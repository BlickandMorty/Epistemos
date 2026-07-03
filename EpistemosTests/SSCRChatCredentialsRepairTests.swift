import Testing
import Foundation

@testable import Epistemos

// SS-CR (owner 2026-06-20, #1 CRITICAL): "credentials rejected" on local + cloud chat.
// Two root causes, fixed in State/InferenceState.swift:
//   • a LOCAL pick mis-routed into the CLOUD branch (a pending unavailable-cloud selection
//     overrode EXECUTION routing) → every turn hit a credential-less cloud model;
//   • a cloud Keychain bootstrap RACE — apiKey(for:) trusted an all-"missing" SEED while the
//     real Keychain read was still async, rejecting a valid key on the first send.
// These are BEHAVIOR tests for the two primary bugs, plus structural guards for the two
// defense-in-depth changes (the auto-route cloud-access gate + the foundation-tier degrade).
@Suite("SS-CR chat credentials repair")
struct SSCRChatCredentialsRepairTests {

    // MARK: Fix 4 — cloud Keychain bootstrap race

    @MainActor
    @Test("apiKey reads the Keychain DURING bootstrap (kills the credential race)")
    func apiKeyDuringBootstrapReadsKeychain() throws {
        let provider = try #require(CloudModelProvider.allCases.first)
        let keychainKey = provider.apiKeyKeychainKey
        // skipCloudCredentialBootstrapOnLaunch leaves isBootstrappingCloudCredentials == true
        // and seeds EVERY provider as "missing" (the seed the old code wrongly trusted).
        let inference = InferenceState(
            keychainLoad: { $0 == keychainKey ? "sk-test-credential-123" : nil },
            skipCloudCredentialBootstrapOnLaunch: true
        )
        // The fix: while bootstrapping, ignore the seed and read the live Keychain — so a
        // VALID key is returned, not rejected as "credentials rejected".
        #expect(inference.apiKey(for: provider) == "sk-test-credential-123")
    }

    // Cloud-only migration: the two "a LOCAL pick must never resolve to .cloud" behavior
    // tests (Fix 1) were removed — they exercised deleted local-model machinery
    // (LocalTextModelID / setInstalledLocalTextModelIDs / setPreferredLocalTextModelID).

    // MARK: Fix 2 — structural cloud-access guard (defense-in-depth)

    @Test("auto-cloud escalation is gated on configured cloud access (Fix 2)")
    func autoCloudGatedOnConfiguredAccess() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        // Every cloud auto-escalation guard requires hasConfiguredCloudAccess(autoModel.provider).
        #expect(src.contains("hasConfiguredCloudAccess(for: autoModel.provider)"))
    }

    @Test("apiKey gates the missing-set early-return on !isBootstrappingCloudCredentials (Fix 4)")
    func apiKeyGatesMissingSetOnBootstrap() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        #expect(src.contains("if !isBootstrappingCloudCredentials, missingCloudAPIKeyProviders.contains(provider)"))
    }
}
