# EPISTEMOS — DEFINITIVE BUILD SPECIFICATION v3.0 (FUSED)

> **Index status**: SUPERSEDED-HISTORICAL — March 28, 2026 comprehensive build spec. Superseded by the current canonical stack: [`docs/architecture/PLAN_V2.md`](architecture/PLAN_V2.md) (architectural authority) + [`docs/MASTER_BUILD_PLAN.md`](MASTER_BUILD_PLAN.md) (operational doctrine + queue) + [`docs/plan/01_DOCTRINE.md`](plan/01_DOCTRINE.md) (14 non-negotiables) + [`docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md`](IMPLEMENTATION_PLAN_FROM_ADVICE.md) (4-model council synthesis). Cited in CLAUDE.md "Detailed Docs" — kept for historical archeology of the v3.0 fusion; **not canonical for current execution**. Classified in [`docs/_INDEX.md §9`](_INDEX.md).

## For Claude Code / Codex / Any Agentic Coding Agent
### Date: March 28, 2026 | Developer: Jordan | Machine: M2 Pro MacBook 16GB
### Synthesized from 25+ research papers, 3 deep research rounds, 20 architectural documents, and the v1.0 megaprompt

---

## HOW TO USE THIS DOCUMENT

**This is NOT a single-session prompt. Do NOT try to execute this entire document in one session.**

Execute one sprint at a time using the sprint files in `docs/sprint-sessions/`. This document is the **reference spec** — read the relevant section when a sprint file says "see Phase X.Y."

**Workflow:**
1. Start a fresh Claude Code session for each sprint
2. Your kickoff prompt is: `Read docs/sprint-sessions/sprint-{N}-{name}.md and execute all tasks in order.`
3. The sprint file will tell you which sections of THIS document to read for detail
4. After each sprint, update `docs/PROGRESS.md` with checkmarks
5. Run the audit prompt from `docs/audit-prompts/post-sprint-audit.md` in a separate session to verify

**Automatic context management:**
- `CLAUDE.md` (project root) loads automatically every session — contains rules and file locations
- `.claude/settings.json` contains hooks that fire automatically on compaction and file writes
- `.claude/context-essentials.txt` gets injected after every context compaction via hook

---

## PREAMBLE — READ EVERY WORD BEFORE TOUCHING CODE

You are implementing a complete systems upgrade to Epistemos, a native macOS Cognitive OS built in Rust + Swift + Metal. The codebase is ~137K lines Swift, ~94K lines Rust, ~370 Swift files, ~99 Rust files, ~115 test files. The existing architecture uses UniFFI for Rust↔Swift FFI, GRDB for persistence, MLX-Swift for local inference, and a multi-agent Omega system for agentic workflows.

**CRITICAL ARCHITECTURAL CONSTRAINTS — VIOLATIONS ARE BUILD FAILURES:**

1. **NO SIDECAR PROCESSES.** All inference runs in-process via Rust FFI or MLX-Swift framework calls. REJECT any code using `Process()`, `NSTask`, `posix_spawn`, or HTTP calls to localhost for inference. The ONLY acceptable inference paths are: (a) Rust library linked via UniFFI/cbindgen calling Candle/mistral.rs Metal backend, (b) llama.cpp compiled as a static library linked directly into the Swift target, (c) MLX-Swift framework calls (ml-explore/mlx-swift-lm). Any localhost:port inference server (Ollama daemon, llama-server, vllm-serve) is REJECTED. The ONLY exception is the oMLX SSD caching bridge for models exceeding system RAM (see Workstream 5).

2. **REAL APIs ONLY.** Every cloud API integration must use officially documented endpoints from the provider. No fake features. No mock implementations dressed up as real capabilities. If a model does not support a feature (e.g., local 9B model doing reliable tool calling), the UI must DISABLE that feature for that model — not fake it with a flimsy wrapper.

3. **ALL MODELS STAY.** The model registry includes EVERY model — from 0.8B local to 671B cloud-only. Models that don't fit locally get routed to cloud APIs. The registry is a scalable manifest, not a capability gate. Models are never removed because they're "too large" — they get a `deploymentMode: .cloudOnly` flag or an `isComingSoon` badge.

4. **HONEST CAPABILITY GATING.** Local models (≤27B) get: fast, thinking, research modes. Cloud models get: all modes including agent and liveAgent. The UI reflects this honestly. Agent mode buttons are DISABLED for local models with a tooltip explaining why.

5. **ZERO TEST REGRESSIONS.** The existing 2,679-test suite is sacred. Every new component gets tests. Every `unsafe` block gets a `// SAFETY:` comment. No `try!`, no force-unwraps, no `print()` in production paths.

**YOUR OPERATING PRINCIPLES:**
- Never ask for approval — just implement.
- After each phase, run the verification greps listed.
- If something doesn't exist where expected, HALT and report — do not guess.
- Build bottom-up: foundation types → inference services → routing → UI.

---

## PRE-FLIGHT: VERIFY CURRENT STATE

Run every one of these FIRST. If any result differs from EXPECTED, halt and report before proceeding.

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

## WORKSTREAM 1: DUAL-BACKEND LOCAL INFERENCE (MLX + GGUF)

