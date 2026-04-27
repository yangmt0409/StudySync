import Foundation
import FirebaseAuth

/// Single source of truth reconciler for Pro status.
///
/// Pro has three independent sources:
///   1. `profile.proLifetime` — early bird grant or future lifetime IAP
///   2. StoreKit subscription (observed by StoreManager)
///   3. `profile.proRewardExpiresAt` — focus challenge reward (time-limited)
///
/// `profile.roles.contains("pro")` is treated as a DERIVED field. Whenever the
/// app loads a profile, completes a purchase, or grants/revokes a reward, we
/// call `reconcile` to make sure the roles array matches the true Pro state.
///
/// This fixes two historical issues:
///   - Pro tag never removed on reward expiry (stale badge visible to friends)
///   - Pro tag never auto-added when server-side state was granted
@MainActor
enum ProEntitlementService {

    // MARK: - Early Bird Configuration

    /// Users whose `createdAt` is strictly before this timestamp qualify for
    /// the lifetime Pro early bird grant.
    ///
    /// Policy: Anyone who signed up before **April 24, 2026 23:59:59 Toronto time**
    /// (America/Toronto, EDT = UTC-4 in April). That's April 25, 00:00 EDT as the
    /// strict upper bound, which converts to April 25, 04:00 UTC.
    ///
    /// ⚠️ Do NOT change this after launch — any grant already written to
    /// Firestore is locked by `earlyBirdGrantedAt` so it can't be revoked,
    /// but changing this value may confuse borderline users who haven't opened
    /// the app yet.
    static let earlyBirdRegistrationCutoff: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 25
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "America/Toronto")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }()

    /// The grant activates at **April 27, 2026 00:00 Toronto time**. Before that,
    /// even if a user qualifies, the reconciler will NOT write `proLifetime = true`.
    ///
    /// This gives us a window (Apr 25–26) to push the updated binary to the App
    /// Store and verify rollout without users seeing the grant before it's
    /// officially announced.
    static let earlyBirdGrantActiveFrom: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 27
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "America/Toronto")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }()

    // MARK: - Public API

    /// Reconcile the `roles` array on a user profile against the true Pro state.
    /// Also runs the early bird grant check if the user is eligible.
    ///
    /// Safe to call repeatedly — all operations are idempotent. Writes to
    /// Firestore only when changes are needed.
    ///
    /// - Returns: The reconciled profile (locally updated), or nil if no profile.
    @discardableResult
    static func reconcile(profile initial: UserProfile?, storeKitPurchased: Bool) async -> UserProfile? {
        guard var profile = initial else { return nil }

        // 1. Early bird grant — runs once, before reconciliation
        if shouldGrantEarlyBird(profile: profile) {
            profile.proLifetime = true
            profile.earlyBirdGrantedAt = Date()
            if !profile.roles.contains(UserRole.earlyBird.rawValue) {
                profile.roles.append(UserRole.earlyBird.rawValue)
            }
            await FirestoreService.shared.updateProfile(uid: profile.id, fields: [
                "proLifetime": true,
                "earlyBirdGrantedAt": profile.earlyBirdGrantedAt ?? Date(),
                "roles": profile.roles
            ])
            debugPrint("[ProEntitlement] Granted early bird lifetime Pro to \(profile.id)")
        }

        // 2. Reconcile "pro" role against actual entitlement
        let shouldHavePro = profile.isProActive(storeKitPurchased: storeKitPurchased)
        let hasProRole = profile.roles.contains(UserRole.pro.rawValue)

        if shouldHavePro && !hasProRole {
            await FirestoreService.shared.addRole(uid: profile.id, role: UserRole.pro.rawValue)
            profile.roles.append(UserRole.pro.rawValue)
            await propagateRoleChange(uid: profile.id, roles: profile.roles)
            debugPrint("[ProEntitlement] Added 'pro' role for \(profile.id)")
        } else if !shouldHavePro && hasProRole {
            await FirestoreService.shared.removeRole(uid: profile.id, role: UserRole.pro.rawValue)
            profile.roles.removeAll { $0 == UserRole.pro.rawValue }
            await propagateRoleChange(uid: profile.id, roles: profile.roles)
            debugPrint("[ProEntitlement] Removed stale 'pro' role for \(profile.id)")
        }

        return profile
    }

    // MARK: - Private

    private static func shouldGrantEarlyBird(profile: UserProfile) -> Bool {
        // Already granted — idempotent
        if profile.proLifetime || profile.earlyBirdGrantedAt != nil {
            return false
        }
        // Grant window hasn't opened yet — don't write prematurely
        if Date() < earlyBirdGrantActiveFrom {
            return false
        }
        // User must have signed up before the registration cutoff
        return profile.createdAt < earlyBirdRegistrationCutoff
    }

    /// When a user's roles change, update the cached `FriendInfo.roles` in each
    /// of their friends' `friends` subcollection so peers see fresh badges
    /// without waiting for a manual refresh.
    ///
    /// Best-effort: errors are logged but not rethrown.
    private static func propagateRoleChange(uid: String, roles: [String]) async {
        await FirestoreService.shared.propagateRolesToFriends(uid: uid, roles: roles)
    }
}
