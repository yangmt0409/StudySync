import Foundation
@preconcurrency import EventKit

/// Scan the user's Apple Calendar for events that look like travel bookings
/// and convert them into `TravelEvent` drafts.
///
/// Heuristics (in order of specificity):
///   1. Event title matches IATA flight pattern `[A-Z]{2,3}\d{1,4}`
///      OR China rail prefix `G\d{1,5}` / `D\d{1,5}` / `C\d{1,5}`
///   2. Event has two distinct location-like fields (location + notes
///      mentioning "to" / "→" / "–" / "从 ... 到 ...")
///   3. Event has `EventKit` structured location with `title` containing
///      airport or station keywords ("Airport", "机场", "Station", "站")
///
/// We look 90 days into the future for candidates, de-dupe against existing
/// TravelEvents by flight number + date.
/// `@MainActor` because `EKCalendar` is a reference type that must be accessed
/// on the main actor (it's not `Sendable`). This struct is only consumed by
/// `CalendarTravelImporter` which is already `@MainActor`, so staying on main
/// costs nothing.
@MainActor
struct CalendarScanInput {
    /// Window in days: how far ahead to look.
    var forwardDays: Int = 90
    /// Calendars to scan (nil = all).
    var calendars: [EKCalendar]? = nil
}

@MainActor
struct CalendarTravelImporter {
    let source: TravelImportSource = .calendar
    let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    /// Find candidate travel events in the user's calendar (default settings).
    func findCandidates() async throws -> [EKEvent] {
        try await findCandidates(CalendarScanInput())
    }

    /// Find candidate travel events with explicit scan parameters.
    /// Caller decides which to import (via a picker UI).
    func findCandidates(_ input: CalendarScanInput) async throws -> [EKEvent] {
        try await requestAccessIfNeeded()
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: input.forwardDays, to: start) ?? start

        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: input.calendars
        )
        let all = eventStore.events(matching: predicate)
        return all.filter { Self.looksLikeTravel($0) }
    }

    /// Convert a single EKEvent that the user selected into a TravelEvent draft.
    func makeDraft(from event: EKEvent) async throws -> TravelEvent {
        let title = event.title ?? ""
        let (carrierCode, number, kind) = Self.extractDesignator(from: title)

        let locationTimezone = TimeZone.current
        let depZone = event.timeZone ?? locationTimezone
        let arrZone = depZone  // EKEvent doesn't give us a distinct arrival zone
        let depLocal = toLocalWallClock(event.startDate, zone: depZone)
        let arrLocal = toLocalWallClock(event.endDate, zone: arrZone)

        // Parse route from location field: "PEK → YYZ" / "Beijing to Toronto"
        let (depCity, arrCity) = Self.parseRoute(from: event.location ?? "")

        let e = TravelEvent(
            kind: kind ?? .flight,
            carrierCode: carrierCode,
            number: number,
            departureCity: depCity,
            departureStation: event.location ?? depCity,
            arrivalCity: arrCity,
            arrivalStation: arrCity,
            departureTimeLocal: depLocal,
            arrivalTimeLocal: arrLocal,
            importSource: .calendar
        )
        e.departureTimeZoneID = depZone.identifier
        e.arrivalTimeZoneID = arrZone.identifier
        e.note = event.notes ?? ""
        e.reminderPreset = TravelReminderPreset.defaultPreset(for: e.kind, isInternational: e.isInternational)
        return e
    }

    // MARK: - Heuristics

    /// Core match: does this look like a travel booking?
    static func looksLikeTravel(_ event: EKEvent) -> Bool {
        let title = (event.title ?? "").uppercased()
        if hasDesignator(in: title) { return true }

        let blob = [
            event.location ?? "",
            event.notes ?? "",
            event.url?.absoluteString ?? ""
        ].joined(separator: " ").lowercased()

        let keywords = [
            "airport", "flight", "boarding", "terminal", "airlines",
            "机场", "航班", "登机", "登机口", "航空",
            "station", "train", "platform", "高铁", "动车", "车站", "站台",
            "ferry", "harbor", "port", "港口", "码头",
        ]
        return keywords.contains { blob.contains($0) }
    }

    static func hasDesignator(in text: String) -> Bool {
        let patterns = [
            #"\b[A-Z]{2,3}\d{1,4}[A-Z]?\b"#,   // flight
            #"\b[GDC]\d{1,5}\b"#,              // HSR
            #"\b[KTZYL]\d{1,5}\b"#,            // conventional train
        ]
        return patterns.contains { pattern in
            text.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// Returns (carrierCode, number, inferredKind).
    static func extractDesignator(from title: String) -> (String, String, TravelKind?) {
        let upper = title.uppercased()
        if let range = upper.range(of: #"\b[A-Z]{2,3}\d{1,4}[A-Z]?\b"#, options: .regularExpression) {
            let match = String(upper[range])
            // Split at first digit
            if let digitIdx = match.firstIndex(where: { $0.isNumber }) {
                let carrier = String(match[..<digitIdx])
                let number = String(match[digitIdx...])
                return (carrier, number, .flight)
            }
        }
        if let range = upper.range(of: #"\b[GDC]\d{1,5}\b"#, options: .regularExpression) {
            let match = String(upper[range])
            return (String(match.prefix(1)), String(match.dropFirst()), .highSpeedRail)
        }
        if let range = upper.range(of: #"\b[KTZYL]\d{1,5}\b"#, options: .regularExpression) {
            let match = String(upper[range])
            return (String(match.prefix(1)), String(match.dropFirst()), .train)
        }
        return ("", title, nil)
    }

    /// "北京 → 多伦多" / "Beijing to Toronto" / "PEK-YYZ"
    static func parseRoute(from location: String) -> (String, String) {
        let separators = [" → ", " to ", " - ", "-", "–", "—", " 至 ", " 到 "]
        for sep in separators {
            if let range = location.range(of: sep, options: .caseInsensitive) {
                let dep = String(location[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let arr = String(location[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !dep.isEmpty && !arr.isEmpty {
                    return (dep, arr)
                }
            }
        }
        return (location, "")
    }

    // MARK: - Permission

    private func requestAccessIfNeeded() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            return
        case .denied, .restricted:
            throw TravelImportError.readFailed(String(localized: "日历访问被拒绝"))
        case .notDetermined, .writeOnly:
            // On iOS 17+: requestFullAccessToEvents. On earlier: requestAccess.
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                if !granted { throw TravelImportError.readFailed(String(localized: "日历访问被拒绝")) }
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                if !granted { throw TravelImportError.readFailed(String(localized: "日历访问被拒绝")) }
            }
        @unknown default:
            throw TravelImportError.readFailed(String(localized: "日历访问被拒绝"))
        }
    }

    private func toLocalWallClock(_ utc: Date, zone: TimeZone) -> Date {
        let comp = Calendar(identifier: .gregorian).dateComponents(in: zone, from: utc)
        var out = DateComponents()
        out.year = comp.year; out.month = comp.month; out.day = comp.day
        out.hour = comp.hour; out.minute = comp.minute; out.second = comp.second
        out.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: out) ?? utc
    }
}
