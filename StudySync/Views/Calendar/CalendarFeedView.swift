import SwiftUI
import EventKit
import Combine
import SwiftData

struct CalendarFeedView: View {
    var manager = CalendarManager.shared
    var urgencyEngine = UrgencyEngine.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Query private var deadlineRecords: [DeadlineRecord]
    @Query(sort: \TravelEvent.departureTimeLocal, order: .forward)
    private var allTravelEvents: [TravelEvent]

    @State private var now = Date()
    @State private var isVisible = false

    // Sheets
    @State private var showAddEvent = false
    @State private var showAddTravel = false
    @State private var editingEvent: EKEvent?
    @State private var showDeleteAlert = false
    @State private var showDeleteSpanAlert = false
    @State private var eventToDelete: EKEvent?

    // Navigation
    @State private var selectedEvent: EKEvent?
    @State private var selectedTravel: TravelEvent?

    /// Filter travel events to upcoming or in-progress only.
    private var upcomingTravel: [TravelEvent] {
        allTravelEvents.filter { !$0.markedComplete && $0.arrivalInstant > Date().addingTimeInterval(-3600) }
    }

    /// Map of "next leg id → connection" for fast O(1) lookup while we
    /// render. A `TravelEvent.id` is in this dict iff it's the SECOND leg
    /// of a layover pair detected by `TravelConnectionDetector`. Used by
    /// `dayItemRow(.travel:)` and the bottom "更多行程" section to pin a
    /// connection banner above the second card.
    private var connectionsByNextId: [UUID: TravelConnection] {
        TravelConnectionDetector.indexByNextId(events: upcomingTravel)
    }

    /// Trips whose departure day falls on `date` (user's current calendar TZ).
    /// Used to interleave trips into per-day calendar sections.
    private func travelForDay(_ date: Date) -> [TravelEvent] {
        let cal = Calendar.current
        return upcomingTravel.filter { cal.isDate($0.departureInstant, inSameDayAs: date) }
    }

