# Epistemos: Low-Memory Model Expansion + TurboQuant Implementation Guide for Claude Code

> **Audience:** Claude Code (automated implementation agent)
> **Machine:** M2 Pro MacBook (base model — 16GB unified memory, 200 GB/s bandwidth)
> **Goal:** Add all models from the upgrade plan, implement TurboQuant KV cache compression, and make every model faster

***

## Executive Summary

Your M2 Pro has 16GB unified memory. The models you want to run range from 8GB to 64GB+. The solution has three mutually reinforcing layers:

1. **GGUF/llama.cpp backend** — required for all new non-MLX models; llama.cpp natively uses Apple Metal GPU acceleration and can partially offload layers to SSD when RAM is exceeded
2. **TurboQuant KV cache compression** — Google Research's new algorithm (ICLR 2026) compresses the KV cache by 6x and achieves up to 8x speedup with zero accuracy loss; an MLX port already exists on HuggingFace
3. **oMLX paged SSD caching** — tiered RAM/SSD KV cache that lets you run 27B+ models on 16GB by offloading cold cache blocks to NVMe, reducing Time To First Token from 90 seconds to 1–3 seconds

On your M2 Pro 16GB with Q4_K_M quantization, the practical performance picture per model is:[^1][^2][^3]

| Model | Backend | Q4 RAM | M2 Pro 16GB Viable? | Estimated tok/s |
|---|---|---|---|---|
| Qwen 3.5 0.8B | MLX | 8GB | ✅ Excellent | ~80 t/s |
| Qwen 3.5 2B | MLX | 10GB | ✅ Excellent | ~60 t/s |
| Qwen 3.5 4B | MLX | 12GB | ✅ Good | ~43 t/s |
| SmolLM3 3B | MLX/GGUF | 8GB | ✅ Excellent | ~55 t/s |
| Phi-4 14B | GGUF | 12GB | ✅ Good | ~15 t/s |
| Qwen 3.5 9B | MLX | 16GB | ✅ Tight fit | ~23 t/s |
| Gemma 3 27B QAT | GGUF | 16GB | ✅ Tight fit | ~10–15 t/s |
| Devstral Small 2 24B | GGUF | 16GB | ✅ Tight fit | ~10 t/s |
| Mistral Small 3.1 24B | GGUF | 16GB | ✅ Tight fit | ~10 t/s |
| Qwen 3.5 27B Opus-Distilled | GGUF | 20GB | ⚠️ Needs SSD offload | ~4–8 t/s w/ offload |
| Qwen 3.5 28B-A3B REAP | GGUF | 20GB | ⚠️ Needs SSD offload | ~6–9 t/s w/ offload (MoE) |
| Qwen 3.5 27B (MLX 4bit) | MLX | 20GB | ⚠️ Needs SSD offload | ~8 t/s w/ offload |
| Qwen 3.5 35B-A3B | MLX | 32GB | ❌ Too large for 16GB | N/A |
| Qwen 3.5 40B Opus Uncensored | GGUF | 24GB | ❌ Too large for 16GB | N/A |
| Llama 4 Scout (109B MoE) | MLX | 64GB | ❌ Too large for 16GB | N/A |

**With TurboQuant + oMLX SSD offload**, the "⚠️ Needs SSD offload" models become viable. Enable the `isComingSoon` flag on the ❌ models.[^4][^5][^6]

***

## Part 1: M2 Pro Hardware Reality Check

### What You Have

The M2 Pro has 200 GB/s memory bandwidth and 16–32GB unified memory. On this hardware, token generation speed is purely a function of memory bandwidth: a 27B Q4 model at ~14GB consumes 14GB × bandwidth, so at 200 GB/s you get roughly 14 tokens per second. The M2 Pro with 16 GPU cores achieves approximately 37.87 tokens/second at Q4_0 on a 7B model and ~15 tokens/second on a 14B model.[^7][^2][^1]

### The Critical Insight: Unified Memory = Advantage

Apple Silicon's unified memory architecture means CPU, GPU, and Neural Engine share the same physical memory pool — zero cross-memory copies. llama.cpp on Metal can achieve 40 tokens/second on a 7B Q4 model at 0% CPU usage by fully using GPU cores. MLX goes further by using lazy evaluation and operation fusion that llama.cpp cannot match on Mac due to its cross-platform design.[^8][^6][^9]

### Memory Thresholds for 16GB

- **Runs great (≤12GB Q4):** All models up to Phi-4 14B
- **Tight fit (13–16GB Q4):** Qwen 3.5 9B, Gemma 3 27B QAT, Devstral 24B, Mistral Small 3.1 24B — these require closing other apps
- **Needs SSD offload (17–24GB Q4):** Qwen 3.5 27B variants — use llama.cpp `--n-gpu-layers` partial offload or oMLX paged SSD caching
- **Out of range (>24GB Q4):** Disable in picker, show `isComingSoon` badge unless user has upgraded RAM

### Gemma 3 27B QAT: The Secret Weapon for 16GB

Google's Gemma 3 27B QAT (Quantization-Aware Training) is designed specifically to run a full 27B model in 16GB of memory. Because quantization was applied during training — not after — the 4-bit weights preserve bfloat16 quality, making it the highest-quality model that fits on your 16GB machine without SSD offload.

***

## Part 2: TurboQuant — What It Is and How to Integrate It

### The Algorithm

