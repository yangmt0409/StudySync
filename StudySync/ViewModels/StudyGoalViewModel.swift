import Foundation
import SwiftData
import Observation
import UserNotifications
import FirebaseAuth

@Observable
final class StudyGoalViewModel {
    var showingAddGoal = false
    var showingPaywall = false
    var showingCelebration = false
    var celebrationGoal: StudyGoal?
    var celebrationMilestone: Milestone?

    /// Free users may keep at most `freeActiveGoalLimit` active goals at a
    /// time. Pro users have no cap.
    static let freeActiveGoalLimit = 3

    func canAddGoal(activeCount: Int) -> Bool {
        StoreManager.shared.isPro || activeCount < Self.freeActiveGoalLimit
    }

    /// Call from "+ add goal" entry points. Opens the add sheet if allowed,
    /// otherwise surfaces Paywall.
    func tryAddGoal(activeCount: Int) {
        if canAddGoal(activeCount: activeCount) {
            showingAddGoal = true
        } else {
            showingPaywall = true
        }
    }

    func checkIn(goal: StudyGoal, context: ModelContext) {
        guard goal.needsCheckIn else { return }

        let record = CheckInRecord(date: Date())
        record.goal = goal
        context.insert(record)
        try? context.save()

        // Cloud sync
        StudyGoalSyncService.shared.pushCheckIn(record, goalId: goal.id)

        // Check milestone after adding
        let newCount = goal.totalCheckIns + 1 // +1 because relationship may not update instantly
        if let milestone = Milestone.reached(count: newCount, frequency: goal.frequency) {
            celebrationGoal = goal
            celebrationMilestone = milestone
            showingCelebration = true
            HapticEngine.shared.celebrationBurst()

            // Send notification
            scheduleMilestoneNotification(goal: goal, milestone: milestone)
        } else {
            HapticEngine.shared.lightImpact()
        }

        // Sync aggregated stats to Firestore (for social profile display)
        pushStatsToFirestore(context: context)
    }

    func undoCheckIn(goal: StudyGoal, context: ModelContext) {
        let calendar = Calendar.current
        if let todayRecord = goal.checkIns.first(where: { calendar.isDateInToday($0.date) }) {
            let recordId = todayRecord.id
            let goalId = goal.id
            context.delete(todayRecord)
            try? context.save()
            StudyGoalSyncService.shared.deleteCheckIn(id: recordId, goalId: goalId)
        }
    }

    func archiveGoal(_ goal: StudyGoal) {
        goal.isActive = false
        goal.isArchived = true
        StudyGoalSyncService.shared.pushGoal(goal)
    }

    func reactivateGoal(_ goal: StudyGoal, activeCount: Int) -> Bool {
        guard canAddGoal(activeCount: activeCount) else { return false }
        goal.isActive = true
        goal.isArchived = false
        StudyGoalSyncService.shared.pushGoal(goal)
        return true
    }

    func deleteGoal(_ goal: StudyGoal, context: ModelContext) {
        let goalId = goal.id
        context.delete(goal)
        try? context.save()
        StudyGoalSyncService.shared.deleteGoal(id: goalId)
    }

    // MARK: - Stats Sync

    /// Compute aggregated stats from ALL local goals and push to Firestore.
    /// Runs in background — no UI blocking.
    func pushStatsToFirestore(context: ModelContext) {
        guard let uid = AuthService.shared.currentUser?.uid else { return }

        // Fetch all goals from SwiftData
        let descriptor = FetchDescriptor<StudyGoal>()
        guard let allGoals = try? context.fetch(descriptor) else { return }

        let totalCheckIns = allGoals.reduce(0) { $0 + $1.totalCheckIns }
        let longestStreak = allGoals.map(\.currentStreak).max() ?? 0

        Task {
            await FirestoreService.shared.updateStats(
                uid: uid,
                totalCheckIns: totalCheckIns,
                longestStreak: longestStreak
            )
        }
    }

    // MARK: - Notifications

    private func scheduleMilestoneNotification(goal: StudyGoal, milestone: Milestone) {
        let content = UNMutableNotificationContent()
        content.title = "\(milestone.emoji) \(L10n.goalMilestoneReached)"
        content.body = L10n.goalMilestoneBody(title: goal.title, count: milestone.count)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "milestone-\(goal.id.uuidString)-\(milestone.count)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
