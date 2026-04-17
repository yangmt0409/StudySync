import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Firestore sync for StudyGoal + CheckInRecord.
///
/// Layout:
///   users/{uid}/studyGoals/{goalId}
///   users/{uid}/studyGoals/{goalId}/checkIns/{checkInId}
///
/// All mutations are fire-and-forget: call `push*` / `delete*` after
/// mutating SwiftData and the service handles the upload in the background.
/// If the user isn't signed in, every method is a silent no-op so the app
/// remains fully usable offline / logged-out.
///
/// On app startup, call `pullAll(context:)` once to hydrate SwiftData from
/// Firestore — this is what restores goals after a reinstall.
final class StudyGoalSyncService {
    static let shared = StudyGoalSyncService()

    private let db = Firestore.firestore()
    private init() {}

    private var uid: String? { AuthService.shared.currentUser?.uid }

    private func goalsCollection(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("studyGoals")
    }

    private func checkInsCollection(_ uid: String, goalId: String) -> CollectionReference {
        goalsCollection(uid).document(goalId).collection("checkIns")
    }

    // MARK: - Push (local → remote)

    /// Upload the full goal document (idempotent).
    func pushGoal(_ goal: StudyGoal) {
        guard let uid else { return }
        let goalId = goal.id.uuidString
        let data: [String: Any] = [
            "id": goalId,
            "title": goal.title,
            "emoji": goal.emoji,
            "colorHex": goal.colorHex,
            "frequencyRaw": goal.frequencyRaw,
            "isActive": goal.isActive,
            "isArchived": goal.isArchived,
            "createdAt": Timestamp(date: goal.createdAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        Task {
            do {
                try await goalsCollection(uid).document(goalId).setData(data, merge: true)
            } catch {
                debugPrint("[StudyGoalSync] pushGoal error: \(error)")
            }
        }
    }

    /// Delete the goal document *and* all of its check-in subcollection docs.
    func deleteGoal(id: UUID) {
        guard let uid else { return }
        let goalId = id.uuidString
        Task {
            do {
                let subSnapshot = try await checkInsCollection(uid, goalId: goalId).getDocuments()
                let batch = db.batch()
                for doc in subSnapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
                batch.deleteDocument(goalsCollection(uid).document(goalId))
                try await batch.commit()
            } catch {
                debugPrint("[StudyGoalSync] deleteGoal error: \(error)")
            }
        }
    }

    /// Upsert a single check-in record.
    func pushCheckIn(_ record: CheckInRecord, goalId: UUID) {
        guard let uid else { return }
        let data: [String: Any] = [
            "id": record.id.uuidString,
            "date": Timestamp(date: record.date),
            "note": record.note
        ]
        let gId = goalId.uuidString
        let cId = record.id.uuidString
        Task {
            do {
                try await checkInsCollection(uid, goalId: gId).document(cId).setData(data, merge: true)
            } catch {
                debugPrint("[StudyGoalSync] pushCheckIn error: \(error)")
            }
        }
    }

    func deleteCheckIn(id: UUID, goalId: UUID) {
        guard let uid else { return }
        let gId = goalId.uuidString
        let cId = id.uuidString
        Task {
            do {
                try await checkInsCollection(uid, goalId: gId).document(cId).delete()
            } catch {
                debugPrint("[StudyGoalSync] deleteCheckIn error: \(error)")
            }
        }
    }

    // MARK: - Pull (remote → local)

    /// Hydrate SwiftData from Firestore. Safe to call on every app launch.
    ///
    /// Strategy:
    /// - For each remote goal: upsert into local SwiftData (overwrite fields).
    /// - For each remote check-in: upsert under its goal.
    /// - Local-only goals/check-ins are left untouched (they'll be pushed
    ///   by their own mutation paths). We never delete locally on pull.
    @MainActor
    func pullAll(context: ModelContext) async {
        guard let uid else { return }

        do {
            let goalsSnapshot = try await goalsCollection(uid).getDocuments()
            guard !goalsSnapshot.documents.isEmpty else { return }

            // Index local goals by id for fast lookup.
            let localGoals = (try? context.fetch(FetchDescriptor<StudyGoal>())) ?? []
            var localById: [UUID: StudyGoal] = [:]
            for g in localGoals { localById[g.id] = g }

            for doc in goalsSnapshot.documents {
                let data = doc.data()
                guard let idString = data["id"] as? String,
                      let goalUUID = UUID(uuidString: idString) else { continue }

                let title = data["title"] as? String ?? ""
                let emoji = data["emoji"] as? String ?? "📚"
                let colorHex = data["colorHex"] as? String ?? "#5B7FFF"
                let frequencyRaw = data["frequencyRaw"] as? String ?? "daily"
                let isActive = data["isActive"] as? Bool ?? true
                let isArchived = data["isArchived"] as? Bool ?? false
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                let goal: StudyGoal
                if let existing = localById[goalUUID] {
                    existing.title = title
                    existing.emoji = emoji
                    existing.colorHex = colorHex
                    existing.frequencyRaw = frequencyRaw
                    existing.isActive = isActive
                    existing.isArchived = isArchived
                    existing.createdAt = createdAt
                    goal = existing
                } else {
                    let newGoal = StudyGoal(
                        title: title,
                        emoji: emoji,
                        colorHex: colorHex,
                        frequency: GoalFrequency(rawValue: frequencyRaw) ?? .daily
                    )
                    newGoal.id = goalUUID
                    newGoal.isActive = isActive
                    newGoal.isArchived = isArchived
                    newGoal.createdAt = createdAt
                    context.insert(newGoal)
                    goal = newGoal
                }

                // Pull check-ins for this goal.
                let checkInSnapshot = try await checkInsCollection(uid, goalId: idString).getDocuments()
                let existingCheckInIds = Set(goal.checkIns.map(\.id))

                for ciDoc in checkInSnapshot.documents {
                    let ciData = ciDoc.data()
                    guard let ciIdString = ciData["id"] as? String,
                          let ciUUID = UUID(uuidString: ciIdString) else { continue }
                    if existingCheckInIds.contains(ciUUID) { continue }

                    let date = (ciData["date"] as? Timestamp)?.dateValue() ?? Date()
                    let note = ciData["note"] as? String ?? ""
                    let record = CheckInRecord(date: date, note: note)
                    record.id = ciUUID
                    record.goal = goal
                    context.insert(record)
                }
            }

            try? context.save()
            debugPrint("[StudyGoalSync] ✅ pulled \(goalsSnapshot.documents.count) goals from Firestore")
        } catch {
            debugPrint("[StudyGoalSync] pullAll error: \(error)")
        }
    }
}
