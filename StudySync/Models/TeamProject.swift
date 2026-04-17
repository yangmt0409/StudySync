import Foundation

// MARK: - Team Project

struct TeamProject: Codable, Identifiable {
    var id: String                          // Firestore document ID
    var name: String
    var emoji: String
    var colorHex: String
    var projectCode: String                 // 8-char join code
    var createdBy: String                   // UID of creator
    var createdAt: Date
    var isArchived: Bool
    var archivedAt: Date?

    // Members (denormalized for quick display)
    var memberIds: [String]
    var memberProfiles: [ProjectMember]

    // Active meeting (nil = no meeting in progress)
    var activeMeeting: ActiveMeeting?

    // Active meetup session (nil = no meetup)
    var activeMeetup: MeetupSession?

    init(
        id: String = UUID().uuidString,
        name: String,
        emoji: String = "📁",
        colorHex: String = "#5B7FFF",
        projectCode: String = "",
        createdBy: String,
        createdAt: Date = Date(),
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        memberIds: [String] = [],
        memberProfiles: [ProjectMember] = [],
        activeMeeting: ActiveMeeting? = nil,
        activeMeetup: MeetupSession? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.projectCode = projectCode.isEmpty ? TeamProject.generateProjectCode() : projectCode
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.memberIds = memberIds
        self.memberProfiles = memberProfiles
        self.activeMeeting = activeMeeting
        self.activeMeetup = activeMeetup
    }

    static func generateProjectCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }

    var memberCount: Int { memberIds.count }

    /// Whether the project has enough members to use assign feature
    var canAssign: Bool { memberCount >= 2 }
}

// MARK: - Project Member

struct ProjectMember: Codable, Identifiable, Equatable {
    var id: String                          // UID
    var displayName: String
    var avatarEmoji: String
    var role: ProjectRole
    var joinedAt: Date

    init(
        id: String,
        displayName: String,
        avatarEmoji: String,
        role: ProjectRole = .member,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.role = role
        self.joinedAt = joinedAt
    }
}

enum ProjectRole: String, Codable {
    case owner
    case member
}

// MARK: - Project Due

