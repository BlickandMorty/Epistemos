import AppKit
import Foundation
import Testing
@testable import Epistemos

@Suite("Runtime Validation")
struct RuntimeValidationTests {
    private let inferenceDefaultsKeys = [
        "epistemos.localRoutingMode",
        "epistemos.preferredLocalTextModelID",
        "epistemos.preferredChatModelSelection",
    ]

    @MainActor
    private func withResetInferenceDefaults(
        _ body: () async throws -> Void
    ) async rethrows {
        let defaults = UserDefaults.standard
        let savedValues = inferenceDefaultsKeys.reduce(into: [String: Any?]()) { partialResult, key in
            partialResult[key] = defaults.object(forKey: key)
            defaults.removeObject(forKey: key)
        }
        defer {
            for key in inferenceDefaultsKeys {
                if let value = savedValues[key] ?? nil {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        try await body()
    }

    @MainActor
    @Test("cold bootstrap leaves the local runtime unloaded until the first real request")
    func coldBootstrapLeavesLocalRuntimeUnloaded() async {
        await withResetInferenceDefaults {
            let bootstrap = AppBootstrap()

            #expect(await bootstrap.localInferenceService.profilingSnapshot() == nil)
            #expect(bootstrap.localLLMClient.configSnapshot().provider == .localMLX)
            #expect(
                bootstrap.localLLMClient.configSnapshot().model
                    == bootstrap.inferenceState.effectiveLocalTextModelID
            )
        }
    }

    @MainActor
    @Test("inference keeps only local routing defaults after legacy cleanup")
    func inferenceKeepsOnlyLocalRoutingDefaults() async {
        await withResetInferenceDefaults {
            let inference = InferenceState()

            #expect(inference.routingMode == .auto)
            #expect(inference.preferredLocalTextModelID == LocalHardwareCapabilitySnapshot.current.recommendedLocalTextModelID.rawValue)
            #expect(
                inference.preferredChatModelSelection
                    == .localQwen(LocalHardwareCapabilitySnapshot.current.recommendedLocalTextModelID.rawValue)
            )
        }
    }

    @Test("inference migrates legacy secure cloud keys and selections forward")
    func inferenceMigratesLegacyCloudConfigurationForward() throws {
        let source = try loadRepoTextFile("Epistemos/State/InferenceState.swift")

        #expect(source.contains("migrateLegacyCloudAPIKeysIfNeeded()"))
        #expect(source.contains("epistemos.apiKey.openai"))
        #expect(source.contains("epistemos.apiKey.anthropic"))
        #expect(source.contains("epistemos.apiKey.google"))
        #expect(source.contains("migrateLegacyCloudSelection(defaults: defaults)"))
        #expect(source.contains("\"gpt-5.3\": .openAIGPT54"))
        #expect(source.contains("\"claude-sonnet-4-6\": .anthropicClaudeSonnet4"))
        #expect(source.contains("\"gemini-1.5-pro\": .googleGemini25Pro"))
    }

    @Test("chat model selector groups cloud models by provider")
    func chatModelSelectorGroupsCloudModelsByProvider() throws {
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(rootView.contains("Section(\"Cloud Models\")"))
        #expect(rootView.contains("ForEach(CloudModelProvider.allCases"))
        #expect(rootView.contains("Section(provider.displayName)"))
        #expect(rootView.contains("ForEach(CloudTextModelID.models(for: provider)"))
    }

    @MainActor
    @Test("warm relaunch bootstrap also starts without an eager local model load")
    func warmBootstrapAlsoStartsCold() async {
        let first = AppBootstrap()
        #expect(await first.localInferenceService.profilingSnapshot() == nil)

        let second = AppBootstrap()
        #expect(await second.localInferenceService.profilingSnapshot() == nil)
        #expect(AppBootstrap.shared === second)
    }

    @Test("bootstrap throttles local model refreshes and the local runtime serializes request turns")
    func bootstrapThrottlesRefreshAndRuntimeSerializesTurns() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let runtime = try loadRepoTextFile("Epistemos/Engine/MLXInferenceService.swift")

        #expect(bootstrap.contains("private final class LocalModelRefreshThrottle"))
        #expect(bootstrap.contains("private let localModelRefreshThrottle: LocalModelRefreshThrottle"))
        #expect(bootstrap.contains("let localModelRefreshThrottle = LocalModelRefreshThrottle("))
        #expect(bootstrap.contains("localModelRefreshThrottle.refreshIfNeeded()"))
        #expect(!bootstrap.contains("prepareForRequest: {\n                localModelManager.refreshFromDisk()"))
        #expect(!bootstrap.contains("prepareForRouting: {\n                localModelManager.refreshFromDisk()"))

        #expect(runtime.contains("actor LocalMLXRequestGate"))
        #expect(runtime.contains("private let requestGate = LocalMLXRequestGate()"))
        #expect(runtime.contains("await requestGate.acquire()"))
        #expect(runtime.contains("await requestGate.release()"))
    }

