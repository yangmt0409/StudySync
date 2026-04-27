import SwiftUI
import SwiftData
import PassKit

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var viewModel = EventViewModel()
    @State private var goalViewModel = StudyGoalViewModel()
    @State private var gradeCalcViewModel = GradeCalculatorViewModel()
    @State private var showBirthdayCelebration = false

    /// Feedback shown after a Wallet pass is imported via Document Type
    /// (Info.plist `CFBundleDocumentTypes`). Tapping a `.pkpass` from
    /// Mail / Files / a Wallet share routes here through `.onOpenURL`.
    @State private var walletImportMessage: String?

    /// One-shot iCloud sync prompt. Backed by `@AppStorage` so it persists
    /// across launches — every user sees this exactly once, including
    /// existing v1.0 users hit by the data-loss bug who really should
    /// know iCloud sync is an option.
    @AppStorage("hasShownICloudPrompt") private var hasShownICloudPrompt = false
    @State private var showICloudPrompt = false

    private var urgencyEngine: UrgencyEngine { .shared }
    private var tabManager: TabManager { .shared }
    private var notificationManager: InAppNotificationManager { .shared }
    private var deepLinkRouter: DeepLinkRouter { .shared }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Main tabs
            ForEach(Array(tabManager.mainTabs.enumerated()), id: \.element.id) { index, tab in
                tabView(for: tab)
                    .tabItem {
                        Label(tab.displayName, systemImage: tab.systemImage)
                    }
                    .tag(index)
                    .badge(badgeValue(for: tab))
            }

            // More tab (if there are overflow tabs)
            if !tabManager.moreTabs.isEmpty {
                MoreTabView(
                    moreTabs: tabManager.moreTabs,
                    viewModel: viewModel,
                    goalViewModel: goalViewModel,
                    gradeCalcViewModel: gradeCalcViewModel
                )
                .tabItem {
                    Label(L10n.more, systemImage: "ellipsis.circle.fill")
                }
                .tag(tabManager.mainTabs.count)
            }
        }
        .tint(SSColor.brand)
        .onChange(of: selectedTab) { _, _ in
            HapticEngine.shared.selection()
        }
        .overlay {
            AppUrgencyOverlay()
        }
        .onAppear {
            DeadlineBackgroundChecker.shared.performStartupCheck(modelContext: modelContext)
        }
        .task {
            // Small delay so splash screen finishes first
            try? await Task.sleep(for: .seconds(1.5))
            if let birthday = AuthService.shared.userProfile?.birthday,
               BirthdayChecker.isBirthdayToday(birthday),
               !BirthdayChecker.hasShownToday {
                showBirthdayCelebration = true
            }
            // iCloud onboarding — show once per user, deferred so it lands
            // after splash + birthday celebration. We don't show it
            // simultaneously with birthday (the birthday overlay is full-
            // screen and would conflict).
            if !hasShownICloudPrompt && !showBirthdayCelebration {
                try? await Task.sleep(for: .seconds(0.8))
                showICloudPrompt = true
            }
        }
        .sheet(isPresented: $showICloudPrompt) {
            iCloudPromptView()
                .interactiveDismissDisabled(false)
        }
        .overlay {
            if showBirthdayCelebration {
                BirthdayCelebrationView(
                    displayName: AuthService.shared.userProfile?.displayName ?? "",
                    onDismiss: {
                        BirthdayChecker.markShown()
                        showBirthdayCelebration = false
                    }
                )
                .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("switchToScheduleTab"))) { _ in
            // Find the index of schedule tab in main tabs
            if let idx = tabManager.mainTabs.firstIndex(of: .schedule) {
                selectedTab = idx
            }
        }
        .onOpenURL { url in
            // Apple Wallet pass: routed here via CFBundleDocumentTypes
            // registration in Info.plist. Path may be a file URL pointing
            // to a .pkpass blob copied into our sandbox by iOS.
            handleIncomingWalletPass(url: url)
        }
        .alert(
            String(localized: "导入行程"),
            isPresented: Binding(
                get: { walletImportMessage != nil },
                set: { if !$0 { walletImportMessage = nil } }
            )
        ) {
            Button("OK") { walletImportMessage = nil }
        } message: {
            Text(walletImportMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("switchToSocialTab"))) { _ in
            if let idx = tabManager.mainTabs.firstIndex(of: .social) {
                selectedTab = idx
            }
        }
        .onChange(of: deepLinkRouter.pendingDestination) { _, newValue in
            guard let dest = newValue else { return }
            if let idx = tabManager.mainTabs.firstIndex(of: dest.tab) {
                selectedTab = idx
            } else if tabManager.moreTabs.contains(dest.tab) {
                // In the "More" tab overflow — land there.
                selectedTab = tabManager.mainTabs.count
            }
            deepLinkRouter.pendingDestination = nil
        }
    }

    // MARK: - Tab View Builder

    @ViewBuilder
    private func tabView(for tab: AppTab) -> some View {
        switch tab {
        case .schedule:
            CalendarFeedView()
        case .todo:
            TodoListView()
        case .focus:
            FocusTimerView()
        case .countdown:
            HomeView(viewModel: viewModel)
        case .studyGoal:
            StudyGoalView(viewModel: goalViewModel)
        case .social:
            SocialHubView()
        case .tools:
            ToolsView()
        case .gradeCalc:
            GradeCalcView(viewModel: gradeCalcViewModel)
        case .aiMonitor:
            if AppTab.aiMonitor.isAvailableInCurrentStorefront {
                AIMonitorView()
            } else {
                EmptyView()
            }
        case .settings:
            SettingsView()
        case .about:
            NavigationStack {
                AboutView()
            }
        }
    }

    // MARK: - Badge

    private func badgeValue(for tab: AppTab) -> String? {
        if tab == .schedule && urgencyEngine.hasActiveDeadline && urgencyEngine.urgencyLevel > 0.3 {
            return "!"
        }
        if tab == .social && notificationManager.hasSocialBadge {
            return "\(notificationManager.socialBadgeCount)"
        }
        return nil
    }

    // MARK: - Wallet Pass Import

    /// Handle a `.pkpass` URL delivered via `.onOpenURL`. Source can be the
    /// iOS share sheet from Wallet, a `.pkpass` attachment in Mail, or a
    /// pass file the user dropped into Files.
    ///
    /// Why this lives here (not in WalletTravelImporter): `.onOpenURL` only
    /// fires inside the SwiftUI view hierarchy, and we need access to
    /// `modelContext` + `selectedTab` to insert + jump to the Schedule tab
    /// after a successful import. The actual pass parsing is delegated to
    /// `WalletTravelImporter.makeDraft()` (existing iPad logic, unchanged).
    private func handleIncomingWalletPass(url: URL) {
        // Make sure this is actually a Wallet pass — we registered the
        // .pkpass UTI but `onOpenURL` also fires for our `studysync://`
        // deep-link scheme (handled separately by DeepLinkRouter).
        guard url.isFileURL,
              url.pathExtension.lowercased() == "pkpass" else { return }

        // Security-scoped resource — required when the file lives outside
        // our sandbox (e.g. shared from Files). Releasing right after the
        // synchronous data read is fine; we re-encode the relevant bits
        // into a TravelEvent which lives entirely in our SwiftData store.
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            walletImportMessage = String(localized: "无法读取 Wallet 文件：") + error.localizedDescription
            return
        }

        let pass: PKPass
        do {
            pass = try PKPass(data: data)
        } catch {
            walletImportMessage = String(localized: "Wallet 文件解析失败：") + error.localizedDescription
            return
        }

        Task { @MainActor in
            do {
                let importer = WalletTravelImporter()
                let draft = try await importer.makeDraft(from: .init(pass: pass))
                modelContext.insert(draft)
                try? modelContext.save()
                TravelEventSyncService.shared.pushEvent(draft)
                await TravelReminderScheduler.shared.scheduleReminders(for: draft)

                // Jump to Schedule tab so the user immediately sees the
                // imported trip — beats a silent insert.
                if let idx = tabManager.mainTabs.firstIndex(of: .schedule) {
                    selectedTab = idx
                }

                walletImportMessage = String(localized: "已导入：") + draft.fullNumber
                HapticEngine.shared.success()
            } catch {
                walletImportMessage = String(localized: "Wallet 导入失败：") + error.localizedDescription
            }
        }
    }
}

