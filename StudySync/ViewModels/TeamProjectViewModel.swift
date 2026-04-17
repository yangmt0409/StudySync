import Foundation
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

@Observable
final class TeamProjectViewModel {
    // MARK: - State

    var myProjects: [TeamProject] = []
    var archivedProjects: [TeamProject] = []
    var currentProject: TeamProject?
    var currentDues: [ProjectDue] = []
    var projectInvites: [ProjectInvite] = []

    var activities: [ProjectActivity] = []

    var isLoading = false
    var errorMessage: String?
    var toastMessage: String?

    // Sheets
    var showingCreateProject = false
    var showingPaywall = false
    var showingJoinProject = false
    var showingAddDue = false
    var showingInviteFriend = false
    var showingProjectSettings = false
    var showingArchivedProjects = false
    var showingStartMeeting = false
    var showingEndMeeting = false
    var showingCreateMeetup = false
    var showingEditMeetup = false
    var showingEndMeetup = false

    // Meetup
    var meetupLocations: [MeetupMemberLocation] = []

    // Filter
    var dueFilter: DueFilter = .all

    // MARK: - Private

    private let firestore = FirestoreService.shared
    private let auth = AuthService.shared
    private var duesListener: ListenerRegistration?
    private var projectListener: ListenerRegistration?
    private var activitiesListener: ListenerRegistration?
    private var meetupLocationsListener: ListenerRegistration?

    enum DueFilter: String, CaseIterable {
        case all
        case mine
        case open

        var displayName: String {
            switch self {
            case .all: return L10n.projectDueAll
            case .mine: return L10n.projectDueMine
            case .open: return L10n.projectDueOpen
            }
        }
    }

    // MARK: - Computed

    var filteredDues: [ProjectDue] {
        let uid = auth.currentUser?.uid ?? ""
        switch dueFilter {
        case .all:
            return currentDues
        case .mine:
            return currentDues.filter { $0.isAssigned(to: uid) }
        case .open:
            return currentDues.filter { !$0.isCompleted }
        }
    }

    var completedDueCount: Int {
        currentDues.filter(\.isCompleted).count
    }

    var totalDueCount: Int {
        currentDues.count
    }

    /// Free users may own at most `freeOwnedProjectLimit` active projects at
    /// once. Joined projects owned by other users don't count against this.
    static let freeOwnedProjectLimit = 1

    private var ownedActiveProjectCount: Int {
        let uid = auth.currentUser?.uid ?? ""
        return myProjects.filter { $0.createdBy == uid }.count
    }

    var canCreateProject: Bool {
        StoreManager.shared.isPro || ownedActiveProjectCount < Self.freeOwnedProjectLimit
    }

    /// Call from "+ Create project" entry points. Opens the sheet if allowed,
    /// otherwise surfaces Paywall.
    func tryCreateProject() {
        if canCreateProject {
            showingCreateProject = true
        } else {
            showingPaywall = true
        }
    }

    var nextDeadlineDays: Int? {
        currentDues
            .filter { !$0.isCompleted }
            .map(\.daysRemaining)
            .min()
    }

    // MARK: - Load

    func loadProjects() async {
        guard let uid = auth.currentUser?.uid else {
            debugPrint("[TeamProject] loadProjects: no currentUser")
            return
        }
        isLoading = true
        defer { isLoading = false }

        debugPrint("[TeamProject] loadProjects for uid: \(uid)")
        myProjects = await firestore.getMyProjects(uid: uid)
        projectInvites = await firestore.getProjectInvites(uid: uid)
        debugPrint("[TeamProject] loaded \(myProjects.count) projects, \(projectInvites.count) invites")
    }

    func loadArchivedProjects() async {
        guard let uid = auth.currentUser?.uid else { return }
        archivedProjects = await firestore.getMyArchivedProjects(uid: uid)
    }

    // MARK: - Create Project

