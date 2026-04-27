import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct StudyRoomView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var members: [StudyRoomMember] = []
    @State private var listener: ListenerRegistration?

    private let firestore = FirestoreService.shared
    private var currentUid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SSSpacing.xl) {
                    // Header
                    headerCard

                    if members.isEmpty {
                        emptyState
                    } else {
                        // Member grid
                        LazyVGrid(columns: iPadGridColumns(iPhone: 2, scale: 2.0, spacing: SSSpacing.lg, sizeClass: hSizeClass), spacing: SSSpacing.lg) {
                            ForEach(members) { member in
                                memberCard(member)
                            }
                        }
                    }
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.top, SSSpacing.md)
                .padding(.bottom, SSSpacing.xxxl)
            }
            .background(SSColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(L10n.studyRoomTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { startListening() }
            .onDisappear { stopListening() }
        }
    }

    private var headerCard: some View {
        HStack(spacing: SSSpacing.lg) {
            Image(systemName: "person.2.fill")
                .font(.title2)
                .foregroundStyle(SSColor.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.studyRoomOnline(members.count))
                    .font(SSFont.bodyMedium)
                Text(L10n.studyRoomDesc)
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(SSSpacing.xl)
        .background(RoundedRectangle(cornerRadius: SSRadius.card).fill(SSColor.backgroundCard))
    }

    private func memberCard(_ member: StudyRoomMember) -> some View {
        VStack(spacing: SSSpacing.md) {
            // Avatar
            Text(member.avatarEmoji)
                .font(.system(size: 36))
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color(.tertiarySystemFill)))

            // Name
            Text(member.displayName)
                .font(SSFont.chipLabel)
                .lineLimit(1)

            // Focus info
            HStack(spacing: SSSpacing.xs) {
                Text(member.focusEmoji)
                    .font(SSFont.secondary)
                Text("\(member.elapsedMinutes)m / \(member.focusDurationMinutes)m")
                    .font(SSFont.mono)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.tertiarySystemFill))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(colors: [SSColor.brand, SSColor.brandPurple],
                                          startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * member.progress)
                }
            }
            .frame(height: 4)

            // "Is me" badge
            if member.id == currentUid {
                Text(L10n.studyRoomMe)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, SSSpacing.md)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(SSColor.brand))
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                        .strokeBorder(
                            member.id == currentUid ? SSColor.brand.opacity(SSOpacity.elevatedShadow) : .clear,
                            lineWidth: 1
                        )
                )
        )
    }

    private var emptyState: some View {
        SSEmptyStateView(
            systemImage: "moon.zzz.fill",
            title: L10n.studyRoomEmpty
        )
        .padding(.vertical, SSSpacing.xxxl)
    }

    private func startListening() {
        listener = firestore.listenToStudyRoom { members in
            // Filter out stale members (no update in 2x their duration or 3 hours, whichever is shorter)
            let now = Date()
            self.members = members.filter { member in
                let maxStale = min(TimeInterval(member.focusDurationMinutes * 60 * 2), 3 * 3600)
                return now.timeIntervalSince(member.updatedAt) < maxStale
            }
            .sorted { $0.startedAt < $1.startedAt }
        }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }
}
