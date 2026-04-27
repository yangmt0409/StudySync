import Foundation

/// Pre-packaged reminder schedules per travel kind / context.
/// Each preset expands into concrete `UNNotificationRequest`s by
/// `TravelReminderScheduler`.
nonisolated enum TravelReminderPreset: String, Codable, CaseIterable, Sendable {
    /// International flight — earlier check-in, longer airport buffer.
    case internationalFlight
    /// Domestic flight — tighter buffer.
    case domesticFlight
    /// High-speed rail — show up 30 min early.
    case highSpeedRail
    /// Conventional train — slightly more buffer for older-style stations.
    case conventionalTrain
    /// Long-distance bus — show up 30 min early.
    case bus
    /// Ferry — similar to HSR.
    case ferry
    /// User disabled all travel reminders for this event.
    case none

    /// Reminders emitted as offsets before departure, newest → oldest.
    /// Returned values are in seconds before departure (positive numbers).
    var offsetsSeconds: [Int] {
        switch self {
        case .internationalFlight:
            return [
                24 * 3600,   // T-24h: check-in opens
                4 * 3600,    // T-4h: leave for airport
                3 * 3600,    // T-3h: bag drop
                90 * 60,     // T-90m: through security
                30 * 60,     // T-30m: boarding reminder
            ]
        case .domesticFlight:
            return [
                24 * 3600,   // T-24h: check-in
                150 * 60,    // T-2h30m: leave for airport
                2 * 3600,    // T-2h: at airport
                60 * 60,     // T-1h: through security
                25 * 60,     // T-25m: boarding
            ]
        case .highSpeedRail:
            return [
                3 * 3600,    // T-3h: print ticket / leave home
                60 * 60,     // T-1h: head to station
                30 * 60,     // T-30m: ticket gate
                10 * 60,     // T-10m: board
            ]
        case .conventionalTrain:
            return [
                3 * 3600,
                90 * 60,
                45 * 60,
                15 * 60,
            ]
        case .bus:
            return [
                90 * 60,
                30 * 60,
            ]
        case .ferry:
            return [
                2 * 3600,
                45 * 60,
            ]
        case .none:
            return []
        }
    }

    /// Localized name of each reminder offset. Index-aligned with `offsetsSeconds`.
    func reminderLabels() -> [String] {
        switch self {
        case .internationalFlight:
            return [
                String(localized: "值机已开放"),
                String(localized: "该出发前往机场了"),
                String(localized: "办理托运"),
                String(localized: "过安检"),
                String(localized: "准备登机"),
            ]
        case .domesticFlight:
            return [
                String(localized: "值机已开放"),
                String(localized: "出发前往机场"),
                String(localized: "到达机场"),
                String(localized: "过安检"),
                String(localized: "准备登机"),
            ]
        case .highSpeedRail:
            return [
                String(localized: "准备出行"),
                String(localized: "前往车站"),
                String(localized: "进站检票"),
                String(localized: "准备上车"),
            ]
        case .conventionalTrain:
            return [
                String(localized: "准备出行"),
                String(localized: "前往车站"),
                String(localized: "取票 / 检票"),
                String(localized: "准备上车"),
            ]
        case .bus:
            return [
                String(localized: "前往车站"),
                String(localized: "准备上车"),
            ]
        case .ferry:
            return [
                String(localized: "前往码头"),
                String(localized: "准备登船"),
            ]
        case .none:
            return []
        }
    }

    var label: String {
        switch self {
        case .internationalFlight: return String(localized: "国际航班提醒")
        case .domesticFlight:      return String(localized: "国内航班提醒")
        case .highSpeedRail:       return String(localized: "高铁提醒")
        case .conventionalTrain:   return String(localized: "普通列车提醒")
        case .bus:                 return String(localized: "大巴提醒")
        case .ferry:               return String(localized: "轮渡提醒")
        case .none:                return String(localized: "关闭提醒")
        }
    }

    /// Choose a sensible default preset based on travel kind.
    /// For flights, we default to domestic; caller should upgrade to
    /// international if origin and destination are in different countries.
    static func defaultPreset(for kind: TravelKind, isInternational: Bool = false) -> TravelReminderPreset {
        switch kind {
        case .flight:             return isInternational ? .internationalFlight : .domesticFlight
        case .highSpeedRail:      return .highSpeedRail
        case .train:              return .conventionalTrain
        case .longDistanceBus:    return .bus
        case .ferry:              return .ferry
        case .intercityTrain:     return .bus
        }
    }
}
