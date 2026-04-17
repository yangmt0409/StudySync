import Foundation

/// A single activity event in a team project timeline.
/// Stored at `projects/{id}/activities/{activityId}` in Firestore.
struct ProjectActivity: Codable, Identifiable {
    var id: String
    var type: ActivityType
    var actorUid: String
    var actorName: String
    var actorEmoji: String
    var detail: String          // e.g. due title, member name
    var timestamp: Date

    init(
        id: String = UUID().uuidString,
        type: ActivityType,
        actorUid: String,
        actorName: String,
        actorEmoji: String,
        detail: String = "",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.actorUid = actorUid
        self.actorName = actorName
        self.actorEmoji = actorEmoji
        self.detail = detail
        self.timestamp = timestamp
    }

    enum ActivityType: String, Codable {
        case memberJoined       = "member_joined"
        case memberLeft         = "member_left"
        case dueCreated         = "due_created"
        case dueCompleted       = "due_completed"
        case dueUncompleted     = "due_uncompleted"
        case dueAssigned        = "due_assigned"
        case dueDeleted         = "due_deleted"
        case projectCreated     = "project_created"
        case meetingStarted     = "meeting_started"
        case meetingEnded       = "meeting_ended"
        case meetupCreated      = "meetup_created"
        case meetupEnded        = "meetup_ended"

        var icon: String {
            switch self {
            case .memberJoined:     return "person.badge.plus"
            case .memberLeft:       return "person.badge.minus"
            case .dueCreated:       return "plus.circle.fill"
            case .dueCompleted:     return "checkmark.circle.fill"
            case .dueUncompleted:   return "arrow.uturn.backward.circle"
            case .dueAssigned:      return "person.crop.circle.badge.checkmark"
            case .dueDeleted:       return "trash.fill"
            case .projectCreated:   return "star.fill"
            case .meetingStarted:   return "video.fill"
            case .meetingEnded:     return "phone.down.fill"
            case .meetupCreated:    return "mappin.circle.fill"
            case .meetupEnded:      return "mappin.slash"
            }
        }

        var colorHex: String {
            switch self {
            case .memberJoined:     return "#5B7FFF"
            case .memberLeft:       return "#94A3B8"
            case .dueCreated:       return "#4ECDC4"
            case .dueCompleted:     return "#22C55E"
            case .dueUncompleted:   return "#F59E0B"
            case .dueAssigned:      return "#A78BFA"
            case .dueDeleted:       return "#EF4444"
            case .projectCreated:   return "#FFB347"
            case .meetingStarted:   return "#2D8CFF"
            case .meetingEnded:     return "#94A3B8"
            case .meetupCreated:    return "#FF6B9D"
            case .meetupEnded:      return "#94A3B8"
            }
        }

        func description(actorName: String, detail: String) -> String {
            switch self {
            case .memberJoined:     return L10n.activityMemberJoined(actorName)
            case .memberLeft:       return L10n.activityMemberLeft(actorName)
            case .dueCreated:       return L10n.activityDueCreated(actorName, detail)
            case .dueCompleted:     return L10n.activityDueCompleted(actorName, detail)
            case .dueUncompleted:   return L10n.activityDueUncompleted(actorName, detail)
            case .dueAssigned:      return L10n.activityDueAssigned(actorName, detail)
            case .dueDeleted:       return L10n.activityDueDeleted(actorName, detail)
            case .projectCreated:   return L10n.activityProjectCreated(actorName)
            case .meetingStarted:   return L10n.activityMeetingStarted(actorName)
            case .meetingEnded:     return L10n.activityMeetingEnded(actorName)
            case .meetupCreated:    return L10n.activityMeetupCreated(actorName, detail)
            case .meetupEnded:      return L10n.activityMeetupEnded(actorName)
            }
        }
    }
}
