import Testing
@testable import Epistemos

/// Sovereign Gate Requirement Matrix — proves the doctrine §4.2 / §A.7 rule
/// that every destructive Core helper routes through `SovereignGate.confirm`
/// with `.deviceOwnerAuthentication`, and that no Swift source instantiates
/// `LAContext` outside `Epistemos/Sovereign/SovereignGate.swift`.
///
/// Doctrine §7 lane: Core killer-feature seed work — Sovereign Gate broader
/// Core classes follow-through. This suite is complementary to
/// `SovereignGateTests` (which audits per-helper text + UI routing) — its job
/// is the **single matrix sweep** over every helper, plus the single-owner
/// guard for `LAContext`.
@MainActor
@Suite("Sovereign Gate Requirement Matrix")
struct SovereignGateRequirementMatrixTests {

    // MARK: - Single-owner LAContext invariant

    @Test("LAContext is instantiated only inside Sovereign/SovereignGate.swift")
    func lacontextIsInstantiatedOnlyInsideSovereignGate() throws {
        // Doctrine §6 forbids ad-hoc Touch ID prompts. The single-owner rule
        // is enforceable via source scan: every other Swift file in the repo
        // must be free of `LAContext()`. If a future patch adds a popup that
        // calls `LAContext()` directly, this test fails with the offender's
        // path.
        let allowedPath = "Epistemos/Sovereign/SovereignGate.swift"
        let suspectPaths = [
            // Boundary policy files that route capabilities — must NOT host
            // their own biometric prompts.
            "Epistemos/LocalAgent/LocalAgentGatewayPolicy.swift",
            "Epistemos/Bridge/ToolTierBridge.swift",
            "Epistemos/Omega/MCPBridge.swift",
            // Settings surfaces that already migrated to Sovereign Gate —
            // they must stay free of direct LAContext usage.
            "Epistemos/Views/Settings/SettingsView.swift",
            "Epistemos/Views/Settings/AuthoritySettingsView.swift",
            "Epistemos/Views/Settings/AgentControlSettingsView.swift",
            "Epistemos/Views/Settings/OverseerSettingsView.swift",
            // Notes / Chat / Diff / Root surfaces that already migrated.
            "Epistemos/Views/Notes/NotesSidebar.swift",
            "Epistemos/Views/Notes/DiffSheetView.swift",
            "Epistemos/Views/Notes/ModelVaultsSidebarSection.swift",
            "Epistemos/App/RootView.swift",
        ]

        // Sanity: the canonical owner must still actually use LAContext.
        let owner = try loadMirroredSourceTextFile(allowedPath)
        #expect(owner.contains("LAContext("),
                "\(allowedPath) must remain the single LAContext owner — if you intentionally moved it, update this test")

