import Foundation

// MARK: - Omega Agent Protocol

/// Protocol that all specialist agents conform to.
/// Each agent owns a narrow toolset and can plan + execute steps for its domain.
@MainActor
protocol OmegaAgent: Sendable {
    /// Unique identifier for this agent (e.g., "safari", "file", "notes").
    var name: String { get }

    /// Human-readable description of this agent's capabilities.
    var description: String { get }

    /// Names of tools this agent is allowed to use.
    var toolNames: [String] { get }

    /// Execute a single step. Returns the result as JSON string.
    func execute(step: AgentStep) async throws -> AgentStepResult
}

// MARK: - Agent Step

/// A single unit of work assigned to an agent by the orchestrator.
struct AgentStep: Identifiable, Sendable {
    let id: UUID
    let description: String
    let assignedAgent: String
    let toolName: String
    let argumentsJson: String
    let riskLevel: RiskLevel
    var dependsOn: [UUID]

    init(
        id: UUID = UUID(),
        description: String,
        assignedAgent: String,
        toolName: String,
        argumentsJson: String = "{}",
        riskLevel: RiskLevel = .low,
        dependsOn: [UUID] = []
    ) {
        self.id = id
        self.description = description
        self.assignedAgent = assignedAgent
        self.toolName = toolName
        self.argumentsJson = argumentsJson
        self.riskLevel = riskLevel
        self.dependsOn = dependsOn
    }
}

// MARK: - Agent Step Result

struct AgentStepResult: Sendable {
    let stepId: UUID
    let success: Bool
    let outputJson: String
    let error: String?
    let durationMs: UInt64
    let confidence: Double

    static func ok(_ outputJson: String, stepId: UUID, durationMs: UInt64, confidence: Double = 1.0) -> AgentStepResult {
        AgentStepResult(stepId: stepId, success: true, outputJson: outputJson, error: nil, durationMs: durationMs, confidence: confidence)
    }

    static func fail(_ error: String, stepId: UUID, durationMs: UInt64) -> AgentStepResult {
        AgentStepResult(stepId: stepId, success: false, outputJson: "null", error: error, durationMs: durationMs, confidence: 0.0)
    }
}

// MARK: - Risk Level

enum RiskLevel: String, Codable, Sendable {
    case low        // Auto-execute
    case medium     // Execute with logging
    case high       // Preview before execution
    case critical   // Require explicit per-step confirmation
}

// MARK: - Escalation

enum EscalationReason: Sendable {
    case lowConfidence(Double)
    case toolNotFound(String)
    case permissionDenied(String)
    case researchNeeded(String)
}
