import Foundation
import Testing
@testable import Epistemos

@MainActor
struct AgentCommandCenterStateTests {
    private static var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func repoFileExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(
            atPath: repoRootURL.appendingPathComponent(relativePath).path
        )
    }

    private static func makeTool(name: String, agent: String = "rust") -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: name,
            agent: agent,
            description: "test tool \(name)",
            argumentsExample: "{}",
            schemaJson: "{}",
            destructive: false,
            requiresConfirmation: false
        )
    }

    private static func makeDefaults() -> UserDefaults {
        let suiteName = "AgentCommandCenterStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static func makeLocalBrain(_ model: LocalTextModelID) -> ACCBrainSelection {
        .local(
            modelId: model.rawValue,
            displayName: model.compactDisplayName,
            supportsThinking: model.supportsThinkingMode,
            supportsVision: model.supportsVision,
            supportsTools: model.supportsNativeToolCalling
        )
    }

    // MARK: - Presentation Lifecycle

    @Test func present() {
        let state = AgentCommandCenterState()
        #expect(!state.isPresented)
        state.present()
        #expect(state.isPresented)
    }

    @Test func dismiss() {
        let state = AgentCommandCenterState()
        state.present()
        state.dismiss()
        #expect(!state.isPresented)
        #expect(state.suggestionMenuState == .hidden)
    }

    @Test func presentIsIdempotent() {
        let state = AgentCommandCenterState()
        state.present()
        state.present()
        #expect(state.isPresented)
    }

    @Test func dismissIsIdempotent() {
        let state = AgentCommandCenterState()
        state.dismiss()
        #expect(!state.isPresented)
    }

    // MARK: - Tool Toggles

    @Test func toolToggle() {
        let state = AgentCommandCenterState()
        state.toolToggles = ["safari_search": true, "file_read": true]

        state.toggleTool("safari_search")
        #expect(state.toolToggles["safari_search"] == false)
        #expect(state.toolToggles["file_read"] == true)
    }

    @Test func enableAllTools() {
        let state = AgentCommandCenterState()
        state.toolToggles = ["a": false, "b": false, "c": true]
        state.enableAllTools()
        #expect(state.toolToggles.values.allSatisfy { $0 })
    }

    @Test func disableAllTools() {
        let state = AgentCommandCenterState()
        state.toolToggles = ["a": true, "b": true, "c": false]
        state.disableAllTools()
        #expect(state.toolToggles.values.allSatisfy { !$0 })
    }

    @Test func enabledToolNames() {
        let state = AgentCommandCenterState()
        state.toolToggles = ["a": true, "b": false, "c": true]
        let enabled = state.enabledToolNames
        #expect(enabled == Set(["a", "c"]))
    }

    @Test func defaultsToStandardPresentationAndProMode() {
        // Use an ephemeral UserDefaults to isolate this test from any
        // persisted activeSpecialistPreset left over from parallel or
        // prior test runs. `AgentCommandCenterState()` with default args
        // reads from UserDefaults.standard, which leaks state across the
        // suite under parallel execution.
        let defaults = Self.makeDefaults()
        let state = AgentCommandCenterState(userDefaults: defaults)
        #expect(state.presentationMode == .standard)
        #expect(state.selectedOperatingMode == .pro)
        #expect(state.nativeProviderEffort == .medium)
    }

    @Test func nativeProviderEffortStringsMatchRustBridgeContract() {
        #expect(ACCNativeProviderEffort.allCases.map(\.rustValue) == ["low", "medium", "high", "max"])
    }

    @Test func curatedAgentSpecialistsExposePurposefulModesAndExperts() {
        #expect(
            ACCSlashCommand.featuredAgentQuickActions == [
                .plan, .notes, .code, .debug, .research, .securityReview,
            ]
        )
        #expect(ACCSlashCommand.notes.defaultOperatingMode == .agent)
        #expect(ACCSlashCommand.code.defaultOperatingMode == .agent)
        #expect(ACCSlashCommand.securityReview.defaultOperatingMode == .pro)
        #expect(ACCSlashCommand.notes.preferredToolNames.contains("vault_write"))
        #expect(ACCSlashCommand.code.expertAllowlist.contains("coding"))
        #expect(ACCSlashCommand.securityReview.expertAllowlist.contains("security-review"))
    }

    @Test func slashCommandsFilterToSupportedOperatingModes() {
        #expect(
            ACCSlashCommand.availableCommands(for: [.fast, .agent]).contains(.code)
        )
        #expect(
            !ACCSlashCommand.availableCommands(for: [.fast]).contains(.code)
        )
        #expect(
            ACCSlashCommand.availableCommands(for: [.thinking]).contains(.debug)
        )
        #expect(
            !ACCSlashCommand.availableCommands(for: [.thinking]).contains(.ask)
        )
    }

    @Test func slashCommandsProvideVisibleStarterPrompts() {
        #expect(!ACCSlashCommand.plan.suggestedPrompt.isEmpty)
        #expect(ACCSlashCommand.code.suggestedPrompt.contains("Implement"))
        #expect(ACCSlashCommand.research.suggestedPrompt.contains("sources"))
    }

    @Test func nativeProviderEffortOnlyAppearsForSupportedCloudBrains() {
        let state = AgentCommandCenterState()
        #expect(state.supportedNativeProviderEfforts.isEmpty)
        #expect(state.selectedNativeProviderEffort == nil)

        state.selectedBrain = .cloud(provider: .anthropic)
        #expect(state.supportedNativeProviderEfforts == ACCNativeProviderEffort.allCases)
        #expect(state.selectedNativeProviderEffort == .medium)

        state.selectedBrain = .cloud(provider: .openAI)
        #expect(state.supportedNativeProviderEfforts.isEmpty)
        #expect(state.selectedNativeProviderEffort == nil)
    }

    @Test func localBrainOnlyExposesValidatedModes() {
        let state = AgentCommandCenterState()
        state.selectedOperatingMode = .agent
        state.selectedBrain = .local(
            modelId: LocalTextModelID.gemma4_2B4Bit.rawValue,
            displayName: "Gemma 2B",
            supportsThinking: false,
            supportsVision: true,
            supportsTools: false
        )

        #expect(state.availableOperatingModes == [.fast])
        #expect(state.selectedOperatingMode == .fast)
    }

    @Test func refreshBrainCatalogHidesGemmaFourEvenWhenInstalled() {
        let state = AgentCommandCenterState(userDefaults: Self.makeDefaults())
        let inference = InferenceState(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        inference.setInstalledLocalTextModelIDs([
            LocalTextModelID.gemma4_4B4Bit.rawValue,
            LocalTextModelID.bonsai4B2Bit.rawValue,
            LocalTextModelID.qwen3_4B4Bit.rawValue,
        ])

        state.refreshBrainCatalog(from: inference)

        #expect(
            !state.availableBrains.contains(where: { $0.id == "local:\(LocalTextModelID.gemma4_4B4Bit.rawValue)" })
        )
        #expect(
            state.availableBrains.contains(where: { $0.id == "local:\(LocalTextModelID.bonsai4B2Bit.rawValue)" })
        )
        #expect(
            state.availableBrains.contains(where: { $0.id == "local:\(LocalTextModelID.qwen3_4B4Bit.rawValue)" })
        )
    }

    @Test func changingBrainSanitizesUnsupportedOperatingModes() {
        let state = AgentCommandCenterState()
        state.selectedOperatingMode = .pro
        state.selectedBrain = .local(
            modelId: LocalTextModelID.qwen25Coder7B.rawValue,
            displayName: "Coder 7B",
            supportsThinking: false,
            supportsVision: false,
            supportsTools: true
        )

        #expect(state.availableOperatingModes == [.agent])
        #expect(state.selectedOperatingMode == .agent)
    }

    @Test func alwaysThinkingBrainsHideFastInCommandCenter() {
        let deepseek = Self.makeLocalBrain(.deepseekR1Distill7B)
        let qwenCoder = Self.makeLocalBrain(.qwen25Coder7B)

        let expectedDeepseekModes: [EpistemosOperatingMode] =
            LocalToolGrammar.supportsStructuredToolCalling
            ? [.thinking, .agent]
            : [.thinking]
        #expect(deepseek.supportedOperatingModes == expectedDeepseekModes)
        #expect(qwenCoder.supportedOperatingModes == [.agent])
    }

    @Test func refreshToolCatalogUsesCurrentOperatingMode() {
        let fastTools = [Self.makeTool(name: "vault_search")]
        let agentTools = [
            Self.makeTool(name: "vault_search"),
            Self.makeTool(name: "send_message"),
        ]
        let state = AgentCommandCenterState(toolCatalogLoader: { _, mode, _ in
            switch mode {
            case .fast: return fastTools
            case .thinking: return fastTools
            case .pro: return fastTools
            case .agent: return agentTools
            }
        })
        let bridge = MCPBridge()

        state.selectedOperatingMode = .fast
        state.refreshToolCatalog(from: bridge, vaultPath: "/tmp/test-vault")

        #expect(state.availableTools.map(\.name) == ["vault_search"])
        #expect(state.toolToggles == ["vault_search": true])
        #expect(state.mcpToolsByAgent["rust"]?.map(\.name) == ["vault_search"])
    }

    @Test func changingOperatingModeRebuildsCatalogAndPreservesSharedToggleState() {
        let fastTools = [
            Self.makeTool(name: "vault_search"),
            Self.makeTool(name: "web_search"),
        ]
        let agentTools = [
            Self.makeTool(name: "vault_search"),
            Self.makeTool(name: "send_message"),
        ]
        // Isolated defaults — AgentCommandCenterState reads activeSpecialist
        // preset from UserDefaults at init. Without isolation, a lingering
        // preset from another test in the same suite overrides this test's
        // .fast → .agent sequence with the preset's defaultOperatingMode.
        let state = AgentCommandCenterState(
            toolCatalogLoader: { _, mode, _ in
                switch mode {
                case .fast: return fastTools
                case .thinking: return fastTools
                case .pro: return fastTools
                case .agent: return agentTools
                }
            },
            userDefaults: Self.makeDefaults()
        )
        let bridge = MCPBridge()

        state.selectedOperatingMode = .fast
        state.refreshToolCatalog(from: bridge, vaultPath: "/tmp/test-vault")
        state.toggleTool("vault_search")

        state.selectedOperatingMode = .agent

        #expect(state.availableTools.map(\.name) == ["vault_search", "send_message"])
        #expect(state.toolToggles["vault_search"] == false)
        #expect(state.toolToggles["send_message"] == true)
        #expect(state.toolToggles["web_search"] == nil)
    }

    @Test func coreAppStoreRefreshToolCatalogFiltersInjectedExternalTools() {
        let state = AgentCommandCenterState(
            toolCatalogLoader: { _, _, _ in
                [
                    Self.makeTool(name: "vault_search"),
                    Self.makeTool(name: "run_command"),
                    Self.makeTool(name: "get_ui_tree"),
                    Self.makeTool(name: "click"),
                ]
            },
            toolSurfaceDistribution: .coreAppStore,
            userDefaults: Self.makeDefaults()
        )

        state.refreshToolCatalog(from: MCPBridge(), vaultPath: "/tmp/test-vault")

        #expect(state.availableTools.map(\.name) == ["vault_search"])
        #expect(state.enabledToolNames == Set(["vault_search"]))
        #expect(state.mcpToolsByAgent["rust"]?.map(\.name) == ["vault_search"])
    }

    @Test func proResearchRefreshToolCatalogKeepsInjectedGatewayTools() {
        let state = AgentCommandCenterState(
            toolCatalogLoader: { _, _, _ in
                [
                    Self.makeTool(name: "vault_search"),
                    Self.makeTool(name: "run_command"),
                    Self.makeTool(name: "get_ui_tree"),
                    Self.makeTool(name: "click"),
                ]
            },
            toolSurfaceDistribution: .proResearch,
            userDefaults: Self.makeDefaults()
        )

        state.refreshToolCatalog(from: MCPBridge(), vaultPath: "/tmp/test-vault")

        #expect(state.availableTools.map(\.name) == [
            "vault_search",
            "run_command",
            "get_ui_tree",
            "click",
        ])
        #expect(state.enabledToolNames == Set([
            "vault_search",
            "run_command",
            "get_ui_tree",
            "click",
        ]))
    }

    @Test func applyingCodeSpecialistPrefersNextBestLocalBrainAndFocusedToolBundle() {
        let defaults = Self.makeDefaults()
        let fastTools = [
            Self.makeTool(name: "vault_search"),
            Self.makeTool(name: "read_file"),
            Self.makeTool(name: "web_search"),
        ]
        let agentTools = [
            Self.makeTool(name: "vault_search"),
            Self.makeTool(name: "vault_read"),
            Self.makeTool(name: "read_file"),
            Self.makeTool(name: "search_files"),
            Self.makeTool(name: "write_file"),
            Self.makeTool(name: "patch"),
            Self.makeTool(name: "bash_execute"),
            Self.makeTool(name: "execute_code"),
            Self.makeTool(name: "web_search"),
        ]
        let state = AgentCommandCenterState(
            toolCatalogLoader: { _, mode, _ in
                switch mode {
                case .agent: return agentTools
                case .fast, .thinking, .pro: return fastTools
                }
            },
            userDefaults: defaults
        )
        state.availableBrains = [
            Self.makeLocalBrain(.gemma4_4B4Bit),
            Self.makeLocalBrain(.qwen25Coder7B),
            Self.makeLocalBrain(.qwen36_35BA3B4Bit),
            .cloud(provider: .openAI),
        ]

        state.refreshToolCatalog(from: MCPBridge(), vaultPath: "/tmp/test-vault")
        state.applySpecialist(.code)

        #expect(state.activeSpecialistPreset == .code)
        #expect(state.selectedOperatingMode == .agent)
        #expect(state.selectedBrain?.id == "local:\(LocalTextModelID.qwen36_35BA3B4Bit.rawValue)")
        #expect(
            state.enabledToolNames == Set([
                "vault_search",
                "vault_read",
                "read_file",
                "search_files",
                "write_file",
                "patch",
                "bash_execute",
                "execute_code",
            ])
        )
        #expect(state.harnessHeadline == "Code")
        #expect(state.harnessPostureLine?.lowercased().contains("asks before risky writes") == true)
    }

    @Test func researchSpecialistRestoresStoredBrainPerRole() {
        let defaults = Self.makeDefaults()
        let state = AgentCommandCenterState(userDefaults: defaults)
        let deepseek = Self.makeLocalBrain(.deepseekR1Distill7B)
        let openAI = ACCBrainSelection.cloud(provider: .openAI)
        let anthropic = ACCBrainSelection.cloud(provider: .anthropic)
        state.availableBrains = [deepseek, openAI, anthropic]

        state.applySpecialist(.research)
        #expect(state.selectedBrain == openAI)

        state.selectedBrain = anthropic
        state.applySpecialist(.code)
        state.applySpecialist(.research)

        #expect(state.selectedBrain == anthropic)

        let restored = AgentCommandCenterState(userDefaults: defaults)
        restored.availableBrains = [deepseek, openAI, anthropic]
        restored.applySpecialist(.research)

        #expect(restored.selectedBrain == anthropic)
    }

    @Test func clearInputKeepsActiveSpecialistHarness() {
        let state = AgentCommandCenterState(userDefaults: Self.makeDefaults())
        state.applySpecialist(.review)
        state.inputText = "/review check this draft"

        state.clearInput()

        #expect(state.activeSpecialistPreset == .review)
        #expect(state.activeSlashToken == nil)
    }

    // MARK: - Build Command Request

    @Test func buildCommandRequest() {
        let state = AgentCommandCenterState()
        state.inputText = "what is Swift?"
        state.selectedOperatingMode = .fast
        state.toolToggles = ["a": true, "b": false]

        let request = state.buildCommandRequest()
        #expect(request.operatingMode == .fast)
        #expect(request.enabledToolNames == Set(["a"]))
        #expect(request.slashToken == nil)
    }

    // MARK: - Clear Input

    @Test func clearInput() {
        let state = AgentCommandCenterState()
        state.inputText = "hello"
        state.activeSlashToken = .builtinMode(.ask)
        state.activeMentions = [ACCContextMention(id: "1", token: "t", resolvedLabel: "l", mentionType: .agent)]
        state.suggestionMenuState = .slashMenu(filter: "a")

        state.clearInput()

        #expect(state.inputText == "")
        #expect(state.activeSlashToken == nil)
        #expect(state.activeMentions.isEmpty)
        #expect(state.suggestionMenuState == .hidden)
    }

    // MARK: - Context Providers

    @Test func refreshContextProviders() {
        let state = AgentCommandCenterState()
        state.refreshContextProviders(vaultNoteCount: 10, openNoteTitles: ["My Note", "Research"])

        #expect(state.contextProviders.count >= 7)
        #expect(state.contextProviders.contains { $0.token == "Safari" })
        #expect(state.contextProviders.contains { $0.token == "AllNotes" })
        #expect(state.contextProviders.contains { $0.token == "My Note" })
    }

    @Test func coreAppStoreContextProvidersHideExternalAgentMentions() {
        let state = AgentCommandCenterState(toolSurfaceDistribution: .coreAppStore)

        state.refreshContextProviders(vaultNoteCount: 10, openNoteTitles: ["My Note"])

        let tokens = Set(state.contextProviders.map(\.token))
        #expect(!tokens.contains("Safari"))
        #expect(!tokens.contains("Terminal"))
        #expect(!tokens.contains("Automation"))
        #expect(tokens.contains("Notes"))
        #expect(tokens.contains("Files"))
        #expect(tokens.contains("AllNotes"))
        #expect(tokens.contains("CurrentGraph"))
        #expect(tokens.contains("My Note"))
    }

    @Test func coreAppStoreManualExternalMentionDoesNotResolve() {
        let state = AgentCommandCenterState(toolSurfaceDistribution: .coreAppStore)
        state.refreshContextProviders(vaultNoteCount: 10, openNoteTitles: [])

        let result = CommandInputParser.parse(
            "@Terminal summarize this",
            contextProviders: state.contextProviders
        )

        #expect(result.mentions.isEmpty)
        #expect(result.cleanedQuery.contains("@Terminal"))
    }

    @Test func proResearchContextProvidersKeepExternalAgentMentions() {
        let state = AgentCommandCenterState(toolSurfaceDistribution: .proResearch)

        state.refreshContextProviders(vaultNoteCount: 10, openNoteTitles: [])

        let tokens = Set(state.contextProviders.map(\.token))
        #expect(tokens.contains("Safari"))
        #expect(tokens.contains("Terminal"))
        #expect(tokens.contains("Automation"))
        #expect(tokens.contains("Notes"))
        #expect(tokens.contains("Files"))
    }

    @Test func legacyAgentWorkspaceViewsAreRemovedFromRepo() {
        #expect(!Self.repoFileExists("Epistemos/Views/AgentChat/AgentChatView.swift"))
        #expect(!Self.repoFileExists("Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift"))
        #expect(!Self.repoFileExists("Epistemos/Views/AgentCommandCenter/AgentPlanEditorView.swift"))
        #expect(!Self.repoFileExists("Epistemos/Views/AgentCommandCenter/BrainPickerMenu.swift"))
        #expect(!Self.repoFileExists("Epistemos/Views/AgentCommandCenter/CommandBarView.swift"))
        #expect(!Self.repoFileExists("Epistemos/Views/AgentCommandCenter/InspectorPanelView.swift"))
        #expect(!Self.repoFileExists("Epistemos/Views/AgentCommandCenter/SuggestionPopoverView.swift"))
        #expect(!Self.repoFileExists("Epistemos/Views/AgentCommandCenter/ToolTogglePillsView.swift"))
    }

    @Test func fusedChatLeavesLegacyAgentSurfaceUnwiredFromRootView() throws {
        let rootSource = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")

        #expect(rootSource.contains("ContentRouter()"))
        #expect(!rootSource.contains("AgentChatView()"))
        #expect(!rootSource.contains(".overlay { agentCommandCenterOverlay }"))
        #expect(!rootSource.contains("if accState.isPresented"))
        #expect(!rootSource.contains("enum HomeSurfaceRoute"))
        #expect(!Self.repoFileExists("Epistemos/Views/AgentChat/AgentChatView.swift"))
    }

    // MARK: - Graph Chat Receiver

    @Test func handleGraphChatRequestPrefillsWithoutPresentingDeprecatedSurface() {
        let state = AgentCommandCenterState()
        #expect(!state.isPresented)

        let request = GraphChatRequest(
            graphNodeId: "node-1",
            sourceId: "page-1",
            nodeType: "note",
            nodeLabel: "Design Review",
            route: .canvas
        )
        state.handleGraphChatRequest(request)

        #expect(!state.isPresented)
        #expect(state.inputText == "Tell me about Design Review")
        #expect(state.pendingGraphChatRequest == request)
    }

    @Test func handleGraphChatRequestFallsBackToTypeWhenLabelEmpty() {
        let state = AgentCommandCenterState()

        let request = GraphChatRequest(
            graphNodeId: "node-2",
            sourceId: nil,
            nodeType: "idea",
            nodeLabel: "",
            route: .canvas
        )
        state.handleGraphChatRequest(request)

        #expect(state.inputText == "Tell me about idea")
    }

    @Test func handleGraphChatRequestDoesNotDismissAlreadyPresented() {
        let state = AgentCommandCenterState()
        state.present()
        state.inputText = "existing query"

        let request = GraphChatRequest(
            graphNodeId: "node-3",
            sourceId: nil,
            nodeType: "folder",
            nodeLabel: "Projects",
            route: .folder(id: "f1")
        )
        state.handleGraphChatRequest(request)

        #expect(state.isPresented)
        #expect(state.inputText == "Tell me about Projects")
        #expect(state.pendingGraphChatRequest?.route == .folder(id: "f1"))
    }

    @Test func graphChatObserverLifecycle() {
        let state = AgentCommandCenterState()
        state.startObservingGraphChatRequests()
        state.stopObservingGraphChatRequests()
        #expect(!state.isPresented)
    }

    @Test func graphChatObserverReceivesNotificationPayload() async {
        let state = AgentCommandCenterState()
        state.startObservingGraphChatRequests()
        defer { state.stopObservingGraphChatRequests() }

        let request = GraphChatRequest(
            graphNodeId: "node-4",
            sourceId: "page-4",
            nodeType: "note",
            nodeLabel: "Notification Node",
            route: .note(id: "page-4")
        )

        NotificationCenter.default.post(
            name: .graphChatRequested,
            object: nil,
            userInfo: [GraphChatRequest.userInfoKey: request]
        )
        await Task.yield()

        #expect(!state.isPresented)
        #expect(state.inputText == "Tell me about Notification Node")
        #expect(state.pendingGraphChatRequest == request)
    }

    @Test func buildCommandRequestForwardsGraphContext() {
        let state = AgentCommandCenterState()
        let request = GraphChatRequest(
            graphNodeId: "node-5",
            sourceId: "page-5",
            nodeType: "note",
            nodeLabel: "Architecture",
            route: .canvas
        )
        state.handleGraphChatRequest(request)

        let cmd = state.buildCommandRequest()
        #expect(cmd.graphContext == request)
        #expect(cmd.graphContext?.graphNodeId == "node-5")
        #expect(cmd.graphContext?.sourceId == "page-5")
        #expect(cmd.graphContext?.nodeType == "note")
    }

    @Test func buildCommandRequestNilGraphContextWhenNoGraphOrigin() {
        let state = AgentCommandCenterState()
        state.inputText = "plain chat"
        let cmd = state.buildCommandRequest()
        #expect(cmd.graphContext == nil)
    }

    @Test func clearInputResetsPendingGraphContext() {
        let state = AgentCommandCenterState()
        let request = GraphChatRequest(
            graphNodeId: "node-6",
            sourceId: nil,
            nodeType: "idea",
            nodeLabel: "Spark",
            route: .canvas
        )
        state.handleGraphChatRequest(request)
        #expect(state.pendingGraphChatRequest != nil)

        state.clearInput()
        #expect(state.pendingGraphChatRequest == nil)
        #expect(state.inputText.isEmpty)
    }

    @Test func duplicateObserverRegistrationDoesNotLeak() {
        let state = AgentCommandCenterState()
        state.startObservingGraphChatRequests()
        state.startObservingGraphChatRequests()
        state.stopObservingGraphChatRequests()
        #expect(!state.isPresented)
    }
}
