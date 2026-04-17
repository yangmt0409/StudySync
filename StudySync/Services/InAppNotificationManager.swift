import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Manages in-app notification badges via Firestore snapshot listeners.
/// Tracks friend requests, project invites, and new/completed project dues.
@Observable
final class InAppNotificationManager {
    static let shared = InAppNotificationManager()

    // MARK: - Badge Counts

    /// Number of pending friend requests
    var friendRequestCount: Int = 0

    /// Number of pending project invites
    var projectInviteCount: Int = 0

    /// Per-project new due activity count (new + recently completed by others)
    var projectNewDueCounts: [String: Int] = [:]

    /// Total new due activity across all projects
    var newDueCount: Int {
        projectNewDueCounts.values.reduce(0, +)
    }

    /// Total badge count for the Social tab
    var socialBadgeCount: Int {
        friendRequestCount + projectInviteCount + newDueCount
    }

    /// Whether to show the Social tab badge
    var hasSocialBadge: Bool { socialBadgeCount > 0 }

    /// Badge for the Friends section (pending friend requests)
    var friendsBadgeCount: Int { friendRequestCount }

    /// Badge for the Projects section (invites + new dues)
    var projectsBadgeCount: Int { projectInviteCount + newDueCount }

    // MARK: - Private

    private let db = Firestore.firestore()
    private var currentUid: String?

    private var friendRequestListener: ListenerRegistration?
    private var projectInviteListener: ListenerRegistration?
    private var membershipListener: ListenerRegistration?
    private var dueListeners: [String: ListenerRegistration] = [:]

    private init() {}

    // MARK: - Lifecycle

    /// Begin listening to Firestore for notification data. Call on login.
    func startListening(uid: String) {
        guard currentUid != uid else { return }
        stopListening()
        currentUid = uid

        listenFriendRequests(uid: uid)
        listenProjectInvites(uid: uid)
        listenMemberships(uid: uid)

        debugPrint("[InAppNotif] Started listening for uid=\(uid.prefix(8))…")
    }

    /// Stop all Firestore listeners. Call on logout.
    func stopListening() {
        friendRequestListener?.remove()
        projectInviteListener?.remove()
        membershipListener?.remove()
        dueListeners.values.forEach { $0.remove() }

        friendRequestListener = nil
        projectInviteListener = nil
        membershipListener = nil
        dueListeners.removeAll()

        friendRequestCount = 0
        projectInviteCount = 0
        projectNewDueCounts.removeAll()
        currentUid = nil

        debugPrint("[InAppNotif] Stopped listening")
    }

    // MARK: - Friend Requests

    private func listenFriendRequests(uid: String) {
        friendRequestListener = db.collection("users").document(uid)
            .collection("friendRequests")
            .limit(to: 200)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else {
                    if let error { debugPrint("[InAppNotif] friendRequests error: \(error)") }
                    return
                }
                Task { @MainActor in self.friendRequestCount = snapshot.documents.count }
            }
    }

    // MARK: - Project Invites

    private func listenProjectInvites(uid: String) {
        projectInviteListener = db.collection("users").document(uid)
            .collection("projectInvites")
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else {
                    if let error { debugPrint("[InAppNotif] projectInvites error: \(error)") }
                    return
                }
                Task { @MainActor in self.projectInviteCount = snapshot.documents.count }
            }
    }

    // MARK: - Project Memberships → Due Listeners

    private func listenMemberships(uid: String) {
        membershipListener = db.collection("users").document(uid)
            .collection("projectMemberships")
            .whereField("isArchived", isEqualTo: false)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else {
                    if let error { debugPrint("[InAppNotif] memberships error: \(error)") }
                    return
                }

                let activeProjectIds = Set(snapshot.documents.map { $0.documentID })

                Task { @MainActor in
                    // Remove listeners for projects no longer active
                    for (projectId, listener) in self.dueListeners where !activeProjectIds.contains(projectId) {
                        listener.remove()
                        self.dueListeners.removeValue(forKey: projectId)
                        self.projectNewDueCounts.removeValue(forKey: projectId)
                    }

                    // Add listeners for new projects
                    for projectId in activeProjectIds where self.dueListeners[projectId] == nil {
                        self.listenDues(projectId: projectId)
                    }
                }
            }
    }

    // MARK: - Per-Project Due Listener

    private func listenDues(projectId: String) {
        dueListeners[projectId] = db.collection("projects").document(projectId)
            .collection("dues")
            .limit(to: 500)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, let uid = self.currentUid else {
                    if let error { debugPrint("[InAppNotif] dues error (\(projectId.prefix(8))): \(error)") }
                    return
                }

                let lastSeen = self.lastSeenDate(for: projectId)
                var count = 0

                for doc in snapshot.documents {
                    let data = doc.data()

                    // New due created after last seen (not by me)
                    if let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                       createdAt > lastSeen,
                       (data["createdBy"] as? String) != uid {
                        count += 1
                        continue
                    }

                    // Due completed after last seen (not by me)
                    if let isCompleted = data["isCompleted"] as? Bool, isCompleted,
                       let completedAt = (data["completedAt"] as? Timestamp)?.dateValue(),
                       completedAt > lastSeen,
                       (data["completedBy"] as? String) != uid {
                        count += 1
                    }
                }

                Task { @MainActor in self.projectNewDueCounts[projectId] = count }
            }
    }

    // MARK: - Mark as Seen

    /// Mark all due activity for a project as seen. Call when entering ProjectDetailView.
    func markProjectDuesSeen(projectId: String) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSeenKey(projectId))
        projectNewDueCounts[projectId] = 0
    }

    // MARK: - Last Seen Helpers

    private func lastSeenKey(_ projectId: String) -> String {
        "notif_lastSeenDues_\(projectId)"
    }

    private func lastSeenDate(for projectId: String) -> Date {
        let timestamp = UserDefaults.standard.double(forKey: lastSeenKey(projectId))
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : Date.distantPast
    }
}
