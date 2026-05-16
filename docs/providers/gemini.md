# Gemini Provider Integration

Status: wired through `agent_core::providers::gemini`.

## Sources

- Generate content REST API: https://ai.google.dev/api/generate-content
- Thinking: https://ai.google.dev/gemini-api/docs/thinking
- Function calling: https://ai.google.dev/gemini-api/docs/function-calling
- Model list: https://ai.google.dev/gemini-api/docs/models/gemini-v2

## §5.0 Reconciliation

The provider substrate was partial, not absent. `GeminiProvider` already exposed `gemini-2.5-flash` and `gemini-2.5-pro`, streamed `streamGenerateContent`, serialized function declarations, and parsed streamed `thought` parts into `StreamEvent::ThinkingDelta`.

This slice completed the existing substrate instead of adding a duplicate provider stack. The missing pieces were the required `//! Source:` module comments, explicit `includeThoughts` in the 2.5 thinking request, explicit `thinkingBudget: 0` for no-thinking turns, and URL-secret hygiene for API-key auth.

## Runtime Contract

| Epistemos provider id | Gemini model id | Notes |
|---|---|---|
| `gemini_flash` | `gemini-2.5-flash` | Fast multimodal model. Supports thinking, function calling, Search grounding, structured outputs, and streaming. |
| `gemini_pro` | `gemini-2.5-pro` | Higher-reasoning Gemini 2.5 model. Supports thinking, function calling, Search grounding, structured outputs, and 65,536 output tokens. |

## Wire Format

- Base URL: `https://generativelanguage.googleapis.com/v1beta/models`
- Endpoint: `/{model}:streamGenerateContent?alt=sse`
- API-key header: `x-goog-api-key: $GOOGLE_API_KEY` or `$GEMINI_API_KEY`
- OAuth header: `Authorization: Bearer $GOOGLE_ACCESS_TOKEN`
- OAuth project header: `x-goog-user-project: $GOOGLE_PROJECT_ID`
- Streaming: Gemini SSE `data: {GenerateContentResponseChunk}` events
- Tool calls: `tools: [{ functionDeclarations: [...] }]`, with Epistemos tool names normalized through `providers::tool_names`
- Thinking: `generationConfig.thinkingConfig.includeThoughts = true` when `AgentConfig.enable_thinking`; streamed parts with `thought: true` map to `StreamEvent::ThinkingDelta`

Gemini 2.5 Flash defaults to thinking and supports disabling it with `thinkingBudget: 0`. Current Google docs say Gemini 2.5 Pro cannot disable thinking with a zero budget, so Epistemos omits `thinkingConfig` for Pro no-thinking turns rather than sending an invalid budget.

## Safety

`GOOGLE_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_ACCESS_TOKEN`, `GOOGLE_AUTH_MODE`, and `GOOGLE_PROJECT_ID` are in the hardened CLI subprocess denylist. CLI passthrough children must not inherit Epistemos-managed provider credentials.
