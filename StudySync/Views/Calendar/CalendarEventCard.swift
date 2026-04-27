import SwiftUI
import EventKit

// MARK: - Event Status

enum CalendarEventStatus {
    case upcoming    // hasn't started
    case inProgress  // currently happening
    case finished    // already ended

    var isUrgent: Bool { false }
}

struct CalendarEventCard: View {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    let event: EKEvent
    let now: Date
    var manager = CalendarManager.shared

    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onDuplicate: (() -> Void)?

    private var status: CalendarEventStatus {
        if event.isAllDay { return .upcoming }
        if now < event.startDate { return .upcoming }
        if now >= event.startDate && now < event.endDate { return .inProgress }
        return .finished
    }

    private var calendarColor: Color {
        Color(cgColor: event.calendar.cgColor)
    }

    private var progress: Double {
        guard status == .inProgress else { return status == .finished ? 1.0 : 0.0 }
        let total = event.endDate.timeIntervalSince(event.startDate)
        guard total > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(event.startDate)
        return min(max(elapsed / total, 0), 1)
    }

    private var minutesUntilStart: Int {
        Int(event.startDate.timeIntervalSince(now) / 60)
    }

    private var isEditable: Bool {
        manager.isEventEditable(event)
    }

    var body: some View {
        cardContent
    }

    // MARK: - Card Content

    private var cardContent: some View {
        HStack(spacing: SSSpacing.lg) {
            // Left: color indicator
            leftIndicator

            // Middle: title + time
            VStack(alignment: .leading, spacing: SSSpacing.xs) {
                HStack(spacing: SSSpacing.xs) {
                    Text(event.title ?? L10n.noTitle)
                        .font(SSFont.bodySmallSemibold)
                        .foregroundStyle(status == .finished ? .secondary : .primary)
                        .lineLimit(2)
                        .truncationMode(.tail)

                    if !isEditable {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }

                if event.isAllDay {
                    Text(L10n.allDay)
                        .font(SSFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(timeRangeText)
                        .font(SSFont.caption)
                        .foregroundStyle(.secondary)
                }

                // Progress bar for in-progress events
                if status == .inProgress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(calendarColor.opacity(SSOpacity.lightTint))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(calendarColor)
                                .frame(width: geo.size.width * progress, height: 4)
                                .animation(.linear(duration: 1), value: progress)
                        }
                    }
                    .frame(height: 4)
                }
            }

            Spacer()

            // Right: countdown
            if !event.isAllDay {
                countdownView
            }
        }
        .padding(SSSpacing.lgXl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                .fill(status == .inProgress
                      ? calendarColor.opacity(0.06)
                      : Color(.secondarySystemGroupedBackground))
        )
        .overlay(alignment: .leading) {
            if status == .inProgress {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green)
                    .frame(width: 3)
                    .padding(.vertical, SSSpacing.md)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                .stroke(
                    status == .inProgress ? calendarColor.opacity(0.2) : Color.clear,
                    lineWidth: 1
                )
        )
        .opacity(status == .finished ? 0.6 : 1.0)
        // Long-press affordance for edit / delete — matches the gesture
        // available on EventCardView (Countdown) and DeadlineEventCard.
        // Only shows up if the parent passes onEdit/onDelete handlers.
        .contextMenu {
            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label(L10n.editEvent, systemImage: "pencil")
                }
            }
            if onEdit != nil && onDelete != nil { Divider() }
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(L10n.deleteEvent, systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Left Indicator

    private var leftIndicator: some View {
        Circle()
            .fill(calendarColor)
            .frame(width: 10, height: 10)
    }

    // MARK: - Time Range Text

    private var timeRangeText: String {
        let start = Self.timeFormatter.string(from: event.startDate)
        let end = Self.timeFormatter.string(from: event.endDate)
        return "\(start) - \(end)"
    }

    // MARK: - Countdown View

    @ViewBuilder
    private var countdownView: some View {
        switch status {
        case .upcoming:
            VStack(alignment: .trailing, spacing: 2) {
                Text(countdownText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(urgencyColor)
            }

        case .inProgress:
            VStack(alignment: .trailing, spacing: 2) {
                Text(remainingText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.green)

                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }

        case .finished:
            Text(L10n.ended)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Urgency Color

    private var urgencyColor: Color {
        let mins = minutesUntilStart
        if mins < 10 { return .red }
        if mins < 30 { return .orange }
        return .primary
    }

    // MARK: - Countdown Text

    private var countdownText: String {
        let interval = event.startDate.timeIntervalSince(now)
        if interval <= 0 { return L10n.starting }
        return "in \(formatInterval(interval))"
    }

    private var remainingText: String {
        let interval = event.endDate.timeIntervalSince(now)
        if interval <= 0 { return L10n.ending }
        return "\(formatInterval(interval)) left"
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let mins = totalMinutes % 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(mins)min"
        } else {
            return "\(max(mins, 1))min"
        }
    }
}
