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

    @Parameter(title: "Task Description", description: "What should the agent runtime do?")
    var taskDescription: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else {
            throw IntentError.appNotReady
        }

        let orchestrator = bootstrap.orchestratorState
        await orchestrator.submitTask(taskDescription)

        // Wait briefly for planning to complete
        try? await Task.sleep(for: .seconds(2))

        let status = orchestrator.taskGraph.status
        switch status {
        case .completed:
            return .result(dialog: "Done! Task completed successfully.")
        case .executing:
            return .result(dialog: "The agent runtime is working on: \(taskDescription). Check the app for progress.")
        case .failed:
            let error = orchestrator.planningError ?? "Task failed"
            return .result(dialog: "Task couldn't complete: \(error)")
        default:
            return .result(dialog: "The agent runtime is processing your request. Open the app to see progress.")
        }
    }
}
