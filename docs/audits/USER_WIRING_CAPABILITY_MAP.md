# User Wiring Capability Map

Date: 2026-04-28
Scope: Phase 1 discovery for Epistemos V1 hardening and user wiring.

Definition: a capability is "wired" only when a user-visible surface reaches the backing state/service/bridge/persistence path and returns a user-visible result without blocking the UI, breaking App Store constraints, or relying on unreachable scaffold code.

Evidence note: this map uses repository-local files as evidence. It is a discovery artifact, not a ship claim. Build and runtime verification belong in `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`.

## Capability: Notes / Prose Editor

Status:
- Built?: Yes. Primary native TextKit path exists in `Epistemos/Views/Notes/ProseEditorView.swift`, `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`, and `Epistemos/Views/Notes/ProseTextView2.swift`.
- Wired?: Yes. Editor state flows through the representable coordinator into SwiftData/vault save paths.
- User-visible?: Yes. This is the primary note editing surface.
- Stable?: Partial. AGENTS.md documents prior editor race and binding-cascade bugs; the current editor is protected, but any future edits need focused tests.
- Tested?: Yes/Partial. Prose/editor tests exist, but release-level dogfood and Instruments proof remain separate Phase S gates.
- App Store safe?: Yes. Native text editing has no special App Store risk beyond vault file access.
Primary files:
- `Epistemos/Views/Notes/ProseEditorView.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Sync/NoteFileStorage.swift`
- `Epistemos/Sync/VaultSyncService.swift`
User entry points:
- Main note editor in the app shell.
- Note windows managed by `Epistemos/Views/Notes/NoteWindowManager.swift`.
Runtime path:
UI -> ProseEditorView/Representable coordinator -> Note state/model context -> NoteFileStorage/VaultSyncService -> SwiftData/vault files -> visible note body.
Current gaps:
- Keep protected from broad refactors until p95 typing, large-file, and AI-streaming editor traces are proven.
- Manual dogfood/accessibility checks were intentionally deferred by the user.
Risk level:
P0
Recommendation:
harden

## Capability: Markdown / Prose Pipeline

Status:
- Built?: Yes. Markdown parsing/styling and projections appear in `MarkdownContentStorage`, `Epistemos/Models/ProseMirrorMarkdownProjector.swift`, and markdown command tests.
- Wired?: Yes for prose notes; Partial for rich Document projections.
- User-visible?: Yes for note markdown editing. Derived markdown for `.epdoc` is mostly behind package/projection logic.
- Stable?: Partial. Markdown is safe as prose source of truth, but must not become a second source of truth for rich Documents.
- Tested?: Partial. `EpistemosTests/MarkdownEditorCommandsTests.swift` and `EpistemosTests/ProseMirrorMarkdownProjectorTests.swift` exist.
- App Store safe?: Yes.
Primary files:
- `Epistemos/Views/Notes/MarkdownContentStorage.swift`
- `Epistemos/Models/ProseMirrorMarkdownProjector.swift`
- `EpistemosTests/MarkdownEditorCommandsTests.swift`
- `EpistemosTests/ProseMirrorMarkdownProjectorTests.swift`
User entry points:
- Prose editor.
- Derived `shadow.md` inside `.epdoc` packages when generated.
Runtime path:
UI -> editor storage/projector -> markdown parser/projection -> note body or `.epdoc` shadow projection -> user-visible editor/search text.
Current gaps:
- External markdown shadow edits must never silently overwrite canonical Document JSON.
- Projection rebuild and mismatch handling need explicit audit in the data-persistence phase.
Risk level:
P1
Recommendation:
harden

## Capability: Documents / .epdoc Rich Artifact Stub

