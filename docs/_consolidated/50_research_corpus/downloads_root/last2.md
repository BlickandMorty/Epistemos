# Epistemos Local Model Stack — Full Audit & Capability Synthesis

## Executive Summary

This audit covers the full 18-model local stack, the Rust `agent_core` infrastructure that powers it, the cloud provider wiring, and the capability gap between what was promised in the NCP session summary and what actually exists in code. The central finding is: **local inference is 100% broken at the provider level.** No local model can actually be invoked through `agent_core` — the bridge's `instantiate_provider()` panics with an unsupported-provider error for every local model name. Beyond that critical blocker, the infrastructure treats all 18 models identically when it comes to context limits, temperature, tool-calling guards, KV cache strategy, and vision routing — meaning even after wiring is fixed, the models would be severely under-utilized. This document gives Claude Code everything it needs to fix both problems completely.

***

## Part 1: Cloud Provider Health (Baseline)

The three cloud stacks are correctly wired and can be used as the reference implementation.

### Claude (Anthropic)

`ClaudeProvider` in `claude.rs` is the gold standard. It has:
- **Per-model capability declarations** via the `capabilities()` match arms (Opus/Sonnet/Haiku with different context, cost, thinking, and computer-use flags)
- **4-breakpoint Anthropic prompt caching** via `cache_system_prompt()` + `apply_message_cache_breakpoints()` in `prompt_caching.rs`, saving ~85% on repeated-context input token costs
- **Extended thinking** via the `adaptive` mode with `effort` parameter, correctly gated away from Haiku
- **Native tool use** with proper SSE assembly across streaming deltas
- **Vision**, **web search**, **code execution**, **MCP servers** all feature-flagged per-request
- **Model names** are current: `claude-opus-4-6`, `claude-sonnet-4-6`, `claude-haiku-4-5`

**Status: ✅ Healthy.**

### OpenAI

`OpenAIProvider` in `openai.rs` is correct for its four models. It handles streaming tool call assembly across fragmented deltas, vision via `image_url`, tool results as `role: tool` messages, and per-model capability tuples. The `o1`/`o3-mini` reasoning models correctly set 200K context and 100K output.

**Status: ✅ Healthy.**

### Perplexity

`PerplexityProvider` with `sonar-pro` is wired in `bridge.rs` and `instantiate_provider()`. The routing logic in `routing.rs` correctly sends research/current-info objectives to Perplexity.

**Status: ✅ Healthy.**

***

## Part 2: Critical Infrastructure Failures

### Failure 1 — No Local Provider Exists

`bridge.rs` `instantiate_provider()` is an exhaustive match with no local arms:

```rust
// Current code — all local model names fall through here:
_ => Err(AgentErrorFFI::AgentError {
    message: format!("Unsupported provider in agent_core bridge: {name}"),
})
```

**Every single one of the 18 local models results in a hard error.** The routing logic in `routing.rs` already recognizes `RoutingDecision::Local` and `LocalWithFallback`, but the bridge test explicitly asserts that `auto_local_only` routes have `supported: false`. The NCP/Ollama bridge described in the session summary does not exist in any source file — there is no `OllamaProvider`, `OpenAICompatibleProvider`, or `LlamaCppProvider` struct anywhere.

**Fix Required:** Create `OllamaProvider` (an `OpenAI`-compatible provider with a configurable `base_url` field pointing to `http://localhost:11434/v1`) and register all 18 model names in `instantiate_provider()`. Ollama exposes a full OpenAI-compatible `/v1/chat/completions` endpoint, so `openai.rs`'s streaming logic is almost entirely reusable — the only change is removing the hardcoded `OPENAI_API` const and adding a `base_url: String` field to the provider struct.[^1]

### Failure 2 — `OpenAIProvider` Has a Hardcoded Remote URL

`openai.rs` declares `const OPENAI_API: &str = "https://api.openai.com/v1/chat/completions"` and never uses any configurable base URL. The struct has no `base_url` field. The Ollama OpenAI-compat layer sits at `http://localhost:11434/v1/chat/completions` — completely unreachable through any existing provider.

