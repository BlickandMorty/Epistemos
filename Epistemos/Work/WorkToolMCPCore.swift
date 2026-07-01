import Foundation

// W-R3 (2026-06-24): the protocol CORE for the app-hosted MCP that exposes the FULL native Epistemos tool
// set to OpenCode (owner requirement: "every tool expressed"). Pure JSON-RPC request→response shaping over
// the Rust tool catalog, Swift-owned native descriptors, and the production `LocalAgentToolExecutor` (which
// actually executes Swift-side tools — computer-use via ComputerUseBridge, vault via Rust FFI).
//
// This is the EXECUTABLE bridge the external `omega_mcp_stdio` can't be: that Rust stdio server can only
// run Rust-side tools, so Swift-side tools (see/click/type) return an honest error there. Here, tools/call
// routes to the in-app `LocalAgentToolExecutor`, so EVERY tool is callable.
//
// NO network in this file — the loopback NWListener transport + OpenCode-config registration (W-R2
// zero-config) wrap this core in a later increment. Unit-testable with a stub executor.

struct WorkToolMCPCore {
    static let contextSnapshotToolName = "epistemos.context.snapshot"
    private static let maxDiagnosticIdentifierCharacters = 96

    /// Executes a tool by (name, argumentsJson). Production passes the app's real `LocalAgentToolExecutor`;
    /// tests pass a stub.
    let executor: LocalAgentToolExecutor
    /// Which tools are surfaced for this build (Pro/direct-dist vs MAS).
    var distribution: ToolSurfacePolicy.Distribution = .currentBuild
    /// The vault root used by the production full-tier executor. `tools/list` must advertise the same
    /// Epistemos-native catalog that `tools/call` can actually execute.
    var nativeToolVaultPath: String?
    /// Optional Work-owned app-context provider. This is deliberately plain data, so graph/chat/note owners can
    /// populate it later without Work importing their UI/state types.
    var appContextProvider: (@Sendable () -> WorkAppContextSnapshot?)? = nil

