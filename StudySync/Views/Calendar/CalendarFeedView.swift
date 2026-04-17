import SwiftUI
import EventKit
import Combine
import SwiftData

struct CalendarFeedView: View {
    var manager = CalendarManager.shared
    var urgencyEngine = UrgencyEngine.shared
    @Environment(\.modelContext) private var modelContext
    @Query private var deadlineRecords: [DeadlineRecord]

    @State private var now = Date()
    @State private var isVisible = false

    // Sheets
    @State private var showAddEvent = false
    @State private var editingEvent: EKEvent?
    @State private var showDeleteAlert = false
    @State private var showDeleteSpanAlert = false
    @State private var eventToDelete: EKEvent?

    // Navigation
    @State private var selectedEvent: EKEvent?

    // Toast
    @State private var toastMessage: String?
    @State private var showToast = false
    @State private var toastUndoAction: (() -> Void)?
    @State private var toastDismissWorkItem: DispatchWorkItem?

    // Timers
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let secondTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Computed helpers — use cross-device-safe matching
    private var deadlineIds: Set<String> {
        Set(deadlineRecords.map(\.eventIdentifier))
    }

    private var completedDeadlineIds: Set<String> {
        Set(deadlineRecords.filter(\.isCompleted).map(\.eventIdentifier))
    }

    /// Find the DeadlineRecord for a given EKEvent (cross-device safe).
    private func deadlineRecord(for event: EKEvent) -> DeadlineRecord? {
        deadlineRecords.first { $0.matches(event) }
    }

    private func isDeadline(_ event: EKEvent) -> Bool {
        deadlineRecords.contains { $0.matches(event) }
    }

    private func isCompletedDeadline(_ event: EKEvent) -> Bool {
        deadlineRecords.contains { $0.matches(event) && $0.isCompleted }
    }

