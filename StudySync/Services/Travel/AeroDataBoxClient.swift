import Foundation

/// AeroDataBox (RapidAPI) flight-lookup client.
///
/// Free tier: 500 requests/month, supports past and future `flight_date`
/// queries. This is strictly better than AviationStack's free tier (100 req/mo,
/// same-day only) so the app defaults to this provider.
///
/// Endpoint: `GET https://aerodatabox.p.rapidapi.com/flights/number/{num}/{date}`
/// Auth: RapidAPI-style headers (`X-RapidAPI-Key` + `X-RapidAPI-Host`).
///
/// API key resolution order:
///   1. UserDefaults["aerodatabox.api_key"] (user-supplied via Settings)
///   2. `Secrets.aeroDataBoxAPIKey` (build-time embedded)
///   3. throws `.missingAPIKey(.aeroDataBox)`
///
/// Sign up + subscribe to the "Basic" plan (free $0) at:
///   https://rapidapi.com/aedbx-aedbx/api/aerodatabox
actor AeroDataBoxClient: FlightLookupProvider {
    static let shared = AeroDataBoxClient()

    nonisolated let kind: FlightProviderKind = .aeroDataBox

    static let embeddedAPIKey: String = Secrets.aeroDataBoxAPIKey

    private let apiKeyDefaultsKey = "aerodatabox.api_key"
    private let baseURL = URL(string: "https://aerodatabox.p.rapidapi.com/")!
    private let rapidHost = "aerodatabox.p.rapidapi.com"

    private var resolvedKey: String? {
        if let stored = UserDefaults.standard.string(forKey: apiKeyDefaultsKey),
           !stored.isEmpty {
            return stored
        }
        if !Self.embeddedAPIKey.isEmpty {
            return Self.embeddedAPIKey
        }
        return nil
    }

    func configuredAPIKey() -> String? { resolvedKey }

    func setAPIKey(_ key: String?) {
        let clean = key?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let k = clean, !k.isEmpty {
            UserDefaults.standard.set(k, forKey: apiKeyDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: apiKeyDefaultsKey)
        }
    }

    // MARK: - Public API

    func lookupFlight(iataNumber: String, flightDate: Date) async throws -> [FlightLookupResult] {
        let cleaned = iataNumber.trimmingCharacters(in: .whitespaces).uppercased()
        guard Self.isValidIATANumber(cleaned) else { throw FlightLookupError.invalidIATANumber }
        guard let key = resolvedKey else { throw FlightLookupError.missingAPIKey(provider: .aeroDataBox) }

        let dateStr = DateFormatter.aeroDataBoxDate.string(from: flightDate)
        let url = baseURL.appendingPathComponent("flights/number/\(cleaned)/\(dateStr)")

        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue(rapidHost, forHTTPHeaderField: "X-RapidAPI-Host")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        if data.isEmpty { return [] }
        let flights = try JSONDecoder().decode([AeroDataBoxFlight].self, from: data)
        return flights.map { $0.toResult() }
    }

    func realTimeStatus(iataNumber: String) async throws -> FlightLookupResult? {
        // AeroDataBox's "real-time" is just today's flight with date=today.
        let results = try await lookupFlight(iataNumber: iataNumber, flightDate: Date())
        return results.first
    }

    // MARK: - Private

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw FlightLookupError.invalidResponse
        }
        if http.statusCode == 204 { return } // no flights matched — caller sees empty list

        // RapidAPI returns 429 when the monthly quota is exhausted. Surface
        // this as a dedicated error so the view can prompt the user to
        // switch to their own key.
        if http.statusCode == 429 {
            throw FlightLookupError.quotaExceeded(provider: .aeroDataBox)
        }

        guard (200...299).contains(http.statusCode) else {
            // RapidAPI + AeroDataBox both ship JSON error bodies. Most commonly:
            //   401: missing/invalid X-RapidAPI-Key
            //   403: not subscribed to the API on RapidAPI
            // Both formats have a top-level "message" key. Also check the
            // message for "exceeded"/"quota" since some RapidAPI APIs return
            // a 403 (not 429) when the quota is hit.
            let body = String(data: data.prefix(256), encoding: .utf8) ?? ""
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["message"] as? String {
                let lower = msg.lowercased()
                if lower.contains("exceeded") && (lower.contains("quota") || lower.contains("limit")) {
                    throw FlightLookupError.quotaExceeded(provider: .aeroDataBox)
                }
                throw FlightLookupError.apiError(code: "http\(http.statusCode)", message: msg)
            }
            throw FlightLookupError.httpStatus(http.statusCode, body: body)
        }
    }

    nonisolated private static func isValidIATANumber(_ s: String) -> Bool {
        guard (3...7).contains(s.count) else { return false }
        return s.range(of: #"^[A-Z0-9]{2,3}\d{1,4}[A-Z]?$"#, options: .regularExpression) != nil
    }
}

