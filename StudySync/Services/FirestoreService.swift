import Foundation
import FirebaseFirestore

final class FirestoreService {
    static let shared = FirestoreService()
    let db = Firestore.firestore()

    private init() {}

    // MARK: - User Profile

    func createUserProfile(_ profile: UserProfile) async {
        do {
            try db.collection("users").document(profile.id).setData(from: profile)
        } catch {
            debugPrint("[Firestore] createUserProfile error: \(error)")
        }
    }

    func getUserProfile(uid: String) async -> UserProfile? {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            return try doc.data(as: UserProfile.self)
        } catch {
            return nil
        }
    }

    func updateProfile(uid: String, fields: [String: Any]) async {
        do {
            try await db.collection("users").document(uid).updateData(fields)
        } catch {
            debugPrint("[Firestore] updateProfile error: \(error)")
        }
    }

    func updateShareEnabled(uid: String, enabled: Bool) async {
        await updateProfile(uid: uid, fields: ["shareEnabled": enabled])
    }

    func updateShareAvailability(uid: String, enabled: Bool) async {
        await updateProfile(uid: uid, fields: ["shareAvailability": enabled])
    }

    func updateAllowNudges(uid: String, allowed: Bool) async {
        await updateProfile(uid: uid, fields: ["allowNudges": allowed])
    }

    // MARK: - Nudge (拍一拍)

    /// Send a nudge to a friend. Writes to their `nudges` subcollection.
    /// Cloud Functions will pick up the write and send a push notification.
    func sendNudge(from senderUid: String, to receiverUid: String, senderName: String, senderEmoji: String) async -> Bool {
        let data: [String: Any] = [
            "fromUid": senderUid,
            "fromName": senderName,
            "fromEmoji": senderEmoji,
            "createdAt": FieldValue.serverTimestamp()
        ]
        do {
            try await db.collection("users").document(receiverUid)
                .collection("nudges").addDocument(data: data)
            return true
        } catch {
            debugPrint("[Firestore] sendNudge error: \(error)")
            return false
        }
    }

    // MARK: - Ring Nudge (响铃拍一拍)

    /// Update per-friend ring nudge permission.
    /// Stored in MY friends subcollection: users/{myUid}/friends/{friendUid}
    func updateAllowRingNudge(myUid: String, friendUid: String, allowed: Bool) async {
        do {
            try await db.collection("users").document(myUid)
                .collection("friends").document(friendUid)
                .updateData(["allowRingNudge": allowed])
        } catch {
            debugPrint("[Firestore] updateAllowRingNudge error: \(error)")
        }
    }

    /// Check if the target has allowed the sender to ring-nudge them.
    /// Reads: users/{targetUid}/friends/{senderUid}.allowRingNudge
    func checkRingNudgePermission(targetUid: String, senderUid: String) async -> Bool {
        do {
            let doc = try await db.collection("users").document(targetUid)
                .collection("friends").document(senderUid)
                .getDocument()
            return doc.data()?["allowRingNudge"] as? Bool ?? false
        } catch {
            return false
        }
    }

    /// Send a ring nudge. Writes to target's `ringNudges` subcollection.
    /// Cloud Functions sends a critical push + rings the phone,
    /// then sends a confirmation push back to the sender.
    func sendRingNudge(from senderUid: String, to receiverUid: String, senderName: String, senderEmoji: String) async -> Bool {
        let data: [String: Any] = [
            "fromUid": senderUid,
            "fromName": senderName,
            "fromEmoji": senderEmoji,
            "createdAt": FieldValue.serverTimestamp()
        ]
        do {
            try await db.collection("users").document(receiverUid)
                .collection("ringNudges").addDocument(data: data)
            return true
        } catch {
            debugPrint("[Firestore] sendRingNudge error: \(error)")
            return false
        }
    }

    /// Read raw friend document data (for checking per-friend fields like allowRingNudge).
    func getFriendDoc(myUid: String, friendUid: String) async -> [String: Any]? {
        do {
            let doc = try await db.collection("users").document(myUid)
                .collection("friends").document(friendUid)
                .getDocument()
            return doc.data()
        } catch {
            return nil
        }
    }

    func updateStats(uid: String, totalCheckIns: Int, longestStreak: Int) async {
        await updateProfile(uid: uid, fields: [
            "totalCheckIns": totalCheckIns,
            "longestStreak": longestStreak
        ])
    }

    // MARK: - Friend Code Lookup

    func findUserByFriendCode(_ code: String) async -> UserProfile? {
        do {
            let snapshot = try await db.collection("users")
                .whereField("friendCode", isEqualTo: code.uppercased())
                .limit(to: 1)
                .getDocuments()
            return try snapshot.documents.first?.data(as: UserProfile.self)
        } catch {
            return nil
        }
    }

    // MARK: - Friend Requests

    func sendFriendRequest(from sender: UserProfile, to receiverUid: String) async -> Bool {
        let request = FriendRequest(
            fromUid: sender.id,
            fromName: sender.displayName,
            fromEmoji: sender.avatarEmoji,
            createdAt: Date()
        )
        do {
            try db.collection("users").document(receiverUid)
                .collection("friendRequests").document(sender.id)
                .setData(from: request)
            return true
        } catch {
            debugPrint("[Firestore] sendFriendRequest error: \(error)")
            return false
        }
    }

    func getFriendRequests(uid: String) async -> [FriendRequest] {
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("friendRequests")
                .limit(to: 200).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: FriendRequest.self) }
        } catch {
            return []
        }
    }

    func acceptFriendRequest(myUid: String, myProfile: UserProfile, request: FriendRequest) async {
        let batch = db.batch()

        // Fetch the requester's full profile for roles/stats
        let requesterProfile = await getUserProfile(uid: request.fromUid)

        // Add friend to my list
        let myFriendRef = db.collection("users").document(myUid)
            .collection("friends").document(request.fromUid)
        let myFriend = FriendInfo(
            id: request.fromUid,
            displayName: request.fromName,
            avatarEmoji: request.fromEmoji,
            shareEnabled: requesterProfile?.shareEnabled ?? false,
            allowNudges: requesterProfile?.allowNudges ?? true,
            showcaseBadges: requesterProfile?.showcaseBadges ?? [],
            roles: requesterProfile?.roles ?? [],
            addedAt: Date(),
            totalCheckIns: requesterProfile?.totalCheckIns ?? 0,
            longestStreak: requesterProfile?.longestStreak ?? 0
        )
        if let data = try? Firestore.Encoder().encode(myFriend) {
            batch.setData(data, forDocument: myFriendRef)
        }

        // Add me to their friend list
        let theirFriendRef = db.collection("users").document(request.fromUid)
            .collection("friends").document(myUid)
        let theirFriend = FriendInfo(
            id: myUid,
            displayName: myProfile.displayName,
            avatarEmoji: myProfile.avatarEmoji,
            shareEnabled: myProfile.shareEnabled,
            allowNudges: myProfile.allowNudges,
            showcaseBadges: myProfile.showcaseBadges,
            roles: myProfile.roles,
            addedAt: Date(),
            totalCheckIns: myProfile.totalCheckIns,
            longestStreak: myProfile.longestStreak
        )
        if let data = try? Firestore.Encoder().encode(theirFriend) {
            batch.setData(data, forDocument: theirFriendRef)
        }

        // Remove the request
        let requestRef = db.collection("users").document(myUid)
            .collection("friendRequests").document(request.fromUid)
        batch.deleteDocument(requestRef)

        do {
            try await batch.commit()
        } catch {
            debugPrint("[Firestore] acceptFriendRequest error: \(error)")
        }
    }

    func rejectFriendRequest(myUid: String, fromUid: String) async {
        do {
            try await db.collection("users").document(myUid)
                .collection("friendRequests").document(fromUid)
                .delete()
        } catch {
            debugPrint("[Firestore] rejectFriendRequest error: \(error)")
        }
    }

    // MARK: - Friends List

    func getFriends(uid: String) async -> [FriendInfo] {
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("friends")
                .limit(to: 500).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: FriendInfo.self) }
        } catch {
            return []
        }
    }

    func removeFriend(myUid: String, friendUid: String) async {
        let batch = db.batch()
        batch.deleteDocument(
            db.collection("users").document(myUid).collection("friends").document(friendUid)
        )
        batch.deleteDocument(
            db.collection("users").document(friendUid).collection("friends").document(myUid)
        )
        do {
            try await batch.commit()
        } catch {
            debugPrint("[Firestore] removeFriend error: \(error)")
        }
    }

    // MARK: - Shared Dues

    /// Full-replace sync (legacy). Prefer `syncDuesIncremental` for safer concurrent writes.
    func syncDues(uid: String, dues: [SharedDue]) async {
        let collectionRef = db.collection("users").document(uid).collection("sharedDues")

        // Clear existing, re-upload
        do {
            let existing = try await collectionRef.limit(to: 500).getDocuments()
            let batch = db.batch()
            for doc in existing.documents {
                batch.deleteDocument(doc.reference)
            }
            for due in dues {
                let ref = collectionRef.document(due.id)
                if let data = try? Firestore.Encoder().encode(due) {
                    batch.setData(data, forDocument: ref)
                }
            }
            try await batch.commit()
        } catch {
            debugPrint("[Firestore] syncDues error: \(error)")
        }
    }

    /// Incremental diff-based sync: only creates/updates/deletes what changed.
    /// Safe for concurrent calls — no full-collection wipe.
    func syncDuesIncremental(uid: String, currentDues: [SharedDue]) async {
        let collectionRef = db.collection("users").document(uid).collection("sharedDues")
        do {
            // Fetch remote IDs
            let snapshot = try await collectionRef.limit(to: 500).getDocuments()
            let remoteIds = Set(snapshot.documents.map(\.documentID))
            let localIds = Set(currentDues.map(\.id))

            let batch = db.batch()

            // Upsert: create or update local dues
            for due in currentDues {
                let ref = collectionRef.document(due.id)
                if let data = try? Firestore.Encoder().encode(due) {
                    batch.setData(data, forDocument: ref, merge: true)
                }
            }

            // Delete: remote docs that no longer exist locally
            for remoteId in remoteIds where !localIds.contains(remoteId) {
                batch.deleteDocument(collectionRef.document(remoteId))
            }

            try await batch.commit()
        } catch {
            debugPrint("[Firestore] syncDuesIncremental error: \(error)")
        }
    }

    /// Upsert a single shared due.
    func upsertSharedDue(uid: String, due: SharedDue) async {
        do {
            try db.collection("users").document(uid)
                .collection("sharedDues").document(due.id)
                .setData(from: due, merge: true)
        } catch {
            debugPrint("[Firestore] upsertSharedDue error: \(error)")
        }
    }

    /// Delete a single shared due.
    func deleteSharedDue(uid: String, dueId: String) async {
        do {
            try await db.collection("users").document(uid)
                .collection("sharedDues").document(dueId)
                .delete()
        } catch {
            debugPrint("[Firestore] deleteSharedDue error: \(error)")
        }
    }

    func getFriendDues(friendUid: String) async -> [SharedDue] {
        do {
            let snapshot = try await db.collection("users").document(friendUid)
                .collection("sharedDues")
                .order(by: "endDate")
                .limit(to: 100).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: SharedDue.self) }
        } catch {
            return []
        }
    }

    // MARK: - Badges

    func awardBadge(uid: String, badgeId: String) async {
        do {
            try await db.collection("users").document(uid).updateData([
                "badges": FieldValue.arrayUnion([badgeId])
            ])
        } catch {
            debugPrint("[Firestore] awardBadge error: \(error)")
        }
    }

    // MARK: - User Roles

    func addRole(uid: String, role: String) async {
        do {
            try await db.collection("users").document(uid).updateData([
                "roles": FieldValue.arrayUnion([role])
            ])
        } catch {
            debugPrint("[Firestore] addRole error: \(error)")
        }
    }

    func removeRole(uid: String, role: String) async {
        do {
            try await db.collection("users").document(uid).updateData([
                "roles": FieldValue.arrayRemove([role])
            ])
        } catch {
            debugPrint("[Firestore] removeRole error: \(error)")
        }
    }

    /// Sync Pro subscription status to Firestore role.
    func syncProRole(uid: String, isPro: Bool) async {
        if isPro {
            await addRole(uid: uid, role: UserRole.pro.rawValue)
        } else {
            await removeRole(uid: uid, role: UserRole.pro.rawValue)
        }
    }

    // MARK: - Availability Timeline

    /// Fetch a single day's availability slots for a user.
    func getAvailability(uid: String, dateString: String) async -> String? {
        do {
            let doc = try await db.collection("users").document(uid)
                .collection("availability").document(dateString).getDocument()
            return doc.data()?["slots"] as? String
        } catch {
            return nil
        }
    }

    /// Batch-fetch a week of availability (7 days).
    func getWeekAvailability(uid: String, dates: [String]) async -> [String: String] {
        var result: [String: String] = [:]
        await withTaskGroup(of: (String, String?).self) { group in
            for dateStr in dates {
                group.addTask {
                    let slots = await self.getAvailability(uid: uid, dateString: dateStr)
                    return (dateStr, slots)
                }
            }
            for await (dateStr, slots) in group {
                if let slots { result[dateStr] = slots }
            }
        }
        return result
    }

    /// Save a single day's availability slots.
    func saveAvailability(uid: String, dateString: String, slots: String) async {
        do {
            try await db.collection("users").document(uid)
                .collection("availability").document(dateString)
                .setData([
                    "slots": slots,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
        } catch {
            debugPrint("[Firestore] saveAvailability error: \(error)")
        }
    }

    /// Delete a single day's availability document (for cleanup).
    func deleteAvailability(uid: String, dateString: String) async {
        do {
            try await db.collection("users").document(uid)
                .collection("availability").document(dateString)
                .delete()
        } catch {
            debugPrint("[Firestore] deleteAvailability error: \(error)")
        }
    }
}
