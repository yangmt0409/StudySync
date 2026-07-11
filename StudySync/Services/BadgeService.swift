import Foundation

/// Central award logic for achievement badges.
///
/// Every badge in `Badge.all` must have an award path routed through here —
/// the badge grid shows each user a concrete unlock requirement, so a badge
/// with no award code is a broken promise (pre-1.0.4, 9 of the 10 badges were
/// permanently unearnable; only `first_friend` had a call site, and only on
/// the accepting side).
///
/// `award(_:)` is idempotent at both layers: it skips ids already on the local
/// profile, and the Firestore write uses `arrayUnion`. Trigger points call the
/// `check*` helpers with whatever counts they already have on hand:
///   - check-ins / streaks → `StudyGoalViewModel.pushStatsToFirestore`
///   - friend counts       → `FriendsListView.loadData`
///   - active goal count   → `AddStudyGoalView.saveGoal`
///   - due sharing         → `SocialHubView` share toggle
@MainActor
enum BadgeService {

    /// Award `badgeId` once. Updates the in-memory profile immediately so the
    /// badge grid reflects it without waiting for a profile reload.
    static func award(_ badgeId: String) async {
        guard var profile = AuthService.shared.userProfile else { return }
        guard !profile.badges.contains(badgeId) else { return }
        profile.badges.append(badgeId)
        AuthService.shared.userProfile = profile
        await FirestoreService.shared.awardBadge(uid: profile.id, badgeId: badgeId)
    }

    /// Cumulative check-in count + longest streak badges.
    static func checkCheckInBadges(totalCheckIns: Int, longestStreak: Int) async {
        if totalCheckIns >= 10 { await award("checkin_10") }
        if totalCheckIns >= 50 { await award("checkin_50") }
        if totalCheckIns >= 100 { await award("checkin_100") }
        if longestStreak >= 7 { await award("streak_7") }
        if longestStreak >= 30 { await award("streak_30") }
        if longestStreak >= 100 { await award("streak_100") }
    }

    /// Friend-count badges. Covers both sides of a friendship: the accepter
    /// hits this right after accepting, the requester the next time their
    /// friends list loads.
    static func checkFriendBadges(friendCount: Int) async {
        if friendCount >= 1 { await award("first_friend") }
        if friendCount >= 5 { await award("social_5") }
    }

    /// "Own 3 study goals at once" badge.
    static func checkGoalBadges(activeGoalCount: Int) async {
        if activeGoalCount >= 3 { await award("goal_3") }
    }

    /// "Enable due sharing" badge.
    static func checkTeamPlayerBadge(shareEnabled: Bool) async {
        if shareEnabled { await award("team_player") }
    }
}