Google Research published TurboQuant on March 25, 2026, to be presented at ICLR 2026. It is a data-oblivious KV cache quantization framework that:[^10]

- Compresses the KV cache to **3 bits** without requiring training or fine-tuning[^4]
- Achieves **6x memory reduction** in the KV cache (the dominant memory consumer during long-context inference)[^11][^10]
- Delivers **up to 8x speedup** in computing attention logits on H100 GPUs[^10][^4]
- Achieves **100% retrieval accuracy** on Needle-In-A-Haystack up to 104k tokens under 4x compression[^11]
- Introduces **zero accuracy loss** — matches full-precision performance on all LongBench tasks[^10]

The algorithm uses two stages: PolarQuant (converts vectors from Cartesian to polar coordinates, skipping per-block normalization overhead) and Quantized Johnson-Lindenstrauss (1-bit error correction on the residual). It requires no dataset-specific calibration.[^10]

### Apple Silicon Reality: Speedup is Different from H100

The 8x speedup figure is measured on Nvidia H100 GPUs. On Apple Silicon M2/M3/M4, the speedup profile is different because unified memory eliminates the HBM↔SRAM transfer bottleneck that TurboQuant targets most aggressively. The community-ported MLX implementation of TurboQuant (flovflo/turboquant-mlx-qwen35-kv) reports on Apple Silicon:[^5][^4]

- **+32.0% prompt throughput**
- **+25.7% decode throughput**
- **-26.0% generation wall time**
- **-43.7% KV cache size**

This is still a massive improvement — nearly double the context length for the same memory footprint. A 27B model running at 8K context on 16GB can potentially run 14K context with TurboQuant enabled.[^5]

### MLX Integration Path

An active community effort is porting TurboQuant to mlx-lm. A GitHub issue has been opened against the official mlx-lm repository requesting PolarQuant KV cache compression. Until this merges into the official mlx-lm release, Claude Code should implement the `KVCacheConfig` struct as a feature-flag that activates the Python-level `kvbits` parameter when available.[^12]

**Implementation in `MLXInferenceService.swift`:**

```swift
// File: Epistemos/Services/Inference/KVCacheConfig.swift

/// KV cache quantization configuration.
/// Mirrors the approach from Google's TurboQuant paper (ICLR 2026) and
/// the community MLX port at flovflo/turboquant-mlx-qwen35-kv.
struct KVCacheConfig: Codable, Sendable {
    /// Number of bits for key/value cache quantization.
    /// 4 → ~6x memory reduction, ~+25-32% throughput on Apple Silicon
    /// 8 → ~3x reduction, negligible quality impact
    /// 16 → no compression (current default)
    var quantizationBits: Int = 4
    
    /// Maximum context window to maintain in compressed cache
    var maxCachedTokens: Int = 50_000
    
    /// Use TurboQuant's PolarQuant stage (requires mlx-lm >= 0.21 or flovflo fork)
    var usePolarQuant: Bool = false
    
    static let turboQuant = KVCacheConfig(
        quantizationBits: 4, 
        maxCachedTokens: 50_000, 
        usePolarQuant: true
    )
    static let standard = KVCacheConfig(
        quantizationBits: 16, 
        maxCachedTokens: 8_192, 
        usePolarQuant: false
    )
    static let balanced = KVCacheConfig(
        quantizationBits: 8, 
        maxCachedTokens: 32_000, 
        usePolarQuant: false
    )
}
```

**Wiring to MLX Python inference script:**

```swift
// MODIFY MLXInferenceService.swift — add kvCacheConfig parameter
// Pass to Python inference via SwiftPython bridge or subprocess args

func generateStream(
    prompt: String,
    maxTokens: Int = 2048,
    temperature: Float = 0.7,
    thinkMode: Bool = false,
    kvCacheConfig: KVCacheConfig = .turboQuant,  // NEW
    onToken: @escaping (String) -> Void
) async throws -> String {
    // Existing MLX call — add kvbits parameter:
    // --kv-bits 4 (when mlx-lm >= 0.21)
    // Until available: use existing QuantizedKVCache with q4 group size 64
    let kvBitsArg = kvCacheConfig.quantizationBits == 16 ? "" : "--kv-bits \(kvCacheConfig.quantizationBits)"
    // ... rest of existing generateStream implementation
}
```

**Settings UI toggle (add to existing Settings panel):**

```swift
// MODIFY Settings view — add TurboQuant toggle
Section("Inference Performance") {
    Toggle(isOn: $turboQuantEnabled) {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("TurboQuant KV Cache")
                    .font(.body)
                Text("6x smaller context cache · ~30% faster · ICLR 2026")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.yellow)
        }
    }
    .onChange(of: turboQuantEnabled) { _, enabled in
        UserDefaults.standard.set(enabled, forKey: "turboQuant.enabled")
        // Reload active model with new KV config
        Task { await inferenceService.reloadWithKVConfig(
            enabled ? .turboQuant : .standard
        )}
    }
}
```

***

## Part 3: GGUF Backend — The Core Blocker

### Why This Matters

The most important models in your upgrade plan — Qwen 3.5 27B Opus-Distilled, Gemma 3 27B QAT, Phi-4 14B, Devstral Small 2, Mistral Small 3.1 — are GGUF format and require llama.cpp inference. Your existing `MLXInferenceService` cannot load them. The GGUF backend must be built first.

### Integration Option A: LocalLLMClient Swift Package (Recommended)