**Fix Required:** Add `base_url: String` to the `OpenAIProvider` struct (or a new `OllamaProvider` struct that clones the logic). Provide an `ollama(model_name: &str)` constructor that points to `http://localhost:11434/v1/chat/completions` with `api_key: "ollama".to_string()`.

### Failure 3 — No Per-Model Context Budget

`context_compiler.rs` uses `DEFAULT_MAX_CONTEXT_CHARS: usize = 24_000` (~6K tokens) for every model regardless of their actual context windows. Meanwhile:
- Gemma 4 E2B/E4B support 128K tokens[^2]
- Gemma 4 26B MoE and 31B support 256K tokens[^2]
- All Qwen 3.5 models (0.8B through 35B) support 262K tokens natively[^3][^4]
- Qwen 2.5 Coder 7B supports 128K tokens[^5]
- SmolLM3 3B supports 128K tokens (64K trained, YaRN to 128K)[^6][^7]
- Devstral Small 24B supports 256K tokens[^8][^9]
- Mistral Small 24B supports 128K tokens[^10]

Capping every model at ~6K characters throws away between 95–99% of the available context window for every model in Tier 3 and Tier 4.

**Fix Required:** The `ContextCompiler::new()` constructor must accept a `max_context_chars` value derived from the model's actual context window (retrieved from the per-model catalog, described below). The `with_max_context_chars()` builder already exists; it just needs to be called with real values.

### Failure 4 — Compaction Budget Is Hardcoded

`compact_messages(messages, 8, 16_384)` is called identically for every model. For a 256K model like Devstral or Gemma 4 27B MoE, this discards 93% of available context at compaction time. For a 6K-effective-context small model under heavy VRAM pressure, 16K may be too large.

**Fix Required:** Pass the model's actual `max_context_tokens` into `compact()` via `AgentConfig` or via a per-provider override so that compaction targets ~75% of the actual window.

### Failure 5 — `ProviderCapabilities` Missing Local-Specific Fields

The current `ProviderCapabilities` struct lacks:
- `num_ctx: Option<u32>` — Ollama requires this as a runtime option to unlock the full context window; without it, Ollama defaults to 2048 tokens regardless of model[^1]
- `temperature: f32` — each model family has a different optimal default
- `supports_tool_calling: bool` — needed to gate tool payload injection
- `is_reasoning_model: bool` — needed to trigger `<think>` tag extraction for DeepSeek R1 Distill
- `is_moe: bool` and `active_params: Option<u32>` — needed to correctly document and route MoE models
- `supports_vision: bool` — already in the struct but never populated for local models; critical for Gemma 4 and Devstral

**Fix Required:** Extend `ProviderCapabilities` with these fields. Set them correctly per model in the `OllamaProvider::capabilities()` implementation.

### Failure 6 — `AgentConfig` Has No Temperature or Sampling Controls

`AgentConfig` in `agent_loop.rs` has no `temperature`, `top_p`, or `repeat_penalty` fields. The OpenAI body builder in `openai.rs` never injects temperature. Ollama's OpenAI-compat layer supports `temperature` in the standard request body, but there is no mechanism to pass a per-model temperature value through the chain.[^11]

**Fix Required:** Add `temperature: Option<f32>` to `AgentConfig`. In `OllamaProvider::stream_message()`, inject it into the request body. Provide sane defaults per tier (see model catalog below).

***

## Part 3: Per-Model Capability Catalog

This is the core deliverable. Each of the 18 models has a distinct capability profile that must be encoded as a structured descriptor. The table below is the ground truth that should drive the `LocalModelDescriptor` struct.

### Tier 1 — Ultra-Light (Routing / Quick Tasks)

