---
name: june-streaming-thinking-boundary
description: Use when adding, auditing, or hardening MAS June streaming paths, token streams, thinking/reasoning deltas, model capability labels, or any local/cloud stream bridge that must stay bounded, in-process, and honest about native thinking versus chat-only capability.
---

# June Streaming Thinking Boundary

## Purpose

Use this skill to keep MAS June stream paths memory-bounded while preserving real thinking/reasoning dynamics. The pattern applies to `agent_core` event streams, local Apple Foundation Models/GGUF token streams, retained cloud scaffolds, and model-picker capability labels.

Do not use this skill to add subprocesses, local servers, stdio MCP, terminal/code tools, hidden sidecars, or fake local function-calling. Local models may surface thinking text only when the stream actually emits parseable thinking tags or a native reasoning channel exists.

## Required Reads

1. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `Epistemos/JuneAgent/JuneAgentGateway.swift`
4. `Epistemos/Goose/GooseInProcessACPServer.swift`
5. `Epistemos/Engine/ThinkTagStreamRouter.swift`
6. `/Users/jojo/dev/june-epistemos/src/lib/model-privacy.ts`
7. `/Users/jojo/dev/june-epistemos/src/components/agent/AgentWorkspace.tsx`

## Method

1. Bound every stream at the creation point.
   - Use `AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256))` for MAS June/Goose/local/cloud event and token wrappers.
   - Scan the touched surface for default `AsyncStream {` or `AsyncThrowingStream {` before closing the change.
   - Keep first-token streaming immediate; bounded buffering is not permission to batch tokens.

2. Preserve the event contract.
   - Text goes to `.textDelta` / `message.delta`.
   - Thinking or reasoning goes to `.thinkingDelta` / `thinking.delta`.
   - Tool and approval events stay outside the thinking disclosure.
   - Completion still emits exactly once, after flushing any local reasoning router remainder.

3. Split local thinking only from real stream evidence.
   - Use `ThinkTagStreamRouter` for inline `<think>`, `<thinking>`, `<thought>`, `<reasoning>`, and `[Start thinking]` forms.
   - If no thinking tags appear, pass text through as answer text.
   - Do not advertise local model tool/function calling because a stream parser exists.

4. Label model thinking from capability truth.
   - Cloud model rows may expose `supportsReasoning`, `supportsReasoningDeltas`, and `supportsNativeReasoningControls` only from Swift model metadata such as `supportedOperatingModes` and native reasoning-control support.
   - The June web picker reads thinking from `capabilities`, not descriptive traits or marketing copy.
   - Local rows remain chat-tier unless a specific local model/runtime has proven native thinking support.

5. Keep OOM pressure visible.
   - Before native builds/tests, check for active `xcodebuild`, `swift-frontend`, broad `tsc`, or model-runtime processes.
   - On 16 GB machines, avoid overlapping native builds and broad JS checks; use source guards first, then checkpoint builds.

## Verification

- Source scan: no default-unbounded `AsyncStream {` / `AsyncThrowingStream {` remains in the touched MAS June/local/Goose surface.
- Swift source guards: `AppStoreJuneHardeningTests` covers bounded Goose stream, bounded June/local streams, and local think-tag splitting.
- Web source guards/tests: `modelSupportsThinking` reads capabilities only, and model search includes capabilities so "thinking" finds real thinking-capable rows.
- Runtime proof: in the sandboxed MAS build, a cloud model with native reasoning emits `thinking.delta`; a local model emitting think tags shows a thinking disclosure while keeping answer text clean.
