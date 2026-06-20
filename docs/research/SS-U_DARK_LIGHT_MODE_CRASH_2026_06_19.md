# SS-U — Dark/light mode toggle crashes the app (2026-06-19)

Read-only research (subagent), code-grounded. Feeds the DARK/LIGHT-MODE-CRASH ledger item. Owner: *"turning to
dark and light mode often crashes the app, maybe because I have lots of surfaces that don't have robust
hardening or a combo."*

## Headline
**Most likely root = forced WKWebView teardown-and-recreation on every appearance switch in the HTML
Workspace.** `HTMLWorkspacePreviewView` carries an explicit `.id(previewRenderIdentity)` whose identity string
folds in the theme hash (`HTMLWorkspaceEditorView.swift:340` + `:617`), and `.onChange(of: colorScheme)`
(`:33-35`) re-stamps `previewPackage`. Each light/dark flip therefore **destroys the live WKWebView
(`dismantleNSView`) and builds a new one (`makeNSView`) synchronously inside a SwiftUI re-render** — the exact
window where a half-detached `WKScriptMessageHandler`/nav-delegate or in-flight `loadHTMLString` can fault. The
CLAUDE.md "shared `WKProcessPool`/`resetPoolIfIdle()` swapped while bound" hypothesis is **STALE** — that code
no longer exists; not the vector.

## Appearance/theme handling map
- System source of truth `Theme/SystemAppearanceState.swift:4` (`isDark()` reads `AppleInterfaceStyle`).
- Observer (notification, not KVO) `App/SystemAppearanceObserver.swift:7-55` — `activeSpaceDidChange` +
  `AppleInterfaceThemeChangedNotification`, coalesced via `lastNotifiedIsDark` (`:52`), callbacks hop to
  `@MainActor` via `Task` (`:24,33`) — no `.sync`.
