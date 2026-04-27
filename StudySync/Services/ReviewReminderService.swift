import UserNotifications

enum ReviewReminderService {
    /// Schedule review reminders for an exam. Reminders at:
    /// 7 days, 3 days, 1 day before the exam date.
    static func scheduleReminders(for event: CountdownEvent) {
        guard event.isExam, event.reviewRemindersEnabled else { return }
        let center = UNUserNotificationCenter.current()

        // Remove old reminders for this event
        let prefix = "review_\(event.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [
            "\(prefix)_7d", "\(prefix)_3d", "\(prefix)_1d"
        ])

        let label = "\(event.emoji) \(event.title)"
        let intervals: [(days: Int, id: String, body: String)] = [
            (7, "\(prefix)_7d", String(localized: "\(label) 还有 7 天，开始复习吧！")),
            (3, "\(prefix)_3d", String(localized: "\(label) 还有 3 天，加紧复习！")),
            (1, "\(prefix)_1d", String(localized: "\(label) 明天就考试了，最后冲刺！")),
        ]

        let calendar = Calendar.current
        for interval in intervals {
            guard let reminderDate = calendar.date(byAdding: .day, value: -interval.days, to: event.endDate),
                  reminderDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "复习提醒 📖")
            content.body = interval.body
            content.sound = .default

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: reminderDate)
            dateComponents.hour = 9  // remind at 9 AM

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: interval.id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    /// Cancel all review reminders for an event.
    static func cancelReminders(for eventId: UUID) {
        let prefix = "review_\(eventId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "\(prefix)_7d", "\(prefix)_3d", "\(prefix)_1d"
        ])
    }
}
