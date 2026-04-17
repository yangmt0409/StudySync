import ActivityKit
import Foundation

struct DueCountdownAttributes: ActivityAttributes {
    let eventTitle: String
    let emoji: String
    let dueDate: Date
    let calendarColorHex: String

    struct ContentState: Codable, Hashable {
        let remainingSeconds: Int
        let isUrgent: Bool       // < 10 min
        let isCritical: Bool     // < 1 min
        let isCompleted: Bool
        let isOverdue: Bool
    }
}