    /// Trips whose departure day isn't covered by any visible day-group.
    /// Shown in a compact "更多行程" section at the bottom so they aren't lost
    /// when the user's `calendarDayRange` is shorter than their planning horizon.
    private func laterTravel(visibleDates: [Date]) -> [TravelEvent] {
        let cal = Calendar.current
        let visibleDays = Set(visibleDates.map { cal.startOfDay(for: $0) })
        return upcomingTravel.filter { trip in
            !visibleDays.contains(cal.startOfDay(for: trip.departureInstant))
        }
    }

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
            .navigationDestination(item: $selectedTravel) { travel in
                TravelDetailView(event: travel)
            }
            .navigationTitle(L10n.calendar)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if manager.hasWriteAccess {
                            Button {
                                showAddEvent = true
                                HapticEngine.shared.selection()
                            } label: {
                                Label(String(localized: "添加日历事件"),
                                      systemImage: "calendar.badge.plus")
                            }
                        }
                        Button {
                            showAddTravel = true
                            HapticEngine.shared.selection()
                        } label: {
                            Label(String(localized: "添加行程"),
                                  systemImage: "airplane")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(SSColor.brand)
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
                // Kick off a travel status refresh in the background
                Task { await TravelStatusRefresher.shared.refreshUpcoming(using: modelContext) }
            }
            .task {
                // Pull travel events from Firestore on tab appearance.
                // Restores trips after reinstall / new device login.
                await TravelEventSyncService.shared.pullAll(context: modelContext)
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
                // Refresh real-time status for upcoming flights on foreground
                Task { await TravelStatusRefresher.shared.refreshUpcoming(using: modelContext) }
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
            .sheet(isPresented: $showAddTravel) {
                AddTravelView()
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
            let laterTrips = laterTravel(visibleDates: groups.map(\.date))
            let allEmpty = groups.allSatisfy { group in
                group.events.isEmpty && travelForDay(group.date).isEmpty
            } && laterTrips.isEmpty

            if allEmpty {
                Section {
                    emptyState
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                    let dayTrips = travelForDay(group.date)
                    let items = mergedDayItems(events: group.events, travel: dayTrips)
                    Section {
                        // Section header — count includes both calendar events
                        // and trips so the badge reflects what the user sees.
                        HStack {
                            Text(group.title)
                                .font(SSFont.bodySmallSemibold)
                                .foregroundStyle(index == 0 ? SSColor.brand : .secondary)

                            Spacer()

                            Text("\(items.count)")
                                .font(SSFont.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(SSColor.fillTertiary))
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))

                        if items.isEmpty {
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
                            ForEach(items) { item in
                                dayItemRow(item)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                }

                // Trips beyond the visible day range — not pinned at top; we
                // surface them at the very bottom so they remain discoverable
                // without hijacking the "today" view.
                if !laterTrips.isEmpty {
                    Section {
                        ForEach(laterTrips) { travel in
                            travelRow(travel)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "airplane")
                                .font(.system(size: 11, weight: .semibold))
                            Text(String(localized: "更多行程"))
                                .font(SSFont.bodySmallSemibold)
                        }
                        .foregroundStyle(.secondary)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
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

    // MARK: - Day item merge + sort

    /// Merge calendar events + travel events for a single day into one
    /// time-ordered list. Ordering rules (applied in this priority):
    ///   1. Completed deadlines fall to the bottom (matches prior behavior).
    ///   2. All-day calendar events float to the top of the non-completed
    ///      group (trips are never all-day).
    ///   3. Everything else sorts by start time — calendar uses `startDate`,
    ///      travel uses `departureInstant`.
    private func mergedDayItems(events: [EKEvent], travel: [TravelEvent]) -> [DayItem] {
        let items: [DayItem] = events.map { .calendar($0) }
            + travel.map { .travel($0) }
        return items.sorted { a, b in
            if a.isCompletedDeadline(completedDeadlineIds) !=
                b.isCompletedDeadline(completedDeadlineIds) {
                return !a.isCompletedDeadline(completedDeadlineIds)
            }
            if a.isAllDay != b.isAllDay { return a.isAllDay }
            return a.sortTime < b.sortTime
        }
    }

    @ViewBuilder
    private func dayItemRow(_ item: DayItem) -> some View {
        switch item {
        case .calendar(let event):
            eventRow(event)
        case .travel(let travel):
            travelRow(travel)
        }
    }

    /// Travel card with an optional connection banner on top.
    /// The banner is pinned ABOVE the card (same tap target sequence as
    /// the surrounding event rows) and only renders if this trip is the
    /// next leg of a detected layover within 18h.
    @ViewBuilder
    private func travelRow(_ travel: TravelEvent) -> some View {
        VStack(spacing: 0) {
            if let connection = connectionsByNextId[travel.id] {
                TravelConnectionBanner(connection: connection)
            }
            Button { selectedTravel = travel } label: {
                TravelCardView(event: travel)
            }
            .buttonStyle(.plain)
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
        SSEmptyStateView(
            systemImage: "calendar.badge.checkmark",
            title: L10n.noRecentSchedule,
            subtitle: L10n.enjoyFreeTime,
            iconColor: SSColor.brand,
            cta: .init(label: L10n.calAddCalEvent) {
                showAddEvent = true
                HapticEngine.shared.lightImpact()
            }
        )
    }

    // MARK: - Request Access View

    private var requestAccessView: some View {
        VStack(spacing: ipScaled(24, sizeClass: hSizeClass)) {
            Spacer()
            Image(systemName: "calendar.circle.fill")
                .font(.system(size: ipScaled(64, sizeClass: hSizeClass)))
                .foregroundStyle(SSColor.brand)
            Text(L10n.connectCalendar)
                .font(.system(size: ipScaled(24, sizeClass: hSizeClass), weight: .bold))
            Text(L10n.calendarAccessDescription)
                .font(.system(size: ipScaled(15, sizeClass: hSizeClass), weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await manager.requestAccess() }
            } label: {
                Text(L10n.allowAccess)
                    .font(.system(size: ipScaled(17, sizeClass: hSizeClass), weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ipScaled(14, sizeClass: hSizeClass))
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                            .fill(SSColor.brand)
                    )
            }
            .padding(.horizontal, 40)
            Spacer()
        }
        .readableContentWidth(520)
    }

    // MARK: - Denied View

    private var deniedView: some View {
        VStack(spacing: ipScaled(24, sizeClass: hSizeClass)) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: ipScaled(64, sizeClass: hSizeClass)))
                .foregroundStyle(.orange)
            Text(L10n.calendarDenied)
                .font(.system(size: ipScaled(24, sizeClass: hSizeClass), weight: .bold))
            Text(L10n.openSettings)
                .font(.system(size: ipScaled(15, sizeClass: hSizeClass), weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(L10n.goToSettings)
                    .font(.system(size: ipScaled(17, sizeClass: hSizeClass), weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ipScaled(14, sizeClass: hSizeClass))
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                            .fill(.orange)
                    )
            }
            .padding(.horizontal, 40)
            Spacer()
        }
        .readableContentWidth(520)
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

/// Unified row type for the calendar feed — a row is either a calendar event
/// or a `TravelEvent`. Used so we can interleave trips with calendar items on
/// the same day and sort everything by time.
fileprivate enum DayItem: Identifiable {
    case calendar(EKEvent)
    case travel(TravelEvent)

    var id: String {
        switch self {
        case .calendar(let e): return "cal-\(e.eventIdentifier)"
        case .travel(let t):   return "trv-\(t.persistentModelID.hashValue)"
        }
    }

    var sortTime: Date {
        switch self {
        case .calendar(let e): return e.startDate
        case .travel(let t):   return t.departureInstant
        }
    }

    var isAllDay: Bool {
        if case .calendar(let e) = self { return e.isAllDay }
        return false
    }

    func isCompletedDeadline(_ completedIds: Set<String>) -> Bool {
        if case .calendar(let e) = self {
            return completedIds.contains(e.eventIdentifier)
        }
        return false
    }
}

#Preview {
    CalendarFeedView()
}
