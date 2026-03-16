# Final Verification Checklist

- [x] The app defaults to no theme on fresh install.
  - Evidence: [ThemePairTests.swift](/Users/jojo/Epistemos/EpistemosTests/ThemePairTests.swift) test `UIState defaults to native system appearance when no theme settings are stored`.

- [x] Custom themes are fully opt-in through Settings.
  - Evidence: [SettingsView.swift](/Users/jojo/Epistemos/Epistemos/Views/Settings/SettingsView.swift) `Enable Custom Themes` toggle drives `ThemeMode.systemDefault` vs `ThemeMode.custom`, with restart confirmation.

- [x] Disabling custom themes returns the app to a true native/system-default path.
  - Evidence: `UIState.windowAppearance == nil` in system-default mode, verified by [ThemePairTests.swift](/Users/jojo/Epistemos/EpistemosTests/ThemePairTests.swift) test `System default keeps window appearance unforced while custom themes opt in`.

- [x] Selected custom theme stays remembered but inactive when themes are OFF.
  - Evidence: [ThemePairTests.swift](/Users/jojo/Epistemos/EpistemosTests/ThemePairTests.swift) tests `Stored custom pair stays remembered without applying when custom themes are disabled` and `Toggling custom themes gates the remembered pair without losing it`.

- [x] Old theme-era toolbar/background/material workarounds do not burden default mode unless truly required.
  - Evidence: [NoteWindowManager.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift) removes `GlassToolbar` in native mode; [NoteWindowManagerTests.swift](/Users/jojo/Epistemos/EpistemosTests/NoteWindowManagerTests.swift) verifies no accessory remains in native mode and that a custom→native transition removes it.

- [x] Blur/translucency/material depth are restored correctly in default mode where appropriate.
  - Evidence: window/panel controllers now use `uiState.windowAppearance` and `uiState.windowBackgroundColor`, leaving native/default appearance unforced; utility windows continue to use `NSVisualEffectView` material backdrops without explicit theme forcing.

- [x] The app retains its curved/liquid premium identity in default mode.
  - Evidence: this pass did not remove the existing glass/material shell system, curved window treatment, or assistant surface chrome. It only gated theme-only forcing/workarounds.

- [x] Themes no longer act like a second design system controlling structure/behavior.
  - Evidence: this pass removed direct structural appearance forcing from default mode and verified custom-theme behavior through gating, while leaving token styling intact.

- [x] No major regressions were introduced.
  - Evidence: `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:EpistemosTests/ThemePairTests -only-testing:EpistemosTests/NoteWindowManagerTests` passed with `74 tests`, `0 failures`.

- [x] Theme changes still require restart.
  - Evidence: [SettingsView.swift](/Users/jojo/Epistemos/Epistemos/Views/Settings/SettingsView.swift) shows the restart prompt, and [AppBootstrap.swift](/Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift) persists preferences then relaunches.
