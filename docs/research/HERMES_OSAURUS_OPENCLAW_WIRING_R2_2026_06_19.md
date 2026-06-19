# ROUND-2 DEEPENING — Hermes 4 lifts · OpenClaw bridge · Osaurus swap (code-level, 2026-06-19)

Read-only research (subagent). Deepens HERMES_ACT_FUSION_MAP + HERMES_OSAURUS_OVERLAP with
exact functions/call-sites/failure-modes/tests. Feeds DEEP_PLAN_AUDIT_HUB.

## Biggest new finding
**Lift #1 (session-search-summarize) is ~70% ALREADY BUILT and NOT wired to the fused index.**
`SessionSearchHandler` exists end-to-end (`agent_core/src/tools/knowledge.rs:575-658`, schema :660,
registered `registry.rs:1109/1789`, aliased `session_search→knowledge.session_search`
`ToolTierBridge.swift:32`, in local allowlist :223) — but it does a **plaintext substring scan over
`<vault>/sessions/*/transcript.jsonl`** (`knowledge.rs:617-635`), never touches tantivy/usearch, no
summarize step. **OQ-1 (highest): it scans `<vault>/sessions/` but the shadow index crawls
`<vault>/chats/` — possibly returning ZERO hits in production today.** Verify the real vault layout first.

## Hermes lift #1 — session search → summarize-then-answer
Wire: new `SearchIndexService.fusedSessionSearch(query,limit,now) -> [FusedResult]` beside `fusedSearch`
(`SearchIndexService.swift:902`), source-filtered to chats projection (the corpus is ALREADY in the
HNSW+BM25+RRF index via `ShadowVaultBootstrapper`; reuse `RRFFusionQuery.execute:969` — no Rust backend).
New Rust `SessionSummarizeHandler` assembles retrieved snippets into a budgeted block (no model call) →
`{sessions, summary_prompt}`. The summarize-then-answer close is the loop's NATURAL turn 2 (prompt already
says "after a `<tool_response>`, summarize it" — `LocalAgentPromptBuilder.swift:87`); add one prompt line
"for session lookups, call session.search then synthesize." Failure: degrade to plaintext scan if shadow
not open (never throw → spurious invisible-repair `LocalAgentLoop.swift:342`); nonisolated cross-actor hop
must not re-enter @MainActor. Test: seed 2 chat JSONs, assert a semantic (not substring) hit + final answer cites session id.

