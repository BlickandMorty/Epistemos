import Foundation
import Testing

/// Act currently rides the Epistemos-skinned AgentClone surface. The deleted
/// Osaurus bridge names must not return; Act prompts should enter AgentClone
/// through the app-owned `AgentCloneBridge`.
@Suite("Act surface = direct AgentClone foundation with Epistemos foreground")
struct ActSurfaceOsaurusUIDirectionGuardTests {

    @Test("RootView mounts the AgentClone host and Landing submits Act prompts to the live AgentClone runner")
    func rootViewRoutesThroughAgentCloneBridge() throws {
        let app = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        let host = try loadMirroredSourceTextFile("Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift")
        let snapshot = try loadMirroredSourceTextFile("Epistemos/Views/AgentFusion/AgentCloneAppContextSnapshot.swift")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let workspaceModeSelection = try loadMirroredSourceTextFile("Epistemos/Views/Landing/WorkspaceModeSelection.swift")
        let agentContent = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift")
        let agentBridge = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/EpistemosAgentBridge.swift")
        let agentHostContext = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/HostContext.swift")
        let sessionStore = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/Services/SessionStore.swift")
        let taskUtilities = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/TaskUtilities/TaskUtilities.swift")
        let taskExecution = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/TaskExecution/TaskExecution.swift")
        let tabLLMServices = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/TabTask/LLMServices.swift")

        #expect(!app.contains("submitActOsaurusPrompt"))
        #expect(!app.contains("openActOsaurusSession"))
        #expect(!app.contains("showActOsaurusSettings"))
        #expect(!app.contains("ActOsaurusPromptRequest"))

        #expect(root.contains("import AgentClone"))
        #expect(root.contains("AgentClone.AgentSkin.configure("))
        #expect(root.contains("AgentCloneChatHostSurface("))
        #expect(root.contains("private var agentCloneContextSnapshot: AgentCloneAppContextSnapshot"))
        #expect(root.contains("AgentCloneAppContextSnapshot("))
        #expect(root.contains("context: agentCloneContextSnapshot"))
        #expect(root.contains("onSyncHostContext: syncAgentCloneHostContext"))
        #expect(snapshot.contains("struct AgentCloneAppContextSnapshot: Codable, Equatable, Sendable"))
        #expect(snapshot.contains("var appName: String"))
        #expect(snapshot.contains("var workspacePath: String?"))
        #expect(snapshot.contains("var vaultPath: String?"))
        #expect(snapshot.contains("var appSupportPath: String?"))
        #expect(snapshot.contains("var modeLabel: String"))
        #expect(snapshot.contains("var presentation: String"))
        #expect(snapshot.contains("var modelVisibleSummary: String"))
        #expect(snapshot.contains("var modelVisibleJSON: String"))
        #expect(snapshot.contains("private struct ModelVisiblePayload: Codable, Equatable, Sendable"))
        #expect(snapshot.contains("encoder.outputFormatting = [.sortedKeys]"))
        #expect(!snapshot.contains("appSupportPath: appSupportPath"))
        #expect(snapshot.contains(#"presentation: String = "main""#))
        #expect(snapshot.contains(#"Self.normalized(appName) ?? "Epistemos""#))
        #expect(snapshot.contains(#"Self.normalized(modeLabel) ?? "Act""#))
        #expect(host.contains("let context: AgentCloneAppContextSnapshot"))
        #expect(host.contains("AgentClone.ContentView()"))
        #expect(host.contains("context.appName"))
        #expect(host.contains("context.modeLabel"))
        #expect(host.contains("context.presentation"))
        #expect(host.contains("context.modelVisibleSummary"))
        #expect(host.contains("context.vaultPath"))
        #expect(host.contains("context.workspacePath"))
        #expect(host.contains("Text(context.appName)"))
        #expect(host.contains("AgentFusionRailRow(title: \"Runtime\", detail: \"native agent\""))
        #expect(!host.contains("AgentClone foundation"))
        #expect(!host.contains("AgentClone bridge"))
        #expect(host.contains(".onAppear {\n            onSyncHostContext()"))
        #expect(host.contains("@State private var showCompactSessionRail = false"))
        #expect(host.contains("@State private var showCompactContextRail = false"))
        #expect(host.contains("if showSessionRail, !compact"))
        #expect(host.contains("if showContextRail, !compact"))
        #expect(host.contains("railControlButtons(compact: compact)"))
        #expect(host.contains("compact && showCompactSessionRail"))
        #expect(host.contains("compact && showCompactContextRail"))
        #expect(root.contains("WorkspaceModeToggle(mode: $workspaceMode)"))
        #expect(root.contains("WorkTerminalHostView("))
        #expect(root.contains("workspace: Self.workWorkspaceURL"))
        #expect(root.contains("epistemosVaultRoot: vaultSync.vaultURL"))
        #expect(root.contains("AgentCloneBridge.updateHostContext("))
        #expect(root.contains("AgentCloneHostContext("))
        #expect(root.contains("let snapshot = agentCloneContextSnapshot"))
        #expect(root.contains("workspacePath: Self.workWorkspaceURL.path"))
        #expect(root.contains("vaultPath: vaultSync.vaultURL?.path"))
        #expect(root.contains("private static var agentCloneSupportURL"))
        #expect(root.contains("AgentCloneAppContextSnapshot.defaultAppSupportPath("))
        #expect(root.contains("appSupportPath: Self.agentCloneSupportURL.path"))
        #expect(root.contains("modeLabel: workspaceMode.defaultLabel"))
        #expect(root.contains("workspaceRootPath: snapshot.workspacePath"))
        #expect(root.contains("vaultRootPath: snapshot.vaultPath"))
        #expect(root.contains("appSupportRootPath: snapshot.appSupportPath"))
        #expect(root.contains("mode: snapshot.modeLabel"))
        #expect(root.contains("presentation: snapshot.bridgePresentation"))
        #expect(root.contains("guard workspaceMode != .work else { return }"))
        #expect(root.contains("WorkspaceModeSelection.didSelectNotification"))
        #expect(root.contains("WorkspaceModeSelection.selectedModeUserInfoKey"))
        #expect(root.contains("workspaceMode = candidate"))
        #expect(root.contains("if candidate != .work {\n                syncAgentCloneHostContext()"))
        #expect(!root.contains(".submitActOsaurusPrompt"))
        #expect(!root.contains(".openActOsaurusSession"))
        #expect(!root.contains(".showActOsaurusSettings"))
        #expect(root.contains("agentChat.openPortalContext(portalContext)"))
        #expect(!root.contains("agentClonePromptText(for: request, prompt: prompt)"))
        #expect(!root.contains("ActOsaurusPromptRequest"))

        #expect(landing.contains("@Environment(AgentChatState.self)"))
        #expect(landing.contains("import AgentClone"))
        #expect(landing.contains("WorkspaceModeSelection.select(.act)"))
        #expect(landing.contains("AgentPortalContextSnapshot.landing("))
        #expect(landing.contains("agentChat.startNewSession(portalContext: portalContext)"))
        #expect(landing.contains("agentChat.submitAgentQuery(trimmed, portalContext: portalContext)"))
        #expect(landing.contains("AgentCloneBridge.updateHostContext(AgentCloneHostContext("))
        #expect(landing.contains("AgentCloneBridge.submitPrompt(portalContext.agentClonePromptEnvelope(userPrompt: trimmed))"))
        #expect(!landing.contains("if isActSearchPage {\n            AgentCloneBridge.submitPrompt(trimmed)"))
        #expect(!landing.contains("submitActOsaurusPrompt"))
        #expect(!landing.contains("ActOsaurusPromptRequest"))

        #expect(workspaceModeSelection.contains("didSelectNotification"))
        #expect(workspaceModeSelection.contains("selectedModeUserInfoKey"))
        #expect(workspaceModeSelection.contains(#"Notification.Name("epistemos.workspace.mode.didSelect")"#))
        #expect(workspaceModeSelection.contains("NotificationCenter.default.post("))
        #expect(workspaceModeSelection.contains("object: defaults"))
        #expect(workspaceModeSelection.contains("userInfo: [selectedModeUserInfoKey: mode.rawValue]"))

        #expect(agentBridge.contains("public enum AgentCloneBridge"))
        #expect(agentBridge.contains("public struct AgentCloneHostContext"))
        #expect(agentBridge.contains("public var appSupportRootPath: String?"))
        #expect(agentBridge.contains("public var presentation: String?"))
        #expect(agentBridge.contains("submitPromptNotification"))
        #expect(agentBridge.contains("hostContextNotification"))
        #expect(agentBridge.contains("promptUserInfoKey"))
        #expect(agentBridge.contains("promptIDUserInfoKey"))
        #expect(agentBridge.contains("hostContextUserInfoKey"))
        #expect(agentBridge.contains("currentHostContext"))
        #expect(agentBridge.contains("AgentClonePendingPrompt"))
        #expect(agentBridge.contains("AgentClonePendingPromptStore"))
        #expect(agentBridge.contains("pendingPromptStore"))
        #expect(agentBridge.contains("@discardableResult"))
        #expect(agentBridge.contains("public static func submitPrompt(_ prompt: String) -> UUID"))
        #expect(agentBridge.contains("markPromptConsumed(id: UUID)"))
        #expect(agentBridge.contains("drainPendingPrompts() -> [AgentClonePendingPrompt]"))
        #expect(agentBridge.contains("updateHostContext(_ context: AgentCloneHostContext)"))
        #expect(agentBridge.contains(#"parts.append("vault: \(vaultRootPath)")"#))
        #expect(agentBridge.contains(#"parts.append("workspace: \(workspaceRootPath)")"#))
        #expect(agentBridge.contains(#"parts.append("surface: \(presentation)")"#))
        #expect(agentBridge.contains("vaultRootPath ?? workspaceRootPath"))
        #expect(!agentBridge.contains("} else if let workspaceRootPath {"))
        #expect(agentBridge.contains("Notification.Name(\"epistemos.agentclone.submitPrompt\")"))
        #expect(agentBridge.contains("Notification.Name(\"epistemos.agentclone.hostContext\")"))
        #expect(agentContent.contains("AgentCloneBridge.submitPromptNotification"))
        #expect(agentContent.contains("AgentCloneBridge.hostContextNotification"))
        #expect(agentContent.contains("private func submitBridgePrompt"))
        #expect(agentContent.contains("drainPendingBridgePrompts()"))
        #expect(agentContent.contains("AgentCloneBridge.markPromptConsumed(id: promptID)"))
        #expect(agentContent.contains("AgentCloneBridge.drainPendingPrompts()"))
        #expect(agentContent.contains("submitBridgePromptText(pendingPrompt.text)"))
        #expect(agentContent.contains("private func applyBridgeHostContext"))
        #expect(agentContent.contains("private func applyCurrentHostContext"))
        #expect(agentContent.contains("applyCurrentHostContext()\n            drainPendingBridgePrompts()"))
        #expect(agentContent.contains("viewModel.applyEpistemosHostContext(context)"))
        #expect(agentContent.contains("EpistemosHostContextRow(summary: viewModel.epistemosHostContextSummary)"))
        #expect(agentContent.contains("Text(\"Epistemos context\")"))
        #expect(agentContent.contains("viewModel.run()"))
        #expect(agentContent.contains("viewModel.runTabTask(tab: tab)"))
        #expect(!agentContent.contains("if !tab.isLLMRunning {\n                viewModel.runTabTask(tab: tab)"))
        #expect(!agentContent.contains("if !viewModel.isRunning {\n            viewModel.run()"))
        #expect(agentHostContext.contains("func applyEpistemosHostContext(_ context: AgentCloneHostContext)"))
        #expect(agentHostContext.contains("epistemosHostContextSummary = context.summary"))
        #expect(agentHostContext.contains("SessionStore.shared.applyEpistemosHostContext(context)"))
        #expect(agentHostContext.contains("context.preferredProjectFolder"))
        #expect(agentHostContext.contains("epistemos.agentclone.lastAppliedHostProjectFolder"))
        #expect(agentHostContext.contains("currentFolder == lastHostFolder"))
        #expect(agentHostContext.contains("RecentFoldersService.shared.addFolder(resolvedFolder)"))
        #expect(sessionStore.contains("func applyEpistemosHostContext(_ context: AgentCloneHostContext)"))
        #expect(sessionStore.contains("context.appSupportRootPath"))
        #expect(sessionStore.contains(#"appendingPathComponent("sessions", isDirectory: true)"#))
        #expect(sessionStore.contains("legacySessionsDir"))
        #expect(sessionStore.contains(#"Documents/AgentScript/sessions"#))
        #expect(sessionStore.contains("importLegacySessionsIfNeeded()"))
        #expect(sessionStore.contains("migrateSessionIfNeeded(from: url)"))
        #expect(taskUtilities.contains("hostContextSummary: String = \"\""))
        #expect(taskUtilities.contains("[Epistemos context: \\(trimmedHostContext)]"))
        #expect(taskExecution.contains("hostContextSummary: epistemosHostContextSummary"))
        #expect(tabLLMServices.contains("hostContextSummary: epistemosHostContextSummary"))

        #expect(!root.contains("import OsaurusCore"))
        #expect(!root.contains("ChatRouteView()"))
        #expect(!root.contains("ChatView("))
        #expect(!root.contains("MiniChat"))
        #expect(!root.contains("EpistemosOsaurusChatHost("))
        #expect(!root.contains("ActEpistemosChatSurface("))
        #expect(!root.contains("NativeActChatView("))
        #expect(!root.contains("NativeActLandingView("))
    }

