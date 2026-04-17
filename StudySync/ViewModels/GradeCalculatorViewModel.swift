import Foundation
import SwiftData

@Observable
final class GradeCalculatorViewModel {
    // MARK: - State

    var showingAddCourse = false
    var showingPaywall = false

    static let freeCourseLimit = 3

    // MARK: - Gate

    func canAddCourse(activeCount: Int) -> Bool {
        StoreManager.shared.isPro || activeCount < Self.freeCourseLimit
    }

    func tryAddCourse(activeCount: Int) {
        if canAddCourse(activeCount: activeCount) {
            showingAddCourse = true
        } else {
            showingPaywall = true
        }
    }

    // MARK: - Course CRUD

    func archiveCourse(_ course: GradeCourse, context: ModelContext) {
        course.isArchived = true
        try? context.save()
        GradeCourseSyncService.shared.pushCourse(course)
        HapticEngine.shared.success()
    }

    func reactivateCourse(_ course: GradeCourse, activeCount: Int, context: ModelContext) -> Bool {
        guard canAddCourse(activeCount: activeCount) else {
            showingPaywall = true
            return false
        }
        course.isArchived = false
        try? context.save()
        GradeCourseSyncService.shared.pushCourse(course)
        HapticEngine.shared.success()
        return true
    }

    func deleteCourse(_ course: GradeCourse, context: ModelContext) {
        let courseId = course.id
        context.delete(course)
        try? context.save()
        GradeCourseSyncService.shared.deleteCourse(id: courseId)
        HapticEngine.shared.success()
    }

    // MARK: - Component CRUD

    func addComponent(to course: GradeCourse, name: String, weight: Double, context: ModelContext) {
        let order = course.components.count
        let comp = GradeComponent(name: name, weightPercent: weight, sortOrder: order)
        comp.course = course
        context.insert(comp)
        try? context.save()
        GradeCourseSyncService.shared.pushComponent(comp, courseId: course.id)
    }

    func updateComponent(_ component: GradeComponent, course: GradeCourse, context: ModelContext) {
        try? context.save()
        GradeCourseSyncService.shared.pushComponent(component, courseId: course.id)
    }

    func deleteComponent(_ component: GradeComponent, course: GradeCourse, context: ModelContext) {
        let compId = component.id
        let courseId = course.id
        context.delete(component)
        try? context.save()
        GradeCourseSyncService.shared.deleteComponent(id: compId, courseId: courseId)
    }
}
