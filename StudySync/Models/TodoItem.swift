import Foundation
import SwiftData

@Model
final class TodoItem {
    var id: UUID = UUID()
    var title: String = ""
    var note: String = ""
    var emoji: String = "📌"
    var isCompleted: Bool = false
    var completedAt: Date?
    var priorityRaw: String = "medium"
    var dueDate: Date?
    var createdAt: Date = Date()

    init(title: String = "", note: String = "", emoji: String = "📌",
         isCompleted: Bool = false, completedAt: Date? = nil,
         priorityRaw: String = "medium", dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.emoji = emoji
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.priorityRaw = priorityRaw
        self.dueDate = dueDate
        self.createdAt = Date()
    }

    // MARK: - Computed

    var priority: TodoPriority {
        get { TodoPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard let dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }

    var daysRemaining: Int? {
        guard let dueDate, !isCompleted else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                               to: Calendar.current.startOfDay(for: dueDate)).day
    }
}

// MARK: - Priority

enum TodoPriority: String, CaseIterable, Identifiable {
    case low, medium, high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low:    return L10n.projectPriorityLow
        case .medium: return L10n.projectPriorityMedium
        case .high:   return L10n.projectPriorityHigh
        }
    }

    var colorHex: String {
        switch self {
        case .low:    return "#4ECDC4"
        case .medium: return "#FFB347"
        case .high:   return "#FF6B6B"
        }
    }

    var icon: String {
        switch self {
        case .low:    return "arrow.down"
        case .medium: return "minus"
        case .high:   return "arrow.up"
        }
    }

    var sortOrder: Int {
        switch self {
        case .high:   return 0
        case .medium: return 1
        case .low:    return 2
        }
    }
}
