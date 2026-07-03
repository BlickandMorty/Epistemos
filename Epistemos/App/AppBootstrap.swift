import AppIntents
import AppKit
import Foundation
import Metal
import os
import QuartzCore
import SQLite3
import SwiftData
#if canImport(agent_coreFFI)
import agent_coreFFI
#endif

// MARK: - Ship Gate
// Release builds ship the same linked agent dylibs as debug builds, so
// Swift-side agent services stay available unless a future dedicated build
// variant intentionally removes them.
enum ShipGate {
    static let agentsEnabled = true
}

enum PersistenceMode: Equatable, Sendable {
    case durable(url: URL)
    case testInMemory
    case inMemoryRecovery(reason: String)

    var isDurable: Bool {
        if case .durable = self { return true }
        return false
    }
}

// MARK: - App Bootstrap
// Pure state/service factory. Creates state objects, services, and the dependency graph.
// All behavioral orchestration is delegated to AppCoordinator.

struct StartupIntegrityReport: Sendable {
    let sampledPageIds: [String]
    let corruptedPageIds: [String]
    let unrecoverablePageIds: [String]
    let eventStoreAvailable: Bool
    let vaultBookmarkExists: Bool
    let vaultBookmarkReadyForAutomaticRestore: Bool
    let vaultBookmarkFailureReason: String?

    var shouldBlockAutomaticVaultRestore: Bool {
        !corruptedPageIds.isEmpty || (vaultBookmarkExists && !vaultBookmarkReadyForAutomaticRestore)
    }
}

struct StartupIntegrityPageSnapshot: Sendable, Equatable {
    let id: String
    let filePath: String?
    let hasInlineBody: Bool
    let hasMeaningfulMetadata: Bool
}

struct StartupIntegrityToast: Sendable, Equatable {
    let message: String
    let type: ToastType
}

nonisolated struct StartupAutoDiscoveryKeyMapping: Sendable, Hashable {
    let envVar: String
    let keychainKey: String
}

nonisolated enum StartupAutoDiscoveryCredentialSource: String, Sendable, Equatable {
    case environment
    case keychain
    case configFile
    case missing
}

nonisolated struct StartupAutoDiscoveryCredentialStatus: Sendable, Equatable {
    let envVar: String
    let keychainKey: String
    let source: StartupAutoDiscoveryCredentialSource
    let origin: String?

    var isAvailable: Bool {
        source != .missing
    }

    var sourceDescription: String {
        switch source {
        case .environment:
            return "env"
        case .keychain:
            return "keychain"
        case .configFile:
            return "config:\(origin ?? "unknown")"
        case .missing:
            return "missing"
        }
    }
}

nonisolated struct StartupAutoDiscoveryReport: Sendable, Equatable {
    let credentialStatuses: [StartupAutoDiscoveryCredentialStatus]
    let browserToolAvailable: Bool
    let localModelDirectories: [URL]
    let huggingFaceModelDirectories: [URL]

    var availableCredentialLabels: [String] {
        credentialStatuses
            .filter(\.isAvailable)
            .map { "\($0.envVar)=\($0.sourceDescription)" }
            .sorted()
    }

    var missingCredentialEnvVars: [String] {
        credentialStatuses
            .filter { !$0.isAvailable }
            .map(\.envVar)
            .sorted()
    }
}

enum StartupAutoDiscovery {
    private nonisolated static let browserbaseKeychainMappings: [StartupAutoDiscoveryKeyMapping] = [
        .init(envVar: "BROWSERBASE_API_KEY", keychainKey: "epistemos.browserbase.apiKey"),
        .init(envVar: "BROWSERBASE_PROJECT_ID", keychainKey: "epistemos.browserbase.projectID"),
    ]

    nonisolated static var keyMappings: [StartupAutoDiscoveryKeyMapping] {
        var seen = Set<StartupAutoDiscoveryKeyMapping>()
        return browserbaseKeychainMappings.filter { seen.insert($0).inserted }
    }

    private nonisolated static let configAliases: [String: [String]] = [
        "OPENROUTER_API_KEY": [
            "OPENROUTER_API_KEY",
            "openrouter_api_key",
            "providers.openrouter.api_key",
            "provider.openrouter.api_key",
            "openrouter.api_key",
        ],
        "ANTHROPIC_API_KEY": [
            "ANTHROPIC_API_KEY",
            "anthropic_api_key",
            "providers.anthropic.api_key",
            "provider.anthropic.api_key",
            "anthropic.api_key",
        ],
        "OPENAI_API_KEY": [
            "OPENAI_API_KEY",
            "openai_api_key",
            "providers.openai.api_key",
            "provider.openai.api_key",
            "openai.api_key",
        ],
        "GOOGLE_API_KEY": [
            "GOOGLE_API_KEY",
            "google_api_key",
            "providers.google.api_key",
            "provider.google.api_key",
            "google.api_key",
        ],
        "TAVILY_API_KEY": [
            "TAVILY_API_KEY",
            "tavily_api_key",
            "tools.tavily.api_key",
            "tool.tavily.api_key",
            "services.tavily.api_key",
            "service.tavily.api_key",
            "tavily.api_key",
        ],
        "EXA_API_KEY": [
            "EXA_API_KEY",
            "exa_api_key",
            "tools.exa.api_key",
            "tool.exa.api_key",
            "services.exa.api_key",
            "service.exa.api_key",
            "exa.api_key",
        ],
        "FIRECRAWL_API_KEY": [
            "FIRECRAWL_API_KEY",
            "firecrawl_api_key",
            "tools.firecrawl.api_key",
            "tool.firecrawl.api_key",
            "services.firecrawl.api_key",
            "service.firecrawl.api_key",
            "firecrawl.api_key",
        ],
        "BROWSERBASE_API_KEY": [
            "BROWSERBASE_API_KEY",
            "browserbase_api_key",
            "tools.browserbase.api_key",
            "tool.browserbase.api_key",
            "services.browserbase.api_key",
            "service.browserbase.api_key",
            "browserbase.api_key",
        ],
        "BROWSERBASE_PROJECT_ID": [
            "BROWSERBASE_PROJECT_ID",
            "browserbase_project_id",
            "tools.browserbase.project_id",
            "tool.browserbase.project_id",
            "services.browserbase.project_id",
            "service.browserbase.project_id",
            "browserbase.project_id",
        ],
    ]