## Hermes lift #2 — Swift summarizing compaction
Today `trimHistory` (`LocalAgentLoop.swift:1356-1383`) only TRUNCATES (drops the middle). Rust
`compaction.rs::compact_messages` is unreachable (cloud-only + operates on `types::Message`, not `LocalMessage`).
Wire: new `private func compactedHistory(_ history,targetTokens) async -> [LocalMessage]` called at the one
`trimHistory` site (`:355`); clean-room port of compaction Phases 1/3 (keep history[0]+last N, replace middle
with one `[Compacted Context]` LocalMessage), **deterministic string assembly, NOT a model call**.
**CRITICAL failure mode (the prior round's named risk, now concrete): a model-summarize call would re-enter
the single MainActor `LocalConfigurableLLMClient` mid-turn → serialized stall, or DEADLOCK against
reflexMode's in-flight stream Task. VERDICT: ship #2 deterministic; any model-summarized variant runs only
BETWEEN turns with a separate one-shot generator handle, never `self.generator`.** Also: preserve
`<tool_call>`/`<tool_response>` pairing (a half-summarized tool block breaks `parseToolCalls`); re-measure
tokens (`approximateTokenCount = utf8/4`, `:1392`) or it recurses. Test: 20-msg history → assert history[0]
kept, last 4 verbatim, exactly one `[Compacted Context]`, total ≤ target (pure fn, no MLX).

## Hermes lift #3 — named prompt tiers (stable/context/volatile)
Today both builders concat one flat string (`prompt_format.rs:42-117`, `LocalAgentPromptBuilder.swift:31-121`).
Wire: Rust `struct PromptTiers{stable,context,volatile}` + `build_system_prompt_tiered`; keep
`build_system_prompt = stable+context+volatile` for byte-identical back-compat; Swift FFI sibling
`runtimeBuildSystemPromptTiered`. Map: **stable** = grammar+file/vault boilerplate (cacheable prefix);
**context** = knowledge_index + folded skills/procedural memory; **volatile** = additional_instructions.
**Failure: folded-skills block must be CONTEXT not stable** (else the prefix cache busts when a skill file
changes); keep knowledge_index first WITHIN context, after stable; assert Swift/Rust byte-parity (2 copies
already exist — tiering doubles the drift surface). Test: Rust assert concat==flat; Swift byte-parity via FFI.

## Hermes lift #4 — richer auto-skill triggers
`propose_repeated_success_skill` (`self_evolution.rs:25-71`) groups SUCCEEDED records by identical
`steps_taken`; ignores failures/errors/corrections. The record already carries `error_mode` + `succeeded`
(`procedural_memory.rs:25-27`). Wire siblings (keep existing): `propose_recurring_error_recovery_skill`
(group error_mode==Some → later succeeded same prefix) + `propose_novel_workflow_skill` (long succeeded
sequence not matching existing skill). **OQ-3: user-correction trigger has NO event source — nothing emits
a `ProcedureOutcomeRecord` on user edit/reject.** Failure: promotion stays Sovereign-gated (drafts only);
don't double-fire the DAG dispatch (`procedural_memory.rs:93`); error-recovery needs prefix/subsequence
matching (a recovered run has MORE steps than the failed one → naive equality finds nothing).

## OpenClaw — bridge-transport contract (no new FFI needed)
Shim `new WebSocket()` → `window.openclawBridge` (injected `.atDocumentStart`); UI sends `{method,params,id}`;
Swift `handleInbound` → in-process `agent_core`; stream back via `AgentStreamEventDelegate`
(`StreamingDelegate.swift:13-30`) → coalesced `evaluateJavaScript("openclawBridge.emit(...)")`.
INBOUND: `chat.send`→agent run (cloud `AgentBackend` via BackendRegistry); `chat.abort`→`GlobalSessions::cancel`
(`session.rs:91`, exact session_id token or runaway billing); `sessions.list`→`GlobalSessions::list:178`;
`sessions.get`→`session_folder_path:64`; `models.list`→InferenceState+RouteProfiles; `tool.invoke`→registry.
OUTBOUND (delegate→emit): onTurnStarted→turn.start, onThinkingDelta→thinking.delta, onTextDelta→message.delta,
onToolStarted/Completed→tool.start/result, onPermissionRequired→permission.request (routes to Epistemos
gate+SovereignGate, NOT OpenClaw's approver), onContextCompacting→context.compacting, onComplete→message.complete,
onError→error, onSubagentSpawned→subagent.spawned. The `AsyncStream<AgentStreamEvent>` adapter already exists
(`StreamingDelegate.swift:515`). Failure: request/reply (sessions.list needs id) vs streaming (chat.send) must
both be supported over the one shared `WKScriptMessageHandler` (OQ-6: does OpenClaw's app-gateway tolerate a shared transport?).

## Osaurus — exact generator-closure swap point
Swap point = `LocalAgentLoop.liveLoop` generator args (`LocalAgentLoop.swift:224-237`: generator/repairGenerator/
streamingGenerator/structuredGenerator). When `engine==.osaurusLocal`, add a PARALLEL `@MainActor static func
osaurusLoop(bridge:toolExecutor:modelID:...)` (don't modify the MLX path) whose `generator` closure conforms to
`LocalAgentGenerationHandler` but calls `bridge.runTurn(model:messages:maxTokens:)` (`ActOsaurusBridge.swift:31`)
instead of the MLX client. Load-bearing differences: `streamingGenerator=nil` → standard non-streaming path (Osaurus
runTurn is stream:false; OQ-5: streaming SSE variant?); `structuredGenerator=nil` → no MLX grammar masking, relies
on Hermes-3 soft-guidance parse (fine, grammar already compatible). **Everything above the closure is byte-identical
— systemPrompt, trim/compaction, tool parse/execute, provenance — so the IP stays in the brain; only token serving
swaps** (confirms the prior claim at line level). Failure: `runTurn` throws honest `ActOsaurusError` → let it
propagate (NO silent cloud fallback, constraint #1); `emptyResponse` must map to a loop error not a silent empty
turn (would trip invisible-repair); `isLive`/`serverHealth` hardcoded inert today (`:84-85`) so gate `.osaurusLocal`
unreachable until live; whole bridge is `#if !EPISTEMOS_APP_STORE` so `osaurusLoop` must be gated too;
**`RuntimeLane` has NO `.osaurus` case (`RuntimeExecutor.swift:46`) — the `.osaurusLocal` decision belongs in the
Act picker (ChatCoordinator), NOT RuntimeRouter, or it's the forbidden 3rd route.**

## OPEN QUESTIONS (carry to next round / flag to build loop)
- OQ-1 (highest): does `session_search` (`/sessions/`) vs the shadow index (`/chats/`) mean zero hits today? Runtime vault-layout check.
- OQ-2: does the local loop ever hit `historyBudget` (32768, maxTurns 8)? Measure before building #2.
- OQ-3: lift #4 user-correction has no emitter — who writes the `ProcedureOutcomeRecord` on edit/reject?
- OQ-4: collapse the 2 prompt copies (Rust+Swift) to Rust-only-via-FFI as part of tiering, or keep dual-write?
- OQ-5: Osaurus streaming (`runTurnStreaming` SSE) in scope for v0, or one-shot acceptable (loses reflex latency)?
- OQ-6: does OpenClaw's app-gateway shim tolerate a shared transport (all sessions over one handler)?

Key files: `LocalAgentLoop.swift` (swap :211-238, trim :1356), `LocalAgentPromptBuilder.swift` (:31-121, FFI :209),
`agent_core/src/agent_runtime/{self_evolution.rs:25,procedural_memory.rs:25,prompt_format.rs:42}`,
`agent_core/src/{compaction.rs:26,session.rs:64/91/178,tools/knowledge.rs:575-676,tools/registry.rs:1109/1789}`,
`ActOsaurus/ActOsaurusBridge.swift:31/82-138`, `Bridge/StreamingDelegate.swift:13-30`, `App/ChatCoordinator.swift:1174-1320`,
`Bridge/ToolTierBridge.swift:32/220-224`, `Sync/SearchIndexService.swift:902-1015`, `Engine/RuntimeExecutor.swift:46`.
