import SwiftUI
import SwiftData

struct StudyGoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // C3 fix: Query active goals count for undo reactivation check
    @Query(filter: #Predicate<StudyGoal> { $0.isArchived == false })
    private var activeGoals: [StudyGoal]

    let goal: StudyGoal
    let viewModel: StudyGoalViewModel

    @State private var showDeleteAlert = false
    @State private var checkInScale: CGFloat = 1.0
    @State private var hasAppeared = false
    // #9 Archive undo toast
    @State private var showArchiveToast = false
    @State private var archiveDismissWorkItem: DispatchWorkItem?

    private var color: Color { Color(hex: goal.colorHex) }

    private var sortedCheckIns: [CheckInRecord] {
        goal.checkIns.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Stats
                statsSection

                // Quick check-in
                checkInSection

                // Milestones
                milestoneSection

                // History
                historySection

                // Actions
                actionsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background {
            SSColor.backgroundPrimary
                .ignoresSafeArea()
        }
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(duration: 0.5)) { hasAppeared = true }
        }
        // #9 Archive undo toast overlay
        .overlay(alignment: .bottom) {
            if showArchiveToast {
                HStack(spacing: 8) {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(.orange)
                    Text(L10n.goalArchivedToast)
                        .font(.subheadline.weight(.medium))

                    Divider().frame(height: 16)

                    Button {
                        // Undo: reactivate the goal
                        // C3 fix: Use actual active goals count
                        // C4 fix: Cancel the auto-dismiss timer
                        archiveDismissWorkItem?.cancel()
                        _ = viewModel.reactivateGoal(goal, activeCount: activeGoals.count)
                        HapticEngine.shared.selection()
                        withAnimation { showArchiveToast = false }
                    } label: {
                        Text(L10n.undoAction)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SSColor.brand)
                    }
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, SSSpacing.xxl)
            }
        }
        .animation(.spring(duration: 0.3), value: showArchiveToast)
        .alert(L10n.confirmDelete, isPresented: $showDeleteAlert) {
            Button(L10n.delete, role: .destructive) {
                // Cancel any pending archive auto-dismiss before deleting
                archiveDismissWorkItem?.cancel()
                viewModel.deleteGoal(goal, context: modelContext)
                dismiss()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.goalDeleteWarning)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(goal.emoji)
                .font(.system(size: 56))

            Text(goal.title)
                .font(.system(size: 22, weight: .bold))

            HStack(spacing: 12) {
                // Frequency
                Text(goal.frequency.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12).clipShape(Capsule()))

                // Since
                Text(L10n.goalSince(goal.createdAt.formattedShort))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.05), color.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "flame.fill",
                iconColor: .orange,
                value: "\(goal.currentStreak)",
                label: L10n.goalStreak
            )
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 15)
            .animation(.spring(duration: 0.5).delay(0.05), value: hasAppeared)

            StatCard(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                value: "\(goal.totalCheckIns)",
                label: L10n.goalTotal
            )
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 15)
            .animation(.spring(duration: 0.5).delay(0.1), value: hasAppeared)

            StatCard(
                icon: "calendar",
                iconColor: color,
                value: daysSinceCreation,
                label: L10n.goalDaysSince
            )
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 15)
            .animation(.spring(duration: 0.5).delay(0.15), value: hasAppeared)
        }
    }

    private var daysSinceCreation: String {
        let days = Calendar.current.dateComponents([.day], from: goal.createdAt, to: Date()).day ?? 0
        return "\(days)"
    }

    // MARK: - Check-in

    private var checkInSection: some View {
        VStack(spacing: 12) {
            if goal.needsCheckIn {
                Button {
                    // #7 Check-in bounce animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        checkInScale = 1.08
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            checkInScale = 1.0
                        }
                    }
                    viewModel.checkIn(goal: goal, context: modelContext)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text(L10n.goalCheckInNow)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(color.gradient)
                    )
                }
                .scaleEffect(checkInScale)
                .accessibilityLabel(L10n.goalCheckInNow)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                    Text(L10n.goalAlreadyCheckedIn)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.green.opacity(0.1))
                )

                // Undo button
                if goal.frequency == .daily && goal.isCheckedInToday {
                    Button {
                        viewModel.undoCheckIn(goal: goal, context: modelContext)
                        HapticEngine.shared.selection()
                    } label: {
                        Text(L10n.goalUndoCheckIn)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Milestones

    private var milestoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.goalMilestones)
                .font(.system(size: 16, weight: .semibold))

            let milestones = Milestone.milestones(for: goal.frequency)
            VStack(spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.element.count) { index, ms in
                    let reached = goal.totalCheckIns >= ms.count

                    HStack(spacing: 12) {
                        Text(ms.emoji)
                            .font(.system(size: 22))
                            .grayscale(reached ? 0 : 1)
                            .opacity(reached ? 1 : 0.4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(ms.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(reached ? .primary : .secondary)

                            Text(goal.frequency == .daily
                                 ? L10n.goalDayCount(ms.count)
                                 : L10n.goalWeekCount(ms.count))
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        if reached {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(color)
                        } else {
                            Text("\(goal.totalCheckIns)/\(ms.count)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)

                    if index < milestones.count - 1 {
                        Divider().padding(.leading, 54)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.goalHistory)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(L10n.goalTotalCheckIns(goal.totalCheckIns))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            if sortedCheckIns.isEmpty {
                Text(L10n.goalNoCheckIns)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
            } else {
                // Calendar heatmap (last 7 weeks)
                checkInCalendar

                // Recent list
                VStack(spacing: 0) {
                    ForEach(Array(sortedCheckIns.prefix(20).enumerated()), id: \.element.id) { index, record in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)

                            Text(record.date.formattedChinese)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(record.date.formattedTime(in: .current))
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)

                        if index < min(sortedCheckIns.count - 1, 19) {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    // MARK: - Calendar Heatmap

    private var checkInCalendar: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // 1=Sun, 7=Sat
        // Total cells: 7 weeks * 7 days
        let totalDays = 49
        // Align to start of current week (Sunday), then go back 6 more weeks
        let daysIntoWeek = weekday - 1 // 0 for Sunday, 6 for Saturday
        let startDate = calendar.date(byAdding: .day, value: -(totalDays - 1 - (6 - daysIntoWeek)), to: today)!

        let checkInDates = Set(goal.checkIns.map { calendar.startOfDay(for: $0.date) })

        return VStack(spacing: 3) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
                ForEach(0..<totalDays, id: \.self) { offset in
                    let date = calendar.date(byAdding: .day, value: offset, to: startDate)!
                    let isCheckedIn = checkInDates.contains(calendar.startOfDay(for: date))
                    let isFuture = date > Date()

                    RoundedRectangle(cornerRadius: 3)
                        .fill(isFuture
                              ? Color.clear
                              : isCheckedIn ? color : Color(.tertiarySystemFill))
                        .frame(height: 16)
                        .opacity(isFuture ? 0.3 : 1)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 10) {
            // Archive
            Button {
                // #9 Show undo toast instead of immediate dismiss
                viewModel.archiveGoal(goal)
                HapticEngine.shared.selection()
                withAnimation { showArchiveToast = true }
                // C4 fix: Use cancellable work item
                archiveDismissWorkItem?.cancel()
                let work = DispatchWorkItem {
                    showArchiveToast = false
                    dismiss()
                }
                archiveDismissWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
            } label: {
                HStack {
                    Image(systemName: "archivebox")
                    Text(L10n.goalArchiveGoal)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.1))
                )
            }

            // Delete
            Button {
                showDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(L10n.goalDeleteGoal)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.red.opacity(0.1))
                )
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        // #13 Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}

#Preview {
    NavigationStack {
        StudyGoalDetailView(
            goal: StudyGoal(title: "每日阅读", emoji: "📖", colorHex: "#5B7FFF"),
            viewModel: StudyGoalViewModel()
        )
    }
    .modelContainer(for: [StudyGoal.self, CheckInRecord.self], inMemory: true)
}
