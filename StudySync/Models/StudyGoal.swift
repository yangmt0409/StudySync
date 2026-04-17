import Foundation
import SwiftData

@Model
final class StudyGoal {
    var id: UUID = UUID()
    var title: String = ""
    var emoji: String = "📚"
    var colorHex: String = "#5B7FFF"
    var frequencyRaw: String = "daily"
    var isActive: Bool = true
    var isArchived: Bool = false
    var createdAt: Date = Date()

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \CheckInRecord.goal)
    var checkIns: [CheckInRecord] = []

    // MARK: - Computed Properties

    var frequency: GoalFrequency {
        get { GoalFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        let sorted = checkIns.sorted { $0.date > $1.date }

        guard !sorted.isEmpty else { return 0 }

        var streak = 0
        var expectedDate = calendar.startOfDay(for: Date())

        if frequency == .daily {
            // Daily: if not checked in today, start from yesterday
            if !isCheckedInToday {
                guard let yesterday = calendar.date(byAdding: .day, value: -1, to: expectedDate) else { return 0 }
                expectedDate = yesterday
            }
        } else {
            // Weekly: if not checked in this week, start from previous week
            if !isCheckedInThisWeek {
                guard let prevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: expectedDate) else { return 0 }
                expectedDate = prevWeek
            }
        }

        let step: Calendar.Component = frequency == .daily ? .day : .weekOfYear

        for record in sorted {
            let recordDay = calendar.startOfDay(for: record.date)

            if frequency == .daily {
                if calendar.isDate(recordDay, inSameDayAs: expectedDate) {
                    streak += 1
                    guard let prev = calendar.date(byAdding: step, value: -1, to: expectedDate) else { break }
                    expectedDate = prev
                } else if recordDay < expectedDate {
                    break
                }
            } else {
                // Weekly: check same week
                if calendar.isDate(recordDay, equalTo: expectedDate, toGranularity: .weekOfYear) {
                    streak += 1
                    guard let prev = calendar.date(byAdding: step, value: -1, to: expectedDate) else { break }
                    expectedDate = prev
                } else if recordDay < calendar.startOfDay(for: expectedDate) {
                    break
                }
            }
        }

        return streak
    }

    var totalCheckIns: Int {
        checkIns.count
    }

    var isCheckedInToday: Bool {
        let calendar = Calendar.current
        return checkIns.contains { calendar.isDateInToday($0.date) }
    }

    var isCheckedInThisWeek: Bool {
        let calendar = Calendar.current
        return checkIns.contains { calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
    }

    var needsCheckIn: Bool {
        switch frequency {
        case .daily: return !isCheckedInToday
        case .weekly: return !isCheckedInThisWeek
        }
    }

    /// Next milestone to reach
    var nextMilestone: Int? {
        let count = totalCheckIns
        let milestones = frequency == .daily
            ? [10, 30, 50, 100]
            : [5, 10, 20, 50]
        return milestones.first { $0 > count }
    }

    /// Progress toward next milestone (0.0 - 1.0)
    var milestoneProgress: Double {
        let count = totalCheckIns
        let milestones = frequency == .daily
            ? [0, 10, 30, 50, 100]
            : [0, 5, 10, 20, 50]

        let currentMilestoneIndex = milestones.lastIndex { $0 <= count } ?? 0
        let current = milestones[currentMilestoneIndex]
        let next = currentMilestoneIndex + 1 < milestones.count ? milestones[currentMilestoneIndex + 1] : (milestones.last ?? current)

        guard next > current else { return 1.0 }
        return Double(count - current) / Double(next - current)
    }

    // MARK: - Init

    init(
        title: String,
        emoji: String = "📚",
        colorHex: String = "#5B7FFF",
        frequency: GoalFrequency = .daily
    ) {
        self.id = UUID()
        self.title = title
        self.emoji = emoji
        self.colorHex = colorHex
        self.frequencyRaw = frequency.rawValue
        self.isActive = true
        self.isArchived = false
        self.createdAt = Date()
        self.checkIns = []
    }
}

// MARK: - GoalFrequency

enum GoalFrequency: String, Codable, CaseIterable {
    case daily
    case weekly

    var displayName: String {
        switch self {
        case .daily: return L10n.goalDaily
        case .weekly: return L10n.goalWeekly
        }
    }
}

// MARK: - Milestone

struct Milestone {
    let count: Int
    let emoji: String
    let title: String

    static let dailyMilestones: [Milestone] = [
        Milestone(count: 10, emoji: "🌟", title: L10n.goalMilestone10d),
        Milestone(count: 30, emoji: "🔥", title: L10n.goalMilestone30d),
        Milestone(count: 50, emoji: "💪", title: L10n.goalMilestone50d),
        Milestone(count: 100, emoji: "🏆", title: L10n.goalMilestone100d),
    ]

    static let weeklyMilestones: [Milestone] = [
        Milestone(count: 5, emoji: "🌟", title: L10n.goalMilestone5w),
        Milestone(count: 10, emoji: "🔥", title: L10n.goalMilestone10w),
        Milestone(count: 20, emoji: "💪", title: L10n.goalMilestone20w),
        Milestone(count: 50, emoji: "🏆", title: L10n.goalMilestone50w),
    ]

    static func milestones(for frequency: GoalFrequency) -> [Milestone] {
        frequency == .daily ? dailyMilestones : weeklyMilestones
    }

    static func reached(count: Int, frequency: GoalFrequency) -> Milestone? {
        let list = milestones(for: frequency)
        return list.first { $0.count == count }
    }
}
