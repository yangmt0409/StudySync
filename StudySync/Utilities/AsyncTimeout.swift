import Foundation

/// Throws if `operation` doesn't finish within `seconds`.
///
/// ────────────────────────────────────────────────────────────────────────
/// Why we need this
/// ────────────────────────────────────────────────────────────────────────
/// Firebase services route through `googleapis.com` which is **blocked by
/// the Great Firewall in mainland China**. Without a timeout, every
/// `Auth.auth().signIn(...)` / Firestore call hangs at the TCP layer for
/// ~75 seconds before returning an opaque networking error. The user sees
/// a frozen spinner and force-quits — that's the bug Chinese users
/// reported on v1.0.
///
/// Wrapping every cloud-backed call in `withTimeout(seconds: 12)` means:
///   • CN users see a real "network unreachable" error in 12s instead of
///     waiting for the OS-level TCP timeout
///   • Non-CN users with flaky networks also get faster feedback
///   • The Swift Task tree is properly cancelled when timeout fires, so
///     the in-flight Firebase callback can be GC'd cleanly
///
/// Note: the Firebase callback itself may still complete in the background
/// after we threw — we just stop waiting for it. That's fine; subsequent
/// auth state will be picked up by the auth-state listener.
@discardableResult
func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw NetworkTimeoutError()
        }
        // First task to finish wins. Cancel the loser so it doesn't dangle.
        guard let result = try await group.next() else {
            throw NetworkTimeoutError()
        }
        group.cancelAll()
        return result
    }
}

/// Thrown by `withTimeout` when the inner operation didn't complete in time.
/// Wording is deliberately neutral — we don't say "VPN" or "GFW" because
/// the cause could also be airplane mode, a flaky hotspot, or Apple/Google
/// having an outage. The user just needs to know "try again later".
struct NetworkTimeoutError: LocalizedError {
    var errorDescription: String? {
        String(localized: "网络请求超时，请检查网络后重试")
    }
}
