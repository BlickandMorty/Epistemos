# R16 ETL PR3 Background Indexing Status Shell Deliberation - 2026-05-01

## Verdict

Approved as a narrow Swift-only PR3a slice that adds a Settings → Diagnostics
"Background Indexing" status row with an explicit foundation-stage data source,
contingent on the implementation acceptance below.

This gate does NOT approve:
- Any Rust edit (no `agent_core/**`, `epistemos-shadow/**`, `graph-engine/**`).
- Any FFI surface change (`@_silgen_name`, `extern "C"`, UniFFI bindings, generated
  headers).
- AFM sidecar generation (`AFMSidecarGenerator.swift`), ETL FFI client
  (`RustEtlFFIClient.swift`), or ETL dispatch from
  `Epistemos/Engine/ShadowVaultBootstrapper.swift`.
- Battery/thermal pause wiring, MAS security-scoped bookmark handling, or
  `xattr` model-derived marking.
- Any protected note editor (`Epistemos/Views/Notes/ProseEditor*.swift`),
  protected graph view/controller (`Epistemos/Views/Graph/MetalGraphView.swift`,
  `Epistemos/Views/Graph/HologramController.swift`), or `graph-engine/**`.
- Any change to the dirty tree outside this slice's allowed-files list. Existing
  pre-existing dirty paths must not be normalized, reverted, restaged, or
  rewritten by this PR.

Subsequent PRs (separately gated):
- **PR3b (FFI bridge)**: agent_core ETL queue stats counters (or
  `epistemos-shadow` exports per the dossier) wired into Swift via
  `RustEtlFFIClient.swift`; Status row's reader implementation swaps from the
  shell stub to live counters.
- **PR3c (AFM sidecar generation)**: `AFMSidecarGenerator.swift` + AFM
  `@Generable` schema + `xattr com.epistemos.modelDerived` marking.
- **PR3d (Bootstrapper integration + pause UI)**: ShadowVaultBootstrapper
  triggers ETL after BM25/HNSW pass, battery/thermal pause via
  `PowerGate.shouldDefer()`, MAS bookmark scope enforcement.
- **PR3 final**: WRV claim, `MASTER_BUILD_PLAN.md §7` R16 status flip, removal
  of the foundation-stage placeholder copy.

## Scope

Add a new pure-Swift Settings → Diagnostics row that surfaces the eventual
Background Indexing state defined by `docs/plan/03_EXECUTION_MAP.md:236`
("running/paused/stopped, files processed count"), with an explicit
foundation-stage data source.

The row mirrors the existing `EditorBundleHealthRow` and
`SearchFusionHealthRow` shape so the Diagnostics section gains a third sibling
without restructuring the section. Until PR3b lands, the row reads from a
Swift-internal `BackgroundIndexingStatusReader` protocol whose default
implementation reports `state = .notWiredYet` (not "Idle", not "Running") and
displays explanatory copy stating that live ETL counters are deferred to a
later PR.

This is an honest Wired-but-not-Visible-yet foundation: the row is wired into
the production Diagnostics section; the user can reach it via standard
Settings navigation; the visible content honestly states the foundation
status. WRV claim for the full R16 product item remains deferred to the
terminal R16 PR.

## Authority Evidence

- `docs/MASTER_BUILD_PLAN.md §7 Bucket C` lists `R16 ETL crawler foundation`
  as 🟡 FOUNDATION; queue/job runner foundation already shipped in PR1
  (`dcc5521f`) plus PR2 (Apalis SQLite queue, oversight round 027). The
  multi-PR pattern is explicitly described in `docs/MASTER_BUILD_PLAN.md §8`.
- `docs/plan/03_EXECUTION_MAP.md:235–238` mandates an "ETL state visible in
  Settings → 'Background Indexing' row (running/paused/stopped, files
  processed count)" as the canonical telemetry surface for R16.
- `docs/RESEARCH_DOSSIER_TIER_3_4.md` R16 section confirms `agent_core/src/etl/`
  is the queue home (no separate crate) and that Swift-side wiring + AFM
  sidecar generation are explicit follow-up scope.
- `docs/fusion/deliberation/r16_etl_apalis_queue_pr2_deliberation_2026_05_01.md`
  and `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_027_2026_05_01.md`
  defer Background Indexing UI, AFM sidecar generation, FFI exports, MAS
  bookmark enforcement, `xattr` marking, and battery/thermal pause UI to a
  separate gate.
