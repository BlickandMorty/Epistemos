# Codebase Cartography

Date: 2026-04-28
Scope: Phase 2A cartography for Master Hardening + Wiring Audit.

This document maps where the major systems live and separates live product paths from scaffold, gated, or unproven paths. It is evidence-first; "Live" means a route appears to exist in the app, not that the route is release-ready.

## Directory-Level Architecture Map

| Directory | Role | Evidence | Risk |
|---|---|---|---|
| `Epistemos/App/` | App bootstrap, environment, chat coordination, policy profile checks. | `Epistemos/App/AppBootstrap.swift`, `Epistemos/App/ChatCoordinator.swift` | P0: launch, routing, and policy mistakes break normal app use. |
| `Epistemos/Views/` | SwiftUI/AppKit user surfaces. | `Epistemos/Views/Notes/`, `Epistemos/Views/Graph/`, `Epistemos/Views/Epdoc/`, `Epistemos/Views/RawThoughts/`, `Epistemos/Views/Recall/` | P1: several surfaces exist but need reachability proof. |
| `Epistemos/Engine/` | Service layer: LLMs, agents, `.epdoc`, command parsing, recall/halo bridge, code editor controllers. | `Epistemos/Engine/LLMService.swift`, `Epistemos/Engine/EpdocDocument.swift`, `Epistemos/Engine/LiveCodeEditorController.swift` | P1: many services can outpace UI wiring. |
| `Epistemos/Models/` | SwiftData/domain models and typed artifacts. | `Epistemos/Models/SDPage.swift`, `Epistemos/Models/Artifact.swift`, `Epistemos/Models/ArtifactKind.swift`, `Epistemos/Models/EpdocPackage.swift` | P0/P1: source-of-truth and migration mistakes risk data loss. |
| `Epistemos/Graph/` | Graph state, storage, extraction, labels, background graph actor. | `Epistemos/Graph/GraphState.swift`, `Epistemos/Graph/GraphStore.swift`, `Epistemos/Graph/BackgroundGraphActor.swift` | P1: graph must stay smooth and incremental. |
| `Epistemos/Sync/` | Vault sync, file I/O, search index, indexing actors. | `Epistemos/Sync/VaultSyncService.swift`, `Epistemos/Sync/SearchIndexService.swift`, `Epistemos/Sync/VaultIndexActor.swift` | P0: user data and index consistency. |
| `Epistemos/Vault/` | Vault lifecycle, chat transcript persistence, lineage, session browser, knowledge graph services. | `Epistemos/Vault/VaultRegistry.swift`, `Epistemos/Vault/AgentSessionLineageStore.swift`, `Epistemos/Vault/ChatTranscriptVaultWriter.swift` | P1: Raw Thoughts/run artifacts need coherent surfacing. |
| `Epistemos/KnowledgeFusion/` | Instant recall, recall context, ingestion/training. | `Epistemos/KnowledgeFusion/InstantRecallService.swift`, `Epistemos/KnowledgeFusion/RecallContextSnapshot.swift` | P1: likely differentiator, not yet proven user-wired. |
| `Epistemos/Omega/` | Agent/Omega/MCP/computer-use/vision systems. | `Epistemos/Omega/MCPBridge.swift`, `Epistemos/Omega/Agents/GhostComputerAgent.swift`, `Epistemos/Omega/Vision/ScreenCaptureService.swift` | P0 for MAS: powerful features must stay gated/hidden. |
| `Epistemos/AppStore/` | MAS-specific stubs and safety gates. | `Epistemos/AppStore/AppStoreComputerUseStubs.swift` | P0: stubs must prevent unsafe App Store behavior. |
| `Epistemos/Resources/` | Privacy manifest, launch agents, resources. | `Epistemos/Resources/PrivacyInfo.xcprivacy`, `Epistemos/Resources/LaunchAgents/com.epistemos.nightbrain.plist` | P0/P1: privacy and launch-helper review risk. |
| `graph-engine/` | Rust graph/knowledge/physics core. | `graph-engine/src/lib.rs`, `graph-engine/src/knowledge_core/` | P1: FFI/perf work needs layout and fallback proof. |
| `graph-engine-bridge/` | C/Swift bridge header. | `graph-engine-bridge/graph_engine.h` | P1: bridge drift can break Swift/Rust contracts. |
| `agent_core/` | Rust agent loop and tool registry. | `agent_core/src/` | P1: run persistence/provenance and MAS gates need proof. |
| `omega-mcp/`, `omega-ax/` | MCP and accessibility/computer-use support crates. | `omega-mcp/`, `omega-ax/` | P0 for MAS: external automation must be hidden/direct-build-only. |
| `EpistemosTests/` | Swift tests and benchmark harnesses. | `EpistemosTests/`, `EpistemosTests/Benchmarks/` | P1: many claims still require focused tests/perf gates. |

