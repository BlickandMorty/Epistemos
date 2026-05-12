import Foundation
import os

nonisolated enum AgentToolNameAliases {
    private static let legacyToV2: [String: String] = [
        "vault_search": "vault.search",
        "vault_read": "vault.read",
        "vault_write": "vault.write",
        "vault_get": "vault.read",
        "pkm_search": "vault.search",
        "pkm_get": "vault.read",
        "pkm_write": "vault.write",
        "chunk_reduce": "chunk.reduce",
        "pkm_graph_neighbors": "graph.neighbors",
        "read_file": "file.read",
        "write_file": "file.write",
        "edit_file": "file.patch",
        "delete_file": "file.delete",
        "patch": "file.patch",
        "search_files": "file.search",
        "list_files": "file.list",
        "move_file": "file.move",
        "todo": "system.todo",
        "vault_recall": "knowledge.recall",
        "contradiction_check": "knowledge.contradiction_check",
        "analyzecontradiction": "knowledge.contradiction_check",
        "scoreevidence": "knowledge.evidence_score",
        "neural_recall": "knowledge.neural_recall",
        "session_search": "knowledge.session_search",
        "create_note": "note.create",
        "edit_note": "note.edit",
        "search_notes": "vault.search",
        "list_notes": "vault.list",
        "collectsnippet": "research.collect_snippet",
        "savecitation": "citation.save",
        "createresearchnote": "note.research_digest",
        "graph_query": "graph.query",
        "vault_navigate": "graph.vault_navigate",
        "memory": "memory.curated",
        "open_url": "web.fetch",
        "web_search": "web.search",
        "search_web": "web.search",
        "web_fetch": "web.fetch",
        "readpagecontent": "web.extract",
        "searchpapers": "research.search_papers",
        "web_extract": "web.extract",
        "web_crawl": "web.crawl",
        "bash_execute": "action.bash",
        "run_command": "action.bash",
        "run_persistent": "action.terminal",
        "terminal": "action.terminal",
        "process": "system.process",
        "cronjob": "system.cron",
        "skills_list": "skills.list",
        "skill_view": "skills.view",
        "skill_manage": "skills.manage",
        "vision_analyze": "media.vision_analyze",
        "image_generate": "media.image_generate",
        "text_to_speech": "media.text_to_speech",
        "mcp_discover": "discovery.mcp_discover",
        "model_catalog": "discovery.model_catalog",
        "mixture_of_minds": "intelligence.mixture_of_minds",
        "find_symbol": "workspace.find_symbol",
        "get_function_source": "workspace.get_function_source",
        "get_dependencies": "workspace.get_dependencies",
        "get_dependents": "workspace.get_dependents",
        "get_change_impact": "workspace.get_change_impact",
    ]

    private static let legacyNamesByV2: [String: Set<String>] = {
        var namesByV2: [String: Set<String>] = [:]
        for (legacy, v2) in legacyToV2 {
            namesByV2[v2, default: []].insert(legacy)
        }
        return namesByV2
    }()

    static func canonical(_ toolName: String) -> String {
        let normalized = toolName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return legacyToV2[normalized] ?? normalized
    }

    static func legacyName(for toolName: String) -> String? {
        legacyNamesByV2[canonical(toolName)]?.sorted().first
    }

    static func equivalentNames(for toolName: String) -> Set<String> {
        let canonicalName = canonical(toolName)
        var names: Set<String> = [canonicalName]
        if let legacyNames = legacyNamesByV2[canonicalName] {
            names.formUnion(legacyNames)
        }
        return names
    }

    static func containsEquivalent(_ names: Set<String>, _ toolName: String) -> Bool {
        !names.isDisjoint(with: equivalentNames(for: toolName))
    }

    static func preferredAvailableName(
        for canonicalName: String,
        availableTools: [OmegaToolDefinition]
    ) -> String? {
        let availableNames = Set(availableTools.map { $0.name.lowercased() })
        let canonicalName = canonical(canonicalName)
        if availableNames.contains(canonicalName) {
            return canonicalName
        }
        for legacy in legacyNamesByV2[canonicalName]?.sorted() ?? [] {
            if availableNames.contains(legacy) {
                return legacy
            }
        }
        return nil
    }
}