Status:
- Built?: Partial. Current code includes `Epistemos/Engine/EpdocDocument.swift`, `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`, `Epistemos/Models/EpdocPackage.swift`, `Epistemos/Models/EpdocManifest.swift`, and `.epdoc` plist registration in `Epistemos-AppStore-Info.plist`.
- Wired?: Partial. NSDocument registration and editor chrome exist; full Tiptap/ProseMirror production editor and V1 user workflow need verification.
- User-visible?: Partial. AppKit document routing is registered; whether the app shell exposes Documents cleanly is not yet proven.
- Stable?: Partial. Tests exist, but this is still a new artifact surface with source-of-truth risk.
- Tested?: Yes/Partial. Evidence includes `EpistemosTests/EpdocInfoPlistTests.swift`, `EpistemosTests/EpdocDocumentTests.swift`, `EpistemosTests/EpdocPackageTests.swift`, and `EpistemosTests/EpdocEndToEndSmokeTests.swift`.
- App Store safe?: Partial. WKWebView/local assets can be MAS-safe, but message handlers, local file access, and package writes need focused privacy/sandbox audit.
Primary files:
- `Epistemos/Engine/EpdocDocument.swift`
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`
- `Epistemos/Models/EpdocPackage.swift`
- `Epistemos/Models/EpdocManifest.swift`
- `Epistemos-AppStore-Info.plist`
- `EpistemosTests/EpdocInfoPlistTests.swift`
User entry points:
- macOS document open/save path for `.epdoc`.
- Any app-shell document route that resolves to `EpdocEditorChromeView`.
Runtime path:
UI -> NSDocument/EpdocEditorChromeView -> EpdocDocument/EpdocPackage -> content.json/shadow.md/search_blocks.jsonl/assets -> visible document canvas/projections.
Current gaps:
- Verify a complete user flow: create/open/save `.epdoc`, regenerate projections, detect external shadow edits, and reopen without data loss.
- Confirm Documents remain typed artifacts in the existing vault/tree, not a parallel sidebar universe.
- Confirm canonical body remains ProseMirror JSON and Markdown is derived only.
Risk level:
P1
Recommendation:
harden

## Capability: Code Editor / Epistemos Code Surface

Status:
- Built?: Partial. `Epistemos/Engine/LiveCodeEditorController.swift`, `Epistemos/Engine/CodeEditorContentDebouncer.swift`, `Epistemos/Models/CodeArtifactSidecar.swift`, `Epistemos/Models/CodeArtifactKind.swift`, `EpistemosTests/LiveCodeEditorControllerTests.swift`, and `EpistemosTests/CodeEditorPolishTests.swift` exist.
- Wired?: Partial. Code artifacts and controller tests exist, but full native high-performance editing, syntax, LSP, and graph-aware provenance are not proven end to end.
- User-visible?: Partial. Code-like file opening appears supported, but exact app-shell route needs Phase 2 wiring audit.
- Stable?: Unknown/Partial. User requirement is Xcode-like smoothness for 4k-line files with syntax colors on; no automated p95 scroll/typing gate is proven here.
- Tested?: Partial. Tests and benchmark harness exist, including `EpistemosTests/Benchmarks/CodeEditorBenchmarkTests.swift`.
- App Store safe?: Yes for local editing. Pro-only CLI/LSP/tool execution must be gated from MAS when it spawns user-installed tools.
Primary files:
- `Epistemos/Engine/LiveCodeEditorController.swift`
- `Epistemos/Engine/CodeEditorContentDebouncer.swift`
- `Epistemos/Models/CodeArtifactSidecar.swift`
- `Epistemos/Models/CodeArtifactKind.swift`
- `EpistemosTests/LiveCodeEditorControllerTests.swift`
- `EpistemosTests/Benchmarks/CodeEditorBenchmarkTests.swift`
User entry points:
- Code artifact/file route in the app shell.
- Future agent patch/provenance route.
Runtime path:
UI -> code editor controller/debouncer -> syntax/highlight/index service or sidecar -> code artifact persistence/search/graph -> visible code surface.
Current gaps:
- Product radar: add a high-performance native line-number gutter that does not collide with theme, scrollbars, selection, or diagnostics UI.
- Product radar: prove 4k-line smooth scrolling with syntax highlighting enabled.
- Architecture guard: Swift should own live TextKit/AppKit ranges, cursor, selection, IME, visible range, gutter, diagnostics UI, and scroll behavior.
- Performance guard: avoid per-keystroke Rust/UniFFI crossings; use Rust for background parsing/indexing/code graph/build-test/agent provenance where measured safe.
- Correctness guard: add UTF-8 byte offset to UTF-16 NSRange mapping tests before Tree-sitter/LSP claims.
Risk level:
P1
Recommendation:
harden

## Capability: Ambient Recall / Contextual Shadows / Instant Recall / Halo

Status:
- Built?: Partial. Evidence includes `Epistemos/KnowledgeFusion/InstantRecallService.swift`, `Epistemos/Engine/ShadowSearchService.swift`, `Epistemos/KnowledgeFusion/RecallContextSnapshot.swift`, `Epistemos/Engine/HaloController.swift`, and `Epistemos/Engine/HaloEditorBridge.swift`.
- Wired?: Partial. Halo tests and recall services exist, but note/chat typing -> recall button -> related notes/chats panel is not proven.
- User-visible?: Partial. Halo UI/tests exist; Ambient Recall as a coherent V1 product surface needs audit.
- Stable?: Unknown. Recall must not block typing, indexing, or app launch.
- Tested?: Partial. `EpistemosTests/InstantRecallTests.swift`, `EpistemosTests/HaloControllerTests.swift`, `EpistemosTests/HaloEditorBridgeTests.swift`, and `EpistemosTests/HaloUITests.swift` exist.
- App Store safe?: Yes if local/private and no hidden data exfiltration.
Primary files:
- `Epistemos/KnowledgeFusion/InstantRecallService.swift`
- `Epistemos/Engine/ShadowSearchService.swift`
- `Epistemos/KnowledgeFusion/RecallContextSnapshot.swift`
- `Epistemos/Engine/HaloController.swift`
- `Epistemos/Engine/HaloEditorBridge.swift`
User entry points:
- Halo/recall affordances in editor or chat, if wired.
- Search/knowledge fusion surfaces.
Runtime path:
UI -> HaloEditorBridge/HaloController -> InstantRecallService/ShadowSearchService -> search/embedding/index stores -> recall panel or editor/chat result.
Current gaps:
- Implement or prove the desired V1 path: active typing shows subtle recall button; panel has Notes and Chats tabs; note/chat results open correctly.
- Recall work must run off MainActor and indexing must be backgrounded.
Risk level:
P1
Recommendation:
wire

## Capability: Knowledge Graph Renderer

Status:
- Built?: Yes. Graph state/store/renderer files exist, including `Epistemos/Graph/GraphState.swift`, `Epistemos/Graph/GraphStore.swift`, and `Epistemos/Views/Graph/MetalGraphView.swift`.
- Wired?: Yes. Graph is a visible core app surface.
- User-visible?: Yes.
- Stable?: Partial. Prior protected-path policy exists because graph rendering/physics are high-risk demo surfaces.
- Tested?: Yes/Partial. `EpistemosTests/GraphStoreTests.swift`, `EpistemosTests/GraphPerformanceTests.swift`, `EpistemosTests/MetalGraphViewBootstrapTests.swift`, and related graph tests exist.
- App Store safe?: Yes.
Primary files:
- `Epistemos/Graph/GraphState.swift`
- `Epistemos/Graph/GraphStore.swift`
- `Epistemos/Graph/GraphBuilder.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `graph-engine/src/lib.rs`
User entry points:
- Graph panel/view in the app shell.
Runtime path:
UI -> GraphState -> GraphStore/GraphBuilder -> Rust graph-engine/Metal renderer -> visible graph.
Current gaps:
- Need ship-gate proof for pan/zoom smoothness, no full rebuild on save, bounded labels, and no MainActor render stalls.
- Typed artifact kinds should be filterable without graph explosion.
Risk level:
P1
Recommendation:
harden

