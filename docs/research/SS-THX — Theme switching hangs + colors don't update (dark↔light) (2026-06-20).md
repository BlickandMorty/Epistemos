---
id: 6A9A082D-DA4B-4046-9010-78CE29C9C599
title: "SS-THX — Theme switching hangs + colors don't update (dark↔light) (2026-06-20)"
---

# SS-THX — Theme switching hangs + colors don't update (dark↔light) (2026-06-20)

Owner: *"theme switching is still lacking — it hangs sometimes, the colors never change because of the theme process,
like when turning dark to light and vice versa."* Code-grounded. **MUST be done WITH / BEFORE SS-TC** (the granular-color
slots add to the uncached hot path — see the ⚠ below). Cross-ref SS-U (dark/light WKWebView crash, fixed 749d2c889), SS-TC.

## Two entry points (the confusion)

- System dark↔light: `App/SystemAppearanceObserver.swift:50` → `RootView.swift:440-443` sets `ui.isSystemDark`.
- In-app theme-pair: `Views/Settings/SettingsView.swift:4134-4135` `ui.setPair()` + `setThemeMode(.custom)` (`State/UIState.swift:559-565`, didSet writes UserDefaults).
Central observable = `UIState.theme` (`UIState.swift:276-293`); default mode `.custom` → resolves via `activePair.resolved(isDark:)`.

## ROOT 1 — the HANG: uncached custom-theme resolve on the MainActor

`EpistemosTheme.resolved` (`EpistemosTheme.swift:306-311`) caches PRESET themes (`resolvedCache:295-304`) BUT short-circuits
to the **UNCACHED** `AppCustomTheme.resolved(isDark:)` on EVERY access when a custom theme is active:

- `AppCustomTheme.isActive` (`:1452-1458`) does a `UserDefaults.string(forKey:)` per `.resolved` call.
- `AppCustomTheme.resolved(isDark:)` (`:1524-1567`) rebuilds the full `ResolvedTheme` from ~7 `hex(...)` calls, each doing
2-3 `UserDefaults.object/integer` reads (`:1460-1475`) → ~15-20 sync UserDefaults reads PER resolve, zero memoization.
Every view reads `ui.theme` then dereferences `theme.resolved.<token>` MANY times per `body` (LandingView alone: dozens). A
theme toggle invalidates the whole view tree → **thousands of synchronous UserDefaults reads + full struct rebuilds on the
MainActor** = the perceived HANG (worse with Landing+Chat+Graph+editors open). Amplified by `EpistemosFont`/`AppDisplayTypography`
also calling `SystemAppearanceState.isDark()` (another UserDefaults read) per font resolution (`:2033,2054,1481,1513`).
**⚠ SS-TC INTERACTION:** SS-TC adds MORE per-slot `hex()` UserDefaults reads to this exact uncached path → it WORSENS the
hang unless the caching below lands. Do SS-THX caching together with / before SS-TC.

## ROOT 2 — colors DON'T update: HTMLWorkspace watches the wrong source

`HTMLWorkspaceEditorView.swift:8` injects `@Environment(\.colorScheme)`; `workspaceTheme` (`:506-509`) falls back to
`colorScheme == .dark ? .oledSoft : .light` and only refreshes on `.onChange(of: colorScheme)` (`:33-35`). Because
`UIState.preferredColorScheme = nil` (`UIState.swift:296`), SwiftUI `colorScheme` follows OS appearance ONLY — so changing
the in-app PAIR (or any pair while system stays dark) never repaints the workspace (reachable from the `theme:nil` call site
`Engine/HTMLWorkspaceDocument.swift:46`). That surface literally "never changes because of the theme process."

## SS-U lesson already applied broadly (no rebuild storm)

Epdoc (`EpdocEditorChromeView.swift:651-660,753-761`), KaTeX (`EpdocKaTeXPreview.swift:90-105`), Metal graph
(`MetalGraphView.swift:582-588,832-838`) all push theme via `updateNSView`/`evaluateJavaScript`, guarded, no rebuild. No
views `.id()` on theme (grep none). Remaining costs = the uncached resolve (Root 1) + the HTMLWorkspace preview doing a full
`loadHTMLString` reparse per flip (`HTMLWorkspacePreviewView.swift:47-69`).

## FIX (instant + non-blocking + all surfaces update)

