import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Firestore sync for GradeCourse + GradeComponent.
///
/// Layout:
///   users/{uid}/gradeCourses/{courseId}
///   users/{uid}/gradeCourses/{courseId}/components/{componentId}
///
/// All mutations are fire-and-forget: call `push*` / `delete*` after
/// mutating SwiftData and the service handles the upload in the background.
/// If the user isn't signed in, every method is a silent no-op.
final class GradeCourseSyncService {
    static let shared = GradeCourseSyncService()

    private let db = Firestore.firestore()
    private init() {}

    private var uid: String? { AuthService.shared.currentUser?.uid }

    private func coursesCollection(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("gradeCourses")
    }

    private func componentsCollection(_ uid: String, courseId: String) -> CollectionReference {
        coursesCollection(uid).document(courseId).collection("components")
    }

    // MARK: - Push (local → remote)

    func pushCourse(_ course: GradeCourse) {
        guard let uid else { return }
        let courseId = course.id.uuidString
        let data: [String: Any] = [
            "id": courseId,
            "name": course.name,
            "emoji": course.emoji,
            "colorHex": course.colorHex,
            "targetGradePercent": course.targetGradePercent,
            "isArchived": course.isArchived,
            "createdAt": Timestamp(date: course.createdAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        Task {
            do {
                try await coursesCollection(uid).document(courseId).setData(data, merge: true)
            } catch {
                debugPrint("[GradeCourseSync] pushCourse error: \(error)")
            }
        }
    }

    func pushComponent(_ component: GradeComponent, courseId: UUID) {
        guard let uid else { return }
        let cId = courseId.uuidString
        let compId = component.id.uuidString
        var data: [String: Any] = [
            "id": compId,
            "name": component.name,
            "weightPercent": component.weightPercent,
            "inputModeRaw": component.inputModeRaw,
            "isFinal": component.isFinal,
            "sortOrder": component.sortOrder
        ]
        if let v = component.scoreNumerator { data["scoreNumerator"] = v } else { data["scoreNumerator"] = NSNull() }
        if let v = component.scoreDenominator { data["scoreDenominator"] = v } else { data["scoreDenominator"] = NSNull() }
        if let v = component.scorePercent { data["scorePercent"] = v } else { data["scorePercent"] = NSNull() }

        Task {
            do {
                try await componentsCollection(uid, courseId: cId).document(compId).setData(data, merge: true)
            } catch {
                debugPrint("[GradeCourseSync] pushComponent error: \(error)")
            }
        }
    }

    func deleteCourse(id: UUID) {
        guard let uid else { return }
        let courseId = id.uuidString
        Task {
            do {
                let subSnapshot = try await componentsCollection(uid, courseId: courseId).getDocuments()
                let batch = db.batch()
                for doc in subSnapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
                batch.deleteDocument(coursesCollection(uid).document(courseId))
                try await batch.commit()
            } catch {
                debugPrint("[GradeCourseSync] deleteCourse error: \(error)")
            }
        }
    }

    func deleteComponent(id: UUID, courseId: UUID) {
        guard let uid else { return }
        Task {
            do {
                try await componentsCollection(uid, courseId: courseId.uuidString)
                    .document(id.uuidString).delete()
            } catch {
                debugPrint("[GradeCourseSync] deleteComponent error: \(error)")
            }
        }
    }

    // MARK: - Pull (remote → local)

    @MainActor
    func pullAll(context: ModelContext) async {
        guard let uid else { return }

        do {
            let coursesSnapshot = try await coursesCollection(uid).getDocuments()
            guard !coursesSnapshot.documents.isEmpty else { return }

            let localCourses = (try? context.fetch(FetchDescriptor<GradeCourse>())) ?? []
            var localById: [UUID: GradeCourse] = [:]
            for c in localCourses { localById[c.id] = c }

            for doc in coursesSnapshot.documents {
                let data = doc.data()
                guard let idString = data["id"] as? String,
                      let courseUUID = UUID(uuidString: idString) else { continue }

                let name = data["name"] as? String ?? ""
                let emoji = data["emoji"] as? String ?? "📘"
                let colorHex = data["colorHex"] as? String ?? "#5B7FFF"
                let targetGrade = data["targetGradePercent"] as? Double ?? 90.0
                let isArchived = data["isArchived"] as? Bool ?? false
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                let course: GradeCourse
                if let existing = localById[courseUUID] {
                    existing.name = name
                    existing.emoji = emoji
                    existing.colorHex = colorHex
                    existing.targetGradePercent = targetGrade
                    existing.isArchived = isArchived
                    existing.createdAt = createdAt
                    course = existing
                } else {
                    let newCourse = GradeCourse(name: name, emoji: emoji, colorHex: colorHex, targetGradePercent: targetGrade)
                    newCourse.id = courseUUID
                    newCourse.isArchived = isArchived
                    newCourse.createdAt = createdAt
                    context.insert(newCourse)
                    course = newCourse
                }

                // Pull components
                let compSnapshot = try await componentsCollection(uid, courseId: idString).getDocuments()
                let existingCompIds = Set(course.components.map(\.id))

                for compDoc in compSnapshot.documents {
                    let cd = compDoc.data()
                    guard let compIdStr = cd["id"] as? String,
                          let compUUID = UUID(uuidString: compIdStr) else { continue }

                    let compName = cd["name"] as? String ?? ""
                    let weight = cd["weightPercent"] as? Double ?? 0
                    let sortOrder = cd["sortOrder"] as? Int ?? 0
                    let inputModeRaw = cd["inputModeRaw"] as? String ?? "raw"
                    let isFinal = cd["isFinal"] as? Bool ?? false
                    let scoreNum = cd["scoreNumerator"] as? Double
                    let scoreDen = cd["scoreDenominator"] as? Double
                    let scorePct = cd["scorePercent"] as? Double

                    if let existing = course.components.first(where: { $0.id == compUUID }) {
                        existing.name = compName
                        existing.weightPercent = weight
                        existing.sortOrder = sortOrder
                        existing.inputModeRaw = inputModeRaw
                        existing.isFinal = isFinal
                        existing.scoreNumerator = scoreNum
                        existing.scoreDenominator = scoreDen
                        existing.scorePercent = scorePct
                    } else if !existingCompIds.contains(compUUID) {
                        let comp = GradeComponent(name: compName, weightPercent: weight, sortOrder: sortOrder)
                        comp.id = compUUID
                        comp.inputModeRaw = inputModeRaw
                        comp.isFinal = isFinal
                        comp.scoreNumerator = scoreNum
                        comp.scoreDenominator = scoreDen
                        comp.scorePercent = scorePct
                        comp.course = course
                        context.insert(comp)
                    }
                }
            }

            try? context.save()
            debugPrint("[GradeCourseSync] pulled \(coursesSnapshot.documents.count) courses from Firestore")
        } catch {
            debugPrint("[GradeCourseSync] pullAll error: \(error)")
        }
    }
}
