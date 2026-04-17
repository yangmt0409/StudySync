import Foundation
import SwiftData

@Model
final class FocusSession {
    var id: UUID = UUID()
    var durationMinutes: Int = 25
    var actualSeconds: Int = 0
    /// Seconds the app was in the foreground during this session.
    /// Used for the focus challenge (foreground-only requirement).
    var foregroundSeconds: Int = 0
    var emoji: String = "📚"
    var label: String = ""
    var isCompleted: Bool = false
    var startedAt: Date = Date()
    var endedAt: Date?

    init(durationMinutes: Int = 25, emoji: String = "📚", label: String = "") {
        self.id = UUID()
        self.durationMinutes = durationMinutes
        self.emoji = emoji
        self.label = label
        self.startedAt = Date()
    }

    // MARK: - Computed

    var actualMinutes: Int { actualSeconds / 60 }

    /// Foreground-only minutes. Falls back to actualMinutes for sessions
    /// created before foreground tracking was added.
    var foregroundMinutes: Int {
        foregroundSeconds > 0 ? foregroundSeconds / 60 : actualMinutes
    }

    var formattedDuration: String {
        let mins = actualSeconds / 60
        let hrs = mins / 60
        if hrs > 0 {
            return "\(hrs)h \(mins % 60)m"
        }
        return "\(mins)m"
    }

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startedAt)
    }

    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startedAt)
    }
}
