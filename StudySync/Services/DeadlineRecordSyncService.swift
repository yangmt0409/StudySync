import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Firestore sync for DeadlineRecord (EventKit deadline flags).
///
/// Layout: users/{uid}/deadlineRecords/{eventIdentifier}
///
/// Doc ID uses `eventIdentifier` (the local EKEvent id). We also store
/// `externalIdentifier` in the doc body so a reinstalled device can re-match
/// these records to its own EventKit events via `calendarItemExternalIdentifier`.
final class DeadlineRecordSyncService {
    static let shared = DeadlineRecordSyncService()

    private let db = Firestore.firestore()
    private init() {}

    private var uid: String? { AuthService.shared.currentUser?.uid }

    private func collection(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("deadlineRecords")
    }

    /// Firestore doc IDs can't contain "/" or be empty. EKEvent identifiers
    /// generally don't contain "/", but sanitize defensively.
    private func docId(for record: DeadlineRecord) -> String {
        let raw = record.eventIdentifier.isEmpty ? UUID().uuidString : record.eventIdentifier
        return raw.replacingOccurrences(of: "/", with: "_")
    }

    // MARK: - Push

    func pushRecord(_ record: DeadlineRecord) {
        guard let uid else { return }
        let id = docId(for: record)
        var data: [String: Any] = [
            "eventIdentifier": record.eventIdentifier,
            "externalIdentifier": record.externalIdentifier,
            "isCompleted": record.isCompleted,
            "createdAt": Timestamp(date: record.createdAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let completedAt = record.completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        } else {
            data["completedAt"] = NSNull()
        }
        Task {
            do {
                try await collection(uid).document(id).setData(data, merge: true)
            } catch {
                debugPrint("[DeadlineRecordSync] pushRecord error: \(error)")
            }
        }
    }

    func deleteRecord(eventIdentifier: String) {
        guard let uid else { return }
        let id = eventIdentifier.replacingOccurrences(of: "/", with: "_")
        guard !id.isEmpty else { return }
        Task {
            do {
                try await collection(uid).document(id).delete()
            } catch {
                debugPrint("[DeadlineRecordSync] deleteRecord error: \(error)")
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

            let locals = (try? context.fetch(FetchDescriptor<DeadlineRecord>())) ?? []
            // Index by eventIdentifier AND externalIdentifier so we can match
            // either — externalIdentifier is stable across devices.
            var byEventId: [String: DeadlineRecord] = [:]
            var byExternalId: [String: DeadlineRecord] = [:]
            for r in locals {
                if !r.eventIdentifier.isEmpty { byEventId[r.eventIdentifier] = r }
                if !r.externalIdentifier.isEmpty { byExternalId[r.externalIdentifier] = r }
            }

            for doc in snapshot.documents {
                let data = doc.data()
                let eventIdentifier = data["eventIdentifier"] as? String ?? ""
                let externalIdentifier = data["externalIdentifier"] as? String ?? ""
                let isCompleted = data["isCompleted"] as? Bool ?? false
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let completedAt = (data["completedAt"] as? Timestamp)?.dateValue()

                let existing = byEventId[eventIdentifier]
                    ?? (externalIdentifier.isEmpty ? nil : byExternalId[externalIdentifier])

                if let existing {
                    existing.isCompleted = isCompleted
                    existing.completedAt = completedAt
                    if !externalIdentifier.isEmpty && existing.externalIdentifier.isEmpty {
                        existing.externalIdentifier = externalIdentifier
                    }
                } else {
                    let newRecord = DeadlineRecord(
                        eventIdentifier: eventIdentifier,
                        externalIdentifier: externalIdentifier
                    )
                    newRecord.isCompleted = isCompleted
                    newRecord.completedAt = completedAt
                    newRecord.createdAt = createdAt
                    context.insert(newRecord)
                }
            }

            try? context.save()
            debugPrint("[DeadlineRecordSync] ✅ pulled \(snapshot.documents.count) records from Firestore")
        } catch {
            debugPrint("[DeadlineRecordSync] pullAll error: \(error)")
        }
    }
}