struct ProjectDue: Codable, Identifiable {
    var id: String
    var title: String
    var description: String
    var emoji: String
    var dueDate: Date
    var createdBy: String                   // UID
    var creatorName: String
    var assignedTo: [String]                // UIDs (empty = unassigned)
    var assigneeNames: [String]
    var assigneeEmojis: [String]
    var isCompleted: Bool
    var completedBy: String?
    var completedAt: Date?
    var createdAt: Date
    var priority: DuePriority

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        emoji: String = "📋",
        dueDate: Date,
        createdBy: String,
        creatorName: String,
        assignedTo: [String] = [],
        assigneeNames: [String] = [],
        assigneeEmojis: [String] = [],
        isCompleted: Bool = false,
        completedBy: String? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        priority: DuePriority = .medium
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.emoji = emoji
        self.dueDate = dueDate
        self.createdBy = createdBy
        self.creatorName = creatorName
        self.assignedTo = assignedTo
        self.assigneeNames = assigneeNames
        self.assigneeEmojis = assigneeEmojis
        self.isCompleted = isCompleted
        self.completedBy = completedBy
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.priority = priority
    }

    /// Backward-compatible decoder: handles both old single-value and new
    /// array formats for assignedTo / assigneeName / assigneeEmoji fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? "📋"
        dueDate = try c.decode(Date.self, forKey: .dueDate)
        createdBy = try c.decode(String.self, forKey: .createdBy)
        creatorName = try c.decode(String.self, forKey: .creatorName)

        // New array format
        if let arr = try? c.decode([String].self, forKey: .assignedTo) {
            assignedTo = arr
        } else if let single = try? c.decode(String.self, forKey: .assignedTo) {
            assignedTo = [single]
        } else {
            assignedTo = []
        }
        // Try new array fields first, fall back to old singular fields
        if let arr = try? c.decode([String].self, forKey: .assigneeNames) {
            assigneeNames = arr
        } else if let single = try? c.decode(String.self, forKey: .assigneeNames) {
            assigneeNames = [single]
        } else if let single = try? c.decode(String.self, forKey: .legacyAssigneeName) {
            assigneeNames = [single]
        } else {
            assigneeNames = []
        }
        if let arr = try? c.decode([String].self, forKey: .assigneeEmojis) {
            assigneeEmojis = arr
        } else if let single = try? c.decode(String.self, forKey: .assigneeEmojis) {
            assigneeEmojis = [single]
        } else if let single = try? c.decode(String.self, forKey: .legacyAssigneeEmoji) {
            assigneeEmojis = [single]
        } else {
            assigneeEmojis = []
        }

        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        completedBy = try c.decodeIfPresent(String.self, forKey: .completedBy)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        priority = try c.decodeIfPresent(DuePriority.self, forKey: .priority) ?? .medium
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, emoji, dueDate, createdBy, creatorName
        case assignedTo, assigneeNames, assigneeEmojis
        case isCompleted, completedBy, completedAt, createdAt, priority
        // Legacy single-value field names from old Firestore docs
        case legacyAssigneeName = "assigneeName"
        case legacyAssigneeEmoji = "assigneeEmoji"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(emoji, forKey: .emoji)
        try c.encode(dueDate, forKey: .dueDate)
        try c.encode(createdBy, forKey: .createdBy)
        try c.encode(creatorName, forKey: .creatorName)
        try c.encode(assignedTo, forKey: .assignedTo)
        try c.encode(assigneeNames, forKey: .assigneeNames)
        try c.encode(assigneeEmojis, forKey: .assigneeEmojis)
        try c.encode(isCompleted, forKey: .isCompleted)
        try c.encodeIfPresent(completedBy, forKey: .completedBy)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(priority, forKey: .priority)
    }

    var isAssigned: Bool { !assignedTo.isEmpty }

    func isAssigned(to uid: String) -> Bool { assignedTo.contains(uid) }

    var isOverdue: Bool {
        !isCompleted && Date() > dueDate
    }

    var daysRemaining: Int {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: now, to: end).day ?? 0
    }

    var isUrgent: Bool {
        !isCompleted && daysRemaining <= 1 && daysRemaining >= 0
    }
}

enum DuePriority: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: return L10n.projectPriorityLow
        case .medium: return L10n.projectPriorityMedium
        case .high: return L10n.projectPriorityHigh
        }
    }

    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        }
    }

    var colorHex: String {
        switch self {
        case .low: return "#4ECDC4"
        case .medium: return "#FFD93D"
        case .high: return "#FF6B6B"
        }
    }
}

// MARK: - Project Invite

struct ProjectInvite: Codable, Identifiable {
    var id: String
    var projectId: String
    var projectName: String
    var projectEmoji: String
    var invitedBy: String                   // UID
    var inviterName: String
    var inviterEmoji: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        projectId: String,
        projectName: String,
        projectEmoji: String,
        invitedBy: String,
        inviterName: String,
        inviterEmoji: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.projectName = projectName
        self.projectEmoji = projectEmoji
        self.invitedBy = invitedBy
        self.inviterName = inviterName
        self.inviterEmoji = inviterEmoji
        self.createdAt = createdAt
    }
}

// MARK: - Meeting Platform

enum MeetingPlatform: String, Codable, CaseIterable {
    case zoom
    case googleMeet
    case teams
    case facetime
    case other

    var displayName: String {
        switch self {
        case .zoom: return "Zoom"
        case .googleMeet: return "Google Meet"
        case .teams: return "Teams"
        case .facetime: return "FaceTime"
        case .other: return L10n.meetingOtherPlatform
        }
    }

