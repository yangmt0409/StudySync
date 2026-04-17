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

    /// True if user has Pro via StoreKit purchase OR an active focus challenge reward
    var isPro: Bool {
        isPurchasedPro || hasActiveProReward
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
            product = products.first
        } catch {
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
                // Sync Pro role
                if let uid = Auth.auth().currentUser?.uid {
                    Task { await FirestoreService.shared.syncProRole(uid: uid, isPro: true) }
                }
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

        // Sync Pro role to Firestore when purchase status changes
        if changed, let uid = Auth.auth().currentUser?.uid {
            Task { await FirestoreService.shared.syncProRole(uid: uid, isPro: found) }
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

    /// Grant 3 months of Pro for completing the monthly 100 h focus challenge.
    @MainActor
    func grantFocusChallengeReward() {
        let calendar = Calendar.current
        let baseDate = max(proRewardExpiresAt ?? Date(), Date())
        guard let newExpiry = calendar.date(byAdding: .month, value: 3, to: baseDate) else { return }

        proRewardExpiresAt = newExpiry
        UserDefaults.standard.set(newExpiry, forKey: proRewardKey)
        UserDefaults.standard.set(Self.monthKey(), forKey: challengeClaimedKey)

        // Sync to Firestore
        if let uid = Auth.auth().currentUser?.uid {
            Task {
                await FirestoreService.shared.updateProfile(uid: uid, fields: [
                    "proRewardExpiresAt": newExpiry
                ])
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