`tattn/LocalLLMClient` is a production-grade Swift package that wraps both llama.cpp and MLX behind a unified interface — exactly what Epistemos needs. It supports both macOS and iOS, streaming via Swift Concurrency, multimodal, and exposes both `LocalLLMClientLlama` (llama.cpp) and `LocalLLMClientMLX` (Apple MLX) backends.[^13]

```yaml
# In project.yml (XcodeGen) — add to packages section:
packages:
  LocalLLMClient:
    url: https://github.com/tattn/LocalLLMClient
    version: latest
```

```swift
// File: Epistemos/Services/Inference/GGUFInferenceService.swift
import LocalLLMClientLlama

actor GGUFInferenceService {
    private var client: LlamaClient?
    private var loadedModelPath: String?
    
    // MARK: - Model Loading
    func loadModel(at path: URL, contextLength: Int = 8_192) async throws {
        let config = LlamaClient.Config(
            contextLength: contextLength,
            nGPULayers: 99  // Offload all layers to Apple Metal GPU
        )
        client = try await LlamaClient(modelPath: path, config: config)
        loadedModelPath = path.path
    }
    
    func unloadModel() async {
        client = nil
        loadedModelPath = nil
    }
    
    // MARK: - Inference (mirrors MLXInferenceService public API)
    func generateStream(
        prompt: String,
        maxTokens: Int = 2048,
        temperature: Float = 0.7,
        thinkMode: Bool = false,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        guard let client else { throw InferenceError.modelNotLoaded }
        
        // Inject <think> token for models that support it
        let fullPrompt = thinkMode ? "<think>\(prompt)" : prompt
        
        var fullOutput = ""
        for try await token in client.generateStream(prompt: fullPrompt, maxTokens: maxTokens, temperature: temperature) {
            onToken(token)
            fullOutput += token
        }
        return fullOutput
    }
    
    var isLoaded: Bool { loadedModelPath != nil }
}
```

### Integration Option B: llama.cpp XCFramework (Direct)

llama.cpp officially ships an XCFramework via Swift Package Manager — Apple Silicon is a first-class citizen with Metal + NEON + Accelerate optimization. Use this if you want lower-level control:[^14]

```swift
// Package.swift or project.yml
// .binaryTarget(
//     name: "LlamaFramework",
//     url: "https://github.com/ggml-org/llama.cpp/releases/download/b5046/llama-b5046-xcframework.zip",
//     checksum: "c19be78b5f00d8d29a25da41042cb7afa094cbf6280a225abe614b03b20029ab"
// )
```

### Backend Routing in LLMService

```swift
// MODIFY InferenceState.swift or LLMService.swift
// Add backend routing based on model.backend property

func generateStream(
    prompt: String,
    model: LocalTextModelID,
    thinkMode: Bool = false,
    onToken: @escaping (String) -> Void
) async throws -> String {
    switch model.backend {
    case .mlx:
        return try await mlxService.generateStream(
            prompt: prompt,
            maxTokens: maxTokens,
            thinkMode: thinkMode,
            kvCacheConfig: turboQuantEnabled ? .turboQuant : .standard,
            onToken: onToken
        )
    case .gguf:
        return try await ggufService.generateStream(
            prompt: prompt,
            maxTokens: maxTokens,
            thinkMode: thinkMode,
            onToken: onToken
        )
    }
}
```

***

## Part 4: oMLX SSD Caching — Running 27B on 16GB

### The Problem

Qwen 3.5 27B Q4 requires ~20GB — 4GB more than your 16GB machine. Without a strategy, macOS memory compression kills performance as it swaps to disk uncontrollably.[^1]

### The Solution: oMLX Paged SSD KV Cache

oMLX is an open-source Apple Silicon inference server that implements paged SSD KV cache — a two-tier hot/cold system where recent cache blocks stay in RAM and older blocks persist to SSD. When a prefix repeats, oMLX restores from SSD instead of recomputing, dropping Time To First Token from 30–90 seconds to 1–3 seconds.[^6][^15]

From the oMLX repo (`github.com/jundot/omlx`):
- Paged KV cache with block-based prefix sharing and copy-on-write
- SSD tiered caching that auto-offloads to "virtually unlimited context"
- Persistent cache blocks that survive server restarts
- Signed and notarized DMG, no terminal required, macOS 14+

**Integration for Epistemos:** Wire oMLX as an optional external inference backend via its OpenAI-compatible HTTP API. When the user enables "Large Model Mode" and selects a 27B+ model, route inference to oMLX rather than the in-process GGUFInferenceService.

```swift
// File: Epistemos/Services/Inference/OMLXBridgeService.swift
// Routes inference to a locally-running oMLX server for large models

struct OMLXBridgeService {
    static let defaultBaseURL = URL(string: "http://localhost:11435/v1")!
    
    /// Send a prompt to oMLX when the model exceeds available RAM
    func generateStream(
        prompt: String,
        model: LocalTextModelID,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        // Use OpenAI-compatible /chat/completions endpoint
        // oMLX handles all SSD caching transparently
        var request = URLRequest(url: defaultBaseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // ... standard streaming SSE implementation
    }
}
```

**When to activate:** Add a computed property `requiresExternalServer: Bool` to `LocalTextModelID` that returns `true` for models where `ramRequirementQ4GB > systemRAMGB`. Display a banner in the model picker warning the user to install oMLX for those models.

***