## Live App Entry Points

| Entry point | Evidence | Notes |
|---|---|---|
| App bootstrap | `Epistemos/App/EpistemosApp.swift`, `Epistemos/App/AppBootstrap.swift` | Primary runtime setup; policy-profile checks and environment injection must stay centralized. |
| Main notes/editor route | `Epistemos/Views/Notes/ProseEditorView.swift`, `Epistemos/Views/Notes/NoteWindowManager.swift` | Live and protected. |
| Chat route | `Epistemos/App/ChatCoordinator.swift`, `Epistemos/State/NoteChatState.swift`, `Epistemos/Views/Chat/` | Live; performance and provider routing need audit. |
| Graph route | `Epistemos/Graph/GraphState.swift`, `Epistemos/Views/Graph/MetalGraphView.swift` | Live; renderer/physics are protected. |
| `.epdoc` document route | `Epistemos/Engine/EpdocDocument.swift`, `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`, `Epistemos-AppStore-Info.plist` | Partial live path; full user workflow needs proof. |
| Raw Thoughts route | `Epistemos/Views/RawThoughts/RawThoughtsSection.swift`, `EpistemosTests/RawThoughtsStateTests.swift` | Surface exists; persistence/timeline completeness needs proof. |
| Recall/Halo route | `Epistemos/Views/Recall/`, `Epistemos/Engine/HaloController.swift`, `Epistemos/Engine/HaloEditorBridge.swift` | Surface/service exists; note/chat active typing flow needs proof. |
| Command Center route | `Epistemos/Engine/CommandInputParser.swift`, `Epistemos/Engine/CommandCenterRequestCompiler.swift` | Parser/compiler exist; UI reachability needs proof. |
| Settings/privacy/model route | `EpistemosTests/SettingsCategoryTests.swift`, `Epistemos/Resources/PrivacyInfo.xcprivacy`, model infrastructure files | Visible settings likely live; exact category/copy needs audit. |

## Feature / System Map