    /// Handle one MCP JSON-RPC request → response JSON string.
    func handle(requestJSON: String) async -> String {
        guard let data = requestJSON.data(using: .utf8),
              let req = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = req["method"] as? String else {
            return Self.errorResponse(id: NSNull(), code: -32700, message: "Parse error")
        }
        let id = req["id"] ?? NSNull()
        switch method {
        case "initialize":
            return Self.successResponse(id: id, result: Self.initializeResult())
        case "tools/list":
            var tools = Self.toolsList(
                distribution: distribution,
                nativeToolVaultPath: nativeToolVaultPath
            )
            if appContextProvider != nil {
                Self.appendContextSnapshotToolIfNeeded(tools: &tools)
            }
            return Self.successResponse(
                id: id,
                result: ["tools": tools])
        case "tools/call":
            guard let params = req["params"] as? [String: Any],
                  let rawName = params["name"] as? String else {
                return Self.errorResponse(id: id, code: -32602, message: "tools/call requires params.name")
            }
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                return Self.errorResponse(id: id, code: -32602, message: "tools/call requires params.name")
            }
            if name == Self.contextSnapshotToolName {
                guard appContextProvider != nil else {
                    return Self.errorResponse(id: id, code: -32601, message: "Tool not found: \(Self.diagnosticIdentifier(name))")
                }
                return Self.successResponse(
                    id: id,
                    result: Self.toolCallResult(from: Self.contextSnapshotResult(appContextProvider?())))
            }
            guard let callableName = Self.callableToolName(
                name,
                distribution: distribution,
                nativeToolVaultPath: nativeToolVaultPath
            ) else {
                return Self.errorResponse(id: id, code: -32601, message: "Tool not found: \(Self.diagnosticIdentifier(name))")
            }
            let argumentsJSON = Self.argumentsJSON(from: params["arguments"])
            let result = await executor(callableName, argumentsJSON)
            return Self.successResponse(id: id, result: Self.toolCallResult(from: result))
        default:
            return Self.errorResponse(id: id, code: -32601, message: "Method not found: \(Self.diagnosticIdentifier(method))")
        }
    }

    // MARK: Pure shaping helpers (testable; no network, no FFI except toolsList)

    /// The full surfaced native catalog as MCP tool descriptors (vault + graph + computer-use + …).
    static func toolsList(
        distribution: ToolSurfacePolicy.Distribution,
        nativeToolVaultPath: String? = nil
    ) -> [[String: Any]] {
        if let agentCoreTools = agentCoreToolsList(
            distribution: distribution,
            nativeToolVaultPath: nativeToolVaultPath
        ), !agentCoreTools.isEmpty {
            return Self.mergedToolDescriptors([
                agentCoreTools,
                swiftNativeToolDescriptors(distribution: distribution),
            ])
        }

        return Self.mergedToolDescriptors([
            omegaToolDescriptors(distribution: distribution),
            swiftNativeToolDescriptors(distribution: distribution),
        ])
    }

    static func callableToolName(
        _ rawName: String,
        distribution: ToolSurfacePolicy.Distribution,
        nativeToolVaultPath: String? = nil
    ) -> String? {
        let canonicalName = AgentToolNameAliases.canonical(rawName)
        guard !canonicalName.isEmpty else {
            return nil
        }
        return advertisedCallableToolName(
            matching: rawName,
            distribution: distribution,
            nativeToolVaultPath: nativeToolVaultPath
        )
    }

    private static func advertisedCallableToolName(
        matching rawName: String,
        distribution: ToolSurfacePolicy.Distribution,
        nativeToolVaultPath: String?
    ) -> String? {
        for descriptor in toolsList(distribution: distribution, nativeToolVaultPath: nativeToolVaultPath) {
            guard let name = descriptor["name"] as? String else { continue }
            let canonicalName = AgentToolNameAliases.canonical(name)
            guard !canonicalName.isEmpty else { continue }
            if AgentToolNameAliases.containsEquivalent(
                AgentToolNameAliases.equivalentNames(for: canonicalName),
                rawName
            ) {
                return canonicalName
            }
        }
        return nil
    }

    private static func omegaToolDescriptors(
        distribution: ToolSurfacePolicy.Distribution
    ) -> [[String: Any]] {
        let json = OmegaToolRegistry.planningSchemasJson(distribution: distribution)
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [[String: Any]] ?? []
    }

    private static func swiftNativeToolDescriptors(
        distribution: ToolSurfacePolicy.Distribution
    ) -> [[String: Any]] {
        ToolSurfacePolicy.surfacedTools(
            WorkNativeToolExecutor.toolDefinitions,
            distribution: distribution
        ).map(\.planningSchema)
    }

    private static func mergedToolDescriptors(_ descriptorGroups: [[[String: Any]]]) -> [[String: Any]] {
        var seenNames: Set<String> = []
        var merged: [[String: Any]] = []
        for descriptor in descriptorGroups.flatMap({ $0 }) {
            guard let name = descriptor["name"] as? String else { continue }
            let canonicalName = AgentToolNameAliases.canonical(name)
            guard !canonicalName.isEmpty,
                  seenNames.insert(canonicalName).inserted else {
                continue
            }
            var canonicalized = descriptor
            canonicalized["name"] = canonicalName
            merged.append(canonicalized)
        }
        return merged
    }

    #if canImport(agent_coreFFI)
    private static func agentCoreToolsList(
        distribution: ToolSurfacePolicy.Distribution,
        nativeToolVaultPath: String?
    ) -> [[String: Any]]? {
        let vaultPath = FoundationSafety.managedToolRuntimeVaultDirectory(
            preferredVaultPath: nativeToolVaultPath
        ).path
        guard let schemas = try? listToolsForTier(vaultPath: vaultPath, tier: ChatToolTier.full.rawValue) else {
            return nil
        }
        let tools = schemas.map { schema in
            let riskLevel = schema.riskLevel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
        return ToolSurfacePolicy.surfacedTools(tools, distribution: distribution).map(\.planningSchema)
    }
    #else
    private static func agentCoreToolsList(
        distribution: ToolSurfacePolicy.Distribution,
        nativeToolVaultPath: String?
    ) -> [[String: Any]]? {
        nil
    }
    #endif

    static func initializeResult() -> [String: Any] {
        [
            "protocolVersion": "2024-11-05",
            "serverInfo": ["name": "epistemos-native-tools", "version": "0.1.0"],
            "capabilities": ["tools": [String: Any]()],
        ]
    }

    static func contextSnapshotToolDescriptor() -> [String: Any] {
        [
            "name": contextSnapshotToolName,
            "description": "Return the bounded Epistemos Work app context currently attached to this engine session.",
            "inputSchema": [
                "type": "object",
                "properties": [String: Any](),
                "additionalProperties": false,
            ],
        ]
    }

    static func appendContextSnapshotToolIfNeeded(tools: inout [[String: Any]]) {
        guard !tools.contains(where: { ($0["name"] as? String) == contextSnapshotToolName }) else { return }
        tools.append(contextSnapshotToolDescriptor())
    }

    static func contextSnapshotResult(_ snapshot: WorkAppContextSnapshot?) -> LocalToolResult {
        let json = snapshot?.jsonString() ?? #"{"available":false,"reason":"No Epistemos Work context is attached."}"#
        return LocalToolResult(toolName: contextSnapshotToolName, resultJson: json, isError: false)
    }

    /// MCP passes `arguments` as a JSON object; the executor wants a JSON string. Normalize dict/string/nil.
    static func argumentsJSON(from arguments: Any?) -> String {
        guard let arguments else { return "{}" }
        if let string = arguments as? String { return string }
        if let data = try? JSONSerialization.data(withJSONObject: arguments),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }

    /// Map a `LocalToolResult` → MCP tools/call result (`{content:[{type:text,text}], isError}`).
    static func toolCallResult(from result: LocalToolResult) -> [String: Any] {
        [
            "content": [["type": "text", "text": result.resultJson]],
            "isError": result.isError,
        ]
    }

    static func successResponse(id: Any, result: [String: Any]) -> String {
        jsonRPC(["jsonrpc": "2.0", "id": id, "result": result])
    }

    static func errorResponse(id: Any, code: Int, message: String) -> String {
        jsonRPC(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
    }

    static func diagnosticIdentifier(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "[empty]" }
        guard !looksSecretBearing(trimmed) else { return "[redacted]" }
        guard trimmed.count > maxDiagnosticIdentifierCharacters else { return trimmed }

        let end = trimmed.index(trimmed.startIndex, offsetBy: maxDiagnosticIdentifierCharacters - 3)
        return String(trimmed[..<end]) + "..."
    }

    private static func looksSecretBearing(_ value: String) -> Bool {
        let lower = value.lowercased()
        let secretMarkers = [
            "authorization",
            "bearer",
            "api_key",
            "api-key",
            "apikey",
            "access_token",
            "refresh_token",
            "client_secret",
            "id_token",
            "auth_code",
            "password",
            "secret",
            "token=",
            "token:",
            "sk-",
            "ghp_",
            "xoxb-",
        ]
        if secretMarkers.contains(where: { lower.contains($0) }) {
            return true
        }
        return lower.contains("://") && (lower.contains("@") || lower.contains("?") || lower.contains("#"))
    }

    private static func jsonRPC(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"jsonrpc":"2.0","error":{"code":-32603,"message":"serialize failed"}}"#
        }
        return string
    }
}