### Phase 1.0 — Foundation Types (no dependencies)

**CREATE** `Epistemos/Services/Inference/ModelBackend.swift`:
```swift
/// Identifies which inference runtime handles a given model.
enum ModelBackend: String, Codable, Sendable {
    case mlx   // mlx-community/* models via existing MLXInferenceService
    case gguf  // *.gguf files via new GGUFInferenceService (llama.cpp static lib)
    case cloud // Cloud API models (Anthropic, OpenAI, Google, DeepSeek, Mistral, Cohere)

    var supportsStreaming: Bool { true }
    var supportsGrammar: Bool { self == .gguf } // llama.cpp gbnf
    var supportsNativeToolCalling: Bool { self == .cloud } // ONLY cloud models reliably call tools
}
```

**CREATE** `Epistemos/Services/Inference/KVCacheConfig.swift`:
```swift
/// KV cache quantization configuration.
/// Implements TurboQuant (Google Research, ICLR 2026) approach for Apple Silicon.
/// PolarQuant: Hadamard rotation → polar coordinates → Lloyd-Max quantization.
/// QJL: 1-bit error correction on residual via random projection.
/// On M2 Pro: +32% prompt throughput, +26% decode throughput, -44% KV cache size.
/// NOTE: Full PolarQuant requires mlx-lm >= 0.21 or flovflo fork.
/// Until merged, this uses mlx-lm's built-in QuantizedKVCache (--kv-bits 4).
struct KVCacheConfig: Codable, Sendable {
    var quantizationBits: Int = 4     // 3 (turbo3), 4 (turbo4), 8, or 16 (no compression)
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

### Phase 1.1 — Complete Model Registry

**REPLACE THE ENTIRE CONTENTS** of `LocalTextModelID.swift` (verify location with grep first) with a comprehensive registry. This includes:

**The original 6 MLX Qwen models** (preserve raw values exactly) plus ALL new models.

Every model must have these computed properties:
```swift
var displayName: String
var familyName: String
var backend: ModelBackend            // .mlx, .gguf, or .cloud
var deploymentMode: DeploymentMode   // .local, .cloudOnly, .hybrid
var ramRequirementQ4GB: Int
var ramRequirementQ8GB: Int?         // nil for models without Q8
var supportsDualThinkMode: Bool      // ONLY Qwen3.5 family + SmolLM3
var isMoE: Bool
var isCodeSpecialist: Bool           // Devstral, MiniMax, Chroma, Codestral
var isUnrestrictedThinking: Bool     // only 40B Opus Uncensored
var isComingSoon: Bool               // Llama4Scout, MiniMax, Chroma
var contextWindowK: Int
var ggufFileQ4: String?              // HuggingFace filename for Q4 GGUF
var ggufFileQ8: String?              // HuggingFace filename for Q8 GGUF
var activeParametersB: Double        // Active params (differs from total for MoE)
var tier: ModelTier                  // .ultraLight ≤8GB, .efficient 9-16GB, .standard 17-24GB, .professional 25-48GB, .maximum 48GB+
var canActAsAgent: Bool              // FALSE for ALL local models. TRUE only for cloud.
func requiresExternalServer(systemRAMGB: Int) -> Bool  // Computed from RAM vs model size
```

**LOCAL MODELS (run on M2 Pro 16GB):**

| Model | Backend | Q4 RAM | Est. tok/s | Think Mode | Notes |
|---|---|---|---|---|---|
| Qwen 3.5 0.8B | MLX | ~4GB | ~80 | Yes | Original |
| Qwen 3.5 2B | MLX | ~5GB | ~60 | Yes | Original |
| Qwen 3.5 4B | MLX | ~6GB | ~43 | Yes | Original |
| Qwen 3.5 9B | MLX | ~7GB | ~25 | Yes | Original |
| Qwen 3.5 27B | MLX | ~16GB | ~6 | Yes | Original |
| Qwen 3.5 35B-A3B | MLX | ~32GB | N/A | Yes | Original, needs oMLX |
| SmolLM3 3B | MLX/GGUF | ~4GB | ~55 | Yes | NEW |
| Phi-4 14B | GGUF | ~9GB | ~15 | No | NEW |
| Phi-4-mini 3.8B | GGUF | ~4GB | ~60 | No | NEW |
| Qwen 2.5 Coder 14B | GGUF | ~9GB | ~15 | No | NEW |
| DeepSeek R1 Distill 14B | GGUF | ~9GB | ~15 | No | NEW |
| Gemma 3 12B QAT | GGUF | ~7GB | ~18 | No | NEW — Google QAT, bfloat16 quality at 4-bit |
| Gemma 3 27B QAT | GGUF | ~16GB | ~8 | No | NEW — fits 16GB, highest quality at boundary |
| Mistral Small 3.1 24B | GGUF | ~14GB | ~8 | No | NEW |
| Devstral Small 2 24B | GGUF | ~14GB | ~8 | No | NEW — code specialist, Apache 2.0 |
| Qwen 3.5 27B Opus-Distilled | GGUF | ~16GB | ~6 | Yes | NEW — needs SSD offload on 16GB |
| Qwen 3.5 28B-A3B REAP | GGUF | ~20GB | ~6-9 | Yes | NEW — MoE, needs SSD offload |
| Qwen 3.5 40B Opus Uncensored | GGUF | ~24GB | N/A | Yes | NEW — isUnrestrictedThinking, needs oMLX |
| Llama 4 Scout 109B MoE | MLX | ~64GB | N/A | No | NEW — isComingSoon on 16GB |
| MiniMax M2.5 | GGUF | TBD | TBD | No | NEW — isComingSoon, code specialist |
| Chroma Context-1 | GGUF | TBD | TBD | No | NEW — isComingSoon, code specialist |

**CLOUD-ONLY MODELS (served via API, too large for 16GB local):**

| Model | Provider | API Endpoint | Key Capabilities |
|---|---|---|---|
| Claude Opus 4.6 | Anthropic | api.anthropic.com/v1/messages | Tool calling, computer use, thinking, MCP, vision, sub-agent dispatch |
| Claude Sonnet 4.6 | Anthropic | api.anthropic.com/v1/messages | Tool calling, computer use, thinking, MCP, vision |
| Claude Haiku 4.5 | Anthropic | api.anthropic.com/v1/messages | Basic tool calling, vision |
| GPT-5.4 | OpenAI | api.openai.com/v1/responses | Function calling, vision, web search |
| GPT-4o | OpenAI | api.openai.com/v1/chat/completions | Function calling, vision |
| o3 | OpenAI | api.openai.com/v1/responses | Reasoning, function calling |
| Gemini 2.5 Pro | Google | generativelanguage.googleapis.com | Function calling, vision, 1M context, grounding |
| Gemini 2.5 Flash | Google | generativelanguage.googleapis.com | Function calling, vision, fast |
| DeepSeek R1 | DeepSeek | api.deepseek.com/v1 | Chain-of-thought reasoning |
| DeepSeek V3.2 | DeepSeek | api.deepseek.com/v1 | Chat, function calling, $0.28/MTok |
| Qwen3-Max | Alibaba | dashscope-intl.aliyuncs.com | Chat, function calling |
| QwQ-32B | Alibaba | dashscope-intl.aliyuncs.com | Reasoning |
| Mistral Large 3 | Mistral | api.mistral.ai/v1 | Chat, function calling, vision |
| Codestral | Mistral | codestral.mistral.ai/v1 | FIM code completion |
| Command A | Cohere | api.cohere.com/v2 | Chat, RAG, rerank, embed |
| Llama 3.3 70B | Meta (via partners) | Various (Together, Groq) | Chat |

### Phase 1.2 — GGUF Inference Service (Embedded, Not Sidecar)

**ADD SPM DEPENDENCY**: `tattn/LocalLLMClient` (branch: main). This wraps both llama.cpp AND MLX behind a unified Swift Concurrency interface with AsyncSequence streaming. Compiles llama.cpp as a static library linked directly into the app binary.

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
            prompt: fullPrompt, maxTokens: maxTokens, temperature: temperature
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

**MODIFY** the main inference dispatch point (`LLMService.swift`, `InferenceState.swift`, or wherever `generateStream` is called). Add a `switch model.backend` that routes:
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
- If using `mlx-swift-lm` native Swift API (which does NOT expose kv-bits yet), invoke `mlx_lm.generate` via `Process()` subprocess as a bridge until mlx-swift-lm catches up. Mark with: `// TODO: Remove subprocess when mlx-swift-lm adds kv-bits support`

