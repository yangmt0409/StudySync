import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - App Intent: Select Event

struct SelectEventIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择事件"
    static var description = IntentDescription("选择要在小组件上显示的事件")

    @Parameter(title: "事件")
    var selectedEvent: EventEntity?
}

// MARK: - Event Entity

struct EventEntity: AppEntity {
    var id: String
    var title: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "事件")
    static var defaultQuery = EventEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct EventEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [EventEntity] {
        let allEvents = WidgetDataProvider.fetchEvents()
        return allEvents
            .filter { identifiers.contains($0.id.uuidString) }
            .map { EventEntity(id: $0.id.uuidString, title: $0.title) }
    }

    func suggestedEntities() async throws -> [EventEntity] {
        WidgetDataProvider.fetchEvents()
            .map { EventEntity(id: $0.id.uuidString, title: $0.title) }
    }

    func defaultResult() async -> EventEntity? {
        guard let first = WidgetDataProvider.fetchEvents().first else { return nil }
        return EventEntity(id: first.id.uuidString, title: first.title)
    }
}

// MARK: - Timeline Entry

struct StudySyncEntry: TimelineEntry {
    let date: Date
    let events: [WidgetEventData]
    let nearestEvent: WidgetEventData?
    let selectedEvent: WidgetEventData?
    let settings: WidgetSettingsData

    static let placeholder = StudySyncEntry(
        date: Date(),
        events: WidgetEventData.sampleEvents,
        nearestEvent: .placeholder,
        selectedEvent: .placeholder,
        settings: .default
    )
}

// MARK: - Configurable Timeline Provider

struct StudySyncConfigurableProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StudySyncEntry {
        .placeholder
    }

    func snapshot(for configuration: SelectEventIntent, in context: Context) async -> StudySyncEntry {
        if context.isPreview { return .placeholder }
        return createEntry(for: Date(), configuration: configuration)
    }

    func timeline(for configuration: SelectEventIntent, in context: Context) async -> Timeline<StudySyncEntry> {
        let now = Date()
        var entries: [StudySyncEntry] = []

        for minuteOffset in stride(from: 0, through: 45, by: 15) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now)!
            entries.append(createEntry(for: entryDate, configuration: configuration))
        }

        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        return Timeline(entries: entries, policy: .after(nextRefresh))
    }

    private func createEntry(for date: Date, configuration: SelectEventIntent) -> StudySyncEntry {
        let events = WidgetDataProvider.fetchEvents(limit: 4)
        let settings = WidgetDataProvider.fetchSettings()

        // 如果用户选择了特定事件，找到它
        let selected: WidgetEventData?
        if let selectedId = configuration.selectedEvent?.id {
            selected = WidgetDataProvider.fetchEvents().first { $0.id.uuidString == selectedId }
        } else {
            selected = events.first
        }

        return StudySyncEntry(
            date: date,
            events: events,
            nearestEvent: events.first,
            selectedEvent: selected,
            settings: settings
        )
    }
}

// MARK: - Static Provider (for non-configurable widgets)

struct StudySyncStaticProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudySyncEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (StudySyncEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        completion(createEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudySyncEntry>) -> Void) {
        let now = Date()
        var entries: [StudySyncEntry] = []
        for minuteOffset in stride(from: 0, through: 45, by: 15) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now)!
            entries.append(createEntry(for: entryDate))
        }
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }

    private func createEntry(for date: Date) -> StudySyncEntry {
        let events = WidgetDataProvider.fetchEvents(limit: 4)
        let settings = WidgetDataProvider.fetchSettings()
        return StudySyncEntry(
            date: date, events: events, nearestEvent: events.first,
            selectedEvent: events.first, settings: settings
        )
    }
}

// MARK: - Widget Entry View

struct StudySyncWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: StudySyncEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularWidgetView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularWidgetView(entry: entry)
        case .accessoryInline:
            AccessoryInlineWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Lock Screen / Accessory Widgets

struct AccessoryCircularWidgetView: View {
    var entry: StudySyncEntry
    private var event: WidgetEventData? { entry.selectedEvent ?? entry.nearestEvent }

    var body: some View {
        ZStack {
            if let event = event {
                AccessoryWidgetBackground()
                Gauge(value: min(max(event.progress, 0), 1)) {
                    Text(event.emoji)
                        .font(.system(size: 10))
                } currentValueLabel: {
                    Text("\(event.daysRemaining)")
                        .font(.system(size: 16, weight: .bold))
                        .minimumScaleFactor(0.5)
                }
                .gaugeStyle(.accessoryCircular)
            } else {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct AccessoryRectangularWidgetView: View {
    var entry: StudySyncEntry
    private var event: WidgetEventData? { entry.selectedEvent ?? entry.nearestEvent }

    var body: some View {
        HStack(spacing: 6) {
            if let event = event {
                Text(event.emoji)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text("\(event.daysRemaining) \(event.unitLabel)")
                        .font(.system(size: 11, weight: .bold))
                        .widgetAccentable()
                    ProgressView(value: min(max(event.progress, 0), 1))
                        .progressViewStyle(.linear)
                        .tint(.primary)
                }
            } else {
                Image(systemName: "calendar.badge.clock")
                Text("留时")
                    .font(.system(size: 12, weight: .semibold))
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct AccessoryInlineWidgetView: View {
    var entry: StudySyncEntry
    private var event: WidgetEventData? { entry.selectedEvent ?? entry.nearestEvent }

    var body: some View {
        if let event = event {
            Text("\(event.emoji) \(event.title) · \(event.daysRemaining)\(event.unitLabel)")
                .containerBackground(.clear, for: .widget)
        } else {
            Text("留时 · 暂无事件")
                .containerBackground(.clear, for: .widget)
        }
    }
}

// MARK: - Main Widget (configurable)

struct StudySyncWidget: Widget {
    let kind = "StudySyncWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectEventIntent.self, provider: StudySyncConfigurableProvider()) { entry in
            StudySyncWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("留时")
        .description("追踪你的重要日期倒计时")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

// MARK: - Dot Grid Widget (configurable)

struct StudySyncDotGridWidget: Widget {
    let kind = "StudySyncDotGridWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectEventIntent.self, provider: StudySyncConfigurableProvider()) { entry in
            MediumDotGridWidgetView(entry: entry)
        }
        .configurationDisplayName("留时 - 点阵")
        .description("点阵进度可视化倒计时")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct StudySyncWidgetBundle: WidgetBundle {
    var body: some Widget {
        StudySyncWidget()
        StudySyncDotGridWidget()
        DueCountdownLiveActivity()
        MeetupLiveActivity()
    }
}

#Preview("Small", as: .systemSmall) {
    StudySyncWidget()
} timeline: {
    StudySyncEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    StudySyncWidget()
} timeline: {
    StudySyncEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    StudySyncWidget()
} timeline: {
    StudySyncEntry.placeholder
}