    @Test("bootstrap refreshes prepared retrieval runtime state on app activation")
    func bootstrapRefreshesPreparedRetrievalRuntimeStateOnActivation() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(bootstrap.contains("private func applyPreparedRetrievalRuntimeConfiguration(_ configuration: PreparedRetrievalRuntimeConfiguration?)"))
        #expect(bootstrap.contains("private func refreshPreparedRetrievalRuntimeConfigurationIfNeeded()"))
        #expect(bootstrap.contains("preparedModelRegistry.load()"))
        #expect(bootstrap.contains("queryEngine.applyPreparedRetrievalRuntimeConfiguration(configuration)"))
        #expect(bootstrap.contains("graphState.applyPreparedRetrievalRuntimeConfiguration(configuration)"))
        #expect(bootstrap.contains("self?.refreshPreparedRetrievalRuntimeConfigurationIfNeeded()"))
    }

    @MainActor
    @Test("bootstrap loads the prepared model registry")
    func bootstrapLoadsPreparedModelRegistry() async {
        let bootstrap = AppBootstrap()

        #expect(bootstrap.preparedModelRegistryState.primaryRetriever?.servedModelID == "BAAI/bge-m3")
        #expect(bootstrap.preparedModelRegistryState.lastErrorMessage == nil)
    }

    @MainActor
    @Test("bootstrap propagates prepared retrieval assets into the live graph and query runtime")
    func bootstrapPropagatesPreparedRetrievalAssets() async throws {
        let bootstrap = AppBootstrap()

        #expect(bootstrap.preparedModelRegistryState.primaryRetriever?.servedModelID == "BAAI/bge-m3")

        let graphAssets = try #require(bootstrap.graphState.preparedRetrievalRuntimeConfiguration)
        let queryAssets = try #require(bootstrap.queryEngine.preparedRetrievalRuntimeConfiguration)
        let embeddingAssets = try #require(bootstrap.graphState.embeddingService.preparedRetrievalRuntimeConfiguration)

        #expect(graphAssets.retriever.servedModelID == "BAAI/bge-m3")
        #expect(graphAssets.retriever.resolvedDownloadPath?.hasSuffix("/PreparedModels/retrieval/bge-m3/source") == true)
        #expect(queryAssets == graphAssets)
        #expect(embeddingAssets == graphAssets)
    }

    @MainActor
    @Test("bootstrap surfaces the prepared retrieval runtime state from the live asset layout")
    func bootstrapSurfacesThePreparedRetrievalRuntimeStateFromTheLiveAssetLayout() async throws {
        let bootstrap = AppBootstrap()
        let configuration = try #require(bootstrap.preparedModelRegistryState.retrievalRuntimeConfiguration)
        let layout = try #require(configuration.assetLayout)

        #expect(layout.retrieverSourceRoot.hasSuffix("/PreparedModels/retrieval/bge-m3/source"))
        if let manifest = layout.indexManifest {
            #expect(FileManager.default.fileExists(atPath: layout.embeddingsPath))
            #expect(FileManager.default.fileExists(atPath: layout.documentsPath))
            #expect(manifest.documentCount > 8)
            #expect(manifest.sourceDatabasePath?.hasSuffix("/Epistemos/search.sqlite") == true)
            #expect(manifest.sourceDatabaseModifiedAt != nil)
        } else {
            #expect(!layout.isBuilt)
        }

        let allowedModes: [PreparedRetrievalExecutionMode] = [
            .preparedIndexReady(retrieverModelID: "BAAI/bge-m3"),
            .preparedAssetsPendingIndex(retrieverModelID: "BAAI/bge-m3"),
            .appleEmbeddingFallback,
        ]
        #expect(allowedModes.contains(where: { $0 == bootstrap.graphState.preparedRetrievalExecutionMode }))
        #expect(allowedModes.contains(where: { $0 == bootstrap.queryEngine.preparedRetrievalExecutionMode }))
        #expect(allowedModes.contains(where: { $0 == bootstrap.graphState.embeddingService.preparedRetrievalExecutionMode }))
    }

    @Test("settings inference surface does not refresh local models on open")
    func settingsInferenceSurfaceDoesNotRefreshOnOpen() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settings.contains("Button(\"Refresh\")"))
        #expect(!settings.contains(".onAppear {\n            localModelManager.refreshFromDisk()"))
        #expect(!settings.contains(".task {\n            localModelManager.refreshFromDisk()"))
    }

    @Test("chat, note, graph, and settings surfaces defer on-appear state mutations off the active view update")
    func statefulSurfacesDeferOnAppearMutations() throws {
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let chatView = try loadRepoTextFile("Epistemos/Views/Chat/ChatView.swift")
        let noteSidebar = try loadRepoTextFile("Epistemos/Views/Notes/NoteChatSidebar.swift")
        let chatSidebar = try loadRepoTextFile("Epistemos/Views/Chat/ChatSidebarView.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(miniChat.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(chatView.contains(".onAppear {\n                    Task { @MainActor in"))
        #expect(noteSidebar.contains(".onAppear {\n                Task { @MainActor in"))
        #expect(chatSidebar.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(settings.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(inspector.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(workspace.contains(".onAppear {\n                Task { @MainActor in"))
    }

    @Test("settings window keeps a native source-list layout with a persistent sidebar toggle")
    func settingsWindowUsesNativeSourceListChrome() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let utilityManager = try loadRepoTextFile("Epistemos/App/UtilityWindowManager.swift")

        #expect(settings.contains(".listStyle(.sidebar)"))
        #expect(settings.contains("Image(systemName: \"sidebar.left\")"))
        #expect(settings.contains("ToolbarItem(placement: .navigation)"))
        #expect(settings.contains("toggleSidebar()"))
        #expect(utilityManager.contains("toolbar.showsBaselineSeparator = false"))
        #expect(utilityManager.contains("panel.toolbarStyle = .unifiedCompact"))
    }

    @Test("note editor still suppresses binding sync churn during AI token flushes")
    func noteEditorStillSuppressesStreamingBindingChurn() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")

        #expect(source.contains("var isFlushingTokens = false"))
        #expect(source.contains("guard !isFlushingTokens else { return }"))
        #expect(source.contains("Task.sleep(for: .milliseconds(300))"))
    }

    @Test("query runtime hot path avoids legacy full-match node sorting")
    func queryRuntimeHotPathAvoidsLegacyFullMatchNodeSorting() throws {
        let source = try loadRepoTextFile("Epistemos/Engine/QueryRuntime.swift")

        #expect(!source.contains("Array(graphStore.nodes.values)"))
        #expect(!source.contains("Array(graphStore.edges.values)"))
        #expect(!source.contains("Set(graphStore.nodes.keys)"))
        #expect(!source.contains("graphStore.nodes.values.compactMap"))
        #expect(!source.contains("graphStore.edgesByNode[scopedNodeID]"))
        #expect(!source.contains("graphStore.nodes.values.filter"))
        #expect(!source.contains("from: graphStore.nodes.values"))
        #expect(!source.contains("results.sort { $0.createdAt > $1.createdAt }"))
        #expect(source.contains("graphStore.nodes(matchingLabelContains: labelContains, types: filter.types)"))
        #expect(source.contains("graphStore.edges(for: scopedNodeID)"))
        #expect(source.contains("graphStore.nodes(matchingLabelContains: text)"))
        #expect(source.contains("graphStore.firstNode(ofType: type)?.id"))
        #expect(source.contains("graphStore.forEachNodeNewestFirst(ofTypes: filter.types)"))
        #expect(source.contains("graphStore.forEachNodeNewestFirst { node in"))
        #expect(!source.contains("graphStore.nodes.values.first { $0.type == type }"))
        #expect(!source.contains("graphStore.adjacency[$0.id]"))
        #expect(!source.contains("graphStore.adjacency[$1.id]"))
        #expect(!source.contains("graphStore.nodes[$0.id]?.createdAt"))
        #expect(!source.contains("graphStore.nodes[$1.id]?.createdAt"))
        #expect(!source.contains("graphStore.nodes[$0.id]?.updatedAt"))
        #expect(!source.contains("graphStore.nodes[$1.id]?.updatedAt"))
        #expect(source.contains("if $0.connectionCount == $1.connectionCount"))
        #expect(source.contains("return $0.connectionCount > $1.connectionCount"))
        #expect(source.contains("let a = $0.createdAt"))
        #expect(source.contains("let b = $1.createdAt"))
        #expect(source.contains("let a = $0.updatedAt"))
        #expect(source.contains("let b = $1.updatedAt"))
    }

    @Test("graph store source lookup uses the direct source index")
    func graphStoreSourceLookupUsesDirectSourceIndex() throws {
        let source = try loadRepoTextFile("Epistemos/Graph/GraphStore.swift")

        #expect(source.contains("private var _sourceLookup: [SourceLookupKey: String] = [:]"))
        #expect(source.contains("let key = SourceLookupKey(sourceId: sourceId, type: type)"))
        #expect(source.contains("_sourceLookup[key]"))
        #expect(!source.contains("nodes.values.first { $0.sourceId == sourceId && $0.type == type }"))
    }

    @Test("graph store type lookup uses the direct type index")
    func graphStoreTypeLookupUsesDirectTypeIndex() throws {
        let source = try loadRepoTextFile("Epistemos/Graph/GraphStore.swift")

        #expect(source.contains("private var _typeLookup: [GraphNodeType: Set<String>] = [:]"))
        #expect(source.contains("(_typeLookup[type] ?? []).compactMap { nodes[$0] }"))
        #expect(source.contains("func nodes(ofTypes types: [GraphNodeType]) -> [GraphNodeRecord]"))
        #expect(source.contains("guard let nodeID = _typeLookup[type]?.first else { return nil }"))
        #expect(!source.contains("nodes.values.filter { $0.type == type }"))
    }

    @Test("semantic clustering stays behind apple fallback and the shared embedding boundary")
    func semanticClusteringStaysBehindAppleFallbackAndSharedEmbeddingBoundary() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let clustering = try loadRepoTextFile("Epistemos/Graph/SemanticClusterService.swift")
        let embeddings = try loadRepoTextFile("Epistemos/Graph/EmbeddingService.swift")
        let infrastructure = try loadRepoTextFile("Epistemos/Engine/LocalModelInfrastructure.swift")
        let controls = try loadRepoTextFile("Epistemos/Views/Graph/GraphFloatingControls.swift")

        #expect(graphState.contains("var semanticClusteringAvailable: Bool"))
        #expect(graphState.contains("guard semanticClusteringAvailable else"))
        #expect(graphState.contains("func canRunFallbackSemanticSearch() -> Bool"))
        #expect(graphState.contains("func semanticSearch(query: String, limit: Int = 20)"))
        #expect(graphState.contains("for hit in semanticSearch(query: query, limit: limit)"))
        #expect(graphState.contains("embeddingService.computeFallbackSemanticClusters(store: store)"))
        #expect(!clustering.contains("NLEmbedding.wordEmbedding"))
        #expect(infrastructure.contains("var usesSwiftEmbeddingFallback: Bool"))
        #expect(embeddings.contains("swiftEmbeddingFallbackActive = preparedRetrievalExecutionMode.usesSwiftEmbeddingFallback"))
        #expect(embeddings.contains("preparedQueryEmbeddingActive = preparedRetrievalExecutionMode.hasPreparedIndexRuntime"))
        #expect(embeddings.contains("guard swiftEmbeddingFallbackActive || preparedQueryEmbeddingActive else { return nil }"))
        #expect(embeddings.contains("guard swiftEmbeddingFallbackActive else { return [:] }"))
        #expect(graphState.contains("private func preparedSemanticSearch(query: String, limit: Int) -> [GraphStore.SearchHit]?"))
        #expect(graphState.contains("manifestPath.withCString"))
        #expect(graphState.contains("graph_engine_load_prepared_retrieval_index(engine, $0)"))
        #expect(graphState.contains("graph_engine_prepared_retrieval_search("))
        #expect(!controls.contains("semanticClusterToggle"))
        #expect(!controls.contains(".disabled(!available)"))
    }

    @Test("fallback semantic query path requires a populated matching Rust embedding store")
    func fallbackSemanticQueryPathRequiresPopulatedMatchingRustStore() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let queryRuntime = try loadRepoTextFile("Epistemos/Engine/QueryRuntime.swift")

        #expect(graphState.contains("func canRunFallbackSemanticSearch() -> Bool"))
        #expect(graphState.contains("func semanticSearch(query: String, limit: Int = 20)"))
        #expect(graphState.contains("graph_engine_embedding_count(engine) > 0"))
        #expect(graphState.contains("Int(graph_engine_embedding_dimension(engine)) == embeddingService.dimension"))
        #expect(queryRuntime.contains("graphState.semanticSearch(query: query, limit: limit)"))
    }

    @Test("native semantic runtime exposes an explicit dimension reset boundary")
    func nativeSemanticRuntimeExposesDimensionResetBoundary() throws {
        let rustFFI = try loadRepoTextFile("graph-engine/src/lib.rs")
        let header = try loadRepoTextFile("graph-engine-bridge/graph_engine.h")
        let swiftWrapper = try loadRepoTextFile("Epistemos/Graph/GraphEngine.swift")

        #expect(rustFFI.contains("pub extern \"C\" fn graph_engine_embedding_dimension"))
        #expect(rustFFI.contains("pub extern \"C\" fn graph_engine_reset_embedding_dimension"))
        #expect(header.contains("uint32_t graph_engine_embedding_dimension(Engine* engine);"))
        #expect(header.contains("uint8_t graph_engine_reset_embedding_dimension(Engine* engine, uint32_t dim);"))
        #expect(swiftWrapper.contains("func semanticEmbeddingDimension() -> Int"))
        #expect(swiftWrapper.contains("func resetSemanticEmbeddingDimension(to dimension: Int) -> Bool"))
    }

    @Test("retired graph ffi controls stay out of the live bridge surface")
    func retiredGraphFFIControlsStayRemoved() throws {
        let rustFFI = try loadRepoTextFile("graph-engine/src/lib.rs")
        let header = try loadRepoTextFile("graph-engine-bridge/graph_engine.h")

        let retiredExports = [
            "graph_engine_set_lite_mode",
            "graph_engine_set_time_filter",
            "graph_engine_add_version",
            "graph_engine_get_version_count",
            "graph_engine_dialogue_open",
            "graph_engine_dialogue_close",
            "graph_engine_dialogue_set_streaming",
            "graph_engine_dialogue_screen_rect",
            "graph_engine_dialogue_node_screen_pos",
            "graph_engine_dialogue_is_active",
        ]

        for symbol in retiredExports {
            #expect(!rustFFI.contains(symbol))
            #expect(!header.contains(symbol))
        }
    }

    @Test("live local ai surfaces stay free of sidecar and deepseek residue")
    func liveLocalAISurfacesStayFreeOfSidecarAndDeepSeekResidue() throws {
        let llm = try loadRepoTextFile("Epistemos/Engine/LLMService.swift")
        let triage = try loadRepoTextFile("Epistemos/Engine/TriageService.swift")
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")

        for banned in [
            "LocalSidecar",
            "mlx-openai-server",
            "http://127.0.0.1",
            "DeepSeek",
        ] {
            #expect(!llm.contains(banned))
            #expect(!triage.contains(banned))
            #expect(!inference.contains(banned))
        }
    }

    @Test("native cleanup fallback grep uses word boundaries for legacy runtime bans")
    func nativeCleanupFallbackGrepUsesWordBoundaries() throws {
        let scan = try loadRepoTextFile("scripts/audit/native_cleanup_scan.sh")

        #expect(scan.contains(#"\\breasoner\\b"#))
        #expect(scan.contains(#"\\bSSE\\b"#))
        #expect(!scan.contains("|SSE'"))
        #expect(scan.contains("ast-grep scan --rule"))
        #expect(scan.contains("${ROOT_DIR}/Epistemos/Engine"))
        #expect(scan.contains("${ROOT_DIR}/Epistemos/Graph"))
        #expect(scan.contains("${ROOT_DIR}/Epistemos/Views/Graph"))
        #expect(scan.contains("periphery scan --project Epistemos.xcodeproj --schemes Epistemos --targets Epistemos --format xcode"))
        #expect(scan.contains("cd '${ROOT_DIR}/graph-engine' && cargo machete"))
    }

    @Test("chat coordinator caches manifest note search fields off the main actor")
    func chatCoordinatorCachesManifestNoteSearchFieldsOffTheMainActor() throws {
        let coordinator = try loadRepoTextFile("Epistemos/App/ChatCoordinator.swift")

        #expect(coordinator.contains("private struct PreparedManifestSearchEntry"))
        #expect(coordinator.contains("private nonisolated static func preparedManifestSearchEntries("))
        #expect(coordinator.contains("private nonisolated static func autoMatchedReferencedNoteIDs("))
        #expect(coordinator.contains("private nonisolated static func noteSearchScore("))
        #expect(coordinator.contains("let preparedEntries = preparedManifestSearchEntries(for: manifest)"))
        #expect(coordinator.contains("let entriesByPageID = Dictionary("))
    }

    @Test("prepared retrieval scorer uses a dedicated candidate list ffi")
    func preparedRetrievalScorerUsesDedicatedCandidateListFFI() throws {
        let queryRuntime = try loadRepoTextFile("Epistemos/Engine/QueryRuntime.swift")
        let rustFFI = try loadRepoTextFile("graph-engine/src/lib.rs")
        let header = try loadRepoTextFile("graph-engine-bridge/graph_engine.h")

        #expect(queryRuntime.contains("graph_engine_prepared_retrieval_score_page_ids("))
        #expect(queryRuntime.contains("graph_engine_free_prepared_retrieval_candidates(list)"))
        #expect(queryRuntime.contains("result.page_id"))
        #expect(!queryRuntime.contains("graph_engine_free_search_results(results, count)"))
        #expect(header.contains("GraphEnginePreparedRetrievalCandidate"))
        #expect(header.contains("GraphEnginePreparedRetrievalCandidateList"))
        #expect(header.contains("graph_engine_free_prepared_retrieval_candidates"))
        #expect(rustFFI.contains("pub struct GraphEnginePreparedRetrievalCandidate"))
        #expect(rustFFI.contains("pub struct GraphEnginePreparedRetrievalCandidateList"))
        #expect(rustFFI.contains("pub extern \"C\" fn graph_engine_free_prepared_retrieval_candidates"))
    }

    @Test("strict verification suite keeps compiler and purge gates wired")
    func strictVerificationSuiteKeepsCompilerAndPurgeGatesWired() throws {
        let verify = try loadRepoTextFile("scripts/audit/verify.sh")
        let cleanupSuite = try loadRepoTextFile("scripts/audit/cleanup_suite.sh")

        #expect(verify.contains("cargo clippy --manifest-path graph-engine/Cargo.toml --all-targets --all-features -- -D warnings -D dead_code"))
        #expect(verify.contains("cargo test --manifest-path graph-engine/Cargo.toml"))
        #expect(verify.contains("native_cleanup_scan.sh"))
        #expect(verify.contains("OTHER_SWIFT_FLAGS='\\$(inherited) -Xfrontend -strict-concurrency=complete'"))
        #expect(verify.contains("MallocStackLogging=1"))
        #expect(verify.contains("leaks Epistemos"))
        #expect(verify.contains("powermetrics --samplers gpu_power"))
        #expect(cleanupSuite.contains("./scripts/audit/verify.sh"))
    }

    @Test("landing surface no longer mounts live cursor fx overlays or controls")
    func landingSurfaceNoLongerMountsLiveCursorFXOverlaysOrControls() throws {
        let landingView = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let pageShell = try loadRepoTextFile("Epistemos/Views/Shell/PageShell.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let uiState = try loadRepoTextFile("Epistemos/State/UIState.swift")
        let liquidGreeting = try loadRepoTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")

        #expect(!landingView.contains("currentCursorSurface"))
        #expect(!landingView.contains("landingWakeVocabulary"))
        #expect(!landingView.contains("ui.landingCursorVisibilityMode.shows(on: surface)"))
        #expect(!landingView.contains("pointerState.registerTap(at: value.location)"))
        #expect(!landingView.contains("LandingASCIIWakeField"))
        #expect(!landingView.contains("LandingPointerState"))
        #expect(!rootView.contains("Cursor FX"))
        #expect(!rootView.contains("LandingCursorControlsView"))
        #expect(!rootView.contains("cursorVisible"))
        #expect(!settings.contains("Cursor Visibility"))
        #expect(!settings.contains("Cursor Animation"))
        #expect(!liquidGreeting.contains("cursorBlinkLoop"))
        #expect(!liquidGreeting.contains("cursorVisible"))
        #expect(!pageShell.contains("cursorVisible"))
        #expect(!uiState.contains("var landingCursorAnimationEnabled"))
        #expect(!uiState.contains("var landingCursorVisibilityMode"))
        #expect(uiState.contains("\"epistemos.landingCursorAnimationEnabled\""))
    }

    @Test("command palette source files are removed from the app")
    func commandPaletteSourceFilesAreRemoved() {
        let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Landing/CommandPaletteOverlay.swift").path))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Landing/CommandPaletteWindowController.swift").path))
    }

    @Test("search index uses a user-initiated query queue for interactive full text search")
    func searchIndexUsesUserInitiatedQueryQueueForInteractiveSearch() throws {
        let searchIndex = try loadRepoTextFile("Epistemos/Sync/SearchIndexService.swift")

        #expect(searchIndex.contains("DatabasePool"))
        #expect(searchIndex.contains("label: \"com.epistemos.search-index.query\""))
        #expect(searchIndex.contains("attributes: .concurrent"))
        #expect(searchIndex.contains("try await offloadSearch { [self] cancellation in"))
        #expect(searchIndex.contains("private final class OffloadedSearchStateBox"))
        #expect(searchIndex.contains("private struct OffloadedSearchCancellationProbe"))
        #expect(searchIndex.contains("private final class SQLiteCancellationContext"))
        #expect(searchIndex.contains("func check() throws"))
        #expect(searchIndex.contains("try cancellation.check()"))
        #expect(searchIndex.contains("let cancellation = OffloadedSearchCancellationProbe {"))
        #expect(searchIndex.contains("currentState.isCancelled()"))
        #expect(searchIndex.contains("return try await withTaskCancellationHandler"))
        #expect(searchIndex.contains("stateBox.cancel()"))
        #expect(searchIndex.contains("private nonisolated static func withSQLiteCancellation"))
        #expect(searchIndex.contains("sqlite3_progress_handler("))
    }

    @Test("notes sidebar caches title matches outside the render path")
    func notesSidebarCachesTitleMatchesOutsideRenderPath() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")

        #expect(sidebar.contains("@State private var titleSearchResults: [SidebarPageItem] = []"))
        #expect(sidebar.contains("@State private var cachedPageSearchCatalog: [SidebarPageSearchCatalogEntry] = []"))
        #expect(sidebar.contains("@State private var cachedPageSearchCatalogById: [String: SidebarPageSearchCatalogEntry] = [:]"))
        #expect(sidebar.contains("@State private var cachedPageSearchTrigramIndex = TrigramSearchIndex<String>()"))
        #expect(sidebar.contains("@State private var cachedTitleSearchResultIDsByQuery: [String: [String]] = [:]"))
        #expect(sidebar.contains("@State private var cachedBodySearchResultsByQuery: [String: [SidebarPageItem]] = [:]"))
        #expect(sidebar.contains("refreshTitleSearchResults(query: notesUI.searchQuery)"))
        #expect(sidebar.contains("titleSearchResults + uniqueBodyMatches"))
        #expect(sidebar.contains("cachedPageSearchTrigramIndex.rebuild("))
        #expect(sidebar.contains("private func longestCachedTitleSearchPrefixIDs(for query: String) -> [String]?"))
        #expect(sidebar.contains("let matchedIDs = cachedTitleSearchResultIDsByQuery[normalizedQuery] ?? {"))
        #expect(sidebar.contains("let candidateIDs = longestCachedTitleSearchPrefixIDs(for: normalizedQuery)"))
        #expect(sidebar.contains("cachedPageSearchTrigramIndex.orderedCandidates(for: normalizedQuery)"))
        #expect(sidebar.contains("guard normalizedQuery.count >= 3 else"))
        #expect(sidebar.contains("if let cached = cachedBodySearchResultsByQuery[normalizedQuery]"))
        #expect(sidebar.contains("cachedBodySearchResultsByQuery[normalizedQuery] = results"))
        #expect(sidebar.contains("private func refreshTitleSearchResults(query: String)"))
    }

    @Test("graph selection ignores redundant same-node picks")
    func graphSelectionIgnoresRedundantSameNodePicks() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let graphStore = try loadRepoTextFile("Epistemos/Graph/GraphStore.swift")
        let inspectorState = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(graphState.contains("guard selectedNodeId != id else { return }"))
        #expect(graphStore.contains("func neighborLabels(of nodeId: String) -> [String]"))
        #expect(graphStore.contains("private var neighborLabelsCache: [String: [String]] = [:]"))
        #expect(graphStore.contains("if let cached = neighborLabelsCache[nodeId]"))
        #expect(inspectorState.contains("let linkedLabels = store.neighborLabels(of: nodeId)"))
        #expect(!inspectorState.contains("store.neighbors(of: node.id).map(\\.label)"))
    }

    @Test("graph selection tracking throttles inspector position churn")
    func graphSelectionTrackingThrottlesInspectorPositionChurn() throws {
        let metalView = try loadRepoTextFile("Epistemos/Views/Graph/MetalGraphView.swift")
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(metalView.contains("private var sampledSelectedNodeId: String?"))
        #expect(metalView.contains("private var lastPublishedSelectedNodeScreenPoint: CGPoint?"))
        #expect(metalView.contains("private var pendingSelectedNodeScreenPoint: CGPoint?"))
        #expect(metalView.contains("private var selectedNodeScreenPointStableFrames = 0"))
        #expect(metalView.contains("private var selectedNodeScreenPointSampleFrame = 0"))
        #expect(metalView.contains("private let selectedNodeScreenPointSampleIntervalFrames = 1"))
        #expect(metalView.contains("selectedNodeScreenPointSampleFrame % selectedNodeScreenPointSampleIntervalFrames == 0"))
        #expect(metalView.contains("lastPublishedSelectedNodeScreenPoint == nil"))
        #expect(metalView.contains("pendingSelectedNodeScreenPoint == nil"))
        #expect(overlay.contains("private var inspectorRepositionTask: Task<Void, Never>?"))
        #expect(overlay.contains("private var lastQueuedInspectorAnchor: CGPoint?"))
        #expect(overlay.contains("private var lastQueuedInspectorMode: NodeInspectorState.InspectorMode?"))
        #expect(overlay.contains("Reposition immediately"))
        #expect(overlay.contains("private func shouldQueueInspectorReposition("))
        #expect(overlay.contains("private var lastInspectorFrame: CGRect?"))
        #expect(overlay.contains("private func shouldApplyInspectorFrame(_ targetFrame: CGRect) -> Bool"))
    }

    @Test("graph sidebar caches notes tree snapshots across selection churn")
    func graphSidebarCachesNotesTreeSnapshotsAcrossSelectionChurn() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")

        #expect(sidebar.contains("@State private var cachedNotesTreeSnapshot"))
        #expect(sidebar.contains("@State private var cachedNotesTreeTopologyVersion = -1"))
        #expect(sidebar.contains("refreshNotesTreeSnapshotIfNeeded()"))
        #expect(sidebar.contains("cachedNotesTreeTopologyVersion != topologyVersion"))
        #expect(sidebar.contains("let snapshot = cachedNotesTreeSnapshot"))
    }

    @Test("graph node inspector keeps summary generation off the immediate selection turn")
    func graphNodeInspectorKeepsSummaryGenerationOffImmediateSelectionTurn() throws {
        let inspectorState = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")
        let inspectorView = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")

        #expect(!inspectorState.contains("summaryKickoffTask"))
        #expect(inspectorState.contains("func ensureSummary(for node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext)"))
        #expect(inspectorState.contains("summaryTask?.cancel()"))
        #expect(inspectorState.contains("guard !Task.isCancelled, selectedNodeId == node.id else { return }"))
        #expect(inspectorView.contains("guard newSection == .summary else { return }"))
        #expect(inspectorView.contains("inspectorState.ensureSummary(for: node, store: graphState.store, modelContext: modelContext)"))
    }

    @Test("graph summaries still prefer Apple Intelligence before local Qwen fallback")
    func graphSummariesStayAppleFirst() throws {
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(inspector.contains("Try Apple Intelligence first for a fast on-device summary, then local Qwen."))
        #expect(inspector.contains("AppleIntelligenceService.shared.generate("))
    }

    @Test("node inspector derives profiles off the main actor and caches them by node version")
    func nodeInspectorDerivesProfilesOffTheMainActorAndCachesThemByNodeVersion() throws {
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(inspector.contains("private var profileCache: [ProfileCacheKey: DialogueNodeProfile] = [:]"))
        #expect(inspector.contains("let derived = await Task.detached(priority: .userInitiated)"))
        #expect(inspector.contains("let normalizedBody = noteBody.trimmingCharacters(in: .whitespacesAndNewlines)"))
        #expect(inspector.contains("let freqKeywords = focusKeywords("))
        #expect(inspector.contains("self.profileCache[cacheKey] = derived"))
        #expect(inspector.contains("if let cachedProfile = profileCache[cacheKey]"))
        #expect(inspector.contains("displayedSummary = full"))
        #expect(!inspector.contains("Task.sleep(for: .milliseconds(16))"))
    }

    @Test("node inspector chat expands folder descendants and linked graph context")
    func nodeInspectorChatExpandsFolderDescendantsAndLinkedGraphContext() throws {
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(inspector.contains("let predicate = #Predicate<SDFolder> { $0.id == folderID }"))
        #expect(inspector.contains("return subfolder == relativePath || (!nestedPrefix.isEmpty && subfolder.hasPrefix(nestedPrefix))"))
        #expect(inspector.contains("Items loaded for context:"))
        #expect(inspector.contains("Connected graph context:"))
        #expect(inspector.contains("Treat folder context as a bundle of descendant notes and relationships"))
    }

    @Test("note picker uses a dedicated split context panel instead of the cramped mention dropdown")
    func notePickerUsesDedicatedSplitContextPanel() throws {
        let popover = try loadRepoTextFile("Epistemos/Views/Chat/NotesMentionDropdown.swift")

        #expect(popover.contains("if style == .notePicker"))
        #expect(popover.contains("notePickerSidebar"))
        #expect(popover.contains("Attach exactly what this turn should know."))
        #expect(popover.contains("Attach the vault retrieval index for this turn."))
        #expect(popover.contains("Searches titles, folders, tags, and indexed body snippets."))
        #expect(popover.contains("final class ComposerReferencePopoverCoordinator"))
        #expect(popover.contains("private let popover = NSPopover()"))
        #expect(popover.contains("self.popover.show("))
        #expect(popover.contains("await Task.yield()"))
        #expect(popover.contains("guard let self, let anchorView, anchorView.window != nil"))
        #expect(!popover.contains("GeometryReader { proxy in"))
    }

    @Test("note editor keeps markdown tables as plain editor text")
    func noteEditorKeepsMarkdownTablesAsPlainEditorText() throws {
        let tk2 = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")

        #expect(tk2.contains("tv.usesRenderedTableOverlays = false"))
        #expect(tk2.contains("tv.markdownDelegate.usesRenderedTableOverlays = false"))
        #expect(!tk2.contains("coord.renderedTableOverlayManager = RenderedTableOverlayManager2("))
    }

    @Test("mini chat stays a real resizable window without the removed palette shell")
    func miniChatStaysARealResizableWindowWithoutPaletteShell() throws {
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let controller = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")

        #expect(controller.contains("styleMask: [.titled, .closable, .resizable, .fullSizeContentView]"))
        #expect(controller.contains("window.maxSize = NSSize(width: 1600, height: 1400)"))
        #expect(miniChat.contains(".padding(.horizontal, 28)"))
        #expect(miniChat.contains(".padding(.top, 18)"))
        #expect(miniChat.contains(".padding(.bottom, 20)"))
        #expect(miniChat.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        #expect(!miniChat.contains("AssistantSurfaceChrome(theme: theme, metrics: surfaceMetrics)"))
        #expect(miniChat.contains("static let messageColumnMaxWidth: CGFloat = 560"))
        #expect(miniChat.contains("MiniChatBubble(message: msg)\n                                            .frame(maxWidth: .infinity)"))
        #expect(miniChat.contains("HStack {\n                            Spacer(minLength: 0)"))
        #expect(miniChat.contains("}\n                        .frame(maxWidth: .infinity)"))
        #expect(miniChat.contains(".background(theme.userBubbleBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))"))
        #expect(miniChat.contains("HStack(spacing: 0) {"))
        #expect(miniChat.contains("Spacer(minLength: 0)"))
        #expect(miniChat.contains(".frame(maxWidth: .infinity)"))
    }

    @Test("mini chat launches in its own real window and keeps main-chat styling cues")
    func miniChatUsesDedicatedWindowAndCompactMainChatLayout() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let statusBar = try loadRepoTextFile("Epistemos/App/StatusBar.swift")
        let intents = try loadRepoTextFile("Epistemos/Intents/Custom/NavigationIntents.swift")
        let sidebar = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let windowController = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(app.contains("MiniChatWindowController.shared.openNewChat()"))
        #expect(statusBar.contains("MiniChatWindowController.shared.openNewChat()"))
        #expect(intents.contains("MiniChatWindowController.shared.show()"))
        #expect(sidebar.contains("MiniChatWindowController.shared.openNewChat()"))
        #expect(!app.contains("CommandPaletteWindowController"))
        #expect(!statusBar.contains("CommandPaletteWindowController"))
        #expect(!intents.contains("CommandPaletteWindowController"))
        #expect(!sidebar.contains("CommandPaletteWindowController"))

        #expect(app.contains(".keyboardShortcut(\"3\", modifiers: .command)"))
        #expect(landing.contains(".keyboardShortcut(\"3\", modifiers: .command)"))
        #expect(landing.contains("CommandHint(modIcon: \"command\", key: \"3\", label: \"Mini Chat\", theme: theme)"))

        #expect(windowController.contains("let window = NSWindow("))
        #expect(!windowController.contains(".nonactivatingPanel"))
        #expect(!windowController.contains(".utilityWindow"))
        #expect(!windowController.contains("let panel = NSPanel("))
        #expect(windowController.contains("WindowPresentationPolicy.applyModularZoomBehavior("))
        #expect(windowController.contains("minimumContentSize: Self.minimumContentSize"))
        #expect(windowController.contains("window.maxSize = NSSize(width: 1600, height: 1400)"))
        #expect(windowController.contains("window.tabbingMode = .preferred"))
        #expect(windowController.contains("window.tabbingIdentifier = \"epistemos-mini-chat-tabs\""))
        #expect(!windowController.contains(".padding(22)"))

        #expect(miniChat.contains("ChatComposerTextEditor("))
        #expect(miniChat.contains(".assistantComposerChrome("))
        #expect(miniChat.contains("TaggedMarkdownTextView("))
        #expect(miniChat.contains(".frame(maxWidth: 360, alignment: .leading)"))
    }

    @Test("mini chat uses native macOS tab groups and loads app-wide chats by chat id")
    func miniChatUsesNativeMacOSTabGroupsAndLoadsAppWideChatsByChatId() throws {
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let threadState = try loadRepoTextFile("Epistemos/State/ThreadState.swift")
        let windowController = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")

        #expect(!miniChat.contains("MiniChatTabBar"))
        #expect(!miniChat.contains("threadState.activeMiniChatThread()"))
        #expect(miniChat.contains("Recent Chats"))
        #expect(miniChat.contains("MiniChatWindowController.shared.openNewChat()"))
        #expect(miniChat.contains("MiniChatWindowController.shared.openChat("))
        #expect(threadState.contains("func upsertMiniChatSession("))
        #expect(threadState.contains("func miniChatSession(id: String) -> ChatThread?"))
        #expect(windowController.contains("window.tabbingIdentifier = \"epistemos-mini-chat-tabs\""))
        #expect(windowController.contains("existingWindow.addTabbedWindow(window, ordered: .above)"))
    }

    @Test("main chat pipeline stays aligned with the compact chat streaming path")
    func mainChatPipelineMatchesCompactChatStreamingPath() throws {
        let pipeline = try loadRepoTextFile("Epistemos/Engine/PipelineService.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let triage = try loadRepoTextFile("Epistemos/Engine/TriageService.swift")

        #expect(pipeline.contains("localSurface: .miniChat"))
        #expect(miniChat.contains("localSurface: .miniChat"))
        #expect(!pipeline.contains("Response too short"))
        #expect(!pipeline.contains("No response received"))
        #expect(!pipeline.contains("finalVisibleAnswer.count >= 10"))
        #expect(triage.contains("if prefersDedicatedLocalChatRouting("))
        #expect(triage.contains("case .mainChat, .miniChat:"))
    }

    @Test("apple fallback preserves the available response when local qwen is unavailable")
    func appleFallbackKeepsVisibleResponseWhenLocalFallbackFails() throws {
        let triage = try loadRepoTextFile("Epistemos/Engine/TriageService.swift")

        #expect(triage.contains("Log.engine.info(\"Local model fallback also failed — using Apple Intelligence response\")"))
        #expect(triage.contains("continuation.yield(result)"))
        #expect(!triage.contains("if !Self.isRefusalResponse(result)"))
        #expect(triage.contains("selectedRoute: .appleIntelligence"))
        #expect(triage.contains("localSelection: localSelection.selection"))
    }

    @Test("chat model selection can explicitly force Apple Intelligence")
    func chatModelSelectionCanExplicitlyForceAppleIntelligence() throws {
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")
        let triage = try loadRepoTextFile("Epistemos/Engine/TriageService.swift")
        let root = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(inference.contains("enum ChatModelSelection"))
        #expect(inference.contains("case appleIntelligence"))
        #expect(inference.contains("var preferredChatModelSelection"))
        #expect(triage.contains("preferredChatModelSelection"))
        #expect(triage.contains("selectedRoute: .appleIntelligence"))
        #expect(root.contains("Apple Intelligence"))
        #expect(root.contains("setPreferredChatModelSelection("))
    }

    @Test("chat model selector always exposes cloud models and shows configuration guidance")
    func chatModelSelectorAlwaysExposesCloudModelsAndShowsConfigurationGuidance() throws {
        let root = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(root.contains("Section(\"Cloud Models\")"))
        #expect(root.contains("ForEach(CloudModelProvider.allCases"))
        #expect(root.contains("Section(provider.displayName)"))
        #expect(root.contains(".disabled(!providerConfigured)"))
        #expect(root.contains("Add API keys in Settings to enable cloud models"))
    }

    @Test("chat file picker defers panel presentation and reads files under a security scope")
    func chatFilePickerDefersPanelPresentationAndReadsFilesUnderASecurityScope() throws {
        let chatInput = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")

        #expect(chatInput.contains("await Task.yield()"))
        #expect(chatInput.contains("panel.beginSheetModal(for: window, completionHandler: handler)"))
        #expect(chatInput.contains("panel.begin(completionHandler: handler)"))
        #expect(chatInput.contains("url.startAccessingSecurityScopedResource()"))
        #expect(chatInput.contains("url.stopAccessingSecurityScopedResource()"))
    }

    @Test("node inspector profile copy avoids synthetic knowledge cluster filler text")
    func nodeInspectorProfileCopyAvoidsSyntheticKnowledgeClusterFillerText() throws {
        let inspectorState = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")
        let inspectorView = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")

        #expect(!inspectorState.contains("is part of a connected knowledge cluster"))
        #expect(inspectorView.contains("if !p.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty"))
    }

    @Test("regex-backed presentation helpers avoid force-try compilation")
    func regexBackedPresentationHelpersAvoidForceTryCompilation() throws {
        let files = [
            "Epistemos/Sync/BlockPropertyParser.swift",
            "Epistemos/Views/Chat/ChatView.swift",
            "Epistemos/Views/Chat/TaggedMarkdownTextView.swift",
            "Epistemos/Views/Notes/MarkdownContentStorage.swift",
            "Epistemos/Views/Notes/MarkdownEditorStyle.swift",
            "Epistemos/Theme/EpistemosTheme.swift",
            "Epistemos/Theme/GlassModifiers.swift",
        ]

        for file in files {
            let source = try loadRepoTextFile(file)
            #expect(!source.contains("try!"), "\(file) should not use try! for regex or detector setup")
        }
    }

    @Test("block mirror similarity avoids quadratic edit-distance buffers")
    func blockMirrorSimilarityAvoidsQuadraticEditDistanceBuffers() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/BlockMirror.swift")

        #expect(!source.contains("Array(lhs.utf16)"))
        #expect(!source.contains("Array(rhs.utf16)"))
        #expect(!source.contains("var previous = Array(0...right.count)"))
        #expect(!source.contains("var current = Array(repeating: 0, count: right.count + 1)"))
    }

    @Test("read only note windows use the shared app environment helper")
    func readOnlyNoteWindowsUseSharedAppEnvironmentHelper() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteWindowManager.swift")

        #expect(source.contains("ReadOnlyVersionView(title: title, versionBody: body, dateLabel: dateStr)\n            .withAppEnvironment(bootstrap)"))
        #expect(!source.contains("ReadOnlyVersionView(title: title, versionBody: body, dateLabel: dateStr)\n            .environment(bootstrap.uiState)"))
    }

    @Test("bootstrap and persistence helpers avoid force-trap fallbacks")
    func bootstrapAndPersistenceHelpersAvoidForceTrapFallbacks() throws {
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let feedbackLogger = try loadRepoTextFile("Epistemos/KnowledgeFusion/Alignment/FeedbackLogger.swift")
        let mcpBridge = try loadRepoTextFile("Epistemos/Omega/MCPBridge.swift")
        let activityTracker = try loadRepoTextFile("Epistemos/State/ActivityTracker.swift")
        let eventStore = try loadRepoTextFile("Epistemos/State/EventStore.swift")
        let appStoreHelper = try loadRepoTextFile("Epistemos/Omega/Distribution/AppStoreHelper.swift")
        let adapterRegistry = try loadRepoTextFile("Epistemos/KnowledgeFusion/Adapters/AdapterRegistry.swift")
        let skillManifest = try loadRepoTextFile("Epistemos/KnowledgeFusion/SkillGeneration/SkillManifest.swift")
        let pythonEnvironmentManager = try loadRepoTextFile("Epistemos/KnowledgeFusion/PythonEnvironmentManager.swift")
        let knowledgeFusionViewModel = try loadRepoTextFile("Epistemos/KnowledgeFusion/UI/KnowledgeFusionViewModel.swift")
        let trainingScheduler = try loadRepoTextFile("Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift")
        let qualityCurator = try loadRepoTextFile("Epistemos/KnowledgeFusion/SyntheticData/QualityCurator.swift")
        let experienceReplayBuffer = try loadRepoTextFile("Epistemos/KnowledgeFusion/Training/ExperienceReplayBuffer.swift")
        let chatSidebar = try loadRepoTextFile("Epistemos/Views/Chat/ChatSidebarView.swift")
        let dataDetectionService = try loadRepoTextFile("Epistemos/Engine/DataDetectionService.swift")
        let queryParser = try loadRepoTextFile("Epistemos/Engine/QueryParser.swift")
        let structuredQueryParser = try loadRepoTextFile("Epistemos/Engine/StructuredQueryParser.swift")

        #expect(!appBootstrap.contains("try! ModelContainer("))
        #expect(!feedbackLogger.contains("try! JSONSerialization.data"))
        #expect(!feedbackLogger.contains("String(data: data, encoding: .utf8)!"))
        #expect(!mcpBridge.contains(".first!"))
        #expect(!activityTracker.contains(".first!"))
        #expect(!eventStore.contains(".first!"))
        #expect(!appStoreHelper.contains(".first!"))
        #expect(!adapterRegistry.contains(".first!"))
        #expect(!skillManifest.contains(".first!"))
        #expect(!pythonEnvironmentManager.contains(".first!"))
        #expect(!knowledgeFusionViewModel.contains(".first!"))
        #expect(!trainingScheduler.contains(".first!"))
        #expect(!qualityCurator.contains("String(data: data, encoding: .utf8)!"))
        #expect(!experienceReplayBuffer.contains("String(data: data, encoding: .utf8)!"))
        #expect(!chatSidebar.contains("calendar.date(byAdding: .day, value: -1, to: startOfToday)!"))
        #expect(!chatSidebar.contains("calendar.date(byAdding: .day, value: -7, to: startOfToday)!"))
        #expect(!dataDetectionService.contains("URL(string: \"webcal://\")!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .day, value: -1, to: now)!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .day, value: -7, to: now)!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .month, value: -1, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .day, value: -1, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .day, value: -7, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .month, value: -1, to: now)!"))
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}

