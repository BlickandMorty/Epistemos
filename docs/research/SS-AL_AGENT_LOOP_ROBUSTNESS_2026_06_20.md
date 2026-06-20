# SS-AL — Agent loop robustness + speed + correctness deepening (2026-06-20)

Read-only research (subagent), code-grounded. The central engine that runs every local + cloud turn. Recursive
"make local agents better" + "super-optimized" mandate. Do NOT touch vault/graph/TK2-Prose. Cross-refs SS-Y
(determinism/repair), SS-H (keystone), SS-PERF (clones + compaction), SS-UMA (recall), SS-S (redaction), SS-Z
(parsing).

## Headline
**Cloud loop = solid + battle-hardened** (clean ReAct, real token streaming, thinking-block preservation, 3
compaction triggers, honest error-observation feedback, parallel tool calls, retries). **The local loop is where
the reliability + speed gains live:** ~5 overlapping ad-hoc repair paths, a keystone gate (`shouldUseToolLoop`)
that silently drops sub-agent models to toolless streaming, and — confirming SS-Y — **all repair/structured
generations run with a no-op token sink `{ _ in }` (masked decode)**, so self-correction is invisible to the user
+ wastes already-spent compute. Biggest gains: (1) stream local repair tokens; (2) retry/resume on **mid-stream**
SSE errors in the cloud loop (currently un-retried → hard abort); (3) drop the O(turns) `response_blocks.clone()`.
**CORRECTION: SS-PERF's "no in-loop compaction" is partly STALE — there ARE 3 in-loop triggers (below).**

## Cloud loop (`agent_core/src/agent_loop.rs`)
- ReAct `run_agent_loop` L151-718; local provider rejected L166-171 (honest gating ✅). `max_turns` = pure safety
  rail vs `DEFAULT_AGENT_MAX_TURNS=25` (L62); agent decides via `stop_reason` (L525) per CLAUDE.md ✅.
- **Streaming:** every event forwarded immediately — `on_thinking_delta L358`, `on_text_delta L376`,
  `on_tool_input_delta L382`; TTFT L346/L368; no buffering ✅.
- **Thinking-block preservation:** the ENTIRE `response_blocks` (incl Thinking/RedactedThinking/ToolUse) pushed
  verbatim on tool_use (L557), serialized with signatures (`claude.rs:608-633`) ✅.
- **stop_reason:** EndTurn/StopSequence→return (L526); ToolUse→execute+observe (L554); MaxTokens→push+compact+
  continue (L684) ✅.
- **Tool errors feed back, never break the loop:** `execute_one_tool` always returns `Ok(ToolResult::text(...,
  is_error=true))` on failure (L1074)/denial (L939)/security-block (L1028) → agent sees honest error + recovers ✅.
- **CONFIRMED inefficiency (SS-PERF):** `response_blocks.clone()` at **L535,L557,L693** clones the full block vec
  (incl large thinking text) each turn; on EndTurn (L535) the clone is immediately followed by moving the
  original into `full_history` (L549) → pure waste. `extract_tool_calls` L555/L720 also clones each id/name/input.
- **FRAGILE — mid-stream SSE errors NOT retried (NEW finding):** `with_retry` (`claude.rs:309-339`) wraps only
  the request SEND. Once `bytes_stream().eventsource()` begins (L341), a transport error (L353 `StreamError`) or
  an `error` SSE frame (L472 `ApiError{status:0}`) propagates via `event_result?` (`agent_loop:343`) and **aborts
  the entire agent run with no resume** — a 30-turn agent dropping a socket on turn 29 loses everything. Highest-
  value robustness fix. Also `claude.rs:311` builds a FRESH `CancellationToken::new()` for the retry wrapper
  instead of threading the loop's `cancel` → retries can't be user-cancelled mid-backoff.
- Existing retry IS good: exp backoff + jitter, `retry-after` honored, cancel-aware (`error.rs:80-117`;
  max_retries=3, base_delay=1s).

## Local loop + self-correction (`Epistemos/LocalAgent/LocalAgentLoop.swift`)
- ReAct `run L270-564`; reflex `runReflexTurn L571+` fires tools the instant `</tool_call>` closes + cancels
  remaining decode (L264-266) — a genuine local-only latency win.
