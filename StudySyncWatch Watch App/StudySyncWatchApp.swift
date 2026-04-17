import SwiftUI

@main
struct StudySyncWatchApp: App {
    @State private var syncManager = WatchSyncManager.shared

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(syncManager)
        }
    }
}
