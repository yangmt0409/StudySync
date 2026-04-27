import Foundation

/// Common abstraction for every way a user can add a travel event.
/// Each concrete importer knows how to go from some input (form data,
/// flight number, scanned barcode, PDF, etc.) to a draft `TravelEvent`.
///
/// `@MainActor` because `TravelEvent` is a SwiftData `@Model` which must be
/// created and mutated on the main actor. Importers that need to do heavy
/// work (network, PDF parsing) can still `await` off-main work and return
/// to the main actor before creating the draft.
@MainActor
protocol TravelImporter {
    associatedtype Input
    var source: TravelImportSource { get }
    func makeDraft(from input: Input) async throws -> TravelEvent
}

// MARK: - Manual form

/// Minimal form payload the user fills in manually.
struct ManualTravelInput {
    var kind: TravelKind
    var carrierCode: String
    var number: String
    var departureCity: String
    var departureStation: String
    var departureStationCode: String?
    var departureTimeLocal: Date
    var departureTimeZoneID: String
    var arrivalCity: String
    var arrivalStation: String
    var arrivalStationCode: String?
    var arrivalTimeLocal: Date
    var arrivalTimeZoneID: String
    var seat: String?
    var pnr: String?
    var note: String?
}

struct ManualTravelImporter: TravelImporter {
    let source: TravelImportSource = .manual
    func makeDraft(from input: ManualTravelInput) async throws -> TravelEvent {
        let e = TravelEvent(
            kind: input.kind,
            carrierCode: input.carrierCode,
            number: input.number,
            departureCity: input.departureCity,
            departureStation: input.departureStation,
            arrivalCity: input.arrivalCity,
            arrivalStation: input.arrivalStation,
            departureTimeLocal: input.departureTimeLocal,
            arrivalTimeLocal: input.arrivalTimeLocal,
            importSource: .manual
        )
        e.departureStationCode = input.departureStationCode ?? ""
        e.arrivalStationCode = input.arrivalStationCode ?? ""
        e.departureTimeZoneID = input.departureTimeZoneID
        e.arrivalTimeZoneID = input.arrivalTimeZoneID
        e.seat = input.seat ?? ""
        e.pnr = input.pnr ?? ""
        e.note = input.note ?? ""
        return e
    }
}

// MARK: - Flight API lookup (AviationStack)

struct FlightAPIInput {
    /// Full IATA flight number, e.g. "CA981".
    var iataNumber: String
    /// Scheduled departure date in origin local timezone.
    var flightDate: Date
    /// Which of the returned candidates the user picked.
    /// Nil when the API returned exactly one result.
    var selectedIndex: Int?
}

struct FlightAPIImporter: TravelImporter {
    let source: TravelImportSource = .flightAPI

    /// Uses `FlightProviderRegistry.active` at call time so a provider switch
    /// in Settings takes effect on the next lookup without re-initializing.
    func makeDraft(from input: FlightAPIInput) async throws -> TravelEvent {
        let results = try await FlightProviderRegistry.active.lookupFlight(
            iataNumber: input.iataNumber,
            flightDate: input.flightDate
        )
        guard !results.isEmpty else { throw TravelImportError.notFound }
        let picked = results[input.selectedIndex ?? 0]
        return try TravelImporterMapping.travelEvent(from: picked, source: .flightAPI)
    }

    /// Probe call used by the UI to show a picker when multiple candidates
    /// match (codeshares / multi-sector flights).
    func lookupCandidates(iataNumber: String, flightDate: Date) async throws -> [FlightLookupResult] {
        try await FlightProviderRegistry.active.lookupFlight(
            iataNumber: iataNumber,
            flightDate: flightDate
        )
    }
}

// MARK: - Shared AviationStack → TravelEvent mapping

