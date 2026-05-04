# OpLog Chain Verification PR4B Deliberation - 2026-05-01

Approved action: **read-only cryptographic OpLog chain verification**.

This gate follows EventStore OpLog replay snapshot PR4A. It adds a bounded
verification report over the existing Rust BLAKE3 `prev_hash` chain, exposes
that report through the existing Swift-owned raw ABI bridge, and proves expected
chain-tip anchoring. It does not add rollback, repair, UI, GraphEvent,
AgentEvent, ReplayBundle export, generated bindings, or production policy
changes.

## Evidence

- `agent_core/src/oplog.rs` already stores `prev_hash` per row, computes a
  BLAKE3 chain tip, persists rows to SQLite, and exposes a narrow raw C ABI.
- `Epistemos/Engine/RustOpLogFFIClient.swift` owns all raw OpLog symbols and
  frees Rust-allocated strings through `oplog_free_string`.
- `Epistemos/Engine/MutationOpLogReplay.swift` already folds decoded OpLog
  entries into read-only projection snapshots. PR4B must not rebuild that fold.
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` names
  cryptographic replay verification as an open provenance-hardening gate.
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
  says future replay work should target chain verification, incremental replay,
  ReplayBundle export, or production visibility behind a new gate.

## Allowed Write Set

- `agent_core/src/oplog.rs`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- Docs under `docs/fusion/**`

## Forbidden Write Set

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/**`
- `Epistemos/Engine/MutationOpLogProjector.swift`
- `Epistemos/Engine/MutationOpLogProjectionWorker.swift`
- `Epistemos/State/EventStore.swift`
- `Epistemos/App/AppBootstrap.swift`
- Generated Swift/header bindings, generated libraries, Xcode project files,
  entitlements, DerivedData, `.xcresult`, staging, commits, stashes, or branch
  operations

## Implementation Contract

- Add a read-only Rust verification report that checks contiguous sequence
  numbers, `prev_hash` continuity from genesis, computed chain-tip parity, and
  optional expected-tip anchoring.
- Expose one bounded raw ABI function returning JSON, using the existing
  `oplog_free_string` allocator contract.
- Add one Swift Codable mirror and one `RustOpLogFFIClient.verifyChain(...)`
  method. Raw symbols must remain private to `RustOpLogFFIClient`.
- Do not mutate the OpLog, projection outbox, EventStore, Settings UI, or
  product behavior.
- Do not add timers, polling loops, repair buttons, rollback execution, or
  ReplayBundle export in this slice.

## Tests And Logs

Red first:

```bash
cargo test --manifest-path agent_core/Cargo.toml oplog --lib
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/OpLogSwiftBridgeTests -only-testing:EpistemosTests/OpLogFFIBoundaryGuardTests test
```

Green:

```bash
cargo test --manifest-path agent_core/Cargo.toml oplog --lib
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/OpLogSwiftBridgeTests -only-testing:EpistemosTests/OpLogFFIBoundaryGuardTests test
```

Guardrails:

```bash
git diff --check -- agent_core/src/oplog.rs Epistemos/Engine/RustOpLogFFIClient.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion
rg -n "oplog_(open_at|iter_after_json|iter_all_json|append_payload_json|chain_tip_hex|verify_chain_json|release|free_string)" Epistemos --glob '*.swift' --glob '!Epistemos/Engine/RustOpLogFFIClient.swift'
git diff --name-only -- Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseEditorView.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift graph-engine epistemos-shadow build-rust
```

## Acceptance

- Rust verifies a valid persisted chain and detects a tampered `prev_hash`.
- Swift can request a verification report, pass the current expected chain tip,
  and receive a valid report without touching generated bindings.
- Swift detects expected-tip mismatch as invalid with a bounded failure reason.
- Existing OpLog raw ABI ownership tests are updated so the new verifier is
  explicit and still isolated to `RustOpLogFFIClient`.
- Focused Rust and Swift tests pass and raw logs are recorded under `/tmp`.

## Stop Triggers

- The verifier needs generated binding edits, graph-engine edits, EventStore
  mutation, Settings UI mutation, or protected editor/graph paths.
- The verifier mutates or repairs rows instead of reporting integrity state.
- Raw OpLog symbols appear outside `RustOpLogFFIClient`.
- Cargo OpLog tests or focused Swift OpLog bridge/boundary tests fail after
  implementation.

## Closeout - 2026-05-01

Gate status: **closed**.

Files changed by this slice:

- `agent_core/src/oplog.rs`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- Docs under `docs/fusion/**`

Implemented:

- Added `OpLogChainVerificationReport` in Rust with read-only validation for
  contiguous `seq`, `prev_hash` continuity from genesis, recomputed chain-tip
  parity, and optional expected-tip anchoring.
- Added bounded raw ABI `oplog_verify_chain_json`, returning JSON through the
  existing Rust-owned string/free contract.
- Added Swift `OpLogChainVerificationReport` plus
  `RustOpLogFFIClient.verifyChain(expectedTipHex:)`; raw OpLog symbols remain
  private to the Swift bridge.
- Added red-first Rust and Swift tests for valid-chain verification, persisted
  tamper detection, expected-tip mismatch reporting, Swift bridge decoding, and
  raw ABI ownership.

Red evidence:

- Cargo red log:
  `/tmp/epistemos-oplog-chain-verify-pr4b-red-cargo-20260501.log`
- Xcode red log:
  `/tmp/epistemos-oplog-chain-verify-pr4b-red-xcode-20260501.log`

Green evidence:

- Cargo green log:
  `/tmp/epistemos-oplog-chain-verify-pr4b-green-cargo-20260501-r1.log`
  (`19` focused OpLog tests passed).
- Xcode green log:
  `/tmp/epistemos-oplog-chain-verify-pr4b-green-xcode-20260501-r1.log`
  (`8` focused Swift tests passed across `OpLogFFIBoundaryGuardTests` and
  `OpLogSwiftBridgeTests`; Xcode reported `** TEST SUCCEEDED **`).

Guardrails:

- `cargo fmt --manifest-path agent_core/Cargo.toml --check` passed.
- `git diff --check -- agent_core/src/oplog.rs Epistemos/Engine/RustOpLogFFIClient.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion`
  passed.
- Raw OpLog symbol grep outside `RustOpLogFFIClient.swift` returned no Swift
  production matches.
- `nm -gU build-rust/libagent_core.dylib | rg 'oplog_verify_chain_json'`
  confirmed `_oplog_verify_chain_json` is exported.
- Protected-path scan still reports inherited dirty `graph-engine/**` and
  `epistemos-shadow/**` files from the broader branch state; this slice did not
  edit those paths.
- Xcode still reports inherited SwiftLint plugin command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`.
  That remains plugin/lint noise, not a PR4B test failure.
