import Testing
@testable import Epistemos
import Foundation

#if false

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

    @Test("Config exports local tool gate environment")
    func exportsLocalToolGateEnvironment() {
        let config = HermesConfig.resolve()
        let expectedHome = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let dotHermes = URL(fileURLWithPath: expectedHome, isDirectory: true)
            .appendingPathComponent(".hermes", isDirectory: true)

        #expect(config.environment["HOME"] == expectedHome)
        #expect(config.environment["HERMES_ENV_TYPE"] == "local")
        #expect(config.environment["TERMINAL_ENV"] == "local")
        #expect((config.environment["PATH"] ?? "").contains("/usr/local/bin"))
        #expect(FileManager.default.fileExists(atPath: dotHermes.path))
    }

    @Test("Tool gate keychain mappings include Browserbase credentials")
    func toolGateMappingsIncludeBrowserbaseCredentials() {
        let envVars = Set(HermesConfig.toolGateKeychainMappings.map(\.envVar))
        #expect(envVars.contains("BROWSERBASE_API_KEY"))
        #expect(envVars.contains("BROWSERBASE_PROJECT_ID"))
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

@MainActor
@Suite("StartupAutoDiscovery", .serialized)
struct StartupAutoDiscoveryTests {
    @Test("Config parser understands env style provider tables and tool tables")
    func parseConfigValuesUnderstandsCommonLayouts() {
        let contents = """
        OPENAI_API_KEY = "sk-openai"

        [providers.anthropic]
        api_key = "sk-ant"

        [tools.tavily]
        api_key = "tvly-test"

        [services.browserbase]
        project_id = "bb-project"
        """

        let values = StartupAutoDiscovery.parseConfigValues(contents)

        #expect(values["OPENAI_API_KEY"] == "sk-openai")
        #expect(values["providers.anthropic.api_key"] == "sk-ant")
        #expect(values["tools.tavily.api_key"] == "tvly-test")
        #expect(values["services.browserbase.project_id"] == "bb-project")
    }

    @Test("Discovery prefers environment without clobbering an existing keychain value")
    func discoveryPrefersEnvironmentWithoutClobberingKeychain() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let configURL = tempRoot.appendingPathComponent("config.toml")
        try Data("OPENAI_API_KEY = \"sk-config\"\n".utf8).write(to: configURL, options: .atomic)

        var fakeKeychain = [
            "epistemos.openai.apiKey": "sk-keychain",
        ]

        let report = StartupAutoDiscovery.perform(
            environment: [
                "OPENAI_API_KEY": "sk-env",
                "PATH": "/usr/bin:/bin",
            ],
            fileManager: .default,
            homeDirectoryURL: tempRoot,
            localModelRootURL: tempRoot.appendingPathComponent("Models", isDirectory: true),
            configFileURLs: [configURL],
            readFile: { try? String(contentsOf: $0, encoding: .utf8) },
            keychainLoad: { fakeKeychain[$0] },
            keychainSave: { value, key in
                fakeKeychain[key] = value
                return true
            }
        )

        let openAIStatus = try #require(
            report.credentialStatuses.first(where: { $0.envVar == "OPENAI_API_KEY" })
        )
        #expect(openAIStatus.source == .environment)
        #expect(fakeKeychain["epistemos.openai.apiKey"] == "sk-keychain")
    }

    @Test("Discovery imports config keys and reports optional tool and model availability")
    func discoveryImportsConfigKeysAndReportsOptionalAvailability() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let homeURL = tempRoot.appendingPathComponent("home", isDirectory: true)
        let configDirectory = homeURL
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("epistemos", isDirectory: true)
        let configURL = configDirectory.appendingPathComponent("config.toml")
        let browserBinDirectory = homeURL.appendingPathComponent("bin", isDirectory: true)
        let localModelRoot = tempRoot.appendingPathComponent("Models", isDirectory: true)
        let localModelURL = localModelRoot
            .appendingPathComponent("retriever", isDirectory: true)
            .appendingPathComponent("prepared-index.mlx", isDirectory: true)
        let huggingFaceModelURL = homeURL
            .appendingPathComponent(".cache", isDirectory: true)
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
            .appendingPathComponent("models--mlx-community--Qwen3.5-4B-4bit", isDirectory: true)

        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: browserBinDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: localModelURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: huggingFaceModelURL, withIntermediateDirectories: true)

        let configContents = """
        [providers.google]
        api_key = "gsk-config"

        [tools.exa]
        api_key = "exa-config"

        [services.browserbase]
        api_key = "bb-key"
        project_id = "bb-project"
        """
        try Data(configContents.utf8).write(to: configURL, options: .atomic)

        try makeExecutable(at: browserBinDirectory.appendingPathComponent("agent-browser"))

        var fakeKeychain: [String: String] = [:]
        let report = StartupAutoDiscovery.perform(
            environment: [
                "PATH": browserBinDirectory.path,
            ],
            fileManager: .default,
            homeDirectoryURL: homeURL,
            localModelRootURL: localModelRoot,
            configFileURLs: [configURL],
            readFile: { try? String(contentsOf: $0, encoding: .utf8) },
            keychainLoad: { fakeKeychain[$0] },
            keychainSave: { value, key in
                fakeKeychain[key] = value
                return true
            }
        )

        let googleStatus = try #require(
            report.credentialStatuses.first(where: { $0.envVar == "GOOGLE_API_KEY" })
        )
        let exaStatus = try #require(
            report.credentialStatuses.first(where: { $0.envVar == "EXA_API_KEY" })
        )
        let browserbaseStatus = try #require(
            report.credentialStatuses.first(where: { $0.envVar == "BROWSERBASE_PROJECT_ID" })
        )

        #expect(googleStatus.source == .configFile)
        #expect(exaStatus.source == .configFile)
        #expect(browserbaseStatus.source == .configFile)
        #expect(fakeKeychain["epistemos.google.apiKey"] == "gsk-config")
        #expect(fakeKeychain["epistemos.exa.apiKey"] == "exa-config")
        #expect(fakeKeychain["epistemos.browserbase.apiKey"] == "bb-key")
        #expect(fakeKeychain["epistemos.browserbase.projectID"] == "bb-project")
        #expect(report.browserToolAvailable)
        #expect(report.dotHermesCreated)
        #expect(FileManager.default.fileExists(atPath: report.dotHermesURL.path))
        #expect(report.localModelDirectories == [localModelURL.standardizedFileURL])
        #expect(report.huggingFaceModelDirectories == [huggingFaceModelURL.standardizedFileURL])
    }

    @Test("Discovery report deduplicates repeated credential mappings")
    func discoveryReportDeduplicatesRepeatedCredentialMappings() {
        let report = StartupAutoDiscovery.perform(
            environment: [
                "PATH": "/usr/bin:/bin",
            ],
            fileManager: .default,
            homeDirectoryURL: FileManager.default.temporaryDirectory,
            localModelRootURL: FileManager.default.temporaryDirectory,
            configFileURLs: [],
            readFile: { _ in nil },
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true }
        )

        #expect(report.missingCredentialEnvVars.count == Set(report.missingCredentialEnvVars).count)
        #expect(report.credentialStatuses.count == Set(report.credentialStatuses.map(\.envVar)).count)
        #expect(report.missingCredentialEnvVars.filter { $0 == "BROWSERBASE_API_KEY" }.count == 1)
        #expect(report.missingCredentialEnvVars.filter { $0 == "BROWSERBASE_PROJECT_ID" }.count == 1)
    }

    @Test("Bootstrap skips live auto-discovery when running under tests")
    @MainActor func bootstrapSkipsLiveAutoDiscoveryUnderTests() {
        var discoverCalled = false

        let report = AppBootstrap.startupAutoDiscoveryReportForTesting(isRunningTests: true) {
            discoverCalled = true
            return StartupAutoDiscovery.perform(
                environment: ["OPENAI_API_KEY": "sk-live"],
                fileManager: .default,
                homeDirectoryURL: FileManager.default.temporaryDirectory,
                localModelRootURL: FileManager.default.temporaryDirectory,
                configFileURLs: [],
                readFile: { _ in nil },
                keychainLoad: { _ in "sk-keychain" },
                keychainSave: { _, _ in true }
            )
        }

        #expect(!discoverCalled)
        #expect(report.credentialStatuses.allSatisfy { $0.source == .missing })
        #expect(!report.browserToolAvailable)
        #expect(!report.dotHermesCreated)
        #expect(report.localModelDirectories.isEmpty)
        #expect(report.huggingFaceModelDirectories.isEmpty)
    }

    @Test("Bootstrap still performs auto-discovery outside tests")
    @MainActor func bootstrapRunsAutoDiscoveryOutsideTests() {
        let expected = StartupAutoDiscoveryReport(
            credentialStatuses: [
                .init(
                    envVar: "OPENAI_API_KEY",
                    keychainKey: "epistemos.openai.apiKey",
                    source: .environment,
                    origin: nil
                ),
            ],
            browserToolAvailable: true,
            dotHermesCreated: true,
            dotHermesURL: URL(fileURLWithPath: "/tmp/.hermes", isDirectory: true),
            localModelDirectories: [URL(fileURLWithPath: "/tmp/models", isDirectory: true)],
            huggingFaceModelDirectories: []
        )
        var discoverCalled = false

        let report = AppBootstrap.startupAutoDiscoveryReportForTesting(isRunningTests: false) {
            discoverCalled = true
            return expected
        }

        #expect(discoverCalled)
        #expect(report == expected)
    }

    @Test("Auto-discovery helpers avoid silent filesystem and fallback search index failures")
    func autoDiscoveryHelpersAvoidSilentFilesystemFailures() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(!source.contains("try? fileManager.createDirectory(at: dotHermesURL, withIntermediateDirectories: true)"))
        #expect(!source.contains("guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),"))
        #expect(!source.contains("guard let contents = try? fileManager.contentsOfDirectory("))
        #expect(!source.contains("vaultSync.searchService ?? (try? SearchIndexService())"))
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

