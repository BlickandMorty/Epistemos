# UI/UX Audit — EditorBundleHealthRow + BackgroundIndexingHealthRow

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 8)
- **Driver**: §4.C — closes the iter-3 loose end (the 590-LOC
  `EditorBundleHealthRow.swift` was only grep'd in iter 3, not
  deep-read).
- **Surface under audit**:
  - `Epistemos/Views/Settings/EditorBundleHealthRow.swift` (590 LOC) —
    contains **two** views: `EditorBundleHealthRow` (lines 1-118) and
    `BackgroundIndexingHealthRow` (lines 120-553).
- **Verification mode**: Static. Env constraints from iter 1 unchanged.

## EditorBundleHealthRow (lines 1-118)

Two sub-rows surfaced:

1. **"Editor bundle"** — probes `Bundle.main.url(forResource: "editor",
   withExtension: "html", subdirectory: "Editor")`. Mirrors the exact
   path `EpdocEditorURLSchemeHandler` uses at WKWebView load, so a
   false here predicts a runtime asset-not-found at every doc open
   (comment at line 83-86 — honest documentation).
2. **"Halo backend"** — reads
   `UserDefaults.standard.bool(forKey: "epistemos.halo.isOpen")` +
   `string(forKey: "epistemos.halo.openPath")`. Recorder methods
   `recordHaloOpened(at:)` / `recordHaloClosed()` (lines 109-117) are
   called from the bootstrap so this view stays dependency-light.

**Strengths preserved**:

- Per-row design rule **NO rebuild button, NO auto-install** is
  explicit in the header doc (lines 10-15). The .app ships the bundle
  pre-compiled — read-only diagnostic discipline matches CLAUDE.md's
  W7.17 doctrine.
- Lookup mirrors the runtime path, so this isn't a phantom indicator.
- Recorder pattern decouples the diagnostic from a direct Rust /
  shadow-backend dependency.

**Verdict**: clean. Refresh-on-.onAppear is sufficient for launch-time
state. No findings unique to this row.

## BackgroundIndexingHealthRow (lines 120-553)

Surface for the Shadow / vault-indexing pipeline. Phase enum
(`.unavailable .scanning .indexing .paused .complete .failed`),
Snapshot struct with vault path + shadow path + domain + enqueued/total
+ ETL queue stats (active/pending/running/done/failed/killed/completed).

**Strengths preserved**:

- **Phase-aware detail strings**. `.complete` explicitly tells the
  user (lines 440-459): *"external edits since launch are not
  auto-indexed."* This is the RCA-P2-014 closure — honest disclosure
  of the deferred FSEvents wiring (W8.7.b). ✅ CLAUDE.md honest
  capability gating.
- **`isHealthy` flag derived** rather than stored. Single source of
  truth.
- **5 explicit pause reasons** as enum (`BackgroundIndexingPauseReason`
  at lines 122-128: battery / thermal / lowPower / memoryPressure /
  backgroundPolicy). Each maps to a human-readable string.
- **ETL queue detail** merged into the row text with a `|` separator
  (lines 486-506).
- **`Keys.all` + `Keys.etlAll`** arrays let `reset(defaults:)` clear
  the entire diagnostic without per-key drift.
- **3 #Preview variants** (DEBUG-only) for "both ready", "both
  missing", "indexing".
- `Snapshot` is `Equatable + Sendable`, `Phase` is `Sendable`.

## Findings

### P0 — blockers

None.

### P1 — must-fix

None.

### P2 — defer

**P2-1 — 1-second polling Task vs. notification-driven refresh.**

Lines 151-156:

```swift
.task {
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(refreshInterval))
        refresh()
    }
}
```

When the user opens Settings → Diagnostics and leaves it visible,
this fires `Self.snapshot()` (which reads ~18 UserDefaults keys)
**every second**, indefinitely. CPU cost is tiny but constant.

Sibling rows (ShadowSearchHealthRow + AnswerPacketHealthRow) use
`NotificationCenter` subscriptions to refresh **only on real state
changes**. This row could do the same — every recorder method
(`recordStarted`, `recordProgress`, etc.) could post
`Notification.Name("epistemos.backgroundIndexing.didChange")` after
its `write(...)`, and the view could `.onReceive(...)` instead of
polling.

- Not P1 because the polling is light and the row is only visible
  while Settings is on-screen.
- Consistency P2: mismatched freshness model between sibling rows.

**P2-2 — Inherits the iter-3 a11y + color-only-state P2s.**

The `row(label:symbol:ok:detail:)` helper at lines 163-187 is
**verbatim identical** to the one in `ShadowSearchHealthRow.swift`,
including:
- No `.accessibilityElement(children: .combine)`
- Color-only state via `AnyShapeStyle(Color.green/.red)` ternary
- No textual `accessibilityValue` for OK/Fail

The "Diagnostics accessibility consistency" iter from iter 3's
carry-overs should standardize this row helper into a shared
modifier or component.

**P2-3 — `AnyShapeStyle(Color.green/.red)` boilerplate.**

Same as iter 3 P2-4: `foregroundStyle` accepts `Color` directly;
`AnyShapeStyle` wrapper is only needed when the two branches have
different concrete `ShapeStyle` types. Lines 73, 131, 181 all reuse
the same boilerplate.

### P3 — observations

- **P3-1** — Two views in one file: `EditorBundleHealthRow` (top) and
  `BackgroundIndexingHealthRow` (bottom). The filename misleads about
  the larger view. A future split into
  `BackgroundIndexingHealthRow.swift` would clarify ownership but
  isn't urgent.
- **P3-2** — `progressDetail` returns `"Indexing vault: 12/-1"` when
  `total < 0` per line 478-484 — wait, line 480-482 actually does
  show "scanning…" instead. Good.

## Action taken this iter

- Filed this audit doc; closes the iter-3 deferred deep-read.
- No code edits.

## Carry-overs

- P2 items above feed into a future "Diagnostics accessibility +
  freshness consistency" iter that batches:
  - Standardized row helper with `.accessibilityElement(children:
    .combine)` + `.accessibilityValue` for state.
  - Notification-driven refresh replacing the 1Hz polling task.
  - `AnyShapeStyle` cleanup across all four sibling rows.
