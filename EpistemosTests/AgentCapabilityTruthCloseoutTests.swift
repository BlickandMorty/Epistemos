import Foundation
import Testing
@testable import Epistemos

@Suite("Agent Capability Truth Closeout")
struct AgentCapabilityTruthCloseoutTests {
    @Test("RuntimeRouter derives honest, experimental, and off agent badges")
    func runtimeRouterDerivesAllAgentCapabilityStates() {
        let honest = RuntimeRouter.agentCapabilityBadgeData(
            forLocalModelID: LocalTextModelID.qwen3_8B4Bit.rawValue
        )
        #expect(honest.state == .honest)
        #expect(honest.title == "HONEST")
        #expect(honest.falsifier == "F-LocalToolUse")
        #expect(honest.witness.contains("RuntimeRouter"))

        let experimental = RuntimeRouter.agentCapabilityBadgeData(
            forLocalModelID: LocalTextModelID.devstralSmall2505_4Bit.rawValue
        )
        #expect(experimental.state == .experimental)
        #expect(experimental.title == "EXPERIMENTAL")
        #expect(experimental.falsifier == "F-LocalToolUse pending")

        let gemmaPreview = RuntimeRouter.agentCapabilityBadgeData(
            forLocalModelID: LocalTextModelID.gemma4_4B4Bit.rawValue
        )
        #expect(gemmaPreview.state == .off)
        #expect(gemmaPreview.title == "OFF")
        #expect(gemmaPreview.falsifier == "F-LocalToolUse unavailable")
        #expect(gemmaPreview.reason.contains("Swift MLX loader"))

        let off = RuntimeRouter.agentCapabilityBadgeData(
            forLocalModelID: LocalTextModelID.smolLM3_3B4Bit.rawValue
        )
        #expect(off.state == .off)
        #expect(off.title == "OFF")
        #expect(off.toolCallMode == .none)
    }

    @Test("model picker, Settings, Active Constellation, and AgentBlueprint surfaces expose capability truth")
    func visibleSurfacesExposeCapabilityTruth() throws {
        let rootView = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let activeConstellation = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ActiveConstellationRow.swift")
        let agentBlueprintView = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentBlueprintSettingsView.swift")
        let agentBlueprint = try loadMirroredSourceTextFile("Epistemos/LocalAgent/AgentBlueprint.swift")

        #expect(rootView.contains("localModelSubtitleWithAgentBadge(for: model)"))
        #expect(rootView.contains("Agent \\(badge.title)"))
        #expect(rootView.contains("gemmaQATRouteLaneRows(closeAction: closeAction)"))
        #expect(rootView.contains("GemmaQATRuntimeLadder.productRouteIntegrationCandidates"))
        #expect(rootView.contains("Gemma QAT GGUF route lanes"))
        #expect(rootView.contains("candidate.routeIntegrationStatusLabel"))
        #expect(rootView.contains("GemmaQATRuntimeLadder.productRouteIntegrationCursor"))
        #expect(settings.contains("localModelPickerLabel(for: descriptor.id)"))
        #expect(settings.contains("activeLocalAgentBadgeData.title"))
        #expect(activeConstellation.contains("model.agentCapabilityBadge.title"))
        #expect(activeConstellation.contains("LocalAgentDiagnostics.snapshot().routePolicySummary"))
        #expect(!activeConstellation.contains("placeholder routes"))
        #expect(!activeConstellation.contains("No production route table is available yet"))
        #expect(agentBlueprintView.contains("modelBadgeStrip(for: modelChoice)"))
        #expect(agentBlueprintView.contains("modelPickerRow("))
        #expect(agentBlueprint.contains("RuntimeRouter.agentCapabilityBadgeData(forLocalModelID: modelID)"))
        #expect(agentBlueprint.contains("strict_grammar: \\(model.strictGrammarStatus)"))

        guard
            let routeLaneRowsStart = rootView.range(
                of: "private func gemmaQATRouteLaneRows"
            )?.lowerBound,
            let routeLaneRowsEnd = rootView.range(
                of: "private var cloudProviderSelectionRows",
                range: routeLaneRowsStart..<rootView.endIndex
            )?.lowerBound
        else {
            Issue.record("Missing Gemma QAT route-lane status section")
            return
        }

        let routeLaneRows = String(rootView[routeLaneRowsStart..<routeLaneRowsEnd])
        #expect(routeLaneRows.contains("Open Diagnostics"))
        #expect(routeLaneRows.contains("openSettings()"))
        #expect(!routeLaneRows.contains("setPreferredChatModelSelection"))
    }

