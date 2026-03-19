import Foundation
import Testing
@testable import Epistemos

@Suite("Runtime Validation")
struct RuntimeValidationTests {
    @MainActor
    @Test("cold bootstrap leaves the local runtime unloaded until the first real request")
    func coldBootstrapLeavesLocalRuntimeUnloaded() async {
        let bootstrap = AppBootstrap()

        #expect(await bootstrap.localInferenceService.profilingSnapshot() == nil)
        #expect(bootstrap.localLLMClient.configSnapshot().provider == .localMLX)
        #expect(
            bootstrap.localLLMClient.configSnapshot().model
                == bootstrap.inferenceState.effectiveLocalTextModelID
        )
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
        let palette = try loadRepoTextFile("Epistemos/Views/Landing/CommandPaletteOverlay.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(miniChat.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(chatView.contains(".onAppear {\n                    Task { @MainActor in"))
        #expect(noteSidebar.contains(".onAppear {\n                Task { @MainActor in"))
        #expect(chatSidebar.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(palette.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(settings.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(inspector.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(workspace.contains(".onAppear {\n                Task { @MainActor in"))
    }

    @Test("settings window keeps a native source-list layout with a persistent sidebar toggle")
    func settingsWindowUsesNativeSourceListChrome() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let utilityManager = try loadRepoTextFile("Epistemos/App/UtilityWindowManager.swift")

        #expect(settings.contains(".listStyle(.sidebar)"))
        #expect(settings.contains(".ignoresSafeArea(.container, edges: .top)"))
        #expect(settings.contains("Image(systemName: \"sidebar.left\")"))
        #expect(utilityManager.contains("toolbar.showsBaselineSeparator = false"))
        #expect(utilityManager.contains("panel.toolbarStyle = .unified"))
    }

    @Test("note editor still suppresses binding sync churn during AI token flushes")
    func noteEditorStillSuppressesStreamingBindingChurn() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable.swift")

        #expect(source.contains("var isFlushingTokens = false"))
        #expect(source.contains("guard !isFlushingTokens else { return }"))
        #expect(source.contains("Task.sleep(for: .milliseconds(300))"))
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