    var icon: String {
        switch self {
        case .zoom: return "video.fill"
        case .googleMeet: return "video.circle.fill"
        case .teams: return "person.3.fill"
        case .facetime: return "facetime"
        case .other: return "link.circle.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .zoom: return "#2D8CFF"
        case .googleMeet: return "#00897B"
        case .teams: return "#6264A7"
        case .facetime: return "#34C759"
        case .other: return "#5B7FFF"
        }
    }

    static func detect(from url: String) -> MeetingPlatform {
        let lower = url.lowercased()
        if lower.contains("zoom.us") || lower.contains("zoom.com") { return .zoom }
        if lower.contains("meet.google.com") { return .googleMeet }
        if lower.contains("teams.microsoft.com") || lower.contains("teams.live.com") { return .teams }
        if lower.contains("facetime.apple.com") { return .facetime }
        return .other
    }
}

// MARK: - Active Meeting

struct ActiveMeeting: Codable {
    var meetingLink: String
    var platform: MeetingPlatform
    var createdBy: String
    var creatorName: String
    var creatorEmoji: String
    var startedAt: Date
}

// MARK: - Meetup Session

struct MeetupSession: Codable, Identifiable {
    var id: String
    var title: String
    var meetupTime: Date
    var placeName: String
    var placeAddress: String
    var placeLatitude: Double
    var placeLongitude: Double
    var createdBy: String
    var creatorName: String
    var creatorEmoji: String
    var createdAt: Date
    var attendeeIds: [String]           // UIDs of members who joined
    var cancelVotes: [String]           // UIDs who voted to cancel

    init(
        id: String = UUID().uuidString,
        title: String,
        meetupTime: Date,
        placeName: String,
        placeAddress: String = "",
        placeLatitude: Double,
        placeLongitude: Double,
        createdBy: String,
        creatorName: String,
        creatorEmoji: String,
        createdAt: Date = Date(),
        attendeeIds: [String] = [],
        cancelVotes: [String] = []
    ) {
        self.id = id
        self.title = title
        self.meetupTime = meetupTime
        self.placeName = placeName
        self.placeAddress = placeAddress
        self.placeLatitude = placeLatitude
        self.placeLongitude = placeLongitude
        self.createdBy = createdBy
        self.creatorName = creatorName
        self.creatorEmoji = creatorEmoji
        self.createdAt = createdAt
        self.attendeeIds = attendeeIds
        self.cancelVotes = cancelVotes
    }

    /// Backward-compatible decoder (cancelVotes may not exist in old docs)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        meetupTime = try c.decode(Date.self, forKey: .meetupTime)
        placeName = try c.decode(String.self, forKey: .placeName)
        placeAddress = try c.decodeIfPresent(String.self, forKey: .placeAddress) ?? ""
        placeLatitude = try c.decode(Double.self, forKey: .placeLatitude)
        placeLongitude = try c.decode(Double.self, forKey: .placeLongitude)
        createdBy = try c.decode(String.self, forKey: .createdBy)
        creatorName = try c.decode(String.self, forKey: .creatorName)
        creatorEmoji = try c.decode(String.self, forKey: .creatorEmoji)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        attendeeIds = try c.decodeIfPresent([String].self, forKey: .attendeeIds) ?? []
        cancelVotes = try c.decodeIfPresent([String].self, forKey: .cancelVotes) ?? []
    }

    /// Number of votes needed to cancel (⌈2/3 of attendees⌉)
    var cancelVotesNeeded: Int {
        (attendeeIds.count * 2 + 2) / 3
    }

    /// Whether enough members voted to cancel
    var cancelThresholdReached: Bool {
        cancelVotes.count >= cancelVotesNeeded
    }
}

// MARK: - Meetup Member Location

struct MeetupMemberLocation: Codable, Identifiable {
    var id: String              // uid
    var displayName: String
    var avatarEmoji: String
    var approxLatitude: Double   // blurred to ~500m grid
    var approxLongitude: Double  // blurred to ~500m grid
    var sharingLocation: Bool    // whether approximate position shows on map
    var etaDrivingSeconds: Int?  // ETA by car
    var etaTransitSeconds: Int?  // ETA by public transit
    var etaWalkingSeconds: Int?  // ETA by walking
    var updatedAt: Date

