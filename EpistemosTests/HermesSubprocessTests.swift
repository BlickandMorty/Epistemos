import Testing
@testable import Epistemos
import Foundation

// MARK: - HermesConfig Tests

@Suite("HermesConfig")
struct HermesConfigTests {
    @Test("Default config resolves Python path")
    func defaultConfigResolves() {
        let config = HermesConfig.resolve()
        #expect(!config.pythonPath.isEmpty)
        #expect(!config.environment.isEmpty)
    }

    @Test("Default config uses app-scoped Hermes home")
    func defaultHermesHomeIsAppScoped() {
        let config = HermesConfig.resolve()
        #expect(config.hermesHomeURL.path.contains("Application Support"))
        #expect(config.hermesHomeURL.path.contains("Epistemos/Hermes"))
    }

    @Test("Config launches the Epistemos Hermes bridge entrypoint")
    func usesEpistemosBridgeEntrypoint() {
        let config = HermesConfig.resolve()
        #expect(config.bridgeScriptURL.lastPathComponent == "epistemos_bridge.py")
        #expect(config.launchArguments.contains(config.bridgeScriptURL.path))
    }

    @Test("Bootstrap config enables Hermes learning defaults")
    func bootstrapConfigEnablesLearningDefaults() {
        let contents = HermesConfig.defaultBootstrapConfig()
        #expect(contents.contains("memory_enabled: true"))
        #expect(contents.contains("user_profile_enabled: true"))
        #expect(contents.contains("creation_nudge_interval: 15"))
    }

    @Test("Preferred Python path uses app-scoped Hermes venv first")
    func preferredPythonPathPrefersHermesVenv() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let binDirectory = tempRoot.appendingPathComponent(".venv/bin", isDirectory: true)
        let pythonURL = binDirectory.appendingPathComponent("python")

