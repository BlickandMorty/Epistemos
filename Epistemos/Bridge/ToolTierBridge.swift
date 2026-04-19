import Foundation
import os

nonisolated enum ToolSurfacePolicy {
    /// User-facing tool surfaces must stay aligned with the runtime contract.
    /// If the app cannot actually satisfy a capability today, the tool should
    /// disappear from visible planning surfaces instead of being advertised and
    /// then failing at runtime.
    static func surfacedTools(_ tools: [OmegaToolDefinition]) -> [OmegaToolDefinition] {
        tools.filter { isSurfacedToolName($0.name) }
    }

    static func isSurfacedToolName(_ toolName: String) -> Bool {
        switch toolName {
        case "think":
            return false
        case "image_generate":
            return BackendRuntimeKind.allCases.contains {
                BackendRuntimeCapabilities.runtime($0).supportsImageGenerate
            }
        default:
            return true
        }
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
    private let logger = Logger(subsystem: "com.epistemos", category: "ToolTierBridge")

    init(
        vaultPath: String,
        tier: ChatToolTier,
        allowedToolNames: Set<String>? = nil
    ) {
        self.vaultPath = vaultPath
        self.tier = tier
        self.allowedToolNames = allowedToolNames
    }

    /// Load the tier-filtered tool list as `OmegaToolDefinition` structs so
    /// `HermesPromptBuilder` can inject them into the local model's system
    /// prompt. Returns an empty array when:
    /// - The Rust bindings are unavailable
    /// - The vault path is empty
    /// - The tier is `.none`
    func loadTools() -> [OmegaToolDefinition] {
        guard !vaultPath.isEmpty, tier != .none else {
            return []
        }

        #if canImport(agent_coreFFI)
        do {
            let schemas: [ToolSchemaFfi]
            if let allowedToolNames {
                schemas = try listToolsForTierFiltered(
                    vaultPath: vaultPath,
                    tier: tier.rawValue,
                    allowedToolNames: Array(allowedToolNames).sorted()
                )
            } else {
                schemas = try listToolsForTier(vaultPath: vaultPath, tier: tier.rawValue)
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
            return ToolSurfacePolicy.surfacedTools(tools)
        } catch {
            logger.warning("Tool list fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
        #else
        return []
        #endif
    }

    /// Returns a tool executor closure suitable for `LocalAgentLoop`.
    /// The closure forwards to the Rust `execute_tool_call` FFI and
    /// wraps the result as a `LocalToolResult`.
    func toolExecutor() -> LocalAgentToolExecutor {
        let path = self.vaultPath
        let tierRaw = self.tier.rawValue
        let allowlist = self.allowedToolNames.map { Array($0).sorted() }
        return { @Sendable name, argumentsJson in
            await Self.executeToolCallBridged(
                vaultPath: path,
                tier: tierRaw,
                toolName: name,
                inputJson: argumentsJson,
                allowedToolNames: allowlist
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
        allowedToolNames: [String]?
    ) async -> LocalToolResult {
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

    private static func errorToJson(_ message: String) -> String {
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