| System | Main files | Live? | UI surface? | Bridge? | Risk | Notes |
|---|---|---|---|---|---|---|
| Prose editor | `Epistemos/Views/Notes/ProseEditorView.swift`; `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`; `Epistemos/Views/Notes/ProseTextView2.swift` | Yes | Yes | AppKit/TextKit | P0 | Protected; no edits without explicit perf/regression proof. |
| Markdown/prose pipeline | `Epistemos/Views/Notes/MarkdownContentStorage.swift`; `Epistemos/Models/ProseMirrorMarkdownProjector.swift` | Yes/Partial | Yes | None | P1 | Markdown is prose source/projection, not rich Document authority. |
| Documents / `.epdoc` | `Epistemos/Engine/EpdocDocument.swift`; `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`; `Epistemos-AppStore-Info.plist` | Partial | Partial | WKWebView/AppKit | P1 | Built stub/host exists; full Tiptap workflow and projection recovery need proof. |
| Code editor | `Epistemos/Engine/LiveCodeEditorController.swift`; `Epistemos/Engine/CodeEditorContentDebouncer.swift`; `Epistemos/Models/CodeArtifactSidecar.swift` | Partial | Partial | Possible syntax/FFI | P1 | Needs line-number gutter, 4k-line perf, syntax on, UTF-8/UTF-16 tests. |
| Ambient Recall/Halo | `Epistemos/KnowledgeFusion/InstantRecallService.swift`; `Epistemos/Engine/HaloController.swift`; `Epistemos/Engine/HaloEditorBridge.swift`; `Epistemos/Views/Recall/` | Partial | Partial | Search/embedding/index | P1 | Likely V1 differentiator; active typing panel path needs proof. |
| Graph renderer | `Epistemos/Graph/GraphState.swift`; `Epistemos/Graph/GraphStore.swift`; `Epistemos/Views/Graph/MetalGraphView.swift`; `graph-engine/src/lib.rs` | Yes | Yes | Rust/C/Metal | P1 | Keep protected; prove smooth pan/zoom and no full rebuilds. |
| Graph physics | `graph-engine/src/physics.rs`; `Epistemos/Graph/GraphState.swift` | Yes | Yes | Rust/C | P1 | Recursive physics/perf audit needed before tuning. |
| Search/retrieval | `Epistemos/Sync/SearchIndexService.swift`; `Epistemos/Models/QueryTypes.swift`; `EpistemosTests/SearchIndexTests.swift` | Yes/Partial | Yes | SQLite/FTS/service | P1 | Universal readable block projection is not fully proven. |
| Embeddings | `Epistemos/Graph/EmbeddingService.swift`; `Epistemos/Graph/SemanticClusterService.swift`; `EpistemosTests/BlockEmbeddingTests.swift` | Partial | Indirect | Model/vector index | P1 | Backgrounding, rebuild, and privacy copy need audit. |
| Local models | `Epistemos/Engine/LocalModelInfrastructure.swift`; `Epistemos/Engine/ModelDownloadManager.swift`; `Epistemos/Models/SDModelProfile.swift` | Partial/Yes | Yes | MLX/local runtime | P1 | Storage footprint and installed/available UX are MAS concerns. |
| Cloud providers | `Epistemos/Engine/LLMService.swift`; `Epistemos/Engine/OpenAICompatibleChatSupport.swift` | Partial/Yes | Yes | Network providers | P1 | Privacy wording and provider capability labels must be exact. |
| Chat/streaming | `Epistemos/App/ChatCoordinator.swift`; `Epistemos/State/NoteChatState.swift`; `Epistemos/Views/Chat/` | Yes | Yes | LLM/agent/provider | P0 | Need no per-token DB/UI cascade proof. |
| Agent runtime | `Epistemos/Engine/AgentRuntime.swift`; `Epistemos/LocalAgent/LocalAgentLoop.swift`; `agent_core/src/` | Partial/Yes | Partial | Rust tools/MCP | P1 | Minimal stable V1 path or hide unstable toggles. |
| MCP bridge | `Epistemos/Omega/MCPBridge.swift`; `Epistemos/Bridge/ChunkedMCPFraming.swift`; `omega-mcp/` | Partial | Advanced/unknown | MCP/server | P1 | External/user MCP must be gated from MAS. |
| Computer use | `Epistemos/Bridge/ComputerUseBridge.swift`; `Epistemos/AppStore/AppStoreComputerUseStubs.swift`; `Epistemos/Omega/Agents/GhostComputerAgent.swift` | Partial | Advanced/unknown | AX/ScreenCapture/events | P0 | Direct-build-only unless App Store safe path is proven. |
| Quick capture | `Epistemos/Engine/TextCapturePipeline.swift`; `EpistemosTests/TextCapturePipelineTests.swift` | Partial | Unknown/Partial | Vault/search/graph | P2 | Needs discoverable entry and safe write proof. |
| Audio/transcription | `Epistemos/KnowledgeFusion/DataIngestion/AudioRecorder.swift`; `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift`; `Epistemos/Engine/ComposerVoiceInputService.swift` | Partial | Partial | Speech/mic | P2 | Permission denial and local/cloud speech disclosure need audit. |
| Settings/privacy/model manager | `Epistemos/Resources/PrivacyInfo.xcprivacy`; `EpistemosTests/SettingsCategoryTests.swift`; model infrastructure files | Yes/Partial | Yes | Preferences/model services | P1 | Settings count/copy drift is a known test target. |
| Command palette/center | `Epistemos/Engine/CommandInputParser.swift`; `Epistemos/Engine/CommandCenterRequestCompiler.swift`; `Epistemos/Models/CommandTokenizer.swift` | Partial | Needs verification | Agent/tool services | P2 | Parser is built; menu/shortcut reachability needs proof. |
| Vault/file watcher | `Epistemos/Sync/VaultSyncService.swift`; `Epistemos/Sync/VaultIndexActor.swift`; `Epistemos/Vault/VaultRegistry.swift` | Yes | Yes | File system/SwiftData | P0 | Security-scoped bookmarks and move/delete propagation need audit. |
| Database/persistence | `Epistemos/Models/`; `Epistemos/Engine/EpdocDatabase.swift`; `Epistemos/Models/EpistemosSchema.swift` | Yes | Indirect | SwiftData/GRDB/SQLite | P0 | Canonical vs derived boundaries are critical. |
| App Store profile | `Epistemos/Epistemos-AppStore.entitlements`; `Epistemos/Resources/PrivacyInfo.xcprivacy`; `Epistemos/AppStore/AppStoreComputerUseStubs.swift` | Partial/Yes | Indirect | Build/profile gates | P0 | Final MAS privacy/sandbox review still required. |
| Build/signing | `Epistemos.xcodeproj`; `Epistemos-AppStore-Info.plist`; `docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` | Partial/Yes | No | Xcode/signing | P1 | Distribution archive/TestFlight/ASC metadata are deferred. |
| Diagnostics/tests | `EpistemosTests/`; `EpistemosTests/Benchmarks/` | Partial/Yes | Hidden | OSLog/signposts | P1 | Perf gates are not fully automated. |
| Raw Thoughts/run artifacts | `Epistemos/Views/RawThoughts/`; `EpistemosTests/RawThoughtsStateTests.swift`; `Epistemos/Vault/AgentSessionLineageStore.swift` | Partial | Partial | Agent/vault | P1 | Need persistent browsable run timeline and provider byte-safety. |
| Knowledge core/deterministic runtime | `Epistemos/Engine/KnowledgeCoreBridge.swift`; `graph-engine/src/knowledge_core/`; `graph-engine-bridge/graph_engine.h` | Partial | Indirect | FFI/shared memory/BoltFFI | P1 | Must prove production view-model path, not debug counters. |

