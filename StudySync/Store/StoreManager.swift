import Foundation
import StoreKit
import SwiftUI
import FirebaseAuth

@Observable
final class StoreManager {
    static let shared = StoreManager()

    private let productID = "com.studysync.pro"
    private let proRewardKey = "proRewardExpiresAt"
    private let challengeClaimedKey = "focusChallengeClaimedMonth"

    var product: Product?
    /// Whether the user purchased Pro via StoreKit
    var isPurchasedPro: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    /// Pro reward expiry from focus challenge (100 h/month → 3 months Pro)
    var proRewardExpiresAt: Date?

    private var transactionListener: Task<Void, Error>?

    /// True if user has Pro via StoreKit, lifetime grant (early bird / lifetime IAP),
    /// or an active focus challenge reward.
    ///
    /// This is the single source of truth for gating Pro features in the UI.
    /// Keep it aligned with `UserProfile.isProActive(...)` on the server side.
    var isPro: Bool {
        isPurchasedPro || hasLifetimeGrant || hasActiveProReward
    }

    /// True if the current profile has `proLifetime = true`.
    /// Falls back to false when no profile is loaded (e.g. signed out).
    var hasLifetimeGrant: Bool {
        AuthService.shared.userProfile?.proLifetime == true
    }

    var hasActiveProReward: Bool {
        guard let expiry = proRewardExpiresAt else { return false }
        return expiry > Date()
    }

    /// Whether the 100 h challenge was already claimed for the current calendar month
    var focusChallengeClaimedThisMonth: Bool {
        guard let claimed = UserDefaults.standard.string(forKey: challengeClaimedKey) else { return false }
        return claimed == Self.monthKey()
    }

    private init() {
        // Load cached pro-reward expiry
        proRewardExpiresAt = UserDefaults.standard.object(forKey: proRewardKey) as? Date
        transactionListener = listenForTransactions()
        Task { await checkProStatus() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Product

    @MainActor
    func loadProduct() async {
        isLoading = true
        errorMessage = nil

        do {
            let products = try await Product.products(for: [productID])
            if let first = products.first {
                product = first
                debugPrint("[Store] Product loaded: \(first.id) — \(first.displayPrice)")
            } else {
                debugPrint("[Store] Product ID \(productID) returned no results — not yet approved on App Store Connect?")
                errorMessage = L10n.productLoadError
            }
        } catch {
            debugPrint("[Store] loadProduct error: \(error)")
            errorMessage = L10n.productLoadError
        }

        isLoading = false
    }

    // MARK: - Purchase

    @MainActor
    func purchase() async -> Bool {
        guard let product else {
            errorMessage = L10n.productNotLoaded
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                isPurchasedPro = true
                await transaction.finish()
                // Reconcile roles against the new purchase state
                await reconcileProfile()
                isLoading = false
                return true

            case .userCancelled:
                isLoading = false
                return false

            case .pending:
                errorMessage = L10n.purchasePending
                isLoading = false
                return false

            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            errorMessage = L10n.purchaseFailed(error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Restore

    @MainActor
    func restore() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkProStatus()

            if !isPurchasedPro {
                errorMessage = L10n.noRestorableRecord
            }
        } catch {
            errorMessage = L10n.restoreFailed(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Check Status

    @MainActor
    func checkProStatus() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID,
               transaction.revocationDate == nil {
                found = true
                break
            }
        }
        let changed = isPurchasedPro != found
        isPurchasedPro = found

        // Reconcile Firestore roles against updated purchase state
        if changed {
            await reconcileProfile()
        }
    }

    /// Shared helper: re-runs the Pro entitlement reconciler using the currently
    /// loaded profile. Called after purchase, expiry changes, or startup status check.
    @MainActor
    private func reconcileProfile() async {
        guard Auth.auth().currentUser?.uid != nil else { return }
        let current = AuthService.shared.userProfile
        let reconciled = await ProEntitlementService.reconcile(
            profile: current,
            storeKitPurchased: isPurchasedPro
        )
        if let reconciled {
            AuthService.shared.userProfile = reconciled
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await MainActor.run {
                        if transaction.productID == self.productID {
                            self.isPurchasedPro = transaction.revocationDate == nil
                        }
                    }
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Focus Challenge Reward

    /// Restore the time-limited focus-challenge Pro reward from the server-side
    /// profile. `proRewardExpiresAt` is otherwise only ever loaded from local
    /// UserDefaults, so on a reinstall / second device the reward the user
    /// earned would be lost even though it's recorded in Firestore. Take the
    /// later of local vs remote so a stale device never shortens an active
    /// reward, and persist locally so the gate survives offline launches.
    @MainActor
    func hydrateRewardFromProfile(_ profile: UserProfile?) {
        guard let remote = profile?.proRewardExpiresAt,
              remote > (proRewardExpiresAt ?? .distantPast) else { return }
        proRewardExpiresAt = remote
        UserDefaults.standard.set(remote, forKey: proRewardKey)
    }

    /// Grant 3 months of Pro for completing the monthly 100 h focus challenge.
    @MainActor
    func grantFocusChallengeReward() {
        let calendar = Calendar.current
        let baseDate = max(proRewardExpiresAt ?? Date(), Date())
        guard let newExpiry = calendar.date(byAdding: .month, value: 3, to: baseDate) else { return }

        proRewardExpiresAt = newExpiry
        UserDefaults.standard.set(newExpiry, forKey: proRewardKey)
        UserDefaults.standard.set(Self.monthKey(), forKey: challengeClaimedKey)

        // Sync to Firestore + reconcile roles (adds "pro" if not already present)
        if let uid = Auth.auth().currentUser?.uid {
            Task {
                await FirestoreService.shared.updateProfile(uid: uid, fields: [
                    "proRewardExpiresAt": newExpiry
                ])
                // Update local profile so the reconciler sees the fresh expiry
                if var profile = AuthService.shared.userProfile {
                    profile.proRewardExpiresAt = newExpiry
                    AuthService.shared.userProfile = profile
                }
                await reconcileProfile()
            }
        }
    }

    private static func monthKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    enum StoreError: LocalizedError {
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .verificationFailed:
                return L10n.verificationFailed
            }
        }
    }
}