| Model | Ollama Tag | Context (tokens) | Tool Calling | Vision | Reasoning Mode | Temperature | MoE | Notes |
|-------|-----------|-----------------|-------------|--------|---------------|-------------|-----|-------|
| Gemma 4 E2B | `gemma4:2b` | 128K[^2] | ✅ Native[^12] | ✅ + Audio[^2][^13] | ✅ Configurable thinking[^12] | 0.7 | ❌ Dense | Effective 2.3B params; 5.1B with embeddings |
| Qwen 3.5 0.8B | `qwen3.5:0.8b` | 262K[^3] | ✅ Native[^3] | ✅ Native multimodal[^3] | ✅ `/think` + `/no_think`[^3] | 0.7 | ❌ Dense hybrid GDN |
| Qwen 3.5 2B | `qwen3.5:2b` | 262K[^3] | ✅ Native[^3] | ✅ Native multimodal[^3] | ✅ `/think` + `/no_think`[^3] | 0.7 | ❌ Dense hybrid GDN |

### Tier 2 — Light (General Assistant)

| Model | Ollama Tag | Context (tokens) | Tool Calling | Vision | Reasoning Mode | Temperature | MoE | Notes |
|-------|-----------|-----------------|-------------|--------|---------------|-------------|-----|-------|
| Gemma 4 E4B | `gemma4:4b` | 128K[^2] | ✅ Native[^12] | ✅ + Audio[^2][^13] | ✅ Configurable thinking[^12] | 0.7 | ❌ Dense | Effective 4.5B; 8B with embeddings |
| Qwen 3.5 4B | `qwen3.5:4b` | 262K[^3] | ✅ Native[^3] | ✅ Native multimodal[^3] | ✅ `/think` + `/no_think`[^3] | 0.7 | ❌ Dense hybrid GDN |
| SmolLM3 3B | `smollm3:3b` | 128K[^14][^7] | ✅ XML + Python tool formats[^15][^7] | ❌ Text only[^15] | ✅ `enable_thinking` flag[^7] | 0.7 | ❌ Dense | Custom chat template required for tool format |

### Tier 3 — Medium (Serious Work)

| Model | Ollama Tag | Context (tokens) | Tool Calling | Vision | Reasoning Mode | Temperature | MoE | Notes |
|-------|-----------|-----------------|-------------|--------|---------------|-------------|-----|-------|
| DeepSeek R1 Distill 7B | `deepseek-r1:7b` | 128K[^16] | ⚠️ Limited | ❌ | ✅ `<think>` tag streaming[^17] | 0.6 | ❌ Dense | **Requires `<think>` tag extraction — raw tags will bleed into output if unhandled** |
| Qwen 2.5 Coder 7B | `qwen2.5-coder:7b` | 128K[^5] | ✅ Good for code agents[^18] | ❌ Text/code only[^5] | ❌ No built-in reasoning mode | 0.3 | ❌ Dense | Optimized for code; lower temperature recommended |
| Qwen 3.5 9B | `qwen3.5:9b` | 262K[^3] | ✅ Native[^3] | ✅ Native multimodal[^3] | ✅ `/think` + `/no_think`[^3] | 0.7 | ❌ Dense hybrid GDN |
| Gemma 4 12B | `gemma4:12b` | 128K[^2] | ✅ Native[^12] | ✅ Images + video[^12][^2] | ✅ Configurable thinking[^12] | 0.7 | ❌ Dense | *(Note: catalog lists 12B; Google canonical releases are E2B/E4B/26B/31B — confirm Ollama tag resolves correctly)* |

### Tier 4 — Large (Frontier Local)

