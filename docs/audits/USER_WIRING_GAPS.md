# User Wiring Gaps

Date: 2026-04-28
Scope: Phase 2A user-wiring gap audit.

## Executive Summary

Epistemos has many real systems. The highest risk is not lack of code; it is product wiring: capabilities exist in services, tests, or bridges without a minimal, reliable user route. For V1, the app should expose a small surface: write, chat, search/recall, graph, quick capture if safe, model/settings transparency, and hidden/direct-build-only advanced automation.

Most important findings:
- P0: computer-use/AX/screen capture must stay hidden or stubbed in MAS.
- P0: vault/database persistence and chat streaming need hardening before any ship claim.
- P1: Ambient Recall/Halo should be the V1 differentiator, but the note/chat typing -> recall panel path is not proven.
- P1: `.epdoc` exists now, but full create/open/save/projection recovery is not yet proven.
- P1: code editor needs a deliberate performance slice: native line-number gutter, 4k-line smooth scrolling with syntax on, no per-keystroke Rust/UniFFI, UTF-8/UTF-16 mapping tests.

## Required Wiring Gap Table

| Capability | Existing code | Missing link | Suggested minimal UI | Priority | Acceptance test |
|---|---|---|---|---|---|
| Ambient Recall / Contextual Shadows | `Epistemos/KnowledgeFusion/InstantRecallService.swift`; `Epistemos/Engine/ShadowSearchService.swift`; `Epistemos/Views/Recall/`; `Epistemos/Engine/HaloEditorBridge.swift` | Active note/chat typing to subtle recall button to Notes/Chats panel is not proven. | Small contextual recall button in note editor and chat input; lightweight panel with Notes/Chats tabs. | P1 | Type in note/chat, button appears, panel opens, related note and chat can open, no MainActor blocking. |
| `.epdoc` Documents | `Epistemos/Engine/EpdocDocument.swift`; `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`; `Epistemos-AppStore-Info.plist`; `EpistemosTests/EpdocInfoPlistTests.swift` | Full user create/open/save/reopen/projection recovery path needs proof. | File/new document route in existing vault/tree; do not add separate document silo. | P1 | Create `.epdoc`, save, close, reopen, delete projections, regenerate, detect external `shadow.md` mismatch. |
| Raw Thoughts | `Epistemos/Views/RawThoughts/RawThoughtsSection.swift`; `EpistemosTests/RawThoughtsStateTests.swift`; `Epistemos/Vault/AgentSessionLineageStore.swift` | Persistent browsable run folder/events/tool traces/summaries/links not proven end to end. | Raw Thoughts section grouped virtually by provider/model, linked from chat/agent run. | P1 | Start fake run, append events, save summaries/tool logs, reopen app, timeline shows run and links. |
| Code editor | `Epistemos/Engine/LiveCodeEditorController.swift`; `Epistemos/Engine/CodeEditorContentDebouncer.swift`; `EpistemosTests/Benchmarks/CodeEditorBenchmarkTests.swift` | High-performance 4k-line editor behavior and line-number gutter not proven. | Native gutter inside existing code surface; no theme collision; optional perf HUD in debug. | P1 | Open 4k-line file with syntax on, scroll fluidly, line gutter aligns, UTF-8/UTF-16 mapping tests pass. |
| Chat streaming | `Epistemos/App/ChatCoordinator.swift`; `Epistemos/State/NoteChatState.swift`; `Epistemos/Views/Chat/`; `EpistemosTests/NoteChatStateTests.swift` | Need proof streaming does not save/invalidate SwiftUI/database per token. | Keep existing chat; add diagnostics/perf counters only. | P0 | 100+ token/sec stream does not flood `@Published`/database, cancellation works, output persists after restart. |
| Computer use / automation | `Epistemos/Bridge/ComputerUseBridge.swift`; `Epistemos/AppStore/AppStoreComputerUseStubs.swift`; `Epistemos/Omega/Agents/GhostComputerAgent.swift`; `Epistemos/Omega/Vision/ScreenCaptureService.swift` | MAS-safe surfacing is not viable without explicit review-safe gating. | Hide from MAS; direct-build-only advanced setting with permission explanations. | P0 | MAS build exposes no screen/AX/control UI and stubs fail safely. |
| MCP / external tools | `Epistemos/Omega/MCPBridge.swift`; `Epistemos/Bridge/ChunkedMCPFraming.swift`; `omega-mcp/` | External/user MCP server surface can violate sandbox/review if visible in MAS. | Built-in tools only for MAS; external MCP hidden/direct-build-only. | P1 | MAS build cannot launch arbitrary MCP server; Pro build prompts and logs permissions. |
| Quick capture | `Epistemos/Engine/TextCapturePipeline.swift`; `EpistemosTests/TextCapturePipelineTests.swift` | Discoverable hotkey/menu/toolbar route not proven. | Small menu bar or command palette action if write path is safe. | P2 | Trigger capture, artifact/note appears, graph/search update incrementally, errors visible. |
| Audio/transcription | `Epistemos/KnowledgeFusion/DataIngestion/AudioRecorder.swift`; `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift`; `Epistemos/Engine/ComposerVoiceInputService.swift` | Permission flow and local/cloud speech behavior need user clarity. | Mic button only where transcription works; explicit permission empty/error state. | P2 | Deny mic/speech permission; UI recovers without crash and explains next step. |
| Command Center | `Epistemos/Engine/CommandInputParser.swift`; `Epistemos/Engine/CommandCenterRequestCompiler.swift`; `Epistemos/Models/CommandTokenizer.swift` | Parser/compiler exist; global shortcut/menu reachability needs proof. | Command palette for advanced actions; do not add giant sidebar. | P2 | Shortcut opens palette, commands route to existing services, unsupported commands show recovery. |
| Search readable projection | `Epistemos/Sync/SearchIndexService.swift`; `Epistemos/Models/QueryTypes.swift`; `EpistemosTests/BlockSearchTests.swift` | Universal artifact/block projection across Prose/Documents/Raw Thoughts/Code not proven. | Keep one search surface; show exact artifact/block target. | P1 | Search hit opens exact note/document/run/code block; derived index rebuilds in background. |
| Settings/privacy/model manager | `Epistemos/Resources/PrivacyInfo.xcprivacy`; `EpistemosTests/SettingsCategoryTests.swift`; `Epistemos/Engine/LocalModelInfrastructure.swift`; `Epistemos/Engine/ModelDownloadManager.swift` | Copy and category counts can drift; cloud/local/storage claims need exactness. | Existing settings sections with precise privacy/model status. | P1 | Settings tests pass; user can tell local/cloud/installed/storage state; PrivacyInfo matches UI claims. |
| Knowledge core deterministic runtime | `Epistemos/Engine/KnowledgeCoreBridge.swift`; `graph-engine/src/knowledge_core/`; `graph-engine-bridge/graph_engine.h` | Staged bridge must reach production view models, not debug counters. | No direct new UI; feature flag plus diagnostics. | P1 | Real mutation updates affected view model only; fallback path works when flag off. |
| Graph typed artifacts | `Epistemos/Models/ArtifactKind.swift`; `Epistemos/Models/ArtifactRoute.swift`; `Epistemos/Graph/GraphStore.swift`; `Epistemos/Engine/EpdocGraphProjector.swift` | New artifact types must display/filter without graph explosion. | Graph filters by artifact kind/layer. | P1 | Graph shows Prose/Document/RawThought/Code types, can filter, no full paragraph materialization. |

