import SwiftUI
import SwiftData
import BackgroundTasks
import FirebaseCore

@main
struct StudySyncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    let container: ModelContainer

    init() {
        FirebaseApp.configure()
        AuthService.shared.listenAuthState()

        // iPad: enlarge the navigation large-title and inline-title font.
        // SwiftUI's `.navigationTitle()` defaults to 34pt regardless of
        // device — fine on iPhone but visually small on iPad's 1024-1366pt
        // canvas. UINavigationBarAppearance is the only way to change the
        // large-title font app-wide. iPhone keeps the system default.
        if UIDevice.current.userInterfaceIdiom == .pad {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.largeTitleTextAttributes = [
                .font: UIFont.systemFont(ofSize: 44, weight: .bold)
            ]
            appearance.titleTextAttributes = [
                .font: UIFont.systemFont(ofSize: 22, weight: .semibold)
            ]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
        }

        let schema = Schema([CountdownEvent.self, UserSettings.self, DeadlineRecord.self, AIAccount.self, AIUsageSnapshot.self, StudyGoal.self, CheckInRecord.self, TodoItem.self, FocusSession.self, GradeCourse.self, GradeComponent.self, StudySpaceItem.self, TravelEvent.self])
        let iCloudEnabled = iCloudSyncManager.shared.isEnabled

        // Clear any stale launch guard from previous versions
        UserDefaults.standard.removeObject(forKey: "iCloudLaunchGuard")

        let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedModelContainer.appGroupID
        )

        func makeConfig(cloudKit: Bool) -> ModelConfiguration {
            if let appGroupURL = appGroupURL {
                let storeURL = appGroupURL.appendingPathComponent("StudySync.store")
                return ModelConfiguration("StudySync", schema: schema, url: storeURL,
                                          cloudKitDatabase: cloudKit ? .automatic : .none)
            } else {
                return ModelConfiguration("StudySync", schema: schema,
                                          cloudKitDatabase: cloudKit ? .automatic : .none)
            }
        }

        // ──────────────────────────────────────────────────────────────
        // Container init policy (post-v1.0 data-loss incident)
        //
        // OLD behavior was: on any failure, silently fall back to an
        // in-memory store via `try!`. That avoided crashing but made the
        // failure invisible — the user added new todos into the
        // in-memory store and they evaporated on next launch. From the
        // user's POV "all my data is gone".
        //
        // NEW behavior: try persistent → on iCloud-config failure, retry
        // local-only (preserves data when CloudKit is the only thing
        // broken). If local-only ALSO fails, we deliberately do NOT use
        // an in-memory store — that just hides the problem and corrupts
        // the user's mental model of what's saved. We retry once, then
        // crash with a diagnostic so iOS auto-restarts and the user gets
        // a fresh attempt instead of silently losing writes.
        // ──────────────────────────────────────────────────────────────
        do {
            let config = makeConfig(cloudKit: iCloudEnabled)
            self.container = try ModelContainer(for: schema, configurations: [config])
            if iCloudEnabled {
                debugPrint("[iCloud] ✅ Sync enabled — CloudKit container active")
            }
        } catch {
            debugPrint("[iCloud] ❌ Container failed: \(error)")
            // Try local-only as a recoverable retry. CloudKit metadata
            // hiccups are common and don't mean the local store is broken.
            if iCloudEnabled, let recovered = Self.tryLocalFallback(schema: schema, makeConfig: makeConfig) {
                self.container = recovered
                debugPrint("[iCloud] ⚠️ Using local-only store this session")
            } else {
                // Both paths failed. Wait briefly and retry once — most
                // SwiftData failures we've seen in production are
                // transient lock contention from a crashed prior session.
                Thread.sleep(forTimeInterval: 0.5)
                if let retry = Self.tryLocalFallback(schema: schema, makeConfig: makeConfig) {
                    self.container = retry
                    debugPrint("[Recovered] ⚠️ Container loaded on retry")
                } else {
                    // Crash cleanly. Better than silent data loss — iOS
                    // will auto-restart, the user keeps the data on disk,
                    // and the next launch has a fresh chance.
                    fatalError(
                        "Failed to open SwiftData store after retry: \(error)\n"
                        + "Data on disk is intact — relaunching the app gives "
                        + "the persistent store another chance to load."
                    )
                }
            }
        }

        // Register the container as the single process-wide instance.
        // Background tasks and App Intents will fetch it from here instead
        // of constructing their own — see AppContainer.swift for the full
        // explanation of the v1.0 corruption bug this prevents.
        AppContainer.shared.register(self.container)

        DeadlineBackgroundChecker.shared.registerBackgroundTask()

        // Activate the phone→watch WCSession now — activation is async, so
        // touching the singleton lazily at first background-sync would find
        // isPaired/isWatchAppInstalled still unset and silently skip that
        // first sync. Early activation also lets the watch's own "sync"
        // request (didReceiveMessage) reach us at any point in the session.
        _ = PhoneToWatchSync.shared
    }

    /// Attempt to open a local-only (no CloudKit) ModelContainer. Returns
    /// nil if it fails — caller decides whether to retry, fatal, etc.
    private static func tryLocalFallback(
        schema: Schema,
        makeConfig: (Bool) -> ModelConfiguration
    ) -> ModelContainer? {
        do {
            return try ModelContainer(for: schema, configurations: [makeConfig(false)])
        } catch {
            debugPrint("[Recovery] local-only fallback failed: \(error)")
            return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            LaunchScreenView()
                .onOpenURL { url in
                    DeepLinkRouter.shared.handle(url: url)
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            // Widgets are only visible once the app is backgrounded, so this
            // single hook refreshes them after any CountdownEvent change the
            // user made this session — without instrumenting every write site.
            if newPhase == .background {
                WidgetReloader.reloadAll()
                // Push the latest countdown events to the paired Apple Watch.
                // updateApplicationContext delivers even while the watch app
                // is closed, so backgrounding is the one hook that captures
                // every edit made this session. (The watch also pulls on its
                // own launch via a WCSession "sync" message.)
                PhoneToWatchSync.shared.syncEvents(from: ModelContext(container))
            }
        }
    }
}
