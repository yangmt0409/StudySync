import SwiftUI

// MARK: - Availability Status

enum AvailabilityStatus: String, CaseIterable, Identifiable {
    case available = "G"
    case maybe     = "Y"
    case busy      = "R"
    case sleeping  = "S"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .available: return .green
        case .maybe:     return .yellow
        case .busy:      return .red
        case .sleeping:  return Color(.systemGray3)
        }
    }

    var label: String {
        switch self {
        case .available: return L10n.avAvailable
        case .maybe:     return L10n.avMaybe
        case .busy:      return L10n.avBusy
        case .sleeping:  return L10n.avSleeping
        }
    }

    var icon: String {
        switch self {
        case .available: return "checkmark.circle.fill"
        case .maybe:     return "questionmark.circle.fill"
        case .busy:      return "xmark.circle.fill"
        case .sleeping:  return "moon.fill"
        }
    }

    init?(code: Character) {
        switch code {
        case "G": self = .available
        case "Y": self = .maybe
        case "R": self = .busy
        case "S": self = .sleeping
        default:  return nil
        }
    }
}

// MARK: - Day Slots Helpers

enum DaySlots {
    /// 48 slots per day (24h × 2 per hour)
    static let count = 48

    /// All-green (available for the full day)
    static let allAvailable = String(repeating: "G", count: count)

    /// All-gray (unset / sleeping) — used when user has never configured their timeline
    static let allSleeping = String(repeating: "S", count: count)

    /// Parse a 48-char slot string into an array of statuses.
    /// Falls back to `.sleeping` for invalid/missing characters (conservative: unknown = unavailable).
    static func parse(_ string: String) -> [AvailabilityStatus] {
        var result = [AvailabilityStatus]()
        result.reserveCapacity(count)
        for (i, ch) in string.enumerated() {
            guard i < count else { break }
            result.append(AvailabilityStatus(code: ch) ?? .sleeping)
        }
        // Pad if string is shorter than 48
        while result.count < count {
            result.append(.sleeping)
        }
        return result
    }

    /// Encode an array of statuses back to a 48-char string.
    static func encode(_ slots: [AvailabilityStatus]) -> String {
        String(slots.prefix(count).map { Character($0.rawValue) })
    }

    /// Time label for a given slot index (0–47).
    static func timeLabel(for index: Int) -> String {
        let hour = index / 2
        let minute = (index % 2 == 0) ? "00" : "30"
        return String(format: "%02d:%@", hour, minute)
    }

    /// Whether this slot index is on the hour (vs :30).
    static func isFullHour(_ index: Int) -> Bool {
        index % 2 == 0
    }
}
