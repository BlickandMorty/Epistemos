# Plan 3 — Browser Tier 1 in-app browser (shipped code, Pass 5)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §2`. The LIGHT, MAS-safe slice: a real browser tab you drive like
> Safari. Standalone — no Rust, no FFI, no agent (Tier 2/3 are separate, Pro). Turns "I can't even see it" into a
> visible, usable browser. `[VERIFIED-CODE]` tagged.

## Current verified implementation
- `Epistemos/Views/Browser/BrowserView.swift` is the Tier-1 Browser surface.
- `BrowserURLGuard` resolves typed URLs/searches and allows only `http`/`https` navigation.
- `BrowserTab` owns chrome state and command closures; `BrowserView` renders the SwiftUI toolbar.
- `BrowserWebView` hosts `WKWebView` with `WKWebsiteDataStore.nonPersistent()`, JavaScript enabled, back/forward
  gestures, magnification, KVO-driven chrome state, and same-tab `target=_blank` handling.
- `BrowserWebView.dismantleNSView` stops loading, nils delegates, invalidates KVO through `Coordinator.shutdown()`,
  clears tab command closures, and notifies `EpdocWebViewShared.notifyWebViewDismantled()`.
- `UtilityPanel.browser` opens `BrowserView()`, defaults to `1024x720`, and is available from the app Browser command
  and the Plan 3 landing Browser button.

## Browser file contract [DELIVERED]
- **`BrowserURLGuard`** — `allowedSchemes = ["http", "https"]`; `resolve(raw, searchTemplate)` promotes bare hosts to
  `https://`, turns non-URL text into DuckDuckGo search, and rejects explicit `file:`, `data:`, `javascript:`,
  `mailto:`, and `tel:` schemes. Raw address/search input is length-bounded before trimming or URL resolution.
- **`@Observable BrowserTab`** — address/current URL/title/back-forward/loading/progress/error state plus command
  closures for navigation. `submitAddress()` and `navigate(to:)` set honest errors on rejected navigation. Page title,
  displayed address, and WebKit error text are capped before untrusted trimming/counting or entering SwiftUI state, with
  ellipsis kept inside the configured display caps.
- **`BrowserView`** — SwiftUI chrome with a registry-backed Browser brand mark, back/forward, reload/stop, lock/globe
  address field, go button, progress bar, error bar, and limits popover. Toolbar actions use shared
  `ToolbarCapsuleButton` chrome rather than local plain/borderless button styling, and the address field uses flat
  theme-token fill without a stroke outline.
- **`BrowserWebView` (NSViewRepresentable)** — `WKWebView` with `nonPersistent()` store, JavaScript enabled, KVO state
  observation, strict `BrowserURLGuard.allows` navigation-action and navigation-response policy, single-tab
  `target=_blank` where new-window navigations are reloaded from a sanitized URL-only request, native
  `WKContentRuleList` tracker/ad blocking with host-anchored request URL filters (not page-domain `if-domain` gating),
  and teardown that breaks retained WebView/tab closures.

## Summon — `UtilityPanel.browser` + ⌘⇧B [DELIVERED]
`.browser` is in `UtilityPanel` (title "Browser", icon "safari", defaultSize 1024×720, free resize), routes to
`BrowserView()`, and reuses `applyOmegaChrome`. `EpistemosCommands` includes
`Button("Browser"){ UtilityWindowManager.shared.show(.browser) }.keyboardShortcut("b", [.command,.shift])`.
Window is cached (`isReleasedWhenClosed=false`) → re-summon reuses the same WebView (one persistent WebView, not N).

## Honest limits (baked into the ⓘ hint UI)
On-device WebKit (like Safari) · cookies/cache isolated from Safari + cleared on close · **no Safari extensions** · some
**FairPlay-DRM premium video may not play**. (Direct consequences of WKWebView + `nonPersistent()`.)

## Forward seam (note only — do NOT build here)
The `WebKitBrowserEngine` Rust stub stays `NotConfigured`. Do not make this human-driven Browser tab agent-driven.
Pro automation is the separate browser-use Chromium lane; it does not and must not drive this native WKWebView tab.
Keep `BrowserView`/`BrowserTab` free of any Goose, agent, Rust FFI, Python, subprocess, Playwright, or Chromium import
so Tier 1 ships MAS-clean.

## Shipped files
`Epistemos/Views/Browser/BrowserView.swift`; `UtilityWindowManager.swift` (`.browser` in
`UtilityPanel`/`apply`/`contentView`) + `EpistemosApp.swift` (⌘⇧B button) + `LandingFeatureButton.browser`. All reuse
verified patterns; MAS-safe, on-device, human-driven, and separate from the Pro browser-use robot.