**For GGUF models:** Pass `--cache-type-k q8_0 --cache-type-v q4_0` to llama.cpp for standard quantized KV cache. When upstream TurboQuant merges (expected Q2 2026), upgrade to `--cache-type-k turbo3 --cache-type-v turbo3`.

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
- Badge system: **"MoE" (purple)**, **"Code" (blue)**, **"Think" (orange)**, **"Uncensored" (red)**, **"Coming Soon" (gray)**, **"Needs oMLX" (orange)** for models exceeding system RAM
- TurboQuant indicator in RAM banner when enabled
- **CRITICAL**: Models where `canActAsAgent == false` show NO agent badge. Only cloud models show agent capability.

---

## WORKSTREAM 2: AGENT SYSTEM OVERHAUL

**WHY:** The current agent system is broken. The Safari agent stops after pasting text. Local models can't reliably call tools because 4B-14B models don't have the spatial/syntactic precision for structured tool invocation.

### Phase 2.0 — Honest Capability Audit (Dual-Brain Architecture)

Local models (≤27B) CANNOT reliably act as autonomous agents. They hallucinate tool schemas, lose track of multi-step plans, and fail at spatial reasoning. The fix:
- **Local models** = Fast response, thinking mode, text generation, embeddings, simple routing
- **Cloud models** = True agentic workflows, tool calling, computer use, research mode

