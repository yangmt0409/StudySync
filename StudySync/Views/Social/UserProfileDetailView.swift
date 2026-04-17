import SwiftUI
import FirebaseAuth

struct UserProfileDetailView: View {
    /// For viewing a friend — provides fallback display data while full profile loads.
    private let friend: FriendInfo?
    /// For viewing self — pass a uid directly, profile loads from Firestore.
    private let uid: String
    /// Whether this is viewing your own profile.
    private let isSelf: Bool

    @State private var profile: UserProfile?
    @State private var isLoading = true

    // Nudge state
    @State private var isNudging = false
    @State private var nudgeSent = false
    @State private var nudgeCooldown = false

    // Ring nudge state
    @State private var isRingNudging = false
    @State private var ringNudgeSent = false
    @State private var ringNudgeCooldown = false
    @State private var targetAllowsRingFromMe = false
    @State private var targetIsFreeNow = false
    @State private var myAllowRingForThem = false   // whether I allow THIS friend to ring me

    // MARK: - Initializers

    /// View a friend's profile.
    init(friend: FriendInfo) {
        self.friend = friend
        self.uid = friend.id
        self.isSelf = false
    }

    /// View your own profile.
    init(myUid: String) {
        self.friend = nil
        self.uid = myUid
        self.isSelf = true
    }

    // MARK: - Computed

    private var displayName: String {
        profile?.displayName ?? friend?.displayName ?? ""
    }

    private var displayEmoji: String {
        profile?.avatarEmoji ?? friend?.avatarEmoji ?? "😊"
    }

    private var displayRoles: [String] {
        profile?.roles ?? friend?.roles ?? []
    }

    private var checkIns: Int {
        profile?.totalCheckIns ?? friend?.totalCheckIns ?? 0
    }

    private var streak: Int {
        profile?.longestStreak ?? friend?.longestStreak ?? 0
    }

    private var focusMinutes: Int {
        profile?.totalFocusMinutes ?? friend?.totalFocusMinutes ?? 0
    }

    private func formatFocusTime(_ minutes: Int) -> String {
        let hrs = minutes / 60
        if hrs > 0 { return "\(hrs)h\(minutes % 60)m" }
        return "\(minutes)m"
    }

    private var earnedBadges: [Badge] {
        guard let profile else { return [] }
        return Badge.earned(from: profile.badges)
    }

    private var unearnedBadges: [Badge] {
        guard let profile else { return [] }
        return Badge.unearned(from: profile.badges)
    }

