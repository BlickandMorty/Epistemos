import Foundation

// MARK: - Confirmation Gate

/// Risk-based confirmation gate for agent actions.
/// Low risk → auto-execute; Medium → log; High → preview; Critical → explicit confirm.
@MainActor @Observable
final class ConfirmationGate {

    /// Pending confirmation request (shown in UI when non-nil).
    var pendingConfirmation: ConfirmationRequest?

    /// Continuation awaiting the user's approve/deny decision.
    private var pendingContinuation: CheckedContinuation<Bool, Never>?

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

    /// Request confirmation from the user. Suspends until approved or denied.
    func requestConfirmation(for step: AgentStep) async -> Bool {
        pendingConfirmation = ConfirmationRequest(
            stepId: step.id,
            description: step.description,
            toolName: step.toolName,
            argumentsJson: step.argumentsJson,
            riskLevel: step.riskLevel
        )

        return await withCheckedContinuation { continuation in
            pendingContinuation = continuation
        }
    }

    /// Called by UI when user approves.
    func approve() {
        let continuation = pendingContinuation
        pendingContinuation = nil
        pendingConfirmation = nil
        continuation?.resume(returning: true)
    }

    /// Called by UI when user denies.
    func deny() {
        let continuation = pendingContinuation
        pendingContinuation = nil
        pendingConfirmation = nil
        continuation?.resume(returning: false)
    }
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