```swift
enum EpistemosOperatingMode: String, CaseIterable, Codable {
    case fast      // Local model, no reasoning overhead, instant answers
    case thinking  // Local model WITH /think tokens, chain-of-thought (4B+ only)
    case research  // Local model thinking + SOAR evidence pipeline (4B+ only)
    case agent     // CLOUD MODEL ONLY — true multi-step agentic execution
    case liveAgent // CLOUD MODEL ONLY — continuous screen observation + computer use

    var requiresCloudModel: Bool {
        self == .agent || self == .liveAgent
    }

    var minimumModelSizeB: Double? {
        switch self {
        case .fast: return nil
        case .thinking, .research: return 4.0
        case .agent, .liveAgent: return nil // Cloud handles this
        }
    }
}
```

### Phase 2.1 — Fix the Broken Safari Agent

**AUDIT** `SafariAgent.swift` — trace the exact failure:
1. Grep for `kAXPressAction`, `CGEvent`, `AXUIElement` calls
2. The agent likely fails because: (a) it pastes text but doesn't wait for page load, (b) it tries to read DOM via AX tree which is sparse in Safari, (c) the local model hallucinates the next tool call
3. **FIX**: Replace the naive ReAct loop with Plan-and-Execute DAG:
   - Planning generates complete JSON execution plan BEFORE any action
   - Grammar-constrained decoding forces valid JSON from local models
   - Execution runs each step independently with fresh context
   - If AX tree is sparse, fall back to Screen2AX visual grounding

### Phase 2.2 — DAG Execution Engine

**CREATE** `Epistemos/Services/Agent/DAGExecutor.swift`:
```swift
actor DAGExecutor {
    func execute(plan: ExecutionPlan) async throws -> ExecutionResult {
        var context: [String: Any] = [:]
        for phase in plan.phases {
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

    /// Execute with FRESH context — prevents contamination.
    /// If node fails, trigger re-planning rather than blind retry.
    private func executeNode(_ node: ExecutionNode, context: [String: Any]) async throws -> NodeResult {
        // ... implementation with error recovery and re-planning
    }
}
```

### Phase 2.3 — Screen2AX Visual Grounding

**CREATE** `Epistemos/Services/Agent/Screen2AX.swift`:
```swift
struct Screen2AXService {
    func captureHybridTree(for window: CGWindowID) async throws -> [UIElement] {
        let axTree = try await AXTreeWalker.walk(window: window)
        if axTree.actionableElements.count < 5 {
            let screenshot = try await ScreenCapture.capture(window: window)
            let visualElements = try await OmniParserService.parse(screenshot)
            return merge(axTree: axTree, visualElements: visualElements)
        }
        return axTree.actionableElements
    }
}
```

**NOTE**: OmniParser V2 runs locally on Metal. Uses YOLOv8 bounding box model + Florence-2 captioner. On M2 Pro: 90-300ms per frame. Fallback only — AX tree always preferred.

### Phase 2.4 — Grammar-Constrained Tool Calling for Local Models

**MODIFY** the inference path for local models in agent mode:
```swift
// When model outputs <tool_call>, switch logit sampler to grammar-constrained mode
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

Use llama.cpp's GBNF grammar or mlx-swift-structured to enforce valid JSON.

---

## WORKSTREAM 3: CLOUD API INTEGRATION — TRUE AGENTIC POWER

**WHY:** Local models are private but CANNOT do real agent work. Cloud models have native tool calling, computer use, and agentic capabilities. The app is marketed as "all local unless you want to extend to cloud."

### Phase 3.0 — Cloud Provider Protocol

**CREATE** `Epistemos/Services/Cloud/CloudProvider.swift`:
```swift
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
    let supportsComputerUse: Bool      // ONLY Anthropic Opus/Sonnet
    let supportsThinking: Bool         // Extended thinking
    let supportsMCP: Bool
    let supportsVision: Bool
    let supportsStreaming: Bool
    let supportsFIM: Bool              // ONLY Mistral Codestral
    let supportsWebSearch: Bool        // Anthropic, OpenAI, Gemini
    let maxContextTokens: Int
    let canDispatchAgents: Bool
}
```

### Phase 3.1 — Anthropic Provider (Claude API — VERIFIED REAL)

**CREATE** `Epistemos/Services/Cloud/AnthropicProvider.swift`:

Base URL: `https://api.anthropic.com/v1/messages`
Auth: `x-api-key` header + `anthropic-version: 2023-06-01`

```swift
actor AnthropicProvider: CloudProvider {
    private let apiKey: String // From Keychain
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    var capabilities: ProviderCapabilities {
        ProviderCapabilities(
            supportsToolCalling: true,
            supportsComputerUse: model.supportsComputerUse,
            supportsThinking: model.supportsThinking,
            supportsMCP: true,
            supportsVision: true,
            supportsStreaming: true,
            supportsFIM: false,
            supportsWebSearch: true,
            maxContextTokens: 200_000,
            canDispatchAgents: model == .opus
        )
    }
}
```

**Capability matrix (VERIFIED March 2026):**

| Claude Model | Tool Calling | Computer Use | Extended Thinking | Sub-Agents | MCP |
|---|---|---|---|---|---|
| Opus 4.6 | ✅ Full | ✅ Full (beta) | ✅ Full | ✅ YES | ✅ |
| Sonnet 4.6 | ✅ Full | ✅ Full (beta) | ✅ Full | ❌ No | ✅ |
| Haiku 4.5 | ✅ Basic | ❌ No | ❌ No | ❌ No | ✅ |

