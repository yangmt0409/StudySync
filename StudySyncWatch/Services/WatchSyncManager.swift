import Foundation
import WatchConnectivity

/// Lightweight event data transferred from iPhone to Watch
struct WatchEvent: Identifiable, Codable {
    let id: UUID
    let title: String
    let emoji: String
    let startDate: Date
    let endDate: Date
    let categoryName: String
    let colorHex: String
    let isPinned: Bool
    var primaryCount: Int = 0
    var unitLabel: String = "天"
    var showPercentage: Bool = false
    var showAsCountUp: Bool = false
    var timeUnitRaw: String = "day"

    init(id: UUID, title: String, emoji: String, startDate: Date, endDate: Date,
         categoryName: String, colorHex: String, isPinned: Bool,
         primaryCount: Int = 0, unitLabel: String = "天",
         showPercentage: Bool = false, showAsCountUp: Bool = false,
         timeUnitRaw: String = "day") {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.startDate = startDate
        self.endDate = endDate
        self.categoryName = categoryName
        self.colorHex = colorHex
        self.isPinned = isPinned
        self.primaryCount = primaryCount
        self.unitLabel = unitLabel
        self.showPercentage = showPercentage
        self.showAsCountUp = showAsCountUp
        self.timeUnitRaw = timeUnitRaw
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, emoji, startDate, endDate, categoryName, colorHex, isPinned
        case primaryCount, unitLabel, showPercentage, showAsCountUp, timeUnitRaw
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        emoji = try c.decode(String.self, forKey: .emoji)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decode(Date.self, forKey: .endDate)
        categoryName = try c.decode(String.self, forKey: .categoryName)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        isPinned = try c.decode(Bool.self, forKey: .isPinned)
        primaryCount = try c.decodeIfPresent(Int.self, forKey: .primaryCount) ?? 0
        unitLabel = try c.decodeIfPresent(String.self, forKey: .unitLabel) ?? "天"
        showPercentage = try c.decodeIfPresent(Bool.self, forKey: .showPercentage) ?? false
        showAsCountUp = try c.decodeIfPresent(Bool.self, forKey: .showAsCountUp) ?? false
        timeUnitRaw = try c.decodeIfPresent(String.self, forKey: .timeUnitRaw) ?? "day"
    }

    var daysRemaining: Int {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: endDate)
        let days = calendar.dateComponents([.day], from: now, to: end).day ?? 0
        return max(days, 0)
    }

    var totalDays: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return max(calendar.dateComponents([.day], from: start, to: end).day ?? 1, 1)
    }

    var progress: Double {
        let elapsed = totalDays - daysRemaining
        guard totalDays > 0 else { return 1.0 }
        return min(max(Double(elapsed) / Double(totalDays), 0.0), 1.0)
    }

    var isExpired: Bool { Date() > endDate }
}

/// Manages Watch Connectivity to receive event data from iPhone
@Observable
final class WatchSyncManager: NSObject {
    static let shared = WatchSyncManager()

    var events: [WatchEvent] = []
    var lastSynced: Date?
    var isReachable = false

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        loadCachedEvents()
    }

    func requestSync() {
        guard let session, session.isReachable else { return }
        session.sendMessage(["request": "sync"], replyHandler: nil)
    }

    // MARK: - Cache

    private let cacheKey = "watch_events_cache"

    private func cacheEvents() {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCachedEvents() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([WatchEvent].self, from: data) {
            events = cached
        }

        // Add sample events if empty (for testing without iPhone)
        if events.isEmpty {
            events = [
                WatchEvent(id: UUID(), title: String(localized: "期末考试周"), emoji: "📝",
                          startDate: Date(),
                          endDate: Calendar.current.date(byAdding: .day, value: 45, to: Date())!,
                          categoryName: String(localized: "学业"), colorHex: "#5B7FFF", isPinned: false),
                WatchEvent(id: UUID(), title: String(localized: "暑假回国"), emoji: "✈️",
                          startDate: Date(),
                          endDate: Calendar.current.date(byAdding: .day, value: 90, to: Date())!,
                          categoryName: String(localized: "旅行"), colorHex: "#4ECDC4", isPinned: false),
                WatchEvent(id: UUID(), title: String(localized: "签证到期"), emoji: "📋",
                          startDate: Calendar.current.date(byAdding: .day, value: -120, to: Date())!,
                          endDate: Calendar.current.date(byAdding: .day, value: 180, to: Date())!,
                          categoryName: String(localized: "签证"), colorHex: "#FF6B6B", isPinned: false),
            ]
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext["events"] as? Data,
           let decoded = try? JSONDecoder().decode([WatchEvent].self, from: data) {
            DispatchQueue.main.async {
                self.events = decoded
                self.lastSynced = Date()
                self.cacheEvents()
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let data = userInfo["events"] as? Data,
           let decoded = try? JSONDecoder().decode([WatchEvent].self, from: data) {
            DispatchQueue.main.async {
                self.events = decoded
                self.lastSynced = Date()
                self.cacheEvents()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
}