- `Epistemos/Views/Settings/SettingsView.swift:661–667` already hosts a
  "Diagnostics" section containing `EditorBundleHealthRow()` and
  `SearchFusionHealthRow()`. The new row follows the established pattern
  rather than introducing a new container.

## Current Surface Evidence

- `Epistemos/Views/Settings/EditorBundleHealthRow.swift:18` —
  `public struct EditorBundleHealthRow: View` with a `View` body and
  preview-friendly state seam. Established shape this slice mirrors.
- `Epistemos/Views/Settings/SearchFusionHealthRow.swift:23` —
  `public struct SearchFusionHealthRow: View`. Same established shape with a
  ring-buffer-backed metric reader. Confirms the Diagnostics section already
  carries multiple sibling rows.
- `Epistemos/Views/Settings/SettingsView.swift:661` — `Section("Diagnostics")`
  insertion site. New row appended after `SearchFusionHealthRow()` — no
  reordering of existing rows, no header rename.
- `Epistemos/Engine/ShadowVaultBootstrapper.swift` — exists but is NOT
  modified by this slice. Future PR3d wires actual ETL dispatch.
- `Epistemos/Engine/RustEtlFFIClient.swift` — does NOT exist. This slice does
  NOT create it; it is reserved for PR3b.

## Allowed Files

- `Epistemos/Views/Settings/SettingsView.swift` — append exactly one
  `BackgroundIndexingHealthRow()` line inside the existing
  `Section("Diagnostics")` block. No reordering, no header rename, no
  description-text edits.
- `Epistemos/Views/Settings/BackgroundIndexingHealthRow.swift` — NEW
  pure-Swift `View` mirroring the public shape of `EditorBundleHealthRow` and
  `SearchFusionHealthRow`.
- `Epistemos/State/BackgroundIndexingStatus.swift` — NEW Swift file owning
  the `BackgroundIndexingState` enum, `BackgroundIndexingStatusSnapshot`
  struct, and `BackgroundIndexingStatusReader` protocol with the foundation-
  stage default `BackgroundIndexingStatusReader.foundation` implementation
  that returns `.notWiredYet` and a deterministic snapshot.
- `EpistemosTests/BackgroundIndexingStatusTests.swift` — NEW Swift Testing
  suite covering the foundation reader's contract and the row's rendered
  copy.
- `docs/fusion/deliberation/r16_etl_pr3_background_indexing_status_shell_deliberation_2026_05_01.md`
  (this file).
