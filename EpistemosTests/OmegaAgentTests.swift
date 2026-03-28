import Foundation
import SwiftData
import Testing
@testable import Epistemos

@Suite("Omega Agents")
@MainActor
struct OmegaAgentTests {
    private final class NotificationFlag: Sendable {
        nonisolated(unsafe) var value = false
    }

    private func makeNotesContainer() throws -> ModelContainer {
        let schema = Schema(EpistemosSchema.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeTempDirectory(prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func parseJSONObject(_ json: String) throws -> [String: Any] {
        let data = try #require(json.data(using: .utf8))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - FileAgent

    @Test("FileAgent has correct toolset")
    func fileAgentToolset() {
        let agent = FileAgent(vaultURL: nil)
        #expect(agent.name == "file")
        #expect(agent.toolNames.count == 5)
        #expect(agent.toolNames.contains("read_file"))
        #expect(agent.toolNames.contains("write_file"))
        #expect(agent.toolNames.contains("delete_file"))
    }

    @Test("FileAgent fails gracefully without vault")
    func fileAgentNoVault() async throws {
        let agent = FileAgent(vaultURL: nil)
        let step = AgentStep(
            description: "Read file",
            assignedAgent: "file",
            toolName: "read_file",
            argumentsJson: "{\"path\":\"test.txt\"}"
        )
        let result = try await agent.execute(step: step)
        #expect(!result.success)
        #expect(result.error?.contains("No vault") == true)
    }

    @Test("FileAgent rejects paths outside vault")
    func fileAgentPathBoundary() async throws {
        let vault = URL(fileURLWithPath: "/tmp/test-vault-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vault) }

        let agent = FileAgent(vaultURL: vault)
        let step = AgentStep(
            description: "Escape vault",
            assignedAgent: "file",
            toolName: "read_file",
            argumentsJson: "{\"path\":\"../../etc/passwd\"}"
        )
        let result = try await agent.execute(step: step)
        // The path resolves inside vault (appendingPathComponent normalizes),
        // but the file won't exist — either path rejection or file-not-found error
        #expect(!result.success)
    }

    @Test("FileAgent lists files in vault")
    func fileAgentListFiles() async throws {
        let vault = URL(fileURLWithPath: "/tmp/test-vault-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try "hello".write(to: vault.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: vault) }

        let agent = FileAgent(vaultURL: vault)
        let step = AgentStep(
            description: "List vault",
            assignedAgent: "file",
            toolName: "list_files",
            argumentsJson: "{\"path\":\".\"}"
        )
        let result = try await agent.execute(step: step)
        #expect(result.success)
        #expect(result.outputJson.contains("test.txt"))
    }

    // MARK: - TerminalAgent

    @Test("TerminalAgent has correct toolset")
    func terminalAgentToolset() {
        let agent = TerminalAgent()
        #expect(agent.name == "terminal")
        #expect(agent.toolNames == ["run_command"])
    }

    @Test("TerminalAgent executes allowed command")
    func terminalAgentAllowed() async throws {
        let agent = TerminalAgent()
        let step = AgentStep(
            description: "Echo test",
            assignedAgent: "terminal",
            toolName: "run_command",
            argumentsJson: "{\"command\":\"echo hello\"}"
        )
        let result = try await agent.execute(step: step)
        #expect(result.success)
        #expect(result.outputJson.contains("hello"))
    }

    @Test("TerminalAgent rejects disallowed command")
    func terminalAgentDisallowed() async throws {
        let agent = TerminalAgent(allowedCommands: ["echo", "ls"])
        let step = AgentStep(
            description: "Run rm",
            assignedAgent: "terminal",
            toolName: "run_command",
            argumentsJson: "{\"command\":\"rm -rf /\"}"
        )
        let result = try await agent.execute(step: step)
        #expect(!result.success)
        #expect(result.error?.contains("allow-list") == true)
    }

    @Test("TerminalAgent fails on missing command argument")
    func terminalAgentMissingArg() async throws {
        let agent = TerminalAgent()
        let step = AgentStep(
            description: "No command",
            assignedAgent: "terminal",
            toolName: "run_command",
            argumentsJson: "{}"
        )
        let result = try await agent.execute(step: step)
        #expect(!result.success)
    }

    // MARK: - SafariAgent

    @Test("SafariAgent has correct toolset")
    func safariAgentToolset() {
        let agent = SafariAgent()
        #expect(agent.name == "safari")
        #expect(agent.toolNames.count == 6)
        #expect(agent.toolNames.contains("open_url"))
        #expect(agent.toolNames.contains("get_page_url"))
        #expect(agent.toolNames.contains("get_page_title"))
        #expect(agent.toolNames.contains("search_web"))
        #expect(agent.toolNames.contains("readpagecontent"))
        #expect(agent.toolNames.contains("searchpapers"))
    }

    // MARK: - AutomationAgent

    @Test("AutomationAgent has correct toolset")
    func automationAgentToolset() {
        let agent = AutomationAgent()
        #expect(agent.name == "automation")
        #expect(agent.toolNames.count == 5)
        #expect(agent.toolNames.contains("get_ui_tree"))
        #expect(agent.toolNames.contains("click_element"))
        #expect(agent.toolNames.contains("type_text"))
        #expect(agent.toolNames.contains("press_key"))
        #expect(agent.toolNames.contains("run_shortcut"))
    }

    @Test("Omega tool registry includes browser, terminal, and computer-control tools")
    func omegaToolRegistryCoverage() {
        let names = Set(OmegaToolRegistry.all.map(\.name))

        #expect(names.contains("open_url"))
        #expect(names.contains("get_page_url"))
        #expect(names.contains("get_page_title"))
        #expect(names.contains("search_web"))
        #expect(names.contains("readpagecontent"))
        #expect(names.contains("searchpapers"))
        #expect(names.contains("run_command"))
        #expect(names.contains("get_ui_tree"))
        #expect(names.contains("click_element"))
        #expect(names.contains("type_text"))
        #expect(names.contains("press_key"))
        #expect(names.contains("run_shortcut"))
    }

    // MARK: - NotesAgent

    @Test("NotesAgent has correct toolset")
    func notesAgentToolset() {
        let agent = NotesAgent(modelContainer: nil, vaultSync: nil)
        #expect(agent.name == "notes")
        #expect(agent.toolNames.count == 9)
        #expect(agent.toolNames.contains("collectsnippet"))
        #expect(agent.toolNames.contains("savecitation"))
        #expect(agent.toolNames.contains("createresearchnote"))
        #expect(agent.toolNames.contains("analyzecontradiction"))
        #expect(agent.toolNames.contains("scoreevidence"))
    }

    @Test("NotesAgent fails gracefully without model container")
    func notesAgentNoContainer() async throws {
        let agent = NotesAgent(modelContainer: nil, vaultSync: nil)
        let step = AgentStep(
            description: "Create note",
            assignedAgent: "notes",
            toolName: "create_note",
            argumentsJson: "{\"title\":\"Test\"}"
        )
        let result = try await agent.execute(step: step)
        #expect(!result.success)
        #expect(result.error?.contains("container") == true)
    }

    @Test("NotesAgent collectsnippet returns snippet payload for research orchestration")
    func notesAgentCollectSnippetIncludesTrackedFields() async throws {
        let container = try makeNotesContainer()
        let suiteName = "OmegaAgentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let vaultURL = try makeTempDirectory(prefix: "omega-agent-vault")
        let storageURL = try makeTempDirectory(prefix: "omega-agent-bodies")
        defer {
            NoteFileStorage.setStorageDirectoryOverrideForTesting(nil)
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: storageURL)
        }

        NoteFileStorage.setStorageDirectoryOverrideForTesting(storageURL)

        let sync = VaultSyncService(modelContainer: container, userDefaults: defaults)
        sync.setVaultURLForTesting(vaultURL)

        let agent = NotesAgent(modelContainer: container, vaultSync: sync)
        let snippet = "Selective state-space models reduce attention overhead."
        let step = AgentStep(
            description: "Collect research snippet",
            assignedAgent: "notes",
            toolName: "collectsnippet",
            argumentsJson: """
            {"text":"\(snippet)","sourceUrl":"https://arxiv.org/abs/2405.21060","sourceTitle":"Mamba-2"}
            """
        )

        let result = try await agent.execute(step: step)
        #expect(result.success)

        let payload = try parseJSONObject(result.outputJson)
        #expect(payload["sessionNoteId"] as? String != nil)
        #expect(payload["sourceUrl"] as? String == "https://arxiv.org/abs/2405.21060")
        #expect(payload["sourceTitle"] as? String == "Mamba-2")
        #expect(payload["text"] as? String == snippet)
    }

    @Test("NotesAgent collectsnippet flushes editor state and notifies body changes for session notes")
    func notesAgentCollectSnippetFlushesAndNotifiesSessionNote() async throws {
        let container = try makeNotesContainer()
        let suiteName = "OmegaAgentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let vaultURL = try makeTempDirectory(prefix: "omega-agent-vault")
        let storageURL = try makeTempDirectory(prefix: "omega-agent-bodies")
        defer {
            NoteFileStorage.setStorageDirectoryOverrideForTesting(nil)
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: storageURL)
        }

        NoteFileStorage.setStorageDirectoryOverrideForTesting(storageURL)

        let sync = VaultSyncService(modelContainer: container, userDefaults: defaults)
        sync.setVaultURLForTesting(vaultURL)

        let noteId = try #require(await sync.createPage(
            title: "Research Session",
            body: "# Research Session\n\nDisk body\n\n"
        ))
        let flushedBody = "# Research Session\n\nLive editor body\n\n"
        let snippet = "Selective state-space models reduce attention overhead."

        let flushRequested = NotificationFlag()
        let bodyChangeNotified = NotificationFlag()
        let flushToken = NotificationCenter.default.addObserver(
            forName: NoteFileStorage.pageBodyWillRead,
            object: nil,
            queue: nil
        ) { notification in
            guard notification.userInfo?["pageId"] as? String == noteId else { return }
            flushRequested.value = true
            NoteFileStorage.writeBody(pageId: noteId, content: flushedBody)
        }
        let changeToken = NotificationCenter.default.addObserver(
            forName: NoteFileStorage.pageBodyDidChange,
            object: nil,
            queue: nil
        ) { notification in
            guard notification.userInfo?["pageId"] as? String == noteId else { return }
            bodyChangeNotified.value = true
        }
        defer {
            NotificationCenter.default.removeObserver(flushToken)
            NotificationCenter.default.removeObserver(changeToken)
        }

        let agent = NotesAgent(modelContainer: container, vaultSync: sync)
        let step = AgentStep(
            description: "Collect research snippet",
            assignedAgent: "notes",
            toolName: "collectsnippet",
            argumentsJson: """
            {"text":"\(snippet)","sourceUrl":"https://arxiv.org/abs/2405.21060","sourceTitle":"Mamba-2","sessionNoteId":"\(noteId)"}
            """
        )

        let result = try await agent.execute(step: step)
        #expect(result.success)
        #expect(flushRequested.value)
        #expect(bodyChangeNotified.value)

        let context = container.mainContext
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate<SDPage> { $0.id == noteId })
        let page = try #require(context.fetch(descriptor).first)
        let body = page.loadBody()
        #expect(body.contains(flushedBody))
        #expect(body.contains(snippet))
    }

    @Test("NotesAgent savecitation flushes editor state and notifies body changes for session notes")
    func notesAgentSaveCitationFlushesAndNotifiesSessionNote() async throws {
        let container = try makeNotesContainer()
        let suiteName = "OmegaAgentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let vaultURL = try makeTempDirectory(prefix: "omega-agent-vault")
        let storageURL = try makeTempDirectory(prefix: "omega-agent-bodies")
        defer {
            NoteFileStorage.setStorageDirectoryOverrideForTesting(nil)
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: storageURL)
        }

        NoteFileStorage.setStorageDirectoryOverrideForTesting(storageURL)

        let sync = VaultSyncService(modelContainer: container, userDefaults: defaults)
        sync.setVaultURLForTesting(vaultURL)

        let noteId = try #require(await sync.createPage(
            title: "Research Session",
            body: "# Research Session\n\nDisk draft\n\n"
        ))
        let flushedBody = "# Research Session\n\nLive draft\n\n"

        let flushRequested = NotificationFlag()
        let bodyChangeNotified = NotificationFlag()
        let flushToken = NotificationCenter.default.addObserver(
            forName: NoteFileStorage.pageBodyWillRead,
            object: nil,
            queue: nil
        ) { notification in
            guard notification.userInfo?["pageId"] as? String == noteId else { return }
            flushRequested.value = true
            NoteFileStorage.writeBody(pageId: noteId, content: flushedBody)
        }
        let changeToken = NotificationCenter.default.addObserver(
            forName: NoteFileStorage.pageBodyDidChange,
            object: nil,
            queue: nil
        ) { notification in
            guard notification.userInfo?["pageId"] as? String == noteId else { return }
            bodyChangeNotified.value = true
        }
        defer {
            NotificationCenter.default.removeObserver(flushToken)
            NotificationCenter.default.removeObserver(changeToken)
        }

        let agent = NotesAgent(modelContainer: container, vaultSync: sync)
        let step = AgentStep(
            description: "Save citation to session note",
            assignedAgent: "notes",
            toolName: "savecitation",
            argumentsJson: """
            {"title":"Mamba-2","url":"https://arxiv.org/abs/2405.21060","authors":"Gu et al.","date":"2024","sessionNoteId":"\(noteId)"}
            """
        )

        let result = try await agent.execute(step: step)
        #expect(result.success)
        #expect(flushRequested.value)
        #expect(bodyChangeNotified.value)

        let context = container.mainContext
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate<SDPage> { $0.id == noteId })
        let page = try #require(context.fetch(descriptor).first)
        let body = page.loadBody()
        #expect(body.contains(flushedBody))
        #expect(body.contains("## Citations"))
        #expect(body.contains("https://arxiv.org/abs/2405.21060"))
    }

    @Test("NotesAgent contradiction analysis echoes compared snippets for confidence tracking")
    func notesAgentAnalyzeContradictionReturnsComparedSnippets() async throws {
        let container = try makeNotesContainer()
        let agent = NotesAgent(modelContainer: container, vaultSync: nil)
        let snippetA = "The benchmark reports revenue at $10 million."
        let snippetB = "The benchmark reports revenue at $14 million."
        let step = AgentStep(
            description: "Compare contradictory snippets",
            assignedAgent: "notes",
            toolName: "analyzecontradiction",
            argumentsJson: """
            {"snippetA":"\(snippetA)","snippetB":"\(snippetB)"}
            """
        )

        let result = try await agent.execute(step: step)
        #expect(result.success)

        let payload = try parseJSONObject(result.outputJson)
        #expect(payload["verdict"] as? String == "contradict")
        #expect(payload["snippetA"] as? String == snippetA)
        #expect(payload["snippetB"] as? String == snippetB)
    }
}
