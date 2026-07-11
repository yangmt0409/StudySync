import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore

struct GroupFocusView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var groupRingSize: CGFloat {
        ipScaled(200, scale: 1.4, sizeClass: hSizeClass)
    }

    @State private var rooms: [GroupFocusRoom] = []
    @State private var currentRoom: GroupFocusRoom?
    @State private var listener: ListenerRegistration?
    @State private var roomTimer: Timer?
    @State private var tickCounter: Int = 0  // forces UI refresh every second

    // Create room
    @State private var showCreateSheet = false
    @State private var createDuration: Int = 25
    @State private var createEmoji: String = "📚"
    @State private var isCreating = false
    @State private var didSaveLocalSession = false

    private var currentUid: String? { Auth.auth().currentUser?.uid }
    private let firestore = FirestoreService.shared

    private let presetMinutes = [15, 25, 30, 45, 60]
    private let emojis = ["📚", "💻", "✍️", "🎯", "🧪", "📐", "🎨", "🔬"]

    var body: some View {
        NavigationStack {
            Group {
                if let room = currentRoom {
                    if room.isWaiting {
                        waitingRoomView(room)
                    } else {
                        activeSessionView(room)
                    }
                } else {
                    roomListView
                }
            }
            .background(SSColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(L10n.groupFocusTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        leaveIfNeeded()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                createRoomSheet
            }
            .onAppear {
                Task { rooms = await firestore.fetchActiveGroupFocusRooms() }
            }
            .onDisappear {
                listener?.remove()
                roomTimer?.invalidate()
            }
        }
    }

    // MARK: - Room List

    private var roomListView: some View {
        ScrollView {
            VStack(spacing: SSSpacing.xl) {
                // 1.5x bonus banner
                HStack(spacing: SSSpacing.md) {
                    Text("⚡️")
                        .font(SSFont.emojiLarge)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.groupFocusBonus)
                            .font(SSFont.bodySemibold)
                        Text(L10n.groupFocusBonusDesc)
                            .font(SSFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("1.5x")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "#F59E0B"))
                }
                .padding(SSSpacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: SSRadius.card)
                        .fill(Color(hex: "#F59E0B").opacity(SSOpacity.shadow))
                        .overlay(RoundedRectangle(cornerRadius: SSRadius.card).strokeBorder(Color(hex: "#F59E0B").opacity(0.2), lineWidth: 1))
                )

                // Create button
                Button { showCreateSheet = true } label: {
                    HStack(spacing: SSSpacing.md) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text(L10n.groupFocusCreate)
                            .font(SSFont.bodySemibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SSSpacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.card)
                            .fill(LinearGradient(colors: [SSColor.brand, SSColor.brandPurple], startPoint: .leading, endPoint: .trailing))
                    )
                }

                // Active rooms
                if rooms.isEmpty {
                    VStack(spacing: SSSpacing.md) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text(L10n.groupFocusNoRooms)
                            .font(SSFont.secondary)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SSSpacing.xxxl)
                } else {
                    VStack(spacing: SSSpacing.md) {
                        Text(L10n.groupFocusActiveRooms)
                            .font(SSFont.sectionHeader)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(rooms) { room in
                            roomRow(room)
                        }
                    }
                }
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.top, SSSpacing.md)
            .padding(.bottom, SSSpacing.xxxl)
        }
    }

    private func roomRow(_ room: GroupFocusRoom) -> some View {
        Button {
            Task { await joinRoom(room) }
        } label: {
            HStack(spacing: SSSpacing.lg) {
                Text(room.focusEmoji)
                    .font(SSFont.emojiLarge)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(.tertiarySystemFill)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(room.hostEmoji) \(room.hostName)")
                        .font(SSFont.bodyMedium)
                    HStack(spacing: SSSpacing.md) {
                        Label("\(room.durationMinutes) min", systemImage: "clock")
                        Label("\(room.members.count)", systemImage: "person.2")
                    }
                    .font(SSFont.footnote)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(L10n.groupFocusJoin)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, SSSpacing.lgXl)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(SSColor.brand))
            }
            .padding(SSSpacing.xl)
            .background(RoundedRectangle(cornerRadius: SSRadius.card).fill(SSColor.backgroundCard))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create Room Sheet

    private var createRoomSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SSSpacing.xxl) {
                    // Duration picker
                    VStack(alignment: .leading, spacing: SSSpacing.mdLg) {
                        Text(L10n.focusDuration)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: SSSpacing.md) {
                            ForEach(presetMinutes, id: \.self) { mins in
                                Button {
                                    createDuration = mins
                                    HapticEngine.shared.selection()
                                } label: {
                                    Text("\(mins)")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(createDuration == mins ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(
                                            RoundedRectangle(cornerRadius: SSRadius.fieldCard)
                                                .fill(createDuration == mins
                                                      ? LinearGradient(colors: [SSColor.brand, SSColor.brandPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                      : LinearGradient(colors: [Color(.tertiarySystemFill)], startPoint: .top, endPoint: .bottom))
                                        )
                                }
                            }
                        }
                    }

                    // Emoji picker
                    HStack(spacing: 0) {
                        ForEach(emojis, id: \.self) { e in
                            Button {
                                createEmoji = e
                                HapticEngine.shared.selection()
                            } label: {
                                Text(e)
                                    .font(.system(size: 26))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(
                                        Circle().fill(createEmoji == e ? SSColor.brandPurple.opacity(SSOpacity.lightTint) : .clear)
                                            .frame(width: 42, height: 42)
                                    )
                            }
                        }
                    }
                    .padding(SSSpacing.md)
                    .background(RoundedRectangle(cornerRadius: SSRadius.card).fill(SSColor.backgroundCard))

                    // 1.5x reminder
                    HStack(spacing: SSSpacing.sm) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color(hex: "#F59E0B"))
                        Text(L10n.groupFocusBonusReminder)
                            .font(SSFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.top, SSSpacing.xl)
            }
            .background(SSColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(L10n.groupFocusCreate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { showCreateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.groupFocusStart) {
                        Task {
                            isCreating = true
                            await createRoom()
                            isCreating = false
                            showCreateSheet = false
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isCreating)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Waiting Room

    private func waitingRoomView(_ room: GroupFocusRoom) -> some View {
        ScrollView {
            VStack(spacing: SSSpacing.xl) {
                // Info header
                VStack(spacing: SSSpacing.md) {
                    Text(room.focusEmoji)
                        .font(.system(size: 56))
                    Text("\(room.durationMinutes) min")
                        .font(SSFont.countdownLarge)
                    Text(L10n.groupFocusWaiting)
                        .font(SSFont.secondary)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, SSSpacing.xl)

                // Members list
                VStack(spacing: SSSpacing.md) {
                    ForEach(room.members) { member in
                        HStack(spacing: SSSpacing.lg) {
                            Text(member.avatarEmoji)
                                .font(SSFont.emojiLarge)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color(.tertiarySystemFill)))

                            Text(member.displayName)
                                .font(SSFont.bodyMedium)

                            Spacer()

                            if member.id == room.hostUid {
                                Text(L10n.groupFocusHost)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, SSSpacing.md)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.orange.opacity(SSOpacity.tagBackground)))
                            }

                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .padding(SSSpacing.xl)
                        .background(RoundedRectangle(cornerRadius: SSRadius.card).fill(SSColor.backgroundCard))
                    }
                }

                // Host controls
                if room.hostUid == currentUid {
                    Button {
                        Task { await firestore.startGroupFocus(roomId: room.id) }
                        HapticEngine.shared.success()
                    } label: {
                        HStack(spacing: SSSpacing.md) {
                            Image(systemName: "play.fill")
                            Text(L10n.groupFocusStartAll)
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.card)
                                .fill(LinearGradient(colors: [SSColor.brand, SSColor.brandPurple], startPoint: .leading, endPoint: .trailing))
                        )
                    }
                    .disabled(room.members.count < 2)
                    .opacity(room.members.count < 2 ? 0.5 : 1)

                    if room.members.count < 2 {
                        Text(L10n.groupFocusNeedMore)
                            .font(SSFont.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text(L10n.groupFocusWaitingHost)
                        .font(SSFont.secondary)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.top, SSSpacing.md)
            .padding(.bottom, SSSpacing.xxxl)
        }
    }

    // MARK: - Active Session

    private func activeSessionView(_ room: GroupFocusRoom) -> some View {
        let _ = tickCounter  // force refresh

        return ScrollView {
            VStack(spacing: SSSpacing.xl) {
                // Timer ring
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemFill), lineWidth: 10)
                        .frame(width: groupRingSize, height: groupRingSize)

                    Circle()
                        .trim(from: 0, to: room.progress)
                        .stroke(
                            AngularGradient(colors: [SSColor.brand, SSColor.brandPurple, SSColor.brand], center: .center),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: groupRingSize, height: groupRingSize)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: SSSpacing.xs) {
                        Text(room.focusEmoji)
                            .font(.system(size: 32))
                        Text(formatTime(room.remainingSeconds))
                            .font(.system(size: 36, weight: .thin, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                .padding(.vertical, SSSpacing.xl)

                // 1.5x bonus badge
                HStack(spacing: SSSpacing.sm) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color(hex: "#F59E0B"))
                    Text(L10n.groupFocusBonusActive)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#F59E0B"))
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.vertical, SSSpacing.md)
                .background(
                    Capsule().fill(Color(hex: "#F59E0B").opacity(0.1))
                        .overlay(Capsule().strokeBorder(Color(hex: "#F59E0B").opacity(0.2), lineWidth: 1))
                )

                // Members status
                VStack(spacing: SSSpacing.md) {
                    ForEach(room.members) { member in
                        HStack(spacing: SSSpacing.lg) {
                            Text(member.avatarEmoji)
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle().fill(
                                        member.gaveUp ? Color.red.opacity(0.1) :
                                        member.isCompleted ? Color.green.opacity(0.1) :
                                        Color(.tertiarySystemFill)
                                    )
                                )
                                .overlay(
                                    Circle().strokeBorder(
                                        member.isFocusing ? SSColor.brand.opacity(0.5) : .clear,
                                        lineWidth: 2
                                    )
                                )

                            Text(member.displayName)
                                .font(SSFont.bodyMedium)
                                .foregroundStyle(member.gaveUp ? .secondary : .primary)

                            Spacer()

                            Group {
                                if member.isCompleted {
                                    Label(L10n.done, systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if member.gaveUp {
                                    Label(L10n.groupFocusGaveUp, systemImage: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                } else {
                                    Label(L10n.focusInProgress, systemImage: "circle.dotted")
                                        .foregroundStyle(SSColor.brand)
                                }
                            }
                            .font(.system(size: 12, weight: .medium))
                        }
                        .padding(SSSpacing.lg)
                        .background(RoundedRectangle(cornerRadius: SSRadius.medium).fill(SSColor.backgroundCard))
                    }
                }

                // My controls (if I'm still focusing)
                if let me = room.members.first(where: { $0.id == currentUid }), me.isFocusing {
                    Button {
                        // Stop the local tick timer immediately — otherwise it
                        // keeps running and, when it reaches 0, overwrites this
                        // "gaveUp" with "completed" (crediting an abandoned
                        // session a full 1.5x reward).
                        roomTimer?.invalidate()
                        roomTimer = nil
                        Task {
                            await firestore.updateGroupFocusMemberStatus(roomId: room.id, uid: currentUid ?? "", status: "gaveUp")
                        }
                        HapticEngine.shared.warning()
                    } label: {
                        HStack(spacing: SSSpacing.md) {
                            Image(systemName: "xmark")
                            Text(L10n.focusGiveUpConfirm)
                        }
                        .font(SSFont.bodySmallMedium)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SSSpacing.lgXl)
                        .background(RoundedRectangle(cornerRadius: SSRadius.medium).fill(.red.opacity(SSOpacity.shadow)))
                    }
                }

                // Completed state
                if room.isCompleted {
                    VStack(spacing: SSSpacing.lg) {
                        Text("🎉")
                            .font(SSFont.displayIcon)
                        Text(L10n.groupFocusCompleted)
                            .font(SSFont.heading2)

                        let completedCount = room.members.filter(\.isCompleted).count
                        Text(L10n.groupFocusCompletedDesc(completedCount, room.members.count))
                            .font(SSFont.secondary)
                            .foregroundStyle(.secondary)

                        Button {
                            dismiss()
                        } label: {
                            Text(L10n.done)
                                .font(SSFont.bodySemibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, SSSpacing.lgXl)
                                .background(RoundedRectangle(cornerRadius: SSRadius.medium).fill(LinearGradient(colors: [SSColor.brand, SSColor.brandPurple], startPoint: .leading, endPoint: .trailing)))
                        }
                    }
                    .padding(SSSpacing.xl)
                    .background(RoundedRectangle(cornerRadius: SSRadius.card).fill(SSColor.backgroundCard))
                }
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.top, SSSpacing.md)
            .padding(.bottom, SSSpacing.xxxl)
        }
    }

    // MARK: - Actions

    private func createRoom() async {
        guard let uid = currentUid else {
            debugPrint("[GroupFocus] createRoom failed: currentUid is nil")
            return
        }
        guard let profile = AuthService.shared.userProfile else {
            debugPrint("[GroupFocus] createRoom failed: userProfile is nil")
            return
        }

        let roomId = UUID().uuidString
        let member = GroupFocusMember(id: uid, displayName: profile.displayName, avatarEmoji: profile.avatarEmoji, status: "ready")
        let room = GroupFocusRoom(
            id: roomId,
            hostUid: uid,
            hostName: profile.displayName,
            hostEmoji: profile.avatarEmoji,
            durationMinutes: createDuration,
            focusEmoji: createEmoji,
            status: "waiting",
            startedAt: nil,
            createdAt: Date(),
            memberUids: [uid],
            members: [member]
        )

        await firestore.createGroupFocus(room: room)
        startListening(roomId: roomId)
        HapticEngine.shared.success()
    }

    private func joinRoom(_ room: GroupFocusRoom) async {
        guard let uid = currentUid, let profile = AuthService.shared.userProfile else { return }
        guard !room.memberUids.contains(uid) else {
            // Already in room, just listen
            startListening(roomId: room.id)
            return
        }

        let member = GroupFocusMember(id: uid, displayName: profile.displayName, avatarEmoji: profile.avatarEmoji, status: "ready")
        await firestore.joinGroupFocus(roomId: room.id, member: member)
        startListening(roomId: room.id)
        HapticEngine.shared.success()
    }

    private func startListening(roomId: String) {
        listener?.remove()
        listener = firestore.listenToGroupFocus(roomId: roomId) { room in
            let wasWaiting = self.currentRoom?.isWaiting == true
            self.currentRoom = room

            // When room transitions to running, save a local FocusSession and start a tick timer
            if let room, room.isRunning, wasWaiting {
                self.startLocalSession(room: room)
            }

            // When room completes, finalize local session with 1.5x bonus
            if let room, room.isCompleted {
                self.completeLocalSession(room: room)
                self.roomTimer?.invalidate()
            }
        }
    }

    private func startLocalSession(room: GroupFocusRoom) {
        // Update my member status to focusing
        Task {
            await firestore.updateGroupFocusMemberStatus(roomId: room.id, uid: currentUid ?? "", status: "focusing")
        }

        // Start a tick timer for UI refresh
        roomTimer?.invalidate()
        roomTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tickCounter += 1

            // Check if timer completed. Only auto-complete if I'm still
            // focusing — a member who gave up (or whose status moved on) must
            // not be flipped back to "completed" by a surviving timer.
            if let room = currentRoom, room.remainingSeconds <= 0, room.isRunning,
               room.members.first(where: { $0.id == currentUid })?.isFocusing == true {
                Task {
                    await firestore.updateGroupFocusMemberStatus(roomId: room.id, uid: currentUid ?? "", status: "completed")
                }
                roomTimer?.invalidate()
            }
        }
        if let roomTimer { RunLoop.current.add(roomTimer, forMode: .common) }

        HapticEngine.shared.success()
    }

    private func completeLocalSession(room: GroupFocusRoom) {
        guard !didSaveLocalSession else { return }  // prevent duplicate saves
        guard let me = room.members.first(where: { $0.id == currentUid }), me.isCompleted else { return }

        didSaveLocalSession = true

        // Save a FocusSession with 1.5x bonus applied
        let session = FocusSession(durationMinutes: room.durationMinutes, emoji: room.focusEmoji, label: "Group Focus")
        session.isCompleted = true
        session.actualSeconds = room.durationMinutes * 60
        // Apply 1.5x bonus: multiply foreground seconds so challenge gets 50% more credit
        session.foregroundSeconds = Int(Double(room.durationMinutes * 60) * 1.5)
        session.endedAt = Date()
        session.startedAt = room.startedAt ?? Date()
        modelContext.insert(session)
        FocusSessionSyncService.shared.pushSession(session)

        HapticEngine.shared.success()
    }

    private func leaveIfNeeded() {
        guard let room = currentRoom, let uid = currentUid else { return }
        if room.isWaiting {
            if room.hostUid == uid {
                // Host leaves → delete entire room
                Task { await firestore.deleteGroupFocus(roomId: room.id) }
            } else {
                // Non-host leaves → remove self from members
                Task { await firestore.leaveGroupFocus(roomId: room.id, uid: uid) }
            }
        }
        listener?.remove()
        roomTimer?.invalidate()
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