**What does NOT exist (DO NOT IMPLEMENT):**
- ❌ Anthropic does NOT have a Swift SDK. Use raw URLSession.
- ❌ Anthropic does NOT have a free tier. $5 minimum deposit.
- ❌ Anthropic does NOT have an OpenAI-compatible endpoint.
- ❌ Claude Code does NOT have an API — CLI tool only.

### Phase 3.2 — OpenAI Provider (VERIFIED REAL)

**CREATE** `Epistemos/Services/Cloud/OpenAIProvider.swift`:

Primary: `POST https://api.openai.com/v1/responses` (Responses API — now primary)
Legacy: `POST https://api.openai.com/v1/chat/completions` (still supported)

- ✅ Function calling, vision, structured outputs, web search
- ✅ Computer use (computer-use-preview model, Tier 3+ required)
- ⚠️ Assistants API is DEPRECATED (sunset Aug 2026) — DO NOT USE
- ❌ OpenAI does NOT have a Swift SDK.

### Phase 3.3 — Additional Cloud Providers

**GeminiProvider.swift**: OpenAI-compatible at `generativelanguage.googleapis.com/v1beta/openai/`. FREE tier available (no credit card). NOT available in EU/EEA/UK/Switzerland. Swift SDK: Firebase AI Logic only (standalone deprecated).

**DeepSeekProvider.swift**: OpenAI-compatible at `api.deepseek.com/v1`. $0.28/MTok. CRITICAL: 78+ outages since Jan 2025 — implement automatic fallback.

**MistralProvider.swift**: OpenAI-compatible at `api.mistral.ai/v1`. Unique FIM endpoint at `/v1/fim/completions` for Codestral.

**CohereProvider.swift**: Unique `/v2/rerank` and `/v2/embed` endpoints for RAG pipelines.

**QwenProvider.swift**: OpenAI-compatible at `dashscope-intl.aliyuncs.com/compatible-mode/v1`.

### Phase 3.4 — Unified Cloud Router

**CREATE** `Epistemos/Services/Cloud/CloudRouter.swift`:

One HTTP client, many providers via OpenAI-compatible endpoints:

| Provider | Base URL | Format |
|---|---|---|
| Anthropic | api.anthropic.com/v1 | Custom (Messages API) |
| OpenAI | api.openai.com/v1 | OpenAI native |
| DeepSeek | api.deepseek.com/v1 | OpenAI-compatible |
| Mistral | api.mistral.ai/v1 | OpenAI-compatible |
| Gemini | generativelanguage.googleapis.com/v1beta/openai/ | OpenAI-compatible |
| Qwen | dashscope-intl.aliyuncs.com/compatible-mode/v1 | OpenAI-compatible |
| Cohere | Compatibility endpoint | OpenAI-compatible |

Anthropic is the ONLY exception requiring its own adapter.

**API keys stored in macOS Keychain** — never UserDefaults, never a plist.

### Phase 3.5 — Subscription Proxy (Claude Max / Codex — ADVANCED FEATURE)

**CREATE** `Epistemos/Services/Cloud/SubscriptionProxy.swift`:

Implements CLIProxyAPI / OpenClaw pattern:
1. Launch local HTTP server on `http://localhost:8317/v1` translating OpenAI-compatible requests into Claude web frontend payloads
2. Auth: User logs into Claude via embedded WKWebView (NOT SFSafariViewController — that sandboxes cookies). Extract `sessionKey` cookie from `WKHTTPCookieStore`.
3. Store session token in macOS Keychain (encrypted, app-scoped)
4. Translate Messages API JSON into web frontend's undocumented payload format
5. Stream SSE responses back as standard `chat.completion.chunk` events

```swift
struct SubscriptionProxyConfig {
    enum Provider { case claude, openai }
    let provider: Provider
    let localPort: Int = 8317
    let sessionToken: String

    /// Bind ONLY to localhost — never expose to network.
    func start() async throws {
        // NWListener bound to 127.0.0.1:\(localPort)
    }
}
```

**IMPORTANT**: BONUS feature. App works fully local by default. Clearly labeled:
- "Use Claude Max Subscription (instead of API key)"
- Warning: "This uses your web session. May be against ToS. Use at your own risk."

### Phase 3.6 — Computer Use: Continuous Screen Observation (CLOUD ONLY)

**CREATE** `Epistemos/Services/Agent/ComputerUseService.swift`:

```swift
actor ComputerUseService {
    /// Continuous observation loop — captures screen, sends to Claude, executes actions.
    /// Uses ScreenCaptureKit for native screen capture (NOT screenshots — live frames).
    func startLiveSession(
        task: String,
        model: CloudModelID, // Must be .opus or .sonnet
        onAction: @escaping (AgentAction) -> Void
    ) async throws {
        guard model.supportsComputerUse else {
            throw AgentError.modelDoesNotSupportComputerUse
        }
        // 1. Capture screen via ScreenCaptureKit (use 2-5fps for agent)
        // 2. Scale to XGA (1024x768) — Anthropic's recommended resolution
        // 3. Send frame + task to Claude Computer Use API
        //    - Tool definitions: computer_20251124, text_editor_20250728, bash_20250124
        //    - Beta header: anthropic-beta: computer-use-2025-11-24
        // 4. Claude returns tool_use blocks: click(x,y), type(text), scroll, wait, done
        // 5. Execute via CGEvent at native resolution (recalculate coordinates)
        // 6. Loop until Claude returns text (no more tool_use)
        //
        // This is a CONTINUOUS LOOP — AI stays "on" watching, waiting, acting.
    }
}
```

