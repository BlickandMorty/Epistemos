import Foundation

// MARK: - Orchestrator State (retired compatibility shim)
// The full Omega orchestrator has been retired in favor of the Rust agent_core.
// This shim preserves the public API surface that other files reference
// (AppBootstrap, AgentViewModel, views) without the dead agent dependencies.

@MainActor @Observable
final class OrchestratorState {
    private static let retiredExecutionMessage = "Omega task execution is retired; use unified chat."

    // MARK: - Safety (still used by AgentViewModel)
    let loopDetector = ToolLoopDetector()
    let contextBudget = ContextBudgetManager()
    let depthLimiter = AgentDepthLimiter()

    // MARK: - State (read by views)
    var currentTaskDescription: String = ""
    var isExecuting: Bool = false
    var isPlanning: Bool = false
    var isModelLoading: Bool = false
    var planningError: String?
    var executionLog: [AgentStepResult] = []

    // MARK: - Bridges (still referenced)
    private(set) weak var mcpBridge: MCPBridge?
    weak var agentGraphMemory: AgentGraphMemory?

    // MARK: - Retired Omega Subsystems (compatibility state)
    // These will be removed when views are migrated to AgentViewModel.
    let taskGraph = RetiredTaskGraphState()
    let confirmationGate = RetiredConfirmationGateState()
    let researchPause = RetiredResearchPauseState()
    let liveRuntime = RetiredLiveRuntimeState()
    let researchOrchestrator = RetiredResearchOrchestratorState()
    var planningService: Any?

    func submitTask(_ description: String) async {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        currentTaskDescription = trimmed
        isExecuting = false
        isPlanning = false
        isModelLoading = false
        planningError = Self.retiredExecutionMessage
        executionLog = [
            .fail(Self.retiredExecutionMessage, stepId: UUID(), durationMs: 0)
        ]
    }

    // MARK: - Setup (retired registration)
    func registerAgents(
        vaultURL: URL? = nil,
        modelContainer: Any? = nil,
        triageService: TriageService? = nil,
        vaultSync: VaultSyncService? = nil,
        mcpBridge: MCPBridge? = nil,
        constrainedDecoding: ConstrainedDecodingService? = nil,
        agentGraphMemory: AgentGraphMemory? = nil,
        screenCapture: ScreenCaptureService? = nil,
        perception: Screen2AXFusion? = nil
    ) {
        self.mcpBridge = mcpBridge
        self.agentGraphMemory = agentGraphMemory
    }
}

// MARK: - Retired Omega Compatibility State
// Minimal retired state objects preserve the public API surface for views
// that still reference Omega types. These will be removed when views are
// fully migrated.

@MainActor @Observable
final class RetiredTaskGraphState {
    var status: TaskGraphStatus = .idle
    var steps: [AgentStepResult] = []
}

enum TaskGraphStatus: String, Sendable {
    case idle, planning, executing, completed, failed
}

@MainActor @Observable
final class RetiredConfirmationGateState {
    var pendingConfirmation: ConfirmationRequest?
}

struct ConfirmationRequest {
    let description: String
    let toolName: String
    let riskLevel: ConfirmationRiskLevel
    let argumentsJson: String
}

enum ConfirmationRiskLevel: String, Sendable {
    case low, medium, high, critical
}

@MainActor @Observable
final class RetiredResearchPauseState {
    var isPaused = false
    var activeRequest: ResearchRequest?
}

struct ResearchRequest {
    let query: String
    let depth: Int
}

@MainActor @Observable
final class RetiredLiveRuntimeState {
    var hasContent = false
    var currentPhase: String = ""
    var lastTurn: String?
    var phaseHistory: [PhaseEntry] = []
    var transcriptPath: String = ""
}

struct PhaseEntry: Identifiable {
    let id = UUID()
    let name: String
    let timestamp: Date
}

@MainActor @Observable
final class RetiredResearchOrchestratorState {
    var isActive = false
}
