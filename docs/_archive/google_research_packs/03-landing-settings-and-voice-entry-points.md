# Landing, Settings, and Voice Entry Points

> **Index status**: SUPERSEDED-HISTORICAL — March 2026 Google research pack; superseded by IMPLEMENTATION_PLAN_FROM_ADVICE (April 2026 4-model council synthesis).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/google_research_packs/` for historical record.



## Why this matters

Even though MLX + TTS are inference features, the integration surface is not only backend. This app already has a current settings architecture, current landing controls, and a specific toolbar/window model. New controls must fit that.

## Current landing state

Landing is a polished current surface with:

- greeting/typewriter text
- cursor wake animation
- inline landing search mode
- detached settings window

Voice/local-model features should not clutter the landing UI or regress performance there.

## Current persisted UI state pattern

The app stores lightweight UI policy in `UIState` using `UserDefaults` and normalized models.

Example:

```swift
enum LandingCursorVisibilityMode: String, CaseIterable, Codable, Sendable {
    case landingOnly
    case searchOnly
    case both
    case neither
}
```

Greeting library pattern:

```swift
struct LandingGreetingEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var text: String
    var durationSeconds: Double
    var isEnabled: Bool
}
```

And persisted normalization:

```swift
var landingCustomGreetings: [LandingGreetingEntry] = [] {
    didSet {
        normalizeLandingGreetingLibrary()
    }
}
```

This is relevant because the current app already has a pattern for:

- persisted user-facing settings
- small Codable value models
- normalization/fallback on load

That same pattern likely fits local-model policy and TTS preferences.

## Current landing settings UI pattern

There is already a dedicated landing section in the detached settings window:

```swift
private struct LandingDetailView: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        Form {
            Section("Cursor Animation") {
                Picker("Cursor Visibility", selection: $ui.landingCursorVisibilityMode) {
                    ForEach(LandingCursorVisibilityMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("Greeting Behavior") {
                Toggle("Animate typewriter", isOn: $ui.landingGreetingTypewriterEnabled)
            }
        }
    }
}
```

The settings window itself is a `NavigationSplitView`:

```swift
NavigationSplitView {
    List(SettingsSection.allCases, selection: $selection) { section in
        Label(section.rawValue, systemImage: section.icon)
            .tag(section)
    }
} detail: {
    switch selection {
    case .inference: InferenceDetailView()
    case .landing: LandingDetailView()
    ...
    }
}
```

## Current toolbar entry points

The root toolbar already has current high-level controls:

```swift
private var rootToolbarControls: some View {
    HStack(spacing: 10) {
        settingsToolbarButton

        if showLandingToolbarControls {
            landingGreetingToolbarButton
            landingCursorToolbarButton
        }

        if activeHomeChat {
            modelToolbarButton
        }

        historyToolbarButton
    }
}
```

This means there are already two likely homes for new MLX/TTS UX:

- full settings UI
- possibly small top-level runtime controls in existing toolbar patterns

## Voice entry point implications

The current app does **not** have a live voice subsystem in the current branch, but the present structure implies likely voice entry points:

- settings window for engine/model/voice preferences
- note chat responses
- chat responses
- graph inspector summaries
- optional read-aloud toggles

Research should recommend a minimal V1 voice control surface that fits the current design system and does not turn settings into a debug console.

## What research should answer

- Should local model management live under current `Inference` settings or a new `Local AI` section?
- Should TTS live under `Inference`, `Voice`, or a combined `Local AI & Voice` section?
- Which controls deserve toolbar presence versus settings-only presence?
- How should download progress, model state, runtime state, and errors be presented in a polished native way?
- How should first-run local setup be exposed without making landing feel heavier?