| Model | Ollama Tag | Context (tokens) | Tool Calling | Vision | Reasoning Mode | Temperature | MoE | Active Params | Notes |
|-------|-----------|-----------------|-------------|--------|---------------|-------------|-----|--------------|-------|
| Gemma 4 27B MoE | `gemma4:27b-moe` | 256K[^2] | ✅ Native[^12] | ✅ Images + video[^2] | ✅ Configurable thinking[^12] | 0.7 | ✅ 26B total / 4B active[^2][^19] | ~4B | #6 open model on Arena leaderboard[^13] |
| Gemma 4 31B JANG | `gemma4:31b` | 256K[^2] | ✅ Native[^12] | ✅ Images + video[^2] | ✅ Configurable thinking[^12] | 0.7 | ❌ Dense | 31B | Abliterated variant — no safety refusals |
| Qwopus 27B v3 | `qwopus3.5:27b-v3` | 262K[^20] | ✅ (inherits Qwen 3.5 27B) | ✅ (inherits Qwen 3.5 27B) | ✅ Reasoning-enhanced[^20] | 0.65 | ❌ Dense | 27B | 95.73% HumanEval[^20]; based on Qwen 3.5-27B |
| Qwopus MoE 35B | `qwopus3.5:35b-moe` | 262K[^4] | ✅ | ✅ | ✅ | 0.65 | ✅ 35B total / 3B active[^4] | ~3B | Fastest in stack; 19× throughput gain at 256K[^21] |
| Qwen 3.5 27B | `qwen3.5:27b` | 262K[^3] | ✅ Native[^3] | ✅ Native multimodal[^3] | ✅ `/think` + `/no_think`[^3] | 0.7 | ❌ Dense | 27B |
| Qwen 3.5 35B MoE | `qwen3.5:35b-moe` | 262K[^4] | ✅ Native[^3] | ✅ Native multimodal[^3] | ✅ `/think` + `/no_think`[^4] | 0.7 | ✅ 35B total / 3B active[^4] | ~3B | Needs ≥128K context to preserve thinking[^4] |
| Devstral Small 24B | `devstral:24b` | 256K[^8][^9] | ✅ Designed for agentic tool use[^9] | ✅ Image inputs[^8] | ❌ No built-in reasoning mode | 0.15[^9] | ❌ Dense | 24B | SWE-bench optimized; Mistral tool-call parser required[^9] |
| Mistral Small 24B | `mistral-small3.1:24b` | 128K[^10] | ✅ Low-latency function calling[^10] | ✅ Vision[^10] | ❌ No built-in reasoning mode | 0.7 | ❌ Dense | 24B | |

***

## Part 4: Specific Wiring Issues per Model Family

### Gemma 4 Family (6 models)

All Gemma 4 models support **native function calling**, making them fully compatible with the existing OpenAI tool-call format used by `openai.rs`. The E2B and E4B models additionally support **audio input** — the current `UserContent` enum has no `Audio` variant, so audio capability is architecturally blocked until that is added.[^12][^13][^2]

**Thinking mode** is supported across the entire family via a configurable thinking parameter, but it is **not the same as Anthropic's `<thinking>` block format**. For Gemma 4 running via Ollama, thinking mode is enabled by passing the prompt through the chat template with `enable_thinking=True` — it is surfaced as regular text tokens prefixed with `<think>...</think>` tags in the output stream. The current `StreamEvent::ThinkingDelta` is hardwired only to Anthropic's `ContentBlockStart::Thinking` SSE event type and will **never fire for local models**. A text-level `<think>` tag extractor is needed in the Ollama streaming parser to surface thinking content via the existing `ThinkingDelta` event.[^17][^12]

The **26B MoE** and **31B dense** models support a 256K context window. `num_ctx` must be explicitly set in the Ollama request options to unlock this — without it, Ollama defaults to 2048 tokens. The value to pass is `num_ctx: 262144` for full 256K utilization.[^2][^1]

### Qwen 3.5 Family (5 models: 0.8B, 2B, 4B, 9B, 27B, 35B MoE)

All Qwen 3.5 models share a **hybrid Gated Delta Network + MoE architecture** with a native **262K context window**. Tool calling is a first-class capability across all sizes including the 0.8B, which is a significant architectural upgrade from prior generations where small models lacked reliable tool use.[^4][^3]

The reasoning mode uses `/think` and `/no_think` mode tags injected into the system prompt, not separate token types. The 35B MoE model specifically requires **at least 128K context** to preserve thinking capability — if `num_ctx` is set below 128K, thinking degrades significantly. This is the only model in the stack with a minimum context requirement (as opposed to a maximum).[^7][^4]

For the **35B MoE and 27B models**, `num_ctx: 262144` should be passed and Ollama should be configured with `--num-gpu-layers` covering the full model to avoid CPU offload latency.

### Qwopus Family (2 models)