## Dead / Stale / Duplicate / Needs Verification

| Item | Evidence | Risk | Required follow-up |
|---|---|---|---|
| Stale audit docs | Prior `docs/audits/USER_WIRING_CAPABILITY_MAP.md` claimed `.epdoc` absent before correction; actual files include `Epistemos/Engine/EpdocDocument.swift` and `Epistemos-AppStore-Info.plist`. | P1 | Keep audit docs versioned against current code before synthesis. |
| Raw Thoughts completeness uncertain | `Epistemos/Views/RawThoughts/RawThoughtsSection.swift`; `EpistemosTests/RawThoughtsStateTests.swift`; run stores in `Epistemos/Vault/` | P1 | Prove run folder/events/summaries/tool traces/links exist or mark scaffold. |
| Command Center reachability uncertain | `Epistemos/Engine/CommandInputParser.swift`; `Epistemos/Engine/CommandCenterRequestCompiler.swift` | P2 | Trace menu/shortcut/sidebar entry before surfacing claims. |
| Code editor perf unproven | `Epistemos/Engine/LiveCodeEditorController.swift`; `EpistemosTests/Benchmarks/CodeEditorBenchmarkTests.swift` | P1 | Add 4k-line scroll/typing benchmark and gutter design gate. |
| Computer use has MAS conflict | `Epistemos/Bridge/ComputerUseBridge.swift`; `Epistemos/AppStore/AppStoreComputerUseStubs.swift`; `Epistemos/Omega/Vision/ScreenCaptureService.swift` | P0 | Keep App Store surface hidden/stubbed unless review-safe. |
| Launch agent resource needs MAS classification | `Epistemos/Resources/LaunchAgents/com.epistemos.nightbrain.plist` | P1 | Direct-build-only or remove from MAS bundle if not review-safe. |

## Services Not Clearly Injected Into UI

| Service | Evidence | Status | Risk | Minimal check |
|---|---|---|---|---|
| Instant Recall | `Epistemos/KnowledgeFusion/InstantRecallService.swift` | Built, UI path needs proof | P1 | Type in note/chat, click recall affordance, see Notes/Chats results. |
| Shadow search | `Epistemos/Engine/ShadowSearchService.swift` | Built, surface unclear | P1 | Verify Halo/Contextual Shadows uses it off MainActor. |
| Text capture | `Epistemos/Engine/TextCapturePipeline.swift` | Built, entry unclear | P2 | Verify menu/hotkey/toolbar entry and safe write result. |
| Live code editor controller | `Epistemos/Engine/LiveCodeEditorController.swift` | Built, route/perf unclear | P1 | Open 4k-line code file and measure scroll/typing. |
| Epdoc graph/projector services | `Epistemos/Engine/EpdocGraphProjector.swift`; `Epistemos/Engine/EpdocGraphRenderingMapper.swift` | Built, workflow unclear | P1 | Save `.epdoc`, regenerate graph/search projections, reopen. |
| Agent lineage/run stores | `Epistemos/Vault/AgentSessionLineageStore.swift`; `Epistemos/Vault/ChatTranscriptVaultWriter.swift` | Built, Raw Thoughts route unclear | P1 | Start run, inspect persistent timeline, reopen app. |

