import UIKit
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // FCM delegate
        Messaging.messaging().delegate = self

        // Notification delegate (handle foreground display)
        UNUserNotificationCenter.current().delegate = self

        // Register interactive action buttons on reminder notifications
        NotificationManager.shared.registerCategories()

        // Register for remote notifications (APNs)
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - APNs Token → FCM

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        debugPrint("[Push] APNs token registered")
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        debugPrint("[Push] APNs registration failed: \(error.localizedDescription)")
    }

    // MARK: - Home Screen Quick Actions

    func application(_ application: UIApplication,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        switch shortcutItem.type {
        case "com.studysync.shortcut.addEvent":
            DeepLinkRouter.shared.pendingDestination = .countdown
            DeepLinkRouter.shared.pendingAddEvent = true
        case "com.studysync.shortcut.schedule":
            DeepLinkRouter.shared.pendingDestination = .schedule
        case "com.studysync.shortcut.goals":
            DeepLinkRouter.shared.pendingDestination = .studyGoal
        default:
            completionHandler(false)
            return
        }
        completionHandler(true)
    }

    // MARK: - FCM Token

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        debugPrint("[Push] FCM token received: \(token.prefix(20))...")

        Task {
            await PushNotificationService.shared.storeFCMToken(token)
        }
    }

    // MARK: - Foreground Notification Display

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }

    // MARK: - Notification Tap

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let actionID = response.actionIdentifier

        // Action-button responses on local countdown reminders
        if let idString = userInfo["eventID"] as? String,
           let eventID = UUID(uuidString: idString) {
            switch actionID {
            case NotificationManager.actionSnooze:
                let title = (response.notification.request.content.body as String?) ?? ""
                NotificationManager.shared.snooze(eventID: eventID, eventTitle: title)
                completionHandler()
                return
            case NotificationManager.actionMarkSeen:
                // Silent dismiss — just clear the badge for this event.
                UNUserNotificationCenter.current().removeDeliveredNotifications(
                    withIdentifiers: [response.notification.request.identifier]
                )
                completionHandler()
                return
            case NotificationManager.actionOpen,
                 UNNotificationDefaultActionIdentifier:
                // Fall through to deep-link routing below.
                break
            case UNNotificationDismissActionIdentifier:
                completionHandler()
                return
            default:
                break
            }
        }

        // Local countdown-event reminders carry an `eventID` — route them
        // through DeepLinkRouter so they land on EventDetailView.
        if DeepLinkRouter.shared.handleLocalNotification(userInfo: userInfo) {
            completionHandler()
            return
        }

        // Remote (FCM) payloads fall through to the social/team handler.
        PushNotificationService.shared.handleNotificationTap(userInfo: userInfo)
        completionHandler()
    }
}
