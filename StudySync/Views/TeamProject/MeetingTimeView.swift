import SwiftUI
import FirebaseAuth

struct MeetingTimeView: View {
    let project: TeamProject

    private var service: AvailabilityService { .shared }
    private var firestore: FirestoreService { .shared }

    @State private var meetingSlots: [AvailabilityService.MeetingSlot] = []
    @State private var sharingMembers: [ProjectMember] = []  // All members in the calculation (including self)
    @State private var isLoading = true
    @State private var hasAppeared = false
    @State private var tooFewMembers = false  // Only self is participating, no real "meeting"

    private var color: Color { Color(hex: project.colorHex) }

    var body: some View {
        ScrollView {
            VStack(spacing: SSSpacing.xl) {
                if isLoading {
                    loadingState
                } else if sharingMembers.isEmpty {
                    noSharingState
                } else if tooFewMembers {
                    tooFewState
                } else if meetingSlots.isEmpty {
                    noMeetingState
                } else {
                    participantsBar
                    slotsHeader
                    slotsList
                }
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.top, SSSpacing.md)
            .padding(.bottom, SSSpacing.xxxl)
            .animation(.spring(duration: 0.5), value: hasAppeared)
        }
        .background {
            SSColor.backgroundPrimary.ignoresSafeArea()
        }
        .navigationTitle(L10n.avMeetingTime)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMeetingTimes()
            withAnimation(.spring(duration: 0.5)) { hasAppeared = true }
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: SSSpacing.lg) {
            Spacer().frame(height: 80)
            ProgressView()
            Text(L10n.avMeetingLoading)
                .font(SSFont.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - No Sharing Members

    private var noSharingState: some View {
        VStack(spacing: SSSpacing.lg) {
            Spacer().frame(height: 60)
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(L10n.avNoSharingMembers)
                .font(SSFont.heading3)
                .foregroundStyle(.secondary)
            Text(L10n.avNoSharingMembersDesc)
                .font(SSFont.secondary)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
    }

    // MARK: - Too Few Members (only self)

    private var tooFewState: some View {
        VStack(spacing: SSSpacing.lg) {
            Spacer().frame(height: 60)
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(L10n.avNoSharingMembers)
                .font(SSFont.heading3)
                .foregroundStyle(.secondary)
            Text(L10n.avNoSharingMembersDesc)
                .font(SSFont.secondary)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
    }

    // MARK: - No Meeting Time

    private var noMeetingState: some View {
        VStack(spacing: SSSpacing.lg) {
            participantsBar

            Spacer().frame(height: 40)
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(L10n.avNoMeetingTime)
                .font(SSFont.heading3)
                .foregroundStyle(.secondary)
            Text(L10n.avNoMeetingTimeDesc)
                .font(SSFont.secondary)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
    }

    // MARK: - Participants Bar

    private var participantsBar: some View {
        HStack(spacing: SSSpacing.md) {
            // Member avatars
            HStack(spacing: -6) {
                ForEach(sharingMembers.prefix(5)) { member in
                    Text(member.avatarEmoji)
                        .font(.system(size: 16))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(Color(.tertiarySystemFill))
                        )
                        .overlay(
                            Circle().stroke(SSColor.backgroundCard, lineWidth: 1.5)
                        )
                }
            }

            Text(L10n.avMeetingParticipants(sharingMembers.count))
                .font(SSFont.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(SSSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 15)
    }

    // MARK: - Slots Header

    private var slotsHeader: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
            Text(L10n.avMeetingSlotsFound(meetingSlots.count))
                .font(SSFont.sectionHeader)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 10)
    }

    // MARK: - Slots List

    private var slotsList: some View {
        let grouped = Dictionary(grouping: meetingSlots) { $0.dateString }
        let sortedDates = service.weekDateStrings.filter { grouped[$0] != nil }

        return ForEach(sortedDates, id: \.self) { dateStr in
            VStack(alignment: .leading, spacing: SSSpacing.md) {
                // Date header
                Text(Self.formatDateHeader(dateStr))
                    .font(SSFont.sectionHeader)
                    .foregroundStyle(.secondary)
                    .padding(.top, SSSpacing.xs)

                // Time slots for this date
                ForEach(grouped[dateStr] ?? []) { slot in
                    meetingSlotRow(slot)
                }
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 10)
        }
    }

    private func meetingSlotRow(_ slot: AvailabilityService.MeetingSlot) -> some View {
        HStack(spacing: SSSpacing.lg) {
            // Time range
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(slot.startTime) – \(slot.endTime)")
                    .font(SSFont.bodyMedium)
                Text(Self.formatDuration(minutes: slot.durationMinutes))
                    .font(SSFont.badge)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Green indicator
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
        .padding(SSSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(.green.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .strokeBorder(.green.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Load

    private func loadMeetingTimes() async {
        isLoading = true

        let myUid = AuthService.shared.currentUser?.uid

        // Current user is ALWAYS included (they're the one looking for a meeting).
        // Other members are only included if they enabled shareAvailability.
        var sharing: [ProjectMember] = []
        await withTaskGroup(of: (ProjectMember, Bool).self) { group in
            for member in project.memberProfiles {
                group.addTask {
                    // Self → always included
                    if member.id == myUid {
                        return (member, true)
                    }
                    // Others → check their shareAvailability setting
                    if let profile = await self.firestore.getUserProfile(uid: member.id) {
                        return (member, profile.shareAvailability)
                    }
                    return (member, false)
                }
            }
            for await (member, enabled) in group {
                if enabled { sharing.append(member) }
            }
        }

        sharingMembers = sharing.sorted { $0.displayName < $1.displayName }

        // Need at least 2 participants for a meaningful "meeting time"
        if sharingMembers.count >= 2 {
            let uids = sharingMembers.map(\.id)
            meetingSlots = await service.computeMeetingTimes(memberUids: uids)
            tooFewMembers = false
        } else if sharingMembers.count == 1 {
            // Only current user — no other members sharing
            tooFewMembers = true
        }
        // sharingMembers.isEmpty → noSharingState (shouldn't happen since self is always included)

        isLoading = false
    }

    // MARK: - Helpers

    private static func makeHeaderDateFmt() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MMMdEEEE")
        return f
    }

    private static let headerParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func formatDateHeader(_ dateStr: String) -> String {
        guard let date = headerParser.date(from: dateStr) else { return dateStr }
        let cal = Calendar.current
        let fmt = makeHeaderDateFmt()
        let base = fmt.string(from: date)
        if cal.isDateInToday(date) {
            return base + " (\(L10n.avToday))"
        } else if cal.isDateInTomorrow(date) {
            return base + " (\(L10n.avTomorrow))"
        }
        return base
    }

    static func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)min"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)min"
        }
    }
}
