import SwiftUI

struct FriendDuesView: View {
    let friend: FriendInfo

    @State private var dues: [SharedDue] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Friend header
                headerCard

                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if !friend.shareEnabled {
                    notSharedState
                } else if dues.isEmpty {
                    emptyState
                } else {
                    duesList
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        }
        .navigationTitle(friend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDues()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Text(friend.avatarEmoji)
                    .font(.system(size: 38))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(friend.displayName)
                            .font(.system(size: 18, weight: .semibold))
                        RoleTagsView(roles: friend.roles)
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                            Text(L10n.goalStreakCount(friend.longestStreak))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                            Text(L10n.goalTotalCheckIns(friend.totalCheckIns))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }

            // Showcase badges
            if !friend.showcaseBadges.isEmpty {
                Divider()
                HStack(spacing: 16) {
                    ForEach(friend.showcaseBadges, id: \.self) { badgeId in
                        if let badge = Badge.badge(for: badgeId) {
                            VStack(spacing: 3) {
                                Text(badge.emoji)
                                    .font(.system(size: 22))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(badge.color.opacity(0.15))
                                    )
                                Text(badge.name)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Dues List

    private var duesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.socialDueEvents)
                .font(.system(size: 16, weight: .semibold))

            ForEach(dues) { due in
                dueRow(due)
            }
        }
    }

    private func dueRow(_ due: SharedDue) -> some View {
        HStack(spacing: 12) {
            Text(due.emoji)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(due.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(due.isCompleted ? .secondary : .primary)

                    if due.isCompleted {
                        Text(L10n.dlCompleted)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.1).clipShape(Capsule()))
                    }
                }

                Text(due.endDate.formattedChinese)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !due.isCompleted {
                if due.isExpired {
                    Text(L10n.dlOverdue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                } else {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(due.daysRemaining)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(due.daysRemaining <= 3 ? .red : Color(hex: due.colorHex))
                        Text(L10n.daysUnit)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    due.daysRemaining <= 1 && !due.isCompleted && !due.isExpired
                    ? Color.red.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Empty / Not Shared

    private var notSharedState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(L10n.socialDueNotShared)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text(L10n.socialDueNotSharedDesc)
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(L10n.socialNoDues)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Load

    private func loadDues() async {
        isLoading = true
        if friend.shareEnabled {
            dues = await FirestoreService.shared.getFriendDues(friendUid: friend.id)
        }
        isLoading = false
    }
}