Qwopus 27B v3 is a **fine-tune of Qwen 3.5-27B** with reasoning-enhanced training, achieving 95.73% HumanEval pass@1. It inherits all Qwen 3.5-27B capabilities including 262K context, native tool calling, and vision. The Qwopus MoE 35B is the corresponding MoE variant and is described as the **fastest model in the tier**. Both should use the same Ollama configuration as their Qwen 3.5 base counterparts, with a slightly lower temperature (0.65) to preserve the reasoning quality improvements.[^21][^20]

### DeepSeek R1 Distill 7B — Special Handling Required

This model is the most architecturally divergent. It outputs reasoning content wrapped in **`<think>...</think>` tags** that appear directly in the text stream. Without special handling, these tags bleed into the user-visible output verbatim. The fix requires a post-processing layer in the Ollama streaming parser that:[^17]
1. Detects `<think>` open tag and switches to buffering mode
2. Routes buffered content to `StreamEvent::ThinkingDelta` instead of `TextDelta`
3. Detects `</think>` close tag and resumes normal text emission

Note: there is ambiguity in the community about whether `<think>` or `<thinking>` is the correct tag for the 7B Qwen-base distill variant. The Ollama `deepseek-r1:7b` model card uses `<think>`. The streaming parser should handle both to be safe.[^22][^16]

Tool calling reliability is limited for this model — it was not trained for structured tool use the way Qwen 3.5 or Gemma 4 were. Tools should be **disabled by default** for DeepSeek R1 Distill and only injected if the caller explicitly opts in.

### SmolLM3 3B — Custom Tool Format

SmolLM3 3B has tool calling but uses a **non-standard XML format**: tools are wrapped in `<tool_call>{"name": "...", "arguments": {...}}</tool_call>` tags rather than the OpenAI `function` format. The existing `openai.rs` tool-call assembler parses `tool_calls[].function.name` and `tool_calls[].function.arguments` from the streaming delta — it will **not** parse SmolLM3's XML output.[^15][^7]

Two options exist: (1) pre-process tool schemas through SmolLM3's chat template via the `xml_tools` parameter before sending to Ollama, and add a response parser that extracts the XML tool calls and maps them to `ContentBlock::ToolUse`; or (2) use `python_tools` mode which produces Python function call syntax. Option (1) is preferable since it maps to existing `ContentBlock::ToolUse` without new types.

Additionally, SmolLM3 supports **`/think`** and **`/no_think`** mode flags identical to Qwen 3.5's approach.[^7]

### Devstral Small 24B — Mistral Tool Parser

Devstral Small is purpose-built for agentic coding and achieves strong SWE-bench scores. It uses the **Mistral tool-call parser** format (`--tool-call-parser mistral` in vLLM) rather than the OpenAI function format. When served via Ollama, it should correctly output OpenAI-compatible tool call JSON since Ollama normalizes the format — but this should be verified at integration time. Devstral has the **lowest recommended temperature** in the stack (0.15), reflecting its deterministic, code-execution-focused character.[^9]

### Mistral Small 24B

Standard Mistral architecture with 128K context, vision, and low-latency function calling. Fully compatible with OpenAI tool format via Ollama. No special handling required.[^10]

***

## Part 5: KV Cache Strategy Per Model

Anthropic prompt caching applies 4 breakpoints that are entirely specific to the Anthropic API. **None of these should be sent to Ollama** — they are Anthropic-specific request fields and will be silently ignored or cause errors.

For Ollama, KV cache strategy is managed differently:
- **`num_keep`**: Number of tokens from the system prompt to keep permanently in the KV cache. Should be set to approximately the character count of the system prompt divided by 4. This replaces breakpoint 1 (system prompt caching).
- **Context reuse**: Ollama automatically reuses the KV cache when the same model receives the same prefix — no explicit breakpoints needed.
- **`num_ctx`**: Must match or exceed the actual context being sent; otherwise Ollama silently truncates.

The Ollama request body should include an `options` object:
```json
{
  "options": {
    "num_ctx": <model_context_window>,
    "num_keep": <system_prompt_token_estimate>,
    "temperature": <per_model_temperature>
  }
}
```