        try FileManager.default.createDirectory(
            at: binDirectory,
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: pythonURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: pythonURL.path
        )
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let path = HermesConfig.preferredPythonPath(hermesHomeURL: tempRoot)
        #expect(path == pythonURL.path)
    }

    @Test("Resolve finds bundled Hermes runtime before falling back to the bundle parent")
    func resolveFindsBundledHermesRuntime() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let appBundle = tempRoot
            .appendingPathComponent("Epistemos.app", isDirectory: true)
        let bundledRuntime = appBundle
            .appendingPathComponent("Contents/Resources/AgentRuntime/hermes-agent", isDirectory: true)
        try makeHermesRuntime(at: bundledRuntime)

        let resolved = HermesConfig.resolveHermesAgentDirectory(
            bundleURL: appBundle,
            currentDirectoryURL: tempRoot
        )

        #expect(resolved.standardizedFileURL == bundledRuntime.standardizedFileURL)
    }

    @Test("Resolve finds repo Hermes runtime from the current working tree when app bundle has none")
    func resolveFindsRepoHermesRuntimeFromCurrentDirectory() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let repoRoot = tempRoot.appendingPathComponent("Epistemos", isDirectory: true)
        let runtime = repoRoot.appendingPathComponent("hermes-agent", isDirectory: true)
        let nestedWorkingDirectory = repoRoot.appendingPathComponent("Epistemos/App", isDirectory: true)
        try makeHermesRuntime(at: runtime)
        try FileManager.default.createDirectory(
            at: nestedWorkingDirectory,
            withIntermediateDirectories: true
        )

        let detachedBundle = tempRoot
            .appendingPathComponent("DerivedData/Build/Products/Debug/Epistemos.app", isDirectory: true)
        try FileManager.default.createDirectory(
            at: detachedBundle,
            withIntermediateDirectories: true
        )

        let resolved = HermesConfig.resolveHermesAgentDirectory(
            bundleURL: detachedBundle,
            currentDirectoryURL: nestedWorkingDirectory
        )

        #expect(resolved.standardizedFileURL == runtime.standardizedFileURL)
    }

    @Test("Config has expected default model")
    func defaultModel() {
        let config = HermesConfig.resolve()
        #expect(config.model == "anthropic/claude-opus-4.6")
    }

    @Test("Config max turns is positive")
    func maxTurnsPositive() {
        let config = HermesConfig.resolve()
        #expect(config.maxTurns > 0)
    }

    @Test("Scaffolding upgrades legacy generated bootstrap config")
    func scaffoldUpgradesLegacyBootstrapConfig() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        try FileManager.default.createDirectory(
            at: tempRoot,
            withIntermediateDirectories: true
        )

        let legacyConfig = """
        model:
          default: "anthropic/claude-sonnet-4-6"
          provider: "auto"

        terminal:
          backend: "local"
          cwd: "."
          timeout: 180
          lifetime_seconds: 300

        memory:
          memory_enabled: true
          user_profile_enabled: true
          memory_char_limit: 2200
          user_char_limit: 1375
          nudge_interval: 10
          flush_min_turns: 6

        skills:
          creation_nudge_interval: 15

        session_reset:
          mode: both
          idle_minutes: 1440
          at_hour: 4
        """

        let configURL = tempRoot.appendingPathComponent("config.yaml")
        try Data(legacyConfig.utf8).write(to: configURL, options: .atomic)

        let config = HermesConfig(
            pythonPath: "/usr/bin/python3",
            hermesAgentDir: URL(fileURLWithPath: "/tmp"),
            model: "anthropic/claude-opus-4.6",
            maxTurns: 30,
            environment: ["HERMES_HOME": tempRoot.path]
        )

        try config.ensureHermesHomeScaffold()

        let upgraded = try String(contentsOf: configURL, encoding: .utf8)
        #expect(upgraded.contains("anthropic/claude-opus-4.6"))
        #expect(!upgraded.contains("anthropic/claude-sonnet-4-6"))
    }

    @Test("Cloud OpenAI selections route Hermes through the direct OpenAI endpoint")
    func openAISelectionUsesDirectOpenAIRuntime() throws {
        let route = HermesRuntimeRoute.resolve(
            for: .cloud(.openAIGPT41Mini),
            apiKeyLookup: { provider in
                provider == .openAI ? "sk-openai" : nil
            }
        )

        let resolved = try #require(route)
        #expect(resolved.model == "gpt-4.1-mini")
        #expect(resolved.requestedProvider == "custom")
        #expect(resolved.baseURL == "https://api.openai.com/v1")
        #expect(resolved.apiMode == "codex_responses")
        #expect(resolved.environmentOverrides["OPENAI_API_KEY"] == "sk-openai")
        #expect(resolved.environmentOverrides["OPENROUTER_API_KEY"] == "")
    }

    @Test("Cloud Anthropic selections route Hermes through native Anthropic")
    func anthropicSelectionUsesNativeAnthropicRuntime() throws {
        let route = HermesRuntimeRoute.resolve(
            for: .cloud(.anthropicClaudeSonnet4),
            apiKeyLookup: { provider in
                provider == .anthropic ? "sk-ant-api03-test" : nil
            }
        )

        let resolved = try #require(route)
        #expect(resolved.model == "claude-sonnet-4-20250514")
        #expect(resolved.requestedProvider == "anthropic")
        #expect(resolved.baseURL == "https://api.anthropic.com")
        #expect(resolved.apiMode == "anthropic_messages")
        #expect(resolved.environmentOverrides["ANTHROPIC_API_KEY"] == "sk-ant-api03-test")
        #expect(resolved.environmentOverrides["OPENAI_API_KEY"] == "")
    }

    @Test("Cloud Gemini selections route Hermes through Google's OpenAI-compatible endpoint")
    func googleSelectionUsesOpenAICompatibilityRuntime() throws {
        let route = HermesRuntimeRoute.resolve(
            for: .cloud(.googleGemini25Flash),
            apiKeyLookup: { provider in
                provider == .google ? "gsk_google_test" : nil
            }
        )

        let resolved = try #require(route)
        #expect(resolved.model == "gemini-2.5-flash")
        #expect(resolved.requestedProvider == "custom")
        #expect(resolved.baseURL == "https://generativelanguage.googleapis.com/v1beta/openai/")
        #expect(resolved.apiMode == "chat_completions")
        #expect(resolved.environmentOverrides["OPENAI_API_KEY"] == "gsk_google_test")
        #expect(resolved.environmentOverrides["GOOGLE_API_KEY"] == "gsk_google_test")
    }

    @Test("Local selections do not resolve to Hermes cloud runtime")
    func localSelectionDoesNotUseHermesCloudRuntime() {
        let route = HermesRuntimeRoute.resolve(
            for: .localQwen(LocalTextModelID.qwen35_4B4Bit.rawValue),
            apiKeyLookup: { _ in nil }
        )

        #expect(route == nil)
    }
}

private func makeHermesRuntime(at root: URL) throws {
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    try Data("#!/usr/bin/env python3\n".utf8).write(
        to: root.appendingPathComponent("run_agent.py"),
        options: .atomic
    )
    try Data("#!/usr/bin/env python3\n".utf8).write(
        to: root.appendingPathComponent("epistemos_bridge.py"),
        options: .atomic
    )
}

// MARK: - HermesProcessState Tests

@Suite("HermesProcessState")
struct HermesProcessStateTests {
    @Test("Initial state is idle")
    @MainActor
    func initialStateIdle() {
        let manager = HermesSubprocessManager()
        if case .idle = manager.processState {
            // OK
        } else {
            Issue.record("Expected idle state, got \(manager.processState)")
        }
    }

    @Test("isRunning is false when idle")
    @MainActor
    func notRunningWhenIdle() {
        let manager = HermesSubprocessManager()
        #expect(!manager.isRunning)
    }