## Part 5: Complete `LocalTextModelID` Replacement

Replace the entire existing `LocalTextModelID.swift` file. This is the canonical source of truth for all 17 models:

```swift
// File: Epistemos/Models/LocalTextModelID.swift
// REPLACE ENTIRE FILE CONTENT

import Foundation

// NEW: inference backend enum (create ModelBackend.swift)
enum ModelBackend: String, Codable, Sendable {
    case mlx   // existing MLXInferenceService
    case gguf  // new GGUFInferenceService
    
    var supportsStreaming: Bool { true }
    var supportsGrammar: Bool { self == .gguf }  // llama.cpp gbnf grammar support
}

// NEW: quantization preference
enum ModelQuantization: String, CaseIterable, Codable {
    case q4 = "Q4"
    case q8 = "Q8"
    var displayLabel: String {
        switch self {
        case .q4: return "Q4 · Fast"
        case .q8: return "Q8 · Quality"
        }
    }
}

nonisolated enum LocalTextModelID: String, Codable, Sendable, CaseIterable {

    // MARK: Qwen 3.5 Core Family — MLX, existing
    case qwen35_0_8B4bit  = "mlx-community/Qwen3.5-0.8B-4bit"
    case qwen35_2B4bit    = "mlx-community/Qwen3.5-2B-4bit"
    case qwen35_4B4bit    = "mlx-community/Qwen3.5-4B-4bit"
    case qwen35_9B4bit    = "mlx-community/Qwen3.5-9B-4bit"
    case qwen35_27B4bit   = "mlx-community/Qwen3.5-27B-4bit"
    case qwen35_35BA3B4bit = "mlx-community/Qwen3.5-35B-A3B-4bit"

    // MARK: Qwen 3.5 Distilled / Pruned — GGUF, NEW
    case qwen35_27BOpusDistilled  = "Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF"
    case qwen35_28BA3BREAP        = "0xSero/Qwen-3.5-28B-A3B-REAP"
    case qwen35_40BOpusUncensored = "mradermacher/Qwen3.5-40B-Claude-4.6-Opus-Deckard-Heretic-Uncensored-Thinking-GGUF"

    // MARK: Mistral Family — GGUF, NEW
    case devstralSmall2_24B  = "mistralai/devstral-small-2-2512"
    case mistralSmall31_24B  = "mistralai/Mistral-Small-3.1-24B-Instruct-2503"

    // MARK: Google — GGUF, NEW
    case gemma3_27BQAT = "google/gemma-3-27b-it-qat-q4_0-gguf"

    // MARK: Microsoft — GGUF, NEW
    case phi4_14B = "microsoft/phi-4"

    // MARK: HuggingFace Small — MLX/GGUF, NEW
    case smolLM3_3B = "HuggingFaceTB/SmolLM3-3B"

    // MARK: Meta MoE — MLX, NEW (requires 64GB — isComingSoon)
    case llama4Scout_109BMoE = "mlx-community/meta-llama-Llama-4-Scout-17B-16E-4bit"

    // MARK: Coming Soon stubs
    case miniMaxM25     = "MiniMaxAI/MiniMax-M2.5"         // weights not yet public
    case chromaContext1_20B = "chroma-ai/Context-1-20B"    // may require registration

    // MARK: - Display Metadata
    var displayName: String {
        switch self {
        case .qwen35_0_8B4bit:         return "Qwen 3.5 0.8B"
        case .qwen35_2B4bit:           return "Qwen 3.5 2B"
        case .qwen35_4B4bit:           return "Qwen 3.5 4B"
        case .qwen35_9B4bit:           return "Qwen 3.5 9B"
        case .qwen35_27B4bit:          return "Qwen 3.5 27B"
        case .qwen35_35BA3B4bit:       return "Qwen 3.5 35B MoE"
        case .qwen35_27BOpusDistilled: return "Qwen 3.5 27B · Opus-Distilled"
        case .qwen35_28BA3BREAP:       return "Qwen 3.5 28B MoE · REAP"
        case .qwen35_40BOpusUncensored:return "Qwen 3.5 40B · Opus Uncensored"
        case .devstralSmall2_24B:      return "Devstral Small 2 (24B)"
        case .mistralSmall31_24B:      return "Mistral Small 3.1 (24B)"
        case .gemma3_27BQAT:           return "Gemma 3 27B · QAT"
        case .phi4_14B:                return "Phi-4 (14B)"
        case .smolLM3_3B:              return "SmolLM3 (3B)"
        case .llama4Scout_109BMoE:     return "Llama 4 Scout (17B active MoE)"
        case .miniMaxM25:              return "MiniMax M2.5"
        case .chromaContext1_20B:      return "Chroma Context-1 (20B)"
        }
    }

    var familyName: String {
        switch self {
        case .qwen35_0_8B4bit, .qwen35_2B4bit, .qwen35_4B4bit,
             .qwen35_9B4bit, .qwen35_27B4bit, .qwen35_35BA3B4bit,
             .qwen35_27BOpusDistilled, .qwen35_28BA3BREAP, .qwen35_40BOpusUncensored:
            return "Qwen"
        case .devstralSmall2_24B, .mistralSmall31_24B:  return "Mistral"
        case .gemma3_27BQAT:   return "Google"
        case .phi4_14B:        return "Microsoft"
        case .smolLM3_3B:      return "HuggingFace"
        case .llama4Scout_109BMoE: return "Meta"
        case .miniMaxM25:      return "MiniMax"
        case .chromaContext1_20B: return "Chroma"
        }
    }

    // MARK: - Inference Backend
    var backend: ModelBackend {
        switch self {
        case .qwen35_0_8B4bit, .qwen35_2B4bit, .qwen35_4B4bit,
             .qwen35_9B4bit, .qwen35_27B4bit, .qwen35_35BA3B4bit,
             .llama4Scout_109BMoE, .smolLM3_3B:
            return .mlx
        default:
            return .gguf
        }
    }

    // MARK: - RAM Requirements
    var ramRequirementQ4GB: Int {
        switch self {
        case .qwen35_0_8B4bit, .smolLM3_3B:    return 8
        case .qwen35_2B4bit:                    return 10
        case .qwen35_4B4bit, .phi4_14B:         return 12
        case .qwen35_9B4bit:                    return 16
        case .devstralSmall2_24B, .mistralSmall31_24B, .gemma3_27BQAT: return 16
        case .miniMaxM25, .chromaContext1_20B:  return 16
        case .qwen35_28BA3BREAP:                return 20  // MoE, only 3B active
        case .qwen35_27B4bit, .qwen35_27BOpusDistilled: return 20
        case .qwen35_40BOpusUncensored:         return 24
        case .qwen35_35BA3B4bit:                return 32
        case .llama4Scout_109BMoE:              return 64
        }
    }

    var ramRequirementQ8GB: Int? {
        switch self {
        case .smolLM3_3B:       return 4
        case .qwen35_0_8B4bit:  return 4
        case .phi4_14B:         return 18
        case .qwen35_9B4bit:    return 14
        case .devstralSmall2_24B, .mistralSmall31_24B, .gemma3_27BQAT: return 32
        case .qwen35_27BOpusDistilled: return 48
        case .qwen35_28BA3BREAP:       return 36
        case .qwen35_40BOpusUncensored: return 64
        // MLX core family: Q8 not separately available from mlx-community
        default: return nil
        }
    }

    // MARK: - Feature Capabilities
    var supportsDualThinkMode: Bool {
        switch self {
        case .qwen35_0_8B4bit, .qwen35_2B4bit, .qwen35_4B4bit,
             .qwen35_9B4bit, .qwen35_27B4bit, .qwen35_35BA3B4bit,
             .qwen35_27BOpusDistilled, .qwen35_28BA3BREAP,
             .qwen35_40BOpusUncensored, .smolLM3_3B:
            return true
        default:
            return false
        }
    }

    var isMoE: Bool {
        switch self {
        case .qwen35_35BA3B4bit, .qwen35_28BA3BREAP, .llama4Scout_109BMoE:
            return true
        default: return false
        }
    }

    var isCodeSpecialist: Bool {
        switch self {
        case .devstralSmall2_24B, .miniMaxM25, .chromaContext1_20B:
            return true
        default: return false
        }
    }

    var isUnrestrictedThinking: Bool { self == .qwen35_40BOpusUncensored }

    var isComingSoon: Bool {
        switch self {
        case .miniMaxM25, .chromaContext1_20B, .llama4Scout_109BMoE:
            return true
        default: return false
        }
    }

    var contextWindowK: Int {
        switch self {
        case .llama4Scout_109BMoE:   return 10_000 // 10M tokens
        case .devstralSmall2_24B:    return 256
        case .mistralSmall31_24B, .smolLM3_3B: return 128
        default: return 32
        }
    }

    // MARK: - GGUF File Names
    var ggufFileQ4: String? {
        switch self {
        case .qwen35_27BOpusDistilled:
            return "Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-Q4_K_M.gguf"
        case .qwen35_28BA3BREAP:
            return "Qwen-3.5-28B-A3B-REAP-Q4_K_M.gguf"
        case .qwen35_40BOpusUncensored:
            return "Qwen3.5-40B-Claude-4.6-Opus-Deckard-Heretic-Uncensored-Thinking-Q4_K_M.gguf"
        case .devstralSmall2_24B:
            return "devstral-small-2-2512-Q4_K_M.gguf"
        case .mistralSmall31_24B:
            return "Mistral-Small-3.1-24B-Instruct-2503-Q4_K_M.gguf"
        case .gemma3_27BQAT:
            return "gemma-3-27b-it-qat-q4_0.gguf"
        case .phi4_14B:
            return "phi-4-Q4_K_M.gguf"
        case .smolLM3_3B:
            return "SmolLM3-3B-Q4_K_M.gguf"
        default: return nil
        }
    }

    var ggufFileQ8: String? {
        switch self {
        case .qwen35_27BOpusDistilled:
            return "Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-Q8_0.gguf"
        case .qwen35_28BA3BREAP:
            return "Qwen-3.5-28B-A3B-REAP-Q8_0.gguf"
        case .qwen35_40BOpusUncensored:
            return "Qwen3.5-40B-Claude-4.6-Opus-Deckard-Heretic-Uncensored-Thinking-Q8_0.gguf"
        default: return nil
        }
    }

    // MARK: - Memory Tier
    var tier: ModelTier {
        switch ramRequirementQ4GB {
        case ...8:    return .ultraLight
        case 9...16:  return .efficient
        case 17...24: return .standard
        case 25...48: return .professional
        default:      return .maximum
        }
    }

    /// Whether this model needs external server (oMLX) on a 16GB machine
    func requiresExternalServer(systemRAMGB: Int) -> Bool {
        ramRequirementQ4GB > systemRAMGB
    }
}

// MARK: - Model Tiers
enum ModelTier: CaseIterable {
    case ultraLight, efficient, standard, professional, maximum

    var displayName: String {
        switch self {
        case .ultraLight:   return "Ultra Light"
        case .efficient:    return "Efficient"
        case .standard:     return "Standard"
        case .professional: return "Professional"
        case .maximum:      return "Maximum"
        }
    }

    var subtitle: String {
        switch self {
        case .ultraLight:   return "≤8GB · Runs on any Mac"
        case .efficient:    return "10–16GB"
        case .standard:     return "16–24GB"
        case .professional: return "24–48GB"
        case .maximum:      return "48GB+ · Mac Studio/Pro"
        }
    }

    var iconName: String {
        switch self {
        case .ultraLight:  return "hare"
        case .efficient:   return "bolt"
        case .standard:    return "cpu"
        case .professional: return "brain"
        case .maximum:     return "server.rack"
        }
    }

    var color: Color {
        switch self {
        case .ultraLight:  return .green
        case .efficient:   return .blue
        case .standard:    return .orange
        case .professional: return .purple
        case .maximum:     return .red
        }
    }
}
```

