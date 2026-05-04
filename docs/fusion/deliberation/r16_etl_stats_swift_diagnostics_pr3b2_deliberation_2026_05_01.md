# R16 ETL Stats Swift Diagnostics PR3B.2 Deliberation - 2026-05-01

## Verdict

Approved for a narrow Swift diagnostics bridge after PR3B.1.

This gate wires the Rust ETL stats C ABI into the existing Settings
Background Indexing diagnostic row. It does not approve AFM sidecar
generation, ETL job dispatch, generated UniFFI bindings, project-file edits,
or protected editor/graph changes.

## Scope

- Add a Swift reader for `etl_queue_stats_json` / `etl_queue_free_string`.
- Record ETL queue stats into the existing `BackgroundIndexingHealthRow`
  diagnostics snapshot.
- Refresh stats from `AppBootstrap` only for the derived per-vault queue path,
  without creating queue databases from Swift.
- Add focused Swift Testing coverage for the diagnostics recorder.

## Allowed Files

- `Epistemos/Engine/RustShadowFFIClient.swift`
- `Epistemos/Views/Settings/EditorBundleHealthRow.swift`
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_032_2026_05_01.md`

## Forbidden Files

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/**`
- Generated UniFFI bindings, Xcode project files, entitlements, generated
  `.rlib`, DerivedData, `.xcresult`, staging, commits, stash operations

## Acceptance

- Settings diagnostics can display ETL queue availability and counts from the
  Rust C ABI JSON snapshot.
- Missing queue databases show an honest not-started/unavailable state.
- Existing Shadow bootstrap progress remains visible and unchanged.
- Focused `ShadowVaultBootstrapperTests` pass.
- No protected or generated files are edited.

## Commands

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test`
- `git diff --check -- Epistemos/Engine/RustShadowFFIClient.swift Epistemos/Views/Settings/EditorBundleHealthRow.swift Epistemos/App/AppBootstrap.swift EpistemosTests/ShadowVaultBootstrapperTests.swift docs/fusion`
