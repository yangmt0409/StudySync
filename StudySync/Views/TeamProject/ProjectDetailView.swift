import SwiftUI

struct ProjectDetailView: View {
    let project: TeamProject
    @Bindable var viewModel: TeamProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasAppeared = false
    @State private var meetingPulse = false

    private var color: Color { Color(hex: currentProject.colorHex) }
    private var currentProject: TeamProject { viewModel.currentProject ?? project }

    var body: some View {
        ZStack {
            SSColor.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: SSSpacing.xl) {
                    // Header
                    headerSection
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)

                    // Invite banner (when alone)
                    if currentProject.memberCount == 1 {
                        inviteBanner
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 15)
                    }

                    // Stats
                    statsRow
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)

                    // Timeline
                    timelineCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)

                    // Meeting time finder
                    if currentProject.memberCount >= 2 {
                        meetingTimeCard
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 10)

                        // Quick meeting
                        quickMeetingCard
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 10)

                        // Meetup session
                        meetupCard
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 10)
                    }

                    // Filter
                    filterPicker

                    // Dues list
                    duesSection

                    // #5 Error message
                    if let error = viewModel.errorMessage {
                        HStack(spacing: SSSpacing.md) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(SSFont.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                withAnimation { viewModel.errorMessage = nil }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(SSSpacing.lg)
                        .background(.orange.opacity(SSOpacity.shadow), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.top, SSSpacing.md)
                .padding(.bottom, SSSpacing.xxl)
                .animation(.spring(duration: 0.5), value: hasAppeared)
            }
            // #1 Pull-to-refresh
            .refreshable {
                viewModel.stopListening()
                viewModel.startListening(to: project)
            }
        }
        .navigationTitle(currentProject.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: SSSpacing.lg) {
                    Button {
                        viewModel.showingAddDue = true
                        HapticEngine.shared.lightImpact()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(color)
                    }

                    NavigationLink {
                        ProjectSettingsView(viewModel: viewModel)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddDue) {
            AddProjectDueView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingStartMeeting) {
            StartMeetingSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingCreateMeetup) {
            CreateMeetupSheet(viewModel: viewModel)
        }
        .alert(L10n.meetupEndConfirm, isPresented: $viewModel.showingEndMeetup) {
            Button(L10n.meetupEnd, role: .destructive) {
                Task { await viewModel.endMeetup() }
                HapticEngine.shared.warning()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.meetupEndWarning)
        }
        .alert(L10n.meetingEndConfirm, isPresented: $viewModel.showingEndMeeting) {
            Button(L10n.meetingEnd, role: .destructive) {
                Task { await viewModel.endMeeting() }
                HapticEngine.shared.warning()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.meetingEndWarning)
        }
        .onAppear {
            viewModel.startListening(to: project)
            InAppNotificationManager.shared.markProjectDuesSeen(projectId: project.id)
            withAnimation(.spring(duration: 0.5)) { hasAppeared = true }
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: SSSpacing.lg) {
            Text(currentProject.emoji)
                .font(.system(size: 42))

            // Members avatars
            HStack(spacing: -8) {
                ForEach(currentProject.memberProfiles.prefix(6)) { member in
                    Text(member.avatarEmoji)
                        .font(.system(size: 20))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color(.tertiarySystemFill))
                        )
                        .overlay(
                            Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2)
                        )
                }
            }

            Text(L10n.projectMemberCount(currentProject.memberCount))
                .font(SSFont.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.large, style: .continuous)
                .fill(color.opacity(colorScheme == .dark ? SSOpacity.shadow : 0.05))
        )
        .background(
            RoundedRectangle(cornerRadius: SSRadius.large, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Invite Banner

    private var inviteBanner: some View {
        HStack(spacing: SSSpacing.mdLg) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "#FFD93D"))

            Text(L10n.projectInviteBanner)
                .font(SSFont.caption)
                .foregroundStyle(.primary)

            Spacer()

            NavigationLink {
                InviteFriendToProjectView(viewModel: viewModel)
            } label: {
                Text(L10n.projectInviteFriend)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, SSSpacing.lg)
                    .padding(.vertical, SSSpacing.sm)
                    .background(Capsule().fill(SSColor.brand))
            }
        }
        .padding(SSSpacing.lgXl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(Color(hex: "#FFD93D").opacity(0.1))
        )
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: SSSpacing.lg) {
            statBadge(
                icon: "checkmark.circle.fill",
                value: L10n.projectDueStats(viewModel.completedDueCount, viewModel.totalDueCount),
                iconColor: .green
            )

            if let days = viewModel.nextDeadlineDays {
                statBadge(
                    icon: days < 0 ? "exclamationmark.triangle.fill" : "clock.fill",
                    value: L10n.projectNextDeadline(days),
                    iconColor: days <= 1 ? .red : .orange
                )
            }
        }
    }

    private func statBadge(icon: String, value: String, iconColor: Color) -> some View {
        HStack(spacing: SSSpacing.sm) {
            Image(systemName: icon)
                .font(SSFont.caption)
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, SSSpacing.lg)
        .padding(.vertical, SSSpacing.md)
        .background(
            Capsule().fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Timeline Card

    private var timelineCard: some View {
        NavigationLink {
            ProjectTimelineView(viewModel: viewModel)
        } label: {
            HStack(spacing: SSSpacing.lg) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: "#A78BFA"))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color(hex: "#A78BFA").opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.projectTimeline)
                        .font(SSFont.bodyMedium)
                        .foregroundStyle(.primary)

                    if let latest = viewModel.activities.first {
                        Text(latest.type.description(actorName: latest.actorName, detail: latest.detail))
                            .font(SSFont.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(SSSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                    .fill(SSColor.backgroundCard)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Meeting Time Card

    private var meetingTimeCard: some View {
        NavigationLink {
            MeetingTimeView(project: currentProject)
        } label: {
            HStack(spacing: SSSpacing.lg) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 22))
                    .foregroundStyle(SSColor.life)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(SSColor.life.opacity(SSOpacity.tagBackground))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.avFindMeetingTime)
                        .font(SSFont.bodyMedium)
                        .foregroundStyle(.primary)
                    Text(L10n.avFindMeetingTimeDesc)
                        .font(SSFont.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(SSSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                    .fill(SSColor.backgroundCard)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Meeting Card

    @ViewBuilder
    private var quickMeetingCard: some View {
        if let meeting = currentProject.activeMeeting {
            activeMeetingCard(meeting)
        } else {
            startMeetingButton
        }
    }

    private var startMeetingButton: some View {
        Button {
            viewModel.showingStartMeeting = true
            HapticEngine.shared.lightImpact()
        } label: {
            HStack(spacing: SSSpacing.lg) {
                Image(systemName: "video.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(SSColor.brand)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(SSColor.brand.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.meetingStart)
                        .font(SSFont.bodyMedium)
                        .foregroundStyle(.primary)
                    Text(L10n.meetingStartDesc)
                        .font(SSFont.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(SSColor.brand)
            }
            .padding(SSSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                    .fill(SSColor.backgroundCard)
            )
        }
        .buttonStyle(.plain)
    }

    private func activeMeetingCard(_ meeting: ActiveMeeting) -> some View {
        VStack(spacing: SSSpacing.lg) {
            // Header: LIVE badge + platform + duration
            HStack(spacing: SSSpacing.md) {
                // Live indicator
                HStack(spacing: SSSpacing.xs) {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                        .opacity(meetingPulse ? 1 : 0.3)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: meetingPulse)
                        .onAppear { meetingPulse = true }

                    Text(L10n.meetingLive)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, SSSpacing.sm)
                .padding(.vertical, 3)
                .background(Capsule().fill(.red.opacity(0.1)))

                Image(systemName: meeting.platform.icon)
                    .font(SSFont.secondary)
                    .foregroundStyle(Color(hex: meeting.platform.colorHex))

                Text(meeting.platform.displayName)
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Duration timer
                Text(meeting.startedAt, style: .timer)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Creator info
            HStack(spacing: SSSpacing.md) {
                Text(meeting.creatorEmoji)
                    .font(SSFont.body)
                Text(L10n.meetingStartedBy(meeting.creatorName))
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Action buttons
            HStack(spacing: SSSpacing.lg) {
                // Join button
                Button {
                    if let url = URL(string: meeting.meetingLink) {
                        UIApplication.shared.open(url)
                    }
                    HapticEngine.shared.lightImpact()
                } label: {
                    HStack(spacing: SSSpacing.sm) {
                        Image(systemName: "video.fill")
                            .font(SSFont.secondary)
                        Text(L10n.meetingJoin)
                            .font(SSFont.chipLabel)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SSSpacing.mdLg)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                            .fill(Color(hex: meeting.platform.colorHex))
                    )
                }

                // End button (creator or project owner only)
                if let uid = viewModel.currentUid,
                   uid == meeting.createdBy || viewModel.isOwner(uid: uid) {
                    Button {
                        viewModel.showingEndMeeting = true
                    } label: {
                        HStack(spacing: SSSpacing.sm) {
                            Image(systemName: "phone.down.fill")
                                .font(SSFont.secondary)
                            Text(L10n.meetingEnd)
                                .font(SSFont.chipLabel)
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SSSpacing.mdLg)
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                .fill(.red.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .stroke(Color(hex: meeting.platform.colorHex).opacity(SSOpacity.elevatedShadow), lineWidth: 1)
        )
    }

    // MARK: - Meetup Card

    @ViewBuilder
    private var meetupCard: some View {
        if let meetup = currentProject.activeMeetup {
            activeMeetupCard(meetup)
        } else {
            createMeetupButton
        }
    }

    private var createMeetupButton: some View {
        Button {
            viewModel.showingCreateMeetup = true
            HapticEngine.shared.lightImpact()
        } label: {
            HStack(spacing: SSSpacing.lg) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(SSColor.meetup)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(SSColor.meetup.opacity(SSOpacity.tagBackground))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.meetupCreate)
                        .font(SSFont.bodyMedium)
                        .foregroundStyle(.primary)
                    Text(L10n.meetupCreateDesc)
                        .font(SSFont.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(SSColor.meetup)
            }
            .padding(SSSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                    .fill(SSColor.backgroundCard)
            )
        }
        .buttonStyle(.plain)
    }

    @State private var meetupPulse = false

    private func activeMeetupCard(_ meetup: MeetupSession) -> some View {
        VStack(spacing: SSSpacing.lg) {
            // Header
            HStack(spacing: SSSpacing.md) {
                HStack(spacing: SSSpacing.xs) {
                    Circle()
                        .fill(SSColor.meetup)
                        .frame(width: 6, height: 6)
                        .opacity(meetupPulse ? 1 : 0.3)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: meetupPulse)
                        .onAppear { meetupPulse = true }

                    Text(L10n.meetupActive)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(SSColor.meetup)
                }
                .padding(.horizontal, SSSpacing.sm)
                .padding(.vertical, 3)
                .background(Capsule().fill(SSColor.meetup.opacity(SSOpacity.border)))

                Spacer()

                // Countdown
                Text(meetup.meetupTime, style: .relative)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Place info
            HStack(spacing: SSSpacing.md) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(SSColor.meetup)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meetup.title)
                        .font(SSFont.bodyMedium)
                    Text(meetup.placeName)
                        .font(SSFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Attendee count
            HStack(spacing: SSSpacing.md) {
                Text(meetup.creatorEmoji)
                    .font(SSFont.secondary)
                Text(L10n.meetupAttendees(meetup.attendeeIds.count))
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Action buttons
            HStack(spacing: SSSpacing.lg) {
                NavigationLink {
                    MeetupDetailView(meetup: meetup, viewModel: viewModel)
                } label: {
                    HStack(spacing: SSSpacing.sm) {
                        Image(systemName: "map.fill")
                            .font(SSFont.secondary)
                        Text(L10n.meetupViewDetails)
                            .font(SSFont.chipLabel)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SSSpacing.mdLg)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                            .fill(SSColor.meetup)
                    )
                }

                if let uid = viewModel.currentUid {
                    if uid == meetup.createdBy {
                        // Creator → direct end
                        Button {
                            viewModel.showingEndMeetup = true
                        } label: {
                            HStack(spacing: SSSpacing.sm) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(SSFont.secondary)
                                Text(L10n.meetupEnd)
                                    .font(SSFont.chipLabel)
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SSSpacing.mdLg)
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                    .fill(.red.opacity(0.1))
                            )
                        }
                    } else if meetup.attendeeIds.contains(uid) {
                        // Member → vote to cancel
                        let hasVoted = meetup.cancelVotes.contains(uid)
                        Button {
                            Task { await viewModel.voteCancelMeetup() }
                            HapticEngine.shared.lightImpact()
                        } label: {
                            HStack(spacing: SSSpacing.sm) {
                                Image(systemName: hasVoted ? "checkmark.circle.fill" : "hand.raised.fill")
                                    .font(SSFont.secondary)
                                Text(hasVoted ? L10n.meetupCancelVoted : L10n.meetupCancelVote)
                                    .font(SSFont.chipLabel)
                                Text("\(meetup.cancelVotes.count)/\(meetup.cancelVotesNeeded)")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                            }
                            .foregroundStyle(hasVoted ? Color.secondary : Color.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SSSpacing.mdLg)
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                    .fill(hasVoted ? Color(.tertiarySystemFill) : .red.opacity(0.1))
                            )
                        }
                        .disabled(hasVoted)
                    }
                }
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .stroke(SSColor.meetup.opacity(SSOpacity.elevatedShadow), lineWidth: 1)
        )
    }

    // MARK: - Filter

    private var filterPicker: some View {
        HStack(spacing: SSSpacing.md) {
            ForEach(TeamProjectViewModel.DueFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        viewModel.dueFilter = filter
                    }
                    HapticEngine.shared.selection()
                } label: {
                    Text(filter.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(viewModel.dueFilter == filter ? .white : .primary)
                        .padding(.horizontal, SSSpacing.lgXl)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(viewModel.dueFilter == filter ? color : Color(.tertiarySystemFill))
                        )
                }
            }
            Spacer()
        }
    }

    // MARK: - Dues

    private var duesSection: some View {
        VStack(spacing: SSSpacing.mdLg) {
            if viewModel.filteredDues.isEmpty {
                VStack(spacing: SSSpacing.lg) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text(L10n.projectNoDues)
                        .font(SSFont.bodySmallMedium)
                        .foregroundStyle(.secondary)
                    Text(L10n.projectNoDuesDesc)
                        .font(SSFont.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(viewModel.filteredDues) { due in
                    ProjectDueRow(
                        due: due,
                        project: currentProject,
                        viewModel: viewModel
                    )
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(
            project: TeamProject(name: "CS 341 Group", emoji: "💻", colorHex: "#5B7FFF", createdBy: "test"),
            viewModel: TeamProjectViewModel()
        )
    }
}