    @Test("main and mini chat composer pills expose selected route tool truth")
    func composerPillsExposeSelectedRouteToolTruth() throws {
        let mainComposer = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let miniComposer = try loadMirroredSourceTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let pill = try loadMirroredSourceTextFile("Epistemos/Views/Shared/ChatCapabilityPill.swift")
        let runtimeTruth = try loadMirroredSourceTextFile("Epistemos/Views/Settings/RuntimeTruthHealthRow.swift")

        #expect(mainComposer.contains("ComposerModelToolTruth.detail("))
        #expect(miniComposer.contains("ComposerModelToolTruth.detail("))
        #expect(runtimeTruth.contains("ComposerModelToolTruth.summary("))
        #expect(mainComposer.contains("inference.effectiveChatSurfaceSelection(for: selectedOperatingMode)"))
        #expect(miniComposer.contains("inference.effectiveChatSurfaceSelection(for: selectedOperatingMode)"))
        #expect(miniComposer.contains("detail: composerPillDetail"))
        #expect(pill.contains("enum ComposerModelToolTruth"))
        #expect(pill.contains("struct Summary: Sendable, Equatable"))
        #expect(pill.contains("static func summary("))
        #expect(pill.contains("RuntimeRouter.agentCapabilityBadgeData(forLocalModelID: modelID)"))
        #expect(pill.contains("provider.supportsAgentTier"))
        #expect(pill.contains("Cloud direct stream (managed tools unavailable)"))
        #expect(pill.contains("native tools"))
        #expect(pill.contains("soft-guidance tools"))
    }

    @Test("shared model tool truth gates cloud and local routes")
    func sharedModelToolTruthGatesCloudAndLocalRoutes() {
        let managedCloud = ComposerModelToolTruth.summary(
            for: .cloud(.openAIGPT54),
            capability: .agent,
            operatingMode: .agent
        )
        #expect(managedCloud.toolsAvailable)
        #expect(managedCloud.pillDetail == "managed tools")
        #expect(managedCloud.label == "Rust managed agent (cloud + tools)")

        let unsupportedCloud = ComposerModelToolTruth.summary(
            for: .cloud(.googleGemini25Pro),
            capability: .agent,
            operatingMode: .agent
        )
        #expect(!unsupportedCloud.toolsAvailable)
        #expect(unsupportedCloud.pillDetail == "no tools")
        #expect(unsupportedCloud.label == "Cloud direct stream (managed tools unavailable)")

        let nativeLocal = ComposerModelToolTruth.summary(
            for: .localMLX(LocalTextModelID.qwen3_8B4Bit.rawValue),
            capability: .agent,
            operatingMode: .agent
        )
        #expect(nativeLocal.toolsAvailable)
        #expect(nativeLocal.pillDetail == "native tools")
        #expect(nativeLocal.label == "Local agent loop (native tools)")

        let gatedGemma = ComposerModelToolTruth.summary(
            for: .localMLX(LocalTextModelID.gemma4_4B4Bit.rawValue),
            capability: .agent,
            operatingMode: .agent
        )
        #expect(!gatedGemma.toolsAvailable)
        #expect(gatedGemma.pillDetail == "no tools")
        #expect(gatedGemma.label == "Local agent unavailable")
        #expect(gatedGemma.detail.contains("Swift MLX loader"))
    }

