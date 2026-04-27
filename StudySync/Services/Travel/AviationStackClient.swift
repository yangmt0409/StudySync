import Foundation

/// Minimal AviationStack v1 API client.
///
/// Free tier (100 req/month): real-time only. The free plan 403s on
/// `flight_date` queries with `function_access_restricted`, so users stuck on
/// free can only look up today's flights. Paid tier ($9.99/mo) unlocks
/// historical + scheduled data.
///
/// HTTP-only on free tier; see `Info.plist` for the `NSExceptionDomains`
/// allowance on `api.aviationstack.com`.
///
/// Conforms to `FlightLookupProvider` so callers can switch between this and
/// `AeroDataBoxClient` via `FlightProviderRegistry`.
actor AviationStackClient: FlightLookupProvider {
    static let shared = AviationStackClient()

    nonisolated let kind: FlightProviderKind = .aviationStack

    // MARK: - Configuration

    /// Shared API key embedded in the binary (read from `Secrets.swift`, which
    /// is gitignored). All users share this key's free-tier quota.
    ///
    /// Individual users can override via the "Configure API Key" flow — that
    /// takes precedence (see `resolvedKey`).
    static let embeddedAPIKey: String = Secrets.aviationStackAPIKey

    private let apiKeyDefaultsKey = "aviationstack.api_key"
    private let baseURL = URL(string: "http://api.aviationstack.com/v1/")!

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
        guard let key = resolvedKey else { throw FlightLookupError.missingAPIKey(provider: .aviationStack) }

        let dateString = DateFormatter.aviationStackDate.string(from: flightDate)
        var components = URLComponents(url: baseURL.appendingPathComponent("flights"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "access_key", value: key),
            URLQueryItem(name: "flight_iata", value: cleaned),
            URLQueryItem(name: "flight_date", value: dateString),
        ]
        guard let url = components.url else { throw FlightLookupError.invalidRequest }

        return try await decodeFlights(from: url)
    }

    func realTimeStatus(iataNumber: String) async throws -> FlightLookupResult? {
        let cleaned = iataNumber.trimmingCharacters(in: .whitespaces).uppercased()
        guard Self.isValidIATANumber(cleaned) else { throw FlightLookupError.invalidIATANumber }
        guard let key = resolvedKey else { throw FlightLookupError.missingAPIKey(provider: .aviationStack) }

        var components = URLComponents(url: baseURL.appendingPathComponent("flights"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "access_key", value: key),
            URLQueryItem(name: "flight_iata", value: cleaned),
        ]
        guard let url = components.url else { throw FlightLookupError.invalidRequest }

        return try await decodeFlights(from: url).first
    }

    // MARK: - Private

    private func decodeFlights(from url: URL) async throws -> [FlightLookupResult] {
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)

        let decoded = try JSONDecoder().decode(AviationStackResponse.self, from: data)
        if let apiError = decoded.error {
            throw Self.translate(apiError)
        }
        return (decoded.data ?? []).map { $0.toResult() }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw FlightLookupError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            // AviationStack ships a JSON `{ "error": { code, message } }` body
            // even on 4xx. Decode it first so the user sees the real reason
            // (e.g. "function_access_restricted" = free tier can't use
            // flight_date) instead of a bare HTTP code.
            if let payload = try? JSONDecoder().decode(AviationStackResponse.self, from: data),
               let apiError = payload.error {
                throw Self.translate(apiError)
            }
            let bodyPreview = String(data: data.prefix(256), encoding: .utf8) ?? ""
            throw FlightLookupError.httpStatus(http.statusCode, body: bodyPreview)
        }
    }

    /// Map AviationStack's error codes to our unified error surface. The
    /// `usage_limit_reached` code = monthly quota hit (on the shared embedded
    /// key, this is a cue to prompt the user for their own key).
    nonisolated private static func translate(_ apiError: AviationStackErrorPayload) -> FlightLookupError {
        switch apiError.code {
        case "usage_limit_reached", "rate_limit_reached":
            return .quotaExceeded(provider: .aviationStack)
        default:
            return .apiError(code: apiError.code, message: apiError.message)
        }
    }

    nonisolated private static func isValidIATANumber(_ s: String) -> Bool {
        guard (3...7).contains(s.count) else { return false }
        return s.range(of: #"^[A-Z0-9]{2,3}\d{1,4}[A-Z]?$"#, options: .regularExpression) != nil
    }
}

// MARK: - Response DTOs (private — callers get `FlightLookupResult`)
// Marked `nonisolated` so the actor-based client can decode + map them off
// the main actor (the project-wide default actor isolation is MainActor).

private nonisolated struct AviationStackResponse: Decodable, Sendable {
    let data: [AviationStackFlight]?
    let error: AviationStackErrorPayload?
}

private nonisolated struct AviationStackErrorPayload: Decodable, Sendable {
    let code: String
    let message: String
}

private nonisolated struct AviationStackFlight: Decodable, Sendable {
    struct Endpoint: Decodable, Sendable {
        let airport: String?
        let timezone: String?
        let iata: String?
        let icao: String?
        let terminal: String?
        let gate: String?
        let scheduled: String?   // ISO8601 with offset
        let estimated: String?
        let actual: String?
        let delay: Int?          // minutes
    }
    struct Airline: Decodable, Sendable {
        let name: String?
        let iata: String?
        let icao: String?
    }
    struct FlightInfo: Decodable, Sendable {
        let number: String?
        let iata: String?
        let icao: String?
    }

    let flight_date: String?
    let flight_status: String?
    let departure: Endpoint?
    let arrival: Endpoint?
    let airline: Airline?
    let flight: FlightInfo?

    func toResult() -> FlightLookupResult {
        FlightLookupResult(
            flightDate: flight_date,
            status: flight_status?.lowercased(),
            departure: departure?.toEndpoint(),
            arrival: arrival?.toEndpoint(),
            airlineName: airline?.name,
            airlineIATA: airline?.iata,
            airlineICAO: airline?.icao,
            flightNumber: flight?.number,
            flightIATA: flight?.iata,
            flightICAO: flight?.icao
        )
    }
}

private nonisolated extension AviationStackFlight.Endpoint {
    func toEndpoint() -> FlightLookupResult.Endpoint {
        FlightLookupResult.Endpoint(
            airportName: airport,
            iata: iata,
            icao: icao,
            terminal: terminal,
            gate: gate,
            timezone: timezone,
            scheduled: Self.parse(scheduled),
            estimated: Self.parse(estimated),
            actual: Self.parse(actual),
            delayMinutes: delay
        )
    }

    /// AviationStack returns strings like `"2026-04-25T10:30:00+00:00"`;
    /// the offset is local at the airport.
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let d = DateFormatter.aviationStackISO.date(from: raw) { return d }
        return ISO8601DateFormatter().date(from: raw)
    }
}

// MARK: - Formatters

extension DateFormatter {
    nonisolated static let aviationStackDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    nonisolated static let aviationStackISO: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
