import Foundation
import Observation
import os

@MainActor @Observable
final class AgentViewModel {
    private static let log = Logger(subsystem: "com.epistemos.agent", category: "AgentViewModel")

    var phase: AgentPhase = .idle
    var thinkingText = ""
    var responseText = ""
    var contentBlocks: [RenderedBlock] = []
    var errorMessage: String?
    var tokenUsage: (input: Int, output: Int) = (0, 0)
    var turnCount = 0
    var latestStopReason = ""
    var sessions: [AgentSessionSummary] = []
    var activeSessionID: String?
    var sessionSearchQuery = ""
    var sessionSearchResults: [AgentSessionSummary] = []

    private var currentTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?
    private let hermesManager: HermesSubprocessManager
    private let inferenceState: InferenceState?
    private var localLLMClient: (any LLMClientProtocol)?
    private var awaitingPrompt = false
    private var isAwaitingApproval = false
    private var activeContinuation: AsyncStream<AgentStreamEvent>.Continuation?
    private var installedBridgeHandler = false
    private var lastSubmittedPrompt = ""
    private var lastProviderName = "claude_sonnet"
    var adminViewModel: HermesAdminViewModel?
    private(set) var localInferencePort: Int?

    /// MCP server exposing native Swift tools to Hermes (vault, AX, screen).
    private var mcpServer: EpistemosMCPServer?
    /// MCP client for calling Hermes tools from Swift side.
    private var mcpClient: HermesMCPClient?
    /// Cron keepalive task — periodically tells bridge to tick the scheduler.
    private var cronKeepaliveTask: Task<Void, Never>?
    /// Context budget tracking — triggers compaction when context grows too large.
    let contextBudget = ContextBudgetManager()
    /// Loop detection for Hermes agent tool calls (mirrors OrchestratorState's detector).
    private let hermesLoopDetector = ToolLoopDetector()
    /// Depth limiting for Hermes delegate/subagent calls.
    private let hermesDepthLimiter = AgentDepthLimiter()
    /// Cost tracking in micro-dollars for the current session.
    let costTracker = CostTracker()
    /// Shadow git checkpoints for file-mutating tool calls.
    private let shadowCheckpoint = ShadowGitCheckpoint()
    /// Agent graph memory — plots Hermes findings as .idea/.source nodes in the knowledge graph.
    var agentGraphMemory: AgentGraphMemory?
    /// Speculative PTY pre-warming: pre-spawned PTY session ID, ready for immediate use.
    private var speculativePtyId: String?

    init(
        hermesManager: HermesSubprocessManager? = nil,
        inferenceState: InferenceState? = nil,
        localLLMClient: (any LLMClientProtocol)? = nil
    ) {
        self.hermesManager = hermesManager ?? HermesSubprocessManager()
        self.inferenceState = inferenceState
        self.localLLMClient = localLLMClient
    }

    var isRunning: Bool {
        switch phase {
        case .idle, .complete, .failed:
            return false
        default:
            return true
        }
    }

    var activeSessionSummary: AgentSessionSummary? {
        guard let activeSessionID else { return nil }
        return sessions.first(where: { $0.id == activeSessionID })
    }

    func prepareRuntimeIfNeeded() async {
        do {
            try await connectIfNeeded()
            requestSessionList()
        } catch {
            handleError(error.localizedDescription)
        }
    }

    func send(prompt: String, providerName: String = "claude_sonnet") {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastProviderName = providerName

        if isRunning {
            stop()
        }
        prepareTurnStateForNewPrompt(prompt: trimmed)

        let (stream, continuation) = AsyncStream<AgentStreamEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(256)
        )
        activeContinuation = continuation

        let startPayload = makeStartPayload(prompt: trimmed, providerName: providerName)

        currentTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await self.connectIfNeeded()
                self.sendHermesCommand(startPayload)
            } catch {
                self.handleError(error.localizedDescription)
            }
        }

        streamTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.consume(stream)
        }
    }

    func performQuickAction(_ action: HermesQuickAction) {
        send(prompt: action.slashCommand)
    }

    func stop() {
        if isRunning {
            sendHermesCommand([
                "command": "interrupt",
                "message": "Stop requested by the user.",
            ])
        }

        currentTask?.cancel()
        streamTask?.cancel()
        currentTask = nil
        streamTask = nil
        awaitingPrompt = false
        isAwaitingApproval = false
        activeContinuation?.finish()
        activeContinuation = nil

        if isRunning {
            phase = .idle
        }
    }

    func refreshSessions() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.connectIfNeeded()
                self.requestSessionList()
            } catch {
                self.handleError(error.localizedDescription)
            }
        }
    }

    func searchSessions(query: String) {
        sessionSearchQuery = query
        guard !query.isEmpty else {
            sessionSearchResults = []
            return
        }
        let payload: [String: Any] = [
            "command": "admin",
            "domain": "sessions",
            "action": "search",
            "query": query,
        ]
        sendHermesCommand(payload, handlesRuntimeFailure: false)
    }

    func startNewSession() {
        switchSession(command: "new_session")
    }

    func forkCurrentSession() {
        guard let activeSessionID else {
            startNewSession()
            return
        }
        switchSession(command: "fork_session", extraPayload: ["session_id": activeSessionID])
    }

    func resume(sessionID: String) {
        switchSession(command: "resume_session", extraPayload: ["session_id": sessionID])
    }

    func resolvePermission(id: String, approved: Bool) {
        sendHermesCommand([
            "command": "approval",
            "permission_id": id,
            "approved": approved,
        ])
        isAwaitingApproval = false
        phase = .thinking(tokenCount: max(1, thinkingText.count / 4))
    }

    /// Fetch the list of registered tools from Hermes via MCP tools/list.
    func fetchHermesTools() async -> [HermesToolItem]? {
        guard let client = mcpClient else { return nil }
        do {
            let result = try await client.listTools()
            guard case .dictionary(let dict) = result,
                  case .array(let toolsArray) = dict["tools"] else { return nil }
            return toolsArray.compactMap { item -> HermesToolItem? in
                guard case .dictionary(let toolDict) = item,
                      case .string(let name) = toolDict["name"] else { return nil }
                let desc: String
                if case .string(let d) = toolDict["description"] { desc = d } else { desc = "" }
                return HermesToolItem(name: name, description: desc)
            }
        } catch {
            Self.log.error("Failed to fetch Hermes tools: \(error.localizedDescription)")
            return nil
        }
    }

    private func consume(_ stream: AsyncStream<AgentStreamEvent>) async {
        var thinkingTokens = 0
        var responseTokens = 0

        // Token coalescing: buffer deltas and flush at ~30fps to avoid
        // triggering @Observable mutations on every single token.
        var pendingThinking = ""
        var pendingResponse = ""
        var lastFlush = ContinuousClock.now
        let flushInterval: Duration = .milliseconds(32)

        func flushTokens() {
            if !pendingThinking.isEmpty {
                thinkingText.append(pendingThinking)
                pendingThinking = ""
                phase = .thinking(tokenCount: thinkingTokens)
            }
            if !pendingResponse.isEmpty {
                responseText.append(pendingResponse)
                pendingResponse = ""
                phase = .responding(tokenCount: responseTokens)
            }
            lastFlush = ContinuousClock.now
        }

        for await event in stream {
            // Fast path: buffer token deltas and coalesce updates.
            let isDelta: Bool
            switch event {
            case .thinkingDelta(let text):
                pendingThinking.append(text)
                thinkingTokens += max(1, text.count / 4)
                isDelta = true

            case .textDelta(let text):
                pendingResponse.append(text)
                responseTokens += max(1, text.count / 4)
                isDelta = true

            default:
                isDelta = false
            }

            if isDelta {
                if ContinuousClock.now - lastFlush >= flushInterval {
                    flushTokens()
                }
                continue
            }

            // Non-delta event: flush any pending tokens first.
            flushTokens()

            switch event {
            case .thinkingDelta, .textDelta:
                break

            case .toolInputStreaming:
                break

            case .toolStarted(_, let name, let inputJson):
                flushBuffers()
                phase = .executing(toolName: name)
                contentBlocks.append(
                    .toolExecution(
                        name: name,
                        input: inputJson,
                        result: nil,
                        isError: false
                    )
                )

            case .toolCompleted(_, let result, let isError):
                if let lastIndex = contentBlocks.indices.last,
                   case .toolExecution(let name, let input, _, _) = contentBlocks[lastIndex] {
                    contentBlocks[lastIndex] = .toolExecution(
                        name: name,
                        input: input,
                        result: result,
                        isError: isError
                    )
                }
                phase = .reasoning(tokenCount: max(1, thinkingText.count / 4))

            case .subagentSpawned(let id, let role):
                contentBlocks.append(.status("Spawned \(role) subagent \(id)"))

            case .permissionRequired(let request):
                isAwaitingApproval = true
                phase = .awaitingApproval(request)

            case .contextCompacting(let tokens):
                contentBlocks.append(.status("Compacting context at ~\(tokens) tokens"))

            case .contextCompacted(let messageCount):
                contentBlocks.append(.status("Context compacted to \(messageCount) messages"))

            case .turnStarted(let turn, _):
                turnCount = turn
                if turn > 1 {
                    flushBuffers()
                    thinkingTokens = 0
                    responseTokens = 0
                }

            case .complete(let stopReason, let inputTokens, let outputTokens, let history):
                flushBuffers()
                if let history,
                   HermesSessionRefreshPolicy.shouldHydrateSurface(afterSubmittedPrompt: lastSubmittedPrompt) {
                    hydrateSessionSurface(with: history)
                }
                latestStopReason = stopReason
                tokenUsage = (inputTokens, outputTokens)
                phase = .complete
                awaitingPrompt = false
                isAwaitingApproval = false
                activeContinuation = nil

            case .error(let error):
                handleError(error.message)
            }
        }

        // Final flush for any remaining buffered tokens.
        flushTokens()
    }

    private func flushBuffers() {
        if !thinkingText.isEmpty {
            contentBlocks.append(
                .thinking(
                    text: thinkingText,
                    tokenCount: max(1, thinkingText.count / 4)
                )
            )
            thinkingText = ""
        }

        if !responseText.isEmpty {
            contentBlocks.append(.text(responseText))
            responseText = ""
        }
    }

    private func handleError(_ message: String) {
        errorMessage = message
        phase = .failed(message)
        awaitingPrompt = false
        isAwaitingApproval = false
        activeContinuation = nil
        lastSubmittedPrompt = ""
    }

    private func makeStartPayload(prompt: String, providerName: String) -> [String: Any] {
        var payload: [String: Any] = [
            "command": "start",
            "prompt": prompt,
            "cwd": AgentRuntimeDefaults.vaultPath,
        ]
        appendRuntimeOverrides(to: &payload, providerName: providerName)
        return payload
    }

    private func makeSessionPayload(command: String) -> [String: Any] {
        var payload: [String: Any] = [
            "command": command,
            "cwd": AgentRuntimeDefaults.vaultPath,
        ]
        appendRuntimeOverrides(to: &payload, providerName: nil)
        return payload
    }

    private func appendRuntimeOverrides(
        to payload: inout [String: Any],
        providerName: String?
    ) {
        guard let inferenceState else {
            if let providerName, !providerName.isEmpty {
                payload["provider_name"] = providerName
            }
            return
        }

        // Try cloud route first.
        if let route = HermesRuntimeRoute.resolve(
            for: inferenceState.preferredChatModelSelection,
            apiKeyLookup: { inferenceState.apiKey(for: $0) }
        ) {
            applyRoute(route, to: &payload)
            return
        }

        // Try local agent route (agent-capable local model → local inference server).
        if case .localQwen(let modelID) = inferenceState.preferredChatModelSelection,
           let port = localInferencePort,
           let route = HermesRuntimeRoute.resolveLocal(modelID: modelID, inferencePort: port) {
            applyRoute(route, to: &payload)
            return
        }

        if let providerName, !providerName.isEmpty {
            payload["provider_name"] = providerName
        }
    }

    private func applyRoute(_ route: HermesRuntimeRoute, to payload: inout [String: Any]) {
        payload["model"] = route.model
        payload["requested_provider"] = route.requestedProvider
        payload["env"] = route.environmentOverrides
        if let baseURL = route.baseURL {
            payload["base_url"] = baseURL
        }
        if let apiMode = route.apiMode {
            payload["api_mode"] = apiMode
        }
    }

    private func connectIfNeeded() async throws {
        if !installedBridgeHandler {
            // Initialize MCP server so Hermes can call back into Swift.
            let server = EpistemosMCPServer(subprocessManager: hermesManager)
            registerVaultTools(on: server)
            registerSkillDiscoveryTools(on: server)
            registerComputerUseTools(on: server)
            registerRoutingTools(on: server)
            registerPTYTools(on: server)
            registerGraphMemoryTools(on: server)
            // Start HTTP transport for large payloads (>50KB)
            _ = server.startHttpTransport()
            mcpServer = server

            // Initialize MCP client so Swift can call Hermes tools.
            let client = HermesMCPClient(subprocessManager: hermesManager)
            mcpClient = client

            hermesManager.setRequestHandler { [weak self] line in
                // Parse JSON off the main thread to avoid beachball on large payloads
                Task.detached { [weak self] in
                    let parsed = Self.parseBridgeLine(line)
                    await MainActor.run { [weak self] in
                        self?.routeParsedBridgeLine(line, parsed: parsed)
                    }
                }
            }
            installedBridgeHandler = true
        }

        if !hermesManager.isRunning {
            try await hermesManager.launch()
            startCronKeepalive()
        }
    }

    /// Parse a bridge line's JSON on any thread (nonisolated).
    /// Heavy JSON deserialization happens here — never on @MainActor.
    nonisolated private static func parseBridgeLine(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Routes a pre-parsed bridge line to the right handler (on @MainActor).
    /// - JSON-RPC requests (have "method") → MCP server
    /// - JSON-RPC responses (have "result"/"error" + "id") → MCP client
    /// - Bridge events (have "type") → regular event handler
    private func routeParsedBridgeLine(_ line: String, parsed: [String: Any]?) {
        guard let raw = parsed else {
            handleHermesBridgeLine(line)
            return
        }

        // JSON-RPC request from Hermes → MCP server
        if raw["method"] is String, raw["type"] == nil {
            mcpServer?.handleRequestLine(line)
            return
        }

        // JSON-RPC response to our MCP client request
        if (raw["result"] != nil || raw["error"] != nil),
           raw["id"] != nil,
           raw["type"] == nil {
            mcpClient?.handleIncomingLine(line)
            return
        }

        // Regular bridge event
        handleHermesBridgeLine(line)
    }

    // MARK: - MCP Vault Tools

    /// Register native vault tools on the MCP server so Hermes can search/read notes.
    private func registerVaultTools(on server: EpistemosMCPServer) {
        // Capture vault path on MainActor so handlers can use it off-actor.
        let vaultPath = AgentRuntimeDefaults.vaultPath
        server.registerTool(
            name: "vault_search",
            description: "Search the Epistemos vault for notes matching a query. Returns titles and paths.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "query": .dictionary([
                        "type": .string("string"),
                        "description": .string("Search query"),
                    ]),
                    "limit": .dictionary([
                        "type": .string("integer"),
                        "description": .string("Max results (default 10)"),
                    ]),
                ]),
                "required": .array([.string("query")]),
            ],
            handler: { _ in
                // Schema registered; dispatch handled via tool: prefix below
                return .success(.null)
            }
        )
        server.registerToolHandler(name: "vault_search") { params in
            let query: String
            let limit: Int
            if case .dictionary(let dict) = params {
                query = dict["query"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
                limit = dict["limit"].flatMap { if case .int(let n) = $0 { return n } else { return nil } } ?? 10
            } else {
                query = ""
                limit = 10
            }
            guard !query.isEmpty else {
                return .error(code: -32602, message: "Missing 'query' parameter")
            }

            // vaultPath captured at registration time above
            var results = searchVaultFiles(query: query, vaultPath: vaultPath, limit: limit)
            // Threat scan + sanitize + redact before sending to Hermes context
            results = results.compactMap { item in
                guard case .string(let s) = item else { return item }
                let scan = MemoryThreatScanner.scan(s)
                if scan.level == .blocked {
                    return nil  // Drop blocked content entirely
                }
                var sanitized = MemoryThreatScanner.sanitize(s)
                sanitized = CredentialRedactor.redact(sanitized)
                return .string(sanitized)
            }
            // U-curve reorder: place highest-relevance items at head + tail of context
            results = ContextCompiler.uCurveOrder(results)
            return .success(.array(results))
        }

        server.registerTool(
            name: "vault_read",
            description: "Read the full content of a note by its vault-relative path.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "path": .dictionary([
                        "type": .string("string"),
                        "description": .string("Vault-relative path to the note"),
                    ]),
                ]),
                "required": .array([.string("path")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "vault_read") { params in
            let notePath: String
            if case .dictionary(let dict) = params,
               case .string(let p) = dict["path"] {
                notePath = p
            } else {
                return .error(code: -32602, message: "Missing 'path' parameter")
            }

            let fullPath = (vaultPath as NSString).appendingPathComponent(notePath)
            guard FileManager.default.fileExists(atPath: fullPath) else {
                return .error(code: -32602, message: "Note not found: \(notePath)")
            }
            do {
                var content = try String(contentsOfFile: fullPath, encoding: .utf8)
                // Clamp to 16K chars to prevent context blowout
                if content.count > 16_384 {
                    let half = 8_000
                    let truncated = content.count - 16_384
                    content = String(content.prefix(half))
                        + "\n\n[... \(truncated) chars truncated ...]\n\n"
                        + String(content.suffix(half))
                }
                // Threat scan + sanitize + redact before sending to Hermes context
                let scan = MemoryThreatScanner.scan(content)
                if scan.level == .blocked {
                    return .error(code: -32600, message: "Note blocked: contains prompt injection patterns")
                }
                content = MemoryThreatScanner.sanitize(content)
                content = CredentialRedactor.redact(content)
                return .success(.string(content))
            } catch {
                return .error(code: -32603, message: "Failed to read note: \(error.localizedDescription)")
            }
        }

        server.registerTool(
            name: "vault_list",
            description: "List note files in the vault, optionally under a path prefix.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "prefix": .dictionary([
                        "type": .string("string"),
                        "description": .string("Path prefix to filter (e.g. 'projects/')"),
                    ]),
                    "limit": .dictionary([
                        "type": .string("integer"),
                        "description": .string("Max files to return (default 50)"),
                    ]),
                ]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "vault_list") { params in
            let prefix: String
            let limit: Int
            if case .dictionary(let dict) = params {
                prefix = dict["prefix"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
                limit = dict["limit"].flatMap { if case .int(let n) = $0 { return n } else { return nil } } ?? 50
            } else {
                prefix = ""
                limit = 50
            }

            let searchDir = prefix.isEmpty
                ? vaultPath
                : (vaultPath as NSString).appendingPathComponent(prefix)

            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: searchDir),
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return .success(.array([]))
            }

            var files: [AnyCodableValue] = []
            while let url = enumerator.nextObject() as? URL, files.count < limit {
                guard url.pathExtension == "md" else { continue }
                let relative = url.path.replacingOccurrences(of: vaultPath + "/", with: "")
                files.append(.string(relative))
            }
            return .success(.array(files))
        }
    }

    // MARK: - Native Skill Store (Progressive Disclosure)

    /// Register skill discovery tools so Hermes can progressively discover
    /// native tools without dumping all 85+ schemas into the prompt.
    /// Level 0: skill_discover → MMR-scored name+description summaries
    /// Level 1: skill_schema → full JSON schema for a specific tool
    private func registerSkillDiscoveryTools(on server: EpistemosMCPServer) {
        server.registerTool(
            name: "skill_discover",
            description: "Search for available native Epistemos tools by intent. Returns name + description summaries (Level 0). Use skill_schema to get the full schema for a specific tool.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "query": .dictionary([
                        "type": .string("string"),
                        "description": .string("What you want to do (e.g. 'search notes', 'browse web', 'edit file')"),
                    ]),
                    "limit": .dictionary([
                        "type": .string("integer"),
                        "description": .string("Max tools to return (default 5)"),
                    ]),
                ]),
                "required": .array([.string("query")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "skill_discover") { params in
            let query: String
            let limit: Int
            if case .dictionary(let dict) = params {
                query = dict["query"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
                limit = dict["limit"].flatMap { if case .int(let n) = $0 { return n } else { return nil } } ?? 5
            } else {
                return .error(code: -32602, message: "Missing query")
            }
            guard !query.isEmpty else {
                return .error(code: -32602, message: "Empty query")
            }

            let allTools = OmegaToolRegistry.all
            // Build scored items for MMR reranking
            let scored = allTools.map { tool in
                // Simple relevance: how many query terms appear in name+description
                let text = "\(tool.name) \(tool.description)".lowercased()
                let terms = query.lowercased().split(separator: " ")
                let matchCount = terms.filter { text.contains($0) }.count
                let relevance = Double(matchCount) / max(1.0, Double(terms.count))

                return MMRReranker.ScoredItem(
                    item: tool,
                    relevanceScore: relevance,
                    textForDiversity: text
                )
            }.filter { $0.relevanceScore > 0 }

            // If no keyword matches, fall back to returning all tools sorted by name
            let results: [OmegaToolDefinition]
            if scored.isEmpty {
                results = Array(allTools.prefix(limit))
            } else {
                let reranked = MMRReranker.rerank(
                    items: scored,
                    query: query,
                    limit: limit,
                    lambda: 0.7
                )
                results = reranked.map { $0.item }
            }

            // Level 0: name + agent + description only (no schema)
            let summaries: [AnyCodableValue] = results.map { tool in
                .dictionary([
                    "name": .string(tool.name),
                    "agent": .string(tool.agent),
                    "description": .string(tool.description),
                    "destructive": .bool(tool.destructive),
                ])
            }
            return .success(.dictionary([
                "tools": .array(summaries),
                "total_available": .int(allTools.count),
                "hint": .string("Use skill_schema(name) to get the full input schema for a tool."),
            ]))
        }

        server.registerTool(
            name: "skill_schema",
            description: "Get the full JSON input schema for a specific native tool. Call skill_discover first to find tool names.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "name": .dictionary([
                        "type": .string("string"),
                        "description": .string("Tool name from skill_discover results"),
                    ]),
                ]),
                "required": .array([.string("name")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "skill_schema") { params in
            let toolName: String
            if case .dictionary(let dict) = params,
               case .string(let n) = dict["name"] {
                toolName = n
            } else {
                return .error(code: -32602, message: "Missing 'name' parameter")
            }

            guard let tool = OmegaToolRegistry.all.first(where: { $0.name == toolName }) else {
                let available = OmegaToolRegistry.all.map(\.name).joined(separator: ", ")
                return .error(code: -32602, message: "Unknown tool: \(toolName). Available: \(available)")
            }

            return .success(.dictionary([
                "name": .string(tool.name),
                "agent": .string(tool.agent),
                "description": .string(tool.description),
                "inputSchema": .string(tool.schemaJson),
                "argumentsExample": .string(tool.argumentsExample),
                "destructive": .bool(tool.destructive),
                "requiresConfirmation": .bool(tool.requiresConfirmation),
            ]))
        }
    }

    // MARK: - Computer Use MCP Tools

    /// Expose macOS computer use capabilities as MCP tools so Hermes can
    /// drive the desktop natively via AXorcist + ScreenCaptureKit.
    private func registerComputerUseTools(on server: EpistemosMCPServer) {
        // see — AX-first hybrid perception via Screen2AXFusion
        server.registerTool(
            name: "computer_see",
            description: "Get the accessibility tree and screen content of the frontmost macOS application. Returns interactive UI elements that can be clicked, typed into, or scrolled.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "app_name": .dictionary([
                        "type": .string("string"),
                        "description": .string("Optional app name or bundle ID to target. Defaults to frontmost app."),
                    ]),
                ]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "computer_see") { params in
            let args = Self.anyCodableToDict(params)
            var result = await GhostComputerAgent.mcpSee(args: args)
            result = CredentialRedactor.redact(result)
            return .success(.string(result))
        }

        // click — AXorcist semantic targeting + omega-ax CGEvent fallback
        server.registerTool(
            name: "computer_click",
            description: "Click a macOS UI element. Prefers semantic targeting by label (uses AXorcist fuzzy match). Falls back to absolute coordinates.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "label": .dictionary([
                        "type": .string("string"),
                        "description": .string("Text label of the element to click (fuzzy matched via AXorcist)."),
                    ]),
                    "x": .dictionary(["type": .string("number"), "description": .string("Absolute X coordinate.")]),
                    "y": .dictionary(["type": .string("number"), "description": .string("Absolute Y coordinate.")]),
                ]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "computer_click") { [weak self] params in
            let args = Self.anyCodableToDict(params)
            guard let self else { return .error(code: -32603, message: "deallocated") }

            // Turbo-Quant: AXMutationDetector before/after for post-action verification
            let frontPID = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1 }
            let perception = await MainActor.run { Screen2AXFusion(screenCapture: self.screenCaptureService) }
            let before = frontPID > 0 ? await MainActor.run { AXMutationDetector.captureSnapshot(pid: frontPID, using: perception) } : nil

            let result = await MainActor.run { GhostComputerAgent.mcpClick(args: args) }

            // Post-action: detect UI mutation (~1ms cost)
            var enriched = result
            if let before, frontPID > 0 {
                try? await Task.sleep(for: .milliseconds(150)) // UI settle
                let after = await MainActor.run { AXMutationDetector.captureSnapshot(pid: frontPID, using: perception) }
                let mutation = await MainActor.run { AXMutationDetector.compare(before: before, after: after) }
                enriched = Self.appendMutationInfo(to: result, mutation: mutation)
            }

            enriched = CredentialRedactor.redact(enriched)
            return .success(.string(enriched))
        }

        // type — omega-ax CGEvent keyboard simulation
        server.registerTool(
            name: "computer_type",
            description: "Type text into the currently focused macOS UI element using keyboard simulation.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "text": .dictionary(["type": .string("string"), "description": .string("The text to type.")]),
                ]),
                "required": .array([.string("text")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "computer_type") { [weak self] params in
            let args = Self.anyCodableToDict(params)
            guard let self else { return .error(code: -32603, message: "deallocated") }

            let frontPID = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1 }
            let perception = await MainActor.run { Screen2AXFusion(screenCapture: self.screenCaptureService) }
            let before = frontPID > 0 ? await MainActor.run { AXMutationDetector.captureSnapshot(pid: frontPID, using: perception) } : nil

            let result = await MainActor.run { GhostComputerAgent.mcpType(args: args) }

            var enriched = result
            if let before, frontPID > 0 {
                try? await Task.sleep(for: .milliseconds(150))
                let after = await MainActor.run { AXMutationDetector.captureSnapshot(pid: frontPID, using: perception) }
                let mutation = await MainActor.run { AXMutationDetector.compare(before: before, after: after) }
                enriched = Self.appendMutationInfo(to: result, mutation: mutation)
            }

            enriched = CredentialRedactor.redact(enriched)
            return .success(.string(enriched))
        }

        // screenshot — ScreenCaptureKit capture
        server.registerTool(
            name: "computer_screenshot",
            description: "Capture a screenshot of the macOS screen or frontmost window. Returns base64-encoded PNG.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "target": .dictionary(["type": .string("string"), "description": .string("'screen' or 'window'. Defaults to 'window'.")]),
                ]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "computer_screenshot") { [weak self] params in
            guard let self else { return .error(code: -32603, message: "Agent deallocated") }
            let args = Self.anyCodableToDict(params)
            var result = await GhostComputerAgent.mcpScreenshot(args: args, screenCapture: self.screenCaptureService)
            result = CredentialRedactor.redact(result)
            return .success(.string(result))
        }

        // keys — keyboard shortcut simulation
        server.registerTool(
            name: "computer_keys",
            description: "Press a keyboard shortcut on macOS (e.g. 'cmd+c', 'enter', 'cmd+shift+s').",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "keys": .dictionary(["type": .string("string"), "description": .string("Key combo string, e.g. 'cmd+c'.")]),
                ]),
                "required": .array([.string("keys")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "computer_keys") { [weak self] params in
            let args = Self.anyCodableToDict(params)
            guard let self else { return .error(code: -32603, message: "deallocated") }

            let frontPID = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1 }
            let perception = await MainActor.run { Screen2AXFusion(screenCapture: self.screenCaptureService) }
            let before = frontPID > 0 ? await MainActor.run { AXMutationDetector.captureSnapshot(pid: frontPID, using: perception) } : nil

            let result = await MainActor.run { GhostComputerAgent.mcpKeys(args: args) }

            var enriched = result
            if let before, frontPID > 0 {
                try? await Task.sleep(for: .milliseconds(150))
                let after = await MainActor.run { AXMutationDetector.captureSnapshot(pid: frontPID, using: perception) }
                let mutation = await MainActor.run { AXMutationDetector.compare(before: before, after: after) }
                enriched = Self.appendMutationInfo(to: result, mutation: mutation)
            }

            enriched = CredentialRedactor.redact(enriched)
            return .success(.string(enriched))
        }

        // scroll — CGEvent scroll wheel simulation
        server.registerTool(
            name: "computer_scroll",
            description: "Scroll in a direction at the current mouse position on macOS.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "direction": .dictionary(["type": .string("string"), "description": .string("'up', 'down', 'left', 'right'.")]),
                    "amount": .dictionary(["type": .string("number"), "description": .string("Scroll amount. Defaults to 3.")]),
                ]),
                "required": .array([.string("direction")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "computer_scroll") { [weak self] params in
            let args = Self.anyCodableToDict(params)
            guard let self else { return .error(code: -32603, message: "deallocated") }

            let frontPID = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1 }
            let perception = await MainActor.run { Screen2AXFusion(screenCapture: self.screenCaptureService) }
            let before = frontPID > 0 ? await MainActor.run { AXMutationDetector.captureSnapshot(pid: frontPID, using: perception) } : nil

            let result = await MainActor.run { GhostComputerAgent.mcpScroll(args: args) }

            var enriched = result
            if let before, frontPID > 0 {
                try? await Task.sleep(for: .milliseconds(150))
                let after = await MainActor.run { AXMutationDetector.captureSnapshot(pid: frontPID, using: perception) }
                let mutation = await MainActor.run { AXMutationDetector.compare(before: before, after: after) }
                enriched = Self.appendMutationInfo(to: result, mutation: mutation)
            }

            enriched = CredentialRedactor.redact(enriched)
            return .success(.string(enriched))
        }
    }

    /// Screen capture service for computer use tools.
    private let screenCaptureService = ScreenCaptureService()

    /// Convert AnyCodableValue to [String: Any] for MCP tool handlers.
    nonisolated private static func anyCodableToDict(_ value: AnyCodableValue) -> [String: Any] {
        guard case .dictionary(let dict) = value else { return [:] }
        var result: [String: Any] = [:]
        for (key, val) in dict {
            switch val {
            case .string(let s): result[key] = s
            case .int(let i): result[key] = i
            case .double(let d): result[key] = d
            case .bool(let b): result[key] = b
            case .null: result[key] = NSNull()
            case .array(let arr):
                result[key] = arr.map { item -> Any in
                    if case .string(let s) = item { return s }
                    return String(describing: item)
                }
            case .dictionary: result[key] = Self.anyCodableToDict(val)
            }
        }
        return result
    }

    /// Append AXMutationDetector results to a JSON tool result string.
    /// Adds `mutation_detected`, `element_count_delta`, `new_window` fields
    /// so Hermes knows whether its action actually changed the UI.
    nonisolated private static func appendMutationInfo(
        to jsonResult: String,
        mutation: AXMutationDetector.MutationResult
    ) -> String {
        // Try to merge into existing JSON object
        guard let data = jsonResult.data(using: .utf8),
              var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Not valid JSON — wrap in object
            return "{\"result\":\"\(jsonResult.replacingOccurrences(of: "\"", with: "\\\""))\",\"mutation_detected\":\(mutation.mutated),\"element_count_delta\":\(mutation.elementCountDelta),\"new_window\":\(mutation.newWindowDetected)}"
        }
        dict["mutation_detected"] = mutation.mutated
        dict["element_count_delta"] = mutation.elementCountDelta
        dict["new_window"] = mutation.newWindowDetected
        dict["mutation_latency_ms"] = mutation.latencyMs
        guard let merged = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: merged, encoding: .utf8) else {
            return jsonResult
        }
        return str
    }

    // MARK: - Routing & Fallback MCP Tools

    /// Register CLI↔GUI routing hints and fallback chain tools so Hermes
    /// can make informed execution arm decisions and recover from failures.
    private func registerRoutingTools(on server: EpistemosMCPServer) {
        // HybridRouter: Given a task description, recommend CLI vs GUI execution arm
        server.registerTool(
            name: "optimal_execution_arm",
            description: "Given a task description, recommends whether to use CLI (terminal) or GUI (computer/automation) tools. Returns arm, confidence, and reasoning.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "description": .dictionary(["type": .string("string"), "description": .string("The task to classify.")]),
                ]),
                "required": .array([.string("description")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "optimal_execution_arm") { params in
            let args = Self.anyCodableToDict(params)
            let desc = args["description"] as? String ?? ""
            let result = await MainActor.run { () -> [String: AnyCodableValue] in
                let router = HybridRouter()
                let step = AgentStep(
                    description: desc,
                    assignedAgent: "",
                    toolName: "",
                    argumentsJson: "{}"
                )
                let decision = router.classify(step: step)
                return [
                    "arm": .string(decision.arm.rawValue),
                    "confidence": .double(decision.confidence),
                    "reasoning": .string(decision.reasoning),
                    "suggested_agent": decision.suggestedAgent.map { .string($0) } ?? .null,
                    "suggested_tool": decision.suggestedTool.map { .string($0) } ?? .null,
                ]
            }
            return .success(.dictionary(result))
        }

        // FallbackChainResolver: When a tool fails, suggest an alternative on the opposite arm
        server.registerTool(
            name: "query_fallback",
            description: "When a tool fails, suggests a fallback on the opposite execution arm (GUI→CLI or CLI→GUI). Returns the fallback agent, tool, and reasoning.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "failed_tool": .dictionary(["type": .string("string"), "description": .string("The tool that failed.")]),
                    "failed_agent": .dictionary(["type": .string("string"), "description": .string("The agent that failed.")]),
                    "error": .dictionary(["type": .string("string"), "description": .string("The error message.")]),
                ]),
                "required": .array([.string("failed_tool"), .string("failed_agent")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "query_fallback") { params in
            let args = Self.anyCodableToDict(params)
            let failedTool = args["failed_tool"] as? String ?? ""
            let failedAgent = args["failed_agent"] as? String ?? ""
            let error = args["error"] as? String ?? "Tool execution failed"

            let result = await MainActor.run { () -> MCPToolResult in
                let resolver = FallbackChainResolver()
                let step = AgentStep(
                    description: error,
                    assignedAgent: failedAgent,
                    toolName: failedTool,
                    argumentsJson: "{}"
                )
                let failResult = AgentStepResult.fail(error, stepId: step.id, durationMs: 0)
                guard let fallback = resolver.resolveFallback(failedStep: step, failedResult: failResult) else {
                    return .error(code: -32600, message: "No fallback available for \(failedAgent)/\(failedTool)")
                }
                return .success(.dictionary([
                    "fallback_agent": .string(fallback.agent),
                    "fallback_tool": .string(fallback.toolName),
                    "arguments": .string(fallback.argumentsJson),
                    "reasoning": .string(fallback.reasoning),
                ]))
            }
            return result
        }
    }

    // MARK: - Native PTY MCP Tools (omega-mcp Rust)

    /// Expose the omega-mcp Rust PTY pool as MCP tools so Hermes terminal
    /// commands execute in a real macOS ZSH with proper $PATH, nvm, cargo, etc.
    /// Without this, Python subprocess.run() gets a barren GUI app environment.
    private func registerPTYTools(on server: EpistemosMCPServer) {
        // native_pty_spawn — Create a persistent PTY session with real ZSH
        server.registerTool(
            name: "native_pty_spawn",
            description: "Spawn a native macOS pseudo-terminal (PTY) session with the user's real shell environment ($PATH, nvm, cargo, brew). Returns a pty_id for subsequent commands.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "session_id": .dictionary(["type": .string("string"), "description": .string("Session identifier for grouping PTY instances.")]),
                    "initial_dir": .dictionary(["type": .string("string"), "description": .string("Working directory to start in.")]),
                ]),
                "required": .array([.string("session_id")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "native_pty_spawn") { params in
            let args = Self.anyCodableToDict(params)
            let sessionId = args["session_id"] as? String ?? UUID().uuidString
            let initialDir = args["initial_dir"] as? String ?? NSHomeDirectory()
            let result = ptySpawnSession(sessionId: sessionId, shell: "/bin/zsh", initialDir: initialDir)
            return .success(.string(CredentialRedactor.redact(result)))
        }

        // native_pty_run — Execute a command in an existing PTY session
        server.registerTool(
            name: "native_pty_run",
            description: "Execute a shell command in a native macOS PTY session. Inherits user's full shell environment. Returns stdout, exit hint, working directory, and duration.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "pty_id": .dictionary(["type": .string("string"), "description": .string("PTY session ID from native_pty_spawn.")]),
                    "command": .dictionary(["type": .string("string"), "description": .string("Shell command to execute.")]),
                    "timeout_ms": .dictionary(["type": .string("number"), "description": .string("Timeout in milliseconds. Defaults to 30000 (30s).")]),
                ]),
                "required": .array([.string("pty_id"), .string("command")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "native_pty_run") { params in
            let args = Self.anyCodableToDict(params)
            let ptyId = args["pty_id"] as? String ?? ""
            let command = args["command"] as? String ?? ""
            let timeoutMs = args["timeout_ms"] as? Int ?? 30_000

            guard !ptyId.isEmpty, !command.isEmpty else {
                return .error(code: -32602, message: "Missing pty_id or command")
            }

            let result = ptyExecuteCommand(ptyId: ptyId, command: command, timeoutMs: UInt64(timeoutMs))
            return .success(.string(CredentialRedactor.redact(result)))
        }

        // native_pty_close — Close a PTY session
        server.registerTool(
            name: "native_pty_close",
            description: "Close a native PTY session and clean up resources.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "pty_id": .dictionary(["type": .string("string"), "description": .string("PTY session ID to close.")]),
                ]),
                "required": .array([.string("pty_id")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "native_pty_close") { params in
            let args = Self.anyCodableToDict(params)
            let ptyId = args["pty_id"] as? String ?? ""
            if !ptyId.isEmpty { ptyCloseSession(ptyId: ptyId) }
            return .success(.dictionary(["closed": .bool(true)]))
        }
    }

    // MARK: - Agent Graph Memory MCP Tools

    /// Register tools that let Hermes write its findings into the native
    /// SwiftData knowledge graph as .idea and .source nodes, and trigger
    /// NightBrain's Ebbinghaus decay to prevent memory bloat.
    private func registerGraphMemoryTools(on server: EpistemosMCPServer) {
        // record_finding — Write an agent insight into the knowledge graph
        server.registerTool(
            name: "record_finding",
            description: "Record an agent finding as an .idea node in the Epistemos knowledge graph. Creates edges to cited sources and auto-generates tags. Findings are subject to NightBrain Ebbinghaus decay.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "description": .dictionary(["type": .string("string"), "description": .string("What the agent discovered or concluded.")]),
                    "sources": .dictionary([
                        "type": .string("array"),
                        "description": .string("URLs or file paths of sources cited."),
                        "items": .dictionary(["type": .string("string")]),
                    ]),
                    "related_note_ids": .dictionary([
                        "type": .string("array"),
                        "description": .string("IDs of existing vault notes this finding relates to."),
                        "items": .dictionary(["type": .string("string")]),
                    ]),
                ]),
                "required": .array([.string("description")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "record_finding") { [weak self] params in
            guard let self else { return .error(code: -32603, message: "deallocated") }
            let args = Self.anyCodableToDict(params)
            let description = args["description"] as? String ?? ""
            let sources = args["sources"] as? [String] ?? []
            let relatedNoteIds = args["related_note_ids"] as? [String] ?? []

            guard !description.isEmpty else {
                return .error(code: -32602, message: "Missing description")
            }

            await MainActor.run { [weak self] in
                guard let self, let graphMemory = self.agentGraphMemory else { return }
                // Build synthetic AgentStepResults from source URLs
                var steps: [AgentStepResult] = []
                for url in sources {
                    steps.append(AgentStepResult(
                        stepId: UUID(),
                        success: true,
                        outputJson: "{\"url\":\"\(url)\"}",
                        error: nil,
                        durationMs: 0,
                        confidence: 0.8
                    ))
                }
                if steps.isEmpty {
                    // At least one successful step so recordExecution doesn't bail
                    steps.append(AgentStepResult.ok("{}", stepId: UUID(), durationMs: 0))
                }
                graphMemory.recordExecution(
                    taskDescription: description,
                    steps: steps,
                    relatedNoteIds: relatedNoteIds
                )
            }

            return .success(.dictionary([
                "recorded": .bool(true),
                "description": .string(String(description.prefix(80))),
                "source_count": .int(sources.count),
            ]))
        }

        // recall_agent_memory — Search the agent's graph memory
        server.registerTool(
            name: "recall_agent_memory",
            description: "Search the agent's long-term knowledge graph for past findings. Returns relevant .idea and .source nodes ranked by relevance with MMR diversity.",
            inputSchema: [
                "type": .string("object"),
                "properties": .dictionary([
                    "query": .dictionary(["type": .string("string"), "description": .string("Search query.")]),
                    "limit": .dictionary(["type": .string("integer"), "description": .string("Max results. Defaults to 10.")]),
                ]),
                "required": .array([.string("query")]),
            ],
            handler: { _ in .success(.null) }
        )
        server.registerToolHandler(name: "recall_agent_memory") { [weak self] params in
            guard let self else { return .error(code: -32603, message: "deallocated") }
            let args = Self.anyCodableToDict(params)
            let query = args["query"] as? String ?? ""
            let limit = args["limit"] as? Int ?? 10

            let results = await MainActor.run { [weak self] () -> [[String: AnyCodableValue]] in
                guard let self, let graphMemory = self.agentGraphMemory else { return [] }
                let nodes = graphMemory.recall(query: query, limit: limit)
                return nodes.map { node in
                    [
                        "id": .string(node.id),
                        "type": .string(node.type.rawValue),
                        "label": .string(node.label),
                        "weight": .double(node.weight),
                        "source_url": node.metadata.url.map { .string($0) } ?? .null,
                    ]
                }
            }

            return .success(.dictionary([
                "results": .array(results.map { .dictionary($0) }),
                "count": .int(results.count),
            ]))
        }
    }

    // MARK: - Cron Keepalive

    private func startCronKeepalive() {
        cronKeepaliveTask?.cancel()
        cronKeepaliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled, let self else { break }
                guard self.hermesManager.isRunning else { break }
                // Tick the cron scheduler in the Python subprocess
                self.sendHermesCommand([
                    "command": "admin",
                    "domain": "cron",
                    "action": "tick",
                ], handlesRuntimeFailure: false)
            }
        }
    }

    private func handleHermesBridgeLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = payload["type"] as? String else {
            // Non-JSON lines (Python warnings, library output, debug prints)
            // are NOT fatal — log and ignore. The stdout guard in
            // epistemos_bridge.py should prevent most of these, but if any
            // leak through, crashing the session is disproportionate.
            let preview = String(line.prefix(120))
            Self.log.warning("Ignoring non-JSON bridge line: \(preview, privacy: .public)")
            return
        }

        if let sessionID = payload["session_id"] as? String,
           !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activeSessionID = sessionID
        }

        switch type {
        case "ready":
            if let port = payload["inference_port"] as? Int, port > 0 {
                localInferencePort = port
            }
            requestSessionList()
            // Auto-refresh all admin state so MCP servers, cron, skills, and
            // config are populated immediately when the bridge connects.
            adminViewModel?.refreshAll()

        case "inference_request":
            handleInferenceRequest(payload)

        case "session_list":
            let activeID = (payload["active_session_id"] as? String) ?? activeSessionID
            let parsedSessions = (payload["sessions"] as? [[String: Any]] ?? [])
                .compactMap { AgentSessionSummary(payload: $0, activeSessionID: activeID) }
                .sorted(by: Self.sessionSort)
            sessions = parsedSessions
            if let activeID, !activeID.isEmpty {
                activeSessionID = activeID
            } else {
                activeSessionID = sessions.first?.id
            }

        case "session_changed":
            if let sessionPayload = payload["session"] as? [String: Any],
               let session = AgentSessionSummary(
                payload: sessionPayload,
                activeSessionID: sessionPayload["session_id"] as? String ?? activeSessionID
               ) {
                activeSessionID = session.id
                upsertSession(session)
            }
            if let history = parseSessionHistory(from: (payload["session"] as? [String: Any])?["history"]) {
                hydrateSessionSurface(with: history)
            }

        case "status":
            if let message = payload["message"] as? String,
               !message.isEmpty,
               !awaitingPrompt,
               !isAwaitingApproval,
               let activeContinuation {
                activeContinuation.yield(.thinkingDelta(message))
            }

        case "thinking":
            if let text = payload["text"] as? String,
               let activeContinuation {
                awaitingPrompt = false
                activeContinuation.yield(.thinkingDelta(text))
            }

        case "text":
            if let text = payload["text"] as? String,
               let activeContinuation {
                awaitingPrompt = false
                activeContinuation.yield(.textDelta(text))
            }

        case "tool_started":
            let id = payload["id"] as? String ?? UUID().uuidString
            let name = payload["name"] as? String ?? "tool"
            let inputJSON = payload["input_json"] as? String ?? "{}"
            awaitingPrompt = false

            // Depth limiter: track delegate/subagent tool invocations
            if name.contains("delegate") || name.contains("subagent") {
                if !hermesDepthLimiter.push(agentId: id) {
                    sendHermesCommand([
                        "command": "interrupt",
                        "message": "Agent depth limit exceeded (\(hermesDepthLimiter.maxDepth)). Stopping to prevent runaway delegation.",
                    ])
                    activeContinuation?.yield(.error(AgentRuntimeError(
                        message: "Subagent depth limit (\(hermesDepthLimiter.maxDepth)) exceeded"
                    )))
                    return
                }
            }

            // Speculative PTY pre-warming: when Hermes starts a terminal tool,
            // pre-spawn a native PTY session so it's warm for the actual command.
            // This shaves 300ms+ off the first command in a session.
            if name.contains("terminal") || name.contains("command") || name.contains("shell") || name.contains("pty") {
                if speculativePtyId == nil {
                    let sessionId = activeSessionID ?? "hermes-\(UUID().uuidString.prefix(8))"
                    let cwd = (try? JSONSerialization.jsonObject(with: Data(inputJSON.utf8)) as? [String: Any])?["cwd"] as? String ?? NSHomeDirectory()
                    let spawnResult = ptySpawnSession(sessionId: sessionId, shell: "/bin/zsh", initialDir: cwd)
                    if let data = spawnResult.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let ptyId = parsed["pty_id"] as? String {
                        speculativePtyId = ptyId
                        Self.log.debug("Speculative PTY pre-warmed: \(ptyId)")
                    }
                }
            }

            // Shadow git checkpoint for file-mutating tools
            if name.contains("write") || name.contains("patch") || name.contains("edit") || name.contains("delete") {
                if let inputData = inputJSON.data(using: .utf8),
                   let inputDict = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any],
                   let filePath = inputDict["path"] as? String ?? inputDict["file_path"] as? String {
                    Task { await shadowCheckpoint.checkpoint(filePath: filePath, message: "\(name): \(filePath)") }
                }
            }

            activeContinuation?.yield(.toolStarted(id: id, name: name, inputJson: inputJSON))

        case "tool_completed":
            let id = payload["id"] as? String ?? UUID().uuidString
            let name = payload["name"] as? String ?? "tool"
            let result = payload["result"] as? String ?? ""
            let isError = payload["is_error"] as? Bool ?? false

            // Depth limiter: pop when delegate/subagent tool completes
            if name.contains("delegate") || name.contains("subagent") {
                hermesDepthLimiter.pop()
            }

            // Loop detection: record every tool completion and interrupt on loop
            if let loop = hermesLoopDetector.record(
                toolName: name,
                argumentsJson: payload["input_json"] as? String ?? "{}",
                outputJson: result
            ) {
                sendHermesCommand([
                    "command": "interrupt",
                    "message": "Loop detected: \(loop.message)",
                ])
                activeContinuation?.yield(.error(AgentRuntimeError(
                    message: "Tool loop detected: \(loop.message)"
                )))
                return
            }

            activeContinuation?.yield(.toolCompleted(id: id, result: result, isError: isError))

        case "permission_required":
            let request = AgentPermissionRequest(
                id: payload["permission_id"] as? String ?? UUID().uuidString,
                toolName: payload["tool_name"] as? String ?? "terminal",
                inputJson: payload["input_json"] as? String ?? "{}",
                riskLevel: AgentRuntimeRiskLevel(rustValue: payload["risk_level"] as? String ?? "modification"),
                description: payload["description"] as? String ?? "Hermes requires approval."
            )
            activeContinuation?.yield(.permissionRequired(request))

        case "complete":
            let stopReason = payload["stop_reason"] as? String ?? "completed"
            let inputTokens = payload["input_tokens"] as? Int ?? 0
            let outputTokens = payload["output_tokens"] as? Int ?? 0
            let history = parseSessionHistory(from: payload["history"])

            // Track cost in micro-dollars
            let model = payload["model"] as? String ?? lastProviderName
            costTracker.recordTurn(model: model, inputTokens: inputTokens, outputTokens: outputTokens)

            // Track token budget and auto-compact if context is getting large
            contextBudget.recordTurn(inputTokens: inputTokens, outputTokens: outputTokens)
            if contextBudget.shouldCompact {
                // Tell Hermes to compress its context window
                sendHermesCommand([
                    "command": "admin",
                    "domain": "config",
                    "action": "compact",
                ], handlesRuntimeFailure: false)
            }

            activeContinuation?.yield(
                .complete(
                    stopReason: stopReason,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    history: history
                )
            )
            activeContinuation?.finish()
            activeContinuation = nil
            requestSessionList()

        case "error":
            let message = payload["message"] as? String ?? "Hermes bridge error"
            let recoverable = payload["recoverable"] as? Bool ?? false

            if recoverable, let activeContinuation {
                // Recoverable error (e.g. tool failure, API retry) — yield the
                // error as a content block but keep the session alive so the
                // model can attempt recovery on its next turn.
                activeContinuation.yield(.textDelta("\n[Error: \(message)]\n"))
            } else if let activeContinuation {
                // Fatal bridge error — tear down the session.
                activeContinuation.yield(.error(AgentRuntimeError(message: message)))
                activeContinuation.finish()
                self.activeContinuation = nil
            } else {
                handleError(message)
            }

        case "admin_result":
            if let domain = payload["domain"] as? String,
               domain == "sessions",
               let action = payload["action"] as? String,
               action == "search" {
                let activeID = activeSessionID
                let rawSessions = (payload["results"] as? [[String: Any]]) ?? []
                sessionSearchResults = rawSessions
                    .compactMap { AgentSessionSummary(payload: $0, activeSessionID: activeID) }
                    .sorted(by: Self.sessionSort)
            }
            adminViewModel?.handleAdminResult(payload)

        default:
            break
        }
    }

    private func handleInferenceRequest(_ payload: [String: Any]) {
        let requestId = payload["request_id"] as? String ?? ""
        let prompt = payload["prompt"] as? String ?? ""
        let systemPrompt = payload["system_prompt"] as? String
        let maxTokens = payload["max_tokens"] as? Int ?? 2048

        guard !requestId.isEmpty, !prompt.isEmpty else {
            sendHermesCommand([
                "command": "inference_response",
                "request_id": requestId,
                "result": ["text": "", "error": "missing request_id or prompt"],
            ])
            return
        }

        Task { @MainActor [weak self] in
            guard let self, let client = self.localLLMClient else {
                self?.sendHermesCommand([
                    "command": "inference_response",
                    "request_id": requestId,
                    "result": ["text": "", "error": "local LLM client not available"],
                ])
                return
            }

            do {
                let text = try await client.generate(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens
                )
                self.sendHermesCommand([
                    "command": "inference_response",
                    "request_id": requestId,
                    "result": [
                        "text": text,
                        "prompt_tokens": max(1, prompt.utf8.count / 4),
                        "completion_tokens": max(1, text.utf8.count / 4),
                    ],
                ])
            } catch {
                self.sendHermesCommand([
                    "command": "inference_response",
                    "request_id": requestId,
                    "result": ["text": "", "error": error.localizedDescription],
                ])
            }
        }
    }

    private func requestSessionList() {
        sendHermesCommand(["command": "list_sessions"], handlesRuntimeFailure: false)
    }

    private func switchSession(command: String, extraPayload: [String: Any] = [:]) {
        if isRunning {
            stop()
        }
        resetSessionSurfaceState()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.connectIfNeeded()
                var payload = self.makeSessionPayload(command: command)
                for (key, value) in extraPayload {
                    payload[key] = value
                }
                self.sendHermesCommand(payload)
            } catch {
                self.handleError(error.localizedDescription)
            }
        }
    }

    private func prepareTurnStateForNewPrompt(prompt: String) {
        phase = .thinking(tokenCount: 0)
        thinkingText = ""
        responseText = ""
        lastSubmittedPrompt = prompt
        if !prompt.isEmpty {
            contentBlocks.append(.userPrompt(prompt))
        }
        errorMessage = nil
        tokenUsage = (0, 0)
        latestStopReason = ""
        awaitingPrompt = true
        isAwaitingApproval = false
    }

    private func resetSessionSurfaceState() {
        phase = .idle
        thinkingText = ""
        responseText = ""
        contentBlocks = []
        errorMessage = nil
        tokenUsage = (0, 0)
        turnCount = 0
        latestStopReason = ""
        awaitingPrompt = false
        isAwaitingApproval = false
        lastSubmittedPrompt = ""
        hermesLoopDetector.reset()
        hermesDepthLimiter.reset()
        costTracker.reset()
    }

    private func upsertSession(_ session: AgentSessionSummary) {
        if let existingIndex = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[existingIndex] = session
        } else {
            sessions.append(session)
        }

        sessions.sort(by: Self.sessionSort)
    }

    private func hydrateSessionSurface(with history: [AgentSessionMessage]) {
        thinkingText = ""
        responseText = ""
        contentBlocks = RenderedBlock.sessionHistory(history)
        errorMessage = nil
        turnCount = history.reduce(into: 0) { count, message in
            if message.role == "user" {
                count += 1
            }
        }
        awaitingPrompt = false
        isAwaitingApproval = false
    }

    private func parseSessionHistory(from value: Any?) -> [AgentSessionMessage]? {
        guard let rawMessages = value as? [Any] else { return nil }

        // Repair transcript before parsing: fix orphaned tool_use/tool_result
        // pairs and duplicate IDs that would corrupt the agent loop.
        let rawDicts = rawMessages.compactMap { $0 as? [String: Any] }
        let repaired = TranscriptRepair.repair(messages: rawDicts)

        return repaired.compactMap { payload in
            AgentSessionMessage(payload: payload)
        }
    }

    private static func sessionSort(_ lhs: AgentSessionSummary, _ rhs: AgentSessionSummary) -> Bool {
        if lhs.isActive != rhs.isActive {
            return lhs.isActive && !rhs.isActive
        }
        switch (lhs.lastActive, rhs.lastActive) {
        case let (left?, right?) where left != right:
            return left > right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            break
        }
        if lhs.historyCount != rhs.historyCount {
            return lhs.historyCount > rhs.historyCount
        }
        return lhs.id < rhs.id
    }

    private func sendHermesCommand(
        _ payload: [String: Any],
        handlesRuntimeFailure: Bool = true
    ) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: data, encoding: .utf8) else {
            if handlesRuntimeFailure {
                handleError("Failed to encode Hermes bridge command.")
            }
            return
        }

        do {
            try hermesManager.writeLine(line)
        } catch {
            if handlesRuntimeFailure {
                handleError(error.localizedDescription)
            }
        }
    }
}

