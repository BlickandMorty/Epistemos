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

        // 26B-A4B (MoE) still lacks a Swift loader (the native port is
        // dense-only), so it keeps the loader-unavailable OFF badge. The dense
        // E4B tier now loads and is covered separately below (no-witness OFF).
        let gemmaPreview = RuntimeRouter.agentCapabilityBadgeData(
            forLocalModelID: LocalTextModelID.gemma4_27BA4B4Bit.rawValue
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

    @Test("model picker, Settings, and Active Constellation surfaces expose capability truth")
    func visibleSurfacesExposeCapabilityTruth() throws {
        let rootView = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let activeConstellation = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ActiveConstellationRow.swift")

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
        // The MLX Gemma 4 enum row has no working Swift loader (mlx-swift-lm
        // doesn't decode `gemma4`), so the honest detail points the user at the
        // runnable GGUF lane instead of the old "no witness" message.
        #expect(gatedGemma.detail.contains("Swift MLX loader is unavailable"))
        #expect(gatedGemma.detail.contains("GGUF"))
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
        // The MLX Gemma 4 enum row has no working Swift loader, so the honest
        // detail points the user at the runnable GGUF lane.
        #expect(gemma.summary.detail.contains("Swift MLX loader is unavailable"))
        #expect(gemma.summary.detail.contains("GGUF"))
        #expect(gemma.appToolStateLabel == "inventory only")

        let google = try #require(rows.first { $0.selection == .cloud(.googleGemini25Pro) })
        #expect(!google.summary.toolsAvailable)
        #expect(google.providerNativeStateLabel == "1 provider-native")
        #expect(google.skillHandlingDetail.contains("slash/instruction context"))
    }

    @Test("landing pills expose effective route tool truth")
    func landingPillsExposeEffectiveRouteToolTruth() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(landing.contains("private var landingPillDetail: String?"))
        #expect(landing.contains("detail: landingPillDetail"))
        #expect(landing.contains("ComposerModelToolTruth.detail("))
        #expect(landing.contains("inference.effectiveChatSurfaceSelection(for: selectedOperatingMode)"))
        #expect(!landing.contains("switch inference.preferredChatModelSelection"))
    }

    @Test("local tool loop model handoff uses the effective route")
    func localToolLoopUsesEffectiveRouteModelIdentity() throws {
        let pipeline = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")

        #expect(pipeline.contains("case .localMLX(let id) = effectiveChatSelection"))
        #expect(!pipeline.contains("if case .localMLX(let id) = inference.preferredChatModelSelection"))
        #expect(!pipeline.contains("inference.preferredChatModelSelection"))
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
        #expect(manifest.contains("do not claim Epistemos generally lacks tools"))
        #expect(manifest.contains("Tools intentionally unavailable on this turn: `vault.write`, `web.search`."))
        #expect(manifest.contains("Treat unavailable tools as absent; do not simulate, rename, or proxy them through another tool."))
    }

    @Test("capability manifest invites agentic tool use only when tools exist")
    @MainActor
    func capabilityManifestInvitesAgenticToolUseWhenToolsPresent() throws {
        let withTools = CapabilityManifestBuilder.render(
            CapabilityManifestBuilder.Context(
                providerLabel: "Claude",
                modelLabel: "Test Model",
                operatingMode: .pro,
                reasoningTier: .medium,
                enabledToolNames: ["vault.search", "web.search"],
                disabledToolNames: [],
                vaultName: "Test Vault",
                vaultNoteCount: nil,
                skillNames: [],
                maxContextTokens: 4096
            )
        )
        // Positive agentic directive present — the "feels like Codex" half.
        #expect(withTools.contains("These are Epistemos tools for this turn."))
        #expect(withTools.contains("Some callable names may be generic or compatibility-prefixed"))
        #expect(withTools.contains("call it by the exact listed name"))
        #expect(withTools.contains("Do not tell the user you lack an Epistemos-specific tool"))
        #expect(withTools.contains("gather it with a tool before answering instead of guessing"))
        #expect(withTools.contains("keep going until the task is genuinely done rather than stopping after one call"))
        // Honesty rules still present (defensive half intact).
        #expect(withTools.contains("Don't claim capabilities you don't currently have"))

        let withoutTools = CapabilityManifestBuilder.render(
            CapabilityManifestBuilder.Context(
                providerLabel: "local",
                modelLabel: "Test Model",
                operatingMode: .fast,
                reasoningTier: .medium,
                enabledToolNames: [],
                disabledToolNames: ["vault.write"],
                vaultName: "Test Vault",
                vaultNoteCount: nil,
                skillNames: [],
                maxContextTokens: 4096
            )
        )
        // No tools → no agentic invitation, and the plain-text rule still holds.
        #expect(!withoutTools.contains("gather it with a tool before answering"))
        #expect(withoutTools.contains("No tools are available on this turn."))
        #expect(withoutTools.contains("do not claim Epistemos generally lacks tools"))
    }

    @Test("capability manifest disabled tools canonicalize legacy aliases")
    func capabilityManifestDisabledToolsCanonicalizeAliases() {
        let disabled = CapabilityManifestBuilder.disabledToolNames(
            availableToolNames: ["web_search", "vault.write", "read_file"],
            enabledToolNames: ["web.search", "file.read"]
        )

        #expect(disabled == ["vault.write"])
    }

    @Test("capability manifests source installed skills from shared catalog")
    func capabilityManifestsCarrySkillCatalogTruth() throws {
        let pipeline = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")
        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        let manifest = try loadMirroredSourceTextFile("Epistemos/Engine/CapabilityManifestBuilder.swift")

        #expect(manifest.contains("Installed skills visible in the slash picker"))
        #expect(manifest.contains("Skill names alone are discovery context"))
        #expect(manifest.contains("Tools intentionally unavailable on this turn"))
        #expect(manifest.contains("disabledToolNames("))
        #expect(pipeline.contains("disabledNames"))
        #expect(pipeline.contains("private let skillNamesProvider: @MainActor () -> [String]"))
        #expect(pipeline.contains("skillNames: skillNamesProvider()"))
        #expect(bootstrap.contains("skillNamesProvider: { [weak agentCommandCenterState]"))
        #expect(!pipeline.contains("skillNames: []"))
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
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentControlSettingsView.swift")

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
