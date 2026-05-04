# Theme Audit

> **Index status**: SUPERSEDED-HISTORICAL — Theme revamp shipped.
> **Superseded by / Phase**: theme refactor shipped.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## Current Theme Architecture Before Refactor

- Theme state lived in [UIState.swift](/Users/jojo/Epistemos/Epistemos/State/UIState.swift) as a single always-on `activePair`.
- The resolved `EpistemosTheme` was treated as canonical everywhere, including in default app startup.
- [RootView.swift](/Users/jojo/Epistemos/Epistemos/App/RootView.swift) forced `preferredColorScheme` from the theme, so the app never had a true native/system path.
- Secondary windows and note windows styled themselves directly from the resolved theme in [UtilityWindowManager.swift](/Users/jojo/Epistemos/Epistemos/App/UtilityWindowManager.swift), [MiniChatWindowController.swift](/Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatWindowController.swift), and [NoteWindowManager.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift).
- Settings exposed theme pairs directly, which made themes feel like a mandatory top-level design system instead of an optional appearance layer.

## True Token Styling

These parts are legitimate theme tokens and were preserved:

- `EpistemosTheme` color, border, accent, and typography tokens in [EpistemosTheme.swift](/Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift)
- theme pair definitions and light/dark resolution
- themed button, glass, and surface token use where appearance is the only thing changing
- display-mode typography switching

## Structural Leakage

These were theme-driven behaviors, not just theme-driven styling:

- global color-scheme forcing from the theme in [RootView.swift](/Users/jojo/Epistemos/Epistemos/App/RootView.swift)
- note and utility window appearance assignment based on theme identity rather than mode in [NoteWindowManager.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift) and [UtilityWindowManager.swift](/Users/jojo/Epistemos/Epistemos/App/UtilityWindowManager.swift)
- page content and chrome backgrounds using theme fills even when the desired result was native blur/translucency in [NoteDetailWorkspaceView.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift)
- command palette still containing a product-level theme switch path in [CommandPaletteOverlay.swift](/Users/jojo/Epistemos/Epistemos/Views/Landing/CommandPaletteOverlay.swift)

## Workaround Baggage

These existed to make themed chrome behave, but were wrong for a native default path:

- glass toolbar accessory insertion for note windows in [ToolbarGlass.swift](/Users/jojo/Epistemos/Epistemos/Theme/ToolbarGlass.swift)
- forced themed window appearance in secondary windows
- themed background fills that sat behind what should have been clear/material-backed regions
- theme-controlled `preferredColorScheme` overrides on popovers and sheets

## Bloat Sources

- theme selection and theme application were coupled into one concept
- theme state propagated into screens that only needed presentation tokens
- dead command-palette theme-transition logic remained after themes stopped belonging in that surface
- test coverage still protected a removed theme-switching behavior instead of the new native-default model

## Preserved On Purpose

- `EpistemosTheme` and `ThemePair` remain intact as optional custom appearance layers
- note toolbar themed glass workaround remains available for custom theme mode
- custom theme pair memory is preserved even while custom themes are disabled
- the curved/liquid visual identity remains; the refactor only removes forced theming from the default path

## Simplified / Quarantined

- `ThemeMode` now separates native/system default from opt-in custom themes
- custom theme workarounds are now gated behind `UIState.shouldUseThemeWorkarounds`
- native/system mode now leaves `preferredColorScheme` unset and restores clear/material-friendly window backgrounds
- theme switching moved into Settings and requires relaunch to flush caches/workaround layers safely

## Remaining Intentionally Themed Areas

- custom theme token rendering still applies when `ThemeMode == .custom`
- theme pair cards remain in Settings
- theme-aware surfaces in `GlassModifiers.swift` still support custom theme coloration for explicit custom theme mode

## Dead / Removed

- command palette theme-switch action
- `CommandPaletteThemeTransition` helper and its tests
- unused `UIState.cycleTheme()` path
