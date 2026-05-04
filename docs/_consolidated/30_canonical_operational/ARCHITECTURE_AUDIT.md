# Architecture Audit

> **Index status**: CANONICAL-OPERATIONAL — Phase A snapshot of identity inventory (string UUIDs/integer IDs/file-system paths) + UniFFI usage + observation patterns.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



Date: 2026-04-03
Scope: Phase A Workstream 2, Substrate Sprint 0 baseline

This document captures the current architecture substrate before any identity or FFI refactor work. It is an inventory, not a redesign. It follows the substrate laws from `docs/UNIFIED_SUBSTRATE_RESEARCH.md`: measure first, avoid speculative rewrites, and treat identity unification as the first real migration step.

## Snapshot

- Canonical persisted identity is still primarily string-based, with most SwiftData models using `String` IDs containing `UUID().uuidString`.
- Runtime and orchestration code still introduce separate `UUID` identity domains for runs, experiments, confirmations, adapters, and agent steps.
- Substrate and storage systems also rely on integer identity (`Int`, `Int64`, SQLite `rowid`, compact graph indices).
- File-system paths are used as identity in note persistence, vault routing, vault dedupe, and recovery flows.
- Legacy observation wrappers are effectively gone: no live `@StateObject`, `@ObservedObject`, or `ObservableObject` usages were found in source under `Epistemos/` or `EpistemosTests/`.
- Current UniFFI usage is concentrated in user-action and lifecycle paths. No render-loop hot path currently crosses UniFFI.
- Python is already mostly subprocess-isolated, but two production launch paths still originate from `@MainActor`.

## 1. Identity Inventory

### 1.1 String IDs

Primary persisted model identity is `String`, usually initialized from `UUID().uuidString`.

Canonical persisted `String` IDs:

- `Epistemos/Models/SDPage.swift:23`
- `Epistemos/Models/SDChat.swift:16`
- `Epistemos/Models/SDMessage.swift:15`
- `Epistemos/Models/SDGraphNode.swift:16`
- `Epistemos/Models/SDGraphEdge.swift:16`
- `Epistemos/Models/SDFolder.swift:17`
- `Epistemos/Models/SDBlock.swift:18`
- `Epistemos/Models/SDModelProfile.swift:19`
- `Epistemos/Models/SDWorkspace.swift:10`
- `Epistemos/Models/SDPageVersion.swift:19`
- `Epistemos/Models/SDPage.swift:312` (`NoteIdea.id`)

String foreign keys and denormalized references:

- `Epistemos/Models/SDPage.swift:49` `filePath`
- `Epistemos/Models/SDPage.swift:104` `parentPageId`
- `Epistemos/Models/SDPage.swift:107` `templateId`
- `Epistemos/Models/SDChat.swift:22` `linkedPageId`
- `Epistemos/Models/SDBlock.swift:22` `pageId`
- `Epistemos/Models/SDBlock.swift:26` `parentBlockId`
- `Epistemos/Models/SDGraphEdge.swift:19` `sourceNodeId`
- `Epistemos/Models/SDGraphEdge.swift:20` `targetNodeId`
- `Epistemos/Models/SDWorkspace.swift:38` `activeChatId`
- `Epistemos/Models/SDWorkspace.swift:43` `activeNoteTabPageId`
- `Epistemos/Models/SDWorkspace.swift:78` `rootPageId`
- `Epistemos/Models/SDWorkspace.swift:79` `currentPageId`
- `Epistemos/Models/SDWorkspace.swift:98` `selectedNodeId`
- `Epistemos/Models/SDNoteInsight.swift:10` `pageId`
- `Epistemos/Models/SDModelProfile.swift:28` `vaultIdentityKey`

Operational note:

- Notes are already effectively centered on `SDPage.id` as the dominant canonical content identity. This is the cleanest first candidate for a future `EntityID` bridge.

### 1.2 UUID IDs

