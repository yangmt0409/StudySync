import Foundation

/// A drop-in wrapper that mirrors values between UserDefaults (local) and
/// NSUbiquitousKeyValueStore (iCloud KV sync).
///
/// - Write: saves to BOTH stores immediately.
/// - Read: prefers iCloud value if newer, otherwise local.
/// - On iCloud change notification: merges into UserDefaults.
///
/// Usage:  Replace `UserDefaults.standard.set(val, forKey:)` with
///         `SyncedDefaults.shared.set(val, forKey:)`.
final class SyncedDefaults {
    static let shared = SyncedDefaults()

    private let local = UserDefaults.standard
    private let cloud = NSUbiquitousKeyValueStore.default

    /// Keys that should sync to iCloud. Anything not listed stays local-only.
    private static let syncableKeys: Set<String> = [
        // Calendar display
        "calendarDayRange",
        "showFinishedCalEvents",
        "showAllDayCalEvents",
        "hiddenCalendarIDs",
        // Live Activity
        "liveActivityEnabled",
        "liveActivityLeadMinutes",
        "overdueTimeoutMinutes",
        // Urgency effects
        "lavaEffectEnabled",
        "globalBorderEnabled",
        "infectionEnabled",
        "urgencyWindowHours",
        // Tab layout
        "tabOrder",
        "tabMainCount",
    ]

    private init() {
        // Listen for iCloud KV changes and merge into local
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
        cloud.synchronize()

        // On first launch, seed iCloud from local (one-time migration)
        migrateLocalToCloudIfNeeded()
    }

    // MARK: - Write (dual-write)

    func set(_ value: Any?, forKey key: String) {
        local.set(value, forKey: key)
        if Self.syncableKeys.contains(key) {
            cloud.set(value, forKey: key)
        }
    }

    func set(_ value: Bool, forKey key: String) {
        local.set(value, forKey: key)
        if Self.syncableKeys.contains(key) {
            cloud.set(value, forKey: key)
        }
    }

    func set(_ value: Int, forKey key: String) {
        local.set(value, forKey: key)
        if Self.syncableKeys.contains(key) {
            cloud.set(value, forKey: key)
        }
    }

    func set(_ value: Double, forKey key: String) {
        local.set(value, forKey: key)
        if Self.syncableKeys.contains(key) {
            cloud.set(value, forKey: key)
        }
    }

    // MARK: - Read (prefer cloud if available)

    func bool(forKey key: String) -> Bool {
        if Self.syncableKeys.contains(key), cloud.object(forKey: key) != nil {
            return cloud.bool(forKey: key)
        }
        return local.bool(forKey: key)
    }

    func integer(forKey key: String) -> Int {
        if Self.syncableKeys.contains(key), cloud.object(forKey: key) != nil {
            return Int(cloud.longLong(forKey: key))
        }
        return local.integer(forKey: key)
    }

    func double(forKey key: String) -> Double {
        if Self.syncableKeys.contains(key), cloud.object(forKey: key) != nil {
            return cloud.double(forKey: key)
        }
        return local.double(forKey: key)
    }

    func object(forKey key: String) -> Any? {
        if Self.syncableKeys.contains(key), let val = cloud.object(forKey: key) {
            return val
        }
        return local.object(forKey: key)
    }

    func data(forKey key: String) -> Data? {
        if Self.syncableKeys.contains(key), let val = cloud.data(forKey: key) {
            return val
        }
        return local.data(forKey: key)
    }

    func stringArray(forKey key: String) -> [String]? {
        if Self.syncableKeys.contains(key), let val = cloud.array(forKey: key) as? [String] {
            return val
        }
        return local.stringArray(forKey: key)
    }

    func removeObject(forKey key: String) {
        local.removeObject(forKey: key)
        if Self.syncableKeys.contains(key) {
            cloud.removeObject(forKey: key)
        }
    }

    // MARK: - iCloud Change Handler

    @objc private func iCloudDidChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reason = info[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              let keys = info[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }

        // Only merge on server change or initial sync
        guard reason == NSUbiquitousKeyValueStoreServerChange ||
              reason == NSUbiquitousKeyValueStoreInitialSyncChange else { return }

        for key in keys where Self.syncableKeys.contains(key) {
            if let val = cloud.object(forKey: key) {
                local.set(val, forKey: key)
            }
        }

        // Post a notification so UI can refresh if needed
        NotificationCenter.default.post(name: .syncedDefaultsDidChange, object: nil, userInfo: ["keys": keys])
    }

    // MARK: - One-time Migration

    private func migrateLocalToCloudIfNeeded() {
        let migrationKey = "syncedDefaults_migrated_v1"
        guard !local.bool(forKey: migrationKey) else { return }

        for key in Self.syncableKeys {
            if let val = local.object(forKey: key), cloud.object(forKey: key) == nil {
                cloud.set(val, forKey: key)
            }
        }
        local.set(true, forKey: migrationKey)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let syncedDefaultsDidChange = Notification.Name("syncedDefaultsDidChange")
}
