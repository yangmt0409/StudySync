import Foundation
import SwiftData
import SwiftUI

// MARK: - Value Types for Widget

struct WidgetEventData: Identifiable {
    let id: UUID
    let title: String
    let emoji: String
    let daysRemaining: Int
    let totalDays: Int
    let progress: Double
    let colorHex: String
    let categoryName: String
    let isPinned: Bool
    let isExpired: Bool
    let endDate: Date
    let backgroundImageData: Data?
    let dotColorHex: String
    let textColorHex: String
    let fontName: String
    let primaryCount: Int
    let unitLabel: String
    let showPercentage: Bool
    let notStarted: Bool

    static let placeholder = WidgetEventData(
        id: UUID(),
        title: "期末考试周",
        emoji: "📝",
        daysRemaining: 45,
        totalDays: 120,
        progress: 0.63,
        colorHex: "#5B7FFF",
        categoryName: "学业",
        isPinned: false,
        isExpired: false,
        endDate: Calendar.current.date(byAdding: .day, value: 45, to: Date())!,
        backgroundImageData: nil,
        dotColorHex: "#FFFFFF",
        textColorHex: "#FFFFFF",
        fontName: "default",
        primaryCount: 45,
        unitLabel: "天",
        showPercentage: false,
        notStarted: false
    )

    static let sampleEvents: [WidgetEventData] = [
        WidgetEventData(
            id: UUID(), title: "期末考试周", emoji: "📝",
            daysRemaining: 45, totalDays: 120, progress: 0.63,
            colorHex: "#5B7FFF", categoryName: "学业",
            isPinned: false, isExpired: false,
            endDate: Calendar.current.date(byAdding: .day, value: 45, to: Date())!,
            backgroundImageData: nil,
            dotColorHex: "#FFFFFF",
            textColorHex: "#FFFFFF",
            fontName: "default",
            primaryCount: 45, unitLabel: "天",
            showPercentage: false, notStarted: false
        ),
        WidgetEventData(
            id: UUID(), title: "Study Permit 到期", emoji: "📋",
            daysRemaining: 180, totalDays: 300, progress: 0.40,
            colorHex: "#FF6B6B", categoryName: "签证",
            isPinned: false, isExpired: false,
            endDate: Calendar.current.date(byAdding: .day, value: 180, to: Date())!,
            backgroundImageData: nil,
            dotColorHex: "#FFFFFF",
            textColorHex: "#FFFFFF",
            fontName: "default",
            primaryCount: 180, unitLabel: "天",
            showPercentage: false, notStarted: false
        ),
        WidgetEventData(
            id: UUID(), title: "暑假回国", emoji: "✈️",
            daysRemaining: 90, totalDays: 90, progress: 0.0,
            colorHex: "#4ECDC4", categoryName: "旅行",
            isPinned: false, isExpired: false,
            endDate: Calendar.current.date(byAdding: .day, value: 90, to: Date())!,
            backgroundImageData: nil,
            dotColorHex: "#FFFFFF",
            textColorHex: "#FFFFFF",
            fontName: "default",
            primaryCount: 90, unitLabel: "天",
            showPercentage: false, notStarted: false
        ),
        WidgetEventData(
            id: UUID(), title: "租房合同到期", emoji: "🏠",
            daysRemaining: 120, totalDays: 180, progress: 0.33,
            colorHex: "#FFB347", categoryName: "生活",
            isPinned: false, isExpired: false,
            endDate: Calendar.current.date(byAdding: .day, value: 120, to: Date())!,
            backgroundImageData: nil,
            dotColorHex: "#FFFFFF",
            textColorHex: "#FFFFFF",
            fontName: "default",
            primaryCount: 120, unitLabel: "天",
            showPercentage: false, notStarted: false
        ),
    ]
}

struct WidgetSettingsData {
    let homeTimeZoneId: String
    let studyTimeZoneId: String
    let homeCityName: String
    let studyCityName: String

    var homeTimeZone: TimeZone {
        TimeZone(identifier: homeTimeZoneId) ?? TimeZone(identifier: "Asia/Shanghai")!
    }

    var studyTimeZone: TimeZone {
        TimeZone(identifier: studyTimeZoneId) ?? TimeZone(identifier: "America/Toronto")!
    }

    static let `default` = WidgetSettingsData(
        homeTimeZoneId: "Asia/Shanghai",
        studyTimeZoneId: "America/Toronto",
        homeCityName: "上海",
        studyCityName: "多伦多"
    )
}

// MARK: - Data Provider

struct WidgetDataProvider {

    static func fetchEvents(limit: Int? = nil) -> [WidgetEventData] {
        let container = SharedModelContainer.create()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<CountdownEvent>(
            sortBy: [SortDescriptor(\.endDate, order: .forward)]
        )

        do {
            let events = try context.fetch(descriptor)

            var result = events
                .filter { !$0.isExpired }
                .sorted { lhs, rhs in
                    if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                    return lhs.daysRemaining < rhs.daysRemaining
                }
                .map { event in
                    WidgetEventData(
                        id: event.id,
                        title: event.title,
                        emoji: event.emoji,
                        daysRemaining: event.daysRemaining,
                        totalDays: event.totalDays,
                        progress: event.progress,
                        colorHex: event.colorHex,
                        categoryName: event.category.rawValue,
                        isPinned: event.isPinned,
                        isExpired: event.isExpired,
                        endDate: event.endDate,
                        backgroundImageData: event.backgroundImageData,
                        dotColorHex: event.dotColorHex,
                        textColorHex: event.textColorHex,
                        fontName: event.fontName,
                        primaryCount: event.primaryCount,
                        unitLabel: event.unitLabel,
                        showPercentage: event.showPercentage,
                        notStarted: event.notStarted
                    )
                }

            if let limit {
                result = Array(result.prefix(limit))
            }

            return result
        } catch {
            return []
        }
    }

    static func fetchSettings() -> WidgetSettingsData {
        let container = SharedModelContainer.create()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<UserSettings>()

        do {
            let settings = try context.fetch(descriptor)
            if let first = settings.first {
                return WidgetSettingsData(
                    homeTimeZoneId: first.homeTimeZoneId,
                    studyTimeZoneId: first.studyTimeZoneId,
                    homeCityName: first.homeCityName,
                    studyCityName: first.studyCityName
                )
            }
        } catch {}

        return .default
    }

    static func nearestEvent() -> WidgetEventData? {
        fetchEvents(limit: 1).first
    }
}
