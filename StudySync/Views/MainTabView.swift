import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var viewModel = EventViewModel()
    @State private var goalViewModel = StudyGoalViewModel()
    @State private var gradeCalcViewModel = GradeCalculatorViewModel()
    @State private var showBirthdayCelebration = false

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
            AIMonitorView()
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
            AIMonitorView()
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