nonisolated enum ToolSurfacePolicy {
    enum Distribution: Sendable {
        case currentBuild
        case coreAppStore
        case proResearch
    }

    static let coreAppStoreAllowedToolNames: Set<String> = [
        "vault.search",
        "vault.read",
        "vault.write",
        "file.read",
        "file.write",
        "file.patch",
        "file.search",
        "system.todo",
        "graph.query",
        "memory.curated",
        "web.search",
        "web.extract",
        "web.crawl",
    ]

    /// User-facing tool surfaces must stay aligned with the runtime contract.
    /// If the app cannot actually satisfy a capability today, the tool should
    /// disappear from visible planning surfaces instead of being advertised and
    /// then failing at runtime.
    static func surfacedTools(
        _ tools: [OmegaToolDefinition],
        distribution: Distribution = .currentBuild
    ) -> [OmegaToolDefinition] {
        var seenCanonicalNames: Set<String> = []
        return tools.compactMap { tool in
            let canonicalName = AgentToolNameAliases.canonical(tool.name)
            guard isSurfacedToolName(canonicalName, distribution: distribution),
                  seenCanonicalNames.insert(canonicalName).inserted else {
                return nil
            }

            return OmegaToolDefinition(
                name: canonicalName,
                agent: tool.agent,
                description: tool.description,
                argumentsExample: tool.argumentsExample,
                schemaJson: tool.schemaJson,
                destructive: tool.destructive,
                requiresConfirmation: tool.requiresConfirmation
            )
        }
    }

    static func isSurfacedToolName(
        _ toolName: String,
        distribution: Distribution = .currentBuild
    ) -> Bool {
        let canonicalToolName = AgentToolNameAliases.canonical(toolName)
        if resolvedDistribution(distribution) == .coreAppStore,
           !coreAppStoreAllowedToolNames.contains(canonicalToolName) {
            return false
        }

        switch canonicalToolName {
        case "think":
            return false
        case "media.image_generate":
            return BackendRuntimeKind.allCases.contains {
                BackendRuntimeCapabilities.runtime($0).supportsImageGenerate
            }
        default:
            return true
        }
    }

    static func resolvedDistribution(_ distribution: Distribution) -> Distribution {
        if isCoreAppStoreBuild {
            return .coreAppStore
        }

        switch distribution {
        case .currentBuild:
            return .proResearch
        case .coreAppStore, .proResearch:
            return distribution
        }
    }

    private static var isCoreAppStoreBuild: Bool {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return true
        #else
        return ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        #endif
    }
}

/// Bridges the Rust `agent_core` tool tier system to Swift. This is the glue
/// that lets normal chat modes (Fast / Thinking / Pro) call tools without
/// running the full agent loop — they use a tier-filtered registry + a
/// `toolExecutor` closure backed by `execute_tool_call`.
///
/// Typical use from inside `PipelineService`:
///
/// ```swift
/// let bridge = ToolTierBridge(vaultPath: vaultPath, tier: .chatLite)
/// let tools = try bridge.loadTools()
/// let loop = LocalAgentLoop.liveLoop(
///     using: modelClient,
///     toolExecutor: bridge.toolExecutor(),
///     modelID: modelID
/// )
/// let result = try await loop.run(
///     objective: query,
///     tools: tools,
///     onToken: { token in /* stream */ }
/// )
/// ```
///
/// The bridge silently returns an empty tool list when the `agent_coreFFI`
/// bindings aren't available, which keeps the UI responsive in unit-test
/// builds where the Rust FFI module isn't linked.
nonisolated enum ToolTierBridgeError: LocalizedError, Sendable {
    case bindingsUnavailable
    case invalidToolList(String)

    var errorDescription: String? {
        switch self {
        case .bindingsUnavailable:
            "Rust agent_core bindings are not available."
        case .invalidToolList(let reason):
            "Failed to load tool list: \(reason)"
        }
    }
}

