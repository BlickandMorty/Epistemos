# Plan 3 — Obscura Tier 1 in-app browser (clone-ready code, Pass 4)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §2`. The LIGHT, MAS-safe slice: a real browser tab you drive like
> Safari. Standalone — no Rust, no FFI, no agent (Tier 2/3 are separate, Pro). Turns "I can't even see it" into a
> visible, usable browser. `[VERIFIED-CODE]`/`[INFERRED]` tagged.

## Verified patterns reused
- WKWebView host + `WKWebsiteDataStore.nonPersistent()` (isolated cookies) + custom nav policy: `GooseWebSurfaceView.swift:436-462,584-603`
  + `EpdocEditorChromeView.swift:592-631,657-665`. Idle hooks `EpdocWebViewShared.notifyWebViewCreated/Dismantled`
  (`:35-50`) feed the global memory-pressure handler (`EpistemosApp.swift:600-606`).
- Window summon: `UtilityWindowManager` + `UtilityPanel` (`:96-146,287-354`); shortcuts in `EpistemosCommands`
  (`EpistemosApp.swift:1450-1556`).

## New file `Epistemos/Views/Obscura/ObscuraBrowserView.swift`
- **`ObscuraURLGuard`** — http/https-only `allowedSchemes`; `resolve(raw, searchTemplate)` promotes bare hosts to
  `https://`, falls non-URL text through to a DuckDuckGo search; `allows(url)` gates EVERY navigation.
- **`@Observable ObscuraTab`** — chrome state (address, currentURL, title, canGoBack/Forward, isLoading, progress,
  lastError) + command closures (navigate/back/forward/reload/stop); `submitAddress()` honest-errors on non-web schemes.
- **`ObscuraBrowserView`** — SwiftUI chrome (back/fwd, reload↔stop, lock-icon address field, go, progress bar, error
  bar, ⓘ limits hint) over the WKWebView.
- **`ObscuraWebRepresentable` (NSViewRepresentable)** — `WKWebView` with `nonPersistent()` store + `allowsContentJavaScript`
  + back-forward gestures + magnification; **KVO** drives chrome (estimatedProgress/isLoading/title/url/canGoBack/Forward);
  `decidePolicyFor` re-checks `ObscuraURLGuard.allows` on every nav (non-web schemes cancelled); `target=_blank` opens in
  the same tab (Tier 1 = single tab). **`dismantleNSView` + `Coordinator.shutdown()`** invalidate KVO, nil the command
  closures (breaks WebView↔tab retain), notify the idle pool → no leak.

## Summon — `UtilityPanel.browser` + ⌘⇧B
Add `.browser` to `UtilityPanel` (title "Browser", icon "safari", defaultSize 1024×720, free resize), route it in
`contentView(for:bootstrap:)` (`:358`) → `ObscuraBrowserView(theme:)`, reuse `applyOmegaChrome`. Add to `EpistemosCommands`
(`CommandGroup(after:.sidebar)`): `Button("Browser"){ UtilityWindowManager.shared.show(.browser) }.keyboardShortcut("b", [.command,.shift])`.
Window is cached (`isReleasedWhenClosed=false`) → re-summon reuses the same WebView (one persistent WebView, not N).

## Honest limits (baked into the ⓘ hint UI)
On-device WebKit (like Safari) · cookies/cache isolated from Safari + cleared on close · **no Safari extensions** · some
**FairPlay-DRM premium video may not play**. (Direct consequences of WKWebView + `nonPersistent()`.)

## Forward seam (note only — do NOT build here)
The same `WKWebView` is exactly what the `NotConfigured` `WebKitBrowserEngine` (`browser_engine/mod.rs:273-317`) needs
for Tier 2 (agent read/extract) — a future `ObscuraWebKitDriver.swift` (separate file, Pro/agent-gated) registers it in
a Swift pool keyed by `SessionId` and implements navigate/snapshot/click/type via `evaluateJavaScript`+AX. Keep
`ObscuraBrowserView`/`ObscuraTab` free of any agent/FFI import so Tier 1 ships MAS-clean and Tier 2/3 are additive. The
Rust-native V8 `ObscuraBrowserEngine` (`:319-364`) is Tier 3 (stealth/automation) — out of scope.

## Files touched
NEW `ObscuraBrowserView.swift`; EDIT `UtilityWindowManager.swift` (`.browser` in `UtilityPanel`/`apply`/`contentView`)
+ `EpistemosApp.swift` (⌘⇧B button). All reuse verified patterns; MAS-safe, on-device. `[INFERRED]` spot-check
`EpistemosTheme`/`GooseSurfaceStyle` member names at build time (they match what `GooseWebSurfaceView.swift` uses).