    @Test("Terminate from idle goes to stopped")
    @MainActor
    func terminateFromIdle() {
        let manager = HermesSubprocessManager()
        manager.terminate()
        if case .stopped = manager.processState {
            // OK
        } else {
            Issue.record("Expected stopped state after terminate")
        }
    }
}

// MARK: - HermesHealthResult Tests

@Suite("HermesHealthResult")
struct HermesHealthResultTests {
    @Test("Healthy when all checks pass")
    func healthyResult() {
        let result = HermesHealthResult(
            pythonAvailable: true,
            pythonVersion: "Python 3.12.0",
            hermesAgentFound: true,
            hermesImportable: true,
            errorDetail: nil
        )
        #expect(result.isHealthy)
    }

    @Test("Not healthy when Python missing")
    func unhealthyNoPython() {
        let result = HermesHealthResult(
            pythonAvailable: false,
            pythonVersion: nil,
            hermesAgentFound: true,
            hermesImportable: false,
            errorDetail: "Python not found"
        )
        #expect(!result.isHealthy)
    }

    @Test("Not healthy when hermes-agent missing")
    func unhealthyNoHermes() {
        let result = HermesHealthResult(
            pythonAvailable: true,
            pythonVersion: "Python 3.12.0",
            hermesAgentFound: false,
            hermesImportable: false,
            errorDetail: "hermes-agent not found"
        )
        #expect(!result.isHealthy)
    }
}

// MARK: - AnyCodableValue Tests

@Suite("AnyCodableValue")
struct AnyCodableValueTests {
    @Test("Encode and decode string")
    func stringRoundTrip() throws {
        let value = AnyCodableValue.string("hello")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        #expect(decoded == .string("hello"))
    }

    @Test("Encode and decode int")
    func intRoundTrip() throws {
        let value = AnyCodableValue.int(42)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        #expect(decoded == .int(42))
    }

    @Test("Encode and decode bool")
    func boolRoundTrip() throws {
        let value = AnyCodableValue.bool(true)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        #expect(decoded == .bool(true))
    }

    @Test("Encode and decode null")
    func nullRoundTrip() throws {
        let value = AnyCodableValue.null
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        #expect(decoded == .null)
    }

