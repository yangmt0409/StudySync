import Foundation
import SwiftData

/// Records a point-in-time usage snapshot for trend tracking.
/// One record per account per fetch (~every 5 minutes while app is active).
@Model
final class AIUsageSnapshot {
    var id: UUID = UUID()
    /// The AIAccount this snapshot belongs to (matched by accountId)
    var accountId: UUID = UUID()
    var timestamp: Date = Date()
    /// Primary window utilization (5h for Claude, Codex for OpenAI, daily for Gemini)
    var utilization1: Double = 0
    /// Secondary window utilization (7d for Claude, 0 for others)
    var utilization2: Double = 0

    init(accountId: UUID, utilization1: Double, utilization2: Double) {
        self.id = UUID()
        self.accountId = accountId
        self.timestamp = Date()
        self.utilization1 = utilization1
        self.utilization2 = utilization2
    }
}

// MARK: - Snapshot Helpers

extension AIUsageSnapshot {
    /// Snapshots older than this are automatically pruned (7 days)
    static let maxAge: TimeInterval = 7 * 24 * 3600

    /// Minimum interval between snapshots for the same account (4 minutes)
    /// to avoid flooding storage during rapid refreshes.
    static let minInterval: TimeInterval = 240
}