### Phase 3.7 — MCP Tool Layer

Cloud models (Claude) connect to MCP servers NATIVELY via Anthropic API's MCP Connector:

```swift
// In AnthropicProvider — add mcp_servers to request body
func generateWithMCP(
    messages: [ChatMessage],
    mcpServers: [MCPServerConfig]
) -> AsyncThrowingStream<StreamChunk, Error> {
    // "mcp_servers": [
    //   { "type": "url", "url": "https://mcp.notion.com/mcp", "name": "notion" }
    // ]
}
```

Also support LOCAL stdio MCP servers:
- Bundle `@modelcontextprotocol/server-filesystem` for vault access
- Bundle `mcp-server-sqlite` for GRDB database queries
- Route through existing MCPBridge with proper JSON-RPC 2.0 framing

---

## WORKSTREAM 4: OPERATING MODE SYSTEM

### Phase 4.0 — Mode Selector UI

**CREATE** `Epistemos/Views/Chat/AgentModeSelectorView.swift`:
```swift
struct AgentModeSelectorView: View {
    @Binding var mode: EpistemosOperatingMode
    let selectedModel: LocalTextModelID?
    let selectedCloudModel: CloudModelID?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(availableModes, id: \.self) { m in modeButton(m) }
        }
    }

    private var availableModes: [EpistemosOperatingMode] {
        var modes: [EpistemosOperatingMode] = [.fast]
        if let local = selectedModel {
            if local.supportsDualThinkMode && local.activeParametersB >= 4.0 {
                modes.append(.thinking)
                modes.append(.research)
            }
            // Agent and Live Agent are NEVER available for local models
        }
        if let cloud = selectedCloudModel {
            modes.append(.thinking)
            modes.append(.research)
            if cloud.canDispatchAgents {
                modes.append(.agent)
                modes.append(.liveAgent)
            } else if cloud.supportsComputerUse {
                modes.append(.liveAgent)
            }
        }
        return modes
    }
}
```

### Phase 4.1 — Thinking Mode (Honest Implementation)

**MODIFY** `LLMService.swift`:
```swift
func thinkingPromptPrefix(for model: LocalTextModelID, thinkMode: Bool) -> String {
    guard model.supportsDualThinkMode else { return "" }
    return thinkMode ? "/think\n" : "/no_think\n"
}
```

For cloud models, use API's native thinking parameter:
- Anthropic: `"thinking": { "type": "enabled", "budget_tokens": 10000 }`
- This is REAL extended thinking, not prompt injection

### Phase 4.2 — Research Mode (SOAR Pipeline)

Research mode activates the SOAR evidence quality pipeline with 4 tools:
- `deepsearchweb` — Boolean web search with recency filter
- `captureandgradesource` — Capture page + compute SOAR score
- `checkcontradiction` — NLI contradiction detection via local model
- `synthesizeresearchnode` — Write verified finding to vault with citation

**CREATE** `Epistemos/Services/Research/TMSService.swift` with `calculateSOAR()` and `evaluateNLI()`.

**MODIFY** `OmegaToolRegistry.swift` — add all 4 SOAR tool definitions.

**MODIFY** `MCPBridge.swift` — SQLite migration adding:
- `soarScore REAL`
- `contradictionFlag INTEGER DEFAULT 0`
- `citationHash TEXT`
- `modelHash TEXT`

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
/// NOTE: This is the ONLY acceptable localhost:port pattern — it's for SSD-offloaded
/// models that physically cannot run in-process on 16GB.
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

**MODIFY** `Epistemos/Epistemos.entitlements` for DIRECT DISTRIBUTION:
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
**MODIFY** `project.yml`: Set BOTH to `"15.0"` (not 26.0). Ships to all Apple Silicon Macs on Sonoma+.

### 6.4 — Fix Top 10 Silent `try?` Failures
Convert highest-risk `try?` sites in `VaultIndexActor.swift` and `NoteFileStorage.swift` to `do/catch` with `Log.vault.error()`.

### 6.5 — Annotate Top 50 Unsafe Blocks
Add `// SAFETY:` comments prioritizing `graph-engine/src/lib.rs` (FFI boundary) and `graph-engine/src/knowledge_core/ring.rs` (concurrency).

---

## WORKSTREAM 7: EPISODIC MEMORY AND SKILL LIBRARIES

### 7.1 — SQLite Episodic Memory

**CREATE** `Epistemos/Services/Agent/EpisodicMemory.swift`:
Log every agent execution as `(task_intent, execution_plan, tool_calls, success_status, duration)`. Use hybrid BM25 + vector retrieval for context injection — top 3-5 results only.

