import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@Observable
final class AuthService: NSObject {
    static let shared = AuthService()

    var currentUser: FirebaseAuth.User?
    var userProfile: UserProfile?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = false
    var errorMessage: String?

    private var currentNonce: String?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private override init() {
        super.init()
        currentUser = Auth.auth().currentUser
        if let user = currentUser {
            Task { await loadProfile(uid: user.uid) }
        }
    }

    // MARK: - Listen Auth State

    func listenAuthState() {
        // Idempotent — if AppDelegate / SwiftUI app lifecycle calls this
        // more than once (warm relaunch, scene re-entry), don't stack
        // multiple Firebase listeners on top of each other.
        guard authStateHandle == nil else { return }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            if let user {
                Task {
                    await self?.loadProfile(uid: user.uid)
                    // Refresh FCM token on login
                    await PushNotificationService.shared.requestPermissionIfNeeded()
                    await PushNotificationService.shared.refreshToken()
                    // Start in-app notification listeners
                    InAppNotificationManager.shared.startListening(uid: user.uid)
                    // Pre-load availability timeline from Firestore
                    await AvailabilityService.shared.loadMyWeek()
                }
            } else {
                self?.userProfile = nil
            }
        }
    }

    // MARK: - Apple Sign-In

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8)
            else {
                errorMessage = L10n.socialLoginFailed
                isLoading = false
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleCredential.fullName
            )

            do {
                // 12s timeout: Firebase auth endpoints are blocked in
                // mainland China — without this, the call hangs for ~75s
                // and Chinese users force-quit the frozen spinner.
                // See AsyncTimeout.swift for the full writeup.
                let authResult = try await withTimeout(seconds: 12) {
                    try await Auth.auth().signIn(with: credential)
                }
                currentUser = authResult.user

                // Create profile if first time
                let displayName = [
                    appleCredential.fullName?.givenName,
                    appleCredential.fullName?.familyName
                ].compactMap { $0 }.joined(separator: " ")

                await createProfileIfNeeded(
                    uid: authResult.user.uid,
                    email: authResult.user.email ?? "",
                    displayName: displayName.isEmpty ? (authResult.user.displayName ?? "User") : displayName
                )
            } catch {
                errorMessage = error.localizedDescription
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Email Sign-In

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 12s timeout — see AsyncTimeout.swift. Firebase auth is blocked
            // in mainland China; without this the call hangs ~75s.
            let result = try await withTimeout(seconds: 12) {
                try await Auth.auth().signIn(withEmail: email, password: password)
            }
            currentUser = result.user
            await loadProfile(uid: result.user.uid)

            // If the Firestore profile is missing (e.g. account created
            // outside the app, or document manually deleted), create it
            // now so the Social tab renders correctly on first login.
            if userProfile == nil {
                let fallbackName = result.user.displayName
                    ?? String(email.split(separator: "@").first ?? "")
                await createProfileIfNeeded(
                    uid: result.user.uid,
                    email: email,
                    displayName: fallbackName.isEmpty ? "User" : fallbackName
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signUpWithEmail(email: String, password: String, displayName: String, birthday: Date? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            // 12s timeout — see AsyncTimeout.swift.
            let result = try await withTimeout(seconds: 12) {
                try await Auth.auth().createUser(withEmail: email, password: password)
            }
            currentUser = result.user

            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await withTimeout(seconds: 8) {
                try await changeRequest.commitChanges()
            }

            await createProfileIfNeeded(uid: result.user.uid, email: email, displayName: displayName, birthday: birthday)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Password Reset

    /// Sends a Firebase password-reset email. Returns `true` on success,
    /// `false` if Firebase rejects the address. On failure `errorMessage`
    /// is populated with a localized description.
    @discardableResult
    func sendPasswordReset(email: String) async -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = L10n.authResetEmptyEmail
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // 10s timeout — see AsyncTimeout.swift. Without this CN users
            // get a frozen "Send reset email" button for ~75s.
            try await withTimeout(seconds: 10) {
                try await Auth.auth().sendPasswordReset(withEmail: trimmed)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Sign Out

    func signOut() {
        // Capture the uid while still authenticated. The FCM-token removal is a
        // Firestore write that is owner-gated, so it MUST complete *before* we
        // tear down the auth session — the previous `Task { clearToken() }`
        // raced Auth.signOut() (which nils currentUser synchronously), so
        // clearToken read a nil uid and the token was never removed, leaving
        // ghost pushes targeting the signed-out account.
        let uid = Auth.auth().currentUser?.uid
        InAppNotificationManager.shared.stopListening()
        Task { @MainActor in
            if let uid {
                // Bounded so a slow network can't hang sign-out indefinitely.
                try? await withTimeout(seconds: 5) {
                    await FirestoreService.shared.removeFCMToken(uid: uid)
                }
            }
            do {
                try Auth.auth().signOut()
                currentUser = nil
                userProfile = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Delete Account

    enum DeleteAccountError: LocalizedError {
        case notSignedIn
        case reauthenticationRequired
        case firebaseError(Error)

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return L10n.deleteAccountErrorNotSignedIn
            case .reauthenticationRequired: return L10n.deleteAccountErrorReauth
            case .firebaseError(let err): return err.localizedDescription
            }
        }
    }

    /// Delete the user's account permanently.
    /// Steps:
    /// 1. Clear FCM token so push stops targeting this device
    /// 2. Delete all Firestore data (profile, subcollections, reciprocal cleanup)
    /// 3. Delete Firebase Auth account
    /// 4. Clear local observable state
    ///
    /// Firebase requires recent authentication to call `user.delete()`. If the
    /// credential is too old, `.reauthenticationRequired` is thrown — the caller
    /// should prompt the user to sign in again and retry.
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw DeleteAccountError.notSignedIn
        }
        let uid = user.uid

        // Stop push / listeners first — failures here are non-fatal
        await PushNotificationService.shared.clearToken()
        InAppNotificationManager.shared.stopListening()

        // Firestore cleanup runs best-effort (errors logged but not thrown)
        await FirestoreService.shared.deleteAllUserData(uid: uid)

        // Final step: delete the Auth user. This is the only step that must succeed
        // — if this fails the account still exists and Apple's review fails.
        do {
            try await user.delete()
        } catch let nsError as NSError {
            // AuthErrorCode.requiresRecentLogin == 17014
            if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                throw DeleteAccountError.reauthenticationRequired
            }
            throw DeleteAccountError.firebaseError(nsError)
        }

        currentUser = nil
        userProfile = nil
    }

    // MARK: - Profile

    func loadProfile(uid: String) async {
        let loaded = await FirestoreService.shared.getUserProfile(uid: uid)
        // Reconcile Pro entitlement on every profile load:
        //   - grants early bird lifetime Pro if eligible
        //   - syncs `roles` array to match actual Pro state (handles expired rewards)
        let reconciled = await ProEntitlementService.reconcile(
            profile: loaded,
            storeKitPurchased: StoreManager.shared.isPurchasedPro
        )
        // Guard against a stale in-flight load repopulating the profile after a
        // concurrent sign-out (or an account switch) already cleared it.
        guard Auth.auth().currentUser?.uid == uid else { return }
        let profile = reconciled ?? loaded
        userProfile = profile
        // Hydrate the time-limited focus-challenge Pro reward from the server
        // so it survives reinstall / second device — it's otherwise only ever
        // read from local UserDefaults and would be lost.
        await StoreManager.shared.hydrateRewardFromProfile(profile)
    }

    private func createProfileIfNeeded(uid: String, email: String, displayName: String, birthday: Date? = nil) async {
        let existing = await FirestoreService.shared.getUserProfile(uid: uid)
        if existing == nil {
            let profile = UserProfile(
                id: uid,
                displayName: displayName,
                email: email,
                birthday: birthday
            )
            await FirestoreService.shared.createUserProfile(profile)
            userProfile = profile
        } else {
            userProfile = existing
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode == errSecSuccess {
            return String(randomBytes.map { charset[Int($0) % charset.count] })
        }
        // Fallback: UUID is backed by the same secure random pool and is safe for single-use nonces.
        // Avoid fatalError so Apple Sign-In degrades gracefully if the CSPRNG is momentarily unavailable.
        debugPrint("[AuthService] SecRandomCopyBytes failed (OSStatus \(errorCode)), using UUID fallback")
        return (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "").prefix(length).description
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
