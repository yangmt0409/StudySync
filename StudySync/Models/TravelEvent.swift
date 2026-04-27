import Foundation
import SwiftData

/// A travel ticket (flight / train / bus / ferry) tracked in Schedule.
///
/// Design notes:
/// - `departureTimeLocal` / `arrivalTimeLocal` store wall-clock times at their
///   respective zones. The UTC instant is reconstructed via `timeZoneID` fields.
///   This lets us display "10:30 Beijing time" consistently regardless of
///   where the user's phone is set.
/// - Multi-leg trips (connections) are stored as JSON-encoded `[TravelSegment]`
///   in `segmentsData`. For direct trips the array is empty — the top-level
///   departure/arrival fields are authoritative.
/// - Status and reminders are driven by `kind` + `reminderPresetRaw`. Real-time
///   updates (flight delays) write into `statusRaw` + `delayMinutes` +
///   `lastStatusRefreshedAt` by `TravelStatusRefresher`.
@Model
final class TravelEvent {
    // MARK: - Identity
    var id: UUID = UUID()
    var kindRaw: String = TravelKind.flight.rawValue

    /// Carrier code (airline IATA / railway prefix). e.g. "CA" / "G".
    var carrierCode: String = ""
    /// Number portion. e.g. "981" / "1234".
    var number: String = ""
    /// Optional service / operator name, e.g. "Air China" / "CRH".
    var serviceName: String = ""

    // MARK: - Origin
    var departureCity: String = ""
    var departureStation: String = ""
    var departureStationCode: String = ""    // "PEK" / "BJP"
    var departureTimeLocal: Date = Date()
    var departureTimeZoneID: String = TimeZone.current.identifier
    var departureTerminal: String = ""
    var departureGate: String = ""

    // MARK: - Destination
    var arrivalCity: String = ""
    var arrivalStation: String = ""
    var arrivalStationCode: String = ""
    var arrivalTimeLocal: Date = Date()
    var arrivalTimeZoneID: String = TimeZone.current.identifier
    var arrivalTerminal: String = ""

    // MARK: - Connections
    /// JSON-encoded `[TravelSegment]`. Empty for direct journeys.
    var segmentsData: Data = Data()

    // MARK: - Passenger info
    var pnr: String = ""
    var seat: String = ""
    var passengerName: String = ""

    // MARK: - Status
    var statusRaw: String = TravelStatus.scheduled.rawValue
    /// Schedule delay in minutes (positive only). 0 means on-time.
    var delayMinutes: Int = 0
    /// When `TravelStatusRefresher` last updated this record.
    var lastStatusRefreshedAt: Date?
    /// Whether the user manually marked this trip complete (overrides status).
    var markedComplete: Bool = false

    // MARK: - Presentation
    var colorHex: String = "#5B8BFF"
    var emoji: String = "✈️"
    var note: String = ""

    // MARK: - Reminders
    var reminderPresetRaw: String = TravelReminderPreset.domesticFlight.rawValue
    var reminderEnabled: Bool = true

    // MARK: - Metadata
    var createdAt: Date = Date()
    var importSourceRaw: String = TravelImportSource.manual.rawValue
    /// Unique identifier of the Apple Wallet pass if imported from Wallet.
    var walletPassIdentifier: String = ""

    // MARK: - Init

