import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Firestore sync for `FocusSession` (focus history).
///
/// Layout: `users/{uid}/focusSessions/{sessionId}`
///
/// Why sync:
/// - Focus history powers the Study Analytics charts (weekly bars, time-of-
///   day heatmap, total streak). On a new device, those screens look like
///   the user has never focused before until iCloud propagates — and on
///   accounts without iCloud sync enabled, they never get back at all.
/// - Focus minutes also unlock Study Space decorations; if history is
///   missing the unlock state silently regresses.
/// - Group focus sessions write extra "bonus" minutes via the same model.
///
/// We push on session start (so the in-progress session is reachable), and
/// re-push on completion / give-up. Incomplete sessions older than 24h are
/// considered stale by the pull (the user probably force-quit) — but we
/// still keep them locally; the analytics queries filter on `isCompleted`.
final class FocusSessionSyncService {
    static let shared = FocusSessionSyncService()

    private let db = Firestore.firestore()
    private init() {}

    private var uid: String? { AuthService.shared.currentUser?.uid }

    private func collection(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("focusSessions")
    }

    // MARK: - Push

    func pushSession(_ session: FocusSession) {
        guard let uid else { return }
        let sessionId = session.id.uuidString
        var data: [String: Any] = [
            "id": sessionId,
            "durationMinutes": session.durationMinutes,
            "actualSeconds": session.actualSeconds,
            "foregroundSeconds": session.foregroundSeconds,
            "emoji": session.emoji,
            "label": session.label,
            "isCompleted": session.isCompleted,
            "startedAt": Timestamp(date: session.startedAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let endedAt = session.endedAt {
            data["endedAt"] = Timestamp(date: endedAt)
        } else {
            data["endedAt"] = NSNull()
        }
        Task {
            do {
                try await collection(uid).document(sessionId).setData(data, merge: true)
            } catch {
                debugPrint("[FocusSessionSync] pushSession error: \(error)")
            }
        }
    }

    func deleteSession(id: UUID) {
        guard let uid else { return }
        let sessionId = id.uuidString
        Task {
            do {
                try await collection(uid).document(sessionId).delete()
            } catch {
                debugPrint("[FocusSessionSync] deleteSession error: \(error)")
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

            let locals = (try? context.fetch(FetchDescriptor<FocusSession>())) ?? []
            var localById: [UUID: FocusSession] = [:]
            for s in locals { localById[s.id] = s }

            for doc in snapshot.documents {
                let data = doc.data()
                guard let idString = data["id"] as? String,
                      let uuid = UUID(uuidString: idString) else { continue }

                let durationMinutes = data["durationMinutes"] as? Int ?? 25
                let actualSeconds = data["actualSeconds"] as? Int ?? 0
                let foregroundSeconds = data["foregroundSeconds"] as? Int ?? 0
                let emoji = data["emoji"] as? String ?? "📚"
                let label = data["label"] as? String ?? ""
                let isCompleted = data["isCompleted"] as? Bool ?? false
                let startedAt = (data["startedAt"] as? Timestamp)?.dateValue() ?? Date()
                let endedAt = (data["endedAt"] as? Timestamp)?.dateValue()

                if let existing = localById[uuid] {
                    existing.durationMinutes = durationMinutes
                    existing.actualSeconds = actualSeconds
                    existing.foregroundSeconds = foregroundSeconds
                    existing.emoji = emoji
                    existing.label = label
                    existing.isCompleted = isCompleted
                    existing.startedAt = startedAt
                    existing.endedAt = endedAt
                } else {
                    let newSession = FocusSession(
                        durationMinutes: durationMinutes,
                        emoji: emoji,
                        label: label
                    )
                    newSession.id = uuid
                    newSession.actualSeconds = actualSeconds
                    newSession.foregroundSeconds = foregroundSeconds
                    newSession.isCompleted = isCompleted
                    newSession.startedAt = startedAt
                    newSession.endedAt = endedAt
                    context.insert(newSession)
                }
            }

            try? context.save()
            debugPrint("[FocusSessionSync] ✅ pulled \(snapshot.documents.count) focus sessions from Firestore")
        } catch {
            debugPrint("[FocusSessionSync] pullAll error: \(error)")
        }
    }
}
