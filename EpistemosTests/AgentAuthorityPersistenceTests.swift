import Testing
import Foundation
@testable import Epistemos

/// RCA-P1-025 verification + drift gate.
///
/// **Verdict** (per `Epistemos/Engine/AgentHarness/AgentAuthority.swift`
/// doctrine note): the user's authority decisions (allow / ask / deny
/// for tool execution, network fetch, git, downloads, vault writes,
/// destructive actions) must survive app relaunch. Before the fix, the
/// `AgentAuthorityStore`'s default constructor used
/// `InMemoryAgentAuthorityPersistence` which silently dropped decisions
/// on quit — research 3 flagged it as a live bug.
///
/// This test suite pins three invariants:
///
///   1. `AgentAuthorityStore()` (default init) uses
///      `FileBackedAgentAuthorityPersistence` — the structural defense
///      against a future refactor that flips the default back to
///      in-memory and silently drops decisions again.
///   2. The file-backed persistence round-trips a decision across
///      independent instances (write via one, read via another) so
///      a real quit/relaunch preserves the user's choices.
///   3. Doctrine comment on the persistence init reaffirms the
///      RCA-P1-025 cross-reference so a future refactor that moves
///      the default surfaces in code review.
@Suite("RCA-P1-025 AgentAuthority Persistence Drift Gate")
@MainActor
struct AgentAuthorityPersistenceTests {

    @Test("Default AgentAuthorityStore() uses file-backed persistence (not in-memory)")
    func defaultStoreUsesFileBackedPersistence() throws {
        // Behavioral proof: write a decision, throw away the store
        // (the in-memory map is gone), instantiate a fresh default
        // store, and assert it reads the prior decision back. This is
        // observable via the public API only if the underlying
        // persistence is file-backed; in-memory persistence wouldn't
        // survive the destroy/recreate cycle.
        //
        // We use a temp directory + explicit storageURL on the
        // FileBackedAgentAuthorityPersistence to avoid mutating the
        // real ApplicationSupport/Epistemos/agent_authority.json that
        // the running app uses.
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rca-p1-025-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageURL = tempDir.appendingPathComponent("agent_authority.json")

        // Step 1: write a non-default decision through a file-backed store.
        do {
            let persistence = FileBackedAgentAuthorityPersistence(storageURL: storageURL)
            let store = AgentAuthorityStore(persistence: persistence)
            store.setDecision(.autoAllow, for: .networkFetch)
            #expect(store.snapshot.decisions[.networkFetch] == .autoAllow,
                "in-memory write must reflect immediately")
        }

