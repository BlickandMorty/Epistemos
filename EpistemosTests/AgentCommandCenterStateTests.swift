import Foundation
import Testing
@testable import Epistemos

@MainActor
struct AgentCommandCenterStateTests {
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
        let state = AgentCommandCenterState()
        #expect(state.presentationMode == .standard)
        #expect(state.selectedOperatingMode == .pro)
        #expect(state.nativeProviderEffort == .medium)
    }

    @Test func nativeProviderEffortStringsMatchRustBridgeContract() {
        #expect(ACCNativeProviderEffort.allCases.map(\.rustValue) == ["low", "medium", "high", "max"])
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

    @Test func refreshToolCatalogUsesCurrentOperatingMode() {
        let fastTools = [Self.makeTool(name: "vault_search")]
        let agentTools = [
            Self.makeTool(name: "vault_search"),
            Self.makeTool(name: "send_message"),
        ]
        let state = AgentCommandCenterState(toolCatalogLoader: { _, mode in
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
        let state = AgentCommandCenterState(toolCatalogLoader: { _, mode in
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
        state.toggleTool("vault_search")

        state.selectedOperatingMode = .agent

        #expect(state.availableTools.map(\.name) == ["vault_search", "send_message"])
        #expect(state.toolToggles["vault_search"] == false)
        #expect(state.toolToggles["send_message"] == true)
        #expect(state.toolToggles["web_search"] == nil)
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

    @Test func agentLandingKeepsRetroGreetingAndUsefulStats() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift")

        #expect(source.contains("Greetings,"))
        #expect(source.contains("AppDisplayTypography.font(size: 21, allowDisplayFont: true)"))
        #expect(source.contains("ACCLandingStatsTab"))
        #expect(source.contains("overviewStatsGrid"))
        #expect(source.contains("modelStatsChart"))
        #expect(source.contains("activityHeatmap"))
        #expect(source.contains("agentPersonaLabel"))
    }

    @Test func agentLandingPreservesTerminalSyntaxAndSafetyLanguage() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift")

        #expect(source.contains("rust:authority"))
        #expect(source.contains("trace:ready"))
        #expect(source.contains("permission:gated"))
        #expect(source.contains("-silentFallback"))
        #expect(source.contains("turnFailureCard"))
        #expect(source.contains("inlineDiffCard"))
    }

    @Test func agentSurfaceRoutesAsDedicatedHomePageInsteadOfOverlay() throws {
        let rootSource = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")

        #expect(rootSource.contains("enum HomeSurfaceRoute"))
        #expect(rootSource.contains("case agent"))
        #expect(rootSource.contains("if accState.isPresented"))
        #expect(rootSource.contains("AgentCommandCenterView()"))
        #expect(!rootSource.contains(".overlay { agentCommandCenterOverlay }"))
    }

    // MARK: - Graph Chat Receiver

    @Test func handleGraphChatRequestPresentsAndPrefills() {
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

        #expect(state.isPresented)
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

        #expect(state.isPresented)
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
