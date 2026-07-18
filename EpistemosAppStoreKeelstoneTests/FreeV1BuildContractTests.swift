import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 build-contract tests must compile in the App Store Free V1 target.")
#endif

@Suite("Free V1 build and release contract")
struct FreeV1BuildContractTests {
    @Test("Free V1 invokes only allowed build inputs and release checks")
    func freeV1BuildAndReleaseContractUsesOnlyAllowedInputs() throws {
        let project = try loadRepoTextFile("project.yml")
        let appTarget = try #require(appStoreTarget(in: project))
        let generatedProject = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let invokedPrebuild = try #require(appStorePrebuild(in: generatedProject))
        let appStoreMembershipExceptionPaths = try #require(appStoreMembershipExceptions(in: generatedProject))
        let repositoryFixtureStagingPhase = try #require(fixtureStagingPhase(in: generatedProject))
        let repositoryFixtureSkipPatterns = try #require(fixtureStageSkipPatterns(in: repositoryFixtureStagingPhase))
        let runtimeAssets = try loadRepoTextFile("bundle-app-runtime-assets.sh")
        let releaseGate = try loadRepoTextFile("scripts/keelstone-release-gate.sh")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let shadowBuild = try loadRepoTextFile("build-epistemos-shadow.sh")

        for paidPrebuild in [
            "build-june-web.sh",
            "build-agent-core.sh",
            "build-omega-mcp.sh",
        ] {
            #expect(!appTarget.contains(paidPrebuild))
            #expect(!invokedPrebuild.contains(paidPrebuild))
        }

        #expect(!appTarget.contains("JuneAgent/**"))
        #expect(!appStoreMembershipExceptionPaths.contains("JuneAgent/"))
        #expect(repositoryFixtureSkipPatterns == ["Epistemos/JuneAgent/*"])
        #expect(repositoryFixtureStagingPhase.contains(#"note: skipping intentionally absent Free V1 source root Epistemos/JuneAgent/: ${relative_path}"#))
        #expect(repositoryFixtureStagingPhase.contains(#"if [[ ! -f \"${source_path}\" ]]; then\n        echo \"error: missing repository source guard input: ${relative_path}\" >&2\n        exit 1\n      fi"#))
        #expect(releaseGate.contains("require_absent \"Epistemos/JuneAgent\""))
        #expect(!rootView.contains("showJuneAgentToolbarControls"))
        #expect(!rootView.contains("JuneAgentNavBar"))

        for paidStagingInput in [
            "JUNE_WEB_SOURCE_DIR",
            "MODEL_MANIFEST_SOURCE",
            "DEFAULT_SKILLS_SOURCE_DIR",
            "PYODIDE_SOURCE_DIR",
            "bundle_june_web",
            "bundle_model_manifest",
            "bundle_default_skills",
            "bundle_pyodide_resources",
        ] {
            #expect(!runtimeAssets.contains(paidStagingInput))
        }
        #expect(runtimeAssets.contains("bundle_editor_resources"))
        #expect(runtimeAssets.contains("bundle_coreeditor_resources"))
        #expect(runtimeAssets.contains("remove_free_v1_forbidden_resources"))

        for staleCheckoutRequirement in [
            "require_file \"Epistemos/JuneAgent/JuneAgentGateway.swift\"",
            "require_file \"agent_core/src/lib.rs\"",
            "STAGED_JUNEWEB",
            "BUILT_JUNEWEB",
            "require_appstore_local_gguf_runtime",
        ] {
            #expect(!releaseGate.contains(staleCheckoutRequirement))
        }
        #expect(releaseGate.contains("require_appstore_free_v1_without_paid_inference_or_agent_runtimes"))
        #expect(releaseGate.contains("Contents/Resources/JuneWeb"))
        #expect(releaseGate.contains("Contents/Resources/model_manifest.json"))
        #expect(releaseGate.contains("Contents/Resources/DefaultSkills"))

        #expect(appTarget.contains("KokoroPipeline"))
        #expect(app.contains("EpistemosAgentReadAloud"))
        #expect(shadowBuild.contains("--no-default-features --features free-lexical"))
    }