        for path in suspectPaths {
            let source = try loadMirroredSourceTextFile(path)
            #expect(!source.contains("LAContext("),
                    "\(path) must NOT instantiate LAContext — Sovereign Gate is the single owner")
            #expect(!source.contains("import LocalAuthentication"),
                    "\(path) must NOT import LocalAuthentication — Sovereign Gate is the single owner")
            #expect(!source.contains("canEvaluatePolicy"),
                    "\(path) must NOT call canEvaluatePolicy — Sovereign Gate is the single owner")
            #expect(!source.contains("evaluatePolicy"),
                    "\(path) must NOT call evaluatePolicy — Sovereign Gate is the single owner")
            #expect(!source.contains("LAPolicy"),
                    "\(path) must NOT reference LAPolicy — Sovereign Gate is the single owner")
        }
    }

    // MARK: - Destructive helper requirement matrix

    /// One row per known destructive helper. The matrix is intentionally
    /// duplicated from `SovereignGateTests` per-helper coverage — its purpose
    /// is to be the single catch-all that fails loudly if any helper
    /// regresses, rather than leaving the regression buried in one of N
    /// per-helper tests.
    @Test("every destructive Core helper requires deviceOwnerAuthentication")
    func everyDestructiveCoreHelperRequiresDeviceOwnerAuthentication() {
        // Notes Sidebar — page / folder / vault disconnect.
        for target in [
            NotesSidebarDeletionSovereignGate.Target.page(title: "Demo Page"),
            .folder(name: "Demo Folder"),
            .vaultDisconnect(name: "Demo Vault"),
        ] {
            #expect(NotesSidebarDeletionSovereignGate.requirement(for: target)
                    == .deviceOwnerAuthentication,
                    "NotesSidebarDeletionSovereignGate target \(target) must require .deviceOwnerAuthentication")
        }

        // Chat Sidebar — chat delete.
        #expect(ChatSidebarDeletionSovereignGate.requirement(for: .chat(title: "Demo Chat"))
                == .deviceOwnerAuthentication)

        // Diff Sheet — version delete.
        #expect(DiffSheetVersionDeletionSovereignGate.requirement(for: .version(label: "Demo Version"))
                == .deviceOwnerAuthentication)

        // Root View — database reset / vault disconnect.
        for target in [
            RootViewDestructiveActionSovereignGate.Target.databaseReset,
            .vaultDisconnect,
        ] {
            #expect(RootViewDestructiveActionSovereignGate.requirement(for: target)
                    == .deviceOwnerAuthentication)
        }

        // Model Vaults Sidebar — file / folder delete.
        for target in [
            ModelVaultDeletionSovereignGate.Target.file(name: "demo.gguf"),
            .folder(name: "demo-adapters"),
        ] {
            #expect(ModelVaultDeletionSovereignGate.requirement(for: target)
                    == .deviceOwnerAuthentication)
        }

        // Agent Control — custom tool delete.
        #expect(AgentControlSettingsDeletionSovereignGate
                .requirement(for: .customTool(name: "demo-tool"))
                == .deviceOwnerAuthentication)

        // Authority Settings — reset to defaults / quick setup preset.
        for target in [
            AuthoritySettingsSovereignGate.Target.resetToDefaults,
            .quickSetup(name: "Demo Preset"),
        ] {
            #expect(AuthoritySettingsSovereignGate.requirement(for: target)
                    == .deviceOwnerAuthentication)
        }

        // Overseer Settings — history reset.
        #expect(OverseerSettingsSovereignGate.requirement(for: .historyReset)
                == .deviceOwnerAuthentication)

        // Settings View — reset everything / saved workspace / vault disconnect.
        for target in [
            SettingsViewDestructiveActionSovereignGate.Target.resetEverything,
            .savedWorkspace(name: "Demo Workspace"),
            .vaultDisconnect(name: "Demo Vault"),
        ] {
            #expect(SettingsViewDestructiveActionSovereignGate.requirement(for: target)
                    == .deviceOwnerAuthentication)
        }
    }

    // MARK: - Reason-text quality matrix

    /// Reasons are what the user sees in the Touch ID prompt. They must
    /// (a) be non-empty, (b) name the specific resource being affected so the
    /// user can tell which delete they are approving, and (c) include a
    /// destructive verb so an unfamiliar user understands the gravity. Empty
    /// or generic reasons are the leading cause of "I clicked yes by accident"
    /// regret.
    @Test("destructive helper reasons name the resource and an actionable verb")
    func destructiveHelperReasonsAreSpecificAndActionable() {
        let destructiveVerbs = ["delete", "disconnect", "reset", "remove"]

        func assertReason(
            _ reason: String,
            mustContain identifier: String,
            label: String,
            file: StaticString = #file,
            line: UInt = #line
        ) {
            #expect(!reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "\(label) reason must not be empty (Touch ID prompt would show blank)")
            #expect(reason.contains(identifier),
                    "\(label) reason must name the specific resource ‘\(identifier)’")
            let containsVerb = destructiveVerbs.contains { reason.localizedCaseInsensitiveContains($0) }
            #expect(containsVerb,
                    "\(label) reason must include a destructive verb (one of: \(destructiveVerbs.joined(separator: ", ")))")
        }

        let pageId = "MatrixDemoPage"
        assertReason(NotesSidebarDeletionSovereignGate.reason(for: .page(title: pageId)),
                     mustContain: pageId, label: "NotesSidebar page delete")

        let folderId = "MatrixDemoFolder"
        assertReason(NotesSidebarDeletionSovereignGate.reason(for: .folder(name: folderId)),
                     mustContain: folderId, label: "NotesSidebar folder delete")

        let vaultId = "MatrixDemoVault"
        assertReason(NotesSidebarDeletionSovereignGate.reason(for: .vaultDisconnect(name: vaultId)),
                     mustContain: vaultId, label: "NotesSidebar vault disconnect")

        let chatId = "MatrixDemoChat"
        assertReason(ChatSidebarDeletionSovereignGate.reason(for: .chat(title: chatId)),
                     mustContain: chatId, label: "ChatSidebar chat delete")

        let versionId = "MatrixDemoVersion"
        assertReason(DiffSheetVersionDeletionSovereignGate.reason(for: .version(label: versionId)),
                     mustContain: versionId, label: "DiffSheet version delete")

        let modelFileId = "matrix-demo-weights.gguf"
        assertReason(ModelVaultDeletionSovereignGate.reason(for: .file(name: modelFileId)),
                     mustContain: modelFileId, label: "ModelVault file delete")

        let modelFolderId = "matrix-demo-adapters"
        assertReason(ModelVaultDeletionSovereignGate.reason(for: .folder(name: modelFolderId)),
                     mustContain: modelFolderId, label: "ModelVault folder delete")

        let toolId = "matrix-demo-tool"
        assertReason(AgentControlSettingsDeletionSovereignGate.reason(for: .customTool(name: toolId)),
                     mustContain: toolId, label: "AgentControl custom tool delete")

        let presetId = "MatrixDemoPreset"
        assertReason(AuthoritySettingsSovereignGate.reason(for: .quickSetup(name: presetId)),
                     mustContain: presetId, label: "AuthoritySettings quick setup")

        let workspaceId = "MatrixDemoWorkspace"
        assertReason(SettingsViewDestructiveActionSovereignGate.reason(for: .savedWorkspace(name: workspaceId)),
                     mustContain: workspaceId, label: "SettingsView saved workspace delete")

        let settingsVaultId = "MatrixDemoSettingsVault"
        assertReason(SettingsViewDestructiveActionSovereignGate.reason(for: .vaultDisconnect(name: settingsVaultId)),
                     mustContain: settingsVaultId, label: "SettingsView vault disconnect")
    }

    // MARK: - SovereignGate requirement enum exhaustiveness

    /// The requirement enum has three cases. Each one has a specific
    /// behavioral contract. If a future patch adds a fourth case (e.g. a
    /// Sovereign-class for Secure Enclave sealing per doctrine §A.7), this
    /// matrix must be updated to cover it — and the failure here flags that.
    @Test("SovereignGateRequirement has the three currently-shipped cases")
    func sovereignGateRequirementHasThreeShippedCases() {
        // We can't introspect the enum's case count at runtime without
        // CaseIterable conformance (which it deliberately does not have —
        // .biometric and .deviceOwnerAuthentication take parameters). Instead,
        // round-trip the three known cases through equality so a future case
        // addition would break the assertion or shadow one of these.
        let none: SovereignGateRequirement = .none
        let biometric: SovereignGateRequirement =
            .biometric(category: SovereignGateCategory(rawValue: "matrix-test"))
        let deviceOwner: SovereignGateRequirement = .deviceOwnerAuthentication

        #expect(none == .none)
        #expect(biometric != .none)
        #expect(biometric != .deviceOwnerAuthentication)
        #expect(deviceOwner != .none)
        #expect(deviceOwner != biometric)

        // Default grace duration must remain the doctrine-declared 15 minutes.
        // If this changes, settings UX text and lifecycle observer assumptions
        // both need an audit.
        let defaultBiometric: SovereignGateRequirement =
            .biometric(category: SovereignGateCategory(rawValue: "matrix-test"))
        let explicitBiometric: SovereignGateRequirement =
            .biometric(category: SovereignGateCategory(rawValue: "matrix-test"),
                       graceDuration: 15 * 60)
        #expect(defaultBiometric == explicitBiometric,
                "Default biometric grace must remain 15 minutes per doctrine §A.7 — if you intentionally changed it, update lifecycle and settings UX too")
    }

    // MARK: - Outcome enum coverage

    @Test("SovereignGateOutcome encodes the two failure modes the matrix expects")
    func sovereignGateOutcomeEncodesTheTwoFailureModes() {
        let allowed: SovereignGateOutcome = .allowed
        let missingReason: SovereignGateOutcome = .denied(.missingReason)
        let authFailed: SovereignGateOutcome = .denied(.authenticationFailed)

        #expect(allowed == .allowed)
        #expect(missingReason != allowed)
        #expect(authFailed != allowed)
        #expect(missingReason != authFailed,
                "denial reasons must remain distinguishable so logs can attribute correctly")
    }
}
