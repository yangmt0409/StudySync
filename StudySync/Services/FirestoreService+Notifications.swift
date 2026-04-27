import Foundation
import FirebaseFirestore

extension FirestoreService {

    // MARK: - FCM Token

    func updateFCMToken(uid: String, token: String) async {
        // Bundle.main.preferredLocalizations resolves the user's language
        // preferences against the localizations we actually ship in the
        // app — so the returned identifier is always one of zh-Hans /
        // zh-Hant / en / ja / ko. Cloud Functions read this value to
        // localize push notification text (title + body) per receiver.
        // Without it, all users receive the source-language Chinese text
        // regardless of system language → Apple Guideline 4 risk.
        let locale = Bundle.main.preferredLocalizations.first ?? "zh-Hans"
        do {
            try await db.collection("users").document(uid).updateData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": Date(),
                "locale": locale
            ])
            debugPrint("[Firestore] FCM token + locale (\(locale)) updated for \(uid.prefix(8))...")
        } catch {
            debugPrint("[Firestore] updateFCMToken error: \(error)")
        }
    }

    func removeFCMToken(uid: String) async {
        do {
            try await db.collection("users").document(uid).updateData([
                "fcmToken": FieldValue.delete(),
                "fcmTokenUpdatedAt": FieldValue.delete()
            ])
        } catch {
            debugPrint("[Firestore] removeFCMToken error: \(error)")
        }
    }

    /// Get FCM tokens for a list of UIDs (for Cloud Functions to use — kept here for reference)
    func getFCMTokens(uids: [String]) async -> [String: String] {
        var tokens: [String: String] = [:]
        for uid in uids {
            do {
                let doc = try await db.collection("users").document(uid).getDocument()
                if let token = doc.data()?["fcmToken"] as? String {
                    tokens[uid] = token
                }
            } catch {
                continue
            }
        }
        return tokens
    }
}