enum TravelImporterMapping {
    /// Convert a provider-agnostic lookup record into our persistent model.
    /// Dates already carry timezone info; we split them into a local wall-clock
    /// time + timezone ID for display consistency.
    static func travelEvent(from flight: FlightLookupResult,
                            source: TravelImportSource) throws -> TravelEvent {
        guard let departure = flight.departure,
              let arrival = flight.arrival,
              let depScheduled = departure.scheduled,
              let arrScheduled = arrival.scheduled
        else { throw TravelImportError.missingRequiredFields }

        let depZone = TimeZone(identifier: departure.timezone ?? "") ?? .current
        let arrZone = TimeZone(identifier: arrival.timezone ?? "") ?? .current

        let depLocal = toLocalWallClock(depScheduled, zone: depZone)
        let arrLocal = toLocalWallClock(arrScheduled, zone: arrZone)

        let carrierCode = flight.airlineIATA
            ?? flight.flightIATA.flatMap { String($0.prefix(2)) }
            ?? ""
        let number = extractNumber(
            flight.flightIATA ?? flight.flightNumber,
            fallback: flight.flightNumber ?? ""
        )

        let e = TravelEvent(
            kind: .flight,
            carrierCode: carrierCode,
            number: number,
            departureCity: departure.airportName ?? "",
            departureStation: departure.airportName ?? "",
            arrivalCity: arrival.airportName ?? "",
            arrivalStation: arrival.airportName ?? "",
            departureTimeLocal: depLocal,
            arrivalTimeLocal: arrLocal,
            importSource: source
        )
        e.serviceName = flight.airlineName ?? ""
        e.departureStationCode = departure.iata ?? ""
        e.arrivalStationCode = arrival.iata ?? ""
        e.departureTerminal = departure.terminal ?? ""
        e.departureGate = departure.gate ?? ""
        e.arrivalTerminal = arrival.terminal ?? ""
        e.departureTimeZoneID = departure.timezone ?? TimeZone.current.identifier
        e.arrivalTimeZoneID = arrival.timezone ?? TimeZone.current.identifier

        // Seed status from the API snapshot — but never accept terminal
        // statuses for a flight that hasn't departed yet. Daily-recurring
        // flight numbers (CX829, AC1, etc.) cause both AeroDataBox and
        // AviationStack to occasionally return state from the previous
        // day's instance. Without this guard a future-dated trip imports
        // showing "Arrived" while still 10+ hours from departure.
        let delay = departure.delayMinutes ?? 0
        let apiStatus = mapStatus(flight.status, delay: delay)
        e.status = guardAgainstStaleTerminalStatus(apiStatus, departure: e.departureInstant)
        e.delayMinutes = max(0, delay)
        e.lastStatusRefreshedAt = Date()

        // International heuristic: different regions → international preset
        e.reminderPreset = TravelReminderPreset.defaultPreset(
            for: .flight,
            isInternational: e.isInternational
        )
        return e
    }

    /// "CA981" → "981"; if already numeric, pass-through.
    private static func extractNumber(_ iata: String?, fallback: String) -> String {
        if let iata, let range = iata.range(of: #"\d+"#, options: .regularExpression) {
            return String(iata[range])
        }
        return fallback
    }

    /// Convert a UTC-anchored Date into a "naive" local wall-clock Date that,
    /// when interpreted in `zone`, gives the same h:m. This is the storage
    /// convention used by TravelEvent for display convenience.
    private static func toLocalWallClock(_ utc: Date, zone: TimeZone) -> Date {
        let components = Calendar(identifier: .gregorian).dateComponents(
            in: zone, from: utc
        )
        var local = DateComponents()
        local.year = components.year
        local.month = components.month
        local.day = components.day
        local.hour = components.hour
        local.minute = components.minute
        local.second = components.second
        local.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: local) ?? utc
    }

    /// Canonical status string (from `FlightLookupResult.status`) + delay →
    /// our internal `TravelStatus`. Exposed (not private) so the status
    /// refresher can reuse it without re-implementing the mapping.
    static func mapStatus(_ raw: String?, delay: Int) -> TravelStatus {
        switch (raw ?? "").lowercased() {
        case "scheduled":             return delay > 0 ? .delayed : .scheduled
        case "active":                return .enRoute
        case "landed":                return .arrived
        case "cancelled":             return .cancelled
        case "delayed":               return .delayed
        case "incident", "diverted":  return .delayed
        default:                      return .scheduled
        }
    }

    /// Drop-in shield against the daily-flight-number stale-status bug:
    /// if departure is still in the future, the API has no business telling
    /// us the flight is `enRoute` / `arrived` / `completed`. That happens
    /// when the API serves the previous day's instance of a recurring
    /// flight number (CX829, AC1, BA9, ...). Coerce those back to
    /// `.scheduled` (or `.delayed` if the API also reported a delay).
    /// `cancelled` and `delayed` are kept as-is — the airline really did
    /// publish those for the upcoming flight.
    static func guardAgainstStaleTerminalStatus(
        _ apiStatus: TravelStatus,
        departure: Date,
        now: Date = Date()
    ) -> TravelStatus {
        guard departure > now else { return apiStatus }
        switch apiStatus {
        case .enRoute, .arrived, .completed:
            return .scheduled
        default:
            return apiStatus
        }
    }
}

// MARK: - Errors

enum TravelImportError: LocalizedError {
    case notFound
    case missingRequiredFields
    case unsupportedFormat
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return String(localized: "未找到该航班，请检查航班号和日期")
        case .missingRequiredFields:
            return String(localized: "返回数据不完整，请尝试手动输入")
        case .unsupportedFormat:
            return String(localized: "不支持的格式")
        case .readFailed(let reason):
            return String(localized: "读取失败：\(reason)")
        }
    }
}