// MARK: - Vault Search (nonisolated for MCP tool handlers)

/// Simple file-system search: matches query terms against note filenames and content.
/// Free function so @Sendable MCP tool closures can call it without actor isolation.
nonisolated private func searchVaultFiles(query: String, vaultPath: String, limit: Int) -> [AnyCodableValue] {
    let terms = query.lowercased().split(separator: " ").map(String.init)
    guard !terms.isEmpty else { return [] }

    guard let enumerator = FileManager.default.enumerator(
        at: URL(fileURLWithPath: vaultPath),
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }

    struct Match {
        let path: String
        let excerpt: String
        let score: Int
    }

    var matches: [Match] = []
    while let url = enumerator.nextObject() as? URL {
        guard url.pathExtension == "md" else { continue }
        let relative = url.path.replacingOccurrences(of: vaultPath + "/", with: "")
        let filename = url.lastPathComponent.lowercased()

        var score = 0
        for term in terms {
            if filename.contains(term) { score += 3 }
        }

        // Quick content scan (first 4KB only for speed)
        if let handle = try? FileHandle(forReadingFrom: url) {
            let data = handle.readData(ofLength: 4096)
            handle.closeFile()
            if let snippet = String(data: data, encoding: .utf8)?.lowercased() {
                for term in terms {
                    if snippet.contains(term) { score += 1 }
                }
            }
        }

        if score > 0 {
            let excerpt = (try? String(contentsOf: url, encoding: .utf8))?
                .prefix(200)
                .replacingOccurrences(of: "\n", with: " ") ?? ""
            matches.append(Match(path: relative, excerpt: String(excerpt), score: score))
        }
    }

    return matches
        .sorted { $0.score > $1.score }
        .prefix(limit)
        .map { match in
            .dictionary([
                "path": .string(match.path),
                "excerpt": .string(match.excerpt),
                "score": .int(match.score),
            ])
        }
}

