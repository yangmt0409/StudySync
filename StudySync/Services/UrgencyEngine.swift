import SwiftUI
import EventKit
import Combine
import SwiftData

@Observable
final class UrgencyEngine {
    static let shared = UrgencyEngine()

    // Published state
    var urgencyLevel: Double = 0.0       // 0.0 (calm) → 1.0 (most urgent)
    var urgencyColor: Color = .clear
    var hasActiveDeadline: Bool = false
    var mostUrgentDeadline: EKEvent?
    var mostUrgentRemainingSeconds: TimeInterval = 0

    // Settings (persisted via SyncedDefaults → iCloud KV sync)
    var lavaEffectEnabled: Bool {
        get { SyncedDefaults.shared.object(forKey: "lavaEffectEnabled") as? Bool ?? true }
        set { SyncedDefaults.shared.set(newValue, forKey: "lavaEffectEnabled") }
    }

    var globalBorderEnabled: Bool {
        get { SyncedDefaults.shared.object(forKey: "globalBorderEnabled") as? Bool ?? true }
        set { SyncedDefaults.shared.set(newValue, forKey: "globalBorderEnabled") }
    }

    var infectionEnabled: Bool {
        get { SyncedDefaults.shared.object(forKey: "infectionEnabled") as? Bool ?? true }
        set { SyncedDefaults.shared.set(newValue, forKey: "infectionEnabled") }
    }

    /// Hours before deadline when lava effect starts (default 10)
    var urgencyWindowHours: Double {
        get {
            let val = SyncedDefaults.shared.double(forKey: "urgencyWindowHours")
            return val > 0 ? val : 10.0
        }
        set { SyncedDefaults.shared.set(newValue, forKey: "urgencyWindowHours") }
    }

    private var timer: Timer?

    private init() {
        startTimer()
    }

    // MARK: - Timer

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.recalculate()
        }
    }

    // MARK: - Core Calculation

    func recalculate() {
        let manager = CalendarManager.shared
        guard manager.authorizationStatus == .fullAccess else {
            reset()
            return
        }

        // Find deadline events (those with DeadlineRecord)
        // This is called externally with the deadline IDs
    }

    /// Main calculation — called from CalendarFeedView or MainTabView
    func update(deadlineEvents: [EKEvent], completedIds: Set<String>) {
        guard lavaEffectEnabled else {
            reset()
            return
        }

        let now = Date()
        let windowSeconds = urgencyWindowHours * 3600

        // Filter: upcoming, not completed, within window
        let urgent = deadlineEvents.filter { event in
            let remaining = event.startDate.timeIntervalSince(now)
            return remaining > -3600  // allow 1 hour past deadline
                && remaining < windowSeconds
                && !completedIds.contains(event.eventIdentifier)
        }

        if let mostUrgent = urgent.min(by: { $0.startDate < $1.startDate }) {
            let remaining = mostUrgent.startDate.timeIntervalSince(now)
            let level = max(0, min(1, 1.0 - (remaining / windowSeconds)))

            withAnimation(.easeInOut(duration: 0.5)) {
                urgencyLevel = level
                urgencyColor = colorForLevel(level)
                hasActiveDeadline = true
                mostUrgentDeadline = mostUrgent
                mostUrgentRemainingSeconds = max(remaining, 0)
            }

            // Auto-start Live Activity if within lead time
            LiveActivityManager.shared.checkAndStartIfNeeded(
                deadlineEvents: deadlineEvents,
                completedIds: completedIds
            )
        } else {
            coolDown()
        }
    }

    /// Smooth cool-down when all deadlines completed
    func coolDown() {
        withAnimation(.easeOut(duration: 0.5)) {
            urgencyLevel = 0
            urgencyColor = .clear
            hasActiveDeadline = false
            mostUrgentDeadline = nil
            mostUrgentRemainingSeconds = 0
        }
    }

    private func reset() {
        urgencyLevel = 0
        urgencyColor = .clear
        hasActiveDeadline = false
        mostUrgentDeadline = nil
        mostUrgentRemainingSeconds = 0
    }

    // MARK: - Color Gradient (Lava)

    func colorForLevel(_ level: Double) -> Color {
        switch level {
        case ..<0.01:
            return .clear
        case 0..<0.3:
            // Warm yellow → light orange
            let t = level / 0.3
            return interpolateColor(
                from: Color(hex: "#F59E0B"),
                to: Color(hex: "#F97316"),
                t: t
            )
        case 0.3..<0.6:
            // Orange → deep orange-red
            let t = (level - 0.3) / 0.3
            return interpolateColor(
                from: Color(hex: "#F97316"),
                to: Color(hex: "#EA580C"),
                t: t
            )
        case 0.6..<0.8:
            // Deep orange-red → red
            let t = (level - 0.6) / 0.2
            return interpolateColor(
                from: Color(hex: "#EA580C"),
                to: Color(hex: "#DC2626"),
                t: t
            )
        default:
            // Red → deep red
            let t = min((level - 0.8) / 0.2, 1.0)
            return interpolateColor(
                from: Color(hex: "#DC2626"),
                to: Color(hex: "#991B1B"),
                t: t
            )
        }
    }

    private func interpolateColor(from: Color, to: Color, t: Double) -> Color {
        let fromComponents = UIColor(from).rgbaComponents
        let toComponents = UIColor(to).rgbaComponents
        let clamped = max(0, min(1, t))

        return Color(
            red: fromComponents.red + (toComponents.red - fromComponents.red) * clamped,
            green: fromComponents.green + (toComponents.green - fromComponents.green) * clamped,
            blue: fromComponents.blue + (toComponents.blue - fromComponents.blue) * clamped
        )
    }

    // MARK: - Infection Calculation

    /// Calculate how much a regular event is "infected" by a nearby deadline
    func infectionLevel(event: EKEvent, deadline: EKEvent) -> Double {
        guard infectionEnabled, urgencyLevel > 0 else { return 0 }

        let deadlineTime = deadline.startDate.timeIntervalSinceNow
        let eventTime = event.startDate.timeIntervalSinceNow

        // Only infect events BEFORE the deadline
        guard eventTime < deadlineTime else { return 0 }

        let timeDiff = deadlineTime - eventTime
        let maxRange = urgencyWindowHours * 3600

        guard timeDiff < maxRange else { return 0 }

        let proximity = 1.0 - (timeDiff / maxRange) // 0.0 (far) → 1.0 (near)
        return urgencyLevel * proximity * 0.6 // Max 60% infection
    }

    // MARK: - Formatted Remaining Time

    var formattedRemainingTime: String {
        let total = Int(mostUrgentRemainingSeconds)
        let hours = total / 3600
        let mins = (total % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(max(mins, 1))m"
        }
    }
}

// MARK: - UIColor RGBA Helper

private extension UIColor {
    var rgbaComponents: (red: Double, green: Double, blue: Double, alpha: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