private func makeExecutable(at url: URL) throws {
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url, options: .atomic)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: url.path
    )
}

private func makeHealthCheckRuntime(respondsToPing: Bool) throws -> (config: HermesConfig, rootURL: URL) {
    let fm = FileManager.default
    let rootURL = fm.temporaryDirectory
        .appendingPathComponent("hermes-health-check-\(UUID().uuidString)", isDirectory: true)
    let hermesHome = rootURL.appendingPathComponent("home", isDirectory: true)
    let adapterDirectory = rootURL.appendingPathComponent("acp_adapter", isDirectory: true)
    try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
    try fm.createDirectory(at: hermesHome, withIntermediateDirectories: true)
    try fm.createDirectory(at: adapterDirectory, withIntermediateDirectories: true)

    let bridgeURL = rootURL.appendingPathComponent("epistemos_bridge.py")
    let runAgentURL = rootURL.appendingPathComponent("run_agent.py")
    let adapterInitURL = adapterDirectory.appendingPathComponent("__init__.py")
    let adapterSessionURL = adapterDirectory.appendingPathComponent("session.py")

    let bridgeScript: String
    if respondsToPing {
        bridgeScript = """
        #!/usr/bin/env python3
        import json
        import sys

        if __name__ == "__main__":
            for line in sys.stdin:
                request = json.loads(line)
                response = {
                    "jsonrpc": "2.0",
                    "result": {"ok": True},
                    "id": request.get("id"),
                }
                print(json.dumps(response), flush=True)
        """
    } else {
        bridgeScript = """
        #!/usr/bin/env python3
        import sys
        import time

        if __name__ == "__main__":
            for _line in sys.stdin:
                time.sleep(60)
        """
    }

    try Data(bridgeScript.utf8).write(to: bridgeURL, options: .atomic)
    try Data("# stub runtime\n".utf8).write(to: runAgentURL, options: .atomic)
    try Data("".utf8).write(to: adapterInitURL, options: .atomic)
    try Data("# stub session module\n".utf8).write(to: adapterSessionURL, options: .atomic)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bridgeURL.path)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runAgentURL.path)

    let resolvedPython = HermesConfig.resolve().pythonPath
    let pythonPath = fm.isExecutableFile(atPath: resolvedPython) ? resolvedPython : "/usr/bin/python3"
    let config = HermesConfig(
        pythonPath: pythonPath,
        hermesAgentDir: rootURL,
        model: "test",
        maxTurns: 1,
        environment: [
            "HERMES_HOME": hermesHome.path,
            "PYTHONUNBUFFERED": "1",
        ]
    )
    return (config, rootURL)
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
            bridgeResponsive: true,
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
            bridgeResponsive: false,
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
            bridgeResponsive: false,
            errorDetail: "hermes-agent not found"
        )
        #expect(!result.isHealthy)
    }

    @Test("Health check requires a live bridge round trip")
    func healthCheckRequiresLiveBridgeRoundTrip() async throws {
        let runtime = try makeHealthCheckRuntime(respondsToPing: false)
        defer {
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        let result = await HermesSubprocessManager.healthCheck(
            config: runtime.config,
            forceRefresh: true
        )

        #expect(result.pythonAvailable)
        #expect(result.hermesAgentFound)
        #expect(result.hermesImportable)
        #expect(!result.bridgeResponsive)
        #expect(!result.isHealthy)
        #expect(result.errorDetail?.contains("bridge probe failed") == true)
    }

    @Test("Health check reports healthy when the bridge answers ping")
    func healthCheckReportsHealthyWhenBridgeResponds() async throws {
        let runtime = try makeHealthCheckRuntime(respondsToPing: true)
        defer {
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        let result = await HermesSubprocessManager.healthCheck(
            config: runtime.config,
            forceRefresh: true
        )

        #expect(result.pythonAvailable)
        #expect(result.hermesAgentFound)
        #expect(result.hermesImportable)
        #expect(result.bridgeResponsive)
        #expect(result.isHealthy)
        #expect(result.errorDetail == nil)
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

    @Test("Cancelled send removes pending request")
    @MainActor
    func cancelledSendRemovesPendingRequest() async throws {
        let runtime = try await makeIdleRuntime()
        defer {
            runtime.manager.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        let client = HermesMCPClient(
            subprocessManager: runtime.manager,
            defaultTimeout: .seconds(60)
        )

        let sendTask = Task {
            try await client.send(method: "ping")
        }

        try await Task.sleep(for: .milliseconds(150))
        sendTask.cancel()

        do {
            _ = try await sendTask.value
            Issue.record("Expected send task to be cancelled")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Expected CancellationError, got \(error.localizedDescription)")
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(client.pendingRequestCountForTesting == 0)
    }

    @Test("Pending requests fail immediately when Hermes disconnects")
    @MainActor
    func disconnectCancelsPendingRequest() async throws {
        let runtime = try await makeIdleRuntime()
        defer {
            runtime.manager.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        let client = HermesMCPClient(
            subprocessManager: runtime.manager,
            defaultTimeout: .seconds(60)
        )
        client.attach()

        let sendTask = Task {
            try await client.send(method: "ping")
        }

        try await Task.sleep(for: .milliseconds(150))
        runtime.manager.terminate()

        do {
            _ = try await withThrowingTaskGroup(of: AnyCodableValue.self) { group in
                group.addTask { try await sendTask.value }
                group.addTask {
                    try await Task.sleep(for: .seconds(2))
                    throw TimeoutError(seconds: 2)
                }
                let result = try await group.next()
                group.cancelAll()
                return try #require(result)
            }
            Issue.record("Expected disconnect to fail the pending request")
        } catch let error as HermesMCPError {
            if case .notConnected = error {
                // Expected.
            } else {
                Issue.record("Expected notConnected, got \(error.localizedDescription)")
            }
        } catch {
            Issue.record("Expected HermesMCPError.notConnected, got \(error.localizedDescription)")
        }

        #expect(client.pendingRequestCountForTesting == 0)
    }

    @Test("Request handler registered after launch still receives stdout lines")
    @MainActor
    func requestHandlerRegisteredAfterLaunchReceivesStdout() async throws {
        let runtime = try await makeEchoRuntime()
        defer {
            runtime.manager.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        let receivedTask = Task<String, Never> {
            await withCheckedContinuation { continuation in
                runtime.manager.setRequestHandler { line in
                    continuation.resume(returning: line)
                }
            }
        }

        try runtime.manager.writeLine("{\"type\":\"ping\"}")

        let received = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { await receivedTask.value }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                throw TimeoutError(seconds: 2)
            }
            let line = try await group.next()
            group.cancelAll()
            return try #require(line)
        }

        #expect(received.contains("\"bridge_event\""))
        #expect(received.contains("\"value\":\"ok\""))
    }

    @Test("Fast Hermes crashes preserve the last stderr line for diagnostics")
    @MainActor
    func fastCrashPreservesLastStderrLine() async throws {
        let marker = "hermes-crash-marker"
        let runtime = try await makeCrashRuntime(stderrLine: marker)
        defer {
            runtime.manager.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        for _ in 0..<100 {
            if case .crashed(let exitCode, let lastStderr) = runtime.manager.processState {
                #expect(exitCode == 7)
                #expect(lastStderr.contains(marker))
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        Issue.record("Timed out waiting for Hermes to crash")
    }

    @Test("Terminate keeps relaunch blocked until Hermes actually exits")
    @MainActor
    func terminateKeepsRelaunchBlockedUntilExit() async throws {
        let runtime = try await makeSlowTerminateRuntime(graceDelaySeconds: 1.0)
        defer {
            runtime.manager.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        runtime.manager.terminate()

        do {
            try await runtime.manager.launch()
            Issue.record("Expected relaunch to stay blocked while Hermes is still terminating")
        } catch let error as HermesSubprocessError {
            if case .alreadyRunning = error {
                // Expected.
            } else {
                Issue.record("Expected alreadyRunning, got \(error.localizedDescription)")
            }
        } catch {
            Issue.record("Expected HermesSubprocessError.alreadyRunning, got \(error.localizedDescription)")
        }

        for _ in 0..<150 {
            if case .stopped = runtime.manager.processState {
                #expect(runtime.manager.pid == nil)
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        Issue.record("Timed out waiting for Hermes to finish terminating")
    }

    @Test("Restart waits for graceful Hermes shutdown before relaunching")
    @MainActor
    func restartWaitsForGracefulShutdown() async throws {
        let runtime = try await makeSlowTerminateRuntime(graceDelaySeconds: 1.0)
        defer {
            runtime.manager.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        let originalPid = try #require(runtime.manager.pid)
        try await runtime.manager.restart()
        let restartedPid = try #require(runtime.manager.pid)

        #expect(runtime.manager.isRunning)
        #expect(restartedPid != originalPid)
    }

    @Test("Terminate cleans up Hermes descendant processes")
    @MainActor
    func terminateCleansUpHermesDescendants() async throws {
        let runtime = try await makeTreeTerminateRuntime()
        defer {
            runtime.manager.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        #expect(kill(runtime.childPID, 0) == 0)

        runtime.manager.terminate()

        for _ in 0..<75 {
            if kill(runtime.childPID, 0) != 0 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(kill(runtime.childPID, 0) != 0)
    }

    @Test("Watchdog terminates Hermes when ping responses stop")
    @MainActor
    func watchdogTerminatesHungHermes() async throws {
        let runtime = try await makeIdleRuntime()
        defer {
            runtime.manager.stopWatchdog()
            runtime.manager.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        runtime.manager.startWatchdog(interval: .milliseconds(100), timeout: .milliseconds(200))

        for _ in 0..<150 {
            if case .stopped = runtime.manager.processState {
                #expect(runtime.manager.pid == nil)
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        Issue.record("Timed out waiting for watchdog to terminate hung Hermes")
    }

    @Test("Watchdog keeps Hermes alive when ping responses arrive")
    @MainActor
    func watchdogKeepsResponsiveHermesAlive() async throws {
        let runtime = try await makePingRuntime()
        defer {
            runtime.manager.stopWatchdog()
            runtime.manager.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        runtime.manager.startWatchdog(interval: .milliseconds(100), timeout: .milliseconds(200))
        try await Task.sleep(for: .milliseconds(700))

        #expect(runtime.manager.isRunning)
        #expect(runtime.manager.pid != nil)
    }

    @MainActor
    private func makeIdleRuntime() async throws -> (manager: HermesSubprocessManager, rootURL: URL) {
        let fm = FileManager.default
        let rootURL = fm.temporaryDirectory
            .appendingPathComponent("hermes-mcp-client-tests-\(UUID().uuidString)", isDirectory: true)
        let hermesHome = rootURL.appendingPathComponent("home", isDirectory: true)
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: hermesHome, withIntermediateDirectories: true)

        let bridgeURL = rootURL.appendingPathComponent("epistemos_bridge.py")
        let runAgentURL = rootURL.appendingPathComponent("run_agent.py")
        let bridgeScript = """
        #!/usr/bin/env python3
        import sys
        import time

        if __name__ == "__main__":
            for _line in sys.stdin:
                time.sleep(60)
        """
        let runAgentStub = """
        #!/usr/bin/env python3
        print("stub")
        """

        try Data(bridgeScript.utf8).write(to: bridgeURL, options: .atomic)
        try Data(runAgentStub.utf8).write(to: runAgentURL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bridgeURL.path)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runAgentURL.path)

        let pythonPath = fm.isExecutableFile(atPath: "/usr/bin/python3")
            ? "/usr/bin/python3"
            : HermesConfig.resolve().pythonPath
        let config = HermesConfig(
            pythonPath: pythonPath,
            hermesAgentDir: rootURL,
            model: "test",
            maxTurns: 1,
            environment: [
                "HERMES_HOME": hermesHome.path,
                "PYTHONUNBUFFERED": "1",
            ]
        )
        let manager = HermesSubprocessManager(config: config)
        try await manager.launch()
        return (manager, rootURL)
    }

    @MainActor
    private func makeEchoRuntime() async throws -> (manager: HermesSubprocessManager, rootURL: URL) {
        let fm = FileManager.default
        let rootURL = fm.temporaryDirectory
            .appendingPathComponent("hermes-mcp-handler-tests-\(UUID().uuidString)", isDirectory: true)
        let hermesHome = rootURL.appendingPathComponent("home", isDirectory: true)
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: hermesHome, withIntermediateDirectories: true)

        let bridgeURL = rootURL.appendingPathComponent("epistemos_bridge.py")
        let runAgentURL = rootURL.appendingPathComponent("run_agent.py")
        let bridgeScript = """
        #!/usr/bin/env python3
        import sys

        if __name__ == "__main__":
            for _line in sys.stdin:
                print('{"type":"bridge_event","value":"ok"}', flush=True)
        """
        let runAgentStub = """
        #!/usr/bin/env python3
        print("stub")
        """

        try Data(bridgeScript.utf8).write(to: bridgeURL, options: .atomic)
        try Data(runAgentStub.utf8).write(to: runAgentURL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bridgeURL.path)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runAgentURL.path)

        let pythonPath = fm.isExecutableFile(atPath: "/usr/bin/python3")
            ? "/usr/bin/python3"
            : HermesConfig.resolve().pythonPath
        let config = HermesConfig(
            pythonPath: pythonPath,
            hermesAgentDir: rootURL,
            model: "test",
            maxTurns: 1,
            environment: [
                "HERMES_HOME": hermesHome.path,
                "PYTHONUNBUFFERED": "1",
            ]
        )
        let manager = HermesSubprocessManager(config: config)
        try await manager.launch()
        return (manager, rootURL)
    }

    @MainActor
    private func makeCrashRuntime(stderrLine: String) async throws -> (manager: HermesSubprocessManager, rootURL: URL) {
        let fm = FileManager.default
        let rootURL = fm.temporaryDirectory
            .appendingPathComponent("hermes-mcp-crash-tests-\(UUID().uuidString)", isDirectory: true)
        let hermesHome = rootURL.appendingPathComponent("home", isDirectory: true)
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: hermesHome, withIntermediateDirectories: true)

        let bridgeURL = rootURL.appendingPathComponent("epistemos_bridge.py")
        let runAgentURL = rootURL.appendingPathComponent("run_agent.py")
        let bridgeScript = """
        #!/usr/bin/env python3
        import sys

        if __name__ == "__main__":
            print(\(String(reflecting: stderrLine)), file=sys.stderr, flush=True)
            raise SystemExit(7)
        """
        let runAgentStub = """
        #!/usr/bin/env python3
        print("stub")
        """

        try Data(bridgeScript.utf8).write(to: bridgeURL, options: .atomic)
        try Data(runAgentStub.utf8).write(to: runAgentURL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bridgeURL.path)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runAgentURL.path)

        let pythonPath = fm.isExecutableFile(atPath: "/usr/bin/python3")
            ? "/usr/bin/python3"
            : HermesConfig.resolve().pythonPath
        let config = HermesConfig(
            pythonPath: pythonPath,
            hermesAgentDir: rootURL,
            model: "test",
            maxTurns: 1,
            environment: [
                "HERMES_HOME": hermesHome.path,
                "PYTHONUNBUFFERED": "1",
            ]
        )
        let manager = HermesSubprocessManager(config: config)
        try await manager.launch()
        return (manager, rootURL)
    }

    @MainActor
    private func makeSlowTerminateRuntime(graceDelaySeconds: Double) async throws -> (manager: HermesSubprocessManager, rootURL: URL) {
        let fm = FileManager.default
        let rootURL = fm.temporaryDirectory
            .appendingPathComponent("hermes-mcp-slow-terminate-tests-\(UUID().uuidString)", isDirectory: true)
        let hermesHome = rootURL.appendingPathComponent("home", isDirectory: true)
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: hermesHome, withIntermediateDirectories: true)

        let bridgeURL = rootURL.appendingPathComponent("epistemos_bridge.py")
        let runAgentURL = rootURL.appendingPathComponent("run_agent.py")
        let bridgeScript = """
        #!/usr/bin/env python3
        import signal
        import sys
        import time

        def handle_term(_signum, _frame):
            time.sleep(\(graceDelaySeconds))
            raise SystemExit(0)

        signal.signal(signal.SIGTERM, handle_term)

        if __name__ == "__main__":
            while True:
                time.sleep(0.1)
        """
        let runAgentStub = """
        #!/usr/bin/env python3
        print("stub")
        """

        try Data(bridgeScript.utf8).write(to: bridgeURL, options: .atomic)
        try Data(runAgentStub.utf8).write(to: runAgentURL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bridgeURL.path)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runAgentURL.path)

        let pythonPath = fm.isExecutableFile(atPath: "/usr/bin/python3")
            ? "/usr/bin/python3"
            : HermesConfig.resolve().pythonPath
        let config = HermesConfig(
            pythonPath: pythonPath,
            hermesAgentDir: rootURL,
            model: "test",
            maxTurns: 1,
            environment: [
                "HERMES_HOME": hermesHome.path,
                "PYTHONUNBUFFERED": "1",
            ]
        )
        let manager = HermesSubprocessManager(config: config)
        try await manager.launch()
        return (manager, rootURL)
    }

    @MainActor
    private func makePingRuntime() async throws -> (manager: HermesSubprocessManager, rootURL: URL) {
        let fm = FileManager.default
        let rootURL = fm.temporaryDirectory
            .appendingPathComponent("hermes-mcp-ping-tests-\(UUID().uuidString)", isDirectory: true)
        let hermesHome = rootURL.appendingPathComponent("home", isDirectory: true)
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: hermesHome, withIntermediateDirectories: true)

        let bridgeURL = rootURL.appendingPathComponent("epistemos_bridge.py")
        let runAgentURL = rootURL.appendingPathComponent("run_agent.py")
        let bridgeScript = """
        #!/usr/bin/env python3
        import json
        import sys

        if __name__ == "__main__":
            for line in sys.stdin:
                request = json.loads(line)
                response = {
                    "jsonrpc": "2.0",
                    "result": {"ok": True},
                    "id": request.get("id"),
                }
                print(json.dumps(response), flush=True)
        """
        let runAgentStub = """
        #!/usr/bin/env python3
        print("stub")
        """

        try Data(bridgeScript.utf8).write(to: bridgeURL, options: .atomic)
        try Data(runAgentStub.utf8).write(to: runAgentURL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bridgeURL.path)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runAgentURL.path)

        let pythonPath = fm.isExecutableFile(atPath: "/usr/bin/python3")
            ? "/usr/bin/python3"
            : HermesConfig.resolve().pythonPath
        let config = HermesConfig(
            pythonPath: pythonPath,
            hermesAgentDir: rootURL,
            model: "test",
            maxTurns: 1,
            environment: [
                "HERMES_HOME": hermesHome.path,
                "PYTHONUNBUFFERED": "1",
            ]
        )
        let manager = HermesSubprocessManager(config: config)
        try await manager.launch()
        return (manager, rootURL)
    }

    @MainActor
    private func makeTreeTerminateRuntime() async throws -> (
        manager: HermesSubprocessManager,
        childPID: pid_t,
        rootURL: URL
    ) {
        let fm = FileManager.default
        let rootURL = fm.temporaryDirectory
            .appendingPathComponent("hermes-mcp-tree-terminate-tests-\(UUID().uuidString)", isDirectory: true)
        let hermesHome = rootURL.appendingPathComponent("home", isDirectory: true)
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: hermesHome, withIntermediateDirectories: true)

        let bridgeURL = rootURL.appendingPathComponent("epistemos_bridge.py")
        let runAgentURL = rootURL.appendingPathComponent("run_agent.py")
        let childPIDURL = rootURL.appendingPathComponent("child.pid")
        let bridgeScript = """
        #!/usr/bin/env python3
        import json
        import pathlib
        import signal
        import subprocess
        import sys
        import time

        signal.signal(signal.SIGTERM, signal.SIG_IGN)

        if __name__ == "__main__":
            for line in sys.stdin:
                payload = json.loads(line)
                pid_file = pathlib.Path(payload["pid_file"])
                child = subprocess.Popen(
                    [
                        sys.executable,
                        "-c",
                        "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(30)",
                    ],
                )
                pid_file.write_text(str(child.pid), encoding="utf-8")
                while True:
                    time.sleep(0.1)
        """
        let runAgentStub = """
        #!/usr/bin/env python3
        print("stub")
        """

        try Data(bridgeScript.utf8).write(to: bridgeURL, options: .atomic)
        try Data(runAgentStub.utf8).write(to: runAgentURL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bridgeURL.path)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runAgentURL.path)

        let pythonPath = fm.isExecutableFile(atPath: "/usr/bin/python3")
            ? "/usr/bin/python3"
            : HermesConfig.resolve().pythonPath
        let cleanup = OrphanSubprocessCleanup(
            processInfoEnvironment: ["XCTestConfigurationFilePath": "1"]
        )
        let config = HermesConfig(
            pythonPath: pythonPath,
            hermesAgentDir: rootURL,
            model: "test",
            maxTurns: 1,
            environment: [
                "HERMES_HOME": hermesHome.path,
                "PYTHONUNBUFFERED": "1",
            ]
        )
        let manager = HermesSubprocessManager(
            config: config,
            orphanCleanupProvider: { cleanup }
        )
        try await manager.launch()
        try manager.writeLine("{\"type\":\"bootstrap\",\"pid_file\":\(String(reflecting: childPIDURL.path))}")

        let childPID = try await withThrowingTaskGroup(of: pid_t.self) { group in
            group.addTask {
                for _ in 0..<100 {
                    if let text = try? String(contentsOf: childPIDURL, encoding: .utf8),
                       let rawPID = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        let pid = pid_t(rawPID)
                        return pid
                    }
                    try await Task.sleep(for: .milliseconds(20))
                }
                throw TimeoutError(seconds: 2)
            }
            return try await group.next()!
        }

        return (manager, childPID, rootURL)
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

@Suite("OrphanSubprocessCleanup")
struct OrphanSubprocessCleanupTests {
    @Test("cleanupAll terminates tracked descendant processes")
    @MainActor
    func cleanupAllTerminatesTrackedDescendants() async throws {
        let runtime = try await makeProcessTreeRuntime()
        let cleanup = OrphanSubprocessCleanup(
            processInfoEnvironment: ["XCTestConfigurationFilePath": "1"]
        )
        defer {
            cleanup.untrack(pid_t(runtime.process.processIdentifier))
            runtime.process.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        cleanup.track(runtime.process)
        #expect(kill(runtime.childPID, 0) == 0)

        cleanup.cleanupAll()

        for _ in 0..<100 {
            if kill(runtime.childPID, 0) != 0 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(kill(runtime.childPID, 0) != 0)
    }

    @MainActor
    private func makeProcessTreeRuntime() async throws -> (process: Process, childPID: pid_t, rootURL: URL) {
        let fm = FileManager.default
        let rootURL = fm.temporaryDirectory
            .appendingPathComponent("orphan-cleanup-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let pidFileURL = rootURL.appendingPathComponent("child.pid")
        let scriptURL = rootURL.appendingPathComponent("spawn_tree.py")
        let script = """
        #!/usr/bin/env python3
        import pathlib
        import signal
        import subprocess
        import sys
        import time

        pid_file = pathlib.Path(sys.argv[1])
        child = subprocess.Popen(
            [
                sys.executable,
                "-c",
                "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(30)",
            ],
            start_new_session=True,
        )
        pid_file.write_text(str(child.pid), encoding="utf-8")
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        time.sleep(30)
        """
        try Data(script.utf8).write(to: scriptURL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: fm.isExecutableFile(atPath: "/usr/bin/python3")
            ? "/usr/bin/python3"
            : HermesConfig.resolve().pythonPath)
        process.arguments = [scriptURL.path, pidFileURL.path]
        process.currentDirectoryURL = rootURL
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()

        for _ in 0..<100 {
            if let childPID = try? readChildPID(from: pidFileURL), childPID > 0 {
                return (process, childPID, rootURL)
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        process.terminate()
        throw NSError(
            domain: "OrphanSubprocessCleanupTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for spawned child PID"]
        )
    }

    private func readChildPID(from fileURL: URL) throws -> pid_t {
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        guard let pid = Int32(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw NSError(
                domain: "OrphanSubprocessCleanupTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid child PID contents"]
            )
        }
        return pid
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
            "available_tools": ["read_file", "terminal"],
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
        #expect(summary.availableTools == ["read_file", "terminal"])
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
        #expect(blocks[0].kind == .userPrompt("hello"))
        #expect(blocks[1].kind == .thinking(text: "Restore the saved context first.", tokenCount: 8))
        #expect(blocks[2].kind == .text("hi there"))
        #expect(
            blocks[3].kind == .toolExecution(
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
#endif

@Suite("Agent Runtime Migration")
struct AgentRuntimeMigrationTests {
    @Test("legacy Hermes subprocess sources stay retired while Rust agent core owns tool execution")
    func legacyHermesSourcesStayRetired() throws {
        let repoRoot = try sourceMirrorRootURL()
        let legacySource = repoRoot
            .appendingPathComponent("Epistemos/Agent/HermesSubprocessManager.swift")
        let bridge = try loadMigrationSource("Epistemos/Bridge/StreamingDelegate.swift")
        let rustBridge = try loadMigrationSource("agent_core/src/bridge.rs")
        let agentLoop = try loadMigrationSource("agent_core/src/agent_loop.rs")

        #expect(!FileManager.default.fileExists(atPath: legacySource.path))
        #expect(bridge.contains("func executeComputerAction(actionJson: String) -> String"))
        #expect(rustBridge.contains("fn execute_computer_action(&self, action_json: String) -> String;"))
        #expect(agentLoop.contains("delegate.execute_computer_action(input_json.clone())"))
    }
}

private func loadMigrationSource(_ relativePath: String) throws -> String {
    try loadMirroredSourceTextFile(relativePath)
}
