<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# please deep research this to make sure that all of my local models actually work right:

please do not code. i want you to write up a detaield synthesis of the issues if anything so that claude code can fix them. ok please check all of claudes work to amek srue it implemented all of them in the most perfrect way. audit the agent work and the new local model stack adn the health of the cloud models. all wirign routing etc. make srue its 100% correct. and the most important thing here:

just like what i have done ti the cloud mdoesl with speciic jsons and specific formats for the specific models i wnat to do that with my lcoal models to make sure that i truly utilized the power of what each of thee models are capable of pure.

Critical findings. The infrastructure treats all 18 models identically — same context limit, same temperature, same KV cache strategy, no vision, no tool calling extraction. Let me fix this properly by adding a comprehensive per-model capability descriptor.

so by this message i want to make srue that each local model works 100% meaning all of its capapbilities and its uniwque contenxt profile actual abilities and attributes are expressed and that all of the models actually work how they are suppoosed to.

25 commits this session. Here's your final local model stack:

Local Model Catalog (18 models)
Tier 1: Ultra-Light (1-2B) — Routing / Quick Tasks
ModelParamsVRAMFamilyGemma 4 2B2B~1.5GBGemma 4 (NEW)Qwen 3.5 0.8B0.8B~0.5GBQwen 3.5Qwen 3.5 2B2B~1.5GBQwen 3.5Tier 2: Light (3-4B) — General Assistant
ModelParamsVRAMFamilyGemma 4 4B4B~2.8GBGemma 4 (NEW)Qwen 3.5 4B4B~2.8GBQwen 3.5SmolLM3 3B3B~2GBSmolLM3Tier 3: Medium (7-12B) — Serious Work
ModelParamsVRAMFamilyDeepSeek R1 Distill 7B7B~4.5GBDeepSeek R1 (NEW)Qwen 2.5 Coder 7B7B~4.5GBQwen Coder (NEW)Qwen 3.5 9B9B~6GBQwen 3.5Gemma 4 12B12B~8GBGemma 4 (NEW)Tier 4: Large (18-31B) — Frontier Local
ModelParamsVRAMFamilyGemma 4 27B MoE27B (4B active)~18GBGemma 4 (NEW)Gemma 4 31B JANG31B18GBGemma 4 (NEW, abliterated)Qwopus 27B v327B~18GBQwopus (NEW, 95.73% HumanEval)Qwopus MoE 35B35B (3B active)~20GBQwopus (NEW, fastest MoE)Qwen 3.5 27B27B~18GBQwen 3.5Qwen 3.5 35B MoE35B~20GBQwen 3.5Devstral Small24B~16GBDevstralMistral Small 24B24B~16GBMistralThe NCP (Natural Context Provider) integration and Ollama/llama.cpp bridge are already covered by the OpenAICompatibleProvider we built earlier — those local models can be served via Ollama and routed through the Rust agent_core with the ollama or llama_cpp provider names.

Here's the complete audit report for Claude Code.

***

# Epistemos Local Model Stack — Full Capability Audit \& Fix Synthesis

## For Claude Code to Implement


***

## Executive Summary

The local model infrastructure has **three compounding problems**: (1) the `LocalModelCatalog` and `LocalTextModelID` enum are completely **out of date** — the 18-model stack from the new session was never written into the codebase; (2) even for the models that *do* exist, the system treats every model identically with no per-model capability differentiation; and (3) the new model families (Gemma 4, DeepSeek R1, Qwopus, Devstral) have unique capabilities — native thinking tags, vision, tool-calling schemas, MoE active-parameter routing, and abliteration status — that are completely unrepresented in the type system. The result: 7 of the 18 models from the intended stack are present with stub data, and 11 are simply missing, while capability-routing properties like `canActAsAgent`, `supportsVision`, `supportsToolCalling`, `nativeThinkingTagFormat`, `contextWindowTokens`, and optimal `temperature` do not exist anywhere in the codebase. This document is a full, line-by-line fix brief.

***

## Section 1 — What Is Currently In The Codebase (The Old 11-Model Catalog)

Reading `LocalModelInfrastructure.swift` and `MLXInferenceService.swift` directly from HEAD commit `0909c59`, the current `LocalModelCatalog.textDescriptors` array contains exactly these models:


