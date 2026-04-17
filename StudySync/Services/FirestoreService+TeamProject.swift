import Foundation
import FirebaseFirestore

extension FirestoreService {

    // MARK: - Project CRUD

    /// Create a new project. Returns the project ID on success.
    func createProject(_ project: TeamProject) async -> String? {
        let ref = db.collection("projects").document(project.id)
        do {
            try ref.setData(from: project)

            // Add membership to creator
            let membership = ProjectMembership(
                id: project.id,
                projectName: project.name,
                projectEmoji: project.emoji,
                projectColorHex: project.colorHex,
                role: .owner,
                joinedAt: project.createdAt
            )
            try db.collection("users").document(project.createdBy)
                .collection("projectMemberships").document(project.id)
                .setData(from: membership)

            return project.id
        } catch {
            debugPrint("[Firestore] createProject error: \(error)")
            return nil
        }
    }

    func getProject(projectId: String) async -> TeamProject? {
        do {
            let doc = try await db.collection("projects").document(projectId).getDocument()
            return try doc.data(as: TeamProject.self)
        } catch {
            return nil
        }
    }

    func getMyProjects(uid: String) async -> [TeamProject] {
        do {
            // Note: avoid .order(by:) with array-contains to skip composite index requirement
            let snapshot = try await db.collection("projects")
                .whereField("memberIds", arrayContains: uid)
                .limit(to: 200).getDocuments()
            let all = snapshot.documents.compactMap { try? $0.data(as: TeamProject.self) }
            return all
                .filter { !$0.isArchived }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            debugPrint("[Firestore] getMyProjects error: \(error)")
            return []
        }
    }

    func getMyArchivedProjects(uid: String) async -> [TeamProject] {
        do {
            let snapshot = try await db.collection("projects")
                .whereField("memberIds", arrayContains: uid)
                .limit(to: 200).getDocuments()
            let all = snapshot.documents.compactMap { try? $0.data(as: TeamProject.self) }
            return all
                .filter { $0.isArchived }
                .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
        } catch {
            debugPrint("[Firestore] getMyArchivedProjects error: \(error)")
            return []
        }
    }

    // MARK: - Join by Code

    func findProjectByCode(_ code: String) async -> TeamProject? {
        do {
            let snapshot = try await db.collection("projects")
                .whereField("projectCode", isEqualTo: code.uppercased())
                .whereField("isArchived", isEqualTo: false)
                .limit(to: 1)
                .getDocuments()
            return try snapshot.documents.first?.data(as: TeamProject.self)
        } catch {
            return nil
        }
    }

    func joinProject(projectId: String, member: ProjectMember) async -> Bool {
        let projectRef = db.collection("projects").document(projectId)
        let membershipRef = db.collection("users").document(member.id)
            .collection("projectMemberships").document(projectId)

        do {
            let doc = try await projectRef.getDocument()
            let project = try doc.data(as: TeamProject.self)

            // Already a member?
            if project.memberIds.contains(member.id) {
                debugPrint("[Firestore] joinProject: already a member")
                return false
            }

            let memberData = try Firestore.Encoder().encode(member)
            let membership = ProjectMembership(
                id: projectId,
                projectName: project.name,
                projectEmoji: project.emoji,
                projectColorHex: project.colorHex,
                role: .member,
                joinedAt: Date()
            )
            let membershipData = try Firestore.Encoder().encode(membership)

            let batch = db.batch()

            batch.updateData([
                "memberIds": FieldValue.arrayUnion([member.id]),
                "memberProfiles": FieldValue.arrayUnion([memberData])
            ], forDocument: projectRef)

            batch.setData(membershipData, forDocument: membershipRef)

            try await batch.commit()
            debugPrint("[Firestore] joinProject: success for \(projectId)")
            return true
        } catch {
            debugPrint("[Firestore] joinProject error: \(error)")
            return false
        }
    }

    func leaveProject(projectId: String, uid: String) async {
        let projectRef = db.collection("projects").document(projectId)
        let membershipRef = db.collection("users").document(uid)
            .collection("projectMemberships").document(projectId)

        do {
            let doc = try await projectRef.getDocument()
            guard var project = try? doc.data(as: TeamProject.self) else { return }

            // Remove from arrays
            project.memberIds.removeAll { $0 == uid }
            let updatedProfiles = project.memberProfiles.filter { $0.id != uid }

            let batch = db.batch()
            batch.updateData([
                "memberIds": project.memberIds,
                "memberProfiles": try Firestore.Encoder().encode(updatedProfiles)
            ], forDocument: projectRef)
            batch.deleteDocument(membershipRef)

            try await batch.commit()
        } catch {
            debugPrint("[Firestore] leaveProject error: \(error)")
        }
    }

    // MARK: - Archive / Delete