@Suite("Audit Hardening Regression")
struct AuditHardeningRegressionTests {
    @Test("Inline response replacement discards stale response before restart")
    @MainActor func inlineResponseReplacementDiscardsStaleResponse() {
        let inference = InferenceState()
        let triage = TriageService(
            inference: inference,
            localLLMService: AuditCapturingStreamingLLMClient()
        )

        let state = NoteChatState(pageId: "page-inline-regression")
        state.noteBodyProvider = { "Original note body." }
        state.hasResponse = true
        state.useResponsePanel = false
        state.responseText = "stale inline response"

        var events: [String] = []
        state.onDiscard = { events.append("discard") }
        state.onStreamStart = { _ in events.append("start") }

        state.submitQuery(
            "Rewrite this paragraph",
            operation: .rewrite,
            triageService: triage
        )

        #expect(Array(events.prefix(2)) == ["discard", "start"])
        #expect(state.hasResponse)
        #expect(state.responseText.isEmpty)
    }

    @Test("Text views protect the divider while allowing AI text edits")
    @MainActor func textViewsProtectDividerWhileAllowingAITextEdits() {
        assertDividerProtection(on: ProseTextView2(frame: .zero))
    }

    @Test("Vault destructive stop snapshots before clearing local data")
    func vaultDestructiveStopSnapshotsBeforeClearing() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let destructiveBlock = try #require(source.range(of: "if !preserveData {"))
        let destructiveBody = source[destructiveBlock.lowerBound...]
        let snapshotCall = try #require(destructiveBody.range(of: "try snapshotLocalState()"))
        let clearCall = try #require(destructiveBody.range(of: "clearVaultData()"))

