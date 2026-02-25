import Foundation
import os
import Security

// MARK: - Keychain Helper
// Thin wrapper around the Security framework for storing sensitive strings.
// Returns success/failure so callers can notify users of save failures.

enum Keychain {
    static let service = "app.epistemos"

    /// Saves a string securely. Returns true on success, false on failure.
    @discardableResult
    static func save(_ value: String, for key: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        // Try updating first
        let attrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)

        if updateStatus == errSecSuccess {
            return true
        } else if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
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
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess && status != errSecItemNotFound {
            Log.security.error("Keychain load failed for key '\(key, privacy: .public)': OSStatus \(status)")
        }
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Log.security.error("Keychain delete failed for key '\(key, privacy: .public)': OSStatus \(status)")
        }
    }
}
