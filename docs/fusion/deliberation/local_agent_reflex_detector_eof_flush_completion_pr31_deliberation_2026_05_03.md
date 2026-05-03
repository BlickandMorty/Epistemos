# LocalAgent Reflex Detector EOF Flush Completion PR31 Deliberation - 2026-05-03

## Slice

Complete the already-committed LocalAgent reflex EOF flush slice by landing the missing detector-side API and focused tests. Commit `2eee1afe` added `LocalAgentLoop`'s call to `IncrementalToolCallDetector.flushOnStreamEnd()`, and the current-state doc marks the fix closed. The detector method and detector-level privacy tests are still unstaged working-tree changes, so branch reality does not fully match the canon until this slice lands.

## Tier

Core. This is local Swift streaming correctness only.

## Allowed Files

- `/Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/IncrementalToolCallDetector.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/IncrementalToolCallDetectorTests.swift`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/local-agent-reflex-detector-eof-flush-completion-pr31/**`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/local_agent_reflex_detector_eof_flush_completion_pr31_deliberation_2026_05_03.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_63_2026_05_03.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`

## Forbidden Files

- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `Epistemos.xcodeproj/**`
- generated bindings, generated libraries, entitlements, model routing, provider calls, tool parsing, tool execution, repair semantics, EventStore schema, AgentEvent, GraphEvent, OpLog, Rust, and UI files.

## Canonical Claim

`MASTER_RESEARCH_INDEX_2026_05_02.md §8` names the local-stream truncation/flush fix as a preservation watch. `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` already records the closure. This patch makes the committed branch self-consistent by adding the detector method that the already-committed `LocalAgentLoop` call requires.

## Implementation Requirements

- Add `IncrementalToolCallDetector.flushOnStreamEnd()` as a detector-local EOF drain.
- Flush safe plaintext held only for tag-prefix disambiguation.
- Drop unterminated hidden scratchpad or malformed tool-call buffers at EOF.
- Do not change normal tool-call detection, hidden-tag stripping, model routing, tool execution, or LocalAgentLoop turn policy.

## Acceptance

- Focused detector tests prove a trailing `<` flushes exactly once.
- Focused detector tests prove unterminated `<think>...` and `<tool_call>...` buffers are dropped.
- Focused LocalAgentLoop tests still prove reflex mode emits the flushed plaintext through the streaming callback.
- `git diff --check` passes for the slice files.
- Protected-path scan proves no Graph, UI, Rust, generated-binding, or Xcode project files are staged for this slice.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §8`
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `CANON_GAPS_AND_ADDENDA_2026_05_02.md C12`

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: preservation/completion addendum under the LocalAgent streaming watch, not a new numbered workcard.
- Deviation: This is a small closure repair for a slice already committed as `2eee1afe`; it intentionally does not advance AgentEvent Card 7 or GraphEvent Card 8.

## Failure-Proof Guardrails (post-merge)

- grep: `rg -n "flushOnStreamEnd|Drops unterminated hidden and tool buffers at stream end|reflex mode flushes trailing tag-prefix plaintext" Epistemos/LocalAgent EpistemosTests`
- log: `TEST SUCCEEDED`
- test: `IncrementalToolCallDetectorTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/local-agent-reflex-detector-eof-flush-completion-pr31/detectives/local-agent-reflex-eof-detector.md`
- `docs/fusion/fleet/local-agent-reflex-detector-eof-flush-completion-pr31/aggregator.md`
- `docs/fusion/fleet/local-agent-reflex-detector-eof-flush-completion-pr31/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: closes branch/canon drift and prevents the committed LocalAgentLoop EOF call from depending on an uncommitted detector API
