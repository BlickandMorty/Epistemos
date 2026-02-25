import AppIntents

// MARK: - Navigation Intents (Custom)
// Let Siri/Shortcuts open specific panels or the MiniChat floating window.

// MARK: Open Panel

struct OpenPanelIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Open Epistemos Panel"
    nonisolated(unsafe) static var description: IntentDescription = "Opens a specific panel in Epistemos."
    nonisolated(unsafe) static var openAppWhenRun = true

    @Parameter(title: "Panel")
    var panel: PanelEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let tab = NavTab(rawValue: panel.id) else {
            return .result()
        }
        AppBootstrap.shared?.uiState.setActivePanel(tab)
        return .result()
    }
}

// MARK: Open MiniChat

struct OpenMiniChatIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Open MiniChat"
    nonisolated(unsafe) static var description: IntentDescription = "Opens the Epistemos MiniChat floating window."
    nonisolated(unsafe) static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let ui = AppBootstrap.shared?.uiState else { return .result() }
        if !ui.miniChatOpen {
            ui.toggleMiniChat()
        }
        return .result()
    }
}