    func createProject(name: String, emoji: String, colorHex: String) async -> Bool {
        guard let profile = auth.userProfile else {
            debugPrint("[TeamProject] createProject failed: userProfile is nil")
            return false
        }

        let member = ProjectMember(
            id: profile.id,
            displayName: profile.displayName,
            avatarEmoji: profile.avatarEmoji,
            role: .owner
        )

        let project = TeamProject(
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            createdBy: profile.id,
            memberIds: [profile.id],
            memberProfiles: [member]
        )

        debugPrint("[TeamProject] creating project: \(project.name) by \(profile.displayName)")
        if let projectId = await firestore.createProject(project) {
            debugPrint("[TeamProject] created successfully: \(projectId)")
            let activity = ProjectActivity(
                type: .projectCreated,
                actorUid: profile.id,
                actorName: profile.displayName,
                actorEmoji: profile.avatarEmoji
            )
            await firestore.logActivity(projectId: projectId, activity: activity)
            await loadProjects()
            return true
        }
        debugPrint("[TeamProject] createProject returned nil")
        return false
    }

    // MARK: - Join Project

    func joinByCode(_ code: String) async -> JoinResult {
        guard let profile = auth.userProfile else { return .error }

        guard let project = await firestore.findProjectByCode(code) else {
            return .notFound
        }

        if project.memberIds.contains(profile.id) {
            return .alreadyMember
        }

        let member = ProjectMember(
            id: profile.id,
            displayName: profile.displayName,
            avatarEmoji: profile.avatarEmoji,
            role: .member
        )

        let success = await firestore.joinProject(projectId: project.id, member: member)
        if success {
            let activity = ProjectActivity(
                type: .memberJoined,
                actorUid: profile.id,
                actorName: profile.displayName,
                actorEmoji: profile.avatarEmoji
            )
            await firestore.logActivity(projectId: project.id, activity: activity)
            await loadProjects()
            return .success
        }
        return .error
    }

    enum JoinResult {
        case success, notFound, alreadyMember, error
    }

    // MARK: - Invites

    func inviteFriend(friendUid: String, to project: TeamProject) async -> Bool {
        guard let profile = auth.userProfile else { return false }

        // Already a member?
        if project.memberIds.contains(friendUid) { return false }

        let invite = ProjectInvite(
            projectId: project.id,
            projectName: project.name,
            projectEmoji: project.emoji,
            invitedBy: profile.id,
            inviterName: profile.displayName,
            inviterEmoji: profile.avatarEmoji
        )

        return await firestore.sendProjectInvite(to: friendUid, invite: invite)
    }

    func acceptInvite(_ invite: ProjectInvite) async -> Bool {
        guard let profile = auth.userProfile else {
            debugPrint("[TeamProject] acceptInvite failed: userProfile is nil")
            errorMessage = L10n.projectJoinError
            return false
        }

        let member = ProjectMember(
            id: profile.id,
            displayName: profile.displayName,
            avatarEmoji: profile.avatarEmoji,
            role: .member
        )

        let success = await firestore.joinProject(projectId: invite.projectId, member: member)
        debugPrint("[TeamProject] acceptInvite joinProject result: \(success)")

        if success {
            let activity = ProjectActivity(
                type: .memberJoined,
                actorUid: profile.id,
                actorName: profile.displayName,
                actorEmoji: profile.avatarEmoji
            )
            await firestore.logActivity(projectId: invite.projectId, activity: activity)
            // Only delete invite on successful join
            await firestore.deleteProjectInvite(uid: profile.id, inviteId: invite.id)
            projectInvites.removeAll { $0.id == invite.id }
            await loadProjects()
        } else {
            // Check if already a member (join returns false for duplicates)
            let projects = await firestore.getMyProjects(uid: profile.id)
            if projects.contains(where: { $0.id == invite.projectId }) {
                // Already a member — clean up the invite
                await firestore.deleteProjectInvite(uid: profile.id, inviteId: invite.id)
                projectInvites.removeAll { $0.id == invite.id }
                await loadProjects()
            } else {
                errorMessage = L10n.projectJoinError
            }
        }

        return success
    }