- **Fragmented repair (confirms SS-Y):** ≥5 repair builders each invoked in 3+ places (standard L446-547, reflex
  L660-950, fallback L926-950): `repairPromptForInvisibleTurn`, `…SkippedExplicitFileToolStep`, `…SkippedExplicit
  NoteToolStep`, `…InvalidExplicitFileToolCall`, `…InvalidExplicitNoteToolCall` + synthetic tool injection
  (L967,L997) + `salvagedHiddenAnswer`. Same 5 checks duplicated across standard/reflex/reflex-repair → drift
  risk. Invisible-turn streak capped `invisibleRepairLoopLimit=2` (L65,L342-349) — reasonable circuit breaker.
- **CONFIRMED masked-decode-on-retry (SS-Y, exact lines):** every repair/structured generator uses a no-op token
  sink `{ _ in }` — `immediateRepairOutput L1132`, `structuredReflexRepairOutput L1083`, `reflexRepairOutput`. The
  first-pass `mlxGenerator` streams (L132 `await onToken(chunk)`), but the moment a turn needs repair, streaming
  silently dies → user sees a stall, recovered text revealed only after repair completes. UX regression +
  "local>cloud" blocker.
- **Keystone gate (confirms SS-H):** `PipelineService.shouldUseToolLoop L316-347` — a `localMLX` model not
  `canRunLocalAgentLoop` returns true only if `fittingLocalAgentTextModelID != nil` (L346); else **returns false
  → toolless direct stream** (L341). Small models drop out of the loop + answer from inlined context = the
  "routed to Qwen again"/hallucination footgun. OOM rationale sound, the SILENT drop is the fragility.
- Cloud self-correction (model + honest error obs) = simple+robust; local hard-codes heuristic "you skipped the
  required file/note tool" repairs + synthetic injection — more powerful but far more fragile (objective-keyword
  driven `requiredExplicitFileToolSequence L319`; every new tool shape needs a new builder).

## Streaming / backpressure
- Cloud SSE (`claude.rs:343-488`): each delta `yield`-ed BEFORE the local buffer copy (L401 before L405) ✅;
  `[DONE]` (L358) + `message_stop` (L465) terminate cleanly; fallback `MessageStop` (L482) on truncated stream.
- Rust path uses `async_stream::stream!` (natural backpressure, no unbounded channel); raw-thoughts via off-path
  `BufWriter` (L186-189) ✅. Micro-note: `RawThoughtsEvent::record` clones delta text (L356/L374) unconditionally
  even though it's a no-op unless `EPISTEMOS_RAW_THOUGHTS_V0=1` — tiny per-token clone.
- (`.bufferingNewest(256)` is the Swift-side StreamingDelegate contract — out of scope, not verified here.)

