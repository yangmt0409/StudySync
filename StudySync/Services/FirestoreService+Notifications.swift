import Foundation
import FirebaseFirestore

extension FirestoreService {

    // MARK: - FCM Token

    func updateFCMToken(uid: String, token: String) async {
        do {
            try await db.collection("users").document(uid).updateData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": Date()
            ])
            debugPrint("[Firestore] FCM token updated for \(uid.prefix(8))...")
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
