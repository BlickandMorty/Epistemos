# Local Agent Excellence Doctrine — 2026-05-17

This is T2's first doctrine pass for §4.F. It is intentionally grounded in the current code audit: local-first, no subprocess on the hot path, no fake agent capability, no hidden cloud fallback.

## §1 Constellation

The local assistant is a constellation, not one model. V1 roles:

| Role | Default class | Purpose | Load policy |
|---|---|---|---|
| Quick Chat | Phi-4-mini / small Qwen-class | Low-latency replies, classification, title/draft text. | Hot when chat active |
| Reasoning Brain | Phi-4 / Mistral Small / Qwen 9B-class | Planning, synthesis, math, multi-note reasoning. | Warm after planning request |
| Code Wizard | Qwen Coder / DeepSeek-Coder | Code patches, repo-map queries, structured edits. | Hot only for code task |
| Tool Caller | Qwen / LocalAgent 4.3 | Strict/soft tool-call loop, vault/search/write workflows. | Hot during agent run |
| Trivial Subtask | Nemotron/Phi-mini-class | Query parsing, retrieval ranking, schema draft. | Opportunistic, unload first |
| Vision | Qwen-VL/LFM VL | Image-aware tasks and computer-use visual checks. | Cold until image task |

No role may claim `STRICT-CAPABLE` until its own grammar fixture passes. XML success for Qwen does not automatically certify Mistral, Phi, or Llama.

## §2 Router

`ConfidenceRouter` should become a task-class router:

- code/edit/test task -> Code Wizard
- planning/synthesis/math -> Reasoning Brain
- short answer/classification -> Quick Chat
- explicit tool workflow -> Tool Caller
- retrieval-ranking/schema-sniffing -> Trivial Subtask
- image/computer-use vision -> Vision

Idle unload policy: role becomes cold after 30 seconds of inactivity unless a run is active. Hot/warm/cold state must be exposed in Settings -> Inference -> Active constellation.

## §3 Tool Schemas

`LocalToolGrammar` becomes a family dispatcher:

- Qwen/LocalAgent/Hermes-format parity: XML `<tool_call>` carrying `{"name","arguments"}`.
- DeepSeek-Coder: code-oriented schema prompt with strict parser fixture.
- Llama-family: JSON/function-call profile, not assumed XML.
- Mistral Small / Devstral: OFF until native Mistral profile passes.
- Phi-4 / Phi-4-mini: OFF until profile exists.

Badges:

- `STRICT-CAPABLE`: constrained decoder import is active and model-family fixture passes.
- `SOFT-GUIDED`: local loop works with parser/repair fallback but no strict masking.
- `OFF`: no passing model-family grammar.

## §4 Event Pipeline

Target pipeline:

```text
AgentBlueprint -> MissionPacket -> agent_core::agent_runtime
  -> SovereignGate -> Executor -> typed AgentEvent stream
  -> RunEventLog/session trace -> AnswerPacket -> ClaimGraph/Cognitive DAG
  -> Swift timeline + replay
```

Current code has a partial spine: cloud streams use `AgentStreamEvent`, local loop uses `LocalAgentLoop`, session folders persist transcript/trace, and `StreamingDelegate` emits live AnswerPackets. Missing pieces are durable AnswerPacket persistence, typed local run events, and replay UI.

## §5 SovereignGate

Destructive operations remain approval-bound. Read-only auto-approval is allowed only where policy explicitly permits it. Local agent confidence never bypasses mutation approval.

## §6 Per-Model Badges

Every picker row needs:

- model family
- role(s)
- grammar badge
- memory badge
- cloud credential badge if cloud
- reason text for unavailable or experimental state

No cloud pick may silently collapse to local without an inline reason.

## §7 UI Surface

V1 UI must ship:

- AgentBlueprint sheet: name, role, model/Auto constellation, tools, scope, approval mode.
- Active constellation row: role, model, hot/warm/cold, strict/soft/off.
- Strict grammar status row.
- Schema-drift detector row.
- Run timeline: plan -> search -> tool -> approval -> output.
- Replay reader from durable session/run data.

## §8 MAS vs Pro

MAS: in-process Rust/Swift, local MLX, cloud APIs through URLSession, no CLI subprocess hot path.

Pro: CLI adapters and external process toolsets may exist behind explicit Pro gates and approval. They are not the foundation and must never be required for local Research Assistant acceptance.

## §9 Performance Budgets

- local first-token p95: under 800 ms for Quick Chat class once loaded
- cloud first-token p95: under 2 s when network is healthy
- tool dispatch overhead: under 50 ms excluding tool body
- idle unload: 30 s per role
- no unbounded `AsyncStream` buffers

## §10 Open Obligations

1. Persist AnswerPacket ids and packet payloads with chat messages.
2. Promote `session_store` trace/transcript into a real RunEventLog/replay surface.
3. Split `LocalToolGrammar` by model family.
4. Extend `ConfidenceRouter` into a constellation router.
5. Expose power-user model gating, strict grammar state, schema drift, and constellation health in Settings.
6. Replace stale Hermes compatibility names where they are not explicitly format-parity or migration shims.
