import SwiftUI
import EventKit
import MapKit
import Combine

struct AddCalendarEventView: View {
    @Environment(\.dismiss) private var dismiss
    var manager = CalendarManager.shared

    // Form fields
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var isAllDay = false
    @State private var selectedCalendar: EKCalendar?
    @State private var location = ""
    @State private var locationSearch = ""
    @State private var isSearchingLocation = false
    @StateObject private var locationCompleter = LocationCompleter()
    @State private var notes = ""
    @State private var alarmEntries: [AlarmEntry] = []
    @State private var recurrenceOption: RecurrenceOption = .none

    // UI state
    @State private var showError = false
    @State private var errorMessage = ""

    /// Optional pre-fill for editing
    var editingEvent: EKEvent?
    var onSaved: (() -> Void)?

    var isEditing: Bool { editingEvent != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Quick templates (only for new events)
                if !isEditing {
                    templateSection
                }

                // Title
                Section {
                    TextField(L10n.calEventTitle, text: $title)
                        .font(.body)
                }

                // Date & Time
                Section {
                    Toggle(L10n.calAllDayEvent, isOn: $isAllDay)

                    if isAllDay {
                        DatePicker(L10n.calStartTime, selection: $startDate, displayedComponents: .date)
                        DatePicker(L10n.calEndTime, selection: $endDate, displayedComponents: .date)
                    } else {
                        DatePicker(L10n.calStartTime, selection: $startDate)
                        DatePicker(L10n.calEndTime, selection: $endDate)
                    }
                }

                // Calendar picker
                Section(header: Text(L10n.calSaveToCalendar)) {
                    ForEach(manager.writableCalendars, id: \.calendarIdentifier) { cal in
                        Button {
                            selectedCalendar = cal
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(cgColor: cal.cgColor))
                                    .frame(width: 12, height: 12)

                                Text(cal.title)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if selectedCalendar?.calendarIdentifier == cal.calendarIdentifier {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                // Location
                Section(header: Text(L10n.calLocation)) {
                    if isSearchingLocation {
                        // Search mode
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField(L10n.calLocationSearch, text: $locationSearch)
                                .autocorrectionDisabled()
                                .onChange(of: locationSearch) { _, newValue in
                                    locationCompleter.search(query: newValue)
                                }
                            if !locationSearch.isEmpty {
                                Button {
                                    locationSearch = ""
                                    locationCompleter.results = []
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // #13 Timeout indicator
                        if locationCompleter.isTimedOut {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text(L10n.locationSearchTimeout)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Results
                        ForEach(locationCompleter.results, id: \.self) { result in
                            Button {
                                location = [result.title, result.subtitle]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: ", ")
                                locationSearch = ""
                                locationCompleter.results = []
                                isSearchingLocation = false
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } else {
                        // Display mode
                        HStack {
                            if location.isEmpty {
                                Button {
                                    isSearchingLocation = true
                                } label: {
                                    HStack {
                                        Image(systemName: "mappin.and.ellipse")
                                            .foregroundStyle(.secondary)
                                        Text(L10n.calLocationPlaceholder)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                HStack {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundStyle(.red)
                                    Text(location)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Button {
                                        isSearchingLocation = true
                                        locationSearch = location
                                        locationCompleter.search(query: location)
                                    } label: {
                                        Image(systemName: "pencil")
                                            .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    Button {
                                        location = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                // Notes
                Section(header: Text(L10n.noteSection)) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                // Alarm (up to 5)
                Section {
                    ForEach($alarmEntries) { $entry in
                        alarmEntryRow(entry: $entry)
                    }
                    .onDelete { offsets in
                        withAnimation { alarmEntries.remove(atOffsets: offsets) }
                    }

                    if alarmEntries.count < 5 {
                        Button {
                            withAnimation {
                                alarmEntries.append(AlarmEntry())
                            }
                            HapticEngine.shared.selection()
                        } label: {
                            Label(L10n.calAddReminder, systemImage: "plus.circle.fill")
                                .foregroundStyle(SSColor.brand)
                        }
                    }
                } header: {
                    Text(L10n.calReminder)
                } footer: {
                    if !alarmEntries.isEmpty {
                        Text(L10n.calReminderMax)
                    }
                }

                // Recurrence
                Section(header: Text(L10n.calRepeat)) {
                    Picker(L10n.calRepeat, selection: $recurrenceOption) {
                        ForEach(RecurrenceOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(isEditing ? L10n.calEditCalEvent : L10n.calAddCalEvent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) { saveEvent() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert(L10n.errorTitle, isPresented: $showError) {
                Button(L10n.done) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if selectedCalendar == nil {
                    selectedCalendar = manager.defaultCalendar
                }
                if let event = editingEvent {
                    prefillFromEvent(event)
                }
            }
        }
    }

    // MARK: - Template Section

    private var templateSection: some View {
        Section(header: Text(L10n.calQuickTemplates)) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    templateButton("📚", L10n.calTemplateCourse, recurrence: .weekly)
                    templateButton("📝", L10n.calTemplateExam, alarms: [.oneHourBefore])
                    templateButton("📋", L10n.calTemplateDeadline, alarms: [.oneDayBefore])
                    templateButton("🏢", L10n.calTemplateOfficeHours, recurrence: .weekly)
                    templateButton("👥", L10n.calTemplateGroupMeeting, alarms: [.fifteenMinutes])
                    templateButton("⚠️", L10n.dlDeadlineLabel, alarms: [.oneHourBefore])
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func templateButton(_ emoji: String, _ name: String, alarms: [AlarmOption] = [], recurrence: RecurrenceOption = .none) -> some View {
        Button {
            title = name
            alarmEntries = alarms.map { AlarmEntry(option: $0) }
            recurrenceOption = recurrence
            HapticEngine.shared.selection()
        } label: {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title2)
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Alarm Entry Row

    private func alarmEntryRow(entry: Binding<AlarmEntry>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)

                Picker("", selection: entry.option) {
                    ForEach(AlarmOption.selectableCases) { opt in
                        Text(opt.displayName).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            if entry.wrappedValue.option == .custom {
                customAlarmPicker(entry: entry)
                    .padding(.top, 4)
            }
        }
    }

    private func customAlarmPicker(entry: Binding<AlarmEntry>) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                Picker(L10n.calAlarmHourUnit, selection: entry.customHours) {
                    ForEach(0..<73) { h in
                        Text("\(h)").tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipped()

                Text(L10n.calAlarmHourUnit)
                    .font(SSFont.secondary)
                    .foregroundStyle(.secondary)
                    .frame(width: 36)

                Picker(L10n.calAlarmMinUnit, selection: entry.customMinutes) {
                    ForEach(0..<60) { m in
                        Text("\(m)").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipped()

                Text(L10n.calAlarmMinUnit)
                    .font(SSFont.secondary)
                    .foregroundStyle(.secondary)
                    .frame(width: 36)
            }

            let total = entry.wrappedValue.customHours * 60 + entry.wrappedValue.customMinutes
            if total > 0 {
                Text(entry.wrappedValue.customSummary)
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Save

    private func saveEvent() {
        guard let calendar = selectedCalendar else { return }

        let adjustedEnd = endDate <= startDate ? startDate.addingTimeInterval(3600) : endDate

        do {
            if let event = editingEvent {
                // Update existing
                event.title = title.trimmingCharacters(in: .whitespaces)
                event.startDate = startDate
                event.endDate = adjustedEnd
                event.calendar = calendar
                event.isAllDay = isAllDay
                event.location = location.isEmpty ? nil : location
                event.notes = notes.isEmpty ? nil : notes

                // Clear and re-add alarms (up to 5)
                if let alarms = event.alarms {
                    for alarm in alarms { event.removeAlarm(alarm) }
                }
                for entry in alarmEntries {
                    if let offset = entry.effectiveInterval {
                        event.addAlarm(EKAlarm(relativeOffset: -offset))
                    }
                }

                // Clear and re-add recurrence
                if let rules = event.recurrenceRules {
                    for rule in rules { event.removeRecurrenceRule(rule) }
                }
                if let rule = recurrenceOption.recurrenceRule {
                    event.addRecurrenceRule(rule)
                }

                try manager.updateEvent(event)
            } else {
                // Create new
                try manager.createEvent(
                    title: title.trimmingCharacters(in: .whitespaces),
                    startDate: startDate,
                    endDate: adjustedEnd,
                    calendar: calendar,
                    isAllDay: isAllDay,
                    location: location.isEmpty ? nil : location,
                    notes: notes.isEmpty ? nil : notes,
                    alarmOffsets: alarmEntries.compactMap(\.effectiveInterval),
                    recurrenceRule: recurrenceOption.recurrenceRule
                )
            }

            HapticEngine.shared.success()
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticEngine.shared.error()
        }
    }

    // MARK: - Prefill

    private func prefillFromEvent(_ event: EKEvent) {
        title = event.title ?? ""
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        selectedCalendar = event.calendar
        location = event.location ?? ""
        notes = event.notes ?? ""

        // Detect alarms (up to 5)
        if let alarms = event.alarms, !alarms.isEmpty {
            alarmEntries = alarms.prefix(5).map { alarm in
                let option = AlarmOption.from(offset: alarm.relativeOffset)
                var entry = AlarmEntry(option: option)
                if option == .custom {
                    let totalMinutes = Int(abs(alarm.relativeOffset) / 60)
                    entry.customHours = totalMinutes / 60
                    entry.customMinutes = totalMinutes % 60
                }
                return entry
            }
        }

        // Detect recurrence
        if let rule = event.recurrenceRules?.first {
            recurrenceOption = RecurrenceOption.from(rule: rule)
        }
    }
}

// MARK: - Alarm Entry (one row in the reminders list)

struct AlarmEntry: Identifiable {
    let id = UUID()
    var option: AlarmOption = .fifteenMinutes
    var customHours: Int = 0
    var customMinutes: Int = 10

    var effectiveInterval: TimeInterval? {
        if option == .custom {
            let total = TimeInterval((customHours * 60 + customMinutes) * 60)
            return total > 0 ? total : nil
        }
        return option.timeInterval
    }

    var customSummary: String {
        let h = customHours, m = customMinutes
        if h > 0 && m > 0 {
            return L10n.calAlarmCustomBefore + " \(h) " + L10n.calAlarmHourUnit + " \(m) " + L10n.calAlarmMinUnit
        } else if h > 0 {
            return L10n.calAlarmCustomBefore + " \(h) " + L10n.calAlarmHourUnit
        } else {
            return L10n.calAlarmCustomBefore + " \(m) " + L10n.calAlarmMinUnit
        }
    }
}

// MARK: - Alarm Options

enum AlarmOption: String, CaseIterable, Identifiable {
    case none, fiveMinutes, fifteenMinutes, thirtyMinutes, oneHourBefore, oneDayBefore, custom

    var id: String { rawValue }

    /// Cases shown in the per-entry picker (excludes `.none`).
    static var selectableCases: [AlarmOption] {
        allCases.filter { $0 != .none }
    }

    var displayName: String {
        switch self {
        case .none: return L10n.calAlarmNone
        case .fiveMinutes: return L10n.calAlarm5min
        case .fifteenMinutes: return L10n.calAlarm15min
        case .thirtyMinutes: return L10n.calAlarm30min
        case .oneHourBefore: return L10n.calAlarm1hour
        case .oneDayBefore: return L10n.calAlarm1day
        case .custom: return L10n.calAlarmCustom
        }
    }

    /// Time interval for preset options. Returns nil for `.none` and `.custom`.
    var timeInterval: TimeInterval? {
        switch self {
        case .none: return nil
        case .fiveMinutes: return 5 * 60
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHourBefore: return 60 * 60
        case .oneDayBefore: return 24 * 60 * 60
        case .custom: return nil
        }
    }

    /// Maps an EKAlarm offset back to a preset, or `.custom` if none match.
    static func from(offset: TimeInterval) -> AlarmOption {
        let absMinutes = Int(abs(offset) / 60)
        switch absMinutes {
        case 0..<8: return .fiveMinutes
        case 8..<23: return .fifteenMinutes
        case 23..<45: return .thirtyMinutes
        case 45..<90: return .oneHourBefore
        case 1320..<1560: return .oneDayBefore      // 22h – 26h tolerance
        default: return .custom
        }
    }
}

// MARK: - Recurrence Options

enum RecurrenceOption: String, CaseIterable, Identifiable {
    case none, daily, weekly, biweekly, monthly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return L10n.calRepeatNone
        case .daily: return L10n.calRepeatDaily
        case .weekly: return L10n.calRepeatWeekly
        case .biweekly: return L10n.calRepeatBiweekly
        case .monthly: return L10n.calRepeatMonthly
        }
    }

    var recurrenceRule: EKRecurrenceRule? {
        switch self {
        case .none: return nil
        case .daily:
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly:
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .biweekly:
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 2, end: nil)
        case .monthly:
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        }
    }

    static func from(rule: EKRecurrenceRule) -> RecurrenceOption {
        switch rule.frequency {
        case .daily: return .daily
        case .weekly: return rule.interval == 2 ? .biweekly : .weekly
        case .monthly: return .monthly
        default: return .none
        }
    }
}

// MARK: - Location Search Completer

final class LocationCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isTimedOut = false
    private let completer = MKLocalSearchCompleter()
    // #13 Search timeout
    private var timeoutTask: DispatchWorkItem?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(query: String) {
        guard !query.isEmpty else {
            results = []
            isTimedOut = false
            timeoutTask?.cancel()
            return
        }
        isTimedOut = false
        timeoutTask?.cancel()

        // #13 Set 8-second timeout
        let timeout = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                if self?.results.isEmpty == true {
                    self?.isTimedOut = true
                }
            }
        }
        timeoutTask = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)

        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.timeoutTask?.cancel()
            self.isTimedOut = false
            self.results = Array(completer.results.prefix(6))
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.timeoutTask?.cancel()
            self.isTimedOut = true
        }
    }
}
