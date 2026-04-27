import Foundation

// MARK: - Result DTO

/// Provider-agnostic flight lookup record. Both `AviationStackClient` and
/// `AeroDataBoxClient` normalize their respective API responses to this shape
/// so the rest of the app never cares which provider is active.
nonisolated struct FlightLookupResult: Sendable {
    nonisolated struct Endpoint: Sendable {
        let airportName: String?
        let iata: String?
        let icao: String?
        let terminal: String?
        let gate: String?
        let timezone: String?
        let scheduled: Date?
        let estimated: Date?
        let actual: Date?
        let delayMinutes: Int?
    }

    let flightDate: String?
    /// Canonical status vocabulary shared across providers.
    /// One of: "scheduled" | "active" | "landed" | "cancelled" | "diverted" | "delayed".
    let status: String?
    let departure: Endpoint?
    let arrival: Endpoint?
    let airlineName: String?
    let airlineIATA: String?
    let airlineICAO: String?
    let flightNumber: String?
    let flightIATA: String?
    let flightICAO: String?
}

// MARK: - Protocol

/// Abstraction over a flight-lookup API. Each implementation is an actor so it
/// serializes its own URLSession work and owns its own UserDefaults-backed key
/// storage without cross-client contention.
protocol FlightLookupProvider: Actor {
    nonisolated var kind: FlightProviderKind { get }
    func configuredAPIKey() -> String?
    func setAPIKey(_ key: String?)
    func lookupFlight(iataNumber: String, flightDate: Date) async throws -> [FlightLookupResult]
    func realTimeStatus(iataNumber: String) async throws -> FlightLookupResult?
}

// MARK: - Provider kinds + registry

enum FlightProviderKind: String, CaseIterable, Sendable {
    case aeroDataBox = "aerodatabox"
    case aviationStack = "aviationstack"

    var displayName: String {
        switch self {
        case .aeroDataBox:   return "AeroDataBox"
        case .aviationStack: return "AviationStack"
        }
    }

    /// Shown beneath the search form so the user understands the quota + caveats.
    var footerBlurb: String {
        switch self {
        case .aeroDataBox:
            return String(localized: "数据来源 AeroDataBox (RapidAPI) · 免费 500 次/月 · 支持未来/历史日期")
        case .aviationStack:
            return String(localized: "数据来源 AviationStack · 免费 100 次/月 · 免费版仅支持当日实时")
        }
    }

    var signupURL: URL? {
        switch self {
        case .aeroDataBox:
            return URL(string: "https://rapidapi.com/aedbx-aedbx/api/aerodatabox")
        case .aviationStack:
            return URL(string: "https://aviationstack.com/signup/free")
        }
    }
}

/// Vends the currently selected provider. Selection persists in `UserDefaults`
/// under `flight.provider.selected`. Default is AeroDataBox since its free
/// tier (500 req/mo, any date) is strictly better than AviationStack's free
/// tier (100 req/mo, same-day only).
enum FlightProviderRegistry {
    private static let defaultsKey = "flight.provider.selected"

    static var selected: FlightProviderKind {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey)
            return raw.flatMap(FlightProviderKind.init(rawValue:)) ?? .aeroDataBox
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    static var active: any FlightLookupProvider {
        provider(for: selected)
    }

    static func provider(for kind: FlightProviderKind) -> any FlightLookupProvider {
        switch kind {
        case .aeroDataBox:   return AeroDataBoxClient.shared
        case .aviationStack: return AviationStackClient.shared
        }
    }
}

// MARK: - Unified error

enum FlightLookupError: LocalizedError {
    case missingAPIKey(provider: FlightProviderKind)
    /// Shared embedded key's monthly quota is exhausted. Caller should surface
    /// a dedicated UI prompting the user to supply their own key (each
    /// RapidAPI / AviationStack account gets its own free allowance).
    case quotaExceeded(provider: FlightProviderKind)
    case invalidIATANumber
    case invalidRequest
    case invalidResponse
    case httpStatus(Int, body: String)
    case apiError(code: String, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return String(localized: "未配置 \(provider.displayName) API 密钥 — 请先填入")
        case .quotaExceeded(let provider):
            return String(localized: "本月共享 \(provider.displayName) 配额已用完 — 请配置您自己的 API Key（免费）继续使用")
        case .invalidIATANumber:
            return String(localized: "航班号格式不对，应类似 CA981")
        case .invalidRequest:
            return String(localized: "请求构造失败")
        case .invalidResponse:
            return String(localized: "返回格式异常")
        case .httpStatus(let code, let body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return String(localized: "网络请求失败 (\(code))")
            }
            return String(localized: "网络请求失败 (\(code))：\(trimmed.prefix(160))")
        case .apiError(_, let message):
            return message
        }
    }
}
