# Codex Kimi Oversight Round 038 - 2026-05-01

## Scope

Raw Thoughts / provenance spine hardening: EventStore-to-OpLog Projection PR2.

This round covered the narrow projection foundation only. It did not approve
UI integration, background workers, launch bootstrap scheduling, AgentEvent,
GraphEvent, protected editor work, graph-engine work, generated binding edits,
staging, commits, or branch operations.

## Gate

Deliberation gate:

- `docs/fusion/deliberation/eventstore_oplog_projection_pr2_deliberation_2026_05_01.md`

Approved files:

- `agent_core/src/oplog.rs`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `Epistemos/Engine/MutationOpLogProjector.swift`
- `Epistemos/State/EventStore.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/**`

Forbidden files and actions:

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/**`
- generated Swift/header bindings and generated libraries
- Xcode project files, entitlements, DerivedData, `.xcresult`
- stash, branch, staging, commit, or destructive git operations

## Kimi Result

Final Kimi advisory:

- `/tmp/epistemos-eventstore-oplog-projection-kimi-final-advisory-20260501.log`

Kimi concluded:

- No P0 or P1 blockers found.
- Suggested keeping serialization-failure logging for a future worker slice.
- Suggested documenting the single-writer assumption before any background
  projection worker exists.
- Suggested keeping the timestamp recovery assertion permanent.

Codex accepted the suggestion that fit this gate:

- The recovery test now asserts that append-before-mark recovery records
  `projected_at` from the already-appended OpLog entry timestamp.

The logging and worker-concurrency suggestions are deferred because this PR2
slice intentionally adds no background worker, lease, retry scheduler, or launch
bootstrap.

## Codex Audit

Codex independently verified:

- EventStore remains the committed `MutationEnvelope` source of truth.
- OpLog receives append-only `mutation_projection` payloads from pending outbox
  rows.
- Duplicate recovery includes seq `0` by using `iterateAll()`.
- Already-appended projections are marked without appending duplicates.
- The payload preserves mutation id, trace id, event kind, status, artifact id,
  artifact kind, integrity hash, source payload JSON, and recorded timestamp
  when available.
- Raw OpLog Swift symbol usage remains isolated to `RustOpLogFFIClient`.
- No production UI, background worker, AgentEvent, or GraphEvent path was added.

## Verification Logs

Red test:

- `/tmp/epistemos-eventstore-oplog-projection-red-20260501.log`
- Expected failure before implementation: missing `MutationOpLogProjector`,
  `opLogSeq`, `projectedAt`, and `RustOpLogFFIClient.iterateAll()`.

Rust focused:

- `/tmp/epistemos-eventstore-oplog-projection-cargo-test-post-kimi-20260501.log`
- Result: `16` OpLog tests passed, `0` failed.

Swift EventStore focused:

- `/tmp/epistemos-eventstore-oplog-projection-green-suite-post-kimi-20260501.log`
- Result: `11` EventStore cognitive table tests passed, `0` failed.
- Xcode reported `** TEST SUCCEEDED **`.

Swift bridge/boundary focused:

- `/tmp/epistemos-eventstore-oplog-projection-bridge-boundary-post-kimi-20260501.log`
- Result: `3` Swift bridge/boundary tests passed, `0` failed.
- Xcode reported `** TEST SUCCEEDED **`.

Guardrails:

- `cargo fmt --manifest-path agent_core/Cargo.toml --check`
- `git diff --check -- agent_core/src/oplog.rs Epistemos/Engine/RustOpLogFFIClient.swift Epistemos/Engine/MutationOpLogProjector.swift Epistemos/State/EventStore.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion`
- `rg -n "oplog_(open_at|iter_after_json|iter_all_json|append_payload_json|chain_tip_hex|release|free_string)" Epistemos --glob '*.swift' --glob '!Epistemos/Engine/RustOpLogFFIClient.swift'`
- `git diff --name-only -- graph-engine Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseEditorView.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift`

Guardrail result:

- Rust formatting and diff checks passed.
- Production-call-site grep returned no raw OpLog usages outside the bridge.
- Protected-path scan only reported inherited dirty `graph-engine/**` state; no
  protected Swift editor or graph files were touched.

## Decision

EventStore-to-OpLog Projection PR2 is approved as a foundation slice.

This proves committed `MutationEnvelope` outbox rows can be mirrored into the
Rust append-only OpLog without creating a second source of truth, without
duplicating rows across retry/restart, and without making UI success depend on
OpLog.

Next provenance work must open new gates for replay/rollback semantics,
background projection leases/retries, AgentEvent/tool provenance, GraphEvent
mapping, or audit/inspector visibility.

## Process Notes

- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after the selected tests passed
  and Xcode reported `** TEST SUCCEEDED **`.
- Existing dirty `graph-engine/**` paths remain in the worktree from outside
  this slice; this slice did not edit them.
