# W9.21 Honest Handle Swift Cutover Deliberation - 2026-04-30

## Gate

Approved action: **bounded W9.21 PR4 honest-handle cutover plus focused source/runtime verification**.

This gate approves only the Rust `epistemos-shadow` handle surface, the Swift `RustShadowFFIClient` consumer cutover, the AppBootstrap construction path, focused source guards, and documentation. It does not approve W9.8 approval-modal wiring, stash apply/pop/drop, generated artifact adoption, staging, commits, branches, protected note-editor/graph edits, or manual app verification.

## Context

`stash@{0}` is labeled:

`session-stash-2026-04-27: W9.21 PR4 (X salvaged) + W9.8 wire-up partial; restart-fresh per user`

The stash mixes separable work:

- W9.21 PR4: `epistemos-shadow/src/honest_handle.rs`, `Epistemos/Engine/RustShadowFFIClient.swift`, and `Epistemos/App/AppBootstrap.swift`.
- W9.8 partial: `ChatCoordinator`, `EpistemosApp`, and `ApprovalModalView` queue/modal wiring.
- Generated/adjacent material: `agent_core/Cargo.lock`, `docs/CRITIQUE_LOG.md`, and `syntax-core/target/...` artifacts.

The W9.21 path was safe to reconstruct directly because the intended product behavior is narrow: Swift should own an explicit per-instance shadow handle instead of opening the Rust backend globally and then calling global `shadow_search_json`.

The W9.8 path remains deferred because the stashed `ChatCoordinator` references `ChatApprovalQueue` and `ChatApprovalResolution`, while the current source tree does not define those types.

## Decision

Implement W9.21 PR4 only.

Do not apply, pop, drop, or cherry-pick `stash@{0}`. Do not import W9.8 approval-modal wiring from the stash in this slice.

## Files Approved

- `epistemos-shadow/src/honest_handle.rs`
- `Epistemos/Engine/RustShadowFFIClient.swift`
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/ShadowServicesTests.swift`
- `docs/fusion/deliberation/w921_honest_handle_swift_cutover_deliberation_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_010_2026_04_30.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Files Forbidden

- `stash@{0}` mutation by apply, pop, drop, branch extraction, checkout, or cherry-pick
- W9.8 approval-modal production wiring in `ChatCoordinator`, `EpistemosApp`, or `ApprovalModalView`
- `agent_core/Cargo.lock`
- `docs/CRITIQUE_LOG.md`
- generated `syntax-core/target/.../*.d` and `syntax-core/target/.../*.rlib`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- graph-engine physics/render internals
- project files, entitlements, branches, staging, or commits

## Evidence

Read-only stash stat:

```bash
git stash show --stat 'stash@{0}'
```

Result:

- `10` files changed.
- `1511` insertions.
- `191` deletions.
- Included W9.21, W9.8 partial, critique-log, lockfile, and generated binary artifact material.

Read-only W9.8 incompleteness audit:

```bash
git show 'stash@{0}:Epistemos/App/ChatCoordinator.swift' | rg -n "ChatApprovalQueue|ChatApprovalResolution|NSAlert|promptUserForToolApproval"
rg -n "struct ChatApprovalQueue|class ChatApprovalQueue|@Observable.*ChatApprovalQueue|enum ChatApprovalResolution" Epistemos EpistemosTests
```

Result:

- Stashed `ChatCoordinator` references `ChatApprovalQueue` and `ChatApprovalResolution`.
- Current source has no matching type definition.
- W9.8 remains blocked behind a fresh implementation gate.

## Implementation

Rust:

- Added panic-safe `shadow_handle_*` exports for open, retain, release, search, insert, remove, flush, stats, and free-string.
- Kept legacy global `shadow_open_at` / `shadow_search_json` symbols exported for compatibility.
- Added C-string ownership helpers and safety comments around unsafe pointer operations.

Swift:

- Replaced `RustShadowFFIClient`'s legacy global search/open bindings with explicit handle ownership.
- Added `public init(path: String) throws` and `deinit` release behavior.
- Kept `warm()` routed through the existing global warm function because warming is not handle-scoped.
- Updated AppBootstrap to construct `RustShadowFFIClient(path: shadowRoot.path)` directly for the vault shadow root.

Tests:

- Added `ShadowHonestHandleSourceGuardTests` to prove Swift owns a handle and does not bind/call the old global search/open surface.
- Added source guards for the complete Rust panic-safe handle export surface.

## Verification

Red Swift source guard:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowHonestHandleSourceGuardTests test
```

- Log: `/tmp/epistemos-w921-honest-handle-red-20260430.log`
- Exit code `65`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_20-42-25--0500.xcresult`
- Expected result: `2` tests failed before the handle cutover existed.

Rust verification:

```bash
cargo test --manifest-path epistemos-shadow/Cargo.toml --lib
```

- Log: `/tmp/epistemos-w921-epistemos-shadow-lib-20260430.log`
- Exit code `0`.
- Result: `45 passed`, `0 failed`, `5 ignored`.

Green Swift source guard:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowHonestHandleSourceGuardTests test
```

- Log: `/tmp/epistemos-w921-honest-handle-green-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_20-52-28--0500.xcresult`
- Swift Testing result:
  - `2` tests passed
  - `1` suite passed
- Xcode result: `** TEST SUCCEEDED **`
- Existing SwiftLint plugin command failures for `CodeEditSourceEditor` and `CodeEditTextView` still appear after test success.

Symbol audit:

```bash
nm -gU build-rust/libepistemos_shadow.dylib 2>/dev/null | rg "shadow_handle_|shadow_search_json|shadow_open_at"
```

- Log: `/tmp/epistemos-w921-honest-handle-symbols-20260430.log`
- Result: all nine `shadow_handle_*` symbols are exported.
- Compatibility note: `_shadow_open_at` and `_shadow_search_json` remain exported.

Source regression audit:

```bash
rg -n "@_silgen_name\\(\"shadow_search_json\"\\)|RustShadowFFIClient\\.openAt|RustShadowFFIClient\\(\\)" Epistemos/Engine/RustShadowFFIClient.swift Epistemos/App/AppBootstrap.swift
```

- Log: `/tmp/epistemos-w921-honest-handle-source-regression-20260430.log`
- Result: no matches.

## Outcome

Status: **passed focused W9.21 verification**.

W9.21 PR4 is now represented by production code and source guards. The stashed W9.8 approval-modal partial remains blocked until a separate gate defines and tests the missing queue/resolution types.

## Next Gate

Continue with a new narrow slice. If W9.8 is selected, start with a fresh red test and define `ChatApprovalQueue` ownership, AppEnvironment injection, modal presentation behavior, timeout/cancel semantics, and the fallback policy before touching production code.
