import Foundation
import SwiftData

struct SharedModelContainer {
    static let appGroupID = "group.com.studysync.shared"

    static func create() -> ModelContainer {
        let schema = Schema([CountdownEvent.self, UserSettings.self, DeadlineRecord.self])

        let config: ModelConfiguration

        if let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            let storeURL = appGroupURL.appendingPathComponent("StudySync.store")
            config = ModelConfiguration(
                "StudySync",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none  // Widget reads only, main app handles sync
            )
        } else {
            config = ModelConfiguration(
                "StudySync",
                schema: schema,
                cloudKitDatabase: .none
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Widget must not crash — fall back to in-memory store
            debugPrint("[Widget] ❌ ModelContainer failed: \(error). Using in-memory fallback.")
            let inMemory = ModelConfiguration("StudySync", schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [inMemory])
        }
    }
}