    @Test("Act entrypoints use direct AgentClone route without Osaurus notification bridge")
    func actEntrypointsPostIntoBridge() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let graph = try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        let app = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")

        #expect(landing.contains("private var isActSearchPage: Bool"))
        #expect(landing.contains("Ask Act..."))
        #expect(landing.contains("AgentPortalContextSnapshot.landing("))
        #expect(landing.contains("agentChat.submitAgentQuery(trimmed, portalContext: portalContext)"))
        #expect(landing.contains("AgentCloneBridge.submitPrompt(portalContext.agentClonePromptEnvelope(userPrompt: trimmed))"))
        #expect(!landing.contains("if isActSearchPage {\n            AgentCloneBridge.submitPrompt(trimmed)"))
        #expect(!landing.contains("submitActOsaurusPrompt"))
        #expect(!landing.contains("ActOsaurusPromptRequest"))
        #expect(!landing.contains("showActOsaurusSettings"))

        #expect(graph.contains("old graph-chat"))
        #expect(graph.contains("chat submission path"))
        #expect(!graph.contains("name: .submitActOsaurusPrompt"))

        #expect(!app.contains("showActOsaurusSettings"))
        #expect(!root.contains("handleActPromptNotification"))
        #expect(!root.contains("openActSettingsFallback"))
        #expect(root.contains("agentChat.openPortalContext(portalContext)"))
        #expect(!root.contains("AgentCloneBridge.submitPrompt(bridgedPrompt)"))
        #expect(!root.contains("Context attachments:"))
        #expect(!root.contains("File attachments:"))
    }

    @Test("AgentChatState keeps streaming support without restoring deleted chat state")
    func agentChatStateKeepsStreamingSupportWithoutRestoringDeletedChatState() throws {
        let support = try loadMirroredSourceTextFile("Epistemos/State/AgentStreamingSupport.swift")
        let agentChatState = try loadMirroredSourceTextFile("Epistemos/State/AgentChatState.swift")

        #expect(support.contains("enum StreamingReasoningTraceBuffer"))
        #expect(support.contains("static let postAnswerDisplaySeparator"))
        #expect(support.contains("final class DisplayPacedTextBuffer"))
        #expect(support.contains("func reset(releaseCapacity: Bool = false)"))
        #expect(agentChatState.contains("private lazy var streamBuffer = DisplayPacedTextBuffer"))
        #expect(agentChatState.contains("StreamingReasoningTraceBuffer.append("))
        #expect(!agentChatState.contains("ChatCoordinator.inferAuthorship"))
        #expect(try !mirroredSourcePathExists("Epistemos/State/ChatState.swift"))
        #expect(try !mirroredSourcePathExists("Epistemos/State/NoteChatState.swift"))
        #expect(try !mirroredSourcePathExists("Epistemos/State/DialogueChatState.swift"))
    }

    @Test("Old native chat portal surfaces stay deleted")
    func oldNativeChatPortalSurfacesStayDeleted() throws {
        let deletedSourcePaths = [
            "Epistemos/App/ChatCoordinator.swift",
            "Epistemos/App/ChatCoordinator+EidosCitationGate.swift",
            "Epistemos/State/ChatState.swift",
            "Epistemos/State/DialogueChatState.swift",
            "Epistemos/State/NoteChatState.swift",
            "Epistemos/Views/Chat/ChatView.swift",
            "Epistemos/Views/Chat/ChatInputBar.swift",
            "Epistemos/Views/Chat/ChatSidebarView.swift",
            "Epistemos/Views/MiniChat/MiniChatView.swift",
            "Epistemos/Views/MiniChat/MiniChatWindowController.swift",
            "Epistemos/Graph/Workspace/GraphChatRequest.swift",
            "Epistemos/Views/Notes/CodeAskBar.swift",
            "Epistemos/Views/Notes/NoteChatSidebar.swift",
            "Epistemos/ActOsaurus/ActOsaurusBridge.swift",
            "Epistemos/Vendor/Osaurus/OsaurusChatMessage.swift",
            "Epistemos/LocalAgent/AgentBlueprint.swift",
            "Epistemos/SystemG/SystemGWiring.swift",
        ]

        for relativePath in deletedSourcePaths {
            #expect(try !mirroredSourcePathExists(relativePath), "\(relativePath) should stay deleted")
        }

        let portalContext = try loadMirroredSourceTextFile("Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift")
        #expect(portalContext.contains("enum Portal: String, Codable, CaseIterable, Sendable"))
        #expect(portalContext.contains("case main"))
        #expect(portalContext.contains("case landing"))
        #expect(portalContext.contains("case mini"))
        #expect(portalContext.contains("case note"))
        #expect(portalContext.contains("case graph"))
        #expect(portalContext.contains("case vault"))
        #expect(portalContext.contains("var contextAttachments: [ContextAttachment]"))

        let routedSourcePaths = [
            "Epistemos/App/EpistemosApp.swift",
            "Epistemos/App/RootView.swift",
            "Epistemos/App/AppBootstrap.swift",
            "Epistemos/App/AppCoordinator.swift",
            "Epistemos/App/AppEnvironment.swift",
            "Epistemos/Views/Landing/LandingView.swift",
            "Epistemos/Views/Graph/HologramSearchSidebar.swift",
            "Epistemos/Views/Graph/GraphWorkspaceContainer.swift",
            "Epistemos/Views/Notes/NoteDetailWorkspaceView.swift",
            "Epistemos/Views/Notes/NoteWindowManager.swift",
            "Epistemos/Views/Notes/NotesSidebar.swift",
            "Epistemos/Views/Settings/SettingsView.swift",
            "Epistemos.xcodeproj/project.pbxproj",
        ]
        let forbiddenRouteTokens = [
            "ChatRouteView",
            "ChatCoordinator",
            "let chatState = ChatState",
            "@Environment(ChatState.self)",
            "DialogueChatState",
            "NoteChatState",
            "ChatView(",
            "MiniChatView",
            "MiniChatWindowController",
            "GraphChatRequest",
            "NoteChatSidebar",
            "CodeAskBar",
            "ActOsaurus",
            "EpistemosOsaurus",
            "AgentBlueprint",
            "SystemGRunSeam",
            "RealSystemGRunSeam",
            "SystemGWiring",
        ]

        for relativePath in routedSourcePaths {
            let source = try loadMirroredSourceTextFile(relativePath)
            for token in forbiddenRouteTokens {
                #expect(!source.contains(token), "\(relativePath) still references \(token)")
            }
        }
    }

    @Test("Embedded AgentClone foreground copy is Epistemos-neutral")
    func embeddedAgentCloneForegroundCopyIsEpistemosNeutral() throws {
        let content = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift")
        let services = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/Views/Header/ServicesPopover.swift")
        let header = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/Views/Header/HeaderSectionView.swift")
        let colors = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/Colors.swift")
        let viewModel = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/AgentViewModel.swift")
        let skin = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/EpistemosReskin.swift")
        let initSource = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/Init.swift")
        let runStop = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/RunStop.swift")

        #expect(content.contains("alert.messageText = \"Epistemos Question\""))
        #expect(content.contains(".overlay(alignment: .leading)"))
        #expect(content.contains(".transition(.move(edge: .leading).combined(with: .opacity))"))
        #expect(content.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)"))
        #expect(content.contains("sidebar.left"))
        #expect(!content.contains("sidebar.right"))
        #expect(services.contains("Background services for shell commands and automation."))
        #expect(services.contains("Text(\"User Helper\")"))
        #expect(services.contains("Text(\"Privileged Helper\")"))
        #expect(header.contains(".help(\"User helper:"))
        #expect(header.contains(".accessibilityLabel(\"User helper\")"))
        #expect(header.contains(".help(\"Privileged helper:"))
        #expect(header.contains(".accessibilityLabel(\"Privileged helper\")"))
        #expect(colors.contains("Background services - user:"))
        #expect(viewModel.contains("User service shut down. Re-enable: Connect"))
        #expect(skin.contains("embedded agent UI"))
        #expect(initSource.contains("Advanced helpers unavailable — Epistemos runs in-process."))
        #expect(runStop.contains("Advanced helpers unavailable — Epistemos runs in-process."))

        for source in [content, services, header, colors, viewModel, skin, initSource, runStop] {
            #expect(!source.contains("Agent Question"))
            #expect(!source.contains("Agent!'s"))
            #expect(!source.contains("Text(\"User Agent\")"))
            #expect(!source.contains("Text(\"Daemon Agent\")"))
            #expect(!source.contains("Text(\"Daemon\")"))
            #expect(!source.contains("Text(\"Daemon Service\")"))
            #expect(!source.contains("Background Agents"))
            #expect(!source.contains("Background agent: unavailable"))
        }
    }

    @Test("Embedded AgentClone foreground directories hide donor app names")
    func embeddedAgentCloneForegroundDirectoriesHideDonorNames() throws {
        let foregroundDirectories = [
            "LocalPackages/AgentClone/Sources/AgentClone/Views",
            "LocalPackages/AgentClone/Sources/AgentClone/DependencyChecker",
        ]
        let foregroundFiles = try foregroundDirectories.flatMap {
            try mirroredSourceFileURLs(under: $0, includingExtensions: ["swift"])
        } + [
            try sourceMirrorURL(for: "LocalPackages/AgentClone/Sources/AgentClone/AgentApp.swift")
        ]

        #expect(!foregroundFiles.isEmpty)

        let forbiddenForegroundLiteralPattern =
            #""(?:[^"\\\n]|\\.)*(Agent!|AgentClone|Agent Question|User Agent|Background Agents|Daemon|OpenCode|Goose|Osaurus)(?:[^"\\\n]|\\.)*""#
        for fileURL in foregroundFiles {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            #expect(
                source.range(of: forbiddenForegroundLiteralPattern, options: .regularExpression) == nil,
                "\(fileURL.path) has a donor/runtime name in a quoted foreground literal"
            )
        }
    }

    @Test("Embedded AgentClone help resources use Epistemos foreground names")
    func embeddedAgentCloneHelpResourcesUseEpistemosForegroundNames() throws {
        let helpFiles = try mirroredSourceFileURLs(
            under: "LocalPackages/AgentClone/Sources/AgentClone/Resources/Agent.help/Contents/Resources/en.lproj",
            includingExtensions: ["html"]
        )
        #expect(!helpFiles.isEmpty)

        let forbiddenHelpText = [
            "Agent!",
            "Agent Help",
            "Agent Scripts",
            "Privileged Daemon",
            "Settings → Daemon",
            "Launch Daemon",
            "User Agent",
            "Background Agents",
            "Agent Question",
            "OpenCode",
            "Goose",
            "Osaurus",
        ]
        for fileURL in helpFiles {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for token in forbiddenHelpText {
                #expect(!source.contains(token), "\(fileURL.path) contains stale help token \(token)")
            }
        }
    }

    @Test("Foreground Act chrome hides donor names while protected contracts stay named")
    func foregroundActChromeHidesDonorNamesWithoutRenamingContracts() throws {
        let foregroundSources = [
            try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift"),
            try loadMirroredSourceTextFile("Epistemos/App/RootView.swift"),
            try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift"),
            try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift"),
            try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift"),
        ]

        let foregroundPatterns = [
            #"Text\(\s*"[^"]*Osaurus"#,
            #"Text\(\s*verbatim:\s*"[^"]*Osaurus"#,
            #"Button\(\s*"[^"]*Osaurus"#,
            #"Label\(\s*"[^"]*Osaurus"#,
            #"LabeledContent\(\s*"[^"]*Osaurus"#,
            #"Picker\(\s*"[^"]*Osaurus"#,
            #"Toggle\(\s*"[^"]*Osaurus"#,
            #"ProgressView\(\s*"[^"]*Osaurus"#,
            #"SettingsDescriptionText\([\s\S]*?text:\s*"[^"]*Osaurus"#,
            #"headline:\s*"[^"]*Osaurus"#,
            #"detail:\s*"[^"]*Osaurus"#,
            #"routeLabel:\s*"[^"]*Osaurus"#,
            #"routeSummary:\s*"[^"]*Osaurus"#,
            #"providerLabel:\s*"[^"]*Osaurus"#,
            #"content:\s*"[^"]*Osaurus"#,
            #"message:\s*"[^"]*Osaurus"#,
            #"reason:\s*"[^"]*Osaurus"#,
            #"return\s*"[^"]*Osaurus"#,
            #"ActOsaurusError\.transport\("[^"]*Osaurus"#,
            #"\.help\(\s*"[^"]*Osaurus"#,
            #"\.accessibilityLabel\(\s*"[^"]*Osaurus"#,
            #"\.navigationTitle\(\s*"[^"]*Osaurus"#,
        ]
        for source in foregroundSources {
            for pattern in foregroundPatterns {
                #expect(source.range(of: pattern, options: .regularExpression) == nil)
            }
        }

        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let app = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")

        #expect(!settings.contains(#"case actClone = "Act (Osaurus)""#))
        #expect(!settings.contains(#"case actClone = "Epistemos Act""#))
        #expect(!app.contains("showActOsaurusSettings"))
        #expect(!root.contains(".submitActOsaurusPrompt"))
        #expect(!root.contains(".showActOsaurusSettings"))
        #expect(!root.contains("ActOsaurusPromptRequest"))
    }

    @Test("Protected AgentClone runtime contracts stay donor-compatible")
    func protectedAgentCloneRuntimeContractsStayDonorCompatible() throws {
        let systemPrompt = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/Services/SystemPromptService.swift")
        let keychain = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/Services/KeychainService.swift")
        let scriptService = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/Services/ScriptService.swift")
        let sessionStore = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/Services/SessionStore.swift")
        let scriptExecution = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/Services/ScriptService+Execution.swift")
        let shellSafety = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/Services/ShellSafetyService.swift")
        let helperService = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/Services/HelperService.swift")
        let viewModel = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/AgentViewModel.swift")
        let setup = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/TaskExecution/Setup.swift")
        let bridge = try loadMirroredSourceTextFile("LocalPackages/AgentClone/Sources/AgentClone/EpistemosAgentBridge.swift")

        #expect(systemPrompt.contains(#"private static let versionPrefix = "// Agent! v""#))
        #expect(systemPrompt.contains(#"private static let customPrefix = "// Agent! custom v""#))
        #expect(systemPrompt.contains(#"private static let readOnlyPrefix = "// Agent! READ ONLY v""#))
        #expect(systemPrompt.contains(#"Documents/AgentScript/system"#))

        #expect(keychain.contains(#"kSecAttrService as String: "Agent!""#))
        #expect(keychain.contains(#"private static let claudeAPIKey = "agent.claudeAPIKey""#))
        #expect(keychain.contains(#"private static let openRouterAPIKey = "com.agent.openrouter-api-key""#))

        #expect(scriptService.contains(#"https://github.com/macOS26/AgentScripts.git"#))
        #expect(scriptService.contains(#"Documents/AgentScript/agents"#))
        #expect(sessionStore.contains(#"Documents/AgentScript/sessions"#))
        #expect(sessionStore.contains("legacySessionsDir"))
        #expect(sessionStore.contains("appSupportRootPath"))
        #expect(scriptExecution.contains(#"env["AGENT_PROJECT_FOLDER"] = cwdPath"#))
        #expect(viewModel.contains(#"forKey: "agentProjectFolder""#))

        #expect(shellSafety.contains("case rootDaemon"))
        #expect(helperService.contains("enum SafeSMAppServiceDaemon"))
        #expect(bridge.contains(#"Notification.Name("epistemos.agentclone.submitPrompt")"#))
        #expect(bridge.contains(#"Notification.Name("epistemos.agentclone.hostContext")"#))

        #expect(setup.contains("ClaudeService"))
        #expect(setup.contains("CodexService"))
        #expect(setup.contains("OpenAICompatibleService"))
        #expect(setup.contains("OllamaService"))
        #expect(setup.contains("FoundationModelService"))
    }

    @Test("Setup remains escapable for first-run users")
    func setupAssistantCanAlwaysFinish() throws {
        let app = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")
        let setup = try loadMirroredSourceTextFile("Epistemos/Views/Onboarding/SetupAssistantView.swift")
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")

        #expect(setup.contains("Button(\"Use App Now\")"))
        #expect(setup.contains("private func completeSetupNow()"))
        #expect(setup.contains("ui.needsSetup = false"))
        #expect(setup.contains("Button(vaultSync.vaultURL == nil ? \"Skip Vault\" : \"Next\")"))
        #expect(!setup.contains(".disabled(vaultSync.vaultURL == nil)"))
        #expect(app.contains("bootstrap.uiState.needsSetup = false"))
        #expect(root.contains("UserDefaults.standard.set(true, forKey: \"epistemos.setupComplete\")"))
    }
}

private nonisolated func mirroredSourcePathExists(_ relativePath: String) throws -> Bool {
    let url = try sourceMirrorURL(for: relativePath)
    return FileManager.default.fileExists(atPath: url.path)
}
