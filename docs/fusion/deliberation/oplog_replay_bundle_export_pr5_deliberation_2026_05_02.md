# OpLog ReplayBundle Export PR5 Deliberation - 2026-05-02

## Tier

Core. This is local, read-only provenance evidence export over existing decoded OpLog replay data.

## Approved action

Add a Swift-only deterministic ReplayBundle export for `MutationOpLogReplaySnapshot`.

## Canon evidence

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §1: current code and passing logs are highest authority.
- `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:648` leaves "ReplayBundle export" open.
- `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md:566` says PR4A already supplies replay snapshots and future replay work should target ReplayBundle export.
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:35` is the existing deterministic replay fold.

## Allowed write set

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/CognitiveSubstrateTests.swift`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/oplog-replay-bundle-export-pr5/**`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_13_2026_05_02.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/REGISTRY.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

## Forbidden write set

- `/Users/jojo/Downloads/Epistemos/Epistemos/State/EventStore.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/RustOpLogFFIClient.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogProjector.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogProjectionWorker.swift`
- `/Users/jojo/Downloads/Epistemos/agent_core/**`
- `/Users/jojo/Downloads/Epistemos/graph-engine/**`
- `/Users/jojo/Downloads/Epistemos/epistemos-shadow/**`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/**`
- generated bindings, generated libraries, Xcode project files, entitlements, DerivedData, `.xcresult`

## Implementation contract

- Add immutable `Codable`, `Equatable`, `Sendable` export types in the existing replay file.
- Export from an existing replay snapshot; do not rebuild replay semantics.
- Include schema version, source, cutoff/highest replay sequence, replayed entry count, record count, duplicate count, ignored non-projection count, records, and duplicates.
- Define `replayedEntryCount` as `records.count + duplicates.count + ignoredNonProjectionCount`, i.e. entries processed at or below cutoff including ignored non-projections and duplicate projections.
- Do not export `sourcePayloadJSON`. Bundle records may export only bounded identifiers/status/hash fields already surfaced by replay records; tests must prove source payload JSON, note bodies, prompt bodies, chat history, cwd, vault paths, and system prompts are absent from deterministic JSON.
- Provide deterministic JSON encoding with sorted keys.
- Add a convenience `RustOpLogFFIClient` method in `MutationOpLogReplay.swift` only, using existing `iterateAll()` and existing replay.
- Do not mutate EventStore or OpLog. Do not append, repair, execute rollback, schedule background work, open UI, or add raw ABI.

## Tests

Red first:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/OpLogSwiftBridgeTests test
```

Expected new failures before implementation:

- `Mutation OpLog replay exports deterministic ReplayBundle JSON`
- `Swift bridge exports ReplayBundle from real OpLog`

Green uses the same focused command.

## Acceptance

- ReplayBundle export round-trips through `JSONEncoder`/`JSONDecoder`.
- Deterministic JSON bytes are stable for repeated encodes of the same bundle.
- Bundle summary counts match replay records, duplicates, and ignored non-projection entries.
- Real Rust OpLog bridge can produce a bundle without new raw ABI or edits to `RustOpLogFFIClient.swift`.
- Protected-path scan shows no PR5 edits outside the allowed write set.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §1
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` lines 105-115, 648-650, 718-741
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 6

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 6 - EventStore To OpLog Projection Gate
- Deviation: This is a named future sub-gate under Card 6: ReplayBundle export only. It narrows the write set below Card 6 because no EventStore, Rust ABI, or projection worker changes are needed.

## Failure-proof guardrails (post-merge)

- grep: `rg -n "oplog_open_at|oplog_append_payload_json|@_silgen_name|markMutationProjectionOutboxProjected|recordMutationProjectionOutboxFailure|claimMutationProjectionOutboxRows|repair|rollback" Epistemos/Engine/MutationOpLogReplay.swift EpistemosTests/CognitiveSubstrateTests.swift`
- log: `** TEST SUCCEEDED **`
- test: `EpistemosTests/OpLogSwiftBridgeTests`

## Fleet evidence packet

- `docs/fusion/fleet/oplog-replay-bundle-export-pr5/aggregator.md`
- `docs/fusion/fleet/oplog-replay-bundle-export-pr5/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Converts a named open provenance export lane into a testable Swift-only slice.
