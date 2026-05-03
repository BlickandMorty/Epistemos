# Bridge No-Double-Count Source Guards PR44 — Deliberation — 2026-05-03

## Decision

Approve a test-only slice that locks the post-PR43 Bridge invariant: transport, parser, router, and Swift tier-policy bridge files must not emit direct AgentEvent rows.

## Tier Classification

- Tier: Both
- Core impact: test-only source guard; no Core runtime behavior changes.
- Pro/Research impact: prevents future Pro bridge layers from double-counting tool events.

## Allowed Files

- `EpistemosTests/AgentEventBridgeNoDoubleCountSourceGuardTests.swift`
- `docs/fusion/fleet/bridge-no-double-count-source-guards-pr44/`
- `docs/fusion/deliberation/bridge_no_double_count_source_guards_pr44_deliberation_2026_05_03.md`
- `docs/fusion/oversight/PREFLIGHT_85_2026_05_03.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/fleet/REGISTRY.md`

## Forbidden Files

- Production Swift/Rust source.
- Protected paths: `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Views/Graph/HologramController.swift`, graph physics/render internals.
- Project/package/build files.
- Parallel-agent test files already created outside this slice.

## Acceptance

- New Swift Testing suite reads `StreamingDelegate.swift`, `ChunkedMCPFraming.swift`, `CoTStreamInterceptor.swift`, and `ToolTierBridge.swift`.
- The suite fails if any of those files directly instantiate `AgentToolProvenanceRecorder` or call `recordToolEvent`.
- Focused xcodebuild test passes.
- No production source files are modified.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §6.
- `AGENT_EVENT_RUNTIME_COVERAGE_MAP_PR42_DELTA_2026_05_03.md` §3.2.
- `AGENT_EVENT_RUNTIME_COVERAGE_MAP_PR42_DELTA_2026_05_03.md` §4.

## Workcard match

- `PARALLEL_WORK_MANIFEST.md` round-82 P5: AgentEvent Bridge No-Double-Count Source Guards.
- Deviation: Codex is implementing it directly now because PR43 is closed and the file is disjoint from all uncommitted parallel test artifacts.

## Failure-proof guardrails (post-merge)

- grep: `rg -n "AgentToolProvenanceRecorder\\(|recordToolEvent\\(" Epistemos/Bridge/ChunkedMCPFraming.swift Epistemos/Bridge/CoTStreamInterceptor.swift Epistemos/Bridge/StreamingDelegate.swift Epistemos/Bridge/ToolTierBridge.swift`
- log: `Test Suite 'AgentEvent Bridge No-Double-Count Source Guards' passed`
- test: `EpistemosTests/AgentEventBridgeNoDoubleCountSourceGuardTests`

## Fleet evidence packet

- `docs/fusion/fleet/bridge-no-double-count-source-guards-pr44/aggregator.md`
- `docs/fusion/fleet/bridge-no-double-count-source-guards-pr44/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Preserves Bridge completion by preventing future double-count AgentEvent instrumentation at lower layers.
