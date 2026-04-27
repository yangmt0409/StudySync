import SwiftUI

/// Real-time status of a travel event.
/// Updated by `TravelStatusRefresher` for flights with API support, manually
/// inferred for rail/bus (just based on clock vs. schedule).
nonisolated enum TravelStatus: String, Codable, CaseIterable, Sendable {
    /// Default — journey is in the future, no live updates yet.
    case scheduled
    /// Check-in / online seat selection is open.
    case checkInOpen
    /// Boarding / ticketing in progress at the gate.
    case boarding
    /// Vehicle has departed, en route.
    case enRoute
    /// Landed / arrived at destination.
    case arrived
    /// Running behind schedule (use `TravelEvent.delayMinutes` for specifics).
    case delayed
    /// Cancelled by carrier.
    case cancelled
    /// User-marked as completed (manual override — hides from upcoming lists).
    case completed

    var label: String {
        switch self {
        case .scheduled:    return String(localized: "已预订")
        case .checkInOpen:  return String(localized: "可值机")
        case .boarding:     return String(localized: "登机中")
        case .enRoute:      return String(localized: "行程中")
        case .arrived:      return String(localized: "已到达")
        case .delayed:      return String(localized: "延误")
        case .cancelled:    return String(localized: "已取消")
        case .completed:    return String(localized: "已完成")
        }
    }

    @MainActor
    var accentColor: Color {
        switch self {
        case .scheduled:    return Color(hex: "#6B7280")
        case .checkInOpen:  return Color(hex: "#5B8BFF")
        case .boarding:     return Color(hex: "#10B981")
        case .enRoute:      return Color(hex: "#3B82F6")
        case .arrived:      return Color(hex: "#059669")
        case .delayed:      return Color(hex: "#F59E0B")
        case .cancelled:    return Color(hex: "#DC2626")
        case .completed:    return Color(hex: "#6B7280")
        }
    }

    var symbolName: String {
        switch self {
        case .scheduled:    return "clock"
        case .checkInOpen:  return "person.crop.rectangle"
        case .boarding:     return "airplane.departure"
        case .enRoute:      return "paperplane.fill"
        case .arrived:      return "checkmark.circle.fill"
        case .delayed:      return "exclamationmark.triangle.fill"
        case .cancelled:    return "xmark.circle.fill"
        case .completed:    return "flag.checkered"
        }
    }
}
