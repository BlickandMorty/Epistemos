# Epistemos Local Model Capability Audit & Synthesis

## Executive Summary

Claude Code has implemented **significant per-model capability descriptors** for the 18-model local stack. The implementation is **functionally complete** but has several **critical accuracy issues** that must be addressed before the system can claim to "fully express the unique power of each local model."

### Overall Assessment: 75% Complete
- ✅ **Structure**: Excellent - Clean capability properties on LocalTextModelID
- ✅ **Wiring**: Good - MLXInferenceService correctly uses per-model parameters
- ✅ **Routing**: Partial - ConfidenceRouter uses canActAsAgent
- ⚠️ **Accuracy Issues**: Context windows are wrong, missing models in catalog, KV cache values need tuning
- ❌ **Missing**: model_manifest.json not populated, no vision encoder integration, no tool-call extraction

---

## What Was Implemented (The Good)

### 1. Per-Model Capability Properties (InferenceState.swift)

Claude added comprehensive computed properties to `LocalTextModelID`:

```swift
var maxContextTokens: Int           // Per-model context limits
var supportsVision: Bool            // Vision capability gating
var supportsNativeToolCalling: Bool // Tool calling support
var optimalTemperature: Float       // Model-specific temperature
var optimalTopP: Float              // Model-specific top-p
var optimalTopK: Int                // Model-specific top-k (Qwopus=20)
var optimalKVCacheSize: Int         // VRAM-aware KV sizing
var isMoE: Bool                     // Architecture detection
var activeParametersBillions: Float // Active param count
var primaryUseCase: LocalModelUseCase // Routing hint
```

### 2. MLXInferenceService Integration

The service now reads from model capabilities instead of hardcoded values:

```swift
private func generationParameters(for request: LocalMLXRequest) -> GenerateParameters {
    let model = LocalTextModelID(rawValue: request.modelID)
    let kvSize = model?.optimalKVCacheSize ?? 1_536
    let temp = model?.optimalTemperature ?? 0.45
    let topP = model?.optimalTopP ?? 0.95
    // ... uses these for generation
}
```

### 3. LocalTextModelID Enum Expansion

All 18 models are present in the enum:
- Gemma 4 family: 2B, 4B, 12B, 27B MoE, 31B JANG
- Qwen 3.5 family: 0.8B, 2B, 4B, 9B, 27B, 35B MoE
- Specialists: DeepSeek R1 Distill 7B, Qwen 2.5 Coder 7B
- Qwopus: 27B v3, MoE 35B
- Others: SmolLM3 3B, Devstral Small, Mistral Small 24B
- Legacy (should be removed): Gemma 3 27B, Llama 4 Scout

### 4. ConfidenceRouter Integration

The router correctly uses `canActAsAgent` to gate agent loops:

```swift
private func hasCapableLocalAgentModel(_ modelID: String?) -> Bool {
    guard let modelID,
          let model = LocalTextModelID(rawValue: modelID) else {
        return false
    }
    return model.canActAsAgent
}
```

---

## Critical Issues Found (Must Fix)

### Issue 1: Context Windows Are Wrong

**Problem**: The `maxContextTokens` values in InferenceState.swift are significantly lower than the models' actual capabilities:

| Model | Current Code | Actual Spec | Impact |
|-------|-------------|-------------|--------|
| Qwen 3.5 0.8B | 32,768 | 262,144 | 87% context wasted |
| Qwen 3.5 2B | 32,768 | 262,144 | 87% context wasted |
| Qwen 3.5 4B | 32,768 | 262,144 | 87% context wasted |
| Qwen 3.5 9B | 131,072 | 262,144 | 50% context wasted |
| Qwen 3.5 27B | 131,072 | 262,144 | 50% context wasted |
| Qwen 3.5 35B MoE | 131,072 | 262,144 | 50% context wasted |
| Gemma 4 2B | 262,144 | 128,000 | Over-committed |
| Gemma 4 4B | 131,072 | 128,000 | OK |
| Gemma 4 12B | 131,072 | 256,000 | 49% context wasted |
| Gemma 4 27B MoE | 262,144 | 256,000 | OK |
| Gemma 4 31B JANG | 262,144 | 256,000 | OK |
| DeepSeek R1 7B | 65,536 | 128,000 | 49% context wasted |

**Fix Required**: Update all context window values to match actual model specs.

### Issue 2: Model Catalog Still Has Old Models

