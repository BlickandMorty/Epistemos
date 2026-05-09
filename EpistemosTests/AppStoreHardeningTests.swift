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
    // Reads from the test bundle's `SourceMirror/` (populated by the
    // EpistemosTests "Bundle Test Source Mirror" preBuildScript) rather
    // than `#filePath`. The mirror lives in DerivedData; using `#filePath`
    // pointed at `~/Downloads/Epistemos`, which can hang on macOS TCC
    // protected-folder prompts under xcodebuild test.

    private func loadEntitlements(named name: String) throws -> [String: Any] {
        let url = try sourceMirrorURL(for: "Epistemos/\(name)")
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
        let url = try sourceMirrorURL(for: name)
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

    // MARK: - PrivacyInfo.xcprivacy drift tests (Phase S.6)
    //
    // The PrivacyInfo.xcprivacy manifest declares the App Privacy posture
    // App Store review reads alongside the App Store Connect "App Privacy"
    // questionnaire. The audit doc PHASE_S_AUDIT.md section 3 (Privacy manifest) documents the
    // baseline these tests guard:
    //   NSPrivacyTracking          = false
    //   NSPrivacyTrackingDomains   = []
    //   NSPrivacyCollectedDataTypes = []
    //   NSPrivacyAccessedAPITypes  = 4 required-reason categories
    //
    // The Settings -> Privacy transparency pane added in slice S.6 shows
    // these manifest-backed fields to the user. If the manifest drifts (e.g.,
    // someone adds a tracking SDK and pushes NSPrivacyTracking to true,
    // or adds a data collection category) without updating the user-
    // facing pane in lockstep, App Review's stated posture and the
    // shipping app's stated posture would disagree. These tests catch
    // the drift before review does.

    private func loadPrivacyManifest() throws -> [String: Any] {
        let url = try sourceMirrorURL(for: "Epistemos/Resources/PrivacyInfo.xcprivacy")
        let data = try Data(contentsOf: url)
        guard let dict = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw EntitlementsError.notADictionary("PrivacyInfo.xcprivacy")
        }
        return dict
    }

    @Test("PrivacyInfo.xcprivacy declares NSPrivacyTracking == false and no tracking domains")
    func privacyManifestDeclaresNoTracking() throws {
        let manifest = try loadPrivacyManifest()
        let trackingMessage: Comment = "PrivacyInfo.xcprivacy NSPrivacyTracking must be false. Flipping this to true is an App Store posture change that requires updating both the Settings -> Privacy pane and the App Store Connect App Privacy questionnaire in lockstep."
        #expect((manifest["NSPrivacyTracking"] as? Bool) == false, trackingMessage)

        let domains = manifest["NSPrivacyTrackingDomains"] as? [Any] ?? []
        let domainsMessage: Comment = "PrivacyInfo.xcprivacy NSPrivacyTrackingDomains must be empty. A non-empty array signals at least one domain doing user tracking and contradicts the user-facing claim that the app has no trackers."
        #expect(domains.isEmpty, domainsMessage)
    }

    @Test("PrivacyInfo.xcprivacy declares no NSPrivacyCollectedDataTypes")
    func privacyManifestCollectsNoData() throws {
        let manifest = try loadPrivacyManifest()
        let collected = manifest["NSPrivacyCollectedDataTypes"] as? [Any] ?? []
        let message: Comment = "PrivacyInfo.xcprivacy NSPrivacyCollectedDataTypes must be empty. Adding a collected-data category is a substantive privacy posture change that needs an explicit user-facing disclosure (Settings -> Privacy pane), an App Store Connect questionnaire update, and a privacy policy URL update."
        #expect(collected.isEmpty, message)
    }

    @Test("PrivacyInfo.xcprivacy declares the four expected NSPrivacyAccessedAPITypes with their reason codes")
    func privacyManifestDeclaresFourAccessedAPITypesWithReasons() throws {
        let manifest = try loadPrivacyManifest()
        let accessedAPITypes = manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        var observed: [String: [String]] = [:]
        for entry in accessedAPITypes {
            guard let category = entry["NSPrivacyAccessedAPIType"] as? String else { continue }
            let reasons = entry["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
            observed[category] = reasons
        }

        // The four required-reason API categories the audit doc section 3 records,
        // each with the exact Apple reason code we ship today. Adding a
        // fifth category requires updating PHASE_S_AUDIT.md section 3, this test,
        // and the user-facing Privacy pane together.
        let expected: [(category: String, reason: String)] = [
            ("NSPrivacyAccessedAPICategoryFileTimestamp", "C617.1"),
            ("NSPrivacyAccessedAPICategorySystemBootTime", "35F9.1"),
            ("NSPrivacyAccessedAPICategoryDiskSpace", "E174.1"),
            ("NSPrivacyAccessedAPICategoryUserDefaults", "CA92.1"),
        ]

        let countMessage: Comment = "PrivacyInfo.xcprivacy NSPrivacyAccessedAPITypes must have exactly \(expected.count) entries. Found \(accessedAPITypes.count). Add or remove a required-reason API together with PHASE_S_AUDIT.md section 3 and the Privacy pane."
        #expect(accessedAPITypes.count == expected.count, countMessage)

        for (category, reason) in expected {
            let categoryMessage: Comment = "PrivacyInfo.xcprivacy is missing required-reason API category '\(category)'. The audit baseline declares it; restore the entry or update PHASE_S_AUDIT.md section 3."
            #expect(observed[category] != nil, categoryMessage)
            let reasonMessage: Comment = "PrivacyInfo.xcprivacy category '\(category)' must list reason '\(reason)' (single-element array). Found \(observed[category] ?? [])."
            #expect(observed[category] == [reason], reasonMessage)
        }
    }

    // MARK: - App Store release-gate script regressions (Drop 12/13)

    @Test("App Review audit fails MAS subprocess findings instead of warning")
    func appReviewAuditFailsMASSubprocessFindingsInsteadOfWarning() throws {
        let source = try loadMirroredSourceTextFile("Tools/app-review-audit/app-review-audit.sh")

        #expect(
            !source.contains("::warning::W26 stage-0 informational"),
            "App Review audit still reports MAS subprocess findings as warnings. MAS-reachable subprocess/PTY/shell findings must fail the release gate."
        )
        #expect(
            !source.contains("stage-0 audit does not fail"),
            "App Review audit still documents subprocess findings as non-fatal stage-0 findings."
        )
        #expect(
            source.contains("::error::W26") && source.contains("MAS-reachable subprocess surface"),
            "App Review audit must emit an error when MAS-reachable subprocess patterns are found."
        )
        #expect(
            source.contains("target=${1:-appstore}") || source.contains("target=\"${1:-appstore}\""),
            "App Review audit should make the audited target explicit, defaulting to appstore."
        )
    }

    @Test("App Store artifact scan inspects final bundle strings symbols executables and resources")
    func appStoreArtifactScanInspectsFinalBundleStringsSymbolsExecutablesAndResources() throws {
        let source = try loadMirroredSourceTextFile("scripts/scan_appstore_bundle.sh")
        let requiredFragments = [
            "find \"$APP\" -type f",
            "strings",
            "nm -gU",
            "otool -L",
            "-perm",
            "pty|osascript|cli_passthrough|bash_execute|Command::new|fork|exec|docker|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|/usr/bin/python|launchctl",
            "MOHAWK|MoLoRA|raw Helios|research packets|Hermes|omega_ax|omega-mcp|pty",
        ]

        for fragment in requiredFragments {
            #expect(
                source.contains(fragment),
                "scripts/scan_appstore_bundle.sh is missing required artifact-scan fragment: \(fragment)"
            )
        }
        #expect(
            source.contains("FORBIDDEN_SYMBOL_PATTERN"),
            "scripts/scan_appstore_bundle.sh must scan fork/exec as Mach-O symbol/linkage evidence, not only as raw strings."
        )
        #expect(
            !source.contains("FORBIDDEN_STRING_PATTERN='(^|[^A-Za-z0-9_])(pty|osascript|cli_passthrough|bash_execute|Command::new|fork|exec|docker|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|/usr/bin/python|launchctl)"),
            "scripts/scan_appstore_bundle.sh should not fail raw string scans on generic exec/fork text such as SQL exec logs; fork/exec belong in the symbol/linkage gate."
        )
        #expect(
            source.contains("(^|[^A-Za-z0-9_.])docker"),
            "scripts/scan_appstore_bundle.sh should flag Docker command/runtime evidence without treating benign ignored-path text like `.docker/` as a subprocess surface."
        )
    }

    @Test("App Store scheme has tests or CI runs a dedicated MAS artifact gate")
    func appStoreSchemeHasTestsOrCIRunsDedicatedMASArtifactGate() throws {
        let scheme = try loadMirroredSourceTextFile(
            "Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-AppStore.xcscheme"
        )
        let ci = try loadMirroredSourceTextFile(".github/workflows/ci.yml")

        let testablesRange = scheme.range(of: "<Testables>")?.upperBound
        let testablesEnd = scheme.range(of: "</Testables>")?.lowerBound
        let testablesBody: Substring
        if let testablesRange, let testablesEnd, testablesRange <= testablesEnd {
            testablesBody = scheme[testablesRange..<testablesEnd]
        } else {
            testablesBody = ""
        }

        let schemeHasTestables = testablesBody.contains("<TestableReference")
        let ciRunsMASGate = ci.contains("Epistemos-AppStore")
            && ci.contains("Tools/app-review-audit/app-review-audit.sh")
            && ci.contains("scripts/scan_appstore_bundle.sh")

        #expect(
            schemeHasTestables || ciRunsMASGate,
            "Epistemos-AppStore.xcscheme has no Testables and CI does not run a dedicated MAS artifact gate."
        )
    }

    @Test("App Store agent command modes do not advertise Pro subprocess tools")
    func appStoreAgentCommandModesHideProSubprocessTools() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/State/AgentCommandCenterState.swift")
        let toolAllowlistSection = Self.sourceSection(
            in: source,
            startingAt: "var preferredToolNames: Set<String>",
            endingBefore: "var expertAllowlist: [String]"
        )
        #expect(
            toolAllowlistSection != nil,
            "AgentCommandCenterState.swift must keep preferredToolNames distinct enough for MAS tool-advertising source guards."
        )
        let guardedSource = toolAllowlistSection ?? source
        let proOnlyToolNames = [
            "bash_execute",
            "run_command",
            "terminal",
            "process",
            "execute_code",
        ]

        for caseMarker in ["case .debug:", "case .code:"] {
            let caseBody = Self.switchCaseBody(in: guardedSource, startingAt: caseMarker)
            #expect(
                caseBody != nil,
                "AgentCommandCenterState.swift is missing \(caseMarker); update this MAS source guard with the new command-mode layout."
            )
            guard let caseBody else { continue }

            #expect(
                caseBody.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX"),
                "\(caseMarker) must gate Pro-only subprocess/tool names out of the MAS binary."
            )
            guard
                let gateRange = caseBody.range(of: "#if EPISTEMOS_APP_STORE || MAS_SANDBOX"),
                let elseRange = caseBody.range(of: "#else", range: gateRange.upperBound..<caseBody.endIndex),
                let endifRange = caseBody.range(of: "#endif", range: elseRange.upperBound..<caseBody.endIndex)
            else {
                Issue.record("\(caseMarker) must use an explicit MAS branch and Pro branch around tool allowlists.")
                continue
            }

            let masBranch = String(caseBody[gateRange.upperBound..<elseRange.lowerBound])
            let proBranch = String(caseBody[elseRange.upperBound..<endifRange.lowerBound])
            for toolName in proOnlyToolNames {
                #expect(
                    !masBranch.contains(toolName),
                    "\(caseMarker) MAS branch must not embed Pro-only tool name \(toolName)."
                )
            }
            #expect(
                proBranch.contains("bash_execute"),
                "\(caseMarker) Pro branch should keep the direct-build tool path; this guard is meant to gate MAS, not delete Pro capability."
            )
        }
    }

    private static func switchCaseBody(in source: String, startingAt marker: String) -> String? {
        guard let markerRange = source.range(of: marker) else { return nil }
        let searchRange = markerRange.upperBound..<source.endIndex
        let nextCase = source.range(of: "\n        case .", range: searchRange)?.lowerBound ?? source.endIndex
        return String(source[markerRange.lowerBound..<nextCase])
    }

    private static func sourceSection(
        in source: String,
        startingAt startMarker: String,
        endingBefore endMarker: String
    ) -> String? {
        guard let startRange = source.range(of: startMarker) else { return nil }
        let searchRange = startRange.upperBound..<source.endIndex
        let endIndex = source.range(of: endMarker, range: searchRange)?.lowerBound ?? source.endIndex
        return String(source[startRange.lowerBound..<endIndex])
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
        let url = try sourceMirrorURL(
            for: "Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift"
        )
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
        let url = try sourceMirrorURL(for: "Epistemos/Sync/VaultSyncService.swift")
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
        let url = try sourceMirrorURL(for: "Epistemos/Vault/VaultChatMutator.swift")
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

        // Second marker: the git executable selection. Catches the case
        // where someone keeps `Process.init` gated but moves the
        // git-specific executable configuration outside the gate --
        // which would silently make MAS prepare a git command even if
        // it cannot run it. Both halves must agree on the gate.
        let gitExecutableScan = scanForMarkerInGateBranches(
            source: source,
            marker: "process.executableURL = URL(fileURLWithPath: \"/usr/bin/git\")"
        )
        let gitExecutableOutsideMessage: Comment = "VaultChatMutator.swift contains `/usr/bin/git` executable setup OUTSIDE a `#if !EPISTEMOS_APP_STORE` block. Even if Process.init( is gated, leaking the git-specific executable prep is a sign that the surgical gate has drifted."
        #expect(!gitExecutableScan.outsideExcludedBlock, gitExecutableOutsideMessage)
        let gitExecutableInsideMessage: Comment = "VaultChatMutator.swift no longer has `/usr/bin/git` executable setup inside a `#if !EPISTEMOS_APP_STORE` block, but the file still contains Process.init(. The Pro git-launch shape may have been refactored away; restore it or update this test."
        #expect(gitExecutableScan.insideExcludedBlock, gitExecutableInsideMessage)
    }

    // MARK: - KnowledgeFusion subprocess-marker regressions (Phase S.2)
    //
    // The five files below all live inside KnowledgeFusion/. The KF
    // settings entry is already UI-gated out of MAS in
    // `Views/Settings/SettingsView.swift` (`#if !(EPISTEMOS_APP_STORE
    // || MAS_SANDBOX)` around `sections.append(.knowledgeFusion)` and
    // around `case .knowledgeFusion: KnowledgeFusionDetailView()`),
    // and AppBootstrap's three calls into `KnowledgeFusionViewModel
    // .shared` are wrapped in `#if !EPISTEMOS_APP_STORE`. So the
    // training/inference/export pipeline is already unreachable in
    // MAS at the UI and bootstrap layers. The surgical gates below
    // make that honest at the binary layer too: every Process.init,
    // every executable URL setup, and every launch argv assignment
    // inside the five files lives inside `#if !EPISTEMOS_APP_STORE`.

    /// Convenience: scan `source` for each marker and assert that
    /// the marker appears ONLY inside `#if !EPISTEMOS_APP_STORE`
    /// blocks. Each marker also gets a "still present somewhere"
    /// sanity check so a future change that rips out the Pro path
    /// entirely is flagged.
    private func assertMarkerIsMASGated(
        source: String,
        fileLabel: String,
        marker: String
    ) {
        let scan = scanForMarkerInGateBranches(source: source, marker: marker)
        let outsideMessage: Comment = "\(fileLabel) contains `\(marker)` OUTSIDE a `#if !EPISTEMOS_APP_STORE` block. The MAS sandbox cannot launch subprocesses; this leaks a launch marker into the MAS binary."
        #expect(!scan.outsideExcludedBlock, outsideMessage)
        let insideMessage: Comment = "\(fileLabel) no longer has `\(marker)` inside any `#if !EPISTEMOS_APP_STORE` block, but the file still contains the substring elsewhere. The Pro branch may have been moved or deleted; restore the gating shape so MAS stays subprocess-free here."
        #expect(scan.insideExcludedBlock, insideMessage)
    }

    /// Per-file MAS-branch marker spec for the KnowledgeFusion
    /// surgical gates added in Phase S.2. Table-driven so adding
    /// another file (or another marker per file) is a one-line
    /// edit, not another copy-pasted @Test method.
    private struct KFMASGateSpec {
        /// Path components after `Epistemos/`, e.g.
        /// `["KnowledgeFusion", "Adapters", "AdapterExporter.swift"]`.
        let pathComponents: [String]
        /// Substrings that must appear ONLY inside `#if !EPISTEMOS_APP_STORE`
        /// blocks in the file. Each substring is checked by
        /// `assertMarkerIsMASGated`. Process API markers (`Process.init(`,
        /// `process.executableURL`, `process.arguments`, `try process.run()`)
        /// catch the Process Foundation API; literal markers
        /// (`/usr/bin/ditto`, `/bin/bash`, etc.) catch the executable
        /// paths the Pro path uses to spawn subprocesses.
        let markers: [String]
    }

    private static let knowledgeFusionMASGateSpecs: [KFMASGateSpec] = [
        // Variable name `process` (default for files using
        // Foundation.Process directly): Process API markers cover
        // `.init(`, `.executableURL`, `.arguments`, and `.run()`.
        KFMASGateSpec(
            pathComponents: ["KnowledgeFusion", "Adapters", "AdapterExporter.swift"],
            markers: [
                "Process.init(",
                "process.executableURL",
                "process.arguments",
                "try process.run()",
                "/usr/bin/ditto",
            ]
        ),
        KFMASGateSpec(
            pathComponents: ["KnowledgeFusion", "Alignment", "KTOTrainer.swift"],
            markers: [
                "Process.init(",
                "process.executableURL",
                "process.arguments",
                "try process.run()",
            ]
        ),
        KFMASGateSpec(
            pathComponents: ["KnowledgeFusion", "Training", "QLoRATrainer.swift"],
            markers: [
                "Process.init(",
                "process.executableURL",
                "process.arguments",
                "try process.run()",
            ]
        ),
        // MoLoRAInferenceService uses `proc` as the Process variable
        // name, so the property/method markers are `proc.*`, not
        // `process.*`.
        KFMASGateSpec(
            pathComponents: ["KnowledgeFusion", "MoLoRA", "MoLoRAInferenceService.swift"],
            markers: [
                "Process.init(",
                "proc.executableURL",
                "proc.arguments",
                "try proc.run()",
            ]
        ),
        // PythonEnvironmentManager keeps the Pro/direct venv and pip
        // subprocess path, but must not carry runtime Homebrew/Python
        // installer-pipeline literals.
        KFMASGateSpec(
            pathComponents: ["KnowledgeFusion", "PythonEnvironmentManager.swift"],
            markers: [
                "Process.init(",
                "process.executableURL",
                "process.arguments",
                "try process.run()",
            ]
        ),
    ]

    private func runKFMASGateRegression(_ spec: KFMASGateSpec) throws {
        let relativePath = (["Epistemos"] + spec.pathComponents).joined(separator: "/")
        let url = try sourceMirrorURL(for: relativePath)
        let source = try String(contentsOf: url, encoding: .utf8)
        let label = spec.pathComponents.last ?? "KF source"

        let proSanity: Comment = "\(label) no longer contains Process.init -- the Pro/direct release relies on subprocess launch for this surface. If this is intentional, update or remove this test."
        #expect(source.contains("Process.init("), proSanity)

        for marker in spec.markers {
            assertMarkerIsMASGated(source: source, fileLabel: label, marker: marker)
        }
    }

    @Test("AdapterExporter MAS branch contains no /usr/bin/ditto launch markers")
    func adapterExporterMASBranchHasNoDittoLaunchMarkers() throws {
        try runKFMASGateRegression(Self.knowledgeFusionMASGateSpecs[0])
    }

    @Test("KTOTrainer MAS branch contains no python subprocess launch markers")
    func ktoTrainerMASBranchHasNoPythonLaunchMarkers() throws {
        try runKFMASGateRegression(Self.knowledgeFusionMASGateSpecs[1])
    }

    @Test("QLoRATrainer MAS branch contains no python subprocess launch markers")
    func qLoRATrainerMASBranchHasNoPythonLaunchMarkers() throws {
        try runKFMASGateRegression(Self.knowledgeFusionMASGateSpecs[2])
    }

    @Test("MoLoRAInferenceService MAS branch contains no python subprocess launch markers")
    func moLoRAInferenceServiceMASBranchHasNoPythonLaunchMarkers() throws {
        try runKFMASGateRegression(Self.knowledgeFusionMASGateSpecs[3])
    }

    @Test("PythonEnvironmentManager MAS branch contains no installer launch markers")
    func pythonEnvironmentManagerMASBranchHasNoInstallerMarkers() throws {
        try runKFMASGateRegression(Self.knowledgeFusionMASGateSpecs[4])
    }

    // MARK: - Category B regression (Phase S.2 ChunkedMCPFraming)
    //
    // The earlier ChunkedMCPFraming.swift used `dlopen(nil, RTLD_LAZY)` +
    // `dlsym("shm_open" / "shm_unlink")` to reach the POSIX symbols
    // because Swift cannot import variadic C functions. That self-handle
    // dlopen was sandbox-safe but the literal `dlopen` / `dlsym` /
    // `RTLD_LAZY` strings could attract paranoid App Store review
    // tooling. The fix replaced the runtime-symbol-lookup with a fixed-
    // signature C shim (`Epistemos/Bridge/ShmPosixShim.{h,c}`) wired
    // through `Epistemos-Bridging-Header.h`. This regression asserts
    // the dlopen / dlsym workaround does not creep back in.

    @Test("ChunkedMCPFraming Swift source has no dlopen/dlsym/RTLD_LAZY in compiled code")
    func chunkedMCPFramingHasNoDlopenWorkaround() throws {
        let url = try sourceMirrorURL(for: "Epistemos/Bridge/ChunkedMCPFraming.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        // Sanity: the C shim is the replacement; the Swift file still
        // calls into it via the bridging header. If `epistemos_shm_open`
        // is gone, the shim was deleted and the dlopen workaround is
        // probably back.
        let shimSanity: Comment = "ChunkedMCPFraming.swift no longer references epistemos_shm_open. The Phase S.2 Category B C-shim replacement may have been reverted; restore it (Epistemos/Bridge/ShmPosixShim.{h,c}) or update this test."
        #expect(source.contains("epistemos_shm_open"), shimSanity)

        // The actual regression: dlopen / dlsym / RTLD_LAZY must not
        // appear in non-comment code. Reuse the existing #if-aware
        // scanner; for ChunkedMCPFraming there is no `#if !EPISTEMOS_APP_STORE`
        // gate in this file, so EVERY non-comment occurrence shows up
        // in `outsideExcludedBlock`. Both flags must be false to pass.
        for marker in ["dlopen(", "dlsym(", "RTLD_LAZY"] {
            let scan = scanForMarkerInGateBranches(source: source, marker: marker)
            let message: Comment = "ChunkedMCPFraming.swift contains `\(marker)` in non-comment code. The dlopen(nil) / dlsym workaround was replaced by the fixed-signature C shim in Epistemos/Bridge/ShmPosixShim.{h,c}; restore the shim path or update this test."
            #expect(!scan.outsideExcludedBlock && !scan.insideExcludedBlock, message)
        }
    }

    // MARK: - Bounded-agent termination invariants (Phase S.4)
    //
    // Phase S.4 acceptance criterion (PHASE_S_AUDIT.md §7, IMPLEMENTATION_PLAN_FROM_ADVICE.md §S.4):
    // the agent loop must terminate at the maxTurns ceiling and must NOT
    // re-enter the backend after the ceiling fires. The local loop's strict
    // `.maxTurnsExceeded(N)` invariant is asserted directly in
    // `EpistemosTests/LocalAgentLoopTests.swift::localLoopStopsWhenToolCallsNeverConverge`.
    // This suite covers the parallel invariant on the Swift `AgentQueryEngine`
    // harness, which has its own ceiling-check at
    // `Epistemos/Engine/AgentHarness/AgentQueryEngine.swift:169`:
    //   if let maxTurns = config.maxTurns, turnCount > maxTurns {
    //       continuation.yield(.sessionComplete(result: .errorMaxTurns(...)))
    //       return
    //   }
    // The test uses a per-call unique backend identifier so it does not need
    // a global unregister API, and a recording backend whose execute() bumps
    // an actor-protected counter so we can assert the engine does NOT call
    // through after the ceiling fires.

    @Test("AgentQueryEngine emits .errorMaxTurns and stops calling the backend after maxTurns")
    func agentQueryEngineHaltsAtMaxTurnsCeiling() async {
        let stats = RecordingMaxTurnsBackendStats()
        let identifier = "test.AppStoreHardeningTests.maxTurnsCeiling.\(UUID().uuidString)"
        let backend = RecordingMaxTurnsBackend(identifier: identifier, stats: stats)

        await MainActor.run {
            BackendRegistry.shared.register(backend)
        }

        let config = AgentQueryEngineConfig(
            backendIdentifier: identifier,
            maxTurns: 1,
            cwd: FileManager.default.temporaryDirectory.path
        )
        let engine = AgentQueryEngine(config: config)

        // Turn 1 -- turnCount becomes 1, NOT greater than maxTurns=1, so the
        // engine resolves the backend and drives one execute() call. The
        // recording backend yields `.complete(...)` immediately so the turn
        // ends with `.success`.
        var turn1Result: AgentQueryEngineResult?
        do {
            for try await event in await engine.submitMessage("first") {
                if case .sessionComplete(let result) = event {
                    turn1Result = result
                }
            }
        } catch {
            Issue.record("Turn 1 should not throw, got: \(error)")
        }
        let executeCallsAfterTurn1 = await stats.executeCallCount()
        let turn1ExpectMessage: Comment =
            "Turn 1 must drive the backend exactly once before the maxTurns ceiling can fire on turn 2 (turnCount becomes 1, 1 > 1 is false)."
        #expect(executeCallsAfterTurn1 == 1, turn1ExpectMessage)
        if case .success = turn1Result {
            // expected branch
        } else {
            Issue.record("Expected .success on turn 1, got: \(String(describing: turn1Result))")
        }

        // Turn 2 -- turnCount becomes 2, 2 > 1 fires the ceiling. The engine
        // must yield `.errorMaxTurns(turns: 2)` and must NOT call execute()
        // again. This is the invariant Phase S.4 was added to lock down.
        var turn2Result: AgentQueryEngineResult?
        do {
            for try await event in await engine.submitMessage("second") {
                if case .sessionComplete(let result) = event {
                    turn2Result = result
                }
            }
        } catch {
            Issue.record("Turn 2 should not throw, got: \(error)")
        }
        let executeCallsAfterTurn2 = await stats.executeCallCount()
        let turn2BackendCallMessage: Comment =
            "Backend execute() must NOT be called after the maxTurns ceiling fires on turn 2; expected counter to remain 1, observed \(executeCallsAfterTurn2)."
        #expect(executeCallsAfterTurn2 == 1, turn2BackendCallMessage)
        if case .errorMaxTurns(_, let turns) = turn2Result {
            let turnsMessage: Comment =
                "Phase S.4 ceiling invariant: AgentQueryEngine reports `turns` from the post-increment turnCount; with maxTurns=1, turn 2 must report turns=2."
            #expect(turns == 2, turnsMessage)
        } else {
            Issue.record("Expected .errorMaxTurns on turn 2, got: \(String(describing: turn2Result))")
        }
    }
}

