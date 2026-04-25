import Foundation
import Testing
@testable import Epistemos

// MARK: - Phase S.2 / S.4 -- App Store hardening regressions
//
// These tests live at the Swift FFI boundary, not in Rust. They
// guard against the silent drift where:
//   - Swift build flags say this is the App Store target, but the
//     linked Rust binary was compiled WITHOUT `mas-sandbox`, so
//     Pro-only tools leak into the registry.
//   - The opposite: Pro target links a sandboxed Rust binary and
//     loses capabilities it needs.
//
// AppBootstrap.verifyAgentCorePolicyProfile() already fatalError's
// at launch if the profile-vs-flag pair is inconsistent. These
// tests exercise the same invariant from Swift Testing so CI fails before
// a user-visible crash would.
//
// Plan refs:
//   docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md Phase S.2 + S.4
//   docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md section 1.7
//   docs/PHASE_S_AUDIT.md (companion audit report)

@Suite("Phase S -- App Store hardening")
struct AppStoreHardeningTests {

    /// Valid return values for `agentCorePolicyProfile()`.
    /// Keep this list in lockstep with `agent_core_policy_profile`
    /// in agent_core/src/bridge.rs:239.
    private static let validProfiles: Set<String> = ["direct", "mas_sandbox"]

    @Test("agentCorePolicyProfile returns a recognized value")
    func policyProfileReturnsRecognizedValue() {
        let profile = agentCorePolicyProfile()
        let message: Comment = "Unrecognized policy profile: '\(profile)'. Update validProfiles and bridge.rs together when adding a new profile."
        #expect(Self.validProfiles.contains(profile), message)
    }

    /// Test builds default to the Pro target (the `Epistemos` scheme).
    /// Under the default test build, the FFI must report `"direct"`.
    /// If this test fails, either:
    ///   (a) the test scheme has been changed to Epistemos-AppStore,
    ///       in which case update this test's expected value and the
    ///       EPISTEMOS_APP_STORE compilation-flag branch below; or
    ///   (b) the agent_core Rust lib was built with `--features
    ///       mas-sandbox` but linked into the non-MAS Swift target,
    ///       which is the drift case this test exists to catch.
    @Test("policy profile matches the compiled Swift build flag")
    func policyProfileMatchesBuildFlag() {
        let profile = agentCorePolicyProfile()
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        let masMessage: Comment = "App Store build flag is set but linked agent_core is '\(profile)'. This is the exact condition AppBootstrap.verifyAgentCorePolicyProfile fatals on at launch; CI should fail here first."
        #expect(profile == "mas_sandbox", masMessage)
        #else
        let directMessage: Comment = "Pro (non-App Store) build flag but linked agent_core is '\(profile)'. Either the Rust lib was built with --features mas-sandbox and linked into the Pro target, or a new build variant was added without updating this test."
        #expect(profile == "direct", directMessage)
        #endif
    }
}
