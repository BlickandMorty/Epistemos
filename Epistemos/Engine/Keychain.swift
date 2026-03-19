import Foundation
import os
import Security

// MARK: - Keychain Helper
// Thin wrapper around the Security framework for storing sensitive strings.
// Uses the Data Protection keychain (kSecUseDataProtectionKeychain) to avoid
// legacy keychain ACL dialogs that prompt for the user's login password on
// every app launch during development.

enum Keychain {
    static let service = "app.epistemos"

    /// Base query attributes shared by all operations.
    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String:                    kSecClassGenericPassword,
            kSecAttrService as String:              service,
            kSecAttrAccount as String:              key,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    /// Saves a string securely. Returns true on success, false on failure.
    @discardableResult
    static func save(_ value: String, for key: String) -> Bool {
        let data = Data(value.utf8)
        let query = baseQuery(for: key)

        // Try updating first
        let attrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)

        if updateStatus == errSecSuccess {
            return true
        } else if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                Log.security.error("Keychain add failed for key '\(key, privacy: .public)': OSStatus \(addStatus)")
                return false
            }
            return true
        } else {
            Log.security.error("Keychain update failed for key '\(key, privacy: .public)': OSStatus \(updateStatus)")
            return false
        }
    }

    static func load(for key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess && status != errSecItemNotFound {
            Log.security.error("Keychain load failed for key '\(key, privacy: .public)': OSStatus \(status)")
        }
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(for key: String) {
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess &&
            status != errSecItemNotFound &&
            status != errSecMissingEntitlement {
            Log.security.error("Keychain delete failed for key '\(key, privacy: .public)': OSStatus \(status)")
        }
    }

    /// Migrates items from the legacy keychain to the Data Protection keychain.
    /// Call once on app launch. Reads from legacy, writes to DP, deletes legacy.
    static func migrateFromLegacyKeychain(keys: [String]) {
        for key in keys {
            // Try loading from legacy keychain (no kSecUseDataProtectionKeychain)
            let legacyQuery: [String: Any] = [
                kSecClass as String:            kSecClassGenericPassword,
                kSecAttrService as String:      service,
                kSecAttrAccount as String:      key,
                kSecReturnData as String:       true,
                kSecMatchLimit as String:       kSecMatchLimitOne,
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(legacyQuery as CFDictionary, &result)
            guard status == errSecSuccess, let data = result as? Data,
                  let value = String(data: data, encoding: .utf8), !value.isEmpty else {
                continue
            }

            // Check if already in Data Protection keychain
            if load(for: key) != nil { continue }

            // Save to Data Protection keychain
            if save(value, for: key) {
                // Delete from legacy keychain
                let deleteQuery: [String: Any] = [
                    kSecClass as String:       kSecClassGenericPassword,
                    kSecAttrService as String:  service,
                    kSecAttrAccount as String:  key,
                ]
                SecItemDelete(deleteQuery as CFDictionary)
                Log.security.info("Migrated keychain item '\(key, privacy: .public)' to Data Protection keychain")
            }
        }
    }
}