- Wiring `App/RootView.swift:441-443` sets `ui.isSystemDark` (no-op guarded); observer `@State` `:196`.
- **No system `.preferredColorScheme` override** — `UIState.preferredColorScheme` returns nil (`UIState.swift
  :296`, Pitfall #13 doc'd `SystemAppearanceObserver.swift:5`); `.preferredColorScheme` only on detached
  popovers (`RootView.swift:501,517`, `UtilityWindowManager.swift:392`).
- KVO `effectiveAppearance` only `Graph/HologramOverlay.swift:935,2276` → `syncTheme()`.
- `.onChange(of: colorScheme)` only `HTMLWorkspaceEditorView.swift:33`.
- Theme color resolution `Theme/EpistemosTheme.swift:88 nsColor`, `:306 resolved`, `:343
  resolvedForAppearance`; pixel/preset override via `ResolvedTheme` (`:100-171`); safe fallback (`:92-95`).
- Web theme injection `EpdocEditorChromeView.swift:536 applyScript`, idempotent `:753-755`.

## Candidate crash roots (ranked)
1. **[VERIFIED-from-code] HTML Workspace preview WebView destroyed+rebuilt on every toggle** —
   `HTMLWorkspaceEditorView.swift:340` `.id(previewRenderIdentity)` + `:617` identity includes
   `workspaceThemeIdentity.hashValue` + `:33-35` `onChange(colorScheme)` re-stamps. *Why:* appearance flip
   changes SwiftUI identity → forced `dismantleNSView`→`makeNSView` of the WKWebView (`HTMLWorkspacePreviewView
   .swift:25,57`) mid-render; teardown of a WKWebView with an attached script-message handler / in-flight
   `loadHTMLString` during re-identity is a known WebKit fault window. Fires **every toggle** while the
   workspace preview is open → matches "often crashes."
2. **[VERIFIED-from-code] `.id` recreation racing message-handler attach** — `HTMLWorkspacePreviewView.swift
   :30-36` adds a `userContentController` handler in `makeNSView`; on recreation the old coordinator's `detach`
   (`:58`) and the new handler add interleave with `syncSafeAPIHandler` (`:53`) → double add/remove of a named
   handler on a freshly-swapped WKWebView can trap.
3. **[VERIFIED, lower] HologramOverlay KVO `effectiveAppearance`→`syncTheme()` touching Metal** —
   `HologramOverlay.swift:935/2276`→`syncTheme()` (`:1853-1869`)→`metalView?.setLightMode(...)` (`:1862`).
   Optional-chaining makes it largely safe, but `setLightMode` re-entering the Metal graph engine mid-destroy
   (`metalView` niled `:1979`) is an unverified GPU risk. Site `:2276` LACKS the `if appearanceObserver==nil`
   guard that `:934` has → double-setup overwrites the prior observation (not an over-release, but harden).
4. **[STALE / NOT the vector] shared WKProcessPool swap** — current `EpdocWebViewShared` only tracks
   `liveWebViewCount` (`EpdocEditorChromeView.swift:36-50`); comment `:28-34` says `WKProcessPool` was removed.
   No pool shared/swapped → no use-after-free.

## Cleared / not implicated
- **Force-unwraps in color path: NONE** — `EpistemosTheme.swift:88-97 nsColor` total (no `!`); grep for
  `try!`/`as!`/`NSColor(named:)!` in theme dir empty.
- **`.sync` in appearance/KVO callbacks: NONE** — all `Task{@MainActor}` or read-only `assumeIsolated`.
- **Epdoc editor + KaTeX WebViews: hardened** — idempotent theme apply (`:754` guard), full `dismantleNSView`
  (`:675-683`, `EpdocKaTeXPreview.swift:85-88`), `[weak]` coordinators, NOT recreated on appearance (no
  theme-keyed `.id`).
- **Metal/MLX pipeline:** `MetalRuntimeManager` not touched by appearance; only `HologramOverlay.syncTheme`
  reaches a Metal view (root #3).

## Fix plan
1. **[S] Decouple the HTML Workspace preview `.id` from the theme hash** — drop `workspaceThemeIdentity.hashValue`
   from `previewRenderIdentity` (`HTMLWorkspaceEditorView.swift:617`); push theme via `updateNSView` (coordinator
   already accepts `themeIdentity`/`themeGuardCSSOverride`, `HTMLWorkspacePreviewView.swift:50-52`). Re-render in
   place, not recreate. **Removes roots #1 + #2. Highest leverage, smallest change.**
2. **[S] Drop the `previewPackage = package` re-stamp in `onChange(of: colorScheme)`** (`:34`) once theme rides
   `updateNSView`.
3. **[M] Re-entrancy-safe teardown** for `HTMLWorkspacePreviewView`/`WebKitCodeEditorView`: in
   `Coordinator.detach` null the nav-delegate + remove named handlers BEFORE `stopLoading`; guard
   `syncSafeAPIHandler` against re-adding to a view being dismantled (`:53,58`).
4. **[M] Debounce/serialize the appearance handler** — `SystemAppearanceObserver` coalesces on `isDark` (`:52`);
   ensure the HTMLWorkspace consumer is equally idempotent (`RootView.swift:442` already guards).
5. **[M] Add the missing `if appearanceObserver==nil` guard at `HologramOverlay.swift:2276`** to match `:934`;
   confirm `setLightMode` no-ops when the graph engine is mid-teardown (root #3).
6. **[L] Prove it** — UI test: open HTML Workspace preview + Epdoc + graph overlay, flip `AppleInterfaceStyle`
   N times, assert no WKWebView leak/crash. Removes the "unverified" tag on root #1.

## Unverified
Root #1/#2 crash MECHANISM inferred from lifecycle code, not a crash log — *needs runtime repro* (toggle
appearance with HTML Workspace preview open). The forced-recreation path IS verified; that recreation faults is
the unverified step. Root #3 unverified (low-probability). Recommend grepping `~/Library/Logs/DiagnosticReports`
for `Epistemos` to confirm the faulting frame (WKWebView vs Metal).

Key files: `Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift` (`:33-35,340,617` — primary root) ·
`Views/HTMLWorkspace/HTMLWorkspacePreviewView.swift` (`:25-59` — recreated surface) · `Views/Graph/Hologram
Overlay.swift` (`:935,1853-1869,1964,2276`) · `App/SystemAppearanceObserver.swift` · `App/RootView.swift:441` ·
`Theme/EpistemosTheme.swift:88,306,343` · `Views/Epdoc/EpdocEditorChromeView.swift:36-50,675-683,753-761`
(hardened reference + stale-pool clearance).