    init(
        kind: TravelKind = .flight,
        carrierCode: String = "",
        number: String = "",
        departureCity: String = "",
        departureStation: String = "",
        arrivalCity: String = "",
        arrivalStation: String = "",
        departureTimeLocal: Date = Date(),
        arrivalTimeLocal: Date = Date(),
        importSource: TravelImportSource = .manual
    ) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.carrierCode = carrierCode
        self.number = number
        self.departureCity = departureCity
        self.departureStation = departureStation
        self.arrivalCity = arrivalCity
        self.arrivalStation = arrivalStation
        self.departureTimeLocal = departureTimeLocal
        self.arrivalTimeLocal = arrivalTimeLocal
        self.importSourceRaw = importSource.rawValue
        self.emoji = kind.defaultEmoji
        let (_, endHex) = kind.gradientHex
        self.colorHex = endHex
        self.reminderPresetRaw = TravelReminderPreset.defaultPreset(for: kind).rawValue
    }

    // MARK: - Computed

    var kind: TravelKind {
        get { TravelKind(rawValue: kindRaw) ?? .flight }
        set {
            kindRaw = newValue.rawValue
            // Sync visual defaults
            if emoji.isEmpty { emoji = newValue.defaultEmoji }
            if reminderPresetRaw == TravelReminderPreset.none.rawValue {
                // user disabled — keep
            }
        }
    }

    var status: TravelStatus {
        get {
            if markedComplete { return .completed }
            return TravelStatus(rawValue: statusRaw) ?? derivedStatus()
        }
        set { statusRaw = newValue.rawValue }
    }

    var importSource: TravelImportSource {
        get { TravelImportSource(rawValue: importSourceRaw) ?? .manual }
        set { importSourceRaw = newValue.rawValue }
    }

    var reminderPreset: TravelReminderPreset {
        get { TravelReminderPreset(rawValue: reminderPresetRaw) ?? .domesticFlight }
        set { reminderPresetRaw = newValue.rawValue }
    }

    /// Decode `segmentsData` to an array of segments.
    var segments: [TravelSegment] {
        get {
            guard !segmentsData.isEmpty,
                  let decoded = try? JSONDecoder.travel.decode([TravelSegment].self, from: segmentsData)
            else { return [] }
            return decoded
        }
        set {
            segmentsData = (try? JSONEncoder.travel.encode(newValue)) ?? Data()
        }
    }

    /// Full display designator, e.g. "CA981" / "G1".
    var fullNumber: String {
        (carrierCode + number).trimmingCharacters(in: .whitespaces)
    }

    var departureTimeZone: TimeZone {
        TimeZone(identifier: departureTimeZoneID) ?? .current
    }

    var arrivalTimeZone: TimeZone {
        TimeZone(identifier: arrivalTimeZoneID) ?? .current
    }

    /// Absolute departure instant (resolved against stored TZ).
    ///
    /// We treat `departureTimeLocal` as a "UTC-packed wall-clock time": its
    /// year/month/day/hour/minute fields are what should display, and we
    /// re-interpret those components as if they were local time in
    /// `departureTimeZone`. Using `Calendar.date(from: components)` with an
    /// explicit timezone is DST-safe — Calendar picks the correct offset for
    /// the actual wall-clock date (important around DST spring-forward where
    /// `secondsFromGMT(for:)` on a packed Date can be ambiguous).
    var departureInstant: Date {
        Self.resolveInstant(from: departureTimeLocal, in: departureTimeZone)
    }

    var arrivalInstant: Date {
        Self.resolveInstant(from: arrivalTimeLocal, in: arrivalTimeZone)
    }

    private static func resolveInstant(from packed: Date, in zone: TimeZone) -> Date {
        // Extract year/month/day/hour/minute/second from the UTC-packed Date.
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = utcCal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: packed
        )
        // Reinterpret those components in the target zone.
        var zonedCal = Calendar(identifier: .gregorian)
        zonedCal.timeZone = zone
        return zonedCal.date(from: components) ?? packed
    }

    /// Real elapsed travel time (accounts for timezones correctly).
    var totalDuration: TimeInterval {
        max(0, arrivalInstant.timeIntervalSince(departureInstant))
    }

    /// "12h 15m" style label.
    var durationLabel: String {
        let total = Int(totalDuration)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }

    /// True if origin and destination are in different countries (heuristic:
    /// different IANA timezone countries). Used to auto-pick international
    /// flight reminder preset.
    var isInternational: Bool {
        guard kind == .flight else { return false }
        let depCountry = (Locale.Region(departureTimeZone.identifier.split(separator: "/").first.map(String.init) ?? ""))
        let arrCountry = (Locale.Region(arrivalTimeZone.identifier.split(separator: "/").first.map(String.init) ?? ""))
        // Falls back to string compare of zone regions
        _ = depCountry; _ = arrCountry
        let depRegion = departureTimeZone.identifier.split(separator: "/").first.map(String.init) ?? ""
        let arrRegion = arrivalTimeZone.identifier.split(separator: "/").first.map(String.init) ?? ""
        return depRegion != arrRegion && !depRegion.isEmpty && !arrRegion.isEmpty
    }

    /// True if departure is still in the future (from now).
    var isUpcoming: Bool {
        !markedComplete && departureInstant > Date()
    }

    /// Infer a status when we don't have API updates (rail/bus).
    private func derivedStatus() -> TravelStatus {
        if markedComplete { return .completed }
        let now = Date()
        if now < departureInstant { return .scheduled }
        if now < arrivalInstant { return .enRoute }
        return .arrived
    }
}

// MARK: - JSON coding helpers

extension JSONEncoder {
    /// Shared encoder for travel payloads — ISO8601 dates.
    /// `nonisolated(unsafe)` because Foundation's JSONEncoder isn't Sendable,
    /// but we only mutate during the initial setup closure — reads after that
    /// are thread-safe (JSONEncoder holds no mutable state post-init).
    nonisolated static let travel: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()
}

extension JSONDecoder {
    nonisolated static let travel: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()
}