## Built Backend With Weak Or Missing UI

| Backend | Evidence | Gap | Priority |
|---|---|---|---|
| Instant Recall | `Epistemos/KnowledgeFusion/InstantRecallService.swift` | Missing proven contextual button/panel path. | P1 |
| Shadow Search | `Epistemos/Engine/ShadowSearchService.swift` | Needs visible Halo/recall result and off-MainActor proof. | P1 |
| Text Capture | `Epistemos/Engine/TextCapturePipeline.swift` | Needs discoverable entry and safe result UI. | P2 |
| Agent lineage/run stores | `Epistemos/Vault/AgentSessionLineageStore.swift`; `Epistemos/Vault/ChatTranscriptVaultWriter.swift` | Needs Raw Thoughts timeline/reopen path. | P1 |
| Epdoc graph/search projectors | `Epistemos/Engine/EpdocGraphProjector.swift`; `Epistemos/Engine/EpdocGraphRenderingMapper.swift`; `Epistemos/Engine/EpdocDatabase.swift` | Needs complete user document workflow and projection rebuild proof. | P1 |
| Code editor controller | `Epistemos/Engine/LiveCodeEditorController.swift` | Needs perf-proven route and gutter polish. | P1 |
| MCP bridge | `Epistemos/Omega/MCPBridge.swift` | Needs MAS/direct-build split and permission UX. | P1 |