## Capability: Graph Physics

Status:
- Built?: Yes. Physics is in Swift graph state plus Rust graph-engine physics paths.
- Wired?: Yes. Renderer behavior depends on physics.
- User-visible?: Yes through graph movement, hover, drag, and layout.
- Stable?: Partial. Protected by recursive physics audit expectations; motion edits are allowed, physics rewrites are not.
- Tested?: Yes/Partial. Evidence includes graph physics tests and the repo skill `.agents/skills/graph_physics_audit/SKILL.md`.
- App Store safe?: Yes.
Primary files:
- `graph-engine/src/physics.rs`
- `graph-engine/src/renderer.rs`
- `Epistemos/Graph/GraphState.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
User entry points:
- Graph panel interactions.
Runtime path:
UI -> graph interaction state -> physics simulation -> Metal renderer -> visible graph movement.
Current gaps:
- Need Instruments/signpost p99 evidence before any claim that graph is release-smooth.
- Keep reduce-motion/window-occlusion gating intact.
Risk level:
P1
Recommendation:
harden

## Capability: Search / Semantic Search / Hybrid Retrieval

Status:
- Built?: Yes/Partial. Search index and tests exist in `Epistemos/Sync/SearchIndexService.swift`, `EpistemosTests/SearchIndexTests.swift`, `EpistemosTests/SearchIndexServiceIntegrationTests.swift`, and `EpistemosTests/SearchPerformanceTests.swift`.
- Wired?: Yes for basic search; Partial for universal artifact/block projection across Prose, Documents, Raw Thoughts, Code, and Sources.
- User-visible?: Yes.
- Stable?: Partial. Requires incremental indexing and exact artifact/block jump verification.
- Tested?: Yes/Partial. Search unit, integration, edge-case, and performance tests exist.
- App Store safe?: Yes.
Primary files:
- `Epistemos/Sync/SearchIndexService.swift`
- `Epistemos/Models/QueryTypes.swift`
- `EpistemosTests/SearchIndexTests.swift`
- `EpistemosTests/BlockSearchTests.swift`
- `EpistemosTests/SearchPerformanceTests.swift`
User entry points:
- Search UI/command surface.
- Recall/Halo when backed by search.
Runtime path:
UI -> search query state -> SearchIndexService/query parser -> SQLite/FTS/readable blocks/index stores -> result rows -> open artifact/block.
Current gaps:
- Universal readable projection must include artifact_id, block_id, headings, text, citations, links, producer/run info, and source path.
- Must prove no full-vault reindex on normal save.
Risk level:
P1
Recommendation:
harden

## Capability: Embeddings

Status:
- Built?: Partial. Evidence includes `Epistemos/Graph/EmbeddingService.swift`, `EpistemosTests/BlockEmbeddingTests.swift`, and semantic cluster services.
- Wired?: Partial. Embeddings may feed graph/recall/search, but user-facing model/index lifecycle is not fully proven.
- User-visible?: Indirect. Users see semantic recall/search/graph effects, not embeddings directly.
- Stable?: Unknown. Embedding work must never block MainActor, typing, graph rendering, or app launch.
- Tested?: Partial. `EpistemosTests/BlockEmbeddingTests.swift` exists.
- App Store safe?: Yes if local/private or cloud disclosure is honest.
Primary files:
- `Epistemos/Graph/EmbeddingService.swift`
- `Epistemos/Graph/SemanticClusterService.swift`
- `EpistemosTests/BlockEmbeddingTests.swift`
User entry points:
- Search/recall/graph semantic features.
Runtime path:
UI -> search/recall/graph request -> embedding service/model backend -> vector/index store -> semantic result.
Current gaps:
- Need index corruption recovery, rebuild visibility, and background scheduling audit.
- Need clear local vs cloud privacy disclosures if embeddings leave device.
Risk level:
P1
Recommendation:
harden

## Capability: Local Model Catalog

Status:
- Built?: Yes/Partial. Evidence includes `Epistemos/Engine/LocalModelInfrastructure.swift`, `Epistemos/Engine/ModelDownloadManager.swift`, `Epistemos/Models/SDModelProfile.swift`, and local model tests.
- Wired?: Partial. Model status/settings exist, but install metadata, storage footprint, and default model correctness need release audit.
- User-visible?: Yes through settings/model surfaces.
- Stable?: Partial. Local model downloads can affect MAS size/storage and must be clear.
- Tested?: Yes/Partial. `EpistemosTests/LocalModelInfrastructureTests.swift`, `EpistemosTests/LocalModelReleaseSweepTests.swift`, and `EpistemosTests/ModelVaultBrowserTests.swift` exist.
- App Store safe?: Partial. Downloads, bundled model size, network disclosure, and user storage policy need MAS review.
Primary files:
- `Epistemos/Engine/LocalModelInfrastructure.swift`
- `Epistemos/Engine/ModelDownloadManager.swift`
- `Epistemos/Engine/LocalBackendLLMClient.swift`
- `Epistemos/Models/SDModelProfile.swift`
User entry points:
- Model settings/model manager.
- Chat/model picker.
Runtime path:
UI -> model settings/profile -> LocalModelInfrastructure/ModelDownloadManager -> local model files/runtime -> chat/agent output.
Current gaps:
- Minimize app bundle/storage footprint for MAS.
- Clearly show installed vs available, local vs cloud, and expected storage.
Risk level:
P1
Recommendation:
harden

## Capability: Cloud Model Providers

Status:
- Built?: Yes/Partial. Evidence includes `Epistemos/Engine/LLMService.swift`, `Epistemos/Engine/OpenAICompatibleChatSupport.swift`, `EpistemosTests/CloudLLMClientVisionTests.swift`, and provider-related chat tests.
- Wired?: Partial. Chat can route to cloud providers, but provider/tool parity and exact privacy copy require verification.
- User-visible?: Yes through chat/model settings.
- Stable?: Partial. Provider errors/offline behavior and capability labels need audit.
- Tested?: Partial. Cloud parser/provider tests exist.
- App Store safe?: Yes with network/privacy disclosures and no misleading local-only claims.
Primary files:
- `Epistemos/Engine/LLMService.swift`
- `Epistemos/Engine/OpenAICompatibleChatSupport.swift`
- `Epistemos/App/ChatCoordinator.swift`
- `EpistemosTests/CloudLLMClientVisionTests.swift`
User entry points:
- Chat model/provider settings.
- Chat composer/model selector.
Runtime path:
UI -> model/provider selection -> ChatCoordinator/LLMService -> cloud provider client -> streaming response -> chat/editor UI.
Current gaps:
- Privacy pane and settings copy must state exactly what can leave device.
- Provider reasoning surfaces must store only what providers expose.
Risk level:
P1
Recommendation:
harden

## Capability: Chat System / AI Streaming

Status:
- Built?: Yes. Evidence includes `Epistemos/App/ChatCoordinator.swift`, `Epistemos/State/NoteChatState.swift`, chat views, and chat tests.
- Wired?: Yes/Partial. Chat is user-facing; tool/agent routing varies by mode/provider.
- User-visible?: Yes.
- Stable?: Partial. Streaming persistence and SwiftUI invalidation need performance audit.
- Tested?: Yes/Partial. `EpistemosTests/ChatPresentationTests.swift`, `EpistemosTests/NoteChatStateTests.swift`, and `EpistemosTests/AgentChatStateTests.swift` exist.
- App Store safe?: Yes if provider/network/model disclosures are accurate.
Primary files:
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/State/NoteChatState.swift`
- `Epistemos/Views/Chat/`
- `Epistemos/Models/SDChat.swift`
- `Epistemos/Models/SDMessage.swift`
User entry points:
- Main chat.
- Per-note chat/sidebar or inline note AI.
Runtime path:
UI -> chat input/message state -> ChatCoordinator/NoteChatState -> LLMService/agent runtime -> persistence -> streamed response in chat/editor.
Current gaps:
- Prove no per-token database save or broad SwiftUI `@Query` cascade.
- Prove cancellation/offline/provider errors have visible recovery.
Risk level:
P0
Recommendation:
harden

