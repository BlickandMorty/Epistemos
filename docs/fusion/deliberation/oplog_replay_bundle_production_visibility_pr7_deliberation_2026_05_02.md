# OpLog ReplayBundle Production Visibility PR7 Deliberation - 2026-05-02

Slice: `oplog-replay-bundle-production-visibility-pr7`

## Decision
Approve a narrow read-only production visibility slice for the existing `MutationOpLogReplayBundle` export substrate.

## Why Now
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` leaves production ReplayBundle visibility open after OpLog PR5/PR6.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 6 explicitly names production ReplayBundle visibility as a future provenance gate.
- Current code already has deterministic, privacy-preserving ReplayBundle export; this slice only surfaces bounded counts.

## Allowed Files
- `Epistemos/Engine/MutationOpLogReplay.swift`
- `Epistemos/Views/Settings/OpLogProjectionHealthRow.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/fleet/oplog-replay-bundle-production-visibility-pr7/**`
- `docs/fusion/oversight/PREFLIGHT_26_2026_05_02.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

## Forbidden Files
- `Epistemos/Views/Notes/**`
- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- generated bindings/libraries
- Xcode project files and entitlements

## Implementation Contract
- Add no mutation, repair, export button, polling loop, timer, graph/retrieval/Halo/Theater consumer, or generated/Rust ABI change.
- Keep raw `oplog_*` symbols confined to `RustOpLogFFIClient.swift`.
- The Settings row may show only bounded counts/ids derived from a read-only ReplayBundle report.
- Preserve ReplayBundle privacy: no raw `sourcePayloadJSON` or note body text in visible diagnostics.

## Acceptance
- Red source guard fails before implementation because no production ReplayBundle visibility report exists in the Settings row.
- Focused green test proves the row references `MutationOpLogReplayBundleVisibilityReport`, displays ReplayBundle counts, and has no raw ABI/repair/timer/mutation symbols.
- Existing OpLog bridge/export tests still pass.

## Canon anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` Safe Next Build Order
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 6

## Workcard match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 6 - EventStore To OpLog Projection Gate.
- Deviation: This is a named future sub-gate under Card 6: production ReplayBundle visibility only.

## Failure-proof guardrails (post-merge)
- grep: `MutationOpLogReplayBundleVisibilityReport`
- log: `OpLog ReplayBundle production visibility row is read-only`
- test: `OpLogFFIBoundaryGuardTests`

## Fleet evidence packet
- `docs/fusion/fleet/oplog-replay-bundle-production-visibility-pr7/aggregator.md`
- `docs/fusion/fleet/oplog-replay-bundle-production-visibility-pr7/codex-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: "Closes a documented Card 6 visibility gap without broad runtime or manual UI work."
