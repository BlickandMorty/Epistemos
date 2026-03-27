# Epistemos V1 Release Audit

## Executive Summary

Epistemos is much closer to a coherent V1 than the research corpus makes it look.

If V1 is defined honestly as a local-first macOS note-thinking app with a strong native editor, vault-backed persistence, search, note-grounded AI, workspace/session memory, and advanced graph/time surfaces, the app is **almost ready**.

If V1 is judged against the full moonshot corpus of Omega, agents, Screen2AX, dual-brain autonomy, self-improving training, and full epistemic-lifecycle machinery, it is obviously not ready. That would be the wrong release standard.

The correct verdict is:

# READY FOR V1 WITH A SHORT FINAL POLISH PASS

The remaining work should focus on:

- release-scope clarity
- build/release reproducibility
- first-run messaging
- manual release QA on the core note workflow

not on expanding the feature surface.

## Verification Snapshot

### Verified

- Core product surfaces were inspected directly in code:
  - `Epistemos/App/EpistemosApp.swift`
  - `Epistemos/App/RootView.swift`
  - `Epistemos/App/AppBootstrap.swift`
  - `Epistemos/Views/Landing/LandingView.swift`
  - `Epistemos/Views/Notes/ProseEditorView.swift`
  - `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
  - `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
  - `Epistemos/Views/Notes/NoteWindowManager.swift`
  - `Epistemos/Sync/NoteFileStorage.swift`
  - `Epistemos/Sync/VaultSyncService.swift`
  - `Epistemos/Sync/SearchIndexService.swift`
  - `Epistemos/State/NoteChatState.swift`
  - `Epistemos/App/ChatCoordinator.swift`
  - `Epistemos/Engine/NoteInsightService.swift`
  - `Epistemos/State/WorkspaceService.swift`
  - `Epistemos/State/WorkspaceSummaryService.swift`
  - `Epistemos/State/TimeMachineService.swift`
  - `Epistemos/Views/Landing/TimeMachineView.swift`
  - `Epistemos/Graph/GraphState.swift`
  - `Epistemos/Graph/GraphStore.swift`
  - `Epistemos/Views/Graph/HologramOverlay.swift`
  - `Epistemos/Views/Graph/HologramNodeInspector.swift`
- Supporting tests were inspected, including:
  - `EpistemosTests/TK1MigrationValidationTests.swift`
  - `EpistemosTests/SearchIndexServiceIntegrationTests.swift`
  - `EpistemosTests/WorkspaceSnapshotTests.swift`
  - `EpistemosTests/RuntimeValidationTests.swift`
- `cargo test -q` in `graph-engine` passed:
  - `2434 passed, 0 failed, 8 ignored`

