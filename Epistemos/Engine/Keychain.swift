import Foundation
import os
import Security

// MARK: - Keychain Helper
// Thin wrapper around the Security framework for storing sensitive strings.
// Prefers the Data Protection keychain when available, but falls back to the
// standard login keychain when the current build/runtime lacks the entitlement
// required for kSecUseDataProtectionKeychain.

enum Keychain {
    nonisolated static let service = "app.epistemos"

    private enum Backend: CaseIterable {
        case dataProtection
        case legacy
    }

    /// Base query attributes shared by all operations.
    private nonisolated static func baseQuery(for key: String, backend: Backend) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String:                    kSecClassGenericPassword,
            kSecAttrService as String:              service,
            kSecAttrAccount as String:              key,
        ]
        switch backend {
        case .dataProtection:
            query[kSecUseDataProtectionKeychain as String] = true
        case .legacy:
            break
        }
        return query
    }

    nonisolated static func shouldFallbackToLegacyKeychain(after status: OSStatus) -> Bool {
        status == errSecMissingEntitlement
    }

    nonisolated static func backendLabelsForTesting() -> [String] {
        Backend.allCases.map { backend in
            switch backend {
            case .dataProtection:
                "dataProtection"
            case .legacy:
                "legacy"
            }
        }
    }

    private nonisolated static func save(_ value: String, for key: String, backend: Backend) -> OSStatus {
        let data = Data(value.utf8)
        let query = baseQuery(for: key, backend: backend)

        let attrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)

        if updateStatus == errSecSuccess {
            return errSecSuccess
        }
        if updateStatus != errSecItemNotFound {
            return updateStatus
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Saves a string securely. Returns true on success, false on failure.
    @discardableResult
    nonisolated static func save(_ value: String, for key: String) -> Bool {
        for backend in Backend.allCases {
            let status = save(value, for: key, backend: backend)
            if status == errSecSuccess {
                return true
            }
            if shouldFallbackToLegacyKeychain(after: status) {
                continue
            }

            Log.security.error("Keychain save failed for key '\(key, privacy: .public)': OSStatus \(status)")
            return false
        }

        Log.security.error("Keychain save failed for key '\(key, privacy: .public)': missing entitlement for Data Protection keychain; legacy fallback unavailable")
        return false
    }

    nonisolated static func load(for key: String) -> String? {
        for backend in Backend.allCases {
            var query = baseQuery(for: key, backend: backend)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecSuccess, let data = result as? Data {
                return String(data: data, encoding: .utf8)
            }
            if status == errSecItemNotFound || shouldFallbackToLegacyKeychain(after: status) {
                continue
            }

            Log.security.error("Keychain load failed for key '\(key, privacy: .public)': OSStatus \(status)")
            return nil
        }
        return nil
    }

    nonisolated static func delete(for key: String) {
        for backend in Backend.allCases {
            let query = baseQuery(for: key, backend: backend)
            let status = SecItemDelete(query as CFDictionary)
            if status != errSecSuccess &&
                status != errSecItemNotFound &&
                !shouldFallbackToLegacyKeychain(after: status) {
                Log.security.error("Keychain delete failed for key '\(key, privacy: .public)': OSStatus \(status)")
            }
        }
    }

    /// Migrates items from the legacy keychain to the Data Protection keychain.
    /// Call once on app launch. Reads from legacy, writes to DP, deletes legacy.
    nonisolated static func migrateFromLegacyKeychain(keys: [String]) {
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
            if load(for: key, backend: .dataProtection) != nil { continue }

            // Save to Data Protection keychain
            if save(value, for: key, backend: .dataProtection) == errSecSuccess {
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

    private nonisolated static func load(for key: String, backend: Backend) -> String? {
        var query = baseQuery(for: key, backend: backend)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
