# Model Grammar Matrix — 2026-05-17

Scope: §4.F Phase A grammar audit. This document distinguishes live grammar support from desired constellation support.

| Model/provider family | Native tool grammar target | Current Epistemos wiring | Strict masking status | Audit state |
|---|---|---|---|---|
| Qwen local | XML `<tool_call>` JSON object | `LocalAgentPromptBuilder` + `agent_runtime::prompt_format` + `LocalToolGrammar` all emit Hermes/Qwen-style XML. | Conditional on `MLXStructured && CMLXStructured && JSONSchema`; soft guidance always on. | PARTIAL/PRIMARY |
| Nous/Hermes format parity | XML `<tool_call>` JSON object | Same as Qwen. This is prompt-format parity, not subprocess resurrection. | Same global import gate. | PARTIAL/PRIMARY |
| LocalAgent 4.3 36B | Function-calling specialist, likely Hermes/Qwen XML-compatible by current prompt | Allowed by `canActAsAgent`; no separate grammar profile. | Same global import gate. | PARTIAL |
| DeepSeek-Coder / DeepSeek distill | Code/tool-call template should be model-specific | Allowed by `canActAsAgent`; receives XML prompt. | Same global import gate. | STALE/PARTIAL |
| Llama 3.3 / Llama-family local | Llama chat / JSON function-call style | No local Llama 3.3 grammar profile found; Llama 4 Scout is allow-listed but receives XML prompt. | Same global import gate. | ABSENT/PARTIAL |
| Mistral Small / Devstral | Mistral tool-call/chat-template style | Explicitly denied in `canActAsAgent` pending grammar support. | Off by allow-list. | ABSENT, HONESTLY OFF |
| Phi-4 / Phi-4-mini | JSON/tool-call or soft schema prompt profile | No Phi local model enum/profile found in audited picker set. | No profile. | ABSENT |
| Gemma 3/4 | Non-XML function-call JSON inside assistant turn | Explicitly denied because XML prompt produced malformed output in observed user run. | Off by allow-list. | ABSENT, HONESTLY OFF |
| OpenAI cloud | Responses API function calls | `agent_core/src/providers/openai.rs` streams function-call arguments and maps tool calls to typed blocks. | Provider-native, not local MLX masking. | SHIPPED CLOUD |
| OpenAI-compatible cloud | Chat Completions `tool_calls` | `agent_core/src/providers/openai_compatible.rs` accumulates streamed `tool_calls`. | Provider-native. | SHIPPED CLOUD |
| Anthropic Claude | `tool_use` / `tool_result` content blocks | `agent_core/src/providers/claude.rs` preserves thinking, signatures, and tool-use events. | Provider-native. | SHIPPED CLOUD |
| Gemini | `functionCall` / `functionResponse` parts | `agent_core/src/providers/gemini.rs` maps function declarations and streamed function calls. | Provider-native. | SHIPPED CLOUD |
| Perplexity | No tools in current provider path | Provider converts tool results to text; finish reason can map `tool_calls`, but no tool schema dispatch is advertised. | N/A. | CHAT/RESEARCH ONLY |

## Required Next Tests

- Fixture parse tests per local family: Qwen XML, LocalAgent XML, DeepSeek-Coder, Llama-family JSON, Mistral-specific, Phi-family.
- Badge derivation tests: `STRICT-CAPABLE`, `SOFT-GUIDED`, `OFF`.
- Drift counter tests: strict parse fail increments per model and demotes badge without disabling the soft local loop.

## Doctrine Rule

Do not add another family to `canActAsAgent` unless one of these is true:

1. Strict MLX grammar masking compiles for that model family and passes a `vault.write` round-trip fixture.
2. A model-family soft-guidance prompt has a passing parser/repair fixture and is labeled `SOFT-GUIDED`, not `STRICT-CAPABLE`.
3. The user explicitly opts into experimental mode and the picker shows the exact unsupported grammar risk.