## Compaction / context (`agent_core/src/compaction.rs`) — SS-PERF CORRECTION
**3 in-loop triggers EXIST** (refutes SS-PERF's "no in-loop compaction"): proactive pre-flight at 80% BEFORE the
API call (`agent_loop:296-319`), reactive after tool results > `context_threshold` (L660-682), forced on MaxTokens
(L694-714). `context_threshold=150_000` (L95). 4-phase pipeline (boundary protect → tool-result replace →
structured summarize → iterative fold, `compaction.rs:26-86`), preserves recent thinking blocks (test L519),
strips stale signatures (L506), sanitizes orphan tool_results (L77-80), repairs role alternation (L83/339). Solid.
**Gaps:** (1) `estimate_tokens` = crude chars/4 (`agent_loop:1167-1204`; images flat 1000 L1180) → can badly
mis-count, making the 150k gate dishonest — a real tokenizer would fix; (2) lossy summarization with no fidelity
guard + `recent_window=8` hardcoded (`claude.rs:492`) → a single >16k-token tool result in the recent window
survives uncompacted + can blow the next call's budget.

## Tool execution
- Dispatch cloud `execute_one_tool`→`tool_registry.execute_v2` (`agent_loop:1006`); **parallel via `try_join_all`
  (L823) default-on (`parallel_tool_execution` L103)** — real parallel tool calls shipped ✅; short-circuits on
  first Err but tool failures return `Ok(is_error)` so siblings aren't aborted.
- Parsing local `parse_tool_calls` (`function_call.rs:141`) = JSON object/array OR `<tool_call>…</tool_call>`
  (L153); strips `<think>`/`<scratch_pad>` (L7,L98). Confirms SS-Z: **only `<tool_call>`/JSON** — a model emitting
  a bare ```json fenced block or `function_call`/`tool_calls[]` shape is MISSED → invisible turn → repair.
- Redaction (confirms SS-S): `redact_credentials` (`security.rs:169`) inbound on tool OUTPUT only (`agent_loop
  :1009,989`) + 40-rule `scan_tool_output` Critical→is_error block (L1015-1036). **NO outbound redaction of tool
  INPUTS** before API send / trace log (L1052 logs `input_summary` raw, only truncated) — a credential in a tool
  arg is unmasked.
- `truncate_tool_output` head+tail 16_384 chars, unicode-safe (L1206) ✅.

## Ranked optimization + hardening (value×effort)
1. **Stream local repair tokens (kill masked decode)** — pass real `onToken` into `immediateRepairOutput`/
   `structuredReflexRepairOutput`/`reflexRepairOutput` instead of `{ _ in }` (`LocalAgentLoop:1083,1132`). High
   value (UX + perceived speed + local>cloud), LOW effort.
2. **Retry/resume on mid-stream SSE errors (cloud)** — wrap stream consumption (`claude.rs:349`/`agent_loop:343`)
   so a transport drop retries the turn vs aborting; thread the loop `cancel` into `with_retry` (`claude.rs:311`).
   High value, medium effort.
3. **Unify local repair through one HyperdynamicLoop dispatcher (SS-Y)** — collapse 5 builders × 3 sites into one
   repair state machine. High value, medium-high effort.
4. **Surface the `shouldUseToolLoop` silent drop (SS-H)** — emit "answering from context, no tools" + eagerly
   route to `fittingLocalAgentTextModelID` (`PipelineService:341/346`). Medium value, low effort.
5. **Remove `response_blocks.clone()` ×3 (SS-PERF)** — move not clone on EndTurn (`agent_loop:535/557/693`).
   Medium value, low effort, zero risk.
6. **Broaden local tool-call parsing (SS-Z)** — accept fenced ```json + `function_call`/`tool_calls[]` in
   `parse_tool_calls` (`function_call.rs:141`) → fewer invisible-turn/repairs at the source. Medium value.
7. **Real tokenizer for `estimate_tokens` + per-message budget guard** (`agent_loop:1167`; `recent_window`
   `claude.rs:492`). Medium value, medium effort.
8. **Outbound tool-INPUT redaction + trace masking (SS-S ext)** — redact tool inputs before API/trace
   (`agent_loop:1052`). Lower value, low effort, real security upside.

## Already solid (don't redo)
Thinking-block+signature preservation (test-pinned `claude.rs:752`); token-by-token cloud streaming + TTFT;
honest tool-error-as-observation; 3-point mid-loop compaction w/ boundary protect + recent-thinking retention +
orphan sanitization + role repair (test L429-554); exp-backoff+jitter retry on initial request; real parallel
tool exec (default-on) w/ per-tool isolation; inbound credential redaction + 40-rule scanner; max_turns=25 +
capability gating.

## Verified vs estimated
All file:line read from source. Estimated: StreamingDelegate `.bufferingNewest(256)` (Swift not opened); the
runtime UX impact of masked decode (inferred from `{ _ in }`, not observed). SS-PERF "no in-loop compaction"
PARTLY REFUTED (3 in-loop triggers confirmed).

Key files: `agent_core/src/agent_loop.rs` (cloud ReAct L151-718, dispatch L856-1077, compaction L296/660/694,
clones L535/557/693, estimate_tokens L1167) · `providers/claude.rs` (SSE L343-488, retry send-only L309-339,
thinking serialize L608-633, fresh-token bug L311, recent_window L492) · `compaction.rs:26-86` · `agent_runtime/
function_call.rs:141,37` · `error.rs:68-118` · `security.rs:169` · `LocalAgent/LocalAgentLoop.swift` (ReAct
L270-564, reflex L571+, repairs, masked `{ _ in }` L1083/1132) · `Engine/PipelineService.swift:316-347` (keystone)
· `LocalAgent/ConfidenceRouter.swift:405` + `RuntimeRouter.swift:528`. Cross-refs SS-Y/H/PERF/UMA/S/Z.
