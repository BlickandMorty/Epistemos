# Codestral Provider Integration

Status: wired through `agent_core::providers::openai_compatible`.

## Sources

- Coding/FIM guide: https://docs.mistral.ai/mistral-vibe/using-fim-api
- Codestral 25.08 model card: https://docs.mistral.ai/models/model-cards/codestral-25-08
- Chat completion endpoint: https://docs.mistral.ai/api/endpoint/chat

## §5.0 Reconciliation

The provider substrate was partial, not absent. `OpenAICompatibleProvider::codestral(model)` already existed, but it had no `codestral_latest()` default, no provider ledger, no provider-specific regression tests, and still advertised a 256k context window.

This slice completed the existing OpenAI-compatible path instead of adding a duplicate provider stack.

## Runtime Contract

| Epistemos provider id | Codestral model id | Notes |
|---|---|---|
| `codestral`, `codestral_latest` | `codestral-latest` | Current moving alias for Codestral. Mistral's current model card lists Codestral 25.08 (`codestral-2508`) at 128k context with chat completions, function calling, structured outputs, and FIM support. |
| `codestral-2508` | `codestral-latest` | Accepted as a model alias in Epistemos so persisted model IDs canonicalize to the moving Codestral endpoint. |

## Wire Format

- Base URL: `https://codestral.mistral.ai/v1`
- Endpoint: `/chat/completions`
- Auth header: `Authorization: Bearer $CODESTRAL_API_KEY`
- Fallback env var: `MISTRAL_API_KEY`
- Streaming: OpenAI-compatible SSE chunks ending in `data: [DONE]`
- Tool calls: OpenAI-compatible `tools: [{ type: "function", function: ... }]`
- Thinking: not advertised for Codestral; no provider-specific thinking request extension is sent.

Mistral documents two domains for Codestral. Epistemos targets `codestral.mistral.ai` here because Terminal D's queue explicitly asks for the individual/user-key Codestral endpoint; production/business Mistral traffic can still use the generic Mistral route later if that becomes a separate slice.

## Safety

`CODESTRAL_API_KEY` is in the hardened CLI subprocess denylist. CLI passthrough children must not inherit Epistemos-managed provider credentials.
