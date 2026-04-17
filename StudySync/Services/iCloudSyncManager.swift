import Foundation
import Security

/// Manages iCloud sync preference.
/// Changing the sync setting requires an app restart to rebuild the ModelContainer.
///
/// The preference is stored in Keychain so it **survives app reinstalls**.
/// Previously used UserDefaults, which gets wiped on reinstall — causing
/// CloudKit to be disabled on first launch and all local data to appear lost.
final class iCloudSyncManager {
    static let shared = iCloudSyncManager()

    // Legacy UserDefaults key (kept for migration)
    private let udKey = "iCloudSyncEnabled"
    private let defaults = UserDefaults.standard

    // Keychain storage (survives reinstalls)
    private let keychainService = "com.studysync.preferences"
    private let keychainAccount = "iCloudSyncEnabled"

    /// Whether iCloud sync is enabled. Changes take effect after app restart.
    var isEnabled: Bool {
        get {
            // 1. Keychain (survives reinstall) — primary source
            if let keychainValue = readKeychain() {
                return keychainValue
            }

            // 2. Migrate from UserDefaults (legacy, pre-fix installs)
            if defaults.object(forKey: udKey) != nil {
                let udValue = defaults.bool(forKey: udKey)
                writeKeychain(udValue)
                return udValue
            }

            // 3. Never set — default to false
            return false
        }
        set {
            defaults.set(newValue, forKey: udKey)
            writeKeychain(newValue)
        }
    }

    private init() {}

    // MARK: - Keychain Read/Write

    private func readKeychain() -> Bool? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str == "1"
    }

    private func writeKeychain(_ value: Bool) {
        let data = (value ? "1" : "0").data(using: .utf8)!

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new (device-local, survives reinstall)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