    nonisolated static func perform(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        homeDirectoryURL: URL? = nil,
        localModelRootURL: URL? = nil,
        configFileURLs: [URL]? = nil,
        readFile: (URL) -> String? = { url in
            do {
                return try String(contentsOf: url, encoding: .utf8)
            } catch {
                if FileManager.default.fileExists(atPath: url.path) {
                    Log.app.error(
                        "AppBootstrap: failed to read auto-discovery config \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                }
                return nil
            }
        },
        keychainLoad: (String) -> String? = { Keychain.load(for: $0) },
        keychainSave: (String, String) -> Bool = { value, key in
            Keychain.save(value, for: key)
        },
        agentProvenanceRecorder: AgentToolProvenanceSyncRecorder? = nil
    ) -> StartupAutoDiscoveryReport {
        let resolvedHomeURL = (homeDirectoryURL ?? fileManager.homeDirectoryForCurrentUser)
            .standardizedFileURL
        let resolvedConfigURLs = configFileURLs
            ?? defaultConfigFileURLs(fileManager: fileManager, homeDirectoryURL: resolvedHomeURL)

        let parsedConfigs = resolvedConfigURLs.compactMap { url -> (URL, [String: String])? in
            guard let contents = readFile(url) else { return nil }
            return (url, parseConfigValues(contents))
        }

        let statuses = keyMappings.map { mapping in
            if let envValue = normalizedCredential(environment[mapping.envVar]) {
                if normalizedCredential(keychainLoad(mapping.keychainKey)) == nil {
                    if keychainSave(envValue, mapping.keychainKey) {
                        recordCredentialImportedEvent(
                            recorder: agentProvenanceRecorder,
                            mapping: mapping,
                            source: .environment,
                            origin: nil
                        )
                    }
                }
                return StartupAutoDiscoveryCredentialStatus(
                    envVar: mapping.envVar,
                    keychainKey: mapping.keychainKey,
                    source: .environment,
                    origin: nil
                )
            }

            if normalizedCredential(keychainLoad(mapping.keychainKey)) != nil {
                return StartupAutoDiscoveryCredentialStatus(
                    envVar: mapping.envVar,
                    keychainKey: mapping.keychainKey,
                    source: .keychain,
                    origin: nil
                )
            }

            if let configMatch = configMatch(for: mapping.envVar, parsedConfigs: parsedConfigs) {
                let origin = configMatch.url.lastPathComponent
                if keychainSave(configMatch.value, mapping.keychainKey) {
                    recordCredentialImportedEvent(
                        recorder: agentProvenanceRecorder,
                        mapping: mapping,
                        source: .configFile,
                        origin: origin
                    )
                }
                return StartupAutoDiscoveryCredentialStatus(
                    envVar: mapping.envVar,
                    keychainKey: mapping.keychainKey,
                    source: .configFile,
                    origin: origin
                )
            }

            return StartupAutoDiscoveryCredentialStatus(
                envVar: mapping.envVar,
                keychainKey: mapping.keychainKey,
                source: .missing,
                origin: nil
            )
        }

        let browserToolAvailable = isExecutableAvailable(
            named: "agent-browser",
            path: environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin",
            fileManager: fileManager
        )

        return StartupAutoDiscoveryReport(
            credentialStatuses: statuses,
            browserToolAvailable: browserToolAvailable,
            localModelDirectories: [],
            huggingFaceModelDirectories: []
        )
    }

    nonisolated static func testHostReport(
        temporaryRootURL: URL = FileManager.default.temporaryDirectory
    ) -> StartupAutoDiscoveryReport {
        return StartupAutoDiscoveryReport(
            credentialStatuses: keyMappings.map { mapping in
                StartupAutoDiscoveryCredentialStatus(
                    envVar: mapping.envVar,
                    keychainKey: mapping.keychainKey,
                    source: .missing,
                    origin: nil
                )
            },
            browserToolAvailable: false,
            localModelDirectories: [],
            huggingFaceModelDirectories: []
        )
    }

    nonisolated static func defaultConfigFileURLs(
        fileManager: FileManager = .default,
        homeDirectoryURL: URL? = nil
    ) -> [URL] {
        let resolvedHomeURL = (homeDirectoryURL ?? fileManager.homeDirectoryForCurrentUser)
            .standardizedFileURL
        return [
            resolvedHomeURL
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("epistemos", isDirectory: true)
                .appendingPathComponent("config.toml", isDirectory: false),
            resolvedHomeURL
                .appendingPathComponent(".epistemos", isDirectory: true)
                .appendingPathComponent("config.toml", isDirectory: false),
        ]
    }

    private nonisolated static func recordCredentialImportedEvent(
        recorder: AgentToolProvenanceSyncRecorder?,
        mapping: StartupAutoDiscoveryKeyMapping,
        source: StartupAutoDiscoveryCredentialSource,
        origin: String?
    ) {
        guard let recorder else { return }

        var payload = [
            "env_var": mapping.envVar,
            "keychain_key": mapping.keychainKey,
            "source": source.rawValue,
        ]
        var metadata = [
            "source": "startup_auto_discovery",
            "surface": "credential_auto_discovery",
            "credential_source": source.rawValue,
            "env_var": mapping.envVar,
            "keychain_key": mapping.keychainKey,
        ]
        if let origin {
            payload["origin"] = origin
            metadata["origin"] = origin
        }

        _ = recorder.recordToolEvent(
            runID: "auth-credential-imported-startup",
            traceID: nil,
            kind: .toolCallCompleted,
            actor: .agent(id: "startup-auto-discovery", modelID: nil),
            toolCallID: credentialImportedToolCallID(
                mapping: mapping,
                source: source,
                origin: origin
            ),
            toolName: "auth.credential.imported",
            argumentsJSON: sortedJSONString(payload),
            resultJSON: "{\"imported\":true}",
            status: .completed,
            metadata: metadata
        )
    }

    private nonisolated static func credentialImportedToolCallID(
        mapping: StartupAutoDiscoveryKeyMapping,
        source: StartupAutoDiscoveryCredentialSource,
        origin: String?
    ) -> String {
        var components = [
            "auth-credential-imported",
            source.rawValue,
            mapping.envVar,
        ]
        if let origin {
            components.append(origin)
        }
        return components.joined(separator: ":")
    }

    private nonisolated static func sortedJSONString(_ payload: [String: String]) -> String {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    nonisolated static func parseConfigValues(_ contents: String) -> [String: String] {
        var values: [String: String] = [:]
        var sectionPath: [String] = []

        for rawLine in contents.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let strippedLine = stripComment(from: String(rawLine))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !strippedLine.isEmpty else { continue }

            if strippedLine.hasPrefix("[") && strippedLine.hasSuffix("]") {
                let rawSection = strippedLine
                    .dropFirst()
                    .dropLast()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                sectionPath = rawSection
                    .split(separator: ".")
                    .map {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                            .lowercased()
                    }
                continue
            }

            guard let equalsIndex = strippedLine.firstIndex(of: "=") else { continue }

            let rawKey = strippedLine[..<equalsIndex]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !rawKey.isEmpty else { continue }

            let rawValue = strippedLine[strippedLine.index(after: equalsIndex)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let parsedValue = parseScalarValue(rawValue) else { continue }

            let loweredKey = rawKey.lowercased()
            values[rawKey] = parsedValue
            values[loweredKey] = parsedValue

            if !sectionPath.isEmpty {
                values[(sectionPath + [loweredKey]).joined(separator: ".")] = parsedValue
            }
        }

        return values
    }

    nonisolated static func isExecutableAvailable(
        named executableName: String,
        path: String,
        fileManager: FileManager = .default
    ) -> Bool {
        path
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }
            .contains { directory in
                fileManager.isExecutableFile(
                    atPath: URL(fileURLWithPath: directory, isDirectory: true)
                        .appendingPathComponent(executableName, isDirectory: false)
                        .path
                )
            }
    }

    nonisolated static func log(_ report: StartupAutoDiscoveryReport) {
        let available = report.availableCredentialLabels.joined(separator: ", ")
        let missing = report.missingCredentialEnvVars.joined(separator: ", ")
        Log.app.info(
            """
            AppBootstrap: auto-discovery available [\(available, privacy: .public)] \
            missing [\(missing, privacy: .public)] \
            agent-browser=\(report.browserToolAvailable, privacy: .public) \
            local-model-dirs=\(report.localModelDirectories.count, privacy: .public) \
            hf-model-dirs=\(report.huggingFaceModelDirectories.count, privacy: .public)
            """
        )
    }

    private nonisolated static func normalizedCredential(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private nonisolated static func configMatch(
        for envVar: String,
        parsedConfigs: [(url: URL, values: [String: String])]
    ) -> (url: URL, value: String)? {
        let aliases = configAliases[envVar] ?? [envVar]
        for parsedConfig in parsedConfigs {
            for alias in aliases {
                if let value = normalizedCredential(parsedConfig.values[alias]) {
                    return (parsedConfig.url, value)
                }
            }
        }
        return nil
    }

    private nonisolated static func parseScalarValue(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.count >= 2,
           let first = trimmed.first,
           let last = trimmed.last,
           (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            let inner = trimmed.dropFirst().dropLast()
            return String(inner)
                .replacingOccurrences(of: #"\""#, with: "\"")
                .replacingOccurrences(of: #"\\\\"#, with: #"\"#)
        }

        return trimmed
    }

    private nonisolated static func stripComment(from line: String) -> String {
        var result = ""
        var insideSingleQuote = false
        var insideDoubleQuote = false

        for character in line {
            switch character {
            case "'" where !insideDoubleQuote:
                insideSingleQuote.toggle()
            case "\"" where !insideSingleQuote:
                insideDoubleQuote.toggle()
            case "#" where !insideSingleQuote && !insideDoubleQuote:
                return result
            default:
                break
            }
            result.append(character)
        }

        return result
    }
}

private actor AgentCoreEnvironmentScopeGate {
    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            isHeld = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

@MainActor
final class AppBootstrap {
    /// Shared instance for App Intent access. Set during init.
    static var shared: AppBootstrap?
    private nonisolated static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private nonisolated static let agentCoreManagedOAuthEnvironmentVars: Set<String> = [
        "OPENAI_ACCESS_TOKEN",
        "OPENAI_AUTH_MODE",
        "OPENAI_CLIENT_VERSION",
        "ANTHROPIC_ACCESS_TOKEN",
        "ANTHROPIC_AUTH_MODE",
        "GOOGLE_ACCESS_TOKEN",
        "GOOGLE_AUTH_MODE",
        "GOOGLE_PROJECT_ID",
    ]
    private nonisolated static let agentCoreEnvironmentKeyMappings: [(envVar: String, keychainKey: String)] = [
        ("ANTHROPIC_API_KEY", "epistemos.anthropic.apiKey"),
        ("OPENAI_API_KEY", "epistemos.openai.apiKey"),
        ("GOOGLE_API_KEY", "epistemos.google.apiKey"),
        ("PERPLEXITY_API_KEY", "epistemos.perplexity.apiKey"),
        ("OPENROUTER_API_KEY", "epistemos.openrouter.apiKey"),
        ("GLM_API_KEY", "epistemos.zai.apiKey"),
        ("ZHIPU_API_KEY", "epistemos.zai.apiKey"),
        ("ZAI_API_KEY", "epistemos.zai.apiKey"),
        ("KIMI_API_KEY", "epistemos.kimi.apiKey"),
        ("MOONSHOT_API_KEY", "epistemos.kimi.apiKey"),
        ("DEEPSEEK_API_KEY", "epistemos.deepseek.apiKey"),
        ("MINIMAX_API_KEY", "epistemos.minimax.apiKey"),
        ("XAI_API_KEY", "epistemos.xai.apiKey"),
        ("MISTRAL_API_KEY", "epistemos.mistral.apiKey"),
        ("GROQ_API_KEY", "epistemos.groq.apiKey"),
        ("HF_TOKEN", "epistemos.huggingface.apiKey"),
        ("HUGGINGFACE_API_KEY", "epistemos.huggingface.apiKey"),
    ]

    private nonisolated static let agentCoreEnvironmentScopeGate = AgentCoreEnvironmentScopeGate()

    private nonisolated static var agentCoreManagedEnvironmentVars: Set<String> {
        Set(agentCoreEnvironmentKeyMappings.map(\.envVar))
            .union(agentCoreManagedOAuthEnvironmentVars)
    }

    /// Clears Epistemos-managed provider env vars from the parent process. Stored
    /// credentials are scoped only around the Rust agent runtime call.
    nonisolated static func populateAgentCoreEnvironment(
        keychainLoad _: @Sendable (String) -> String? = { Keychain.load(for: $0) }
    ) {
        clearAgentCoreEnvironment()
    }

    nonisolated static func clearAgentCoreEnvironment() {
        for envVar in agentCoreManagedEnvironmentVars {
            unsetenv(envVar)
        }
    }

    nonisolated static func withScopedAgentCoreEnvironment<T>(
        keychainLoad: @Sendable (String) -> String? = { Keychain.load(for: $0) },
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let overrides = agentCoreEnvironmentOverrides(keychainLoad: keychainLoad)
        let managedVars = agentCoreManagedEnvironmentVars

        await agentCoreEnvironmentScopeGate.acquire()

        let previous = snapshotEnvironmentVars(managedVars)
        applyAgentCoreEnvironmentOverrides(overrides, managedVars: managedVars)

        do {
            let result = try await operation()
            restoreEnvironmentVars(previous)
            await agentCoreEnvironmentScopeGate.release()
            return result
        } catch {
            restoreEnvironmentVars(previous)
            await agentCoreEnvironmentScopeGate.release()
            throw error
        }
    }

    private nonisolated static func snapshotEnvironmentVars(_ vars: Set<String>) -> [String: String?] {
        vars.reduce(into: [String: String?]()) { result, envVar in
            if let rawValue = getenv(envVar) {
                result.updateValue(String(cString: rawValue), forKey: envVar)
            } else {
                result.updateValue(nil, forKey: envVar)
            }
        }
    }

    private nonisolated static func applyAgentCoreEnvironmentOverrides(
        _ overrides: [String: String],
        managedVars: Set<String>
    ) {
        for envVar in managedVars {
            if let value = overrides[envVar], !value.isEmpty {
                setenv(envVar, value, 1)
            } else {
                unsetenv(envVar)
            }
        }
    }

    private nonisolated static func restoreEnvironmentVars(_ snapshot: [String: String?]) {
        for (envVar, value) in snapshot {
            if let value {
                setenv(envVar, value, 1)
            } else {
                unsetenv(envVar)
            }
        }
    }

    nonisolated static func agentCoreEnvironmentOverrides(
        keychainLoad: @Sendable (String) -> String? = { Keychain.load(for: $0) }
    ) -> [String: String] {
        var overrides: [String: String] = [:]
        for mapping in agentCoreEnvironmentKeyMappings {
            if let value = normalizedAgentCoreEnvironmentValue(keychainLoad(mapping.keychainKey)) {
                overrides[mapping.envVar] = value
            }
        }

        if let credential = storedOAuthCredential(
            for: .openAI,
            authMode: .openAICodex,
            keychainLoad: keychainLoad
        ) {
            overrides["OPENAI_ACCESS_TOKEN"] = credential.accessToken
            overrides["OPENAI_AUTH_MODE"] = "codex"
            overrides["OPENAI_CLIENT_VERSION"] = OpenAICodexRuntimeMetadata.clientVersion
        }

        if let credential = storedOAuthCredential(
            for: .anthropic,
            authMode: .anthropicClaudeCode,
            keychainLoad: keychainLoad
        ) {
            overrides["ANTHROPIC_ACCESS_TOKEN"] = credential.accessToken
            overrides["ANTHROPIC_AUTH_MODE"] = "oauth"
        }

        if let credential = storedOAuthCredential(
            for: .google,
            authMode: .googleGemini,
            keychainLoad: keychainLoad
        ),
           let projectID = normalizedAgentCoreEnvironmentValue(credential.projectID) {
            overrides["GOOGLE_ACCESS_TOKEN"] = credential.accessToken
            overrides["GOOGLE_AUTH_MODE"] = "oauth"
            overrides["GOOGLE_PROJECT_ID"] = projectID
        }

        return overrides
    }

    nonisolated static func agentCoreKeychainKey(forEnvironmentKey envVar: String) -> String? {
        agentCoreEnvironmentKeyMappings.first { $0.envVar == envVar }?.keychainKey
    }

    private nonisolated static func storedOAuthCredential(
        for provider: CloudModelProvider,
        authMode: CloudProviderOAuthMode,
        keychainLoad: @Sendable (String) -> String?
    ) -> CloudProviderOAuthCredential? {
        guard let rawCredential = normalizedAgentCoreEnvironmentValue(
            keychainLoad(provider.oauthKeychainKey)
        ),
        let credential = CloudProviderOAuthCredential.decode(from: rawCredential),
        credential.authMode == authMode,
        normalizedAgentCoreEnvironmentValue(credential.accessToken) != nil else {
            return nil
        }
        return credential
    }

    private nonisolated static func normalizedAgentCoreEnvironmentValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
    #if DEBUG
    private nonisolated static let isDebugBuild = true
    #else
    private nonisolated static let isDebugBuild = false
    #endif

    nonisolated static func startupAutoDiscoveryReportForTesting(
        isRunningTests: Bool,
        discover: () -> StartupAutoDiscoveryReport = { StartupAutoDiscovery.perform() }
    ) -> StartupAutoDiscoveryReport {
        guard !isRunningTests else {
            return StartupAutoDiscovery.testHostReport()
        }
        return discover()
    }

    private nonisolated static func currentStartupAutoDiscoveryReportForTesting() -> StartupAutoDiscoveryReport {
        Self.startupAutoDiscoveryReportForTesting(
            isRunningTests: Self.isRunningTests
        )
    }

    nonisolated static func shouldReadKeychainAtLaunch(
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        VaultSyncService.shouldRestoreVaultFromBookmark(
            processInfoEnvironment: processInfoEnvironment
        )
    }

    nonisolated static func shouldPopulateAgentCoreEnvironmentAtLaunch(
        deferredCloudCredentialBootstrapInFlight: Bool,
        launchKeychainAccessAllowed: Bool = shouldReadKeychainAtLaunch()
    ) -> Bool {
        launchKeychainAccessAllowed && !deferredCloudCredentialBootstrapInFlight
    }

    private nonisolated static func scheduleStartupAutoDiscoveryLoggingIfNeeded() {
        guard shouldReadKeychainAtLaunch() else { return }
        Task.detached(priority: .utility) {
            let report = startupAutoDiscoveryReportForTesting(
                isRunningTests: Self.isRunningTests,
                discover: {
                    StartupAutoDiscovery.perform(
                        agentProvenanceRecorder: AgentToolProvenanceSyncRecorder()
                    )
                }
            )
            StartupAutoDiscovery.log(report)
        }
    }


    nonisolated static func shouldScheduleMetalShaderWarmupAtLaunch(
        isRunningTests: Bool = AppBootstrap.isRunningTests,
        isDebugBuild: Bool = AppBootstrap.isDebugBuild
    ) -> Bool {
        !isRunningTests && !isDebugBuild
    }

    private static func requireInitialized<Value>(_ value: Value?, name: StaticString) -> Value {
        guard let value else {
            preconditionFailure("AppBootstrap.\(name.description) accessed before initialization")
        }
        return value
    }

    private nonisolated static func makeFallbackSearchIndexService() -> SearchIndexService? {
        do {
            return try SearchIndexService()
        } catch {
            Log.app.error(
                "AppBootstrap: failed to create fallback search index service: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    // MARK: - Model Container
    let modelContainer: ModelContainer
    let persistenceMode: PersistenceMode
    /// Non-nil when the on-disk database failed to load and the app is in
    /// recovery-only in-memory mode. RootView blocks normal workspace editing.
    var databaseError: Error?

    // MARK: - State
    let eventBus = EventBus()
    let pipelineState = PipelineState()
    let uiState = UIState()
    let notesUI = NotesUIState()
    let inferenceState: InferenceState
    let dailyBriefState = DailyBriefState()
    let threadState = ThreadState()
    let graphState = GraphState()
    let queryEngine = QueryEngine()
    let physicsCoordinator = PhysicsCoordinator()
    let mcpBridge = MCPBridge()
    /// Patch 7 / AMBIENT_RECALL_WIRING_PLAN.md §5 — Contextual Shadows V0
    /// state container (recall hits + panel visibility). Hidden behind
    /// `EPISTEMOS_AMBIENT_RECALL_V0` env flag; UI hides itself when
    /// `state.isEnabled == false`.
    let contextualShadowsState = ContextualShadowsState()
    let ambientFrequencyPlaybackState = AmbientFrequencyPlaybackState()
    let agentAuthorityStore = AgentAuthorityStore(
        persistence: FileBackedAgentAuthorityPersistence()
    )
    let chatApprovalQueue = ChatApprovalQueue()
    let sovereignGate = SovereignGate()
    /// Simulation Mode v1.6 — Companion Farm + Notes Sidebar Skin +
    /// (future) Graph Live Theater. Single source of truth for
    /// companion CRUD + activation per the simulation worktree
    /// DOCTRINE.md. Wired to the canonical SwiftData ModelContext at
    /// the end of AppBootstrap.init so SwiftUI surfaces can read the
    /// roster immediately on first paint.
    let companionState = CompanionState()
    private let sovereignGateLifecycleObserver = SovereignGateLifecycleObserver()
    var isSovereignGateLifecycleObserverStarted: Bool {
        sovereignGateLifecycleObserver.isStarted
    }
    private var commandCenterLocalHotkeyMonitor: Any?
    private var commandCenterGlobalHotkeyMonitor: Any?
    // Computer-use (screen capture / AX automation / device agent) removed — cloud-only build.
    private var _reasoningLoopService: ReasoningLoopService?
    var reasoningLoopService: ReasoningLoopService { Self.requireInitialized(_reasoningLoopService, name: "reasoningLoopService") }
    let instantRecallService = InstantRecallService()
    private var _textCapturePipeline: TextCapturePipeline?
    var textCapturePipeline: TextCapturePipeline { Self.requireInitialized(_textCapturePipeline, name: "textCapturePipeline") }
    private var _mutationOpLogProjectionWorker: MutationOpLogProjectionWorker?
    var mutationOpLogProjectionWorker: MutationOpLogProjectionWorker? { _mutationOpLogProjectionWorker }
    private var _workspaceService: WorkspaceService?
    var workspaceService: WorkspaceService { Self.requireInitialized(_workspaceService, name: "workspaceService") }
    let activityTracker = ActivityTracker()
    private var _workspaceSummaryService: WorkspaceSummaryService?
    var workspaceSummaryService: WorkspaceSummaryService { Self.requireInitialized(_workspaceSummaryService, name: "workspaceSummaryService") }
    private var _timeMachineService: TimeMachineService?
    var timeMachineService: TimeMachineService { Self.requireInitialized(_timeMachineService, name: "timeMachineService") }

    // MARK: - Infrastructure
    let supervisor = AppSupervisor()
    let orphanCleanup = OrphanSubprocessCleanup()
    private var _paperclipStore: PaperclipStateStore?
    var paperclipStore: PaperclipStateStore { Self.requireInitialized(_paperclipStore, name: "paperclipStore") }
    private var _paperclipHeartbeatClock: PaperclipHeartbeatClock?
    var paperclipHeartbeatClock: PaperclipHeartbeatClock? { _paperclipHeartbeatClock }

    // MARK: - Cognitive Substrates
    let epistemosConfig = EpistemosConfig()
    private var _frictionMonitor: FrictionMonitorService?
    var frictionMonitor: FrictionMonitorService { Self.requireInitialized(_frictionMonitor, name: "frictionMonitor") }

    // MARK: - Ambient Vault Manifest
    /// Always-available vault manifest — built eagerly on vault attach, refreshed on changes.
    /// Nil when no vault is attached. Shared across agent, editor, and graph surfaces.
    var ambientManifest: VaultManifest?

    // MARK: - Active Query Task
    var queryTask: Task<Void, Never>?
    private var healthyVaultBodyCleanupTask: Task<Void, Never>?

    private var preparedRetrievalRefreshTask: Task<Void, Never>?
    private var startupIntegrityReport: StartupIntegrityReport?
    private var didStartPrimaryLaunchInitialization = false
    private var didCompletePrimaryLaunchInitialization = false
    private var didStartDeferredRuntimeServices = false

    /// Last absolute vault path we successfully passed to
    /// `resourceServiceInit` — used to skip redundant re-initializations
    /// when `.vaultChanged` fires for a mutation that did NOT switch
    /// vaults. Nil means the gateway is not (yet) initialized, or the
    /// last init attempt failed and should be retried.
    ///
    /// Lives on the main actor; only mutated in
    /// `initializeRustResourceServiceIfReady()` and its failure path.
    private var lastR3InitializedVaultPath: String?

    /// W8.7 — Halo's persistent indexer + the most recent vault path
    /// it was opened against. Stored so the actor isn't GC'd mid-crawl
    /// and so a `.vaultChanged` notification can short-circuit when
    /// the user re-opens the same vault.
    private var shadowIndexer: ShadowIndexingService?
    private var lastShadowIndexedVaultPath: String?
    private var shadowIndexingInFlightVaultPath: String?

    /// KC cutover Slice 3 — the in-app KnowledgeCore shadow runtime, held
    /// here so it survives across vault-sync ticks and isn't GC'd mid-poll.
    /// Instantiated only when `knowledgeCoreRuntimeV0` is on (default OFF);
    /// `nil` otherwise, so default-build behavior is unchanged. Persists its
    /// mutation log to `<vault>/.epcache/kc-oplog.jsonl` and replays it on
    /// open, so the projected fact state survives a restart.
    private(set) var knowledgeCoreRuntime: KnowledgeCoreShadowRuntime?
    private var lastKnowledgeCoreVaultPath: String?

    /// Filesystem path of the KC runtime's durable oplog for the active vault
    /// (`<vault>/.epcache/kc-oplog.jsonl`), or `nil` when no vault is open. Read
    /// by the diagnostics row to show that persistence is happening.
    var knowledgeCoreOplogPath: String? {
        vaultSync.vaultURL.map { Self.knowledgeCoreOplogURL(for: $0).path }
    }

    /// Minimal Sendable note reference captured from the SwiftData context on
    /// main, then carried into the off-main KC seed loop (see
    /// `feedKnowledgeCoreRuntimeIfReady`).
    private struct KnowledgeCoreFeedPageRef: Sendable {
        let id: String
        let filePath: String?
    }

    private nonisolated static let primaryLaunchInitializationWaitTimeout: Duration = .seconds(6)
    private nonisolated static let primaryLaunchInitializationPollInterval: Duration = .milliseconds(50)
    private nonisolated static let deferredRuntimeServicesDelay: Duration = .milliseconds(250)

    private struct InstantRecallSeed: Sendable {
        let id: String
        let inlineBody: String
        let liveBody: String?
    }

    private struct ShadowPageIndexStage: Sendable {
        let pageId: String
        let docId: String
        let title: String
        let filePath: String?
        let inlineBody: String
        let vaultPath: String
        let shadowPath: String
    }

    private func recordPersistenceIssue(
        _ message: String,
        error: Error
    ) {
        Log.persistence.error(
            "\(message, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
        RuntimeDiagnostics.record(
            .error,
            category: "Persistence",
            message: message,
            metadata: ["error": error.localizedDescription]
        )
    }

    private func removeItemIfPresent(
        at url: URL,
        fileManager: FileManager,
        failureMessage: String
    ) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            recordPersistenceIssue("\(failureMessage) (\(url.lastPathComponent))", error: error)
        }
    }

    private nonisolated static let legacyMessageColumns: [(name: String, declaration: String)] = [
        ("ZTHINKINGTRACE", "TEXT"),
        ("ZTHINKINGDURATIONSECONDS", "DOUBLE"),
        // Pass 8 — per-model authorship memory. Optional strings, no
        // default needed; SwiftData lightweight migration handles new
        // stores automatically but legacy SQLite stores adopted via
        // `preparePersistentModelStoreIfNeeded` still need the columns
        // explicitly added.
        ("ZAUTHOREDBYPROVIDERID", "TEXT"),
        ("ZAUTHOREDBYMODELID", "TEXT"),
    ]

    private nonisolated static let legacyPageColumns: [(name: String, declaration: String)] = [
        ("ZWIKILINKREFERENCES", "BLOB"),
        ("ZWIKILINKREFERENCESCANSIGNATURE", "VARCHAR"),
    ]

    nonisolated static func legacyRootModelStoreURL(
        applicationSupportDirectory: URL
    ) -> URL {
        applicationSupportDirectory
            .appendingPathComponent("default.store", isDirectory: false)
            .standardizedFileURL
    }

    nonisolated static func persistentModelStoreURL(
        applicationSupportDirectory: URL,
        fileManager: FileManager = .default
    ) -> URL {
        let directory = applicationSupportDirectory
            .appendingPathComponent("Epistemos", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
            .appendingPathComponent("default.store", isDirectory: false)
            .standardizedFileURL
    }

    nonisolated static func preparePersistentModelStoreIfNeeded(
        applicationSupportDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let destinationURL = persistentModelStoreURL(
            applicationSupportDirectory: applicationSupportDirectory,
            fileManager: fileManager
        )
        let legacyURL = legacyRootModelStoreURL(applicationSupportDirectory: applicationSupportDirectory)

        // Two scenarios diverge here:
        //
        // (a) **Dual stores** — legacy AND destination both exist
        // independently. Both need column-repair in place so that
        // any tool that still reads the legacy path sees the same
        // schema. The `bootstrapRepairsLegacyRootAndAppScopedStores
        // WhenBothExist` test pins this contract.
        //
        // (b) **Adoption** — only legacy exists. We copy it to the
        // destination, then repair the destination. Repairing legacy
        // ALSO in this branch would place the `default.store.pre-
        // column-repair.backup` at the legacy parent (the user's
        // Application Support root) rather than next to the
        // destination — recovery tooling would then be pointed at the
        // wrong path. The `bootstrapAdoptsLegacyRootStoresIntoTheApp
        // ScopedPathAndRepairsMessageColumns` test pins backup
        // placement at the destination parent.
        //
        // Branch the logic so the dual-store case still repairs legacy
        // but the adoption case lets the destination repair create the
        // single, co-located backup.
        let legacyExists = fileManager.fileExists(atPath: legacyURL.path)
        let destinationExists = fileManager.fileExists(atPath: destinationURL.path)

        if legacyExists && destinationExists {
            try repairLegacyStoreColumnsIfNeeded(at: legacyURL)
        }

        if !destinationExists, legacyExists {
            try VaultSyncService.backupSQLiteDatabaseIfPresent(at: legacyURL, to: destinationURL)
        }

        try repairLegacyStoreColumnsIfNeeded(at: destinationURL)
        try verifyRequiredLegacyStoreColumns(at: destinationURL)
        return destinationURL
    }

    private nonisolated static func repairLegacyStoreColumnsIfNeeded(
        at storeURL: URL
    ) throws {
        try repairLegacyMessageColumnsIfNeeded(at: storeURL)
        try repairLegacyPageColumnsIfNeeded(at: storeURL)
    }

    private nonisolated static func repairLegacyMessageColumnsIfNeeded(
        at storeURL: URL
    ) throws {
        try repairLegacyColumnsIfNeeded(
            at: storeURL,
            tableName: "ZSDMESSAGE",
            columns: legacyMessageColumns,
            alterDomain: "Message"
        )
    }

    private nonisolated static func repairLegacyPageColumnsIfNeeded(
        at storeURL: URL
    ) throws {
        try repairLegacyColumnsIfNeeded(
            at: storeURL,
            tableName: "ZSDPAGE",
            columns: legacyPageColumns,
            alterDomain: "Page"
        )
    }

    private nonisolated static func repairLegacyColumnsIfNeeded(
        at storeURL: URL,
        tableName: String,
        columns: [(name: String, declaration: String)],
        alterDomain: String
    ) throws {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        var db: OpaquePointer?
        guard sqlite3_open_v2(
            storeURL.path,
            &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let db else {
            throw sqliteStoreError(
                domain: "AppBootstrap.ModelStore.Open",
                code: -1,
                storeURL: storeURL,
                db: db
            )
        }
        defer { sqlite3_close(db) }

        sqlite3_busy_timeout(db, 1_000)

        let columnNames = try sqliteColumnNames(in: tableName, db: db, storeURL: storeURL)
        guard !columnNames.isEmpty else { return }
        let missingColumns = columns.filter { !columnNames.contains($0.name) }
        guard !missingColumns.isEmpty else { return }

        try backupModelStoreBeforeLegacyColumnRepairIfNeeded(at: storeURL)

        for column in missingColumns {
            let sql = "ALTER TABLE \(tableName) ADD COLUMN \(column.name) \(column.declaration);"
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw sqliteStoreError(
                    domain: "AppBootstrap.ModelStore.Alter\(alterDomain)",
                    code: Int(sqlite3_errcode(db)),
                    storeURL: storeURL,
                    db: db
                )
            }
        }
    }

    private nonisolated static func verifyRequiredLegacyStoreColumns(
        at storeURL: URL
    ) throws {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        var db: OpaquePointer?
        guard sqlite3_open_v2(
            storeURL.path,
            &db,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let db else {
            throw sqliteStoreError(
                domain: "AppBootstrap.ModelStore.VerifyOpen",
                code: -1,
                storeURL: storeURL,
                db: db
            )
        }
        defer { sqlite3_close(db) }

        try verifyRequiredColumns(
            in: "ZSDMESSAGE",
            requiredColumns: legacyMessageColumns.map(\.name),
            db: db,
            storeURL: storeURL
        )
        try verifyRequiredColumns(
            in: "ZSDPAGE",
            requiredColumns: legacyPageColumns.map(\.name),
            db: db,
            storeURL: storeURL
        )
    }

    private nonisolated static func verifyRequiredColumns(
        in tableName: String,
        requiredColumns: [String],
        db: OpaquePointer,
        storeURL: URL
    ) throws {
        let columnNames = try sqliteColumnNames(in: tableName, db: db, storeURL: storeURL)
        guard !columnNames.isEmpty else { return }

        let missingColumns = requiredColumns.filter { !columnNames.contains($0) }
        guard missingColumns.isEmpty else {
            throw NSError(
                domain: "AppBootstrap.ModelStore.VerifyColumns",
                code: 1,
                userInfo: [
                    NSFilePathErrorKey: storeURL.path,
                    NSLocalizedDescriptionKey:
                        "\(tableName) missing required columns: \(missingColumns.joined(separator: ", "))",
                ]
            )
        }
    }

    private nonisolated static func backupModelStoreBeforeLegacyColumnRepairIfNeeded(
        at storeURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let backupURL = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("default.store.pre-column-repair.backup", isDirectory: false)
        if fileManager.fileExists(atPath: backupURL.path) {
            guard !legacyColumnRepairBackupIsUsable(at: backupURL) else { return }
            try fileManager.removeItem(at: backupURL)
        }
        try VaultSyncService.backupSQLiteDatabaseIfPresent(at: storeURL, to: backupURL)
    }

    private nonisolated static func legacyColumnRepairBackupIsUsable(at backupURL: URL) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(
            backupURL.path,
            &db,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let db else {
            return false
        }
        defer { sqlite3_close(db) }

        guard let tableCount = try? sqliteUserTableCount(db: db, storeURL: backupURL) else {
            return false
        }
        return tableCount > 0
    }

    private nonisolated static func sqliteUserTableCount(
        db: OpaquePointer,
        storeURL: URL
    ) throws -> Int {
        var statement: OpaquePointer?
        let query = "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';"
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteStoreError(
                domain: "AppBootstrap.ModelStore.TableCount",
                code: Int(sqlite3_errcode(db)),
                storeURL: storeURL,
                db: db
            )
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw sqliteStoreError(
                domain: "AppBootstrap.ModelStore.TableCountStep",
                code: Int(sqlite3_errcode(db)),
                storeURL: storeURL,
                db: db
            )
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    private nonisolated static func sqliteColumnNames(
        in tableName: String,
        db: OpaquePointer,
        storeURL: URL
    ) throws -> Set<String> {
        var statement: OpaquePointer?
        let query = "PRAGMA table_info(\(tableName));"
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteStoreError(
                domain: "AppBootstrap.ModelStore.TableInfo",
                code: Int(sqlite3_errcode(db)),
                storeURL: storeURL,
                db: db
            )
        }
        defer { sqlite3_finalize(statement) }

        var columnNames = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let rawName = sqlite3_column_text(statement, 1) else { continue }
            columnNames.insert(String(cString: rawName))
        }
        return columnNames
    }

    private nonisolated static func sqliteStoreError(
        domain: String,
        code: Int,
        storeURL: URL,
        db: OpaquePointer?
    ) -> NSError {
        let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite store error"
        return NSError(
            domain: domain,
            code: code,
            userInfo: [
                NSFilePathErrorKey: storeURL.path,
                NSLocalizedDescriptionKey: "\(message) (\(storeURL.lastPathComponent))",
            ]
        )
    }

    private nonisolated static func modelStoreArtifactURLs(for storeURL: URL) -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm", isDirectory: false),
            URL(fileURLWithPath: storeURL.path + "-wal", isDirectory: false),
        ]
    }

    private nonisolated static func removeModelStoreArtifacts(
        at storeURL: URL,
        fileManager: FileManager = .default
    ) throws {
        for url in modelStoreArtifactURLs(for: storeURL) where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Services
    let llmService: LLMService
    let localRuntimeControlPlane: BackendRuntimeControlPlane
    let preparedModelRegistryState: PreparedModelRegistryState
    let preparedModelRegistry: PreparedModelRegistry
    let cloudLLMClient: CloudLLMClient
    let triageService: TriageService
    /// Transparency-only audit trail of recent Overseer planning decisions.
    let overseerAuditState = OverseerAuditState()
    let vaultSync: VaultSyncService
    let vaultChatMutator: VaultChatMutator
    let liveNoteScheduler = LiveNoteSchedulerService()
    // Lazy: NoteInsightService construct is deferred until the first
    // user action that needs it (notes reindex, dialogue insight fetch).
    // Most sessions never trigger these paths; the eager construct held
    // ~6-10 MB of model staging buffers for nothing. The build closure
    // captures only `modelContainer` which is `let` on self.
    private var _noteInsightService: NoteInsightService?
    var noteInsightService: NoteInsightService {
        if let existing = _noteInsightService { return existing }
        let new = NoteInsightService(modelContainer: modelContainer)
        _noteInsightService = new
        return new
    }
    private(set) var meaningAnchorService: MeaningAnchorService?

    // MARK: - Coordinators
    private var _coordinator: AppCoordinator?
    var coordinator: AppCoordinator { Self.requireInitialized(_coordinator, name: "coordinator") }

    init() {
        let interval = Log.appPerf.beginInterval("bootstrapInit")
        defer { Log.appPerf.endInterval("bootstrapInit", interval) }

        // NOTE-4 (audit 2026-07-03): recover any note crash-drafts left by an unclean
        // shutdown, before editors load. Runs off-main (file I/O only, no SwiftData) so it
        // doesn't extend the bootstrap; reconciles straight into the durable .md.
        Task.detached(priority: .userInitiated) {
            NoteDraftStore.reconcileOrphanedDrafts()
        }

        // USER REPORT 2026-05-12 (ISSUE-12-011 diagnostics): per-step
        // wall-clock logging so the runtime trace shows exactly which
        // bootstrap sub-step is responsible for the startup hang. The
        // overhead is one Date() per step (microseconds) — strictly
        // diagnostic, can be removed once ISSUE-12-011 is fully closed.
        let bootstrapStart = Date()
        func logStep(_ name: String, since: Date) -> Date {
            let now = Date()
            let elapsedMs = now.timeIntervalSince(since) * 1000.0
            if elapsedMs > 50 {
                Log.app.info("bootstrap step '\(name, privacy: .public)' took \(elapsedMs, format: .fixed(precision: 1)) ms")
            }
            return now
        }
        var stepClock = bootstrapStart

        // Cut the default `URLCache.shared` (4 MB memory + 20 MB disk).
        // Almost every URLSession in this app explicitly opts out of
        // caching (LLM streams, HF downloads, MCP) or uses ephemeral
        // configurations. The shared cache table is dead weight that
        // counts toward resident memory at idle.
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0)
        stepClock = logStep("urlCache_disable", since: stepClock)

        // Register custom fonts (display, pixel, mono, etc.)
        EpistemosFont.registerFonts()
        stepClock = logStep("registerFonts", since: stepClock)

        // Create the SwiftData container against an explicit app-scoped store path.
        // Legacy root-level default.store files are adopted once into the app
        // directory, and known message-column gaps are repaired before opening.
        // Falls back to in-memory only under tests or if container creation fails.
        let schema = Schema(EpistemosSchema.models)
        stepClock = logStep("schemaLoad", since: stepClock)
        let container: ModelContainer
        let dbError: Error?
        let resolvedPersistenceMode: PersistenceMode
        let fileManager = FileManager.default
        let applicationSupportDirectory = FoundationSafety.userApplicationSupportDirectory(fileManager: fileManager)
        Self.prepareSharedSubstrateContainer(AppGroupContainer.shared)
        let usesInMemoryModelStore = Self.isRunningTests
        let modelStoreURL = Self.persistentModelStoreURL(
            applicationSupportDirectory: applicationSupportDirectory,
            fileManager: fileManager
        )
        let modelConfiguration: ModelConfiguration
        if usesInMemoryModelStore {
            modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            do {
                _ = try Self.preparePersistentModelStoreIfNeeded(
                    applicationSupportDirectory: applicationSupportDirectory,
                    fileManager: fileManager
                )
            } catch {
                Log.persistence.error(
                    "Persistent model store preparation failed: \(error.localizedDescription, privacy: .public)"
                )
                RuntimeDiagnostics.record(
                    .error,
                    category: "Persistence",
                    message: "Persistent model store preparation failed",
                    metadata: [
                        "error": error.localizedDescription,
                        "storePath": modelStoreURL.path,
                    ]
                )
            }
            modelConfiguration = ModelConfiguration(url: modelStoreURL)
        }
        stepClock = logStep("modelStorePrepare", since: stepClock)
        do {
            container = try ModelContainer(
                for: schema,
                configurations: modelConfiguration
            )
            stepClock = logStep("modelContainerInit", since: stepClock)
            dbError = nil
            resolvedPersistenceMode = usesInMemoryModelStore
                ? .testInMemory
                : .durable(url: modelStoreURL)
        } catch {
            Log.persistence.error(
                "Database failed to load; entering recovery-only in-memory mode: \(error.localizedDescription, privacy: .public)"
            )
            RuntimeDiagnostics.record(
                .fault,
                category: "Persistence",
                message: "Database failed to load; entering recovery-only in-memory mode",
                metadata: ["error": error.localizedDescription]
            )
            container = Self.makeFallbackModelContainer(schema: schema)
            dbError = error
            resolvedPersistenceMode = .inMemoryRecovery(reason: error.localizedDescription)
        }
        self.modelContainer = container
        self.persistenceMode = resolvedPersistenceMode
        self.databaseError = dbError

        // Wire CompanionState to the canonical SwiftData ModelContext
        // so the Farm + Notes Sidebar Skin (Simulation v1.6) can read
        // the roster on first paint. seedDefaultIfEmpty is a one-shot
        // that adds a small default agent roster if the user has never
        // created any — gives the Landing agent dock something to show without
        // forcing the user through the wizard on first launch.
        //
        // RCA13 P6 first-click responsiveness: attach inline (cheap
        // property set), defer the seed to the next main-actor tick so
        // the SwiftData fetch + 4 inserts on first launch don't sit on
        // the bootstrap critical path. The Farm has a graceful empty
        // state for the ~1 frame between paint and seed.
        companionState.attachModelContext(container.mainContext)
        Task { @MainActor [weak companionState] in
            companionState?.seedDefaultIfEmpty()
        }

        // InferenceState reads Keychain + checks Apple Intelligence availability
        let inference = InferenceState()
        self.inferenceState = inference

        let embeddingService = graphState.embeddingService
        let localRuntimeControlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [],
                primaryGenerationRuntimeKind: .remote,
                allowMLXGenerationFallback: false
            ),
            embeddingResolver: { request in
                embeddingService.queryEmbedding(
                    for: request.text,
                    expectedDimension: request.expectedDimension
                )
            }
        )
        self.localRuntimeControlPlane = localRuntimeControlPlane

        let preparedModelRegistryState = PreparedModelRegistryState()
        self.preparedModelRegistryState = preparedModelRegistryState

        let preparedModelRegistry = PreparedModelRegistry()
        self.preparedModelRegistry = preparedModelRegistry

        // Defer the prepared-model manifest load off the synchronous init path.
        // Reading the manifest + parsing it previously blocked the first
        // foreground tap on launch (the "app feels frozen when I click on it"
        // symptom). The state starts empty; downstream clients are wired with
        // `nil` generation-runtime configuration and will fall back to
        // baseline defaults. `refreshPreparedRetrievalRuntimeConfigurationIfNeeded`
        // is scheduled from `didStartPrimaryLaunchInitialization` / activation
        // notifications and will apply the real snapshot once loaded.
        graphState.applyPreparedRetrievalRuntimeConfiguration(nil)

        let cloudLLMClient = CloudLLMClient(inference: inference)
        self.cloudLLMClient = cloudLLMClient

        // LLMService is the shared generation facade used by older subsystems.
        let llm = LLMService(
            inference: inference,
            cloudLLMClient: cloudLLMClient
        )
        self.llmService = llm

        // Start centralized power authority — must be before any subsystem that
        // checks PowerGuard.shared.currentMode during init.
        PowerGuard.shared.start()

        // Start main thread watchdog to detect UI hangs (skipped in eco/lowPower).
        if !Self.isRunningTests && !PowerGuard.shared.shouldDisableBackground {
            MainThreadWatchdog.install()
        }

        // Start centralized thermal authority before any inference work.
        Task { await ThermalGuard.shared.start() }

        supervisor.start()

        // TriageService keeps foundation retrieval available while app-local generation stays removed.
        let triage = TriageService(
            inference: inference,
            cloudLLMService: cloudLLMClient,
            prepareForRouting: {}
        )
        self.triageService = triage

        // VaultSyncService — hybrid persistence bridge
        self.vaultSync = VaultSyncService(modelContainer: container)
        self.vaultChatMutator = VaultChatMutator(
            vaultResolver: { _ in
                guard let root = await AppBootstrap.shared?.vaultSync.vaultURL else {
                    throw VaultChatMutatorError.vaultUnavailable
                }
                return root
            },
            autoCommitInAgentMode: false
        )

        // Meaning Anchor Service — generates structured chat snapshots for graph intelligence
        self.meaningAnchorService = MeaningAnchorService(
            triageService: triage,
            graphState: graphState,
            modelContainer: container
        )

        // PipelineService — direct local answer streaming + tool-enabled loop
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: llm,
            triageService: triage,
            inference: inference,
            eventBus: eventBus,
            vaultPathProvider: { [weak vaultSync] in
                vaultSync?.vaultURL?.path
            },
            skillNamesProvider: {
                SkillDiscoveryCatalog.discoverSkillEntries().map(\.title).sorted()
            },
            vaultRankingSearchProvider: { [weak vaultSync] query in
                // L1187 — deterministic ranked vault answer (flag-gated in the responder). Uses the
                // installed vault search + the model container's main context to resolve note paths.
                guard let search = vaultSync?.searchService else { return nil }
                return VaultBestEssayResponder.liveAnswer(
                    query: query,
                    searchService: search,
                    modelContext: container.mainContext
                )
            }
        )

        // Create coordinators
        let appCoordinator = AppCoordinator(
            bootstrap: self,
            eventBus: eventBus,
            uiState: uiState,
            dailyBriefState: dailyBriefState,
            triageService: triage,
            vaultSync: vaultSync,
            pipelineService: pipeline,
            modelContainer: container,
            notesUI: notesUI
        )
        self._coordinator = appCoordinator

        // Set shared before wiring so that any callbacks can access it.
        AppBootstrap.shared = self
        if !Self.isRunningTests {
            VaultCrashRecorder.install(vaultURL: vaultSync.vaultURL)
        }
        chatApprovalQueue.sessionFolderPathResolver = { sessionId in
            sessionFolderPathLocal(sessionId: sessionId)
        }
        sovereignGateLifecycleObserver.start(gate: sovereignGate)

        // V6.2 Option B: start the LatestAnswerPacketSink so SwiftUI
        // bubble renders can synchronously look up the AnswerPacket
        // bound to a ChatMessage.answerPacketId. Idempotent — safe
        // to call multiple times if AppBootstrap is reconstructed.
        LatestAnswerPacketSink.shared.start()

        // SUBSTRATE Phase 2 (SUBSTRATE_BUILD_SEQUENCE) — LOAD-ON-LAUNCH RING RESTORE: seed the
        // AnswerPacketEmitter ring from the durable JSONL so per-answer provenance survives relaunch
        // (emit() already persists; the ring just started empty on launch). Off-MainActor (actor),
        // best-effort, only seeds when the ring is empty so it never duplicates live-emitted packets.
        Task.detached(priority: .utility) {
            await AnswerPacketEmitter.shared.restoreFromPersistence()
        }

        // ISSUE-2026-05-12-008: amortize BlockMirror first-parse for the 5
        // most-recently-modified pages so the first-open hang (~10-200ms per
        // note) moves from click-time to launch-time. Uses the canonical
        // R.3 fallback chain so disk-only pages (production majority) are
        // covered alongside inline-body pages.
        Task.detached(priority: .userInitiated) {
            await AppBootstrap.prewarmRecentBlockMirrors(
                modelContainer: container,
                limit: 5
            )
        }

        self._workspaceService = WorkspaceService(modelContainer: container)
        self._workspaceSummaryService = WorkspaceSummaryService(
            triageService: triage, activityTracker: activityTracker, modelContainer: container
        )

        // Initialize reasoning loop (STaR + autoresearch flywheel)
        // Opt-in via Settings → Omega. Do NOT force-enable at startup.
        let reasoning = ReasoningLoopService(triageService: triage)
        reasoning.config.enabled = UserDefaults.standard.bool(forKey: "omega.enableReasoningLoop")
        reasoning.onTracesGenerated = { _ in }
        self._reasoningLoopService = reasoning

        // Device-action / computer-use infrastructure removed — cloud-only build.

        // Initialize the persistent event store (separate SQLite database with WAL mode).
        EventStore.shared = EventStore()
        if let eventStore = EventStore.shared {
            self._mutationOpLogProjectionWorker = MutationOpLogProjectionWorker(
                eventStore: eventStore,
                databaseURL: MutationOpLogProjectionWorker.databaseURL(
                    applicationSupportDirectory: applicationSupportDirectory
                )
            )
        }
        self._timeMachineService = TimeMachineService(modelContainer: container)
        self.workspaceService.timeMachineService = timeMachineService

        // FrictionMonitor stays eager — read by RootView at startup.
        // (AmbientCapture and the rest of the Omega ambient/cognitive chain were removed.)
        self._frictionMonitor = FrictionMonitorService(config: epistemosConfig)

        // Phase 6.5: Text capture pipeline — capture → structure → memory → evidence → trace
        self._textCapturePipeline = TextCapturePipeline()
        FrictionMonitorService.shared = frictionMonitor

        // Wire all events (pipeline, toast, vault, daily brief)
        appCoordinator.wireAll()

        // Evict old disk style cache entries in background (filesystem I/O).
        Task(priority: .utility) { DiskStyleCache.shared.evictIfNeeded() }

        // Give VaultSyncService access to EventBus for change notifications
        vaultSync.setEventBus(eventBus)

        // Phase R.3 — initialize the canonical Rust `VaultResourceService`
        // (in `agent_core::resources::bridge::resource_service_init`) as
        // soon as we know the vault URL. This is scaffolding for the
        // planned R.3 migrations (NoteFileStorage / VaultIndexActor /
        // NotesSidebar read paths → unified gateway). Until those call
        // sites migrate, this init is a no-op at the user level — but
        // `resourceServiceIsReady()` now flips to true, which is the
        // prerequisite for every subsequent R.3 work.
        //
        // Errors are logged and swallowed: we do NOT want the gateway
        // init to crash app launch in the unlikely case of a
        // SQLite/filesystem failure. The legacy note I/O paths
        // continue to work regardless.
        initializeRustResourceServiceIfReady()

        // Phase R.5 persistence — migrate the in-memory permission
        // store to an on-disk SQLite file at a container-safe path.
        // Without this, R.5 grants disappear on app quit, so the
        // user has to re-say "you have my permission" every launch.
        // With this, a grant recorded once survives future launches
        // until the user explicitly revokes (or until the scope
        // expires).
        //
        // We call this BEFORE any chat UI can take a user turn, so
        // the very first grant of the session lands in the on-disk
        // store — not in the in-memory fallback that would be
        // replaced by the subsequent init and thus lose the row.
        initializeRustPermissionStoreIfReady()
        verifyAgentCorePolicyProfile()

        // W8.7 — open the persistent Halo Shadow backend at the
        // current vault and run the first-launch crawl. Without this,
        // every first-launch user opens Halo to an empty panel and
        // the V1 "type a sentence, see a related thought appear" demo
        // fails on day one. Idempotent on repeat launches.
        initializeShadowBackendIfReady()

        // KC cutover Slice 3 — stand up the in-app KnowledgeCore shadow runtime
        // (flag-gated behind knowledgeCoreRuntimeV0, default OFF). No-op unless
        // the flag is on, so default-build startup is unchanged.
        initializeKnowledgeCoreRuntimeIfReady()

        // W-46.1 (Terminal A 2026-05-23) — open the production Eidos
        // vault index with a vault-path-stable signature so the
        // closed-citation manifest is `vault-<sig>` (not the fixture
        // manifest). This is the seam that flips EidosHealthRow's
        // chip-strip from orange ("fixture path active") to green
        // ("production vault binding active") once the first retrieve
        // runs. Bulk crawl insertion is Terminal B's piggyback on
        // ShadowVaultBootstrapper — until then, callers can insert
        // per-edit via `EidosBridge.insertVaultNote(...)`.
        EidosVaultBootstrapper.openProductionIndexIfReady(
            vaultURL: vaultSync.vaultURL
        )

        // AP7 — bulk-prefetch every `*.epistemos.json` sidecar in
        // the active vault into SidecarCache so the first graph
        // render + the first depth-overlay query don't pay per-node
        // disk I/O. Per the perf agent: 1000 ms first-render cost
        // → 100-150 ms parallel prefetch. Background priority so it
        // doesn't compete with the user's first interactions.
        if let vaultURL = vaultSync.vaultURL {
            Task.detached(priority: .background) {
                _ = await EpistemosSidecarStore.prefetchAll(under: vaultURL)
            }
        }

        // Phase R.3 reactive re-init — subscribe to `.vaultChanged` so
        // the gateway tracks vault switches (bookmark restore lands
        // async, user can switch vaults, tests seed new vault URLs).
        // The handler is idempotent on vault-content mutations thanks
        // to the path-equality gate inside
        // `initializeRustResourceServiceIfReady()`.
        wireR3VaultSwitchObserver()


        // Instant recall has a warm idle path so the first typed sentence does
        // not pay vault hydration. The actual rebuild still runs off-main.
        instantRecallService.configureInitialSnapshotProvider { [self] in
            snapshotInstantRecallNotes()
        }
        if !Self.isRunningTests {
            Task { @MainActor [instantRecallService, contextualShadowsState] in
                try? await Task.sleep(for: .milliseconds(1_600))
                guard contextualShadowsState.isEnabled else { return }
                instantRecallService.prewarmForAmbientRecall()
            }
        }

        // Body-file migration runs off-main to avoid launch hitching.
        // Orphan cleanup now waits for a confirmed healthy vault attach/import.
        Task(priority: .utility) {
            await migrateBodiesToFileStorage()
        }

        // Keep the graph fully lazy at launch so normal idle use does not pay the
        // graph-store residency cost until the graph is actually opened.
        graphState.modelContext = container.mainContext

        scheduleMetalShaderWarmupIfNeeded()

        // Configure query engine with live dependencies (used by graph sidebar search).
        // The search index resolves lazily on first query so launch does not pay
        // the FTS/database setup cost unless the user actually opens search.
        queryEngine.configure(
            graphStore: graphState.store,
            graphState: graphState,
            searchIndexProvider: { [vaultSync] in
                vaultSync.searchService ?? Self.makeFallbackSearchIndexService()
            },
            preparedRetrievalRuntimeConfiguration: preparedModelRegistryState.retrievalRuntimeConfiguration
        )

        // Initialize Paperclip high-frequency state store (SQLite WAL mode)
        do {
            let store = try PaperclipStateStore()
            self._paperclipStore = store
            let paperclipHeartbeatClock = PaperclipHeartbeatClock(store: store)
            self._paperclipHeartbeatClock = paperclipHeartbeatClock
            if !Self.isRunningTests {
                Task(priority: .utility) {
                    await paperclipHeartbeatClock.start()
                }
            }
        } catch {
            Log.app.error("PaperclipStateStore init failed: \(error.localizedDescription)")
        }

        // App Shortcuts metadata is static and Settings exposes an explicit
        // refresh action. Do not touch external Shortcuts services during
        // passive launch; that path has triggered privacy/TCC diagnostics.

        commandCenterLocalHotkeyMonitor = nil
        commandCenterGlobalHotkeyMonitor = nil

        // D4 faculty roster: log the resolved primary agent model so users
        // can verify which local agent is selected. Default is the 7-8B 4-bit
        // fallback that fits the 16 GB Mac ceiling; the 36B LocalAgent is
        // gated on ≥32 GB host RAM + explicit opt-in. Power-user mode
        // preserves Capability Ceiling controls, but does not lower the dense
        let configuredCloudProvidersSummary: String
        if inference.isDeferredCloudCredentialBootstrapInFlight {
            configuredCloudProvidersSummary = "deferred"
        } else {
            configuredCloudProvidersSummary = inference.configuredCloudProviders
                .map(\.rawValue)
                .joined(separator: ",")
        }

        Log.app.info(
            """
            App-local model stack removed: \
            cloud-models=\(inference.cloudModelsEnabled ? "ON" : "OFF", privacy: .public), \
            configured-cloud-providers=\(configuredCloudProvidersSummary, privacy: .public)
            """
        )

        Log.app.info("AppBootstrap: initialized — foundation services ready")
    }

    private static func prepareSharedSubstrateContainer(
        _ appGroupContainer: AppGroupContainer = .shared
    ) {
        do {
            try appGroupContainer.ensureLayout()
            try appGroupContainer.migrateLegacyDatabasesIfNeeded()
            Log.app.info(
                "AppBootstrap: shared substrate container ready at \(appGroupContainer.rootURL.path, privacy: .public)"
            )
        } catch {
            Log.app.error(
                "AppBootstrap: shared substrate container init failed: \(error.localizedDescription, privacy: .public)"
            )
            RuntimeDiagnostics.record(
                .error,
                category: "AppGroup",
                message: "Shared substrate container init failed",
                metadata: [
                    "error": error.localizedDescription,
                    "group": AppGroupContainer.canonicalGroupIdentifier,
                ]
            )
        }
    }

    nonisolated static func startupIntegritySamplePageIdsForTesting(_ pageIds: [String]) -> [String] {
        let normalized = Array(Set(pageIds.filter { NoteFileStorage.isValidPageId($0) })).sorted()
        guard !normalized.isEmpty else { return [] }

        let sampleSize = min(normalized.count, max(1, normalized.count / 10), 64)
        guard sampleSize < normalized.count else { return normalized }

        let lastIndex = normalized.count - 1
        let strideDivisor = max(1, sampleSize - 1)
        let sampled = (0..<sampleSize).map { sampleIndex in
            let position = Int(round(Double(sampleIndex * lastIndex) / Double(strideDivisor)))
            return normalized[position]
        }
        return Array(NSOrderedSet(array: sampled)) as? [String] ?? sampled
    }

    nonisolated static func startupIntegrityReportForTesting(
        samplePageIds: [String],
        readBodyData: (String) -> Data?,
        eventStoreAvailable: Bool,
        vaultBookmarkValidation: VaultBookmarkStartupValidation = VaultBookmarkStartupValidation(
            bookmarkExists: false,
            isReadyForAutomaticRestore: true,
            failureReason: nil
        ),
        pageSnapshots: [StartupIntegrityPageSnapshot] = [],
        bodyFileExists: (String) -> Bool = { _ in false },
        filePathReadable: (String) -> Bool = { _ in false }
    ) -> StartupIntegrityReport {
        let corruptedPageIds = samplePageIds.filter { readBodyData($0) == nil }
        let unrecoverablePageIds = startupUnrecoverablePageIdsForTesting(
            pageSnapshots,
            bodyFileExists: bodyFileExists,
            filePathReadable: filePathReadable
        )
        return StartupIntegrityReport(
            sampledPageIds: samplePageIds,
            corruptedPageIds: corruptedPageIds,
            unrecoverablePageIds: unrecoverablePageIds,
            eventStoreAvailable: eventStoreAvailable,
            vaultBookmarkExists: vaultBookmarkValidation.bookmarkExists,
            vaultBookmarkReadyForAutomaticRestore: vaultBookmarkValidation.isReadyForAutomaticRestore,
            vaultBookmarkFailureReason: vaultBookmarkValidation.failureReason
        )
    }

    nonisolated static func startupUnrecoverablePageIdsForTesting(
        _ pageSnapshots: [StartupIntegrityPageSnapshot],
        bodyFileExists: (String) -> Bool,
        filePathReadable: (String) -> Bool
    ) -> [String] {
        pageSnapshots.compactMap { page in
            let hasManagedBody = bodyFileExists(page.id)
            let hasReadableVaultSource = page.filePath.map { filePath in
                let trimmedPath = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedPath.isEmpty else { return false }
                return filePathReadable(trimmedPath)
            } ?? false
            guard !hasManagedBody,
                  !hasReadableVaultSource,
                  !page.hasInlineBody,
                  page.hasMeaningfulMetadata else {
                return nil
            }
            return page.id
        }
        .sorted()
    }

    nonisolated static func startupIntegrityToastForTesting(
        report: StartupIntegrityReport
    ) -> StartupIntegrityToast? {
        var segments: [String] = []
        var type: ToastType = .warning

        if !report.eventStoreAvailable {
            segments.append("session store is unavailable.")
            type = .error
        }

        if let vaultBookmarkFailureReason = report.vaultBookmarkFailureReason {
            segments.append("\(vaultBookmarkFailureReason) Automatic vault restore was paused.")
            type = .error
        }

        let corruptedCount = report.corruptedPageIds.count
        if corruptedCount > 0 {
            let noun = corruptedCount == 1 ? "note body" : "note bodies"
            segments.append(
                "quarantined \(corruptedCount) corrupted \(noun). Automatic vault restore was paused."
            )
            type = .error
        }

        let unrecoverableCount = report.unrecoverablePageIds.count
        if unrecoverableCount > 0 {
            let noun = unrecoverableCount == 1 ? "note" : "notes"
            segments.append(
                "found \(unrecoverableCount) \(noun) with no body file or vault source. Review them before editing."
            )
        }

        guard !segments.isEmpty else { return nil }
        return StartupIntegrityToast(
            message: "Startup integrity warning: \(segments.joined(separator: " "))",
            type: type
        )
    }

    private func startupIntegrityPageSnapshots() -> [StartupIntegrityPageSnapshot] {
        let context = modelContainer.mainContext
        let pages: [SDPage]
        do {
            pages = try context.fetch(FetchDescriptor<SDPage>())
        } catch {
            recordPersistenceIssue("Startup integrity snapshot failed", error: error)
            return []
        }

        return pages
            .filter { !$0.isTemplate }
            .map { page in
                let titleHasContent = !page.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let summaryHasContent = !page.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let hasFrontMatter = !(page.frontMatterData?.isEmpty ?? true)
                let hasMeaningfulMetadata =
                    titleHasContent
                    || summaryHasContent
                    || !page.tags.isEmpty
                    || hasFrontMatter
                    || !page.blockReferences.isEmpty
                    || page.needsVaultSync
                    || page.updatedAt.timeIntervalSince(page.createdAt) > 1

                return StartupIntegrityPageSnapshot(
                    id: page.id,
                    filePath: page.filePath,
                    hasInlineBody: !page.body.isEmpty,
                    hasMeaningfulMetadata: hasMeaningfulMetadata
                )
            }
    }

    private nonisolated static func shouldDeferLaunchVaultPreloads(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        vaultBookmarkValidation.bookmarkExists && vaultBookmarkValidation.isReadyForAutomaticRestore
    }

    private nonisolated static func shouldScheduleInitialGraphLoad(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        false
    }

    private nonisolated static func shouldWaitForPrimaryLaunchBeforeAutomaticVaultRestore(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        shouldDeferLaunchVaultPreloads(vaultBookmarkValidation: vaultBookmarkValidation)
    }

    nonisolated static func shouldScheduleInitialGraphLoadForTesting(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        shouldScheduleInitialGraphLoad(vaultBookmarkValidation: vaultBookmarkValidation)
    }

    nonisolated static func shouldWaitForPrimaryLaunchBeforeAutomaticVaultRestoreForTesting(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) -> Bool {
        shouldWaitForPrimaryLaunchBeforeAutomaticVaultRestore(
            vaultBookmarkValidation: vaultBookmarkValidation
        )
    }

    func performStartupIntegrityCheck() async -> StartupIntegrityReport {
        if let startupIntegrityReport {
            return startupIntegrityReport
        }

        let eventStoreAvailable = EventStore.shared != nil
        let vaultBookmarkValidation = vaultSync.startupBookmarkValidation()
        let pageSnapshots = startupIntegrityPageSnapshots()
        let report = await Task.detached(priority: .utility) {
            Self.startupIntegrityReportForTesting(
                samplePageIds: Self.startupIntegritySamplePageIdsForTesting(
                    NoteFileStorage.managedBodyPageIds()
                ),
                readBodyData: { pageId in
                    NoteFileStorage.readBodyData(pageId: pageId, fast: true)
                },
                eventStoreAvailable: eventStoreAvailable,
                vaultBookmarkValidation: vaultBookmarkValidation,
                pageSnapshots: pageSnapshots,
                bodyFileExists: { pageId in
                    NoteFileStorage.bodyExists(pageId: pageId)
                },
                filePathReadable: { filePath in
                    FileManager.default.isReadableFile(atPath: filePath)
                }
            )
        }.value

        startupIntegrityReport = report

        if !report.unrecoverablePageIds.isEmpty {
            Log.persistence.warning(
                "Startup integrity warning: \(report.unrecoverablePageIds.count, privacy: .public) notes have no managed body or readable vault source"
            )
        }

        if let toast = Self.startupIntegrityToastForTesting(report: report) {
            uiState.showToast(toast.message, type: toast.type)
        }

        return report
    }

    func performPrimaryLaunchInitialization() async {
        guard !didStartPrimaryLaunchInitialization else { return }
        didStartPrimaryLaunchInitialization = true

        Self.scheduleStartupAutoDiscoveryLoggingIfNeeded()
        let shouldPopulateAgentCoreEnvironment = Self.shouldPopulateAgentCoreEnvironmentAtLaunch(
            deferredCloudCredentialBootstrapInFlight: inferenceState.isDeferredCloudCredentialBootstrapInFlight
        )

        // Clear any stale managed provider env slots from older launches
        // without reading Keychain on the main thread.
        Task.detached(priority: .utility) {
            guard shouldPopulateAgentCoreEnvironment else { return }
            Self.populateAgentCoreEnvironment()
        }

        activityTracker.loadFlushedEvents()
        workspaceService.autoRestore()
        activityTracker.startTracking()
        workspaceSummaryService.startAutoSummaryLoop()
        workspaceService.startAutoSave()
        if workspaceService.welcomeBack != nil {
            Task { @MainActor [weak self] in
                await self?.refreshWelcomeBackSummary()
            }
        }
        refreshLiveNoteScheduler()
        didCompletePrimaryLaunchInitialization = true

        // One-time meaning anchor backfill for existing chats
        if !UserDefaults.standard.bool(forKey: "epistemos.anchorBackfillComplete") {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(30))
                await self?.meaningAnchorService?.backfillExistingChats()
                UserDefaults.standard.set(true, forKey: "epistemos.anchorBackfillComplete")
            }
        }

        startDeferredRuntimeServicesIfNeeded()
    }

    func runAutomaticVaultRestoreAfterLaunchIfNeeded() async {
        let vaultBookmarkValidation = vaultSync.startupBookmarkValidation()
        let report = await performStartupIntegrityCheck()
        guard !report.shouldBlockAutomaticVaultRestore else {
            if vaultBookmarkValidation.bookmarkExists {
                vaultSync.clearPendingStartupRestore()
            }
            return
        }

        await waitForPrimaryLaunchInitializationIfNeeded(
            vaultBookmarkValidation: vaultBookmarkValidation
        )
        await vaultSync.restoreVaultFromBookmark()
        refreshLiveNoteScheduler()
    }

    private func refreshWelcomeBackSummary() async {
        guard UserDefaults.standard.bool(forKey: "epistemos.enableLaunchWelcomeBackModelRefresh") else {
            applyStoredWelcomeBackSummary()
            return
        }

        await workspaceSummaryService.generateSummaryNow()
        applyStoredWelcomeBackSummary()
    }

    private func applyStoredWelcomeBackSummary() {
        let predicate = #Predicate<SDWorkspace> { $0.isAutoSave == true }
        do {
            if let ws = try modelContainer.mainContext.fetch(
                FetchDescriptor(predicate: predicate)
            ).first, !ws.summary.isEmpty {
                workspaceService.welcomeBack?.intentSummary = WelcomeBackInfo.cleanedSummaryText(from: ws.summary)
            }
        } catch {
            recordPersistenceIssue("Welcome-back summary fetch failed", error: error)
        }
    }

    private func waitForPrimaryLaunchInitializationIfNeeded(
        vaultBookmarkValidation: VaultBookmarkStartupValidation
    ) async {
        guard Self.shouldWaitForPrimaryLaunchBeforeAutomaticVaultRestore(
            vaultBookmarkValidation: vaultBookmarkValidation
        ) else { return }

        let clock = ContinuousClock()
        let deadline = clock.now + Self.primaryLaunchInitializationWaitTimeout

        while !didCompletePrimaryLaunchInitialization && clock.now < deadline {
            do {
                try await Task.sleep(for: Self.primaryLaunchInitializationPollInterval)
            } catch is CancellationError {
                return
            } catch {
                Log.app.error("Primary launch initialization wait failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }

    private func startDeferredRuntimeServicesIfNeeded() {
        guard !Self.isRunningTests else { return }
        guard !didStartDeferredRuntimeServices else { return }
        didStartDeferredRuntimeServices = true

        Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.deferredRuntimeServicesDelay)
            } catch is CancellationError {
                return
            } catch {
                Log.app.error("Deferred runtime services launch failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let self else { return }

            self.mutationOpLogProjectionWorker?.scheduleDrain(reason: "deferred_runtime_services")

            // Load the prepared-model manifest off the main launch path. The
            // synchronous `preparedModelRegistry.load()` that used to run in
            // `init` blocked the first foreground tap while parsing JSON — the
            // "tap on the app and it freezes" symptom. Doing it here lets the
            // UI come up first and then populates the registry configuration
            // once the deferred runtime services bring themselves online.
            self.refreshPreparedRetrievalRuntimeConfigurationIfNeeded()

        }
    }

    // MARK: - Forwarding (for external callers that reference AppBootstrap directly)

    func refreshAmbientManifest() { coordinator.refreshAmbientManifest() }

    /// 0.48b-part2: persist an opened Work/OpenCode session as an SDChat "worker" row so it appears in the WORK
    /// section of the unified recent-chats popover. Keyed by a STABLE id (the workspace path) so re-opening the
    /// same workspace updates ONE row instead of spawning duplicates. Honest: a session MARKER (title + timestamp),
    /// not faked message bubbles — the work surface is a PTY, not a message thread; reopen = relaunch work there.
    @MainActor
    func persistWorkSession(id: String, title: String) {
        let context = modelContainer.mainContext
        let predicate = #Predicate<SDChat> { $0.id == id }
        let descriptor = FetchDescriptor<SDChat>(predicate: predicate)
        let chat: SDChat
        if let existing = (try? context.fetch(descriptor))?.first {
            chat = existing
        } else {
            let created = SDChat(title: title, chatType: "worker")
            created.id = id
            context.insert(created)
            chat = created
        }
        chat.title = title
        chat.markAsWorkerSession()   // sets chatType "worker" + updatedAt = .now
        try? context.save()
    }

    func refreshLiveNoteScheduler() {
        guard !Self.isRunningTests else { return }
        // Live notes are opt-in (UserDefaults key "epistemos.liveNotes.enabled").
        // Most vaults contain zero live-note task blocks, so scanning 800+ pages
        // on a timer was burning idle CPU for no observed benefit. Users who
        // actually rely on the feature can flip the toggle in Settings.
        let enabled = UserDefaults.standard.bool(forKey: "epistemos.liveNotes.enabled")
        guard enabled, let vaultURL = vaultSync.vaultURL else {
            liveNoteScheduler.stop()
            return
        }

        liveNoteScheduler.start(
            llmService: llmService,
            modelContainer: modelContainer,
            vaultRoot: vaultURL,
            approvalMutator: vaultChatMutator
        )
    }
    static func gradeFromConfidence(_ confidence: Double) -> EvidenceGrade {
        switch confidence {
        case 0.85...:
            return .a
        case 0.70..<0.85:
            return .b
        case 0.50..<0.70:
            return .c
        case 0.30..<0.50:
            return .d
        default:
            return .f
        }
    }

    private static func makeFallbackModelContainer(schema: Schema) -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            preconditionFailure(
                "Failed to create in-memory model container fallback: \(error.localizedDescription)"
            )
        }
    }

    private func applyPreparedRetrievalRuntimeConfiguration(_ configuration: PreparedRetrievalRuntimeConfiguration?) {
        graphState.applyPreparedRetrievalRuntimeConfiguration(configuration)
        queryEngine.applyPreparedRetrievalRuntimeConfiguration(configuration)
    }

    private func refreshPreparedRetrievalRuntimeConfigurationIfNeeded() {
        preparedRetrievalRefreshTask?.cancel()
        preparedRetrievalRefreshTask = Task(priority: .utility) { [weak self] in
            let result: Result<PreparedModelRegistrySnapshot, Error>
            do {
                let snapshot = try await Task.detached(priority: .utility) {
                    try await PreparedModelRegistry().load()
                }.value
                result = .success(snapshot)
            } catch {
                result = .failure(error)
            }

            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.preparedRetrievalRefreshTask = nil
                switch result {
                case .success(let snapshot):
                    self.applyPreparedRetrievalRuntimeConfiguration(snapshot)
                case .failure(let error):
                    self.applyPreparedRetrievalRuntimeConfiguration(error)
                }
            }
        }
    }

    /// Test-only seam to force the deferred prepared-model-registry load to
    /// complete. Production code relies on
    /// `refreshPreparedRetrievalRuntimeConfigurationIfNeeded` fired from the
    /// deferred-services task, which returns before the manifest JSON is
    /// parsed; tests that assert state-is-populated need a deterministic
    /// await point.
    func loadPreparedModelRegistryForTesting() async {
        refreshPreparedRetrievalRuntimeConfigurationIfNeeded()
        await preparedRetrievalRefreshTask?.value
    }

    private func applyPreparedRetrievalRuntimeConfiguration(
        _ snapshot: PreparedModelRegistrySnapshot
    ) {
        guard snapshot.manifestURL != preparedModelRegistryState.manifestURL
            || snapshot.entriesByKey != preparedModelRegistryState.entriesByKey else {
            return
        }

        preparedModelRegistryState.apply(snapshot)
        applyPreparedRetrievalRuntimeConfiguration(snapshot.retrievalRuntimeConfiguration)
    }

    private func applyPreparedRetrievalRuntimeConfiguration(_ error: Error) {
        guard preparedModelRegistryState.lastErrorMessage != error.localizedDescription
            || !preparedModelRegistryState.entriesByKey.isEmpty else {
            return
        }

        preparedModelRegistryState.apply(error: error)
        applyPreparedRetrievalRuntimeConfiguration(nil)
    }

    // MARK: - On-Demand Memory Unload (ISSUE-2026-05-12-006)

    /// Result of a manual on-demand idle-unload, reported back to the
    /// diagnostic UI so the user can see what was actually released
    /// without spinning up Instruments.
    public struct IdleUnloadReport: Sendable, Equatable {
        public let residentMBBefore: Int
        public let residentMBAfter: Int
        public let mbFreed: Int
        public let rustSegmentsEvicted: UInt32
        public let rustSegmentBytesFreedMB: UInt64
        public let rustSessionsPruned: UInt32
        public let mlxUnloaded: Bool
        public let searchCachesReleased: Bool
        public let durationMs: Int
    }

    /// Run the same unload sequence the critical memory-pressure
    /// handler runs, but on demand and synchronous so the diagnostic
    /// row can report the actual delta.
    ///
    /// This is the in-app substitute for "open Instruments and profile."
    /// Users can click the Force Idle Unload button, see the RSS drop,
    /// and report which subsystem actually contributed.
    @MainActor
    public func forceIdleUnload() async -> IdleUnloadReport {
        let start = Date()
        let before = Self.currentResidentMB()

        // Rust-side relief: shared-memory arena evict + finished-session prune
        let relief = respondToMemoryPressure(level: 2)

        // Swift-side: search caches
        let searchService = vaultSync.searchService
        if let searchService {
            searchService.releaseMemoryPressureCaches()
        }

        let mlxUnloaded = false

        let after = Self.currentResidentMB()
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)

        Log.app.info(
            "ForceIdleUnload: \(before, privacy: .public) MB → \(after, privacy: .public) MB, freed \(before - after, privacy: .public) MB in \(durationMs, privacy: .public) ms"
        )

        return IdleUnloadReport(
            residentMBBefore: before,
            residentMBAfter: after,
            mbFreed: max(0, before - after),
            rustSegmentsEvicted: relief.segmentsEvicted,
            rustSegmentBytesFreedMB: relief.segmentBytesFreed / (1024 * 1024),
            rustSessionsPruned: relief.sessionsPruned,
            mlxUnloaded: mlxUnloaded,
            searchCachesReleased: searchService != nil,
            durationMs: durationMs
        )
    }

    /// Helper for ForceIdleUnload diagnostics. Mirrors the existing
    /// `EpistemosApp.currentMemoryUsageMB()` private helper so the
    /// before/after measurements use the same accounting basis as
    /// the rest of the app.
    private static func currentResidentMB() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rawPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int(info.resident_size / (1024 * 1024))
    }

