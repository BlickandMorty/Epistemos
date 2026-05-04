# Persistence, Installation, and Distribution Constraints

> **Index status**: SUPERSEDED-HISTORICAL — March 2026 Google research pack; superseded by IMPLEMENTATION_PLAN_FROM_ADVICE (April 2026 4-model council synthesis).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/google_research_packs/` for historical record.



## Why this matters

The user explicitly wants local models and TTS to feel built into the app. That is not only a model question. It is a packaging, persistence, update, and shipping question.

## Current bootstrap style

`AppBootstrap` eagerly creates core state and lazily defers expensive work:

```swift
let inference = InferenceState()
let llm = LLMService(inference: inference)
let triage = TriageService(inference: inference, llmService: llm)
...
Task(priority: .utility) { await graphState.loadGraph(container: container) }
```

And query search index setup is intentionally lazy:

```swift
queryEngine.configure(
    graphStore: graphState.store,
    graphState: graphState,
    searchIndexProvider: { [vaultSync] in
        vaultSync.searchService ?? (try? SearchIndexService())
    }
)
```

This is important because any local model manager should probably follow the same pattern:

- register early
- initialize lazily
- avoid launch-time heavy work

## Current persistence patterns

The app already uses multiple persistence layers intentionally:

- `SwiftData` for app entities
- `UserDefaults` for lightweight UI/config state
- `Keychain` for secrets / API keys
- filesystem-backed services for notes/search/cache

Examples:

### UserDefaults

```swift
UserDefaults.standard.set(
    landingCursorVisibilityMode.rawValue,
    forKey: LandingWakeFieldPolicy.visibilityModeDefaultsKey
)
```

### Keychain

```swift
self.anthropicKey = Keychain.load(for: "epistemos.apiKey.anthropic") ?? ""
self.openaiKey = Keychain.load(for: "epistemos.apiKey.openai") ?? ""
```

## Strong likely pattern for local AI/TTS

Research should assume the app will likely want:

- `UserDefaults` for user policy and selected active models/voices
- a new manager/state object for runtime/download state
- filesystem storage under `~/Library/Application Support/Epistemos/...`
- no model blobs inside SwiftData

## Distribution constraints

Older internal docs envisioned:

- App Store Lite
- Direct Download Pro

That matters because the best packaging for Chatterbox may differ between:

- direct-download notarized build
- App Store-safe build

Research should explicitly analyze:

- if embedded Python + Chatterbox is acceptable for direct-download notarized macOS distribution
- whether that is App Store-safe
- whether local TTS should be gated or swapped to a different engine in App Store builds
- how MLX model downloads should be signed/verified and updated

## Installation realities to research

Research should provide a strong answer for:

- app bundle size vs first-run download
- prebundled tiny starter assets vs full first-run network install
- resumable download strategy
- checksum/signature strategy
- disk-space preflight checks
- cleanup of unused models and runtimes
- background download policy
- offline-first behavior

## What must be preserved

- startup speed
- app responsiveness
- simple install experience
- no manual shell steps for the user
- maintainable macOS shipping story
