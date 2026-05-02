# Durable GraphEvent Projection Snapshot PR3 Deliberation - 2026-05-01

## Verdict

Proceed with a read-only Swift projection snapshot over durable `graph_events`.

This is the smallest safe live-projection step after PR1 durable mapping and
PR2 Settings visibility. It consumes persisted `DurableGraphEvent` rows and
folds them into deterministic node/edge projection state without touching the
protected graph renderer, note editor, Rust graph engine, OpLog, Halo, Theater,
or retrieval surfaces.

## Why This Slice Now

- The current doctrine lists live GraphEvent projection as a Core-open item.
- EventStore already persists graph events and exposes read-only diagnostics.
- Production hook mounting has no current non-test call-site evidence.
- Halo V1 requires protected editor gating.
- R15 remaining baselines are valuable but do not advance the substrate spine
  as directly as consuming typed graph provenance.
- R16 full closure needs manual/runtime verification, which the user deferred.

## Authority Evidence

- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` says GraphEvent
  PR1 and PR2 are closed and live projections remain open.
- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` lists live GraphEvent
  projection under Core open work.
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
  Card 8 allows future projection PRs only after a new gate names exact files.
- `Epistemos/Models/MutationEnvelope.swift` owns `DurableGraphEvent`,
  `DurableGraphEventKind`, and `DurableGraphEventRelation`.
- `Epistemos/State/EventStore.swift` owns `graph_events`, `saveGraphEvent`,
  `loadGraphEvent`, `graphEvents(mutationID:limit:)`, and
  `graphEventDiagnostics()`.
- `EpistemosTests/CognitiveSubstrateTests.swift` already covers graph event
  persistence, bounded mutation reads, diagnostics, and committed-envelope
  emission.

## Scope

Add a read-only projection fold that turns a bounded chronological stream of
durable graph events into a deterministic in-memory node/edge snapshot, plus a
bounded EventStore query for the most recent graph events in chronological
projection order.

This is an audit/projection substrate slice, not a user-facing graph renderer,
retrieval, Halo, Theater, or repair feature.

## Allowed Write Set

- `Epistemos/Models/MutationEnvelope.swift`
- `Epistemos/State/EventStore.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- This deliberation file

## Forbidden Write Set

- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `agent_core/**`
- `epistemos-shadow/**`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Engine/PipelineService.swift`
- `Epistemos/Engine/HookRegistry.swift`
- `Epistemos/Omega/**`
- generated bindings, generated libraries, Xcode project files, entitlements,
  DerivedData, `.xcresult`, or build artifacts

## Implementation Contract

- EventStore remains the durable source of `graph_events`.
- Add only read APIs and pure in-memory projection folding.
- Bounded reads must clamp negative/zero limits to empty and cap at the existing
  graph-event read maximum.
- Recent events must be returned in chronological projection order, even when
  selected from the latest rows.
- Projection folding must be deterministic:
  - node create/update records the latest node state;
  - node delete removes that node;
  - edge create/update records the latest relation state;
  - edge update removes the old labeled edge when `oldLabel` differs;
  - edge delete removes the relation edge;
  - generic `graph_mutation` rows count as consumed events but do not invent
    synthetic graph structure.
- No UI, renderer, retrieval, Halo, Theater, OpLog, AgentEvent, Rust, or FFI
  dependency may be introduced.

## Test Plan

Red first:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test | tee /tmp/epistemos-graph-event-projection-pr3-red-20260501.log
```

Green focused:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test | tee /tmp/epistemos-graph-event-projection-pr3-green-20260501.log
```

Guardrails:

```bash
git diff --check -- Epistemos/Models/MutationEnvelope.swift Epistemos/State/EventStore.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion
/usr/bin/grep -nE "MetalGraphView|HologramController|ProseEditor|RustOpLogFFIClient|MutationOpLogProjector|MutationOpLogProjectionWorker|HookRegistry|Omega|ChatCoordinator|PipelineService|graph-engine|agent_core" Epistemos/Models/MutationEnvelope.swift Epistemos/State/EventStore.swift
git diff --name-only -- Epistemos/Views/Graph Epistemos/Graph Epistemos/Views/Notes graph-engine agent_core epistemos-shadow Epistemos/App/ChatCoordinator.swift Epistemos/Engine/PipelineService.swift Epistemos/Engine/HookRegistry.swift Epistemos/Omega
```

## Acceptance

- Wired: EventStore exposes a bounded recent GraphEvent read path.
- Reachable: tests can save durable graph rows and feed them to the projection
  snapshot without production UI or graph renderer dependencies.
- Visible: focused tests prove chronological recent reads, node/edge folding,
  edge-label update handling, deletion handling, and empty-limit behavior.
- Boundary: source and diff guardrails prove no protected graph/editor/Rust/
  Omega/chat/pipeline/hook files were touched.

## Closeout

Implementation is closed as a read-only substrate projection snapshot.

- Red log: `/tmp/epistemos-graph-event-projection-pr3-red-20260501.log`
  failed as expected before implementation because `EventStore.recentGraphEvents`
  and `DurableGraphEventProjection` did not exist.
- Green log: `/tmp/epistemos-graph-event-projection-pr3-green-20260501.log`
  passed with 33 tests in the EventStore Cognitive Tables suite after the
  implementation and blank-relation edge guard.
- Known external noise: the Xcode test command still reports the existing
  CodeEdit SwiftLint package-plugin `Output` folder failures, but the selected
  Swift Testing suite reports `TEST SUCCEEDED`.
- Diff guardrail: `git diff --check` over the allowed code/docs paths passed.
- Doctrine invariant guardrail: diff-only grep over the code implementation
  found no protected graph/editor/Rust/OpLog/Omega/chat/pipeline/hook paths and
  no new subprocess, solver-hot-path, unsafe, or Swift kernel-global patterns.

## Stop Triggers

- The projection needs `Epistemos/Graph/**`, renderer, editor, Rust, or FFI
  changes.
- The implementation changes `MutationEnvelope` or `DurableGraphEvent` wire
  format.
- EventStore read behavior becomes unbounded or nondeterministic.
- Projection creates graph structure from generic `graph_mutation` rows.
- Tests require broad app launch or manual runtime verification to pass.

## Rollback

Remove the projection structs, the recent EventStore read API, the PR3 tests,
and this deliberation/doc update. Durable GraphEvent PR1/PR2 persistence and
Settings visibility remain intact.