enum HermesQuickAction: String, CaseIterable, Identifiable, Sendable {
    case help
    case model
    case tools
    case context
    case compact
    case reset
    case version

    var id: String { rawValue }

    var title: String {
        switch self {
        case .help: "Help"
        case .model: "Model"
        case .tools: "Tools"
        case .context: "Context"
        case .compact: "Compact"
        case .reset: "Reset"
        case .version: "Version"
        }
    }

    var detail: String {
        switch self {
        case .help: "Show the Hermes command list"
        case .model: "Show the current Hermes model"
        case .tools: "List enabled Hermes tools"
        case .context: "Inspect the current session context"
        case .compact: "Compress session history"
        case .reset: "Clear the current session history"
        case .version: "Show the Hermes runtime version"
        }
    }

    var systemImage: String {
        switch self {
        case .help: "questionmark.circle"
        case .model: "cpu"
        case .tools: "wrench.and.screwdriver"
        case .context: "text.alignleft"
        case .compact: "arrow.down.left.and.arrow.up.right"
        case .reset: "arrow.counterclockwise"
        case .version: "number"
        }
    }

    var slashCommand: String {
        "/\(rawValue)"
    }

    var isDestructive: Bool {
        self == .reset
    }
}

enum HermesSessionRefreshPolicy {
    static func shouldHydrateSurface(afterSubmittedPrompt prompt: String) -> Bool {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return true }

