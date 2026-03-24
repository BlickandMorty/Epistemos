import Foundation
import SwiftData

// MARK: - Orchestrator State

/// Central Omega state object. Manages the agent execution lifecycle:
/// task submission → LLM planning → confirmation → execution → results.
@MainActor @Observable
final class OrchestratorState {

    // MARK: - Sub-components
    let taskGraph = TaskGraph()
    let confirmationGate = ConfirmationGate()
    let researchPause = ResearchPauseHandler()

    // MARK: - Planning
    private(set) var planningService: OmegaPlanningService?

    // MARK: - Agents
    private(set) var agents: [String: any OmegaAgent] = [:]

    // MARK: - Current task
    var currentTaskDescription: String = ""
    var isExecuting: Bool = false
    var isPlanning: Bool = false
    var planningError: String?
    var planningMethod: String = ""
    var executionLog: [AgentStepResult] = []

    // MARK: - Setup

    /// Register all specialist agents and wire the planning service.
    /// Called by AppBootstrap after services are created.
    func registerAgents(
        vaultURL: URL?,
        modelContainer: ModelContainer?,
        triageService: TriageService?
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

        // Wire planning service if TriageService is available
        if let triage = triageService {
            let bridge = OmegaInferenceBridge(triageService: triage)
            planningService = OmegaPlanningService(
                inferenceBridge: bridge,
                availableAgents: Array(agents.keys)
            )
        }
    }

    // MARK: - Task Lifecycle

    /// Submit a new task for execution.
    /// Uses LLM-based planning when available, falls back to heuristic routing.
    func submitTask(_ description: String) async {
        currentTaskDescription = description
        taskGraph.reset()
        taskGraph.status = .planning
        isPlanning = true
        planningError = nil
        executionLog.removeAll()

        // Generate plan via LLM or Rust heuristic fallback
        var steps: [AgentStep] = []
        var usedLLM = false

        if let planner = planningService {
            let llmSteps = await planner.generatePlan(for: description)
            if !llmSteps.isEmpty {
                steps = llmSteps
                usedLLM = true
            }
        }

        // If LLM planning failed or unavailable, use Rust-side heuristic planner
        if steps.isEmpty {
            steps = rustHeuristicPlan(for: description)
        }

        isPlanning = false
        planningMethod = usedLLM ? "AI-planned" : "Rust heuristic"

        if steps.isEmpty {
            planningError = "Could not determine what to do. Try rephrasing your task, or load a local AI model in Settings > Inference for intelligent planning."
            taskGraph.status = .failed
            return
        }

        for step in steps {
            taskGraph.addStep(step)
        }
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

            for step in ready {
                // Check confirmation gate
                let decision = confirmationGate.evaluate(step: step)
                switch decision {
                case .autoExecute, .executeWithLogging:
                    break
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
                        stepId: step.id, durationMs: 0
                    )
                    taskGraph.recordResult(result)
                    executionLog.append(result)
                    continue
                }

                // Execute with retry logic (max 3, exponential backoff 0.2s base)
                let maxRetries = 3
                let baseDelayMs: UInt64 = 200

                for attempt in 0..<maxRetries {
                    do {
                        let result = try await agent.execute(step: step)

                        if result.success {
                            taskGraph.recordResult(result)
                            executionLog.append(result)
                            if result.confidence < 0.8 {
                                _ = await researchPause.requestResearch(
                                    questions: ["Agent reported low confidence (\(result.confidence)). Continue?"],
                                    context: step.description
                                )
                            }
                            break
                        }

                        if attempt < maxRetries - 1 {
                            try? await Task.sleep(for: .milliseconds(baseDelayMs * UInt64(1 << attempt)))
                        } else {
                            taskGraph.recordResult(result)
                            executionLog.append(result)
                        }
                    } catch {
                        let result = AgentStepResult.fail(error.localizedDescription, stepId: step.id, durationMs: 0)
                        if attempt == maxRetries - 1 {
                            taskGraph.recordResult(result)
                            executionLog.append(result)
                        } else {
                            try? await Task.sleep(for: .milliseconds(baseDelayMs * UInt64(1 << attempt)))
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
        isPlanning = false
        taskGraph.status = .failed
    }

    // MARK: - Rust-Side Heuristic Planning

    /// Calls the Rust orchestrator's heuristic planner via UniFFI.
    /// Parses the JSON TaskGraph response into Swift AgentSteps.
    private func rustHeuristicPlan(for task: String) -> [AgentStep] {
        // Call Rust heuristic planner
        let graphJson = generateHeuristicPlan(task: task)

        // Parse the Rust TaskGraph JSON into Swift AgentSteps
        guard let data = graphJson.data(using: .utf8),
              let graph = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let steps = graph["steps"] as? [[String: Any]] else {
            return []
        }

        return steps.compactMap { stepDict -> AgentStep? in
            guard let description = stepDict["description"] as? String,
                  let agent = stepDict["assigned_agent"] as? String,
                  let tool = stepDict["tool_name"] as? String else {
                return nil
            }

            let argsJson = stepDict["arguments_json"] as? String ?? "{}"
            let riskStr = (stepDict["risk_level"] as? String) ?? "Low"
            let risk: RiskLevel = {
                switch riskStr.lowercased() {
                case "low": return .low
                case "medium": return .medium
                case "high": return .high
                case "critical": return .critical
                default: return .low
                }
            }()

            // Validate agent-tool combination via Rust
            let validation = validateAgentTool(agentName: agent, toolName: tool)
            if !validation.isEmpty {
                // Agent not allowed to use this tool — skip step
                return nil
            }

            let depsArray = stepDict["depends_on"] as? [String] ?? []

            return AgentStep(
                description: description,
                assignedAgent: agent,
                toolName: tool,
                argumentsJson: argsJson,
                riskLevel: risk,
                dependsOn: depsArray.compactMap { UUID(uuidString: $0) }
            )
        }
    }

    // MARK: - Rust Confirmation Gate

    /// Check confirmation decision via Rust orchestrator.
    func rustConfirmationDecision(for riskLevel: RiskLevel) -> String {
        evaluateRiskConfirmation(riskLevel: riskLevel.rawValue)
    }
}