Distinct runtime `UUID` identity still appears across orchestration, pipeline, and knowledge-fusion domains.

Representative locations:

- `Epistemos/Vault/VaultChatMutator.swift:71` `DiffResult.id`
- `Epistemos/Vault/ConversationPersistence.swift:10` `ConversationTurn.id`
- `Epistemos/Vault/ConversationPersistence.swift:11` `ConversationTurn.parentID`
- `Epistemos/Engine/PipelineService.swift:37` `activeRunID`
- `Epistemos/Engine/MLXInferenceService.swift:193` `StreamingTask.id`
- `Epistemos/State/UIState.swift:45`
- `Epistemos/Omega/Agents/OmegaAgent.swift:26`
- `Epistemos/Omega/Agents/OmegaAgent.swift:56`
- `Epistemos/Omega/Orchestrator/ConfirmationGate.swift:18`
- `Epistemos/Omega/Orchestrator/ConfirmationGate.swift:107`
- `Epistemos/Omega/Orchestrator/ResearchPause.swift:60`
- `Epistemos/KnowledgeFusion/Autoresearch/AutoresearchLoop.swift:7`
- `Epistemos/KnowledgeFusion/Autoresearch/ExperimentTracker.swift:46`
- `Epistemos/KnowledgeFusion/SkillGeneration/SkillManifest.swift:6`
- `Epistemos/KnowledgeFusion/Adapters/AdapterRegistry.swift:13`
- `Epistemos/KnowledgeFusion/Adapters/AdapterExporter.swift:174`
- `Epistemos/KnowledgeFusion/DataIngestion/DocumentChunker.swift:12`
- `Epistemos/KnowledgeFusion/DataIngestion/DocumentChunker.swift:13`
- `Epistemos/KnowledgeFusion/DataIngestion/VaultParser.swift:25`
- `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift:13`

Operational note:

- These UUID domains are mostly ephemeral or orchestration-scoped today, but they complicate any attempt to reason about a single canonical identity substrate across notes, agents, runs, and artifacts.

### 1.3 Int and Int64 IDs

Integer identity is already entrenched in substrate storage and compact indexes.

Representative locations:

- `Epistemos/State/CognitiveSubstrateTypes.swift:8`
- `Epistemos/State/CognitiveSubstrateTypes.swift:20`
- `Epistemos/State/CognitiveSubstrateTypes.swift:35`
- `Epistemos/State/CognitiveSubstrateTypes.swift:44`
- `Epistemos/State/EventStore.swift:101`
- `Epistemos/State/EventStore.swift:113`
- `Epistemos/State/EventStore.swift:126`
- `Epistemos/State/EventStore.swift:141`
- `Epistemos/State/EventStore.swift:160`
- `Epistemos/State/EventStore.swift:172`
- `Epistemos/Harness/HarnessLab.swift:1110`
- `Epistemos/Harness/HarnessLab.swift:1343`
- `Epistemos/Sync/SearchIndexService.swift:280`
- `Epistemos/Sync/SearchIndexService.swift:291`
- `Epistemos/Agent/HermesMCPClient.swift:37`
- `Epistemos/Agent/HermesMCPClient.swift:44`
- `Epistemos/Agent/HermesSubprocessManager.swift:1149`
- `Epistemos/Graph/GraphStore.swift:150` `_nodeIdx`
- `Epistemos/Graph/GraphStore.swift:156` `_edgeIdx`
- `Epistemos/Graph/GraphStore.swift:352` compact node index rebuild
- `Epistemos/Graph/GraphStore.swift:376` compact edge index rebuild

Operational note:

- The graph store is already halfway to substrate-style numeric identity internally, but it still projects string IDs at the public API boundary.

### 1.4 File Path as Identity

Path strings are acting as identity in multiple places, especially around note persistence and vault routing.

Representative locations:

