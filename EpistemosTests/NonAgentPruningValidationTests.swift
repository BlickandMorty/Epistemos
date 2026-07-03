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
        #expect(source.contains("vault sync, fast search, provenance, skills, tools, and MCP"))
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

        #expect(source.contains("Button(\"Skip\")"))
        #expect(source.contains("withAnimation(stepTransitionAnimation) { currentStep = .model }"))
        #expect(!source.contains("if vaultSync.vaultURL != nil {\n                    Button(\"Skip\")"))
    }

    @Test("main window leaves the SwiftUI home window background-drag policy untouched")
    func mainWindowLeavesBackgroundDraggingUntouched() throws {
        let source = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(!source.contains("window.isMovableByWindowBackground = false"))
        #expect(!source.contains("if window.isMovableByWindowBackground"))
        #expect(source.contains("enum WindowPresentationPolicy"))
    }

    @Test("session intelligence is removed from landing and global command paths")
    func sessionIntelligenceIsRemovedFromLandingAndGlobalCommandPaths() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let root = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let quitSave = try loadRepoTextFile("Epistemos/Views/Landing/QuitSavePanelController.swift")

        #expect(!app.contains("toggleSessionIntelligence"))
        #expect(!app.contains("Session Intelligence"))
        #expect(!root.contains("showSessionIntelligence"))
        #expect(!root.contains("SessionIntelligenceOverlay"))
        #expect(!landing.contains("Session Intelligence"))
        #expect(!quitSave.contains("GlobalSessionIntelligence"))
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

        #expect(source.contains("static var visibleSections"))
        #expect(source.contains("ForEach(SettingsCategory.orderedCases)"))
        #expect(source.contains("SettingsSection.visibleSections"))
        #expect(!source.contains("List(SettingsSection.allCases"))
        #expect(source.contains(".substrateHealth"))
        #expect(source.contains(".workClone"))
        #expect(!source.contains(".cognitive"))
        #expect(!source.contains(".knowledgeFusion"))
        #expect(!source.contains(".modelVaults"))
        #expect(source.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(!source.contains(".omega"))
    }

    @Test("settings exposes user-facing retention controls for local history")
    func settingsExposeUserFacingRetentionControlsForLocalHistory() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let policy = try loadRepoTextFile("Epistemos/State/AppDataRetentionPolicy.swift")
        let eventStore = try loadRepoTextFile("Epistemos/State/EventStore.swift")
        let workspaceService = try loadRepoTextFile("Epistemos/State/WorkspaceService.swift")

        #expect(settings.contains("Section(\"Data Retention\")"))
        #expect(settings.contains("Time Machine history"))
        #expect(settings.contains("Detailed event log"))
        #expect(settings.contains("Ambient capture artifacts"))
        #expect(settings.contains("Apply Retention Now"))
        #expect(policy.contains("timeMachineRetentionDaysKey"))
        #expect(eventStore.contains("func applyRetentionPolicy("))
        #expect(workspaceService.contains("func enforceSavedWorkspaceLimit("))
    }

    @Test("backlinks popover offloads body scanning and avoids page loadBody in the view task")
    func backlinksPopoverOffloadsScanning() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteBacklinksPanel.swift")

        #expect(source.contains("Task.detached(priority: .utility)"))
        #expect(source.contains("await SDPage.loadBodyAsyncFromPrimitives("))
        #expect(source.contains("filePath: candidate.filePath"))
        #expect(source.contains("inlineBody: candidate.inlineBody"))
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
        #expect(source.contains("private struct BodyReadStage: Sendable"))
        #expect(source.contains("await SDPage.loadBodyAsyncFromPrimitives("))
        #expect(source.contains("NoteWindowManager.shared.editorBody(for: pageId)"))
        #expect(source.contains("if let liveBody = currentEditorBody(for: sourceId)"))
    }

    @Test("note workspace prefers live editor state when rehydrating persisted bodies")
    func noteWorkspacePrefersLiveEditorBodies() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(source.contains("private func schedulePersistedBodyRefresh(for page: SDPage?)"))
        #expect(source.contains("NoteWindowManager.shared.editorBody(for: pageId)"))
        #expect(source.contains("NoteFileStorage.readBody(pageId: pageId, mapped: false, fast: true)"))
        #expect(source.contains("_persistedBody = State(initialValue: \"\")"))
        #expect(!source.contains("_persistedBody = State(initialValue: NoteWindowManager.shared.currentBody"))
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

        #expect(source.contains("@State private var loadedBodyPageId: String?"))
        #expect(source.contains("private func loadBodyIfNeeded(force: Bool) async"))
        #expect(source.contains("NoteWindowManager.shared.editorBody(for: pageId)"))
        #expect(source.contains("NoteFileStorage.readBody(pageId: pageId, mapped: false, fast: true)"))
        #expect(source.contains("if loadedBodyPageId == page.id"))
        #expect(!source.contains("private static func currentBody(for page: SDPage"))
        #expect(!source.contains("NoteWindowManager.shared.currentBody(for: page.id)"))
        #expect(!source.contains("Self.currentBody(for: page)"))
    }

    @Test("note window manager exposes a shared live-editor-first body helper")
    func noteWindowManagerExposesCurrentBodyHelper() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteWindowManager.swift")

        #expect(source.contains("func currentBody(for pageId: String, mapped: Bool = false) -> String"))
        #expect(source.contains("editorBody(for: pageId) ?? NoteFileStorage.readBody(pageId: pageId, mapped: mapped, fast: !mapped)"))
    }

    @Test("workspace and idle summary surfaces use the shared live-editor-first body helper")
    func workspaceAndIdleSummarySurfacesUseSharedBodyHelper() throws {
        let activity = try loadRepoTextFile("Epistemos/State/ActivityTracker.swift")
        let workspace = try loadRepoTextFile("Epistemos/State/WorkspaceSummaryService.swift")
        let timeMachine = try loadRepoTextFile("Epistemos/State/TimeMachineService.swift")

        #expect(activity.contains("NoteWindowManager.shared.editorBody(for: pageId)"))
        #expect(activity.contains("Task.detached(priority: .utility)"))
        #expect(activity.contains("NoteFileStorage.readBody(pageId: pageId, mapped: true, fast: true)"))
        #expect(!activity.contains("NoteWindowManager.shared.currentBody(for: pageId, mapped: true)"))
        #expect(workspace.contains("NoteWindowManager.shared.currentBody(for: pageId, mapped: true)"))
        #expect(timeMachine.contains("NoteWindowManager.shared.currentBody(for: pageId, mapped: true)"))
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
        // omegaIntent (Intents/Custom/OmegaIntent.swift) removed with cloud-only/Omega removal
        // 2026-07-03 — the intent no longer exists (stronger than the prior "not discoverable" guard).
        let uiState = try loadRepoTextFile("Epistemos/State/UIState.swift")

        #expect(!rootView.contains("omegaToolbarButton"))
        #expect(!app.contains("Button(\"Show Omega\")"))
        #expect(!shortcuts.contains("OmegaTaskIntent"))
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
            "Epistemos/Engine/EpdocDocument.swift",
            "Epistemos/Engine/LSPMessage.swift",
        ] {
            try expectNoForceUnwraps(in: relativePath)
        }
    }

    @Test("coder-only AppKit scaffolds fail initialization instead of trapping")
    func coderOnlyAppKitScaffoldsDoNotTrap() throws {
        for relativePath in [
            "Epistemos/Views/Notes/BlockRefAutocomplete2.swift",
            "Epistemos/Views/Notes/EditableTransclusionView.swift",
            "Epistemos/Views/Graph/GraphOverlayPanel.swift",
            "Epistemos/Views/Notes/NoteWindowManager.swift",
            "Epistemos/Views/Notes/MarkdownLayoutFragment.swift",
            "Epistemos/Views/Shared/MarkdownTextView.swift",
        ] {
            let source = try loadRepoTextFile(relativePath)
            #expect(source.contains("required init?(coder: NSCoder)"))
            #expect(source.contains("return nil"), "\(relativePath) should fail failable coder initialization without trapping")
            #expect(!source.contains("fatalError("), "\(relativePath) still traps from a coder-only initializer")
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
