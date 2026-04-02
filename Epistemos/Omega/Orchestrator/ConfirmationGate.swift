import Foundation

// MARK: - Confirmation Gate

/// Risk-based confirmation gate for agent actions.
/// Low risk → auto-execute (when enabled in settings); Medium → log; High → preview; Critical → explicit confirm.
@MainActor @Observable
final class ConfirmationGate {
    init(timeout: Duration = .seconds(120)) {
        self.confirmationTimeout = timeout
    }

    /// Pending confirmation request (shown in UI when non-nil).
    var pendingConfirmation: ConfirmationRequest?

    /// Continuation awaiting the user's approve/deny decision.
    private var pendingContinuation: CheckedContinuation<Bool, Never>?
    private var pendingRequestID: UUID?

    /// Whether low-risk actions auto-execute. Reads from Settings → Omega.
    private var autoExecuteLowRisk: Bool {
        // Default true if key not set (preserves existing behavior)
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "omega.autoExecuteLowRisk") == nil
            ? true
            : defaults.bool(forKey: "omega.autoExecuteLowRisk")
    }

    /// Evaluate a step's risk and determine whether to auto-execute or block.
    func evaluate(step: AgentStep) -> ConfirmationDecision {
        switch step.riskLevel {
        case .low:
            return autoExecuteLowRisk ? .autoExecute : .requirePreview(step)
        case .medium:
            return .executeWithLogging
        case .high:
            return .requirePreview(step)
        case .critical:
            return .requireExplicitConfirmation(step)
        }
    }

    /// How long to wait for user response before auto-denying.
    private let confirmationTimeout: Duration

    /// Request confirmation from the user. Suspends until approved, denied, or timeout.
    func requestConfirmation(for step: AgentStep) async -> Bool {
        // Cancel any leaked prior continuation before storing a new one
        resolvePendingConfirmation(with: false)

        let requestID = UUID()
        pendingRequestID = requestID

        pendingConfirmation = ConfirmationRequest(
            stepId: step.id,
            description: step.description,
            toolName: step.toolName,
            argumentsJson: step.argumentsJson,
            riskLevel: step.riskLevel
        )

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                pendingContinuation = continuation

                // Timeout safety net — auto-deny if user never responds
                Task { @MainActor [weak self, requestID] in
                    try? await Task.sleep(for: self?.confirmationTimeout ?? .seconds(120))
                    self?.deny(requestID: requestID)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self, requestID] in
                self?.deny(requestID: requestID)
            }
        }
    }

    /// Called by UI when user approves.
    func approve() {
        resolvePendingConfirmation(with: true)
    }

    /// Called by UI when user denies.
    func deny() {
        resolvePendingConfirmation(with: false)
    }

    private func deny(requestID: UUID) {
        resolvePendingConfirmation(with: false, requestID: requestID)
    }

    private func resolvePendingConfirmation(with decision: Bool, requestID: UUID? = nil) {
        if let requestID, let pendingRequestID, pendingRequestID != requestID { return }
        let continuation = pendingContinuation
        pendingContinuation = nil
        pendingRequestID = nil
        pendingConfirmation = nil
        continuation?.resume(returning: decision)
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
