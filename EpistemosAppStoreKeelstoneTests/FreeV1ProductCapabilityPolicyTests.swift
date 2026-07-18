import Foundation
import SwiftData
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX
#error("Free V1 product-capability tests must compile with the Mac App Store sandbox lane.")
#endif

private nonisolated struct FreeV1DeterministicParagraphLookup: TextEmbeddingLookup {
    let dimension = 3

    func vector(for token: String) -> [Float]? {
        nil
    }

    func textVector(for text: String) -> [Float]? {
        switch text {
        case "semantic query":
            [0, 1, 0]
        case "a related paragraph":
            [0, 0.8, 0.2]
        default:
            nil
        }
    }
}

@Suite("Free V1 Product Capability Policy")
@MainActor
struct FreeV1ProductCapabilityPolicyTests {
    @Test("free V1 has one explicit capability partition")
    func capabilityPartitionIsComplete() {
        let expectedFree: Set<ProductCapability> = [
            .epdocPlanner,
            .knowledgeGraph,
            .kokoroVoice,
            .meeting,
            .pdfImport,
            .quickCapture,
            .search,
            .sync,
            .workspaceExport,
        ]
        let expectedPaid: Set<ProductCapability> = [
            .agentAutomation,
            .browser,
            .epdocAssist,
            .generativeActions,
            .models,
            .paidAgent,
            .provenanceConsole,
            .reckoner,
            .sourceDiscovery,
        ]

        #expect(ProductCapabilityPolicy.currentEdition == .freeV1)
        #expect(Set(ProductCapability.allCases) == expectedFree.union(expectedPaid))
        #expect(Set(ProductCapabilityPolicy.freeCapabilities) == expectedFree)
        #expect(Set(ProductCapabilityPolicy.paidCapabilities) == expectedPaid)
        #expect(ProductCapabilityPolicy.freeCapabilities.allSatisfy(ProductCapabilityPolicy.isAvailable))
        #expect(ProductCapabilityPolicy.paidCapabilities.allSatisfy { !ProductCapabilityPolicy.isAvailable($0) })
    }

    @Test("free V1 keeps HTML Workspace regeneration in the paid capability boundary")
    func htmlWorkspaceRegenerationIsUnavailable() {
        #expect(!ProductCapabilityPolicy.allowsHTMLWorkspaceRegeneration)
    }

    @Test("landing exposes only retained Free feature routes")
    func landingVisibilityUsesTheReleasePolicy() {
        #expect(LandingFeatureButton.allCases == [.pdfImport, .arxiv, .browser, .meetingNote])
        #expect(LandingFeatureButton.visibleCases == [.pdfImport, .meetingNote])
        #expect(LandingFeatureButton.pdfImport.productCapability == .pdfImport)
        #expect(LandingFeatureButton.meetingNote.productCapability == .meeting)
        #expect(LandingFeatureButton.arxiv.productCapability == .sourceDiscovery)
        #expect(LandingFeatureButton.browser.productCapability == .browser)
        #expect(LandingFeatureButton.arxiv.isPaidOnly)
        #expect(LandingFeatureButton.browser.isPaidOnly)
        #expect(!ProductCapabilityPolicy.isAvailable(.paidAgent))
    }

    @Test("free V1 compiled identities remain neutral for hidden model and agent lanes")
    func hiddenPaidIdentitiesRemainNeutral() {
        let forbiddenIdentities = Set(["june", "openai", "anthropic", "claude", "gguf"])
        #expect(Set(SettingsView.SettingsSection.cloudModels.searchKeywords).isDisjoint(with: forbiddenIdentities))
        #expect(Set(SettingsView.SettingsSection.substrateHealth.searchKeywords).isDisjoint(with: forbiddenIdentities))
        #expect(BackendRuntimeKind.allCases == [.unavailable])
        #expect(BackendRuntimeKind.unavailable.rawValue == "free_v1_unavailable")
    }

