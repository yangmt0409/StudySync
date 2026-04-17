import Foundation
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

@Observable
final class PushNotificationService {
    static let shared = PushNotificationService()

    /// Set when user taps a push notification — views observe this to navigate
    var pendingNavigation: PushNavigation?

    private let firestore = FirestoreService.shared

    private init() {}

    // MARK: - Permission

    func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted == true {
                debugPrint("[Push] Permission granted")
            }
        case .authorized, .provisional, .ephemeral:
            break
        case .denied:
            debugPrint("[Push] Permission denied by user")
        @unknown default:
            break
        }
    }

    // MARK: - Token Management

    func storeFCMToken(_ token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        await firestore.updateFCMToken(uid: uid, token: token)
    }

    /// Call on login to ensure token is fresh
    func refreshToken() async {
        do {
            let token = try await Messaging.messaging().token()
            await storeFCMToken(token)
            debugPrint("[Push] Token refreshed")
        } catch {
            debugPrint("[Push] Token refresh error: \(error.localizedDescription)")
        }
    }

    /// Call on logout to remove token
    func clearToken() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        await firestore.removeFCMToken(uid: uid)
        debugPrint("[Push] Token cleared")
    }

    // MARK: - Handle Notification Tap

    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let typeString = userInfo["type"] as? String else { return }

        let type = PushNotificationType(rawValue: typeString) ?? .general
        let projectId = userInfo["projectId"] as? String
        let dueId = userInfo["dueId"] as? String

        debugPrint("[Push] Tapped notification: type=\(type), projectId=\(projectId ?? "nil")")

        pendingNavigation = PushNavigation(
            type: type,
            projectId: projectId,
            dueId: dueId
        )

        // Switch to Social tab for social-related notifications
        switch type {
        case .friendRequest, .projectInvite, .dueCreated, .dueCompleted, .memberJoined, .nudgeReceived, .ringNudgeReceived, .ringNudgeDelivered:
            NotificationCenter.default.post(name: .init("switchToSocialTab"), object: nil)
        default:
            break
        }
    }

    func clearNavigation() {
        pendingNavigation = nil
    }
}

// MARK: - Types

struct PushNavigation: Equatable {
    let type: PushNotificationType
    let projectId: String?
    let dueId: String?
}

enum PushNotificationType: String, Equatable {
    case dueCreated = "due_created"
    case dueCompleted = "due_completed"
    case projectInvite = "project_invite"
    case friendRequest = "friend_request"
    case deadlineApproaching = "deadline_approaching"
    case deadlineOverdue = "deadline_overdue"
    case memberJoined = "member_joined"
    case nudgeReceived = "nudge_received"
    case ringNudgeReceived = "ring_nudge_received"
    case ringNudgeDelivered = "ring_nudge_delivered"
    case general
}