// MARK: - Test helpers for AgentQueryEngine ceiling test

/// Actor-protected counter for backend execute() invocations. Lives outside
/// the suite struct because Swift Testing requires `@Test` methods to be
/// instance-bound but the recording backend protocol is `nonisolated Sendable`
/// -- the actor lets the backend's execute() bump a counter without sharing
/// mutable state.
private actor RecordingMaxTurnsBackendStats {
    private var count: Int = 0
    func bump() { count += 1 }
    func executeCallCount() -> Int { count }
}

/// Minimal `AgentBackend` that records every execute() call into the shared
/// stats actor and yields a single immediate `.complete` event so the engine's
/// turn loop terminates cleanly. The unique `identifier` prevents collisions
/// with backends registered by app bootstrap or other test runs -- there is no
/// global unregister API, and this avoids needing one.
private struct RecordingMaxTurnsBackend: AgentBackend {
    let identifier: String
    let displayName: String = "AppStoreHardening recording backend (max-turns)"
    let stats: RecordingMaxTurnsBackendStats

    func execute(
        prompt: String,
        history: [String],
        options: AgentExecOptions
    ) async throws -> AsyncThrowingStream<AgentBackendEvent, Error> {
        await stats.bump()
        return AsyncThrowingStream { continuation in
            continuation.yield(.complete(sessionID: nil, stopReason: "stop"))
            continuation.finish()
        }
    }
}
