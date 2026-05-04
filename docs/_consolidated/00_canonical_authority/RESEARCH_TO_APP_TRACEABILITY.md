# Research-to-App Traceability Audit

> **Index status**: CANONICAL — Research-to-App F01-F29 traceability matrix; honest "Alive / Alive but thin / Partial / Latent / Stub / Paper-only / Deferred / Conflicted" feature labels with file:line evidence.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/00_canonical_authority/`.



## Method

This matrix was built with the following authority order:

1. reachable production code and execution paths
2. current app surface definitions in SwiftUI/AppKit
3. current verification results
4. major product vision and research papers
5. lower-authority prompts, plans, and handoff docs

A feature is only marked `Alive` when there is clear end-to-end evidence in current code and a reachable user-facing surface.

## Source Inventory

### Canonical Source Groups

#### Core V1 product vision

- `/Users/jojo/Downloads/old research/EPISTEMOS-NORTH-STAR.md`
- `/Users/jojo/Downloads/old research/Epistemos  A New Paradigm for Time-Aware Personal Knowledge.md`
- `/Users/jojo/Downloads/old research/Epistemos_ Audit, Research, Design.md`
- `/Users/jojo/Downloads/old research/Designing Epistemos Time Machine UI.md`

#### Core UX, memory, notes, retrieval, and hardening support

- `/Users/jojo/Downloads/old research/Epistemos Editor Stack — Hardening Pass Audit Report.md`
- `/Users/jojo/Downloads/old research/TK1 to TK2 Migration Audit.md`
- `/Users/jojo/Downloads/old research/Optimizing Graph Initialization Performance.md`
- `/Users/jojo/Downloads/old research/Epistemos_Master_Remediation_Checklist.md`
- `docs/audit-progress.md`
- `docs/future-work-audit.md`

#### Training / inference / model work

- `/Users/jojo/Downloads/old research/On-Device AI Training System Research.md`
- `/Users/jojo/Downloads/old research/On-Device LLM Knowledge Fusion Research.md`
- `/Users/jojo/Downloads/old research/App-Specific Training + Multi-Scale Model Family  Deep Nuanced Pipelines for Nano Base Pro Device Agents.md`
- `/Users/jojo/Downloads/old research/EPISTEMOS-NANO-MASTER-TRAINING-GUIDE.md`
- `/Users/jojo/Downloads/old research/MLX Constrained Decoding Research.md`

#### Deferred Omega / Agents / autonomy

- `/Users/jojo/Downloads/old research/Mac AI Assistant Design Blueprint.md`
- `/Users/jojo/Downloads/old research/# OMEGA DEEP RESEARCH PROMPT_## For Google Deep Re.md`
- `/Users/jojo/Downloads/old research/Local AI Agent Architecture Research.md`
- `/Users/jojo/Downloads/old research/Epistemos Omega — Dual-Brain Hardware-Action Protocol  Deep Research Analysis & Master Execution Prompt.md`
- `/Users/jojo/Downloads/old research/Epistemos Omega — Supreme Master Execution Prompt for Claude Code.md`

### Deduplicated / Superseded Inputs

- `Cognitive OS & Local Model Blueprint.md` exists both at the root of `/Users/jojo/Downloads/old research` and inside `/Users/jojo/Downloads/old research/agents/`
- `Designing Epistemos Time Machine UI.md` exists both at the root of `/Users/jojo/Downloads/old research` and inside `/Users/jojo/Downloads/old research/ui/`
- `On-Device AI Training System Research.md` exists both at the root of `/Users/jojo/Downloads/old research` and inside `/Users/jojo/Downloads/old research/training/`
- `On-Device Knowledge Fusion Research Roadmap.md` exists both at the root of `/Users/jojo/Downloads/old research` and inside `/Users/jojo/Downloads/old research/old features that should be done/`
- `On-Device-AI-Training-System-Prompt.md`, `TurboQuant (PolarQuant + QJL) — Technical Deep Dive for Implementation.md`, and `epistemos-custom-mamba-model-blueprint.md` each exist in duplicate `(1)` copies

## Status Taxonomy

