# Goose Phase 1 — Native Frame Hardening Log (2026-06-29)

> 🔴 **SUPERSEDED 2026-07-02 (OpenChamber pivot) — DO NOT BUILD FROM THIS.** Hardening log for the DEAD native-frame-around-reskinned-Goose-WebView approach. The agent surface is OpenChamber (Pro) / June+goose-in-process (MAS); goose = one engine. Historical reference only. Canon: memory `project_ui_base_pivot_openchamber_2026_07_02`.

Phase 1 = HYBRID APPKIT, **native FRAME only** (window + nav rail + permission/elicitation
pop-ups) wrapping Goose's reskinned WebView. Every Goose feature stays in the WebView (owner
charter 2026-06-27). This log records the thermonuclear hardening pass over the new frame.

## Scope reviewed
`Epistemos/Agent/AgentSurface.swift`, `AgentNavigationRailView.swift`, `AgentSurfaceRootView.swift`,
`AgentSurfaceWindowController.swift`, plus the `route` delta added to
`Epistemos/Goose/GooseWebSurfaceView.swift` (rail → embedded WebView navigation).

## Thermonuclear review result
**0 HIGH / 3 MED / 2 LOW.** No orphaned `goose serve`, no second spawn, no false-green honesty
hole. The three explicit lifecycle questions all PASS (independently re-verified):
1. Window close → no orphan (`onDisappear` → `supervisor.stop()` + `gooseUIServer.stop()` +
   ACP disconnect; app-exit SIGTERM cleanup is the backstop).
2. Double-window (⌘3 + ⌘⇧A) → honest occupied-port fail, **no second `goose serve`** (NOT a
   golden-rule violation).
3. Existing ⌘3 Goose window → fully unaffected by the additive `route` param (default `/?`).

All nine rail route strings verified REAL against the Goose SPA (`useNavigationItems.ts`,
`App.tsx`): `/?`, `/sessions`, `/settings`, `/configure-providers`, `/skills`, `/recipes`,
`/extensions`, `/schedules`, `/apps`. No dead controls.

## Findings + disposition

### FIXED — MED-1: post-provider-sync reload snapped WebView back to hub
`GooseWebSurfaceView.reloadSurfaceAfterProviderSync` hardcoded `route: "/?"`. Once the rail drives
`route`, this guaranteed a rail/content desync on first run (rail shows Sessions, content jumps to
hub). **Fix:** reload to the live current route.

### FIXED — MED-2: rail clicks during startup were dropped
The initial-load route was read from a `self` captured at view-appear (`route == "/?"`); the
bounded poll path (stale `self`) frequently won the `drivenConnectionKey` race and loaded `/?`,
discarding a mid-startup rail selection (`onChange` no-ops until the UI server is running, and
nothing replayed it). **Fix:** introduced a single `@State` live source-of-truth, `activeRoute`.
`onChange(of: route)` writes it; the load chain (`loadGooseUIWhenReady`) and the post-sync reload
read it at the actual load instant. Because `@State` storage is shared across struct re-creations,
even the stale captured `self` reads the live value — startup clicks (including ones made while the
UI server is still coming up) are now honored.

### DEFERRED — MED-3: two windows on the same port → second is non-functional (by design)
With ⌘3 already serving on 3284, the ⌘⇧A window's supervisor sees `/health` answering, waits the 2s
`portReleaseGrace`, then goes `.failed(occupiedPortMessage)` — it never spawns a second `goose serve`
and never orphans anything (honest placeholder shown). This is a UX limitation, not a correctness or
golden-rule bug. Proper fix = a shared supervisor singleton across both surfaces (invasive: touches
both window controllers + the per-view `@State supervisor` ownership; app-build-only validation).
Transitional anyway — the native frame is intended to supersede the plain ⌘3 window. **Defer** until
the shared-supervisor refactor is scheduled; until then the two windows are mutually exclusive
(second recovers via Restart once the first closes — see LOW-2).

### DEFERRED — LOW-1: controller relies on `onDisappear` for teardown (no direct `stop()`)
`AgentSurfaceWindowController.handleClose()` mirrors the proven `GooseSurfaceWindowController`
pattern; `onDisappear` fires on host-view teardown and the app-exit SIGTERM net is the backstop. A
belt-and-suspenders `supervisor.stop()` from the controller would need new plumbing (the supervisor
is `@State` inside the view, not reachable from the controller). Already covered. **Defer.**

### DEFERRED — LOW-2: a `.failed` (occupied-port) window does not auto-recover when the port frees
Recovery is manual via the existing Restart button (`canRestartSurface` is true for `.failed`).
Honest and recoverable; auto-recovery would need port-polling while failed. Low value. **Defer.**

## Build validation
App-target build on the isolated DerivedData (`~/.epistemos-isoloop-dd`) — see commit. (Shared test
target remains blocked by the concurrent Plan-3 `ArxivPlan3Tests`; validated via app build + the
independent lifecycle re-verification above.)