### Not Fully Verifiable In This Environment

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build` failed before the app finished building because upstream `mlx-swift` failed in `Source/Cmlx/fmt/src/format.cc` while building target `Cmlx`
- This means I could not complete a fresh full-app Swift build/test validation for the current tree in this environment

### Important Interpretation

The current release verdict is therefore based on:

- strong code-path evidence
- green Rust/graph-engine verification
- current UI/code reachability
- a blocked Swift build caused by an external dependency/toolchain issue, not by a clearly local app-source regression discovered during this pass

## 1. What Epistemos is today

Epistemos today is a native macOS note-thinking workspace built around local note bodies, SwiftData metadata, a production TK2 editor, and a hybrid vault bridge. The core user loop is real: connect a vault, create or open notes, edit in native note windows, search across notes and blocks, chat with note or vault context, and reopen your previous workspace later.

The product is not a generic LLM shell. The most convincing live identity is:

- a local-first writing and research environment
- with strong note-grounded AI assistance
- plus workspace/session memory
- plus graph and temporal exploration as advanced support tools

The most important truth-mapping detail is architectural: the app is not currently a pure live-Markdown-vault editor in the Obsidian sense. `Epistemos/Sync/VaultSyncService.swift` explicitly treats the vault as an import/export and sync boundary, while editing itself is driven by SwiftData metadata and Application Support note-body files via `Epistemos/Sync/NoteFileStorage.swift` and `Epistemos/Views/Notes/ProseEditorView.swift`.

## 2. What the papers promised

Across the research corpus, the papers promise four overlapping products:

1. A local-first personal knowledge system where truth is temporal and notes become time-aware epistemic states.
2. A semantic memory layer with instant recall, ambient retrieval, serendipity, gap detection, and cross-note synthesis.
3. A visually rich graph/time interface for navigating knowledge and session history.
4. A much larger Omega vision: dual-brain agents, computer use, Screen2AX, self-improving training loops, adapter routing, and hardware-native autonomy.

The first three are relevant to V1. The fourth is not.

## 3. What is already alive

- Local note creation, opening, and multi-window note work are alive in `Epistemos/Views/Landing/LandingView.swift` and `Epistemos/Views/Notes/NoteWindowManager.swift`.
- The production editor is alive and clearly pinned to TK2 in `Epistemos/Views/Notes/ProseEditorView.swift` and `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`.
- Search is alive and technically credible through `Epistemos/Sync/SearchIndexService.swift`, `Epistemos/Sync/VaultSyncService.swift`, and `Epistemos/Engine/QueryRuntime.swift`.
- Home chat with explicit note/vault attachment is alive in `Epistemos/Views/Landing/LandingView.swift` and `Epistemos/App/ChatCoordinator.swift`.
- Per-note inline AI assistance is alive in `Epistemos/State/NoteChatState.swift` and `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`.
- Workspace memory is alive in `Epistemos/State/WorkspaceService.swift` and `Epistemos/Views/Landing/LandingView.swift`.
- Session intelligence is alive in `Epistemos/State/WorkspaceSummaryService.swift` and `Epistemos/Views/Landing/SessionIntelligenceOverlay.swift`.
- Time Machine is alive as a real session-history surface in `Epistemos/State/EventStore.swift`, `Epistemos/State/TimeMachineService.swift`, and `Epistemos/Views/Landing/TimeMachineView.swift`.
- The graph is alive in `Epistemos/Graph/GraphState.swift`, `Epistemos/Graph/GraphStore.swift`, and `Epistemos/Views/Graph/HologramOverlay.swift`.
- Daily Brief is alive in `Epistemos/State/DailyBriefState.swift` and `Epistemos/App/AppCoordinator.swift`.

## 4. What is partially alive

- Ambient retrieval is only partially alive. The app has an ambient manifest, mention-driven context loading, and instant recall support, but it is not yet the fully reflexive “memory without search” system promised in the strongest research language. Evidence: `Epistemos/App/AppCoordinator.swift`, `Epistemos/Views/Landing/LandingView.swift`, `Epistemos/KnowledgeFusion/InstantRecallService.swift`, `Epistemos/State/NoteChatState.swift`.
- Cross-note serendipity and gap detection are partially alive. `Epistemos/Engine/NoteInsightService.swift`, `Epistemos/State/DialogueChatState.swift`, `Epistemos/State/DailyBriefState.swift`, and `Epistemos/State/WorkspaceSummaryService.swift` provide early pieces, but not a strong standalone “gap detector” product behavior.
- Time-aware knowledge is partially alive. Versions, snapshots, and diffs exist, but not a full belief-tracking or intellectual-autobiography layer. Evidence: `Epistemos/Models/SDPageVersion.swift`, `Epistemos/State/TimeMachineService.swift`.
- Prepared retrieval / continuous encoding foundations are partially alive, but not yet a clean user-visible promise. Evidence: `Epistemos/App/AppBootstrap.swift`, `Epistemos/Engine/QueryEngine.swift`, `Epistemos/Graph/GraphState.swift`.
- The time-machine paper’s immersive spatial/physics-heavy vision is only partially alive. The current `TimeMachineView` is functional and coherent, but much simpler than the paper.

## 5. What is missing

- A first-class, explicit belief-tracking model is missing. The app tracks notes, versions, sessions, and diffs, but not beliefs as first-class evolving entities.
- A strong, dedicated serendipity/gap-detection workflow is missing. The current app hints at it, but does not yet make it a primary product moment.
- The research promise of “collaborative knowledge without shared data” is not meaningfully present as a user-facing feature.
- The fully immersive temporal-navigation design language from the Time Machine paper is not present in current shipping UI.
- The strongest “ambient retrieval, no search step” promise is overstated relative to the current product surface.

## 6. What should be added before V1

Only high-leverage, low-risk, low-interference items belong here.

| Recommendation | Why it matters | Evidence | Training interference |
|---|---|---|---|
| Clarify the V1 story in onboarding and settings | The current first-run and settings copy still over-advertise Omega and training-era scope, which dilutes the real V1 identity | `Epistemos/Views/Onboarding/SetupAssistantView.swift`; `Epistemos/Views/Settings/SettingsView.swift` | None |
| Produce a clean, reproducible release build on the chosen Xcode/toolchain | A release cannot be signed off confidently while the current environment fails upstream in `mlx-swift` | current `xcodebuild` result; `mlx-swift` `Cmlx` `format.cc` failure | None |
| Run a focused manual release smoke on the actual release bundle | The core workflow should be validated end to end on the real build artifact: vault attach, note create/edit/save, search, note chat, graph open, workspace restore, time machine | core surfaces listed in the verification snapshot | None |
| Freeze a clean V1 branch/slice separate from ongoing Omega/training churn | The current working tree mixes core product work with deferred systems, which is a release-management risk even if the product scope is coherent | current `git status --short` shows heavy cross-scope ongoing work | None |
| Tighten release messaging around real strengths: notes, retrieval, note-grounded AI, workspace memory | The product is strongest when described honestly; overpromising ambient magic or autonomy hurts trust | research vs code matrix in `docs/RESEARCH_TO_APP_TRACEABILITY.md` | None |

## 7. What should wait until after V1

- Stronger ambient retrieval that works more automatically across every surface
- A dedicated gap-detector / contradiction-detector experience
- More ambitious temporal belief tracking and intellectual-autobiography tooling
- More immersive time-machine visualization work
- Larger graph refinements if they are not essential to the daily writing/research loop

These are good post-V1 directions precisely because the core app already lays some groundwork for them.

## 8. What is explicitly excluded

The following must not be used to fail or delay V1:

- Omega
- Agents
- computer use
- Screen2AX
- multi-agent orchestration
- app-control/browser-control flows
- nightly self-improvement loops
- autoresearch loops
- QLoRA/KTO training completion
- MoLoRA / adapter-routing completion
- model-tier migration work

These areas are real context in the repo, but they are a separate delivery track.

## 9. Training interference guardrails

Before V1, avoid changes that would:

- alter note corpus formatting in ways that affect future training data assumptions
- change retrieval/index formats in ways that invalidate prepared assets or require re-ingestion
- churn prompt/data contracts used by trace generation or adapter work
- destabilize MLX inference contracts or routing assumptions
- couple the core note app more tightly to Omega or training subsystems

The correct prelaunch polish set is overwhelmingly non-invasive. Most recommended V1 work should rate `None` for training interference.

## 10. Final release verdict

## READY FOR V1 WITH A SHORT FINAL POLISH PASS

### Why

- The core note-thinking app is real.
- The app already has a coherent identity if V1 is defined correctly.
- The strongest user value is already present in reachable code paths: native notes, search, note-grounded AI, workspace memory, and advanced graph/time tools.
- The biggest remaining risks are not “missing product pillars.” They are scope clarity, release packaging discipline, and final validation.

### Why not an unconditional READY FOR V1

- I could not complete a fresh full macOS build/test pass in this environment because `mlx-swift` failed upstream in `Cmlx` during `xcodebuild`.
- The current product narrative is still muddied by deferred Omega/training surfaces.
- Some research promises are still materially ahead of the product and need to stay out of launch language.

### Why not NOT READY FOR V1

- Judging the app against Omega/agent moonshots would be the wrong standard.
- The current codebase already supports a coherent, attractive, differentiated V1 slice.

## 11. What the app could become with more time

### +1 week

- cleaner onboarding and settings hierarchy
- clear V1 release copy
- reproducible release build
- validated manual smoke pass on the release artifact

### +2 to 4 weeks

- stronger ambient retrieval on more surfaces
- better cross-note surfacing and related-note explanations
- crisper graph/time-machine polish without changing the product boundary

### +1 to 2 months

- first-class gap detection
- explicit contradiction and belief-drift tooling
- stronger query/retrieval experiences built on the existing graph/search foundations

### Long-horizon North Star

- a real temporal epistemic system
- deeply personalized retrieval and knowledge synthesis
- optional agentic and computer-use layers
- optional training/fusion systems that sit on top of a stable, trusted note-thinking core rather than competing with it

## Release Risk Summary

### Highest Risks

- release narrative drift caused by Omega/training ambition
- inability to produce a clean release build on the intended toolchain
- overpromising ambient magic that the current UI does not consistently deliver

### Lowest-Risk, Highest-ROI Path

- freeze scope
- fix the build environment
- validate the core note workflow
- ship the app as the strong local-first thinking tool it already is
