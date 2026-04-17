import SwiftUI
import SwiftData
import FirebaseAuth

struct FocusTimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var allSessions: [FocusSession]

    // Timer state
    @State private var timerState: TimerState = .idle
    @State private var selectedMinutes: Int = 25
    @State private var remainingSeconds: Int = 25 * 60
    @State private var elapsedSeconds: Int = 0
    @State private var foregroundElapsedSeconds: Int = 0
    @State private var timer: Timer?
    @State private var currentSession: FocusSession?

    // UI
    @State private var selectedEmoji = "📚"
    @State private var showHistory = false
    @State private var pulseRing = false
    @State private var breathe = false
    @State private var hasAppeared = false
    @State private var showComplete = false
    @State private var backgroundedAt: Date?
    @State private var showChallengeUnlocked = false
    @State private var showGiveUpAlert = false

    private let presetMinutes = [15, 25, 30, 45, 60, 90]
    private let emojis = ["📚", "💻", "✍️", "🎯", "🧪", "📐", "🎨", "🔬"]

    enum TimerState {
        case idle, running, paused
    }

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

    private var ringColor1: Color { Color(hex: "#5B7FFF") }
    private var ringColor2: Color { Color(hex: "#7C3AED") }

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
                            .padding(.top, 8)

                        // Bottom card
                        bottomCard
                            .padding(.top, 24)
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
            .sheet(isPresented: $showHistory) {
                FocusHistoryView()
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
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard timerState == .running else { return }
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
                        completeSession()
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
            if timerState == .running {
                LinearGradient(
                    colors: [
                        ringColor2.opacity(colorScheme == .dark ? 0.08 : 0.04),
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
                // Outer glow when running
                if timerState == .running {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [ringColor2.opacity(0.12), .clear],
                                center: .center,
                                startRadius: 100,
                                endRadius: 160
                            )
                        )
                        .frame(width: 280, height: 280)
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
                    .frame(width: 230, height: 230)

                // Progress arc
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(
                        AngularGradient(
                            colors: [ringColor1, ringColor2, ringColor1],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 230, height: 230)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: progress)
                    .shadow(color: ringColor2.opacity(timerState == .running ? 0.4 : 0), radius: 8)

                // Dot at tip
                if progress > 0.01 {
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                        .shadow(color: ringColor2.opacity(0.6), radius: 4)
                        .offset(y: -115)
                        .rotationEffect(.degrees(360 * progress))
                }

                // Center content
                VStack(spacing: 6) {
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
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
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
                .padding(.top, 20)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 30)
    }

    // MARK: - Bottom Card

    private var bottomCard: some View {
        VStack(spacing: 16) {
            // Stats
            statsBar

            // Focus challenge
            challengeCard

            // Presets + emoji (only when idle)
            if timerState == .idle {
                presetPicker
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                emojiPicker
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
        .padding(.vertical, 16)
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
                .font(.system(size: 14))
                .foregroundStyle(color)

            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
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
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.focusDuration)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
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
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedMinutes == mins
                                          ? LinearGradient(colors: [ringColor1, ringColor2], startPoint: .topLeading, endPoint: .bottomTrailing)
                                          : LinearGradient(colors: [Color(.tertiarySystemFill)], startPoint: .top, endPoint: .bottom))
                            )
                    }
                }
            }
        }
        .padding(16)
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
                                .fill(selectedEmoji == e ? ringColor2.opacity(0.15) : Color.clear)
                                .frame(width: 42, height: 42)
                        )
                        .scaleEffect(selectedEmoji == e ? 1.15 : 1.0)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
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

        return VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 8) {
                Text(claimed ? "✅" : "🔥")
                    .font(.system(size: 20))
                Text(L10n.focusChallenge)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(L10n.focusChallengeDeadline)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1), in: Capsule())
            }

            if !claimed {
                Text(L10n.focusChallengeDesc)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Progress bar
            VStack(spacing: 6) {
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
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.green)
                        }
                    } else {
                        let remaining = goalHours - challengeHours
                        if remaining > 0 {
                            Text(L10n.focusChallengeRemaining(String(format: "%.1f", remaining)))
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            // Foreground-only note
            if !claimed {
                HStack(spacing: 4) {
                    Image(systemName: "iphone")
                        .font(.system(size: 10))
                    Text(L10n.focusChallengeForegroundNote)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.quaternary)
            }

            // Show active reward even when not yet claimed this month
            if !claimed, let expiry = store.proRewardExpiresAt, store.hasActiveProReward {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                    Text(L10n.focusChallengeRewardExpiry(formatExpiry(expiry)))
                        .font(.system(size: 12))
                }
                .foregroundStyle(ringColor2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .strokeBorder(
                    claimed
                        ? Color.green.opacity(0.3)
                        : challengeProgress > 0.7 ? ringColor2.opacity(0.2) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // Ended challenge — only shows if the user still has an active reward
    private func challengeEndedCard(expiry: Date) -> some View {
        HStack(spacing: 10) {
            Text("⏰")
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.focusChallenge)
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text(L10n.focusChallengeRewardExpiry(formatExpiry(expiry)))
                        .font(.system(size: 12))
                }
                .foregroundStyle(ringColor2)
            }
            Spacer()
            Text(L10n.focusChallengeEnded)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 14) {
            switch timerState {
            case .idle:
                Button { startTimer() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18))
                        Text(L10n.focusStart)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(colors: [ringColor1, ringColor2],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                    )
                    .shadow(color: ringColor2.opacity(0.3), radius: 12, y: 6)
                }

            case .running:
                Button { pauseTimer() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 18))
                        Text(L10n.focusPause)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.orange.gradient)
                    )
                }

                giveUpButton

            case .paused:
                Button { resumeTimer() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18))
                        Text(L10n.focusResume)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.green.gradient)
                    )
                }

                giveUpButton
            }
        }
        .animation(.spring(duration: 0.3), value: timerState)
    }

    private var giveUpButton: some View {
        Button { showGiveUpAlert = true } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.red.opacity(colorScheme == .dark ? 0.15 : 0.08))
                )
        }
    }

    // MARK: - Completion Overlay

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { withAnimation {
                    showComplete = false
                    showChallengeUnlocked = false
                } }

            VStack(spacing: 20) {
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
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.orange)
                        Text(L10n.focusChallengeRewardExpiry(formatExpiry(expiry)))
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
        currentSession = session

        withAnimation(.spring(duration: 0.4)) { timerState = .running }
        scheduleTimer()
        HapticEngine.shared.success()
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
            modelContext.delete(session)
        }
        currentSession = nil
        withAnimation(.spring(duration: 0.4)) {
            timerState = .idle
            remainingSeconds = selectedMinutes * 60
            elapsedSeconds = 0
            foregroundElapsedSeconds = 0
        }
        HapticEngine.shared.warning()
    }

    private func completeSession() {
        timer?.invalidate()
        timer = nil

        if let session = currentSession {
            session.isCompleted = true
            session.actualSeconds = elapsedSeconds
            session.foregroundSeconds = foregroundElapsedSeconds
            session.endedAt = Date()
        }

        syncFocusStats()
        checkFocusChallenge()
        currentSession = nil

        withAnimation(.spring(duration: 0.5)) {
            timerState = .idle
            remainingSeconds = selectedMinutes * 60
            elapsedSeconds = 0
            showComplete = true
        }
        HapticEngine.shared.success()
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
                elapsedSeconds += 1
                foregroundElapsedSeconds += 1 // only foreground ticks count for challenge
            } else {
                completeSession()
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
        // Use foreground-only minutes; include just-completed session (query may lag)
        let sessionFgMins = foregroundElapsedSeconds / 60
        let effectiveMonthly = monthlyChallengeMinutes + sessionFgMins
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
