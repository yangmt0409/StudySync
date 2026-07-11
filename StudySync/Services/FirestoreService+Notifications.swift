import Foundation
import FirebaseFirestore

extension FirestoreService {

    // MARK: - FCM Token

    /// The owner-only doc that holds the FCM push token + locale. Kept out of
    /// the publicly readable `users/{uid}` doc so other authenticated clients
    /// can't harvest every user's push token. Cloud Functions read it via the
    /// Admin SDK (which bypasses security rules).
    private func pushDocRef(uid: String) -> DocumentReference {
        db.collection("users").document(uid).collection("private").document("push")
    }

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
            try await pushDocRef(uid: uid).setData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": Date(),
                "locale": locale
            ], merge: true)
            // Migrate-and-clean: strip the token/locale that older builds wrote
            // to the public user doc, so the legacy exposure is closed over time.
            try? await db.collection("users").document(uid).updateData([
                "fcmToken": FieldValue.delete(),
                "fcmTokenUpdatedAt": FieldValue.delete(),
                "locale": FieldValue.delete()
            ])
            debugPrint("[Firestore] FCM token + locale (\(locale)) updated for \(uid.prefix(8))...")
        } catch {
            debugPrint("[Firestore] updateFCMToken error: \(error)")
        }
    }

    func removeFCMToken(uid: String) async {
        do {
            try await pushDocRef(uid: uid).setData([
                "fcmToken": FieldValue.delete(),
                "fcmTokenUpdatedAt": FieldValue.delete()
            ], merge: true)
        } catch {
            debugPrint("[Firestore] removeFCMToken error: \(error)")
        }
        // Also clear any legacy fields still on the public doc.
        try? await db.collection("users").document(uid).updateData([
            "fcmToken": FieldValue.delete(),
            "fcmTokenUpdatedAt": FieldValue.delete()
        ])
    }
}