1. **[S, highest impact] CACHE the custom-theme resolve** — memoize `AppCustomTheme.resolved(isDark:)` keyed on a revision
 counter bumped in the custom-theme setters/`setHex`; read `isActive` once per derivation, not per token. Better: hoist
 resolution into `UIState.theme` so the `ResolvedTheme` is computed ONCE per `appearanceSyncKey` change + stored, instead of
 every `theme.resolved.*` re-reading UserDefaults. Target: one resolve per flip, not thousands → hang gone. (`EpistemosTheme  .swift:306-311,1452-1568`.) **This is also the prerequisite for SS-TC.**
2. **[S] Fix HTMLWorkspace theme dependency** — `workspaceTheme` reads `ui.theme.surfaceVariant(.other)` (inject UIState) or
 pass non-nil `theme` at `HTMLWorkspaceDocument.swift:46`; refresh on `ui.appearanceSyncKey`/`ui.theme`, not only
 `@Environment(\.colorScheme)` (`HTMLWorkspaceEditorView.swift:8,33,506-509`).
3. **[S] Push, don't reload, the HTML preview palette** — inject theme via `evaluateJavaScript`/CSS-vars (Epdoc/KaTeX pattern)
 instead of `loadHTMLString` per flip (`HTMLWorkspacePreviewView.swift:47-69`).
4. **[S] Defer heavy toggle work off the sync frame** — coalesce/defer `UtilityWindowManager.syncTheme` (`:262-269`) +
 `CodeEditorView.applyGutterPreferences` (`:1937`) to the next runloop tick rather than inline in `onChange`.
Order: #1 first (kills the hang + unblocks SS-TC), then #2/#3 (workspace repaints), then #4. Test: a perf/behavior test that
a theme toggle triggers ONE resolve (not N), + a render check that the workspace palette tracks `ui.activePair`. NON-INVASIVE.

---

## 🔴 REGRESSION (owner on-device 2026-06-20): CUSTOM theme takes ~3 changes before TK2 + tabs match — staleness from the SS-THX cache

Owner: *"the custom theme takes a few times before it loads the full theme — TK2 is one color and the tabs are another, then after changing themes ~3 times it finally matches. This is a regression that wasn't there before; harden it."* The SS-THX
memoization (28402960d) fixed the hang but introduced a propagation/staleness bug for CUSTOM-theme color edits. Root (grounded):

- **TK2/Prose doesn't re-apply on a custom-color edit.** `ProseEditorRepresentable2.updateNSView` re-applies theme only when
`parent.theme` VALUE changes (`tv.applyTheme(parent.theme)` :565). A custom-theme color edit keeps the SAME `.appCustom`
enum case → `parent.theme` "unchanged by value" → `updateNSView` skips `applyTheme` → TK2 keeps OLD colors. The tabs
(SwiftUI views reading the resolved palette via @Observable) DO update because the resolved cache was invalidated → TK2 vs
tabs diverge. After ~3 switches enough churn forces a re-apply → it finally matches.
- **+ possible cache-key staleness:** `AppCustomTheme.resolved(isDark:defaults:)` caches by isDark+defaults (`:1610-1628`);
the change-invalidation (`:1564/:1582`) must flush BOTH isDark variants (and any per-appearance keys) on a single edit, else  
the first read returns the stale entry.
- **FIX (harden, NON-INVASIVE):** (1) make custom-theme edits force a re-apply on the theme-VALUE-blind surfaces — bump a
`themeRevision` token (or a customTheme-change signal) `ProseEditorRepresentable2.updateNSView` observes, so TK2 `applyTheme`
runs on EVERY custom-color edit even though the enum case is unchanged (sweep CodeEditorView + any other
`applyTheme`-on-value-change surface for the same pattern). (2) On a custom-theme edit, FULLY invalidate the
AppCustomTheme.resolved cache (all isDark/appearance keys) in one pass. Net: ONE custom-theme change → ALL surfaces (TK2,
tabs, editors, chat) match immediately, no 3-toggle convergence. Test: behavior — a single custom-color edit re-applies the
TK2 theme (themeRevision bumped) + the resolved cache returns the NEW value on first read (no stale). Tracked, normal order
(fold into SS-TC/SS-THX). A cache that fixed one thing + broke another = SS-CLEAN "layering mud" catch.

