import SwiftUI
import SwiftData

// MARK: - Quick Template

struct EventTemplate: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let category: EventCategory
    let colorHex: String
    let defaultDays: Int

    static let templates: [EventTemplate] = [
        EventTemplate(name: L10n.templateSemester, emoji: "🎓", category: .academic, colorHex: "#5B7FFF", defaultDays: 120),
        EventTemplate(name: L10n.templateReturn, emoji: "✈️", category: .travel, colorHex: "#4ECDC4", defaultDays: 90),
        EventTemplate(name: L10n.templateExam, emoji: "📝", category: .academic, colorHex: "#A78BFA", defaultDays: 30),
        EventTemplate(name: L10n.templateVisa, emoji: "📋", category: .visa, colorHex: "#FF6B6B", defaultDays: 180),
    ]
}

// MARK: - AddEventView

struct AddEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingEvent: CountdownEvent?

    @State private var title: String = ""
    @State private var emoji: String = "📌"
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date().addingTimeInterval(30*24*3600)
    @State private var category: EventCategory = .academic
    @State private var selectedColorHex: String = "#5B7FFF"
    @State private var isPinned: Bool = false
    @State private var notifyEnabled: Bool = true

    private let colorOptions: [String] = [
        "#5B7FFF", "#FF6B6B", "#4ECDC4", "#FFB347",
        "#A78BFA", "#F472B6", "#34D399", "#FBBF24",
        "#6366F1", "#EC4899",
    ]

    private let emojiOptions = [
        "📝", "📚", "📋", "✈️", "🏠", "💼", "🎓", "📄",
        "🗓️", "⏰", "🌟", "❤️", "📌", "🔔", "🎯", "💡",
        "🎉", "🏆", "🧳", "💻", "🎵", "🍜", "☕", "🌈",
    ]

    private var isEditing: Bool { editingEvent != nil }

    private static let titleMaxLength = 30

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && endDate >= startDate
    }

    var body: some View {
        NavigationStack {
            Form {
                templateSection
                emojiSection
                infoSection
                dateSection
                colorSection
                optionsSection
                previewSection
                deleteSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? L10n.editEvent : L10n.addEvent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        saveEvent()
                        dismiss()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let event = editingEvent {
                    title = event.title
                    emoji = event.emoji
                    startDate = event.startDate
                    endDate = event.endDate
                    category = event.category
                    selectedColorHex = event.colorHex
                    isPinned = event.isPinned
                    notifyEnabled = event.notifyEnabled
                }
            }
        }
    }

    // MARK: - Template Section

    @ViewBuilder
    private var templateSection: some View {
        if !isEditing {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(EventTemplate.templates) { template in
                            TemplateChip(template: template) {
                                applyTemplate(template)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text(L10n.quickAdd)
            } footer: {
                Text(L10n.quickAddFooter)
            }
        }
    }

    // MARK: - Emoji Section

    private var emojiSection: some View {
        Section(L10n.iconSection) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 10) {
                ForEach(emojiOptions, id: \.self) { option in
                    Text(option)
                        .font(.system(size: 26))
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(emoji == option ? Color.blue.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(emoji == option ? Color.blue : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture { emoji = option }
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section(L10n.eventInfo) {
            // #11 Title with character count & limit
            VStack(alignment: .trailing, spacing: 4) {
                TextField(L10n.eventName, text: $title)
                    .font(.system(size: 16))
                    .onChange(of: title) { _, newValue in
                        if newValue.count > Self.titleMaxLength {
                            title = String(newValue.prefix(Self.titleMaxLength))
                        }
                    }

                Text(L10n.eventTitleCount(title.count, Self.titleMaxLength))
                    .font(SSFont.footnote)
                    .foregroundStyle(title.count >= Self.titleMaxLength ? .red : .secondary)
            }

            Picker(L10n.category, selection: $category) {
                ForEach(EventCategory.allCases) { cat in
                    Label(cat.displayName, systemImage: cat.icon).tag(cat)
                }
            }
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        Section {
            DatePicker(L10n.startDate, selection: $startDate, displayedComponents: .date)
                .environment(\.locale, Locale.current)

            DatePicker(L10n.endDate, selection: $endDate, displayedComponents: .date)
                .environment(\.locale, Locale.current)

            if endDate < startDate {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 13))
                    Text(L10n.dateError)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text(L10n.date)
        } footer: {
            Text(datFooterText)
        }
    }

    private var datFooterText: String {
        if endDate >= startDate {
            let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            return L10n.totalDays(days)
        }
        return ""
    }

    // MARK: - Color Section

    private var colorSection: some View {
        Section(L10n.cardColor) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(colorOptions, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.3), lineWidth: selectedColorHex == hex ? 3 : 0)
                                .padding(3)
                        )
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .opacity(selectedColorHex == hex ? 1 : 0)
                        )
                        .scaleEffect(selectedColorHex == hex ? 1.1 : 1.0)
                        .animation(.spring(duration: 0.2), value: selectedColorHex)
                        .onTapGesture { selectedColorHex = hex }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        Section {
            Toggle(L10n.pinDisplay, isOn: $isPinned)
            Toggle(L10n.expiryReminder, isOn: $notifyEnabled)
        } header: {
            Text(L10n.options)
        } footer: {
            Text(notifyEnabled ? L10n.reminderFooter : "")
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Section(L10n.preview) {
            EventCardView(
                event: CountdownEvent(
                    title: title.isEmpty ? L10n.eventName : title,
                    emoji: emoji,
                    startDate: startDate,
                    endDate: endDate,
                    category: category,
                    colorHex: selectedColorHex,
                    isPinned: isPinned
                )
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
        }
    }

    // MARK: - Delete Section

    @ViewBuilder
    private var deleteSection: some View {
        if isEditing {
            Section {
                Button(role: .destructive) {
                    if let event = editingEvent {
                        // Remove scheduled notifications before deleting
                        NotificationManager.shared.removeNotifications(for: event.id)
                        let eventId = event.id
                        modelContext.delete(event)
                        CountdownEventSyncService.shared.deleteEvent(id: eventId)
                    }
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Label(L10n.deleteEvent, systemImage: "trash")
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func applyTemplate(_ template: EventTemplate) {
        withAnimation {
            title = template.name
            emoji = template.emoji
            category = template.category
            selectedColorHex = template.colorHex
            startDate = Date()
            endDate = Calendar.current.date(byAdding: .day, value: template.defaultDays, to: Date()) ?? Date()
        }
    }

    private func saveEvent() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty, endDate >= startDate else { return }

        if let event = editingEvent {
            event.title = trimmedTitle
            event.emoji = emoji
            event.startDate = startDate
            event.endDate = endDate
            event.category = category
            event.colorHex = selectedColorHex
            event.isPinned = isPinned
            event.notifyEnabled = notifyEnabled

            NotificationManager.shared.removeNotifications(for: event.id)
            if notifyEnabled {
                NotificationManager.shared.scheduleNotifications(for: event)
            }
            CountdownEventSyncService.shared.pushEvent(event)
        } else {
            let newEvent = CountdownEvent(
                title: trimmedTitle,
                emoji: emoji,
                startDate: startDate,
                endDate: endDate,
                category: category,
                colorHex: selectedColorHex,
                isPinned: isPinned,
                notifyEnabled: notifyEnabled
            )
            modelContext.insert(newEvent)
            CountdownEventSyncService.shared.pushEvent(newEvent)

            if notifyEnabled {
                Task {
                    let granted = await NotificationManager.shared.requestPermission()
                    if granted {
                        NotificationManager.shared.scheduleNotifications(for: newEvent)
                    }
                }
            }
        }

        HapticManager.success()
    }
}

// MARK: - Template Chip

struct TemplateChip: View {
    let template: EventTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(template.emoji)
                    .font(.system(size: 16))
                Text(template.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: template.colorHex).opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: template.colorHex).opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddEventView()
        .modelContainer(for: CountdownEvent.self, inMemory: true)
}