***

## Part 6: Model Selector UI

Create `LocalModelSelectorView.swift` as specified in the Complete Model Support plan. Key additions for M2 Pro 16GB awareness:

```swift
// MODIFY ModelRowView to show SSD offload badge for large models
// In the ModelRowView body:

let systemRAM = ProcessInfo.processInfo.physicalMemory.ramGB
let needsOffload = model.requiresExternalServer(systemRAMGB: systemRAM)
let isComingSoon = model.isComingSoon

// Show badge hierarchy:
if isComingSoon {
    badge("Coming Soon", color: .gray)
} else if needsOffload {
    badge("Needs oMLX", color: .orange)
    // Tapping badge opens oMLX install instructions
}
```

The RAM banner at the top of `LocalModelSelectorView` should dynamically read actual system RAM:

```swift
private var ramBanner: some View {
    HStack(spacing: 8) {
        Image(systemName: "memorychip")
        Text("Your Mac has \(systemRAM)GB unified memory")
        if turboQuantEnabled {
            Text("· TurboQuant ⚡️")
                .foregroundStyle(.yellow)
        }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
}
```

***

## Part 7: Prompt Repetition — Free Quality Boost

The Leviathan et al. (Google Research) Prompt Repetition technique improves non-reasoning model output quality at zero token cost by duplicating the user prompt in the system message. This applies to models without `supportsDualThinkMode`:

```swift
// MODIFY SystemPromptBuilder.swift or wherever system prompts are built

extension SystemPromptBuilder {
    /// Implements the Leviathan et al. Google Research Prompt Repetition technique.
    /// Only applies to non-thinking models — reasoning models already self-repeat via <think> tags.
    static func withPromptRepetition(
        baseSystemPrompt: String,
        userMessage: String,
        model: LocalTextModelID
    ) -> String {
        // Don't apply to thinking models — they already have superior self-correction
        guard !model.supportsDualThinkMode else { return baseSystemPrompt }
        return """
        \(baseSystemPrompt)
        
        The user's request is: \(userMessage)
        """
    }
}
```

***

## Part 8: ModelDownloadManager GGUF Extension

```swift
// MODIFY ModelDownloadManager.swift

extension ModelDownloadManager {
    
    /// Local file path for a GGUF model variant
    func ggufModelPath(for model: LocalTextModelID, quantization: ModelQuantization) -> URL {
        let modelsDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .appendingPathComponent("Epistemos/Models/GGUF")
        
        let fileName: String
        switch quantization {
        case .q4: fileName = model.ggufFileQ4 ?? "\(model.rawValue.split(separator: "/").last!)-Q4_K_M.gguf"
        case .q8: fileName = model.ggufFileQ8 ?? "\(model.rawValue.split(separator: "/").last!)-Q8_0.gguf"
        }
        
        return modelsDir
            .appendingPathComponent(model.familyName)
            .appendingPathComponent(fileName)
    }
    
    /// Download GGUF model from HuggingFace (uses existing URLSession infrastructure)
    func downloadGGUF(
        model: LocalTextModelID,
        quantization: ModelQuantization,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        guard model.backend == .gguf else {
            throw DownloadError.notGGUFModel
        }
        
        let hfRepo = model.rawValue
        let fileName = quantization == .q4 ? model.ggufFileQ4! : (model.ggufFileQ8 ?? model.ggufFileQ4!)
        let hfURL = URL(string: "https://huggingface.co/\(hfRepo)/resolve/main/\(fileName)")!
        let destPath = ggufModelPath(for: model, quantization: quantization)
        
        // Create directory
        try FileManager.default.createDirectory(
            at: destPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        // Wire to existing URLSessionDownloadTask progress pattern
        // ... existing download infrastructure
        return destPath
    }
}
```

***

## Part 9: Implementation Order for Claude Code

Execute in exactly this order. Steps marked `[PARALLEL]` can run simultaneously.

### Phase 0: Foundation (no dependencies)
1. Create `ModelBackend.swift` with `ModelBackend` enum
2. Create `GGUFQuantVariant.swift` with quantization config types
3. Create `KVCacheConfig.swift` with TurboQuant config
4. Add `ModelQuantization` enum