### 7.2 — Voyager-Style Skill Library

Successful multi-step execution plans get hashed and saved as verified "skills." When future requests match semantically, bypass LLM planning entirely and execute the deterministic graph directly. Eliminates hallucination risk for repeated workflows.

### 7.3 — ODIA Nightly Training

When hardware is idle (overnight), parse SQLite execution logs, isolate successful traces, format as fine-tuning data, and run QLoRA on the local model via MLX. Use MoLoRA routing — separate adapters for Terminal, Safari, Notes domains.

---

## IMPLEMENTATION ORDER (EXACT SEQUENCE)

### Sprint 1: Foundation (Days 1-2)
1. Pre-flight verification greps (all 11)
2. Create `ModelBackend.swift`, `KVCacheConfig.swift`, `ModelQuantization.swift`
3. REPLACE entire `LocalTextModelID.swift` with full model registry (local + cloud)
4. Create `GGUFInferenceService.swift` (can be stubbed initially)
5. Add LocalLLMClient SPM dependency
6. Wire backend routing in `LLMService.swift`

### Sprint 2: Model Selector + TurboQuant (Days 3-4)
1. Create `LocalModelSelectorView.swift` with 5-tier sections and badge system
2. Add GGUF download path to `ModelDownloadManager.swift`
3. Wire TurboQuant `--kv-bits` to MLX and `--cache-type-k q8_0` to GGUF
4. Add TurboQuant toggle to Settings

### Sprint 3: Cloud API Integration (Days 5-7)
1. Create `CloudProvider.swift` protocol
2. Create `AnthropicProvider.swift` with REAL tool calling
3. Create `OpenAIProvider.swift` (Responses API)
4. Create `GeminiProvider.swift`, `DeepSeekProvider.swift`, remaining providers
5. Create `CloudRouter.swift` — unified OpenAI-compatible dispatcher
6. Create `SubscriptionProxy.swift` for Claude Max session proxy
7. Add API key + subscription settings UI (Keychain storage)

### Sprint 4: Agent Overhaul (Days 8-10)
1. Create `EpistemosOperatingMode` with honest capability gating
2. Create `AgentModeSelectorView.swift` with `availableModes`
3. Create `DAGExecutor.swift` replacing linear ReAct loop
4. Fix Safari agent — add wait-for-load, AX tree verification, Screen2AX fallback
5. Create `Screen2AXService.swift` for visual grounding
6. Add grammar-constrained tool calling for local models

### Sprint 5: Computer Use + Live Agent (Days 11-13)
1. Create `ComputerUseService.swift` with ScreenCaptureKit
2. Wire to Anthropic Computer Use API (Opus/Sonnet only, beta header)
3. Implement CGEvent action execution (mouse, keyboard, scroll)
4. Wire screenshot scaling (1024x768 → native coordinates)
5. Create `LiveAgentView.swift` showing real-time agent observation + Kanban

### Sprint 6: SOAR Research + Memory (Days 14-15)
1. Create `TMSService.swift` with SOAR scoring + NLI
2. Add 4 SOAR tools to `OmegaToolRegistry.swift`
3. MCPBridge SQLite migration (soarScore, contradictionFlag, citationHash, modelHash)
4. Create `EpisodicMemory.swift`
5. Wire MCP tool layer for both local (stdio) + cloud (HTTP)
6. Add Prompt Repetition to `SystemPromptBuilder.swift`

### Sprint 7: Release Blockers + Polish (Days 16-17)
1. Populate release entitlements (exact XML above)
2. Create privacy manifest (exact XML above)
3. Fix deployment target to 15.0
4. Fix top 10 `try?` sites → `do/catch` with logging
5. Annotate top 50 unsafe blocks with `// SAFETY:`
6. Run full ASAN/TSAN/UBSAN sanitizer suite
7. Run all existing tests — ZERO regressions

---

## ACCEPTANCE CRITERIA (Every Item Must Be True)

### Models & Inference
- [ ] Model registry has ALL local models (original 6 + new additions) AND all cloud models
- [ ] Every model has `ramRequirementQ4GB`, `ramRequirementQ8GB?`, `activeParametersB` populated
- [ ] `ModelBackend.swift` exists with `.mlx`, `.gguf`, `.cloud` cases
- [ ] `GGUFInferenceService.swift` exists, compiles, runs IN-PROCESS (NO sidecar)
- [ ] Model picker shows 5 tier sections with RAM labels and badge colors
- [ ] Q4/Q8 buttons render in picker for each GGUF model row
- [ ] TurboQuant toggle wired to MLX via `--kv-bits` and GGUF via `--cache-type-k`
- [ ] oMLX bridge exists for oversized models
- [ ] `isComingSoon` models show gray badge, disabled download

### Agent System
- [ ] `EpistemosOperatingMode` has 5 modes: fast, thinking, research, agent, liveAgent
- [ ] Agent + liveAgent DISABLED for local models (honest capability gating)
- [ ] Thinking mode only for `supportsDualThinkMode` AND `activeParametersB >= 4.0`
- [ ] Research mode only for 4B+ thinking models
- [ ] Safari agent uses DAG execution + wait-for-load (not broken ReAct)
- [ ] Grammar-constrained decoding forces valid JSON from local models
- [ ] `DAGExecutor.swift` replaces linear ReAct loop
- [ ] `Screen2AXService.swift` provides visual fallback when AX tree sparse

