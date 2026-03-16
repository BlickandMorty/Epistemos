# Theme Revamp Final Changelog

## Architecture

- Added `UIState.windowAppearance` in [UIState.swift](/Users/jojo/Epistemos/Epistemos/State/UIState.swift).
  - Why: native/default mode needed a single explicit source of truth for whether windows should force Aqua/Dark Aqua or remain unforced.
  - Type: architecture

- Changed secondary-window theme sync to use `UIState` instead of raw theme identity in:
  - [UtilityWindowManager.swift](/Users/jojo/Epistemos/Epistemos/App/UtilityWindowManager.swift)
  - [MiniChatWindowController.swift](/Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatWindowController.swift)
  - [CommandPaletteWindowController.swift](/Users/jojo/Epistemos/Epistemos/Views/Landing/CommandPaletteWindowController.swift)
  - [HologramController.swift](/Users/jojo/Epistemos/Epistemos/Views/Graph/HologramController.swift)
  - [HologramOverlay.swift](/Users/jojo/Epistemos/Epistemos/Views/Graph/HologramOverlay.swift)
  - Why: default mode must not keep running per-window theme-era logic behind the scenes.
  - Type: architecture

## Cleanup

- Removed dead `ThemedGlassToolbarModifier`, `WindowAccessor`, and `View.themedGlassToolbar()` from [ToolbarGlass.swift](/Users/jojo/Epistemos/Epistemos/Theme/ToolbarGlass.swift).
  - Why: these were obsolete workaround glue from the old theme era and were no longer used by the live app.
  - Type: cleanup

## Workaround Removal / Isolation

- Updated [NoteWindowManager.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift) so the custom-theme path reinstalls the themed glass toolbar accessory and the native/default path removes it.
  - Why: the previous implementation was partial. It could leave custom themes without their own workaround, and it did not explicitly prove cleanup when returning to native mode.
  - Type: workaround removal / rendering restoration

- Updated [NoteDetailWorkspaceView.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift) to use `ui.windowAppearance` during note-window appearance refreshes.
  - Why: this closed a direct leak where note workspace updates still forced themed appearance values even in native/default mode.
  - Type: workaround removal / regression fix

## Rendering Restoration

- Updated command palette, mini chat, graph overlay, and utility windows to leave `appearance` unforced in system-default mode while still honoring custom theme appearance when themes are enabled.
  - Why: native/default mode should restore honest blur/translucency behavior, not carry stale themed chrome forcing.
  - Type: rendering restoration

## Tests / Hardening

- Hardened [ThemePairTests.swift](/Users/jojo/Epistemos/EpistemosTests/ThemePairTests.swift) by isolating theme defaults from live machine state.
  - Added coverage for:
    - native default on fresh launch
    - remembered custom pair staying dormant when themes are off
    - turning custom themes off without losing the remembered pair
    - native/default `windowAppearance == nil`
  - Type: hardening

- Hardened [NoteWindowManagerTests.swift](/Users/jojo/Epistemos/EpistemosTests/NoteWindowManagerTests.swift) by isolating theme defaults and adding same-window transition coverage.
  - Added coverage for:
    - native note windows carrying no `GlassToolbar` accessory
    - custom themes reinstalling the accessory
    - switching from custom back to native removing the accessory on the same window instance
  - Type: hardening

## Verification

- Targeted verification run:
  - `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:EpistemosTests/ThemePairTests -only-testing:EpistemosTests/NoteWindowManagerTests`
  - Result: `74 tests`, `0 failures`

## Not Changed On Purpose

- `ThemePair` and `EpistemosTheme` were preserved.
  - Why: the product still wants optional custom themes.

- Token-level `ui.theme` usage across views was not removed wholesale.
  - Why: this pass targeted structural leakage and stale workaround baggage, not a full visual token rewrite.

- Restart-required theme switching was preserved.
  - Why: the user explicitly requires a relaunch to apply a new theme and flush old chrome/material state safely.
