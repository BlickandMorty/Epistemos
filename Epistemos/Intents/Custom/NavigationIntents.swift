import AppIntents

// MARK: - Navigation Intents (Custom)
// Let Siri/Shortcuts open specific panels.

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
        AppBootstrap.shared?.uiState.setActivePanel(tab.releaseSupportedVariant)
        return .result()
    }
}