This is an Ollama-specific extension to the OpenAI-compat body format and must be added by the `OllamaProvider::stream_message()` implementation.[^23][^11]

***

## Part 6: Routing Layer — What Needs to Change

`routing.rs` `LocalTask` has only four variants: `GhostWrite`, `Classify`, `Embed`, `SimpleTool`. None of these map to specific local models. The `ConfidenceRouter` never selects a local model — it always falls back to cloud. The bridge asserts `supported: false` for all `auto_local_only` routes.

To make routing work properly, `LocalTask` needs to be expanded:
- Add `Inference { model_name: String, tier: u8 }` variant
- Add `VisionInference { model_name: String }` variant (gates vision-capable models only)
- Add `CodeInference { model_name: String }` (gates to Qwen 2.5 Coder or Devstral)
- Add `ReasoningInference { model_name: String }` (gates to DeepSeek R1 Distill, Qwopus, or Gemma 4 thinking models)

The `ConfidenceRouter::route()` logic should be extended with VRAM-aware tier selection: route simple tasks to Tier 1 models, medium tasks to Tier 3, and only escalate to Tier 4 for complex multi-step tasks. Privacy-sensitive tasks should always route local regardless of complexity.

`bridge.rs`'s `resolve_provider_selection_preview()` must add match arms for all 18 model names (e.g., `"gemma4_2b"`, `"qwen35_9b"`, `"deepseek_r1_7b"`, `"devstral_24b"` etc.) and map them to the Ollama instantiation path.

***

## Part 7: `AgentConfig` + `AgentConfigFFI` — Required Extensions

`AgentConfig` in `agent_loop.rs` needs two new fields to support local models fully:

```rust
pub struct AgentConfig {
    // existing fields...
    pub temperature: Option<f32>,    // per-model default injected by OllamaProvider
    pub num_ctx: Option<u32>,        // explicit context window for Ollama
}
```

`AgentConfigFFI` in `bridge.rs` needs corresponding additions so Swift can pass these through:

```rust
pub struct AgentConfigFFI {
    // existing fields...
    pub temperature: Option<f32>,
    pub num_ctx: Option<u32>,
}
```

The `AgentConfig::from_ffi()` conversion method must be updated accordingly.

***

## Part 8: `ProviderCapabilities` — Required New Fields

The existing struct must be extended:

```rust
pub struct ProviderCapabilities {
    // existing fields preserved...
    pub supports_tool_calling: bool,      // gate for injecting tools into request
    pub supports_vision: bool,            // gate for routing image-bearing messages
    pub is_reasoning_model: bool,         // trigger <think> tag extraction
    pub is_moe: bool,                     // informational / routing
    pub active_params: Option<u32>,       // MoE active param count in millions
    pub default_temperature: f32,         // per-model optimal default
    pub max_output_tokens: usize,         // already in struct, must be set correctly
    pub num_ctx: Option<u32>,             // Ollama context window to request
}
```

The `supports_vision` field is already present in the struct — it just needs to be populated for local models. `supports_tool_calling` is new and critical: when `false`, the `stream_message()` call must strip the `tools` slice before building the request body to avoid sending tool schemas to models that will hallucinate or error on them.

***

## Part 9: `model_manifest.json` — Needs Full Population

`config/model_manifest.json` currently only has one entry for `BAAI/bge-m3` (the retriever, status `"missing"`). None of the 18 inference models are listed. This file should be extended with the full catalog:

```json
{
  "models": [
    {
      "id": "gemma4-2b",
      "ollama_tag": "gemma4:2b",
      "tier": 1,
      "params_b": 2.3,
      "active_params_b": 2.3,
      "vram_gb": 1.5,
      "context_tokens": 131072,
      "default_temperature": 0.7,
      "supports_tools": true,
      "supports_vision": true,
      "supports_audio": true,
      "supports_thinking": true,
      "is_moe": false,
      "is_abliterated": false,
      "family": "gemma4"
    },
    // ... all 18 models
  ]
}
```

