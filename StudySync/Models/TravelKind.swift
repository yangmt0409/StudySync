import SwiftUI

/// Kind of travel ticket. Drives visuals and reminder cadence.
/// `nonisolated` so the actor-based scheduler / refresher can use it safely.
nonisolated enum TravelKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case flight              // 飞机
    case highSpeedRail       // 高铁 / 动车
    case train               // 普通火车 (K/T/Z)
    case longDistanceBus     // 长途大巴
    case ferry               // 船
    case intercityTrain      // 城际 / 地铁跨城

    var id: String { rawValue }

    var defaultEmoji: String {
        switch self {
        case .flight:            return "✈️"
        case .highSpeedRail:     return "🚄"
        case .train:             return "🚆"
        case .longDistanceBus:   return "🚌"
        case .ferry:             return "🚢"
        case .intercityTrain:    return "🚇"
        }
    }

    var symbolName: String {
        switch self {
        case .flight:            return "airplane"
        case .highSpeedRail:     return "tram.fill"
        case .train:             return "tram"
        case .longDistanceBus:   return "bus.fill"
        case .ferry:             return "ferry.fill"
        case .intercityTrain:    return "tram.tunnel.fill"
        }
    }

    /// Localized label shown on cards.
    var label: String {
        switch self {
        case .flight:            return String(localized: "航班")
        case .highSpeedRail:     return String(localized: "高铁")
        case .train:             return String(localized: "火车")
        case .longDistanceBus:   return String(localized: "长途大巴")
        case .ferry:             return String(localized: "轮渡")
        case .intercityTrain:    return String(localized: "城际")
        }
    }

    /// Primary gradient used on the travel card. Chosen to evoke each mode.
    var gradientHex: (start: String, end: String) {
        switch self {
        case .flight:          return ("#5B8BFF", "#2B4FCC")  // sky → deep blue
        case .highSpeedRail:   return ("#D7DEE9", "#C8002B")  // CRH silver → red
        case .train:           return ("#B4C2AE", "#4A5D3A")  // khaki → forest
        case .longDistanceBus: return ("#F5B342", "#C87A1F")  // amber
        case .ferry:           return ("#5ED1C7", "#1E6B8C")  // teal → ocean
        case .intercityTrain:  return ("#A78BFA", "#4C1D95")  // violet
        }
    }

    /// `Color(hex:)` is main-actor isolated, so expose this as a main-actor
    /// computed property. Views asking for `accentColor` already run on main.
    @MainActor
    var accentColor: Color {
        Color(hex: gradientHex.end)
    }

    /// Carrier-code prefix pattern used to auto-detect kind from a ticket number.
    /// Flight: 2–3 letters + digits (e.g. CA981, CZ3107, UA89). Hit-rate is high
    /// because IATA codes are globally unique.
    /// High-speed rail (China): G/D/C prefix + digits (e.g. G1, D326, C6845).
    static func detect(from rawNumber: String) -> TravelKind? {
        let number = rawNumber.uppercased().trimmingCharacters(in: .whitespaces)
        if number.range(of: #"^[A-Z]{2,3}\d{1,4}[A-Z]?$"#, options: .regularExpression) != nil {
            return .flight
        }
        if number.range(of: #"^[GDC]\d{1,5}$"#, options: .regularExpression) != nil {
            return .highSpeedRail
        }
        if number.range(of: #"^[KTZYL]\d{1,5}$"#, options: .regularExpression) != nil {
            return .train
        }
        return nil
    }
}
