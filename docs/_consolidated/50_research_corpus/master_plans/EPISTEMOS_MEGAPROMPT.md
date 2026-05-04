# EPISTEMOS — DEFINITIVE IMPLEMENTATION PROMPT
## For Claude Code / Codex / Any Agentic Coding Agent
### Date: March 28, 2026 | Developer: Jordan | Machine: M2 Pro MacBook 16GB

---

## PREAMBLE — READ BEFORE TOUCHING ANY CODE

You are implementing a complete systems upgrade to Epistemos, a native macOS Cognitive OS built in Rust + Swift + Metal. The codebase is 137K lines Swift, 94K lines Rust, 370 Swift files, 99 Rust files, 115 test files. The existing architecture uses UniFFI for Rust↔Swift FFI, GRDB for persistence, MLX for local inference, and a multi-agent Omega system for agentic workflows.

This prompt synthesizes 20+ research papers and architectural blueprints into exact executable instructions. There are **SEVEN MAJOR WORKSTREAMS** that must be implemented, each with explicit file-level instructions. Read this entire document before writing a single line of code.

**YOUR OPERATING PRINCIPLES:**
1. Never ask for approval — just implement.
2. After each phase, run the verification greps listed.
3. If something doesn't exist where expected, HALT and report — do not guess.
4. Preserve all existing passing tests (2,679-test suite). Zero regressions.
5. Every new component gets tests. No exceptions.
6. Every `unsafe` block gets a `// SAFETY:` comment.
7. No `try!`, no force-unwraps, no `print()` in production paths.

---

## PRE-FLIGHT: VERIFY CURRENT STATE

Run every one of these greps FIRST. If any result differs from EXPECTED, halt and report the discrepancy before proceeding.

```bash
# 1. Existing model enum — should be 6 MLX-only cases
grep -r "LocalTextModelID" --include="*.swift" | head -20
# EXPECTED: nonisolated enum with cases qwen35* (6 cases), MLX only

# 2. Existing inference — MLX only, no GGUF
grep -r "ModelDownloadManager\|MLXInferenceService" --include="*.swift" | head -10
# EXPECTED: EXISTS — MLX pipeline only

# 3. Existing thinking toggle — model-agnostic
grep -r "fastThinking\|thinkMode" --include="*.swift" | head -10
# EXPECTED: EXISTS — toggle present but not model-aware

# 4. Omega agent system — all trustworthy
grep -r "OrchestratorState\|ResearchOrchestrator\|MCPBridge" --include="*.swift" | head -10
# EXPECTED: ALL EXIST — per 2,679-test passing suite

# 5. GGUF backend — should NOT exist yet
grep -r "GGUF\|llama\.cpp\|LlamaInference\|GGUFInferenceService" --include="*.swift" | head -5
# EXPECTED: ZERO results

# 6. Cloud API integration — should NOT exist yet
grep -r "AnthropicAPI\|OpenAIAPI\|CloudInferenceService\|ComputerUse" --include="*.swift" | head -5
# EXPECTED: ZERO results

# 7. TurboQuant — should NOT exist yet
grep -r "KVCacheConfig\|turboQuant\|kvbits" --include="*.swift" | head -5
# EXPECTED: ZERO results

# 8. Safari agent failures — audit current state
grep -r "SafariAgent\|safari.*agent\|kAXPressAction" --include="*.swift" | head -10
# EXPECTED: EXISTS but broken — stops after pasting text, can't complete tasks

# 9. Tool calling — check if local models actually invoke tools
grep -r "toolCall\|tool_call\|function_call\|tool_use" --include="*.swift" | head -15
# EXPECTED: Schemas exist in OmegaToolRegistry but local models don't reliably call them

# 10. Release blockers
cat Epistemos/Epistemos.entitlements
# EXPECTED: Empty <dict/>  — THIS IS A RELEASE BLOCKER
ls Epistemos/PrivacyInfo.xcprivacy 2>/dev/null || echo "MISSING — RELEASE BLOCKER"

# 11. Deployment target conflict
grep -r "MACOSX_DEPLOYMENT_TARGET" project.yml
# EXPECTED: Conflicting 15.0 and 26.0 — must resolve to 15.0 for shipping
```

---

## WORKSTREAM 1: DUAL-BACKEND INFERENCE (MLX + GGUF)

**WHY:** The 11 new models require GGUF/llama.cpp. The existing MLXInferenceService only handles MLX models. You must build a parallel GGUF backend and a unified routing layer.

### Phase 1.0 — Foundation Types (no dependencies)

**CREATE** `Epistemos/Services/Inference/ModelBackend.swift`:
```swift
/// Identifies which inference runtime handles a given model.
enum ModelBackend: String, Codable, Sendable {
    case mlx   // mlx-community/* models via existing MLXInferenceService
    case gguf  // *.gguf files via new GGUFInferenceService
    case cloud // Cloud API models (Anthropic, OpenAI) — see Workstream 3

    var supportsStreaming: Bool { true }
    var supportsGrammar: Bool { self == .gguf } // llama.cpp gbnf
    var supportsNativeToolCalling: Bool { self == .cloud } // ONLY cloud models reliably call tools
}
```

