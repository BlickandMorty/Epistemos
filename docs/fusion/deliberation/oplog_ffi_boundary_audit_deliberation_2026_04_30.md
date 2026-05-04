# OpLog FFI Boundary Audit Deliberation - 2026-04-30

## Gate

Approved action: **read-only symbol and source audit only**.

No Swift bridge, no Rust edits, no production integration, no AgentEvent/GraphEvent projection, and no protected-path edits are approved by this gate.

## Repo Evidence

- `agent_core/src/lib.rs` declares `pub mod oplog;`.
- `agent_core/src/oplog.rs` exports four raw C ABI functions:
  - `oplog_open_at`
  - `oplog_iter_after_json`
  - `oplog_release`
  - `oplog_free_string`
- `agent_core/src/oplog.rs` contains BLAKE3 chain-tip and `prev_hash` tests, but no Swift client exists.
- Swift imports `agent_coreFFI` in several places, but no Swift source currently calls the raw `oplog_*` symbols.
- Generated UniFFI Swift/header files do not expose these raw `oplog_*` symbols.

## Research Evidence

- `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` item 5 requires Raw Thoughts / Provenance Spine hardening, but warns that dirty `agent_core` event/log files must be audited before edits.
- `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md` preserves the spine: `TypedArtifact -> MutationEnvelope -> RunEventLog -> AgentEvent -> GraphEvent`.
- `docs/fusion/deliberation/mutation_projection_outbox_pending_reader_deliberation_2026_04_30.md` explicitly rejected bridging directly to Rust `oplog` without a separate Rust boundary deliberation.

## Kimi Advisory

Kimi was invoked in read-only advisory mode from `/tmp` with excerpts embedded in the prompt and no repo access required.

Kimi verdict: accept this as a documentation-and-symbol audit only. Kimi highlighted raw-pointer risks, allocator/freeing requirements, null-contract risk, ownership opacity, and the fact that symbol existence does not prove runtime Swift integration correctness.

Resume id: `14011cf1-9ebc-470d-80d5-0aba060ee74b`

## Decision

Audit only:

- Prove the built `libagent_core.dylib` exports the expected `oplog_*` symbols.
- Prove both dylib architectures carry those symbols.
- Prove generated Swift/header bindings do not expose conflicting `oplog_*` declarations.
- Prove Swift app/tests do not call these raw symbols yet.
- Run focused Rust `oplog` tests.
- Document that this does not implement RunEventLog integration, Swift `OpLogFFIClient`, AgentEvent, GraphEvent, graph projection, or UI visibility.

## Files Likely Touched

- `docs/fusion/deliberation/oplog_ffi_boundary_audit_deliberation_2026_04_30.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_007_2026_04_30.md`

## Forbidden Files

- `agent_core/src/oplog.rs`
- `agent_core/src/lib.rs`
- any Rust source or Cargo manifest
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- graph-engine physics/render internals
- Swift production bridge/client files
- generated `.rlib`, DerivedData, and `.xcresult` bundles

## Verification

Commands:

```bash
nm -gU build-rust/libagent_core.dylib | rg 'oplog_(open_at|iter_after_json|release|free_string)'
lipo -archs build-rust/libagent_core.dylib
nm -arch arm64 -gU build-rust/libagent_core.dylib | rg 'oplog_(open_at|iter_after_json|release|free_string)'
nm -arch x86_64 -gU build-rust/libagent_core.dylib | rg 'oplog_(open_at|iter_after_json|release|free_string)'
rg -n 'oplog_open_at|oplog_iter_after_json|oplog_release|oplog_free_string|\boplog_' build-rust/swift-bindings/agent_coreFFI.h build-rust/swift-bindings/agent_coreFFI/agent_coreFFI.h build-rust/swift-bindings/agent_coreFFI.modulemap build-rust/swift-bindings/agent_core.swift Epistemos EpistemosTests --glob '!**/SourceMirror/**'
cargo test --manifest-path agent_core/Cargo.toml oplog --lib
```

Results:

- `build-rust/libagent_core.dylib` is universal: `x86_64 arm64`.
- `nm` showed the four expected symbols for both `arm64` and `x86_64`:
  - `_oplog_free_string`
  - `_oplog_iter_after_json`
  - `_oplog_open_at`
  - `_oplog_release`
- Generated header/modulemap/Swift binding and app/test source search found no `oplog_*` declarations or call sites outside `agent_core/src/oplog.rs`.
- Rust focused log: `/tmp/epistemos-agent-core-oplog-boundary-20260430.log`
- Rust focused result: `14` `oplog` tests passed; `760` filtered out.

## Stop Triggers

- Any Swift wrapper or call site for `oplog_*` is found.
- Any missing symbol in either dylib architecture.
- Any Rust `oplog` test failure.
- Any need to edit Rust, Swift production bridge files, protected editor/graph files, project settings, entitlements, generated artifacts, stashes, branches, staging, or commits.

## Outcome

Status: **passed read-only boundary audit**.

This gate proves the raw Rust symbols exist in the built library and are not currently integrated into Swift. It does not prove Swift runtime correctness, ownership safety, or complete `RunEventLog` integration. A future Swift bridge must get a separate implementation deliberation with ownership, nullability, allocator, and runtime tests.