    @Test("shared compatibility matrix covers current, local, cloud, provider-native, and skills")
    func sharedCompatibilityMatrixCoversActualRouteSet() throws {
        let rows = ComposerModelToolTruth.compatibilityRows(
            currentSelection: .cloud(.openAIGPT54),
            operatingMode: .agent,
            localModelIDs: [
                LocalTextModelID.qwen3_8B4Bit.rawValue,
                LocalTextModelID.gemma4_4B4Bit.rawValue,
            ],
            cloudModels: [
                .openAIGPT54,
                .googleGemini25Pro,
                .anthropicClaudeSonnet46,
            ],
            providerNativeToolNames: { selection in
                switch selection {
                case .cloud(.openAIGPT54):
                    ["web_search"]
                case .cloud(.googleGemini25Pro):
                    ["google_search"]
                case .cloud(.anthropicClaudeSonnet46):
                    ["code_execution", "web_fetch", "web_search"]
                case .appleIntelligence, .localMLX, .cloud:
                    []
                }
            },
            skillCount: 7
        )

        #expect(rows.count == 5)

        let current = try #require(rows.first { $0.selection == .cloud(.openAIGPT54) })
        #expect(current.isCurrent)
        #expect(current.summary.toolsAvailable)
        #expect(current.providerNativeToolNames == ["web_search"])
        #expect(current.skillStateLabel == "7 skills visible")

        let qwen = try #require(
            rows.first { $0.selection == .localMLX(LocalTextModelID.qwen3_8B4Bit.rawValue) }
        )
        #expect(qwen.summary.toolsAvailable)
        #expect(qwen.summary.label == "Local agent loop (native tools)")

