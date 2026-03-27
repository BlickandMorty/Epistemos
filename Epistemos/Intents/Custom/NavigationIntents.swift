import AppIntents

// MARK: - Navigation Intents (Custom)
// Let Siri/Shortcuts open specific panels or the MiniChat floating window.

// MARK: Open Panel

struct OpenPanelIntent: AppIntent {
    static var title: LocalizedStringResource { "Open Epistemos Panel" }
    static var description: IntentDescription {
        IntentDescription("Opens a specific panel in Epistemos.")
    }
    static var openAppWhenRun: Bool { true }

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
    static var title: LocalizedStringResource { "Open MiniChat" }
    static var description: IntentDescription {
        IntentDescription("Opens the Epistemos floating chat.")
    }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        MiniChatWindowController.shared.show()
        return .result()
    }
}
