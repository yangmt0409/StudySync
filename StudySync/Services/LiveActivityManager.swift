import ActivityKit
import EventKit
import SwiftUI
import UIKit

@Observable
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    var activeActivity: Activity<DueCountdownAttributes>?
    var currentEventIdentifier: String?

    // Settings
    var liveActivityEnabled: Bool {
        get { SyncedDefaults.shared.object(forKey: "liveActivityEnabled") as? Bool ?? true }
        set { SyncedDefaults.shared.set(newValue, forKey: "liveActivityEnabled") }
    }

    var liveActivityLeadMinutes: Int {
        get {
            let val = SyncedDefaults.shared.integer(forKey: "liveActivityLeadMinutes")
            return val > 0 ? val : 60
        }
        set { SyncedDefaults.shared.set(newValue, forKey: "liveActivityLeadMinutes") }
    }

    var overdueTimeoutMinutes: Int {
        get {
            let val = SyncedDefaults.shared.integer(forKey: "overdueTimeoutMinutes")
            return val > 0 ? val : 5
        }
        set { SyncedDefaults.shared.set(newValue, forKey: "overdueTimeoutMinutes") }
    }

    private var updateTask: Task<Void, Never>?

    private init() {}

    // MARK: - Start

    func startCountdown(for event: EKEvent, emoji: String) {
        guard liveActivityEnabled else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End existing activity first
        if activeActivity != nil {
            endCountdown(completed: false, switchingToNext: true)
        }

        let calColor = UIColor(cgColor: event.calendar.cgColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        calColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))

        let attributes = DueCountdownAttributes(
            eventTitle: event.title ?? "Due",
            emoji: emoji,
            dueDate: event.startDate,
            calendarColorHex: hex
        )

        let remaining = Int(event.startDate.timeIntervalSinceNow)
        let initialState = DueCountdownAttributes.ContentState(
            remainingSeconds: max(0, remaining),
            isUrgent: remaining <= 600,
            isCritical: remaining <= 60,
            isCompleted: false,
            isOverdue: remaining <= 0
        )

        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            activeActivity = activity
            currentEventIdentifier = event.eventIdentifier

            // Schedule checkpoint updates
            updateTask?.cancel()
            updateTask = Task {
                await scheduleUpdates(activity: activity, dueDate: event.startDate)
            }
        } catch {
            debugPrint("Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update Scheduling

    private func scheduleUpdates(activity: Activity<DueCountdownAttributes>, dueDate: Date) async {
        // Key checkpoints: 10min, 5min, 1min, due, overdue
        let checkpoints: [(TimeInterval, Bool, Bool)] = [
            (600, true, false),    // 10 min - urgent
            (300, true, false),    // 5 min
            (60, true, true),      // 1 min - critical
            (0, true, true),       // due
        ]

        for (secondsBefore, isUrgent, isCritical) in checkpoints {
            let targetDate = dueDate.addingTimeInterval(-secondsBefore)
            guard targetDate > Date.now else { continue }

            let sleepDuration = targetDate.timeIntervalSinceNow
            guard sleepDuration > 0 else { continue }

            do {
                try await Task.sleep(for: .seconds(sleepDuration))
            } catch {
                return // Task cancelled
            }

            guard !Task.isCancelled else { return }

            let remaining = Int(dueDate.timeIntervalSinceNow)
            let state = DueCountdownAttributes.ContentState(
                remainingSeconds: max(0, remaining),
                isUrgent: isUrgent,
                isCritical: isCritical,
                isCompleted: false,
                isOverdue: remaining <= 0
            )
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }

        // Wait for overdue timeout
        let timeoutSeconds = Double(overdueTimeoutMinutes) * 60
        do {
            try await Task.sleep(for: .seconds(timeoutSeconds))
        } catch {
            return
        }

        guard !Task.isCancelled else { return }

        // Auto-end after timeout
        let finalState = DueCountdownAttributes.ContentState(
            remainingSeconds: 0,
            isUrgent: true,
            isCritical: true,
            isCompleted: false,
            isOverdue: true
        )
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .after(.now + 60)
        )
        await MainActor.run {
            activeActivity = nil
            currentEventIdentifier = nil
        }
    }

    // MARK: - Complete

    func completeCountdown() {
        guard let activity = activeActivity else { return }
        updateTask?.cancel()

        let completedState = DueCountdownAttributes.ContentState(
            remainingSeconds: 0,
            isUrgent: false,
            isCritical: false,
            isCompleted: true,
            isOverdue: false
        )

        Task {
            await activity.update(ActivityContent(state: completedState, staleDate: nil))
            try? await Task.sleep(for: .seconds(2))
            await activity.end(
                ActivityContent(state: completedState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            await MainActor.run {
                activeActivity = nil
                currentEventIdentifier = nil
            }
        }
    }

    // MARK: - End

    func endCountdown(completed: Bool, switchingToNext: Bool = false) {
        guard let activity = activeActivity else { return }
        updateTask?.cancel()

        let finalState = DueCountdownAttributes.ContentState(
            remainingSeconds: 0,
            isUrgent: false,
            isCritical: false,
            isCompleted: completed,
            isOverdue: !completed
        )

        Task {
            let dismissal: ActivityUIDismissalPolicy = switchingToNext ? .immediate : .after(.now + 60)
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: dismissal
            )
            await MainActor.run {
                activeActivity = nil
                currentEventIdentifier = nil
            }
        }
    }

    // MARK: - Auto Check (called by UrgencyEngine)

    func checkAndStartIfNeeded(deadlineEvents: [EKEvent], completedIds: Set<String>) {
        guard liveActivityEnabled else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()
        let leadSeconds = TimeInterval(liveActivityLeadMinutes * 60)

        // Find most urgent upcoming Due within lead time
        let candidates = deadlineEvents.filter { event in
            let remaining = event.startDate.timeIntervalSince(now)
            return remaining > -60  // not more than 1 min overdue
                && remaining < leadSeconds
                && !completedIds.contains(event.eventIdentifier)
        }

        guard let mostUrgent = candidates.min(by: { $0.startDate < $1.startDate }) else {
            return
        }

        // Don't restart if already tracking this event
        if currentEventIdentifier == mostUrgent.eventIdentifier { return }

        // Start countdown for the most urgent
        let emoji = "⚠️"
        startCountdown(for: mostUrgent, emoji: emoji)
    }
}
