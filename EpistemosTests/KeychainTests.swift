import Security
import Testing
@testable import Epistemos

@Suite("Keychain", .serialized)
struct KeychainTests {
    @Test("falls back to legacy keychain when Data Protection is unavailable")
    func fallsBackToLegacyKeychainWhenDataProtectionIsUnavailable() {
        #expect(Keychain.shouldFallbackToLegacyKeychain(after: errSecMissingEntitlement))
        #expect(!Keychain.shouldFallbackToLegacyKeychain(after: errSecItemNotFound))
        #expect(Keychain.backendLabelsForTesting() == ["dataProtection", "legacy"])
    }

    @Test("save load and delete round-trip succeeds for app keys")
    func saveLoadAndDeleteRoundTripSucceedsForAppKeys() {
        let key = "epistemos.tests.keychain.\(UUID().uuidString)"
        let value = "sk-test-\(UUID().uuidString)"

        defer { Keychain.delete(for: key) }

        #expect(Keychain.save(value, for: key))
        #expect(Keychain.load(for: key) == value)

        Keychain.delete(for: key)
        #expect(Keychain.load(for: key) == nil)
    }
}