## Capability: Agent Runtime

Status:
- Built?: Yes/Partial. Evidence includes `Epistemos/Engine/AgentRuntime.swift`, `Epistemos/LocalAgent/LocalAgentLoop.swift`, `Epistemos/Engine/AgentHarness/`, `agent_core/`, and Omega agents.
- Wired?: Partial. Agent pathways exist, but V1 user-facing agent toggles must avoid unreachable stubs and MAS-only unsafe features.
- User-visible?: Partial. Agent Command Center/tests exist; full discoverable workflow needs audit.
- Stable?: Partial. Tool permissions, trace persistence, and fallback paths need end-to-end proof.
- Tested?: Partial. `EpistemosTests/AgentHarnessTests.swift`, `EpistemosTests/LocalAgentLoopTests.swift`, `EpistemosTests/AgentCommandCenterStateTests.swift`, and `EpistemosTests/OmegaAgentTests.swift` exist.
- App Store safe?: Partial. MAS must gate computer use, external CLIs, broad filesystem, AX, and screen capture.
Primary files:
- `Epistemos/Engine/AgentRuntime.swift`
- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `Epistemos/Engine/AgentHarness/`
- `agent_core/src/`
- `Epistemos/Omega/Agents/OmegaAgent.swift`
User entry points:
- Agent/command center surfaces if enabled.
- Chat agent mode.
Runtime path:
UI -> ChatCoordinator/AgentCommandCenter state -> AgentRuntime/LocalAgentLoop/Rust agent_core -> tools/MCP/vault/search -> run events/artifacts/results.
Current gaps:
- Either wire a minimal stable V1 agent path or hide unstable toggles.
- No reachable `bindingsUnavailable`, `fatalError`, or stub-only agent paths in App Store build.
Risk level:
P1
Recommendation:
harden

## Capability: MCP Bridge / Server