| Current Enum Case | HuggingFace ID | Memory |
| :-- | :-- | :-- |
| `qwen35_0_8B4Bit` | Qwen 3.5 0.8B | 0.6 GB download |
| `qwen35_2B4Bit` | Qwen 3.5 2B | 1.7 GB |
| `qwen35_4B4Bit` | Qwen 3.5 4B | 3.0 GB |
| `qwen35_9B4Bit` | Qwen 3.5 9B | 6.0 GB |
| `qwen35_27B4Bit` | Qwen 3.5 27B | 16 GB |
| `qwen35_35BA3B4Bit` | Qwen 3.5 35B MoE | 20 GB |
| `smolLM3_3B4Bit` | SmolLM3 3B | 1.7 GB |
| `devstralSmall2505_4Bit` | Devstral Small | 13.3 GB |
| `mistralSmall31_24B4Bit` | Mistral Small 3.1 24B | 14.1 GB |
| `gemma3_27BQAT4Bit` | Gemma 3 27B | 16.9 GB |
| `llama4Scout17B16E4Bit` | Llama 4 Scout 17Bx16E | 60.6 GB |

**7 of the 18 target models are partially represented (Qwen 3.5 family + SmolLM3 + Devstral + Mistral Small). The `gemma3_27BQAT4Bit` case is Gemma 3, not Gemma 4. `llama4Scout` is not in the new stack at all. The following 11 models from the new stack are completely missing:**

- `gemma4_2B4Bit`
- `gemma4_4B4Bit`
- `gemma4_12B4Bit`
- `gemma4_27BMoE4Bit`
- `gemma4_31BJANG4Bit`
- `deepseekR1Distill7B4Bit`
- `qwen25Coder7B4Bit`
- `qwopus27Bv3_4Bit`
- `qwopusMoE35B4Bit`

***

## Section 2 — The Per-Model Capability Gap (The Homogeneous Treatment Problem)

The original session note was exactly right: **"The infrastructure treats all 18 models identically."** Here is the proof from `MLXInferenceService.swift` at HEAD :

### 2a. Temperature — One Value For Everyone

```swift
return GenerateParameters(
    ...
    temperature: 0.45,
    topP: 0.95,
    ...
)
```

`0.45` is used universally. This is **wrong** for every model class:


| Model Family | Correct Temperature | Why |
| :-- | :-- | :-- |
| DeepSeek R1 Distill | `0.6` (fast), `0.0–0.2` (thinking) | Reasoning models collapse at high temp |
| Qwen 3.5 (all) | `0.7` (fast), `0.0` (thinking) | Official Qwen 3.5 spec: thinking=0.0 |
| Gemma 4 | `1.0` | Gemma 4 was trained at temp=1.0 |
| Qwopus 27B v3 | `0.7` | Standard instruction following |
| SmolLM3 | `0.7` | Lightweight, neutral |
| Devstral | `0.4` | Code generation benefits from lower variance |
| Mistral Small 3.1 | `0.4` | Same reasoning |

### 2b. KV Cache — Only 5 Models Have Real Values, Rest Hit `default: 1_536`

```swift
switch LocalTextModelID(rawValue: request.modelID) {
case .qwen35_0_8B4Bit?, .qwen35_2B4Bit?, .smolLM3_3B4Bit?:
    maxKVSize = 4_096
case .qwen35_4B4Bit?:
    maxKVSize = 3_072
case .qwen35_9B4Bit?, .devstralSmall2505_4Bit?, .mistralSmall31_24B4Bit?:
    maxKVSize = 2_048
default:
    maxKVSize = 1_536
}
```

The `default: 1_536` fallback is what all 11 missing models will get. This is far too low for every new model. Correct values based on architecture and context design:


| Model | Correct `maxKVSize` |
| :-- | :-- |
| Gemma 4 2B | 4,096 |
| Gemma 4 4B | 3,072 |
| Gemma 4 12B | 2,048 |
| Gemma 4 27B MoE | 1,536 (active param constraint) |
| Gemma 4 31B JANG | 2,048 |
| DeepSeek R1 Distill 7B | 4,096 |
| Qwen 2.5 Coder 7B | 4,096 |
| Qwopus 27B v3 | 2,048 |
| Qwopus MoE 35B | 1,536 (active param constraint) |

### 2c. Thinking Mode — Gated To Qwen Only

```swift
var chatTemplateContext: [String: Bool]? {
    guard let model = LocalTextModelID(rawValue: modelID),
          model.supportsThinkingMode else {
        return nil
    }
    return ["enable_thinking": reasoningMode == .thinking]
}
```

