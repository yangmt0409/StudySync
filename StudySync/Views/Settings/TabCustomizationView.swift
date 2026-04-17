import SwiftUI

struct TabCustomizationView: View {
    @State private var movableTabs: [AppTab] = AppTab.allCases.filter { $0 != .schedule && !TabManager.pinnedTailTabs.contains($0) }
    @State private var mainCount: Int = TabManager.shared.mainTabCount
    @State private var showingResetAlert = false

    private let manager = TabManager.shared

    /// iOS tab bar shows max 5 icons; reserve 1 slot for our "More" tab → max 4 main tabs.
    /// If total tabs ≤ 5, all can fit without a More tab, so allow up to totalTabs.
    private var maxMainCount: Int {
        let total = movableTabs.count + 1   // +1 for locked schedule
        return total <= 5 ? total : 4
    }

    var body: some View {
        List {
            // Tab bar size control
            Section {
                Stepper(value: $mainCount, in: 2...maxMainCount) {
                    HStack {
                        Text(L10n.tabBarDisplayCount)
                        Spacer()
                        Text("\(mainCount)")
                            .font(.system(.body, design: .rounded).bold())
                            .foregroundStyle(SSColor.brand)
                    }
                }
                .onChange(of: mainCount) { _, _ in
                    saveOrder()
                    HapticEngine.shared.selection()
                }
            } footer: {
                Text(L10n.tabBarDisplayCountFooter)
            }

            // All tabs — single flat list
            Section {
                // Schedule always at position 0 (locked)
                tabRow(tab: .schedule, isMain: true, locked: true)

                ForEach(Array(movableTabs.enumerated()), id: \.element.id) { index, tab in
                    let isMain = (index + 1) < mainCount
                    tabRow(tab: tab, isMain: isMain, locked: false)
                }
                .onMove { source, destination in
                    movableTabs.move(fromOffsets: source, toOffset: destination)
                    saveOrder()
                    HapticEngine.shared.selection()
                }

                // Pinned tail tabs (locked at bottom, always in More)
                ForEach(TabManager.pinnedTailTabs) { tab in
                    tabRow(tab: tab, isMain: false, locked: true)
                }
            } header: {
                HStack {
                    Text(L10n.tabBarSection)
                    Spacer()
                    Text("\(mainCount)/\(movableTabs.count + 1)")
                        .font(SSFont.caption)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(L10n.tabCustomizeDragFooter)
            }

            // Reset button
            Section {
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(L10n.resetTabLayout)
                    }
                }
            }
        }
        .navigationTitle(L10n.tabCustomization)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
        .onAppear { loadTabs() }
        .alert(L10n.resetTabLayout, isPresented: $showingResetAlert) {
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.reset, role: .destructive) {
                manager.resetToDefault()
                loadTabs()
                HapticEngine.shared.success()
            }
        } message: {
            Text(L10n.resetTabLayoutConfirm)
        }
    }

    // MARK: - Tab Row

    private func tabRow(tab: AppTab, isMain: Bool, locked: Bool) -> some View {
        HStack(spacing: SSSpacing.lg) {
            Image(systemName: tab.systemImage)
                .font(SSFont.body)
                .foregroundStyle(isMain ? SSColor.brand : .secondary)
                .frame(width: 28)

            Text(tab.displayName)
                .font(SSFont.body)

            if locked {
                Image(systemName: "lock.fill")
                    .font(SSFont.micro)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !locked {
                Text(isMain ? L10n.tabBarSection : L10n.moreSection)
                    .font(SSFont.badge)
                    .foregroundStyle(isMain ? SSColor.brand : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (isMain ? SSColor.brand : Color(.systemGray4)).opacity(0.12),
                        in: Capsule()
                    )
            }
        }
        .moveDisabled(locked)
        .padding(.vertical, SSSpacing.xxs)
    }

    // MARK: - Data

    private func loadTabs() {
        let order = manager.tabOrder
        movableTabs = order.filter { $0 != .schedule && !TabManager.pinnedTailTabs.contains($0) }
        mainCount = min(max(2, manager.mainTabCount), maxMainCount)
    }

    private func saveOrder() {
        // Pinned-last tabs (.about) are appended automatically by the setter
        manager.tabOrder = [.schedule] + movableTabs
        manager.mainTabCount = mainCount
    }
}

#Preview {
    NavigationStack {
        TabCustomizationView()
    }
}