This manifest feeds the `OllamaProvider` factory so that `instantiate_provider("gemma4_2b")` looks up the entry, reads `ollama_tag`, `context_tokens`, `default_temperature`, and `supports_tools`, and constructs the provider with the correct parameters.

***

## Part 10: Summary of Changes for Claude Code

The following is an ordered implementation plan:

1. **Add `base_url` field to `OpenAIProvider`** (or create `OllamaProvider` as a fork) so local Ollama models can be reached at `http://localhost:11434/v1/chat/completions`.[^1]

2. **Register all 18 model names in `bridge.rs` `instantiate_provider()`** with Ollama-backed constructors pointing to the correct `ollama_tag` from the catalog.

3. **Add `options: { num_ctx, temperature, num_keep }` injection** to the Ollama request body builder. This is the single most important Ollama-specific configuration.[^11][^23]

4. **Add `<think>` / `</think>` tag extractor** to the Ollama streaming parser to route DeepSeek R1 Distill and Gemma 4 / Qwen 3.5 thinking tokens into `StreamEvent::ThinkingDelta` instead of `TextDelta`.[^17]

5. **Add `supports_tool_calling` guard** in `stream_message()`: if `capabilities().supports_tool_calling == false`, pass an empty `tools` slice to the API regardless of what `AgentConfig` says.

6. **Extend `ProviderCapabilities`** with the fields enumerated in Part 8 above.

7. **Extend `AgentConfig` and `AgentConfigFFI`** with `temperature: Option<f32>` and `num_ctx: Option<u32>`.

8. **Populate `model_manifest.json`** with the full 18-model catalog using the specifications from Part 3.

9. **Update `ContextCompiler`** to accept the model's context window as input and set `max_context_chars` to `(context_tokens * 4) * 0.85` (char-to-token ratio with 15% safety margin).

10. **Update `compact_messages()`** call sites to pass the model's actual token budget instead of the hardcoded 16,384.

11. **Add SmolLM3 XML tool-call response parser** that maps `<tool_call>{...}</tool_call>` output to `ContentBlock::ToolUse`.[^15][^7]

12. **Update `routing.rs`** `LocalTask` with tier-aware model selection variants and extend `ConfidenceRouter::route()` to actually dispatch to local models for privacy-sensitive, low-latency, and offline tasks.

13. **Do not send Anthropic prompt caching headers to Ollama.** Cache logic in `prompt_caching.rs` must be gated to `ClaudeProvider` only — which it already is, but this must be verified after `OllamaProvider` is created to ensure no accidental use.

14. **Verify Gemma 4 12B Ollama tag.** The canonical Gemma 4 release has sizes E2B, E4B, 26B MoE, and 31B. A "12B" is not in Google's official release. The catalog entry may refer to a community GGUF or a mislabeled variant — confirm the correct `ollama pull` tag before hardcoding it.[^19][^2]

---

## References

