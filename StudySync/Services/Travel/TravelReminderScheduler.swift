import Foundation
import UserNotifications

/// Schedule local notifications for travel events based on their preset.
///
/// Design:
///   - Reminders are identified by `"travel_<uuid>_<offsetSeconds>"` so we
///     can cancel + re-schedule on changes.
///   - All reminders are scheduled against the real departure instant
///     (UTC), NOT the wall-clock stored on the model — this way crossing
///     timezones doesn't double-fire or skip reminders.
///   - The scheduler runs idempotently; re-scheduling an event will replace
///     its existing reminders.
///
/// `@MainActor` because `TravelEvent` is a SwiftData `@Model` that requires
/// main-actor access. The heavy work here is async UN* calls which release
/// the actor while waiting, so running on main is fine performance-wise.
@MainActor
final class TravelReminderScheduler {
    static let shared = TravelReminderScheduler()

    func scheduleReminders(for event: TravelEvent) async {
        await cancelReminders(for: event.id)
        guard event.reminderEnabled,
              event.reminderPreset != .none,
              event.isUpcoming else { return }

        let center = UNUserNotificationCenter.current()
        let preset = event.reminderPreset
        let offsets = preset.offsetsSeconds
        let labels = preset.reminderLabels()
        let departure = event.departureInstant

        for (idx, offset) in offsets.enumerated() {
            let fireDate = departure.addingTimeInterval(-TimeInterval(offset))
            if fireDate <= Date() { continue }  // in the past — skip

            let content = UNMutableNotificationContent()
            content.title = "\(event.emoji) \(event.fullNumber)"
            let label = idx < labels.count ? labels[idx] : ""
            content.body = label.isEmpty
                ? String(localized: "即将出发")
                : label
            content.sound = .default
            content.userInfo = [
                "travelEventID": event.id.uuidString,
                "offsetSeconds": offset,
            ]

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: fireDate.timeIntervalSinceNow,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: reminderIdentifier(for: event.id, offset: offset),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelReminders(for eventID: UUID) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let toCancel = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("travel_\(eventID.uuidString)_") }
        center.removePendingNotificationRequests(withIdentifiers: toCancel)
    }

    private func reminderIdentifier(for id: UUID, offset: Int) -> String {
        "travel_\(id.uuidString)_\(offset)"
    }
}
