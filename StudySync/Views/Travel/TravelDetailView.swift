import SwiftUI
import SwiftData

struct TravelDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var event: TravelEvent

    @State private var isRefreshing = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TravelCardView(event: event)
                infoGrid
                reminderSection
                metadataSection
            }
            .padding(16)
        }
        .navigationTitle(event.fullNumber.isEmpty ? event.kind.label : event.fullNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if event.importSource.supportsStatusRefresh {
                        Button {
                            Task { await refresh() }
                        } label: {
                            Label(String(localized: "刷新状态"), systemImage: "arrow.clockwise")
                        }
                        .disabled(isRefreshing)
                    }
                    Button {
                        event.markedComplete.toggle()
                        try? modelContext.save()
                        TravelEventSyncService.shared.pushEvent(event)
                    } label: {
                        Label(
                            event.markedComplete ? String(localized: "取消完成") : String(localized: "标记完成"),
                            systemImage: event.markedComplete ? "arrow.uturn.backward" : "checkmark"
                        )
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(String(localized: "删除"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert(String(localized: "确认删除"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "删除"), role: .destructive) { delete() }
            Button(String(localized: "取消"), role: .cancel) {}
        } message: {
            Text(String(localized: "删除后无法恢复"))
        }
    }

    private var infoGrid: some View {
        VStack(spacing: 10) {
            infoRow(String(localized: "类型"), value: event.kind.label)
            if !event.serviceName.isEmpty {
                infoRow(String(localized: "运营方"), value: event.serviceName)
            }
            if !event.seat.isEmpty {
                infoRow(String(localized: "座位"), value: event.seat)
            }
            if !event.pnr.isEmpty {
                infoRow(String(localized: "订票号"), value: event.pnr)
            }
            if !event.passengerName.isEmpty {
                infoRow(String(localized: "乘客"), value: event.passengerName)
            }
            infoRow(String(localized: "时长"), value: event.durationLabel)
            if event.segments.count > 0 {
                infoRow(String(localized: "段数"), value: "\(event.segments.count)")
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "提醒"))
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Toggle("", isOn: $event.reminderEnabled)
                    .labelsHidden()
                    .onChange(of: event.reminderEnabled) { _, _ in
                        Task { await TravelReminderScheduler.shared.scheduleReminders(for: event) }
                        try? modelContext.save()
                        TravelEventSyncService.shared.pushEvent(event)
                    }
            }
            Picker(String(localized: "提醒方案"), selection: Binding(
                get: { event.reminderPreset },
                set: { newValue in
                    event.reminderPreset = newValue
                    Task { await TravelReminderScheduler.shared.scheduleReminders(for: event) }
                    try? modelContext.save()
                    TravelEventSyncService.shared.pushEvent(event)
                }
            )) {
                ForEach(TravelReminderPreset.allCases, id: \.self) { p in
                    Text(p.label).tag(p)
                }
            }
            .pickerStyle(.menu)
            .disabled(!event.reminderEnabled)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: event.importSource.symbolName)
                    .font(.system(size: 11))
                Text(String(localized: "来源：") + event.importSource.label)
            }
            if let refreshed = event.lastStatusRefreshedAt {
                Text(String(localized: "状态刷新于 \(refreshed.formatted(date: .abbreviated, time: .shortened))"))
            }
            if !event.note.isEmpty {
                Divider().padding(.vertical, 4)
                Text(event.note)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await TravelStatusRefresher.shared.refresh(event: event)
        try? modelContext.save()
        TravelEventSyncService.shared.pushEvent(event)
    }

    private func delete() {
        let eventId = event.id
        Task { await TravelReminderScheduler.shared.cancelReminders(for: eventId) }
        modelContext.delete(event)
        try? modelContext.save()
        TravelEventSyncService.shared.deleteEvent(id: eventId)
        dismiss()
    }
}
