import Foundation
import SwiftData

// MARK: - Orchestrator State

/// Central Omega state object. Manages the agent execution lifecycle:
/// task submission → planning → confirmation → execution → results.
@MainActor @Observable
final class OrchestratorState {

    // MARK: - Sub-components
    let taskGraph = TaskGraph()
    let confirmationGate = ConfirmationGate()
    let researchPause = ResearchPauseHandler()

    // MARK: - Agents
    private(set) var agents: [String: any OmegaAgent] = [:]

    // MARK: - Current task
    var currentTaskDescription: String = ""
    var isExecuting: Bool = false
    var executionLog: [AgentStepResult] = []

    // MARK: - Setup

    /// Register all specialist agents. Called by AppBootstrap after services are created.
    func registerAgents(
        vaultURL: URL?,
        modelContainer: ModelContainer?
    ) {
        let fileAgent = FileAgent(vaultURL: vaultURL)
        let notesAgent = NotesAgent(modelContainer: modelContainer)
        let terminalAgent = TerminalAgent()
        let safariAgent = SafariAgent()
        let automationAgent = AutomationAgent()

        agents = [
            fileAgent.name: fileAgent,
            notesAgent.name: notesAgent,
            terminalAgent.name: terminalAgent,
            safariAgent.name: safariAgent,
            automationAgent.name: automationAgent,
        ]
    }

    // MARK: - Task Lifecycle

    /// Submit a new task for execution.
    /// The orchestrator will plan steps and execute them through the TaskGraph.
    func submitTask(_ description: String) async {
        currentTaskDescription = description
        taskGraph.reset()
        taskGraph.status = .planning
        executionLog.removeAll()

        // For now, create a simple single-step plan.
        // Phase 4 (OmegaPlanningService) will replace this with LLM-generated plans.
        let step = AgentStep(
            description: description,
            assignedAgent: "terminal",
            toolName: "run_command",
            argumentsJson: "{\"command\":\"echo 'Task received: \(description.replacingOccurrences(of: "'", with: "'\\''"))'\"}",
            riskLevel: .low
        )
        taskGraph.addStep(step)
        taskGraph.status = .awaitingConfirmation

        await executePlan()
    }

    /// Execute the current plan, respecting confirmation gates.
    func executePlan() async {
        isExecuting = true
        taskGraph.status = .executing

        while !taskGraph.isComplete && !taskGraph.hasFailed {
            let ready = taskGraph.readySteps()
            if ready.isEmpty { break }

            // Execute ready steps (could be parallel, but sequential for safety)
            for step in ready {
                // Check confirmation gate
                let decision = confirmationGate.evaluate(step: step)
                switch decision {
                case .autoExecute, .executeWithLogging:
                    break // proceed
                case .requirePreview, .requireExplicitConfirmation:
                    taskGraph.status = .awaitingConfirmation
                    let approved = await confirmationGate.requestConfirmation(for: step)
                    if !approved {
                        let result = AgentStepResult.fail("User denied", stepId: step.id, durationMs: 0)
                        taskGraph.recordResult(result)
                        executionLog.append(result)
                        continue
                    }
                    taskGraph.status = .executing
                }

                // Find the assigned agent
                guard let agent = agents[step.assignedAgent] else {
                    let result = AgentStepResult.fail(
                        "Agent '\(step.assignedAgent)' not found",
                        stepId: step.id,
                        durationMs: 0
                    )
                    taskGraph.recordResult(result)
                    executionLog.append(result)
                    continue
                }

                // Execute the step with retry logic (max 3 retries, 0.2s base exponential backoff)
                let maxRetries = 3
                let baseDelayMs: UInt64 = 200
                var lastResult: AgentStepResult?

                for attempt in 0..<maxRetries {
                    do {
                        let result = try await agent.execute(step: step)
                        lastResult = result

                        if result.success {
                            taskGraph.recordResult(result)
                            executionLog.append(result)

                            // Escalate on low confidence
                            if result.confidence < 0.8 {
                                _ = await researchPause.requestResearch(
                                    questions: ["Agent reported low confidence (\(result.confidence)). Should we continue?"],
                                    context: step.description
                                )
                            }
                            break
                        }

                        // Failed — retry if attempts remain
                        if attempt < maxRetries - 1 {
                            let delay = baseDelayMs * UInt64(1 << attempt) // Exponential backoff
                            try? await Task.sleep(for: .milliseconds(delay))
                        } else {
                            // Final attempt failed
                            taskGraph.recordResult(result)
                            executionLog.append(result)
                        }
                    } catch {
                        let result = AgentStepResult.fail(error.localizedDescription, stepId: step.id, durationMs: 0)
                        lastResult = result
                        if attempt == maxRetries - 1 {
                            taskGraph.recordResult(result)
                            executionLog.append(result)
                        } else {
                            let delay = baseDelayMs * UInt64(1 << attempt)
                            try? await Task.sleep(for: .milliseconds(delay))
                        }
                    }
                }
            }
        }

        isExecuting = false
    }

    /// Cancel the current execution.
    func cancel() {
        isExecuting = false
        taskGraph.status = .failed
    }
}
