# Local Model Stack Architecture Advice for Epistemos
## Deep Research: Gemma 4, Qwopus/Qwen3.5, MCP, Ollama, llama.cpp, OpenRouter

**Date:** April 7, 2026  
**Context:** Expanding Epistemos local model infrastructure with frontier quantized models  
**Target Hardware:** M2 Pro 18GB (primary), 24-48GB+ Macs (secondary tier)

---

## Executive Summary

Your current local model stack uses MLX-native Qwen 3.5 variants (0.8B to 35B-A3B MoE) via `MLXInferenceService`. To achieve a "very robust and capable local setup," you should expand into **three parallel tracks**:

1. **GGUF/Ollama Bridge** — For Qwopus variants (Jackrong's Claude-distilled Qwen) and Gemma 4 REAP
2. **MLX-Continued** — For Gemma 4 variants via vMLX (requires vMLX 1.3.26+)
3. **MCP-Native Orchestration** — For tool-calling agent workflows with local models

---

## Part 1: Model Comparison — Your Linked Hugging Face Repos

### 1.1 Qwopus Family (Claude Opus 4.6 Distilled)

| Model | Size | Quant | VRAM | M2 Pro 18GB? | Best For |
|-------|------|-------|------|--------------|----------|
| **Jackrong/Qwopus3.5-27B-v3** | 54GB | BF16 | ~56GB | ❌ No | Source weights only |
| **Qwopus3.5-27B-v3-GGUF Q4_K_M** | 16.5GB | GGUF 4-bit | ~18GB | ⚠️ Tight | **Primary coding/tool-calling** |
| **Qwopus3.5-27B-v3-GGUF Q3_K_M** | ~13GB | GGUF 3-bit | ~14GB | ✅ Yes | Conservative 18GB option |
| **PolarQuant-Q5** | 16.2GB | PQ5 | ~17GB | ⚠️ Tight | Best quality-per-bit (needs torchao) |
| **TQ3_4S** | ~13GB | TQ3_4S | ~14GB | ✅ Yes | Experimental, needs custom llama.cpp fork |
| **Qwopus-MoE-35B-A3B-GGUF** | 20GB | GGUF Q4 | ~21GB | ❌ No | **24GB+ tier — fastest MoE** |

**Key Finding:** Qwopus v3 achieves **95.73% on HumanEval** (157/164) — the highest strict score among all Qwen variants. It uses "Act-Then-Refine" paradigm: execute tool calls early, refine based on feedback — ideal for agentic workflows.

**Recommended for M2 Pro 18GB:**
- Primary: `Qwopus3.5-27B-v3-GGUF` at **Q3_K_M** (~13GB) — leaves 5GB headroom for KV cache
- Experimental: `TQ3_4S` variant if you can bundle the custom `turbo-tan/llama.cpp-tq3` runtime

### 1.2 Gemma 4 Family (Google + Community)

| Model | Size | Quant | VRAM | M2 Pro 18GB? | Best For |
|-------|------|-------|------|--------------|----------|
| **gemma-4-21b-a4b-it-REAP** | 43GB | BF16 | ~43GB | ❌ No | Source (needs GGUF conversion) |
| **gemma-4-21b-a4b-it-REAP-GGUF** | ~15GB | GGUF Q4 | ~16GB | ✅ Yes | **Best multimodal on 18GB** |
| **Gemma-4-31B-JANG_4M-CRACK** | 18GB | JANG 5.1-bit | ~18GB | ⚠️ Tight | **Abliterated, MLX-native** |
| **Gemma-4-31B-IT-NVFP4** | 32.7GB | NVFP4 | ~33GB | ❌ No | Blackwell GPUs only |
| **Intel/gemma-4-31B-int4-AutoRound** | 19.2GB | INT4 | ~20GB | ❌ No | Intel/vLLM servers |

**REAP Pruning Explained:**
- Removes 20% of MoE experts (25 of 128 per layer) based on activation patterns
- Total params: 26B → 21.34B, but **active params stay ~4B** per token
- **12/14 blind quality comparisons tied** with original — essentially same quality, 18% smaller
- Context window: 262K tokens (massive)
- Multimodal: Yes (text + vision)

**JANG_4M CRACK Explained:**
- Abliterated (refusal removal) via MPOA magnitude-preserving surgery
- Mixed precision: 8-bit for attention (Q/K/V/O), 4-bit for MLP layers = 5.1-bit average
- **MMLU: 74.5%** (only -2% vs base), **HarmBench compliance: 93.7%**
- Requires **vMLX 1.3.26+** — standard `mlx_lm` doesn't support Gemma 4 yet

### 1.3 Recommended Tiered Stack

```
TIER 1 — M2 Pro 18GB (Your Machine):
├── Primary Coding: Qwopus3.5-27B-v3-GGUF Q3_K_M (~13GB)
├── Primary Multimodal: gemma-4-21b-a4b-it-REAP-GGUF Q4 (~15GB)  
└── Experimental: Gemma-4-31B-JANG_4M-CRACK (18GB, vMLX)

TIER 2 — 24-32GB Macs:
├── Qwopus3.5-27B-v3-GGUF Q4_K_M (16.5GB) — full quality
├── Qwopus-MoE-35B-A3B-GGUF Q4_K_M (20GB) — fastest MoE
└── gemma-4-26B-A4B-GGUF Q4 (~18GB) — original Google MoE

TIER 3 — 48GB+ / Servers:
├── Qwopus-MoE-35B-A3B-GGUF Q6_K (27GB)
├── gemma-4-31B-GGUF Q4 (~20GB)
└── nvidia/Gemma-4-31B-IT-NVFP4 (Blackwell only)
```

---

## Part 2: MCP (Model Context Protocol) Architecture

### 2.1 What MCP Solves

Your current `TriageService` routes between Apple Intelligence and local MLX. MCP extends this to **arbitrary tool ecosystems**:

```
Current: User → TriageService → (Apple Intelligence | Local MLX)
MCP:     User → TriageService → MCP Client → MCP Servers → (Filesystem, DB, Browser, APIs)
```

**Key Benefits:**
- **Tool discovery:** Models discover capabilities at runtime, not hardcoded
- **Standardized:** One protocol for 500+ tools (Postgres, Slack, Puppeteer, etc.)
- **Local-first:** MCP servers run locally via stdio; no cloud required
- **Agent-ready:** Natural fit for Qwopus's "Act-Then-Refine" paradigm

### 2.2 MCP Architecture for Epistemos

```swift
// New Component: MCPClientService
@MainActor
final class MCPClientService {
    // Manages MCP client connections to various servers
    var servers: [MCPConnection] = []
    
    // Discovers tools from all connected servers
    func discoverTools() async -> [MCPToolDefinition]
    
    // Executes tool calls from model responses
    func executeTool(_ call: ToolCall) async throws -> ToolResult
}

// Integration with TriageService
extension TriageService {
    func streamWithMCP(
        prompt: String,
        mcpTools: [MCPToolDefinition]? = nil
    ) -> AsyncThrowingStream<String, Error> {
        // If tools provided, inject into system prompt
        // Model can then emit tool calls as JSON
        // MCPClientService executes and returns results
        // Continue loop until final response
    }
}
```

### 2.3 MCP Transport Options

| Transport | Use Case | Implementation |
|-----------|----------|----------------|
| **stdio** | Local servers (filesystem, shell, browser) | Spawn process, pipe JSON-RPC |
| **Streamable HTTP** | Remote/cloud MCP servers | HTTP + SSE |
| **TCP (custom)** | Local bridge to Ollama/llama.cpp | Loopback with auth |

**For Epistemos:** Start with **stdio** for local tools, **TCP bridge** for Ollama/llama.cpp integration.

### 2.4 MCP + Ollama Integration Pattern

```bash
# Ollama serves GGUF models with OpenAI-compatible API
ollama serve
ollama pull qwopus:27b-v3-q4_k_m

# MCP bridge exposes Ollama to Epistemos
mcp-server-ollama-bridge --endpoint http://localhost:11434
```

```swift
// Epistemos MCP Client configuration
let ollamaMCPServer = MCPServerConfiguration(
    name: "ollama-local",
    transport: .stdio(command: "mcp-server-ollama-bridge"),
    tools: [.textCompletion, .chatCompletion]
)
```

---

## Part 3: Ollama vs llama.cpp vs MLX — Backend Strategy

### 3.1 Comparison Matrix

| Feature | MLX (Current) | Ollama | llama.cpp |
|---------|---------------|--------|-----------|
| **Apple Silicon** | ✅ Native | ✅ Excellent | ✅ Good |
| **GGUF Support** | ❌ No (needs conversion) | ✅ Native | ✅ Native |
| **Speed** | Fastest on Apple | Fast | 1.5x faster than Ollama (tuned) |
| **Tool Calling** | ⚠️ Manual | ✅ Native OpenAI-style | ✅ With --jinja |
| **MCP Integration** | Custom | Via bridge | Via bridge |
| **Model Management** | Manual | Auto-download, manage | Manual |
| **Quant Options** | 4/8-bit | All GGUF | All GGUF + experimental (TQ3) |

### 3.2 Recommended Backend Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                    Epistemos Backend Layer                   │
├─────────────────────────────────────────────────────────────┤
│  Tier 1: MLX (keep current)                                  │
│  ├── Qwen3.5 0.8B-27B (existing)                            │
│  └── Gemma 4 via vMLX 1.3.26+ (future)                      │
│                                                              │
│  Tier 2: Ollama Bridge (new)                                 │
│  ├── Qwopus 27B-v3 GGUF                                     │
│  ├── Qwopus MoE 35B-A3B GGUF                                │
│  └── Gemma 4 REAP GGUF                                      │
│                                                              │
│  Tier 3: llama.cpp (power user/advanced)                     │
│  ├── TurboQuant (TQ3_4S) experimental                       │
│  └── APEX/MoE-optimized quants                              │
└─────────────────────────────────────────────────────────────┘
```

### 3.3 Implementation: Ollama Bridge Service

```swift
// MARK: - Ollama Bridge Service

import Foundation

actor OllamaBridgeService: LocalMLXRuntime {
    private let endpoint: URL
    private let modelName: String
    private let session: URLSession
    
    init(endpoint: URL = URL(string: "http://localhost:11434")!,
         modelName: String = "qwopus:27b-v3-q4_k_m") {
        self.endpoint = endpoint
        self.modelName = modelName
        self.session = URLSession(configuration: .default)
    }
    
    func generate(request: LocalMLXRequest) async throws -> String {
        let url = endpoint.appendingPathComponent("api/generate")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = OllamaGenerateRequest(
            model: modelName,
            prompt: request.prompt,
            system: request.systemPrompt,
            stream: false,
            options: [
                "temperature": 0.6,
                "top_k": 20,
                "num_predict": request.maxTokens
            ]
        )
        
        urlRequest.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: urlRequest)
        let generateResponse = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
        return generateResponse.response
    }
    
    func stream(request: LocalMLXRequest) async -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = endpoint.appendingPathComponent("api/generate")
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let body = OllamaGenerateRequest(
                        model: modelName,
                        prompt: request.prompt,
                        system: request.systemPrompt,
                        stream: true,
                        options: [
                            "temperature": 0.6,
                            "top_k": 20,
                            "num_predict": request.maxTokens
                        ]
                    )
                    
                    urlRequest.httpBody = try JSONEncoder().encode(body)
                    
                    let (bytes, _) = try await session.bytes(for: urlRequest)
                    
                    for try await line in bytes.lines {
                        if let data = line.data(using: .utf8),
                           let chunk = try? JSONDecoder().decode(OllamaStreamChunk.self, from: data) {
                            continuation.yield(chunk.response)
                            if chunk.done { break }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    
    func unload() async {
        // Ollama manages its own memory; optional: call /api/generate with keep_alive: 0
    }
}

// Request/Response types
struct OllamaGenerateRequest: Codable {
    let model: String
    let prompt: String
    let system: String?
    let stream: Bool
    let options: [String: AnyCodable]
}

struct OllamaGenerateResponse: Codable {
    let response: String
    let done: Bool
}

struct OllamaStreamChunk: Codable {
    let response: String
    let done: Bool
}
```

---

## Part 4: OpenRouter Integration

### 4.1 Why OpenRouter

OpenRouter provides **unified API access** to frontier models (GPT-5.4, Claude Opus 4.6, Gemini 3.1) with:
- Automatic fallback routing
- Cost-optimized model selection
- OpenAI-compatible API (drop-in replacement)

### 4.2 Integration Pattern

```swift
// OpenRouter as Cloud Tier in TriageService
enum CloudModelTier {
    case openrouter(model: OpenRouterModel)
    case directOpenAI
    case directAnthropic
}

enum OpenRouterModel: String {
    case gpt5_4 = "openai/gpt-5.4"
    case claudeOpus46 = "anthropic/claude-opus-4.6"
    case geminiPro31 = "google/gemini-pro-3.1"
    
    var complexityThreshold: Double {
        switch self {
        case .gpt5_4: return 0.70
        case .claudeOpus46: return 0.80
        case .geminiPro31: return 0.75
        }
    }
}

// Triage logic extension
extension InferencePolicyEngine {
    func shouldRouteToOpenRouter(
        profile: InferenceRequestProfile,
        localSelection: LocalModelSelection?
    ) -> OpenRouterModel? {
        // If complexity > local model capability, use OpenRouter
        let complexity = complexityTier(for: profile)
        switch complexity {
        case .extreme:
            return .claudeOpus46
        case .heavy where localSelection == nil:
            return .gpt5_4
        default:
            return nil
        }
    }
}
```

---

## Part 5: Concrete Implementation Roadmap

### Phase 1: Ollama Bridge (Week 1-2)

1. **Add OllamaBridgeService** — OpenAI-compatible HTTP client for Ollama
2. **Extend LocalModelCatalog** — Add Qwopus GGUF descriptors
3. **Update TriageService** — Route to Ollama for GGUF models
4. **UI: Model Provider Toggle** — Let users choose MLX vs Ollama per model

### Phase 2: MCP Foundation (Week 3-4)

1. **Add MCPClientService** — Manage MCP server lifecycle
2. **Implement stdio transport** — For local MCP servers
3. **Create filesystem MCP bridge** — First tool: vault file operations
4. **Tool calling parser** — Parse JSON tool calls from model outputs

### Phase 3: Advanced Quantization (Week 5-6)

1. **Evaluate PolarQuant** — Torchao integration for Q5 quality at Q4 size
2. **Evaluate TurboQuant** — Custom llama.cpp fork for TQ3_4S
3. **vMLX Integration** — For Gemma 4 JANG_4M support
4. **Benchmark suite** — Compare perplexity, speed, memory across quants

### Phase 4: Agent Orchestration (Week 7-8)

1. **Qwopus + MCP integration** — Leverage "Act-Then-Refine" paradigm
2. **Multi-turn tool loops** — Automatic tool execution + re-prompting
3. **Planning service** — Break complex tasks into tool sequences
4. **OpenRouter fallback** — When local models hit complexity limits

---

## Part 6: Specific Model Recommendations

### Immediate Additions (This Week)

```swift
// Add to LocalModelCatalog.textDescriptors:

// Qwopus 27B v3 — Best coding/tool-calling for 18GB
LocalModelDescriptor(
    id: "ollama/qwopus-27b-v3-q3_k_m",
    kind: .text,
    displayName: "Qwopus 27B v3 (Q3_K_M)",
    familyName: "Qwopus",
    summary: "Claude Opus 4.6 distilled. Best coding/tool-calling for 18GB Macs.",
    approximateDownloadBytes: 13_000_000_000,
    minimumRecommendedMemoryGB: 18,
    revision: "v3-q3km",
    matchingGlobs: ["*.gguf"],
    backend: .ollama  // New field needed
),

// Gemma 4 21B REAP — Best multimodal for 18GB  
LocalModelDescriptor(
    id: "ollama/gemma-4-21b-reap-q4",
    kind: .text,
    displayName: "Gemma 4 21B REAP (Q4)",
    familyName: "Gemma 4",
    summary: "Pruned MoE with 262K context. Best multimodal on 18GB.",
    approximateDownloadBytes: 15_000_000_000,
    minimumRecommendedMemoryGB: 18,
    revision: "reap-q4",
    matchingGlobs: ["*.gguf"],
    backend: .ollama
)
```

### Hardware Tier Recommendations

```swift
enum HardwareTier {
    case tier1_18GB   // M2 Pro, M3 base
    case tier2_24GB   // M3 Pro
    case tier3_32GB   // M3 Max
    case tier4_48GB   // M4 Max, Mac Studio
    
    var recommendedModels: [LocalTextModelID] {
        switch self {
        case .tier1_18GB:
            return [.qwopus27BQ3KM, .gemma4_21B_REAP_Q4, .qwen35_4B4Bit]
        case .tier2_24GB:
            return [.qwopus27BQ4KM, .qwopusMoE35B_Q4, .gemma4_26B_Q4]
        case .tier3_32GB:
            return [.qwopus27BQ5KM, .qwopusMoE35B_Q5, .gemma4_31B_JANG]
        case .tier4_48GB:
            return [.qwopusMoE35B_Q6, .gemma4_31B_Q4, .llama4Scout]
        }
    }
}
```

---

## Part 7: Key Technical Decisions

### Decision 1: MLX vs Ollama for GGUF

**Recommendation:** Use **Ollama** for GGUF models, keep **MLX** for native MLX models.

**Rationale:**
- Ollama handles GGUF natively without conversion
- Users can `ollama pull` models independently
- Easier to update models (just restart Ollama)
- Cleaner separation: MLX = Apple-native, Ollama = universal

### Decision 2: PolarQuant vs Standard GGUF

**Recommendation:** Start with standard GGUF (Q4_K_M), evaluate PolarQuant as "quality mode".

**Rationale:**
- GGUF Q4_K_M has universal compatibility
- PolarQuant requires torchao/PolarEngine (extra dependency)
- PolarQuant Q5 at 16.2GB vs GGUF Q4_K_M at 16.5GB — marginal size difference
- Benchmark first: if PolarQuant shows >5% quality gain, add as option

### Decision 3: MCP Adoption Strategy

**Recommendation:** Implement MCP client-side first, add server bridge later.

**Rationale:**
- Many existing tools already have MCP servers
- Epistemos can consume them without building custom servers
- stdio transport is simple and secure (local only)
- Later: expose Epistemos capabilities as MCP server for Claude Code integration

### Decision 4: OpenRouter as Primary Cloud

**Recommendation:** Make OpenRouter the default cloud tier, keep direct APIs as fallbacks.

**Rationale:**
- Single API key for multiple providers
- Automatic fallback if one provider fails
- Cost routing (can specify "cheapest" vs "best quality")
- OpenAI-compatible API = minimal code changes

---

## Part 8: Resources & References

### Model Cards
- [Jackrong/Qwopus3.5-27B-v3](https://huggingface.co/Jackrong/Qwopus3.5-27B-v3) — Main Qwopus
- [samuelcardillo/Qwopus-MoE-35B-A3B-GGUF](https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B-GGUF) — MoE variant
- [0xSero/gemma-4-21b-a4b-it-REAP](https://huggingface.co/0xSero/gemma-4-21b-a4b-it-REAP) — Pruned Gemma 4
- [dealignai/Gemma-4-31B-JANG_4M-CRACK](https://huggingface.co/dealignai/Gemma-4-31B-JANG_4M-CRACK) — Abliterated MLX

### MCP Resources
- [MCP Spec](https://modelcontextprotocol.io) — Official specification
- [MCP Inspector](https://github.com/modelcontextprotocol/inspector) — Debug tool
- [Awesome MCP Servers](https://github.com/punkpeye/awesome-mcp-servers) — 500+ servers

### Quantization Papers
- [PolarQuant](https://arxiv.org/abs/2603.29078) — Hadamard rotation + Lloyd-Max
- [REAP](https://arxiv.org/abs/2510.13999) — Router-weighted expert pruning

### Integration Examples
- [byte-vision-mcp](https://github.com/kbrisso/byte-vision-mcp) — Go MCP server for llama.cpp
- [Vesta macOS](https://github.com/scouzi1966/vesta-mac-dist) — SwiftUI + MLX + MCP reference

---

## Summary

To build the "best possible local stack":

1. **Immediate:** Add Ollama bridge for Qwopus 27B v3 Q3_K_M (best coding on 18GB)
2. **Short-term:** Add Gemma 4 REAP GGUF (best multimodal on 18GB)
3. **Medium-term:** MCP client integration for tool-calling workflows
4. **Long-term:** PolarQuant evaluation, vMLX Gemma 4 support, OpenRouter cloud tier

The combination of **Qwopus (coding/tool-calling) + Gemma 4 (multimodal/long-context) + MCP (tool ecosystem)** gives you a local stack competitive with cloud APIs for most tasks, with OpenRouter as the safety net for extreme complexity.