    private var deadlineEvents: [EKEvent] {
        manager.events.filter { event in deadlineRecords.contains { $0.matches(event) } }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch manager.authorizationStatus {
                case .fullAccess:
                    authorizedContent
                case .notDetermined:
                    requestAccessView
                default:
                    deniedView
                }
            }
            .navigationDestination(item: $selectedEvent) { event in
                CalendarEventDetailView(event: event)
            }
            .navigationTitle(L10n.calendar)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if manager.hasWriteAccess {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddEvent = true
                            HapticEngine.shared.selection()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(SSColor.brand)
                        }
                    }
                }
            }
            .onAppear {
                isVisible = true
                manager.updateAuthStatus()
                if manager.authorizationStatus == .fullAccess {
                    manager.fetchUpcomingEvents()
                }
                updateUrgency()
            }
            .onDisappear {
                isVisible = false
            }
            // #3 Refresh auth status when returning from Settings
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                manager.updateAuthStatus()
                if manager.authorizationStatus == .fullAccess {
                    manager.fetchUpcomingEvents()
                }
            }
            .onReceive(minuteTimer) { _ in
                guard isVisible else { return }
                now = Date()
                updateUrgency()
            }
            .onReceive(secondTimer) { _ in
                guard isVisible else { return }
                if hasInProgressEvents {
                    now = Date()
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddCalendarEventView {
                    showToastMessage(L10n.calEventCreated)
                }
            }
            .sheet(item: $editingEvent) { event in
                AddCalendarEventView(editingEvent: event) {
                    showToastMessage(L10n.calEventUpdated)
                }
            }
            .alert(L10n.calDeleteEvent, isPresented: $showDeleteAlert) {
                Button(L10n.cancel, role: .cancel) { eventToDelete = nil }
                Button(L10n.delete, role: .destructive) { performDelete(span: .thisEvent) }
            } message: {
                Text(L10n.calDeleteConfirmMessage)
            }
            .alert(L10n.calDeleteEvent, isPresented: $showDeleteSpanAlert) {
                Button(L10n.cancel, role: .cancel) { eventToDelete = nil }
                Button(L10n.calDeleteThisOnly, role: .destructive) { performDelete(span: .thisEvent) }
                Button(L10n.calDeleteAllFuture, role: .destructive) { performDelete(span: .futureEvents) }
            } message: {
                Text(L10n.calDeleteRecurringMessage)
            }
            .overlay(alignment: .bottom) {
                if showToast, let message = toastMessage {
                    toastView(message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, SSSpacing.xxl)
                }
            }
        }
    }

    // MARK: - Urgency Update

    private func updateUrgency() {
        urgencyEngine.update(
            deadlineEvents: deadlineEvents,
            completedIds: completedDeadlineIds
        )
    }

    // MARK: - Authorized Content

    private var authorizedContent: some View {
        List {
            // Calendar filter
            Section {
                calendarFilter
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            let groups = manager.groupedByDay()

            if groups.allSatisfy({ $0.events.isEmpty }) {
                Section {
                    emptyState
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                    Section {
                        // Section header
                        HStack {
                            Text(group.title)
                                .font(SSFont.bodySmallSemibold)
                                .foregroundStyle(index == 0 ? SSColor.brand : .secondary)

                            Spacer()

                            Text("\(group.events.count)")
                                .font(SSFont.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(SSColor.fillTertiary))
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))

                        if group.events.isEmpty {
                            HStack {
                                Spacer()
                                Text(L10n.noSchedule)
                                    .font(SSFont.secondary)
                                    .foregroundStyle(.tertiary)
                                    .padding(.vertical, 20)
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            let sorted = sortEvents(group.events)
                            ForEach(sorted, id: \.eventIdentifier) { event in
                                eventRow(event)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(SSColor.backgroundPrimary)
        .scrollContentBackground(.hidden)
        .refreshable {
            manager.fetchUpcomingEvents()
            updateUrgency()
        }
    }

    // MARK: - Sort (completed deadlines to bottom)

    private func sortEvents(_ events: [EKEvent]) -> [EKEvent] {
        events.sorted { a, b in
            let aCompleted = completedDeadlineIds.contains(a.eventIdentifier)
            let bCompleted = completedDeadlineIds.contains(b.eventIdentifier)
            if aCompleted != bCompleted { return !aCompleted }

            // All-day first
            if a.isAllDay != b.isAllDay { return a.isAllDay }
            return a.startDate < b.startDate
        }
    }

    // MARK: - Event Row

    @ViewBuilder
    private func eventRow(_ event: EKEvent) -> some View {
        let isDeadline = deadlineIds.contains(event.eventIdentifier)

        if isDeadline {
            // Deadline card
            let isCompleted = completedDeadlineIds.contains(event.eventIdentifier)
            let eventUrgency = calculateEventUrgency(event)

            Button {
                selectedEvent = event
            } label: {
                DeadlineEventCard(
                    event: event,
                    now: now,
                    isCompleted: isCompleted,
                    urgencyLevel: isCompleted ? 0 : eventUrgency,
                    urgencyColor: isCompleted ? .clear : urgencyEngine.colorForLevel(eventUrgency),
                    onToggleComplete: { toggleDeadlineCompletion(event) },
                    onEdit: { editingEvent = event },
                    onDelete: { requestDelete(event) },
                    onDuplicate: { duplicateEvent(event) },
                    onRemoveDeadline: { removeDeadlineRecord(event) }
                )
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    toggleDeadlineCompletion(event)
                } label: {
                    Label(
                        isCompleted ? L10n.dlMarkIncomplete : L10n.dlMarkComplete,
                        systemImage: isCompleted ? "circle" : "checkmark.circle"
                    )
                }
                .tint(isCompleted ? .orange : .green)
            }
        } else {
            // Normal card with possible infection
            let infection = calculateInfection(for: event)

            Button {
                selectedEvent = event
            } label: {
                CalendarEventCard(
                    event: event,
                    now: now,
                    onEdit: { editingEvent = event },
                    onDelete: { requestDelete(event) },
                    onDuplicate: { duplicateEvent(event) }
                )
                // Infection overlay
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            urgencyEngine.colorForLevel(urgencyEngine.urgencyLevel).opacity(infection),
                            lineWidth: 1 + infection * 1.5
                        )
                        .opacity(infection > 0.05 ? 1 : 0)
                )
                .contextMenu {
                    Button { selectedEvent = event } label: {
                        Label(L10n.calViewDetail, systemImage: "eye")
                    }

                    if manager.isEventEditable(event) {
                        Button { editingEvent = event } label: {
                            Label(L10n.calEditCalEvent, systemImage: "pencil")
                        }

                        Button { duplicateEvent(event) } label: {
                            Label(L10n.calDuplicateEvent, systemImage: "doc.on.doc")
                        }
                    }

                    Divider()

                    Button { markAsDeadline(event) } label: {
                        Label(L10n.dlMarkAsDeadline, systemImage: "exclamationmark.triangle")
                    }

                    if manager.isEventEditable(event) {
                        Divider()
                        Button(role: .destructive) { requestDelete(event) } label: {
                            Label(L10n.calDeleteEvent, systemImage: "trash")
                        }
                    }

                    if !manager.isEventEditable(event) {
                        Label(L10n.calReadOnly, systemImage: "lock")
                    }
                }
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if manager.isEventEditable(event) {
                    Button(role: .destructive) {
                        requestDelete(event)
                    } label: {
                        Label(L10n.delete, systemImage: "trash")
                    }
                    .tint(.red)
                }

                Button {
                    markAsDeadline(event)
                } label: {
                    Label(L10n.dlMarkAsDeadline, systemImage: "exclamationmark.triangle")
                }
                .tint(.orange)
            }
        }
    }

    // MARK: - Urgency Calculations

    private func calculateEventUrgency(_ event: EKEvent) -> Double {
        let remaining = event.startDate.timeIntervalSince(now)
        let window = urgencyEngine.urgencyWindowHours * 3600
        if remaining > window { return 0 }
        if remaining < -3600 { return 1.0 }
        return max(0, min(1, 1.0 - (remaining / window)))
    }

    private func calculateInfection(for event: EKEvent) -> Double {
        guard urgencyEngine.infectionEnabled else { return 0 }
        // Don't infect finished events
        if !event.isAllDay && event.endDate < now { return 0 }

        var maxInfection: Double = 0
        for deadline in deadlineEvents {
            if completedDeadlineIds.contains(deadline.eventIdentifier) { continue }
            let level = urgencyEngine.infectionLevel(event: event, deadline: deadline)
            maxInfection = max(maxInfection, level)
        }
        return maxInfection
    }

    // MARK: - Deadline Management

    private func markAsDeadline(_ event: EKEvent) {
        // Check if already a deadline
        guard !isDeadline(event) else { return }

        let record = DeadlineRecord(
            eventIdentifier: event.eventIdentifier,
            externalIdentifier: event.calendarItemExternalIdentifier
        )
        modelContext.insert(record)
        try? modelContext.save()
        DeadlineRecordSyncService.shared.pushRecord(record)

        HapticEngine.shared.notification(.warning)
        showToastMessage(L10n.dlMarkedAsDeadline)
        updateUrgency()
    }

    private func removeDeadlineRecord(_ event: EKEvent) {
        if let record = deadlineRecords.first(where: { $0.eventIdentifier == event.eventIdentifier }) {
            let eid = record.eventIdentifier
            modelContext.delete(record)
            try? modelContext.save()
            DeadlineRecordSyncService.shared.deleteRecord(eventIdentifier: eid)
            showToastMessage(L10n.dlRemovedDeadline)
            updateUrgency()
        }
    }

    private func toggleDeadlineCompletion(_ event: EKEvent) {
        if let record = deadlineRecords.first(where: { $0.eventIdentifier == event.eventIdentifier }) {
            record.isCompleted.toggle()
            record.completedAt = record.isCompleted ? Date() : nil
            try? modelContext.save()
            DeadlineRecordSyncService.shared.pushRecord(record)

            if record.isCompleted {
                HapticEngine.shared.success()
                // End Live Activity if this was the tracked event
                if LiveActivityManager.shared.currentEventIdentifier == event.eventIdentifier {
                    LiveActivityManager.shared.completeCountdown()
                }
                // #5 Show undo toast
                showUndoToast(L10n.dlCompleted) {
                    record.isCompleted = false
                    record.completedAt = nil
                    try? modelContext.save()
                    DeadlineRecordSyncService.shared.pushRecord(record)
                    HapticEngine.shared.selection()
                    updateUrgency()
                }
            } else {
                HapticEngine.shared.selection()
                // #5 Show undo toast for uncomplete
                showUndoToast(L10n.deadlineUncompleted) {
                    record.isCompleted = true
                    record.completedAt = Date()
                    try? modelContext.save()
                    DeadlineRecordSyncService.shared.pushRecord(record)
                    HapticEngine.shared.selection()
                    updateUrgency()
                }
            }

            updateUrgency()
        }
    }

    // MARK: - Delete Logic

    private func requestDelete(_ event: EKEvent) {
        eventToDelete = event
        if event.hasRecurrenceRules {
            showDeleteSpanAlert = true
        } else {
            showDeleteAlert = true
        }
    }

    private func performDelete(span: EKSpan) {
        guard let event = eventToDelete else { return }

        // Also clean up deadline record
        if let record = deadlineRecords.first(where: { $0.eventIdentifier == event.eventIdentifier }) {
            let eid = record.eventIdentifier
            modelContext.delete(record)
            try? modelContext.save()
            DeadlineRecordSyncService.shared.deleteRecord(eventIdentifier: eid)
        }

        do {
            try manager.deleteEvent(event, span: span)
            HapticEngine.shared.success()
            showToastMessage(L10n.calEventDeleted)
            updateUrgency()
        } catch {
            HapticEngine.shared.error()
        }
        eventToDelete = nil
    }

    private func duplicateEvent(_ event: EKEvent) {
        do {
            try manager.duplicateEvent(event)
            HapticEngine.shared.success()
            showToastMessage(L10n.calEventDuplicated)
        } catch {
            HapticEngine.shared.error()
        }
    }

    // MARK: - Toast

    private func showToastMessage(_ message: String) {
        // C2 fix: Cancel any previous toast timer
        toastDismissWorkItem?.cancel()
        toastMessage = message
        toastUndoAction = nil
        withAnimation(.spring(response: 0.3)) {
            showToast = true
        }
        let work = DispatchWorkItem {
            withAnimation(.spring(response: 0.3)) {
                showToast = false
            }
        }
        toastDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    // #5 Undo toast with action
    private func showUndoToast(_ message: String, undoAction: @escaping () -> Void) {
        // C2 fix: Cancel any previous toast timer
        toastDismissWorkItem?.cancel()
        toastMessage = message
        toastUndoAction = undoAction
        withAnimation(.spring(response: 0.3)) {
            showToast = true
        }
        let work = DispatchWorkItem {
            withAnimation(.spring(response: 0.3)) {
                showToast = false
                toastUndoAction = nil
            }
        }
        toastDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func toastView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.subheadline.weight(.medium))

            if let undo = toastUndoAction {
                Divider().frame(height: 16)
                Button {
                    undo()
                    withAnimation(.spring(response: 0.3)) {
                        showToast = false
                        toastUndoAction = nil
                    }
                } label: {
                    Text(L10n.undoAction)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SSColor.brand)
                }
            }
        }
        .padding(.horizontal, SSSpacing.xl)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
    }

    // MARK: - Calendar Filter

    private var calendarFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(manager.calendars, id: \.calendarIdentifier) { cal in
                    let isHidden = manager.hiddenCalendarIDs.contains(cal.calendarIdentifier)

                    Button {
                        var hidden = manager.hiddenCalendarIDs
                        if isHidden {
                            hidden.remove(cal.calendarIdentifier)
                        } else {
                            hidden.insert(cal.calendarIdentifier)
                        }
                        manager.hiddenCalendarIDs = hidden
                        HapticEngine.shared.selection()
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(cgColor: cal.cgColor))
                                .frame(width: 8, height: 8)

                            Text(cal.title)
                                .font(SSFont.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(isHidden ? .secondary : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isHidden ? SSColor.fillTertiary : Color(cgColor: cal.cgColor).opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .stroke(isHidden ? Color.clear : Color(cgColor: cal.cgColor).opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "calendar.badge.checkmark")
                .font(SSFont.displayIcon)
                .foregroundStyle(.secondary)
            Text(L10n.noRecentSchedule)
                .font(SSFont.heading3)
                .foregroundStyle(.secondary)
            Text(L10n.enjoyFreeTime)
                .font(SSFont.secondary)
                .foregroundStyle(.tertiary)

            Button {
                showAddEvent = true
                HapticEngine.shared.lightImpact()
            } label: {
                Label(L10n.calAddCalEvent, systemImage: "plus")
                    .font(SSFont.bodySmallSemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(SSColor.brand))
            }
            .padding(.top, SSSpacing.md)

            Spacer()
        }
    }

    // MARK: - Request Access View

    private var requestAccessView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "calendar.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(SSColor.brand)
            Text(L10n.connectCalendar)
                .font(SSFont.heading1)
            Text(L10n.calendarAccessDescription)
                .font(SSFont.bodySmallMedium)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await manager.requestAccess() }
            } label: {
                Text(L10n.allowAccess)
                    .font(SSFont.heading3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                            .fill(SSColor.brand)
                    )
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Denied View

    private var deniedView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            Text(L10n.calendarDenied)
                .font(SSFont.heading1)
            Text(L10n.openSettings)
                .font(SSFont.bodySmallMedium)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(L10n.goToSettings)
                    .font(SSFont.heading3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                            .fill(.orange)
                    )
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Helpers

    private var hasInProgressEvents: Bool {
        manager.events.contains { event in
            !event.isAllDay && now >= event.startDate && now < event.endDate
        }
    }
}

// Make EKEvent identifiable for .sheet(item:)
extension EKEvent: @retroactive Identifiable {
    public var id: String { eventIdentifier }
}

#Preview {
    CalendarFeedView()
}