- `docs/fusion/oversight/<TBD>_2026_05_01.md` — operator-authored oversight
  record after implementation.
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md` — append-only entry
  documenting the slice; no rewrite of prior entries.

## Forbidden Files And Subsystems

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `Epistemos/Engine/ShadowVaultBootstrapper.swift`
- `Epistemos/Engine/RustEtlFFIClient.swift` (deferred to PR3b)
- `Epistemos/Engine/AFMSidecarGenerator.swift` (deferred to PR3c)
- `epistemos-shadow/src/lib.rs` and any other `epistemos-shadow/**` path
- `agent_core/**` (queue/jobs/walker/hash/Cargo.toml/Cargo.lock — none of
  these are touched by this slice)
- Any `extern "C"`, `@_silgen_name`, UniFFI binding, or generated FFI header
  surface
- Xcode project files (`.xcodeproj/**`, `.xcworkspace/**`), `project.yml`,
  entitlements (`Epistemos*.entitlements`, `Epistemos*-Info.plist`)
- DerivedData, `.xcresult`, `build-rust/**`, generated `.rlib`/`.dylib`
  artefacts
- Existing pre-existing dirty paths NOT in the Allowed Files list — this
  PR does not normalize, revert, restage, rewrite, or `git add` any of
  them. The dirty tree at gate time is treated as unrelated upstream work
  and must remain untouched.
- No staging, committing, branching, stashing, force-push, or worktree merge.

## Implementation Plan

1. Create `Epistemos/State/BackgroundIndexingStatus.swift` defining:
   - `enum BackgroundIndexingState: Sendable, Equatable { case notWiredYet, idle, running, paused(reason: BackgroundIndexingPauseReason), stopped, error(message: String) }`
     — `running`, `paused`, `stopped`, `error` exist for shape parity with
     `03_EXECUTION_MAP.md:236` but only `notWiredYet` is reachable in this
     slice.
   - `enum BackgroundIndexingPauseReason: Sendable, Equatable { case battery, thermal, manual, memoryPressure }` — reserved; no callers in this slice.
   - `struct BackgroundIndexingStatusSnapshot: Sendable, Equatable { let state: BackgroundIndexingState; let queuedJobCount: Int; let processedFileCount: Int; let lastUpdate: Date? }` — `Date?` is `nil` in the foundation snapshot to make "no live data yet" explicit instead of stamping a misleading `Date.now`.
   - `protocol BackgroundIndexingStatusReader: Sendable { func currentSnapshot() -> BackgroundIndexingStatusSnapshot }`.
   - `struct FoundationBackgroundIndexingStatusReader: BackgroundIndexingStatusReader { ... }` returning `.notWiredYet`, zero counts, `nil` timestamp.
   - `extension BackgroundIndexingStatusReader where Self == FoundationBackgroundIndexingStatusReader { static var foundation: FoundationBackgroundIndexingStatusReader { .init() } }`.
2. Create `Epistemos/Views/Settings/BackgroundIndexingHealthRow.swift`:
   - `public struct BackgroundIndexingHealthRow: View` mirroring
     `EditorBundleHealthRow` shape (public init taking an optional
     `BackgroundIndexingStatusReader` defaulting to `.foundation`).
   - Renders: title row "Background indexing", subtitle copy "ETL crawler
     not wired yet — live counters land in R16 PR3b. (Shell only.)" when
     state is `.notWiredYet`.
   - Pre-codes the `running`/`paused(...)` / `stopped` / `error(...)` /
     `idle` cases with placeholder copy so the swap in PR3b is a single
     reader injection — no view-shape edits needed at that point.
   - SwiftUI `Preview` blocks per the `EditorBundleHealthRow` and
     `SearchFusionHealthRow` precedent (foundation reader + a
     Preview-only mock reader exercising each case for visual review).
3. Append exactly one line — `BackgroundIndexingHealthRow()` — after
   `SearchFusionHealthRow()` inside `SettingsView.swift:665–666`. No other
   edits to `SettingsView.swift`. The Diagnostics description text is NOT
   updated in this slice (the new row's own copy is self-explanatory) to
   keep the diff minimal.
4. Create `EpistemosTests/BackgroundIndexingStatusTests.swift` with Swift
   Testing (`@Suite` + `@Test` + `#expect`) covering at minimum:
   - `FoundationBackgroundIndexingStatusReader.currentSnapshot()` returns
     `state == .notWiredYet`, both counts `== 0`, `lastUpdate == nil`.
   - Snapshot equality is structural across two reads from the foundation
     reader (deterministic).
   - A test-only mock reader can drive each `BackgroundIndexingState` case
     and `BackgroundIndexingHealthRow` accepts injection (compile-time
     proof the shape supports PR3b's swap).
   - At least one test that verifies the row's rendered text for the
     `.notWiredYet` case includes the literal string "not wired yet" —
     prevents accidental copy regressions that would mask the foundation-
     stage state.
5. Append a single section to
   `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md` titled
   `## R16 ETL PR3a Background Indexing Status Shell` listing:
   touched files, deliberation gate path, oversight record path (TBD),
   exact build/test commands run, exact log file paths under `/tmp/`,
   protected diff name-only audit log path, and explicit confirmation
   that no protected, FFI, Rust, or pre-existing dirty file was edited.

## Acceptance

- `BackgroundIndexingHealthRow` renders inside Settings → Diagnostics
  immediately after `SearchFusionHealthRow`. Verified by reading
  `SettingsView.swift` and the new file's body in the same review.
- The default reader returns `.notWiredYet` and the row visibly states the
  foundation-stage condition. No "Idle" / "Running" / "Paused" copy is
  reachable from production code paths until PR3b's reader replacement.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination
  'platform=macOS' build` is green.
- New `BackgroundIndexingStatusTests` suite passes; no other Swift test
  regresses against the existing test floor.
- `cargo test --manifest-path agent_core/Cargo.toml etl --lib` and
  `cargo test --manifest-path agent_core/Cargo.toml` remain green and are
  re-run as a regression check (PR2's bar). Even though no Rust file is
  edited, the floor must hold.
- No protected file (`ProseEditor*`, `MetalGraphView`, `HologramController`,
  `graph-engine/**`) is touched. Verified by `git diff --name-only -- <protected paths>`
  returning empty.
- No new file outside the Allowed Files list is created. Verified by
  `git status --short --untracked-files=normal | rg -v '^( M|\?\?) (?:Epistemos/State/BackgroundIndexingStatus|Epistemos/Views/Settings/BackgroundIndexingHealthRow|Epistemos/Views/Settings/SettingsView|EpistemosTests/BackgroundIndexingStatusTests|docs/fusion/)'`
  containing only pre-existing dirty paths.

## Commands

Run from the repo root (`/Users/jojo/Downloads/Epistemos`).

Build + test floor:

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/BackgroundIndexingStatusTests test`
- `cargo test --manifest-path agent_core/Cargo.toml etl --lib`
- `cargo test --manifest-path agent_core/Cargo.toml`

Hygiene + protected-path audits:

- `git diff --check -- Epistemos/Views/Settings/SettingsView.swift Epistemos/Views/Settings/BackgroundIndexingHealthRow.swift Epistemos/State/BackgroundIndexingStatus.swift EpistemosTests/BackgroundIndexingStatusTests.swift docs/fusion`
- `git diff --name-only -- Epistemos/Views/Notes/ProseEditor*.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift graph-engine/`
  (must print nothing)
- `git diff --name-only -- agent_core/ epistemos-shadow/ epistemos-core/`
  (must print nothing)
- New-source anti-pattern scan on the three new Swift files for `try!`,
  force-unwrap `!` on optionals, `print(`, `repeatForever`,
  `DispatchQueue.main.asyncAfter`, `ObservableObject`, XCTest. None
  permitted.

## Stop Triggers

- The foundation status row cannot satisfy the `EditorBundleHealthRow` /
  `SearchFusionHealthRow` shape contract (e.g. SwiftUI requires environment
  injection unavailable inside the existing Diagnostics section).
- Adding the new row triggers a Swift 6.2 strict-concurrency error in
  `SettingsView` that requires structural changes outside the allowed-files
  list.
- A test would require touching `ShadowVaultBootstrapper.swift`,
  `RustEtlFFIClient.swift`, `AFMSidecarGenerator.swift`, or any forbidden
  path to compile.
- The Swift test floor regresses (any pre-existing test fails) — STOP and
  surface; do not silently skip.
- The Rust ETL test floor (`agent_core` etl + full lib) regresses despite
  no Rust file edits — STOP and surface; the regression is unrelated
  upstream churn that must be filed separately.
- Any protected file shows up in `git diff --name-only` against the
  protected-paths set, including from accidental editor save / formatter
  side effect.
- Any pre-existing dirty file outside the Allowed Files list is silently
  changed by this slice (e.g. an unintended re-format).
- Implementation pressure to add live FFI counters, real timestamps,
  `xattr` marking, ShadowVaultBootstrapper dispatch, AFM sidecar wiring,
  battery/thermal pause logic, or MAS bookmark enforcement inside this
  slice — those require their own gates.

## WRV

WRV is NOT claimed for the full R16 product item by this slice. This is the
first Swift-side foundation step inside the multi-PR R16 sequence. Per
`docs/MASTER_BUILD_PLAN.md §4`, R16 is not on the closed exempt list, so the
final WRV proof must land in the terminal R16 PR (PR3 final) once live ETL
counters, AFM sidecars, ShadowVaultBootstrapper dispatch, and battery/thermal
pause copy are wired and reachable.

The intermediate honest state for this slice:

- WIRED (foundation): `BackgroundIndexingHealthRow()` is referenced inside
  `SettingsView.swift`'s production `Section("Diagnostics")` block — not a
  test, not a preview. `grep -rn 'BackgroundIndexingHealthRow' Epistemos`
  must return at least one production-source caller in addition to the
  type definition.
- REACHABLE (foundation): from a fresh launch → `⌘,` (Settings) → General
  pane → "Diagnostics" section → the new row is visible alongside
  `EditorBundleHealthRow` and `SearchFusionHealthRow`. No env vars, no
  debug menus.
- VISIBLE (foundation, honest): the row's body text contains the literal
  phrase "not wired yet" and identifies the PR3b dependency. This is the
  no-silent-behavior surface for the foundation stage; it explicitly
  prevents claiming live ETL telemetry that does not exist yet.

The final R16 WRV claim — running/paused/stopped state with live file-count
deltas plus AFM sidecar visibility — happens in the terminal R16 PR after
PR3b/PR3c/PR3d.

## Next Gate

PR3b (FFI bridge): a separate deliberation gate must authorise touching
either `agent_core/src/etl/` (queue stats counters + extern "C" or UniFFI
exports) or `epistemos-shadow/src/lib.rs` (per the dossier's
`etl_enqueue_walk` / `etl_pause` / `etl_status` plan), plus
`Epistemos/Engine/RustEtlFFIClient.swift` (new). At that point the
`FoundationBackgroundIndexingStatusReader` default is replaced by a
Rust-backed reader and the row's foundation copy is removed.