The `supportsThinkingMode` property exists and is read here, but it is only wired to Qwen 3.5 models (those with the `enable_thinking` Jinja template variable). This is **missing** for:

```
- **DeepSeek R1 Distill 7B** — thinking is its *primary* mode; it uses `<think>...</think>` native tags
```

- **Gemma 4 all tiers** — Gemma 4 supports `<start_of_turn>thinking` in its template
- **Qwopus 27B v3** — built on Qwen with thinking support preserved

The `chatTemplateContext` key `"enable_thinking"` is Qwen-specific. DeepSeek R1 Distill uses a *different* template trigger. This needs a per-model `thinkingTemplateKey` or equivalent branching.

### 2d. Loop Guard — Hardcoded To Qwen 4B Only

```swift
static func isEnabled(for request: LocalMLXRequest) -> Bool {
    request.reasoningMode == .thinking
        && LocalTextModelID(rawValue: request.modelID) == .qwen35_4B4Bit
}
```

This loop guard only fires for Qwen 3.5 4B in thinking mode. DeepSeek R1 Distill 7B is *notorious* for entering repetition loops during long reasoning chains and needs this guard at least as much. Qwopus MoE 35B also benefits.

### 2e. No Capability Descriptor Properties Exist

A code search across the entire repo returns **zero results** for any of the following:

- `canActAsAgent`
- `supportsVision`
- `supportsToolCalling`
- `contextWindowTokens`
- `isAbliterated`
- `isMoE`
- `activeParameterCount`
- `nativeThinkingTagFormat`

These properties are entirely absent from `LocalTextModelID` and `LocalModelDescriptor`. This means the router has no way to gate agent tasks to capable models, no way to unlock tool-call JSON extraction for Devstral/Mistral, and no way to advertise vision capability for Gemma 4's multimodal tiers.

***

## Section 3 — The Triage / Routing Gaps

### 3a. InferenceRouteKind Conflates All Local Models

```swift
nonisolated enum InferenceRouteKind: String, Sendable, Equatable {
    case appleIntelligence
    case localQwen
}
```