    func rejectInvite(_ invite: ProjectInvite) async {
        guard let uid = auth.currentUser?.uid else { return }
        await firestore.deleteProjectInvite(uid: uid, inviteId: invite.id)
        projectInvites.removeAll { $0.id == invite.id }
    }

    // MARK: - Project Detail (Real-time Listeners)

    func startListening(to project: TeamProject) {
        currentProject = project
        stopListening()

        projectListener = firestore.listenToProject(projectId: project.id) { [weak self] updated in
            guard let self, let updated else { return }
            let hadMeetup = self.currentProject?.activeMeetup != nil
            let oldMeetup = self.currentProject?.activeMeetup
            self.currentProject = updated

            // Meetup ended externally (another member ended it)
            if hadMeetup && updated.activeMeetup == nil {
                MeetupLocationService.shared.stopTracking()
                self.stopMeetupLocationsListener()
            }

            // New meetup appeared and user is in it → start Live Activity
            if let meetup = updated.activeMeetup,
               let uid = self.auth.currentUser?.uid,
               meetup.attendeeIds.contains(uid),
               !hadMeetup {
                self.startMeetupLocationsListener(projectId: updated.id)
                MeetupLocationService.shared.startLiveActivity(
                    meetupTime: meetup.meetupTime,
                    meetupTitle: meetup.title,
                    placeName: meetup.placeName,
                    destLatitude: meetup.placeLatitude,
                    destLongitude: meetup.placeLongitude
                )
            }

            // Meetup details edited → restart Live Activity + update destination
            if let meetup = updated.activeMeetup,
               let old = oldMeetup,
               meetup.id == old.id,
               let uid = self.auth.currentUser?.uid,
               meetup.attendeeIds.contains(uid),
               meetup.title != old.title ||
               meetup.placeName != old.placeName ||
               meetup.placeLatitude != old.placeLatitude ||
               meetup.placeLongitude != old.placeLongitude ||
               abs(meetup.meetupTime.timeIntervalSince(old.meetupTime)) > 1 {
                let service = MeetupLocationService.shared
                service.endLiveActivity()
                service.startLiveActivity(
                    meetupTime: meetup.meetupTime,
                    meetupTitle: meetup.title,
                    placeName: meetup.placeName,
                    destLatitude: meetup.placeLatitude,
                    destLongitude: meetup.placeLongitude
                )
                if meetup.placeLatitude != old.placeLatitude || meetup.placeLongitude != old.placeLongitude {
                    service.updateDestination(CLLocationCoordinate2D(
                        latitude: meetup.placeLatitude,
                        longitude: meetup.placeLongitude
                    ))
                }
            }

            // Cancel vote threshold reached → auto-end meetup
            if let meetup = updated.activeMeetup, meetup.cancelThresholdReached {
                Task { [weak self] in await self?.endMeetup() }
            }
        }

        duesListener = firestore.listenToProjectDues(projectId: project.id) { [weak self] dues in
            guard let self else { return }
            self.currentDues = dues
        }

        activitiesListener = firestore.listenToActivities(projectId: project.id) { [weak self] activities in
            guard let self else { return }
            self.activities = activities
        }

        // Start meetup locations listener + Live Activity if user is in an active meetup
        if let meetup = project.activeMeetup {
            startMeetupLocationsListener(projectId: project.id)
            if let uid = auth.currentUser?.uid, meetup.attendeeIds.contains(uid) {
                MeetupLocationService.shared.startLiveActivity(
                    meetupTime: meetup.meetupTime,
                    meetupTitle: meetup.title,
                    placeName: meetup.placeName,
                    destLatitude: meetup.placeLatitude,
                    destLongitude: meetup.placeLongitude
                )
            }
        }
    }

    func stopListening() {
        duesListener?.remove()
        duesListener = nil
        projectListener?.remove()
        projectListener = nil
        activitiesListener?.remove()
        activitiesListener = nil
        stopMeetupLocationsListener()
    }

    private func startMeetupLocationsListener(projectId: String) {
        meetupLocationsListener?.remove()
        meetupLocationsListener = firestore.listenToMeetupLocations(projectId: projectId) { [weak self] locations in
            self?.meetupLocations = locations
        }
    }

