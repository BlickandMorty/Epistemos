import Foundation
import os
import Security

// MARK: - CredentialPool
// Multi-key credential management with least-used load distribution.
// Inspired by Hermes Agent's credential pool rotation system.
//
// Supports multiple API keys per provider. When a key hits rate limits or fails,
// it's deprioritized and the next least-used key is selected.
//
// Keys are stored in macOS Keychain (never UserDefaults — per CLAUDE.md).
// Pool entries track usage count, last use time, and failure count.

actor CredentialPool {
    nonisolated private static let log = Logger(subsystem: "com.epistemos", category: "CredentialPool")

    struct PoolEntry: Sendable {
        let key: String
        var useCount: Int = 0
        var lastUsed: Date = .distantPast
        var failCount: Int = 0

        /// Score for least-used selection. Lower = preferred.
        /// Failed keys get heavy penalty. Otherwise, prefer least-recently-used.
        var selectionScore: Double {
            let failPenalty = Double(failCount) * 100.0
            let usePenalty = Double(useCount)
            let recencyPenalty = Date().timeIntervalSince(lastUsed) < 60 ? 10.0 : 0.0
            return failPenalty + usePenalty + recencyPenalty
        }
    }

    /// provider name → array of pool entries
    private var pools: [String: [PoolEntry]] = [:]

    /// Add a key to a provider's pool.
    func addKey(provider: String, key: String) {
        guard !key.isEmpty else { return }
        var pool = pools[provider] ?? []

        // Don't add duplicates
        guard !pool.contains(where: { $0.key == key }) else { return }

        pool.append(PoolEntry(key: key))
        pools[provider] = pool
        Self.log.info("CredentialPool: added key for \(provider) (pool size: \(pool.count))")
    }

    /// Get the best available key for a provider (least-used selection).
    func getKey(provider: String) -> String? {
        guard let pool = pools[provider], !pool.isEmpty else { return nil }
        return pool.min(by: { $0.selectionScore < $1.selectionScore })?.key
    }

    /// Mark a key as successfully used.
    func markUsed(provider: String, key: String) {
        guard var pool = pools[provider] else { return }
        if let idx = pool.firstIndex(where: { $0.key == key }) {
            pool[idx].useCount += 1
            pool[idx].lastUsed = Date()
            pools[provider] = pool
        }
    }

    /// Mark a key as failed (rate limited, auth error, etc.). Deprioritizes it.
    func markFailed(provider: String, key: String) {
        guard var pool = pools[provider] else { return }
        if let idx = pool.firstIndex(where: { $0.key == key }) {
            pool[idx].failCount += 1
            pools[provider] = pool
            Self.log.warning("CredentialPool: key for \(provider) failed (\(pool[idx].failCount) failures)")
        }
    }

    /// Reset failure count for a key (e.g., after rate limit window passes).
    func resetFailures(provider: String, key: String) {
        guard var pool = pools[provider] else { return }
        if let idx = pool.firstIndex(where: { $0.key == key }) {
            pool[idx].failCount = 0
            pools[provider] = pool
        }
    }

    /// Number of keys available for a provider.
    func keyCount(provider: String) -> Int {
        pools[provider]?.count ?? 0
    }

    /// Remove a specific key from the pool.
    func removeKey(provider: String, key: String) {
        pools[provider]?.removeAll { $0.key == key }
    }

    /// Load all keys from Keychain for known providers.
    func loadFromKeychain(providers: [String] = ["anthropic", "openai", "perplexity", "google"]) {
        for provider in providers {
            // Try loading indexed keys: provider-0, provider-1, etc.
            for i in 0..<5 {
                let account = i == 0 ? provider : "\(provider)-\(i)"
                if let key = keychainRead(service: "com.epistemos.apikeys", account: account) {
                    addKey(provider: provider, key: key)
                }
            }
        }
    }

    // MARK: - Keychain Helpers

    private func keychainRead(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else {
            return nil
        }
        return key
    }
}
