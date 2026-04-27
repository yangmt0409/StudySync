import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Firestore sync for `TodoItem`.
///
/// Layout: `users/{uid}/todos/{todoId}`
///
/// Why a Firestore mirror in addition to SwiftData/CloudKit:
///   - SwiftData's CloudKit container only syncs when the user has iCloud
///     Sync explicitly enabled in Settings (default off). For users in
///     mainland China, on a different Apple ID per device, or with iCloud
///     storage full, that channel silently no-ops.
///   - All the other primary entities (CountdownEvent, StudyGoal,
///     GradeCourse, UserSettings, DeadlineRecord) already have a Firestore
///     sync service. TodoItem was the lone outlier — its absence meant
///     todos disappeared on reinstall / new-device login. (User-reported
///     in v1.0.2 hotfix cycle.)
///
/// Conflict resolution: Firestore `setData(merge: true)` + serverTimestamp
/// for `updatedAt` — last writer wins. Same model as `CountdownEventSyncService`.
final class TodoItemSyncService {
    static let shared = TodoItemSyncService()

    private let db = Firestore.firestore()
    private init() {}

    private var uid: String? { AuthService.shared.currentUser?.uid }

    private func collection(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("todos")
    }

    // MARK: - Push

    func pushTodo(_ todo: TodoItem) {
        guard let uid else { return }
        let todoId = todo.id.uuidString
        var data: [String: Any] = [
            "id": todoId,
            "title": todo.title,
            "note": todo.note,
            "emoji": todo.emoji,
            "isCompleted": todo.isCompleted,
            "priorityRaw": todo.priorityRaw,
            "createdAt": Timestamp(date: todo.createdAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let completedAt = todo.completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        } else {
            data["completedAt"] = NSNull()
        }
        if let dueDate = todo.dueDate {
            data["dueDate"] = Timestamp(date: dueDate)
        } else {
            data["dueDate"] = NSNull()
        }
        if let courseName = todo.courseName {
            data["courseName"] = courseName
        } else {
            data["courseName"] = NSNull()
        }
        Task {
            do {
                try await collection(uid).document(todoId).setData(data, merge: true)
            } catch {
                debugPrint("[TodoItemSync] pushTodo error: \(error)")
            }
        }
    }

    func deleteTodo(id: UUID) {
        guard let uid else { return }
        let todoId = id.uuidString
        Task {
            do {
                try await collection(uid).document(todoId).delete()
            } catch {
                debugPrint("[TodoItemSync] deleteTodo error: \(error)")
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

            let locals = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
            var localById: [UUID: TodoItem] = [:]
            for t in locals { localById[t.id] = t }

            for doc in snapshot.documents {
                let data = doc.data()
                guard let idString = data["id"] as? String,
                      let uuid = UUID(uuidString: idString) else { continue }

                let title = data["title"] as? String ?? ""
                let note = data["note"] as? String ?? ""
                let emoji = data["emoji"] as? String ?? "📌"
                let isCompleted = data["isCompleted"] as? Bool ?? false
                let priorityRaw = data["priorityRaw"] as? String ?? "medium"
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
                let dueDate = (data["dueDate"] as? Timestamp)?.dateValue()
                let courseName = data["courseName"] as? String

                if let existing = localById[uuid] {
                    existing.title = title
                    existing.note = note
                    existing.emoji = emoji
                    existing.isCompleted = isCompleted
                    existing.completedAt = completedAt
                    existing.priorityRaw = priorityRaw
                    existing.dueDate = dueDate
                    existing.courseName = courseName
                    existing.createdAt = createdAt
                } else {
                    let newTodo = TodoItem(
                        title: title,
                        note: note,
                        emoji: emoji,
                        isCompleted: isCompleted,
                        completedAt: completedAt,
                        priorityRaw: priorityRaw,
                        dueDate: dueDate
                    )
                    newTodo.id = uuid
                    newTodo.createdAt = createdAt
                    newTodo.courseName = courseName
                    context.insert(newTodo)
                }
            }

            try? context.save()
            debugPrint("[TodoItemSync] ✅ pulled \(snapshot.documents.count) todos from Firestore")
        } catch {
            debugPrint("[TodoItemSync] pullAll error: \(error)")
        }
    }
}