Status:
- Built?: Yes/Partial. Evidence includes `Epistemos/Omega/MCPBridge.swift`, `Epistemos/Bridge/ChunkedMCPFraming.swift`, `omega-mcp/`, and command/compiler tests.
- Wired?: Partial. MCP is likely available to agent/Omega paths; V1 direct user surface needs audit.
- User-visible?: Partial/advanced.
- Stable?: Partial. Chunking, permissioning, and MAS gating need verification.
- Tested?: Partial. MCP/command tests exist in related suites.
- App Store safe?: Partial. External MCP servers/plugins should be Pro/direct-build only unless sandbox-safe.
Primary files:
- `Epistemos/Omega/MCPBridge.swift`
- `Epistemos/Bridge/ChunkedMCPFraming.swift`
- `omega-mcp/`
- `Epistemos/Engine/CommandCenterRequestCompiler.swift`
User entry points:
- Agent tools/Command Center if enabled.
Runtime path:
UI/agent request -> MCPBridge/framing -> MCP server/tool registry -> tool result -> agent/chat/artifact output.
Current gaps:
- Built-in tools should be clearly separated from external/user MCP tools.
- External tool execution must be hidden or gated in MAS.
Risk level:
P1
Recommendation:
hide

## Capability: Computer-Use Stack

Status:
- Built?: Yes/Partial. Evidence includes `Epistemos/Bridge/ComputerUseBridge.swift`, `Epistemos/Omega/Agents/GhostComputerAgent.swift`, `Epistemos/Omega/Vision/ScreenCaptureService.swift`, `Epistemos/Omega/Inference/DeviceAgentService.swift`, and MAS stubs.
- Wired?: Partial. Pro/direct paths appear present; App Store has stubs.
- User-visible?: Partial/advanced.
- Stable?: Unknown. TCC permissions and automation safety need manual/runtime verification.
- Tested?: Partial. `EpistemosTests/DeviceAgentServiceTests.swift` and computer-use adjacent tests exist.
- App Store safe?: No for unrestricted screen/AX/control features; MAS path must stay stubbed/hidden unless review-safe.
Primary files:
- `Epistemos/Bridge/ComputerUseBridge.swift`
- `Epistemos/AppStore/AppStoreComputerUseStubs.swift`
- `Epistemos/Omega/Agents/GhostComputerAgent.swift`
- `Epistemos/Omega/Vision/ScreenCaptureService.swift`
User entry points:
- Omega/agent automation surfaces if enabled.
Runtime path:
UI/agent request -> computer-use bridge/device agent -> AX/ScreenCapture/event APIs -> observed tool result -> agent response.
Current gaps:
- Keep disabled or direct-build-only for MAS V1.
- Permission prompts, failure states, and privacy copy must be explicit.
Risk level:
P0
Recommendation:
keep hidden

## Capability: Quick Capture / Text Capture

Status:
- Built?: Partial. Evidence includes `Epistemos/Engine/TextCapturePipeline.swift`, `EpistemosTests/TextCapturePipelineTests.swift`, and ingestion services.
- Wired?: Partial. Pipeline exists; global hotkey/menu/user entry is not proven.
- User-visible?: Unknown/Partial.
- Stable?: Partial. Capture must write safely and update graph/search incrementally.
- Tested?: Partial. Text capture pipeline tests exist.
- App Store safe?: Yes if file access and privacy permissions are scoped.
Primary files:
- `Epistemos/Engine/TextCapturePipeline.swift`
- `EpistemosTests/TextCapturePipelineTests.swift`
- `Epistemos/KnowledgeFusion/SyntheticData/EmbodiedCaptureService.swift`
User entry points:
- Capture UI/menu/hotkey if wired.
Runtime path:
UI/hotkey -> TextCapturePipeline -> artifact/note/vault write -> graph/search update -> visible captured item.
Current gaps:
- Verify discoverable Quick Capture entry point.
- Verify capture writes are atomic and errors are visible.
Risk level:
P2
Recommendation:
surface minimally

## Capability: Audio / Transcription

Status:
- Built?: Partial. Evidence includes `Epistemos/KnowledgeFusion/DataIngestion/AudioRecorder.swift`, `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift`, and `Epistemos/Engine/ComposerVoiceInputService.swift`.
- Wired?: Partial. Voice input/transcription paths exist; top-level workflow needs audit.
- User-visible?: Partial.
- Stable?: Unknown. Permissions, offline behavior, and user feedback need verification.
- Tested?: Unknown/Partial.
- App Store safe?: Yes with microphone/speech usage descriptions and honest privacy copy.
Primary files:
- `Epistemos/KnowledgeFusion/DataIngestion/AudioRecorder.swift`
- `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift`
- `Epistemos/Engine/ComposerVoiceInputService.swift`
User entry points:
- Composer voice input or ingestion UI if enabled.
Runtime path:
UI -> recorder/transcriber -> speech/local/cloud transcription -> captured text/artifact -> visible transcript.
Current gaps:
- Verify usage descriptions, permission denial states, and whether speech recognition is local/cloud.
Risk level:
P2
Recommendation:
harden

## Capability: Settings / Privacy / Model Manager

