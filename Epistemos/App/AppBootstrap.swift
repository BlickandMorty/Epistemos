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
// All behavioral orchestration is delegated to AppCoordinator and ChatCoordinator.

@MainActor
private final class LocalModelRefreshThrottle {
    private let manager: LocalModelManager
    private let interval: TimeInterval
    private var lastRefreshAt: Date = .distantPast

    init(manager: LocalModelManager, interval: TimeInterval) {
        self.manager = manager
        self.interval = interval
    }

    func refreshIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastRefreshAt) >= interval else {
            return
        }
        manager.refreshFromDisk()
        lastRefreshAt = now
    }
}

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

        let modelRootURL = localModelRootURL
            ?? LocalModelPaths.defaultRootDirectory(fileManager: fileManager)

        return StartupAutoDiscoveryReport(
            credentialStatuses: statuses,
            browserToolAvailable: browserToolAvailable,
            localModelDirectories: discoverLocalModelDirectories(
                rootDirectory: modelRootURL,
                fileManager: fileManager
            ),
            huggingFaceModelDirectories: discoverHuggingFaceModelDirectories(
                homeDirectoryURL: resolvedHomeURL,
                fileManager: fileManager
            )
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

    nonisolated static func discoverLocalModelDirectories(
        rootDirectory: URL = LocalModelPaths.defaultRootDirectory(),
        fileManager: FileManager = .default
    ) -> [URL] {
        guard fileManager.fileExists(atPath: rootDirectory.path) else {
            return []
        }
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            Log.app.error(
                "AppBootstrap: failed to enumerate local model directory root \(rootDirectory.path, privacy: .public)"
            )
            return []
        }

        let knownSlugs = Set(LocalModelCatalog.allDescriptors.map(\.slug))
        var discovered: Set<URL> = []

        for case let url as URL in enumerator {
            let resourceValues: URLResourceValues
            do {
                resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            } catch {
                Log.app.error(
                    "AppBootstrap: failed to inspect local model candidate \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                continue
            }

            guard resourceValues.isDirectory == true else {
                continue
            }

            let standardizedURL = url.standardizedFileURL
            let lastPathComponent = standardizedURL.lastPathComponent
            if lastPathComponent.hasSuffix(".mlx") || knownSlugs.contains(lastPathComponent) {
                discovered.insert(standardizedURL)
                enumerator.skipDescendants()
            }
        }

        return discovered.sorted { $0.path < $1.path }
    }

    nonisolated static func discoverHuggingFaceModelDirectories(
        homeDirectoryURL: URL,
        fileManager: FileManager = .default
    ) -> [URL] {
        let hubURL = homeDirectoryURL
            .appendingPathComponent(".cache", isDirectory: true)
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)

        guard fileManager.fileExists(atPath: hubURL.path) else {
            return []
        }
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: hubURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            Log.app.error(
                "AppBootstrap: failed to enumerate Hugging Face cache \(hubURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return []
        }

        return contents.compactMap { url in
            let resourceValues: URLResourceValues
            do {
                resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            } catch {
                Log.app.error(
                    "AppBootstrap: failed to inspect Hugging Face model candidate \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                return nil
            }

            guard resourceValues.isDirectory == true,
                  url.lastPathComponent.hasPrefix("models--") else {
                return nil
            }
            return url.standardizedFileURL
        }
        .sorted { $0.path < $1.path }
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
        ("KIMI_API_KEY", "epistemos.kimi.apiKey"),
        ("DEEPSEEK_API_KEY", "epistemos.deepseek.apiKey"),
        ("MINIMAX_API_KEY", "epistemos.minimax.apiKey"),
        ("XAI_API_KEY", "epistemos.xai.apiKey"),
        ("MISTRAL_API_KEY", "epistemos.mistral.apiKey"),
        ("GROQ_API_KEY", "epistemos.groq.apiKey"),
        ("HF_TOKEN", "epistemos.huggingface.apiKey"),
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
    let chatState = ChatState()
    let pipelineState = PipelineState()
    let uiState = UIState()
    let notesUI = NotesUIState()
    let inferenceState: InferenceState
    let localModelManager: LocalModelManager
    let dailyBriefState = DailyBriefState()
    let threadState = ThreadState()
    let graphState = GraphState()
    let queryEngine = QueryEngine()
    let physicsCoordinator = PhysicsCoordinator()
    let dialogueChatState = DialogueChatState()
    let orchestratorState = OrchestratorState()
    let mcpBridge = MCPBridge()
    let agentCommandCenterState = AgentCommandCenterState()
    let agentChatState = AgentChatState()
    /// Patch 5 / USER_WIRING_GAPS G2 — Raw Thoughts V0 sidebar consumer.
    /// Hidden behind `EPISTEMOS_RAW_THOUGHTS_V0` env flag; UI hides itself
    /// when `state.isEnabled == false`.
    let rawThoughtsState = RawThoughtsState()
    /// Patch 7 / AMBIENT_RECALL_WIRING_PLAN.md §5 — Contextual Shadows V0
    /// state container (recall hits + panel visibility). Hidden behind
    /// `EPISTEMOS_AMBIENT_RECALL_V0` env flag; UI hides itself when
    /// `state.isEnabled == false`.
    let contextualShadowsState = ContextualShadowsState()
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
    let channelRegistry: ChannelRegistryState
    let constrainedDecoding = ConstrainedDecodingService()
    let hardwareTierManager = HardwareTierManager()
    private var _iMessageDriver: IMessageDriverService?
    var iMessageDriver: IMessageDriverService { Self.requireInitialized(_iMessageDriver, name: "iMessageDriver") }
    private var _deviceAgent: DeviceAgentService?
    var deviceAgent: DeviceAgentService { Self.requireInitialized(_deviceAgent, name: "deviceAgent") }
    // Computer-use chain: lazy. ScreenCaptureService, Screen2AXFusion, and
    // AmbientCaptureService form a dependency graph. None are read at
    // app launch unless the user (a) opens a computer-use agent task,
    // or (b) opts into ambient capture. For typical sessions that don't
    // trigger either path, the eager construct burned ~8-12 MB on
    // AX-listener buffers + AVF
    // scaffolding for nothing. First access builds only the dependency
    // subtree each service needs; subsequent reads are O(1).
    private var _screenCapture: ScreenCaptureService?
    var screenCapture: ScreenCaptureService {
        if let existing = _screenCapture { return existing }
        let new = ScreenCaptureService()
        _screenCapture = new
        return new
    }
    private var _screen2AXFusion: Screen2AXFusion?
    var screen2AXFusion: Screen2AXFusion {
        if let existing = _screen2AXFusion { return existing }
        let new = Screen2AXFusion(screenCapture: screenCapture)
        _screen2AXFusion = new
        return new
    }
    private var _agentGraphMemory: AgentGraphMemory?
    var agentGraphMemory: AgentGraphMemory { Self.requireInitialized(_agentGraphMemory, name: "agentGraphMemory") }
    private var _recipeGraphSkills: RecipeGraphSkills?
    var recipeGraphSkills: RecipeGraphSkills { Self.requireInitialized(_recipeGraphSkills, name: "recipeGraphSkills") }
    private var _ghostBrainCoauthor: GhostBrainCoauthor?
    var ghostBrainCoauthor: GhostBrainCoauthor { Self.requireInitialized(_ghostBrainCoauthor, name: "ghostBrainCoauthor") }
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

    // MARK: - Cognitive Substrates
    let epistemosConfig = EpistemosConfig()
    private var _ambientCapture: AmbientCaptureService?
    var ambientCapture: AmbientCaptureService {
        if let existing = _ambientCapture { return existing }
        let new = AmbientCaptureService(config: epistemosConfig, screen2AXFusion: screen2AXFusion)
        _ambientCapture = new
        return new
    }
    private var _frictionMonitor: FrictionMonitorService?
    var frictionMonitor: FrictionMonitorService { Self.requireInitialized(_frictionMonitor, name: "frictionMonitor") }
    private var _nightBrain: NightBrainService?
    var nightBrain: NightBrainService { Self.requireInitialized(_nightBrain, name: "nightBrain") }

    // MARK: - Ambient Vault Manifest
    /// Always-available vault manifest — built eagerly on vault attach, refreshed on changes.
    /// Nil when no vault is attached. Shared across all AI surfaces (main chat, MiniChat, graph inspector).
    var ambientManifest: VaultManifest?

    // MARK: - Active Query Task
    var queryTask: Task<Void, Never>?
    private var healthyVaultBodyCleanupTask: Task<Void, Never>?
    private struct LocalRuntimeObserverToken {
        let center: NotificationCenter
        let token: NSObjectProtocol
    }

    private var localRuntimeObserverTokens: [LocalRuntimeObserverToken] = []
    private var localRuntimeActivationTask: Task<Void, Never>?
    private var preparedRetrievalRefreshTask: Task<Void, Never>?
    private let localModelRefreshThrottle: LocalModelRefreshThrottle
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

    private func routeMainChatDraft(
        prefill inputText: String? = nil,
        operatingMode: EpistemosOperatingMode? = nil
    ) {
        if let operatingMode {
            let visibleMode: EpistemosOperatingMode =
                operatingMode == .agent ? .pro : operatingMode
            UserDefaults.standard.set(
                visibleMode.rawValue,
                forKey: MainChatOperatingModePreference.defaultsKey
            )
        }

        if let inputText {
            let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                chatState.primeComposerDraft(trimmed)
            }
        }

        chatState.showLanding = false
        uiState.setActivePanel(.home)
        uiState.homeTab = .home
        HomeWindowIdentity.surfaceHomeWindow()
    }

    func routeGraphChatRequestIntoMainChat(_ request: GraphChatRequest) {
        let label = request.nodeLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let draftLabel = label.isEmpty ? request.nodeType : label
        chatState.primeGraphChatRequest(request)
        routeMainChatDraft(
            prefill: "Tell me about \(draftLabel)"
        )
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

        if !fileManager.fileExists(atPath: destinationURL.path),
           fileManager.fileExists(atPath: legacyURL.path) {
            try VaultSyncService.backupSQLiteDatabaseIfPresent(at: legacyURL, to: destinationURL)
        }

        try repairLegacyMessageColumnsIfNeeded(at: destinationURL)
        return destinationURL
    }

    private nonisolated static func repairLegacyMessageColumnsIfNeeded(
        at storeURL: URL
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

        let columnNames = try sqliteColumnNames(in: "ZSDMESSAGE", db: db, storeURL: storeURL)
        guard !columnNames.isEmpty else { return }

        for column in legacyMessageColumns where !columnNames.contains(column.name) {
            let sql = "ALTER TABLE ZSDMESSAGE ADD COLUMN \(column.name) \(column.declaration);"
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw sqliteStoreError(
                    domain: "AppBootstrap.ModelStore.AlterMessage",
                    code: Int(sqlite3_errcode(db)),
                    storeURL: storeURL,
                    db: db
                )
            }
        }
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
    let localInferenceService: MLXInferenceService
    let localRuntimeControlPlane: BackendRuntimeControlPlane
    let localMLXClient: LocalMLXClient
    let preparedModelRegistryState: PreparedModelRegistryState
    let preparedModelRegistry: PreparedModelRegistry
    let localLLMClient: any LocalConfigurableLLMClient
    let cloudLLMClient: CloudLLMClient
    let triageService: TriageService
    /// Transparency-only audit trail of recent Overseer planning
    /// decisions. Populated by ChatCoordinator on every main-chat turn;
    /// surfaced in Settings → Overseer.
    let overseerAuditState = OverseerAuditState()
    let vaultSync: VaultSyncService
    let vaultChatMutator: VaultChatMutator
    let liveNoteScheduler = LiveNoteSchedulerService()
    let ssmStateService: SSMStateService
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
    // Lazy: CloudKnowledgeDistillationService is touched only by
    // (1) the NightBrain background job (runs >3s after launch, deferred
    //     enough that lazy-build there is fine) and
        // (2) the Settings > Model Vaults user action.
    // The targetsProvider closure stays MainActor-bound so each rebuild reads
    // the current visible model set instead of a stale launch snapshot.
    private var _cloudKnowledgeDistillationService: CloudKnowledgeDistillationService?
    var cloudKnowledgeDistillationService: CloudKnowledgeDistillationService {
        if let existing = _cloudKnowledgeDistillationService { return existing }
        let inferenceState = self.inferenceState
        let new = CloudKnowledgeDistillationService(
            modelContainer: modelContainer,
            targetsProvider: { inferenceState.modelVaultTargets() }
        )
        _cloudKnowledgeDistillationService = new
        return new
    }
    private(set) var meaningAnchorService: MeaningAnchorService?

    // MARK: - Coordinators
    private var _coordinator: AppCoordinator?
    var coordinator: AppCoordinator { Self.requireInitialized(_coordinator, name: "coordinator") }

    init() {
        let interval = Log.appPerf.beginInterval("bootstrapInit")
        defer { Log.appPerf.endInterval("bootstrapInit", interval) }

        // Cut the default `URLCache.shared` (4 MB memory + 20 MB disk).
        // Almost every URLSession in this app explicitly opts out of
        // caching (LLM streams, HF downloads, MCP) or uses ephemeral
        // configurations. The shared cache table is dead weight that
        // counts toward resident memory at idle.
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0)

        // Register custom fonts (RetroGaming, etc.)
        EpistemosFont.registerFonts()

        // Create the SwiftData container against an explicit app-scoped store path.
        // Legacy root-level default.store files are adopted once into the app
        // directory, and known message-column gaps are repaired before opening.
        // Falls back to in-memory only under tests or if container creation fails.
        let schema = Schema(EpistemosSchema.models)
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
                try? Self.removeModelStoreArtifacts(at: modelStoreURL, fileManager: fileManager)
            }
            modelConfiguration = ModelConfiguration(url: modelStoreURL)
        }
        do {
            container = try ModelContainer(
                for: schema,
                configurations: modelConfiguration
            )
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

        let channelRegistry = ChannelRegistryState()
        self.channelRegistry = channelRegistry

        // InferenceState reads Keychain + checks Apple Intelligence availability
        let inference = InferenceState()
        self.inferenceState = inference
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx])
        let localModelManager = LocalModelManager(
            inference: inference,
            installer: ModelDownloadManager()
        )
        self.localModelManager = localModelManager
        let localModelRefreshThrottle = LocalModelRefreshThrottle(
            manager: localModelManager,
            interval: 2
        )
        self.localModelRefreshThrottle = localModelRefreshThrottle

        let localInferenceService = MLXInferenceService(snapshot: inference.hardwareCapabilitySnapshot)
        self.localInferenceService = localInferenceService
        let embeddingService = graphState.embeddingService
        let localRuntimeControlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
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

        let localRuntimeAgentProvenanceRecorder = AgentToolProvenanceRecorder()
        let localMLXClient = LocalMLXClient(
            runtime: localInferenceService,
            inference: inference,
            paths: localModelManager.paths,
            runtimeControlPlane: localRuntimeControlPlane,
            agentProvenanceRecorder: localRuntimeAgentProvenanceRecorder,
            prepareForRequest: {
                localModelRefreshThrottle.refreshIfNeeded()
            }
        )
        localMLXClient.configurePreparedGenerationRuntime(
            preparedModelRegistryState.generationRuntimeConfiguration
        )
        self.localMLXClient = localMLXClient
        let localGGUFRuntime = LocalGGUFInProcessRuntime()
        let localGGUFClient = LocalGGUFClient(
            runtime: localGGUFRuntime,
            inference: inference,
            runtimeControlPlane: localRuntimeControlPlane,
            agentProvenanceRecorder: localRuntimeAgentProvenanceRecorder,
            prepareForRequest: {
                localModelRefreshThrottle.refreshIfNeeded()
            }
        )
        localGGUFClient.configurePreparedGenerationRuntime(
            preparedModelRegistryState.generationRuntimeConfiguration
        )
        localGGUFClient.setOnRunProfileUpdated { [weak inference] profile in
            Task { @MainActor in
                inference?.setLatestLocalRuntimeHealth(LocalRuntimeHealthSnapshot(profile))
            }
        }
        let localLLMClient = LocalBackendLLMClient(
            inference: inference,
            runtimeControlPlane: localRuntimeControlPlane,
            mlxClient: localMLXClient,
            ggufClient: localGGUFClient,
            refreshAvailableRuntimeKinds: { configuration, requestedModelID in
                var availableRuntimeKinds: Set<BackendRuntimeKind> = [.mlx]

                let probeModelID = requestedModelID
                    ?? inference.effectiveLocalTextModelID
                    ?? configuration?.primaryGenerator.servedModelID

                let probeArtifactID = configuration.flatMap { config in
                    if let probeModelID {
                        return config.resolvedArtifactID(for: probeModelID) ?? config.primaryGenerator.artifactID
                    }
                    return config.primaryGenerator.artifactID
                }
                let probeModelDirectory = configuration.flatMap { config in
                    if let probeModelID {
                        return config.resolvedModelDirectory(for: probeModelID) ?? config.primaryResolvedModelDirectory
                    }
                    return config.primaryResolvedModelDirectory
                }
                let probeRuntimeKind: BackendRuntimeKind? = configuration.flatMap { config in
                    if let probeModelID {
                        return config.resolvedRuntimeKind(for: probeModelID) ?? LocalTextModelID(rawValue: probeModelID)?.runtimeKind
                    }
                    return config.primaryGenerator.runtimeKind
                } ?? probeModelID.flatMap { LocalTextModelID(rawValue: $0)?.runtimeKind }
                let hasPreparedProbeDirectory = probeModelDirectory.map { directory in
                    FileManager.default.fileExists(atPath: directory.path)
                } ?? false

                if probeRuntimeKind == .gguf, hasPreparedProbeDirectory, let probeModelID {
                    do {
                        _ = try await localGGUFRuntime.availability(
                            requestedModelID: probeModelID,
                            artifactID: probeArtifactID,
                            modelDirectory: probeModelDirectory
                        )
                        availableRuntimeKinds.insert(.gguf)
                    } catch {
                        Log.app.warning(
                            "AppBootstrap: GGUF availability probe failed for \(probeModelID, privacy: .public): \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }

                return availableRuntimeKinds
            },
            preparedGenerationRuntimeConfiguration: preparedModelRegistryState.generationRuntimeConfiguration,
            agentProvenanceRecorder: localRuntimeAgentProvenanceRecorder
        )
        localLLMClient.configurePreparedGenerationRuntime(
            preparedModelRegistryState.generationRuntimeConfiguration
        )
        self.localLLMClient = localLLMClient
        Task { @MainActor in
            _ = await localLLMClient.refreshRuntimeAvailability()
        }
        let cloudLLMClient = CloudLLMClient(inference: inference)
        self.cloudLLMClient = cloudLLMClient

        // LLMService is now the shared local-only gateway used by older subsystems.
        let llm = LLMService(
            inference: inference,
            localLLMClient: localLLMClient,
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

        // TriageService routes between Apple Intelligence and local Qwen.
        let triage = TriageService(
            inference: inference,
            localLLMService: localLLMClient,
            cloudLLMService: cloudLLMClient,
            prepareForRouting: {
                localModelRefreshThrottle.refreshIfNeeded()
            }
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

        // SSMStateService — Mamba/SSM hidden state persistence for vault memory
        let ssmStateRoot = applicationSupportDirectory
            .appendingPathComponent("Epistemos", isDirectory: true)
        let ssmStateService = SSMStateService(stateRoot: ssmStateRoot)
        ssmStateService.activate(enabled: epistemosConfig.ssmStatePersistenceEnabled)
        self.ssmStateService = ssmStateService

        // Wire SSM state service into the local inference engine
        Task {
            await localInferenceService.setSsmStateService(ssmStateService)
            await localInferenceService.setOnSSMStateSaved { sessionID, statePath in
                Log.app.info("SSM state saved for session=\(sessionID) at \(statePath)")
                guard let sessionUUID = UUID(uuidString: sessionID) else {
                    Log.app.warning("Ignoring SSM state bind for non-UUID session id \(sessionID)")
                    return
                }
                Task {
                    await ConversationPersistence.shared.bindSSMStatePath(
                        sessionID: sessionUUID,
                        statePath: statePath
                    )
                }
            }
            await localInferenceService.setOnRunProfileUpdated { [weak inference] profile in
                Task { @MainActor in
                    inference?.setLatestLocalRuntimeProfile(profile)
                }
            }
        }

        // NoteInsightService + CloudKnowledgeDistillationService now
        // construct lazily on first access (see properties above); the
        // ~6-15 MB of staging buffers they hold are deferred until a
        // notes-analysis or model-vault-rebuild path actually needs them.

        // Meaning Anchor Service — generates structured chat snapshots for graph intelligence
        self.meaningAnchorService = MeaningAnchorService(
            triageService: triage,
            graphState: graphState,
            modelContainer: container
        )

        // PipelineService — direct local answer streaming + tool-enabled loop
        let companionStateForPipeline = companionState
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: llm,
            triageService: triage,
            inference: inference,
            eventBus: eventBus,
            localModelClient: localLLMClient,
            constrainedDecoding: constrainedDecoding,
            vaultPathProvider: { [weak vaultSync] in
                vaultSync?.vaultURL?.path
            },
            activeCompanionInstructionProvider: { [weak companionStateForPipeline] in
                companionStateForPipeline?.activeAgentSystemInstruction()
            }
        )

        // Wire event bus to chat state
        chatState.eventBus = eventBus

        // Create coordinators
        let chatCoordinator = ChatCoordinator(
            bootstrap: self,
            chatState: chatState,
            inferenceState: inference,
            vaultSync: vaultSync,
            modelContainer: container,
            eventBus: eventBus,
            llmService: llm,
            notesUI: notesUI
        )

        let appCoordinator = AppCoordinator(
            bootstrap: self,
            chatCoordinator: chatCoordinator,
            eventBus: eventBus,
            uiState: uiState,
            chatState: chatState,
            dailyBriefState: dailyBriefState,
            triageService: triage,
            vaultSync: vaultSync,
            pipelineService: pipeline,
            modelContainer: container,
            notesUI: notesUI
        )
        self._coordinator = appCoordinator

        // Wire stop button → cancel active pipeline query
        chatState.onStopRequested = { [weak self] in
            self?.coordinator.cancelActiveQuery()
        }

        // Set shared before wiring so that any callbacks can access it.
        AppBootstrap.shared = self
        sovereignGateLifecycleObserver.start(gate: sovereignGate)

        self._workspaceService = WorkspaceService(modelContainer: container)
        self._workspaceSummaryService = WorkspaceSummaryService(
            triageService: triage, activityTracker: activityTracker, modelContainer: container
        )

        // Initialize reasoning loop (STaR + autoresearch flywheel)
        // Opt-in via Settings → Omega. Do NOT force-enable at startup.
        let reasoning = ReasoningLoopService(triageService: triage)
        reasoning.config.enabled = UserDefaults.standard.bool(forKey: "omega.enableReasoningLoop")
        reasoning.onTracesGenerated = { jsonlLines in
            #if !EPISTEMOS_APP_STORE
            KnowledgeFusionViewModel.shared.ingestReasoningTraces(jsonlLines)
            #endif
        }
        self._reasoningLoopService = reasoning

        #if !EPISTEMOS_APP_STORE
        // Configure Knowledge Fusion at boot so the inference bridge is ready.
        // State loading is deferred until after the primary launch path settles.
        KnowledgeFusionViewModel.shared.configure(triageService: triage)
        #endif

        #if !EPISTEMOS_APP_STORE
        // Initialize iMessage driver (starts disabled — user toggles via Settings).
        // Local-model contacts route through `LocalAgentLoop` via the
        // localModelClientProvider; cloud contacts continue to use
        // `runAgentSession` against agent_core.
        self._iMessageDriver = IMessageDriverService(
            vaultPathProvider: { [weak vaultSync] in
                vaultSync?.vaultURL?.path
            },
            currentChannelConfigurationProvider: { [weak channelRegistry] in
                guard let channelRegistry else {
                    return nil
                }
                return channelRegistry.configuration(for: channelRegistry.driverChannel)
            },
            channelAdapterProvider: { [weak channelRegistry] in
                channelRegistry?.makeDriverAdapter() ?? IMessageChannelAdapter()
            },
            localModelClientProvider: { [weak self] in
                self?.localMLXClient
            },
            constrainedDecodingProvider: { [weak self] in
                self?.constrainedDecoding
            }
        )
        let driverConfiguration = channelRegistry.configuration(for: channelRegistry.driverChannel)
        if driverConfiguration.supportsInboundDriver,
           driverConfiguration.pairingMetadata?.keepAliveOnLaunch == true,
           vaultSync.vaultURL != nil {
            self._iMessageDriver?.start()
        }
        #endif

        // Initialize device-action infrastructure. The retired dual-brain
        // router stays archived in source, but the live app keeps only the
        // device-action services that still back computer-use flows.
        self._deviceAgent = DeviceAgentService(hardwareTier: hardwareTierManager)
        let deviceBackend: any DeviceInferenceBackend
        if let coreMLBackend = CoreMLActionBackendLoader.loadIfAvailable() {
            deviceBackend = coreMLBackend
        } else {
            let sharedGPUBackend = SharedGPUBackend(
                triageService: triage,
                localModelClient: localMLXClient,
                constrainedDecoding: constrainedDecoding,
                activeModelID: { [weak inference] in
                    inference?.activeLocalTextModelID
                }
            )
            deviceBackend = SharedGPUAppleFallbackBackend(sharedGPUBackend: sharedGPUBackend)
        }
        deviceAgent.setBackend(deviceBackend)
        // Device-agent contextual embeddings stay lazy. Constructing the Apple
        // NL contextual resolver during passive launch can load language assets
        // before the user asks for computer-use/device-action work.

        // ScreenCaptureService, Screen2AXFusion, and AmbientCaptureService now
        // build lazily on first access via the computed-getter pattern declared
        // on the class. Sessions that never open a computer-use agent or enable
        // ambient capture skip ~8-12 MB of AX-listener buffers + AVF
        // scaffolding entirely.

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

        // Cognitive substrates (Phase 0). FrictionMonitor stays eager
        // (read by RootView at startup); AmbientCapture is lazy.
        self._frictionMonitor = FrictionMonitorService(config: epistemosConfig)

        // Phase 6.5: Text capture pipeline — capture → structure → memory → evidence → trace
        self._textCapturePipeline = TextCapturePipeline()
        FrictionMonitorService.shared = frictionMonitor
        // Agent services: gated by ShipGate.agentsEnabled. When false,
        // NightBrain never starts — no background agent work. Zero runtime overhead.
        if ShipGate.agentsEnabled {
            self._nightBrain = NightBrainService(
                config: epistemosConfig,
                searchIndexProvider: { @MainActor [weak vaultSync] in
                    vaultSync?.searchService
                },
                graphMemoryProvider: { @MainActor [weak self] in
                    self?._agentGraphMemory
                },
                cloudKnowledgeJob: { [weak self] in
                    guard let cloudKnowledgeDistillationService = await MainActor.run(body: {
                        self?.cloudKnowledgeDistillationService
                    }) else {
                        throw NightBrainService.JobExecutionError.missingCloudKnowledgeJob
                    }
                    _ = try await cloudKnowledgeDistillationService.rebuildAllModelVaults()
                },
                vaultPathProvider: { @MainActor [weak vaultSync] in
                    vaultSync?.vaultURL?.path
                },
                ssmStateServiceProvider: { @MainActor [weak self] in
                    self?.ssmStateService
                }
            )
        }

        if !Self.isRunningTests {
            wireLocalRuntimeLifecycle()
        }

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

        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        // W10.10-FIX — register the NightBrain LaunchAgent so the 3 AM
        // consolidation pass survives the main app being quit. Failure
        // is logged + swallowed (e.g. helper executable target not yet
        // present in this build, or user has not approved Login Item).
        do {
            try NightBrainScheduler.register()
        } catch {
            Log.app.warning(
                "W10.10 NightBrain LaunchAgent register failed — \(error.localizedDescription, privacy: .public)"
            )
        }
        #endif

        // Live NightBrain task registration (2026-05-04 follow-up #1+#5).
        // Idempotently registers all 10 canonical task names against the
        // process-global Rust scheduler singleton via UniFFI through
        // the typed Swift wrapper at `NightBrainLiveRegistry`. Without
        // this, the FFI exposes only canonical_task_names() + admission
        // preview — the live scheduler has zero registered tasks.
        // Logs the registered set for diagnostics; failure is non-fatal
        // (the FFI returns Vec::new() on panic via ffi_guard_value).
        Task.detached(priority: .background) {
            let registered = NightBrainLiveRegistry.shared.registerCanonicalTasks()
            Log.app.info(
                "NightBrain live registration: \(registered.count, privacy: .public) canonical tasks registered"
            )
        }
        // Fallback for missed nights (M-series laptop on battery, lid
        // closed): if launchd skipped > 36 h, run the in-process
        // consolidation inline now while the user is foreground.
        // AFM classifier sessions stay cold during passive launch. The pool
        // still reuses sessions after explicit classifier work starts, but it
        // must not warm FoundationModels/TokenGenerationCore before user intent.

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

        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        if NightBrainScheduler.shouldRunFallbackInline() {
            Task.detached(priority: .utility) { [weak self] in
                let result = await self?._nightBrain?.runInlineFallback()
                if case .finished? = result {
                    await MainActor.run { NightBrainScheduler.recordSuccessfulRun() }
                }
            }
        }
        #endif

        // Phase R.3 reactive re-init — subscribe to `.vaultChanged` so
        // the gateway tracks vault switches (bookmark restore lands
        // async, user can switch vaults, tests seed new vault URLs).
        // The handler is idempotent on vault-content mutations thanks
        // to the path-equality gate inside
        // `initializeRustResourceServiceIfReady()`.
        wireR3VaultSwitchObserver()

        // Register Omega specialist agents and wire LLM planning
        orchestratorState.registerAgents(
            vaultURL: vaultSync.vaultURL,
            modelContainer: container,
            triageService: triage,
            vaultSync: vaultSync,
            mcpBridge: mcpBridge,
            constrainedDecoding: constrainedDecoding
        )

        // Wire constrained decoding generator (Ω11)
        // Note: Current JSONSchemaLogitProcessor only applies soft EOS penalties,
        // NOT real grammar masking. ConstrainedDecodingService.isAvailable will
        // remain false until a fully constraining generator is registered.
        constrainedDecoding.setGenerator(MLXConstrainedGenerator(inferenceService: localInferenceService))
        if !constrainedDecoding.isAvailable {
            Log.app.info("AppBootstrap: constrained decoding registered but not available (soft guidance only)")
        }

        // Initialize knowledge graph integration (Ω14)
        self._agentGraphMemory = AgentGraphMemory(graphStore: graphState.store, graphState: graphState)
        self._recipeGraphSkills = RecipeGraphSkills(graphStore: graphState.store, mcpBridge: mcpBridge)
        self._ghostBrainCoauthor = GhostBrainCoauthor(graphStore: graphState.store, agentMemory: agentGraphMemory)
        orchestratorState.agentGraphMemory = agentGraphMemory

        // Instant recall now hydrates on first real recall use instead of
        // rebuilding its vault index during idle launch.
        instantRecallService.configureInitialSnapshotProvider { [self] in
            snapshotInstantRecallNotes()
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
            self._paperclipStore = try PaperclipStateStore()
        } catch {
            Log.app.error("PaperclipStateStore init failed: \(error.localizedDescription)")
        }

        // App Shortcuts metadata is static and Settings exposes an explicit
        // refresh action. Do not touch external Shortcuts services during
        // passive launch; that path has triggered privacy/TCC diagnostics.

        // Initialize Agent Command Center state (Phase 5).
        // Tool catalog load calls synchronous Rust FFI (listToolsForTier) which
        // can stall the main thread. Defer it off the synchronous init path so
        // the first frame renders without blocking.
        agentCommandCenterState.refreshSkillCatalog()
        agentCommandCenterState.refreshBrainCatalog(from: inference)
        agentCommandCenterState.startObservingGraphChatRequests()
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.agentCommandCenterState.refreshToolCatalog(
                from: self.mcpBridge,
                vaultPath: self.vaultSync.vaultURL?.path ?? ""
            )
        }
        agentChatState.eventBus = eventBus
        agentChatState.onStopRequested = { [weak self] in
            self?.coordinator.cancelActiveQuery()
        }

        commandCenterLocalHotkeyMonitor = nil
        commandCenterGlobalHotkeyMonitor = nil

        // D4 faculty roster: log the resolved primary agent model so users
        // can verify which local agent loaded. Default is the 7-8B 4-bit
        // fallback that fits the 16 GB Mac ceiling; the 36B LocalAgent is
        // gated on ≥32 GB host RAM + explicit opt-in.
        let primaryAgent = LocalModelCatalog.defaultPrimaryAgentModel
        Log.app.info(
            """
            Local agent model loaded: \
            \(primaryAgent.displayName, privacy: .public), \
            ~\(primaryAgent.estimated4BitWeightsGB, privacy: .public) GB \
            (host \(inference.hardwareCapabilitySnapshot.roundedMemoryGB, privacy: .public) GB, \
            36B opt-in min \(LocalModelCatalog.primaryAgentModelMinHostRAMGB, privacy: .public) GB)
            """
        )

        Log.app.info("AppBootstrap: initialized — local AI stack ready")
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

        let sampleSize = min(normalized.count, max(1, normalized.count / 10))
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
                    NoteFileStorage.readBodyData(pageId: pageId, fast: false)
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
        await workspaceSummaryService.generateSummaryNow()
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

            await self.nightBrain.start()
            #if !EPISTEMOS_APP_STORE
            KnowledgeFusionViewModel.shared.prepareBackgroundSchedulingIfNeeded()
            #endif

            if self.epistemosConfig.captureEnabled {
                await self.ambientCapture.start()
            }
        }
    }

    // MARK: - Forwarding (for external callers that reference AppBootstrap directly)

    func refreshAmbientManifest() { coordinator.refreshAmbientManifest() }
    func loadChat(chatId: String) { coordinator.loadChat(chatId: chatId) }

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
    func requestVaultBriefing(chatState: ChatState) { coordinator.requestVaultBriefing(chatState: chatState) }
    static func gradeFromConfidence(_ confidence: Double) -> EvidenceGrade { ChatCoordinator.gradeFromConfidence(confidence) }

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
        localMLXClient.configurePreparedGenerationRuntime(snapshot.generationRuntimeConfiguration)
        if let localLLMClient = localLLMClient as? LocalBackendLLMClient {
            localLLMClient.configurePreparedGenerationRuntime(snapshot.generationRuntimeConfiguration)
            Task { @MainActor in
                _ = await localLLMClient.refreshRuntimeAvailability()
            }
        } else {
            inferenceState.setPreparedLocalTextModelIDs(
                snapshot.generationRuntimeConfiguration?.interactiveLocalTextModelIDs(
                    availableRuntimeKinds: inferenceState.availableLocalGenerationRuntimeKinds
                ) ?? []
            )
        }
        applyPreparedRetrievalRuntimeConfiguration(snapshot.retrievalRuntimeConfiguration)
    }

    private func applyPreparedRetrievalRuntimeConfiguration(_ error: Error) {
        guard preparedModelRegistryState.lastErrorMessage != error.localizedDescription
            || !preparedModelRegistryState.entriesByKey.isEmpty else {
            return
        }

        preparedModelRegistryState.apply(error: error)
        inferenceState.setPreparedLocalTextModelIDs([])
        localMLXClient.configurePreparedGenerationRuntime(nil)
        if let localLLMClient = localLLMClient as? LocalBackendLLMClient {
            localLLMClient.configurePreparedGenerationRuntime(nil)
            Task { @MainActor in
                _ = await localLLMClient.refreshRuntimeAvailability()
            }
        }
        applyPreparedRetrievalRuntimeConfiguration(nil)
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

    func applyDisplayModeAndRelaunch(_ mode: AppDisplayMode) {
        uiState.setDisplayMode(mode)
        clearVisualCaches()

        guard !Self.isRunningTests else {
            Log.app.info("Skipping display-mode relaunch under tests")
            return
        }

        Log.app.info("Display mode updated to \(mode.rawValue, privacy: .public) — relaunching")
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
            try context.delete(model: SDModelProfile.self)
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

        chatState.clearMessages()
        notesUI.resetForVaultSwitch()
        pipelineState.reset()
        clearVaultLifecycleRuntimeState(
            reason: "Reset Everything completed",
            clearWorkspaceRestore: true
        )

        inferenceState.setRoutingMode(.auto)
        inferenceState.setPreferredLocalTextModelID(
            inferenceState.hardwareCapabilitySnapshot.recommendedLocalTextModelID.rawValue
        )
        inferenceState.setPreferredChatModelSelection(
            .localMLX(inferenceState.hardwareCapabilitySnapshot.recommendedLocalTextModelID.rawValue)
        )

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

    private func wireLocalRuntimeLifecycle() {
        let center = NotificationCenter.default
        localRuntimeObserverTokens = [
            LocalRuntimeObserverToken(
                center: center,
                token: center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.localRuntimeActivationTask?.cancel()
                    self?.localRuntimeActivationTask = Task(priority: .utility) { [weak self] in
                        try? await Task.sleep(for: .milliseconds(150))
                        guard !Task.isCancelled else { return }
                        self?.refreshPreparedRetrievalRuntimeConfigurationIfNeeded()
                        self?.syncLocalRuntimeConditions(appActive: true)
                        self?.localRuntimeActivationTask = nil
                    }
                }
            }
            ),
            LocalRuntimeObserverToken(
                center: center,
                token: center.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.localRuntimeActivationTask?.cancel()
                    self?.localRuntimeActivationTask = nil
                    self?.syncLocalRuntimeConditions(appActive: false)
                }
            }
            ),
            LocalRuntimeObserverToken(
                center: center,
                token: center.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.syncLocalRuntimeConditions(appActive: nil)
                }
            }
            ),
            LocalRuntimeObserverToken(
                center: center,
                token: center.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.syncLocalRuntimeConditions(appActive: nil)
                }
            }
            ),
        ]
        syncLocalRuntimeConditions(appActive: NSApp?.isActive ?? true)
    }

    private func syncLocalRuntimeConditions(appActive: Bool?) {
        let conditions = LocalRuntimeConditions.current(
            appActive: appActive ?? (NSApp?.isActive ?? true)
        )
        inferenceState.setLocalRuntimeConditions(conditions)
        Task(priority: .utility) { [localInferenceService] in
            await localInferenceService.updateRuntimeConditions(conditions)
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
            case .vaultPageChanged(let pageId):
                self.enqueueShadowPageReindexIfReady(pageId: pageId)
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

        for observer in localRuntimeObserverTokens {
            observer.center.removeObserver(observer.token)
        }
        localRuntimeObserverTokens.removeAll()
        localRuntimeActivationTask?.cancel()
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