**Problem**: `LocalModelCatalog.textDescriptors` in LocalModelInfrastructure.swift still contains:
- `gemma3_27BQAT4Bit` (Gemma 3 - should be removed)
- `llama4Scout17B16E4Bit` (Llama 4 - not in new stack)

And is **missing descriptors** for:
- `gemma4_2B4Bit`
- `gemma4_4B4Bit`
- `gemma4_12B4Bit`
- `gemma4_27BA4B4Bit` (note: enum says 27BA4B, should be 27BMoE)
- `gemma4_31BJANG`
- `deepseekR1Distill7B`
- `qwen25Coder7B`
- `qwopus27Bv3`
- `qwopusMoE35BA3B`

**Impact**: These 9 models can be selected in the UI but have no download/install metadata.

**Fix Required**: Update LocalModelCatalog with correct descriptors for all 18 models.

### Issue 3: model_manifest.json Not Populated

**Problem**: The config/model_manifest.json only has the retriever entry:
```json
{
  "models": {
    "retriever_primary": { ... }
  }
}
```

It should contain all 18 local inference models with their:
- Ollama tags
- Context windows
- Temperature defaults
- Vision/tool-calling flags
- Memory requirements

**Fix Required**: Populate model_manifest.json with full 18-model catalog.

### Issue 4: InferenceRouteKind Still Says "localQwen"

**Problem**: The enum case name is misleading:
```swift
nonisolated enum InferenceRouteKind: String, Sendable, Equatable {
    case appleIntelligence
    case localQwen  // ← Still Qwen-specific
}
```

While the string value "localQwen" is used in persistence, this should be renamed to `localMLX` for consistency with `TriageDecision.localMLX`.

**Fix Required**: Rename to `localMLX` and update all references.

### Issue 5: Temperature Values Inconsistent with Research

**Problem**: Per the research documents:
- Gemma 4 models should use **temp=1.0** (trained at this temperature)
- Qwen 3.5 models should use **temp=1.0/presence_penalty=1.5** for thinking mode
- DeepSeek R1 Distill should use **temp=0.6** (correct) but the range should be 0.5-0.7
- Devstral should use **temp=0.15** for coding (currently 0.4 in the recommendations)

Current code has:
- Gemma 4: 0.7 (too low)
- Qwen 3.5: 0.7 (OK but should be 1.0 for some variants)
- DeepSeek R1: 0.5 (correct)
- Qwen Coder: 0.3 (correct)

**Fix Required**: Update temperature values to match research findings.

### Issue 6: No Vision Encoder Integration

**Problem**: While `supportsVision` is defined for Gemma 4 models, there is no actual vision encoder integration:
- No image preprocessing pipeline
- No vision token budget management (70-1120 tokens per image for Gemma 4)
- No multimodal prompt formatting

**Fix Required**: Implement vision encoder loading and image tokenization.

### Issue 7: No Native Tool-Calling Extraction

**Problem**: While `supportsNativeToolCalling` is defined, there's no actual tool-call extraction logic:
- No parser for Gemma 4's `<start_function_call>` format
- No parser for Qwen's `<tool_call_start>` format
- No parser for SmolLM3's XML `<tool_call>` format
- No structured output validation

**Fix Required**: Implement tool-call parsers per model family.

### Issue 8: Missing Abliteration-Aware System Prompt

**Problem**: Gemma 4 31B JANG is marked as abliterated (`isAbliterated: true` is missing - need to add this property), but the system prompt doesn't adjust:

```swift
private static let localQwenBaselineSystemPrompt = """
You are Epistemos' local on-device assistant.
Answer directly and concisely.
Do not claim to have browsing, external tool use...
"""
```

For abliterated models, the "do not claim" coaching is unnecessary and conflicts with the model's training.

**Fix Required**: Add `isAbliterated` property and branch system prompt accordingly.

### Issue 9: Thinking Mode Template Keys Not Implemented

**Problem**: DeepSeek R1 Distill uses `<think>` tags natively, Qwen uses `enable_thinking`, but the code doesn't handle this:

```swift
var chatTemplateContext: [String: Bool]? {
    guard let model = LocalTextModelID(rawValue: modelID),
          model.supportsThinkingMode else { return nil }
    return ["enable_thinking": reasoningMode == .thinking]  // Qwen only
}
```

**Fix Required**: Add `thinkingTemplateKey` property and handle per-model activation.

---

## Medium-Priority Issues

### Issue 10: KV Cache Sizing May Be Conservative

