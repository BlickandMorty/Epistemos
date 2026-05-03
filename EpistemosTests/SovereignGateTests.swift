import AppKit
import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("Sovereign Gate")
struct SovereignGateTests {
    private final class FakeAuthenticator: SovereignGateAuthenticating {
        private var results: [Bool]
        private(set) var requests: [(policy: SovereignGateAuthenticationPolicy, reason: String)] = []

        init(results: [Bool] = [true]) {
            self.results = results
        }

        func authenticate(
            policy: SovereignGateAuthenticationPolicy,
            reason: String
        ) async -> Bool {
            requests.append((policy, reason))
            guard !results.isEmpty else { return true }
            return results.removeFirst()
        }
    }

    @Test("None requirement allows without prompting")
    func noneRequirementAllowsWithoutPrompting() async {
        let authenticator = FakeAuthenticator()
        let gate = SovereignGate(authenticator: authenticator)

        let outcome = await gate.confirm(.none, reason: "", now: Date(timeIntervalSince1970: 1_000))

        #expect(outcome == .allowed)
        #expect(authenticator.requests.isEmpty)
    }

    @Test("Biometric requirement caches only within category and grace")
    func biometricRequirementCachesOnlyWithinCategoryAndGrace() async {
        let authenticator = FakeAuthenticator(results: [true, true, true])
        let gate = SovereignGate(authenticator: authenticator)
        let export = SovereignGateCategory(rawValue: "export")
        let share = SovereignGateCategory(rawValue: "share")
        let start = Date(timeIntervalSince1970: 2_000)

        #expect(await gate.confirm(.biometric(category: export), reason: "Export note", now: start) == .allowed)
        #expect(
            await gate.confirm(
                .biometric(category: export),
                reason: "Export note again",
                now: start.addingTimeInterval(899)
            ) == .allowed
        )
        #expect(
            await gate.confirm(
                .biometric(category: share),
                reason: "Share note",
                now: start.addingTimeInterval(100)
            ) == .allowed
        )
        #expect(
            await gate.confirm(
                .biometric(category: export),
                reason: "Export after grace",
                now: start.addingTimeInterval(901)
            ) == .allowed
        )

        #expect(authenticator.requests.map(\.policy) == [
            .deviceOwnerAuthenticationWithBiometrics,
            .deviceOwnerAuthenticationWithBiometrics,
            .deviceOwnerAuthenticationWithBiometrics,
        ])
        #expect(authenticator.requests.map(\.reason) == [
            "Export note",
            "Share note",
            "Export after grace",
        ])
    }

    @Test("Clearing grace forces the next biometric prompt")
    func clearingGraceForcesNextBiometricPrompt() async {
        let authenticator = FakeAuthenticator(results: [true, true])
        let gate = SovereignGate(authenticator: authenticator)
        let category = SovereignGateCategory(rawValue: "oauth")
        let start = Date(timeIntervalSince1970: 3_000)

        #expect(await gate.confirm(.biometric(category: category), reason: "Grant OAuth", now: start) == .allowed)
        gate.clearGrace()
        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Grant OAuth again",
                now: start.addingTimeInterval(10)
            ) == .allowed
        )

        #expect(authenticator.requests.count == 2)
    }

    @Test("Biometric grace rejects clock rollback and invalid durations")
    func biometricGraceRejectsClockRollbackAndInvalidDurations() async {
        let authenticator = FakeAuthenticator(results: [true, true, true, true])
        let gate = SovereignGate(authenticator: authenticator)
        let category = SovereignGateCategory(rawValue: "vault-export")
        let start = Date(timeIntervalSince1970: 3_500)

        #expect(await gate.confirm(.biometric(category: category), reason: "Export vault", now: start) == .allowed)
        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Export after clock rollback",
                now: start.addingTimeInterval(-1)
            ) == .allowed
        )
        #expect(
            await gate.confirm(
                .biometric(category: category, graceDuration: .infinity),
                reason: "Export with invalid grace",
                now: start.addingTimeInterval(1)
            ) == .allowed
        )
        #expect(
            await gate.confirm(
                .biometric(category: category, graceDuration: 0),
                reason: "Export with zero grace",
                now: start.addingTimeInterval(2)
            ) == .allowed
        )

        #expect(authenticator.requests.count == 4)
    }

    @Test("Device-owner authentication prompts every time")
    func deviceOwnerAuthenticationPromptsEveryTime() async {
        let authenticator = FakeAuthenticator(results: [true, true])
        let gate = SovereignGate(authenticator: authenticator)
        let start = Date(timeIntervalSince1970: 4_000)

        #expect(await gate.confirm(.deviceOwnerAuthentication, reason: "Empty trash", now: start) == .allowed)
        #expect(
            await gate.confirm(
                .deviceOwnerAuthentication,
                reason: "Empty trash again",
                now: start.addingTimeInterval(1)
            ) == .allowed
        )

        #expect(authenticator.requests.map(\.policy) == [
            .deviceOwnerAuthentication,
            .deviceOwnerAuthentication,
        ])
    }

    @Test("Failed biometric authentication denies and does not grant grace")
    func failedBiometricAuthenticationDeniesAndDoesNotGrantGrace() async {
        let authenticator = FakeAuthenticator(results: [false, true])
        let gate = SovereignGate(authenticator: authenticator)
        let category = SovereignGateCategory(rawValue: "delete")
        let start = Date(timeIntervalSince1970: 5_000)

        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Soft delete",
                now: start
            ) == .denied(.authenticationFailed)
        )
        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Soft delete retry",
                now: start.addingTimeInterval(1)
            ) == .allowed
        )

        #expect(authenticator.requests.count == 2)
    }

    @Test("Prompting requirements reject empty reasons before authentication")
    func promptingRequirementsRejectEmptyReasonsBeforeAuthentication() async {
        let authenticator = FakeAuthenticator()
        let gate = SovereignGate(authenticator: authenticator)

        #expect(
            await gate.confirm(
                .biometric(category: SovereignGateCategory(rawValue: "export")),
                reason: "   ",
                now: Date(timeIntervalSince1970: 6_000)
            ) == .denied(.missingReason)
        )
        #expect(
            await gate.confirm(
                .deviceOwnerAuthentication,
                reason: "",
                now: Date(timeIntervalSince1970: 6_001)
            ) == .denied(.missingReason)
        )
        #expect(authenticator.requests.isEmpty)
    }

    @Test("Agent approval decisions map to Sovereign Gate requirements")
    func agentApprovalDecisionsMapToSovereignGateRequirements() {
        #expect(
            ChatApprovalSovereignGate.requirement(
                for: .approveOnce,
                toolName: "shell.execute"
            ) == .biometric(category: SovereignGateCategory(rawValue: "agent-tool-shell.execute"))
        )
        #expect(
            ChatApprovalSovereignGate.requirement(
                for: .applyLessInterruptions,
                toolName: "shell.execute"
            ) == .deviceOwnerAuthentication
        )
        #expect(
            ChatApprovalSovereignGate.requirement(
                for: .approveAlways,
                toolName: "shell.execute"
            ) == .deviceOwnerAuthentication
        )
        #expect(ChatApprovalSovereignGate.requirement(for: .deny, toolName: "shell.execute") == .none)
        #expect(ChatApprovalSovereignGate.requirement(for: .timedOut, toolName: "shell.execute") == .none)
        #expect(
            ChatApprovalSovereignGate.reason(
                for: .approveAlways,
                toolName: "shell.execute"
            ).contains("shell.execute")
        )
    }

    @Test("Notes sidebar permanent deletes map to destructive Sovereign Gate requirements")
    func notesSidebarDeletesMapToSovereignGateRequirements() {
        #expect(
            NotesSidebarDeletionSovereignGate.requirement(for: .page(title: "Research Notes"))
                == .deviceOwnerAuthentication
        )
        #expect(
            NotesSidebarDeletionSovereignGate.requirement(for: .folder(name: "Archive"))
                == .deviceOwnerAuthentication
        )

        let pageReason = NotesSidebarDeletionSovereignGate.reason(for: .page(title: "Research Notes"))
        let folderReason = NotesSidebarDeletionSovereignGate.reason(for: .folder(name: "Archive"))

        #expect(pageReason.contains("Research Notes"))
        #expect(folderReason.contains("Archive"))
        #expect(pageReason.localizedCaseInsensitiveContains("permanently delete"))
        #expect(folderReason.localizedCaseInsensitiveContains("permanently delete"))
    }

    @Test("Notes sidebar vault disconnect maps to destructive Sovereign Gate requirements")
    func notesSidebarVaultDisconnectMapsToDestructiveSovereignGateRequirements() {
        #expect(
            NotesSidebarDeletionSovereignGate.requirement(for: .vaultDisconnect(name: "Research Vault"))
                == .deviceOwnerAuthentication
        )

        let reason = NotesSidebarDeletionSovereignGate.reason(
            for: .vaultDisconnect(name: "Research Vault")
        )

        #expect(reason.contains("Research Vault"))
        #expect(reason.localizedCaseInsensitiveContains("disconnect vault"))
    }

    @Test("Notes sidebar vault disconnect routes through Sovereign Gate")
    func notesSidebarVaultDisconnectRoutesThroughSovereignGate() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NotesSidebar.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let vaultButton = try section(
            from: "private struct VaultConnectionButton: View",
            to: "// MARK: - Sidebar Icon Button"
        )
        #expect(vaultButton.contains("@State private var isVaultDisconnectAuthorizationInFlight = false"))
        #expect(vaultButton.contains("requestVaultDisconnectAuthorization(vaultURL: vaultURL)"))
        #expect(!vaultButton.contains("Button(\"Disconnect Vault\", role: .destructive) {\n                    VaultConnectionActions.disconnect(notesUI: notesUI, vaultSync: vaultSync)"))
        #expect(vaultButton.contains(".disabled(isVaultDisconnectAuthorizationInFlight)"))

        let request = try section(
            from: "private func requestVaultDisconnectAuthorization(vaultURL: URL) async",
            to: "// MARK: - Sidebar Icon Button"
        )
        #expect(request.contains("guard !isVaultDisconnectAuthorizationInFlight else { return }"))
        #expect(request.contains("isVaultDisconnectAuthorizationInFlight = true"))
        #expect(request.contains("defer { isVaultDisconnectAuthorizationInFlight = false }"))
        #expect(request.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(request.contains("?? .denied(.authenticationFailed)"))
        #expect(request.contains("guard outcome == .allowed else { return }"))
        #expect(request.contains("guard vaultSync.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL else { return }"))
        #expect(request.contains("VaultConnectionActions.disconnect(notesUI: notesUI, vaultSync: vaultSync)"))
        #expect(!source.contains("LocalAuthentication"))
        #expect(!source.contains("LAContext"))
        #expect(!source.contains("LAError"))
        #expect(!source.contains("LABiometryType"))
        #expect(!source.contains("LAPolicy"))
        #expect(!source.contains("canEvaluatePolicy"))
        #expect(!source.contains("evaluatePolicy"))
    }

    @Test("Chat sidebar deletes map to destructive Sovereign Gate requirements")
    func chatSidebarDeletesMapToSovereignGateRequirements() {
        #expect(
            ChatSidebarDeletionSovereignGate.requirement(for: .chat(title: "Planning Thread"))
                == .deviceOwnerAuthentication
        )

        let reason = ChatSidebarDeletionSovereignGate.reason(for: .chat(title: "Planning Thread"))

        #expect(reason.contains("Planning Thread"))
        #expect(reason.localizedCaseInsensitiveContains("permanently delete"))
    }

    @Test("Diff sheet version deletes map to destructive Sovereign Gate requirements")
    func diffSheetVersionDeletesMapToSovereignGateRequirements() {
        #expect(
            DiffSheetVersionDeletionSovereignGate.requirement(for: .version(label: "May 2, 2026 at 12:00 PM"))
                == .deviceOwnerAuthentication
        )

        let reason = DiffSheetVersionDeletionSovereignGate.reason(for: .version(label: "May 2, 2026 at 12:00 PM"))

        #expect(reason.contains("May 2, 2026 at 12:00 PM"))
        #expect(reason.localizedCaseInsensitiveContains("permanently delete"))
    }

    @Test("Diff sheet version delete menu routes through captured Sovereign Gate target")
    func diffSheetVersionDeleteMenuRoutesThroughCapturedSovereignGateTarget() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/DiffSheetView.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let menuAction = try section(
            from: "Button(role: .destructive) {",
            to: "Label(\"Delete This Version\", systemImage: \"trash\")"
        )
        #expect(menuAction.contains("requestSelectedVersionDeleteAuthorization()"))
        #expect(!menuAction.contains("deleteSelectedVersion()"))

        let request = try section(
            from: "private func requestSelectedVersionDeleteAuthorization()",
            to: "private func deleteSelectedVersion()"
        )
        #expect(request.contains("guard let version = selectedVersion else { return }"))
        #expect(request.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(request.contains("guard outcome == .allowed else { return }"))
        #expect(request.contains("deleteSelectedVersion(version)"))

        let capture = try #require(request.range(of: "guard let version = selectedVersion else { return }"))
        let confirm = try #require(request.range(of: "AppBootstrap.shared?.sovereignGate.confirm("))
        let allowed = try #require(request.range(of: "guard outcome == .allowed else { return }"))
        let delete = try #require(request.range(of: "deleteSelectedVersion(version)"))
        #expect(capture.lowerBound < confirm.lowerBound)
        #expect(confirm.lowerBound < allowed.lowerBound)
        #expect(allowed.lowerBound < delete.lowerBound)
    }

    @Test("Root view destructive actions map to destructive Sovereign Gate requirements")
    func rootViewDestructiveActionsMapToSovereignGateRequirements() {
        #expect(
            RootViewDestructiveActionSovereignGate.requirement(for: .databaseReset)
                == .deviceOwnerAuthentication
        )
        #expect(
            RootViewDestructiveActionSovereignGate.requirement(for: .vaultDisconnect)
                == .deviceOwnerAuthentication
        )

        let resetReason = RootViewDestructiveActionSovereignGate.reason(for: .databaseReset)
        let disconnectReason = RootViewDestructiveActionSovereignGate.reason(for: .vaultDisconnect)

        #expect(resetReason.localizedCaseInsensitiveContains("reset database"))
        #expect(resetReason.localizedCaseInsensitiveContains("delete saved data"))
        #expect(disconnectReason.localizedCaseInsensitiveContains("disconnect vault"))
    }

    @Test("Root view destructive controls route through Sovereign Gate")
    func rootViewDestructiveControlsRouteThroughSovereignGate() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let resetButton = try section(
            from: "Button(\"Reset Database\", role: .destructive) {",
            to: "Button(\"Quit\")"
        )
        #expect(resetButton.contains("requestDatabaseResetAuthorization()"))
        #expect(!resetButton.contains("onResetDatabase?()"))

        let resetRequest = try section(
            from: "private func requestDatabaseResetAuthorization()",
            to: "private func handleDatabaseCheck()"
        )
        #expect(resetRequest.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(resetRequest.contains("guard outcome == .allowed else {"))
        #expect(resetRequest.contains("showDatabaseAlert = true"))
        #expect(resetRequest.contains("onResetDatabase?()"))

        let resetDenied = try #require(resetRequest.range(of: "guard outcome == .allowed else {"))
        let resetReopen = try #require(resetRequest.range(of: "showDatabaseAlert = true"))
        let resetClosure = try #require(resetRequest.range(of: "onResetDatabase?()"))
        #expect(resetDenied.lowerBound < resetReopen.lowerBound)
        #expect(resetReopen.lowerBound < resetClosure.lowerBound)

        let disconnectButton = try section(
            from: "Button(\"Disconnect Vault\", role: .destructive) {",
            to: ".disabled(isRecovering || isVaultDisconnectAuthorizationInFlight)"
        )
        #expect(disconnectButton.contains("requestVaultDisconnectAuthorization()"))
        #expect(!disconnectButton.contains("disconnectAction()"))
        #expect(source.contains(".disabled(isRecovering || isVaultDisconnectAuthorizationInFlight)"))

        let disconnectRequest = try section(
            from: "private func requestVaultDisconnectAuthorization()",
            to: "var body: some View"
        )
        #expect(disconnectRequest.contains("guard !isVaultDisconnectAuthorizationInFlight else { return }"))
        #expect(disconnectRequest.contains("isVaultDisconnectAuthorizationInFlight = true"))
        #expect(disconnectRequest.contains("defer { isVaultDisconnectAuthorizationInFlight = false }"))
        #expect(disconnectRequest.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(disconnectRequest.contains("guard outcome == .allowed else { return }"))
        #expect(disconnectRequest.contains("disconnectAction()"))
    }

    @Test("Model vault deletes map to destructive Sovereign Gate requirements")
    func modelVaultDeletesMapToDestructiveSovereignGateRequirements() {
        #expect(
            ModelVaultDeletionSovereignGate.requirement(for: .file(name: "weights.gguf"))
                == .deviceOwnerAuthentication
        )
        #expect(
            ModelVaultDeletionSovereignGate.requirement(for: .folder(name: "adapters"))
                == .deviceOwnerAuthentication
        )

        let fileReason = ModelVaultDeletionSovereignGate.reason(for: .file(name: "weights.gguf"))
        let folderReason = ModelVaultDeletionSovereignGate.reason(for: .folder(name: "adapters"))

        #expect(fileReason.contains("weights.gguf"))
        #expect(folderReason.contains("adapters"))
        #expect(fileReason.localizedCaseInsensitiveContains("permanently delete"))
        #expect(folderReason.localizedCaseInsensitiveContains("permanently delete"))
    }

    @Test("Model vault delete alert routes through captured Sovereign Gate target")
    func modelVaultDeleteAlertRoutesThroughCapturedSovereignGateTarget() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/ModelVaultsSidebarSection.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let alert = try section(
            from: ".alert(item: $pendingDeleteTarget) { target in",
            to: ".sheet(item: $pendingCreateRequest)"
        )
        #expect(alert.contains("requestDeleteAuthorization(target)"))
        #expect(!alert.contains("delete(target)"))

        let request = try section(
            from: "private func requestDeleteAuthorization(_ target: ModelVaultDeleteTarget)",
            to: "private func delete(_ target: ModelVaultDeleteTarget)"
        )
        #expect(request.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(request.contains("guard outcome == .allowed else { return }"))
        #expect(request.contains("delete(target)"))

        let confirm = try #require(request.range(of: "AppBootstrap.shared?.sovereignGate.confirm("))
        let allowed = try #require(request.range(of: "guard outcome == .allowed else { return }"))
        let delete = try #require(request.range(of: "delete(target)"))
        #expect(confirm.lowerBound < allowed.lowerBound)
        #expect(allowed.lowerBound < delete.lowerBound)
        #expect(!source.contains("LocalAuthentication"))
        #expect(!source.contains("LAContext"))
        #expect(!source.contains("canEvaluatePolicy"))
        #expect(!source.contains("evaluatePolicy"))
    }

    @Test("Agent control custom tool deletes map to destructive Sovereign Gate requirements")
    func agentControlCustomToolDeletesMapToDestructiveSovereignGateRequirements() {
        #expect(
            AgentControlSettingsDeletionSovereignGate.requirement(for: .customTool(name: "shell-wrap"))
                == .deviceOwnerAuthentication
        )

        let reason = AgentControlSettingsDeletionSovereignGate.reason(for: .customTool(name: "shell-wrap"))

        #expect(reason.contains("shell-wrap"))
        #expect(reason.localizedCaseInsensitiveContains("permanently delete"))
    }

    @Test("Agent control custom tool delete routes through Sovereign Gate")
    func agentControlCustomToolDeleteRoutesThroughSovereignGate() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentControlSettingsView.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let customToolsList = try section(
            from: "ForEach(customTools) { tool in",
            to: "Text(tool.commandTemplate)"
        )
        #expect(customToolsList.contains("requestCustomToolDeleteAuthorization("))
        #expect(customToolsList.contains("named: tool.name"))
        #expect(customToolsList.contains("vaultPath: vaultPath"))
        #expect(!customToolsList.contains("deleteCustomTool(named: tool.name, vaultPath: vaultPath)"))

        let request = try section(
            from: "private func requestCustomToolDeleteAuthorization(named name: String, vaultPath: String) async",
            to: "private func deleteCustomTool(named name: String, vaultPath: String) async"
        )
        #expect(request.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(request.contains("guard outcome == .allowed else { return }"))
        #expect(request.contains("await deleteCustomTool(named: name, vaultPath: vaultPath)"))
        #expect(!source.contains("LocalAuthentication"))
        #expect(!source.contains("LAContext"))
        #expect(!source.contains("canEvaluatePolicy"))
        #expect(!source.contains("evaluatePolicy"))
    }

    @Test("Authority settings batch policy changes map to destructive Sovereign Gate requirements")
    func authoritySettingsBatchPolicyChangesMapToDestructiveSovereignGateRequirements() {
        #expect(
            AuthoritySettingsSovereignGate.requirement(for: .resetToDefaults)
                == .deviceOwnerAuthentication
        )
        #expect(
            AuthoritySettingsSovereignGate.requirement(for: .quickSetup(name: "Less Interruptions"))
                == .deviceOwnerAuthentication
        )

        let resetReason = AuthoritySettingsSovereignGate.reason(for: .resetToDefaults)
        let presetReason = AuthoritySettingsSovereignGate.reason(for: .quickSetup(name: "Less Interruptions"))

        #expect(resetReason.localizedCaseInsensitiveContains("reset authority"))
        #expect(presetReason.contains("Less Interruptions"))
        #expect(presetReason.localizedCaseInsensitiveContains("apply authority preset"))
    }

    @Test("Authority settings batch policy changes route through Sovereign Gate")
    func authoritySettingsBatchPolicyChangesRouteThroughSovereignGate() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AuthoritySettingsView.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let quickSetup = try section(
            from: "private var quickSetupCard: some View",
            to: "private func categoryCard(for category: AgentAuthorityCategory)"
        )
        #expect(quickSetup.contains("requestQuickSetupAuthorization(preset)"))
        #expect(!quickSetup.contains("applyPreset(preset)"))

        let footer = try section(
            from: "private var footer: some View",
            to: "private func requestResetToDefaultsAuthorization()"
        )
        #expect(footer.contains("requestResetToDefaultsAuthorization()"))
        #expect(!footer.contains("store.reset()"))

        let resetRequest = try section(
            from: "private func requestResetToDefaultsAuthorization()",
            to: "private func requestQuickSetupAuthorization"
        )
        #expect(resetRequest.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(resetRequest.contains("?? .denied(.authenticationFailed)"))
        #expect(resetRequest.contains("guard outcome == .allowed else { return }"))
        #expect(resetRequest.contains("resetToDefaults()"))

        let presetRequest = try section(
            from: "private func requestQuickSetupAuthorization(_ preset: AgentAuthorityQuickSetupPreset)",
            to: "private func resetToDefaults()"
        )
        #expect(presetRequest.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(presetRequest.contains("?? .denied(.authenticationFailed)"))
        #expect(presetRequest.contains("guard outcome == .allowed else { return }"))
        #expect(presetRequest.contains("applyPreset(preset)"))

        #expect(!source.contains("LocalAuthentication"))
        #expect(!source.contains("LAContext"))
        #expect(!source.contains("LAError"))
        #expect(!source.contains("LABiometryType"))
        #expect(!source.contains("LAPolicy"))
        #expect(!source.contains("canEvaluatePolicy"))
        #expect(!source.contains("evaluatePolicy"))
    }

    @Test("Overseer history reset maps to destructive Sovereign Gate requirements")
    func overseerHistoryResetMapsToDestructiveSovereignGateRequirements() {
        #expect(
            OverseerSettingsSovereignGate.requirement(for: .historyReset)
                == .deviceOwnerAuthentication
        )

        let reason = OverseerSettingsSovereignGate.reason(for: .historyReset)

        #expect(reason.localizedCaseInsensitiveContains("reset overseer"))
        #expect(reason.localizedCaseInsensitiveContains("history"))
    }

    @Test("Overseer history reset routes through Sovereign Gate")
    func overseerHistoryResetRoutesThroughSovereignGate() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/OverseerSettingsView.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let footer = try section(
            from: "private var footer: some View",
            to: "private func requestHistoryResetAuthorization()"
        )
        #expect(footer.contains("requestHistoryResetAuthorization()"))
        #expect(!footer.contains("audit.clear()"))

        let request = try section(
            from: "private func requestHistoryResetAuthorization()",
            to: "private func resetHistory()"
        )
        #expect(request.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(request.contains("?? .denied(.authenticationFailed)"))
        #expect(request.contains("guard outcome == .allowed else { return }"))
        #expect(request.contains("resetHistory()"))

        #expect(!source.contains("LocalAuthentication"))
        #expect(!source.contains("LAContext"))
        #expect(!source.contains("LAError"))
        #expect(!source.contains("LABiometryType"))
        #expect(!source.contains("LAPolicy"))
        #expect(!source.contains("canEvaluatePolicy"))
        #expect(!source.contains("evaluatePolicy"))
    }

    @Test("Settings reset everything maps to destructive Sovereign Gate requirements")
    func settingsResetEverythingMapsToDestructiveSovereignGateRequirements() {
        #expect(
            SettingsViewDestructiveActionSovereignGate.requirement(for: .resetEverything)
                == .deviceOwnerAuthentication
        )

        let reason = SettingsViewDestructiveActionSovereignGate.reason(for: .resetEverything)

        #expect(reason.localizedCaseInsensitiveContains("reset everything"))
        #expect(reason.localizedCaseInsensitiveContains("delete saved data"))
    }

    @Test("Settings saved workspace delete maps to destructive Sovereign Gate requirements")
    func settingsSavedWorkspaceDeleteMapsToDestructiveSovereignGateRequirements() {
        #expect(
            SettingsViewDestructiveActionSovereignGate.requirement(for: .savedWorkspace(name: "Research Sprint"))
                == .deviceOwnerAuthentication
        )

        let reason = SettingsViewDestructiveActionSovereignGate.reason(for: .savedWorkspace(name: "Research Sprint"))

        #expect(reason.contains("Research Sprint"))
        #expect(reason.localizedCaseInsensitiveContains("delete saved workspace"))
    }

    @Test("Settings vault disconnect maps to destructive Sovereign Gate requirements")
    func settingsVaultDisconnectMapsToDestructiveSovereignGateRequirements() {
        #expect(
            SettingsViewDestructiveActionSovereignGate.requirement(for: .vaultDisconnect(name: "Research Vault"))
                == .deviceOwnerAuthentication
        )

        let reason = SettingsViewDestructiveActionSovereignGate.reason(for: .vaultDisconnect(name: "Research Vault"))

        #expect(reason.contains("Research Vault"))
        #expect(reason.localizedCaseInsensitiveContains("disconnect vault"))
    }

    @Test("Settings reset everything alert routes through Sovereign Gate")
    func settingsResetEverythingAlertRoutesThroughSovereignGate() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let resetSection = try section(
            from: "Section(\"Reset\")",
            to: ".alert(\"Rename Workspace\""
        )
        #expect(resetSection.contains("Button(\"Reset Everything\", role: .destructive)"))
        #expect(resetSection.contains("showResetAlert = true"))

        let alert = try section(
            from: ".alert(\"Reset Everything?\"",
            to: "} message:"
        )
        #expect(alert.contains("requestResetEverythingAuthorization()"))
        #expect(!alert.contains("resetAllData()"))

        let request = try section(
            from: "private func requestResetEverythingAuthorization()",
            to: "private func resetEverything()"
        )
        #expect(request.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(request.contains("?? .denied(.authenticationFailed)"))
        #expect(request.contains("guard outcome == .allowed else { return }"))
        #expect(request.contains("await resetEverything()"))

        #expect(!source.contains("LocalAuthentication"))
        #expect(!source.contains("LAContext"))
        #expect(!source.contains("LAError"))
        #expect(!source.contains("LABiometryType"))
        #expect(!source.contains("LAPolicy"))
        #expect(!source.contains("canEvaluatePolicy"))
        #expect(!source.contains("evaluatePolicy"))
    }

    @Test("Settings saved workspace delete routes through Sovereign Gate")
    func settingsSavedWorkspaceDeleteRoutesThroughSovereignGate() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let savedWorkspaces = try section(
            from: "Section(\"Saved Workspaces\")",
            to: "Section(\"Data Protection\")"
        )
        #expect(savedWorkspaces.contains("requestSavedWorkspaceDeleteAuthorization(workspace)"))
        #expect(!savedWorkspaces.contains("workspaceService.deleteWorkspace(workspace)"))

        let request = try section(
            from: "private func requestSavedWorkspaceDeleteAuthorization(_ workspace: SDWorkspace) async",
            to: "private func deleteSavedWorkspace(_ workspace: SDWorkspace)"
        )
        #expect(request.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(request.contains("?? .denied(.authenticationFailed)"))
        #expect(request.contains("guard outcome == .allowed else { return }"))
        #expect(request.contains("deleteSavedWorkspace(workspace)"))

        let delete = try section(
            from: "private func deleteSavedWorkspace(_ workspace: SDWorkspace)",
            to: "private func requestResetEverythingAuthorization()"
        )
        #expect(delete.contains("workspaceService.deleteWorkspace(workspace)"))
        #expect(delete.contains("refreshWorkspaces()"))

        #expect(!source.contains("LocalAuthentication"))
        #expect(!source.contains("LAContext"))
        #expect(!source.contains("LAError"))
        #expect(!source.contains("LABiometryType"))
        #expect(!source.contains("LAPolicy"))
        #expect(!source.contains("canEvaluatePolicy"))
        #expect(!source.contains("evaluatePolicy"))
    }

    @Test("Settings vault disconnect routes through Sovereign Gate")
    func settingsVaultDisconnectRoutesThroughSovereignGate() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let vaultDetail = try section(
            from: "private struct VaultDetailView: View",
            to: "private func autoSaveOption"
        )

        #expect(vaultDetail.contains("@State private var isVaultDisconnectAuthorizationInFlight = false"))
        #expect(vaultDetail.contains("requestVaultDisconnectAuthorization(vaultURL: url)"))
        #expect(!vaultDetail.contains("Button(\"Disconnect\", role: .destructive) {\n                            VaultConnectionActions.disconnect(notesUI: notesUI, vaultSync: vaultSync)"))
        #expect(vaultDetail.contains(".disabled(isVaultDisconnectAuthorizationInFlight)"))

        let request = try section(
            from: "private func requestVaultDisconnectAuthorization(vaultURL: URL) async",
            to: "private func autoSaveOption"
        )
        #expect(request.contains("guard !isVaultDisconnectAuthorizationInFlight else { return }"))
        #expect(request.contains("isVaultDisconnectAuthorizationInFlight = true"))
        #expect(request.contains("defer { isVaultDisconnectAuthorizationInFlight = false }"))
        #expect(request.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(request.contains("?? .denied(.authenticationFailed)"))
        #expect(request.contains("guard outcome == .allowed else { return }"))
        #expect(request.contains("guard vaultSync.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL else { return }"))
        #expect(request.contains("VaultConnectionActions.disconnect(notesUI: notesUI, vaultSync: vaultSync)"))

        #expect(!source.contains("LocalAuthentication"))
        #expect(!source.contains("LAContext"))
        #expect(!source.contains("LAError"))
        #expect(!source.contains("LABiometryType"))
        #expect(!source.contains("LAPolicy"))
        #expect(!source.contains("canEvaluatePolicy"))
        #expect(!source.contains("evaluatePolicy"))
    }

    @Test("Lifecycle observer clears sensitive grace on app and system boundaries")
    func lifecycleObserverClearsSensitiveGraceOnBoundaries() async throws {
        let authenticator = FakeAuthenticator(results: [true, true, true])
        let gate = SovereignGate(authenticator: authenticator)
        let observer = SovereignGateLifecycleObserver()
        let applicationCenter = NotificationCenter()
        let workspaceCenter = NotificationCenter()
        let category = SovereignGateCategory(rawValue: "vault-export")
        let start = Date(timeIntervalSince1970: 7_000)

        observer.start(
            gate: gate,
            applicationCenter: applicationCenter,
            workspaceCenter: workspaceCenter
        )

        #expect(await gate.confirm(.biometric(category: category), reason: "Export vault", now: start) == .allowed)
        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Export within grace",
                now: start.addingTimeInterval(10)
            ) == .allowed
        )
        #expect(authenticator.requests.count == 1)

        applicationCenter.post(name: NSApplication.didResignActiveNotification, object: nil)
        try await Task.sleep(for: .milliseconds(10))
        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Export after app resign",
                now: start.addingTimeInterval(20)
            ) == .allowed
        )
        #expect(authenticator.requests.count == 2)

        workspaceCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        try await Task.sleep(for: .milliseconds(10))
        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Export after sleep",
                now: start.addingTimeInterval(30)
            ) == .allowed
        )
        #expect(authenticator.requests.count == 3)
    }

    @Test("Lifecycle observer stop removes security boundary notifications")
    func lifecycleObserverStopRemovesNotifications() async throws {
        let authenticator = FakeAuthenticator(results: [true])
        let gate = SovereignGate(authenticator: authenticator)
        let observer = SovereignGateLifecycleObserver()
        let applicationCenter = NotificationCenter()
        let workspaceCenter = NotificationCenter()
        let category = SovereignGateCategory(rawValue: "oauth")
        let start = Date(timeIntervalSince1970: 8_000)

        observer.start(
            gate: gate,
            applicationCenter: applicationCenter,
            workspaceCenter: workspaceCenter
        )
        #expect(await gate.confirm(.biometric(category: category), reason: "Grant OAuth", now: start) == .allowed)

        observer.stop()
        applicationCenter.post(name: NSApplication.didResignActiveNotification, object: nil)
        workspaceCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        try await Task.sleep(for: .milliseconds(10))

        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Grant OAuth within uncleared grace",
                now: start.addingTimeInterval(10)
            ) == .allowed
        )
        #expect(authenticator.requests.count == 1)
    }

    @Test("App bootstrap owns the shared Sovereign Gate lifecycle")
    func appBootstrapOwnsSharedSovereignGateLifecycle() throws {
        let bootstrap = try #require(AppBootstrap.shared)

        #expect(bootstrap.isSovereignGateLifecycleObserverStarted)
    }
}
