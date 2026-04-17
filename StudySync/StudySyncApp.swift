import SwiftUI
import SwiftData
import BackgroundTasks
import FirebaseCore

@main
struct StudySyncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer

    init() {
        FirebaseApp.configure()
        AuthService.shared.listenAuthState()

        let schema = Schema([CountdownEvent.self, UserSettings.self, DeadlineRecord.self, AIAccount.self, StudyGoal.self, CheckInRecord.self, TodoItem.self, FocusSession.self, GradeCourse.self, GradeComponent.self])
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

        do {
            let config = makeConfig(cloudKit: iCloudEnabled)
            self.container = try ModelContainer(for: schema, configurations: [config])
            if iCloudEnabled {
                debugPrint("[iCloud] ✅ Sync enabled — CloudKit container active")
            }
        } catch {
            debugPrint("[iCloud] ❌ Container failed: \(error)")
            if iCloudEnabled {
                // CloudKit failed — fall back to local for this session only
                // (user preference stays ON so it retries next launch)
                do {
                    let fallback = makeConfig(cloudKit: false)
                    self.container = try ModelContainer(for: schema, configurations: [fallback])
                    debugPrint("[iCloud] ⚠️ Using local store this session")
                } catch {
                    debugPrint("[Fatal] ❌ iCloud fallback also failed: \(error). Using in-memory store.")
                    let inMemory = ModelConfiguration("StudySync", schema: schema, isStoredInMemoryOnly: true)
                    self.container = try! ModelContainer(for: schema, configurations: [inMemory])
                }
            } else {
                // Last resort — in-memory store so the app doesn't crash
                debugPrint("[Fatal] ❌ Local store also failed: \(error). Using in-memory fallback.")
                let inMemory = ModelConfiguration("StudySync", schema: schema, isStoredInMemoryOnly: true)
                self.container = try! ModelContainer(for: schema, configurations: [inMemory])
            }
        }

        DeadlineBackgroundChecker.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            LaunchScreenView()
                .onOpenURL { url in
                    DeepLinkRouter.shared.handle(url: url)
                }
        }
        .modelContainer(container)
    }
}