- `Alive` = real, reachable, and meaningful in the app today
- `Alive but thin` = real and reachable, but underpowered versus the paper promise
- `Partial` = some real wiring exists, but not enough to count as delivered
- `Latent` = implementation exists but is not a strong surfaced product behavior
- `Stub / Skeleton` = placeholder only
- `Paper-only` = described in research but not present in the app
- `Deferred` = intentionally excluded from V1 gating
- `Conflicted` = attractive on paper, but harmful to V1 focus or likely to interfere with deferred training work

## Normalized Research Moments

After deduplication, the research corpus resolves into these canonical moments:

- local-first vault-backed notes
- native writing and multi-window knowledge work
- semantic search and instant recall
- note-grounded AI help
- contextual vault memory
- session/workspace memory
- temporal navigation and historical reconstruction
- graph-based exploration
- serendipity / gap detection / cross-note synthesis
- personalized training and knowledge fusion
- dual-brain agentic automation and computer use

## Traceability Matrix

| ID | Canonical feature | Source doc(s) | Core / Optional / Deferred | Current evidence in code/UI | Status | User-visible today? | V1 importance | Effort | Risk | Training interference | Recommendation | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F01 | Local-first note bodies with vault connection | NS, TPK | Core | `Epistemos/Sync/NoteFileStorage.swift`; `Epistemos/Sync/VaultSyncService.swift`; `Epistemos/Views/Onboarding/SetupAssistantView.swift` | Alive | Yes | Critical | S | Low | None | Ship as-is | Actual architecture is hybrid: local body files + SwiftData during editing, vault as import/export/sync boundary rather than the live editing substrate. |
| F02 | Native note creation, opening, and multi-window tabbed notes | TPK, ARD | Core | `Epistemos/Views/Landing/LandingView.swift#createAndOpenNote`; `Epistemos/Views/Notes/NoteWindowManager.swift#open(pageId:)` | Alive | Yes | Critical | S | Low | None | Ship as-is | Strong evidence of a real document workflow, not just a chat shell. |
| F03 | Production TK2-only editor | Editor hardening docs, TK2 migration docs | Core | `Epistemos/Views/Notes/ProseEditorView.swift`; `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`; `EpistemosTests/TK1MigrationValidationTests.swift` | Alive | Yes | Critical | S | Low | None | Ship as-is | This is one of the clearest “alive” features in the repo. |
| F04 | Wikilinks, block references, and transclusion editing | TPK, Logseq-inspired design notes | Core | `Epistemos/Views/Notes/BlockRefAutocomplete2.swift`; `Epistemos/Views/Notes/TransclusionOverlayManager2.swift`; `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | Alive | Yes | Important | S | Medium | None | Ship as-is | This is real differentiating note UX. |
| F05 | Full-text note and block search | NS, TPK | Core | `Epistemos/Sync/SearchIndexService.swift`; `Epistemos/Engine/QueryRuntime.swift`; `EpistemosTests/SearchIndexServiceIntegrationTests.swift` | Alive | Yes | Critical | S | Low | None | Ship as-is | Search is materially real and better grounded than the papers sometimes imply. |
| F06 | Home chat with explicit note / vault context attachment | TPK, Bedroom PhD sections | Core | `Epistemos/Views/Landing/LandingView.swift#landingSearchPopoverContent`; `Epistemos/App/ChatCoordinator.swift#handleQuery` | Alive | Yes | Critical | S | Low | None | Ship as-is | This is one of the strongest bridges from “search” to “research” in the current app. |
| F07 | Per-note inline AI chat inside the editor | TPK, ARD | Core | `Epistemos/State/NoteChatState.swift`; `Epistemos/Views/Notes/ProseEditorRepresentable2.swift#wireNoteChatCallbacks`; `Epistemos/Views/Notes/NoteChatSidebar.swift` | Alive | Yes | Important | S | Medium | Low | Ship as-is | The inline divider workflow is real and distinctive. |
| F08 | Instant recall semantic retrieval for note chat | NS, TPK | Core | `Epistemos/KnowledgeFusion/InstantRecallService.swift`; `Epistemos/App/AppBootstrap.swift#instantRecallService.initialize()`; `Epistemos/State/NoteChatState.swift#instantRecallContext` | Alive but thin | Partially | Important | M | Medium | Medium | Tighten before launch | It is live, but only clearly visible through note chat rather than as a pervasive ambient memory layer. |
| F09 | Ambient vault manifest and mention-driven context loading | NS, TPK | Core | `Epistemos/App/AppCoordinator.swift#refreshAmbientManifest`; `Epistemos/Views/Landing/LandingView.swift`; `Epistemos/App/ChatCoordinator.swift#searchReferenceResults` | Alive but thin | Partially | Important | S | Low | Low | Ship as-is | Real, but still user-invoked rather than reflexive/ambient in the strong paper sense. |
| F10 | Related-note semantic recall and cross-note reasoning support | TPK, ARD | Optional | `Epistemos/Engine/NoteInsightService.swift`; `Epistemos/State/DialogueChatState.swift#buildRelatedNotesSection` | Alive but thin | Partially | Important | M | Medium | Low | Tighten before launch | Real cross-note support exists, but it is a support layer, not yet a flagship “serendipity engine.” |
| F11 | Workspace save/restore and welcome-back memory | ARD | Core | `Epistemos/State/WorkspaceService.swift`; `Epistemos/Views/Landing/LandingView.swift#welcomeBackContent`; `EpistemosTests/WorkspaceSnapshotTests.swift` | Alive | Yes | Important | S | Low | None | Ship as-is | Strongly aligned with the “memoryful workspace” story. |
| F12 | Session intelligence synthesis | ARD | Optional | `Epistemos/State/WorkspaceSummaryService.swift`; `Epistemos/Views/Landing/SessionIntelligenceOverlay.swift` | Alive | Yes | Important | S | Medium | Low | Ship as-is | This is a real differentiator if framed as an advanced session aid rather than a full agent. |
| F13 | Time Machine session history and state diffing | ARD, TMUI | Optional | `Epistemos/State/EventStore.swift`; `Epistemos/State/TimeMachineService.swift`; `Epistemos/Views/Landing/TimeMachineView.swift` | Alive but thin | Yes | Important | M | Medium | None | Tighten before launch | The core surface exists, but it is still a lightweight session-history tool, not the immersive temporal system described in the paper. |
| F14 | Temporal belief tracking / intellectual autobiography | NS, TPK | Optional | `Epistemos/Models/SDPageVersion.swift`; `Epistemos/State/TimeMachineService.swift` provide raw ingredients only | Partial | No | Nice-to-have | L | Medium | Medium | Defer to post-V1 | There is no explicit belief model, contradiction timeline, or first-class epistemic evolution UI. |
| F15 | Knowledge graph overlay and graph-native exploration | NS, TPK | Optional | `Epistemos/Graph/GraphState.swift`; `Epistemos/Graph/GraphStore.swift`; `Epistemos/Views/Graph/HologramOverlay.swift`; `Epistemos/Views/Graph/HologramNodeInspector.swift` | Alive | Yes | Important | M | Medium | None | Ship as-is | Real and visually meaningful, but it should not be the sole release identity. |
| F16 | Query language and graph/search result exploration | TPK, ARD | Optional | `Epistemos/Engine/QueryEngine.swift`; `Epistemos/Engine/QueryRuntime.swift`; `Epistemos/Views/Graph/QueryResultsView.swift` | Alive but thin | Partially | Nice-to-have | M | Medium | Low | Ship as-is | Powerful but still closer to an advanced surface than a mainstream V1 workflow. |
| F17 | Daily brief from recent notes/chats | TPK, ARD | Optional | `Epistemos/State/DailyBriefState.swift`; `Epistemos/App/AppCoordinator.swift#saveDailyBrief`; `Epistemos/Views/Landing/LandingView.swift#buildDailyBriefPrompt` | Alive | Yes | Nice-to-have | S | Low | Low | Ship as-is | A legitimate live feature; not enough by itself to carry the “serendipity engine” narrative. |
| F18 | Spotlight/system deep linking | NS | Optional | `Epistemos/Engine/SpotlightIndexer.swift`; `Epistemos/App/EpistemosApp.swift#onContinueUserActivity`; `Epistemos/Views/Notes/NoteWindowManager.swift#donateNoteActivity` | Alive | Yes | Nice-to-have | S | Low | None | Ship as-is | Good OS-native polish. |
| F19 | Local model install and local routing controls | NS, local-first model papers | Core | `Epistemos/Views/Onboarding/SetupAssistantView.swift`; `Epistemos/Views/Settings/SettingsView.swift#InferenceDetailView` | Alive | Yes | Important | S | Medium | Low | Ship as-is | Real, but the current onboarding copy still frames it partly around Omega, which muddies the V1 story. |
| F20 | Prepared retrieval runtime / continuous encoding foundation | NS, TPK | Optional | `Epistemos/App/AppBootstrap.swift`; `Epistemos/Engine/QueryEngine.swift`; `Epistemos/Graph/GraphState.swift`; `Epistemos/Sync/VaultSyncService.swift#rebuildIndex` | Partial | Partially | Nice-to-have | M | Medium | High | Defer to post-V1 | Foundation exists, but this is not yet a clean user-facing promise to headline. |
| F21 | Serendipity engine / gap detector / cross-note synthesis | TPK | Optional | Early approximations only: `NoteInsightService`, `DailyBriefState`, `WorkspaceSummaryService` | Partial | Partially | Important | M | Medium | Medium | Defer to post-V1 | The papers promise a stronger product behavior than the app currently delivers. |
| F22 | Collaborative knowledge without shared data | TPK | Optional | No convincing reachable implementation found in current app code | Paper-only | No | Nice-to-have | L | Low | Medium | Defer to post-V1 | Valuable idea, but not a V1 reality. |
| F23 | Immersive spatial / physics-rich time machine | TMUI | Optional | `Epistemos/Views/Landing/TimeMachineView.swift` is a clean overlay, but not the spatial Metal-driven temporal navigation described in the paper | Partial | Partially | Nice-to-have | L | Medium | None | Defer to post-V1 | The current implementation is a simpler, valid V1 slice. |
| F24 | Private, on-device-first posture | NS, TPK | Core | `Epistemos/Sync/NoteFileStorage.swift`; `Epistemos/Engine/Keychain.swift`; `Epistemos/Views/Settings/SettingsView.swift#Data Protection` | Alive but thin | Yes | Critical | S | Low | None | Ship as-is | Honest framing matters: the app is local-first, but not purely local-only because cloud API settings still exist. |
| F25 | Dual-brain device-action agent | NS, MAA, Omega docs | Deferred | `Epistemos/Omega/**`; `Epistemos/Views/Settings/OmegaSettingsDetailView.swift`; `Epistemos/Intents/Custom/OmegaIntent.swift` | Deferred | Yes, but deferred | Deferred | L | High | High | Exclude entirely | This exists in the tree, but it must not gate V1. |
| F26 | Computer-use perception stack / Screen2AX | NS, MAA, Omega docs | Deferred | `Epistemos/Omega/Vision/Screen2AXFusion.swift`; onboarding permission copy in `SetupAssistantView.swift` | Deferred | Partially | Deferred | L | High | High | Exclude entirely | Strong scope-creep risk for release messaging. |
| F27 | Multi-agent orchestration and tool-use planning | Omega docs | Deferred | `Epistemos/Omega/Orchestrator/OrchestratorState.swift`; `Epistemos/Omega/MCPBridge.swift` | Deferred | Partially | Deferred | L | High | High | Exclude entirely | A separate product track for release purposes. |
| F28 | Knowledge-fusion training, QLoRA/KTO, replay, MoLoRA | ODTS, KF | Deferred | `Epistemos/KnowledgeFusion/**`; `docs/TRAINING_GUIDE.md` | Deferred | Yes, but deferred | Deferred | L | High | High | Exclude entirely | Valuable long-term foundation, but absolutely not a V1 ship gate. |
| F29 | Model-tier migration, adapter routing evolution, and trace-generation assumptions | NS, ODTS, KF | Conflicted | `Epistemos/Engine/LocalModelInfrastructure.swift`; `Epistemos/State/InferenceState.swift`; `Epistemos/KnowledgeFusion/**` | Conflicted | No | Deferred | L | High | High | Exclude entirely | Any late churn here would create retraining debt and destabilize the release story. |

## Summary Read

### Already Real Enough To Define V1

- F01-F07
- F11-F13
- F15
- F17-F19
- F24

### Real But Still Thin

- F08-F10
- F13
- F16
- F20-F21

### Not Real Enough To Promise

- F14
- F22
- F23 as currently described in the research language

### Explicitly Deferred

- F25-F29