### Phase 1: Core Enum Replacement (blocks everything)
1. **REPLACE** entire `LocalTextModelID.swift` with Part 5 content
2. Add all tier/RAM/capability extensions
3. `[PARALLEL]` Add `ModelBackend` routing to `MLXInferenceService.swift`

### Phase 2: GGUF Backend (blocks new models)
1. Add `LocalLLMClient` SPM dependency (preferred) or llama.cpp XCFramework[^14][^13]
2. **CREATE** `GGUFInferenceService.swift` using LocalLLMClient wrapper
3. **MODIFY** `ModelDownloadManager.swift` — add GGUF download path
4. `[PARALLEL]` Route GGUF models in `InferenceState.swift`/`LLMService.swift`

### Phase 3: Model Selector UI
1. **CREATE** `LocalModelSelectorView.swift` with 5-tier sections, RAM labels, oMLX badges
2. Replace old model picker with new `LocalModelSelectorView`
3. `[PARALLEL]` Add `selectedQuantization: ModelQuantization` to `UserDefaults`/`AppState`

### Phase 4: TurboQuant + Prompt Repetition
1. **MODIFY** `MLXInferenceService.swift` — add `KVCacheConfig` struct and `kvbits` flag
2. **MODIFY** `SystemPromptBuilder.swift` — add `withPromptRepetition`
3. Add TurboQuant toggle + Prompt Repetition toggle to Settings UI

### Phase 5: Fast/Thinking/Agent Mode
1. **MODIFY** `LLMService.swift` — add `thinkingPromptPrefix(for:thinkMode:)` and `buildPromptWithThinkMode`
2. **MODIFY** `ChatInputBar.swift` — make existing toggle model-aware
3. **CREATE** `AgentModeSelector.swift` — Fast/Thinking/Agent three-way toggle
4. **MODIFY** `ChatState.swift` — wire `EpistemosOperatingMode.agent` → `OrchestratorState.submitTask`

### Phase 6: SOAR Research Mode
Follow Part 8 of the Complete Model Support plan exactly (TMSService, OmegaToolRegistry, MCPBridge migration, SafariAgent/NotesAgent wiring)

### Phase 7: Training Data
Run `generateResearchWorkflowExamples` in `generateEpistemosTrainingData.py`

***

## Part 10: Acceptance Criteria

A session is complete when ALL of the following are true:

- [ ] `LocalTextModelID` has all 17 model cases (6 existing MLX + 11 new)
- [ ] Every model has `ramRequirementQ4GB` and `ramRequirementQ8GB?` populated
- [ ] `ModelBackend.swift` exists with `.mlx` and `.gguf` cases
- [ ] `GGUFInferenceService.swift` exists and compiles (even if inference calls are stubbed)
- [ ] `KVCacheConfig.swift` exists with `.turboQuant`, `.standard`, `.balanced` presets
- [ ] TurboQuant toggle wired to MLX inference call via `kvbits` arg
- [ ] Model picker shows 5 tier sections (Ultra Light → Maximum) with RAM labels
- [ ] Q4/Q8 buttons render in picker for each GGUF model row
- [ ] "Needs oMLX" badge shows for models exceeding system RAM
- [ ] "Coming Soon" badge shows for `llama4Scout_109BMoE`, `miniMaxM25`, `chromaContext1_20B`
- [ ] Thinking toggle is model-aware (disabled/greyed for models without `supportsDualThinkMode`)
- [ ] `AgentModeSelector.swift` renders Fast/Thinking/Agent three-way toggle
- [ ] Prompt Repetition function exists in `SystemPromptBuilder`
- [ ] `TMSService.swift` exists with `calculateSOAR` and `evaluateNLI`
- [ ] All 4 SOAR tool schemas are in `OmegaToolRegistry.all`
- [ ] MCPBridge SQLite migration adds `soarScore`, `contradictionFlag`, `citationHash`, `modelHash`
- [ ] All `ModelSupportTests` pass
- [ ] All existing `ThemePairTests` continue to pass (no regressions)

***

## Part 11: Known Gaps and Stubs

| Item | Status | Action |
|------|--------|--------|
| Llama 4 Scout 109B MLX | Available on HuggingFace but requires 64GB | Add to enum, show "Coming Soon" if system RAM < 64GB |
| MiniMax M2.5 | Weights not yet public as of March 2026 | Add enum case, `isComingSoon = true` |
| Chroma Context-1 | May require registration/access | Same `isComingSoon` treatment |
| Full TurboQuant | Requires `mlx-lm >= 0.21` or flovflo fork[^5][^12] | Implement flag now, activate when mlx-lm ships it |
| oMLX SSD caching | External app, not in-process | Implement HTTP bridge, show install banner for large models |
| Exo distributed inference | Multi-Mac networking | Out of scope, file as enhancement issue |
| TurboQuant speedup on Apple Silicon | ~30% vs 8x on H100[^5] | Set correct user expectations in UI ("~30% faster on Apple Silicon") |

***

## Part 12: Pre-Flight Verification Greps

Before writing a single line of code, Claude Code must run these greps and confirm expected state. Halt and report any discrepancy:

