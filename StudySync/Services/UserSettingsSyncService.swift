import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Firestore sync for UserSettings (singleton-style).
///
/// Layout: users/{uid}/settings/profile
///
/// Stored as a single doc since there's only ever one UserSettings per user.
final class UserSettingsSyncService {
    static let shared = UserSettingsSyncService()

    private let db = Firestore.firestore()
    private init() {}

    private var uid: String? { AuthService.shared.currentUser?.uid }

    private func docRef(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid).collection("settings").document("profile")
    }

    // MARK: - Push

    func pushSettings(_ settings: UserSettings) {
        guard let uid else { return }
        let data: [String: Any] = [
            "homeTimeZoneId": settings.homeTimeZoneId,
            "studyTimeZoneId": settings.studyTimeZoneId,
            "homeCityName": settings.homeCityName,
            "studyCityName": settings.studyCityName,
            "showExpiredEvents": settings.showExpiredEvents,
            "defaultCategoryRaw": settings.defaultCategoryRaw,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        Task {
            do {
                try await docRef(uid).setData(data, merge: true)
            } catch {
                debugPrint("[UserSettingsSync] pushSettings error: \(error)")
            }
        }
    }

    // MARK: - Pull

    @MainActor
    func pullSettings(context: ModelContext) async {
        guard let uid else { return }

        do {
            let snapshot = try await docRef(uid).getDocument()
            guard let data = snapshot.data() else { return }

            let locals = (try? context.fetch(FetchDescriptor<UserSettings>())) ?? []
            let target: UserSettings
            if let existing = locals.first {
                target = existing
            } else {
                let newSettings = UserSettings()
                context.insert(newSettings)
                target = newSettings
            }

            if let v = data["homeTimeZoneId"] as? String { target.homeTimeZoneId = v }
            if let v = data["studyTimeZoneId"] as? String { target.studyTimeZoneId = v }
            if let v = data["homeCityName"] as? String { target.homeCityName = v }
            if let v = data["studyCityName"] as? String { target.studyCityName = v }
            if let v = data["showExpiredEvents"] as? Bool { target.showExpiredEvents = v }
            if let v = data["defaultCategoryRaw"] as? String { target.defaultCategoryRaw = v }

            try? context.save()
            debugPrint("[UserSettingsSync] ✅ pulled settings from Firestore")
        } catch {
            debugPrint("[UserSettingsSync] pullSettings error: \(error)")
        }
    }
}
