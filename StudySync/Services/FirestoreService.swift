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
            // 10s timeout: this is on the login-blocking path (signIn →
            // loadProfile → getUserProfile). Firestore hits googleapis.com
            // which is blocked in mainland China — without this the login
            // UI freezes for ~75s. See AsyncTimeout.swift.
            let database = self.db
            let doc = try await withTimeout(seconds: 10) {
                try await database.collection("users").document(uid).getDocument()
            }
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

    /// Push a user's updated `roles` array into every friend's cached `FriendInfo`.
    /// Firestore mirrors the user's roles into `users/{friend}/friends/{uid}.roles`
    /// so friend lists show a Pro tag without refetching. When the role changes
    /// (e.g. Pro expires), we propagate here so peers don't see stale tags.
    ///
    /// Best-effort: errors per-friend are logged but don't abort the rest.
    func propagateRolesToFriends(uid: String, roles: [String]) async {
        // 1. List our own friends
        let friendUids: [String]
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("friends").getDocuments()
            friendUids = snapshot.documents.map { $0.documentID }
        } catch {
            debugPrint("[Firestore] propagateRolesToFriends list error: \(error)")
            return
        }

        // 2. Update the cached FriendInfo in each friend's subcollection
        for friendUid in friendUids {
            do {
                try await db.collection("users").document(friendUid)
                    .collection("friends").document(uid)
                    .updateData(["roles": roles])
            } catch {
                debugPrint("[Firestore] propagate roles to \(friendUid) error: \(error)")
            }
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

    // MARK: - Study Room

    func joinStudyRoom(member: StudyRoomMember) async {
        do {
            let data = try Firestore.Encoder().encode(member)
            try await db.collection("studyRoom").document(member.id).setData(data)
        } catch {
            debugPrint("[Firestore] joinStudyRoom error: \(error)")
        }
    }

    func leaveStudyRoom(uid: String) async {
        do {
            try await db.collection("studyRoom").document(uid).delete()
        } catch {
            debugPrint("[Firestore] leaveStudyRoom error: \(error)")
        }
    }

    func listenToStudyRoom(onChange: @escaping ([StudyRoomMember]) -> Void) -> ListenerRegistration {
        return db.collection("studyRoom")
            .addSnapshotListener { snapshot, error in
                if let error {
                    debugPrint("[Firestore] listenToStudyRoom error: \(error)")
                }
                let members = snapshot?.documents.compactMap {
                    try? $0.data(as: StudyRoomMember.self)
                } ?? []
                Task { @MainActor in onChange(members) }
            }
    }

    // MARK: - Group Focus

    func createGroupFocus(room: GroupFocusRoom) async {
        do {
            try db.collection("groupFocus").document(room.id).setData(from: room)
            debugPrint("[Firestore] createGroupFocus success: \(room.id)")
        } catch {
            debugPrint("[Firestore] createGroupFocus error: \(error)")
        }
    }

    func joinGroupFocus(roomId: String, member: GroupFocusMember) async {
        do {
            let data = try Firestore.Encoder().encode(member)
            try await db.collection("groupFocus").document(roomId).updateData([
                "memberUids": FieldValue.arrayUnion([member.id]),
                "members": FieldValue.arrayUnion([data])
            ])
        } catch {
            debugPrint("[Firestore] joinGroupFocus error: \(error)")
        }
    }

    func startGroupFocus(roomId: String) async {
        do {
            try await db.collection("groupFocus").document(roomId).updateData([
                "status": "running",
                "startedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            debugPrint("[Firestore] startGroupFocus error: \(error)")
        }
    }

    func updateGroupFocusMemberStatus(roomId: String, uid: String, status: String) async {
        let ref = db.collection("groupFocus").document(roomId)
        do {
            _ = try await db.runTransaction { transaction, errorPointer in
                let doc: DocumentSnapshot
                do {
                    doc = try transaction.getDocument(ref)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                guard var room = try? doc.data(as: GroupFocusRoom.self) else { return nil }
                if let idx = room.members.firstIndex(where: { $0.id == uid }) {
                    room.members[idx].status = status
                }
                let allDone = room.members.allSatisfy { $0.status == "completed" || $0.status == "gaveUp" }
                var updates: [String: Any] = [:]
                if let membersData = try? room.members.map({ try Firestore.Encoder().encode($0) }) {
                    updates["members"] = membersData
                }
                if allDone {
                    updates["status"] = "completed"
                }
                transaction.updateData(updates, forDocument: ref)
                return nil
            }
        } catch {
            debugPrint("[Firestore] updateGroupFocusMemberStatus error: \(error)")
        }
    }

    func leaveGroupFocus(roomId: String, uid: String) async {
        let ref = db.collection("groupFocus").document(roomId)
        do {
            _ = try await db.runTransaction { transaction, errorPointer in
                let doc: DocumentSnapshot
                do {
                    doc = try transaction.getDocument(ref)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                guard var room = try? doc.data(as: GroupFocusRoom.self) else { return nil }
                room.members.removeAll { $0.id == uid }
                room.memberUids.removeAll { $0 == uid }
                if let membersData = try? room.members.map({ try Firestore.Encoder().encode($0) }) {
                    transaction.updateData([
                        "members": membersData,
                        "memberUids": room.memberUids
                    ], forDocument: ref)
                }
                return nil
            }
        } catch {
            debugPrint("[Firestore] leaveGroupFocus error: \(error)")
        }
    }

    func deleteGroupFocus(roomId: String) async {
        do {
            try await db.collection("groupFocus").document(roomId).delete()
        } catch {
            debugPrint("[Firestore] deleteGroupFocus error: \(error)")
        }
    }

    func listenToGroupFocus(roomId: String, onChange: @escaping (GroupFocusRoom?) -> Void) -> ListenerRegistration {
        return db.collection("groupFocus").document(roomId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    debugPrint("[Firestore] listenToGroupFocus error: \(error)")
                }
                guard let snapshot, snapshot.exists else {
                    Task { @MainActor in onChange(nil) }
                    return
                }
                do {
                    let room = try snapshot.data(as: GroupFocusRoom.self)
                    Task { @MainActor in onChange(room) }
                } catch {
                    debugPrint("[Firestore] listenToGroupFocus decode error: \(error)")
                    Task { @MainActor in onChange(nil) }
                }
            }
    }

    func fetchActiveGroupFocusRooms() async -> [GroupFocusRoom] {
        do {
            let snapshot = try await db.collection("groupFocus")
                .whereField("status", in: ["waiting", "running"])
                .limit(to: 20)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: GroupFocusRoom.self) }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            debugPrint("[Firestore] fetchActiveGroupFocusRooms error: \(error)")
            return []
        }
    }

    // MARK: - Account Deletion

    /// Delete ALL Firestore data associated with a user.
    /// Removes: main user doc + all subcollections (friends, friendRequests, sharedDues,
    /// availability, focusStats, etc.), studyRoom presence, and membership in groupFocus rooms.
    /// Also removes the user from OTHER users' friends subcollections (reciprocal cleanup).
    ///
    /// This runs best-effort: each cleanup step is isolated so one failure doesn't block others.
    /// Firebase Auth deletion is performed separately by the caller AFTER this completes.
    func deleteAllUserData(uid: String) async {
        // 1. Collect friend UIDs BEFORE deleting our own friends subcollection,
        //    so we can reciprocally remove ourselves from their friend lists.
        var friendUids: [String] = []
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("friends").getDocuments()
            friendUids = snapshot.documents.map { $0.documentID }
        } catch {
            debugPrint("[Firestore] deleteAllUserData list friends error: \(error)")
        }

        // 2. Remove self from each friend's friends subcollection
        for friendUid in friendUids {
            do {
                try await db.collection("users").document(friendUid)
                    .collection("friends").document(uid).delete()
            } catch {
                debugPrint("[Firestore] reciprocal friend removal error for \(friendUid): \(error)")
            }
        }

        // 3. Delete all subcollections under users/{uid}
        let subcollections = [
            "friends", "friendRequests", "sentFriendRequests",
            "sharedDues", "availability", "focusStats",
            "checkIns", "studyGoals", "countdowns", "todos",
            "projectInvites", "notifications"
        ]
        for sub in subcollections {
            await deleteSubcollection(path: "users/\(uid)/\(sub)")
        }

        // 4. Delete main user doc
        do {
            try await db.collection("users").document(uid).delete()
        } catch {
            debugPrint("[Firestore] delete main user doc error: \(error)")
        }

        // 5. Delete studyRoom presence
        do {
            try await db.collection("studyRoom").document(uid).delete()
        } catch {
            debugPrint("[Firestore] delete studyRoom error: \(error)")
        }

        // 6. Remove self from any groupFocus rooms we're in (leave but keep room alive for others)
        do {
            let snapshot = try await db.collection("groupFocus")
                .whereField("memberUids", arrayContains: uid)
                .getDocuments()
            for doc in snapshot.documents {
                await leaveGroupFocus(roomId: doc.documentID, uid: uid)
            }
        } catch {
            debugPrint("[Firestore] leave groupFocus rooms error: \(error)")
        }
    }

    /// Recursively delete all documents under a collection path.
    /// Firestore has no native "delete collection" — we must list + batch delete.
    private func deleteSubcollection(path: String) async {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count >= 3 else { return }
        // parts: ["users", uid, "subcollection"]
        let ref = db.collection(parts[0]).document(parts[1]).collection(parts[2])
        do {
            let snapshot = try await ref.getDocuments()
            // Use batched writes (Firestore limit: 500 ops per batch)
            let chunks = snapshot.documents.chunked(into: 450)
            for chunk in chunks {
                let batch = db.batch()
                for doc in chunk {
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()
            }
        } catch {
            debugPrint("[Firestore] deleteSubcollection \(path) error: \(error)")
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
