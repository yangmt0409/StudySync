import SwiftUI
import FirebaseAuth

struct FriendsListView: View {
    private var auth: AuthService { .shared }

    @State private var friends: [FriendInfo] = []
    @State private var requests: [FriendRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var friendToRemove: FriendInfo?
    @State private var showRemoveAlert = false
    @State private var requestToReject: FriendRequest?
    @State private var showRejectAlert = false
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    // #5 Error banner
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.subheadline)
                            Text(error)
                                .font(SSFont.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                withAnimation { errorMessage = nil }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(SSSpacing.lg)
                        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Friend requests
                    if !requests.isEmpty {
                        requestsSection
                    }

                    // Friends list
                    if friends.isEmpty && requests.isEmpty {
                        emptyState
                    } else if !friends.isEmpty {
                        friendsSection
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .animation(.spring(duration: 0.5), value: hasAppeared)
        }
        .background {
            SSColor.backgroundPrimary
                .ignoresSafeArea()
        }
        .navigationTitle(L10n.socialFriends)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AddFriendView()
                } label: {
                    Image(systemName: "person.badge.plus")
                        .foregroundStyle(SSColor.brand)
                }
            }
        }
        .task {
            await loadData()
            withAnimation(.spring(duration: 0.5)) { hasAppeared = true }
        }
        .refreshable {
            await loadData()
        }
        // #2 Delete friend confirmation
        .alert(L10n.removeFriendConfirm, isPresented: $showRemoveAlert) {
            Button(L10n.delete, role: .destructive) {
                if let friend = friendToRemove {
                    Task { await removeFriend(friend) }
                }
            }
            Button(L10n.cancel, role: .cancel) { friendToRemove = nil }
        } message: {
            Text(L10n.removeFriendWarning)
        }
        // #2 Reject request confirmation
        .alert(L10n.rejectRequestConfirm, isPresented: $showRejectAlert) {
            Button(L10n.delete, role: .destructive) {
                if let request = requestToReject {
                    Task { await rejectRequest(request) }
                }
            }
            Button(L10n.cancel, role: .cancel) { requestToReject = nil }
        } message: {
            Text(L10n.rejectRequestWarning)
        }
    }

    // MARK: - Requests

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.socialFriendRequests)
                    .font(SSFont.bodySemibold)
                Text("\(requests.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 15)

            ForEach(Array(requests.enumerated()), id: \.element.id) { index, request in
                requestRow(request)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 15)
                    .animation(.spring(duration: 0.5).delay(Double(index) * 0.08), value: hasAppeared)
            }
        }
    }

    private func requestRow(_ request: FriendRequest) -> some View {
        HStack(spacing: 12) {
            Text(request.fromEmoji)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromName)
                    .font(.system(size: 15, weight: .medium))
                Text(L10n.socialWantsToAdd)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                HapticEngine.shared.lightImpact()
                Task { await acceptRequest(request) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)
            }
            .accessibilityLabel(L10n.projectInviteAccept)

            Button {
                HapticEngine.shared.selection()
                requestToReject = request
                showRejectAlert = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red.opacity(0.6))
            }
            .accessibilityLabel(L10n.projectInviteReject)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    // MARK: - Friends

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.socialFriends)
                .font(SSFont.bodySemibold)

            ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
                NavigationLink {
                    UserProfileDetailView(friend: friend)
                } label: {
                    friendRow(friend)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { HapticEngine.shared.selection() })
                // Context menu for delete (swipeActions only works in List)
                .contextMenu {
                    Button(role: .destructive) {
                        friendToRemove = friend
                        showRemoveAlert = true
                    } label: {
                        Label(L10n.delete, systemImage: "trash")
                    }
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 15)
                .animation(.spring(duration: 0.5).delay(Double(index) * 0.06), value: hasAppeared)
            }
        }
    }

    private func friendRow(_ friend: FriendInfo) -> some View {
        HStack(spacing: 12) {
            Text(friend.avatarEmoji)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(friend.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    RoleTagsView(roles: friend.roles)
                }

                HStack(spacing: 8) {
                    if friend.shareEnabled {
                        HStack(spacing: 3) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 10))
                            Text(L10n.socialDueShared)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.green)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                        Text(L10n.goalTotalCheckIns(friend.totalCheckIns))
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color(.tertiaryLabel))
            Text(L10n.socialNoFriends)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            Text(L10n.socialNoFriendsDesc)
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            NavigationLink {
                AddFriendView()
            } label: {
                Label(L10n.socialAddFriend, systemImage: "person.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "#5B7FFF").gradient))
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        guard let uid = auth.currentUser?.uid else { return }
        async let friendsTask = FirestoreService.shared.getFriends(uid: uid)
        async let requestsTask = FirestoreService.shared.getFriendRequests(uid: uid)
        friends = await friendsTask
        requests = await requestsTask
    }

    private func acceptRequest(_ request: FriendRequest) async {
        guard let uid = auth.currentUser?.uid,
              let profile = auth.userProfile else { return }
        await FirestoreService.shared.acceptFriendRequest(myUid: uid, myProfile: profile, request: request)
        HapticEngine.shared.lightImpact()

        // Check badge: first friend
        if friends.isEmpty {
            await FirestoreService.shared.awardBadge(uid: uid, badgeId: "first_friend")
        }

        await loadData()
    }

    private func rejectRequest(_ request: FriendRequest) async {
        guard let uid = auth.currentUser?.uid else { return }
        await FirestoreService.shared.rejectFriendRequest(myUid: uid, fromUid: request.fromUid)
        await loadData()
    }

    private func removeFriend(_ friend: FriendInfo) async {
        guard let uid = auth.currentUser?.uid else { return }
        await FirestoreService.shared.removeFriend(myUid: uid, friendUid: friend.id)
        friends.removeAll { $0.id == friend.id }
    }
}

#Preview {
    NavigationStack {
        FriendsListView()
    }
}