Status:
- Built?: Yes/Partial. Evidence includes settings tests, privacy pane work, model infrastructure, and `Epistemos/Resources/PrivacyInfo.xcprivacy`.
- Wired?: Yes/Partial. Settings are visible; category count/copy drift must be tested when sections change.
- User-visible?: Yes.
- Stable?: Partial. Copy must be exact, especially cloud-provider, telemetry, MAS vs Pro, and local model storage claims.
- Tested?: Partial. `EpistemosTests/SettingsCategoryTests.swift`, `EpistemosTests/SettingsWindowPresentationTests.swift`, and `EpistemosTests/AppStoreHardeningTests.swift` exist.
- App Store safe?: Partial. Depends on entitlements, PrivacyInfo, and feature gating.
Primary files:
- `Epistemos/Resources/PrivacyInfo.xcprivacy`
- `EpistemosTests/SettingsCategoryTests.swift`
- `EpistemosTests/AppStoreHardeningTests.swift`
- `Epistemos/Engine/LocalModelInfrastructure.swift`
- `Epistemos/Engine/ModelDownloadManager.swift`
User entry points:
- Settings window.
- Model/privacy sections.
Runtime path:
UI -> settings state/category views -> model/privacy/vault/agent services -> persisted preferences/profile -> visible capability behavior.
Current gaps:
- Keep privacy copy exact and ASCII-clean unless file style already uses non-ASCII.
- Update settings category tests whenever a visible section is added.
Risk level:
P1
Recommendation:
harden

## Capability: Command Palette / Command Center

Status:
- Built?: Partial. Evidence includes `Epistemos/Engine/CommandInputParser.swift`, `Epistemos/Engine/CommandCenterRequestCompiler.swift`, `Epistemos/Models/CommandTokenizer.swift`, and related tests.
- Wired?: Partial. Parsing/compiler exist; discoverable command palette/center and right-side inspector need audit.
- User-visible?: Partial/Unknown.
- Stable?: Partial. Command execution must not bypass permissions or MAS gates.
- Tested?: Partial. `EpistemosTests/CommandTokenizerTests.swift`, `EpistemosTests/CommandInputParserTests.swift`, and `EpistemosTests/CommandCenterRequestCompilerTests.swift` exist.
- App Store safe?: Yes for local commands; Pro-only tools need gates.
Primary files:
- `Epistemos/Engine/CommandInputParser.swift`
- `Epistemos/Engine/CommandCenterRequestCompiler.swift`
- `Epistemos/Models/CommandTokenizer.swift`
- `EpistemosTests/CommandCenterRequestCompilerTests.swift`
User entry points:
- Command palette/Command Center if surfaced.
Runtime path:
UI -> command tokenizer/parser -> request compiler -> agent/service/tool route -> visible result.
Current gaps:
- Identify whether command palette is reachable from menus/shortcuts.
- Advanced commands should use progressive disclosure, not clutter the sidebar.
Risk level:
P2
Recommendation:
surface minimally

## Capability: Vault / File Watcher / Sync

