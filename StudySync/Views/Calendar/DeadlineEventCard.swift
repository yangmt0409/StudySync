import SwiftUI
import EventKit

struct DeadlineEventCard: View {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    let event: EKEvent
    let now: Date
    let isCompleted: Bool
    let urgencyLevel: Double
    let urgencyColor: Color

    var onToggleComplete: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onDuplicate: (() -> Void)?
    var onRemoveDeadline: (() -> Void)?

    @State private var checkScale: CGFloat = 1.0
    @State private var glowPhase: Bool = false

    private var calendarColor: Color {
        Color(cgColor: event.calendar.cgColor)
    }

    private var status: CalendarEventStatus {
        if event.isAllDay { return .upcoming }
        if now < event.startDate { return .upcoming }
        if now >= event.startDate && now < event.endDate { return .inProgress }
        return .finished
    }

    // #7 Detect overdue state (including all-day events past their date)
    private var isOverdue: Bool {
        if isCompleted { return false }
        if event.isAllDay {
            // All-day event endDate is start of next day in EventKit
            return now >= event.endDate
        }
        return event.endDate < now
    }

    private var sideColor: Color {
        if isCompleted { return .green }
        if isOverdue { return .red }
        if urgencyLevel > 0 { return urgencyColor }
        return .orange
    }

    private var borderWidth: CGFloat {
        if isCompleted { return 0 }
        if isOverdue { return 2.5 }
        return 1 + urgencyLevel * 2
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            checkboxView

            // Left side bar
            // (integrated into overlay)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("⚠️")
                        .font(.system(size: 12))
                        .opacity(isCompleted ? 0.3 : 1.0)

                    Text(event.title ?? L10n.noTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted, color: .secondary)
                        .lineLimit(1)
                }

                if event.isAllDay {
                    Text(L10n.allDay)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    Text(timeRangeText)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Countdown / Status
            if isCompleted {
                Text(L10n.dlCompleted)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.green)
            } else if !event.isAllDay {
                countdownView
            } else if isOverdue {
                // All-day overdue indicator
                Text(L10n.dlOverdue)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCompleted
                      ? Color(.tertiarySystemFill)
                      : isOverdue
                        ? Color.red.opacity(0.08)
                        : urgencyLevel > 0.3
                            ? urgencyColor.opacity(0.06)
                            : Color(.secondarySystemGroupedBackground))
        )
        // Left side bar
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(sideColor)
                .frame(width: isOverdue ? 4 : 3)
                .padding(.vertical, 8)
        }
        // Urgency / overdue border
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isCompleted ? Color.clear
                    : isOverdue ? Color.red.opacity(0.6)
                    : urgencyColor.opacity(urgencyLevel > 0.1 ? 1.0 : 0),
                    lineWidth: borderWidth
                )
        )
        // Glow effect for high urgency
        .shadow(
            color: urgencyLevel > 0.7 && !isCompleted
                ? urgencyColor.opacity(glowPhase ? 0.5 : 0.2)
                : .clear,
            radius: urgencyLevel * 8
        )
        .opacity(isCompleted ? 0.7 : 1.0)
        .onAppear {
            if urgencyLevel > 0.7 && !isCompleted {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowPhase = true
                }
            }
        }
        .onChange(of: urgencyLevel) { _, newValue in
            if newValue > 0.7 && !isCompleted {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowPhase = true
                }
            } else {
                glowPhase = false
            }
        }
        .contextMenu {
            Button { onToggleComplete?() } label: {
                Label(
                    isCompleted ? L10n.dlMarkIncomplete : L10n.dlMarkComplete,
                    systemImage: isCompleted ? "circle" : "checkmark.circle"
                )
            }

            if CalendarManager.shared.isEventEditable(event) {
                Button { onEdit?() } label: {
                    Label(L10n.calEditCalEvent, systemImage: "pencil")
                }

                Button { onDuplicate?() } label: {
                    Label(L10n.calDuplicateEvent, systemImage: "doc.on.doc")
                }

                Divider()

                Button { onRemoveDeadline?() } label: {
                    Label(L10n.dlRemoveDeadline, systemImage: "minus.circle")
                }

                Button(role: .destructive) { onDelete?() } label: {
                    Label(L10n.calDeleteEvent, systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Checkbox

    private var checkboxView: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                checkScale = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2)) {
                    checkScale = 1.0
                }
            }
            onToggleComplete?()
        } label: {
            ZStack {
                if isCompleted {
                    Circle()
                        .fill(.green)
                        .frame(width: 24, height: 24)

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .stroke(urgencyLevel > 0 ? urgencyColor : .orange, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .scaleEffect(checkScale)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time Range

    private var timeRangeText: String {
        "\(Self.timeFormatter.string(from: event.startDate)) - \(Self.timeFormatter.string(from: event.endDate))"
    }

    // MARK: - Countdown

    @ViewBuilder
    private var countdownView: some View {
        let interval = event.startDate.timeIntervalSince(now)
        if interval > 0 {
            Text(L10n.dlTimeRemaining(formatInterval(interval)))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(urgencyLevel > 0.5 ? urgencyColor : .orange)
        } else if now < event.endDate {
            Text(L10n.calInProgress)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.green)
        } else {
            Text(L10n.dlOverdue)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.red)
        }
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let mins = totalMinutes % 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(max(mins, 1))m"
    }
}
