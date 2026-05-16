# Together AI Provider Integration

Status: wired through `agent_core::providers::openai_compatible`.

## Sources

- OpenAI compatibility: https://docs.together.ai/docs/inference/openai-compatibility
- Chat completions: https://docs.together.ai/docs/inference/chat/overview
- Function calling: https://docs.together.ai/docs/inference/function-calling/overview
- Reasoning: https://docs.together.ai/docs/inference/chat/reasoning
- Serverless models: https://docs.together.ai/docs/serverless/models
- Pricing: https://www.together.ai/pricing

## §5.0 Reconciliation

The provider substrate was partial, not absent. `OpenAICompatibleProvider::together(model)` already existed and `bridge.rs` already routed the `together` provider id, but the implementation still used the legacy `https://api.together.xyz/v1` host, a non-Turbo Llama model id, and had no provider-specific regression tests or ledger row.

This slice completed the existing OpenAI-compatible path instead of adding a duplicate provider module.

## Runtime Contract

| Epistemos provider id | Together model id | Notes |
|---|---|---|
| `together`, `together_latest` | `meta-llama/Llama-3.3-70B-Instruct-Turbo` | Current default. Together's serverless catalog lists this model at 131,072 context tokens, $0.88 / $0.88 per million input/output tokens, function calling, and structured outputs. |

## Wire Format

- Base URL: `https://api.together.ai/v1`
- Endpoint: `/chat/completions`
- Auth header: `Authorization: Bearer $TOGETHER_API_KEY`
- Streaming: OpenAI-compatible SSE chunks ending in `data: [DONE]`
- Tool calls: OpenAI-compatible `tools: [{ type: "function", function: ... }]`
- Thinking stream: Together reasoning models can emit `delta.reasoning`; the shared OpenAI-compatible parser maps that field to `StreamEvent::ThinkingDelta`

The default Llama 3.3 70B Turbo route does not advertise thinking. Together's reasoning catalog is model-specific, so Epistemos only marks known reasoning model ids as `supports_thinking`.

## Safety

`TOGETHER_API_KEY` is in the hardened CLI subprocess denylist. CLI passthrough children must not inherit Epistemos-managed provider credentials.
