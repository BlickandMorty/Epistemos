import Foundation
import os

nonisolated enum AgentToolNameAliases {
    private static let legacyToV2: [String: String] = {
        var aliases: [String: String] = [
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
            "eidos_query": "eidos.query",
            "eidos_search": "eidos.query",
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
            "note_template": "note.template",
            "note_linker": "note.linker",
            "research_digest": "note.research_digest",
            "collectsnippet": "research.collect_snippet",
            "savecitation": "citation.save",
            "createresearchnote": "note.research_digest",
            "citation_extractor": "citation.extract",
            "markdown_table": "markdown.table",
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
            "clarify": "clarify.ask",
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
            "browser_complete_task": "browser.complete_task",
        ]
        #if !EPISTEMOS_APP_STORE && !MAS_SANDBOX
        aliases.merge([
            "bash_execute": "action.bash",
            "run_command": "action.bash",
            "run_persistent": "action.terminal",
            "terminal": "action.terminal",
            "process": "system.process",
            "cronjob": "system.cron",
        ]) { current, _ in current }
        #endif
        return aliases
    }()

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

    /// A separator/case-insensitive key for a tool name, namespaced so a stripped key only ever
    /// matches ANOTHER stripped key (never a raw canonical/legacy name). Local models frequently vary
    /// the separator (`web_search` / `web.search` / `websearch`) or casing; sharing this key across the
    /// variants lets a clear-intent tool call still resolve to its registered tool — directly the
    /// SS-LT "intent recognized but the tool call drops" failure. Empty for an all-separator string.
    static func separatorInsensitiveKey(_ toolName: String) -> String {
        let stripped = toolName.lowercased().filter { $0.isLetter || $0.isNumber }
        return stripped.isEmpty ? "" : "\u{1}sep:\(stripped)"
    }

    static func equivalentNames(for toolName: String) -> Set<String> {
        let canonicalName = canonical(toolName)
        var names: Set<String> = [canonicalName]
        if let legacyNames = legacyNamesByV2[canonicalName] {
            names.formUnion(legacyNames)
        }
        // Bridge separator/case variants of the canonical name (web_search ↔ web.search ↔ websearch).
        let separatorKey = separatorInsensitiveKey(canonicalName)
        if !separatorKey.isEmpty { names.insert(separatorKey) }
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

    static func canonicalizedDefinitions(
        for tools: [OmegaToolDefinition]
    ) -> [OmegaToolDefinition] {
        var seenNames: Set<String> = []
        var canonicalTools: [OmegaToolDefinition] = []
        canonicalTools.reserveCapacity(tools.count)

        for tool in tools {
            let canonicalName = canonical(tool.name)
            guard seenNames.insert(canonicalName).inserted else { continue }
            canonicalTools.append(OmegaToolDefinition(
                name: canonicalName,
                agent: tool.agent,
                description: tool.description,
                argumentsExample: tool.argumentsExample,
                schemaJson: tool.schemaJson,
                destructive: tool.destructive,
                requiresConfirmation: tool.requiresConfirmation
            ))
        }

        return canonicalTools
    }
}

nonisolated enum ToolSurfacePolicy {
    enum Distribution: Sendable {
        case currentBuild
        case coreAppStore
        case proResearch
    }

    /// Tools the MAS (App Store) build advertises + executes. Every
    /// canonical name here points at a Rust tool implementation that
    /// has been audited to:
    ///   1. NOT spawn a subprocess (osascript, bash, browser shim,
    ///      computer-use, iMessage outbound, cronjob, etc.)
    ///   2. NOT escape the vault root for filesystem ops
    ///   3. NOT require Accessibility / screen-recording / iMessage
    ///      Full Disk Access entitlements (those are Pro-only)
    ///
    /// 2026-05-13 expansion (mas-release-prep): added the
    /// vault-knowledge + composer tools
    /// the user asked for ("CLI + local agents + cloud agents + tool
    /// use looping + model looping + agent looping ... it shouldn't
    /// have Pro capabilities but should still be as good"):
    ///
    ///   * `knowledge.recall` / `.contradiction_check` /
    ///     `.session_search` / `.neural_recall` — vault knowledge
    ///     fetchers. Pure Rust + GRDB / Tantivy / HNSW lookups, no
    ///     subprocess.
    ///   * `note.template` / `note.linker` — note authoring helpers
    ///     scoped to the active vault (uses the existing vault
    ///     write surface that's already on the MAS list).
    ///   * `clarify.ask` — agent asks the user a follow-up question;
    ///     pure in-process prompt round-trip.
    ///   * Pro-only subagent / model-loop primitives stay out of
    ///     Core App Store because Rust registers `delegate_task` and
    ///     `intelligence.mixture_of_minds` only under `pro-build`.
    ///   * Pro-only skill management stays out of Core App Store because
    ///     Rust registers `skills.list` / `skills.view` / `skills.manage`
    ///     only under the `pro-build` feature.
    static let coreAppStoreAllowedToolNames: Set<String> = [
        // Vault primitives (verified sandbox-safe)
        "vault.search",
        "vault.read",
        "vault.write",
        "vault.list",
        // File ops scoped to vault root
        "file.read",
        "file.write",
        "file.patch",
        "file.search",
        // System
        "system.todo",
        // Graph + memory
        "graph.query",
        "graph.neighbors",
        "graph.vault_navigate",
        "memory.curated",
        // Eidos evidence selector
        "eidos.query",
        // Web (HTTPS via URLSession, no subprocess)
        "web.search",
        "web.extract",
        "web.crawl",
        "web.fetch",
        // 2026-05-13 MAS expansion — vault knowledge + note composition
        "knowledge.recall",
        "knowledge.contradiction_check",
        "knowledge.evidence_score",
        "knowledge.session_search",
        "knowledge.neural_recall",
        "note.create",
        "note.edit",
        "note.research_digest",
        "note.template",
        "note.linker",
        "clarify.ask",
        "research.collect_snippet",
        "research.search_papers",
        "citation.save",
        "chunk.reduce",
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

nonisolated enum ToolTierBridgeDiagnostics {
    static let maxMessageCharacters = 360
    private static let maxDomainCharacters = 96
    private static let domainAllowedPunctuation = CharacterSet(charactersIn: "._-")

    static func externalErrorDescription(_ error: Error, fallback: String) -> String {
        if let bridgeError = error as? ToolTierBridgeError {
            return boundedMessage(bridgeError.errorDescription ?? fallback, fallback: fallback)
        }
        let nsError = error as NSError
        let domain = safeDomain(nsError.domain)
        return boundedMessage("\(fallback) (domain=\(domain) code=\(nsError.code))", fallback: fallback)
    }

    static func toolErrorMessage(_ message: String, fallback: String = "tool failed") -> String {
        boundedMessage(message, fallback: fallback)
    }

    private static func boundedMessage(_ message: String, fallback: String) -> String {
        let bounded = String(message.prefix(maxMessageCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        guard value.count > maxMessageCharacters else {
            return value
        }
        return String(value.prefix(maxMessageCharacters - 3)) + "..."
    }

    private static func safeDomain(_ domain: String) -> String {
        let bounded = String(domain.prefix(maxDomainCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathLikeCharacters = CharacterSet(charactersIn: "/\\:")
        guard trimmed.rangeOfCharacter(from: pathLikeCharacters) == nil else {
            return "Error"
        }
        let value = trimmed.isEmpty ? "Error" : trimmed
        guard value.unicodeScalars.allSatisfy({ scalar in
            CharacterSet.alphanumerics.contains(scalar) || domainAllowedPunctuation.contains(scalar)
        }) else {
            return "Error"
        }
        let clamped = String(value.prefix(maxDomainCharacters))
        return clamped.isEmpty ? "Error" : clamped
    }
}

/// Logical tool tier used by the chat path. These map 1:1 onto the Rust
/// `ToolTier` enum via the string form accepted by `with_tier` on the
/// registry.
nonisolated enum ChatToolTier: String, Sendable, CaseIterable {
    case none
    case readOnly = "read_only"
    case chatLite = "chat_lite"
    case chatPro = "chat_pro"
    case agent
    case full

    var ffiTierName: String {
        switch self {
        case .readOnly:
            "full"
        default:
            rawValue
        }
    }

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

    private var effectiveAllowedToolNames: Set<String>? {
        switch tier {
        case .readOnly:
            allowedToolNames ?? []
        default:
            allowedToolNames
        }
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

    /// Load the tier-filtered tool list as `OmegaToolDefinition` structs for
    /// app-owned tool catalogs. Returns an empty array when:
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
            if let allowedToolNames = effectiveAllowedToolNames {
                schemas = try listToolsForTierFiltered(
                    vaultPath: resolvedVaultPath,
                    tier: tier.ffiTierName,
                    allowedToolNames: Array(allowedToolNames).sorted()
                )
            } else {
                schemas = try listToolsForTier(vaultPath: resolvedVaultPath, tier: tier.ffiTierName)
            }
            let tools = schemas.map { schema in
                let riskLevel = schema.riskLevel.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                return OmegaToolDefinition(
                    name: schema.name,
                    agent: "rust",
                    description: schema.description,
                    argumentsExample: "{}",
                    schemaJson: schema.parametersJson,
                    destructive: riskLevel == "destructive",
                    requiresConfirmation: riskLevel == "modification" || riskLevel == "destructive"
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
            let errorMessage = ToolTierBridgeDiagnostics.externalErrorDescription(
                error,
                fallback: "tool list fetch failed"
            )
            logger.error(
                "Tool list fetch FAILED (tier=\(self.tier.rawValue, privacy: .public), vault=redacted): \(errorMessage, privacy: .public). Tool-capable surfaces will run without tools until the next refresh."
            )
            NotificationCenter.default.post(
                name: .toolTierBridgeLoadFailed,
                object: nil,
                userInfo: [
                    "tier": self.tier.rawValue,
                    "error": errorMessage,
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
        let tierRaw = self.tier.ffiTierName
        let allowlist = self.effectiveAllowedToolNames.map { Array($0).sorted() }
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

    nonisolated static func normalizedInputJson(
        toolName: String,
        inputJson: String,
        defaultFileSearchRoot: String? = nil
    ) -> String {
        let canonicalName = AgentToolNameAliases.canonical(toolName)
        guard canonicalName == "file.search"
            || canonicalName == "file.read"
            || canonicalName == "eidos.query"
            || canonicalName == "vault.search" else {
            return inputJson
        }
        guard let data = inputJson.data(using: .utf8),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return inputJson
        }
        switch canonicalName {
        case "file.search":
            if trimmedStringValue(object["pattern"]) == nil {
                let aliases = ["query", "term", "text", "title", "name"]
                if let aliasValue = aliases.compactMap({ trimmedStringValue(object[$0]) }).first {
                    object["pattern"] = aliasValue
                }
            }
            if let maxResults = object["max_results"], object["limit"] == nil {
                object["limit"] = maxResults
            }
            if shouldUseDefaultFileSearchRoot(
                object["path"],
                defaultFileSearchRoot: defaultFileSearchRoot
            ),
               let defaultFileSearchRoot = normalizedDefaultFileSearchRoot(defaultFileSearchRoot) {
                object["path"] = defaultFileSearchRoot
            } else if trimmedStringValue(object["path"]) == nil {
                object["path"] = "."
            }
            object.removeValue(forKey: "query")
        case "file.read":
            if trimmedStringValue(object["path"]) == nil {
                let aliases = ["file", "file_path", "filePath", "title", "name"]
                if let aliasValue = aliases.compactMap({ trimmedStringValue(object[$0]) }).first {
                    object["path"] = aliasValue
                }
            }
            if let root = normalizedDefaultFileSearchRoot(defaultFileSearchRoot),
               let path = trimmedStringValue(object["path"]),
               let vaultScopedPath = vaultScopedReadPath(for: path, rootPath: root) {
                object["path"] = vaultScopedPath
            }
        case "vault.search":
            if trimmedStringValue(object["query"]) == nil {
                let aliases = ["pattern", "term", "text", "title", "name", "path"]
                if let aliasValue = aliases.compactMap({ trimmedStringValue(object[$0]) }).first {
                    object["query"] = aliasValue
                }
            }
            object.removeValue(forKey: "path")
        case "eidos.query":
            if trimmedStringValue(object["query"]) == nil {
                let aliases = ["pattern", "term", "text", "title", "name", "path"]
                if let aliasValue = aliases.compactMap({ trimmedStringValue(object[$0]) }).first {
                    object["query"] = aliasValue
                }
            }
            if let limit = object["limit"], object["top_k"] == nil {
                object["top_k"] = limit
            }
            object.removeValue(forKey: "path")
        default:
            break
        }
        guard JSONSerialization.isValidJSONObject(object),
              let normalizedData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys]
              ),
              let normalized = String(data: normalizedData, encoding: .utf8) else {
            return inputJson
        }
        return normalized
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
        if let denial = allowedToolNameDenial(
            toolName: toolName,
            allowedToolNames: allowedToolNames
        ) {
            return denial
        }
        let normalizedInputJson = normalizedInputJson(
            toolName: toolName,
            inputJson: inputJson,
            defaultFileSearchRoot: vaultPath
        )
        if let denial = emptySearchQueryDenial(toolName: toolName, inputJson: normalizedInputJson) {
            return denial
        }

        #if canImport(agent_coreFFI)
        do {
            if let appFirstResult = try await executeVaultLookupBeforeFileSearchIfNeeded(
                vaultPath: vaultPath,
                tier: tier,
                requestedToolName: toolName,
                normalizedInputJson: normalizedInputJson,
                allowedToolNames: allowedToolNames
            ) {
                return appFirstResult
            }
            let result = try await executeRustToolCall(
                vaultPath: vaultPath,
                tier: tier,
                toolName: toolName,
                inputJson: normalizedInputJson,
                allowedToolNames: allowedToolNames
            )
            if result.success {
                let isError = ToolOutputErrorClassifier.isError(
                    toolName: toolName,
                    outputJson: result.outputJson
                )
                return LocalToolResult(
                    toolName: toolName,
                    resultJson: result.outputJson,
                    isError: isError
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
            let errJson = errorToJson(ToolTierBridgeDiagnostics.externalErrorDescription(
                error,
                fallback: "tool execution failed"
            ))
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

    #if canImport(agent_coreFFI)
    private static func executeRustToolCall(
        vaultPath: String,
        tier: String,
        toolName: String,
        inputJson: String,
        allowedToolNames: [String]?
    ) async throws -> ToolExecutionResultFfi {
        if let allowedToolNames {
            return try await executeToolCallFiltered(
                vaultPath: vaultPath,
                tier: tier,
                toolName: toolName,
                inputJson: inputJson,
                allowedToolNames: allowedToolNames
            )
        }
        return try await executeToolCall(
            vaultPath: vaultPath,
            tier: tier,
            toolName: toolName,
            inputJson: inputJson
        )
    }

    private static func executeVaultLookupBeforeFileSearchIfNeeded(
        vaultPath: String,
        tier: String,
        requestedToolName: String,
        normalizedInputJson: String,
        allowedToolNames: [String]?
    ) async throws -> LocalToolResult? {
        guard let lookup = appFirstVaultLookupForFileSearch(
            toolName: requestedToolName,
            normalizedInputJson: normalizedInputJson,
            defaultFileSearchRoot: vaultPath,
            allowedToolNames: allowedToolNames
        ) else {
            return nil
        }

        let result = try await executeRustToolCall(
            vaultPath: vaultPath,
            tier: tier,
            toolName: lookup.toolName,
            inputJson: lookup.inputJson,
            allowedToolNames: allowedToolNames
        )
        guard result.success,
              vaultSearchOutputHasUsableResults(result.outputJson) else {
            return nil
        }

        return LocalToolResult(
            toolName: requestedToolName,
            resultJson: """
            App-first vault lookup (\(lookup.toolName)) ran before file.search and found note matches. Use the returned vault-relative path with vault.read before falling back to Finder/filesystem search.

            \(result.outputJson)
            """,
            isError: false
        )
    }
    #endif

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

    private nonisolated static func emptySearchQueryDenial(
        toolName: String,
        inputJson: String
    ) -> LocalToolResult? {
        let canonicalName = AgentToolNameAliases.canonical(toolName)
        guard canonicalName == "file.search"
            || canonicalName == "eidos.query"
            || canonicalName == "vault.search" else {
            return nil
        }
        guard let data = inputJson.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        let searchTermKey = canonicalName == "file.search" ? "pattern" : "query"
        guard trimmedStringValue(object[searchTermKey]) == nil else { return nil }
        return LocalToolResult(
            toolName: toolName,
            resultJson: errorToJson("Tool '\(canonicalName)' requires a non-empty \(searchTermKey)."),
            isError: true
        )
    }

    private nonisolated static func allowedToolNameDenial(
        toolName: String,
        allowedToolNames: [String]?
    ) -> LocalToolResult? {
        guard let allowedToolNames else { return nil }
        let allowed = Set(allowedToolNames.map(AgentToolNameAliases.canonical))
        let canonicalName = AgentToolNameAliases.canonical(toolName)
        guard allowed.contains(canonicalName) else {
            return LocalToolResult(
                toolName: toolName,
                resultJson: errorToJson("Tool not found: \(toolName)"),
                isError: true
            )
        }
        return nil
    }

    nonisolated static func appFirstVaultSearchInputForFileSearch(
        toolName: String,
        normalizedInputJson: String,
        defaultFileSearchRoot: String?,
        allowedToolNames: [String]? = nil
    ) -> String? {
        appFirstVaultLookupForFileSearch(
            toolName: toolName,
            normalizedInputJson: normalizedInputJson,
            defaultFileSearchRoot: defaultFileSearchRoot,
            allowedToolNames: allowedToolNames,
            preferredLookupToolName: "vault.search"
        )?.inputJson
    }

    nonisolated static func appFirstVaultLookupForFileSearch(
        toolName: String,
        normalizedInputJson: String,
        defaultFileSearchRoot: String?,
        allowedToolNames: [String]? = nil,
        preferredLookupToolName: String = "eidos.query"
    ) -> (toolName: String, inputJson: String)? {
        guard AgentToolNameAliases.canonical(toolName) == "file.search" else {
            return nil
        }
        let canonicalPreferred = AgentToolNameAliases.canonical(preferredLookupToolName)
        let lookupToolName: String
        if let allowedToolNames {
            let allowed = Set(allowedToolNames.map(AgentToolNameAliases.canonical))
            if canonicalPreferred == "eidos.query", allowed.contains("eidos.query") {
                lookupToolName = "eidos.query"
            } else if allowed.contains("vault.search") {
                lookupToolName = "vault.search"
            } else {
                return nil
            }
        } else if canonicalPreferred == "vault.search" {
            lookupToolName = "vault.search"
        } else {
            lookupToolName = "eidos.query"
        }
        guard let root = normalizedDefaultFileSearchRoot(defaultFileSearchRoot),
              let data = normalizedInputJson.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let pattern = trimmedStringValue(object["pattern"]),
              let requestedRoot = trimmedStringValue(object["path"]) else {
            return nil
        }

        let searchRoot = URL(
            fileURLWithPath: (requestedRoot as NSString).expandingTildeInPath,
            isDirectory: true
        ).standardizedFileURL
        let vaultRoot = URL(fileURLWithPath: root, isDirectory: true).standardizedFileURL
        guard isDescendant(searchRoot, of: vaultRoot) else {
            return nil
        }

        let requestedLimit = object["limit"] as? Int
            ?? (object["limit"] as? NSNumber)?.intValue
            ?? 5
        let vaultLimit = max(1, min(requestedLimit, 20))
        let vaultInput: [String: Any]
        if lookupToolName == "eidos.query" {
            vaultInput = [
                "query": pattern,
                "top_k": vaultLimit,
            ]
        } else {
            vaultInput = [
                "query": pattern,
                "limit": vaultLimit,
            ]
        }
        guard let encoded = try? JSONSerialization.data(
            withJSONObject: vaultInput,
            options: [.sortedKeys]
        ) else {
            return nil
        }
        guard let inputJson = String(data: encoded, encoding: .utf8) else {
            return nil
        }
        return (lookupToolName, inputJson)
    }

    nonisolated static func vaultSearchOutputHasUsableResults(_ output: String) -> Bool {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }
        if let data = trimmed.data(using: .utf8),
           let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let count = object["count"] as? Int {
                return count > 0
            }
            if let count = object["count"] as? NSNumber {
                return count.intValue > 0
            }
            if let results = object["results"] as? [Any] {
                return !results.isEmpty
            }
        }
        let lowercased = trimmed.lowercased()
        let noMatchSignals = [
            "no notes matched",
            "no vault note",
            "no recovery candidates",
            "ladder declined",
        ]
        guard !noMatchSignals.contains(where: lowercased.contains) else {
            return false
        }
        return trimmed.range(
            of: #"(?m)^\s*\d+\.\s+\*\*.+\*\*"#,
            options: .regularExpression
        ) != nil
    }

    private nonisolated static func trimmedStringValue(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private nonisolated static func shouldUseDefaultFileSearchRoot(
        _ value: Any?,
        defaultFileSearchRoot: String? = nil
    ) -> Bool {
        guard let path = trimmedStringValue(value) else { return true }
        if path == "." || path == "./" {
            return true
        }
        guard normalizedDefaultFileSearchRoot(defaultFileSearchRoot) != nil else {
            return false
        }

        let expanded = (path as NSString).expandingTildeInPath
        let standardized = URL(fileURLWithPath: expanded, isDirectory: true)
            .standardizedFileURL
            .path
        let home = FileManager.default.homeDirectoryForCurrentUser
            .standardizedFileURL
            .path
        return standardized == home
    }

    private nonisolated static func normalizedDefaultFileSearchRoot(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: raw, isDirectory: true).standardizedFileURL.path
    }

    private nonisolated static func vaultScopedReadPath(
        for rawPath: String,
        rootPath: String
    ) -> String? {
        guard !rawPath.hasPrefix("/") && !rawPath.hasPrefix("~") else {
            return nil
        }
        guard !rawPath.contains("://") else {
            return nil
        }

        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL
        let relativeCandidate = rootURL
            .appendingPathComponent(rawPath)
            .standardizedFileURL
        if isDescendant(relativeCandidate, of: rootURL),
           FileManager.default.fileExists(atPath: relativeCandidate.path) {
            return relativeCandidate.path
        }

        guard !rawPath.contains("/") else {
            return isDescendant(relativeCandidate, of: rootURL) ? relativeCandidate.path : nil
        }
        return uniqueVaultFileMatchingTitle(rawPath, rootURL: rootURL)?.path
    }

    private nonisolated static func uniqueVaultFileMatchingTitle(
        _ title: String,
        rootURL: URL
    ) -> URL? {
        let needle = normalizedVaultFilename(title)
        guard !needle.isEmpty,
              let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
                options: [.skipsPackageDescendants]
              ) else {
            return nil
        }

        var matches: [URL] = []
        var scanned = 0
        for case let url as URL in enumerator {
            scanned += 1
            if scanned > 5_000 { break }
            guard isDescendant(url.standardizedFileURL, of: rootURL) else { continue }
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isHiddenKey]),
                  values.isRegularFile == true,
                  values.isHidden != true else {
                continue
            }
            let fileName = normalizedVaultFilename(url.deletingPathExtension().lastPathComponent)
            let fullName = normalizedVaultFilename(url.lastPathComponent)
            guard fileName == needle || fullName == needle else { continue }
            matches.append(url.standardizedFileURL)
            if matches.count > 1 { return nil }
        }
        return matches.first
    }

    private nonisolated static func normalizedVaultFilename(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func isDescendant(_ url: URL, of rootURL: URL) -> Bool {
        let rootPath = rootURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    private nonisolated static func errorToJson(_ message: String) -> String {
        let safeMessage = ToolTierBridgeDiagnostics.toolErrorMessage(message)
        let payload: [String: Any] = [
            "error": safeMessage,
            "success": false,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{\"error\":\"\(safeMessage)\",\"success\":false}"
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
