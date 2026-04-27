import SwiftUI
import SwiftData
import Charts

struct StudyAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FocusSession.startedAt, order: .reverse) private var allSessions: [FocusSession]
    @Query(filter: #Predicate<StudyGoal> { $0.isArchived == false }) private var activeGoals: [StudyGoal]

    private let brandBlue = SSColor.brand
    private let brandPurple = SSColor.brandPurple

    // MARK: - Computed: Sessions

    private var thisWeekSessions: [FocusSession] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        )!
        return allSessions.filter { $0.isCompleted && $0.startedAt >= startOfWeek }
    }

    private var lastWeekSessions: [FocusSession] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        )!
        let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek)!
        return allSessions.filter {
            $0.isCompleted && $0.startedAt >= startOfLastWeek && $0.startedAt < startOfWeek
        }
    }

    private var thisWeekMinutes: Int {
        thisWeekSessions.reduce(0) { $0 + $1.actualMinutes }
    }

    private var lastWeekMinutes: Int {
        lastWeekSessions.reduce(0) { $0 + $1.actualMinutes }
    }

    private var weekChangePercent: Double {
        guard lastWeekMinutes > 0 else { return thisWeekMinutes > 0 ? 100 : 0 }
        return Double(thisWeekMinutes - lastWeekMinutes) / Double(lastWeekMinutes) * 100
    }

    private var bestCurrentStreak: Int {
        activeGoals.map(\.currentStreak).max() ?? 0
    }

    private var dailyFocusData: [(date: Date, minutes: Int)] {
        let calendar = Calendar.current
        var result: [(date: Date, minutes: Int)] = []
        for dayOffset in (0..<7).reversed() {
            let date = calendar.date(
                byAdding: .day,
                value: -dayOffset,
                to: calendar.startOfDay(for: Date())
            )!
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
            let mins = allSessions
                .filter { $0.isCompleted && $0.startedAt >= date && $0.startedAt < nextDay }
                .reduce(0) { $0 + $1.actualMinutes }
            result.append((date: date, minutes: mins))
        }
        return result
    }

    private var hourlyDistribution: [(hour: Int, minutes: Int)] {
        var hours = Array(repeating: 0, count: 24)
        for s in allSessions where s.isCompleted {
            let hour = Calendar.current.component(.hour, from: s.startedAt)
            hours[hour] += s.actualMinutes
        }
        return hours.enumerated()
            .map { (hour: $0, minutes: $1) }
            .filter { $0.minutes > 0 }
            .sorted { $0.minutes > $1.minutes }
    }

    private var topHours: [(hour: Int, minutes: Int)] {
        Array(hourlyDistribution.prefix(8))
    }

    private var maxHourlyMinutes: Int {
        topHours.map(\.minutes).max() ?? 1
    }

    // Weekly report text
    private var reportHours: Int { thisWeekMinutes / 60 }
    private var reportMins: Int { thisWeekMinutes % 60 }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SSSpacing.xxl) {
                    summaryCard
                    dailyChartCard
                    if !topHours.isEmpty {
                        hourlyDistributionCard
                    }
                    if !activeGoals.isEmpty {
                        goalStreaksCard
                    }
                    weeklyReportCard
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.vertical, SSSpacing.xxl)
            }
            .background(SSColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(L10n.analyticsTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done) { dismiss() }
                        .font(SSFont.bodySemibold)
                        .foregroundStyle(SSColor.brand)
                }
            }
        }
    }

    // MARK: - Section A: Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            sectionHeader(L10n.analyticsThisWeek, icon: "calendar.badge.clock")

            HStack(spacing: 0) {
                // Focus minutes with change indicator
                VStack(alignment: .leading, spacing: SSSpacing.xs) {
                    let hrs = thisWeekMinutes / 60
                    let mins = thisWeekMinutes % 60
                    HStack(alignment: .lastTextBaseline, spacing: SSSpacing.xs) {
                        if hrs > 0 {
                            Text("\(hrs)")
                                .font(SSFont.countdownLarge)
                            Text("h")
                                .font(SSFont.caption)
                                .foregroundStyle(.secondary)
                                .offset(y: -2)
                        }
                        Text("\(mins)")
                            .font(SSFont.countdownLarge)
                        Text("m")
                            .font(SSFont.caption)
                            .foregroundStyle(.secondary)
                            .offset(y: -2)
                    }
                    .foregroundStyle(.primary)

                    changeLabel
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Divider
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(.separator).opacity(0.3))
                    .frame(width: 1, height: 60)
                    .padding(.horizontal, SSSpacing.lg)

                // Sessions count
                VStack(spacing: SSSpacing.xs) {
                    Text("\(thisWeekSessions.count)")
                        .font(SSFont.countdownLarge)
                    Text(L10n.analyticsSessions)
                        .font(SSFont.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Divider
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(.separator).opacity(0.3))
                    .frame(width: 1, height: 60)
                    .padding(.horizontal, SSSpacing.lg)

                // Best streak
                VStack(spacing: SSSpacing.xs) {
                    HStack(spacing: 2) {
                        Text("\(bestCurrentStreak)")
                            .font(SSFont.countdownLarge)
                        Text("🔥")
                            .font(SSFont.body)
                    }
                    Text(L10n.goalStreak)
                        .font(SSFont.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    @ViewBuilder
    private var changeLabel: some View {
        let change = weekChangePercent
        let isUp = change >= 0
        let isZero = lastWeekMinutes == 0 && thisWeekMinutes == 0

        if isZero {
            Text(L10n.analyticsNoData)
                .font(SSFont.footnote)
                .foregroundStyle(.tertiary)
        } else {
            HStack(spacing: 3) {
                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 11, weight: .semibold))
                Text(String(format: "%.0f%%", abs(change)))
                    .font(SSFont.badge)
                    .fontWeight(.semibold)
                Text(L10n.analyticsChange)
                    .font(SSFont.badge)
            }
            .foregroundStyle(isUp ? Color.green : Color.red)
        }
    }

    // MARK: - Section B: Daily Bar Chart

    private var dailyChartCard: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            sectionHeader(L10n.analyticsDailyFocus, icon: "chart.bar.fill")

            let hasData = dailyFocusData.contains { $0.minutes > 0 }

            if hasData {
                Chart {
                    ForEach(dailyFocusData, id: \.date) { item in
                        BarMark(
                            x: .value("Day", item.date, unit: .day),
                            y: .value("Minutes", item.minutes)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [brandBlue, brandPurple],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.tertiary)
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)m")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .font(SSFont.micro)
                    }
                }
                .frame(height: 180)
            } else {
                emptyChartPlaceholder(height: 180)
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    // MARK: - Section C: Hourly Distribution

    private var hourlyDistributionCard: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            sectionHeader(L10n.analyticsHourly, icon: "clock.fill")

            VStack(spacing: SSSpacing.sm) {
                ForEach(topHours, id: \.hour) { item in
                    HStack(spacing: SSSpacing.md) {
                        Text(hourLabel(item.hour))
                            .font(SSFont.badge)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                            .monospacedDigit()

                        GeometryReader { geo in
                            let width = geo.size.width * CGFloat(item.minutes) / CGFloat(maxHourlyMinutes)
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 14)

                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [brandBlue, brandPurple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(width, 4), height: 14)
                            }
                        }
                        .frame(height: 14)

                        Text("\(item.minutes)m")
                            .font(SSFont.badge)
                            .foregroundStyle(.tertiary)
                            .frame(width: 36, alignment: .leading)
                            .monospacedDigit()
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

    // MARK: - Section D: Goal Streaks

    private var goalStreaksCard: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            sectionHeader(L10n.analyticsGoalStreaks, icon: "flame.fill")

            VStack(spacing: SSSpacing.md) {
                ForEach(activeGoals) { goal in
                    goalStreakRow(goal)
                }
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    private func goalStreakRow(_ goal: StudyGoal) -> some View {
        HStack(spacing: SSSpacing.md) {
            Text(goal.emoji)
                .font(.system(size: 24))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(hex: goal.colorHex).opacity(SSOpacity.lightTint))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(SSFont.bodySmallMedium)
                    .lineLimit(1)

                HStack(spacing: SSSpacing.sm) {
                    Label("\(goal.currentStreak)", systemImage: "flame.fill")
                        .font(SSFont.badge)
                        .foregroundStyle(.orange)

                    Text("·")
                        .foregroundStyle(.quaternary)

                    Text(L10n.goalTotalCheckIns(goal.totalCheckIns))
                        .font(SSFont.badge)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Milestone progress ring
            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: goal.milestoneProgress)
                    .stroke(
                        LinearGradient(
                            colors: [brandBlue, brandPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.5), value: goal.milestoneProgress)
            }
            .frame(width: 32, height: 32)
        }
        .padding(.vertical, SSSpacing.xs)
    }

    // MARK: - Section E: Weekly Report Card

    private var weeklyReportCard: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            sectionHeader(L10n.analyticsWeeklyReport, icon: "doc.text.fill")

            // Report card
            reportCardContent
                .padding(SSSpacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [brandBlue.opacity(SSOpacity.tagBackground), brandPurple.opacity(SSOpacity.shadow)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                .strokeBorder(brandBlue.opacity(0.2), lineWidth: 1)
                        )
                )

            // Share button
            ShareLink(
                item: shareText,
                preview: SharePreview(L10n.analyticsWeeklyReport, image: Image(systemName: "chart.bar.fill"))
            ) {
                Label(L10n.analyticsShareReport, systemImage: "square.and.arrow.up")
                    .font(SSFont.bodySmallSemibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SSSpacing.mdLg)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [brandBlue, brandPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    private var reportCardContent: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            HStack {
                Text("📊")
                    .font(.system(size: 22))
                Text(L10n.analyticsWeeklyReport)
                    .font(SSFont.heading3)
            }

            VStack(alignment: .leading, spacing: SSSpacing.sm) {
                reportRow(
                    icon: "timer",
                    text: reportHours > 0
                        ? L10n.analyticsReportStudyTimeHM(reportHours, reportMins)
                        : L10n.analyticsReportStudyTimeM(reportMins)
                )
                reportRow(
                    icon: "checkmark.circle.fill",
                    text: L10n.analyticsReportSessions(thisWeekSessions.count)
                )
                reportRow(
                    icon: "flame.fill",
                    text: L10n.analyticsReportStreak(bestCurrentStreak)
                )
                if lastWeekMinutes > 0 {
                    let change = weekChangePercent
                    let isUp = change >= 0
                    reportRow(
                        icon: isUp ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                        text: L10n.analyticsReportWeekChange(
                            isUp: isUp,
                            percent: String(format: "%.0f", abs(change))
                        )
                    )
                }
            }
        }
    }

    private func reportRow(icon: String, text: String) -> some View {
        HStack(spacing: SSSpacing.sm) {
            Image(systemName: icon)
                .font(SSFont.caption)
                .foregroundStyle(brandBlue)
                .frame(width: 18)
            Text(text)
                .font(SSFont.secondary)
                .foregroundStyle(.primary)
        }
    }

    private var shareText: String {
        let hoursPart = reportHours > 0
            ? L10n.analyticsReportStudyTimeHM(reportHours, reportMins)
            : L10n.analyticsReportStudyTimeM(reportMins)
        return """
        \(hoursPart)
        \(L10n.analyticsReportSessions(thisWeekSessions.count))
        \(L10n.analyticsReportStreak(bestCurrentStreak))
        \(L10n.analyticsReportFrom)
        """
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(SSFont.bodySmallSemibold)
            .foregroundStyle(.primary)
    }

    private func emptyChartPlaceholder(height: CGFloat) -> some View {
        VStack(spacing: SSSpacing.sm) {
            Image(systemName: "chart.bar")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(L10n.analyticsNoData)
                .font(SSFont.footnote)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}

#Preview {
    StudyAnalyticsView()
        .modelContainer(for: [FocusSession.self, StudyGoal.self], inMemory: true)
}
