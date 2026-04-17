import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper()

    private let service = "com.studysync.aikeys"

    private init() {}

    // MARK: - API Key Storage

    func saveAPIKey(_ apiKey: String, for accountId: UUID) {
        guard let data = apiKey.data(using: .utf8) else { return }
        let key = accountId.uuidString

        // Delete existing (both old device-only and new syncable)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new — use kSecAttrAccessibleAfterFirstUnlock to allow iCloud Keychain sync.
        // Previously used kSecAttrAccessibleWhenUnlockedThisDeviceOnly which blocked sync.
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    func getAPIKey(for accountId: UUID) -> String? {
        let key = accountId.uuidString

        // Try synced keychain first (new format)
        let syncQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        var status = SecItemCopyMatching(syncQuery as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }

        // Fallback: try legacy device-only keychain (pre-migration items)
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: false,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        result = nil
        status = SecItemCopyMatching(legacyQuery as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data,
           let apiKey = String(data: data, encoding: .utf8) {
            // Migrate to synced keychain
            saveAPIKey(apiKey, for: accountId)
            return apiKey
        }

        return nil
    }

    func deleteAPIKey(for accountId: UUID) {
        let key = accountId.uuidString
        // Delete both synced and legacy items
        for syncable in [true, false] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecAttrSynchronizable as String: syncable
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