    // MARK: - Database Recovery

    func resetDatabaseAndRelaunch() {
        guard !Self.isRunningTests else {
            Log.app.info("Skipping database reset relaunch under tests")
            return
        }

        let fm = FileManager.default
        let appSupport = FoundationSafety.userApplicationSupportDirectory(fileManager: fm)
        let legacyStoreURL = Self.legacyRootModelStoreURL(applicationSupportDirectory: appSupport)
        let appScopedStoreURL = Self.persistentModelStoreURL(
            applicationSupportDirectory: appSupport,
            fileManager: fm
        )

        for url in Self.modelStoreArtifactURLs(for: legacyStoreURL) + Self.modelStoreArtifactURLs(for: appScopedStoreURL) {
            removeItemIfPresent(
                at: url,
                fileManager: fm,
                failureMessage: "Database reset cleanup failed"
            )
        }

        // Also clean Epistemos subdirectory (search index, etc.)
        let epistemosDirectory = appSupport.appendingPathComponent("Epistemos")
        do {
            let contents = try fm.contentsOfDirectory(at: epistemosDirectory, includingPropertiesForKeys: nil)
            for file in contents where file.pathExtension == "sqlite"
                || file.lastPathComponent.contains("default.store") {
                removeItemIfPresent(
                    at: file,
                    fileManager: fm,
                    failureMessage: "Database reset cleanup failed"
                )
            }
        } catch {
            recordPersistenceIssue("Failed to enumerate Epistemos directory during reset", error: error)
        }
        Log.app.info("Database reset complete — relaunching")
        relaunchApp()
    }

