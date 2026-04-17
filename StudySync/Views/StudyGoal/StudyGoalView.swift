import SwiftUI
import SwiftData

struct StudyGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(filter: #Predicate<StudyGoal> { $0.isArchived == false },
           sort: \StudyGoal.createdAt, order: .reverse)
    private var activeGoals: [StudyGoal]

    @Query(filter: #Predicate<StudyGoal> { $0.isArchived == true },
           sort: \StudyGoal.createdAt, order: .reverse)
    private var archivedGoals: [StudyGoal]

    @Bindable var viewModel: StudyGoalViewModel
    @State private var hasAppeared = false
    @State private var showArchived = false

    var body: some View {
        NavigationStack {
            ZStack {
                SSColor.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if activeGoals.isEmpty && archivedGoals.isEmpty {
                            emptyState
                        } else {
                            // Active goals
                            if !activeGoals.isEmpty {
                                activeGoalsSection
                            }

                            // Add button — always shown; tapping when over
                            // the free limit routes to paywall.
                            addGoalButton

                            // Archived section
                            if !archivedGoals.isEmpty {
                                archivedSection
                            }
                        }
                    }
                    .padding(.horizontal, SSSpacing.xl)
                    .padding(.top, SSSpacing.md)
                    .padding(.bottom, SSSpacing.xxl)
                }
            }
            .navigationTitle(L10n.goalTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.tryAddGoal(activeCount: activeGoals.count)
                        HapticEngine.shared.lightImpact()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(SSColor.brand)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddGoal) {
                AddStudyGoalView()
            }
            .sheet(isPresented: $viewModel.showingPaywall) {
                PaywallView()
            }
            .onAppear {
                withAnimation(.spring(duration: 0.5)) {
                    hasAppeared = true
                }
            }
            .task {
                // Hydrate from Firestore on first appearance — restores
                // goals after a fresh install / reinstall.
                await StudyGoalSyncService.shared.pullAll(context: modelContext)
            }
        }
        .overlay {
            if viewModel.showingCelebration,
               let goal = viewModel.celebrationGoal,
               let milestone = viewModel.celebrationMilestone {
                MilestoneCelebrationView(
                    goalTitle: goal.title,
                    goalEmoji: goal.emoji,
                    milestone: milestone,
                    colorHex: goal.colorHex,
                    onDismiss: {
                        viewModel.showingCelebration = false
                    }
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showingCelebration)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)

            Image(systemName: "target")
                .font(.system(size: 56))
                .foregroundStyle(SSColor.brand.opacity(0.4))

            Text(L10n.goalEmptyTitle)
                .font(SSFont.heading3)
                .foregroundStyle(.primary)

            Text(L10n.goalEmptySubtitle)
                .font(SSFont.secondary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                viewModel.tryAddGoal(activeCount: activeGoals.count)
                HapticEngine.shared.lightImpact()
            } label: {
                Label(L10n.goalAddGoal, systemImage: "plus")
                    .font(SSFont.bodySemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(SSColor.brand.gradient)
                    )
            }
            .padding(.top, SSSpacing.md)
        }
    }

    // MARK: - Active Goals

    private var activeGoalsSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(activeGoals.enumerated()), id: \.element.id) { index, goal in
                NavigationLink {
                    StudyGoalDetailView(goal: goal, viewModel: viewModel)
                } label: {
                    GoalCardView(goal: goal, viewModel: viewModel)
                }
                .buttonStyle(.plain)
                // #10 Context menu for quick actions
                .contextMenu {
                    Button {
                        if goal.needsCheckIn {
                            viewModel.checkIn(goal: goal, context: modelContext)
                            HapticEngine.shared.lightImpact()
                        }
                    } label: {
                        Label(goal.needsCheckIn ? L10n.goalCheckIn : L10n.goalCheckedIn,
                              systemImage: goal.needsCheckIn ? "checkmark.circle" : "checkmark.circle.fill")
                    }
                    .disabled(!goal.needsCheckIn)

                    Divider()

                    Button {
                        viewModel.archiveGoal(goal)
                        HapticEngine.shared.selection()
                    } label: {
                        Label(L10n.goalArchiveGoal, systemImage: "archivebox")
                    }
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(
                    .spring(duration: 0.5).delay(Double(index) * 0.1),
                    value: hasAppeared
                )
            }
        }
    }

    // MARK: - Add Button

    private var addGoalButton: some View {
        Button {
            viewModel.showingAddGoal = true
            HapticEngine.shared.lightImpact()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                Text(L10n.goalAddGoal)
                    .font(SSFont.bodySmallMedium)
            }
            .foregroundStyle(SSColor.brand)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                    .strokeBorder(SSColor.brand.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
            )
        }
    }

    // MARK: - Archived Section

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showArchived.toggle()
                }
            } label: {
                HStack {
                    Text(L10n.goalArchived)
                        .font(SSFont.bodySemibold)
                        .foregroundStyle(.primary)
                    Text("\(archivedGoals.count)")
                        .font(SSFont.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(SSColor.fillTertiary))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showArchived ? 90 : 0))
                }
            }
            .padding(.top, SSSpacing.md)

            if showArchived {
                ForEach(archivedGoals) { goal in
                    ArchivedGoalRow(goal: goal, viewModel: viewModel, activeCount: activeGoals.count)
                }
            }
        }
    }
}

