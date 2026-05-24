# Model Grammar Matrix — 2026-05-17

Scope: §4.F Phase A grammar audit. This document distinguishes live grammar support from desired constellation support.

| Model/provider family | Native tool grammar target | Current Epistemos wiring | Strict masking status | Audit state |
|---|---|---|---|---|
| Qwen local | XML `<tool_call>` JSON object | `LocalAgentPromptBuilder` + `agent_runtime::prompt_format` + `LocalToolGrammar.qwenXML` emit XML with JSON arguments. | Conditional on `MLXStructured && CMLXStructured && JSONSchema`; soft guidance always on. | PRIMARY |
| Nous/Hermes format parity | XML `<tool_call>` JSON object | `LocalToolGrammar.hermesJSON` preserves format-parity grammar only. This is not subprocess resurrection. | Same global import gate. | PRIMARY/PARITY |
| LocalAgent 4.3 36B | Function-calling specialist, Hermes/Qwen-compatible profile | Allowed by `canActAsAgent` behind opt-in/power-user RAM gates; picker exposes OOM-risk badge when constrained. | Same global import gate. | PARTIAL, LIVE PROOF PENDING |
| DeepSeek-Coder / DeepSeek distill | Code-oriented tool-call prompt with JSON argument repair | `LocalToolGrammar.deepSeekCoder` profile exists and router can prefer it for code tasks; parser coverage is still soft/canonical rather than strict-masked. | Same global import gate; no per-family strict counter yet. | PARTIAL |
| Llama 3.3 / Llama-family local | Llama chat / JSON function-call style | `LocalToolGrammar.llama33` profile exists for Llama-family JSON calls. Local enum coverage is still broader than the proven fixture set. | Same global import gate; no per-family strict counter yet. | PARTIAL |
| Mistral Small | Mistral tool-call/chat-template style | `LocalToolGrammar.mistralSmall` supports `[TOOL_CALLS]tool.name[CALL_ID]...[ARGS]{json}` plus `[TOOL_CALLS][{...}]` array output; `canActAsAgent` is enabled for Mistral Small. | Same global import gate; named and array parser fixtures pass. | ENABLED/PARTIAL |
| Devstral | Mistral-family tool-call/chat-template style | Native-tool-capable in model metadata, but `canActAsAgent` remains false until Devstral-specific fixtures or live proof pass. Picker should show experimental/soft risk, not agent-ready. | Off by allow-list. | HONESTLY OFF |
| Phi-4 / Phi-4-mini | Phi tool-call markers plus JSON fallback | `LocalToolGrammar.phi4` and `phi4Mini` profiles exist; parser accepts `<|tool_call|>` and JSON-shaped output. Broader corpus and live MLX proof remain pending. | Same global import gate; no per-family strict counter yet. | PARTIAL |
| Gemma 3/4 | Non-XML function-call JSON inside assistant turn | Explicitly denied because XML prompt produced malformed output in observed user run. | Off by allow-list. | ABSENT, HONESTLY OFF |
| OpenAI cloud | Responses API function calls | `agent_core/src/providers/openai.rs` streams function-call arguments and maps tool calls to typed blocks. | Provider-native, not local MLX masking. | SHIPPED CLOUD |
| OpenAI-compatible cloud | Chat Completions `tool_calls` | `agent_core/src/providers/openai_compatible.rs` accumulates streamed `tool_calls`. | Provider-native. | SHIPPED CLOUD |
| Anthropic Claude | `tool_use` / `tool_result` content blocks | `agent_core/src/providers/claude.rs` preserves thinking, signatures, and tool-use events. | Provider-native. | SHIPPED CLOUD |
| Gemini | `functionCall` / `functionResponse` parts | `agent_core/src/providers/gemini.rs` maps function declarations and streamed function calls. | Provider-native. | SHIPPED CLOUD |
| Perplexity | No tools in current provider path | Provider converts tool results to text; finish reason can map `tool_calls`, but no tool schema dispatch is advertised. | N/A. | CHAT/RESEARCH ONLY |

## Required Next Tests

- Fixture parse tests per local family: Qwen XML, LocalAgent XML, DeepSeek-Coder, Llama-family JSON, broader Mistral corpus, Phi-family.
- Live MLX proof for Mistral Small, Phi-4, Phi-4-mini, and LocalAgent 4.3 36B before marking them fully strict-capable.
- Badge derivation tests: `STRICT-CAPABLE`, `SOFT-GUIDED`, `OFF`.
- Drift counter tests: strict parse fail increments per model and demotes badge without disabling the soft local loop.

## Doctrine Rule

Do not add another family to `canActAsAgent` unless one of these is true:

1. Strict MLX grammar masking compiles for that model family and passes a `vault.write` round-trip fixture.
2. A model-family soft-guidance prompt has a passing parser/repair fixture and is labeled `SOFT-GUIDED`, not `STRICT-CAPABLE`.
3. The user explicitly opts into experimental mode and the picker shows the exact unsupported grammar risk.
