# R16 Background Indexing Visible Status PR3A Deliberation - 2026-05-01

## Verdict

Approved for a small feature slice.

This gate only surfaces the existing ShadowVaultBootstrapper progress in
Settings Diagnostics. It does not approve AFM sidecar generation, Rust ETL FFI,
xattr sidecar marking, security-scoped bookmark changes, or editor badges.

## Scope

Make background indexing visible and honest by recording the existing vault
bootstrap crawl state and rendering it in Settings -> General -> Diagnostics.

## Allowed Files

- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Views/Settings/EditorBundleHealthRow.swift`
- `Epistemos/Views/Settings/SettingsView.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_028_2026_05_01.md`

## Forbidden Files

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/src/lib.rs`
- Xcode project files, entitlements, generated bindings, staging, commits

## Acceptance

- Settings Diagnostics includes a Background Indexing row.
- The row reads real bootstrap status from the existing shadow crawl path.
- No AFM sidecar or ETL FFI behavior is claimed.
- A focused test covers the status recorder.

## Commands

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test`
- `git diff --check -- Epistemos/App/AppBootstrap.swift Epistemos/Views/Settings EpistemosTests/ShadowVaultBootstrapperTests.swift docs/fusion`

## Stop Triggers

- The status row requires project-file edits.
- The row would misrepresent AFM sidecar generation as active.
- The change touches protected note editor, graph view/controller, or graph-engine paths.
