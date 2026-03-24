import Foundation

// MARK: - Confirmation Gate

/// Risk-based confirmation gate for agent actions.
/// Low risk → auto-execute; Medium → log; High → preview; Critical → explicit confirm.
@MainActor @Observable
final class ConfirmationGate {

    /// Pending confirmation request (shown in UI when non-nil).
    var pendingConfirmation: ConfirmationRequest?

    /// Evaluate a step's risk and determine whether to auto-execute or block.
    func evaluate(step: AgentStep) -> ConfirmationDecision {
        switch step.riskLevel {
        case .low:
            return .autoExecute
        case .medium:
            return .executeWithLogging
        case .high:
            return .requirePreview(step)
        case .critical:
            return .requireExplicitConfirmation(step)
        }
    }

    /// Request confirmation from the user. Blocks until approved or denied.
    func requestConfirmation(for step: AgentStep) async -> Bool {
        pendingConfirmation = ConfirmationRequest(
            stepId: step.id,
            description: step.description,
            toolName: step.toolName,
            argumentsJson: step.argumentsJson,
            riskLevel: step.riskLevel
        )

        // Wait for UI to set the response
        while pendingConfirmation != nil {
            try? await Task.sleep(for: .milliseconds(100))
        }

        return lastConfirmationApproved
    }

    /// Called by UI when user approves.
    func approve() {
        lastConfirmationApproved = true
        pendingConfirmation = nil
    }

    /// Called by UI when user denies.
    func deny() {
        lastConfirmationApproved = false
        pendingConfirmation = nil
    }

    private var lastConfirmationApproved = false
}

// MARK: - Types

struct ConfirmationRequest: Identifiable, Sendable {
    let id = UUID()
    let stepId: UUID
    let description: String
    let toolName: String
    let argumentsJson: String
    let riskLevel: RiskLevel
}

enum ConfirmationDecision: Sendable {
    case autoExecute
    case executeWithLogging
    case requirePreview(AgentStep)
    case requireExplicitConfirmation(AgentStep)
}
