import SwiftUI
import FirebaseAuth

struct InviteFriendToProjectView: View {
    let viewModel: TeamProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var friends: [FriendInfo] = []
    @State private var isLoading = true
    @State private var sentInvites: Set<String> = []

    private let auth = AuthService.shared
    private let firestore = FirestoreService.shared

    private var project: TeamProject? { viewModel.currentProject }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    VStack(spacing: SSSpacing.xl) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text(L10n.socialFriends)
                            .font(SSFont.bodyMedium)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(friends) { friend in
                        HStack(spacing: SSSpacing.lg) {
                            Text(friend.avatarEmoji)
                                .font(.system(size: 22))
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color(.tertiarySystemFill)))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .font(SSFont.bodySmallMedium)
                            }

                            Spacer()

                            if let project, project.memberIds.contains(friend.id) {
                                Text(L10n.projectMember)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, SSSpacing.mdLg)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                            } else if sentInvites.contains(friend.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Button {
                                    inviteFriend(friend)
                                } label: {
                                    Text(L10n.projectInviteFriend)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, SSSpacing.lg)
                                        .padding(.vertical, SSSpacing.sm)
                                        .background(Capsule().fill(SSColor.brand))
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle(L10n.projectInviteFriend)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFriends()
        }
    }

    private func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        guard let uid = auth.currentUser?.uid else { return }
        friends = await firestore.getFriends(uid: uid)
    }

    private func inviteFriend(_ friend: FriendInfo) {
        guard let project else { return }
        Task {
            let success = await viewModel.inviteFriend(friendUid: friend.id, to: project)
            if success {
                sentInvites.insert(friend.id)
                HapticEngine.shared.success()
            }
        }
    }
}
