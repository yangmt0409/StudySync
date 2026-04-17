import Foundation
import SwiftData

@Model
final class CountdownEvent {
    var id: UUID = UUID()
    var title: String = ""
    var emoji: String = "📌"
    var startDate: Date = Date()
    var endDate: Date = Date()
    var categoryRaw: String = "life"
    var colorHex: String = "#5B7FFF"
    var isPinned: Bool = false
    var notifyEnabled: Bool = false
    var createdAt: Date = Date()

    // New: theme & display
    var dotShapeRaw: String = "circle"
    var timeUnitRaw: String = "day"
    var themeStyleRaw: String = "grid"
    var showAsCountUp: Bool = false
    var showPercentage: Bool = false
    @Attribute(.externalStorage) var backgroundImageData: Data?
    var note: String = ""
    var dotColorHex: String = "#FFFFFF"
    var textColorHex: String = "#FFFFFF"
    var fontName: String = "default"

    // MARK: - Computed Properties

    var category: EventCategory {
        get { EventCategory(rawValue: categoryRaw) ?? .life }
        set { categoryRaw = newValue.rawValue }
    }

    var dotShape: DotShape {
        get { DotShape(rawValue: dotShapeRaw) ?? .circle }
        set { dotShapeRaw = newValue.rawValue }
    }

    var timeUnit: TimeUnit {
        get { TimeUnit(rawValue: timeUnitRaw) ?? .day }
        set { timeUnitRaw = newValue.rawValue }
    }

    var themeStyle: ThemeStyle {
        get { ThemeStyle(rawValue: themeStyleRaw) ?? .grid }
        set { themeStyleRaw = newValue.rawValue }
    }

    var daysRemaining: Int {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: endDate)
        return max(calendar.dateComponents([.day], from: now, to: end).day ?? 0, 0)
    }

    /// `true` when the event's start date is still in the future (i.e. it
    /// hasn't kicked off yet). Used to show a "waiting to start" badge.
    var notStarted: Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: Date()) < calendar.startOfDay(for: startDate)
    }

    /// Whole-day gap between today and the start date (0 if already started).
    var daysUntilStart: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: startDate)
        return max(calendar.dateComponents([.day], from: today, to: start).day ?? 0, 0)
    }

    /// Remaining count expressed in the user-selected `timeUnit`.
    /// Returns 0 once the end date has passed.
    var remainingInUnit: Int {
        let calendar = Calendar.current
        let now = Date()
        guard now < endDate else { return 0 }
        switch timeUnit {
        case .day:
            let from = calendar.startOfDay(for: now)
            let to = calendar.startOfDay(for: endDate)
            return max(calendar.dateComponents([.day], from: from, to: to).day ?? 0, 0)
        case .week:
            return max(calendar.dateComponents([.weekOfYear], from: now, to: endDate).weekOfYear ?? 0, 0)
        case .month:
            return max(calendar.dateComponents([.month], from: now, to: endDate).month ?? 0, 0)
        }
    }

    /// Elapsed count since `startDate` expressed in the user-selected `timeUnit`.
    var elapsedInUnit: Int {
        timeUnit.elapsedCount(from: startDate)
    }

    /// Primary count to display on cards / widgets — respects count-up vs
    /// count-down and the user-selected time unit.
    var primaryCount: Int {
        showAsCountUp ? elapsedInUnit : remainingInUnit
    }

    /// Localized unit label matching `timeUnit` (e.g. "天" / "周" / "月").
    var unitLabel: String {
        timeUnit.displayName
    }

    var daysElapsed: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let now = calendar.startOfDay(for: Date())
        return max(calendar.dateComponents([.day], from: start, to: now).day ?? 0, 0)
    }

    var totalDays: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return max(calendar.dateComponents([.day], from: start, to: end).day ?? 1, 1)
    }

    var progress: Double {
        let elapsed = totalDays - daysRemaining
        guard totalDays > 0 else { return 1.0 }
        return min(max(Double(elapsed) / Double(totalDays), 0.0), 1.0)
    }

    var isExpired: Bool {
        Date() > endDate
    }

    /// Display text based on count up/down, percentage mode, and time unit.
    var displayText: String {
        if showPercentage {
            return "\(Int(progress * 100))%"
        }
        return "\(primaryCount) \(unitLabel)"
    }

    // MARK: - Init

    init(
        title: String,
        emoji: String = "📌",
        startDate: Date = Date(),
        endDate: Date,
        category: EventCategory = .life,
        colorHex: String = "#5B7FFF",
        isPinned: Bool = false,
        notifyEnabled: Bool = false,
        dotShape: DotShape = .circle,
        timeUnit: TimeUnit = .day,
        themeStyle: ThemeStyle = .grid,
        showAsCountUp: Bool = false,
        showPercentage: Bool = false,
        note: String = "",
        dotColorHex: String = "#FFFFFF",
        textColorHex: String = "#FFFFFF",
        fontName: String = "default"
    ) {
        self.id = UUID()
        self.title = title
        self.emoji = emoji
        self.startDate = startDate
        self.endDate = endDate
        self.categoryRaw = category.rawValue
        self.colorHex = colorHex
        self.isPinned = isPinned
        self.notifyEnabled = notifyEnabled
        self.createdAt = Date()
        self.dotShapeRaw = dotShape.rawValue
        self.timeUnitRaw = timeUnit.rawValue
        self.themeStyleRaw = themeStyle.rawValue
        self.showAsCountUp = showAsCountUp
        self.showPercentage = showPercentage
        self.backgroundImageData = nil
        self.note = note
        self.dotColorHex = dotColorHex
        self.textColorHex = textColorHex
        self.fontName = fontName
    }
}