    func relaunchSkippingRestoreAndDiscardSession() {
        guard !Self.isRunningTests else {
            Log.app.info("Skipping skip-restore relaunch under tests")
            return
        }

        workspaceService.prepareSkipRestoreRelaunch()
        SavedApplicationStatePurger.purgeIfNeeded()
        Log.app.info("Skip-restore relaunch requested — relaunching into Home")
        relaunchApp()
    }

    private func snapshotInstantRecallSeeds() -> [InstantRecallSeed] {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived && $0.templateId == nil }
        )
        let pages: [SDPage]
        do {
            pages = try modelContainer.mainContext.fetch(descriptor)
        } catch {
            recordPersistenceIssue("Instant Recall seed snapshot failed", error: error)
            return []
        }
        return pages.map {
            InstantRecallSeed(
                id: $0.id,
                inlineBody: $0.body,
                liveBody: NoteWindowManager.shared.editorBody(for: $0.id)
            )
        }
    }

    private func snapshotInstantRecallNotes() -> [(id: String, text: String)] {
        snapshotInstantRecallSeeds().map { seed in
            let diskBody = NoteFileStorage.readBody(pageId: seed.id, mapped: true)
            let text = seed.liveBody ?? (diskBody.isEmpty ? seed.inlineBody : diskBody)
            return (id: seed.id, text: text)
        }
    }

    // MARK: - Full Reset

    func clearVaultLifecycleRuntimeState(reason: String, clearWorkspaceRestore: Bool = false) {
        queryTask?.cancel()
        queryTask = nil
        preparedRetrievalRefreshTask?.cancel()
        preparedRetrievalRefreshTask = nil
        healthyVaultBodyCleanupTask?.cancel()
        healthyVaultBodyCleanupTask = nil

        ambientManifest = nil
        vaultSync.ambientManifest = nil
        queryEngine.resetForVaultLifecycle()
        queryEngine.invalidateRuntime()
        contextualShadowsState.resetForVaultLifecycle()
        ShadowSearchDiagnostics.shared.reset()
        shadowIndexer = nil
        lastShadowIndexedVaultPath = nil
        shadowIndexingInFlightVaultPath = nil
        lastR3InitializedVaultPath = nil
        instantRecallService.clearIndex()
        graphState.resetForVaultLifecycle()
        if clearWorkspaceRestore {
            workspaceService.stopAutoSave()
            workspaceService.clearAutoSavedWorkspace()
            workspaceService.welcomeBack = nil
        }
        EditorBundleHealthRow.recordHaloClosed()
        BackgroundIndexingHealthRow.recordUnavailable(reason: reason)
        Log.pipeline.info("Vault lifecycle: cleared runtime state (\(reason, privacy: .public))")
    }

    func resetAllData() async {
        clearVaultLifecycleRuntimeState(
            reason: "Reset Everything started",
            clearWorkspaceRestore: true
        )
        let didClear = await vaultSync.stopWatchingAsync(preserveData: false)
        if !didClear {
            await vaultSync.forceClearDerivedLocalStateForFullReset()
        }
        vaultSync.clearPersistedVaultSelection()
        NoteWindowManager.shared.resetForVaultRebuild()

        let context = modelContainer.mainContext
        do {
            try context.delete(model: SDMessage.self)
            try context.delete(model: SDChat.self)
            try context.delete(model: SDPageVersion.self)
            try context.delete(model: SDNoteInsight.self)
            try context.delete(model: SDGraphEdge.self)
            try context.delete(model: SDGraphNode.self)
            try context.delete(model: SDBlock.self)
            try context.delete(model: SDPage.self)
            try context.delete(model: SDFolder.self)
            try context.delete(model: SDWorkspace.self)
            try context.save()
            _ = NoteFileStorage.removeAllManagedBodies()
        } catch {
            Log.pipeline.error("Reset: SwiftData wipe failed: \(error.localizedDescription, privacy: .public)")
        }

        let defaults = UserDefaults.standard
        let keysToRemove = [
            "epistemos.localRoutingMode",
            "epistemos.preferredLocalTextModelID",
            "epistemos.preferredChatModelSelection",
        ]
        InferenceState.purgeLegacyRemoteConfiguration(defaults: defaults)
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }

        notesUI.resetForVaultSwitch()
        pipelineState.reset()
        clearVaultLifecycleRuntimeState(
            reason: "Reset Everything completed",
            clearWorkspaceRestore: true
        )

        if let provider = inferenceState.activeCloudProvider ?? inferenceState.preferredAutoRouteCloudProvider {
            inferenceState.setPreferredChatModelSelection(.cloud(inferenceState.preferredCloudModel(for: provider)))
        } else {
            inferenceState.setPreferredChatModelSelection(.appleIntelligence)
        }

        uiState.setActivePanel(.home)
        uiState.needsSetup = false
        UserDefaults.standard.set(false, forKey: "epistemos.setupComplete")

        Log.pipeline.info("Reset: All data cleared. Setup assistant re-armed.")
    }

    private func clearVisualCaches() {
        DiskStyleCache.shared.clearAll()
    }

    private func scheduleMetalShaderWarmupIfNeeded() {
        guard Self.shouldScheduleMetalShaderWarmupAtLaunch() else { return }

        // Pre-warm Metal shader cache.
        // The Rust engine compiles Metal shaders from source during graph_engine_create(),
        // which blocks for 300-800ms on first invocation. Creating a throwaway engine at
        // launch warms the Metal shader cache so the real engine creation in
        // MetalGraphNSView.setupMetal() hits the cache and completes in <5ms.
        //
        // CAMetalLayer must be created on the main thread (Core Animation requirement),
        // so we create the layer here and hand it to a background task for engine creation.
        // The engine creation (shader compilation + pipeline state) runs off-main.
        let warmupLayer = CAMetalLayer()
        warmupLayer.pixelFormat = .bgra8Unorm
        Task.detached(priority: .userInitiated) { [warmupLayer] in
            guard let device = MTLCreateSystemDefaultDevice() else { return }

            // Serialize shader compilation through a file lock to prevent flock
            // contention (errno 35) on Metal's shared shader cache. This avoids
            // races between the warmup engine and any concurrent Metal clients,
            // including zombie processes from previous crashed instances.
            let lockURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("com.epistemos.shader-warmup.lock")
            let lockFd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
            if lockFd >= 0 {
                flock(lockFd, LOCK_EX)
            }
            defer {
                if lockFd >= 0 {
                    flock(lockFd, LOCK_UN)
                    close(lockFd)
                }
            }

            warmupLayer.device = device
            let devicePtr = Unmanaged.passUnretained(device).toOpaque()
            let layerPtr = Unmanaged.passUnretained(warmupLayer).toOpaque()
            let warmupEngine = graph_engine_create(devicePtr, layerPtr)
            if let warmupEngine {
                graph_engine_destroy(warmupEngine)
            }
        }
    }

    private func relaunchApp() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    // MARK: - Body File Storage Migration

    private func migrateBodiesToFileStorage() async {
        let migrationKey = "v2_body_migration_complete"
        let blockMigrationKey = "v2_block_ref_migration_complete"
        let interval = Log.appPerf.beginInterval("migrateBodiesToFileStorage")
        defer { Log.appPerf.endInterval("migrateBodiesToFileStorage", interval) }

        let actor = BodyMigrationActor(modelContainer: modelContainer)

        // 1. Body migration
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            do {
                let migrated = try await actor.migrateInlineBodiesToFiles()
                UserDefaults.standard.set(true, forKey: migrationKey)
                if migrated > 0 {
                    Log.persistence.info("Body file storage migration moved \(migrated) bodies to disk")
                }
            } catch {
                recordPersistenceIssue("Body migration failed", error: error)
            }
        }

        // 2. Block reference migration (for graph performance)
        if !UserDefaults.standard.bool(forKey: blockMigrationKey) {
            do {
                let migrated = try await actor.migrateBlockReferences()
                UserDefaults.standard.set(true, forKey: blockMigrationKey)
                if migrated > 0 {
                    Log.persistence.info("Block reference migration cached \(migrated) pages")
                }
            } catch {
                recordPersistenceIssue("Block reference migration failed", error: error)
            }
        }

        // 3. RCA-P0-003 — strip hidden capture-provenance / audio-source
        // HTML comments from any pre-2026-05-09 managed bodies still on
        // disk. New captures already sanitize at write time; this is
        // the export-share-migration runtime piece of RCA-P0-003 (the
        // remaining manual smoke item there is the export pipeline
        // inspection itself). Idempotent + one-shot via the
        // `v2_hidden_capture_metadata_migration_complete` flag.
        let hiddenMetadataKey = "v2_hidden_capture_metadata_migration_complete"
        if !UserDefaults.standard.bool(forKey: hiddenMetadataKey) {
            // Detached so the I/O walk doesn't block bootstrap.
            // Sequential per pageId — `NoteFileStorage` serializes
            // writes through its own mutation queue.
            let migrated = await Task.detached(priority: .utility) {
                TextCapturePipeline.migrateLegacyCaptureMetadataInManagedBodies()
            }.value
            UserDefaults.standard.set(true, forKey: hiddenMetadataKey)
            if migrated > 0 {
                Log.persistence.info(
                    "Hidden capture metadata migration stripped legacy comments from \(migrated) bodies"
                )
            }
        }
    }

    private func cleanupOrphanBodyFiles() async {
        do {
            let removed = try await BodyMigrationActor(modelContainer: modelContainer).cleanupOrphanBodies()
            if removed > 0 {
                Log.persistence.info("Body file cleanup removed \(removed) orphan note bodies")
            }
        } catch {
            recordPersistenceIssue("Body file cleanup failed", error: error)
        }
    }

    func scheduleHealthyVaultBodyCleanup() {
        guard !Self.isRunningTests else { return }
        healthyVaultBodyCleanupTask?.cancel()
        healthyVaultBodyCleanupTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            guard await vaultSync.shouldRunBodyCleanup(candidateVaultURL: vaultSync.vaultURL) else {
                Log.app.info("Body file cleanup skipped until vault health is confirmed")
                return
            }
            await cleanupOrphanBodyFiles()
        }
    }



    /// Phase R.3 boot activation — initialize the Rust
    /// `VaultResourceService` so the canonical gateway FFI surface is
    /// ready to be called from Swift production code. Safe to call
    /// multiple times: a subsequent init replaces the prior service
    /// (handy for vault-switch flows added in a later commit).
    ///
    /// Runs off-main via `Task.detached` because `resource_service_init`
    /// opens SQLite synchronously (blocking I/O). Errors are logged
    /// but never propagated — legacy note I/O paths continue to work
    /// whether or not the gateway is ready.
    private func initializeRustResourceServiceIfReady() {
        guard let vaultURL = vaultSync.vaultURL else {
            Log.app.info(
                "R.3 gateway: skipping init — no active vault URL yet"
            )
            return
        }
        // Use a stable, filesystem-friendly vault identifier so it
        // survives path changes from security-scoped-bookmark
        // remapping. `lastPathComponent` is usually the vault name
        // ("main", "Personal", etc.); fallback to "default" if empty.
        let rawName = vaultURL.lastPathComponent
        let vaultID = rawName.isEmpty ? "default" : rawName
        let vaultPath = vaultURL.path

        // Idempotency gate: skip re-init if the active vault path has
        // not changed AND the gateway is still ready. `.vaultChanged`
        // fires on every vault mutation (page save, delete, move) —
        // without this guard we'd reopen the VaultStore SQLite handle
        // on every note edit, which is wasteful even if harmless.
        if vaultPath == lastR3InitializedVaultPath, resourceServiceIsReady() {
            return
        }

        // Optimistically record the path BEFORE dispatching so a
        // burst of `.vaultChanged` events while the detached task is
        // still running does not pile up N concurrent re-inits. If
        // init fails we clear the path back to nil below so a future
        // event can retry.
        lastR3InitializedVaultPath = vaultPath
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try resourceServiceInit(vaultRoot: vaultPath, vaultId: vaultID)
                Log.app.info(
                    "R.3 gateway: ready for vault=\(vaultID, privacy: .public)"
                )
            } catch {
                Log.app.error(
                    "R.3 gateway: init failed for vault=\(vaultID, privacy: .public) — \(error.localizedDescription, privacy: .public)"
                )
                await MainActor.run {
                    // Clear so the next `.vaultChanged` can retry; a
                    // transient SQLite open error should not disable
                    // the gateway for the entire session.
                    self?.lastR3InitializedVaultPath = nil
                }
            }
        }
    }

    /// W8.7 — Open the persistent Halo Shadow backend at
    /// `<vault>/.epcache/shadow` and run the first-launch crawl so
    /// Halo is not empty on day one. Idempotent: re-running for the
    /// same vault path is a no-op; switching vaults rotates the
    /// backend and re-crawls.
    ///
    /// Runs off-main via `Task.detached` because:
    ///   - `shadow_handle_open_at` synchronously opens tantivy + usearch
    ///     handles + may trigger a Model2Vec download on first launch
    ///     (HF network round-trip).
    ///   - `ShadowVaultBootstrapper.bootstrap()` walks the vault
    ///     directory tree and reads every `.md` / `.json` file.
    ///
    /// Errors are logged and swallowed — Halo gracefully degrades to
    /// an empty result set instead of taking down the rest of the
    /// app's startup path.
    private func initializeShadowBackendIfReady() {
        guard let vaultURL = vaultSync.vaultURL else {
            Log.app.info("W8.7 shadow: skipping init — no active vault URL yet")
            contextualShadowsState.resetForVaultLifecycle()
            shadowIndexer = nil
            lastShadowIndexedVaultPath = nil
            shadowIndexingInFlightVaultPath = nil
            EditorBundleHealthRow.recordHaloClosed()
            BackgroundIndexingHealthRow.recordUnavailable(
                reason: "No active vault selected - cached local note/graph data only"
            )
            // SS-IR: the #1 "I don't see Instant Recall" cause — no vault to index.
            ShadowSearchDiagnostics.shared.recordInstall(
                vaultPresent: false, serviceInstalled: false, indexedDocumentCount: nil)
            return
        }
        let vaultPath = vaultURL.path
        if vaultPath == lastShadowIndexedVaultPath, shadowIndexer != nil {
            return
        }
        if vaultPath == shadowIndexingInFlightVaultPath {
            return
        }
        if vaultPath != lastShadowIndexedVaultPath {
            shadowIndexer = nil
            contextualShadowsState.resetForVaultLifecycle()
        }
        lastShadowIndexedVaultPath = vaultPath
        shadowIndexingInFlightVaultPath = vaultPath

        let shadowRoot = Self.shadowRootURL(for: vaultURL)
        let etlQueuePath = Self.etlQueueURL(for: vaultURL).path
        BackgroundIndexingHealthRow.recordStarted(
            vaultPath: vaultPath,
            shadowPath: shadowRoot.path
        )

        Task.detached(priority: .utility) { [weak self] in
            let client: RustShadowFFIClient
            do {
                try FileManager.default.createDirectory(
                    at: shadowRoot,
                    withIntermediateDirectories: true
                )
                client = try RustShadowFFIClient(path: shadowRoot.path)
            } catch {
                Log.app.error(
                    "W8.7 shadow: handle open failed at \(shadowRoot.path, privacy: .public) — \(error.localizedDescription, privacy: .public)"
                )
                ShadowSearchDiagnostics.shared.recordInitFailure(class: .handleOpen)
                // SS-IR: vault present, but the Rust FFI handle failed to open → no search service.
                ShadowSearchDiagnostics.shared.recordInstall(
                    vaultPresent: true, serviceInstalled: false, indexedDocumentCount: nil)
                await MainActor.run {
                    guard self?.shadowIndexingInFlightVaultPath == vaultPath else { return }
                    BackgroundIndexingHealthRow.recordFailed(
                        vaultPath: vaultPath,
                        shadowPath: shadowRoot.path,
                        error: error.localizedDescription
                    )
                    self?.lastShadowIndexedVaultPath = nil
                    self?.shadowIndexingInFlightVaultPath = nil
                    self?.contextualShadowsState.resetForVaultLifecycle()
                }
                return
            }

            // Canonical fire-and-log per docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md
            // §3.2: the Swift bootstrap fires shadow_warm() once so the first
            // shadow_handle_search doesn't pay the ~30 MB Model2Vec download
            // cost on the typing hot path. Failures are non-fatal — the
            // handle is still usable, the first search just blocks 2s on cold
            // cache. We surface the warm-up failure so the diagnostics row
            // can distinguish "embedder unavailable" from "tantivy unavailable".
            do {
                try client.warm()
            } catch {
                Log.app.warning(
                    "W8.7 shadow: embedder warm failed — \(error.localizedDescription, privacy: .public). First Halo search may block on HF download or fall back."
                )
                ShadowSearchDiagnostics.shared.recordInitFailure(class: .embedderWarm)
            }

            let indexer = ShadowIndexingService(client: client)
            let bootstrapper = ShadowVaultBootstrapper(
                vaultRoot: vaultURL,
                indexer: indexer
            )
            let initialEtlStats = RustEtlQueueStatsClient.stats(path: etlQueuePath)
            let installed = await MainActor.run { () -> Bool in
                guard let self else { return false }
                guard self.vaultSync.vaultURL?.path == vaultPath,
                      self.lastShadowIndexedVaultPath == vaultPath,
                      self.shadowIndexingInFlightVaultPath == vaultPath else {
                    return false
                }
                let search = ShadowSearchService(client: client)
                self.shadowIndexer = indexer
                self.contextualShadowsState.configureShadowSearch(search)
                // SS-IR: vault + FFI open + search service installed → recall is live (the owner's
                // "is it working?" answer flips to operational here). Index size left nil to avoid
                // a stats() FFI call racing the live search service; preconditions are the answer.
                ShadowSearchDiagnostics.shared.recordInstall(
                    vaultPresent: true, serviceInstalled: true, indexedDocumentCount: nil)
                BackgroundIndexingHealthRow.recordEtlQueueStats(
                    initialEtlStats,
                    queuePath: etlQueuePath
                )
                return true
            }
            guard installed else {
                Log.app.info(
                    "W8.7 shadow: ignoring stale bootstrap at \(shadowRoot.path, privacy: .public)"
                )
                return
            }
            let progressStream = bootstrapper.progress
            let progressTask = Task {
                for await progress in progressStream {
                    await MainActor.run {
                        BackgroundIndexingHealthRow.recordProgress(
                            progress,
                            vaultPath: vaultPath,
                            shadowPath: shadowRoot.path
                        )
                    }
                }
            }
            await bootstrapper.bootstrap()
            await progressTask.value
            await indexer.flushNow()
            let powerSnapshot = await MainActor.run {
                PowerGate.deferSnapshot()
            }
            let dispatchSnapshot: EtlQueueDispatchSnapshot? = powerSnapshot.shouldDefer
                ? nil
                : RustEtlQueueDispatchClient.enqueueVaultWalk(
                    vaultPath: vaultPath,
                    queuePath: etlQueuePath
                )
            let postDispatchEtlStats = RustEtlQueueStatsClient.stats(path: etlQueuePath)
            let workerSnapshot: EtlQueueWorkerSnapshot?
            if !powerSnapshot.shouldDefer,
               dispatchSnapshot?.available != false,
               postDispatchEtlStats.available,
               postDispatchEtlStats.pending > 0 {
                workerSnapshot = RustEtlQueueWorkerClient.run(
                    queuePath: etlQueuePath,
                    maxJobs: postDispatchEtlStats.pending
                )
            } else {
                workerSnapshot = nil
            }
            let finalEtlStats = RustEtlQueueStatsClient.stats(path: etlQueuePath)
            await MainActor.run {
                guard self?.vaultSync.vaultURL?.path == vaultPath,
                      self?.lastShadowIndexedVaultPath == vaultPath else {
                    return
                }
                EditorBundleHealthRow.recordHaloOpened(at: shadowRoot.path)
                if powerSnapshot.shouldDefer {
                    BackgroundIndexingHealthRow.recordPaused(
                        vaultPath: vaultPath,
                        shadowPath: shadowRoot.path,
                        reason: Self.backgroundIndexingPauseReason(for: powerSnapshot.reason)
                    )
                } else {
                    BackgroundIndexingHealthRow.recordComplete(
                        vaultPath: vaultPath,
                        shadowPath: shadowRoot.path
                    )
                }
                let reportedEtlStats: EtlQueueStatsSnapshot
                if dispatchSnapshot?.available == false {
                    reportedEtlStats = .unavailable(dispatchSnapshot?.error ?? "ETL dispatch failed")
                } else if workerSnapshot?.available == false {
                    reportedEtlStats = .unavailable(workerSnapshot?.error ?? "ETL worker failed")
                } else {
                    reportedEtlStats = finalEtlStats
                }
                BackgroundIndexingHealthRow.recordEtlQueueStats(
                    reportedEtlStats,
                    queuePath: etlQueuePath
                )
                if self?.shadowIndexingInFlightVaultPath == vaultPath {
                    self?.shadowIndexingInFlightVaultPath = nil
                }
            }
            Log.app.info(
                "W8.7 shadow: bootstrap complete at \(shadowRoot.path, privacy: .public)"
            )
        }
    }

    /// KC cutover Slice 3 (step 1) — stand up the in-app KnowledgeCore shadow
    /// runtime, flag-gated behind `knowledgeCoreRuntimeV0` (default OFF). When
    /// on, the runtime opens against `<vault>/.epcache/kc-oplog.jsonl`, replays
    /// any prior mutation log (so projected fact state survives a restart), and
    /// is held in `knowledgeCoreRuntime` across vault-sync ticks.
    ///
    /// Idempotent: re-running for the same vault is a no-op; switching vaults
    /// rotates the runtime. With the flag off (the default) the runtime is torn
    /// down and this method has no effect on app behavior.
    ///
    /// Step 1 only stands the runtime up. Feeding it the vault's notes (so it
    /// has facts to project) is `feedKnowledgeCoreRuntimeIfReady()` (step 2),
    /// and driving live SwiftUI surfaces from its diffs is step 3 (dev-cert
    /// runtime-verify only). The oplog replay runs synchronously during the
    /// bridge open; for a personal vault's edit log this is a bounded
    /// local-CPU cost, and the heavy vault feed is deferred off-main.
    private func initializeKnowledgeCoreRuntimeIfReady() {
        let enabled = EpistemosRuntimeFeatureFlags.load().knowledgeCoreRuntimeV0
        guard enabled, let vaultURL = vaultSync.vaultURL else {
            if knowledgeCoreRuntime != nil {
                knowledgeCoreRuntime = nil
                lastKnowledgeCoreVaultPath = nil
                Log.app.info("KC runtime: torn down (flag off or no active vault)")
            }
            return
        }

        let vaultPath = vaultURL.path
        if vaultPath == lastKnowledgeCoreVaultPath, knowledgeCoreRuntime != nil {
            return
        }
        // Vault changed (or first open): rotate the runtime.
        knowledgeCoreRuntime = nil
        lastKnowledgeCoreVaultPath = nil

        let oplogURL = Self.knowledgeCoreOplogURL(for: vaultURL)
        do {
            try FileManager.default.createDirectory(
                at: oplogURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            Log.app.error(
                "KC runtime: failed to create .epcache dir at \(oplogURL.deletingLastPathComponent().path, privacy: .public) — \(error.localizedDescription, privacy: .public)"
            )
            return
        }

        // Seed gate: opening the runtime replays any prior mutation log, which
        // restores the projected fact state from the last session. Re-feeding
        // the whole vault on every open would append a full ingest set to the
        // log each launch (unbounded growth) and duplicate replayed work — so
        // we seed (feed every note) ONLY when there is no prior log to replay.
        // Once seeded + journaled, later opens trust the replayed state and the
        // oplog stays bounded. (Incremental note-edit → KC mutation wiring is
        // step 3; until then KC trusts its persisted projection — harmless
        // while it is shadow-only and drives no user-visible surface.)
        let priorLogAttrs = try? FileManager.default.attributesOfItem(atPath: oplogURL.path)
        let priorLogBytes = (priorLogAttrs?[.size] as? Int) ?? 0
        let needsSeed = priorLogBytes == 0

        guard let runtime = KnowledgeCoreShadowRuntime(oplogPath: oplogURL.path) else {
            Log.app.error("KC runtime: KnowledgeCoreShadowRuntime init returned nil")
            return
        }
        knowledgeCoreRuntime = runtime
        lastKnowledgeCoreVaultPath = vaultPath
        Log.app.info(
            "KC runtime: opened at \(oplogURL.path, privacy: .public) (vault \(vaultPath, privacy: .public), seed=\(needsSeed, privacy: .public))"
        )

        if needsSeed {
            feedKnowledgeCoreRuntimeIfReady(vaultURL: vaultURL, vaultPath: vaultPath)
        }
    }

    /// KC cutover Slice 3 (step 2) — seed the active vault's notes into the
    /// KnowledgeCore runtime, so it has facts to project. Each ingest is
    /// idempotent at the store level (re-ingesting a page replaces its blocks)
    /// and is journaled to the oplog, so a later restart replays straight from
    /// the log without re-walking the vault.
    ///
    /// Page metadata is read from the canonical SwiftData context on main; each
    /// body is then loaded off the managed store and ingested through the bridge
    /// actor (parse/store work runs off-main on the actor's executor). The
    /// `await` points keep startup responsive even on a large vault, and the
    /// loop bails if the vault rotates out mid-feed.
    private func feedKnowledgeCoreRuntimeIfReady(vaultURL: URL, vaultPath: String) {
        guard let runtime = knowledgeCoreRuntime else { return }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived && $0.templateId == nil }
        )
        let pageRefs: [KnowledgeCoreFeedPageRef]
        do {
            pageRefs = try context.fetch(descriptor).map {
                KnowledgeCoreFeedPageRef(id: $0.id, filePath: $0.filePath)
            }
        } catch {
            Log.app.error(
                "KC runtime feed: page fetch failed — \(error.localizedDescription, privacy: .public)"
            )
            return
        }
        guard !pageRefs.isEmpty else {
            Log.app.info("KC runtime feed: no notes to seed for \(vaultPath, privacy: .public)")
            return
        }

        Task { @MainActor [weak self] in
            var ingested = 0
            for ref in pageRefs {
                // Bail if the vault rotated out from under us mid-seed.
                guard self?.lastKnowledgeCoreVaultPath == vaultPath,
                      self?.knowledgeCoreRuntime != nil else { return }
                let body = await SDPage.loadBodyAsyncFromPrimitives(
                    pageId: ref.id,
                    filePath: ref.filePath
                )
                guard !body.isEmpty else { continue }
                if await runtime.ingestDocument(pageId: ref.id, format: .markdown, text: body) {
                    ingested += 1
                }
            }
            Log.app.info(
                "KC runtime feed: seeded \(ingested)/\(pageRefs.count) notes for \(vaultPath, privacy: .public)"
            )
        }
    }

    /// KC cutover Slice 3 — re-ingest a single changed page into the runtime so
    /// the projection tracks the live vault between launches. Fires on
    /// `.vaultPageChanged` (the same debounced save signal the shadow reindex
    /// uses), so re-ingest frequency follows save frequency, not keystrokes.
    /// No-op unless the runtime flag is on and a runtime is standing.
    ///
    /// Re-ingest replaces the page's blocks (idempotent at the store) and
    /// journals one mutation to the oplog — the intended durable record of an
    /// edit. (Oplog compaction/snapshotting was deferred in Slice 2; per-edit
    /// growth is bounded by edit volume and acceptable while KC is shadow-only.)
    private func reingestKnowledgeCorePageIfReady(pageId: String) {
        // Fast-path: when the flag is off the runtime is never instantiated, so
        // the nil check short-circuits every page save without a flags read.
        guard let runtime = knowledgeCoreRuntime,
              EpistemosRuntimeFeatureFlags.load().knowledgeCoreRuntimeV0 else {
            return
        }

        // Resolve the page's on-disk reference on main, then load + ingest the
        // body off-main through the bridge actor.
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == pageId }
        )
        guard let page = try? context.fetch(descriptor).first else { return }
        // A page that became archived/templated since the seed should be dropped
        // from KC rather than re-ingested, but DeleteDocument is not yet on the
        // runtime surface; skip it for now (stale entry is harmless shadow-side).
        guard !page.isArchived, page.templateId == nil else { return }
        let filePath = page.filePath

        Task { @MainActor [weak self] in
            guard self?.knowledgeCoreRuntime != nil else { return }
            let body = await SDPage.loadBodyAsyncFromPrimitives(
                pageId: pageId,
                filePath: filePath
            )
            guard !body.isEmpty else { return }
            let ok = await runtime.ingestDocument(pageId: pageId, format: .markdown, text: body)
            Log.app.debug(
                "KC runtime re-ingest: page \(pageId, privacy: .public) ok=\(ok, privacy: .public)"
            )
        }
    }

    private func enqueueShadowPageReindexIfReady(pageId: String) {
        guard let vaultURL = vaultSync.vaultURL else { return }
        let vaultPath = vaultURL.path
        guard lastShadowIndexedVaultPath == vaultPath else { return }
        guard let indexer = shadowIndexer else { return }
        guard let stage = shadowPageIndexStage(pageId: pageId, vaultURL: vaultURL) else { return }

        BackgroundIndexingHealthRow.recordProgress(
            .init(domain: .notes, enqueued: 0, total: 1, isComplete: false),
            vaultPath: stage.vaultPath,
            shadowPath: stage.shadowPath
        )

        Task.detached(priority: .utility) { [weak self] in
            let body = await SDPage.loadBodyAsyncFromPrimitives(
                pageId: stage.pageId,
                filePath: stage.filePath,
                inlineBody: stage.inlineBody,
                mapped: true
            )
            let isCurrentVault = await MainActor.run { () -> Bool in
                guard let self else { return false }
                return self.vaultSync.vaultURL?.path == stage.vaultPath
                    && self.lastShadowIndexedVaultPath == stage.vaultPath
            }
            guard isCurrentVault else { return }
            await indexer.enqueueInsert(
                ShadowDocumentDTO(
                    docId: stage.docId,
                    title: stage.title,
                    body: body,
                    domain: .notes
                )
            )
            await indexer.flushNow()
            await MainActor.run {
                guard self?.vaultSync.vaultURL?.path == stage.vaultPath,
                      self?.lastShadowIndexedVaultPath == stage.vaultPath else {
                    return
                }
                BackgroundIndexingHealthRow.recordProgress(
                    .init(domain: .notes, enqueued: 1, total: 1, isComplete: true),
                    vaultPath: stage.vaultPath,
                    shadowPath: stage.shadowPath
                )
                BackgroundIndexingHealthRow.recordComplete(
                    vaultPath: stage.vaultPath,
                    shadowPath: stage.shadowPath
                )
            }
        }
    }

    private func shadowPageIndexStage(pageId: String, vaultURL: URL) -> ShadowPageIndexStage? {
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = try? modelContainer.mainContext.fetch(descriptor).first else {
            return nil
        }

        let fileURL = page.filePath.map { URL(fileURLWithPath: $0) }
        let docId = fileURL
            .flatMap { ShadowVaultBootstrapper.vaultRelativeDocId(for: $0, vaultRoot: vaultURL) }
            ?? page.id
        let shadowRoot = Self.shadowRootURL(for: vaultURL)
        return ShadowPageIndexStage(
            pageId: page.id,
            docId: docId,
            title: page.title,
            filePath: page.filePath,
            inlineBody: page.body,
            vaultPath: vaultURL.path,
            shadowPath: shadowRoot.path
        )
    }

    nonisolated private static func shadowRootURL(for vaultURL: URL) -> URL {
        vaultURL
            .appendingPathComponent(".epcache", isDirectory: true)
            .appendingPathComponent("shadow", isDirectory: true)
    }

    nonisolated private static func etlQueueURL(for vaultURL: URL) -> URL {
        vaultURL
            .appendingPathComponent(".epcache", isDirectory: true)
            .appendingPathComponent("etl", isDirectory: true)
            .appendingPathComponent("queue.sqlite", isDirectory: false)
    }

    /// KC cutover Slice 3 — durable mutation replay log for the in-app
    /// KnowledgeCore shadow runtime. Lives under the same `.epcache`
    /// sibling directory as the Halo shadow + ETL queue.
    nonisolated private static func knowledgeCoreOplogURL(for vaultURL: URL) -> URL {
        vaultURL
            .appendingPathComponent(".epcache", isDirectory: true)
            .appendingPathComponent("kc-oplog.jsonl", isDirectory: false)
    }

    private static func backgroundIndexingPauseReason(
        for reason: PowerGate.DeferReason?
    ) -> BackgroundIndexingPauseReason {
        switch reason {
        case .lowPower:
            return .lowPower
        case .thermal:
            return .thermal
        case .battery:
            return .battery
        case .memoryPressure:
            return .memoryPressure
        case nil:
            return .backgroundPolicy
        }
    }

    /// Phase R.5 persistence boot activation — migrate the Rust
    /// permission store from its default in-memory fallback to an
    /// on-disk SQLite file at a container-safe path. After this call
    /// succeeds, grants recorded via `permissionStoreRecordUserGrantFromStatement`
    /// persist across app relaunches until explicitly revoked.
    ///
    /// The container-safe path is resolved via
    /// `FileManager.default.url(for: .applicationSupportDirectory, ...)`
    /// which honors the App Sandbox container on MAS builds and falls
    /// back to `~/Library/Application Support/` on unsandboxed builds.
    /// Both are writable by the app without extra entitlements.
    ///
    /// Runs off-main via `Task.detached` because the FFI call opens
    /// SQLite synchronously. Errors are logged and swallowed — a
    /// transient filesystem failure on launch should not take down
    /// the app, and the in-memory fallback keeps the R.5 gate
    /// working for the current session.
    private func initializeRustPermissionStoreIfReady() {
        let supportDir = FoundationSafety.userApplicationSupportDirectory(fileManager: .default)

        // Bundle-scoped subdirectory so multiple Epistemos builds
        // don't collide. `bundleIdentifier` fallback mirrors what
        // other bootstrap paths use when running under xctest.
        let bundleID = Bundle.main.bundleIdentifier ?? "com.epistemos.Epistemos"
        let dbURL = supportDir
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("permissions.db", isDirectory: false)

        let dbPath = dbURL.path
        Task.detached(priority: .userInitiated) {
            do {
                try permissionStoreInitAtPath(path: dbPath)
                Log.app.info(
                    "R.5 persist: permission store backed at \(dbPath, privacy: .public)"
                )
            } catch {
                Log.app.error(
                    "R.5 persist: init failed at \(dbPath, privacy: .public) — \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func verifyAgentCorePolicyProfile() {
        #if canImport(agent_coreFFI)
        let profile = agentCorePolicyProfile()
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        guard profile == "mas_sandbox" else {
            Log.app.fault(
                "App Store runtime safety check failed: linked agent_core profile is \(profile, privacy: .public)"
            )
            fatalError("App Store build linked non-sandboxed agent_core runtime")
        }
        #else
        if profile != "direct" {
            Log.app.error(
                "Direct runtime safety check found unexpected agent_core profile \(profile, privacy: .public)"
            )
        }
        #endif
        #endif
    }

    /// Subscribe to `.vaultChanged` so the R.3 gateway is re-initialized
    /// whenever the active vault switches (bookmark-restored at startup,
    /// user-triggered vault switch, test seeding). The subscription is
    /// set up ONCE at bootstrap and kept alive for the app lifetime.
    ///
    /// `.vaultChanged` also fires on non-switch mutations (page save,
    /// trash, move). `initializeRustResourceServiceIfReady()`'s
    /// path-equality gate short-circuits those into a no-op, so the
    /// noisy channel is safe to subscribe to.
    private func wireR3VaultSwitchObserver() {
        eventBus.subscribe(id: "r3-gateway-vault-switch") { [weak self] event in
            guard let self else { return }
            switch event {
            case .vaultChanged:
                self.initializeRustResourceServiceIfReady()
                self.initializeShadowBackendIfReady()
                // KC cutover Slice 3 — rotate the KnowledgeCore runtime onto the
                // new vault (path-equality gate makes repeat fires a no-op).
                self.initializeKnowledgeCoreRuntimeIfReady()
                // W-46.1 — re-open the Eidos vault index against the
                // new vault path so the manifest_id flips with the
                // user's vault switch. Idempotent for repeat fires of
                // the same vault.
                EidosVaultBootstrapper.openProductionIndexIfReady(
                    vaultURL: self.vaultSync.vaultURL
                )
            case .vaultPageChanged(let pageId):
                self.enqueueShadowPageReindexIfReady(pageId: pageId)
                // KC cutover Slice 3 — keep the KnowledgeCore projection current
                // with the live vault by re-ingesting the changed page (no-op
                // unless the runtime flag is on). Closes the seed-then-trust
                // staleness gap without a full vault re-walk.
                self.reingestKnowledgeCorePageIfReady(pageId: pageId)
            default:
                break
            }
        }
    }

    func teardownRuntimeObservers() {
        sovereignGateLifecycleObserver.stop()

        if let monitor = commandCenterLocalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            commandCenterLocalHotkeyMonitor = nil
        }

        if let monitor = commandCenterGlobalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            commandCenterGlobalHotkeyMonitor = nil
        }

    }
}