**CREATE** `Epistemos/Services/Inference/KVCacheConfig.swift`:
```swift
/// KV cache quantization configuration.
/// Implements TurboQuant (Google Research, ICLR 2026) approach for Apple Silicon.
/// On M2 Pro: +32% prompt throughput, +26% decode throughput, -44% KV cache size.
/// NOTE: Full PolarQuant requires mlx-lm >= 0.21 or flovflo fork.
/// Until merged, this uses mlx-lm's built-in QuantizedKVCache (--kv-bits 4).
struct KVCacheConfig: Codable, Sendable {
    var quantizationBits: Int = 4     // 3, 4, 8, or 16 (no compression)
    var groupSize: Int = 64           // --kv-group-size for affine quant
    var quantizedKVStart: Int = 5000  // tokens before activating compression
    var maxCachedTokens: Int = 50_000

    static let turboQuant = KVCacheConfig(quantizationBits: 4, groupSize: 64, quantizedKVStart: 0, maxCachedTokens: 50_000)
    static let standard   = KVCacheConfig(quantizationBits: 16, groupSize: 64, quantizedKVStart: 5000, maxCachedTokens: 8_192)
    static let balanced   = KVCacheConfig(quantizationBits: 8, groupSize: 64, quantizedKVStart: 5000, maxCachedTokens: 32_000)
}
```

**CREATE** `Epistemos/Models/ModelQuantization.swift`:
```swift
enum ModelQuantization: String, CaseIterable, Codable, Sendable {
    case q4 = "Q4"
    case q8 = "Q8"
    var displayLabel: String {
        switch self {
        case .q4: return "Q4 · Fast"
        case .q8: return "Q8 · Quality"
        }
    }
}
```

### Phase 1.1 — Complete LocalTextModelID Replacement

**REPLACE THE ENTIRE CONTENTS** of `LocalTextModelID.swift` (or wherever the enum lives — verify with grep) with the full 17-model enum from the TurboQuant Implementation Guide. This includes:

- 6 existing MLX Qwen models (preserve raw values exactly)
- 11 new models: Qwen 3.5 27B Opus-Distilled, 28B-A3B REAP, 40B Opus Uncensored, Devstral Small 2, Mistral Small 3.1, Gemma 3 27B QAT, Phi-4 14B, SmolLM3 3B, Llama 4 Scout 109B MoE, MiniMax M2.5, Chroma Context-1

Every model must have these computed properties:
- `displayName: String`
- `familyName: String`
- `backend: ModelBackend` (.mlx for existing 6 + SmolLM3 + Llama4Scout, .gguf for all others)
- `ramRequirementQ4GB: Int` (exact values from the implementation guide)
- `ramRequirementQ8GB: Int?` (nil for models without Q8 available)
- `supportsDualThinkMode: Bool` (true ONLY for Qwen3.5 family + SmolLM3 — NOT for Gemma, Phi, Mistral, Devstral)
- `isMoE: Bool`
- `isCodeSpecialist: Bool` (Devstral, MiniMax, Chroma)
- `isUnrestrictedThinking: Bool` (only 40B Opus Uncensored)
- `isComingSoon: Bool` (Llama4Scout, MiniMax, Chroma)
- `contextWindowK: Int`
- `ggufFileQ4: String?` and `ggufFileQ8: String?`
- `tier: ModelTier` (.ultraLight ≤8GB, .efficient 9-16GB, .standard 17-24GB, .professional 25-48GB, .maximum 48GB+)
- `requiresExternalServer(systemRAMGB:) -> Bool`
- `canActAsAgent: Bool` — **NEW**: returns false for ALL local models. Only cloud models get true agent capability.

### Phase 1.2 — GGUF Inference Service

**ADD SPM DEPENDENCY**: `tattn/LocalLLMClient` (branch: main). This wraps both llama.cpp and MLX behind a unified Swift Concurrency interface with AsyncSequence streaming.

**CREATE** `Epistemos/Services/Inference/GGUFInferenceService.swift`:
```swift
import LocalLLMClientLlama

actor GGUFInferenceService {
    private var client: LlamaClient?
    private var loadedModelPath: String?

    func loadModel(at path: URL, contextLength: Int = 8_192) async throws {
        let config = LlamaClient.Config(
            contextLength: contextLength,
            nGPULayers: 99  // Full Metal GPU offload on Apple Silicon
        )
        client = try await LlamaClient(modelPath: path, config: config)
        loadedModelPath = path.path
    }

    func unloadModel() async {
        client = nil
        loadedModelPath = nil
    }

    /// Mirrors MLXInferenceService.generateStream API exactly.
    /// CRITICAL: thinkMode injects /think prefix for supported models ONLY.
    func generateStream(
        prompt: String,
        maxTokens: Int = 2048,
        temperature: Float = 0.7,
        thinkMode: Bool = false,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        guard let client else { throw InferenceError.modelNotLoaded }
        let fullPrompt = thinkMode ? "/think\n\(prompt)" : prompt
        var fullOutput = ""
        for try await token in client.generateStream(
            prompt: fullPrompt,
            maxTokens: maxTokens,
            temperature: temperature
        ) {
            onToken(token)
            fullOutput += token
        }
        return fullOutput
    }

    var isLoaded: Bool { loadedModelPath != nil }
}
```

### Phase 1.3 — Backend Routing in LLMService

