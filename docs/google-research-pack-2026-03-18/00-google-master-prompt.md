# Google Research Prompt — Epistemos Local MLX + Chatterbox TTS

You are doing a deep technical/product research pass for a real macOS app that already exists and is actively used.

Your task is not to redesign the app from scratch. Your task is to determine the very best way to add:

1. native local MLX model support on Apple Silicon
2. two local model families: Qwen and Gemma
3. local TTS using Chatterbox
4. app-managed install/download/update flows for models and TTS runtime
5. a production-quality settings/control layer for all of the above

Read all attached markdown files before answering.

## What This App Is

This is **Epistemos**, a native macOS knowledge app built with:

- Swift 6
- SwiftUI
- AppKit bridges for advanced editing
- SwiftData
- Metal
- Rust FFI for the graph engine

Today the app already has:

- a polished landing/home experience
- native notes windows with an AppKit-based markdown editor
- inline AI note chat
- a full-screen graph overlay driven by Rust + Metal
- a settings window
- Apple Intelligence routing for simple tasks
- cloud providers for larger tasks

Do **not** propose restoring any old shell, old library feature, old nav pill, or old app structure. The current app visuals and layout are the baseline to preserve.

## Hard Product Requirements

These are not optional:

- Preserve the current app architecture and visual direction unless there is a clear technical reason to extend it.
- Apple Intelligence remains the first on-device routing layer for trivial/simple work.
- MLX local inference becomes the next tier after Apple Intelligence.
- Qwen should be the primary local family.
- Gemma should be the secondary local family / fallback family.
- Chatterbox should be the primary TTS engine.
- Fish Speech may be discussed as an optional later engine, but do not treat it as the default recommendation unless you can strongly justify it despite its heavier operational and licensing profile.
- The user wants the local stack to feel like it "installs with the app" with as little manual setup as possible.
- The answer must optimize for real shipping quality on macOS, not demo quality.

## What You Need To Research

Produce a concrete, implementation-grade recommendation for the current app.

### A. Local MLX architecture

Determine the best architecture for integrating MLX local inference into this existing app:

- best way to add MLX to the current `InferenceState` / `LLMService` / `TriageService` stack
- whether MLX should be a new provider, a local sub-provider layer, or a separate local inference subsystem feeding triage
- best way to support both Qwen and Gemma cleanly
- best way to handle model loading, unload, swap, memory budgeting, and cancellation
- best way to stream tokens into the app's current UI architecture
- best way to keep startup fast and avoid loading large local models too early
- best way to avoid regressions with Apple Intelligence routing and existing cloud providers

### B. Best starter models for MacBook Pro

Research the best current MLX-friendly local models to start with on modern MacBook Pro hardware.

I need a recommendation matrix for:

- 18GB unified memory Macs
- 24GB unified memory Macs
- 36GB unified memory Macs
- 48GB unified memory Macs
- 64GB+ unified memory Macs

For each tier, recommend:

- best Qwen starter model
- best Gemma starter model
- quantization
- approximate disk size
- approximate memory footprint
- intended use case
- whether it should be always-available, on-demand, or optional

Also answer:

- what model should be auto-installed on first run
- what second model should also be auto-installed
- what larger upgrades should be optional downloads
- whether the old Qwen 3.5 suggestions should now be replaced by newer Qwen or Gemma variants

### C. Chatterbox TTS architecture

Research the best production architecture for integrating Chatterbox into a native macOS app like this.

I need guidance on:

- bundled Python runtime vs managed internal environment vs other approach
- best way to package and sign it for direct-download macOS distribution
- what is realistic or unrealistic for App Store distribution
- daemon/subprocess architecture
- IPC protocol choice
- startup lifecycle
- voice asset management
- caching
- synthesis latency mitigation
- streaming or chunked playback if relevant
- cancellation
- error recovery
- offline behavior

Also recommend:

- whether Chatterbox Turbo should be the default engine
- whether multilingual Chatterbox should be optional
- best default voice strategy
- best path for custom voice cloning later

### D. Model + runtime install flow

Research the best way for the app to manage local dependencies.

I need a recommendation for:

- where models should live on disk
- where Chatterbox runtime assets should live
- how downloads should be tracked
- how integrity should be verified
- how updates should work
- how disk pressure should be handled
- how uninstall/cleanup should work
- how progress UI should behave
- what should happen on first launch
- what should happen on low-storage systems

The user experience goal is:

- app feels self-contained
- no manual terminal setup
- no confusing external tooling
- minimal friction

### E. Settings UX

Research the best settings architecture and UX for this app.

Recommend:

- what belongs under current Settings > Inference
- whether there should be a dedicated Local AI / Voice section
- model status UI
- download progress UI
- active/local routing policy UI
- TTS controls
- read-aloud surface controls
- defaults vs advanced controls
- safe fallback behavior when local models are missing

### F. Surface integration

Propose how MLX and TTS should integrate with the existing app surfaces:

- main home chat
- note editor AI
- note chat sidebar/panel
- graph summaries / graph inspector
- notifications or read-aloud modes
- settings

Be specific about what should ship in V1 versus later phases.

### G. Performance and macOS engineering

Research the best technical practices for:

- keeping launch fast
- preventing UI hitching while models load
- avoiding large memory spikes
- lazy initialization
- actor isolation
- streaming into SwiftUI/AppKit safely
- handling unified memory on Apple Silicon
- preserving responsiveness while Metal graph and note windows are open
- concurrency patterns that fit Swift 6 well

### H. Distribution strategy

Research the cleanest shipping strategy for:

- direct-download build
- App Store-compatible build if possible
- feature gating if Python-based Chatterbox is not App Store-safe
- notarization/signing implications
- auto-download legal/compliance implications for external weights

## Required Output

Your answer should be structured and decisive.

Give me:

1. **Executive recommendation**
2. **Best architecture for this exact app**
3. **Best starter model matrix for MacBook Pro memory tiers**
4. **Best Chatterbox packaging/runtime architecture**
5. **Best install/download/update architecture**
6. **Best settings UX architecture**
7. **V1 scope vs later scope**
8. **Step-by-step implementation plan for this codebase**
9. **Risk register**
10. **What not to do**

## Important Constraints

- Be concrete.
- Prefer production-grade simplicity over theoretical maximalism.
- Assume the app is real and already polished.
- Avoid suggesting large-scale rewrites unless absolutely necessary.
- Preserve the current app structure and current UX direction.
- Cite real sources and current upstream realities.
- If older internal docs conflict with current best practice, say so clearly.

## Attached Context Files

Read these attached files in order:

1. `01-app-overview.md`
2. `02-current-ai-inference-stack.md`
3. `03-landing-settings-and-voice-entry-points.md`
4. `04-notes-editor-and-note-chat.md`
5. `05-graph-overlay-and-query-stack.md`
6. `06-persistence-installation-and-distribution-constraints.md`
7. `07-prior-mlx-tts-history-and-reference-repos.md`
8. `08-research-questions-and-decision-matrix.md`

## Final Tone

Respond like a principal engineer / applied researcher writing an implementation recommendation for a serious native macOS product.