// MARK: - More Tab View

struct MoreTabView: View {
    let moreTabs: [AppTab]
    @Bindable var viewModel: EventViewModel
    @Bindable var goalViewModel: StudyGoalViewModel
    @Bindable var gradeCalcViewModel: GradeCalculatorViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(moreTabs) { tab in
                    NavigationLink {
                        destinationView(for: tab)
                    } label: {
                        Label(tab.displayName, systemImage: tab.systemImage)
                            .font(SSFont.body)
                    }
                }
            }
            .navigationTitle(L10n.more)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func destinationView(for tab: AppTab) -> some View {
        switch tab {
        case .schedule:
            CalendarFeedView()
        case .todo:
            TodoListView()
        case .focus:
            FocusTimerView()
        case .countdown:
            HomeView(viewModel: viewModel)
        case .studyGoal:
            StudyGoalView(viewModel: goalViewModel)
        case .social:
            SocialHubView()
        case .tools:
            ToolsView()
        case .gradeCalc:
            GradeCalcView(viewModel: gradeCalcViewModel)
        case .aiMonitor:
            if AppTab.aiMonitor.isAvailableInCurrentStorefront {
                AIMonitorView()
            } else {
                EmptyView()
            }
        case .settings:
            SettingsView()
        case .about:
            AboutView()
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [CountdownEvent.self, UserSettings.self, DeadlineRecord.self, AIAccount.self, StudyGoal.self, CheckInRecord.self, TodoItem.self, FocusSession.self, GradeCourse.self, GradeComponent.self], inMemory: true)
}