    var body: some View {
        ScrollView {
            if isLoading {
                VStack {
                    Spacer().frame(height: 80)
                    ProgressView()
                }
            } else {
                VStack(spacing: SSSpacing.xl) {
                    // Header card
                    headerCard

                    // Stats card
                    statsCard

                    // Quick actions (only for viewing others)
                    if !isSelf {
                        actionsSection
                    }

                    // Badges section
                    badgesSection
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.top, SSSpacing.md)
                .padding(.bottom, SSSpacing.xxxl)
            }
        }
        .background {
            SSColor.backgroundPrimary.ignoresSafeArea()
        }
        .navigationTitle(L10n.profileDetail)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProfile()
            if !isSelf {
                await loadRingNudgeState()
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: SSSpacing.xl) {
            // Avatar + Name
            VStack(spacing: SSSpacing.md) {
                Text(displayEmoji)
                    .font(.system(size: 56))
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(SSColor.brand.opacity(0.1))
                    )

                Text(displayName)
                    .font(SSFont.heading1)

                // Role tags
                RoleTagsView(roles: displayRoles)

                // Joined date
                if let createdAt = profile?.createdAt {
                    HStack(spacing: SSSpacing.xs) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption2)
                        Text("\(L10n.profileMemberSince) \(createdAt.formattedChinese)")
                            .font(SSFont.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                // Friend code (self only)
                if isSelf, let code = profile?.friendCode {
                    HStack(spacing: SSSpacing.xs) {
                        Text(L10n.socialFriendCode)
                            .font(SSFont.caption)
                            .foregroundStyle(.secondary)
                        Text(code)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(SSColor.brand)
                    }
                }
            }

            // Showcase badges
            if let profile, !profile.showcaseBadges.isEmpty {
                Divider()

                HStack(spacing: SSSpacing.xxl) {
                    ForEach(profile.showcaseBadges, id: \.self) { badgeId in
                        if let badge = Badge.badge(for: badgeId) {
                            VStack(spacing: SSSpacing.xs) {
                                Text(badge.emoji)
                                    .font(.system(size: 26))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(badge.color.opacity(0.15))
                                    )
                                Text(badge.name)
                                    .font(SSFont.badge)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding(SSSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.large, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            Text(L10n.profileStats)
                .font(SSFont.sectionHeader)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 0) {
                statItem(
                    value: "\(checkIns)",
                    label: L10n.goalTotal,
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                Divider()
                    .frame(height: 40)

                statItem(
                    value: "\(streak)",
                    label: L10n.goalStreak,
                    icon: "flame.fill",
                    color: .orange
                )

                Divider()
                    .frame(height: 40)

                statItem(
                    value: formatFocusTime(focusMinutes),
                    label: L10n.focusTime,
                    icon: "timer",
                    color: Color(hex: "#7C3AED")
                )

                Divider()
                    .frame(height: 40)

                statItem(
                    value: "\(earnedBadges.count)",
                    label: L10n.socialBadges,
                    icon: "medal.fill",
                    color: SSColor.brand
                )
            }
            .padding(.vertical, SSSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                    .fill(SSColor.backgroundCard)
            )
        }
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: SSSpacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .contentTransition(.numericText())

            Text(label)
                .font(SSFont.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions (friend only)

    private var actionsSection: some View {
        VStack(spacing: SSSpacing.md) {
            if let friend, friend.shareEnabled {
                NavigationLink {
                    FriendDuesView(friend: friend)
                } label: {
                    actionRow(
                        icon: "list.bullet.clipboard",
                        color: SSColor.brand,
                        title: L10n.profileViewDues
                    )
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                FriendAvailabilityView(
                    friendUid: uid,
                    friendName: displayName,
                    friendEmoji: displayEmoji
                )
            } label: {
                actionRow(
                    icon: "calendar.day.timeline.left",
                    color: Color(hex: "#FFB347"),
                    title: L10n.profileViewTimeline
                )
            }
            .buttonStyle(.plain)

            // Nudge button (拍一拍)
            nudgeButton

            // Ring nudge button (响铃拍一拍)
            ringNudgeButton

            // Allow ring nudge toggle (per-friend permission I grant)
            ringNudgePermissionToggle
        }
    }

    // MARK: - Nudge Button

    private var nudgeButton: some View {
        Button {
            Task { await sendNudge() }
        } label: {
            HStack(spacing: SSSpacing.lg) {
                Image(systemName: nudgeSent ? "hand.tap.fill" : "hand.tap")
                    .font(.body)
                    .foregroundStyle(nudgeButtonColor)
                    .frame(width: 28)

                Text(nudgeSent ? L10n.nudgeSent : L10n.nudgeSend)
                    .font(SSFont.bodyMedium)
                    .foregroundStyle(nudgeSent ? .secondary : .primary)

                Spacer()

                if isNudging {
                    ProgressView()
                        .controlSize(.small)
                } else if nudgeSent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(SSFont.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(SSSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                    .fill(SSColor.backgroundCard)
            )
        }
        .buttonStyle(.plain)
        .disabled(isNudging || nudgeCooldown)
        .opacity(nudgeCooldown && !nudgeSent ? 0.5 : 1)
    }

    private var nudgeButtonColor: Color {
        if nudgeSent { return .green }
        if nudgeCooldown { return .secondary }
        return SSColor.meetup
    }

    @MainActor
    private func sendNudge() async {
        // Check if target allows nudges
        if let profile, !profile.allowNudges {
            HapticEngine.shared.error()
            return
        }

        guard let myUid = Auth.auth().currentUser?.uid,
              let myProfile = AuthService.shared.userProfile else { return }

        isNudging = true

        let success = await FirestoreService.shared.sendNudge(
            from: myUid,
            to: uid,
            senderName: myProfile.displayName,
            senderEmoji: myProfile.avatarEmoji
        )

        isNudging = false

        if success {
            nudgeSent = true
            nudgeCooldown = true
            HapticEngine.shared.success()

            // Reset visual state after 3s, keep cooldown for 60s
            Task {
                try? await Task.sleep(for: .seconds(3))
                nudgeSent = false
            }
            Task {
                try? await Task.sleep(for: .seconds(60))
                nudgeCooldown = false
            }
        } else {
            HapticEngine.shared.error()
        }
    }

    // MARK: - Ring Nudge Button

    private var ringNudgeButton: some View {
        Button {
            Task { await sendRingNudge() }
        } label: {
            HStack(spacing: SSSpacing.lg) {
                Image(systemName: ringNudgeSent ? "bell.fill" : "bell.and.waves.left.and.right")
                    .font(.body)
                    .foregroundStyle(ringNudgeButtonColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ringNudgeSent ? L10n.ringNudgeSent : L10n.ringNudgeSend)
                        .font(SSFont.bodyMedium)
                        .foregroundStyle(ringNudgeEnabled ? (ringNudgeSent ? .secondary : .primary) : .secondary)

                    if !targetAllowsRingFromMe {
                        Text(L10n.ringNudgeNoPermission)
                            .font(SSFont.micro)
                            .foregroundStyle(.tertiary)
                    } else if !targetIsFreeNow {
                        Text(L10n.ringNudgeNotFree)
                            .font(SSFont.micro)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if isRingNudging {
                    ProgressView()
                        .controlSize(.small)
                } else if ringNudgeSent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(SSFont.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(SSSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                    .fill(SSColor.backgroundCard)
            )
        }
        .buttonStyle(.plain)
        .disabled(!ringNudgeEnabled)
        .opacity(ringNudgeEnabled ? 1 : 0.5)
    }

    private var ringNudgeEnabled: Bool {
        !isRingNudging && !ringNudgeCooldown && targetAllowsRingFromMe && targetIsFreeNow
    }

    private var ringNudgeButtonColor: Color {
        if ringNudgeSent { return .green }
        if !ringNudgeEnabled { return .secondary }
        return .orange
    }

    @MainActor
    private func sendRingNudge() async {
        guard let myUid = Auth.auth().currentUser?.uid,
              let myProfile = AuthService.shared.userProfile else { return }

        isRingNudging = true

        // Double-check permission + availability server-side
        let hasPermission = await FirestoreService.shared.checkRingNudgePermission(targetUid: uid, senderUid: myUid)
        guard hasPermission else {
            isRingNudging = false
            targetAllowsRingFromMe = false
            HapticEngine.shared.error()
            return
        }

        let isFree = await checkTargetFreeNow()
        guard isFree else {
            isRingNudging = false
            targetIsFreeNow = false
            HapticEngine.shared.error()
            return
        }

        let success = await FirestoreService.shared.sendRingNudge(
            from: myUid,
            to: uid,
            senderName: myProfile.displayName,
            senderEmoji: myProfile.avatarEmoji
        )

        isRingNudging = false

        if success {
            ringNudgeSent = true
            ringNudgeCooldown = true
            HapticEngine.shared.success()

            Task {
                try? await Task.sleep(for: .seconds(3))
                ringNudgeSent = false
            }
            Task {
                try? await Task.sleep(for: .seconds(120))
                ringNudgeCooldown = false
            }
        } else {
            HapticEngine.shared.error()
        }
    }

    // MARK: - Ring Nudge Permission Toggle

    /// Toggle: "Allow this person to ring-nudge ME"
    /// Writes to users/{myUid}/friends/{theirUid}.allowRingNudge
    private var ringNudgePermissionToggle: some View {
        HStack(spacing: SSSpacing.lg) {
            Image(systemName: "bell.badge")
                .font(.body)
                .foregroundStyle(.orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.ringNudgeAllowToggle)
                    .font(SSFont.bodyMedium)
                Text(L10n.ringNudgeAllowDesc)
                    .font(SSFont.micro)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { myAllowRingForThem },
                set: { newValue in
                    myAllowRingForThem = newValue
                    guard let myUid = Auth.auth().currentUser?.uid else { return }
                    Task {
                        await FirestoreService.shared.updateAllowRingNudge(
                            myUid: myUid, friendUid: uid, allowed: newValue
                        )
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    // MARK: - Availability Check

    /// Check if the target user is currently in a free (G) time slot.
    private func checkTargetFreeNow() async -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        guard let slotString = await FirestoreService.shared.getAvailability(uid: uid, dateString: today) else {
            return false
        }

        let slots = DaySlots.parse(slotString)
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let minute = Calendar.current.component(.minute, from: now)
        let slotIndex = hour * 2 + (minute >= 30 ? 1 : 0)

        guard slotIndex < slots.count else { return false }
        return slots[slotIndex] == .available
    }

    private func actionRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: SSSpacing.lg) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)

            Text(title)
                .font(SSFont.bodyMedium)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(SSFont.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    // MARK: - Badges

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            HStack {
                Text(L10n.profileBadgesSection)
                    .font(SSFont.sectionHeader)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text(L10n.profileBadgeCount(earnedBadges.count, Badge.all.count))
                    .font(SSFont.badge)
                    .foregroundStyle(.tertiary)
            }

            if earnedBadges.isEmpty && unearnedBadges.isEmpty {
                VStack(spacing: SSSpacing.md) {
                    Image(systemName: "medal")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text(L10n.profileNoBadges)
                        .font(SSFont.secondary)
                        .foregroundStyle(.secondary)
                    Text(L10n.profileNoBadgesDesc)
                        .font(SSFont.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SSSpacing.xxxl)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: SSSpacing.lg), count: 4)

                if !earnedBadges.isEmpty {
                    LazyVGrid(columns: columns, spacing: SSSpacing.xl) {
                        ForEach(earnedBadges) { badge in
                            badgeCell(badge, earned: true)
                        }
                    }
                }

                if !unearnedBadges.isEmpty {
                    if !earnedBadges.isEmpty {
                        Divider()
                            .padding(.vertical, SSSpacing.xs)
                    }

                    LazyVGrid(columns: columns, spacing: SSSpacing.xl) {
                        ForEach(unearnedBadges) { badge in
                            badgeCell(badge, earned: false)
                        }
                    }
                }
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    private func badgeCell(_ badge: Badge, earned: Bool) -> some View {
        VStack(spacing: SSSpacing.xs) {
            Text(badge.emoji)
                .font(.system(size: 28))
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(earned ? badge.color.opacity(0.15) : Color(.tertiarySystemFill))
                )
                .grayscale(earned ? 0 : 1)
                .opacity(earned ? 1 : 0.4)

            Text(badge.name)
                .font(SSFont.badge)
                .foregroundStyle(earned ? .primary : .tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Load

    private func loadProfile() async {
        isLoading = true
        profile = await FirestoreService.shared.getUserProfile(uid: uid)
        isLoading = false
    }

    /// Load ring nudge permission states:
    /// 1. Does target allow ME to ring them?  → users/{target}/friends/{me}.allowRingNudge
    /// 2. Do I allow THEM to ring me?          → users/{me}/friends/{target}.allowRingNudge
    /// 3. Is target currently free?             → users/{target}/availability/{today}
    private func loadRingNudgeState() async {
        guard let myUid = Auth.auth().currentUser?.uid else { return }

        async let permissionCheck = FirestoreService.shared.checkRingNudgePermission(targetUid: uid, senderUid: myUid)
        async let freeCheck = checkTargetFreeNow()
        async let myFriendDoc = FirestoreService.shared.getFriendDoc(myUid: myUid, friendUid: uid)

        let (hasPermission, isFree, friendDoc) = await (permissionCheck, freeCheck, myFriendDoc)

        targetAllowsRingFromMe = hasPermission
        targetIsFreeNow = isFree
        myAllowRingForThem = friendDoc?["allowRingNudge"] as? Bool ?? false
    }
}