Status:
- Built?: Yes. Evidence includes `Epistemos/Sync/VaultSyncService.swift`, `Epistemos/Sync/VaultIndexActor.swift`, `Epistemos/Vault/VaultRegistry.swift`, and vault tests.
- Wired?: Yes/Partial. Notes/vault sync is core; Document/Raw Thought integration needs audit.
- User-visible?: Yes.
- Stable?: Partial. File watcher loops, security-scoped bookmarks, iCloud/local behavior, and indexing stalls need release audit.
- Tested?: Yes/Partial. `EpistemosTests/VaultSyncServiceAuditTests.swift`, `EpistemosTests/VaultIndexActorTests.swift`, and import tests exist.
- App Store safe?: Partial. MAS requires sandbox-safe access and security-scoped bookmarks for user-selected folders.
Primary files:
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Sync/VaultIndexActor.swift`
- `Epistemos/Vault/VaultRegistry.swift`
- `Epistemos/Vault/VaultLifecycleService.swift`
User entry points:
- Open/create vault.
- Sidebar/recent files.
Runtime path:
UI -> vault registry/lifecycle -> sync/index actor/file storage -> vault files/database/indexes -> visible notes/artifacts.
Current gaps:
- Verify security-scoped bookmark persistence.
- Verify deletion/rename/move updates graph/search/derived indexes.
Risk level:
P0
Recommendation:
harden

## Capability: Database / Persistence

Status:
- Built?: Yes. Evidence includes SwiftData models in `Epistemos/Models/`, GRDB/database code in `Epistemos/Engine/EpdocDatabase.swift`, and persistence tests.
- Wired?: Yes/Partial. Notes/chat/graph/search/db stores exist; derived/canonical boundaries need audit.
- User-visible?: Indirect but critical.
- Stable?: Partial. Migrations, corrupt stores, partial JSONL, and derived index rebuilds need ship-gate coverage.
- Tested?: Yes/Partial. Evidence includes `EpistemosTests/EpdocDatabaseTests.swift`, model tests, vault tests, and persistence-related suites.
- App Store safe?: Yes if all stores live in sandbox/user-approved vault paths.
Primary files:
- `Epistemos/Models/SDPage.swift`
- `Epistemos/Models/SDChat.swift`
- `Epistemos/Models/Artifact.swift`
- `Epistemos/Engine/EpdocDatabase.swift`
- `Epistemos/Models/EpistemosSchema.swift`
User entry points:
- All save/load/open workflows.
Runtime path:
UI -> model/state/service -> SwiftData/GRDB/SQLite/vault files -> persisted object/projection/index -> visible restored state.
Current gaps:
- User data must not depend on opaque cache only.
- Derived indexes must rebuild in background with visible status.
- Manifest updates must follow canonical write success.
Risk level:
P0
Recommendation:
harden

## Capability: Privacy / Sandbox / App Store Config

Status:
- Built?: Yes/Partial. Evidence includes `Epistemos/Epistemos-AppStore.entitlements`, `Epistemos/Resources/PrivacyInfo.xcprivacy`, `Epistemos-AppStore-Info.plist`, `Epistemos/AppStore/AppStoreComputerUseStubs.swift`, and App Store hardening tests.
- Wired?: Yes/Partial. MAS target compiles with App Store profile; full submission metadata remains manual/deferred.
- User-visible?: Yes through privacy/settings copy and permission flows.
- Stable?: Partial. Needs final entitlement, privacy, and App Review wording audit.
- Tested?: Yes/Partial. `EpistemosTests/AppStoreHardeningTests.swift` exists; previous MAS build log was green in `/tmp/epistemos_round2_mas_build.log`.
- App Store safe?: Partial until final review of all gated features.
Primary files:
- `Epistemos/Epistemos-AppStore.entitlements`
- `Epistemos/Resources/PrivacyInfo.xcprivacy`
- `Epistemos-AppStore-Info.plist`
- `Epistemos/AppStore/AppStoreComputerUseStubs.swift`
User entry points:
- App Store build.
- Settings/privacy pane.
- Permission prompts.
Runtime path:
build profile -> entitlements/privacy manifest/stubs -> gated runtime services -> user-safe MAS behavior.
Current gaps:
- Computer use, external CLIs, screen recording, AX, helper tools, downloads, JIT, and network disclosure need final MAS audit.
- App Store Connect assets/metadata/TestFlight are skipped for now by user instruction, not complete.
Risk level:
P0
Recommendation:
harden

## Capability: Build / Signing / Notarization Config

Status:
- Built?: Yes/Partial. Evidence includes app plist/entitlements, release docs, and prior build logs.
- Wired?: Yes/Partial. Dev/pro/MAS schemes build; final distribution archive and App Store submission gates remain open.
- User-visible?: No direct UI; critical for install/release.
- Stable?: Partial. Must not use "notarization" wording for MAS path.
- Tested?: Partial. Recent Pro and MAS build logs were green (`/tmp/epistemos_round2_build.log`, `/tmp/epistemos_round2_mas_build.log`), but full CI-style pass remains open.
- App Store safe?: Partial until archive/signing/export compliance metadata are verified.
Primary files:
- `Epistemos.xcodeproj`
- `Epistemos-Info.plist`
- `Epistemos-AppStore-Info.plist`
- `Epistemos/Epistemos.entitlements`
- `Epistemos/Epistemos-AppStore.entitlements`
- `docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md`
User entry points:
- Build/distribution pipeline.
Runtime path:
scheme/build settings -> entitlements/plist/resources -> signed app/archive -> install/TestFlight/App Store.
Current gaps:
- Distribution-signed archive, TestFlight, ASC metadata, and review-response packet are deferred/manual.
- Full suite/CI-style pass required before any ship claim.
Risk level:
P1
Recommendation:
harden

## Capability: Diagnostics / Logging / Test Infrastructure

Status:
- Built?: Yes/Partial. Evidence includes extensive `EpistemosTests/`, benchmark suites, signpost-related tests, and OSLog usage in new systems.
- Wired?: Partial. Tests exist, but in-app diagnostics and automated perf gates are incomplete.
- User-visible?: Mostly hidden; optional developer diagnostics surface may exist or be future work.
- Stable?: Partial. Need raw log capture for release claims.
- Tested?: Yes/Partial. Many tests exist; benchmark harnesses are not final ship gates by themselves.
- App Store safe?: Yes if logs avoid sensitive data.
Primary files:
- `EpistemosTests/`
- `EpistemosTests/Benchmarks/`
- `Epistemos/Engine/EpdocDocument.swift`
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`
User entry points:
- Developer diagnostics if surfaced.
- Test/build system.
Runtime path:
code path -> OSLog/signpost/test harness -> raw logs/benchmarks -> audit evidence.
Current gaps:
- Add perf gates for typing, graph pan/zoom, chat streaming, recall search, and app launch.
- Keep logs privacy-safe.
Risk level:
P1
Recommendation:
harden

## Capability: Raw Thoughts / Run Artifacts

Status:
- Built?: Partial. Evidence includes `EpistemosTests/RawThoughtsStateTests.swift`, `Epistemos/Models/MutationEnvelope.swift`, run/agent lineage stores, and agent runtime code.
- Wired?: Partial. Raw Thought persistence/timeline is not proven as a complete browsable user surface.
- User-visible?: Partial/Unknown.
- Stable?: Partial. Provider reasoning preservation and JSONL recovery are high-risk if implemented incorrectly.
- Tested?: Partial. `EpistemosTests/RawThoughtsStateTests.swift` exists; more provider byte-preservation and partial-line recovery tests are required.
- App Store safe?: Yes if it stores only provider-exposed/app-owned surfaces and avoids hidden chain-of-thought fabrication.
Primary files:
- `EpistemosTests/RawThoughtsStateTests.swift`
- `Epistemos/Vault/AgentSessionLineageStore.swift`
- `Epistemos/Vault/ChatTranscriptVaultWriter.swift`
- `Epistemos/Engine/AgentRuntime.swift`
- `agent_core/src/`
User entry points:
- Raw Thoughts/timeline if surfaced.
- Agent run inspector if wired.
Runtime path:
agent/model run -> run event capture/tool traces/provider surfaces -> JSONL/summaries/links -> Raw Thoughts timeline or run inspector.
Current gaps:
- Need run folder layout, append-only recoverable `events.jsonl`, tool call/result files, summaries, provider metadata, and links to produced artifacts.
- Anthropic thinking/signatures must be byte-identical if used for replay; OpenAI raw reasoning must not be assumed exposed.
Risk level:
P1
Recommendation:
wire

## Capability: Knowledge Core / Deterministic Runtime / FFI