    func archiveProject(projectId: String, memberIds: [String]) async {
        let projectRef = db.collection("projects").document(projectId)
        let batch = db.batch()

        batch.updateData([
            "isArchived": true,
            "archivedAt": Date()
        ], forDocument: projectRef)

        // Update all members' memberships
        for uid in memberIds {
            let ref = db.collection("users").document(uid)
                .collection("projectMemberships").document(projectId)
            batch.updateData(["isArchived": true], forDocument: ref)
        }

        do {
            try await batch.commit()
        } catch {
            debugPrint("[Firestore] archiveProject error: \(error)")
        }
    }

    func deleteProject(projectId: String, memberIds: [String]) async {
        let batch = db.batch()

        // Delete project doc
        batch.deleteDocument(db.collection("projects").document(projectId))

        // Delete all members' memberships
        for uid in memberIds {
            let ref = db.collection("users").document(uid)
                .collection("projectMemberships").document(projectId)
            batch.deleteDocument(ref)
        }

        do {
            // Delete all dues first
            let duesSnapshot = try await db.collection("projects").document(projectId)
                .collection("dues").limit(to: 500).getDocuments()
            for doc in duesSnapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        } catch {
            debugPrint("[Firestore] deleteProject error: \(error)")
        }
    }

    // MARK: - Project Invites

    func sendProjectInvite(to uid: String, invite: ProjectInvite) async -> Bool {
        do {
            try db.collection("users").document(uid)
                .collection("projectInvites").document(invite.id)
                .setData(from: invite)
            return true
        } catch {
            debugPrint("[Firestore] sendProjectInvite error: \(error)")
            return false
        }
    }