        #expect(snapshotCall.lowerBound > destructiveBlock.lowerBound)
        #expect(snapshotCall.lowerBound < clearCall.lowerBound)
    }

    @Test("Omega planner schemas stay aligned with registered MCP tools")
    @MainActor func omegaPlannerSchemasStayAligned() throws {
        let inference = InferenceState()
        let triage = TriageService(inference: inference)
        let planner = OmegaInferenceBridge(triageService: triage)
        let runtime = MCPBridge()

        let data = try #require(planner.toolSchemasJson.data(using: .utf8))
        let schemas = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        #expect(!schemas.isEmpty)
        #expect(schemas.count == runtime.toolCount)
        #expect(schemas.count == OmegaToolRegistry.all.count)
    }

    @Test("Regex-backed helpers avoid force-try compilation")
    func regexBackedHelpersAvoidForceTryCompilation() throws {
        let files = [
            "Epistemos/Sync/BlockPropertyParser.swift",
            "Epistemos/Views/Chat/ChatView.swift",
            "Epistemos/Views/Chat/TaggedMarkdownTextView.swift",
            "Epistemos/Views/Notes/MarkdownContentStorage.swift",
            "Epistemos/Views/Notes/MarkdownEditorStyle.swift",
            "Epistemos/Theme/EpistemosTheme.swift",
            "Epistemos/Theme/GlassModifiers.swift",
        ]

        for file in files {
            let source = try loadRepoTextFile(file)
            #expect(!source.contains("try!"), "\(file) should not use try! for regex or detector setup")
        }
    }

    @Test("Trap-prone persistence fallbacks stay removed")
    func trapPronePersistenceFallbacksStayRemoved() throws {
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let feedbackLogger = try loadRepoTextFile("Epistemos/KnowledgeFusion/Alignment/FeedbackLogger.swift")
        let dataDetectionService = try loadRepoTextFile("Epistemos/Engine/DataDetectionService.swift")
        let queryParser = try loadRepoTextFile("Epistemos/Engine/QueryParser.swift")
        let structuredQueryParser = try loadRepoTextFile("Epistemos/Engine/StructuredQueryParser.swift")

        #expect(!appBootstrap.contains("try! ModelContainer("))
        #expect(!feedbackLogger.contains("try! JSONSerialization.data"))
        #expect(!feedbackLogger.contains("String(data: data, encoding: .utf8)!"))
        #expect(!dataDetectionService.contains("URL(string: \"webcal://\")!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .day, value: -1, to: now)!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .day, value: -7, to: now)!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .month, value: -1, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .day, value: -1, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .day, value: -7, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .month, value: -1, to: now)!"))
    }

    @Test("launch and note shell surfaces keep explicit loading empty and accessibility states")
    func launchAndNoteShellSurfacesKeepExplicitPolishStates() throws {
        let timeMachine = try loadRepoTextFile("Epistemos/Views/Landing/TimeMachineView.swift")
        let workspaces = try loadRepoTextFile("Epistemos/Views/Landing/WorkspaceSwitcherOverlay.swift")
        let notesSidebar = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(timeMachine.contains("Text(\"No session history yet\")"))
        #expect(timeMachine.contains("ProgressView()"))
        #expect(timeMachine.contains("Text(\"Select a session to explore\")"))

        #expect(workspaces.contains("Text(\"No saved workspaces\")"))
        #expect(workspaces.contains("Text(\"esc to close\")"))

        #expect(notesSidebar.contains("Text(\"No results\")"))
        #expect(notesSidebar.contains("Text(\"No notes yet\")"))
        #expect(notesSidebar.contains(".accessibilityLabel(\"Search notes\")"))
        #expect(notesSidebar.contains(".accessibilityLabel(\"Clear search\")"))

        #expect(landing.contains(".accessibilityLabel(\"Send prompt\")"))
        #expect(landing.contains(".accessibilityLabel(\"Local Model\")"))
        #expect(landing.contains("ProgressView()"))
    }

    @Test("root shell keeps recovery overlays toast feedback and toolbar accessibility affordances")
    func rootShellKeepsRecoveryAndAccessibilityAffordances() throws {
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(rootView.contains("ToastOverlay("))
        #expect(rootView.contains("VaultRecoveryOverlay("))
        #expect(rootView.contains(".accessibilityLabel(\"Back to Home\")"))
        #expect(rootView.contains(".accessibilityLabel(\"Settings\")"))
        #expect(rootView.contains(".accessibilityLabel(\"Chat History\")"))
        #expect(rootView.contains(".alert(\"Database Error\""))
    }

    @MainActor
    private func assertDividerProtection(on textView: NSTextView) {
        textView.string = "Hello world.\(NoteChatInlineResponse.divider)AI response."

        if let prose = textView as? ProseTextView2 {
            prose.hasProtectedInlineResponseDivider = true
        }

        let fullText = textView.string as NSString
        let dividerRange = fullText.range(of: NoteChatInlineResponse.divider)
        let responseRange = fullText.range(of: "AI response.")

        #expect(dividerRange.location != NSNotFound)
        #expect(responseRange.location != NSNotFound)

        let blocked: Bool
        let allowed: Bool

        switch textView {
        case let prose as ProseTextView2:
            blocked = prose.shouldChangeText(
                in: NSRange(location: dividerRange.location + 1, length: 1),
                replacementString: ""
            )
            allowed = prose.shouldChangeText(
                in: responseRange,
                replacementString: "Edited response."
            )
        default:
            Issue.record("Unexpected text view type: \(type(of: textView))")
            return
        }

        #expect(!blocked)
        #expect(allowed)
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}

@MainActor
private final class AuditCapturingStreamingLLMClient: LLMClientProtocol {
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        "unused"
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield("ok")
                continuation.finish()
            }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(
            provider: .localMLX,
            model: LocalTextModelID.qwen35_4B4Bit.rawValue,
            reasoningMode: .fast
        )
    }
}
