# AgentGrep AgentEvent PR14 Deliberation - 2026-05-02

## Slice

Card 7 PR14 adds bounded AgentEvent provenance to the clean
`AgentGrepService.search(query:kindFilter:limit:)` chokepoint.

## Gate

Allowed write set for this slice:

- `Epistemos/Engine/AgentGrepService.swift`
- `EpistemosTests/AgentGrepServiceTests.swift`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/deliberation/agent_grep_agent_event_pr14_deliberation_2026_05_02.md`
- `docs/fusion/fleet/agent-grep-agent-event-pr14/**`
- `docs/fusion/fleet/REGISTRY.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`

Forbidden for this slice:

- `agent_core/**`
- `graph-engine/**`
- `Epistemos/Views/**`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Engine/PipelineService.swift`
- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `Epistemos/Engine/LLMService.swift`
- `Epistemos/Omega/**`
- EventStore schema, generated bindings, Xcode project, entitlements, approval
  policy, provider routing, UI, graph renderer, OpLog, GraphEvent, indexing
  algorithm, sidecar schema, or mutation semantics.

## Evidence

- Red:
  `/tmp/epistemos-agent-grep-agent-event-pr14-red-20260502.log` failed before
  implementation because the test required an `agentProvenanceRecorder` injection
  point and AgentGrep emitted no AgentEvents.
- Green:
  `/tmp/epistemos-agent-grep-agent-event-pr14-green-20260502.log` passed the
  focused `AgentGrepService (Wave 9.9 base)` Swift Testing suite: 10 tests,
  including `search records sanitized AgentEvents` and
  `search records sanitized backend failure AgentEvents`. Xcode still printed
  the known vendored CodeEdit SwiftLint package-plugin footer after
  `TEST SUCCEEDED`.

## Red Team

- Red Team returned one P1 against whole-worktree review scope:
  `/Users/jojo/Downloads/Epistemos` is already dirty in unrelated forbidden
  surfaces, so reviewing `git diff` globally is not an approvable PR14 gate.
- The isolated PR14 code path had no reported privacy leak: arguments exclude
  query/path/snippet/provenance, result JSON is hit count only, failure events
  use `backend_failure`, and focused tests cover success/failure sanitization.
- Mitigation required before commit: exact-stage only the allowed PR14 files and
  prove `git diff --cached --name-only` is empty for PR14 forbidden surfaces.

## Decision

Approved exactly as scoped after the staged-diff protected-path scan passes.
PR14 is additive instrumentation only: `search(...)` emits
requested/started/completed/failed AgentEvents with stable tool identity while
preserving search behavior and sidecar enrichment. Persisted AgentEvent payloads
intentionally exclude query text, snippets, vault-relative paths, file bodies,
source text, sidecar provenance ids, and tool-use ids.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2`
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:698`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:800`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:905`

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance
- Deviation: none. This is the new exact live-emission gate required for broader runtime AgentEvent coverage after PR13.

## Failure-proof guardrails (post-merge)

- grep: `toolName: "agent_grep.search"`
- grep: `agentGrepSearchArgumentsJSON`
- forbidden grep: `argumentsJSON.*query|resultJSON.*snippet|resultJSON.*vaultRelativePath|resultJSON.*provenance`
- staged guard: `git diff --cached --name-only -- agent_core graph-engine Epistemos/Views Epistemos/Omega Epistemos.xcodeproj Epistemos/State/EventStore.swift`
- log: `✔ Test "search records sanitized AgentEvents" passed`
- test: `AgentGrepService (Wave 9.9 base)`

## Fleet evidence packet

- `docs/fusion/fleet/agent-grep-agent-event-pr14/aggregator.md`
- `docs/fusion/fleet/agent-grep-agent-event-pr14/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes a clean remaining AgentEvent runtime provenance surface without widening routing, UI, graph, or Rust paths.