    func getProjectInvites(uid: String) async -> [ProjectInvite] {
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("projectInvites")
                .order(by: "createdAt", descending: true)
                .limit(to: 100).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: ProjectInvite.self) }
        } catch {
            return []
        }
    }

    func deleteProjectInvite(uid: String, inviteId: String) async {
        do {
            try await db.collection("users").document(uid)
                .collection("projectInvites").document(inviteId)
                .delete()
        } catch {
            debugPrint("[Firestore] deleteProjectInvite error: \(error)")
        }
    }

    // MARK: - Project Dues

    func createProjectDue(projectId: String, due: ProjectDue) async -> String? {
        let ref = db.collection("projects").document(projectId)
            .collection("dues").document(due.id)
        do {
            try ref.setData(from: due)
            return due.id
        } catch {
            debugPrint("[Firestore] createProjectDue error: \(error)")
            return nil
        }
    }

    func updateProjectDue(projectId: String, dueId: String, fields: [String: Any]) async {
        do {
            try await db.collection("projects").document(projectId)
                .collection("dues").document(dueId)
                .updateData(fields)
        } catch {
            debugPrint("[Firestore] updateProjectDue error: \(error)")
        }
    }

    func toggleProjectDueCompletion(projectId: String, due: ProjectDue, completedByUid: String) async {
        let newCompleted = !due.isCompleted
        var fields: [String: Any] = [
            "isCompleted": newCompleted
        ]
        if newCompleted {
            fields["completedBy"] = completedByUid
            fields["completedAt"] = Date()
        } else {
            fields["completedBy"] = NSNull()
            fields["completedAt"] = NSNull()
        }
        await updateProjectDue(projectId: projectId, dueId: due.id, fields: fields)
    }

    func deleteProjectDue(projectId: String, dueId: String) async {
        do {
            try await db.collection("projects").document(projectId)
                .collection("dues").document(dueId)
                .delete()
        } catch {
            debugPrint("[Firestore] deleteProjectDue error: \(error)")
        }
    }

    func getProjectDues(projectId: String) async -> [ProjectDue] {
        do {
            let snapshot = try await db.collection("projects").document(projectId)
                .collection("dues")
                .order(by: "dueDate")
                .limit(to: 500).getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: ProjectDue.self) }
        } catch {
            return []
        }
    }

    /// Get all dues assigned to a specific user across all their active projects
    func getMyDuesAcrossProjects(uid: String) async -> [(ProjectDue, TeamProject)] {
        var result: [(ProjectDue, TeamProject)] = []

        let projects = await getMyProjects(uid: uid)
        for project in projects {
            let dues = await getProjectDues(projectId: project.id)
            let myDues = dues.filter { $0.isAssigned(to: uid) && !$0.isCompleted }
            for due in myDues {
                result.append((due, project))
            }
        }

        return result.sorted { $0.0.dueDate < $1.0.dueDate }
    }

    // MARK: - Quick Meeting

    func startMeeting(projectId: String, meeting: ActiveMeeting) async {
        do {
            let data = try Firestore.Encoder().encode(meeting)
            try await db.collection("projects").document(projectId)
                .updateData(["activeMeeting": data])
        } catch {
            debugPrint("[Firestore] startMeeting error: \(error)")
        }
    }

    func endMeeting(projectId: String) async {
        do {
            try await db.collection("projects").document(projectId)
                .updateData(["activeMeeting": FieldValue.delete()])
        } catch {
            debugPrint("[Firestore] endMeeting error: \(error)")
        }
    }

    // MARK: - Meetup Session

    func createMeetup(projectId: String, meetup: MeetupSession) async {
        do {
            let data = try Firestore.Encoder().encode(meetup)
            try await db.collection("projects").document(projectId)
                .updateData(["activeMeetup": data])
        } catch {
            debugPrint("[Firestore] createMeetup error: \(error)")
        }
    }

    func endMeetup(projectId: String) async {
        do {
            try await db.collection("projects").document(projectId)
                .updateData(["activeMeetup": FieldValue.delete()])
            // Clean up location docs
            let locSnap = try await db.collection("projects").document(projectId)
                .collection("meetupLocations").limit(to: 200).getDocuments()
            let batch = db.batch()
            for doc in locSnap.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        } catch {
            debugPrint("[Firestore] endMeetup error: \(error)")
        }
    }

    func updateMeetupDetails(projectId: String, title: String, meetupTime: Date, placeName: String, placeAddress: String, latitude: Double, longitude: Double) async {
        do {
            try await db.collection("projects").document(projectId)
                .updateData([
                    "activeMeetup.title": title,
                    "activeMeetup.meetupTime": meetupTime,
                    "activeMeetup.placeName": placeName,
                    "activeMeetup.placeAddress": placeAddress,
                    "activeMeetup.placeLatitude": latitude,
                    "activeMeetup.placeLongitude": longitude
                ])
        } catch {
            debugPrint("[Firestore] updateMeetupDetails error: \(error)")
        }
    }

    func voteCancelMeetup(projectId: String, uid: String) async {
        do {
            try await db.collection("projects").document(projectId)
                .updateData(["activeMeetup.cancelVotes": FieldValue.arrayUnion([uid])])
        } catch {
            debugPrint("[Firestore] voteCancelMeetup error: \(error)")
        }
    }

    func joinMeetup(projectId: String, uid: String) async {
        do {
            try await db.collection("projects").document(projectId)
                .updateData(["activeMeetup.attendeeIds": FieldValue.arrayUnion([uid])])
        } catch {
            debugPrint("[Firestore] joinMeetup error: \(error)")
        }
    }

    func updateMeetupLocation(projectId: String, location: MeetupMemberLocation) async {
        do {
            let data = try Firestore.Encoder().encode(location)
            try await db.collection("projects").document(projectId)
                .collection("meetupLocations").document(location.id)
                .setData(data)
        } catch {
            debugPrint("[Firestore] updateMeetupLocation error: \(error)")
        }
    }

    func listenToMeetupLocations(projectId: String, onChange: @escaping ([MeetupMemberLocation]) -> Void) -> ListenerRegistration {
        return db.collection("projects").document(projectId)
            .collection("meetupLocations")
            .addSnapshotListener { snapshot, _ in
                let locations = snapshot?.documents.compactMap {
                    try? $0.data(as: MeetupMemberLocation.self)
                } ?? []
                Task { @MainActor in onChange(locations) }
            }
    }

    // MARK: - Activity Log

    func logActivity(projectId: String, activity: ProjectActivity) async {
        do {
            let data = try Firestore.Encoder().encode(activity)
            try await db.collection("projects").document(projectId)
                .collection("activities").document(activity.id)
                .setData(data)
        } catch {
            debugPrint("[Firestore] logActivity error: \(error)")
        }
    }

    func getActivities(projectId: String, limit: Int = 50) async -> [ProjectActivity] {
        do {
            let snapshot = try await db.collection("projects").document(projectId)
                .collection("activities")
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: ProjectActivity.self) }
        } catch {
            debugPrint("[Firestore] getActivities error: \(error)")
            return []
        }
    }

    func listenToActivities(projectId: String, limit: Int = 30, onChange: @escaping ([ProjectActivity]) -> Void) -> ListenerRegistration {
        return db.collection("projects").document(projectId)
            .collection("activities")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, _ in
                let activities = snapshot?.documents.compactMap { try? $0.data(as: ProjectActivity.self) } ?? []
                Task { @MainActor in onChange(activities) }
            }
    }

    // MARK: - Snapshot Listeners

    func listenToProjectDues(projectId: String, onChange: @escaping ([ProjectDue]) -> Void) -> ListenerRegistration {
        return db.collection("projects").document(projectId)
            .collection("dues")
            .order(by: "dueDate")
            .limit(to: 500)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                let dues = docs.compactMap { try? $0.data(as: ProjectDue.self) }
                Task { @MainActor in onChange(dues) }
            }
    }

    func listenToProject(projectId: String, onChange: @escaping (TeamProject?) -> Void) -> ListenerRegistration {
        return db.collection("projects").document(projectId)
            .addSnapshotListener { snapshot, error in
                guard let doc = snapshot else {
                    Task { @MainActor in onChange(nil) }
                    return
                }
                let project = try? doc.data(as: TeamProject.self)
                Task { @MainActor in onChange(project) }
            }
    }
}
