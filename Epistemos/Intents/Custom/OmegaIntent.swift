import AppIntents

// MARK: - Agent Runtime Task Intent

/// Siri shortcut: "Run an agent task in Epistemos"
/// Allows users to trigger agent-runtime tasks via Siri, Shortcuts, or Spotlight.
struct OmegaTaskIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Run Agent Runtime Task"
    nonisolated(unsafe) static var description = IntentDescription(
        "Run an automation task using the agent runtime.",
        categoryName: "Automation"
    )
    nonisolated(unsafe) static var openAppWhenRun = true
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Task Description", description: "What should the agent runtime do?")
    var taskDescription: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        _ = taskDescription
        return .result(
            dialog: "Agent Runtime shortcuts aren't available in this build. Open Epistemos and use chat or Mini Chat instead."
        )
    }
}
