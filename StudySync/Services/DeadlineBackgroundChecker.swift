import SwiftUI
import SwiftData
import EventKit
import BackgroundTasks

/// Checks for upcoming Due events at app launch and via background refresh,
/// independent of which tab the user is viewing.
@Observable
final class DeadlineBackgroundChecker {
    static let shared = DeadlineBackgroundChecker()
    static let bgTaskIdentifier = "com.studysync.deadline-check"

    private var hasPerformedInitialCheck = false

    private init() {}

    // MARK: - App Launch Check

    /// Call this from StudySyncApp.onAppear or MainTabView.onAppear
    func performStartupCheck(modelContext: ModelContext) {
        guard !hasPerformedInitialCheck else { return }
        hasPerformedInitialCheck = true
        checkDeadlines(modelContext: modelContext)
        scheduleBackgroundRefresh()
    }

    // MARK: - Core Check Logic

    func checkDeadlines(modelContext: ModelContext) {
        let manager = CalendarManager.shared
        guard manager.authorizationStatus == .fullAccess else { return }

        // Fetch DeadlineRecords from SwiftData
        let descriptor = FetchDescriptor<DeadlineRecord>()
        guard let records = try? modelContext.fetch(descriptor) else { return }

        let deadlineIds = Set(records.map(\.eventIdentifier))
        let completedIds = Set(records.filter(\.isCompleted).map(\.eventIdentifier))

        // Find matching EKEvents
        let deadlineEvents = manager.events.filter { deadlineIds.contains($0.eventIdentifier) }

        // Update UrgencyEngine (handles lava effect + Live Activity auto-start)
        UrgencyEngine.shared.update(
            deadlineEvents: deadlineEvents,
            completedIds: completedIds
        )
    }

    // MARK: - Background App Refresh

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            self.handleBackgroundTask(refreshTask)
        }
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskIdentifier)
        // Request to run in 15 minutes (iOS decides actual timing)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            debugPrint("Background refresh scheduling failed: \(error)")
        }
    }

    private func handleBackgroundTask(_ task: BGAppRefreshTask) {
        // Schedule the next refresh
        scheduleBackgroundRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Create a temporary ModelContext for background work
        let container = SharedModelContainer.create()
        let context = ModelContext(container)

        let manager = CalendarManager.shared
        guard manager.authorizationStatus == .fullAccess else {
            task.setTaskCompleted(success: true)
            return
        }

        // Fetch records
        let descriptor = FetchDescriptor<DeadlineRecord>()
        guard let records = try? context.fetch(descriptor) else {
            task.setTaskCompleted(success: true)
            return
        }

        let deadlineIds = Set(records.map(\.eventIdentifier))
        let completedIds = Set(records.filter(\.isCompleted).map(\.eventIdentifier))
        let deadlineEvents = manager.events.filter { deadlineIds.contains($0.eventIdentifier) }

        // Check and start Live Activity if needed
        DispatchQueue.main.async {
            UrgencyEngine.shared.update(
                deadlineEvents: deadlineEvents,
                completedIds: completedIds
            )
        }

        task.setTaskCompleted(success: true)
    }
}