        let slashCommand = trimmed
            .split(whereSeparator: \.isWhitespace)
            .first?
            .lowercased() ?? ""

        switch slashCommand {
        case "/reset", "/compact":
            return true
        default:
            return false
        }
    }
}

struct AgentSessionSummary: Identifiable, Equatable, Sendable {
    let id: String
    let cwd: String
    let model: String
    let historyCount: Int
    let isActive: Bool
    let preview: String
    let lastActive: Date?
    private let explicitTitle: String?

    init?(payload: [String: Any], activeSessionID: String?) {
        guard let sessionID = payload["session_id"] as? String,
              !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.id = sessionID
        self.cwd = payload["cwd"] as? String ?? "."
        self.model = payload["model"] as? String ?? ""
        self.historyCount = payload["history_len"] as? Int ?? 0
        let rawPreview = payload["preview"] as? String ?? ""
        self.preview = rawPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawTitle = (payload["title"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !rawTitle.isEmpty {
            self.explicitTitle = rawTitle
        } else {
            self.explicitTitle = nil
        }
        if let seconds = payload["last_active"] as? Double {
            self.lastActive = Date(timeIntervalSince1970: seconds)
        } else if let seconds = payload["last_active"] as? Int {
            self.lastActive = Date(timeIntervalSince1970: TimeInterval(seconds))
        } else if let seconds = payload["last_active"] as? NSNumber {
            self.lastActive = Date(timeIntervalSince1970: seconds.doubleValue)
        } else {
            self.lastActive = nil
        }

        if let explicitActive = payload["is_active"] as? Bool {
            self.isActive = explicitActive
        } else {
            self.isActive = sessionID == activeSessionID
        }
    }

    var shortID: String {
        String(id.prefix(8))
    }

    var title: String {
        if let explicitTitle {
            return explicitTitle
        }
        let lastComponent = URL(fileURLWithPath: cwd).lastPathComponent
        if !lastComponent.isEmpty {
            return lastComponent
        }
        if !preview.isEmpty {
            return String(preview.prefix(40))
        }
        return shortID
    }

    var detail: String {
        let modelText = model.isEmpty ? "Hermes session" : model
        return "\(modelText) • \(historyCount) messages"
    }
}

enum AgentPhase: Equatable {
    case idle
    case thinking(tokenCount: Int)
    case searching(query: String)
    case executing(toolName: String)
    case reasoning(tokenCount: Int)
    case responding(tokenCount: Int)
    case awaitingApproval(AgentPermissionRequest)
    case complete
    case failed(String)
}

enum AgentStreamEvent: Sendable {
    case thinkingDelta(String)
    case textDelta(String)
    case toolInputStreaming(index: UInt32, partialJson: String)
    case toolStarted(id: String, name: String, inputJson: String)
    case toolCompleted(id: String, result: String, isError: Bool)
    case subagentSpawned(id: String, role: String)
    case permissionRequired(AgentPermissionRequest)
    case contextCompacting(tokens: Int)
    case contextCompacted(messageCount: Int)
    case turnStarted(turn: Int, messageCount: Int)
    case complete(stopReason: String, inputTokens: Int, outputTokens: Int, history: [AgentSessionMessage]?)
    case error(AgentRuntimeError)
}

struct AgentRuntimeError: Error, Sendable, Equatable {
    let message: String
}

struct AgentPermissionRequest: Sendable, Identifiable, Equatable {
    let id: String
    let toolName: String
    let inputJson: String
    let riskLevel: AgentRuntimeRiskLevel
    let description: String
}

enum AgentRuntimeRiskLevel: Sendable, Equatable {
    case readOnly
    case modification
    case destructive

    init(rustValue: String) {
        switch rustValue {
        case "read_only":
            self = .readOnly
        case "destructive":
            self = .destructive
        default:
            self = .modification
        }
    }
}

enum RenderedBlock: Identifiable, Equatable, Sendable {
    case userPrompt(String)
    case thinking(text: String, tokenCount: Int)
    case text(String)
    case toolExecution(name: String, input: String, result: String?, isError: Bool)
    case status(String)

    var id: String {
        switch self {
        case .userPrompt(let text):
            return "user-\(text.hashValue)"
        case .thinking(let text, let tokenCount):
            return "thinking-\(tokenCount)-\(text.hashValue)"
        case .text(let text):
            return "text-\(text.hashValue)"
        case .toolExecution(let name, let input, _, _):
            return "tool-\(name)-\(input.hashValue)"
        case .status(let text):
            return "status-\(text.hashValue)"
        }
    }

    static func sessionHistory(_ messages: [AgentSessionMessage]) -> [RenderedBlock] {
        var blocks: [RenderedBlock] = []
        blocks.reserveCapacity(messages.count)

        for message in messages {
            switch message.role {
            case "user":
                if let content = message.trimmedContent {
                    blocks.append(.userPrompt(content))
                }
            case "assistant":
                if let reasoning = message.trimmedReasoning {
                    blocks.append(.thinking(text: reasoning, tokenCount: max(1, reasoning.count / 4)))
                }
                if let content = message.trimmedContent {
                    blocks.append(.text(content))
                }
            case "tool":
                let toolName = message.trimmedToolName ?? "tool"
                let result = message.trimmedContent
                blocks.append(
                    .toolExecution(
                        name: toolName,
                        input: "",
                        result: result,
                        isError: result.map(Self.looksLikeError) ?? false
                    )
                )
            case "system":
                if let content = message.trimmedContent {
                    blocks.append(.status("System: \(content)"))
                }
            default:
                if let content = message.trimmedContent {
                    blocks.append(.status("\(message.role.capitalized): \(content)"))
                }
            }
        }

        return blocks
    }

    private static func looksLikeError(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.hasPrefix("error") || lowered.contains("traceback") || lowered.contains("failed")
    }
}

struct AgentSessionMessage: Equatable, Sendable {
    let role: String
    let content: String?
    let toolName: String?
    let toolCallID: String?
    let reasoning: String?
    let finishReason: String?

    init?(payload: [String: Any]) {
        guard let rawRole = payload["role"] as? String else {
            return nil
        }
        let trimmedRole = rawRole.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRole.isEmpty else {
            return nil
        }
        self.role = trimmedRole
        self.content = payload["content"] as? String
        self.toolName = payload["tool_name"] as? String
        self.toolCallID = payload["tool_call_id"] as? String
        self.reasoning = payload["reasoning"] as? String
        self.finishReason = payload["finish_reason"] as? String
    }

    var trimmedContent: String? {
        guard let content else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmedToolName: String? {
        guard let toolName else { return nil }
        let trimmed = toolName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmedReasoning: String? {
        guard let reasoning else { return nil }
        let trimmed = reasoning.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum AgentRuntimeDefaults {
    static var vaultPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".epistemos", isDirectory: true)
            .appendingPathComponent("vault", isDirectory: true)
            .path
    }

    static let enableBash = false
    static let enableWebSearch = true
}