    init(
        id: String,
        displayName: String,
        avatarEmoji: String,
        approxLatitude: Double,
        approxLongitude: Double,
        sharingLocation: Bool = true,
        etaDrivingSeconds: Int? = nil,
        etaTransitSeconds: Int? = nil,
        etaWalkingSeconds: Int? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.approxLatitude = approxLatitude
        self.approxLongitude = approxLongitude
        self.sharingLocation = sharingLocation
        self.etaDrivingSeconds = etaDrivingSeconds
        self.etaTransitSeconds = etaTransitSeconds
        self.etaWalkingSeconds = etaWalkingSeconds
        self.updatedAt = updatedAt
    }

    /// Backward-compatible decoder: handles old docs with exact lat/lng + single ETA
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        avatarEmoji = try c.decode(String.self, forKey: .avatarEmoji)

        // New blurred fields first, fall back to legacy exact fields
        if let lat = try c.decodeIfPresent(Double.self, forKey: .approxLatitude) {
            approxLatitude = lat
        } else {
            approxLatitude = try c.decodeIfPresent(Double.self, forKey: .legacyLatitude) ?? 0
        }
        if let lng = try c.decodeIfPresent(Double.self, forKey: .approxLongitude) {
            approxLongitude = lng
        } else {
            approxLongitude = try c.decodeIfPresent(Double.self, forKey: .legacyLongitude) ?? 0
        }

        sharingLocation = try c.decodeIfPresent(Bool.self, forKey: .sharingLocation) ?? true

        // New 3 ETAs; fall back to legacy single ETA as driving
        etaDrivingSeconds = try c.decodeIfPresent(Int.self, forKey: .etaDrivingSeconds)
            ?? (try c.decodeIfPresent(Int.self, forKey: .legacyEtaSeconds))
        etaTransitSeconds = try c.decodeIfPresent(Int.self, forKey: .etaTransitSeconds)
        etaWalkingSeconds = try c.decodeIfPresent(Int.self, forKey: .etaWalkingSeconds)

        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    private enum CodingKeys: String, CodingKey {
        case id, displayName, avatarEmoji
        case approxLatitude, approxLongitude, sharingLocation
        case etaDrivingSeconds, etaTransitSeconds, etaWalkingSeconds
        case updatedAt
        // Legacy keys for backward compatibility
        case legacyLatitude = "latitude"
        case legacyLongitude = "longitude"
        case legacyEtaSeconds = "etaSeconds"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(avatarEmoji, forKey: .avatarEmoji)
        try c.encode(approxLatitude, forKey: .approxLatitude)
        try c.encode(approxLongitude, forKey: .approxLongitude)
        try c.encode(sharingLocation, forKey: .sharingLocation)
        try c.encodeIfPresent(etaDrivingSeconds, forKey: .etaDrivingSeconds)
        try c.encodeIfPresent(etaTransitSeconds, forKey: .etaTransitSeconds)
        try c.encodeIfPresent(etaWalkingSeconds, forKey: .etaWalkingSeconds)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Project Membership (denormalized under users)

struct ProjectMembership: Codable, Identifiable {
    var id: String                          // projectId
    var projectName: String
    var projectEmoji: String
    var projectColorHex: String
    var role: ProjectRole
    var joinedAt: Date
    var isArchived: Bool

    init(
        id: String,
        projectName: String,
        projectEmoji: String,
        projectColorHex: String,
        role: ProjectRole = .member,
        joinedAt: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.projectName = projectName
        self.projectEmoji = projectEmoji
        self.projectColorHex = projectColorHex
        self.role = role
        self.joinedAt = joinedAt
        self.isArchived = isArchived
    }
}
