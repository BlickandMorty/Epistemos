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

    // MARK: Fix 1 — a LOCAL pick must NEVER resolve to .cloud

    @MainActor
    @Test("a local pick never resolves to .cloud — even with a pending unavailable-cloud selection")
    func localPickNeverRoutesToCloud() throws {
        // No cloud access anywhere (Keychain returns nil); bootstrap skipped for determinism.
        let inference = InferenceState(
            keychainLoad: { _ in nil },
            skipCloudCredentialBootstrapOnLaunch: true
        )
        let qwen = LocalTextModelID.qwen3_4B4Bit.rawValue
        inference.setInstalledLocalTextModelIDs([qwen])
        inference.setPreferredLocalTextModelID(qwen)

        // Pick a cloud model with NO configured access → pins .localMLX + sets the pending
        // "reconnect to use X" badge state (the exact trigger of the live bug).
        let cloudModel = try #require(inference.cloudFallbackChain(for: .fast).first)
        inference.setPreferredChatModelSelection(.cloud(cloudModel))

        // EXECUTION must stay on the runnable local pin across every tier — the pending
        // selection is UI-only and must not override routing.
        for mode in [EpistemosOperatingMode.fast, .thinking, .pro, .agent] {
            let resolved = inference.effectiveChatSurfaceSelection(for: mode)
            if case .cloud = resolved {
                Issue.record("local pick routed to .cloud for \(mode) — the credentials-rejected bug")
            }
        }
    }

    @MainActor
    @Test("with no cloud access, auto-route never escalates a local surface to .cloud")
    func noCloudAccessNeverEscalatesToCloud() {
        let inference = InferenceState(
            keychainLoad: { _ in nil },
            skipCloudCredentialBootstrapOnLaunch: true
        )
        // A runnable local model is installed and pinned → cloud must never appear.
        let qwen = LocalTextModelID.qwen3_4B4Bit.rawValue
        inference.setInstalledLocalTextModelIDs([qwen])
        inference.setPreferredLocalTextModelID(qwen)
        for mode in [EpistemosOperatingMode.fast, .thinking, .pro, .agent] {
            if case .cloud = inference.effectiveChatSurfaceSelection(for: mode) {
                Issue.record("escalated to .cloud without configured cloud access for \(mode)")
            }
        }
    }

    // MARK: Fix 2 + Fix 3 — structural guards (defense-in-depth)

    @Test("auto-cloud escalation is gated on configured cloud access (Fix 2)")
    func autoCloudGatedOnConfiguredAccess() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        // Every cloud auto-escalation guard requires hasConfiguredCloudAccess(autoModel.provider).
        #expect(src.contains("hasConfiguredCloudAccess(for: autoModel.provider)"))
    }

    @Test("a foundation tier whose model isn't installed degrades to a runnable baseline (Fix 3)")
    func foundationTierDegradesToRunnableBaseline() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        // The not-installed-tier branch returns the installed Fast baseline, not nil.
        #expect(src.contains("return installedFoundationModelID(for: .fast)"))
    }

    @Test("apiKey gates the missing-set early-return on !isBootstrappingCloudCredentials (Fix 4)")
    func apiKeyGatesMissingSetOnBootstrap() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        #expect(src.contains("if !isBootstrappingCloudCredentials, missingCloudAPIKeyProviders.contains(provider)"))
    }
}
