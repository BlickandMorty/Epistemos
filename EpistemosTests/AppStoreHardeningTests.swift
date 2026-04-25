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

    // MARK: - Info.plist drift tests (Phase S.2)

    private func loadInfoPlist(named name: String) throws -> [String: Any] {
        let url = Self.projectRoot.appendingPathComponent(name)
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

    /// Usage-description keys the MAS Info.plist must keep non-empty.
    /// Each corresponds to a capability the app actually exercises; an
    /// empty or missing description is an automatic App Review hold.
    private static let masRequiredUsageDescriptionKeys: [String] = [
        "NSMicrophoneUsageDescription",
        "NSSpeechRecognitionUsageDescription",
        "NSDocumentsFolderUsageDescription",
        "NSDesktopFolderUsageDescription",
        "NSDownloadsFolderUsageDescription",
    ]

    @Test("MAS Info.plist answers the export-compliance question")
    func masInfoPlistDeclaresExportComplianceAnswer() throws {
        // `ITSAppUsesNonExemptEncryption` must be present in Info.plist
        // or App Store Connect asks the export-compliance questionnaire
        // on every submission. Setting it statically (true or false)
        // skips the questionnaire. Epistemos uses only standard
        // HTTPS/TLS so `false` is the correct answer; the test just
        // asserts the key is present so the drift that deletes it is
        // caught.
        let plist = try loadInfoPlist(named: "Epistemos-AppStore-Info.plist")
        let message: Comment = "MAS Info.plist is missing ITSAppUsesNonExemptEncryption. Without it App Store Connect will prompt the export-compliance questionnaire on every submission."
        #expect(plist["ITSAppUsesNonExemptEncryption"] != nil, message)
    }

    @Test("MAS Info.plist keeps required usage-description strings non-empty")
    func masInfoPlistKeepsUsageDescriptionsNonEmpty() throws {
        let plist = try loadInfoPlist(named: "Epistemos-AppStore-Info.plist")
        for key in Self.masRequiredUsageDescriptionKeys {
            let value = plist[key] as? String
            let missingMessage: Comment = "MAS Info.plist is missing '\(key)'. Without it, App Store review holds the submission pending a reason string."
            #expect(value != nil, missingMessage)
            let emptyMessage: Comment = "MAS Info.plist '\(key)' is empty. Must be a user-facing sentence; empty strings are an auto-reject."
            #expect(value?.isEmpty == false, emptyMessage)
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

    // MARK: - Per-file MAS-branch subprocess-launch regressions (Phase S.2)
    //
    // For files that MUST stay compiled into the MAS binary (i.e. the
    // ones that cannot be whole-file gated because they expose live
    // production API used by MAS-reachable callers), assert that the
    // MAS-visible portion does NOT contain `Process.init(`. The Pro
    // (non-MAS) branch is allowed to keep the subprocess fallback.

    /// Strip lines inside `#if !EPISTEMOS_APP_STORE ... #endif` blocks
    /// so the result reflects what the MAS compiler would see for the
    /// current branch.
    ///
    /// **Limitation -- simple-shape parser only.** This implementation
    /// tracks ONLY `#if !EPISTEMOS_APP_STORE` opens and matches them
    /// against the next `#endif`. It does NOT track other `#if`
    /// directives. That means: an unrelated `#if FOO` inside an excluded
    /// `#if !EPISTEMOS_APP_STORE` block will end on its own `#endif`
    /// rather than being treated as a nested level, and the next
    /// `#endif` would then incorrectly re-open the excluded section.
    /// This is fine for AudioTranscriber today, which uses the simple
    /// flat `#if !EPISTEMOS_APP_STORE ... #endif` shape with no nested
    /// `#if` directives. If a future file under this regression mixes
    /// nested `#if`s inside the gate, upgrade the parser to track
    /// generic `#if` depth before adding that file to the regression.
    /// Also does not interpret `#else` (no current call site needs it).
    private func masVisibleSource(_ source: String) -> String {
        var kept: [String] = []
        var inExcludedBlock = false
        for line in source.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#if !EPISTEMOS_APP_STORE") {
                inExcludedBlock = true
                continue
            }
            if inExcludedBlock {
                if trimmed.hasPrefix("#endif") {
                    inExcludedBlock = false
                }
                continue
            }
            kept.append(line)
        }
        return kept.joined(separator: "\n")
    }

    @Test("AudioTranscriber MAS branch contains no Process.init subprocess launch")
    func audioTranscriberMASBranchHasNoProcessInit() throws {
        let url = Self.projectRoot
            .appendingPathComponent("Epistemos")
            .appendingPathComponent("KnowledgeFusion")
            .appendingPathComponent("DataIngestion")
            .appendingPathComponent("AudioTranscriber.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        // Sanity: the Pro branch must still keep the subprocess fallback.
        // Removing all subprocess code from the file entirely is NOT the
        // goal -- direct/Pro releases need MLX Whisper and whisper.cpp.
        let proSanity: Comment = "AudioTranscriber.swift no longer contains any Process.init -- the Pro/direct release relies on the mlx-whisper / whisper.cpp fallbacks. If this is intentional, update or remove this test."
        #expect(source.contains("Process.init("), proSanity)

        // The actual regression: MAS-visible source must be subprocess-free.
        let masView = masVisibleSource(source)
        let masMessage: Comment = "AudioTranscriber.swift's MAS branch contains Process.init(. Either a new subprocess call landed outside `#if !EPISTEMOS_APP_STORE`, or an existing gate was removed. The MAS binary must keep Apple Speech only -- no Python, no whisper.cpp."
        #expect(!masView.contains("Process.init("), masMessage)

        // Also assert the gate marker is still there. If somebody removes
        // the `#if !EPISTEMOS_APP_STORE` gates entirely, masView would
        // equal source and the previous expect would catch it -- but a
        // direct check makes the failure mode obvious.
        let gateMessage: Comment = "AudioTranscriber.swift no longer contains `#if !EPISTEMOS_APP_STORE`. The Phase S.2 surgical gating was removed; restore it."
        #expect(source.contains("#if !EPISTEMOS_APP_STORE"), gateMessage)
    }

    /// Result of `scanForMarkerInGateBranches(source:marker:)`.
    private struct GateMarkerScan {
        /// True if `marker` was seen inside a `#if !EPISTEMOS_APP_STORE`
        /// block (i.e., compiled into Pro but not MAS).
        var insideExcludedBlock: Bool
        /// True if `marker` was seen outside any `#if !EPISTEMOS_APP_STORE`
        /// block (i.e., compiled into both MAS and Pro).
        var outsideExcludedBlock: Bool
    }

    /// Walk a Swift source string line by line, track `#if
    /// !EPISTEMOS_APP_STORE` open / `#else` / `#endif` boundaries (the
    /// shape used by surgical S.2 gates), and report whether `marker`
    /// substring was seen inside the excluded block, outside, or both.
    /// Comment-only lines (starting with `//`) are skipped.
    ///
    /// Limitation: this helper, like `masVisibleSource`, only tracks
    /// `#if !EPISTEMOS_APP_STORE` opens. Other `#if` directives (e.g.
    /// `#if DEBUG`) inside the gated region are not recognized. Today's
    /// VaultSyncService and VaultChatMutator surgical gates use the
    /// simple flat shape; if a future call site mixes nested `#if`s
    /// inside the gate, upgrade this helper before adding the file to
    /// the regression set.
    private func scanForMarkerInGateBranches(
        source: String,
        marker: String
    ) -> GateMarkerScan {
        var inExcludedBlock = false
        var insideExcludedBlock = false
        var outsideExcludedBlock = false
        for line in source.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#if !EPISTEMOS_APP_STORE") {
                inExcludedBlock = true
                continue
            }
            if inExcludedBlock {
                if trimmed.hasPrefix("#endif") || trimmed.hasPrefix("#else") {
                    // `#else` of `#if !EPISTEMOS_APP_STORE` opens the
                    // MAS-visible branch; treat it the same as `#endif`
                    // for the purpose of "are we still inside the
                    // excluded block".
                    inExcludedBlock = false
                    continue
                }
                if line.contains(marker) && !trimmed.hasPrefix("//") {
                    insideExcludedBlock = true
                }
            } else {
                if line.contains(marker) && !trimmed.hasPrefix("//") {
                    outsideExcludedBlock = true
                }
            }
        }
        return GateMarkerScan(
            insideExcludedBlock: insideExcludedBlock,
            outsideExcludedBlock: outsideExcludedBlock
        )
    }

    @Test("VaultSyncService MAS branch contains no tmutil Process.init")
    func vaultSyncServiceMASBranchHasNoTMUtilProcessInit() throws {
        let url = Self.projectRoot
            .appendingPathComponent("Epistemos")
            .appendingPathComponent("Sync")
            .appendingPathComponent("VaultSyncService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        // Sanity: the Pro branch must still keep the tmutil subprocess
        // implementation. Removing tmutil from the file entirely is not
        // the goal -- the Pro/direct release uses APFS safety snapshots
        // for recovery.
        let proSanity: Comment = "VaultSyncService.swift no longer contains Process.init -- the Pro/direct release relies on /usr/bin/tmutil for APFS safety snapshots. If this is intentional, update or remove this test."
        #expect(source.contains("Process.init("), proSanity)

        let scan = scanForMarkerInGateBranches(source: source, marker: "Process.init(")

        let outsideMessage: Comment = "VaultSyncService.swift contains a Process.init( call OUTSIDE a `#if !EPISTEMOS_APP_STORE` block. The MAS sandbox cannot spawn /usr/bin/tmutil; this leaks subprocess launch into the MAS binary."
        #expect(!scan.outsideExcludedBlock, outsideMessage)

        let insideMessage: Comment = "VaultSyncService.swift no longer has Process.init( inside any `#if !EPISTEMOS_APP_STORE` block, but the file does still contain Process.init(. The Pro branch may have been moved or deleted; restore the gating shape so MAS stays subprocess-free here."
        #expect(scan.insideExcludedBlock, insideMessage)
    }

    @Test("VaultChatMutator MAS branch contains no /usr/bin/git Process.init or git-launch arguments")
    func vaultChatMutatorMASBranchHasNoGitProcessInit() throws {
        let url = Self.projectRoot
            .appendingPathComponent("Epistemos")
            .appendingPathComponent("Vault")
            .appendingPathComponent("VaultChatMutator.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        // Sanity: the Pro branch must still keep the git subprocess
        // implementation. Removing git from the file entirely is not
        // the goal -- the Pro/direct release uses git to record an
        // audit trail of approved staged vault mutations.
        let proSanity: Comment = "VaultChatMutator.swift no longer contains Process.init -- the Pro/direct release relies on /usr/bin/git for the staged-mutation audit trail. If this is intentional, update or remove this test."
        #expect(source.contains("Process.init("), proSanity)

        // First marker: the literal Process.init( allocation. Catches a
        // direct subprocess-spawn primitive.
        let processScan = scanForMarkerInGateBranches(source: source, marker: "Process.init(")
        let processOutsideMessage: Comment = "VaultChatMutator.swift contains a Process.init( call OUTSIDE a `#if !EPISTEMOS_APP_STORE` block. The MAS sandbox cannot spawn /usr/bin/git; this leaks subprocess launch into the MAS binary. Approved staged mutations must still durable-write the file via VaultVerifiedFileWriter (already unconditional), but the git layer must stay Pro-only."
        #expect(!processScan.outsideExcludedBlock, processOutsideMessage)
        let processInsideMessage: Comment = "VaultChatMutator.swift no longer has Process.init( inside any `#if !EPISTEMOS_APP_STORE` block, but the file does still contain Process.init(. The Pro branch may have been moved or deleted; restore the gating shape so MAS stays subprocess-free here."
        #expect(processScan.insideExcludedBlock, processInsideMessage)

        // Second marker: the git-launch argument list. Catches the case
        // where someone keeps `Process.init` gated but moves the
        // git-specific configuration (`process.arguments = ["git"] + ...`)
        // outside the gate -- which would silently make MAS prepare a
        // git command even if it cannot run it. Both halves must agree
        // on the gate.
        let gitArgsScan = scanForMarkerInGateBranches(
            source: source,
            marker: "process.arguments = [\"git\"]"
        )
        let gitArgsOutsideMessage: Comment = "VaultChatMutator.swift contains `process.arguments = [\"git\"]` OUTSIDE a `#if !EPISTEMOS_APP_STORE` block. Even if Process.init( is gated, leaking the git-specific argv prep is a sign that the surgical gate has drifted."
        #expect(!gitArgsScan.outsideExcludedBlock, gitArgsOutsideMessage)
        let gitArgsInsideMessage: Comment = "VaultChatMutator.swift no longer has `process.arguments = [\"git\"]` inside a `#if !EPISTEMOS_APP_STORE` block, but the file still contains the substring elsewhere. The Pro git-launch shape may have been refactored away; restore it or update this test."
        #expect(gitArgsScan.insideExcludedBlock, gitArgsInsideMessage)
    }
}
