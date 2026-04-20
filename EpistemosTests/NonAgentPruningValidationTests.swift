import Foundation
import Testing

@Suite("Non-Agent Pruning Validation")
struct NonAgentPruningValidationTests {
    @Test("setup assistant stays note-first and does not foreground Omega permissions")
    func setupAssistantStaysNoteFirst() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Onboarding/SetupAssistantView.swift")

        #expect(!source.contains("import ScreenCaptureKit"))
        #expect(!source.contains("Omega agent"))
        #expect(!source.contains("Screen Recording"))
        #expect(!source.contains("OmegaPermissions.checkAccessibility()"))
        #expect(!source.contains("case .permissions"))
        #expect(source.contains("private note intelligence"))
    }

    @Test("setup assistant explains vault sync instead of claiming live markdown-only storage")
    func setupAssistantUsesVaultSyncNarrative() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Onboarding/SetupAssistantView.swift")

        #expect(!source.contains("all notes are stored as Markdown files"))
        #expect(source.contains("sync"))
        #expect(source.contains("local note bodies"))
    }

    @Test("setup assistant allows fresh local-only setup without a vault")
    func setupAssistantAllowsFreshLocalOnlySetup() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Onboarding/SetupAssistantView.swift")

        #expect(source.contains("Button(\"Skip\") { withAnimation(Self.stepTransition) { currentStep = .model } }"))
        #expect(!source.contains("if vaultSync.vaultURL != nil {\n                    Button(\"Skip\")"))
    }

    @Test("main window leaves the SwiftUI home window background-drag policy untouched")
    func mainWindowLeavesBackgroundDraggingUntouched() throws {
        let source = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(!source.contains("window.isMovableByWindowBackground = false"))
        #expect(!source.contains("if window.isMovableByWindowBackground"))
        #expect(source.contains("enum WindowPresentationPolicy"))
    }

    @Test("session intelligence overlay prefers live editor text before disk fallback")
    func sessionIntelligenceOverlayPrefersEditorBodies() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Landing/SessionIntelligenceOverlay.swift")

        #expect(source.contains("private func currentBody(for pageId: String) -> String"))
        #expect(source.contains("NoteWindowManager.shared.currentBody(for: pageId, mapped: true)"))
    }

    @Test("session intelligence overlay avoids full vault scans for title lookups")
    func sessionIntelligenceOverlayAvoidsFullVaultScansForTitleLookups() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Landing/SessionIntelligenceOverlay.swift")

        #expect(!source.contains("let pages = (try? context.fetch(FetchDescriptor<SDPage>())) ?? []"))
        #expect(!source.contains("let chats = (try? context.fetch(FetchDescriptor<SDChat>())) ?? []"))
        #expect(source.contains("FetchDescriptor<SDChat>(predicate: #Predicate { $0.id == chatId })"))
        #expect(source.contains("ChatPreviewText.preview(for: persisted)"))
    }

    @Test("session intelligence overlay removes the legacy reopen-note command path")
    func sessionIntelligenceOverlayRemovesLegacyReopenPath() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Landing/SessionIntelligenceOverlay.swift")

        #expect(!source.contains("SessionIntelligenceNoteLookup.candidateTitles(in: text)"))
        #expect(!source.contains("findOpenNoteByTitle(candidate)"))
        #expect(!source.contains("private func findNoteByTitle("))
        #expect(!source.contains("private func findOpenNoteByTitle("))
    }

    @Test("session intelligence overlay removes the legacy chat summarization command path")
    func sessionIntelligenceOverlayRemovesLegacyChatSummaries() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Landing/SessionIntelligenceOverlay.swift")

        #expect(!source.contains("SessionIntelligenceChatSummary.orderedGroups(from: chatGroups, limit: 10)"))
        #expect(!source.contains("loadChatTitles(for: orderedGroups.map(\\.chatId), in: context)"))
        #expect(!source.contains("private func summarizeChats() async"))
    }

    @Test("session intelligence overlay shares autosave summary and note presentation helpers")
    func sessionIntelligenceOverlaySharesAutosaveAndPresentationHelpers() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Landing/SessionIntelligenceOverlay.swift")

        #expect(source.contains("private func latestAutoSavedWorkspaceSummary("))
        #expect(source.contains("private func createAndOpenNote("))
        #expect(source.contains("SessionIntelligenceOverlayTiming.notePresentationDelay()"))
        #expect(source.contains("SessionIntelligenceOverlayTiming.dismissDelay()"))
        #expect(!source.contains("try? await Task.sleep(for: .milliseconds(100))"))
        #expect(!source.contains("try? await Task.sleep(for: .milliseconds(150))"))
        #expect(!source.contains("try? AppBootstrap.shared?.modelContainer.mainContext.save()"))
    }

    @Test("session intelligence overlay uses direct actions instead of an embedded chat console")
    func sessionIntelligenceOverlayUsesDirectActionsInsteadOfEmbeddedChat() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Landing/SessionIntelligenceOverlay.swift")

        #expect(source.contains("private var sessionActionSection: some View"))
        #expect(source.contains("Save Session Note"))
        #expect(source.contains("Open Notes"))
        #expect(!source.contains("Session Intelligence Chat"))
        #expect(!source.contains("TextField(\"Ask about your session"))
        #expect(!source.contains("Picker(\"\", selection: $chatModel)"))
        #expect(!source.contains("@State private var commandInput"))
        #expect(!source.contains("private func executeCommand() async"))
        #expect(!source.contains("private func runAIQuery(_ query: String) async -> String"))
    }

    @Test("setup assistant sheet uses shared app environment injection")
    func setupAssistantSheetUsesSharedEnvironment() throws {
        let source = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(source.contains("SetupAssistantView {"))
        #expect(source.contains(".withAppEnvironment(bootstrap)"))
        #expect(!source.contains(".environment(bootstrap.vaultSync)"))
        #expect(!source.contains(".environment(bootstrap.inferenceState)"))
    }

    @Test("settings sidebar exposes the current advanced sections without restoring Omega")
    func settingsSidebarShowsAdvancedSections() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(source.contains("static let visibleSections"))
        #expect(source.contains("ForEach(SettingsCategory.orderedCases)"))
        #expect(source.contains("SettingsSection.visibleSections"))
        #expect(!source.contains("List(SettingsSection.allCases"))
        #expect(source.contains(".cognitive"))
        #expect(source.contains(".knowledgeFusion"))
        #expect(source.contains(".modelVaults"))
        #expect(!source.contains(".omega"))
    }

    @Test("backlinks popover offloads body scanning and avoids page loadBody in the view task")
    func backlinksPopoverOffloadsScanning() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteBacklinksPanel.swift")

        #expect(source.contains("Task.detached(priority: .utility)"))
        #expect(source.contains("NoteFileStorage.readBody(pageId: candidate.id, mapped: true)"))
        #expect(!source.contains("page.loadBody(mapped: true)"))
    }

    @Test("graph node inspector prefers live editor text before disk fallback")
    func graphNodeInspectorPrefersEditorBody() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")

        #expect(source.contains("private func currentBody(for pageId: String) -> String"))
        #expect(source.contains("NoteWindowManager.shared.currentBody(for: pageId)"))
    }

    @Test("node inspector state prefers live editor bodies before disk fallback")
    func nodeInspectorStatePrefersEditorBodies() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(source.contains("private func currentEditorBody(for pageId: String) -> String?"))
        #expect(source.contains("private func liveEditorBodies(for pageIds: [String]) -> [String: String]"))
        #expect(source.contains("NoteWindowManager.shared.editorBody(for: pageId)"))
        #expect(source.contains("if let liveBody = currentEditorBody(for: sourceId)"))
    }

    @Test("note workspace prefers live editor state when rehydrating persisted bodies")
    func noteWorkspacePrefersLiveEditorBodies() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(source.contains("NoteWindowManager.shared.currentBody(for: pageId)"))
    }

    @Test("living guidance documents point to the production TK2 editor stack")
    func livingGuidanceDocumentsUseProductionTK2Paths() throws {
        let agents = try loadRepoTextFile("AGENTS.md")
        let memory = try loadRepoTextFile("docs/codex-memory.md")
        let claude = try loadRepoTextFile("CLAUDE.md")

        for source in [agents, memory, claude] {
            #expect(source.contains("ProseEditorRepresentable2.swift"))
            #expect(source.contains("ProseTextView2.swift"))
            #expect(!source.contains("Views/Notes/ProseEditorRepresentable.swift"))
        }
    }

    @Test("living guidance documents use the current dialogue surfaces")
    func livingGuidanceDocumentsUseCurrentDialogueSurfaces() throws {
        let memory = try loadRepoTextFile("docs/codex-memory.md")

        #expect(memory.contains("HologramOverlay.swift"))
        #expect(memory.contains("HologramNodeInspector.swift"))
        #expect(!memory.contains("DialogueOverlayView"))
        #expect(!memory.contains("NoteChatOrb"))
    }

    @Test("legacy comparison tests are labeled as compatibility coverage")
    func legacyComparisonTestsAreLabeledClearly() throws {
        let benchmarks = try loadRepoTextFile("EpistemosTests/TextKit2BenchmarkTests.swift")
        let layout = try loadRepoTextFile("EpistemosTests/NoteEditorLayoutTests.swift")

        #expect(benchmarks.contains("legacy compatibility"))
        #expect(!benchmarks.contains("TK1 vs TK2 Performance"))
        #expect(!layout.contains("@Test(\"classic editor"))
        #expect(layout.contains("legacy compatibility"))
    }

    @Test("prose editor view prefers live editor bodies before disk fallback")
    func proseEditorViewPrefersLiveBodies() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")

        #expect(source.contains("private static func currentBody(for page: SDPage, preferredBody: String? = nil) -> String"))
        #expect(source.contains("NoteWindowManager.shared.currentBody(for: page.id)"))
        #expect(source.contains("let body = Self.currentBody(for: page)"))
        #expect(source.contains("let fresh = Self.currentBody(for: page)"))
    }

    @Test("note window manager exposes a shared live-editor-first body helper")
    func noteWindowManagerExposesCurrentBodyHelper() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteWindowManager.swift")

        #expect(source.contains("func currentBody(for pageId: String, mapped: Bool = false) -> String"))
        #expect(source.contains("editorBody(for: pageId) ?? NoteFileStorage.readBody(pageId: pageId, mapped: mapped, fast: !mapped)"))
    }

    @Test("workspace and activity surfaces use the shared live-editor-first body helper")
    func workspaceAndActivitySurfacesUseSharedBodyHelper() throws {
        let activity = try loadRepoTextFile("Epistemos/State/ActivityTracker.swift")
        let workspace = try loadRepoTextFile("Epistemos/State/WorkspaceSummaryService.swift")
        let chatCoordinator = try loadRepoTextFile("Epistemos/App/ChatCoordinator.swift")
        let timeMachine = try loadRepoTextFile("Epistemos/State/TimeMachineService.swift")

        #expect(activity.contains("NoteWindowManager.shared.currentBody(for: pageId, mapped: true)"))
        #expect(workspace.contains("NoteWindowManager.shared.currentBody(for: pageId, mapped: true)"))
        #expect(chatCoordinator.contains("NoteWindowManager.shared.currentBody(for: pageId, mapped: true)"))
        #expect(timeMachine.contains("NoteWindowManager.shared.currentBody(for: pageId, mapped: true)"))
    }

    @Test("mini chat snapshots prefer live editor text before disk fallback")
    func miniChatSnapshotsPreferLiveEditorBodies() throws {
        let source = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(source.contains("@MainActor init(page: SDPage, preferredBody: String?)"))
        #expect(source.contains("let body = preferredBody ?? NoteWindowManager.shared.currentBody(for: page.id)"))
    }

    @Test("chat preview helpers fall back to structured tool activity when prose is empty")
    func chatPreviewHelpersFallbackToToolActivity() throws {
        let source = try loadRepoTextFile("Epistemos/Models/ChatTypes.swift")

        #expect(source.contains("toolSummaryPreview"))
        #expect(source.contains("decodedContentBlocks()"))
    }

    @Test("daily brief recent note context prefers live editor text before disk fallback")
    func dailyBriefRecentContextPrefersLiveEditorBodies() throws {
        let source = try loadRepoTextFile("Epistemos/State/DailyBriefState.swift")

        #expect(source.contains("NoteWindowManager.shared.currentBody(for: pageId, mapped: true)"))
        #expect(!source.contains("page.loadBody(mapped: true)"))
        #expect(source.contains("let body = persistedOrLiveBody.isEmpty ? page.body : persistedOrLiveBody"))
    }

    @Test("instant recall seed rebuild prefers captured live editor text before disk fallback")
    func instantRecallSeedRebuildPrefersLiveEditorBodies() throws {
        let source = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(source.contains("let liveBody: String?"))
        #expect(source.contains("let text = seed.liveBody ?? (diskBody.isEmpty ? seed.inlineBody : diskBody)"))
        #expect(source.contains("liveBody: NoteWindowManager.shared.editorBody(for: $0.id)"))
    }

    @Test("app bootstrap uses guarded backing storage instead of implicitly unwrapped services")
    func appBootstrapAvoidsImplicitlyUnwrappedServiceSlots() throws {
        let source = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(source.contains("private static func requireInitialized"))
        #expect(source.contains("private var _workspaceService: WorkspaceService?"))
        #expect(source.contains("var workspaceService: WorkspaceService { Self.requireInitialized(_workspaceService, name: \"workspaceService\") }"))
        #expect(source.contains("private var _coordinator: AppCoordinator?"))
        #expect(source.contains("var coordinator: AppCoordinator { Self.requireInitialized(_coordinator, name: \"coordinator\") }"))
        #expect(!source.contains("private(set) var workspaceService: WorkspaceService!"))
        #expect(!source.contains("private(set) var coordinator: AppCoordinator!"))
        #expect(!source.contains("private(set) var timeMachineService: TimeMachineService!"))
    }

    @Test("note and journal intent entities prefer live editor text before disk fallback")
    func intentEntitiesPreferLiveEditorBodies() throws {
        let noteEntity = try loadRepoTextFile("Epistemos/Intents/Entities/NoteEntity.swift")
        let journalEntity = try loadRepoTextFile("Epistemos/Intents/Schemas/JournalIntents.swift")

        #expect(noteEntity.contains("@MainActor func toNoteEntity(contentPreview: String? = nil) -> NoteEntity"))
        #expect(noteEntity.contains("let pageBody = contentPreview ?? NoteWindowManager.shared.currentBody(for: id)"))
        #expect(journalEntity.contains("@MainActor func toJournalEntity(markdownPreview: String? = nil) -> JournalEntity"))
        #expect(journalEntity.contains("NoteWindowManager.shared.currentBody(for: id)"))
    }

    @Test("note analysis and summarize intents prefer live editor text before disk fallback")
    func noteAnalysisAndSummarizeIntentsPreferLiveEditorBodies() throws {
        let analysis = try loadRepoTextFile("Epistemos/Intents/Custom/AnalysisIntents.swift")
        let noteActions = try loadRepoTextFile("Epistemos/Intents/Custom/NoteActionIntents.swift")

        #expect(analysis.contains("NoteWindowManager.shared.currentBody(for: page.id, mapped: true)"))
        #expect(noteActions.contains("let content = NoteWindowManager.shared.currentBody(for: page.id)"))
    }

    @Test("core app surfaces do not foreground deferred Omega shortcuts or training claims")
    func coreAppSurfacesDoNotForegroundDeferredFeatures() throws {
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let shortcuts = try loadRepoTextFile("Epistemos/Intents/EpistemosShortcutsProvider.swift")
        let omegaIntent = try loadRepoTextFile("Epistemos/Intents/Custom/OmegaIntent.swift")
        let uiState = try loadRepoTextFile("Epistemos/State/UIState.swift")

        #expect(!rootView.contains("omegaToolbarButton"))
        #expect(!app.contains("Button(\"Show Omega\")"))
        #expect(!shortcuts.contains("OmegaTaskIntent"))
        #expect(omegaIntent.contains("static var isDiscoverable: Bool { false }"))
        #expect(omegaIntent.contains("Agent Runtime shortcuts aren't available in this build"))
        #expect(!uiState.contains("Knowledge Fusion trains a model on your writing style"))
        #expect(uiState.contains("daily briefs summarize recent notes and conversations"))
    }

    @Test("historical docs are labeled so deleted TK1 and old dialogue surfaces are not treated as current")
    func historicalDocsAreLabeledClearly() throws {
        let integrationPlan = try loadRepoTextFile("docs/plans/2026-03-07-apple-frameworks-integration-plan.md")
        let releaseAudit = try loadRepoTextFile("docs/codex-v2-release-audit.md")
        let hardening = try loadRepoTextFile("docs/audits/2026-03-10-release-hardening-report.md")
        let logicAudit = try loadRepoTextFile("docs/audits/2026-03-10-logic-performance-audit.md")
        let platinumAudit = try loadRepoTextFile("docs/audits/2026-03-11-platinum-theme-markdown-audit.md")

        for source in [integrationPlan, releaseAudit, hardening, logicAudit, platinumAudit] {
            #expect(source.contains("Historical snapshot"))
        }
    }

    @Test("previously flagged live surfaces stay free of force unwraps")
    func previouslyFlaggedLiveSurfacesStayFreeOfForceUnwraps() throws {
        for relativePath in [
            "Epistemos/Views/Notes/ProseEditorRepresentable2.swift",
            "Epistemos/Views/Graph/HologramOverlay.swift",
            "Epistemos/Views/Graph/MetalGraphView.swift",
            "Epistemos/Views/Landing/SessionIntelligenceOverlay.swift",
        ] {
            try expectNoForceUnwraps(in: relativePath)
        }
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }

    private func expectNoForceUnwraps(in relativePath: String) throws {
        let source = try loadRepoTextFile(relativePath)
        let pattern = #"(?<![=!<>])(?:[A-Za-z_][A-Za-z0-9_]*|\)|\]|\})!(?!=)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        #expect(matches.isEmpty, "\(relativePath) still contains force unwrap syntax")
    }
}