1. [OpenAI compatibility - Ollama's documentation](https://docs.ollama.com/api/openai-compatibility) - Ollama provides compatibility with parts of the OpenAI API to help connect existing applications to ...

2. [Welcome Gemma 4: Frontier multimodal intelligence on device](https://huggingface.co/blog/gemma4) - The text decoder is based on the Gemma model with support for long context windows. ... for tool cal...

3. [[Deep Dive] Qwen 3.5 Brings Native Multimodality and Long Context ...](https://trilogyai.substack.com/p/deep-dive-qwen-35-brings-native-multimodality) - Context length jumps to 262K natively across the full model lineup, including the 0.8B, 2B, 4B, and ...

4. [Qwen/Qwen3.5-35B-A3B - Hugging Face](https://huggingface.co/Qwen/Qwen3.5-35B-A3B) - The model has a default context length of 262,144 tokens. If you encounter out-of-memory (OOM) error...

5. [Qwen/Qwen2.5-Coder-7B - Hugging Face](https://huggingface.co/Qwen/Qwen2.5-Coder-7B) - Long-context Support up to 128K tokens. This repo contains the 7B Qwen2.5-Coder model, which has the...

6. [The Best Open-Source Small Language Models (SLMs) in 2026](https://www.bentoml.com/blog/the-best-open-source-small-language-models) - Designed with function calling and structured (JSON-style) outputs in mind, it can be easily integra...

7. [SmolLM3: smol, multilingual, long-context reasoner - Hugging Face](https://huggingface.co/blog/smollm3) - SmolLM3 supports tool calling! Just pass your list of tools under the argument xml_tools (for standa...

8. [Introducing: Devstral 2 and Mistral Vibe CLI.](https://mistral.ai/news/devstral-2-vibe-cli) - Devstral Small 2, a 24B-parameter model with the same 256K context window and released under Apache ...

9. [mistralai/Devstral-Small-2-24B-Instruct-2512 - Hugging Face](https://huggingface.co/mistralai/Devstral-Small-2-24B-Instruct-2512) - Key Features · Agentic Coding: Devstral is designed to excel at agentic coding tasks, making it a gr...

10. [mistral-small3.1:24b-instruct-2503-q4_K_M - Ollama](https://ollama.com/library/mistral-small3.1:24b-instruct-2503-q4_K_M) - This new model comes with improved text performance, multimodal understanding, and an expanded conte...

11. [How to Use Ollama API - OneUptime](https://oneuptime.com/blog/post/2026-02-02-ollama-api/view) - This guide covers every aspect of the Ollama API, from basic requests to advanced patterns like stre...

12. [Gemma 4 model card | Google AI for Developers](https://ai.google.dev/gemma/docs/core/model_card_4) - Function Calling – Native support for structured tool use, enabling agentic workflows. Coding – Code...

13. [Gemma 4: Byte for byte, the most capable open models - Google Blog](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/) - At the edge, our E2B and E4B models redefine on-device utility, prioritizing multimodal capabilities...

14. [SmolLM3: smol 3B, multilingual, long-context reasoner](https://smollm3.com) - SmolLM3 delivers exceptional multilingual reasoning, long-context understanding, and tool-calling ca...

15. [HuggingFaceTB/SmolLM3-3B · Hugging Face](https://huggingface.co/HuggingFaceTB/SmolLM3-3B) - Agentic Usage. SmolLM3 supports tool calling! Just pass your list of tools: Under the argument xml_t...

16. [deepseek-r1:7b - Ollama](https://ollama.com/library/deepseek-r1:7b) - DeepSeek-R1 is a family of open reasoning models with performance approaching that of leading models...

17. [How to Set Up and Run DeepSeek-R1 Locally With Ollama](https://www.datacamp.com/tutorial/deepseek-r1-ollama) - The ollama_llm() function formats the user's question and the retrieved document context into a stru...

18. [Qwen2.5 Coder 7B Instruct - API Pricing & Providers - OpenRouter](https://openrouter.ai/qwen/qwen2.5-coder-7b-instruct) - It is optimized for agentic coding tasks such as function calling, tool use, and long-context reason...

19. [[AINews] Gemma 4: The best small Multimodal Open Models ...](https://www.latent.space/p/ainews-gemma-4-the-best-small-multimodal) - Commenters highlight the model's native thinking and tool-calling ... vision tasks and others doubti...

20. [Jackrong/Qwopus3.5-27B-v3-GGUF - Hugging Face](https://huggingface.co/Jackrong/Qwopus3.5-27B-v3-GGUF) - Consequently, the number of tasks affected by context window truncation has changed for each model, ...

21. [Qwen 3.5 Developer Guide: Benchmarks, Architecture & Integration](https://lushbinary.com/blog/qwen-3-5-developer-guide-benchmarks-architecture-integration-2026/) - Complete developer guide to Alibaba's Qwen 3.5 model family. Covers the 397B MoE flagship, medium (2...

22. [deepseek-ai/DeepSeek-R1-Distill-Llama-70B - Hugging Face](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Llama-70B/discussions/8) - What do you mean using think tags, I assumed the model should automatically generate the think tags ...

23. [The Complete Guide to Ollama: Local LLM Inference Made Simple](https://read.theaimerge.com/p/the-complete-guide-to-ollama-local) - A deep dive into Ollama's architecture, going through model management, OpenAI API schema and local ...

