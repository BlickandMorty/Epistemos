# SS-GE — Graph editability (both graphs) + raw-thoughts visibility + graph appearance toggles (2026-06-20)

Owner: *"Like the other graph view (the mini overlay graph), I want to be able to EDIT the Epdoc in it. For the mini-chat
and the home-embedded chat there are surfaces that are NOT editable in the graph and open a UTILITY instead — I want to
edit ALL surfaces in BOTH graphs, not just home, and make sure both the home graph AND the embedded one can edit all the
other surfaces. Also raw thoughts — I don't see raw thoughts at all in my vault, not sure if that's still a thing. And the
tags + all the togglable things on the graph appearance setting — make sure they WORK; several I don't see at all. Add to
plan somewhere, non-invasive, but I really want them all working + the surfaces editable in the graphs."* Code-grounded.
NON-INVASIVE; TRACKED (owner: "add to plan somewhere"); cross-ref SS-HGT (graph tunnel), SS-CLEAN (surface-parity + dead-flag).

## (A) Edit ALL surfaces inline in BOTH graphs (home + embedded/mini overlay), don't open a "utility"
- Today a graph surface like **Epdoc opens a separate document window** instead of editing inline:
  `Views/Graph/HologramSearchSidebar.swift:1177` → `EpdocDocumentOpening.openDocument(...)` (the "utility" the owner means).
- The graph surfaces: `Views/Graph/GraphWorkspaceContainer.swift` (routes `.note`/`.epdoc`/`.htmlWorkspace`/etc.),
  `GraphNotePage.swift`, `Views/Home/HomeGraphEmbeddedView.swift` (home-embedded), the mini overlay graph.
- **Goal:** every surface (note/Epdoc/HTML/code) is editable IN-PLACE inside BOTH the home graph tunnel AND the embedded/
  mini overlay graph — not bounced to a detached document window. Note (SS-2S/SS-EM): the in-graph Epdoc editor must use the
  same md-first editor as elsewhere (one editor, not a divergent in-graph clone — SS-CLEAN). Verify which surfaces currently
  fall through to `openDocument`/utility vs render an inline editor, and make them all inline-editable in both graphs.
  Honest gating: a surface that genuinely can't edit inline yet shows an honest affordance, not a silent no-op.

## (B) Raw thoughts not visible in the vault — verify it's still wired/surfaced
- The feature EXISTS in code: `State/RawThoughtsState.swift` (+ `ArtifactRoute`/`ArtifactKind`/`GraphTypes` references).
- Owner sees NO raw thoughts in the vault → likely built-but-not-surfaced (a hidden-rule/surface-parity miss like SS-VIS):
  raw thoughts may not be WRITTEN to the vault, or not SHOWN in the vault/graph UI, or the writer points at a dir the UI
  doesn't read. **Verify:** is `RawThoughtsState` actually persisting raw thoughts to the vault, and is there a surface that
  displays them? If the feature is dead/orphaned, either wire it to be visible or honestly retire it (don't leave a
  half-feature). Cross-ref SS-CLEAN dead-flag/orphan scan.

## (C) Graph appearance toggles (tags + others) — make them actually WORK
- Controls live in `Views/Graph/GraphFloatingControls.swift` + graph appearance entries in `SettingsView.swift` +
  `MetalGraphView.swift`/`HologramOverlay.swift` (the renderer).
- Owner: several toggles (tags etc.) "I don't see at all" → likely **dead toggles** — a toggle flips an `@AppStorage`/state
  flag that the Metal graph renderer / overlay never reads, so toggling does nothing (green-without-witness muddiness).
- **Verify each graph-appearance toggle end-to-end:** the flag it sets is actually CONSUMED by `MetalGraphView`/`HologramOverlay`
  rendering (tags/labels shown, node styling, etc.). Wire the dead ones to real rendering, or remove toggles for features
  that don't exist. Behavior test: toggling each appearance flag changes what the graph renders (or honest "not supported").

## Plan (NON-INVASIVE, tracked, normal order)
(A) in-graph inline editing for all surfaces in home + embedded graphs (reuse the one md-first Epdoc editor; no detached
utility) → (B) verify/wire raw-thoughts visibility (or honestly retire) → (C) audit every graph-appearance toggle is wired
to the renderer (kill dead toggles). Each test-backed; one shared editor/seam (SS-CLEAN). Cross-ref SS-HGT, SS-2S/SS-EM
(editor), SS-VIS (surface-parity), SS-SH (panel honesty). The toggle/raw-thoughts items are textbook SS-CLEAN dead-flag /
surface-parity catches — fold the audit into the Cleanliness Gate.
