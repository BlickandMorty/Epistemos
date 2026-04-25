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

    // MARK: - Entitlements drift tests (Phase S.2)
    //
    // Parse the two entitlements plists from source and assert key
    // invariants. Catches the regression where a Pro-only entitlement
    // gets added to the MAS plist (blocking App Review) or where the
    // MAS plist loses `app-sandbox` (making the MAS archive unshippable).
    //
    // Uses #filePath to resolve the source-tree path so the tests
    // work regardless of xcodebuild derived-data layout or CWD.

    /// Resolve the project root by walking up from this test file.
    /// This file lives at `<repo>/EpistemosTests/AppStoreHardeningTests.swift`,
    /// so two `deletingLastPathComponent()` calls give `<repo>`.
    ///
    /// Uses `#filePath` (absolute) rather than `#file` (which is now a
    /// compressed identifier in recent Swift and cannot be opened).
    private static var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func loadEntitlements(named name: String) throws -> [String: Any] {
        let url = Self.projectRoot
            .appendingPathComponent("Epistemos")
            .appendingPathComponent(name)
        let data = try Data(contentsOf: url)
        guard let dict = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw EntitlementsError.notADictionary(name)
        }
        return dict
    }

    enum EntitlementsError: Error {
        case notADictionary(String)
    }

    /// Keys that MUST be present in the MAS plist. Losing any of these
    /// means the MAS archive will be rejected or broken in production.
    private static let masRequiredKeys: [String] = [
        "com.apple.security.app-sandbox",
        "com.apple.security.network.client",
        "com.apple.security.files.user-selected.read-write",
        "com.apple.security.files.bookmarks.app-scope",
    ]

    /// Keys that MUST NOT appear in the MAS plist. Adding any of these
    /// will trigger App Store review rejection (or weaken the sandbox
    /// enough that review rejects it). If a future feature genuinely
    /// needs one of these, it belongs in the Pro-only deployment
    /// profile, not in the App Store build.
    private static let masForbiddenKeys: [String] = [
        "com.apple.security.cs.allow-unsigned-executable-memory",
        "com.apple.security.cs.disable-library-validation",
        "com.apple.security.automation.apple-events",
        "com.apple.security.temporary-exception.mach-lookup.global-name",
        "com.apple.security.files.all",
        // document-scope bookmarks are Pro-only per the deployment
        // profile split (see docs/PHASE_S_AUDIT.md section 2 and
        // existing ProductionHardeningTests). App-scope bookmarks are
        // what MAS uses instead.
        "com.apple.security.files.bookmarks.document-scope",
    ]

    @Test("MAS entitlements plist declares every required App Store key")
    func masEntitlementsDeclareRequiredKeys() throws {
        let plist = try loadEntitlements(named: "Epistemos-AppStore.entitlements")
        for key in Self.masRequiredKeys {
            let message: Comment = "MAS plist is missing required key '\(key)'. Without this, the App Store archive will be rejected or the app will fail at launch inside the sandbox."
            #expect(plist[key] != nil, message)
            if let value = plist[key] as? Bool {
                #expect(value, "MAS plist key '\(key)' must be true, found false")
            }
        }
    }

    @Test("MAS entitlements plist omits every Pro-only App Store blocker")
    func masEntitlementsOmitProOnlyKeys() throws {
        let plist = try loadEntitlements(named: "Epistemos-AppStore.entitlements")
        for key in Self.masForbiddenKeys {
            let message: Comment = "MAS plist contains forbidden key '\(key)'. This entitlement belongs in the Pro-only deployment profile; adding it to the MAS plist will trigger App Store review rejection. Move it to Epistemos.entitlements or remove the underlying feature from the MAS source set."
            #expect(plist[key] == nil, message)
        }
    }

    @Test("Pro entitlements plist still carries the Pro-only keys")
    func proEntitlementsStillCarryProOnlyKeys() throws {
        // Sanity check: if the Pro plist ever loses the Pro-only keys
        // the MAS test would start passing trivially. Assert the Pro
        // plist still declares the capabilities that justify having a
        // separate deployment profile at all. Note: Pro is not a true
        // superset of MAS, because MAS adds `com.apple.security.app-sandbox`
        // while Pro omits it; these are two different profiles, not a
        // subset / superset pair.
        let plist = try loadEntitlements(named: "Epistemos.entitlements")
        let proRequired = [
            "com.apple.security.cs.allow-unsigned-executable-memory",
            "com.apple.security.cs.disable-library-validation",
            "com.apple.security.automation.apple-events",
        ]
        for key in proRequired {
            let message: Comment = "Pro plist is missing '\(key)'. The Pro deployment profile exists to carry these; losing one means either Pro has narrowed in scope (update this test) or the plist drifted (fix the plist)."
            #expect(plist[key] != nil, message)
        }
    }
}
