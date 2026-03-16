# Theme Revamp Audit Report

## Scope

This pass audited the prior agent work centered on commit `8037a3c` (`refactor: default to native appearance`) and verified the current codebase against the intended spec:

- default mode must be native/system and first-class
- custom themes must be opt-in
- custom theme state must be gated by Settings
- theme-era workaround baggage must not burden default mode
- default mode must restore blur/translucency/material depth
- themes must not keep controlling structure

## What Prior Agents Changed Correctly

The prior revamp did land the major conceptual split:

- [UIState.swift](/Users/jojo/Epistemos/Epistemos/State/UIState.swift) introduced `ThemeMode.systemDefault` and `ThemeMode.custom`.
- [SettingsView.swift](/Users/jojo/Epistemos/Epistemos/Views/Settings/SettingsView.swift) added an `Enable Custom Themes` toggle and restart prompt flow.
- [AppBootstrap.swift](/Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift) persisted theme mode + pair and relaunched to flush cached chrome.
- [RootView.swift](/Users/jojo/Epistemos/Epistemos/App/RootView.swift) stopped forcing a custom color scheme in native/default mode.
- [UtilityWindowManager.swift](/Users/jojo/Epistemos/Epistemos/App/UtilityWindowManager.swift), [MiniChatWindowController.swift](/Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatWindowController.swift), [NoteWindowManager.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift), and [ToolbarGlass.swift](/Users/jojo/Epistemos/Epistemos/Theme/ToolbarGlass.swift) had already started moving theme-era chrome behind explicit gating.

Those parts were real improvements, not cosmetic-only work.

## What Was Partial Or Wrong

The prior revamp was not actually complete. The forensic audit found five real gaps:

1. Floating panels still forced explicit Aqua/Dark Aqua appearance in native mode.
   - [CommandPaletteWindowController.swift](/Users/jojo/Epistemos/Epistemos/Views/Landing/CommandPaletteWindowController.swift) still hard-set `NSAppearance(named:)`.
   - Graph overlay sync still forced themed appearance instead of allowing native/default `nil` appearance.

2. Note custom-theme workaround reinstall was incomplete.
   - [NoteWindowManager.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift) only called `updateGlassToolbarTheme(...)`.
   - If the `GlassToolbar` accessory had not been installed yet, custom theme mode could end up with no themed toolbar workaround at all.

3. A note workspace appearance refresh path still bypassed the new default-mode gate.
   - [NoteDetailWorkspaceView.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift) still wrote Aqua/Dark Aqua directly on `ui.appearanceSyncKey` changes.

4. Dead theme-era SwiftUI glue was still present.
   - [ToolbarGlass.swift](/Users/jojo/Epistemos/Epistemos/Theme/ToolbarGlass.swift) still carried the unused `ThemedGlassToolbarModifier`, `WindowAccessor`, and `View.themedGlassToolbar()` path.
   - That code still contained old `DispatchQueue.main.async` theme application baggage and no longer belonged in the active architecture.

5. Prior tests were giving a false sense of safety.
   - The new theme tests were reading the real persisted user defaults state.
   - That meant they could fail or pass depending on the developer machine’s saved theme settings, which does not prove the product behavior.
   - There was also no regression check for `custom → native` cleanup on the same note window instance.

## Structural Theme Leakage Still Present Vs Acceptable

### Preserved intentionally

These still use `ui.theme`, but they are token-level presentation, not structural theme leakage:

- glass/button color tokens in [GlassModifiers.swift](/Users/jojo/Epistemos/Epistemos/Theme/GlassModifiers.swift)
- appearance tokens consumed by views such as [ChatView.swift](/Users/jojo/Epistemos/Epistemos/Views/Chat/ChatView.swift), [LandingView.swift](/Users/jojo/Epistemos/Epistemos/Views/Landing/LandingView.swift), and [NotesSidebar.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NotesSidebar.swift)
- custom theme pair selection UI in Settings

These are acceptable because `ThemeMode.systemDefault` now resolves through a native/default token path and no longer activates theme-only chrome workarounds.

### Leakage that needed correction

These were not acceptable because they changed runtime chrome behavior:

- explicit panel/window appearance forcing in native/default mode
- note toolbar workaround install/update paths that did not fully gate on mode
- stale accessory/background workaround code paths that stayed compiled in as active architecture

## Workaround Baggage Found

The following workaround classes were confirmed as true theme-era baggage:

- note titlebar accessory glass insertion in [ToolbarGlass.swift](/Users/jojo/Epistemos/Epistemos/Theme/ToolbarGlass.swift)
- direct `NSAppearance(named:)` forcing in panel/window controllers
- note workspace appearance refreshes that reintroduced themed window appearance during general UI sync

These are now isolated to the custom-theme path only, or removed if dead.

## What Was Fixed In This Pass

- Added `UIState.windowAppearance` in [UIState.swift](/Users/jojo/Epistemos/Epistemos/State/UIState.swift) as the single source of truth for window appearance forcing.
- Updated [UtilityWindowManager.swift](/Users/jojo/Epistemos/Epistemos/App/UtilityWindowManager.swift), [MiniChatWindowController.swift](/Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatWindowController.swift), [CommandPaletteWindowController.swift](/Users/jojo/Epistemos/Epistemos/Views/Landing/CommandPaletteWindowController.swift), [HologramController.swift](/Users/jojo/Epistemos/Epistemos/Views/Graph/HologramController.swift), and [HologramOverlay.swift](/Users/jojo/Epistemos/Epistemos/Views/Graph/HologramOverlay.swift) to use the native/default gate instead of hand-rolled appearance logic.
- Updated [NoteWindowManager.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift) so custom theme mode reinstalls the glass toolbar accessory when needed, and native mode removes it.
- Updated [NoteDetailWorkspaceView.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift) so appearance refreshes go through `ui.windowAppearance`.
- Removed dead `ThemedGlassToolbarModifier` baggage from [ToolbarGlass.swift](/Users/jojo/Epistemos/Epistemos/Theme/ToolbarGlass.swift).
- Hardened tests in [ThemePairTests.swift](/Users/jojo/Epistemos/EpistemosTests/ThemePairTests.swift) and [NoteWindowManagerTests.swift](/Users/jojo/Epistemos/EpistemosTests/NoteWindowManagerTests.swift) to isolate persisted defaults and verify `custom → native` note toolbar cleanup.

## Regressions Found During The Audit

- False-negative/false-positive test behavior caused by reading live user defaults.
- Native note-window verification could silently inherit a persisted custom theme and report the wrong result.
- The custom-theme note toolbar path could look “implemented” in code review while still failing to install the accessory at runtime.

## Final Assessment

The prior revamp was directionally correct but incomplete. The architecture split existed, but runtime chrome paths were still inconsistent and the tests did not fully prove the intended behavior.

After this pass:

- default mode is a real native/default path
- custom themes are opt-in
- window and panel appearance forcing is centrally gated
- note toolbar workaround baggage is bypassed in native mode and restored only in custom mode
- dead theme-era glue has been removed
- regression coverage now checks the actual toggle/cleanup behavior rather than only static defaults
