# OpenRouter Provider Integration

Status: wired through `agent_core::providers::openai_compatible`.

## Sources

- API overview: https://openrouter.ai/docs/api/reference/overview
- Chat completion endpoint: https://openrouter.ai/docs/api/api-reference/chat/send-chat-completion-request
- Streaming: https://openrouter.ai/docs/api/reference/streaming
- Reasoning tokens: https://openrouter.ai/docs/guides/best-practices/reasoning-tokens
- Provider routing: https://openrouter.ai/docs/guides/routing/provider-selection
- Pricing: https://openrouter.ai/pricing

## §5.0 Reconciliation

The provider substrate was partial, not absent. `OpenAICompatibleProvider::openrouter(model)` already targeted `https://openrouter.ai/api/v1` and the bridge already routed `openrouter` plus arbitrary `provider/model` slugs through it.

This slice completed the existing OpenAI-compatible gateway path instead of adding a duplicate provider module. The missing pieces were required source comments, current OpenRouter attribution header, reasoning request configuration, plaintext reasoning delta parsing, provider-specific regression tests, and ledger coverage.

## Runtime Contract

| Epistemos provider id | OpenRouter model id | Notes |
|---|---|---|
| `openrouter` | Current bridge default model | Generic OpenRouter gateway selection. The model id must include the provider prefix OpenRouter expects, such as `openai/gpt-5.2` or `anthropic/claude-sonnet-4.5`. |
| Any non-HuggingFace `provider/model` slug | Same slug | The bridge defaults slash-delimited provider/model strings to OpenRouter unless prefixed with `hf/` or `huggingface/`. |

OpenRouter model pricing and context length are model-specific. Epistemos keeps OpenRouter as a gateway contract rather than hard-coding a single task-to-provider decision in Terminal D.

## Wire Format

- Base URL: `https://openrouter.ai/api/v1`
- Endpoint: `/chat/completions`
- Auth header: `Authorization: Bearer $OPENROUTER_API_KEY`
- Attribution headers: `HTTP-Referer: https://epistemos.app` and `X-OpenRouter-Title: Epistemos`
- Streaming: OpenAI-compatible SSE chunks ending in `data: [DONE]`
- Tool calls: OpenAI-compatible `tools: [{ type: "function", function: ... }]`; OpenRouter maps/transforms tool schemas for providers that need custom upstream shape
- Thinking: Epistemos writes OpenRouter's `reasoning` request object from `AgentConfig.enable_thinking` and `AgentConfig.effort`
- Thinking stream: plaintext `delta.reasoning` and `delta.reasoning_content` both map to `StreamEvent::ThinkingDelta`

Structured `reasoning_details` preservation is not widened in this slice because the shared `ContentBlock` contract only carries plaintext thinking plus Anthropic-style signatures today. This slice handles OpenRouter's plaintext reasoning surface without changing the cross-provider transcript schema.

## Safety

`OPENROUTER_API_KEY` is in the hardened CLI subprocess denylist. CLI passthrough children must not inherit Epistemos-managed provider credentials.
