import SwiftUI
import FirebaseAuth

struct AvailabilityView: View {
    private var auth: AuthService { .shared }
    private var service: AvailabilityService { .shared }

    @State private var isEditing = false
    @State private var selectedBrush: AvailabilityStatus = .busy
    @State private var weekData: [String: String] = [:]
    @State private var isLoading = true
    @State private var showResetAlert = false

    // Friends
    @State private var friends: [FriendInfo] = []

    var body: some View {
        if auth.isAuthenticated {
            mainContent
        } else {
            LoginView()
                .navigationTitle(L10n.avTitle)
        }
    }

    private var mainContent: some View {
        GeometryReader { geo in
            let dayWidth = (geo.size.width - AvailabilityGridView.timeLabelWidth - SSSpacing.xl * 2) / CGFloat(service.weekDateStrings.count)

            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    if isEditing {
                        // Edit mode: brush selector bar (pinned)
                        brushBar
                            .padding(.horizontal, SSSpacing.xl)
                            .padding(.vertical, SSSpacing.md)

                        // Hint text (pinned)
                        Text(L10n.avHint)
                            .font(SSFont.badge)
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, SSSpacing.xs)
                    } else {
                        // Preview mode: legend bar (pinned)
                        legendBar
                            .padding(.horizontal, SSSpacing.xl)
                            .padding(.vertical, SSSpacing.md)

                        // Preview hint (pinned)
                        Text(L10n.avPreviewHint)
                            .font(SSFont.badge)
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, SSSpacing.xs)
                    }

                    // Day header (pinned — stays visible while scrolling)
                    AvailabilityGridView.dayHeader(
                        dateStrings: service.weekDateStrings,
                        dayWidth: dayWidth
                    )
                    .padding(.horizontal, SSSpacing.xl)
                    .padding(.bottom, 4)
                    .background(SSColor.backgroundPrimary)

                    // Scrollable: grid rows + friends
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            AvailabilityGridView(
                                dateStrings: service.weekDateStrings,
                                dayWidth: dayWidth,
                                weekData: $weekData,
                                isEditable: isEditing,
                                collapseLongRuns: !isEditing,
                                selectedBrush: selectedBrush,
                                onPaint: { dateStr, slotIndex, status in
                                    service.updateSlot(dateString: dateStr, slotIndex: slotIndex, status: status)
                                    weekData = service.weekData
                                }
                            )
                            .padding(.horizontal, SSSpacing.xl)
                            .animation(.easeInOut(duration: 0.3), value: isEditing)

                            if !friends.isEmpty {
                                friendsSection
                            }
                        }
                        .padding(.bottom, SSSpacing.xxxl)
                    }
                }
            }
        }
        .background {
            SSColor.backgroundPrimary.ignoresSafeArea()
        }
        .navigationTitle(L10n.avMyTimeline)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showResetAlert = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.body)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isEditing = false
                        }
                        HapticEngine.shared.lightImpact()
                    } label: {
                        Text(L10n.done)
                            .font(SSFont.bodySemibold)
                            .foregroundStyle(SSColor.brand)
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isEditing = true
                        }
                        HapticEngine.shared.selection()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.body)
                            .foregroundStyle(SSColor.brand)
                    }
                }
            }
        }
        .alert(L10n.avResetWeek, isPresented: $showResetAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.avResetWeek, role: .destructive) {
                service.resetWeek()
                weekData = service.weekData
                HapticEngine.shared.success()
            }
        } message: {
            Text(L10n.avResetConfirm)
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Brush Bar (edit mode)

    private var brushBar: some View {
        HStack(spacing: SSSpacing.md) {
            ForEach(AvailabilityStatus.allCases) { status in
                Button {
                    selectedBrush = status
                    HapticEngine.shared.selection()
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(status.color)
                            .frame(width: 12, height: 12)
                        Text(status.label)
                            .font(SSFont.badge)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(selectedBrush == status
                                  ? status.color.opacity(0.2)
                                  : Color(.tertiarySystemFill))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(selectedBrush == status
                                          ? status.color
                                          : Color.clear,
                                          lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Legend Bar (preview mode)

    private var legendBar: some View {
        HStack(spacing: SSSpacing.lg) {
            ForEach(AvailabilityStatus.allCases) { status in
                HStack(spacing: 4) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 10, height: 10)
                    Text(status.label)
                        .font(SSFont.badge)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: SSSpacing.md) {
            Text(L10n.avFriendTimelines)
                .font(SSFont.sectionHeader)
                .foregroundStyle(.secondary)
                .padding(.horizontal, SSSpacing.xl)
                .padding(.top, SSSpacing.xxl)

            ForEach(friends) { friend in
                NavigationLink {
                    FriendAvailabilityView(
                        friendUid: friend.id,
                        friendName: friend.displayName,
                        friendEmoji: friend.avatarEmoji
                    )
                } label: {
                    HStack(spacing: SSSpacing.lg) {
                        Text(friend.avatarEmoji)
                            .font(.title3)

                        Text(friend.displayName)
                            .font(SSFont.bodyMedium)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(SSFont.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(SSSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                            .fill(SSColor.backgroundCard)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, SSSpacing.xl)
            }
        }
    }

    // MARK: - Load

    private func loadData() async {
        isLoading = true
        await service.loadMyWeek()
        weekData = service.weekData

        if let uid = auth.currentUser?.uid {
            friends = await FirestoreService.shared.getFriends(uid: uid)
        }
        isLoading = false
    }
}