## Bridges / FFI / Stubs

| Bridge | Evidence | Current state | Risk | Notes |
|---|---|---|---|---|
| Graph C bridge | `graph-engine-bridge/graph_engine.h`; `Epistemos/Graph/GraphState.swift` | Live | P1 | Layout/ownership must remain tested. |
| Knowledge core bridge | `Epistemos/Engine/KnowledgeCoreBridge.swift`; `graph-engine/src/knowledge_core/` | Partial/staged | P1 | Must reach production view models before performance claims. |
| BoltFFI typed buffers | `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md` | Flag-gated | P1 | Keep fallback until parity and perf proof. |
| Computer-use bridge | `Epistemos/Bridge/ComputerUseBridge.swift`; `Epistemos/AppStore/AppStoreComputerUseStubs.swift` | Pro/live plus MAS stubs | P0 | MAS must not expose unsafe automation. |
| MCP bridge | `Epistemos/Omega/MCPBridge.swift`; `Epistemos/Bridge/ChunkedMCPFraming.swift` | Partial/live | P1 | External servers/tools should be direct-build-only unless sandbox-safe. |
| WKWebView `.epdoc` bridge | `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift` | Partial/live | P1 | Message handlers must be narrow, local-assets-only, and debounced. |

## Feature Flags And Ship Gates

| Gate | Evidence | Classification | Required action |
|---|---|---|---|
| MAS profile | `Epistemos/Epistemos-AppStore.entitlements`; `Epistemos/AppStore/AppStoreComputerUseStubs.swift` | P0 ship gate | Keep unsafe Pro features hidden/stubbed. |
| BoltFFI/graph typed buffers | `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md`; `graph-engine-bridge/graph_engine.h` | P1 perf gate | No default-on without parity/perf proof. |
| Knowledge core deterministic runtime | `Epistemos/Engine/KnowledgeCoreBridge.swift`; `graph-engine/src/knowledge_core/` | P1 perf/correctness gate | No "zero-copy" or "deterministic" claim without end-to-end tests. |
| Computer use / AX / screen capture | `Epistemos/Omega/Vision/ScreenCaptureService.swift`; `Epistemos/Omega/Agents/GhostComputerAgent.swift` | P0 MAS gate | Direct-build-only unless explicitly review-safe. |
| Code editor syntax path | `Epistemos/Engine/LiveCodeEditorController.swift`; benchmark tests | P1 perf gate | Only enable hot paths with 4k-line measurement. |

## P0/P1 Cartography Findings

| Severity | Finding | Evidence | Fix direction |
|---|---|---|---|
| P0 | App Store computer-use and automation surface must remain hidden/stubbed. | `Epistemos/AppStore/AppStoreComputerUseStubs.swift`; `Epistemos/Omega/Vision/ScreenCaptureService.swift`; `Epistemos/Bridge/ComputerUseBridge.swift` | Privacy/App Store audit must classify direct-build-only features before V1. |
| P0 | Vault/database persistence is the highest data-loss surface. | `Epistemos/Sync/VaultSyncService.swift`; `Epistemos/Sync/VaultIndexActor.swift`; `Epistemos/Models/`; `Epistemos/Engine/EpdocDatabase.swift` | Data audit must prove safe writes, rebuildable indexes, and migration recovery. |
| P1 | `.epdoc` is not absent, but it is not fully proven as a user-wired workflow. | `Epistemos/Engine/EpdocDocument.swift`; `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`; `EpistemosTests/EpdocInfoPlistTests.swift` | Verify create/open/save/projection/recovery path. |
| P1 | Ambient Recall/Halo exists but V1 product path is not proven. | `Epistemos/KnowledgeFusion/InstantRecallService.swift`; `Epistemos/Views/Recall/`; `Epistemos/Engine/HaloEditorBridge.swift` | Build focused Ambient Recall wiring plan next. |
| P1 | Code editor target is explicit but not performance-proven. | `Epistemos/Engine/LiveCodeEditorController.swift`; `EpistemosTests/Benchmarks/CodeEditorBenchmarkTests.swift` | Add radar to performance audit and patch queue. |