    @Test("Free V1 Home recovery avoids competing launch fallback probes")
    func freeV1HomeRecoveryUsesOnlyEventDrivenFallback() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let reopenStart = try #require(app.range(of: "func applicationShouldHandleReopen("))
        let reopenEnd = try #require(app.range(
            of: "    func applicationShouldOpenUntitledFile",
            range: reopenStart.upperBound..<app.endIndex
        ))
        let reopen = String(app[reopenStart.lowerBound..<reopenEnd.lowerBound])

        #expect(app.components(separatedBy: "WindowGroup(\"Epistemos\")").count == 2)
        for retiredLaunchProbe in [
            "private var didSchedule",
            "func schedule(bootstrap: AppBootstrap? = AppBootstrap.shared)",
            "func scheduleAfterLaunch(bootstrap: AppBootstrap? = AppBootstrap.shared)",
            "HomeWindowFallbackPresenter.shared.schedule(bootstrap: bootstrap)",
            "AppStoreFirstWindowPresenter.shared.schedule(bootstrap: bootstrap)",
            "HomeWindowFallbackPresenter.shared.scheduleAfterLaunch()",
            "AppStoreFirstWindowPresenter.shared.scheduleAfterLaunch()",
        ] {
            #expect(!app.contains(retiredLaunchProbe))
        }

        #expect(reopen.contains("guard !flag else { return true }"))
        #expect(!app.contains("AppStoreFirstWindowPresenter"))
        #expect(reopen.contains("HomeWindowFallbackPresenter.shared.ensureHomeWindow()"))
        #expect(reopen.contains("return false"))
        #expect(!reopen.contains("schedule"))
    }

    @Test("Free V1 removes retired closures and excludes only pending physical batches")
    func freeV1RemovesOrExcludesPaidPipelineAndCommandCenterClosures() throws {
        let project = try loadRepoTextFile("project.yml")
        let appTarget = try #require(appStoreTarget(in: project))
        let generatedProject = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let membershipExceptions = try #require(appStoreMembershipExceptions(in: generatedProject))

        for paidSource in [
            "Engine/AFMSessionPool.swift",
            "Engine/AFMSidecarGenerator.swift",
            "Engine/CommandCenterRequestCompiler.swift",
            "Engine/ConversationStateClassifier.swift",
            "Engine/IntakeValve.swift",
            "Engine/SessionTelemetryClassifier.swift",
            "Graph/EntityExtractor.swift",
            "Graph/OntologyClassifier.swift",
            "Omega/MCPBridge.swift",
            "State/AgentCommandCenterState.swift",
        ] {
            #expect(
                appTarget.components(separatedBy: "\n").filter {
                    $0 == "          - \(paidSource)"
                }.count == 1
            )
            #expect(
                membershipExceptions.components(separatedBy: "\n").filter {
                    $0.trimmingCharacters(in: .whitespaces) == "\(paidSource),"
                }.count == 1
            )
        }

        for physicallyRetiredSource in [
            "Engine/AgentNoteEditProvenance.swift",
            "Engine/CapabilityManifestBuilder.swift",
            "Engine/CommandInputParser.swift",
            "Engine/StructureRegistry.swift",
            "State/CommandCenterDiagnostics.swift",
            "Engine/VaultNoteEditor.swift",
            "Vault/ContradictionDetectionService.swift",
            "Vault/LiveNoteExecutor.swift",
            "Engine/ProvenanceConsoleProjectionService.swift",
            "Views/Settings/ProvenanceConsoleView.swift",
            "Views/Landing/SessionIntelligenceOverlay.swift",
            "Views/Notes/VaultOrganizerView.swift",
        ] {
            #expect(
                !freeV1RetiredPathExists(
                    "Epistemos/\(physicallyRetiredSource)",
                    sourceFilePath: #filePath
                ),
                "Free V1 must physically remove \(physicallyRetiredSource)."
            )
            #expect(!appTarget.contains(physicallyRetiredSource))
            #expect(!membershipExceptions.contains(physicallyRetiredSource))
            #expect(!generatedProject.contains(physicallyRetiredSource))
        }

        #expect(!freeV1RetiredPathExists(
            "Epistemos/App/AppCoordinator.swift",
            sourceFilePath: #filePath
        ))
        #expect(!appTarget.components(separatedBy: "\n").contains("          - App/AppCoordinator.swift"))
        #expect(!membershipExceptions.components(separatedBy: "\n").contains {
            $0.trimmingCharacters(in: .whitespaces) == "App/AppCoordinator.swift,"
        })
    }

    @Test("Free V1 physically removes the agent hook registry")
    func freeV1RemovesAgentHookRegistry() throws {
        let project = try loadRepoTextFile("project.yml")
        let appTarget = try #require(appStoreTarget(in: project))

        #expect(
            !freeV1RetiredPathExists(
                "Epistemos/Engine/HookRegistry.swift",
                sourceFilePath: #filePath
            ),
            "The agent hook interception path must be physically absent from Free V1."
        )
        #expect(!appTarget.contains("Engine/HookRegistry.swift"))
    }

    @Test("Free V1 physically removes the unused substrate event-ring build lane")
    func freeV1RemovesSubstrateEventRingBuildLane() throws {
        let project = try loadRepoTextFile("project.yml")
        let appTarget = try #require(appStoreTarget(in: project))
        let generatedProject = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")

        for retiredBridgeSource in [
            "Engine/EventDrain.swift",
            "Engine/RustEventRingClient.swift",
        ] {
            #expect(
                !freeV1RetiredPathExists(
                    "Epistemos/\(retiredBridgeSource)",
                    sourceFilePath: #filePath
                ),
                "Free V1 must physically remove \(retiredBridgeSource)."
            )
            #expect(!appTarget.contains(retiredBridgeSource))
            #expect(!generatedProject.contains(retiredBridgeSource))
        }

        for retiredFreeBuildInput in [
            "EPISTEMOS_LINK_SUBSTRATE_RT",
            "-lsubstrate_rt",
            "build-substrate-rt.sh",
        ] {
            #expect(!project.contains(retiredFreeBuildInput))
        }
    }

    @Test("Free V1 never constructs or heartbeats the Paperclip agent store")
    func freeV1RemovesPaperclipStartupState() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        for retiredPaperclipSource in [
            "State/PaperclipStateStore.swift",
            "State/PaperclipHeartbeatClock.swift",
        ] {
            #expect(
                !freeV1RetiredPathExists(
                    "Epistemos/\(retiredPaperclipSource)",
                    sourceFilePath: #filePath
                ),
                "Paperclip agent state must be physically absent from Free V1."
            )
            #expect(!bootstrap.contains(retiredPaperclipSource))
        }

        for retiredBootstrapSurface in [
            "PaperclipStateStore",
            "PaperclipHeartbeatClock",
            "_paperclipStore",
            "_paperclipHeartbeatClock",
            "paperclipStore",
            "paperclipHeartbeatClock",
            "paperclip_state.db",
        ] {
            #expect(!bootstrap.contains(retiredBootstrapSurface))
        }
    }

    @Test("Free V1 excludes note-insight analysis and bootstrap startup")
    func freeV1ExcludesNoteInsightAnalysisStartup() throws {
        let project = try loadRepoTextFile("project.yml")
        let appTarget = try #require(appStoreTarget(in: project))
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(!freeV1RetiredPathExists(
            "Epistemos/App/AppCoordinator.swift",
            sourceFilePath: #filePath
        ))
        #expect(!appTarget.components(separatedBy: "\n").contains("          - App/AppCoordinator.swift"))
        #expect(
            appTarget.components(separatedBy: "\n").filter {
                $0 == "          - Engine/NoteInsightService.swift"
            }.count == 1
        )

        for retiredBootstrapSurface in [
            "NoteInsightService",
            "_noteInsightService",
            "noteInsightService",
        ] {
            #expect(!bootstrap.contains(retiredBootstrapSurface))
        }
    }

    @Test("Free V1 retains workspace-summary preferences without its Triage executor")
    func freeV1SeparatesWorkspaceSummaryPreferencesFromExecutor() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let freePreferences = try loadRepoTextFile("Epistemos/State/FreeV1WorkspaceSummaryPreferences.swift")
        let project = try loadRepoTextFile("project.yml")
        let appTarget = try #require(appStoreTarget(in: project))

        #expect(
            bootstrap.contains(
                "#if EPISTEMOS_FREE_V1\n    let workspaceSummaryService = WorkspaceSummaryPreferences()\n    #else\n    private var _workspaceSummaryService: WorkspaceSummaryService?"
            )
        )
        #expect(appTarget.contains("          - State/WorkspaceSummaryService.swift"))
        #expect(freePreferences.contains("final class WorkspaceSummaryPreferences"))
        #expect(freePreferences.contains("enum WorkspaceSummaryService"))
        #expect(!freePreferences.contains("TriageService"))
        #expect(!freePreferences.contains("generateSummaryNow"))
    }

    @Test("Free V1 physically removes cloud consent and excludes the general-LLM executable closure")
    func freeV1RemovesCloudConsentAndExcludesGeneralLLMExecutableClosure() throws {
        let project = try loadRepoTextFile("project.yml")
        let appTarget = try #require(appStoreTarget(in: project))
        let freeRuntime = try loadRepoTextFile("Epistemos/State/FreeV1RuntimeState.swift")

        #expect(
            !freeV1RetiredPathExists(
                "Epistemos/AgentWorkspace/AgentCloudConsent.swift",
                sourceFilePath: #filePath
            ),
            "Cloud consent must be physically absent from the primary Free V1 source tree."
        )
        #expect(!appTarget.contains("AgentWorkspace/AgentCloudConsent.swift"))
        #expect(
            !freeV1RetiredPathExists(
                "Epistemos/Engine/StructuredOutput.swift",
                sourceFilePath: #filePath
            ),
            "Cloud structured-output support must be physically absent from Free V1."
        )
        #expect(!appTarget.contains("Engine/StructuredOutput.swift"))

        for retiredCloudSource in [
            "Engine/CloudProviderAuthService.swift",
            "Engine/OpenAICompatibleChatSupport.swift",
            "Engine/URLSessionTransportSupport.swift",
            "Engine/LLMService.swift",
            "Engine/TriageService.swift",
            "Engine/PipelineService.swift",
        ] {
            #expect(
                !freeV1RetiredPathExists(
                    "Epistemos/\(retiredCloudSource)",
                    sourceFilePath: #filePath
                ),
                "Free V1 must physically remove \(retiredCloudSource)."
            )
            #expect(!appTarget.contains(retiredCloudSource))
        }

        for canceledSource in [
            "State/ProductRuntimeState.swift",
        ] {
            #expect(
                appTarget.components(separatedBy: "\n").filter {
                    $0 == "          - \(canceledSource)"
                }.count == 1,
                "Free V1 must exclude \(canceledSource) rather than compiling an unavailable cloud or LLM facade."
            )
        }

        for canceledIdentity in [
            "CloudModelProvider",
            "CloudTextModelID",
            "CloudProviderOAuthCredential",
            "LLMService",
            "ChatModelSelection",
            "TriageService",
            "URLSession",
        ] {
            #expect(!freeRuntime.contains(canceledIdentity))
        }
    }

    @Test("Free V1 app composition denies agent-core execution even when bindings exist")
    func freeV1AppCompositionDeniesAgentCoreAtCompileTime() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let freeDeniedAgentCoreCondition = "#if !EPISTEMOS_FREE_V1 && canImport(agent_coreFFI)"

        #expect(!bootstrap.contains("#if canImport(agent_coreFFI)"))
        #expect(!bootstrap.contains("enum ShipGate"))
        #expect(!bootstrap.contains("agentsEnabled"))
        #expect(
            bootstrap.components(separatedBy: freeDeniedAgentCoreCondition).count - 1 == 7,
            "Every AppBootstrap agent-core import or call must be unavailable to Free V1."
        )
        #expect(
            bootstrap.contains(
                "#if !EPISTEMOS_FREE_V1\n                EidosVaultBootstrapper.openProductionIndexIfReady("
            ),
            "The vault-switch observer must not reopen the agent Eidos runtime in Free V1."
        )
        #expect(!app.contains("#if canImport(agent_coreFFI)"))
        #expect(app.components(separatedBy: freeDeniedAgentCoreCondition).count - 1 == 1)
    }

    @Test("Free V1 widget omits unreachable model classifier sources")
    func freeV1WidgetOmitsUnreachableModelClassifierSources() throws {
        let project = try loadRepoTextFile("project.yml")
        let widgetTarget = try #require(widgetsTarget(in: project))
        let generatedProject = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")

        for modelClassifierSource in [
            "Epistemos/Engine/AFMSessionPool.swift",
            "Epistemos/Engine/ConversationStateClassifier.swift",
            "Epistemos/Engine/SessionTelemetryClassifier.swift",
        ] {
            #expect(!widgetTarget.contains("- path: \(modelClassifierSource)"))
        }

        for widgetBuildMember in [
            "AFMSessionPool.swift in Sources",
            "ConversationStateClassifier.swift in Sources",
            "SessionTelemetryClassifier.swift in Sources",
        ] {
            #expect(!generatedProject.contains(widgetBuildMember))
        }
    }

    @Test("Free V1 graph state omits the LLM extraction seam")
    func freeV1GraphStateOmitsLLMExtractionSeam() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")

        for retiredExtractionSurface in [
            "var isScanning",
            "var scanProgress",
            "var scanStatus",
            "func scanVault(context: ModelContext, llmService: any LLMClientProtocol)",
            "EntityExtractor(",
        ] {
            #expect(!graphState.contains(retiredExtractionSurface))
        }
    }

    @Test("Free V1 EventStore omits uncalled agent-session persistence APIs")
    func freeV1EventStoreOmitsUncalledAgentSessionPersistenceAPIs() throws {
        let eventStore = try loadRepoTextFile("Epistemos/State/EventStore.swift")

        for retiredPersistenceAPI in [
            "func saveSessionTelemetry(",
            "func loadSessionTelemetryJSON(",
            "func saveConversationState(",
            "func loadConversationStateJSON(",
            "func saveSessionMetrics(",
            "ReasoningTrajectoryMetricsFFI",
        ] {
            #expect(!eventStore.contains(retiredPersistenceAPI))
        }
    }

    @Test("Free V1 Epdoc paste handling omits the model-classifier side channel")
    func freeV1EpdocPasteHandlingOmitsModelClassifierSideChannel() throws {
        let pasteBridge = try loadRepoTextFile("js-editor/src/extensions/paste-classifier-bridge.ts")
        let outboundBridge = try loadRepoTextFile("js-editor/src/bridge/outbound.ts")
        let editor = try loadRepoTextFile("js-editor/src/index.ts")
        let chrome = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")

        for retiredClassifierToken in [
            "classifyPaste",
            "IntakeValve",
            "pasteClassifierBridge",
            "PASTE_CLASSIFIER_KEY",
        ] {
            #expect(!pasteBridge.contains(retiredClassifierToken))
            #expect(!outboundBridge.contains(retiredClassifierToken))
            #expect(!editor.contains(retiredClassifierToken))
            #expect(!chrome.contains(retiredClassifierToken))
        }

        #expect(pasteBridge.contains("parseMarkdownPaste"))
        #expect(pasteBridge.contains("return false"))
        #expect(pasteBridge.contains("type: 'contentDidChange'"))
        #expect(editor.contains("pasteHandlingBridge()"))
        #expect(chrome.contains("EpdocBridgeMessage.decode(messageBody: body)"))
    }

    @Test("Free V1 graph inspector previews omit model and provider generation")
    func freeV1GraphInspectorPreviewsOmitModelAndProviderGeneration() throws {
        let inspectorSources = [
            try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift"),
            try loadRepoTextFile("Epistemos/Views/Graph/PinnedInspector.swift"),
        ]

        for source in inspectorSources {
            for retiredGenerationSurface in [
                "AppleIntelligenceService",
                "TriageService",
                "AppleIntelligenceError",
                "generateGeneral",
                "AppBootstrap.shared?.triageService",
                "buildSummaryPrompt",
            ] {
                #expect(!source.contains(retiredGenerationSurface))
            }
            #expect(source.contains("func ensureSummary"))
            #expect(source.contains("String(content.prefix(300))"))
            #expect(source.contains("summaryCache[node.id]"))
        }
    }

    @Test("Free V1 note ideas keep capture and insertion without generation")
    func freeV1NoteIdeasKeepCaptureAndInsertionWithoutGeneration() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        for retiredGenerationSurface in [
            "AppleIntelligenceService",
            "integrateWithAI",
            "formatWithAI",
            "capturedSelection",
            "snapshotEditorSelection",
            "busyItemId",
            "onIntegrate",
            "onFormat",
            "ProductCapabilityPolicy.isAvailable(.generativeActions)",
        ] {
            #expect(!workspace.contains(retiredGenerationSurface))
        }

        for retainedCaptureSurface in [
            "private struct IdeasPanel: View",
            "private func writeIdeas(_ ideas: [NoteIdea])",
            "private func insertIdea(_ item: NoteIdea)",
            "showIdeasPopover",
            "formattedBody",
            "Text(\"Formatted\")",
        ] {
            #expect(workspace.contains(retainedCaptureSurface))
        }
    }

    @Test("Free V1 Code Editor keeps direct semantic retrieval without generation")
    func freeV1CodeEditorKeepsDirectSemanticRetrievalWithoutGeneration() throws {
        let editor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        for retiredGenerationSurface in [
            "AppleIntelligenceService",
            "TriageService",
            "CodeCompanionService",
            "CodeInsightGenerator",
            "CodeInsightsPanel",
            "Explain with AI",
            "generateAIContextSummary",
            "explainCodeWithVaultContext",
            "insightRefreshDelay",
            "ProductCapabilityPolicy.isAvailable(.generativeActions)",
            "private(set) var lastQuery",
            "selectedMatch = match",
        ] {
            #expect(!editor.contains(retiredGenerationSurface))
        }

        for retainedRetrievalSurface in [
            "final class CodeContextBridge",
            "private let embeddingService: EmbeddingService",
            "func findRelatedNotes(for codeContent: String)",
            "graphState.semanticSearchWithQueryEmbedding(",
            "let queryEmbedding = semanticResult.queryEmbedding",
            "guard embedding.count == queryEmbedding.count else { continue }",
            "MetalComputeEngine.shared.batchCosineSimilarity(",
            "func semanticCodeSearch(query: String)",
            "struct CodeSemanticSidebar: View",
            "private var relatedNotesSection",
            "SemanticCodeSearchSheet(bridge: bridge)",
            "onCreateNoteFromCode()",
        ] {
            #expect(editor.contains(retainedRetrievalSurface))
        }

        #expect(!editor.contains("findRelatedNotes(for: query)\n        return relatedNotes"))
        #expect(editor.contains("guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query),"))
        #expect(!editor.contains("computeEmbedding("))
        #expect(editor.contains("query: checkedCodeContent,"))
        #expect(editor.contains("query: checkedQuery,"))
        #expect(editor.contains("documentEmbeddings.reserveCapacity(searchHits.count)"))
        #expect(editor.contains("documentMetadata.reserveCapacity(searchHits.count)"))
    }

    @Test("Free V1 deterministic SQLite search emits no synthetic agent provenance")
    func freeV1SearchIndexOmitsSyntheticAgentProvenance() throws {
        let searchIndex = try loadRepoTextFile("Epistemos/Sync/SearchIndexService.swift")

        for retiredProvenanceSurface in [
            "AgentToolProvenance",
            "AgentProvenanceActor",
            "AgentProvenanceEventKind",
            "AgentToolEventStatus",
            "agentProvenance",
            "search-index-page-sync-",
            "search-index-page-async-",
            "search-index-block-sync-",
            "search-index-block-async-",
            "search-index-fused-sync-",
            "search-index-fused-async-",
            "recordToolEvent",
            "searchIndexAgentJSON",
            "limitedSearchArgumentsJSON",
            "limitedSearchMetadata",
            "SearchIndexFailureClass",
        ] {
            #expect(!searchIndex.contains(retiredProvenanceSurface))
        }

        for retainedRetrievalSurface in [
            "nonisolated func search(query:",
            "func searchAsync(query:",
            "nonisolated func searchBlocks(query:",
            "func searchBlocksAsync(query:",
            "nonisolated public func fusedSearch(",
            "public func fusedSearchAsync(",
            "SearchFusionMetrics.shared.record",
            "vaultRecallTrace",
            "withSQLiteCancellation",
        ] {
            #expect(searchIndex.contains(retainedRetrievalSurface))
        }
    }

    @Test("Free V1 omits the retired overseer planner source")
    func freeV1OmitsRetiredOverseerPlannerSource() {
        #expect(!repositorySourceExists("Epistemos/Engine/OverseerProtocol.swift"))
    }

    @Test("Free V1 omits the dead model runtime executor")
    func freeV1OmitsDeadModelRuntimeExecutor() {
        #expect(!repositorySourceExists("Epistemos/Engine/RuntimeExecutor.swift"))
    }

    @Test("Free V1 omits dead agent-session lineage persistence")
    func freeV1OmitsDeadAgentSessionLineagePersistence() {
        #expect(!repositorySourceExists("Epistemos/Vault/AgentSessionLineageStore.swift"))
    }

    @Test("Free V1 omits the local agent tool bridge")
    func freeV1OmitsLocalAgentToolBridge() {
        for retiredToolBridgeSource in [
            "Epistemos/Bridge/ToolExecutionTypes.swift",
            "Epistemos/Bridge/ToolOutputErrorClassifier.swift",
            "Epistemos/Bridge/ToolTierBridge.swift",
        ] {
            #expect(!repositorySourceExists(retiredToolBridgeSource))
        }
    }

    @Test("Free V1 omits the uncalled code-editor AI context engine")
    func freeV1OmitsUncalledCodeEditorAIContextEngine() {
        #expect(!repositorySourceExists("Epistemos/Views/Notes/WeightedContextEngine.swift"))
    }

    @Test("Free V1 omits the orphaned agent-session reasoning badge")
    func freeV1OmitsOrphanedAgentSessionReasoningBadge() {
        #expect(!repositorySourceExists("Epistemos/Views/Shared/ReasoningTrajectoryBadge.swift"))
    }

    @Test("Free V1 omits the retired AI Partner source closure")
    func freeV1OmitsRetiredAIPartnerSourceClosure() {
        for retiredSource in [
            "Epistemos/Views/Notes/AIPartnerControlPanel.swift",
            "Epistemos/Views/Notes/AIPartnerInlineView.swift",
            "Epistemos/Views/Notes/AIPartnerService.swift",
        ] {
            #expect(!repositorySourceExists(retiredSource))
        }
    }

    @Test("Free V1 localization omits unreferenced paid and agent surfaces")
    func freeV1LocalizationOmitsUnreferencedPaidAndAgentSurfaces() throws {
        let localizations = try loadRepoTextFile("Epistemos/Resources/Localizable.xcstrings")

        for retiredLocalization in [
            "Apple Intelligence Insights",
            "Capture brain dump ${body}",
            "Enable read-only vault MCP server",
            "Expose the connected markdown vault as a bearer-protected local MCP endpoint for external tools. The server advertises read-only vault and graph tools only.",
            "Format with Apple Intelligence",
            "Read-Only MCP Server",
            "Tap refresh to analyze this code with Apple Intelligence",
            "%@: about %lld agent tokens",
            "%lld chat%@",
            "AI Insight",
            "AI Partner",
            "AI formatted",
            "AI integrates this into the note",
            "Agent Surface (Pro)",
            "Agent native chrome",
            "Delegate ${prompt} to ${capabilityTier}",
            "Dump raw thoughts — format & insert with AI",
            "Epistemos Agent",
            "Explain with AI",
            "Format with AI",
            "Heading, text, note surfaces, panels, and chat stay together.",
            "Integrate with AI",
            "New chat",
            "Searches across all your Epistemos notes, research, and chat history.",
            "Send prompt",
            "Session Focus",
            "Session Intelligence",
            "Want a stronger local model? Download %@",
            "queued prompt",
        ] {
            #expect(!localizations.contains(retiredLocalization))
        }

        #expect(localizations.contains("Kokoro-82M"))
        #expect(localizations.contains("Read aloud"))
    }

    private func appStoreTarget(in project: String) -> String? {
        guard let start = project.range(of: "  Epistemos-AppStore:\n"),
              let end = project.range(of: "  EpistemosWidgets:\n", range: start.upperBound..<project.endIndex) else {
            return nil
        }
        return String(project[start.lowerBound..<end.lowerBound])
    }

    private func widgetsTarget(in project: String) -> String? {
        guard let start = project.range(of: "  EpistemosWidgets:\n"),
              let end = project.range(
                of: "  EpistemosAppStoreKeelstoneTests:\n",
                range: start.upperBound..<project.endIndex
              ) else {
            return nil
        }
        return String(project[start.lowerBound..<end.lowerBound])
    }

    private func appStorePrebuild(in project: String) -> String? {
        guard let start = project.range(of: "1DA88FE300B58BE04268296B /* Build Rust Engine */ = {"),
              let end = project.range(of: "\n\t\t};", range: start.upperBound..<project.endIndex) else {
            return nil
        }
        return String(project[start.lowerBound..<end.lowerBound])
    }

    private struct PBXObject {
        let identifier: String
        let body: String
    }

    private func appStoreMembershipExceptions(in project: String) -> String? {
        guard let appStoreTarget = pbxObject(named: "Epistemos-AppStore", in: project),
              appStoreTarget.body.contains("isa = PBXNativeTarget;"),
              appStoreTarget.body.contains("name = \"Epistemos-AppStore\";"),
              let synchronizedGroups = pbxList(named: "fileSystemSynchronizedGroups", in: appStoreTarget.body),
              let epistemosRootIdentifier = singlePBXReference(named: "Epistemos", in: synchronizedGroups),
              let epistemosRoot = pbxObject(identifier: epistemosRootIdentifier, named: "Epistemos", in: project),
              epistemosRoot.body.contains("isa = PBXFileSystemSynchronizedRootGroup;"),
              epistemosRoot.body.contains("path = Epistemos;"),
              let exceptionReferences = pbxList(named: "exceptions", in: epistemosRoot.body),
              let exceptionSetIdentifier = singlePBXReference(
                named: "PBXFileSystemSynchronizedBuildFileExceptionSet",
                in: exceptionReferences
              ),
              let exceptionSet = pbxObject(
                identifier: exceptionSetIdentifier,
                named: "PBXFileSystemSynchronizedBuildFileExceptionSet",
                in: project
              ),
              exceptionSet.body.contains("isa = PBXFileSystemSynchronizedBuildFileExceptionSet;"),
              exceptionSet.body.contains(
                "target = \(appStoreTarget.identifier) /* Epistemos-AppStore */;"
              ),
              let membershipExceptions = pbxList(named: "membershipExceptions", in: exceptionSet.body) else {
            return nil
        }

        return membershipExceptions
    }

    private func fixtureStagingPhase(in project: String) -> String? {
        guard let phase = pbxObject(named: "Stage Repository Source Guards", in: project),
              phase.body.contains("isa = PBXShellScriptBuildPhase;") else {
            return nil
        }
        return phase.body
    }

    private func fixtureStageSkipPatterns(in phase: String) -> [String]? {
        guard let start = phase.range(of: #"case \"${relative_path}\" in\n"#),
              let end = phase.range(of: #"\n      esac"#, range: start.upperBound..<phase.endIndex) else {
            return nil
        }

        let caseBody = phase[start.upperBound..<end.lowerBound]
        return caseBody
            .components(separatedBy: #"\n"#)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasSuffix(")"), !trimmed.hasPrefix("case ") else {
                    return nil
                }
                return String(trimmed.dropLast())
            }
    }

    private func pbxObject(named name: String, in project: String) -> PBXObject? {
        let marker = "/* \(name) */ = {"
        guard let markerRange = project.range(of: marker),
              let lineStart = project[..<markerRange.lowerBound].lastIndex(of: "\n"),
              let end = project.range(of: "\n\t\t};", range: markerRange.upperBound..<project.endIndex) else {
            return nil
        }

        let identifier = project[project.index(after: lineStart)..<markerRange.lowerBound]
            .trimmingCharacters(in: .whitespaces)
        guard !identifier.isEmpty, identifier.allSatisfy(\.isHexDigit) else {
            return nil
        }

        return PBXObject(
            identifier: identifier,
            body: String(project[markerRange.upperBound..<end.lowerBound])
        )
    }

    private func pbxObject(identifier: String, named name: String, in project: String) -> PBXObject? {
        let marker = "\(identifier) /* \(name) */ = {"
        guard let markerRange = project.range(of: marker),
              let end = project.range(of: "\n\t\t};", range: markerRange.upperBound..<project.endIndex) else {
            return nil
        }
        return PBXObject(
            identifier: identifier,
            body: String(project[markerRange.upperBound..<end.lowerBound])
        )
    }

    private func pbxList(named name: String, in object: String) -> String? {
        guard let start = object.range(of: "\(name) = ("),
              let end = object.range(of: "\n\t\t\t);", range: start.upperBound..<object.endIndex) else {
            return nil
        }
        return String(object[start.upperBound..<end.lowerBound])
    }

    private func singlePBXReference(named name: String, in list: String) -> String? {
        let marker = "/* \(name) */"
        let references = list.split(separator: "\n").compactMap { line -> String? in
            guard let markerRange = line.range(of: marker) else {
                return nil
            }

            let identifier = line[..<markerRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            guard !identifier.isEmpty, identifier.allSatisfy(\.isHexDigit) else {
                return nil
            }
            return identifier
        }

        guard references.count == 1 else {
            return nil
        }
        return references[0]
    }

    private final class SourceGuardBundleToken {}

    private func repositorySourceFixtureURL(_ relativePath: String) -> URL? {
        let bundle = Bundle(for: SourceGuardBundleToken.self)
        return bundle.resourceURL?
            .appendingPathComponent("RepositorySourceFixtures", isDirectory: true)
            .appendingPathComponent(relativePath)
    }

    private func repositorySourceExists(_ relativePath: String) -> Bool {
        guard let fixture = repositorySourceFixtureURL(relativePath) else {
            return false
        }
        return FileManager.default.fileExists(atPath: fixture.path)
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        guard let fixture = repositorySourceFixtureURL(relativePath),
              repositorySourceExists(relativePath) else {
            throw CocoaError(
                .fileNoSuchFile,
                userInfo: [
                    NSFilePathErrorKey: relativePath,
                    NSLocalizedDescriptionKey: "Repository source fixture was not staged into the test bundle."
                ]
            )
        }
        return try String(contentsOf: fixture, encoding: .utf8)
    }
}