**MODIFY** the main inference dispatch point (LLMService.swift, InferenceState.swift, or wherever `generateStream` is called). Add a `switch model.backend` that routes:
- `.mlx` → existing `MLXInferenceService` (add `kvCacheConfig` parameter for TurboQuant)
- `.gguf` → new `GGUFInferenceService`
- `.cloud` → new `CloudInferenceService` (built in Workstream 3)

### Phase 1.4 — ModelDownloadManager GGUF Extension

**MODIFY** `ModelDownloadManager.swift`:
- Add `ggufModelPath(for:quantization:) -> URL` returning `~/Library/Application Support/Epistemos/Models/GGUF/{familyName}/{filename}`
- Add `downloadGGUF(model:quantization:onProgress:) async throws -> URL` using `URLSessionDownloadTask` for resumable downloads from HuggingFace `/resolve/main/` endpoint
- HuggingFace auth: Accept optional Bearer token for gated models (Gemma). Store in Keychain.

### Phase 1.5 — TurboQuant Integration

**MODIFY** `MLXInferenceService.swift`:
- Add `kvCacheConfig: KVCacheConfig` parameter to `generateStream`
- Pass to MLX Python inference: `--kv-bits \(kvCacheConfig.quantizationBits) --kv-group-size \(kvCacheConfig.groupSize)`
- If using `mlx-swift-lm` native Swift API (which does NOT expose kv-bits yet), invoke `mlx_lm.generate` via `Process()` subprocess as a bridge until mlx-swift-lm catches up

**ADD** TurboQuant toggle to Settings UI:
```swift
Toggle(isOn: $turboQuantEnabled) {
    Label {
        VStack(alignment: .leading, spacing: 2) {
            Text("TurboQuant KV Cache")
            Text("44% smaller cache · ~30% faster · ICLR 2026")
                .font(.caption).foregroundStyle(.secondary)
        }
    } icon: { Image(systemName: "bolt.fill").foregroundStyle(.yellow) }
}
```

### Phase 1.6 — Model Selector UI

**CREATE** `Epistemos/Views/Settings/LocalModelSelectorView.swift`:
- 5-tier sections (Ultra Light → Maximum) with SF Symbol icons and tier colors
- RAM banner reading `ProcessInfo.processInfo.physicalMemory` dynamically
- Q4/Q8 quantization picker per model row
- Badge system: "MoE" (purple), "Code" (blue), "Think" (orange), "Uncensored" (red), "Coming Soon" (gray), "Needs oMLX" (orange for models exceeding system RAM)
- TurboQuant indicator in RAM banner when enabled
- **CRITICAL**: Models where `canActAsAgent == false` show NO agent badge. Only cloud models show agent capability.

---

## WORKSTREAM 2: AGENT SYSTEM OVERHAUL

**WHY:** The current agent system is broken. The Safari agent stops after pasting text. Local models can't reliably call tools because 4B-14B models don't have the spatial/syntactic precision for structured tool invocation. The agent modes are "fake" — they say "Safari Agent" but the models aren't actually executing multi-step plans.

### Phase 2.0 — Honest Capability Audit

**CRITICAL ARCHITECTURAL DECISION**: Local models (≤27B on consumer hardware) CANNOT reliably act as autonomous agents. They hallucinate tool schemas, lose track of multi-step plans, and fail at spatial reasoning. The current system pretends they can — this is the root cause of the Safari agent failures.

The fix is a **Dual-Brain Architecture**:
- **Local models** = Fast response, thinking mode, text generation, embeddings, simple routing
- **Cloud models** = True agentic workflows, tool calling, computer use, research mode

This means `EpistemosOperatingMode` gets redefined:

```swift
enum EpistemosOperatingMode: String, CaseIterable, Codable {
    case fast      // Local model, no reasoning overhead, instant answers
    case thinking  // Local model WITH /think tokens, chain-of-thought (4B+ only)
    case research  // Local model thinking + SOAR evidence pipeline (4B+ only)
    case agent     // CLOUD MODEL ONLY — true multi-step agentic execution
    case liveAgent // CLOUD MODEL ONLY — continuous screen observation + computer use

    var requiresCloudModel: Bool {
        switch self {
        case .fast, .thinking, .research: return false
        case .agent, .liveAgent: return true
        }
    }

    var minimumModelSizeB: Double? {
        switch self {
        case .fast: return nil // Any size
        case .thinking, .research: return 4.0 // 4B minimum
        case .agent, .liveAgent: return nil // Cloud handles this
        }
    }
}
```

### Phase 2.1 — Fix the Broken Safari Agent