## UI Exists But Reachability Needs Proof

| UI | Evidence | Reachability question | Priority |
|---|---|---|---|
| Raw Thoughts section | `Epistemos/Views/RawThoughts/RawThoughtsSection.swift` | Is it reachable from main navigation and backed by persistent run artifacts? | P1 |
| Recall panel/views | `Epistemos/Views/Recall/` | Does active typing in note/chat trigger it? | P1 |
| Epdoc editor chrome | `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift` | Can a normal user create/open/save it from the existing vault tree? | P1 |
| Command Center/palette | `Epistemos/Engine/CommandInputParser.swift`; `Epistemos/Engine/CommandCenterRequestCompiler.swift` | Is there a menu/shortcut/toolbar entry? | P2 |
| Computer-use/Omega surfaces | `Epistemos/Omega/Agents/GhostComputerAgent.swift`; `Epistemos/Omega/Vision/ScreenCaptureService.swift` | Are they hidden in MAS and permission-gated in Pro? | P0 |

## Feature Flags / Hidden Capabilities

| Capability | Evidence | Desired visibility | Priority |
|---|---|---|---|
| Computer use | `Epistemos/AppStore/AppStoreComputerUseStubs.swift`; `Epistemos/Bridge/ComputerUseBridge.swift` | Hidden in MAS; direct-build-only if safe. | P0 |
| External MCP / CLIs | `Epistemos/Omega/MCPBridge.swift`; `omega-mcp/` | Hidden in MAS; Pro-only with permission logs. | P1 |
| BoltFFI / knowledge core | `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md`; `Epistemos/Engine/KnowledgeCoreBridge.swift` | Hidden behind feature flag until end-to-end proof. | P1 |
| Code syntax/perf path | `Epistemos/Engine/LiveCodeEditorController.swift`; `EpistemosTests/Benchmarks/CodeEditorBenchmarkTests.swift` | Experimental until 4k-line measurement passes. | P1 |
| `.epdoc` Documents | `Epistemos-AppStore-Info.plist`; `Epistemos/Engine/EpdocDocument.swift` | Surface minimally after create/open/save/projection tests pass. | P1 |

## P0/P1 Wiring Findings

| Severity | Finding | Evidence | Required next step |
|---|---|---|---|
| P0 | MAS must not expose computer-use/AX/screen capture. | `Epistemos/AppStore/AppStoreComputerUseStubs.swift`; `Epistemos/Omega/Vision/ScreenCaptureService.swift` | Privacy/App Store audit must classify and hide direct-build-only features. |
| P0 | Chat streaming needs proof against per-token UI/database cascades. | `Epistemos/App/ChatCoordinator.swift`; `Epistemos/State/NoteChatState.swift` | Performance/concurrency audit and synthetic stream test. |
| P0 | Vault/database paths need corruption and recovery proof. | `Epistemos/Sync/VaultSyncService.swift`; `Epistemos/Engine/EpdocDatabase.swift`; `Epistemos/Models/` | Data/persistence/indexing audit. |
| P1 | Ambient Recall/Halo exists but is not proven as the V1 user moment. | `Epistemos/KnowledgeFusion/InstantRecallService.swift`; `Epistemos/Views/Recall/`; `Epistemos/Engine/HaloEditorBridge.swift` | Create dedicated Ambient Recall wiring plan. |
| P1 | `.epdoc` exists but must not become a second source-of-truth system. | `Epistemos/Engine/EpdocDocument.swift`; `Epistemos/Models/EpdocPackage.swift`; `Epistemos/Models/ProseMirrorMarkdownProjector.swift` | Data/persistence audit must enforce content.json canonical, shadow.md derived. |
| P1 | Code editor target is important but not yet measured. | `Epistemos/Engine/LiveCodeEditorController.swift`; `EpistemosTests/Benchmarks/CodeEditorBenchmarkTests.swift` | Add benchmark and UI plan for gutter/4k-line smoothness. |
