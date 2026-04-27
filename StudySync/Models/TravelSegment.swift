import Foundation

/// A single leg of a multi-segment journey (connections / transfers).
/// Stored inline on `TravelEvent` as JSON-encoded array because SwiftData
/// doesn't yet support nested `@Model` collections elegantly for embedded
/// value types.
nonisolated struct TravelSegment: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var carrierCode: String?      // "CA" / "G"
    var number: String            // "981" / "1234"
    var serviceName: String?      // "Air China" / "CRH"

    // Departure
    var departureCity: String
    var departureStation: String
    var departureStationCode: String?   // "PEK" / "BJP"
    var departureTimeLocal: Date        // local wall-clock time at origin
    var departureTimeZoneID: String     // "Asia/Shanghai"
    var departureTerminal: String?
    var departureGate: String?

    // Arrival
    var arrivalCity: String
    var arrivalStation: String
    var arrivalStationCode: String?
    var arrivalTimeLocal: Date
    var arrivalTimeZoneID: String
    var arrivalTerminal: String?

    // MARK: - Computed

    var departureTimeZone: TimeZone {
        TimeZone(identifier: departureTimeZoneID) ?? .current
    }

    var arrivalTimeZone: TimeZone {
        TimeZone(identifier: arrivalTimeZoneID) ?? .current
    }

    /// Duration of this leg as a real elapsed time, properly accounting for
    /// cross-timezone travel. We interpret the stored `*TimeLocal` as wall-clock
    /// times in their respective zones, convert to real UTC instants via
    /// Calendar (DST-safe), then diff.
    var duration: TimeInterval {
        let depUTC = resolveInstant(from: departureTimeLocal, in: departureTimeZone)
        let arrUTC = resolveInstant(from: arrivalTimeLocal, in: arrivalTimeZone)
        return max(0, arrUTC.timeIntervalSince(depUTC))
    }

    /// Convenience: "12h 15m" / "2h 30m" / "45m"
    var durationLabel: String {
        let total = Int(duration)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }

    /// DST-safe wall-clock → UTC resolution.
    /// Extract the packed wall-clock components using a UTC Calendar, then
    /// rebuild as a real instant using a Calendar set to the target zone.
    private func resolveInstant(from packed: Date, in zone: TimeZone) -> Date {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let comps = utcCal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: packed
        )
        var zonedCal = Calendar(identifier: .gregorian)
        zonedCal.timeZone = zone
        return zonedCal.date(from: comps) ?? packed
    }
}