```bash
# Verify existing trustworthy infrastructure
grep -r "LocalTextModelID" --include="*.swift" | head -20
# EXPECTED: nonisolated enum with 6 MLX cases

grep -r "ModelDownloadManager\|MLXInferenceService" --include="*.swift" | head -10
# EXPECTED: EXISTS — MLX pipeline only, no GGUF backend

grep -r "fastThinking\|thinkMode" --include="*.swift" | head -10
# EXPECTED: EXISTS — toggle present, but model-agnostic

grep -r "OrchestratorState\|ResearchOrchestrator\|MCPBridge" --include="*.swift" | head -10
# EXPECTED: ALL TRUSTWORTHY per 2,679-test passing suite

grep -r "GGUF\|llama\.cpp\|LlamaInference\|GGUFInferenceService" --include="*.swift" | head -5
# EXPECTED: ZERO results — this is what you're building

grep -r "KVCacheConfig\|turboQuant" --include="*.swift" | head -5
# EXPECTED: ZERO results — this is what you're building
```

---

## References

1. [Running LLMs Locally in 2025: Speed tests on M2 Pro + 16 GB RAM](https://adamjones.me/blog/local-llms-speed-early-2025/) - Each model <= 14B parameters was tested generating 1000 tokens, at least three times. The model was ...

2. [Running LLMs on a MacBook Apple M2 Pro Performance Analysis](https://openllmbenchmarks.com/running-llms-on-a-macbook-apple-m2-pro-performance-analysis.html) - It boasts impressive processing power, enhanced memory bandwidth, and a powerful GPU, making it a pe...

3. [Can MacBook Pro M2 Pro 16GB run Qwen3.5 9B? | Will It Run AI](https://www.willitrunai.com/can-run/hf-lmstudio-community--qwen3-5-9b-gguf-on-m2-pro-16gb) - Can MacBook Pro M2 Pro 16GB run Qwen3.5 9B? Detailed VRAM analysis, fit score (C), 23.7 tok/s decode...

4. [TurboQuant: Redefining AI efficiency with extreme compression](https://research.google/blog/turboquant-redefining-ai-efficiency-with-extreme-compression/) - TurboQuant is a compression method that achieves a high reduction in model size with zero accuracy l...

5. [flovflo/turboquant-mlx-qwen35-kv - Hugging Face](https://huggingface.co/flovflo/turboquant-mlx-qwen35-kv) - This repository is the MLX / Apple Silicon translation of that idea: same target problem: KV cache b...

6. [90 Seconds of Waiting, Gone: How oMLX Buries Ollama on Mac](https://rexai.top/en/ai/llm/2026-03-23-omlx-apple-silicon-llm-inference/) - oMLX runs on Apple's officially open-sourced MLX framework. Ollama's engine, by contrast, is llama.c...

7. [M5 Max 128G Performance tests. I just got my new toy, and ... - Reddit](https://www.reddit.com/r/LocalLLaMA/comments/1rzkw4x/m5_max_128g_performance_tests_i_just_got_my_new/) - ... GGUF for Qwen3.5-27b model ? Wouldn't a fairer comparison be MLX 4bit vs Q4? And what are your s...

8. [Full GPU inference on Apple Silicon using Metal with GGML - Reddit](https://www.reddit.com/r/LocalLLaMA/comments/140nto2/full_gpu_inference_on_apple_silicon_using_metal/) - A new version of llama.cpp is released where it can do 40 tok/s inference of the 7B model on a M2 Ma...

9. [Installing Qwen 3.5 on Apple Silicon Using MLX for 2X Performance](https://dev.to/thefalkonguy/installing-qwen-35-on-apple-silicon-using-mlx-for-2x-performance-37ma) - With unified memory architectures supporting up to 192 GB of shared CPU and GPU memory and memory ba...

10. [Google's TurboQuant reduces AI LLM cache memory capacity ...](https://www.tomshardware.com/tech-industry/artificial-intelligence/googles-turboquant-compresses-llm-kv-caches-to-3-bits-with-no-accuracy-loss) - Google's TurboQuant reduces AI LLM cache memory capacity requirements by at least six times — up to ...

11. [Google Introduces TurboQuant: A New Compression Algorithm that ...](https://www.marktechpost.com/2026/03/25/google-introduces-turboquant-a-new-compression-algorithm-that-reduces-llm-key-value-cache-memory-by-6x-and-delivers-up-to-8x-speedup-all-with-zero-accuracy-loss/) - TurboQuant: A Compression Algorithm that Reduces LLM Key-Value Cache Memory by 6x and Delivers Up to...

12. [PolarQuant KV cache compression (TurboQuant, ICLR 2026) #1060](https://github.com/ml-explore/mlx-lm/issues/1060) - KV cache is the memory bottleneck for long context inference on Apple Silicon. The existing Quantize...

13. [A Swift Package for Local LLMs Using llama.cpp and MLX](https://dev.to/tattn/localllmclient-a-swift-package-for-local-llms-using-llamacpp-and-mlx-1bcp) - In this article, I'm introducing LocalLLMClient, a library that makes it simple to use local LLMs fr...

14. [llama.cpp - Swift Package Registry](https://swiftpackageregistry.com/ggml-org/llama.cpp) - The main goal of llama.cpp is to enable LLM inference with minimal setup and state-of-the-art perfor...

15. [oMLX - open-source MLX inference server with paged SSD caching ...](https://www.reddit.com/r/LocalLLaMA/comments/1r3qwyi/omlx_opensource_mlx_inference_server_with_paged/) - An LLM inference server for Apple Silicon with a native macOS menubar app. Download the DMG, drag to...