    private func stopMeetupLocationsListener() {
        meetupLocationsListener?.remove()
        meetupLocationsListener = nil
        meetupLocations = []
    }

    // MARK: - Due CRUD

    func createDue(projectId: String, title: String, description: String, emoji: String,
                   dueDate: Date, priority: DuePriority, assignedTo: [ProjectMember]) async -> Bool {
        guard let profile = auth.userProfile else { return false }

        let due = ProjectDue(
            title: title,
            description: description,
            emoji: emoji,
            dueDate: dueDate,
            createdBy: profile.id,
            creatorName: profile.displayName,
            assignedTo: assignedTo.map(\.id),
            assigneeNames: assignedTo.map(\.displayName),
            assigneeEmojis: assignedTo.map(\.avatarEmoji),
            priority: priority
        )

        let result = await firestore.createProjectDue(projectId: projectId, due: due)
        if result != nil {
            logActivity(type: .dueCreated, detail: title)
        }
        return result != nil
    }

    func toggleDueCompletion(_ due: ProjectDue) async {
        guard let projectId = currentProject?.id,
              let uid = auth.currentUser?.uid else { return }
        await firestore.toggleProjectDueCompletion(projectId: projectId, due: due, completedByUid: uid)
        logActivity(type: due.isCompleted ? .dueUncompleted : .dueCompleted, detail: due.title)
    }

    func assignDue(_ due: ProjectDue, to members: [ProjectMember]) async {
        guard let projectId = currentProject?.id else { return }
        let fields: [String: Any] = [
            "assignedTo": members.map(\.id),
            "assigneeNames": members.map(\.displayName),
            "assigneeEmojis": members.map(\.avatarEmoji)
        ]
        await firestore.updateProjectDue(projectId: projectId, dueId: due.id, fields: fields)
        if !members.isEmpty {
            logActivity(type: .dueAssigned, detail: due.title)
        }
    }

    func updateFullDue(_ due: ProjectDue, title: String, description: String, emoji: String,
                        dueDate: Date, priority: DuePriority, assignedTo: [ProjectMember]) async {
        guard let projectId = currentProject?.id else { return }
        let fields: [String: Any] = [
            "title": title,
            "description": description,
            "emoji": emoji,
            "dueDate": dueDate,
            "priority": priority.rawValue,
            "assignedTo": assignedTo.map(\.id),
            "assigneeNames": assignedTo.map(\.displayName),
            "assigneeEmojis": assignedTo.map(\.avatarEmoji)
        ]
        await firestore.updateProjectDue(projectId: projectId, dueId: due.id, fields: fields)
    }

    func deleteDue(_ due: ProjectDue) async {
        guard let projectId = currentProject?.id else { return }
        await firestore.deleteProjectDue(projectId: projectId, dueId: due.id)
        logActivity(type: .dueDeleted, detail: due.title)
    }

    // MARK: - Project Management

    func archiveProject() async {
        guard let project = currentProject else { return }
        await firestore.archiveProject(projectId: project.id, memberIds: project.memberIds)
        currentProject?.isArchived = true
        await loadProjects()
    }

    func leaveProject() async {
        guard let project = currentProject,
              let profile = auth.userProfile else { return }
        let activity = ProjectActivity(
            type: .memberLeft,
            actorUid: profile.id,
            actorName: profile.displayName,
            actorEmoji: profile.avatarEmoji
        )
        await firestore.logActivity(projectId: project.id, activity: activity)
        stopListening()
        await firestore.leaveProject(projectId: project.id, uid: profile.id)
        currentProject = nil
        await loadProjects()
    }

    func deleteProject() async {
        guard let project = currentProject else { return }
        stopListening()
        await firestore.deleteProject(projectId: project.id, memberIds: project.memberIds)
        currentProject = nil
        await loadProjects()
    }

    // MARK: - Quick Meeting

