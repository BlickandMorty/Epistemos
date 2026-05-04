# Codex Kimi Oversight Round 037 - 2026-05-01

## Scope

Raw Thoughts / provenance spine hardening: OpLog Swift Bridge PR1.

This round covered the narrow bridge foundation only. It did not approve
production EventStore integration, UI surfaces, GraphEvent projection,
AgentEvent projection, protected editor work, graph-engine work, generated
binding edits, staging, commits, or branch operations.

## Gate

Deliberation gate:

- `docs/fusion/deliberation/oplog_swift_bridge_pr1_deliberation_2026_05_01.md`

Approved files:

- `agent_core/src/oplog.rs`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
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

Initial Kimi run:

- `/tmp/epistemos-oplog-swift-bridge-pr1-kimi-advisory-20260501.log`
- Result: stalled mid-read and was terminated by Codex.

Fallback Kimi run:

- `/tmp/epistemos-oplog-swift-bridge-pr1-kimi-advisory-fallback-20260501.log`
- Resume id: `642337d3-daec-4e4a-95a7-d3e08bc66bfc`

Kimi concluded:

- No P0/P1 blockers found.
- Suggested hardening the legacy missing-`prev_hash` serde path.
- Suggested documenting `actorID` behavior on reopen.
- Suggested keeping null-handle assumptions explicit.

Codex accepted the low-risk hardening suggestions that fit this gate:

- Added a Rust test proving legacy wire `Op` JSON without `prev_hash` defaults
  to genesis.
- Documented that Swift `actorID` is used for future appends while existing
  persisted rows keep their original actor IDs.

The null-handle concern did not require code: `RustOpLogFFIClient.init` throws
if `oplog_open_at` returns null, and the stored handle is non-optional.

## Codex Audit

Codex independently verified:

- Rust exports remain explicit and bounded to six raw OpLog ABI functions.
- Swift raw-symbol use is isolated to `RustOpLogFFIClient`.
- Swift owns the Rust handle and releases it in `deinit`.
- Rust-allocated C strings are freed with `oplog_free_string`.
- Append uses JSON serde payloads, not debug strings.
- Chain-tip hex is stable across open, append, reopen, and second append.
- No production call site was added in this slice.

## Verification Logs

Red test:

- `/tmp/epistemos-oplog-swift-bridge-pr1-red-20260501.log`
- Expected failure before implementation: `Cannot find 'RustOpLogFFIClient' in scope`.

Rust focused:

- `/tmp/epistemos-oplog-swift-bridge-pr1-cargo-test-final-20260501.log`
- Result: `16` OpLog tests passed, `0` failed.

Swift focused:

- `/tmp/epistemos-oplog-swift-bridge-pr1-final2-xcode-20260501.log`
- Result: `3` Swift bridge/boundary tests passed, `0` failed.
- Xcode reported `** TEST SUCCEEDED **`.

Guardrails:

- `cargo fmt --manifest-path agent_core/Cargo.toml --check`
- `git diff --check -- agent_core/src/oplog.rs Epistemos/Engine/RustOpLogFFIClient.swift EpistemosTests/CognitiveSubstrateTests.swift docs/fusion`
- `rg -n "oplog_(open_at|iter_after_json|append_payload_json|chain_tip_hex|release|free_string)" Epistemos --glob '*.swift' --glob '!Epistemos/Engine/RustOpLogFFIClient.swift'`

Guardrail result:

- Rust formatting and diff checks passed.
- Production-call-site grep returned no raw OpLog usages outside the bridge.

## Decision

OpLog Swift Bridge PR1 is approved as a foundation slice.

This proves a narrow Swift-owned bridge to the existing Rust append-only OpLog:
open, append payload JSON, read chain-tip hex, iterate after a sequence, reopen,
and verify the hash-chain predecessor relationship.

It does not yet make OpLog the product event log. The next provenance slice must
open a new gate for EventStore/MutationEnvelope projection into OpLog.

## Process Notes

- The local Kimi config exposed `Kimi-k2.6` only. Two obvious 2.5 model ids were
  attempted and rejected with `LLM not set`.
- The successful fallback used the same Kimi provider with no-thinking,
  final-only output to avoid the earlier stalled long transcript.
- The selected Xcode test still emitted inherited SwiftLint command failures
  for `CodeEditSourceEditor` and `CodeEditTextView` after the tests passed and
  Xcode reported `** TEST SUCCEEDED **`.
- Existing dirty `graph-engine/**` paths remain in the worktree from outside
  this slice; this slice did not edit them.
