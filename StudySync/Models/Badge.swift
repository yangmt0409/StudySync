import Foundation
import SwiftUI

struct Badge: Identifiable {
    let id: String
    let emoji: String
    let name: String
    let description: String
    let colorHex: String
    let category: BadgeCategory
    let requirement: Int

    var color: Color { Color(hex: colorHex) }
}

enum BadgeCategory: String, CaseIterable {
    case streak
    case social
    case milestone

    var displayName: String {
        switch self {
        case .streak: return L10n.badgeCatStreak
        case .social: return L10n.badgeCatSocial
        case .milestone: return L10n.badgeCatMilestone
        }
    }
}

// MARK: - Badge Definitions

extension Badge {
    static let all: [Badge] = [
        // Streak badges
        Badge(id: "streak_7", emoji: "⚡", name: L10n.badgeStreak7,
              description: L10n.badgeStreak7Desc, colorHex: "#FFD93D",
              category: .streak, requirement: 7),
        Badge(id: "streak_30", emoji: "🌊", name: L10n.badgeStreak30,
              description: L10n.badgeStreak30Desc, colorHex: "#5B7FFF",
              category: .streak, requirement: 30),
        Badge(id: "streak_100", emoji: "👑", name: L10n.badgeStreak100,
              description: L10n.badgeStreak100Desc, colorHex: "#6C5CE7",
              category: .streak, requirement: 100),

        // Social badges
        Badge(id: "first_friend", emoji: "🤝", name: L10n.badgeFirstFriend,
              description: L10n.badgeFirstFriendDesc, colorHex: "#4ECDC4",
              category: .social, requirement: 1),
        Badge(id: "social_5", emoji: "🦋", name: L10n.badgeSocial5,
              description: L10n.badgeSocial5Desc, colorHex: "#FF6B6B",
              category: .social, requirement: 5),
        Badge(id: "team_player", emoji: "📋", name: L10n.badgeTeamPlayer,
              description: L10n.badgeTeamPlayerDesc, colorHex: "#A8E6CF",
              category: .social, requirement: 1),

        // Milestone badges
        Badge(id: "checkin_10", emoji: "🌟", name: L10n.badgeCheckin10,
              description: L10n.badgeCheckin10Desc, colorHex: "#FFD93D",
              category: .milestone, requirement: 10),
        Badge(id: "checkin_50", emoji: "💪", name: L10n.badgeCheckin50,
              description: L10n.badgeCheckin50Desc, colorHex: "#FF8A5C",
              category: .milestone, requirement: 50),
        Badge(id: "checkin_100", emoji: "🏆", name: L10n.badgeCheckin100,
              description: L10n.badgeCheckin100Desc, colorHex: "#6C5CE7",
              category: .milestone, requirement: 100),
        Badge(id: "goal_3", emoji: "🎯", name: L10n.badgeGoal3,
              description: L10n.badgeGoal3Desc, colorHex: "#778BEB",
              category: .milestone, requirement: 3),
    ]

    static func badge(for id: String) -> Badge? {
        all.first { $0.id == id }
    }

    static func earned(from ids: [String]) -> [Badge] {
        ids.compactMap { badge(for: $0) }
    }

    static func unearned(from ids: [String]) -> [Badge] {
        all.filter { !ids.contains($0.id) }
    }
}