        let gemma = try #require(
            rows.first { $0.selection == .localMLX(LocalTextModelID.gemma4_4B4Bit.rawValue) }
        )
        #expect(!gemma.summary.toolsAvailable)
        #expect(gemma.summary.detail.contains("Swift MLX loader"))
        #expect(gemma.appToolStateLabel == "inventory only")

        let google = try #require(rows.first { $0.selection == .cloud(.googleGemini25Pro) })
        #expect(!google.summary.toolsAvailable)
        #expect(google.providerNativeStateLabel == "1 provider-native")
        #expect(google.skillHandlingDetail.contains("slash/instruction context"))
    }

    @Test("landing and note ask pills expose effective route tool truth")
    func secondaryComposerPillsExposeEffectiveRouteToolTruth() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let noteWorkspace = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(landing.contains("private var landingPillDetail: String?"))
        #expect(landing.contains("detail: landingPillDetail"))
        #expect(landing.contains("ComposerModelToolTruth.detail("))
        #expect(landing.contains("inference.effectiveChatSurfaceSelection(for: selectedOperatingMode)"))
        #expect(!landing.contains("switch inference.preferredChatModelSelection"))

        #expect(noteWorkspace.contains("private var toolbarAskPillDetail: String?"))
        #expect(noteWorkspace.contains("detail: toolbarAskPillDetail"))
        #expect(noteWorkspace.contains("ComposerModelToolTruth.detail("))
        #expect(noteWorkspace.contains("inference.effectiveChatSurfaceSelection(for: selectedNoteChatOperatingMode)"))
    }

    @Test("local tool loop model handoff uses the effective route")
    func localToolLoopUsesEffectiveRouteModelIdentity() throws {
        let pipeline = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")

        #expect(pipeline.contains("case .localMLX(let id) = effectiveChatSelection"))
        #expect(!pipeline.contains("if case .localMLX(let id) = inference.preferredChatModelSelection"))
        #expect(!pipeline.contains("inference.preferredChatModelSelection"))
    }

    @Test("command center auto brain uses the effective route")
    func commandCenterAutoBrainUsesEffectiveRoute() throws {
        let coordinator = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")

        #expect(coordinator.contains("private func currentCommandCenterAutoBrain(operatingMode: EpistemosOperatingMode)"))
        #expect(coordinator.contains("self.currentCommandCenterAutoBrain(operatingMode: accState.selectedOperatingMode)"))
        #expect(coordinator.contains("switch inferenceState.effectiveChatSurfaceSelection(for: operatingMode)"))
        #expect(!coordinator.contains("switch inferenceState.preferredChatModelSelection"))
    }

    @Test("fused chat composers preserve typed slash skill tokens")
    func fusedComposersPreserveTypedSlashSkillTokens() throws {
        let mainComposer = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let miniComposer = try loadMirroredSourceTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let popover = try loadMirroredSourceTextFile("Epistemos/Views/Chat/SlashCommandPopover.swift")
        let chatState = try loadMirroredSourceTextFile("Epistemos/State/ChatState.swift")
        let coordinator = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")

        #expect(popover.contains("enum ComposerSlashCommandItem"))
        #expect(popover.contains("case skill(SkillDiscoveryEntry)"))
        #expect(popover.contains("static func filteredItems("))
        #expect(mainComposer.contains("@Environment(AgentCommandCenterState.self)"))
        #expect(miniComposer.contains("@Environment(AgentCommandCenterState.self)"))
        #expect(mainComposer.contains("agentCommandCenter.availableSkills"))
        #expect(miniComposer.contains("agentCommandCenter.availableSkills"))
        #expect(landing.contains("agentCommandCenter.availableSkills"))
        #expect(mainComposer.contains("chat.queuePendingSlashToken(activeSelectedSlashToken)"))
        #expect(miniComposer.contains("bridgeState.queuePendingSlashToken(requestedSlashToken)"))
        #expect(landing.contains("chat.queuePendingSlashToken(slashToken)"))
        #expect(chatState.contains("private var pendingSlashToken: ParsedSlashToken?"))
        #expect(coordinator.contains("let requestedSlashToken = chatState.consumePendingSlashToken()"))
        #expect(coordinator.contains("title: \"Requested Skill\""))
        #expect(coordinator.contains("do not claim the skill executed unless a tool or runtime explicitly reports execution"))
    }

    @Test("mini chat preserves main chat tool-route truth before shared coordinator handoff")
    func miniChatPreservesMainChatToolRouteTruth() throws {
        let miniComposer = try loadMirroredSourceTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(miniComposer.contains("private var cloudSurfaceSupportsAgentTier"))
        #expect(miniComposer.contains("model.provider.supportsAgentTier"))
        #expect(miniComposer.contains("private var needsSharedToolRouteWarning"))
        #expect(miniComposer.contains("draftCapabilityPrediction.predicted == .agent"))
        #expect(miniComposer.contains("draftCapabilityPrediction.predicted == .research"))
        #expect(miniComposer.contains("sharedToolRouteWarningBanner"))
        #expect(miniComposer.contains("inference.setActiveAIProvider(.openAI)"))
        #expect(miniComposer.contains("shouldUseSharedCoordinator("))
        #expect(miniComposer.contains("requestedSlashToken != nil"))
        #expect(miniComposer.contains("bootstrap.coordinator.handleMiniChatQuery("))
        #expect(miniComposer.contains("bridgeState.queuePendingSlashToken(requestedSlashToken)"))
        #expect(miniComposer.contains("HTMLWorkspacePatchRouter.contextPack(for: attachments)"))
        #expect(miniComposer.contains("providerNativeCapabilityToolNameList"))
    }

    @Test("capability manifest renders installed skill discovery without claiming execution")
    @MainActor
    func capabilityManifestRendersInstalledSkillTruth() throws {
        let manifest = CapabilityManifestBuilder.render(
            CapabilityManifestBuilder.Context(
                providerLabel: "local",
                modelLabel: "Test Model",
                operatingMode: .fast,
                reasoningTier: .medium,
                enabledToolNames: [],
                disabledToolNames: ["vault.write", "web.search"],
                vaultName: "Test Vault",
                vaultNoteCount: nil,
                skillNames: ["Note Read", "Code Review"],
                maxContextTokens: 4096
            )
        )

        #expect(manifest.contains("Installed skills visible in the slash picker: `Note Read`, `Code Review`."))
        #expect(manifest.contains("Skill names alone are discovery context"))
        #expect(manifest.contains("don't claim a skill body or skill execution"))
        #expect(manifest.contains("No tools are available on this turn."))
        #expect(manifest.contains("Tools intentionally unavailable on this turn: `vault.write`, `web.search`."))
        #expect(manifest.contains("Treat unavailable tools as absent; do not simulate, rename, or proxy them through another tool."))
    }

    @Test("capability manifest disabled tools canonicalize legacy aliases")
    func capabilityManifestDisabledToolsCanonicalizeAliases() {
        let disabled = CapabilityManifestBuilder.disabledToolNames(
            availableToolNames: ["web_search", "vault.write", "read_file"],
            enabledToolNames: ["web.search", "file.read"]
        )

        #expect(disabled == ["vault.write"])
    }

    @Test("main and direct chat manifests source installed skills from shared catalog")
    func chatCapabilityManifestsCarrySkillCatalogTruth() throws {
        let coordinator = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")
        let pipeline = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")
        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        let manifest = try loadMirroredSourceTextFile("Epistemos/Engine/CapabilityManifestBuilder.swift")

        #expect(manifest.contains("Installed skills visible in the slash picker"))
        #expect(manifest.contains("Skill names alone are discovery context"))
        #expect(manifest.contains("Tools intentionally unavailable on this turn"))
        #expect(manifest.contains("disabledToolNames("))
        #expect(coordinator.contains("manifestDisabledToolNames"))
        #expect(coordinator.contains("bootstrap.agentCommandCenterState.disabledToolNames("))
        #expect(pipeline.contains("disabledNames"))
        #expect(coordinator.contains("skillNames: bootstrap.agentCommandCenterState.availableSkills.map(\\.title).sorted()"))
        #expect(pipeline.contains("private let skillNamesProvider: @MainActor () -> [String]"))
        #expect(pipeline.contains("skillNames: skillNamesProvider()"))
        #expect(bootstrap.contains("skillNamesProvider: { [weak agentCommandCenterState]"))
        #expect(!coordinator.contains("skillNames: []"))
        #expect(!pipeline.contains("skillNames: []"))
    }

    @Test("AgentBlueprint surfaces MissionPacket tool omissions")
    func agentBlueprintSurfacesMissionPacketToolOmissions() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentBlueprintSettingsView.swift")

        #expect(source.contains("blueprintUnavailableToolNames"))
        #expect(source.contains("not in packet"))
        #expect(source.contains("Not sent to this MissionPacket"))
        #expect(source.contains("commandCenter.disabledToolNames(for: Array(selectedToolNames))"))
    }

    @Test("Agent Control surfaces route tool and skill compatibility")
    func agentControlSurfacesRouteToolAndSkillCompatibility() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentControlSettingsView.swift")

        #expect(source.contains("private var modelToolCompatibilityCard"))
        #expect(source.contains("Text(\"Route Compatibility\")"))
        #expect(source.contains("Text(\"Compatibility Matrix\")"))
        #expect(source.contains("private var modelToolCompatibilityRows"))
        #expect(source.contains("ComposerModelToolTruth.compatibilityRows("))
        #expect(source.contains("ComposerModelToolTruth.summary("))
        #expect(source.contains("inference.effectiveChatSurfaceSelection(for: agentControlOperatingMode)"))
        #expect(source.contains("inference.providerNativeCapabilityToolNameList(for: agentControlOperatingMode)"))
        #expect(source.contains("inference.releaseSelectableInstalledLocalTextModelIDs"))
        #expect(source.contains("CloudModelProvider.preferredOrder.map"))
        #expect(source.contains("inference.providerNativeCapabilityToolNameList(for: $0)"))
        #expect(source.contains("diagnosticDiscoveredSkills.count) skills"))
        #expect(source.contains("MCP tools below are inventory only for this route"))
    }

    @Test("chat MCP execution logs parse into Agent Control recent activity")
    @MainActor
    func chatMCPExecutionLogsParseIntoAgentControlRecentActivity() throws {
        let coordinator = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentControlSettingsView.swift")

        #expect(coordinator.contains("self.bootstrap.mcpBridge.logExecution("))
        #expect(source.contains("recentExecutions = MCPExecutionEntry.parse(from: mcpBridge.recentExecutionsJson(limit: 12))"))
        #expect(source.contains("ForEach(recentExecutions)"))

        let bridge = MCPBridge()
        let marker = "agent-control-recent-\(UUID().uuidString)"
        bridge.logExecution(
            toolName: "file.read",
            argumentsJson: #"{"path":"/tmp/\#(marker).txt"}"#,
            resultJson: #"{"ok":true}"#,
            durationMs: 17,
            success: true
        )

        let entries = MCPExecutionEntry.parse(from: bridge.recentExecutionsJson(limit: 50))
        let entry = try #require(entries.first { $0.argumentsPreview?.contains(marker) == true })

        #expect(entry.toolName == "file.read")
        #expect(entry.durationMs == 17)
        #expect(entry.success)
    }

    @Test("legacy AgentCommandCenter donor shell is not resurrected for capability truth")
    func legacyAgentCommandCenterShellStaysAbsent() {
        let repoRootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let legacyFiles = [
            "Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift",
            "Epistemos/Views/AgentCommandCenter/BrainPickerMenu.swift",
            "Epistemos/Views/AgentCommandCenter/CommandBarView.swift",
            "Epistemos/Views/AgentCommandCenter/InspectorPanelView.swift",
            "Epistemos/Views/AgentCommandCenter/SuggestionPopoverView.swift",
        ]

        for path in legacyFiles {
            #expect(!FileManager.default.fileExists(atPath: repoRootURL.appendingPathComponent(path).path))
        }
    }
}
