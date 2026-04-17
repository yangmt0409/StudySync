import Foundation
import EventKit
import SwiftUI

@Observable
final class CalendarManager {
    static let shared = CalendarManager()

    let eventStore = EKEventStore()
    var events: [EKEvent] = []
    var calendars: [EKCalendar] = []
    var authorizationStatus: EKAuthorizationStatus = .notDetermined
    var isLoading = false

    /// Whether the user has granted write access to calendars
    var hasWriteAccess: Bool {
        authorizationStatus == .fullAccess
    }

    private init() {
        updateAuthStatus()
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            self?.fetchUpcomingEvents()
        }
    }

    // MARK: - Authorization

    func updateAuthStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    @MainActor
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            updateAuthStatus()
            if granted {
                fetchUpcomingEvents()
            }
            return granted
        } catch {
            updateAuthStatus()
            return false
        }
    }

    // MARK: - Fetch Events

    func fetchUpcomingEvents() {
        let days = calendarDayRange
        fetchEvents(days: days)
    }

    func fetchEvents(days: Int) {
        guard authorizationStatus == .fullAccess else { return }
        isLoading = true

        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let endDate = calendar.date(byAdding: .day, value: days, to: startOfToday) else {
            isLoading = false
            return
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfToday,
            end: endDate,
            calendars: nil
        )

        let fetchedEvents = eventStore.events(matching: predicate)
        calendars = eventStore.calendars(for: .event)
        events = fetchedEvents.sorted { $0.startDate < $1.startDate }
        isLoading = false
    }

    // MARK: - Writable Calendars

    /// Returns only calendars that the user can write to
    var writableCalendars: [EKCalendar] {
        calendars.filter { $0.allowsContentModifications }
    }

    /// Returns the user's default calendar for new events
    var defaultCalendar: EKCalendar? {
        eventStore.defaultCalendarForNewEvents
    }

    /// Check if an event's calendar allows modifications
    func isEventEditable(_ event: EKEvent) -> Bool {
        event.calendar.allowsContentModifications
    }

    // MARK: - Create Event

    @discardableResult
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendar: EKCalendar,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        alarmOffsets: [TimeInterval] = [],
        recurrenceRule: EKRecurrenceRule? = nil
    ) throws -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        event.isAllDay = isAllDay

        if let location, !location.isEmpty {
            event.location = location
        }
        if let notes, !notes.isEmpty {
            event.notes = notes
        }
        for offset in alarmOffsets {
            event.addAlarm(EKAlarm(relativeOffset: -offset))
        }
        if let recurrenceRule {
            event.addRecurrenceRule(recurrenceRule)
        }

        try eventStore.save(event, span: .thisEvent)
        fetchUpcomingEvents()
        return event
    }

    // MARK: - Update Event

    func updateEvent(_ event: EKEvent, span: EKSpan = .thisEvent) throws {
        try eventStore.save(event, span: span)
        fetchUpcomingEvents()
    }

    // MARK: - Delete Event

    func deleteEvent(_ event: EKEvent, span: EKSpan = .thisEvent) throws {
        try eventStore.remove(event, span: span)
        fetchUpcomingEvents()
    }

    // MARK: - Duplicate Event

    @discardableResult
    func duplicateEvent(_ event: EKEvent, to newDate: Date? = nil) throws -> EKEvent {
        let newEvent = EKEvent(eventStore: eventStore)
        newEvent.title = event.title
        newEvent.calendar = event.calendar
        newEvent.isAllDay = event.isAllDay
        newEvent.location = event.location
        newEvent.notes = event.notes

        if let newDate {
            let duration = event.endDate.timeIntervalSince(event.startDate)
            newEvent.startDate = newDate
            newEvent.endDate = newDate.addingTimeInterval(duration)
        } else {
            newEvent.startDate = event.startDate
            newEvent.endDate = event.endDate
        }

        // Copy alarms
        if let alarms = event.alarms {
            for alarm in alarms {
                newEvent.addAlarm(EKAlarm(relativeOffset: alarm.relativeOffset))
            }
        }

        try eventStore.save(newEvent, span: .thisEvent)
        fetchUpcomingEvents()
        return newEvent
    }

    // MARK: - Settings

    var calendarDayRange: Int {
        get {
            let val = SyncedDefaults.shared.integer(forKey: "calendarDayRange")
            if val < 3 || val > 30 { return 3 }
            return val
        }
        set { SyncedDefaults.shared.set(newValue, forKey: "calendarDayRange") }
    }

    var showFinishedEvents: Bool {
        get { SyncedDefaults.shared.object(forKey: "showFinishedCalEvents") as? Bool ?? false }
        set { SyncedDefaults.shared.set(newValue, forKey: "showFinishedCalEvents") }
    }

    var showAllDayEvents: Bool {
        get { SyncedDefaults.shared.object(forKey: "showAllDayCalEvents") as? Bool ?? true }
        set { SyncedDefaults.shared.set(newValue, forKey: "showAllDayCalEvents") }
    }

    var hiddenCalendarIDs: Set<String> {
        get {
            let arr = SyncedDefaults.shared.stringArray(forKey: "hiddenCalendarIDs") ?? []
            return Set(arr)
        }
        set {
            SyncedDefaults.shared.set(Array(newValue), forKey: "hiddenCalendarIDs")
        }
    }

    // MARK: - Filtered & Grouped

    func filteredEvents(for date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        return events.filter { event in
            // Calendar filter
            if hiddenCalendarIDs.contains(event.calendar.calendarIdentifier) { return false }

            // All-day filter
            if event.isAllDay && !showAllDayEvents { return false }

            // Finished filter
            if !showFinishedEvents && event.endDate < Date() && !event.isAllDay { return false }

            // Date filter: event overlaps with this day
            return event.startDate < end && event.endDate > start
        }
    }

    func groupedByDay() -> [(title: String, date: Date, events: [EKEvent])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = calendarDayRange

        var groups: [(title: String, date: Date, events: [EKEvent])] = []

        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }

            let dayLabel: String
            switch offset {
            case 0: dayLabel = L10n.today
            case 1: dayLabel = L10n.tomorrow
            case 2: dayLabel = L10n.dayAfterTomorrow
            default: dayLabel = date.formattedDate(in: .current)
            }

            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("MMMd EEEE")
            formatter.locale = Locale.current
            let dateStr = formatter.string(from: date)
            let title = offset <= 2 ? "\(dayLabel) · \(dateStr)" : dateStr

            let dayEvents = filteredEvents(for: date).sorted { lhs, rhs in
                // All-day events first
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.startDate < rhs.startDate
            }

            groups.append((title: title, date: date, events: dayEvents))
        }

        return groups
    }
}