- `Epistemos/Models/SDPage.swift:49` absolute `filePath` for note source of truth
- `Epistemos/Models/SDFolder.swift:45` derived `relativePath`
- `Epistemos/Vault/VaultChatMutator.swift:75` `DiffResult.relativePath`
- `Epistemos/Vault/VaultChatMutator.swift:270` `targetVault.relativeMemoryPath`
- `Epistemos/Vault/VaultChatMutator.swift:271` file resolution via `repositoryRootURL.appendingPathComponent(relativePath)`
- `Epistemos/Vault/VaultRegistry.swift:76` dedupe on `entry.rootURL.path`
- `Epistemos/Vault/VaultRegistry.swift:99` path-based sort
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:2872` `filePath`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:2984` recovery flow persists absolute file path

Operational note:

- Path identity is legitimate for vault and recovery workflows, but it is not stable enough to become the canonical cross-substrate identity for notes or agents.

## 2. Legacy Observation Inventory

Search result:

- No live `@StateObject` occurrences in `Epistemos/` or `EpistemosTests/`
- No live `@ObservedObject` occurrences in `Epistemos/` or `EpistemosTests/`
- No live `ObservableObject` protocol conformances in `Epistemos/` or `EpistemosTests/`

Implication:

- There are no remaining legacy observable wrappers to migrate as part of substrate work.
- No legacy wrapper currently holds canonical state because none are present.

Canonical state does still exist, but it lives in `@Observable` reference types instead:

- `Epistemos/State/InferenceState.swift`
- `Epistemos/Graph/GraphState.swift`
- `Epistemos/State/ChatState.swift`
- `Epistemos/State/NoteChatState.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Agent/HermesSubprocessManager.swift`
- `Epistemos/ViewModels/AgentViewModel.swift`

Substrate implication:

- Identity and threading work can proceed without a parallel legacy observation cleanup stream.

## 3. UniFFI Call Sites

### 3.1 High Frequency

No high-frequency render-loop UniFFI call sites were found in current Swift source.

Observed hot-path behavior:

- Graph rendering uses the Rust graph engine through the existing C ABI bridge, not UniFFI.
- No current SwiftUI render loop, Metal frame loop, or hover loop appears to call UniFFI directly.

This supports Law 4 from the substrate research: keep UniFFI unless measurement proves a real hotspot.

### 3.2 Medium Frequency

These call sites run on user action, ingestion flows, agent actions, or orchestration steps.

