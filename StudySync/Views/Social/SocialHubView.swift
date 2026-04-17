import SwiftUI
import FirebaseAuth

struct SocialHubView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var auth: AuthService { .shared }
    private var notificationManager: InAppNotificationManager { .shared }
    @State private var hasAppeared = false
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            if auth.isAuthenticated {
                authenticatedContent
            } else {
                LoginView()
                    .navigationTitle(L10n.socialTitle)
            }
        }
    }

    private var authenticatedContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Profile card
                if let profile = auth.userProfile {
                    profileCard(profile)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                }

                // Quick actions
                quickActions
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 15)

                // Friend requests
                NavigationLink {
                    FriendsListView()
                } label: {
                    menuRow(icon: "person.2.fill", color: "#5B7FFF",
                            title: L10n.socialFriends, showChevron: true,
                            badgeCount: notificationManager.friendsBadgeCount)
                }
                .simultaneousGesture(TapGesture().onEnded { HapticEngine.shared.selection() })
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 15)

                // Availability Timeline
                NavigationLink {
                    AvailabilityView()
                } label: {
                    menuRow(icon: "calendar.badge.clock", color: "#FFB347",
                            title: L10n.avTitle, showChevron: true)
                }
                .simultaneousGesture(TapGesture().onEnded { HapticEngine.shared.selection() })
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 15)

                // Team Projects
                NavigationLink {
                    TeamProjectListView()
                } label: {
                    menuRow(icon: "person.3.fill", color: "#4ECDC4",
                            title: L10n.projectTitle, showChevron: true,
                            badgeCount: notificationManager.projectsBadgeCount)
                }
                .simultaneousGesture(TapGesture().onEnded { HapticEngine.shared.selection() })
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 15)

                // Badges
                NavigationLink {
                    BadgeGridView()
                } label: {
                    menuRow(icon: "medal.fill", color: "#FFD93D",
                            title: L10n.socialBadges, showChevron: true)
                }
                .simultaneousGesture(TapGesture().onEnded { HapticEngine.shared.selection() })
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 15)

                // Sharing toggles
                if let profile = auth.userProfile {
                    VStack(spacing: 0) {
                        shareToggle(profile)
                        Divider().padding(.leading, 56)
                        shareAvailabilityToggle(profile)
                        Divider().padding(.leading, 56)
                        allowNudgesToggle(profile)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                            .fill(SSColor.backgroundCard)
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)
                }

                // Sign out
                Button {
                    showSignOutConfirm = true
                    HapticEngine.shared.warning()
                } label: {
                    menuRow(icon: "rectangle.portrait.and.arrow.right", color: "#FF6B6B",
                            title: L10n.socialLogout, showChevron: false)
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 10)
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.top, SSSpacing.md)
            .padding(.bottom, SSSpacing.xxl)
            .animation(.spring(duration: 0.6), value: hasAppeared)
        }
        // #1 Pull-to-refresh
        .refreshable {
            if let uid = auth.currentUser?.uid {
                await auth.loadProfile(uid: uid)
            }
        }
        .background {
            SSColor.backgroundPrimary
                .ignoresSafeArea()
        }
        .navigationTitle(L10n.socialTitle)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if !hasAppeared {
                withAnimation(.spring(duration: 0.5)) {
                    hasAppeared = true
                }
            }
        }
        .alert(L10n.signOutConfirmTitle, isPresented: $showSignOutConfirm) {
            Button(L10n.socialLogout, role: .destructive) {
                auth.signOut()
                HapticEngine.shared.success()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.signOutConfirmMessage)
        }
    }

    // MARK: - Profile Card

    private func profileCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                NavigationLink {
                    UserProfileDetailView(myUid: profile.id)
                } label: {
                    Text(profile.avatarEmoji)
                        .font(.system(size: 42))
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(SSColor.brand.opacity(0.1))
                        )
                }
                .simultaneousGesture(TapGesture().onEnded { HapticEngine.shared.selection() })

                VStack(alignment: .leading, spacing: 4) {
                    NavigationLink {
                        UserProfileDetailView(myUid: profile.id)
                    } label: {
                        Text(profile.displayName)
                            .font(SSFont.heading3)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    RoleTagsView(roles: profile.roles)
                    Text(profile.email)
                        .font(SSFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink {
                    ProfileView()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(SSColor.brand)
                }
                .simultaneousGesture(TapGesture().onEnded { HapticEngine.shared.selection() })
            }

            Divider()

            // Friend code
            HStack {
                Text(L10n.socialFriendCode)
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(profile.friendCode)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(SSColor.brand)

                Button {
                    UIPasteboard.general.string = profile.friendCode
                    HapticEngine.shared.lightImpact()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(SSFont.secondary)
                        .foregroundStyle(SSColor.brand)
                }
            }

            // Showcase badges
            if !profile.showcaseBadges.isEmpty {
                Divider()
                HStack(spacing: 16) {
                    ForEach(profile.showcaseBadges, id: \.self) { badgeId in
                        if let badge = Badge.badge(for: badgeId) {
                            VStack(spacing: 3) {
                                Text(badge.emoji)
                                    .font(.system(size: 24))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(badge.color.opacity(0.15))
                                    )
                                Text(badge.name)
                                    .font(SSFont.micro)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            // Stats
            Divider()
            HStack(spacing: 0) {
                statItem(value: "\(profile.totalCheckIns)", label: L10n.goalTotal)
                Divider().frame(height: 24)
                statItem(value: "\(profile.longestStreak)", label: L10n.goalStreak)
                Divider().frame(height: 24)
                statItem(value: formatFocusTime(profile.totalFocusMinutes), label: L10n.focusTime)
                Divider().frame(height: 24)
                statItem(value: "\(profile.badges.count)", label: L10n.socialBadges)
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    private func formatFocusTime(_ minutes: Int) -> String {
        let hrs = minutes / 60
        if hrs > 0 { return "\(hrs)h\(minutes % 60)m" }
        return "\(minutes)m"
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(SSFont.badge)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            NavigationLink {
                AddFriendView()
            } label: {
                actionButton(icon: "person.badge.plus", label: L10n.socialAddFriend, color: "#4ECDC4")
            }

            NavigationLink {
                FriendsListView()
            } label: {
                actionButton(icon: "eye.fill", label: L10n.socialViewDues, color: "#FF8A5C")
            }
        }
    }

    private func actionButton(icon: String, label: String, color: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: color))
            Text(label)
                .font(SSFont.footnote)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    // MARK: - Menu Row

    private func menuRow(icon: String, color: String, title: String, showChevron: Bool, badgeCount: Int = 0) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: color))
                .frame(width: 28)

            Text(title)
                .font(SSFont.bodyMedium)
                .foregroundStyle(.primary)

            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 20, minHeight: 20)
                    .padding(.horizontal, 4)
                    .background(Color.red, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        .animation(.spring(duration: 0.3), value: badgeCount)
    }

    // MARK: - Share Toggle

    private func shareToggle(_ profile: UserProfile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shared.with.you")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "#A8E6CF"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.socialShareDues)
                    .font(SSFont.bodyMedium)
                Text(L10n.socialShareDuesDesc)
                    .font(SSFont.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { profile.shareEnabled },
                set: { newValue in
                    auth.userProfile?.shareEnabled = newValue
                    Task {
                        await FirestoreService.shared.updateShareEnabled(uid: profile.id, enabled: newValue)
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(SSSpacing.xl)
    }

    private func shareAvailabilityToggle(_ profile: UserProfile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "#FFB347"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.avShareAvailability)
                    .font(SSFont.bodyMedium)
                Text(L10n.avShareAvailabilityDesc)
                    .font(SSFont.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { profile.shareAvailability },
                set: { newValue in
                    auth.userProfile?.shareAvailability = newValue
                    Task {
                        await FirestoreService.shared.updateShareAvailability(uid: profile.id, enabled: newValue)
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(SSSpacing.xl)
    }

    private func allowNudgesToggle(_ profile: UserProfile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.system(size: 18))
                .foregroundStyle(SSColor.meetup)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.nudgeAllowToggle)
                    .font(SSFont.bodyMedium)
                Text(L10n.nudgeAllowDesc)
                    .font(SSFont.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { profile.allowNudges },
                set: { newValue in
                    auth.userProfile?.allowNudges = newValue
                    Task {
                        await FirestoreService.shared.updateAllowNudges(uid: profile.id, allowed: newValue)
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(SSSpacing.xl)
    }
}

#Preview {
    SocialHubView()
}
