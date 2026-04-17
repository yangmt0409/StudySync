import SwiftUI
import EventKit
import Combine

struct CalendarEventDetailView: View {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMd EEEE")
        f.locale = Locale.current
        return f
    }()

    let event: EKEvent
    var manager = CalendarManager.shared

    @Environment(\.dismiss) private var dismiss
    @State private var now = Date()
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showDeleteSpanAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isDeleted = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var calendarColor: Color {
        Color(cgColor: event.calendar.cgColor)
    }

    private var isEditable: Bool {
        manager.isEventEditable(event)
    }

    private var isRecurring: Bool {
        event.hasRecurrenceRules
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Color bar at top
                calendarColor
                    .frame(height: 4)

                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Time info card
                    timeInfoCard

                    // Location (map thumbnail)
                    if let location = event.location, !location.isEmpty {
                        LocationMapThumbnail(location: location) {
                            openInMaps(location)
                        }
                    }

                    // Notes
                    if let notes = event.notes, !notes.isEmpty {
                        infoRow(icon: "note.text", title: L10n.noteSection, content: notes)
                    }

                    // Alarms
                    if let alarms = event.alarms, !alarms.isEmpty {
                        alarmsCard(alarms)
                    }

                    // Calendar
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        Text(L10n.calBelongsToCalendar)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)

                        Spacer()

                        HStack(spacing: 6) {
                            Circle()
                                .fill(calendarColor)
                                .frame(width: 10, height: 10)
                            Text(event.calendar.title)
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )

                    // Read-only indicator
                    if !isEditable {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                            Text(L10n.calReadOnly)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    }

                    // Action buttons
                    if isEditable {
                        actionButtons
                    }
                }
                .padding(16)
            }
        }
        .background {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        }
        .navigationTitle(L10n.calEventDetail)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in now = Date() }
        .sheet(isPresented: $showEditSheet) {
            AddCalendarEventView(editingEvent: event) {
                // #6 Refresh event data after edit
                manager.fetchUpcomingEvents()
            }
        }
        .alert(L10n.calDeleteEvent, isPresented: $showDeleteAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.delete, role: .destructive) { deleteEvent(span: .thisEvent) }
        } message: {
            Text(L10n.calDeleteConfirmMessage)
        }
        .alert(L10n.calDeleteEvent, isPresented: $showDeleteSpanAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.calDeleteThisOnly, role: .destructive) { deleteEvent(span: .thisEvent) }
            Button(L10n.calDeleteAllFuture, role: .destructive) { deleteEvent(span: .futureEvents) }
        } message: {
            Text(L10n.calDeleteRecurringMessage)
        }
        .alert(L10n.errorTitle, isPresented: $showError) {
            Button(L10n.done) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(event.title ?? L10n.noTitle)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Circle()
                    .fill(calendarColor)
                    .frame(width: 8, height: 8)
                Text(event.calendar.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Time Info Card

    /// Whether start and end fall on the same calendar day.
    private var isSameDay: Bool {
        Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate)
    }

    private var timeInfoCard: some View {
        VStack(spacing: 14) {
            if event.isAllDay {
                // All-day event
                allDaySection
            } else if isSameDay {
                // Same-day event — compact single-date layout
                sameDaySection
            } else {
                // Multi-day event — show both dates
                multiDaySection
            }

            // Countdown / Progress
            countdownSection

            // Recurrence
            if let rules = event.recurrenceRules, let rule = rules.first {
                HStack(spacing: 6) {
                    Image(systemName: "repeat")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text(formatRecurrence(rule))
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - All Day

    private var allDaySection: some View {
        VStack(spacing: 4) {
            Text(formatDate(event.startDate))
                .font(SSFont.secondary)
                .foregroundStyle(.secondary)
            Text(L10n.allDay)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Same Day (compact)

    private var sameDaySection: some View {
        VStack(spacing: 6) {
            // Date — shown once
            Text(formatDate(event.startDate))
                .font(SSFont.secondary)
                .foregroundStyle(.secondary)

            // Time range — single line, large
            HStack(spacing: 10) {
                Text(formatTime(event.startDate))
                    .font(.title2.bold().monospacedDigit())

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)

                Text(formatTime(event.endDate))
                    .font(.title2.bold().monospacedDigit())
            }

            // Duration
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(formatDuration(from: event.startDate, to: event.endDate))
                    .font(SSFont.caption)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Multi-day

    private var multiDaySection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                // Start
                VStack(spacing: 4) {
                    Text(formatTime(event.startDate))
                        .font(.title3.bold().monospacedDigit())
                    Text(formatDate(event.startDate))
                        .font(SSFont.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 32)

                // End
                VStack(spacing: 4) {
                    Text(formatTime(event.endDate))
                        .font(.title3.bold().monospacedDigit())
                    Text(formatDate(event.endDate))
                        .font(SSFont.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Duration
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(formatDuration(from: event.startDate, to: event.endDate))
                    .font(SSFont.caption)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Countdown / Progress

    @ViewBuilder
    private var countdownSection: some View {
        if event.isAllDay {
            EmptyView()
        } else if now < event.startDate {
            let interval = event.startDate.timeIntervalSince(now)
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.subheadline)
                Text(L10n.calStartsIn(formatCountdown(interval)))
                    .font(.subheadline.bold())
            }
            .foregroundStyle(.orange)
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.12))
            )
        } else if now < event.endDate {
            let total = event.endDate.timeIntervalSince(event.startDate)
            let elapsed = now.timeIntervalSince(event.startDate)
            let progress = min(max(elapsed / total, 0), 1)

            VStack(spacing: 6) {
                ProgressView(value: progress)
                    .tint(.green)

                HStack {
                    Text(L10n.calInProgress)
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Spacer()
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Alarms Card

    private func alarmsCard(_ alarms: [EKAlarm]) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.fill")
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.calReminder)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(Array(alarms.enumerated()), id: \.offset) { _, alarm in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 5, height: 5)
                        Text(formatAlarm(alarm))
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Info Row

    private func infoRow(icon: String, title: String, content: String, tappable: Bool = false, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if tappable {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .disabled(!tappable)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showEditSheet = true
            } label: {
                Label(L10n.calEditCalEvent, systemImage: "pencil")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
            }

            Button(role: .destructive) {
                if isRecurring {
                    showDeleteSpanAlert = true
                } else {
                    showDeleteAlert = true
                }
            } label: {
                Label(L10n.calDeleteEvent, systemImage: "trash")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.red.opacity(0.1))
                    )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Delete

    private func deleteEvent(span: EKSpan) {
        do {
            try manager.deleteEvent(event, span: span)
            HapticEngine.shared.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticEngine.shared.error()
        }
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatDuration(from start: Date, to end: Date) -> String {
        let minutes = Int(end.timeIntervalSince(start) / 60)
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return L10n.calDurationHourMin(hours, mins)
        } else if hours > 0 {
            return L10n.calDurationHour(hours)
        } else {
            return L10n.calDurationMin(mins)
        }
    }

    private func formatCountdown(_ interval: TimeInterval) -> String {
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

    private func formatAlarm(_ alarm: EKAlarm) -> String {
        let offset = abs(alarm.relativeOffset)
        let minutes = Int(offset / 60)
        if minutes < 60 {
            return L10n.calAlarmMinBefore(minutes)
        } else if minutes < 1440 {
            return L10n.calAlarmHourBefore(minutes / 60)
        } else {
            return L10n.calAlarmDayBefore(minutes / 1440)
        }
    }

    private func formatRecurrence(_ rule: EKRecurrenceRule) -> String {
        switch rule.frequency {
        case .daily: return L10n.calRepeatDaily
        case .weekly:
            if rule.interval == 2 { return L10n.calRepeatBiweekly }
            return L10n.calRepeatWeekly
        case .monthly: return L10n.calRepeatMonthly
        case .yearly: return L10n.calRepeatYearly
        @unknown default: return ""
        }
    }

    private func openInMaps(_ location: String) {
        let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}