Current KV cache values:
- Tiny models (0.8B, 2B): 8K, 6K
- Small models (4B): 4K
- Medium (7-9B): 3K, 2.5K
- Large (24-31B): 2K, 1.5K

Given that:
- Qwen 3.5 uses Gated DeltaNet (memory efficient)
- Gemma 4 uses hybrid attention with KV sharing
- MoE models only activate subset of parameters

The KV cache values could potentially be increased for better context retention, especially for the 256K context models.

### Issue 11: No Quantization-Aware Routing

The research identified specific quantization formats:
- Gemma 4: Q4_K_M, TQ3_4S, JANG_4M
- Qwopus: Q4_K_M
- DeepSeek: Q4_K_M

The system doesn't differentiate between quantization formats or route based on format compatibility.

### Issue 12: No Per-Model Reasoning Loop Guard

The `LocalMLXLoopMitigation` is hardcoded to Qwen 3.5 4B thinking mode only. DeepSeek R1 Distill is notorious for reasoning loops but isn't covered.

---

## What the User Asked For vs What Was Delivered

### User's Core Request:
> "just like what i have done to the cloud models with specific jsons and specific formats for the specific models i want to do that with my local models to make sure that i truly utilized the power of what each of these models are capable of pure"

### What Cloud Models Have (Per Research):
- JSON configuration files with exact context limits
- Specific tool schemas per model
- Per-model temperature/top-p/top-k
- Vision token budgets
- Specific reasoning modes (thinking tags)
- Header merging for model-specific flags

### What Local Models Now Have:
- ✅ Per-model context windows (but values are wrong)
- ✅ Per-model temperature (but values need tuning)
- ✅ Per-model KV cache sizing
- ✅ Agent capability gating
- ✅ Vision capability flags (but no encoder)
- ✅ Tool calling flags (but no extraction)
- ❌ No JSON configuration files
- ❌ No model-specific tool schemas
- ❌ No vision token budget management
- ❌ No reasoning tag extraction

---

## Recommended Fix Priority

### P0 - Critical (Blocks Full Utilization)
1. **Fix context window values** - Currently throwing away 50-87% of available context
2. **Update LocalModelCatalog** - 9 models have no install metadata
3. **Populate model_manifest.json** - Required for Ollama bridge integration

### P1 - High (Quality Impact)
4. **Fix temperature values** - Gemma 4 should be 1.0, verify all values
5. **Add thinking template key handling** - DeepSeek R1 needs `<think>` extraction
6. **Expand loop mitigation** - Cover DeepSeek R1 and other thinking models

### P2 - Medium (Completeness)
7. **Rename localQwen → localMLX** - Consistency with TriageDecision
8. **Add isAbliterated property** - JANG model needs different system prompt
9. **Add vision token budgets** - Prepare for encoder integration

### P3 - Lower (Advanced Features)
10. **Implement tool-call parsers** - Actually extract tool calls from model output
11. **Add vision encoder integration** - Load and use vision models
12. **Quantization-aware routing** - Handle different GGUF formats

---

## Code References

### Key Files:
- `Epistemos/State/InferenceState.swift` - LocalTextModelID enum with capabilities (lines 60-376)
- `Epistemos/Engine/LocalModelInfrastructure.swift` - Model catalog (lines 166-331)
- `Epistemos/Engine/MLXInferenceService.swift` - Generation parameters (lines 977-1000)
- `Epistemos/Engine/TriageService.swift` - Routing logic (lines 82, 398, 1273)
- `Epistemos/LocalAgent/ConfidenceRouter.swift` - Agent routing (lines 219-226)
- `config/model_manifest.json` - Model registry (needs population)

### What to Verify:
1. All 18 models have correct context windows matching their architecture specs
2. LocalModelCatalog has descriptors for all 18 models
3. Temperature values match research (Gemma 4 = 1.0)
4. model_manifest.json contains full model catalog
5. InferenceRouteKind is renamed to localMLX

---

## Summary

Claude Code implemented a **solid foundation** for per-model capability descriptors. The architecture is correct and the wiring is in place. However, **the values are wrong** - context windows are severely under-reported, the model catalog is incomplete, and several advanced features (vision, tool extraction) are flagged but not implemented.

To achieve the user's goal of "truly utilizing the power of what each of these models are capable of pure," the P0 and P1 fixes must be completed. The system is currently operating at approximately **50-75% of the models' actual capability** due to the context window and temperature misconfigurations.
