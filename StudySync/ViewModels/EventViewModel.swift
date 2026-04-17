import Foundation
import SwiftData
import SwiftUI

@Observable
final class EventViewModel {
    var searchText: String = ""
    var selectedCategory: EventCategory?
    var showingAddEvent = false
    var showingPaywall = false
    var eventToEdit: CountdownEvent?
    var collapsedCategories: Set<EventCategory> = []

    static let freeEventLimit = 5

    /// 检查是否可以添加新事件（免费版限制 5 个）
    func canAddEvent(currentCount: Int) -> Bool {
        StoreManager.shared.isPro || currentCount < Self.freeEventLimit
    }

    /// 尝试添加事件，如果受限则弹出 Paywall
    func tryAddEvent(currentCount: Int) {
        if canAddEvent(currentCount: currentCount) {
            showingAddEvent = true
        } else {
            showingPaywall = true
        }
    }

    func toggleSection(_ category: EventCategory) {
        if collapsedCategories.contains(category) {
            collapsedCategories.remove(category)
        } else {
            collapsedCategories.insert(category)
        }
    }

    func isSectionCollapsed(_ category: EventCategory) -> Bool {
        collapsedCategories.contains(category)
    }

    func filteredEvents(_ events: [CountdownEvent], showExpired: Bool) -> [CountdownEvent] {
        var result = events

        if !showExpired {
            result = result.filter { !$0.isExpired }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    /// 按分类分组，置顶优先，剩余天数升序
    func groupedEvents(_ events: [CountdownEvent], showExpired: Bool) -> [(EventCategory, [CountdownEvent])] {
        let filtered = filteredEvents(events, showExpired: showExpired)

        var grouped: [EventCategory: [CountdownEvent]] = [:]
        for event in filtered {
            grouped[event.category, default: []].append(event)
        }

        // 每组内排序
        for key in grouped.keys {
            grouped[key]?.sort { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.daysRemaining < rhs.daysRemaining
            }
        }

        // 按 EventCategory.allCases 顺序返回
        return EventCategory.allCases.compactMap { category in
            guard let events = grouped[category], !events.isEmpty else { return nil }
            return (category, events)
        }
    }

    func addSampleEvents(context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()

        let events: [(String, String, Date, Date, EventCategory, String)] = [
            (
                "期末考试周",
                "📝",
                now,
                calendar.date(byAdding: .day, value: 45, to: now) ?? now,
                .academic,
                "#5B7FFF"
            ),
            (
                "Study Permit 到期",
                "📋",
                calendar.date(byAdding: .day, value: -120, to: now) ?? now,
                calendar.date(byAdding: .day, value: 180, to: now) ?? now,
                .visa,
                "#FF6B6B"
            ),
            (
                "暑假回国",
                "✈️",
                now,
                calendar.date(byAdding: .day, value: 90, to: now) ?? now,
                .travel,
                "#4ECDC4"
            ),
            (
                "租房合同到期",
                "🏠",
                calendar.date(byAdding: .day, value: -60, to: now) ?? now,
                calendar.date(byAdding: .day, value: 120, to: now) ?? now,
                .life,
                "#FFB347"
            ),
        ]

        for (title, emoji, start, end, category, color) in events {
            let event = CountdownEvent(
                title: title,
                emoji: emoji,
                startDate: start,
                endDate: end,
                category: category,
                colorHex: color
            )
            context.insert(event)
        }
    }
}
