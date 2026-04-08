import Foundation

// MARK: - Orchestrator State (Stub)
// The full Omega orchestrator has been retired in favor of the Rust agent_core.
// This stub preserves the public API surface that other files reference
// (AppBootstrap, AgentViewModel, views) without the dead agent dependencies.

@MainActor @Observable
final class OrchestratorState {

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

    // MARK: - Retired Omega Subsystems (stubs for compile compatibility)
    // These will be removed when views are migrated to AgentViewModel.
    let taskGraph = TaskGraphStub()
    let confirmationGate = ConfirmationGateStub()
    let researchPause = ResearchPauseStub()
    let liveRuntime = LiveRuntimeStub()
    let researchOrchestrator = ResearchOrchestratorStub()
    var planningService: Any?

    func submitTask(_ description: String) async {
        // No-op — agent tasks now go through Rust agent_core via ChatCoordinator
    }

    // MARK: - Setup (no-op — agents retired)
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

// MARK: - Retired Omega Type Stubs
// Minimal stubs that preserve the public API surface for views that still
// reference Omega types. These will be removed when views are fully migrated.

@MainActor @Observable
final class TaskGraphStub {
    var status: TaskGraphStatus = .idle
    var steps: [AgentStepResult] = []
}

enum TaskGraphStatus: String, Sendable {
    case idle, planning, executing, completed, failed
}

@MainActor @Observable
final class ConfirmationGateStub {
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
final class ResearchPauseStub {
    var isPaused = false
    var activeRequest: ResearchRequest?
}

struct ResearchRequest {
    let query: String
    let depth: Int
}

@MainActor @Observable
final class LiveRuntimeStub {
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
final class ResearchOrchestratorStub {
    var isActive = false
}
