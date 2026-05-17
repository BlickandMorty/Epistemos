# xAI Grok Provider Integration

Status: wired through `agent_core::providers::openai_compatible`.

## Sources

- Chat Completions: https://docs.x.ai/developers/model-capabilities/legacy/chat-completions
- Streaming: https://docs.x.ai/developers/model-capabilities/text/streaming
- Reasoning: https://docs.x.ai/developers/model-capabilities/text/reasoning
- Function calling: https://docs.x.ai/developers/tools/function-calling
- Grok 4.3 model card: https://docs.x.ai/developers/models/grok-4.3
- May 15, 2026 model retirement: https://docs.x.ai/developers/migration/may-15-retirement
- Pricing: https://docs.x.ai/developers/pricing

## §5.0 Reconciliation

The provider substrate was partial, not absent. `OpenAICompatibleProvider::xai()` already existed and `bridge.rs` already routed `xai` / `grok`, but the implementation still defaulted to `grok-3`, had no source-guard tests, no pricing row, and no provider ledger.

Official xAI docs changed the queue assumption. The Terminal D queue named Grok-2 / Grok-3, but xAI retired `grok-3` on May 15, 2026 at 12:00 PM PT. Deprecated text slugs now redirect to `grok-4.3` and bill at `grok-4.3` pricing. This slice therefore pins the explicit current model id instead of relying on a deprecated redirect.

## Runtime Contract

| Epistemos provider id | xAI model id | Notes |
|---|---|---|
| `xai`, `grok`, `grok_latest`, `grok-4.3` | `grok-4.3` | Current default. xAI lists 1,000,000 context tokens, function calling, structured outputs, image input, configurable reasoning, and $1.25 / $2.50 per million input/output tokens. |

## Wire Format

- Base URL: `https://api.x.ai/v1`
- Endpoint: `/chat/completions`
- Auth header: `Authorization: Bearer $XAI_API_KEY`
- Streaming: OpenAI-compatible SSE chunks ending in `data: [DONE]`
- Tool calls: OpenAI-compatible `tools: [{ type: "function", function: ... }]`
- Thinking stream: xAI can emit `reasoning_content`; the shared OpenAI-compatible parser maps it to `StreamEvent::ThinkingDelta`

`grok-4.3` supports configurable reasoning. The current shared provider path uses the legacy Chat Completions endpoint, so it preserves streaming text, custom function calls, and reasoning-summary deltas without enabling xAI server-side tools such as web search, code execution, or remote MCP.

## Safety

`XAI_API_KEY` is in the hardened CLI subprocess denylist. CLI passthrough children must not inherit Epistemos-managed provider credentials.