Status:
- Built?: Partial. Evidence includes `Epistemos/Engine/KnowledgeCoreBridge.swift`, `EpistemosTests/KnowledgeCoreBridgeTests.swift`, graph-engine knowledge-core paths, and BoltFFI audit docs.
- Wired?: Partial. Shared-memory/deterministic runtime work may be staged; production Swift view-model update path needs proof.
- User-visible?: Indirect.
- Stable?: Unknown/Partial. Unsafe/FFI paths require layout, lifetime, and fallback tests.
- Tested?: Partial. Knowledge core bridge tests and Rust tests exist, but end-to-end mutation-to-view-model evidence is separate.
- App Store safe?: Yes if local and memory-safe.
Primary files:
- `Epistemos/Engine/KnowledgeCoreBridge.swift`
- `EpistemosTests/KnowledgeCoreBridgeTests.swift`
- `graph-engine/src/knowledge_core/`
- `graph-engine-bridge/graph_engine.h`
- `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md`
User entry points:
- Indirect through graph/search/recall/UI updates.
Runtime path:
mutation -> knowledge-core envelope/diff -> FFI/shared bridge -> Swift adapter/view model -> visible UI update.
Current gaps:
- Must prove deterministic invalidation and no over-materialization before performance claims.
- Old fallback path must remain behind feature flags.
Risk level:
P1
Recommendation:
harden

## Capability: Local / Cloud AI Model User Surface

Status:
- Built?: Yes/Partial. This crosses local and cloud provider infrastructure, settings, chat badges, and privacy copy.
- Wired?: Partial. User can likely pick/use models; exact mode/provider capability truth needs audit.
- User-visible?: Yes.
- Stable?: Partial. Unsupported modes must be hidden rather than merely failing.
- Tested?: Partial. Model and user-facing output tests exist.
- App Store safe?: Partial. Requires network/privacy/storage disclosure.
Primary files:
- `Epistemos/Engine/LLMService.swift`
- `Epistemos/Engine/LocalBackendLLMClient.swift`
- `Epistemos/Engine/LocalModelInfrastructure.swift`
- `Epistemos/Models/SDModelProfile.swift`
- `EpistemosTests/UserFacingModelOutputTests.swift`
User entry points:
- Chat model selector.
- Settings/model manager.
Runtime path:
UI -> selected profile/provider -> local/cloud client -> streamed/completed output -> chat/editor/artifact.
Current gaps:
- User should understand which models are installed, local, cloud, available, and how much storage/network they use.
Risk level:
P1
Recommendation:
harden

## Capability: Artifact Identity / Typed Artifact Routing

Status:
- Built?: Partial. Evidence includes `Epistemos/Models/Artifact.swift`, `Epistemos/Models/ArtifactKind.swift`, `Epistemos/Models/ArtifactRoute.swift`, `Epistemos/Models/GraphTypes.swift`, and artifact bridge tests.
- Wired?: Partial. Prose/code/.epdoc/run artifacts are in motion; full typed graph/search/agent routing needs audit.
- User-visible?: Indirect through sidebar/routing/open behavior.
- Stable?: Partial. Second source-of-truth risk remains if projections become canonical.
- Tested?: Partial. `EpistemosTests/GraphNodeTypeArtifactBridgeTests.swift`, `EpistemosTests/GraphNodeTypeRuntimeSyncTests.swift`, and artifact route tests exist.
- App Store safe?: Yes.
Primary files:
- `Epistemos/Models/Artifact.swift`
- `Epistemos/Models/ArtifactKind.swift`
- `Epistemos/Models/ArtifactRoute.swift`
- `Epistemos/Models/GraphTypes.swift`
User entry points:
- Sidebar/open route/search result route.
Runtime path:
UI route -> ArtifactRoute/ArtifactKind -> editor surface/service -> artifact persistence/projection -> visible artifact.
Current gaps:
- Ensure Prose, Document, RawThoughtRun, RawThoughtBlock, Source, Code, Output, Model, Concept, and Block remain distinct where implemented.
- Block graph nodes should be promoted on demand, not for every paragraph.
Risk level:
P1
Recommendation:
harden

## Phase 1 Discovery Summary

P0 risk capabilities:
- Chat System / AI Streaming
- Vault / File Watcher / Sync
- Database / Persistence
- Privacy / Sandbox / App Store Config
- Computer-Use Stack
- Notes / Prose Editor

P1 risk capabilities:
- Markdown / Prose Pipeline
- Documents / .epdoc Rich Artifact Stub
- Code Editor / Epistemos Code Surface
- Ambient Recall / Contextual Shadows / Instant Recall / Halo
- Knowledge Graph Renderer
- Graph Physics
- Search / Semantic Search / Hybrid Retrieval
- Embeddings
- Local Model Catalog
- Cloud Model Providers
- Agent Runtime
- MCP Bridge / Server
- Settings / Privacy / Model Manager
- Build / Signing / Notarization Config
- Diagnostics / Logging / Test Infrastructure
- Raw Thoughts / Run Artifacts
- Knowledge Core / Deterministic Runtime / FFI
- Local / Cloud AI Model User Surface
- Artifact Identity / Typed Artifact Routing

P2 risk capabilities:
- Quick Capture / Text Capture
- Audio / Transcription
- Command Palette / Command Center

Immediate audit implication:
- Phase 2 should start with codebase cartography and user-wiring gaps, then go deep on Ambient Recall, performance/concurrency, App Store privacy, and data persistence.
- No P0/P1 implementation should start until the Phase 2 reports, master synthesis, and patch queue exist.
