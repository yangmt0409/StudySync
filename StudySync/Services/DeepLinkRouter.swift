import Foundation
import SwiftUI

/// Centralised handler for `studysync://` URLs coming from widgets, Live
/// Activities, local notifications, shortcut items, and universal links.
///
/// Views observe `pendingDestination` (for tab switches) and `pendingEventID`
/// (for detail-screen routing) and clear them once consumed.
@Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    /// Tab-level navigation target. Set on deep-link receipt, cleared by
    /// `MainTabView` after it has switched tabs.
    var pendingDestination: DeepLinkDestination?

    /// Event ID to open in `EventDetailView`. Set on deep-link receipt,
    /// cleared by `HomeView` after it has presented the detail sheet.
    var pendingEventID: UUID?

    /// Request to immediately present the Add Event sheet.
    var pendingAddEvent: Bool = false

    private init() {}

    // MARK: - URL Handling

    /// Parses and dispatches a `studysync://` URL. Supported hosts:
    /// - `countdown` / `event/{uuid}`  → countdown tab (+ optional detail)
    /// - `schedule`                    → schedule tab
    /// - `add`                         → countdown tab + add sheet
    /// - `social`                      → social tab
    /// - `goals`                       → study goal tab
    func handle(url: URL) {
        guard url.scheme?.lowercased() == "studysync" else { return }

        let host = url.host?.lowercased()

        switch host {
        case "event":
            // studysync://event/{uuid}
            let idString = url.pathComponents.dropFirst().first ?? ""
            if let id = UUID(uuidString: idString) {
                pendingDestination = .countdown
                pendingEventID = id
            } else {
                pendingDestination = .countdown
            }
        case "countdown":
            pendingDestination = .countdown
        case "schedule":
            pendingDestination = .schedule
        case "add":
            pendingDestination = .countdown
            pendingAddEvent = true
        case "social":
            pendingDestination = .social
        case "goals", "studygoal":
            pendingDestination = .studyGoal
        case "aimonitor":
            pendingDestination = .aiMonitor
        case "grades", "gradecalc":
            pendingDestination = .gradeCalc
        default:
            break
        }
    }

    /// Route a local notification tap. Called from `AppDelegate` before the
    /// payload is forwarded to `PushNotificationService` (which handles
    /// remote / social payloads).
    ///
    /// Returns `true` if the tap was consumed as a local-event link, so the
    /// caller can skip forwarding it to the push handler.
    @discardableResult
    func handleLocalNotification(userInfo: [AnyHashable: Any]) -> Bool {
        if let idString = userInfo["eventID"] as? String,
           let id = UUID(uuidString: idString) {
            pendingDestination = .countdown
            pendingEventID = id
            return true
        }
        return false
    }

    // MARK: - Consumers

    func consumeEventID() -> UUID? {
        let id = pendingEventID
        pendingEventID = nil
        return id
    }

    func consumeAddEvent() -> Bool {
        let flag = pendingAddEvent
        pendingAddEvent = false
        return flag
    }

    func consumeDestination() -> DeepLinkDestination? {
        let dest = pendingDestination
        pendingDestination = nil
        return dest
    }

    // MARK: - Project Code Parsing

    /// Extracts an 8-character team-project invite code from a scanned QR
    /// payload. Accepts either a raw code (`ABCD1234`) or a deep link of the
    /// form `studysync://project/ABCD1234`. Returns `nil` if no valid code
    /// can be extracted.
    static func parseProjectCode(from payload: String) -> String? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)

        // studysync://project/CODE
        if let url = URL(string: trimmed),
           url.scheme?.lowercased() == "studysync",
           url.host?.lowercased() == "project" {
            let code = url.pathComponents.dropFirst().first ?? ""
            return validate(code)
        }

        // Raw code
        return validate(trimmed)
    }

    private static func validate(_ code: String) -> String? {
        let upper = code.uppercased()
        guard upper.count == 8,
              upper.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return upper
    }
}

enum DeepLinkDestination: Equatable {
    case countdown
    case schedule
    case studyGoal
    case social
    case aiMonitor
    case gradeCalc

    /// Map to the corresponding `AppTab` so `MainTabView` can look up its
    /// index in the user-customised tab order.
    var tab: AppTab {
        switch self {
        case .countdown: return .countdown
        case .schedule: return .schedule
        case .studyGoal: return .studyGoal
        case .social: return .social
        case .aiMonitor: return .aiMonitor
        case .gradeCalc: return .gradeCalc
        }
    }
}
