import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    static let categoryIdentifier = "EVENT_REMINDER"
    static let actionOpen = "EVENT_ACTION_OPEN"
    static let actionSnooze = "EVENT_ACTION_SNOOZE"
    static let actionMarkSeen = "EVENT_ACTION_MARK_SEEN"

    private init() {}

    // MARK: - Category Registration

    /// Register interactive action buttons for the reminder category. Must
    /// be called once at launch, before any notification is scheduled.
    func registerCategories() {
        let open = UNNotificationAction(
            identifier: Self.actionOpen,
            title: L10n.notifActionOpen,
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: Self.actionSnooze,
            title: L10n.notifActionSnooze,
            options: []
        )
        let markSeen = UNNotificationAction(
            identifier: Self.actionMarkSeen,
            title: L10n.notifActionMarkSeen,
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [open, snooze, markSeen],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Request Permission

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    // MARK: - Snooze

    /// Re-schedule a reminder 24 hours from now. Used by the "Snooze" action
    /// button in local notifications.
    func snooze(eventID: UUID, eventTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = L10n.notificationTitle
        content.body = eventTitle
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = ["eventID": eventID.uuidString, "daysBefore": 0]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 24 * 60 * 60,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "\(eventID.uuidString)-snooze",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Schedule Notifications for Event

    func scheduleNotifications(for event: CountdownEvent) {
        let reminders = [1, 3, 7] // days before

        for daysBefore in reminders {
            let calendar = Calendar.current
            guard let triggerDate = calendar.date(byAdding: .day, value: -daysBefore, to: event.endDate) else {
                continue
            }

            // Skip if trigger date is in the past
            guard triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = L10n.notificationTitle
            content.body = L10n.notificationBody(title: event.title, days: daysBefore)
            content.sound = .default
            content.categoryIdentifier = "EVENT_REMINDER"
            content.userInfo = [
                "eventID": event.id.uuidString,
                "daysBefore": daysBefore
            ]

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let identifier = "\(event.id.uuidString)-\(daysBefore)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Remove Notifications for Event

    func removeNotifications(for eventId: UUID) {
        let identifiers = [1, 3, 7].map { "\(eventId.uuidString)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Remove All

    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
