# OpLog Swift Bridge PR1 Deliberation - 2026-05-01

## Gate

Approved action: **narrow RunEventLog/OpLog Swift bridge foundation**.

This gate approves a small bridge over the existing `agent_core/src/oplog.rs`
append-only log. It does not approve production UI integration,
`MutationEnvelope` rewiring, AgentEvent/GraphEvent projection, protected editor
work, graph-engine work, generated binding edits, staging, commits, or branch
operations.

## Repo Evidence

- `agent_core/src/oplog.rs` already implements an append-only `OpLog`, SQLite
  persistence, BLAKE3 `prev_hash`, `chain_tip()`, and raw C ABI functions for
  open/iterate/release/free.
- `docs/fusion/deliberation/oplog_ffi_boundary_audit_deliberation_2026_04_30.md`
  proved the original raw symbols exist and are not yet used by Swift.
- `docs/fusion/deliberation/oplog_no_swift_bridge_guard_deliberation_2026_04_30.md`
  blocked Swift integration until a bridge gate defined ownership, nullability,
  allocator/freeing, error handling, runtime tests, and rollback behavior.
- `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` item 5 requires Raw
  Thoughts / Provenance Spine hardening with append-only event-chain evidence.

## Decision

Add the smallest useful bridge:

- Extend Rust C ABI with append and chain-tip read functions.
- Add a Swift `RustOpLogFFIClient` that owns the Rust handle and frees returned
  strings through `oplog_free_string`.
- Decode/encode only the existing `OpPayload` wire variants.
- Add tests proving Swift can open a persistent log, append a payload, iterate
  later payloads with `prev_hash`, reopen the database, and continue the chain.

## Files Approved

- `agent_core/src/oplog.rs`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/oplog_swift_bridge_pr1_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_037_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Files Forbidden

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/**`
- generated Swift/header bindings
- generated libraries
- Xcode project files
- entitlements
- DerivedData, `.xcresult`, `.rlib`
- stash, branch, staging, commit, or destructive git operations

## Implementation Contract

- Swift owns exactly one handle and releases it in `deinit`.
- Null open returns a Swift error.
- Returned JSON strings are always freed with `oplog_free_string`.
- Append uses `serde_json`, not debug string formatting.
- Chain tip is exposed as lowercase hex for diagnostics and later
  `epistemos-trace` verification.
- No production call site is added in this slice.
- No hot path is changed.

## Tests

Red/green Swift focused command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/OpLogSwiftBridgeTests test
```

Rust focused command:

```bash
cargo test --manifest-path agent_core/Cargo.toml oplog --lib
```

Guardrails:

```bash
git diff --check -- agent_core/src/oplog.rs Epistemos/Engine/RustOpLogFFIClient.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion
git diff --name-only -- Epistemos/Views/Notes/ProseEditor\*.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift graph-engine
```

## Rollback

Revert only the approved Rust bridge additions, Swift client, focused tests, and
docs for this slice. The existing Rust OpLog implementation and prior boundary
guards remain otherwise intact.

## Stop Triggers

- Any need to touch protected editor/graph files, `graph-engine/**`, generated
  bindings, project files, entitlements, stashes, branches, staging, or commits.
- Any FFI ownership ambiguity that cannot be tested.
- Any Rust `oplog` test failure.
- Any Swift bridge test failure that requires production call-site changes.
- Any temptation to claim full AgentEvent/GraphEvent projection or product UI
  readiness from this bridge alone.
