# OpLog No-Swift-Bridge Guard Deliberation - 2026-04-30

## Gate

Approved action: **tests-only source guard**.

This gate may add Swift tests that document the current Rust OpLog FFI boundary. It does not approve a Swift bridge, Rust edits, production call sites, generated binding edits, AgentEvent/GraphEvent projection, graph projection, or UI integration.

## Context

The previous OpLog boundary audit proved:

- `build-rust/libagent_core.dylib` exports the raw `oplog_*` symbols for both `arm64` and `x86_64`.
- `agent_core/src/oplog.rs` contains four manual raw C ABI functions.
- Swift app/tests and generated bindings did not call or expose those symbols.
- Rust `oplog` focused tests passed.

That evidence was useful but ephemeral. A SourceMirror regression guard keeps the boundary visible in normal Swift test runs.

## Decision

Add source-level tests that assert:

- `agent_core/src/lib.rs` still exposes `pub mod oplog;`.
- `agent_core/src/oplog.rs` still has exactly the four known raw `oplog_*` C ABI exports.
- The raw exports remain marked with `#[unsafe(no_mangle)]`.
- The manual ownership/freeing markers remain visible near the boundary:
  - `Arc::into_raw`
  - `Arc::decrement_strong_count`
  - `CString::new(json)`
  - `CString::from_raw`
  - `out_error`
- Swift production source under `Epistemos/` does not call any raw `oplog_*` symbol before a future bridge deliberation.

## Files Approved

- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/deliberation/oplog_no_swift_bridge_guard_deliberation_2026_04_30.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_008_2026_04_30.md`

## Files Forbidden

- `agent_core/src/oplog.rs`
- `agent_core/src/lib.rs`
- any Rust source or Cargo manifest
- Swift production bridge/client files
- generated bindings or build artifacts
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- graph-engine physics/render internals
- project files, entitlements, stashes, branches, staging, or commits

## Verification

Command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/OpLogFFIBoundaryGuardTests test
```

Result:

- Log: `/tmp/epistemos-oplog-no-swift-bridge-guard-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_20-27-03--0500.xcresult`
- Swift Testing result:
  - `2` tests passed
  - `1` suite passed
- Xcode result: `** TEST SUCCEEDED **`
- Existing SwiftLint plugin command failures for `CodeEditSourceEditor` and `CodeEditTextView` still appear after test success.

## Outcome

Status: **passed tests-only guard**.

No production code, Rust code, generated files, protected graph/editor files, project settings, entitlements, branches, stashes, staging, or commits were changed.

## Next Gate

The next OpLog/RunEventLog step must remain blocked until a separate bridge implementation deliberation defines ownership, nullability, allocator/freeing, error handling, runtime tests, and rollback behavior.