    @Test("Encode and decode dictionary")
    func dictionaryRoundTrip() throws {
        let value = AnyCodableValue.dictionary([
            "name": .string("test"),
            "count": .int(5),
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("Encode and decode array")
    func arrayRoundTrip() throws {
        let value = AnyCodableValue.array([.string("a"), .int(1), .bool(false)])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        #expect(decoded == value)
    }
}

// MARK: - HermesMCPClient Tests

@Suite("HermesMCPClient")
struct HermesMCPClientTests {
    @Test("writeLine throws when not running")
    @MainActor
    func writeLineThrowsWhenNotRunning() {
        let manager = HermesSubprocessManager()
        #expect(throws: HermesSubprocessError.self) {
            try manager.writeLine("{}")
        }
    }

    @Test("Launch fails with bad Python path")
    @MainActor
    func launchFailsBadPython() async {
        let config = HermesConfig(
            pythonPath: "/nonexistent/python",
            hermesAgentDir: URL(fileURLWithPath: "/tmp"),
            model: "test",
            maxTurns: 1,
            environment: [:]
        )
        let manager = HermesSubprocessManager(config: config)
        do {
            try await manager.launch()
            Issue.record("Expected launch to throw")
        } catch {
            // Expected: pythonNotFound
        }
    }

    @Test("Launch fails with bad hermes path")
    @MainActor
    func launchFailsBadHermes() async {
        let config = HermesConfig(
            pythonPath: "/usr/bin/python3",
            hermesAgentDir: URL(fileURLWithPath: "/nonexistent/hermes-agent"),
            model: "test",
            maxTurns: 1,
            environment: [:]
        )
        let manager = HermesSubprocessManager(config: config)
        do {
            try await manager.launch()
            Issue.record("Expected launch to throw")
        } catch {
            // Expected: hermesAgentNotFound
        }
    }
}

// MARK: - EpistemosMCPServer Tests

@Suite("EpistemosMCPServer")
struct EpistemosMCPServerTests {
    @Test("Server registers builtin handlers")
    @MainActor
    func builtinHandlers() {
        let manager = HermesSubprocessManager()
        let server = EpistemosMCPServer(subprocessManager: manager)
        // Just verify it initializes without crashing
        #expect(String(describing: type(of: server)) == "EpistemosMCPServer")
    }

    @Test("Server handles malformed JSON gracefully")
    @MainActor
    func malformedJsonHandled() {
        let manager = HermesSubprocessManager()
        let server = EpistemosMCPServer(subprocessManager: manager)
        // Should not crash
        server.handleRequestLine("not json at all")
        server.handleRequestLine("")
        server.handleRequestLine("{}")
    }

    @Test("Register custom tool handler")
    @MainActor
    func registerCustomTool() {
        let manager = HermesSubprocessManager()
        let server = EpistemosMCPServer(subprocessManager: manager)
        server.registerTool(
            name: "test_tool",
            description: "A test tool",
            inputSchema: ["type": .string("object")]
        ) { _ in
            .success(.string("test result"))
        }
        // Tool registered without crashing
    }
}

// MARK: - HermesSubprocessError Tests

@Suite("HermesSubprocessError")
struct HermesSubprocessErrorTests {
    @Test("Error descriptions are non-empty")
    func errorDescriptions() {
        let errors: [HermesSubprocessError] = [
            .pythonNotFound("/usr/bin/python3"),
            .hermesAgentNotFound(URL(fileURLWithPath: "/tmp")),
            .bridgeScriptNotFound(URL(fileURLWithPath: "/tmp/epistemos_bridge.py")),
            .alreadyRunning,
            .launchFailed("test"),
            .notRunning,
            .terminationTimeout,
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}

@Suite("Hermes Agent Sessions")
struct HermesAgentSessionTests {
    @Test("Bridge session payload parses into a summary")
    func sessionPayloadParsesIntoSummary() throws {
        let payload: [String: Any] = [
            "session_id": "session-123",
            "cwd": "/tmp/runtime",
            "model": "gpt-4.1-mini",
            "history_len": 7,
            "is_active": true,
            "title": "auth refactor",
            "preview": "Help me refactor the auth module please",
            "last_active": 123.0,
        ]

        let summary = try #require(
            AgentSessionSummary(payload: payload, activeSessionID: "session-123")
        )

        #expect(summary.id == "session-123")
        #expect(summary.cwd == "/tmp/runtime")
        #expect(summary.model == "gpt-4.1-mini")
        #expect(summary.historyCount == 7)
        #expect(summary.isActive)
        #expect(summary.title == "auth refactor")
        #expect(summary.preview == "Help me refactor the auth module please")
        #expect(summary.lastActive?.timeIntervalSince1970 == 123.0)
    }

    @Test("Bridge history payload renders user assistant and tool transcript blocks")
    func historyPayloadBuildsRenderedBlocks() throws {
        let payload: [[String: Any]] = [
            [
                "role": "user",
                "content": "hello",
            ],
            [
                "role": "assistant",
                "content": "hi there",
                "reasoning": "Restore the saved context first.",
            ],
            [
                "role": "tool",
                "tool_name": "search_files",
                "content": "Found 3 matches",
            ],
        ]

        let messages = try payload.map {
            try #require(AgentSessionMessage(payload: $0))
        }
        let blocks = RenderedBlock.sessionHistory(messages)

        #expect(blocks.count == 4)
        #expect(blocks[0] == .userPrompt("hello"))
        #expect(blocks[1] == .thinking(text: "Restore the saved context first.", tokenCount: 8))
        #expect(blocks[2] == .text("hi there"))
        #expect(
            blocks[3] == .toolExecution(
                name: "search_files",
                input: "",
                result: "Found 3 matches",
                isError: false
            )
        )
    }

    @Test("Informational Hermes slash commands keep their transient response visible")
    func informationalSlashCommandsKeepTransientResponseVisible() {
        #expect(!HermesSessionRefreshPolicy.shouldHydrateSurface(afterSubmittedPrompt: "/help"))
        #expect(!HermesSessionRefreshPolicy.shouldHydrateSurface(afterSubmittedPrompt: "/tools"))
        #expect(!HermesSessionRefreshPolicy.shouldHydrateSurface(afterSubmittedPrompt: "/context"))
        #expect(!HermesSessionRefreshPolicy.shouldHydrateSurface(afterSubmittedPrompt: "/version"))
        #expect(!HermesSessionRefreshPolicy.shouldHydrateSurface(afterSubmittedPrompt: "/model"))
        #expect(!HermesSessionRefreshPolicy.shouldHydrateSurface(afterSubmittedPrompt: "/model gpt-4.1-mini"))
    }

    @Test("Mutating Hermes slash commands still rehydrate the session surface")
    func mutatingSlashCommandsStillHydrateSessionSurface() {
        #expect(HermesSessionRefreshPolicy.shouldHydrateSurface(afterSubmittedPrompt: "write a summary"))
        #expect(HermesSessionRefreshPolicy.shouldHydrateSurface(afterSubmittedPrompt: "/reset"))
        #expect(HermesSessionRefreshPolicy.shouldHydrateSurface(afterSubmittedPrompt: "/compact"))
        #expect(HermesSessionRefreshPolicy.shouldHydrateSurface(afterSubmittedPrompt: "   "))
    }
}
