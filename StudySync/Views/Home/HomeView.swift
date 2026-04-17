import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CountdownEvent.createdAt, order: .reverse) private var events: [CountdownEvent]
    @Bindable var viewModel: EventViewModel

    @State private var hasAppeared = false
    @State private var eventToDelete: CountdownEvent?
    @State private var showDeleteAlert = false

    private var deepLinkRouter: DeepLinkRouter { .shared }

    var body: some View {
        NavigationStack {
            List {
                // 分类过滤器
                Section {
                    categoryFilter
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                if groupedEvents.isEmpty {
                    Section {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } else {
                    ForEach(Array(groupedEvents.enumerated()), id: \.element.0) { sectionIndex, pair in
                        let (category, categoryEvents) = pair
                        Section {
                            if !viewModel.isSectionCollapsed(category) {
                                ForEach(Array(categoryEvents.enumerated()), id: \.element.id) { cardIndex, event in
                                    EventCardView(
                                        event: event,
                                        onTogglePin: {
                                            withAnimation(.spring(duration: 0.3)) {
                                                event.isPinned.toggle()
                                            }
                                            CountdownEventSyncService.shared.pushEvent(event)
                                            HapticManager.light()
                                        },
                                        onDelete: {
                                            // M1 fix: Route through confirmation dialog
                                            eventToDelete = event
                                            showDeleteAlert = true
                                            HapticManager.warning()
                                        }
                                    )
                                    .onTapGesture {
                                        viewModel.eventToEdit = event
                                        HapticEngine.shared.selection()
                                    }
                                    // #10 Context menu
                                    .contextMenu {
                                        Button {
                                            viewModel.eventToEdit = event
                                        } label: {
                                            Label(L10n.editEvent, systemImage: "pencil")
                                        }

                                        Button {
                                            withAnimation(.spring(duration: 0.3)) {
                                                event.isPinned.toggle()
                                            }
                                            HapticManager.light()
                                        } label: {
                                            Label(
                                                event.isPinned ? L10n.unpin : L10n.pin,
                                                systemImage: event.isPinned ? "pin.slash" : "pin.fill"
                                            )
                                        }

                                        Divider()

                                        Button(role: .destructive) {
                                            eventToDelete = event
                                            showDeleteAlert = true
                                            HapticManager.warning()
                                        } label: {
                                            Label(L10n.deleteEvent, systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            eventToDelete = event
                                            showDeleteAlert = true
                                            HapticManager.warning()
                                        } label: {
                                            Label(L10n.delete, systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            withAnimation(.spring(duration: 0.3)) {
                                                event.isPinned.toggle()
                                            }
                                            HapticManager.light()
                                        } label: {
                                            Label(
                                                event.isPinned ? L10n.unpin : L10n.pin,
                                                systemImage: event.isPinned ? "pin.slash" : "pin.fill"
                                            )
                                        }
                                        .tint(.orange)
                                    }
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .opacity(hasAppeared ? 1 : 0)
                                    .offset(y: hasAppeared ? 0 : 20)
                                    .animation(
                                        .spring(duration: 0.5).delay(Double(sectionIndex * 2 + cardIndex) * 0.06),
                                        value: hasAppeared
                                    )
                                }
                            }
                        } header: {
                            sectionHeader(category: category, count: categoryEvents.count)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(SSColor.backgroundPrimary)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 20, for: .scrollContent)
            .navigationTitle(L10n.tabCountdown)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.tryAddEvent(currentCount: events.count)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(SSColor.brand)
                    }
                }
            }
            .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: L10n.searchEvents)
            .sheet(isPresented: $viewModel.showingAddEvent) {
                AddEventView()
            }
            .sheet(isPresented: $viewModel.showingPaywall) {
                PaywallView()
            }
            .sheet(item: $viewModel.eventToEdit) { event in
                EventDetailView(event: event)
            }
            .onAppear {
                if events.isEmpty {
                    viewModel.addSampleEvents(context: modelContext)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    hasAppeared = true
                }
                consumePendingDeepLink()
            }
            .onChange(of: deepLinkRouter.pendingEventID) { _, _ in
                consumePendingDeepLink()
            }
            .onChange(of: deepLinkRouter.pendingAddEvent) { _, _ in
                consumePendingDeepLink()
            }
            .task {
                // Hydrate cloud state on first appearance — restores events,
                // settings, and deadline flags after reinstall / new device.
                await CountdownEventSyncService.shared.pullAll(context: modelContext)
                await UserSettingsSyncService.shared.pullSettings(context: modelContext)
                await DeadlineRecordSyncService.shared.pullAll(context: modelContext)
            }
            // #1 Delete confirmation alert
            .alert(L10n.confirmDeleteEvent, isPresented: $showDeleteAlert) {
                Button(L10n.delete, role: .destructive) {
                    if let event = eventToDelete {
                        NotificationManager.shared.removeNotifications(for: event.id)
                        let eventId = event.id
                        withAnimation(.spring(duration: 0.3)) {
                            modelContext.delete(event)
                        }
                        CountdownEventSyncService.shared.deleteEvent(id: eventId)
                        HapticManager.success()
                    }
                    eventToDelete = nil
                }
                Button(L10n.cancel, role: .cancel) {
                    eventToDelete = nil
                }
            } message: {
                Text(L10n.deleteEventWarning)
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: L10n.filterAll,
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    withAnimation(.spring(duration: 0.3)) { viewModel.selectedCategory = nil }
                }

                ForEach(EventCategory.allCases) { category in
                    FilterChip(
                        title: category.displayName,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        withAnimation(.spring(duration: 0.3)) {
                            viewModel.selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, SSSpacing.xxl)
            .padding(.vertical, SSSpacing.xs)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(category: EventCategory, count: Int) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                viewModel.toggleSection(category)
            }
            HapticEngine.shared.selection()
        } label: {
            HStack {
                Image(systemName: category.icon)
                    .font(SSFont.caption)
                    .foregroundStyle(Color(hex: category.defaultColorHex))

                Text(category.displayName)
                    .font(SSFont.chipLabel)
                    .foregroundStyle(.primary)

                Text("\(count)")
                    .font(SSFont.badge)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(SSColor.fillTertiary)
                    )

                Spacer()

                Image(systemName: "chevron.right")
                    .font(SSFont.footnote)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(viewModel.isSectionCollapsed(category) ? 0 : 90))
            }
        }
        .buttonStyle(.plain)
        .textCase(nil)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56))
                .foregroundStyle(.blue.opacity(0.4))

            VStack(spacing: 8) {
                Text(L10n.emptyTitle)
                    .font(SSFont.heading3)

                Text(L10n.emptySubtitle)
                    .font(SSFont.secondary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                viewModel.showingAddEvent = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(SSFont.chipLabel)
                    Text(L10n.addEvent)
                        .font(SSFont.bodySmallSemibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(.blue))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var groupedEvents: [(EventCategory, [CountdownEvent])] {
        viewModel.groupedEvents(events, showExpired: true)
    }

    /// Resolve any pending deep link targeting this tab. Runs on initial
    /// appear and whenever the router's pending values change.
    private func consumePendingDeepLink() {
        if let id = deepLinkRouter.consumeEventID(),
           let event = events.first(where: { $0.id == id }) {
            viewModel.eventToEdit = event
        }
        if deepLinkRouter.consumeAddEvent() {
            viewModel.tryAddEvent(currentCount: events.count)
        }
    }
}

// HapticManager shortcuts (delegate to HapticEngine.shared)
struct HapticManager {
    static func light() { HapticEngine.shared.lightImpact() }
    static func medium() { HapticEngine.shared.mediumImpact() }
    static func success() { HapticEngine.shared.success() }
    static func selection() { HapticEngine.shared.selection() }
    static func warning() { HapticEngine.shared.warning() }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SSFont.chipLabel)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, SSSpacing.xl)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : SSColor.fillTertiary)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(viewModel: EventViewModel())
        .modelContainer(for: CountdownEvent.self, inMemory: true)
}