/// Logical tool tier used by the chat path. These map 1:1 onto the Rust
/// `ToolTier` enum via the string form accepted by `with_tier` on the
/// registry.
nonisolated enum ChatToolTier: String, Sendable, CaseIterable {
    case none
    case chatLite = "chat_lite"
    case chatPro = "chat_pro"
    case agent
    case full

    /// Derive the tier to use for a given operating mode. This is the
    /// mapping PipelineService uses when building tools for the active
    /// chat session.
    static func from(operatingMode: EpistemosOperatingMode) -> ChatToolTier {
        switch operatingMode {
        case .fast:     .chatLite
        case .thinking: .chatLite
        case .pro:      .chatPro
        case .agent:    .agent
        }
    }
}

/// Main actor — all mutation happens on the main thread so the Rust FFI
/// calls can run via `Task.detached` without worrying about sharing the
/// bridge between threads.
@MainActor
final class ToolTierBridge {
    private let vaultPath: String
    private let tier: ChatToolTier
    private let allowedToolNames: Set<String>?
    private let distribution: ToolSurfacePolicy.Distribution
    private let logger = Logger(subsystem: "com.epistemos", category: "ToolTierBridge")

    private var resolvedVaultPath: String {
        FoundationSafety.managedToolRuntimeVaultDirectory(
            preferredVaultPath: vaultPath
        ).path
    }

    init(
        vaultPath: String,
        tier: ChatToolTier,
        allowedToolNames: Set<String>? = nil,
        distribution: ToolSurfacePolicy.Distribution = .currentBuild
    ) {
        self.vaultPath = vaultPath
        self.tier = tier
        self.allowedToolNames = allowedToolNames
        self.distribution = distribution
    }

    /// Load the tier-filtered tool list as `OmegaToolDefinition` structs so
    /// `LocalAgentPromptBuilder` can inject them into the local model's system
    /// prompt. Returns an empty array when:
    /// - The Rust bindings are unavailable
    /// - The tier is `.none`
    func loadTools() -> [OmegaToolDefinition] {
        guard tier != .none else {
            return []
        }
        let resolvedVaultPath = self.resolvedVaultPath

        #if canImport(agent_coreFFI)
        do {
            let schemas: [ToolSchemaFfi]
            if let allowedToolNames {
                schemas = try listToolsForTierFiltered(
                    vaultPath: resolvedVaultPath,
                    tier: tier.rawValue,
                    allowedToolNames: Array(allowedToolNames).sorted()
                )
            } else {
                schemas = try listToolsForTier(vaultPath: resolvedVaultPath, tier: tier.rawValue)
            }
            let tools = schemas.map { schema in
                OmegaToolDefinition(
                    name: schema.name,
                    agent: "rust",
                    description: schema.description,
                    argumentsExample: "{}",
                    schemaJson: schema.parametersJson,
                    destructive: schema.riskLevel == "destructive",
                    requiresConfirmation: schema.riskLevel == "destructive"
                )
            }
            return ToolSurfacePolicy.surfacedTools(
                tools,
                distribution: distribution
            )
        } catch {
            // RCA13 RCA2-P1-016: bump from .warning to .error and post
            // a Notification so any subscribed UI (chat composer
            // capability pill, command-center diagnostics row) can
            // distinguish "Rust bindings broke" from "tier intentionally
            // disabled." Empty return preserved for compatibility, but
            // the surface is no longer silent.
            logger.error(
                "Tool list fetch FAILED (tier=\(self.tier.rawValue, privacy: .public), vault=\(resolvedVaultPath, privacy: .public)): \(error.localizedDescription, privacy: .public). Tool-capable surfaces will run without tools until the next refresh."
            )
            NotificationCenter.default.post(
                name: .toolTierBridgeLoadFailed,
                object: nil,
                userInfo: [
                    "tier": self.tier.rawValue,
                    "error": error.localizedDescription,
                ]
            )
            return []
        }
        #else
        // RCA13 RCA2-P1-016: build-time #else (no agent_coreFFI in
        // this target). Log once at error level so anyone running a
        // debug build without the FFI knows tools are off.
        logger.error("Tool list fetch unavailable: agent_coreFFI not linked in this build.")
        return []
        #endif
    }