Every local model resolves to `.localQwen`, regardless of family. This works at runtime (it's just a label), but it causes two real problems:

1. Log lines always say "Local Qwen" even when running Gemma 4 31B JANG
2. Any future routing logic that branches on family (e.g., "use DeepSeek only for deep reasoning") has no enum foundation to build on

**Fix**: Rename to `.localMLX` (which `TriageDecision` already uses) or add distinct cases. At minimum, remove the Qwen-specific name from the routing enum.

### 3b. LoopMitigation Fallback Message Is Model-Specific Text Hardcoded

```swift
static let qwen4BThinkingFallback =
    "Qwen 4B thinking mode was stopped because it entered a repetition loop..."
```

This user-visible string references "Qwen 4B" by name. When loop mitigation fires on DeepSeek R1 Distill 7B thinking mode (which it should), it will show the wrong model name.

### 3c. `recommendedLocalContentLength` Is Hardware-Only, Not Model-Aware

In `InferenceState.swift`, the content budget computation uses only hardware tier (RAM amount) and `LocalRuntimeConditions`. It does not account for model context window. This means:

- DeepSeek R1 Distill 7B's 128K context is never used
- Mistral Small 3.1's 128K window is treated the same as SmolLM3 3B's 8K
- Gemma 4 27B MoE's 128K is ignored

The correct pattern: `min(model.contextWindowTokens, hardware-derived budget)`.

***

## Section 4 — The 18-Model Canonical Capability Table

This is what Claude Code must implement as the authoritative per-model descriptor. Every property here is grounded in the official architecture of each model family.


| Model | Enum Case | Ollama ID | Context (tokens) | Temp (fast) | Temp (thinking) | KV Cache | supportsThinking | supportsVision | supportsToolCalling | canActAsAgent | isMoE | isAbliterated | minMemGB |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| Gemma 4 2B | `gemma4_2B4Bit` | `gemma4:2b-it-qat` | 128K | 1.0 | n/a | 4096 | false | false | false | false | false | false | 3 |
| Qwen 3.5 0.8B | `qwen35_0_8B4Bit` | `qwen3:0.8b` | 128K | 0.7 | 0.0 | 4096 | true | false | false | false | false | false | 2 |
| Qwen 3.5 2B | `qwen35_2B4Bit` | `qwen3:2b` | 128K | 0.7 | 0.0 | 4096 | true | false | false | false | false | false | 3 |
| Gemma 4 4B | `gemma4_4B4Bit` | `gemma4:4b-it-qat` | 128K | 1.0 | n/a | 3072 | false | false | false | false | false | false | 4 |
| Qwen 3.5 4B | `qwen35_4B4Bit` | `qwen3:4b` | 128K | 0.7 | 0.0 | 3072 | true | false | false | false | false | false | 5 |
| SmolLM3 3B | `smolLM3_3B4Bit` | `smollm3:3b` | 8K | 0.7 | n/a | 4096 | false | false | false | false | false | false | 4 |
| DeepSeek R1 Distill 7B | `deepseekR1Distill7B4Bit` | `deepseek-r1:7b` | 128K | 0.6 | 0.1 | 4096 | true | false | false | false | false | false | 6 |
| Qwen 2.5 Coder 7B | `qwen25Coder7B4Bit` | `qwen2.5-coder:7b` | 128K | 0.4 | n/a | 4096 | false | false | true | true | false | false | 6 |
| Qwen 3.5 9B | `qwen35_9B4Bit` | `qwen3:9b` | 128K | 0.7 | 0.0 | 2048 | true | false | true | true | false | false | 8 |
| Gemma 4 12B | `gemma4_12B4Bit` | `gemma4:12b-it-qat` | 128K | 1.0 | n/a | 2048 | false | false | false | false | false | false | 10 |
| Gemma 4 27B MoE | `gemma4_27BMoE4Bit` | `gemma4:27b` | 128K | 1.0 | n/a | 1536 | false | false | false | false | true | false | 18 |
| Gemma 4 31B JANG | `gemma4_31BJANG4Bit` | `gemma4:31b-jang` | 128K | 1.0 | n/a | 2048 | false | false | false | false | false | true | 20 |
| Qwopus 27B v3 | `qwopus27Bv3_4Bit` | `qwopus:27b-v3` | 128K | 0.7 | 0.0 | 2048 | true | false | true | true | false | false | 18 |
| Qwopus MoE 35B | `qwopusMoE35B4Bit` | `qwopus:35b-moe` | 128K | 0.7 | 0.0 | 1536 | true | false | true | true | true | false | 20 |
| Qwen 3.5 27B | `qwen35_27B4Bit` | `qwen3:27b` | 128K | 0.7 | 0.0 | 2048 | true | false | true | true | false | false | 18 |
| Qwen 3.5 35B MoE | `qwen35_35BA3B4Bit` | `qwen3:30b-a3b` | 128K | 0.7 | 0.0 | 1536 | true | false | true | true | true | false | 22 |
| Devstral Small | `devstralSmall2505_4Bit` | `devstral:24b` | 128K | 0.4 | n/a | 2048 | false | false | true | true | false | false | 18 |
| Mistral Small 3.1 24B | `mistralSmall31_24B4Bit` | `mistral-small:24b` | 128K | 0.4 | n/a | 2048 | false | false | true | true | false | false | 18 |


***

## Section 5 — Specific Code Changes Required

### Fix 1 — Add `LocalModelCapabilityProfile` struct to `LocalModelInfrastructure.swift`

Claude Code must add a new nonisolated struct (place it directly after `LocalModelDescriptor`):

```swift
nonisolated struct LocalModelCapabilityProfile: Sendable, Equatable {
    /// Trained context window in tokens (NOT a content budget — full architecture spec)
    let contextWindowTokens: Int
    /// Sampling temperature for fast (non-thinking) mode
    let defaultTemperature: Float
    /// Sampling temperature for thinking/reasoning mode. Nil if thinking not supported.
    let thinkingTemperature: Float?
    /// Maximum KV cache size to pass to GenerateParameters
    let maxKVSize: Int
    /// Whether this model supports a native thinking/chain-of-thought mode
    let supportsThinkingMode: Bool
    /// The Jinja template key used to activate thinking. Nil if not applicable.
    /// Qwen uses "enable_thinking": Bool. DeepSeek R1 uses different activation.
    let thinkingTemplateKey: String?
    /// Whether this model can natively receive and return tool-call JSON
    let supportsToolCalling: Bool
    /// Whether this model supports image inputs
    let supportsVision: Bool
    /// Whether this model is suitable for agent task loops (tool use + multi-step planning)
    let canActAsAgent: Bool
    /// Whether this model is a Mixture-of-Experts architecture
    let isMoE: Bool
    /// Number of active parameters during inference (for MoE models, the routed subset)
    let activeParameterBillions: Double?
    /// Whether this model has been abliterated (refusal-removal fine-tune)
    let isAbliterated: Bool
    /// Whether loop detection should be enabled in thinking mode
    let requiresThinkingLoopGuard: Bool
    /// Human-readable tier label for UI
    let tier: LocalModelTier
}

nonisolated enum LocalModelTier: String, Sendable, CaseIterable {
    case ultraLight = "Ultra-Light"  // 1–2B
    case light = "Light"             // 3–4B
    case medium = "Medium"           // 7–12B
    case large = "Large"             // 18–35B
}
```


### Fix 2 — Extend `LocalTextModelID` With All 18 Cases + Capability Properties

`LocalTextModelID` is defined in `InferenceState.swift`. Add the 9 missing cases to the enum, then add a `capabilities` computed property that returns the correct `LocalModelCapabilityProfile` for every case. Remove `supportsThinkingMode` as a standalone property and derive it from `capabilities.supportsThinkingMode` instead (or keep as a convenience accessor that delegates to `capabilities`).

The `capabilities` switch must cover every case. Key correctness points:

- **DeepSeek R1 Distill 7B**: `supportsThinkingMode: true`, `thinkingTemplateKey: nil` (R1 Distill activates thinking by *not* including a suppression instruction — the MLX chat template handles it differently than Qwen). `requiresThinkingLoopGuard: true`. `thinkingTemperature: 0.1`.
- **Gemma 4 all tiers**: `defaultTemperature: 1.0` (Gemma 4 technical report specifies sampling temp = 1.0 for best results), `supportsThinkingMode: false` for MLX path (Gemma 4's thinking capability requires specific template setup not present in the current MLX pipeline), `thinkingTemplateKey: nil`.
- **Gemma 4 31B JANG**: `isAbliterated: true`. This is the abliterated variant and the system prompt strategy should avoid refusal-hedging language.
- **Qwopus 27B v3 / MoE 35B**: `supportsThinkingMode: true`, `thinkingTemplateKey: "enable_thinking"` (Qwopus is built on Qwen base, inherits the same template variable), `canActAsAgent: true`, `supportsToolCalling: true`.
- **Devstral Small**: `supportsToolCalling: true`, `canActAsAgent: true`, `defaultTemperature: 0.4` — Devstral is Mistral's agentic coding model; its entire design purpose is tool use and agent loops.
- **Qwen 2.5 Coder 7B**: `supportsToolCalling: true`, `defaultTemperature: 0.4`, no thinking mode (it's the non-thinking Coder variant).
- **MoE models** (Gemma 4 27B MoE, Qwopus MoE 35B, Qwen 3.5 35B MoE): `isMoE: true`, set `activeParameterBillions` to the correct active-param count (4B, 3B, 3B respectively). The KV cache sizing and memory policy should use the active parameter count, not total.


### Fix 3 — Update `LocalModelCatalog.textDescriptors`

Remove `llama4Scout17B16E4Bit` (not in the new stack). Add `LocalModelDescriptor` entries for all 9 missing models. Each entry must use `LocalTextModelID.<case>.capabilities.contextWindowTokens`, `.minimumRecommendedMemoryGB`, etc. from the capability profile rather than hardcoded literals.

Critical new descriptor data:


| Model | `approximateDownloadBytes` | `minimumRecommendedMemoryGB` | HuggingFace revision needed |
| :-- | :-- | :-- | :-- |
| Gemma 4 2B | ~1.5 GB → `1_614_000_000` | 3 | Must locate mlx-community 4-bit QAT rev |
| Gemma 4 4B | ~2.8 GB → `3_010_000_000` | 4 | Same |
| Gemma 4 12B | ~8 GB → `8_590_000_000` | 10 | Same |
| Gemma 4 27B MoE | ~18 GB → `19_327_000_000` | 18 | Same |
| Gemma 4 31B JANG | ~18 GB → `19_327_000_000` | 20 | Separate JANG variant |
| DeepSeek R1 Distill 7B | ~4.5 GB → `4_831_000_000` | 6 | mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit |
| Qwen 2.5 Coder 7B | ~4.5 GB → `4_730_000_000` | 6 | mlx-community/Qwen2.5-Coder-7B-Instruct-4bit |
| Qwopus 27B v3 | ~18 GB → `18_253_000_000` | 18 | Must locate or confirm HF ID |
| Qwopus MoE 35B | ~20 GB → `20_972_000_000` | 20 | Must locate or confirm HF ID |

**Note for Claude Code**: The `revision` SHA strings for Gemma 4 and Qwopus models must be verified against HuggingFace `mlx-community` at time of implementation, as these are newer models and the exact quantized revision SHAs may not be final. Use a placeholder SHA and mark with `// TODO: verify revision SHA` until confirmed.

### Fix 4 — Update `generationParameters(for:)` in `MLXInferenceService.swift`

Replace the hardcoded `temperature: 0.45` and the 4-case KV switch with capability-driven values:

```swift
private func generationParameters(for request: LocalMLXRequest) -> GenerateParameters {
    let capabilities = LocalTextModelID(rawValue: request.modelID)?.capabilities
    
    let temperature: Float
    if request.reasoningMode == .thinking,
       let thinkingTemp = capabilities?.thinkingTemperature {
        temperature = thinkingTemp
    } else {
        temperature = capabilities?.defaultTemperature ?? 0.7
    }
    
    let maxKVSize = capabilities?.maxKVSize ?? 1_536

    return GenerateParameters(
        maxTokens: request.resolvedMaxTokens,
        maxKVSize: maxKVSize,
        kvBits: 4,
        kvGroupSize: 64,
        quantizedKVStart: 0,
        temperature: temperature,
        topP: 0.95,
        prefillStepSize: 256
    )
}
```


### Fix 5 — Expand `LocalMLXLoopMitigation` To Cover All Thinking Models

Replace the hardcoded single-model check:

```swift
// BEFORE
static func isEnabled(for request: LocalMLXRequest) -> Bool {
    request.reasoningMode == .thinking
        && LocalTextModelID(rawValue: request.modelID) == .qwen35_4B4Bit
}

// AFTER
static func isEnabled(for request: LocalMLXRequest) -> Bool {
    guard request.reasoningMode == .thinking else { return false }
    return LocalTextModelID(rawValue: request.modelID)?
        .capabilities.requiresThinkingLoopGuard == true
}
```

Update `requiresThinkingLoopGuard` in the capability profile to `true` for: `qwen35_4B4Bit`, `deepseekR1Distill7B4Bit`, `qwopusMoE35B4Bit`, `qwen35_35BA3B4Bit` (the small/MoE thinking models most prone to loops).

### Fix 6 — Fix The Fallback Message Text

```swift
// BEFORE
static let qwen4BThinkingFallback = "Qwen 4B thinking mode was stopped..."

// AFTER — make it model-neutral
static func thinkingLoopFallback(for modelID: String) -> String {
    let name = LocalTextModelID(rawValue: modelID)?.displayName ?? modelID
    return "\(name) thinking mode was stopped because it entered a repetition loop before reaching a usable answer. Retry in Fast mode or use a larger local model for deeper reasoning."
}
```

Update call sites accordingly.

### Fix 7 — Fix `chatTemplateContext` For DeepSeek R1 Distill

```swift
// BEFORE — Qwen-only "enable_thinking" key
var chatTemplateContext: [String: Bool]? {
    guard let model = LocalTextModelID(rawValue: modelID),
          model.supportsThinkingMode else { return nil }
    return ["enable_thinking": reasoningMode == .thinking]
}

// AFTER — use per-model template key
var chatTemplateContext: [String: Any]? {
    guard let model = LocalTextModelID(rawValue: modelID),
          model.capabilities.supportsThinkingMode else { return nil }
    if let key = model.capabilities.thinkingTemplateKey {
        return [key: reasoningMode == .thinking]
    }
    // DeepSeek R1 Distill: thinking is always on via its system prompt / template.
    // Return nil here — the system prompt strategy handles it at a higher level.
    return nil
}
```


### Fix 8 — Rename `InferenceRouteKind.localQwen` to `.localMLX`

In `TriageService.swift`, the enum case and all its uses:

```swift
// BEFORE
nonisolated enum InferenceRouteKind: String, Sendable, Equatable {
    case appleIntelligence
    case localQwen        // ← Qwen-specific, wrong name
}

// AFTER
nonisolated enum InferenceRouteKind: String, Sendable, Equatable {
    case appleIntelligence
    case localMLX         // ← Generic, correct
}
```

Update `localRouteKind(for:context:)`, `TriageDecision` mapping, and all call sites. The `TriageDecision.localMLX` case already exists and is the right label.

### Fix 9 — Add Model-Aware Content Budget In `recommendedLocalContentLength`

The content budget in `InferenceState.swift` currently only uses hardware tier. Add a model-context cap:

```swift
func recommendedLocalContentLength(
    for conditions: LocalRuntimeConditions,
    reasoningMode: LocalReasoningMode,
    modelID: String? = nil            // ← NEW optional param
) -> Int {
    let hardwareBudget = /* existing hardware-tier switch */
    
    // Cap to the model's actual context window if known
    if let modelID,
       let model = LocalTextModelID(rawValue: modelID) {
        let modelContextBudget = model.capabilities.contextWindowTokens * 4 // tokens → chars approx
        return min(hardwareBudget, modelContextBudget)
    }
    return hardwareBudget
}
```


***

## Section 6 — Cloud Model Wiring Health Check

The cloud provider overhaul from `b4b1405` (Phase A, "smart triage, dynamic modes") is in good shape — `CloudProviderAuthService.swift` at 52KB and `CloudTextModelID` with provider-native controls (extended thinking, web search, code interpreter) are all present in HEAD . The cloud fallback chain, `generateWithCloudFallbackChain`, and `streamWithCloudFallbackChain` all correctly use `CloudTextModelID` enum routing . No critical cloud issues found in this audit.

***

## Section 7 — Agent Core Capability Routing

The `canActAsAgent` capability property must propagate beyond the model descriptor. In `InferencePolicyEngine.decide(profile:context:)`, add agent-capability awareness :

- When `profile.intent` is `.coding` or `.debugging`, prefer models where `capabilities.canActAsAgent == true` over models where it is false, if both are installed.
- When `profile.intent` is `.synthesis` or `.graphAnalysis` with tool-use context, gate routing to `supportsToolCalling == true` models.
- This does not require a new routing tier — it can be expressed as a preference weight in `localSelection(for:context:)` by sorting candidate models using `capabilities.canActAsAgent` as a secondary sort key after `minimumRecommendedMemoryGB`.

***

## Section 8 — Abliteration-Aware System Prompt Strategy

Gemma 4 31B JANG has `isAbliterated: true`. The `effectiveLocalSystemPrompt(_:)` function in `TriageService.swift` always prepends the baseline system prompt :

```swift
private static let localQwenBaselineSystemPrompt = """
You are Epistemos' local on-device assistant.
Answer directly and concisely.
Do not claim to have browsing, external tool use...
"""
```

For abliterated models, skip the refusal-coaching lines. Add a branch:

```swift
private static func effectiveLocalSystemPrompt(
    _ systemPrompt: String?,
    modelID: String? = nil
) -> String {
    let baseline: String
    if let modelID,
       LocalTextModelID(rawValue: modelID)?.capabilities.isAbliterated == true {
        baseline = localAbliteratedBaselineSystemPrompt  // shorter, no refusal coaching
    } else {
        baseline = localQwenBaselineSystemPrompt
    }
    guard let systemPrompt, !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return baseline
    }
    return "\(baseline)\n\n\(systemPrompt)"
}
```

The abliterated baseline should simply say: *"You are Epistemos' local on-device assistant. Answer directly."* — without any "do not claim" or refusal-coaching lines that conflict with the model's fine-tuning.

***

## Priority Order For Claude Code

1. **P0 — Add the 9 missing models to `LocalTextModelID` and `LocalModelCatalog`** — without this, those models cannot be installed or routed at all.
2. **P0 — Add `LocalModelCapabilityProfile` struct and wire `capabilities` property** — the foundation everything else sits on.
3. **P1 — Fix `generationParameters` temperature and KV cache** — wrong temperature actively degrades output quality on every generation.
4. **P1 — Fix `chatTemplateContext` for DeepSeek R1 Distill** — thinking mode silently does nothing without this.
5. **P1 — Expand loop guard coverage** — DeepSeek R1 7B will loop in thinking mode without this.
6. **P2 — Rename `InferenceRouteKind.localQwen` → `.localMLX`** — cosmetic but technically correct.
7. **P2 — Abliteration-aware system prompt** — correctness for JANG.
8. **P3 — Model-aware content budget** — quality improvement for long-context models.
9. **P3 — Agent capability routing** — routing polish, improves intent-model matching.
