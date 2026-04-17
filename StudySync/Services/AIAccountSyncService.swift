import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Firestore sync for AIAccount **metadata only**.
///
/// Layout: users/{uid}/aiAccounts/{accountId}
///
/// What's synced:
///   provider, nickname, email, organizationId, planName, notifyThreshold,
///   isEnabled, extraUsage*, createdAt, last-known usage snapshot
///
/// What's **NOT** synced:
///   - Login session (lives in `WKWebsiteDataStore.default()` which is
///     sandbox-scoped; Apple doesn't allow cross-install cookie export).
///   - `isAuthenticated` — on pull we always set this to `false`, so restored
///     cards show "needs re-login" and the user re-authenticates once via
///     WebView. Usage auto-refetch resumes after that.
///
/// Why this still matters: users keep their account list, nicknames,
/// thresholds, and last usage snapshot after reinstall — instead of
/// starting from scratch.
final class AIAccountSyncService {
    static let shared = AIAccountSyncService()

    private let db = Firestore.firestore()
    private init() {}

    private var uid: String? { AuthService.shared.currentUser?.uid }

    private func collection(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("aiAccounts")
    }

    // MARK: - Push

    func pushAccount(_ account: AIAccount) {
        guard let uid else { return }
        let accountId = account.id.uuidString
        var data: [String: Any] = [
            "id": accountId,
            "providerRaw": account.providerRaw,
            "nickname": account.nickname,
            "notifyThreshold": account.notifyThreshold,
            "isEnabled": account.isEnabled,
            "extraUsageEnabled": account.extraUsageEnabled,
            "extraUsageLimitCents": account.extraUsageLimitCents,
            "extraUsageUsedCents": account.extraUsageUsedCents,
            "utilization5h": account.utilization5h,
            "utilization7d": account.utilization7d,
            "utilization7dOpus": account.utilization7dOpus,
            "utilization7dSonnet": account.utilization7dSonnet,
            "codexTasksUsed": account.codexTasksUsed,
            "codexTasksLimit": account.codexTasksLimit,
            "createdAt": Timestamp(date: account.createdAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let email = account.email { data["email"] = email }
        if let org = account.organizationId { data["organizationId"] = org }
        if let plan = account.planName { data["planName"] = plan }
        if let r = account.resetTime5h { data["resetTime5h"] = Timestamp(date: r) }
        if let r = account.resetTime7d { data["resetTime7d"] = Timestamp(date: r) }
        if let r = account.resetTime7dOpus { data["resetTime7dOpus"] = Timestamp(date: r) }
        if let r = account.resetTime7dSonnet { data["resetTime7dSonnet"] = Timestamp(date: r) }
        if let last = account.lastFetchedAt { data["lastFetchedAt"] = Timestamp(date: last) }

        Task {
            do {
                try await collection(uid).document(accountId).setData(data, merge: true)
            } catch {
                debugPrint("[AIAccountSync] pushAccount error: \(error)")
            }
        }
    }

    func deleteAccount(id: UUID) {
        guard let uid else { return }
        let accountId = id.uuidString
        Task {
            do {
                try await collection(uid).document(accountId).delete()
            } catch {
                debugPrint("[AIAccountSync] deleteAccount error: \(error)")
            }
        }
    }

    // MARK: - Pull

    @MainActor
    func pullAll(context: ModelContext) async {
        guard let uid else { return }

        do {
            let snapshot = try await collection(uid).getDocuments()
            guard !snapshot.documents.isEmpty else { return }

            let locals = (try? context.fetch(FetchDescriptor<AIAccount>())) ?? []
            var localById: [UUID: AIAccount] = [:]
            for a in locals { localById[a.id] = a }

            for doc in snapshot.documents {
                let data = doc.data()
                guard let idString = data["id"] as? String,
                      let uuid = UUID(uuidString: idString) else { continue }

                let providerRaw = data["providerRaw"] as? String ?? "claude"
                let nickname = data["nickname"] as? String ?? ""
                let notifyThreshold = data["notifyThreshold"] as? Int ?? 80
                let isEnabled = data["isEnabled"] as? Bool ?? true
                let extraUsageEnabled = data["extraUsageEnabled"] as? Bool ?? false
                let extraUsageLimitCents = data["extraUsageLimitCents"] as? Int ?? 0
                let extraUsageUsedCents = data["extraUsageUsedCents"] as? Int ?? 0
                let utilization5h = data["utilization5h"] as? Double ?? 0
                let utilization7d = data["utilization7d"] as? Double ?? 0
                let utilization7dOpus = data["utilization7dOpus"] as? Double ?? 0
                let utilization7dSonnet = data["utilization7dSonnet"] as? Double ?? 0
                let codexTasksUsed = data["codexTasksUsed"] as? Int ?? 0
                let codexTasksLimit = data["codexTasksLimit"] as? Int ?? 0
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let email = data["email"] as? String
                let organizationId = data["organizationId"] as? String
                let planName = data["planName"] as? String
                let resetTime5h = (data["resetTime5h"] as? Timestamp)?.dateValue()
                let resetTime7d = (data["resetTime7d"] as? Timestamp)?.dateValue()
                let resetTime7dOpus = (data["resetTime7dOpus"] as? Timestamp)?.dateValue()
                let resetTime7dSonnet = (data["resetTime7dSonnet"] as? Timestamp)?.dateValue()
                let lastFetchedAt = (data["lastFetchedAt"] as? Timestamp)?.dateValue()

                let target: AIAccount
                if let existing = localById[uuid] {
                    target = existing
                } else {
                    let provider = AIProvider(rawValue: providerRaw) ?? .claude
                    let newAccount = AIAccount(provider: provider, nickname: nickname)
                    newAccount.id = uuid
                    context.insert(newAccount)
                    target = newAccount
                }

                target.providerRaw = providerRaw
                target.nickname = nickname
                target.notifyThreshold = notifyThreshold
                target.isEnabled = isEnabled
                target.extraUsageEnabled = extraUsageEnabled
                target.extraUsageLimitCents = extraUsageLimitCents
                target.extraUsageUsedCents = extraUsageUsedCents
                target.utilization5h = utilization5h
                target.utilization7d = utilization7d
                target.utilization7dOpus = utilization7dOpus
                target.utilization7dSonnet = utilization7dSonnet
                target.codexTasksUsed = codexTasksUsed
                target.codexTasksLimit = codexTasksLimit
                target.createdAt = createdAt
                target.email = email
                target.organizationId = organizationId
                target.planName = planName
                target.resetTime5h = resetTime5h
                target.resetTime7d = resetTime7d
                target.resetTime7dOpus = resetTime7dOpus
                target.resetTime7dSonnet = resetTime7dSonnet
                target.lastFetchedAt = lastFetchedAt

                // Session can't be restored across reinstall — the WebView
                // sandbox is gone. Force re-login UI unless the local
                // instance is already authenticated in this app session.
                if localById[uuid] == nil {
                    target.isAuthenticated = false
                }
            }

            try? context.save()
            debugPrint("[AIAccountSync] ✅ pulled \(snapshot.documents.count) AI accounts from Firestore")
        } catch {
            debugPrint("[AIAccountSync] pullAll error: \(error)")
        }
    }
}
