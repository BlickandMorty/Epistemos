# Theme Refactor Changelog

## Architecture

- [UIState.swift](/Users/jojo/Epistemos/Epistemos/State/UIState.swift)
  - Added `ThemeMode` with `systemDefault` and `custom`
  - Separated remembered theme pair from active theme mode
  - Added native-default helpers: `preferredColorScheme`, `shouldUseThemeWorkarounds`, `usesNativeWindowBlur`, `wallpaperBackground`, `windowBackgroundColor`, `contentBackground`, `overlayChromeBackground`
  - Removed dead `cycleTheme()` logic

- [AppBootstrap.swift](/Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift)
  - Added relaunch flow for theme changes
  - Clears visual caches before restart
  - Resets theme mode during full app reset

## Root UI / Rendering Restoration

- [RootView.swift](/Users/jojo/Epistemos/Epistemos/App/RootView.swift)
  - Stopped forcing color scheme from the active theme
  - Synced appearance changes through a dedicated key instead of raw theme identity
  - Restored native wallpaper/background behavior when custom themes are off

- [NoteDetailWorkspaceView.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift)
  - Switched note content/chrome backgrounds to the new native-aware helpers
  - Stopped forcing themed window appearance in native mode

- [NativeButtonStyles.swift](/Users/jojo/Epistemos/Epistemos/Theme/NativeButtonStyles.swift)
- [ChatView.swift](/Users/jojo/Epistemos/Epistemos/Views/Chat/ChatView.swift)
- [LibraryView.swift](/Users/jojo/Epistemos/Epistemos/Views/Library/LibraryView.swift)
- [NotesSidebar.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NotesSidebar.swift)
  - Switched secondary surfaces/popovers to `ui.preferredColorScheme`

## Window Chrome / Toolbar Workaround Gating

- [UtilityWindowManager.swift](/Users/jojo/Epistemos/Epistemos/App/UtilityWindowManager.swift)
  - Split native default window styling from custom theme styling
  - Removed forced themed background behavior from the default path

- [MiniChatWindowController.swift](/Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatWindowController.swift)
  - Updated hosted mini-chat window to follow native/default appearance behavior

- [NoteWindowManager.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift)
  - Gates glass toolbar theme injection behind custom theme mode
  - Restores native note window appearance when custom themes are disabled

- [ToolbarGlass.swift](/Users/jojo/Epistemos/Epistemos/Theme/ToolbarGlass.swift)
  - Added explicit removal path for the glass toolbar accessory

## Settings UX

- [SettingsView.swift](/Users/jojo/Epistemos/Epistemos/Views/Settings/SettingsView.swift)
  - Added `Enable Custom Themes`
  - Disabled theme pair selection while custom themes are off
  - Added restart prompt for theme changes
  - Kept display mode restart flow separate
  - Simplified the appearance view structure so it compiles reliably

## Cleanup

- [CommandPaletteOverlay.swift](/Users/jojo/Epistemos/Epistemos/Views/Landing/CommandPaletteOverlay.swift)
  - Removed direct theme switching from the command palette
  - Replaced it with navigation into Settings → Appearance

- [TextKit2FoundationTests.swift](/Users/jojo/Epistemos/EpistemosTests/TextKit2FoundationTests.swift)
  - Removed tests for the deleted command palette theme-transition helper

## Regression Coverage

- [ThemePairTests.swift](/Users/jojo/Epistemos/EpistemosTests/ThemePairTests.swift)
  - Added coverage for first-launch native default mode
  - Added coverage for dormant remembered custom themes
  - Added coverage for restoring remembered custom theme mode

- [NoteWindowManagerTests.swift](/Users/jojo/Epistemos/EpistemosTests/NoteWindowManagerTests.swift)
  - Added coverage for native note window chrome when themes are off
  - Added coverage for themed note window chrome when themes are on
