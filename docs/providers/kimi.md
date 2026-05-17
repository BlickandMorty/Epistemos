# Kimi Provider Integration

Status: wired through `agent_core::providers::openai_compatible`.

## Sources

- API overview: https://platform.kimi.ai/docs/api/overview
- Chat completion: https://platform.kimi.ai/docs/api/chat
- Model list: https://platform.kimi.ai/docs/models
- K2.6 guide: https://platform.kimi.ai/docs/guide/kimi-k2-6-quickstart
- Thinking models: https://platform.kimi.ai/docs/guide/use-kimi-k2-thinking-model
- Tool calls: https://platform.kimi.ai/docs/guide/use-kimi-api-to-complete-tool-calls
- Pricing: https://platform.kimi.ai/docs/pricing/chat-k26

## §5.0 Reconciliation

The provider substrate was partial, not absent. `OpenAICompatibleProvider::kimi_coding()` already existed, but it used the legacy `https://api.moonshot.cn/v1` base URL, `KIMI_API_KEY`, `kimi-k2`, and did not parse `reasoning_content` streaming deltas.

This slice completed the existing substrate instead of adding a duplicate provider stack.

## Runtime Contract

| Epistemos provider id | Kimi model id | Notes |
|---|---|---|
| `kimi`, `kimi_latest`, `kimi_coding` | `kimi-k2.6` | Current default. Kimi docs list this as the latest model, with 256k context, multimodal input, tool calls, JSON mode, and configurable thinking. |
| `kimi_k2`, `kimi-k2` | `kimi-k2-0905-preview` | Explicit K2 compatibility id. Kimi docs say K2-series models discontinue on 2026-05-25, so this stays opt-in only. |
| `kimi_thinking`, `kimi-k2-thinking` | `kimi-k2-thinking` | Dedicated K2 thinking model. |

`kimi-latest` is not used as a wire model id. Kimi docs mark it discontinued on 2026-01-28 and recommend `kimi-k2.6`.

## Wire Format

- Base URL: `https://api.moonshot.ai/v1`
- Endpoint: `/chat/completions`
- Auth header: `Authorization: Bearer $MOONSHOT_API_KEY`
- Legacy fallback env var: `KIMI_API_KEY`
- Streaming: OpenAI-compatible SSE chunks ending in `data: [DONE]`
- Tool calls: OpenAI-compatible `tools: [{ type: "function", function: ... }]`
- Thinking: Kimi emits `delta.reasoning_content`; the provider maps it to `StreamEvent::ThinkingDelta`.

For `kimi-k2.6` and `kimi-k2.5`, Epistemos writes Kimi's `thinking` request extension from `AgentConfig.enable_thinking`, because thinking is enabled by default on K2.6 and must be explicitly disabled for no-thinking turns.

## Safety

`MOONSHOT_API_KEY` is in the hardened CLI subprocess denylist. CLI passthrough children must not inherit Epistemos-managed provider credentials.

Source guard: `providers::openai_compatible::tests::module_prologue_includes_moonshot_source_comments` keeps the Kimi/Moonshot official URLs in the module-level `//! Source:` prologue.