**AUDIT** `SafariAgent.swift` and trace the exact failure:
1. Grep for `kAXPressAction`, `CGEvent`, `AXUIElement` calls
2. The agent likely fails because: (a) it pastes text but doesn't wait for the page to load, (b) it tries to read DOM elements via AX tree which is sparse in Safari, (c) the local model hallucinates the next tool call after the paste
3. **FIX**: Replace the naive ReAct loop with a Plan-and-Execute DAG model:
   - The planning phase generates a complete JSON execution plan BEFORE any action
   - Use grammar-constrained decoding (llama.cpp's GBNF or mlx-swift-structured) to force valid JSON from local models
   - The execution phase runs each step independently with fresh context
   - If AX tree is sparse (< threshold actionable elements), fall back to Screen2AX visual grounding

### Phase 2.2 — DAG Execution Engine

**CREATE** `Epistemos/Services/Agent/DAGExecutor.swift`:

Replace the current linear agent loop with a Directed Acyclic Graph executor built on Swift Concurrency:

```swift
actor DAGExecutor {
    /// Execute a pre-planned task graph.
    /// Each node runs independently with only its required context.
    /// Parallel nodes execute via TaskGroup.
    func execute(plan: ExecutionPlan) async throws -> ExecutionResult {
        var context: [String: Any] = [:]

        for phase in plan.phases {
            // Parallel execution of independent nodes
            try await withThrowingTaskGroup(of: NodeResult.self) { group in
                for node in phase.parallelNodes {
                    group.addTask {
                        try await self.executeNode(node, context: context)
                    }
                }
                for try await result in group {
                    context[result.nodeId] = result.output
                }
            }
        }

        return ExecutionResult(context: context)
    }

    /// Execute a single node with FRESH context — prevents contamination.
    /// If the node fails, trigger re-planning rather than blind retry.
    private func executeNode(_ node: ExecutionNode, context: [String: Any]) async throws -> NodeResult {
        // ... implementation with error recovery and re-planning
    }
}
```

### Phase 2.3 — Screen2AX Visual Grounding

**CREATE** `Epistemos/Services/Agent/Screen2AX.swift`:

When the AX tree is sparse (Electron apps, web content), fuse AX data with visual parsing:

```swift
struct Screen2AXService {
    /// Capture screen + AX tree simultaneously.
    /// If AX tree has < threshold actionable elements, invoke visual parser.
    /// Returns a unified element list with precise bounding boxes.
    func captureHybridTree(for window: CGWindowID) async throws -> [UIElement] {
        let axTree = try await AXTreeWalker.walk(window: window)

        if axTree.actionableElements.count < 5 {
            // AX tree is sparse — use ScreenCaptureKit + visual parsing
            let screenshot = try await ScreenCapture.capture(window: window)
            let visualElements = try await OmniParserService.parse(screenshot)
            return merge(axTree: axTree, visualElements: visualElements)
        }

        return axTree.actionableElements
    }
}
```

**NOTE**: OmniParser V2 runs locally on Metal. Use the YOLOv8 bounding box model + Florence-2 captioner. On M2 Pro, expect 90-300ms per frame. This is for fallback only — AX tree is always preferred.

### Phase 2.4 — Grammar-Constrained Tool Calling for Local Models

Local models can only call tools if you FORCE valid JSON output:

**MODIFY** the inference path for local models in agent mode:
1. When the model outputs `<tool_call>`, switch the logit sampler to grammar-constrained mode
2. Use llama.cpp's GBNF grammar or mlx-swift-structured to enforce the tool's JSON schema
3. The model outputs free text in `<think>` blocks but MUST output valid JSON after `<tool_call>`

```swift
// Pseudo-code for the grammar switch
func processTokenStream(model: LocalTextModelID) {
    var inToolCall = false
    for token in stream {
        if token.contains("<tool_call>") {
            inToolCall = true
            activateGrammarConstraint(schema: currentToolSchema)
        }
        if token.contains("</tool_call>") {
            inToolCall = false
            deactivateGrammarConstraint()
        }
    }
}
```

---

## WORKSTREAM 3: CLOUD API INTEGRATION — TRUE AGENTIC POWER

**WHY:** Local models are pure and private but they CANNOT do real agent work. Cloud models (Claude Opus, GPT-4.5, Sonnet) have native tool calling, computer use, and agentic capabilities built into their APIs. The app is marketed as "all local unless you want to extend to cloud — basically a bonus."

### Phase 3.0 — Cloud Provider Protocol

**CREATE** `Epistemos/Services/Cloud/CloudProvider.swift`:

```swift
/// Unified provider protocol — same interface for Anthropic, OpenAI, and local.
/// Uses AsyncThrowingStream<StreamChunk, Error> as the universal streaming type.
protocol CloudProvider: Sendable {
    var capabilities: ProviderCapabilities { get }
    func generateStream(
        messages: [ChatMessage],
        systemPrompt: String?,
        tools: [ToolDefinition]?,
        maxTokens: Int,
        temperature: Float
    ) -> AsyncThrowingStream<StreamChunk, Error>
}

struct ProviderCapabilities: Sendable {
    let supportsToolCalling: Bool
    let supportsComputerUse: Bool
    let supportsThinking: Bool      // Extended thinking (Claude Opus/Sonnet)
    let supportsMCP: Bool           // Can connect to MCP servers
    let supportsVision: Bool
    let supportsStreaming: Bool
    let maxContextTokens: Int
    let canDispatchAgents: Bool     // TRUE agentic autonomy
}
```

### Phase 3.1 — Anthropic Provider (Claude API)

**CREATE** `Epistemos/Services/Cloud/AnthropicProvider.swift`:

Wire to the Anthropic Messages API (`/v1/messages`). This MUST use the real API, not a wrapper:

```swift
actor AnthropicProvider: CloudProvider {
    private let apiKey: String // From Keychain — user provides their own key
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    var capabilities: ProviderCapabilities {
        ProviderCapabilities(
            supportsToolCalling: true,
            supportsComputerUse: model.supportsComputerUse, // Opus + Sonnet only
            supportsThinking: model.supportsThinking,       // Opus + Sonnet only
            supportsMCP: true,                              // Native MCP connector
            supportsVision: true,
            supportsStreaming: true,
            maxContextTokens: 200_000,
            canDispatchAgents: model == .opus               // ONLY Opus can dispatch sub-agents
        )
    }
}
```

**Model capability mapping — be honest, no faking:**

| Claude Model | Tool Calling | Computer Use | Extended Thinking | Can Dispatch Agents | MCP |
|---|---|---|---|---|---|
| Opus 4.6 | ✅ Full | ✅ Full | ✅ Full | ✅ YES | ✅ |
| Sonnet 4.6 | ✅ Full | ✅ Full | ✅ Full | ❌ No sub-agents | ✅ |
| Haiku 4.5 | ✅ Basic | ❌ No | ❌ No | ❌ No | ✅ |

### Phase 3.2 — OpenAI Provider

**CREATE** `Epistemos/Services/Cloud/OpenAIProvider.swift`:

Wire to `/v1/chat/completions`. Support function calling via the `tools` parameter. Computer use is NOT available on OpenAI — only tool calling.

### Phase 3.3 — Subscription Proxy (Use Claude Max/Codex Instead of API Key)

**WHY:** Jordan wants to use their Claude Max subscription instead of paying per-token API fees.

**CREATE** `Epistemos/Services/Cloud/SubscriptionProxy.swift`:

This implements the CLIProxyAPI / OpenClaw pattern:
1. Launch a local HTTP server on `http://localhost:8317/v1` that translates OpenAI-compatible requests into Claude web frontend payloads
2. Authentication: User logs into Claude via an embedded WKWebView (NOT SFSafariViewController — that sandboxes cookies). Extract the `sessionKey` cookie from `WKHTTPCookieStore`.
3. Store the session token in macOS Keychain (encrypted, app-scoped)
4. The proxy translates standard Messages API JSON into the Claude web frontend's undocumented payload format
5. Stream SSE responses back as standard OpenAI-format `chat.completion.chunk` events

```swift
struct SubscriptionProxyConfig {
    enum Provider { case claude, openai }
    let provider: Provider
    let localPort: Int = 8317
    let sessionToken: String // Extracted from WKWebView cookie store

    /// Launch the local proxy server using Vapor or a lightweight HTTP server.
    /// Bind ONLY to localhost — never expose to network.
    func start() async throws {
        // NWListener bound to 127.0.0.1:\(localPort)
        // Accept standard /v1/chat/completions and /v1/messages
        // Translate to web frontend payload format
        // Forward with sessionToken as cookie
        // Stream SSE response back
    }
}
```

**IMPORTANT**: This is a BONUS feature. The app works fully local by default. The subscription proxy is an advanced option in Settings, clearly labeled:
- "Use Claude Max Subscription (instead of API key)"
- Warning: "This uses your web session. May be against ToS. Use at your own risk."

### Phase 3.4 — Computer Use: Continuous Screen Observation

**WHY:** Jordan wants the AI to watch the screen LIVE — not just take screenshots on demand. Like Antigravity, Claude Code app, where the AI continuously observes, moves the cursor, types, navigates.

**CREATE** `Epistemos/Services/Agent/ComputerUseService.swift`:

This is a CLOUD-ONLY feature using Anthropic's Computer Use API:

```swift
actor ComputerUseService {
    /// Continuous observation loop — captures screen, sends to Claude, executes actions.
    /// Uses ScreenCaptureKit for native screen capture (NOT screenshots — live frames).
    /// Claude Opus/Sonnet returns coordinate-based actions.
    /// System executes via CGEvent (mouse) and AXUIElement (semantic clicks).
    func startLiveSession(
        task: String,
        model: CloudModelID, // Must be .opus or .sonnet
        onAction: @escaping (AgentAction) -> Void
    ) async throws {
        guard model.supportsComputerUse else {
            throw AgentError.modelDoesNotSupportComputerUse
        }

        // 1. Capture screen via ScreenCaptureKit (60fps available, use 2-5fps for agent)
        // 2. Send frame + task to Claude Computer Use API
        // 3. Claude returns: { action: "click", coordinates: [x, y] }
        //    or: { action: "type", text: "..." }
        //    or: { action: "scroll", direction: "down" }
        //    or: { action: "wait", reason: "page loading" }
        //    or: { action: "done", result: "..." }
        // 4. Execute action via CGEvent / AXUIElement
        // 5. Loop back to step 1 until Claude says "done"
        //
        // KEY DIFFERENCE from screenshot-based: This is a CONTINUOUS LOOP.
        // The AI stays "on" — watching, waiting, thinking, acting.
        // It can wait for a page to load, back out if it sees an error,
        // dynamically adjust its approach based on what it observes.
    }
}
```

**Scale screenshots to XGA (1024x768)** before sending to Claude — this is Anthropic's recommended resolution for coordinate accuracy. Recalculate coordinates back to native resolution for CGEvent execution.

### Phase 3.5 — MCP Tool Layer for Cloud Models

Cloud models (especially Claude) can connect to MCP servers NATIVELY via the Anthropic API's MCP Connector:

```swift
// In AnthropicProvider — add mcp_servers to the request body
func generateWithMCP(
    messages: [ChatMessage],
    mcpServers: [MCPServerConfig]  // e.g., filesystem, sqlite, github
) -> AsyncThrowingStream<StreamChunk, Error> {
    // Add to request body:
    // "mcp_servers": [
    //   { "type": "url", "url": "https://mcp.notion.com/mcp", "name": "notion" }
    // ]
    // Claude handles tool discovery + execution server-side
}
```

Also support LOCAL stdio MCP servers for the local pipeline:
- Bundle `@modelcontextprotocol/server-filesystem` for vault access
- Bundle `mcp-server-sqlite` for GRDB database queries
- Route through the existing MCPBridge but add proper JSON-RPC 2.0 framing

---

## WORKSTREAM 4: OPERATING MODE SYSTEM

### Phase 4.0 — Mode Selector UI

**CREATE** `Epistemos/Views/Chat/AgentModeSelectorView.swift`:

A segmented control that shows ONLY modes the selected model actually supports:

```swift
struct AgentModeSelectorView: View {
    @Binding var mode: EpistemosOperatingMode
    let selectedModel: LocalTextModelID?   // nil if cloud model selected
    let selectedCloudModel: CloudModelID?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(availableModes, id: \.self) { m in
                modeButton(m)
            }
        }
    }

    /// Compute which modes are HONESTLY available
    private var availableModes: [EpistemosOperatingMode] {
        var modes: [EpistemosOperatingMode] = [.fast]

        if let local = selectedModel {
            // Thinking requires 4B+ AND supportsDualThinkMode
            if local.supportsDualThinkMode && local.activeParametersB >= 4.0 {
                modes.append(.thinking)
            }
            // Research requires 4B+ thinking model
            if local.supportsDualThinkMode && local.activeParametersB >= 4.0 {
                modes.append(.research)
            }
            // Agent and Live Agent are NEVER available for local models
        }

        if let cloud = selectedCloudModel {
            modes.append(.thinking) // Claude Opus/Sonnet have extended thinking
            modes.append(.research)
            if cloud.canDispatchAgents {
                modes.append(.agent)     // Full agentic — Opus only
                modes.append(.liveAgent) // Continuous screen observation — Opus + Sonnet
            } else if cloud.supportsComputerUse {
                modes.append(.liveAgent) // Sonnet can do live agent but not dispatch sub-agents
            }
        }

        return modes
    }
}
```

### Phase 4.1 — Thinking Mode (Honest Implementation)

**MODIFY** `LLMService.swift` or equivalent:

```swift
func thinkingPromptPrefix(for model: LocalTextModelID, thinkMode: Bool) -> String {
    // ONLY inject think tokens for models that actually support it
    guard model.supportsDualThinkMode else { return "" }
    return thinkMode ? "/think\n" : "/no_think\n"
}
```

For cloud models, use the API's native thinking parameter:
- Anthropic: `"thinking": { "type": "enabled", "budget_tokens": 10000 }`
- This is REAL extended thinking, not prompt injection

### Phase 4.2 — Research Mode (SOAR Pipeline)

Research mode (4B+ models) activates the SOAR evidence quality pipeline:
- `deepsearchweb` — Boolean web search with recency filter
- `captureandgradesource` — Capture page + compute SOAR score
- `checkcontradiction` — NLI contradiction detection via local model
- `synthesizeresearchnode` — Write verified finding to vault with citation

**CREATE** `Epistemos/Services/Research/TMSService.swift` with `calculateSOAR()` and `evaluateNLI()` — full implementation from the Complete Model Support plan.

**MODIFY** `OmegaToolRegistry.swift` — add all 4 SOAR tool definitions.

**MODIFY** `MCPBridge.swift` — SQLite migration adding `soarScore REAL`, `contradictionFlag INTEGER DEFAULT 0`, `citationHash TEXT`, `modelHash TEXT`.

### Phase 4.3 — Prompt Repetition (Free Quality Boost)

**CREATE/MODIFY** `SystemPromptBuilder.swift`:

```swift
/// Leviathan et al. (Google Research, arXiv 2512.14982) Prompt Repetition.
/// Duplicating user prompt in system message improves non-reasoning output by up to 76%.
/// Apply ONLY to non-thinking models — reasoning models already self-correct via CoT.
static func withPromptRepetition(
    baseSystemPrompt: String,
    userMessage: String,
    model: LocalTextModelID
) -> String {
    guard !model.supportsDualThinkMode else { return baseSystemPrompt }
    return """
    \(baseSystemPrompt)

    The user's request is: \(userMessage)
    """
}
```

---

## WORKSTREAM 5: oMLX SSD CACHING FOR LARGE MODELS

**WHY:** Models >16GB (Qwen 27B, 40B) need SSD offload. oMLX provides paged KV cache with SSD tiering, dropping TTFT from 90s to 1-3s.

**CREATE** `Epistemos/Services/Inference/OMLXBridgeService.swift`:

```swift
/// Routes inference to locally-running oMLX server for models exceeding system RAM.
/// oMLX runs at http://localhost:8000/v1 (configurable).
/// OpenAI-compatible API — streaming via SSE.
struct OMLXBridgeService {
    static let defaultBaseURL = URL(string: "http://localhost:8000/v1")!

    func generateStream(
        prompt: String,
        model: LocalTextModelID,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        // Standard OpenAI-compatible /chat/completions with stream: true
        // oMLX handles all SSD caching transparently
    }
}
```

**ADD** to model picker: Banner for models where `requiresExternalServer(systemRAMGB:)` returns true, with instructions to install oMLX.

---

## WORKSTREAM 6: RELEASE BLOCKERS

### 6.1 — Populate Release Entitlements

**MODIFY** `Epistemos/Epistemos.entitlements`:

For DIRECT DISTRIBUTION (recommended for v1):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

### 6.2 — Create Privacy Manifest

**CREATE** `Epistemos/PrivacyInfo.xcprivacy`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array><string>C617.1</string></array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array><string>CA92.1</string></array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array><string>E174.1</string></array>
        </dict>
    </array>
</dict>
</plist>
```

### 6.3 — Fix Deployment Target

**MODIFY** `project.yml`: Set BOTH deployment targets to `"15.0"` (not 26.0). This ships to all Apple Silicon Macs on Sonoma+.

### 6.4 — Fix Top 10 Silent `try?` Failures

Convert the highest-risk `try?` sites in `VaultIndexActor.swift` and `NoteFileStorage.swift` to `do/catch` with `Log.vault.error()`. See the Final Release Plan Section 1D for exact line numbers.

### 6.5 — Annotate Top 50 Unsafe Blocks

Add `// SAFETY:` comments to the 50 most critical unsafe blocks, prioritizing `graph-engine/src/lib.rs` (FFI boundary) and `graph-engine/src/knowledge_core/ring.rs` (concurrency).

---

## WORKSTREAM 7: EPISODIC MEMORY AND SKILL LIBRARIES

### 7.1 — SQLite Episodic Memory

**CREATE** `Epistemos/Services/Agent/EpisodicMemory.swift`:

Log every agent execution as `(task_intent, execution_plan, tool_calls, success_status, duration)`. Use hybrid BM25 + vector retrieval for context injection — top 3-5 results only.

### 7.2 — Voyager-Style Skill Library

Successful multi-step execution plans get hashed and saved as verified "skills." When future requests match semantically, bypass LLM planning entirely and execute the deterministic graph directly. This eliminates hallucination risk for repeated workflows.

### 7.3 — ODIA Nightly Training

When hardware is idle (overnight), parse SQLite execution logs, isolate successful traces, format as fine-tuning data, and run QLoRA on the local model via MLX. Use MoLoRA routing — separate adapters for Terminal, Safari, Notes domains.

---

## IMPLEMENTATION ORDER (EXACT SEQUENCE)

### Sprint 1: Foundation (Days 1-2)
1. Pre-flight verification greps
2. Create `ModelBackend.swift`, `KVCacheConfig.swift`, `ModelQuantization.swift`
3. REPLACE entire `LocalTextModelID.swift` with 17-model enum
4. Create `GGUFInferenceService.swift` (can be stubbed initially)
5. Add LocalLLMClient SPM dependency
6. Wire backend routing in `LLMService.swift`

### Sprint 2: Model Selector + TurboQuant (Days 3-4)
1. Create `LocalModelSelectorView.swift` with 5-tier sections
2. Add GGUF download path to `ModelDownloadManager.swift`
3. Wire TurboQuant `--kv-bits` to MLX inference
4. Add TurboQuant toggle to Settings

### Sprint 3: Cloud API Integration (Days 5-7)
1. Create `CloudProvider.swift` protocol
2. Create `AnthropicProvider.swift` with REAL tool calling
3. Create `OpenAIProvider.swift`
4. Create `SubscriptionProxy.swift` for Claude Max/Codex session proxy
5. Add API key + subscription settings UI

### Sprint 4: Agent Overhaul (Days 8-10)
1. Create `EpistemosOperatingMode` with honest capability gating
2. Create `AgentModeSelectorView.swift`
3. Create `DAGExecutor.swift` replacing linear ReAct loop
4. Fix Safari agent — add wait-for-load, AX tree verification, fallback to Screen2AX
5. Create `Screen2AXService.swift` for visual grounding fallback
6. Add grammar-constrained tool calling for local models

### Sprint 5: Computer Use + Live Agent (Days 11-13)
1. Create `ComputerUseService.swift` for continuous screen observation
2. Wire ScreenCaptureKit for native frame capture (not screenshots)
3. Implement CGEvent action execution (mouse, keyboard, scroll)
4. Wire to Anthropic Computer Use API for Opus/Sonnet
5. Create `LiveAgentView.swift` showing real-time agent observation + Kanban progress

### Sprint 6: SOAR Research + Memory (Days 14-15)
1. Create `TMSService.swift` with SOAR scoring
2. Add 4 SOAR tools to `OmegaToolRegistry.swift`
3. MCPBridge SQLite migration
4. Create `EpisodicMemory.swift`
5. Wire MCP tool layer for both local + cloud

### Sprint 7: Release Blockers + Polish (Days 16-17)
1. Populate release entitlements
2. Create privacy manifest
3. Fix deployment target to 15.0
4. Fix top 10 `try?` sites
5. Annotate top 50 unsafe blocks
6. Run full ASAN/TSAN/UBSAN sanitizer suite
7. Run all existing tests — ZERO regressions

---

## ACCEPTANCE CRITERIA (Every Item Must Be True)

### Models & Inference
- [ ] `LocalTextModelID` has all 17 models (6 MLX + 11 new)
- [ ] Every model has `ramRequirementQ4GB` and `ramRequirementQ8GB?` populated
- [ ] `ModelBackend.swift` exists with `.mlx`, `.gguf`, `.cloud` cases
- [ ] `GGUFInferenceService.swift` exists and compiles
- [ ] Model picker shows 5 tier sections with RAM labels
- [ ] Q4/Q8 buttons render in picker for each GGUF model row
- [ ] TurboQuant toggle wired to MLX inference via `--kv-bits`
- [ ] oMLX bridge exists for oversized models

### Agent System
- [ ] `EpistemosOperatingMode` has 5 modes: fast, thinking, research, agent, liveAgent
- [ ] Agent + liveAgent modes are DISABLED for local models (honest capability gating)
- [ ] Thinking mode only available for models with `supportsDualThinkMode` AND ≥4B
- [ ] Research mode only available for ≥4B thinking models
- [ ] Safari agent no longer stops after paste — uses DAG execution + wait-for-load
- [ ] Grammar-constrained decoding forces valid JSON tool calls from local models
- [ ] `DAGExecutor.swift` replaces linear ReAct loop
- [ ] `Screen2AXService.swift` provides visual fallback when AX tree is sparse

### Cloud Integration
- [ ] `AnthropicProvider.swift` supports tool calling, computer use, extended thinking, MCP
- [ ] Opus can dispatch sub-agents; Sonnet cannot; Haiku has basic tool calling only
- [ ] `SubscriptionProxy.swift` enables Claude Max session-based access
- [ ] Computer Use service provides continuous screen observation via ScreenCaptureKit
- [ ] MCP servers work for both local (stdio) and cloud (HTTP) models
- [ ] API key stored in macOS Keychain, not UserDefaults

### Research Mode
- [ ] `TMSService.swift` exists with `calculateSOAR()` and `evaluateNLI()`
- [ ] All 4 SOAR tool schemas in `OmegaToolRegistry.all`
- [ ] MCPBridge migration adds soarScore, contradictionFlag, citationHash, modelHash
- [ ] Prompt Repetition function exists for non-thinking models

### Release Blockers
- [ ] Release entitlements populated (not empty `<dict/>`)
- [ ] `PrivacyInfo.xcprivacy` exists with required reason APIs
- [ ] Deployment target is `15.0` everywhere in `project.yml`
- [ ] Top 10 `try?` sites converted to `do/catch` with logging
- [ ] Top 50 unsafe blocks have `// SAFETY:` comments
- [ ] All existing tests pass with zero regressions
- [ ] ASAN, TSAN, UBSAN sanitizer runs complete without errors

---

## APPENDIX A: KEY ARCHITECTURAL DECISIONS

1. **Local models cannot be agents.** This is not a limitation to work around — it's a fundamental constraint of 4B-27B parameter models on consumer hardware. They hallucinate tool schemas, lose multi-step context, and fail at spatial reasoning. The Dual-Brain architecture (local for thinking, cloud for doing) is the correct approach.

2. **The app is local-first, cloud as a bonus.** The entire marketing and UX should make clear: Epistemos works completely offline with zero cloud dependency. Cloud features (agent mode, computer use, MCP) are a premium extension for users who want them.

3. **TurboQuant is KV cache compression, NOT weight compression.** It complements GGUF quantization (Q4_K_M for weights) by compressing the runtime cache that grows with context. On Apple Silicon: ~44% cache reduction, ~30% throughput gain.

4. **Direct distribution first, Mac App Store later.** The Omega agent system requires unsandboxed access. Ship notarized + Sparkle for auto-updates. A sandboxed "lite" version can follow.

5. **Subscription proxy is advanced/optional.** Not everyone wants to risk their Claude Max account. Offer it as a power-user feature with clear warnings.

## APPENDIX B: REFERENCED RESEARCH PAPERS

- TurboQuant: arXiv 2504.19874 (Google Research, ICLR 2026)
- Prompt Repetition: arXiv 2512.14982 (Leviathan et al., Google Research)
- REAP Expert Pruning: arXiv 2510.13999 (Cerebras, ICLR 2026)
- Gemma 3 QAT: Google Developers Blog (2025)
- oMLX SSD Caching: github.com/jundot/omlx
- LocalLLMClient: github.com/tattn/LocalLLMClient
- OmniParser V2: Microsoft Research
- Screen2AX: Proposed hybrid architecture from Native macOS Agent Orchestration paper
- Karpathy Autoresearch Loop: Referenced in Cognitive OS Blueprint
- MCP Specification: modelcontextprotocol.io (version 2025-11-25)

---

*This prompt was synthesized from 20+ research documents totaling ~150,000 words of architectural analysis. Every code snippet, model ID, RAM requirement, and capability flag has been cross-referenced across multiple source documents for consistency. Last updated: March 28, 2026.*
