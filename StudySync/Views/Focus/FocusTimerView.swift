import SwiftUI
import SwiftData
import FirebaseAuth

nonisolated enum FocusTimerState: Equatable {
    case idle, running, paused, breakTime, breakPaused
}

struct FocusTimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var hSizeClass

    /// Outer glow ring size — base 280pt on iPhone, scaled up on iPad so the
    /// timer doesn't look like a small token in the middle of the canvas.
    private var ringOuterSize: CGFloat {
        ipScaled(280, scale: 1.5, sizeClass: hSizeClass)
    }
    /// Inner track + progress ring size (must stay proportional to outer).
    private var ringInnerSize: CGFloat {
        ipScaled(230, scale: 1.5, sizeClass: hSizeClass)
    }
    /// Tip-dot rotation radius — exactly half of the inner ring diameter so
    /// the dot orbits along the stroke center line.
    private var ringTipOffset: CGFloat {
        -ringInnerSize / 2
    }

    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var allSessions: [FocusSession]

    // Timer state
    @State private var timerState: FocusTimerState = .idle
    @State private var selectedMinutes: Int = 25
    @State private var remainingSeconds: Int = 25 * 60
    @State private var elapsedSeconds: Int = 0
    @State private var foregroundElapsedSeconds: Int = 0
    @State private var timer: Timer?
    @State private var currentSession: FocusSession?

    // UI
    @State private var selectedEmoji = "📚"
    @State private var showHistory = false
    @State private var showAnalytics = false
    @State private var joinStudyRoom = false
    @State private var showStudyRoom = false
    @State private var pulseRing = false
    @State private var breathe = false
    @State private var hasAppeared = false
    @State private var showComplete = false
    @State private var backgroundedAt: Date?
    @State private var showChallengeUnlocked = false
    @State private var showGiveUpAlert = false
    @State private var showGroupFocus = false
    @State private var showStudySpace = false

    @Query private var unlockedSpaceItems: [StudySpaceItem]

    private var unlockedCount: Int { unlockedSpaceItems.count }

    // Pomodoro / break state
    @State private var pomodoroCount: Int = 0
    @State private var isLongBreak: Bool = false
    @State private var shortBreakMinutes: Int = 5
    @State private var longBreakMinutes: Int = 15
    @State private var pomodorosForLongBreak: Int = 4

    private let presetMinutes = [15, 25, 30, 45, 60, 90]
    private let emojis = ["📚", "💻", "✍️", "🎯", "🧪", "📐", "🎨", "🔬"]

    // MARK: - Computed

    private var progress: Double {
        let total = Double(selectedMinutes * 60)
        guard total > 0 else { return 0 }
        return Double(elapsedSeconds) / total
    }

    private var todayMinutes: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allSessions
            .filter { $0.isCompleted && $0.startedAt >= startOfDay }
            .reduce(0) { $0 + $1.actualMinutes }
    }

    private var totalMinutes: Int {
        allSessions.filter(\.isCompleted).reduce(0) { $0 + $1.actualMinutes }
    }

    private var totalSessions: Int {
        allSessions.filter(\.isCompleted).count
    }

    // Focus challenge: 30 h in a calendar month → 3 months Pro (ends June 30 2026)
    private let challengeGoalMinutes = 1800 // 30 hours

    private static let challengeDeadline: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 30
        c.hour = 23; c.minute = 59; c.second = 59
        return Calendar.current.date(from: c) ?? Date()
    }()

    private var isChallengeActive: Bool {
        Date() <= Self.challengeDeadline
    }

    /// All focus minutes this month (foreground + background) — for display stats
    private var monthlyFocusMinutes: Int {
        let cal = Calendar.current
        guard let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) else { return 0 }
        return allSessions
            .filter { $0.isCompleted && $0.startedAt >= startOfMonth }
            .reduce(0) { $0 + $1.actualMinutes }
    }

    /// Only foreground focus minutes this month — counts toward the 100 h challenge
    private var monthlyChallengeMinutes: Int {
        let cal = Calendar.current
        guard let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) else { return 0 }
        return allSessions
            .filter { $0.isCompleted && $0.startedAt >= startOfMonth }
            .reduce(0) { $0 + $1.foregroundMinutes }
    }

    private var challengeProgress: Double {
        min(Double(monthlyChallengeMinutes) / Double(challengeGoalMinutes), 1.0)
    }

    private var ringColor1: Color { SSColor.brand }
    private var ringColor2: Color { SSColor.brandPurple }

    private var currentRingColor1: Color {
        timerState == .breakTime || timerState == .breakPaused ? Color(hex: "#10B981") : ringColor1
    }
    private var currentRingColor2: Color {
        timerState == .breakTime || timerState == .breakPaused ? Color(hex: "#06B6D4") : ringColor2
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Timer area
                        timerSection
                            .padding(.top, SSSpacing.md)

                        // Bottom card
                        bottomCard
                            .padding(.top, SSSpacing.xxxl)
                    }
                    .padding(.horizontal, SSSpacing.xl)
                    .padding(.bottom, SSSpacing.xxl)
                }

                // Completion overlay
                if showComplete {
                    completionOverlay
                }
            }
            .navigationTitle(L10n.focusTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAnalytics = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(SSColor.brand)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showStudyRoom = true
                    } label: {
                        Image(systemName: "person.2.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(joinStudyRoom ? SSColor.brand : .secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "list.bullet.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(SSColor.brand)
                    }
                }
            }
            .sheet(isPresented: $showAnalytics) {
                StudyAnalyticsView()
            }
            .sheet(isPresented: $showHistory) {
                FocusHistoryView()
            }
            .sheet(isPresented: $showStudyRoom) {
                StudyRoomView()
            }
            .sheet(isPresented: $showGroupFocus) {
                GroupFocusView()
            }
            .sheet(isPresented: $showStudySpace) {
                StudySpaceView()
            }
            .alert(L10n.focusGiveUpTitle, isPresented: $showGiveUpAlert) {
                Button(L10n.focusGiveUpConfirm, role: .destructive) { giveUp() }
                Button(L10n.cancel, role: .cancel) { }
            } message: {
                Text(L10n.focusGiveUpMessage)
            }
            .onAppear {
                withAnimation(.spring(duration: 0.6)) { hasAppeared = true }
            }
            .task {
                // Pull focus history from Firestore on tab appearance.
                // Restores analytics + study space unlocks after reinstall
                // / new device login.
                await FocusSessionSyncService.shared.pullAll(context: modelContext)
            }
            .onDisappear {
                // DO NOT invalidate the timer here. This view sits inside
                // a TabView and `.onDisappear` fires on every tab switch —
                // killing the timer made the running focus session freeze
                // (timerState stayed `.running` but ticks stopped, so the
                // user perceived "auto-paused" and had to tap Pause →
                // Resume to recover).
                //
                // Legitimate cleanup happens in:
                //   • pauseTimer()      — explicit pause button
                //   • completeSession() — timer hit zero
                //   • giveUp()          — user abandoned
                //   • scenePhase → .background — full app backgrounded
                //     (with proper "elapsed catch-up" on return)
                //
                // For genuinely terminal dismissal (rare — TabView caches
                // this view across tab switches) the timer is reclaimed
                // when the @State storage is finally torn down. A leaked
                // timer cost is negligible and far better than freezing
                // an active focus session.
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard timerState == .running || timerState == .breakTime else { return }
                if newPhase == .background {
                    backgroundedAt = Date()
                    timer?.invalidate()
                    timer = nil
                } else if newPhase == .active, let bg = backgroundedAt {
                    let elapsed = Int(Date().timeIntervalSince(bg))
                    backgroundedAt = nil
                    remainingSeconds = max(0, remainingSeconds - elapsed)
                    elapsedSeconds += elapsed
                    if remainingSeconds <= 0 {
                        if timerState == .running {
                            completeSession()
                        } else {
                            completeBreak()
                        }
                    } else {
                        scheduleTimer()
                    }
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        Group {
            if timerState == .running || timerState == .breakTime {
                LinearGradient(
                    colors: [
                        currentRingColor2.opacity(colorScheme == .dark ? 0.08 : 0.04),
                        SSColor.backgroundPrimary
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            } else {
                SSColor.backgroundPrimary
            }
        }
        .animation(.easeInOut(duration: 0.8), value: timerState)
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: 0) {
            // Ring
            ZStack {
                // Outer glow when running or on break
                if timerState == .running || timerState == .breakTime {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [currentRingColor2.opacity(SSOpacity.tagBackground), .clear],
                                center: .center,
                                startRadius: 100,
                                endRadius: 160
                            )
                        )
                        .frame(width: ringOuterSize, height: ringOuterSize)
                        .scaleEffect(breathe ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: breathe)
                        .onAppear { breathe = true }
                        .onDisappear { breathe = false }
                }

                // Track
                Circle()
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.06)
                            : Color.black.opacity(0.04),
                        lineWidth: 12
                    )
                    .frame(width: ringInnerSize, height: ringInnerSize)

                // Progress arc
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(
                        AngularGradient(
                            colors: [currentRingColor1, currentRingColor2, currentRingColor1],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: ringInnerSize, height: ringInnerSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: progress)
                    .shadow(color: currentRingColor2.opacity(timerState == .running || timerState == .breakTime ? SSOpacity.disabled : 0), radius: 8)

                // Dot at tip
                if progress > 0.01 {
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                        .shadow(color: currentRingColor2.opacity(SSOpacity.muted), radius: 4)
                        .offset(y: ringTipOffset)
                        .rotationEffect(.degrees(360 * progress))
                }

                // Center content
                VStack(spacing: SSSpacing.sm) {
                    Text(selectedEmoji)
                        .font(.system(size: 40))

                    Text(formatTime(remainingSeconds))
                        .font(.system(size: 48, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(timerState == .running ? .primary : .secondary)

                    if timerState == .running {
                        Text(L10n.focusInProgress)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ringColor2)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    } else if timerState == .idle {
                        Text(L10n.focusMinutes(selectedMinutes))
                            .font(SSFont.caption)
                            .foregroundStyle(.tertiary)
                    } else if timerState == .breakTime {
                        Text(isLongBreak ? L10n.focusLongBreak : L10n.focusShortBreak)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "#10B981"))
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    } else if timerState == .breakPaused {
                        Text(L10n.focusPause)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                    } else {
                        Text(L10n.focusPause)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                }
                .animation(.spring(duration: 0.3), value: timerState)
            }
            .frame(height: 280)

            // Controls
            controlButtons
                .padding(.top, SSSpacing.xxl)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 30)
    }

    // MARK: - Bottom Card

    private var bottomCard: some View {
        VStack(spacing: SSSpacing.xl) {
            // Stats
            statsBar

            // Pomodoro streak indicator
            if pomodoroCount > 0 {
                HStack(spacing: SSSpacing.sm) {
                    ForEach(0..<pomodorosForLongBreak, id: \.self) { i in
                        let filledCount = pomodoroCount % pomodorosForLongBreak == 0 && pomodoroCount > 0
                            ? pomodorosForLongBreak
                            : pomodoroCount % pomodorosForLongBreak
                        Circle()
                            .fill(i < filledCount ? currentRingColor2 : Color(.tertiarySystemFill))
                            .frame(width: 8, height: 8)
                    }
                    Text("\(pomodoroCount)")
                        .font(SSFont.badge)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, SSSpacing.mdLg)
                .padding(.horizontal, SSSpacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                        .fill(SSColor.backgroundCard)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            // Focus challenge
            challengeCard

            // Presets + emoji (only when idle)
            if timerState == .idle {
                presetPicker
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                emojiPicker
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                studyRoomToggle
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                // Group focus button
                Button { showGroupFocus = true } label: {
                    HStack(spacing: SSSpacing.md) {
                        Image(systemName: "person.3.fill")
                            .font(.title3)
                            .foregroundStyle(Color(hex: "#F59E0B"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.groupFocusTitle)
                                .font(SSFont.bodyMedium)
                                .foregroundStyle(.primary)
                            Text(L10n.groupFocusBonusShort)
                                .font(SSFont.caption)
                                .foregroundStyle(Color(hex: "#F59E0B"))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(SSFont.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(SSSpacing.xl)
                    .background(RoundedRectangle(cornerRadius: SSRadius.card).fill(SSColor.backgroundCard))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                // My Study Space
                Button { showStudySpace = true } label: {
                    HStack(spacing: SSSpacing.md) {
                        Image(systemName: "desktopcomputer")
                            .font(.title3)
                            .foregroundStyle(Color(hex: "#F59E0B"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.studySpaceTitle)
                                .font(SSFont.bodyMedium)
                                .foregroundStyle(.primary)
                            Text(L10n.studySpaceSubtitle)
                                .font(SSFont.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        // Show unlocked count
                        Text("\(unlockedCount)/\(StudySpaceItem.catalog.count)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(SSFont.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(SSSpacing.xl)
                    .background(RoundedRectangle(cornerRadius: SSRadius.card).fill(SSColor.backgroundCard))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(duration: 0.4), value: timerState)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            miniStat(
                value: "\(todayMinutes)",
                unit: "min",
                label: L10n.focusToday,
                icon: "sun.max.fill",
                color: .orange
            )
            miniDivider
            miniStat(
                value: formatTotalTime(totalMinutes),
                unit: nil,
                label: L10n.focusTotal,
                icon: "clock.fill",
                color: ringColor2
            )
            miniDivider
            miniStat(
                value: "\(totalSessions)",
                unit: nil,
                label: L10n.focusSessions,
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
        .padding(.vertical, SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    private var miniDivider: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color(.separator).opacity(0.3))
            .frame(width: 1, height: 32)
    }

    private func miniStat(value: String, unit: String?, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(SSFont.secondary)
                .foregroundStyle(color)

            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                if let unit {
                    Text(unit)
                        .font(SSFont.badge)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentTransition(.numericText())

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Preset Picker

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: SSSpacing.mdLg) {
            Text(L10n.focusDuration)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: SSSpacing.md) {
                ForEach(presetMinutes, id: \.self) { mins in
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            selectedMinutes = mins
                            remainingSeconds = mins * 60
                        }
                        HapticEngine.shared.selection()
                    } label: {
                        Text("\(mins)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(selectedMinutes == mins ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                                    .fill(selectedMinutes == mins
                                          ? LinearGradient(colors: [ringColor1, ringColor2], startPoint: .topLeading, endPoint: .bottomTrailing)
                                          : LinearGradient(colors: [Color(.tertiarySystemFill)], startPoint: .top, endPoint: .bottom))
                            )
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

    // MARK: - Emoji Picker

    private var emojiPicker: some View {
        HStack(spacing: 0) {
            ForEach(emojis, id: \.self) { e in
                Button {
                    withAnimation(.spring(duration: 0.2)) { selectedEmoji = e }
                    HapticEngine.shared.selection()
                } label: {
                    Text(e)
                        .font(.system(size: 26))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            Circle()
                                .fill(selectedEmoji == e ? ringColor2.opacity(SSOpacity.lightTint) : Color.clear)
                                .frame(width: 42, height: 42)
                        )
                        .scaleEffect(selectedEmoji == e ? 1.15 : 1.0)
                }
            }
        }
        .padding(.vertical, SSSpacing.md)
        .padding(.horizontal, SSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    // MARK: - Study Room Toggle

    private var studyRoomToggle: some View {
        HStack(spacing: SSSpacing.md) {
            Image(systemName: "person.2.fill")
                .font(.title3)
                .foregroundStyle(SSColor.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.studyRoomJoin)
                    .font(SSFont.bodyMedium)
                Text(L10n.studyRoomJoinDesc)
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $joinStudyRoom)
                .labelsHidden()
        }
        .padding(SSSpacing.xl)
        .background(RoundedRectangle(cornerRadius: SSRadius.card).fill(SSColor.backgroundCard))
    }

    // MARK: - Challenge Card

    @ViewBuilder
    private var challengeCard: some View {
        let store = StoreManager.shared
        let hasReward = store.hasActiveProReward

        if !isChallengeActive {
            // Activity ended — show minimal card only if reward is still active
            if hasReward, let expiry = store.proRewardExpiresAt {
                challengeEndedCard(expiry: expiry)
            }
        } else {
            activeChallengeCard(store: store)
        }
    }

    // Active challenge (before June 30)
    private func activeChallengeCard(store: StoreManager) -> some View {
        let challengeHours = Double(monthlyChallengeMinutes) / 60.0
        let goalHours = Double(challengeGoalMinutes) / 60.0
        let claimed = store.focusChallengeClaimedThisMonth

        return VStack(alignment: .leading, spacing: SSSpacing.lg) {
            // Header row
            HStack(spacing: SSSpacing.md) {
                Text(claimed ? "✅" : "🔥")
                    .font(.system(size: 20))
                Text(L10n.focusChallenge)
                    .font(SSFont.bodySmallSemibold)
                Spacer()
                Text(L10n.focusChallengeDeadline)
                    .font(SSFont.badge)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, SSSpacing.md)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1), in: Capsule())
            }

            if !claimed {
                Text(L10n.focusChallengeDesc)
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Progress bar
            VStack(spacing: SSSpacing.sm) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                claimed
                                    ? LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [ringColor1, ringColor2], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: proxy.size.width * challengeProgress)
                            .animation(.spring(duration: 0.4), value: challengeProgress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(String(format: "%.1fh / %.0fh", challengeHours, goalHours))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if claimed {
                        if let expiry = store.proRewardExpiresAt {
                            Text(L10n.focusChallengeRewardExpiry(formatExpiry(expiry)))
                                .font(SSFont.badge)
                                .foregroundStyle(.green)
                        }
                    } else {
                        let remaining = goalHours - challengeHours
                        if remaining > 0 {
                            Text(L10n.focusChallengeRemaining(String(format: "%.1f", remaining)))
                                .font(SSFont.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            // Foreground-only note
            if !claimed {
                HStack(spacing: SSSpacing.xs) {
                    Image(systemName: "iphone")
                        .font(SSFont.micro)
                    Text(L10n.focusChallengeForegroundNote)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.quaternary)
            }

            // Show active reward even when not yet claimed this month
            if !claimed, let expiry = store.proRewardExpiresAt, store.hasActiveProReward {
                HStack(spacing: SSSpacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                    Text(L10n.focusChallengeRewardExpiry(formatExpiry(expiry)))
                        .font(SSFont.footnote)
                }
                .foregroundStyle(ringColor2)
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .strokeBorder(
                    claimed
                        ? Color.green.opacity(SSOpacity.elevatedShadow)
                        : challengeProgress > 0.7 ? ringColor2.opacity(0.2) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // Ended challenge — only shows if the user still has an active reward
    private func challengeEndedCard(expiry: Date) -> some View {
        HStack(spacing: SSSpacing.mdLg) {
            Text("⏰")
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.focusChallenge)
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: SSSpacing.xs) {
                    Image(systemName: "sparkles")
                        .font(SSFont.micro)
                    Text(L10n.focusChallengeRewardExpiry(formatExpiry(expiry)))
                        .font(SSFont.footnote)
                }
                .foregroundStyle(ringColor2)
            }
            Spacer()
            Text(L10n.focusChallengeEnded)
                .font(SSFont.badge)
                .foregroundStyle(.secondary)
                .padding(.horizontal, SSSpacing.md)
                .padding(.vertical, 3)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: SSSpacing.lgXl) {
            switch timerState {
            case .idle:
                Button { startTimer() } label: {
                    HStack(spacing: SSSpacing.mdLg) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18))
                        Text(L10n.focusStart)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                            .fill(
                                LinearGradient(colors: [ringColor1, ringColor2],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                    )
                    .shadow(color: ringColor2.opacity(SSOpacity.elevatedShadow), radius: 12, y: 6)
                }

            case .running:
                Button { pauseTimer() } label: {
                    HStack(spacing: SSSpacing.mdLg) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 18))
                        Text(L10n.focusPause)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                            .fill(Color.orange.gradient)
                    )
                }

                giveUpButton

            case .paused:
                Button { resumeTimer() } label: {
                    HStack(spacing: SSSpacing.mdLg) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18))
                        Text(L10n.focusResume)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                            .fill(Color.green.gradient)
                    )
                }

                giveUpButton

            case .breakTime:
                Button { pauseBreak() } label: {
                    HStack(spacing: SSSpacing.mdLg) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 18))
                        Text(L10n.focusPause)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#10B981"), Color(hex: "#06B6D4")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                    )
                }

                Button { skipBreak() } label: {
                    Text(L10n.focusSkipBreak)
                        .font(SSFont.bodySmallMedium)
                        .foregroundStyle(.secondary)
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                        )
                }

            case .breakPaused:
                Button { resumeBreak() } label: {
                    HStack(spacing: SSSpacing.mdLg) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18))
                        Text(L10n.focusResume)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#10B981"), Color(hex: "#06B6D4")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                    )
                }

                Button { skipBreak() } label: {
                    Text(L10n.focusSkipBreak)
                        .font(SSFont.bodySmallMedium)
                        .foregroundStyle(.secondary)
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                        )
                }
            }
        }
        .animation(.spring(duration: 0.3), value: timerState)
    }

    private var giveUpButton: some View {
        Button { showGiveUpAlert = true } label: {
            Image(systemName: "xmark")
                .font(SSFont.heading3)
                .foregroundStyle(.red)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                        .fill(.red.opacity(colorScheme == .dark ? SSOpacity.lightTint : SSOpacity.shadow))
                )
        }
    }

    // MARK: - Completion Overlay

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(SSOpacity.elevatedShadow)
                .ignoresSafeArea()
                .onTapGesture { withAnimation {
                    showComplete = false
                    showChallengeUnlocked = false
                } }

            VStack(spacing: SSSpacing.xxl) {
                Text(showChallengeUnlocked ? "🏆" : "🎉")
                    .font(.system(size: 56))

                Text(showChallengeUnlocked ? L10n.focusChallengeUnlocked : L10n.focusComplete)
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(L10n.focusCompleteDesc(selectedMinutes))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Challenge reward banner
                if showChallengeUnlocked, let expiry = StoreManager.shared.proRewardExpiresAt {
                    HStack(spacing: SSSpacing.sm) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.orange)
                        Text(L10n.focusChallengeRewardExpiry(formatExpiry(expiry)))
                            .font(SSFont.chipLabel)
                    }
                    .padding(.horizontal, SSSpacing.xl)
                    .padding(.vertical, SSSpacing.mdLg)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                            .fill(Color.orange.opacity(0.1))
                    )
                }

                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showComplete = false
                        showChallengeUnlocked = false
                    }
                } label: {
                    Text(L10n.done)
                        .font(SSFont.bodySemibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SSSpacing.lgXl)
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                .fill(
                                    showChallengeUnlocked
                                        ? LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [ringColor1, ringColor2], startPoint: .leading, endPoint: .trailing)
                                )
                        )
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(SSColor.backgroundCard)
            )
            .padding(.horizontal, 40)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    // MARK: - Timer Logic

    private func startTimer() {
        remainingSeconds = selectedMinutes * 60
        elapsedSeconds = 0
        foregroundElapsedSeconds = 0

        let session = FocusSession(durationMinutes: selectedMinutes, emoji: selectedEmoji)
        modelContext.insert(session)
        FocusSessionSyncService.shared.pushSession(session)
        currentSession = session

        withAnimation(.spring(duration: 0.4)) { timerState = .running }
        scheduleTimer()
        HapticEngine.shared.success()

        if joinStudyRoom,
           let uid = AuthService.shared.currentUser?.uid,
           let profile = AuthService.shared.userProfile {
            let member = StudyRoomMember(
                id: uid,
                displayName: profile.displayName,
                avatarEmoji: profile.avatarEmoji,
                focusEmoji: selectedEmoji,
                focusDurationMinutes: selectedMinutes,
                startedAt: Date(),
                updatedAt: Date()
            )
            Task { await FirestoreService.shared.joinStudyRoom(member: member) }
        }
    }

    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        withAnimation(.spring(duration: 0.3)) { timerState = .paused }
        HapticEngine.shared.lightImpact()
    }

    private func resumeTimer() {
        withAnimation(.spring(duration: 0.3)) { timerState = .running }
        scheduleTimer()
        HapticEngine.shared.lightImpact()
    }

    private func giveUp() {
        timer?.invalidate()
        timer = nil
        if let session = currentSession {
            let sessionId = session.id
            modelContext.delete(session)
            FocusSessionSyncService.shared.deleteSession(id: sessionId)
        }
        currentSession = nil
        pomodoroCount = 0
        withAnimation(.spring(duration: 0.4)) {
            timerState = .idle
            remainingSeconds = selectedMinutes * 60
            elapsedSeconds = 0
            foregroundElapsedSeconds = 0
        }
        HapticEngine.shared.warning()

        if joinStudyRoom, let uid = AuthService.shared.currentUser?.uid {
            Task { await FirestoreService.shared.leaveStudyRoom(uid: uid) }
        }
    }

    private func completeSession() {
        timer?.invalidate()
        timer = nil

        if let session = currentSession {
            session.isCompleted = true
            session.actualSeconds = elapsedSeconds
            session.foregroundSeconds = foregroundElapsedSeconds
            session.endedAt = Date()
            FocusSessionSyncService.shared.pushSession(session)
        }

        syncFocusStats()
        checkFocusChallenge()
        currentSession = nil

        withAnimation(.spring(duration: 0.5)) {
            showComplete = true
        }

        if joinStudyRoom, let uid = AuthService.shared.currentUser?.uid {
            Task { await FirestoreService.shared.leaveStudyRoom(uid: uid) }
        }

        pomodoroCount += 1
        isLongBreak = pomodoroCount % pomodorosForLongBreak == 0
        startBreak()
    }

    private func startBreak() {
        let breakMins = isLongBreak ? longBreakMinutes : shortBreakMinutes
        remainingSeconds = breakMins * 60
        elapsedSeconds = 0
        withAnimation(.spring(duration: 0.4)) { timerState = .breakTime }
        scheduleTimer()
        HapticEngine.shared.lightImpact()
    }

    private func completeBreak() {
        timer?.invalidate()
        timer = nil
        withAnimation(.spring(duration: 0.4)) {
            timerState = .idle
            remainingSeconds = selectedMinutes * 60
            elapsedSeconds = 0
        }
        HapticEngine.shared.success()
    }

    private func skipBreak() {
        completeBreak()
    }

    private func pauseBreak() {
        timer?.invalidate()
        timer = nil
        withAnimation(.spring(duration: 0.3)) { timerState = .breakPaused }
    }

    private func resumeBreak() {
        withAnimation(.spring(duration: 0.3)) { timerState = .breakTime }
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
                elapsedSeconds += 1
                if timerState == .running {
                    foregroundElapsedSeconds += 1 // only foreground focus ticks count for challenge
                }
            } else {
                if timerState == .running {
                    completeSession()
                } else if timerState == .breakTime {
                    completeBreak()
                }
            }
        }
        // .common mode keeps the timer firing while the user scrolls
        if let timer { RunLoop.current.add(timer, forMode: .common) }
    }

    private func syncFocusStats() {
        let completedSessions = allSessions.filter(\.isCompleted)
        let totalMins = completedSessions.reduce(0) { $0 + $1.actualMinutes }
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        Task {
            await FirestoreService.shared.updateProfile(uid: uid, fields: [
                "totalFocusMinutes": totalMins
            ])
        }
    }

    private func checkFocusChallenge() {
        guard isChallengeActive else { return }
        let store = StoreManager.shared
        guard !store.focusChallengeClaimedThisMonth else { return }
        // The just-completed session was inserted at startTimer() and had its
        // foregroundSeconds mutated in-place before this call, so it's already
        // summed into monthlyChallengeMinutes. Adding it again double-counted
        // it and could trip the reward early.
        let effectiveMonthly = monthlyChallengeMinutes
        guard effectiveMonthly >= challengeGoalMinutes else { return }
        store.grantFocusChallengeReward()
        showChallengeUnlocked = true
    }

    // MARK: - Helpers

    private func formatExpiry(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func formatTotalTime(_ minutes: Int) -> String {
        let hrs = minutes / 60
        if hrs > 0 { return "\(hrs)h\(minutes % 60)m" }
        return "\(minutes)m"
    }
}

#Preview {
    FocusTimerView()
        .modelContainer(for: FocusSession.self, inMemory: true)
}
