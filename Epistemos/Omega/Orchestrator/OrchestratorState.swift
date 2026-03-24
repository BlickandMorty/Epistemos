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

        // Generate plan via LLM or heuristic fallback
        var steps: [AgentStep] = []
        var usedLLM = false

        if let planner = planningService {
            let llmSteps = await planner.generatePlan(for: description)
            if !llmSteps.isEmpty {
                steps = llmSteps
                usedLLM = true
            }
        }

        // If LLM planning failed or unavailable, use heuristic
        if steps.isEmpty {
            steps = heuristicPlan(for: description)
        }

        isPlanning = false
        planningMethod = usedLLM ? "AI-planned" : "Heuristic routing"

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

    // MARK: - Heuristic Fallback

    /// Keyword-based routing when the LLM is unavailable or returns unparseable output.
    /// Covers common task patterns. Falls back to a helpful error for unrecognized tasks.
    private func heuristicPlan(for task: String) -> [AgentStep] {
        let lower = task.lowercased()

        // ── Writing / Summarization (use notes agent) ────────────────────
        let writeKeywords = ["write", "summarize", "summary", "draft", "compose", "rewrite", "outline", "essay", "paragraph"]
        if writeKeywords.contains(where: { lower.contains($0) }) {
            return [AgentStep(
                description: "Write/summarize: \(task)",
                assignedAgent: "notes",
                toolName: "create_note",
                argumentsJson: "{\"title\":\"\(escapeJson(task))\",\"body\":\"\"}"
            )]
        }

        // ── Web browsing ─────────────────────────────────────────────────
        if lower.contains("open") && (lower.contains("safari") || lower.contains("http") || lower.contains("url") || lower.contains("website") || lower.contains("apple.com")) {
            let url = extractURL(from: task) ?? "https://www.apple.com"
            return [AgentStep(
                description: "Open URL in Safari",
                assignedAgent: "safari",
                toolName: "open_url",
                argumentsJson: "{\"url\":\"\(url)\"}"
            )]
        }

        // ── Web search ───────────────────────────────────────────────────
        let searchKeywords = ["search", "google", "look up", "find info", "research"]
        if searchKeywords.contains(where: { lower.contains($0) }) {
            let query = task
                .replacingOccurrences(of: "search for ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "search the web for ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "google ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "look up ", with: "", options: .caseInsensitive)
            return [AgentStep(
                description: "Search the web",
                assignedAgent: "safari",
                toolName: "search_web",
                argumentsJson: "{\"query\":\"\(escapeJson(query))\"}"
            )]
        }

        // ── File operations ──────────────────────────────────────────────
        if lower.contains("list") && (lower.contains("file") || lower.contains("folder") || lower.contains("directory")) {
            return [AgentStep(
                description: "List files",
                assignedAgent: "file",
                toolName: "list_files",
                argumentsJson: "{\"path\":\".\"}"
            )]
        }

        if (lower.contains("read") || lower.contains("open") || lower.contains("show")) && lower.contains("file") {
            return [AgentStep(
                description: "Read file",
                assignedAgent: "file",
                toolName: "read_file",
                argumentsJson: "{\"path\":\"\"}"
            )]
        }

        // ── Note operations ──────────────────────────────────────────────
        if lower.contains("note") && (lower.contains("create") || lower.contains("new") || lower.contains("make")) {
            return [AgentStep(
                description: "Create a new note",
                assignedAgent: "notes",
                toolName: "create_note",
                argumentsJson: "{\"title\":\"New Note\",\"body\":\"\"}"
            )]
        }

        if lower.contains("note") && lower.contains("search") {
            return [AgentStep(
                description: "Search notes",
                assignedAgent: "notes",
                toolName: "search_notes",
                argumentsJson: "{\"query\":\"\(escapeJson(task))\"}"
            )]
        }

        // ── Destructive operations (high risk) ───────────────────────────
        if lower.contains("delete") || lower.contains("remove") || lower.contains("trash") {
            return [AgentStep(
                description: task,
                assignedAgent: "file",
                toolName: "delete_file",
                argumentsJson: "{}",
                riskLevel: .high
            )]
        }

        // ── Shell commands (explicit) ────────────────────────────────────
        if lower.contains("run ") || lower.contains("execute ") || lower.hasPrefix("ls") || lower.hasPrefix("pwd") || lower.hasPrefix("echo") {
            let cmd = task.replacingOccurrences(of: "run ", with: "", options: .caseInsensitive)
                         .replacingOccurrences(of: "execute ", with: "", options: .caseInsensitive)
            return [AgentStep(
                description: "Run command: \(cmd)",
                assignedAgent: "terminal",
                toolName: "run_command",
                argumentsJson: "{\"command\":\"\(escapeJson(cmd))\"}"
            )]
        }

        // ── Shortcut operations ──────────────────────────────────────────
        if lower.contains("shortcut") || lower.contains("workflow") {
            return [AgentStep(
                description: task,
                assignedAgent: "automation",
                toolName: "run_shortcut",
                argumentsJson: "{\"name\":\"\"}"
            )]
        }

        // ── Default: try to use notes agent for general questions ─────────
        // If no specific pattern matches, treat it as a question/writing task
        // rather than blindly running a terminal command.
        return [AgentStep(
            description: task,
            assignedAgent: "notes",
            toolName: "create_note",
            argumentsJson: "{\"title\":\"\(escapeJson(task))\",\"body\":\"Omega could not determine the right action. Please try rephrasing or load a local AI model for intelligent planning.\"}"
        )]
    }

    private func extractURL(from text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, range: range)
            .flatMap { Range($0.range, in: text) }
            .map { String(text[$0]) }
    }

    private func escapeJson(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
    }
}
