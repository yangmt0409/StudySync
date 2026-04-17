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
                let authResult = try await Auth.auth().signIn(with: credential)
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
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
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
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            currentUser = result.user

            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

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
            try await Auth.auth().sendPasswordReset(withEmail: trimmed)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Sign Out

    func signOut() {
        // Clear FCM token before signing out
        Task { await PushNotificationService.shared.clearToken() }
        // Stop in-app notification listeners
        InAppNotificationManager.shared.stopListening()
        do {
            try Auth.auth().signOut()
            currentUser = nil
            userProfile = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Profile

    func loadProfile(uid: String) async {
        userProfile = await FirestoreService.shared.getUserProfile(uid: uid)
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
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