// MARK: - Goal Card View

struct GoalCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    let goal: StudyGoal
    let viewModel: StudyGoalViewModel

    private var color: Color { Color(hex: goal.colorHex) }

    var body: some View {
        VStack(spacing: 0) {
            // Top: Emoji + Title + Streak
            HStack(spacing: 12) {
                Text(goal.emoji)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(SSFont.heading3)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        // Frequency badge
                        Text(goal.frequency.displayName)
                            .font(SSFont.badge)
                            .foregroundStyle(color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.12).clipShape(Capsule()))

                        // Streak
                        if goal.currentStreak > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(SSFont.badge)
                                    .foregroundStyle(.orange)
                                Text(L10n.goalStreakCount(goal.currentStreak))
                                    .font(SSFont.badge)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                // Check-in button
                checkInButton
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.top, SSSpacing.xl)
            .padding(.bottom, 12)

            // Progress bar toward next milestone
            if let nextMilestone = goal.nextMilestone {
                VStack(spacing: 6) {
                    Divider().padding(.horizontal, SSSpacing.xl)

                    HStack {
                        Text(L10n.goalTotalCheckIns(goal.totalCheckIns))
                            .font(SSFont.footnote)
                            .foregroundStyle(.secondary)

                        Spacer()

                        let milestones = Milestone.milestones(for: goal.frequency)
                        if let ms = milestones.first(where: { $0.count == nextMilestone }) {
                            Text("\(ms.emoji) \(nextMilestone)")
                                .font(SSFont.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, SSSpacing.xl)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(SSColor.fillTertiary)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(color.gradient)
                                .frame(width: max(0, geo.size.width * goal.milestoneProgress))
                                .animation(.easeInOut(duration: 0.6), value: goal.milestoneProgress)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, SSSpacing.xl)
                }
                .padding(.bottom, 14)
            } else {
                // All milestones completed
                Divider()
                    .padding(.horizontal, SSSpacing.xl)
                    .padding(.bottom, 4)

                HStack {
                    Text("🏆 \(L10n.goalAllMilestones)")
                        .font(SSFont.footnote)
                        .foregroundStyle(color)
                    Spacer()
                    Text(L10n.goalTotalCheckIns(goal.totalCheckIns))
                        .font(SSFont.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.bottom, 14)
            }

            // Footer: chevron hint
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        .ssAdaptiveBorder(color: color, colorScheme: colorScheme)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(goal.title), \(goal.frequency.displayName), \(L10n.goalTotalCheckIns(goal.totalCheckIns))"))
    }

    @State private var checkInScale: CGFloat = 1.0

    private var checkInButton: some View {
        Button {
            if goal.needsCheckIn {
                // #7 Check-in success animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    checkInScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        checkInScale = 1.0
                    }
                }
                viewModel.checkIn(goal: goal, context: modelContext)
            }
        } label: {
            if goal.needsCheckIn {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(color)
                    Text(L10n.goalCheckIn)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(color)
                }
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                    Text(L10n.goalCheckedIn)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green)
                }
            }
        }
        .scaleEffect(checkInScale)
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3), value: goal.needsCheckIn)
        .accessibilityLabel(goal.needsCheckIn ? L10n.goalCheckIn : L10n.goalCheckedIn)
        .accessibilityHint(goal.needsCheckIn ? L10n.goalCheckInNow : "")
    }
}

// MARK: - Archived Goal Row

struct ArchivedGoalRow: View {
    @Environment(\.modelContext) private var modelContext
    let goal: StudyGoal
    let viewModel: StudyGoalViewModel
    let activeCount: Int

    @State private var showDeleteAlert = false

    var body: some View {
        HStack(spacing: 12) {
            Text(goal.emoji)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(SSFont.bodySmallMedium)
                    .foregroundStyle(.secondary)
                Text(L10n.goalTotalCheckIns(goal.totalCheckIns))
                    .font(SSFont.footnote)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Reactivate (always available; paywall gate handled inside VM)
            if viewModel.canAddGoal(activeCount: activeCount) {
                Button {
                    _ = viewModel.reactivateGoal(goal, activeCount: activeCount)
                    HapticEngine.shared.lightImpact()
                } label: {
                    Text(L10n.goalReactivate)
                        .font(SSFont.footnote)
                        .foregroundStyle(SSColor.brand)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(SSColor.brand.opacity(0.1))
                        )
                }
            }

            // Delete — with confirmation (#2)
            Button {
                showDeleteAlert = true
                HapticEngine.shared.warning()
            } label: {
                Image(systemName: "trash")
                    .font(SSFont.secondary)
                    .foregroundStyle(.red.opacity(0.6))
            }
        }
        .padding(.horizontal, SSSpacing.xl)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        .alert(L10n.confirmDeleteArchivedGoal, isPresented: $showDeleteAlert) {
            Button(L10n.delete, role: .destructive) {
                viewModel.deleteGoal(goal, context: modelContext)
                HapticEngine.shared.success()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deleteArchivedGoalWarning)
        }
    }
}

#Preview {
    StudyGoalView(viewModel: StudyGoalViewModel())
        .modelContainer(for: [StudyGoal.self, CheckInRecord.self], inMemory: true)
}
