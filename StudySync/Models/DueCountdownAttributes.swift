import ActivityKit
import Foundation

struct DueCountdownAttributes: ActivityAttributes {
    let eventTitle: String
    let emoji: String
    let dueDate: Date
    let calendarColorHex: String
    /// Lead-time window (minutes) the activity was started with — the user's
    /// 15/30/60 setting. The widget renders its progress bar against this.
    /// Optional so activities started by an older build (which didn't encode
    /// the field) still decode after an app update; the widget falls back
    /// to the legacy hardcoded 60.
    var leadMinutes: Int?

    struct ContentState: Codable, Hashable {
        let remainingSeconds: Int
        let isUrgent: Bool       // < 10 min
        let isCritical: Bool     // < 1 min
        let isCompleted: Bool
        let isOverdue: Bool
    }
}