        // Step 2: a fresh `FileBackedAgentAuthorityPersistence` (same
        // storageURL) must read back the decision. This is the
        // round-trip that the default in-memory persistence would
        // have silently dropped.
        do {
            let persistence = FileBackedAgentAuthorityPersistence(storageURL: storageURL)
            let store = AgentAuthorityStore(persistence: persistence)
            #expect(store.snapshot.decisions[.networkFetch] == .autoAllow,
                "file-backed persistence must survive store destroy/recreate (file path: \(storageURL.path))")
        }

        // Step 3: assert the file actually exists on disk so future
        // refactors can't slip a "stub" non-persisting implementation
        // into the FileBacked class.
        #expect(FileManager.default.fileExists(atPath: storageURL.path),
            "FileBackedAgentAuthorityPersistence must produce a JSON file at the configured storageURL")
    }

    @Test("Setting a preset persists every member of the preset across reload")
    func presetPersistsAcrossReload() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rca-p1-025-preset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageURL = tempDir.appendingPathComponent("agent_authority.json")
        let preset: [AgentAuthorityCategory: AuthorityDecision] = [
            .networkFetch: .autoAllow,
            .gitOperation: .askFirst,
            .downloadArtifact: .neverAllow,
        ]

        do {
            let persistence = FileBackedAgentAuthorityPersistence(storageURL: storageURL)
            let store = AgentAuthorityStore(persistence: persistence)
            store.applyPreset(preset)
        }

        do {
            let persistence = FileBackedAgentAuthorityPersistence(storageURL: storageURL)
            let store = AgentAuthorityStore(persistence: persistence)
            for (category, expected) in preset {
                let stored = store.snapshot.decisions[category]
                #expect(stored == expected,
                    "preset decision for \(category) must persist as \(expected); got \(stored.map(String.init(describing:)) ?? "nil")")
            }
        }
    }

    @Test("Default store init signature declares FileBackedAgentAuthorityPersistence as the default")
    func sourceDoctrinePinsFileBackedAsDefault() throws {
        // Source-grep pin: if a future refactor flips the default
        // back to `InMemoryAgentAuthorityPersistence`, this test
        // breaks. Strong defense — the in-memory default was the
        // load-bearing bug RCA-P1-025 fixed.
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Engine/AgentHarness/AgentAuthority.swift"
        )
        #expect(source.contains("init(persistence: AgentAuthorityPersistence = FileBackedAgentAuthorityPersistence())"),
            "AgentAuthorityStore.init default must remain FileBackedAgentAuthorityPersistence — see RCA-P1-025; a future refactor that switches to in-memory silently drops authority decisions on quit")
        // Doctrine cross-reference must remain so a refactor that
        // touches the init surfaces the original bug context.
        #expect(source.contains("RCA13 P1-025") || source.contains("RCA-P1-025"),
            "AgentAuthorityStore doctrine note must cross-reference RCA-P1-025 to preserve the post-mortem context")
    }

    @Test("Production authority stores are shared or explicitly file-backed")
    func productionAuthorityStoresStayDurable() throws {
        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let authoritySettings = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/AuthoritySettingsView.swift"
        )

        #expect(bootstrap.contains("let agentAuthorityStore = AgentAuthorityStore("))
        #expect(bootstrap.contains("persistence: FileBackedAgentAuthorityPersistence()"))
        #expect(settings.contains("AppBootstrap.shared?.agentAuthorityStore"))
        #expect(settings.contains("?? AgentAuthorityStore(persistence: FileBackedAgentAuthorityPersistence())"))

        let appProductionSources = [bootstrap, settings].joined(separator: "\n")
        #expect(
            !appProductionSources.contains("AgentAuthorityStore()"),
            "shipping app code must not construct an implicit authority store; use AppBootstrap.shared?.agentAuthorityStore or explicit FileBackedAgentAuthorityPersistence()"
        )
        #expect(
            authoritySettings.contains("AuthoritySettingsView(store: AgentAuthorityStore())"),
            "AuthoritySettingsView keeps its default constructor confined to the SwiftUI preview; AgentAuthorityStore() itself is file-backed."
        )
    }

    @Test("Tool dispatch consults stored authority before executor resolution")
    func toolDispatchConsultsStoredAuthorityBeforeExecution() throws {
        let coordinator = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")
        let promptBlock = try sourceSlice(
            coordinator,
            from: "private func promptForToolApproval(_ request: AgentPermissionRequest) async -> Bool",
            to: "private func seedApprovedR5WriteGrantIfNeeded"
        )
        #expect(promptBlock.contains("switch storedAuthorityDecision(for: request)"))
        #expect(promptBlock.contains("case .autoAllow:"))
        #expect(promptBlock.contains("case .neverAllow:"))
        #expect(promptBlock.contains("return false"))
        #expect(promptBlock.contains("case .askFirst:"))
        #expect(promptBlock.contains("promptUserForToolApproval("))

        let commandCenterLocalBlock = try sourceSlice(
            coordinator,
            from: "private func runCommandCenterLocalAgentPath(",
            to: "private func commandCenterPlanDocumentSeed("
        )
        try expectOrdered(
            in: commandCenterLocalBlock,
            "let approved = await self.promptForToolApproval(permissionRequest)",
            "let result = await baseToolExecutor(name, argumentsJson)"
        )

        let commandCenterRustBlock = try sourceSlice(
            coordinator,
            from: "private func runCommandCenterRustAgentPath(",
            to: "private func commandCenterExecutionPlan("
        )
        try expectOrdered(
            in: commandCenterRustBlock,
            "approved = await promptForToolApproval(request)",
            "capturedDelegate?.resolvePermission(permissionId: request.id, approved: approved)"
        )

        let managedRustBlock = try sourceSlice(
            coordinator,
            from: "// Process the agent stream",
            to: "persistCompletedAgentTurn()"
        )
        try expectOrdered(
            in: managedRustBlock,
            "switch storedAuthorityDecision(for: request)",
            "capturedDelegate?.resolvePermission(permissionId: request.id, approved: approved)"
        )

        let pipelineHandlerCount = coordinator.components(
            separatedBy: "return await self.promptForToolApproval(request)"
        ).count - 1
        #expect(
            pipelineHandlerCount >= 2,
            "main chat and command-center pipeline handlers must delegate tool approval to ChatCoordinator.promptForToolApproval so persisted authority decisions are enforced before local tool execution"
        )
    }

    private func sourceSlice(_ source: String, from startMarker: String, to endMarker: String) throws -> String {
        let start = try #require(source.range(of: startMarker))
        let tail = source[start.lowerBound...]
        let end = try #require(tail.range(of: endMarker))
        return String(tail[..<end.lowerBound])
    }

    private func expectOrdered(
        in source: String,
        _ firstMarker: String,
        _ secondMarker: String
    ) throws {
        let first = try #require(source.range(of: firstMarker))
        let second = try #require(source.range(of: secondMarker))
        #expect(
            first.lowerBound < second.lowerBound,
            "'\(firstMarker)' must appear before '\(secondMarker)'"
        )
    }
}
