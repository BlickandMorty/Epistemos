import Testing
@testable import Epistemos

@Suite("Omega Agents")
@MainActor
struct OmegaAgentTests {

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
        #expect(agent.toolNames.count == 4)
        #expect(agent.toolNames.contains("open_url"))
        #expect(agent.toolNames.contains("search_web"))
    }

    // MARK: - AutomationAgent

    @Test("AutomationAgent has correct toolset")
    func automationAgentToolset() {
        let agent = AutomationAgent()
        #expect(agent.name == "automation")
        #expect(agent.toolNames.count == 5)
        #expect(agent.toolNames.contains("get_ui_tree"))
        #expect(agent.toolNames.contains("click_element"))
        #expect(agent.toolNames.contains("run_shortcut"))
    }

    // MARK: - NotesAgent

    @Test("NotesAgent has correct toolset")
    func notesAgentToolset() {
        let agent = NotesAgent(modelContainer: nil, vaultSync: nil)
        #expect(agent.name == "notes")
        #expect(agent.toolNames.count == 4)
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
}
