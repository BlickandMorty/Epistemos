# ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING) ═══
# LICENSING CLOSED (2026-07-06 research): Rive RUNTIMES (rive-ios + @rive-app/canvas) are MIT,
# free for commercial apps (rive.app/runtimes; github.com/rive-app/rive-runtime LICENSE). The paid
# part is only the AUTHORING editor/export tier — Cadet $9/mo unlocks unlimited production exports
# (rive.app/pricing). The D4b Rive verdict STANDS at trivial cost; the SVG fallback is not needed
# for licensing reasons. rive-ios is not yet a dependency: add via SPM to the Epistemos target ONLY.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
# companion.riv — the single mascot artifact (both render paths)

EPI-RP-05-KINDRED · D4b render verdict: **Rive, one `.riv`, both paths.**

This is a placeholder for the binary `companion.riv`. The verdict from the research is that
ONE Rive file renders on both the native SwiftUI path (`rive-ios` / `RiveViewModel`) and the
WebView path (`@rive-app/canvas`), guaranteeing the creature is visually identical — and
killing the demo-grade artifacts (seams, sub-pixel misalignment, transform-origin drift,
HiDPI jaggies) that a layered-PNG compositor produces, because Rive is a vector rig with
defined anchors and draw order.

## State machine input contract (must match CompanionAnimationState.riveInput)
Booleans:  isIdle · isThinking · isReading · isWriting · isWorking · needsApproval · hasError
Trigger:   trigDone

Every input is driven ONLY by a real `RunState` from `agent_core` (skin over real state).
No input may be set without a backing run event.

## Artboard variants
`bodyKind` (from CompanionModel) selects the artboard/variant so companions look distinct
while sharing one rig skeleton. Accessories (hats/eyes/held-items) are layers with fixed
anchors set IN the Rive editor, never composited at runtime.

## Open question (do not ship until resolved)
Confirm Rive runtime licensing/pricing for a shipped macOS app, and whether the authoring
editor tier is required. If unacceptable, fall back to a layered-SVG + SF Symbols composite
(native) / inline SVG (WebView) — more artifact-prone, more code. See KINDRED plan doc.