    @Test("free V1 removes legacy remote runtime preferences")
    func legacyRemoteRuntimePreferencesArePurged() {
        let suiteName = "FreeV1LegacyRemoteConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let retiredKeys = [
            "epistemos.apiProvider",
            "epistemos.ollamaBaseUrl",
            "epistemos.ollamaModel",
            "epistemos.activeAIProvider",
            "epistemos.lastNonLocalAIProvider",
            "epistemos.chatAutoRouteToCloud",
            "epistemos.cloudAutoFallback",
        ]

        for key in retiredKeys {
            defaults.set("legacy", forKey: key)
        }
        LegacyRemoteConfiguration.purge(defaults: defaults)

        for key in retiredKeys {
            #expect(defaults.object(forKey: key) == nil)
        }
    }

    @Test("unavailable paid home routes fail closed while free routes remain intact")
    func homeRouteSanitizationFailsClosed() {
        #expect(LandingViewStateSync.sanitizedHomeContent(.arxiv) == .greeting)
        #expect(LandingViewStateSync.sanitizedHomeContent(.browser) == .greeting)
        #expect(LandingViewStateSync.sanitizedHomeContent(.greeting) == .greeting)
        #expect(LandingViewStateSync.sanitizedHomeContent(.graph) == .graph)
        #expect(LandingViewStateSync.sanitizedHomeContent(.meeting) == .meeting)
    }

    @Test("settings and utility windows cannot deep-link around the free boundary")
    func deepLinksCannotBypassThePolicy() {
        #expect(SettingsView.SettingsSection.visibleSections.contains(.voice))
        #expect(!SettingsView.SettingsSection.visibleSections.contains(.cloudModels))
        #expect(!SettingsView.SettingsSection.visibleSections.contains(.skills))
        #expect(!SettingsView.SettingsSection.visibleSections.contains(.provenance))
        #expect(SettingsView.SettingsSection.safeDetailSelection(for: .cloudModels) == .general)
        #expect(SettingsView.SettingsSection.safeDetailSelection(for: .skills) == .general)
        #expect(SettingsView.SettingsSection.safeDetailSelection(for: .provenance) == .general)
        #expect(!ProductCapabilityPolicy.isAvailable(.provenanceConsole))
        #expect(UtilityPanel.meetingNote.isAvailableInCurrentEdition)
        #expect(!UtilityPanel.browser.isAvailableInCurrentEdition)
    }

    @Test("free V1 graph projection excludes stored chat and agent artifacts")
    func graphProjectionFailsClosedForPaidArtifacts() throws {
        let paidArtifacts: Set<GraphNodeType> = [.chat, .run, .rawThought, .toolTrace]
        #expect(Set(GraphNodeType.visibleCases).isDisjoint(with: paidArtifacts))
        #expect(Set(GraphNodeType.defaultActiveCases).isDisjoint(with: paidArtifacts))

        let schema = Schema([SDPage.self, SDFolder.self, SDChat.self, SDGraphNode.self, SDGraphEdge.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(SDChat(title: "Archived paid chat"))
        try context.save()

        let graph = GraphBuilder().build(context: context)
        #expect(graph.nodes.isEmpty)
    }

    @Test("free V1 preserves legacy Epdoc metadata without restoring a tab or outline surface")
    func epdocNotebookCompatibilityFailsClosedForChatAndSheet() {
        let sheetID = "11111111-1111-4111-8111-111111111111"
        let chatID = "22222222-2222-4222-8222-222222222222"
        let markdown = """
        ```epistemos-notebook
        version: 1
        tab: id=\(sheetID) type=sheet version=1 title="Metrics" ref="dataset:metrics.dataset.md"
        tab: id=\(chatID) type=chat version=1 title="Archived analysis" ref="session:archived-analysis"
        ```
        """

        let manifest = EpdocNotebookManifest.parse(in: markdown)
        #expect(manifest.tabs.map(\.id) == [sheetID, chatID])
        #expect(EpdocNotebookManifest.normalizedFreeV1SelectedTabID(sheetID) == EpdocNotebookManifest.bodyTabID)
        #expect(EpdocNotebookManifest.normalizedFreeV1SelectedTabID(chatID) == EpdocNotebookManifest.bodyTabID)
        #expect(TOCParser.parse(markdown).isEmpty)
        #expect(LensFidelityDisclosure.items(in: markdown, lens: .document).isEmpty)
    }

    @Test("free V1 HTML workspace cannot classify or return stored chat context")
    func htmlWorkspaceChatContextProjectionFailsClosed() throws {
        let schema = Schema([SDChat.self, SDMessage.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let chat = SDChat(title: "Archived paid chat", chatType: "notes")
        let message = SDMessage(role: "assistant", content: "This paid chat must remain hidden in free V1.")
        message.chat = chat
        context.insert(chat)
        context.insert(message)
        try context.save()

        #expect(HTMLWorkspaceDataFeedContextSources.recentChatResults(
            query: "recent chats",
            modelContainer: container,
            limit: 5
        ).isEmpty)
        #expect(HTMLWorkspaceDataFeedContextSources.results(
            for: "recent_chat",
            searchResults: [],
            modelContainer: container,
            limit: 5,
            query: "recent chats"
        ).isEmpty)
        #expect(HTMLWorkspaceDataFeedContextSources.requiredContextKind(
            forFreeformQuery: "recent chats"
        ) == nil)
        #expect(!HTMLWorkspaceDataFeedContextSources.usesStandaloneContextSource("recent_chat"))
    }

    @Test("free V1 preview redacts stored chat context from legacy workspace data")
    func htmlWorkspacePreviewRedactsLegacyChatContext() throws {
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "recent chats", limit: 5)
        let legacyData = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            contextResults: [
                HTMLWorkspaceDataFeedResult(
                    pageID: "paid-chat",
                    title: "Archived paid chat",
                    snippet: "This stored chat must never reach the free V1 preview.",
                    rank: 1,
                    contextKind: "recent_chat",
                    sourceLabel: "Recent chat",
                    provenance: "SDChat / notes"
                ),
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_800_000_000),
            requiredContextKind: "recent_chat"
        )

        let presentationData = HTMLWorkspaceDataFeedRenderer.presentationDataJSON(from: legacyData)
        #expect(!presentationData.contains("Archived paid chat"))
        #expect(!presentationData.contains("must never reach"))
        #expect(!presentationData.contains("recent_chat"))

        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: presentationData))
        #expect(metadata.resultCount == 0)
        #expect(metadata.contextKinds == [])
        #expect(metadata.requiredContextKind == nil)

        var legacyPackage = HTMLWorkspacePackage.defaultPackage()
        legacyPackage.dataJSON = legacyData
        let renderedPreview = HTMLWorkspacePreviewDocument.render(package: legacyPackage)
        #expect(!renderedPreview.contains("Archived paid chat"))
        #expect(!renderedPreview.contains("recent_chat"))
    }

    @Test("free V1 welcome back hides stored AI narrative and chat stats")
    func welcomeBackPresentationFailsClosedForPaidSessionData() {
        let info = WelcomeBackInfo(
            intentSummary: "Paid agent recap that must not appear in free V1.",
            userNote: "Review the draft.",
            noteCount: 2,
            chatCount: 4,
            graphWasOpen: true,
            sessionMinutes: 18,
            editedNoteTitles: ["Draft"]
        )

        #expect(info.sanitizedIntentSummary.isEmpty)
        #expect(info.presentedChatCount == nil)
        #expect(!info.displayText.contains("Paid agent recap"))
        #expect(!info.displayText.contains("chat"))
        #expect(!info.spokenSessionSummary.contains("chat"))
        #expect(info.spokenSessionSummary.contains("2 notes"))
    }

    @Test("free V1 workspace history hides paid summaries and chat activity")
    func workspaceHistoryPresentationFailsClosedForPaidSessionData() {
        let workspace = SDWorkspace(name: "Archived workspace")
        workspace.summary = "Paid model recap that must not appear in free V1."

        var chatOnlyDiff = WorkspaceDiffSummary()
        chatOnlyDiff.chatsStarted = 2
        chatOnlyDiff.chatMessagesSent = 5

        #expect(workspace.presentedSummary.isEmpty)
        #expect(ProductCapabilityPolicy.sanitizedAIOutput(workspace.summary).isEmpty)
        #expect(chatOnlyDiff.presentedChatActivity.started == 0)
        #expect(chatOnlyDiff.presentedChatActivity.messagesSent == 0)
        #expect(!chatOnlyDiff.hasPresentedChanges)

        chatOnlyDiff.notesOpened = 1
        #expect(chatOnlyDiff.hasPresentedChanges)
    }

    @Test("Epdoc Source keeps its line-number gutter on the active surface")
    func sourceEditorGutterUsesTheActiveSurface() {
        for theme in [EpistemosTheme.light, EpistemosTheme.platinumVioletDark] {
            let palette = MarkEditCoreEditorThemePalette.current(theme: theme)
            #expect(palette.gutter == palette.background)
        }
    }

    @Test("generation and model capability admission remain fail-closed")
    func generationAdmissionFailsClosed() {
        // AppleIntelligenceService is intentionally excluded from the Free V1
        // target. The target-level contract must therefore prove the boundary
        // without compiling or recreating a model service just for this test.
        #expect(!ProductCapabilityPolicy.isAvailable(.generativeActions))
        #expect(!ProductCapabilityPolicy.isAvailable(.models))
        #expect(!ProductCapabilityPolicy.allowsHTMLWorkspaceRegeneration)
    }

    @Test("free V1 graph defaults retain on-device sentence embeddings")
    func graphDefaultsRetainOnDeviceSentenceEmbeddings() {
        let serviceDefault = EmbeddingService()
            .swiftFallbackEmbeddingLookupForBackground()
        let graphState = GraphState()
        let graphDefault = graphState
            .embeddingService
            .swiftFallbackEmbeddingLookupForBackground()

        #expect(graphState.semanticClusteringAvailable)
        for lookup in [serviceDefault, graphDefault] {
            #expect(lookup.dimension > 0)
            #expect(
                lookup.textVector(for: "semantic paragraph search for research notes")?.count
                    == lookup.dimension
            )
        }
    }

    @Test("free V1 sentence embeddings rank related paragraphs above unrelated text")
    func sentenceEmbeddingsPreserveBasicParagraphSemantics() throws {
        let lookup = EmbeddingService().swiftFallbackEmbeddingLookupForBackground()
        let query = try #require(
            lookup.textVector(for: "notes from the product planning meeting")
        )
        let related = try #require(
            lookup.textVector(for: "team discussion and action items from our planning session")
        )
        let unrelated = try #require(
            lookup.textVector(for: "bake sourdough bread with flour and water")
        )

        func cosine(_ lhs: [Float], _ rhs: [Float]) -> Float? {
            guard lhs.count == rhs.count, !lhs.isEmpty else { return nil }
            let dot = zip(lhs, rhs).reduce(Float.zero) { $0 + $1.0 * $1.1 }
            let leftNorm = lhs.reduce(Float.zero) { $0 + $1 * $1 }.squareRoot()
            let rightNorm = rhs.reduce(Float.zero) { $0 + $1 * $1 }.squareRoot()
            guard leftNorm > 0, rightNorm > 0 else { return nil }
            return dot / (leftNorm * rightNorm)
        }

        let relatedScore = try #require(cosine(query, related))
        let unrelatedScore = try #require(cosine(query, unrelated))
        #expect(relatedScore > unrelatedScore)
    }

    @Test("free V1 keeps an explicit no-model path fail-closed")
    func explicitNoModelEmbeddingLookupFailsClosed() {
        let disabledService = EmbeddingService(embeddingLookup: NoModelTextEmbeddingLookup())
        #expect(!disabledService.isSwiftEmbeddingFallbackAvailable)
        #expect(disabledService.queryEmbedding(for: "semantic query") == nil)
        #expect(disabledService.computeBlockVectors(blocks: [
            (id: "paragraph", content: "a related paragraph")
        ]).isEmpty)

        let localService = EmbeddingService(
            embeddingLookup: FreeV1DeterministicParagraphLookup()
        )
        #expect(localService.isSwiftEmbeddingFallbackAvailable)
        #expect(localService.queryEmbedding(for: "semantic query") == [0, 1, 0])
        #expect(localService.queryEmbedding(for: "semantic query", expectedDimension: 2) == nil)
        #expect(localService.computeBlockVectors(blocks: [
            (id: "paragraph", content: "a related paragraph"),
            (id: "absent", content: "unmapped paragraph")
        ]) == ["paragraph": [0, 0.8, 0.2]])
    }

    @Test("free V1 App Intents metadata is an exact deterministic whitelist")
    func appIntentsMetadataUsesExactDeterministicWhitelist() throws {
        #expect(EpistemosShortcutsProvider.appShortcuts.count == 4)

        let metadataURL = try #require(Bundle.main.url(
            forResource: "extract",
            withExtension: "actionsdata",
            subdirectory: "Metadata.appintents"
        ))
        let metadata = try Data(contentsOf: metadataURL)
        let root = try #require(
            JSONSerialization.jsonObject(with: metadata) as? [String: Any]
        )
        let actions = try #require(root["actions"] as? [String: Any])
        let entities = try #require(root["entities"] as? [String: Any])
        let queries = try #require(root["queries"] as? [String: Any])
        let enums = root["enums"] as? [[String: Any]] ?? []
        let autoShortcuts = try #require(root["autoShortcuts"] as? [[String: Any]])

        let expectedActions: Set<String> = [
            "ArchiveNoteIntent",
            "CaptureBrainDumpIntent",
            "CreateJournalIntent",
            "CreateNoteIntent",
            "DeleteNoteIntent",
            "MoveNoteToFolderIntent",
            "NotePreviewSnippet",
            "OpenPanelIntent",
            "OpenVaultFileIntent",
            "QuickCaptureIntent",
            "SearchDocumentsIntent",
            "SearchJournalIntent",
            "SystemSearchIntent",
        ]
        let expectedEntities: Set<String> = [
            "FolderEntity",
            "JournalEntity",
            "NoteEntity",
            "PanelEntity",
            "WordProcessorDocumentEntity",
            "WordProcessorDocumentTemplateEntity",
        ]
        let expectedQueries: Set<String> = [
            "FolderEntityQuery",
            "JournalEntityQuery",
            "NoteEntityQuery",
            "PanelEntityQuery",
            "WordProcessorDocumentQuery",
            "WordProcessorTemplateQuery",
        ]
        let expectedAutoShortcuts = [
            "CreateNoteIntent",
            "SystemSearchIntent",
            "QuickCaptureIntent",
            "CaptureBrainDumpIntent",
        ]

        #expect(Set(actions.keys) == expectedActions)
        #expect(Set(entities.keys) == expectedEntities)
        #expect(Set(queries.keys) == expectedQueries)
        #expect(enums.compactMap { $0["identifier"] as? String }.isEmpty)
        #expect(autoShortcuts.compactMap { $0["actionIdentifier"] as? String } == expectedAutoShortcuts)
        #expect((root["assistantIntents"] as? [Any])?.isEmpty == true)
        #expect((root["assistantEntities"] as? [Any])?.isEmpty == true)
    }

    @Test("free V1 app bundle omits paid runtime resources")
    func appBundleOmitsPaidRuntimeResources() {
        #expect(Bundle.main.bundleIdentifier == "com.epistemos.appstore")
        #expect(Bundle.main.url(forResource: "JuneWeb", withExtension: nil) == nil)
        #expect(Bundle.main.url(forResource: "model_manifest", withExtension: "json") == nil)
        #expect(Bundle.main.url(forResource: "DefaultSkills", withExtension: nil) == nil)

        let frameworks = Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks", isDirectory: true)
        let fileManager = FileManager.default
        #expect(!fileManager.fileExists(atPath: frameworks.appendingPathComponent("llama.framework").path))
        #expect(!fileManager.fileExists(atPath: frameworks.appendingPathComponent("libagent_core.dylib").path))
        #expect(!fileManager.fileExists(atPath: frameworks.appendingPathComponent("libomega_mcp.dylib").path))
    }
}
