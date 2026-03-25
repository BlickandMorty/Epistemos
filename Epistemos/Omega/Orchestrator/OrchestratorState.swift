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
    var isModelLoading: Bool = false
    var planningError: String?
    var planningMethod: String = ""
    var executionLog: [AgentStepResult] = []

    // MARK: - Logging bridge
    private(set) weak var mcpBridge: MCPBridge?

    // MARK: - Graph memory (Ω14)
    weak var agentGraphMemory: AgentGraphMemory?

    // MARK: - Setup

    /// Register all specialist agents and wire the planning service.
    /// Called by AppBootstrap after services are created.
    func registerAgents(
        vaultURL: URL?,
        modelContainer: ModelContainer?,
        triageService: TriageService?,
        vaultSync: VaultSyncService? = nil,
        mcpBridge: MCPBridge? = nil,
        constrainedDecoding: ConstrainedDecodingService? = nil,
        agentGraphMemory: AgentGraphMemory? = nil
    ) {
        self.mcpBridge = mcpBridge
        self.agentGraphMemory = agentGraphMemory

        let fileAgent = FileAgent(vaultURL: vaultURL)
        let notesAgent = NotesAgent(modelContainer: modelContainer, vaultSync: vaultSync)
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
            bridge.constrainedDecoding = constrainedDecoding
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
            isModelLoading = true
            let llmSteps = await planner.generatePlan(for: description)
            isModelLoading = false
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
                        recordAndLog(result, step: step)
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
                    recordAndLog(result, step: step)
                    continue
                }

                // Inject dependency outputs into step arguments for chaining
                let enrichedStep = contextualizedStep(step)

                // Execute with retry logic (max 3, exponential backoff 0.2s base)
                let maxRetries = 3
                let baseDelayMs: UInt64 = 200

                for attempt in 0..<maxRetries {
                    do {
                        let result = try await agent.execute(step: enrichedStep)

                        if result.success {
                            recordAndLog(result, step: step)
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
                            recordAndLog(result, step: step)
                        }
                    } catch {
                        let result = AgentStepResult.fail(error.localizedDescription, stepId: step.id, durationMs: 0)
                        if attempt == maxRetries - 1 {
                            recordAndLog(result, step: step)
                        } else {
                            try? await Task.sleep(for: .milliseconds(baseDelayMs * UInt64(1 << attempt)))
                        }
                    }
                }
            }
        }

        isExecuting = false

        // Record to knowledge graph (Ω14)
        agentGraphMemory?.recordExecution(
            taskDescription: currentTaskDescription,
            steps: executionLog
        )
    }

    /// Record a step result in the task graph, execution log, and SQLite via MCPBridge.
    private func recordAndLog(_ result: AgentStepResult, step: AgentStep) {
        taskGraph.recordResult(result)
        executionLog.append(result)
        mcpBridge?.logExecution(
            toolName: step.toolName,
            argumentsJson: step.argumentsJson,
            resultJson: result.outputJson,
            durationMs: result.durationMs,
            success: result.success
        )
    }

    /// Enrich a step's arguments with outputs from its completed dependencies.
    /// Enables multi-step data flow: step 1 search results → step 2 can reference them.
    /// Adds a `"_context"` key to the arguments JSON containing dependency outputs.
    private func contextualizedStep(_ step: AgentStep) -> AgentStep {
        guard !step.dependsOn.isEmpty else { return step }

        // Collect outputs from completed dependencies
        var depOutputs: [[String: Any]] = []
        for depId in step.dependsOn {
            if let result = taskGraph.results[depId], result.success,
               let depStep = taskGraph.steps.first(where: { $0.id == depId }) {
                depOutputs.append([
                    "step_description": depStep.description,
                    "tool": depStep.toolName,
                    "output": result.outputJson,
                ])
            }
        }

        guard !depOutputs.isEmpty else { return step }

        // Merge context into existing arguments
        var args: [String: Any] = [:]
        if let data = step.argumentsJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            args = parsed
        }
        args["_context"] = depOutputs

        guard let enrichedData = try? JSONSerialization.data(withJSONObject: args),
              let enrichedJson = String(data: enrichedData, encoding: .utf8) else {
            return step
        }

        return AgentStep(
            id: step.id,
            description: step.description,
            assignedAgent: step.assignedAgent,
            toolName: step.toolName,
            argumentsJson: enrichedJson,
            riskLevel: step.riskLevel,
            dependsOn: step.dependsOn
        )
    }

    /// Cancel the current execution.
    func cancel() {
        isExecuting = false
        isPlanning = false
        taskGraph.status = .failed
    }

    /// Retry the last task from scratch.
    func retryTask() async {
        let task = currentTaskDescription
        guard !task.isEmpty else { return }
        await submitTask(task)
    }

    /// Return to idle with the current task description preserved so the user can re-submit.
    func editPlan() {
        isExecuting = false
        isPlanning = false
        planningError = nil
        planningMethod = ""
        executionLog.removeAll()
        taskGraph.reset()
        // currentTaskDescription is kept so the input bar shows it for editing
    }

    /// Reset all state to idle.
    func reset() {
        currentTaskDescription = ""
        isExecuting = false
        isPlanning = false
        planningError = nil
        planningMethod = ""
        executionLog.removeAll()
        taskGraph.reset()
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
