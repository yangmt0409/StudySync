import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Firestore sync for `StudySpaceItem` (desk decoration unlocks).
///
/// Layout: `users/{uid}/spaceItems/{itemId}`
///
/// We use `itemId` (the catalog string like `"desk_lamp"`) as the Firestore
/// document ID rather than the SwiftData UUID `id`. Reasons:
///   1. Each catalog item should unlock at most once — using `itemId` as the
///      doc id makes that an idempotency invariant. If the user focuses
///      enough hours on iPhone and iPad simultaneously, both writes land at
///      the same path and merge harmlessly instead of creating duplicates.
///   2. The `StudySpaceItem` UUID is not stable across SwiftData/CloudKit
///      sync vs Firestore push — using the catalog ID means pulls converge.
///
/// `unlockedAt` is preserved (earliest write wins on merge via setData merge).
final class StudySpaceItemSyncService {
    static let shared = StudySpaceItemSyncService()

    private let db = Firestore.firestore()
    private init() {}

    private var uid: String? { AuthService.shared.currentUser?.uid }

    private func collection(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("spaceItems")
    }

    // MARK: - Push

    func pushItem(_ item: StudySpaceItem) {
        guard let uid else { return }
        // Use itemId (catalog string) as doc id — idempotent across devices.
        let docId = item.itemId
        let data: [String: Any] = [
            "itemId": item.itemId,
            "uuid": item.id.uuidString,
            "unlockedAt": Timestamp(date: item.unlockedAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        Task {
            do {
                try await collection(uid).document(docId).setData(data, merge: true)
            } catch {
                debugPrint("[StudySpaceItemSync] pushItem error: \(error)")
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

            let locals = (try? context.fetch(FetchDescriptor<StudySpaceItem>())) ?? []
            var localByItemId: [String: StudySpaceItem] = [:]
            for item in locals { localByItemId[item.itemId] = item }

            for doc in snapshot.documents {
                let data = doc.data()
                guard let itemId = data["itemId"] as? String, !itemId.isEmpty else { continue }
                let unlockedAt = (data["unlockedAt"] as? Timestamp)?.dateValue() ?? Date()

                if let existing = localByItemId[itemId] {
                    // Earliest unlock wins (preserve original unlock date).
                    if unlockedAt < existing.unlockedAt {
                        existing.unlockedAt = unlockedAt
                    }
                } else {
                    let newItem = StudySpaceItem(itemId: itemId)
                    newItem.unlockedAt = unlockedAt
                    if let uuidString = data["uuid"] as? String,
                       let uuid = UUID(uuidString: uuidString) {
                        newItem.id = uuid
                    }
                    context.insert(newItem)
                }
            }

            try? context.save()
            debugPrint("[StudySpaceItemSync] ✅ pulled \(snapshot.documents.count) space items from Firestore")
        } catch {
            debugPrint("[StudySpaceItemSync] pullAll error: \(error)")
        }
    }
}
