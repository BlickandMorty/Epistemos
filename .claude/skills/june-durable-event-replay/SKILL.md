---
name: june-durable-event-replay
description: Use when adding, auditing, or hardening MAS June durable replay for streamed agent events, including thinking/reasoning deltas, tool calls/results, approval-adjacent evidence, Hermes-compatible session messages, and relaunch/all-chats parity without weakening live streaming or MAS bounds.
---

# June Durable Event Replay

## Purpose

Use this skill when a live June stream has richer structure than the persisted transcript. The pattern keeps live events immediate while storing the Hermes-compatible fields the vendored June UI already understands, so relaunch and all-chats replay preserve agent work instead of degrading into plain assistant text.

Do not use this skill to add a second replay protocol, a subprocess, a local server, stdio MCP, terminal/code tools, Pro-only artifacts, or fake local tool capability.

## Required Reads

1. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `Epistemos/JuneAgent/JuneSessionStore.swift`
4. `Epistemos/JuneAgent/JuneAgentGateway.swift`
5. `/Users/jojo/dev/june-epistemos/src/lib/tauri.ts`
6. `/Users/jojo/dev/june-epistemos/src/lib/agent-chat-runtime.ts`

## Method

1. Reuse the existing Hermes message contract.
   - Persist assistant reasoning through `reasoning` and `reasoning_content`.
   - Persist tool calls through assistant `tool_calls`.
   - Persist tool results as `role: "tool"` messages with `tool_call_id` and `tool_name`.
   - Avoid a parallel replay JSON shape unless the June fork cannot render the existing one.

2. Keep live streaming first.
   - Continue emitting `message.delta`, `thinking.delta`, `tool.start`, `tool.complete`, and `approval.request` immediately.
   - Accumulate replay fields as bounded side evidence; do not wait to stream until persistence succeeds.
   - Persist at turn finalization so tool calls and tool results can land in an order the UI can reconstruct.

3. Bound every retained field.
   - Reasoning/thinking retention must have a byte ceiling.
   - Tool call/result counts must have a ceiling.
   - Tool payloads must pass through the same truncation and vault-root redaction used for live JS events.
   - Never persist raw provider secrets, Keychain values, security-scoped root paths, or unbounded tool output.

4. Preserve prompt history semantics.
   - If durable `role: "tool"` messages are included in later history assembly, label them as `Tool:`, not `User:`.
   - Local models remain compact-context chat lanes; tool replay does not make local rows tool-capable.
   - Keep history bounded so replay metadata does not crowd out the user's current task.

5. Validate replay through source and runtime.
   - Source guard that `JuneSessionStore.Message` carries the optional Hermes replay fields.
   - Source guard that `messagesPayload` emits those fields only when nonempty.
   - Source guard that `JuneAgentGateway` accumulates bounded reasoning/tool calls/results and persists them at turn finalization.
   - Runtime proof: run a cloud tool turn, relaunch or reload the session, and confirm the thinking disclosure and tool card still render from persisted messages.

## Review Checklist

- Relaunch replay preserves reasoning/tool cards without introducing a second UI protocol.
- Live stream timing is unchanged.
- Replay storage is atomic through the existing session store write path.
- Tool payloads are bounded and redacted before persistence.
- Tool messages are not fed back into future prompts as user-authored text.
- Local capability gating remains honest.
- No App Store forbidden tool, executable, server, stdio MCP, or subprocess path is added.