    func startMeeting(link: String, platform: MeetingPlatform) async {
        guard let projectId = currentProject?.id,
              let profile = auth.userProfile else { return }

        let meeting = ActiveMeeting(
            meetingLink: link,
            platform: platform,
            createdBy: profile.id,
            creatorName: profile.displayName,
            creatorEmoji: profile.avatarEmoji,
            startedAt: Date()
        )

        await firestore.startMeeting(projectId: projectId, meeting: meeting)
        logActivity(type: .meetingStarted)
    }

    func endMeeting() async {
        guard let projectId = currentProject?.id else { return }
        await firestore.endMeeting(projectId: projectId)
        logActivity(type: .meetingEnded)
    }

    // MARK: - Meetup Session

    func createMeetup(title: String, meetupTime: Date, placeName: String, placeAddress: String, latitude: Double, longitude: Double) async -> Bool {
        guard let projectId = currentProject?.id,
              let profile = auth.userProfile else { return false }

        let meetup = MeetupSession(
            title: title,
            meetupTime: meetupTime,
            placeName: placeName,
            placeAddress: placeAddress,
            placeLatitude: latitude,
            placeLongitude: longitude,
            createdBy: profile.id,
            creatorName: profile.displayName,
            creatorEmoji: profile.avatarEmoji,
            attendeeIds: [profile.id]
        )

        await firestore.createMeetup(projectId: projectId, meetup: meetup)
        startMeetupLocationsListener(projectId: projectId)
        logActivity(type: .meetupCreated, detail: placeName)

        // Start Live Activity immediately
        MeetupLocationService.shared.startLiveActivity(
            meetupTime: meetupTime,
            meetupTitle: title,
            placeName: placeName,
            destLatitude: latitude,
            destLongitude: longitude
        )
        return true
    }

    func updateMeetup(title: String, meetupTime: Date, placeName: String, placeAddress: String, latitude: Double, longitude: Double) async -> Bool {
        guard let projectId = currentProject?.id else { return false }
        await firestore.updateMeetupDetails(
            projectId: projectId,
            title: title,
            meetupTime: meetupTime,
            placeName: placeName,
            placeAddress: placeAddress,
            latitude: latitude,
            longitude: longitude
        )
        return true
    }

    func voteCancelMeetup() async {
        guard let projectId = currentProject?.id,
              let uid = auth.currentUser?.uid else { return }
        await firestore.voteCancelMeetup(projectId: projectId, uid: uid)
        // Threshold check happens in the project listener when updated data arrives
    }

    func joinMeetup() async {
        guard let projectId = currentProject?.id,
              let uid = auth.currentUser?.uid else { return }
        await firestore.joinMeetup(projectId: projectId, uid: uid)

        // Start Live Activity on join
        if let meetup = currentProject?.activeMeetup {
            MeetupLocationService.shared.startLiveActivity(
                meetupTime: meetup.meetupTime,
                meetupTitle: meetup.title,
                placeName: meetup.placeName,
                destLatitude: meetup.placeLatitude,
                destLongitude: meetup.placeLongitude
            )
        }
    }

    func endMeetup() async {
        guard let projectId = currentProject?.id else { return }
        MeetupLocationService.shared.stopTracking()
        await firestore.endMeetup(projectId: projectId)
        stopMeetupLocationsListener()
        logActivity(type: .meetupEnded)
    }

    var isInMeetup: Bool {
        guard let meetup = currentProject?.activeMeetup,
              let uid = auth.currentUser?.uid else { return false }
        return meetup.attendeeIds.contains(uid)
    }

    // MARK: - Activity Logging

    private func logActivity(type: ProjectActivity.ActivityType, detail: String = "") {
        guard let projectId = currentProject?.id,
              let profile = auth.userProfile else { return }
        let activity = ProjectActivity(
            type: type,
            actorUid: profile.id,
            actorName: profile.displayName,
            actorEmoji: profile.avatarEmoji,
            detail: detail
        )
        Task { await firestore.logActivity(projectId: projectId, activity: activity) }
    }

    // MARK: - Helpers

    func isOwner(uid: String) -> Bool {
        currentProject?.createdBy == uid
    }

    var currentUid: String? {
        auth.currentUser?.uid
    }
}