| File | UniFFI module | Calls | Why this is medium frequency |
| --- | --- | --- | --- |
| `Epistemos/KnowledgeFusion/InstantRecallService.swift` | `epistemos_core` | `instantRecallCreate`, `instantRecallCount`, `instantRecallClear`, `instantRecallInsert`, `instantRecallRemove`, `instantRecallSearch` | Triggered by note indexing, note removal, and recall search during chat work |
| `Epistemos/KnowledgeFusion/DataIngestion/VaultParser.swift` | `epistemos_core` | `classifyDocument`, `filterBoilerplate` | Runs during vault/document ingestion |
| `Epistemos/KnowledgeFusion/DataIngestion/DocumentChunker.swift` | `epistemos_core` | `chunkDocument`, `estimateTokens` | Runs during ingestion and chunk generation |
| `Epistemos/KnowledgeFusion/SyntheticData/QualityCurator.swift` | `epistemos_core` | `scoreTrainingPair`, `dedupTexts` | Runs during synthetic data curation passes |
| `Epistemos/KnowledgeFusion/Adapters/AdapterRouter.swift` | `epistemos_core` | `routePrompt` | Runs per routed prompt, not per frame |
| `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | `epistemos_core` | `classifyCorruption`, `repairMojibake`, `extractTextFromBinary` | Invoked during explicit recovery/repair flows |
| `Epistemos/KnowledgeFusion/SyntheticData/EmbodiedCaptureService.swift` | `omega_ax` | `walkAxTreeJson` | Invoked during embodied capture |
| `Epistemos/Omega/Agents/GhostComputerAgent.swift` | `omega_ax` | `clickElementByName`, `simulateClick`, `simulateTypeText`, `simulateKeyPress` | Runs during agent actuation, not app rendering |
| `Epistemos/Omega/Agents/AutomationAgent.swift` | `omega_ax` | `simulateTypeText`, `simulateKeyPress`, `runShortcutByName`, `clickElementByName`, `simulateClick` | Runs during automation execution |
| `Epistemos/Omega/Agents/SafariAgent.swift` | `omega_mcp` | `toolOpenUrl`, `toolGetPageUrl`, `toolGetPageTitle`, `toolSearchWeb`, `toolGetPageText` | Explicit browser tool usage |
| `Epistemos/Omega/Agents/TerminalAgent.swift` | `omega_mcp` | `toolRunCommand`, `ptyExecuteCommand`, `ptySpawnSession` | Explicit terminal tool usage |
| `Epistemos/ViewModels/AgentViewModel.swift` | `omega_mcp` | `ptySpawnSession`, `ptyExecuteCommand`, `ptyCloseSession` | Agent session interaction and terminal lifecycle |
| `Epistemos/Omega/MCPBridge.swift` | `omega_mcp` | `dispatch`, `logExecution`, `recentExecutionsJson` | Runtime tool dispatch and logging |
| `Epistemos/Omega/Orchestrator/OrchestratorState.swift` | `omega_mcp` | `generateHeuristicPlan`, `validateAgentTool`, `evaluateRiskConfirmation` | Runs per orchestration decision cycle |

### 3.3 Low Frequency

These call sites are lifecycle, integrity, or bootstrap oriented.

| File | UniFFI module | Calls | Why this is low frequency |
| --- | --- | --- | --- |
| `Epistemos/Sync/NoteFileStorage.swift` | `epistemos_core` | `sanitizeAndNormalize`, `uniffi_epistemos_core_fn_func_content_hash_bytes`, `uniffi_epistemos_core_fn_func_verify_content_hash`, `uniffi_epistemos_core_fn_func_full_sync_fd` | Write integrity, normalization, hashing, and durable write checks |
| `Epistemos/Omega/OmegaPermissions.swift` | `omega_ax` | `checkPermissions` | Permission checks are lifecycle or explicit settings actions |
| `Epistemos/Omega/MCPBridge.swift` | `omega_mcp` | `builtinToolsJson`, `McpDispatcher`, `registerBuiltinTools`, `toolCount`, `executionCount` | Catalog bootstrap and dispatcher setup |

Substrate implication:

- Current evidence does not justify replacing UniFFI with C ABI on any Phase A path.
- The only obvious render-loop FFI sensitivity remains the existing graph engine bridge, which is already separate from UniFFI.

## 4. Python Invocation Audit

Only Python-related subprocess paths are listed here. Non-Python `Process` usage such as `git`, screen capture helpers, and shell tools is excluded.

| File | Actor / thread context | Launch style | Main-thread risk | Notes |
| --- | --- | --- | --- | --- |
| `Epistemos/Agent/HermesSubprocessManager.swift` | `@MainActor` | `Process.run()` inside `launch()` | Yes | Production Hermes runtime launch still originates on the main actor |
| `Epistemos/KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift` | `@MainActor` | `Process.run()` inside `start(...)` | Yes | Long-lived Python inference subprocess launched from the main actor |
| `Epistemos/KnowledgeFusion/PythonEnvironmentManager.swift` | `@MainActor` wrapper, but execution is `nonisolated` on `DispatchQueue.global(qos: .utility)` | Off-main subprocess execution | No | Good match for Law 5 direction |
| `Epistemos/Agent/HermesSetupService.swift` | `@MainActor` wrapper, but execution is `nonisolated` on a global queue | Off-main subprocess execution | No | Setup path already separated from main-thread execution |
| `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift` | `actor` | Actor-isolated subprocess launch | No | Off-main training flow |
| `Epistemos/KnowledgeFusion/Alignment/KTOTrainer.swift` | `actor` | Actor-isolated subprocess launch | No | Off-main training flow |
| `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift` | `actor` | Actor-isolated subprocess launch | No | Off-main transcription flow |

Immediate substrate finding:

- Law 5 is not fully satisfied yet because Hermes and MoLoRA still launch Python from `@MainActor`.

## 5. Binary Size Baseline

### 5.1 Rust static archives (`nm` + archive size)

Measurements from current release archives:

| Component | Archive path | Size (bytes) | `nm -gU` line count |
| --- | --- | ---: | ---: |
| `graph-engine` | `graph-engine/target/aarch64-apple-darwin/release/libgraph_engine.a` | 59,359,288 | 33,681 |
| `epistemos-core` | `epistemos-core/target/aarch64-apple-darwin/release/libepistemos_core.a` | 16,919,816 | 15,984 |
| `omega-mcp` | `omega-mcp/target/aarch64-apple-darwin/release/libomega_mcp.a` | 10,093,832 | 4,199 |
| `omega-ax` | `omega-ax/target/aarch64-apple-darwin/release/libomega_ax.a` | 6,380,632 | 2,505 |

Interpretation:

- `graph-engine` remains the largest native binary payload by a wide margin.
- `epistemos-core` is already substantial enough that any new substrate-core crate should avoid accidental duplication with it.

### 5.2 Embedded native dylibs in the verified release app

Measured from `build/verify-derived-data/Build/Products/Release/Epistemos.app/Contents/Frameworks`:

| Embedded dylib | Size (bytes) | `nm -gU` line count |
| --- | ---: | ---: |
| `libepistemos_core.dylib` | 5,389,312 | 118 |
| `libomega_mcp.dylib` | 4,973,280 | 117 |
| `libomega_ax.dylib` | 1,078,320 | 73 |

Related note:

- `graph-engine` is not shipped as a separate dylib in that verified release artifact, so its weight is absorbed into the app binary itself.

### 5.3 Swift / app binary baseline

Current stable Swift-side measurement:

- Verified release app binary: `build/verify-derived-data/Build/Products/Release/Epistemos.app/Contents/MacOS/Epistemos`
- Size: 224,842,752 bytes

Link-map status:

- Debug link map was generated at `~/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Intermediates.noindex/Epistemos.build/Debug/Epistemos.build/Epistemos-LinkMap-normal-arm64.txt`.
- That debug map is not representative of real Swift code composition because the Debug app binary is a lightweight launcher around `Epistemos.debug.dylib`.
- A one-off Release link-map build with `LD_GENERATE_MAP_FILE=YES` was started to capture a fuller Swift-side object breakdown; until that completes, the release app binary size above is the stable baseline.

### 5.4 Assets

Measured asset and resource directory sizes:

| Path | Size |
| --- | ---: |
| `Epistemos/Assets.xcassets` | 20 KB |
| `Epistemos/Resources` | 36 KB |
| `Epistemos/Shaders` | 4 KB |

Interpretation:

- Asset payload is negligible relative to native binary size.
- Binary growth, not art assets, is the primary substrate-size pressure today.

## Conclusions

1. Identity is fragmented across four real shapes today: string UUIDs, runtime UUIDs, integer substrate IDs, and path identity. Notes are the right first migration slice.
2. There is no legacy `ObservableObject` cleanup blocking substrate work.
3. UniFFI is not presently a render-loop problem. Do not replace it preemptively.
4. Python is already mostly out-of-process, but Hermes and MoLoRA still violate the spirit of the "Python out-of-process immediately" law by launching from `@MainActor`.
5. The biggest measurable native weight is still the graph engine and the monolithic release app binary, not assets.