// MARK: - AeroDataBox response DTOs (private to this file)
// Marked `nonisolated` so the actor-based client can decode + map them off
// the main actor (the project-wide default actor isolation is MainActor).

private nonisolated struct AeroDataBoxFlight: Decodable, Sendable {
    struct Airport: Decodable, Sendable {
        let icao: String?
        let iata: String?
        let name: String?
        let timeZone: String?
    }
    struct Movement: Decodable, Sendable {
        let airport: Airport?
        let scheduledTime: TimePair?
        let revisedTime: TimePair?
        let runwayTime: TimePair?
        let terminal: String?
        let gate: String?
    }
    struct TimePair: Decodable, Sendable {
        let utc: String?
        let local: String?
    }
    struct Airline: Decodable, Sendable {
        let name: String?
        let iata: String?
        let icao: String?
    }

    let number: String?
    let callSign: String?
    let status: String?
    let departure: Movement?
    let arrival: Movement?
    let airline: Airline?

    func toResult() -> FlightLookupResult {
        let flightDateStr = departure?.scheduledTime?.local
            .flatMap { String($0.prefix(10)) }
        let compactNumber = number?.replacingOccurrences(of: " ", with: "")
        return FlightLookupResult(
            flightDate: flightDateStr,
            status: Self.normalizeStatus(status),
            departure: departure?.toEndpoint() ?? Self.emptyEndpoint,
            arrival: arrival?.toEndpoint() ?? Self.emptyEndpoint,
            airlineName: airline?.name,
            airlineIATA: airline?.iata,
            airlineICAO: airline?.icao,
            flightNumber: compactNumber,
            flightIATA: compactNumber,
            flightICAO: callSign
        )
    }

    private static let emptyEndpoint = FlightLookupResult.Endpoint(
        airportName: nil, iata: nil, icao: nil, terminal: nil, gate: nil,
        timezone: nil, scheduled: nil, estimated: nil, actual: nil, delayMinutes: nil
    )

    /// AeroDataBox's ~15 status strings collapse into the 6 canonical ones.
    private static func normalizeStatus(_ raw: String?) -> String? {
        guard let raw = raw?.lowercased() else { return nil }
        switch raw {
        case "expected", "checkin", "boarding", "gateclosed", "scheduled":
            return "scheduled"
        case "departed", "approaching", "enroute":
            return "active"
        case "arrived", "landed":
            return "landed"
        case "cancelled", "canceled":
            return "cancelled"
        case "diverted":
            return "diverted"
        case "delayed":
            return "delayed"
        default:
            return raw
        }
    }
}

private nonisolated extension AeroDataBoxFlight.Movement {
    func toEndpoint() -> FlightLookupResult.Endpoint {
        let scheduled = Self.parseTime(scheduledTime)
        let revised = Self.parseTime(revisedTime)
        let runway = Self.parseTime(runwayTime)
        let estimated = revised ?? runway
        let delay: Int? = {
            guard let s = scheduled, let e = estimated else { return nil }
            return Int((e.timeIntervalSince(s) / 60).rounded())
        }()
        return FlightLookupResult.Endpoint(
            airportName: airport?.name,
            iata: airport?.iata,
            icao: airport?.icao,
            terminal: terminal,
            gate: gate,
            timezone: airport?.timeZone,
            scheduled: scheduled,
            estimated: estimated,
            actual: runway,
            delayMinutes: delay
        )
    }

    /// AeroDataBox sends timestamps as:
    ///   utc:   "2026-04-28 09:00Z"
    ///   local: "2026-04-28 17:00+08:00"
    /// Note the literal space (not T) and the trailing Z / offset.
    private static func parseTime(_ pair: AeroDataBoxFlight.TimePair?) -> Date? {
        guard let pair else { return nil }
        if let raw = pair.utc {
            let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "Z "))
            if let d = DateFormatter.aeroDataBoxUTC.date(from: trimmed) { return d }
        }
        if let raw = pair.local,
           let d = DateFormatter.aeroDataBoxLocal.date(from: raw) {
            return d
        }
        return nil
    }
}

// MARK: - Formatters

extension DateFormatter {
    nonisolated static let aeroDataBoxDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    nonisolated static let aeroDataBoxUTC: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    nonisolated static let aeroDataBoxLocal: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mmXXXXX"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
