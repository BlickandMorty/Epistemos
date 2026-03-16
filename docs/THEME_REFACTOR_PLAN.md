# Theme Refactor Plan

## New Architecture

The theme system is now split into two explicit modes:

- `ThemeMode.systemDefault`
- `ThemeMode.custom`

Implementation lives in [UIState.swift](/Users/jojo/Epistemos/Epistemos/State/UIState.swift).

`systemDefault` is the first-class default path:

- no custom theme is applied
- `preferredColorScheme` is `nil`
- theme-era window/toolbars workarounds are off
- native blur/material/translucency can render normally

`custom` is the opt-in path:

- the remembered `ThemePair` resolves into the active `EpistemosTheme`
- theme-era chrome workarounds are re-enabled only where still necessary
- custom appearance stays token-driven instead of controlling structure

## Why This Is Better

- The default app experience is now native instead of themed-by-default.
- Themes no longer define the app’s canonical chrome behavior.
- Window and toolbar behavior can return to native translucency in default mode.
- Custom themes remain available without forcing the rest of the app to compensate for them.

## Default / Native Path

When custom themes are off:

- [RootView.swift](/Users/jojo/Epistemos/Epistemos/App/RootView.swift) does not force a color scheme
- [UtilityWindowManager.swift](/Users/jojo/Epistemos/Epistemos/App/UtilityWindowManager.swift) and [NoteWindowManager.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift) leave window appearance native
- note chrome stops injecting themed glass toolbar accessories
- content areas use system-friendly clear/background values instead of stale themed fills

## Custom Theme Opt-In Path

When custom themes are on:

- the remembered theme pair is resolved and applied
- note toolbar/theme accessory behavior is restored
- themed windows reapply their explicit appearance
- theme token rendering continues to work without affecting product structure

## Settings UX

Appearance settings now provide:

- `Enable Custom Themes` toggle
- theme pair picker disabled when custom themes are off
- explicit restart prompt when theme mode or pair changes
- display mode restart prompt kept separate

This is implemented in [SettingsView.swift](/Users/jojo/Epistemos/Epistemos/Views/Settings/SettingsView.swift).

## Theme-Era Workarounds

Handled as follows:

- preserved for custom theme mode only
- bypassed in native/system mode
- flushed on relaunch via [AppBootstrap.swift](/Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift)

## Maintainability Wins

- one source of truth for theme mode and remembered pair
- one explicit gate for theme workarounds
- fewer global UI branches driven by theme identity
- no command palette theme switching path outside Settings
