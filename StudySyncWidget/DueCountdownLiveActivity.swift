import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Shared Attributes (must match main app)

struct DueCountdownAttributes: ActivityAttributes {
    let eventTitle: String
    let emoji: String
    let dueDate: Date
    let calendarColorHex: String

    struct ContentState: Codable, Hashable {
        let remainingSeconds: Int
        let isUrgent: Bool
        let isCritical: Bool
        let isCompleted: Bool
        let isOverdue: Bool
    }
}

// MARK: - Live Activity Widget

struct DueCountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DueCountdownAttributes.self) { context in
            DueLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.emoji)
                            .font(.title3)
                        Text(context.attributes.eventTitle)
                            .font(.caption.bold())
                            .lineLimit(2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isCompleted {
                        Text("✅")
                            .font(.title)
                    } else {
                        Text(timerInterval: Date.now...context.attributes.dueDate, countsDown: true)
                            .font(.title.bold().monospacedDigit())
                            .foregroundStyle(urgencyTextColor(state: context.state))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    let dueDate = context.attributes.dueDate
                    let progress = progressValue(dueDate: dueDate, leadMinutes: 60)
                    VStack(spacing: 6) {
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.white.opacity(0.2))
                                    .frame(height: 5)
                                Capsule()
                                    .fill(urgencyBarColor(state: context.state))
                                    .frame(width: geo.size.width * progress, height: 5)
                            }
                        }
                        .frame(height: 5)

                        HStack {
                            Text("\(Int(progress * 100))%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Due \(dueDate, format: .dateTime.hour().minute())")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Text(context.attributes.emoji)
                    .font(.caption)
            } compactTrailing: {
                if context.state.isCompleted {
                    Text("✅")
                        .font(.caption)
                } else {
                    Text(timerInterval: Date.now...context.attributes.dueDate, countsDown: true)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(context.state.isUrgent ? .red : .primary)
                        .frame(width: 52)
                }
            } minimal: {
                minimalView(context: context)
            }
        }
    }

    // MARK: - Minimal View

    @ViewBuilder
    private func minimalView(context: ActivityViewContext<DueCountdownAttributes>) -> some View {
        if context.state.isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            let remaining = max(0, context.state.remainingSeconds)
            let mins = remaining / 60
            ZStack {
                Circle()
                    .fill(urgencyBgColor(state: context.state))
                Text("\(mins)")
                    .font(.caption2.bold().monospacedDigit())
            }
        }
    }

    // MARK: - Helper Colors

    private func urgencyTextColor(state: DueCountdownAttributes.ContentState) -> Color {
        if state.isOverdue { return .red }
        if state.isCritical { return .red }
        if state.isUrgent { return Color(hex: "#F97316") }
        return .primary
    }

    private func urgencyBarColor(state: DueCountdownAttributes.ContentState) -> Color {
        if state.isOverdue { return .red }
        if state.isCritical { return .red }
        if state.isUrgent { return Color(hex: "#F97316") }
        return Color(hex: "#F59E0B")
    }

    private func urgencyBgColor(state: DueCountdownAttributes.ContentState) -> Color {
        if state.isOverdue { return .red.opacity(0.8) }
        if state.isCritical { return .red.opacity(0.6) }
        if state.isUrgent { return Color(hex: "#F97316").opacity(0.5) }
        return .orange.opacity(0.3)
    }

    private func progressValue(dueDate: Date, leadMinutes: Int) -> Double {
        let total = TimeInterval(leadMinutes * 60)
        let remaining = dueDate.timeIntervalSinceNow
        let elapsed = total - remaining
        return min(max(elapsed / total, 0), 1)
    }
}

// MARK: - Lock Screen View

struct DueLockScreenView: View {
    let context: ActivityViewContext<DueCountdownAttributes>

    private var bgGradient: LinearGradient {
        let state = context.state
        let colors: [Color]
        if state.isCompleted {
            colors = [Color(hex: "#065F46"), Color(hex: "#064E3B")]
        } else if state.isOverdue || state.isCritical {
            colors = [Color(hex: "#991B1B"), Color(hex: "#7F1D1D")]
        } else if state.isUrgent {
            colors = [Color(hex: "#9A3412"), Color(hex: "#7C2D12")]
        } else {
            colors = [Color(hex: "#1C1917"), Color(hex: "#292524")]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Top: emoji + title
            HStack {
                Text(context.attributes.emoji)
                Text(context.attributes.eventTitle)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
            }

            if context.state.isCompleted {
                completedContent
            } else {
                countdownContent
            }

            // Bottom: due time + progress %
            HStack {
                Text("Due \(context.attributes.dueDate, format: .dateTime.hour().minute())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                let progress = progressValue
                Text("\(Int(progress * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(bgGradient)
        .widgetURL(URL(string: "studysync://schedule"))
    }

    // MARK: - Completed

    private var completedContent: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("已完成")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Countdown

    private var countdownContent: some View {
        VStack(spacing: 8) {
            // Big countdown
            Text(timerInterval: Date.now...context.attributes.dueDate, countsDown: true)
                .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(timerColor)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * progressValue, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var timerColor: Color {
        let s = context.state
        if s.isOverdue || s.isCritical { return .red }
        if s.isUrgent { return Color(hex: "#FB923C") }
        return .white
    }

    private var barColor: Color {
        let s = context.state
        if s.isOverdue || s.isCritical { return .red }
        if s.isUrgent { return Color(hex: "#F97316") }
        return Color(hex: "#F59E0B")
    }

    private var progressValue: Double {
        let total: TimeInterval = 3600 // 1 hour
        let remaining = context.attributes.dueDate.timeIntervalSinceNow
        let elapsed = total - remaining
        return min(max(elapsed / total, 0), 1)
    }
}

