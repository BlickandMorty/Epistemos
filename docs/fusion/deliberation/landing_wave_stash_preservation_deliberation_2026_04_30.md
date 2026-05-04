# Landing Wave Stash Preservation Deliberation - 2026-04-30

## Gate

Approved action: **read-only stash preservation audit plus focused Landing Wave verification**.

This gate may inspect `stash@{1}` and current Landing Wave source to decide whether any finished Landing Wave work needs rescue. It does not approve stash apply/pop/drop, production code edits, graph edits, note editor edits, generated artifact edits, staging, commits, branches, or manual app verification.

## Context

`docs/fusion/WORKTREE_INVENTORY_2026_04_30.md` identified `stash@{1}` as `codex-wip-parallel-during-landing-wave-session` and recommended checking whether the Landing Wave work needed preservation before broader fusion continued.

The stash contains Landing Wave files, but current branch source already carries a newer Landing implementation:

- `LandingView` mounts `LandingWaveOverlay` as the full-surface Metal wave/scrim layer.
- `LiquidGreeting` owns the inline search/greeting experience.
- `landingSearchControlsRow` owns the mention, attach, cache, and send affordances.
- `LandingWaveSearchBar.swift` still exists, but no production call site mounts `LandingWaveSearchBar`.

## Decision

Do not apply, pop, drop, or partially cherry-pick `stash@{1}`.

The current branch appears to supersede the stashed Landing Wave UI. Applying the stash would risk reverting the newer inline `LiquidGreeting` search path back toward an older overlay-hosted `LandingWaveSearchBar` design.

Non-Landing entries in the stash remain deferred to separate deliberations because they touch separate risk surfaces:

- `Epistemos/Engine/NoteInsightService.swift`
- `Epistemos/Vault/LiveNoteScanner.swift`
- `Epistemos/Views/Graph/NodeInspectorState.swift`
- `Epistemos/Views/Graph/PinnedInspector.swift`
- `Epistemos/Views/Notes/NoteBacklinksPanel.swift`
- `EpistemosTests/PhaseR5ChatGrantWiringTests.swift`
- `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-AppStore.xcscheme`
- generated `syntax-core/.../libsyntax_core.rlib`

## Files Approved

- `docs/fusion/deliberation/landing_wave_stash_preservation_deliberation_2026_04_30.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_009_2026_04_30.md`

## Files Forbidden

- `stash@{1}` mutation by apply, pop, drop, branch extraction, checkout, or cherry-pick
- generated `.rlib` artifacts
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- graph-engine physics/render internals
- Landing production source without a failing test and fresh implementation gate
- project files, entitlements, branches, staging, or commits

## Evidence

Read-only stash stat:

```bash
git stash show --stat 'stash@{1}'
```

Result:

- `16` files changed.
- `664` insertions.
- `145` deletions.
- Landing Wave files were present in the stash.
- The stash also included unrelated graph, note, runtime, App Store scheme, R.5 grant, and generated artifact changes.

Current call-site audit:

```bash
rg -n "LandingWaveSearchBar|LiquidGreeting|landingSearchControlsRow|LandingWaveOverlay\\(" Epistemos/Views/Landing -S
```

Result:

- `LandingView` mounts `LandingWaveOverlay`.
- `LandingView` mounts `LiquidGreeting`.
- `LandingView` exposes `landingSearchControlsRow`.
- `LandingWaveSearchBar.swift` defines `LandingWaveSearchBar`, but no production call site uses it.

Current Landing tree status:

```bash
git status --short -- Epistemos/Views/Landing EpistemosTests/LandingWaveChoreographyTests.swift EpistemosTests/LandingWaveGlyphAtlasTests.swift EpistemosTests/LandingOptimizationTests.swift EpistemosTests/LandingWavePerformancePolicyTests.swift
```

Result:

- No Landing Wave source or focused Landing test files were dirty for this preservation slice.

## Verification

Command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/LandingWaveChoreographyTests -only-testing:EpistemosTests/LandingWavePerformancePolicyTests -only-testing:EpistemosTests/LandingWaveGlyphAtlasTests -only-testing:EpistemosTests/LandingOptimizationTests test
```

Result:

- Log: `/tmp/epistemos-landing-wave-preservation-focused-20260430.log`
- Exit code `0`.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_20-34-15--0500.xcresult`
- Swift Testing result:
  - `18` tests passed
  - `4` suites passed
- Xcode result: `** TEST SUCCEEDED **`
- Existing SwiftLint plugin command failures for `CodeEditSourceEditor` and `CodeEditTextView` still appear after test success.

## Outcome

Status: **passed preservation audit**.

Landing Wave does not need rescue from `stash@{1}` at this point. The stash remains untouched for forensic reference, and non-Landing stash contents remain blocked until separate focused deliberations approve or reject them.

## Next Gate

Continue with the next narrow queue item. If `stash@{0}` or the R.5 write-through grant material is considered next, keep it read-only until a separate gate defines the target behavior, test shape, App Store/direct-distribution impact, and rollback plan.