    /// Returns a tool executor closure suitable for `LocalAgentLoop`.
    /// The closure forwards to the Rust `execute_tool_call` FFI and
    /// wraps the result as a `LocalToolResult`.
    func toolExecutor() -> LocalAgentToolExecutor {
        let path = self.resolvedVaultPath
        let tierRaw = self.tier.rawValue
        let allowlist = self.allowedToolNames.map { Array($0).sorted() }
        let distribution = self.distribution
        return { @Sendable name, argumentsJson in
            await Self.executeToolCallBridged(
                vaultPath: path,
                tier: tierRaw,
                toolName: name,
                inputJson: argumentsJson,
                allowedToolNames: allowlist,
                distribution: distribution
            )
        }
    }

    /// Static helper so the executor closure doesn't capture `self`.
    /// Runs the call on a background task so we don't stall the main
    /// thread while the Rust side does I/O (file reads, HTTP fetches).
    private static func executeToolCallBridged(
        vaultPath: String,
        tier: String,
        toolName: String,
        inputJson: String,
        allowedToolNames: [String]?,
        distribution: ToolSurfacePolicy.Distribution
    ) async -> LocalToolResult {
        if let denial = executionPolicyDenial(
            toolName: toolName,
            distribution: distribution
        ) {
            return denial
        }

        #if canImport(agent_coreFFI)
        do {
            let result: ToolExecutionResultFfi
            if let allowedToolNames {
                result = try await executeToolCallFiltered(
                    vaultPath: vaultPath,
                    tier: tier,
                    toolName: toolName,
                    inputJson: inputJson,
                    allowedToolNames: allowedToolNames
                )
            } else {
                result = try await executeToolCall(
                    vaultPath: vaultPath,
                    tier: tier,
                    toolName: toolName,
                    inputJson: inputJson
                )
            }
            if result.success {
                return LocalToolResult(
                    toolName: toolName,
                    resultJson: result.outputJson,
                    isError: false
                )
            } else {
                let errJson = errorToJson(result.error ?? "unknown error")
                return LocalToolResult(
                    toolName: toolName,
                    resultJson: errJson,
                    isError: true
                )
            }
        } catch {
            let errJson = errorToJson(error.localizedDescription)
            return LocalToolResult(
                toolName: toolName,
                resultJson: errJson,
                isError: true
            )
        }
        #else
        let errJson = errorToJson("agent_core bindings unavailable")
        return LocalToolResult(
            toolName: toolName,
            resultJson: errJson,
            isError: true
        )
        #endif
    }

    nonisolated static func executionPolicyDenial(
        toolName: String,
        distribution: ToolSurfacePolicy.Distribution
    ) -> LocalToolResult? {
        guard !ToolSurfacePolicy.isSurfacedToolName(
            toolName,
            distribution: distribution
        ) else {
            return nil
        }

        return LocalToolResult(
            toolName: toolName,
            resultJson: errorToJson("Tool not found: \(toolName)"),
            isError: true
        )
    }

    private nonisolated static func errorToJson(_ message: String) -> String {
        let payload: [String: Any] = [
            "error": message,
            "success": false,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{\"error\":\"\(message)\",\"success\":false}"
    }
}

extension Notification.Name {
    /// Posted when `ToolTierBridge.loadTools()` fails (Rust FFI throw
    /// or build-time absence of agent_coreFFI). Per RCA13 RCA2-P1-016,
    /// subscribed UI surfaces can use this to distinguish "tier
    /// intentionally disabled" from "tools broken" instead of treating
    /// an empty array as both. userInfo carries `tier` (String) and
    /// optionally `error` (String).
    static let toolTierBridgeLoadFailed = Notification.Name(
        "com.epistemos.toolTierBridge.loadFailed"
    )
}