@ModelActor
private actor BodyMigrationActor {
    func migrateInlineBodiesToFiles() throws -> Int {
        let pages = try modelContext.fetch(FetchDescriptor<SDPage>())
        var migrated = 0
        var migratedPageIds: [String] = []
        migratedPageIds.reserveCapacity(pages.count)
        for page in pages where !page.body.isEmpty {
            NoteFileStorage.writeBody(pageId: page.id, content: page.body)
            migratedPageIds.append(page.id)
            page.body = ""
            migrated += 1
        }
        if migrated > 0 {
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                modelContext.processPendingChanges()
                for pageId in migratedPageIds {
                    NoteFileStorage.deleteBody(pageId: pageId)
                }
                throw error
            }
        }
        return migrated
    }

    func migrateBlockReferences() async throws -> Int {
        let pages = try modelContext.fetch(FetchDescriptor<SDPage>())
        var migrated = 0
        let pattern = /\(\(([^)]+)\)\)/

        for page in pages where page.blockReferences.isEmpty {
            // Phase R.3: managed-sidecar-first body read via the
            // Sendable-primitive helper, with gateway fallback.
            let body = await SDPage.loadBodyAsyncFromPrimitives(
                pageId: page.id,
                filePath: page.filePath,
                inlineBody: page.body,
                mapped: true
            )
            guard !body.isEmpty else { continue }
            let matches = body.matches(of: pattern)
            let refs = matches.compactMap { match -> String? in
                let refId = String(match.1).trimmingCharacters(in: .whitespaces)
                return refId.isEmpty ? nil : refId
            }
            if !refs.isEmpty {
                page.blockReferences = refs
                migrated += 1
            }
        }
        if migrated > 0 {
            try modelContext.save()
        }
        return migrated
    }

    func cleanupOrphanBodies() throws -> Int {
        let pages = try modelContext.fetch(FetchDescriptor<SDPage>())
        return NoteFileStorage.cleanupOrphanBodies(validPageIds: pages.map(\.id)).count
    }
}