### Cloud Integration
- [ ] `AnthropicProvider.swift` supports tool calling, computer use, extended thinking, MCP
- [ ] Opus dispatches sub-agents; Sonnet does not; Haiku has basic tool calling only
- [ ] `SubscriptionProxy.swift` enables Claude Max session-based access (labeled as advanced)
- [ ] Computer Use service provides continuous screen observation via ScreenCaptureKit
- [ ] MCP works for both local (stdio) and cloud (HTTP) models
- [ ] API keys stored in macOS Keychain, not UserDefaults
- [ ] Every model ID string verified against provider's official docs

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

1. **Local models cannot be agents.** Fundamental constraint of 4B-27B models on consumer hardware. Dual-Brain (local for thinking, cloud for doing) is correct.

2. **The app is local-first, cloud as a bonus.** Works completely offline. Cloud features are a premium extension.

3. **TurboQuant is KV cache compression, NOT weight compression.** Complements GGUF Q4_K_M weights by compressing runtime cache. ~44% cache reduction, ~30% throughput gain.

4. **Direct distribution first, Mac App Store later.** Omega agent system requires unsandboxed access. Ship notarized + Sparkle auto-updates.

5. **Subscription proxy is advanced/optional.** Power-user feature with clear ToS warnings.

## APPENDIX B: API VERIFICATION CHECKLIST

| Provider | Official Docs URL | Verify |
|---|---|---|
| Anthropic | platform.claude.com/docs | Model IDs, tool schemas, computer use beta header |
| OpenAI | developers.openai.com | Responses API format, Assistants deprecation |
| Google | ai.google.dev/gemini-api | Free tier availability, model list |
| DeepSeek | api-docs.deepseek.com | OpenAI compat, reasoner endpoint |
| Mistral | docs.mistral.ai | FIM endpoint, agents API (beta) |
| Cohere | docs.cohere.com | v2 API, rerank/embed endpoints |

## APPENDIX C: SWIFT SDK STATUS (DO NOT HALLUCINATE)

| Provider | Official Swift SDK? | What to use instead |
|---|---|---|
| Anthropic | ❌ NO | Raw URLSession to Messages API |
| OpenAI | ❌ NO | Raw URLSession (or community MacPaw/OpenAI) |
| Google | ⚠️ Firebase AI Logic only | FirebaseAILogic or REST API |
| Meta | ✅ YES | llama-stack-client-swift |
| Apple MLX | ✅ YES | mlx-swift, mlx-swift-lm |
| MCP | ✅ YES (Tier 3) | modelcontextprotocol/swift-sdk |
| All others | ❌ NO | Raw URLSession or OpenAI-compat client |

## APPENDIX D: REFERENCED RESEARCH

- TurboQuant: arXiv 2504.19874 (Google Research, ICLR 2026)
- PolarQuant: Stage 1 of TurboQuant — Hadamard rotation + Lloyd-Max quantization
- QJL: Stage 2 of TurboQuant — Quantized Johnson-Lindenstrauss projection
- Prompt Repetition: arXiv 2512.14982 (Leviathan et al., Google Research)
- REAP Expert Pruning: arXiv 2510.13999 (Cerebras, ICLR 2026)
- Gemma 3 QAT: Google Developers Blog (2025)
- QuIP#: 2-bit weight quantization via Hadamard incoherence + E8 lattice codebooks
- HQQ: Half-Quadratic Quantization — calibration-free, fast, 2-4 bit
- BitNet b1.58: Microsoft ternary weights {-1, 0, 1}
- EAGLE: Speculative decoding via feature-level autoregression — 3× speedup
- Token Recycling: Train-free speculative decoding — 2× speedup, <2MB overhead
- metal-flash-attention: Philip Turner's Metal FlashAttention — 2-4× faster than MLX
- metalQwen3: Complete Metal transformer implementation (BoltzmannEntropy)
- ZMLX: Triton-style kernel toolkit for MLX — fused MoE kernels +12% decode
- oMLX SSD Caching: github.com/jundot/omlx
- LocalLLMClient: github.com/tattn/LocalLLMClient
- OmniParser V2: Microsoft Research (YOLOv8 + Florence-2 for Screen2AX)
- Screen2AX: Hybrid AX tree + visual grounding architecture
- Karpathy Autoresearch Loop: Referenced in Cognitive OS Blueprint
- MCP Specification: modelcontextprotocol.io (version 2025-11-25)
- LLM in a Flash: Apple ICLR 2025 — FFN sparsity for flash storage inference

---

*This specification is the FUSED v3.0 — combining the original megaprompt (v1.0) with three rounds of deep research (API verification, quantization frontier, native Rust+Metal stack). Every code snippet, model ID, RAM requirement, capability flag, API endpoint, and research citation has been cross-referenced. Nothing from v1.0 was dropped. Last updated: March 28, 2026.*
