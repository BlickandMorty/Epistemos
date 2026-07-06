# App Shell Deep Audit

Cycle: ProShell subprocess env hardening, 2026-07-05

Status: in progress. This file exists to keep the two-domain loop honest while this cycle ships an OpenChamber hardening frontier. The shared shell is already dirty in the current worktree from existing/user/other-agent changes, so this cycle does not edit shell files.

## Current Apple HIG/API Check

Web-verified against official Apple Human Interface Guidelines on 2026-07-06:

- Dark Mode remains a systemwide appearance expectation; shell surfaces must be proven in both light and dark appearances. Source: https://developer.apple.com/design/human-interface-guidelines/dark-mode
- Apple's color guidance still favors system/adaptive colors that work across backgrounds, appearance modes, vibrancy, and accessibility settings. Source: https://developer.apple.com/design/human-interface-guidelines/color
- Accessibility and keyboard operation remain first-class design requirements; Apple's keyboard guidance includes Full Keyboard Access for navigating and activating windows, menus, controls, and system features. Sources: https://developer.apple.com/design/human-interface-guidelines/accessibility and https://developer.apple.com/design/human-interface-guidelines/keyboards
- Layout guidance now includes Liquid Glass as a cross-platform material direction; Epistemos shell changes should use native system materials sparingly and preserve content hierarchy. Source: https://developer.apple.com/design/human-interface-guidelines/layout

## Boundary State

Observed dirty shared-shell files before this cycle included `Epistemos/App/RootView.swift`, onboarding, settings, read-aloud, voice, landing, localization, and several tests. Protected dirty files also existed in the worktree (`Epistemos/Sync/**`, notes/editor surfaces, MAS June, Experimental, project file, and build script). This cycle leaves those untouched and confines implementation to the clean ProAgent frontier.

## Seven-Layer Shell Audit Slice

1. App shell/window chrome: READ. `RootView` owns home window identity, theme appearance stamping, and main shell state (`Epistemos/App/RootView.swift:10`, `Epistemos/App/RootView.swift:35`, `Epistemos/App/RootView.swift:185`). The current file is dirty from existing work, so no cycle edit is made here.
2. First-run/onboarding: READ. `SetupAssistantView` exposes a five-step flow with Reduce Motion-aware transitions and labeled progress (`Epistemos/Views/Onboarding/SetupAssistantView.swift:7`, `Epistemos/Views/Onboarding/SetupAssistantView.swift:13`, `Epistemos/Views/Onboarding/SetupAssistantView.swift:43`). It is dirty from existing work; later shell cycles should verify light/dark screenshots and first-value path.
3. Settings shell: READ. `SettingsView` uses a `NavigationSplitView`-style category/section model, with destructive actions behind SovereignGate reasons and visible section/category metadata (`Epistemos/Views/Settings/SettingsView.swift:12`, `Epistemos/Views/Settings/SettingsView.swift:47`, `Epistemos/Views/Settings/SettingsView.swift:66`, `Epistemos/Views/Settings/SettingsView.swift:88`). It is dirty from existing work and not touched here.
4. Voice/read-aloud: READ. `ReadAloudButton` centralizes playback state in the shared synthesizer, exposes icon/labeled/progress styles, disables unsupported input, and includes accessibility/help text (`Epistemos/Views/Shared/ReadAloudButton.swift:21`, `Epistemos/Views/Shared/ReadAloudButton.swift:27`, `Epistemos/Views/Shared/ReadAloudButton.swift:60`, `Epistemos/Views/Shared/ReadAloudButton.swift:163`, `Epistemos/Views/Shared/ReadAloudButton.swift:211`). Voice package truth is surfaced through `KokoroVoiceGateStatus` without AVSpeech fallback overclaim (`Epistemos/VoicePro/KokoroVoiceGateStatus.swift:44`, `Epistemos/VoicePro/KokoroVoiceGateStatus.swift:92`, `Epistemos/VoicePro/KokoroVoiceGateStatus.swift:144`).
5. Landing/navigation: PENDING. `Epistemos/Views/Landing/**` is dirty from existing work. A later cycle should audit quick-entry routing, empty states, keyboard navigation, and theme parity before claiming shell DoD.
6. Shared UI/accessibility/localization: PENDING. Current dirty state includes shared UI and `Localizable.xcstrings`. A later cycle should audit strings, labels, keyboard paths, reduced motion, and contrast with running-app proof.
7. Diagnostics/health rows: PENDING. Settings health rows report protected subsystems. A later cycle must keep them presentation-only and avoid changing protected subsystem contracts.

## Carry-Forward Findings

- SHELL-BORDER-1: Do not edit shared shell files until the current dirty work is separated or intentionally adopted. The worktree already contains unrelated shell/protected changes, so this OpenChamber cycle keeps its implementation boundary clean.
- SHELL-DOD-1: Full shared-shell Phase A remains incomplete. Required later evidence: file-line cited audit, focused tests, light/dark running screenshots, accessibility/keyboard pass, and zero protected-path edits attributable to that cycle.
