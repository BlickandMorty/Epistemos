# UI/UX Audit — Halo panel + Provenance Console

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 4)
- **Driver**: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.C
  (feature #10: "Halo / shadow search panel · Provenance Console
  (already shipped)").
- **Surfaces under audit**:
  - `Epistemos/Views/Halo/HaloButton.swift` (66 LOC)
  - `Epistemos/Views/Halo/ShadowPanel.swift` (231 LOC) — `NSPanel` host
    + positioning controller
  - `Epistemos/Views/Halo/ShadowPanelContent.swift` (351 LOC) — SwiftUI
    panel content
  - `Epistemos/Views/Settings/ProvenanceConsoleView.swift` (39 LOC)
- **Verification mode**: Static review. iter-1 env constraints
  unchanged (no computer-use, pre-existing main-broken
  `ContradictionFfi` typealias).

## Strengths (preserve)

**HaloButton** is a model of the §4.C step-5 accessibility bar:

- `.accessibilityLabel("Show contextual recall")` ✅
- `.accessibilityHint("Reveals related notes and chats... Keyboard
  shortcut: Command-Shift-H.")` ✅
- `.help("Show related notes & chats (⌘⇧H)")` tooltip ✅
- `.keyboardShortcut("h", modifiers: [.command, .shift])` — ⌘⇧H is
  grep-verified unbound elsewhere ✅
- `.allowsHitTesting(visible)` so the hidden state can't catch clicks ✅
- Spring animation `.spring(duration: 0.18, bounce: 0.2)` — system
  honors `Reduce Motion` automatically via this API ✅
- Focus-aware muting via `EpistemosFocusKeys.muteHaloRecallChip` ✅

**ShadowPanel** is correct AppKit window discipline:

- `nonactivatingPanel` style — clicking does **not** steal main from
  the editor (`ShadowPanel.swift:31, 51`).
- `canBecomeMain = false` (permanent), `canBecomeKey = true` so inline
  text editors inside the panel still receive keyboard input
  (lines 50-51).
- `panelOrigin(forAnchorRect:panelSize:in:)` is a **pure function**
  (lines 156-189) — trailing-edge placement, leading-edge flip on
  overflow, horizontal + vertical clamp — fully testable without
  spinning up NSPanel.
- Lazy panel creation + reuse so user-resized size persists
  (lines 91-140).
- Outside-click observer attached on every show, detached on hide and
  on dismiss (lines 210-230). No leaked observers.
- Default size 360×480 matches V1 budget cap (blur ≤ 2 ms/frame).

**ShadowPanelContent** SwiftUI hygiene:

- `.onExitCommand { ... }` — Escape dismisses the panel without losing
  any in-flight inline edits (line 77-80).
- `.accessibilityElement(children: .contain)` +
  `.accessibilityLabel("Contextual shadows")` (line 81-82).
- Graph-projection ribbon has its own
  `.accessibilityLabel(graphProjectionAccessibilityLabel(for: report))`
  (line 117) — explicit, not relying on the auto-merged Image+Text
  fallback.
- `.background(.ultraThinMaterial)` matches the macOS HIG floating
  surface treatment.
- Closure-based handler surface (`ShadowPanelHandlers`) makes the
  panel pure-presentation — no retrieval or mutation runs inside the
  view tree.

**ProvenanceConsoleView** read-only discipline:

- Snapshot captured in `init()` and on `.onAppear { refresh() }`
  (lines 7-23). No live polling.
- `ProvenanceConsoleProjectionService` is the only data source; the
  view never reaches into Rust/agent_core directly.
- Routes through `GenUIDispatcher.shared.render(payload)` so a single
  generic UI renderer handles every provenance plane (RunEventLog,
  MutationEnvelope, ClaimLedger retraction, AgentEvent, GraphEvent).
- Capped at 40 entries (`snapshot(limit: 40)`) so opening Settings
  doesn't render an unbounded scroll.

## Findings

### P0 — blockers

None.

### P1 — must-fix

None. The shipped surfaces meet driver step 1-7 substantively.

### P2 — defer

**P2-1 — Provenance Console has no live refresh.**

`ProvenanceConsoleView` reads a snapshot once at `init()` and again
at `.onAppear { refresh() }`. New provenance events emitted while
Settings is open do **not** appear. The user must close + reopen
Settings to see new entries. The 40-entry cap is reasonable, but the
freshness model is not honest about its staleness.

- Fix sketch: subscribe to the projection service's notification (if
  one exists) or poll via `TimelineView(.periodic(2))`. Two seconds
  is plenty given the Diagnostics-tier audience.
- Not P1 because the audience for the Provenance Console is power
  users debugging, who can refresh; not on-path for the §4.C audit
  gates.

**P2-2 — Provenance Console pagination beyond 40.**

`snapshot(limit: 40)` cuts the ledger silently. No "show older"
control. For a long debugging session, valuable retractions get
chopped.

- Fix sketch: add "Load 40 more" button at the foot of the scroll
  view.

**P2-3 — Halo panel resize persistence is per-controller, not
per-launch.**

`ShadowPanelController` lazily creates the panel on first `show(...)`
and reuses the same `NSPanel` for the lifetime of the controller, so
the user-resized size persists across opens **within** the same
session. After app relaunch, the controller is fresh and the panel
reverts to 360×480. Minor UX nit.

- Fix sketch: persist the panel's final frame to `@AppStorage` on
  hide and restore on lazy-create. Single-key change.

### P3 — observations

- **P3-1 — `panelOrigin` step 3 commentary is slightly off.**
  The comment at line 171-173 says "we err toward the screen's right
  edge so the leading characters of the panel are visible." Reading
  the code, the clamp at 174-178 actually pins the panel inside the
  screen — at `screen.minX` if `x < screen.minX`, otherwise at
  `screen.maxX - panelSize.width`. Both branches keep the **full**
  panel visible. The comment seems to suggest clipping, which isn't
  what the code does.

- **P3-2 — Multi-screen behavior.**
  `ShadowPanel.swift:128-131` picks the screen whose frame intersects
  `anchorRect`, falling back to `NSScreen.main`, falling back to a
  hardcoded 1280×800. Reasonable fallback chain. Untested for the
  case where the editor straddles two screens — first-match by
  iteration order may produce a non-obvious placement.

- **P3-3 — `ProvenanceConsoleView` could expose a hash-of-current-state
  in the header for log-friendly screenshots.** Power users debugging
  off the console often need a stable identifier for the snapshot
  they're looking at. Not urgent.

## Action taken this iter

- Filed this audit doc.
- **No code edits this iter.** No P0/P1 found. P2/P3 items are minor
  freshness/persistence ergonomics; defer to follow-up.

## Carry-overs

- P2/P3 above.
- Audit backlog still gated on landings from other terminals: T4 →
  F-VaultRecall-50, T2 → Agent UI / per-model badges, T3 → UAS-ACS
  visualizer, T5 → EML-IR diagnostic row, T1 → Tri-Fusion mutation
  surface.
