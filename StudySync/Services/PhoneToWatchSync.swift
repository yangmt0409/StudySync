import Foundation
import WatchConnectivity
import SwiftData

/// iPhone-side: sends event data to Apple Watch
final class PhoneToWatchSync: NSObject {
    static let shared = PhoneToWatchSync()

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    /// Call this after any event changes to push data to Watch
    func syncEvents(from context: ModelContext) {
        guard let session, session.isPaired, session.isWatchAppInstalled else { return }

        let descriptor = FetchDescriptor<CountdownEvent>()
        guard let events = try? context.fetch(descriptor) else { return }

        // Convert to lightweight WatchEvent format
        struct WatchEventPayload: Codable {
            let id: UUID
            let title: String
            let emoji: String
            let startDate: Date
            let endDate: Date
            let categoryName: String
            let colorHex: String
            let isPinned: Bool
            let primaryCount: Int
            let unitLabel: String
            let showPercentage: Bool
            let showAsCountUp: Bool
            let timeUnitRaw: String
        }

        let payload = events
            .filter { !$0.isExpired }
            .sorted { $0.primaryCount < $1.primaryCount }
            .prefix(10)
            .map { event in
                WatchEventPayload(
                    id: event.id,
                    title: event.title,
                    emoji: event.emoji,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    categoryName: event.category.rawValue,
                    colorHex: event.colorHex,
                    isPinned: event.isPinned,
                    primaryCount: event.primaryCount,
                    unitLabel: event.unitLabel,
                    showPercentage: event.showPercentage,
                    showAsCountUp: event.showAsCountUp,
                    timeUnitRaw: event.timeUnitRaw
                )
            }

        if let data = try? JSONEncoder().encode(Array(payload)) {
            try? session.updateApplicationContext(["events": data])
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneToWatchSync: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Watch requested a sync — but we need a ModelContext
        // This would be handled by the main app observing changes
    }
}
