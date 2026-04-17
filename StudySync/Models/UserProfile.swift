import Foundation

struct UserProfile: Codable, Identifiable {
    var id: String  // Firebase UID
    var displayName: String
    var email: String
    var avatarEmoji: String
    var friendCode: String
    var shareEnabled: Bool
    var shareAvailability: Bool
    var allowNudges: Bool
    var badges: [String]
    var showcaseBadges: [String]  // up to 3 badges to display on profile
    var roles: [String]           // identity roles: developer, pro, tester, early_bird, contributor
    var createdAt: Date

    // Stats synced from local
    var totalCheckIns: Int
    var longestStreak: Int
    var totalFocusMinutes: Int

    // Focus challenge → Pro reward
    var proRewardExpiresAt: Date?

    // Birthday (optional — for birthday celebration)
    var birthday: Date?

    // Push notifications
    var fcmToken: String?
    var fcmTokenUpdatedAt: Date?

    init(
        id: String,
        displayName: String,
        email: String,
        avatarEmoji: String = "😊",
        friendCode: String = "",
        shareEnabled: Bool = false,
        shareAvailability: Bool = false,
        allowNudges: Bool = true,
        badges: [String] = [],
        showcaseBadges: [String] = [],
        roles: [String] = [],
        createdAt: Date = Date(),
        totalCheckIns: Int = 0,
        longestStreak: Int = 0,
        totalFocusMinutes: Int = 0,
        birthday: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.avatarEmoji = avatarEmoji
        self.friendCode = friendCode.isEmpty ? UserProfile.generateFriendCode() : friendCode
        self.shareEnabled = shareEnabled
        self.shareAvailability = shareAvailability
        self.allowNudges = allowNudges
        self.badges = badges
        self.showcaseBadges = showcaseBadges
        self.roles = roles
        self.createdAt = createdAt
        self.totalCheckIns = totalCheckIns
        self.longestStreak = longestStreak
        self.totalFocusMinutes = totalFocusMinutes
        self.birthday = birthday
    }

    static func generateFriendCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    // Custom decoder to handle missing shareAvailability in existing Firestore docs
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        email = try container.decode(String.self, forKey: .email)
        avatarEmoji = try container.decode(String.self, forKey: .avatarEmoji)
        friendCode = try container.decode(String.self, forKey: .friendCode)
        shareEnabled = try container.decode(Bool.self, forKey: .shareEnabled)
        shareAvailability = try container.decodeIfPresent(Bool.self, forKey: .shareAvailability) ?? false
        allowNudges = try container.decodeIfPresent(Bool.self, forKey: .allowNudges) ?? true
        badges = try container.decode([String].self, forKey: .badges)
        showcaseBadges = try container.decodeIfPresent([String].self, forKey: .showcaseBadges) ?? []
        roles = try container.decodeIfPresent([String].self, forKey: .roles) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        totalCheckIns = try container.decodeIfPresent(Int.self, forKey: .totalCheckIns) ?? 0
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        totalFocusMinutes = try container.decodeIfPresent(Int.self, forKey: .totalFocusMinutes) ?? 0
        birthday = try container.decodeIfPresent(Date.self, forKey: .birthday)
        proRewardExpiresAt = try container.decodeIfPresent(Date.self, forKey: .proRewardExpiresAt)
        fcmToken = try container.decodeIfPresent(String.self, forKey: .fcmToken)
        fcmTokenUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .fcmTokenUpdatedAt)
    }
}

// MARK: - Friend Request

struct FriendRequest: Codable, Identifiable {
    var id: String { fromUid }
    var fromUid: String
    var fromName: String
    var fromEmoji: String
    var createdAt: Date
}

// MARK: - Friend Info (lightweight)

struct FriendInfo: Codable, Identifiable {
    var id: String  // friend UID
    var displayName: String
    var avatarEmoji: String
    var shareEnabled: Bool
    var allowNudges: Bool
    var allowRingNudge: Bool   // per-friend: allow this person to ring-nudge me
    var showcaseBadges: [String]
    var roles: [String]
    var addedAt: Date
    var totalCheckIns: Int
    var longestStreak: Int
    var totalFocusMinutes: Int

    init(id: String, displayName: String, avatarEmoji: String, shareEnabled: Bool, allowNudges: Bool = true, allowRingNudge: Bool = false, showcaseBadges: [String] = [], roles: [String] = [], addedAt: Date = Date(), totalCheckIns: Int = 0, longestStreak: Int = 0, totalFocusMinutes: Int = 0) {
        self.id = id
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.shareEnabled = shareEnabled
        self.allowNudges = allowNudges
        self.allowRingNudge = allowRingNudge
        self.showcaseBadges = showcaseBadges
        self.roles = roles
        self.addedAt = addedAt
        self.totalCheckIns = totalCheckIns
        self.longestStreak = longestStreak
        self.totalFocusMinutes = totalFocusMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        avatarEmoji = try container.decode(String.self, forKey: .avatarEmoji)
        shareEnabled = try container.decodeIfPresent(Bool.self, forKey: .shareEnabled) ?? false
        allowNudges = try container.decodeIfPresent(Bool.self, forKey: .allowNudges) ?? true
        allowRingNudge = try container.decodeIfPresent(Bool.self, forKey: .allowRingNudge) ?? false
        showcaseBadges = try container.decodeIfPresent([String].self, forKey: .showcaseBadges) ?? []
        roles = try container.decodeIfPresent([String].self, forKey: .roles) ?? []
        addedAt = try container.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date()
        totalCheckIns = try container.decodeIfPresent(Int.self, forKey: .totalCheckIns) ?? 0
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        totalFocusMinutes = try container.decodeIfPresent(Int.self, forKey: .totalFocusMinutes) ?? 0
    }
}

// MARK: - Shared Due Event

struct SharedDue: Codable, Identifiable {
    var id: String
    var title: String
    var emoji: String
    var endDate: Date
    var categoryRaw: String
    var isCompleted: Bool
    var colorHex: String
    var updatedAt: Date

    var daysRemaining: Int {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: endDate)
        return max(calendar.dateComponents([.day], from: now, to: end).day ?? 0, 0)
    }

    var isExpired: Bool {
        Date() > endDate
    }
}
