import Foundation

// MARK: - LocalGuardrailScaffold
//
// SCAFFOLD ONLY — RCA-P2-010 classification 2026-05-13.
//
// Decision-table guardrail for Local backend runtime requests. The
// scaffold encodes the local-vs-control-plane policy in a pure
// function, but **no production caller wires it into the runtime**
// (`rg "LocalGuardrailScaffold("` returns no matches in the app
// target). The shipping app's local-agent gate lives in
// `LocalAgentGatewayPolicy` (Epistemos/LocalAgent/). This scaffold
// stays around as the decision-table reference for whatever
// future control-plane bridge ends up consuming it.
//
// Activation tracked under audit register `RCA-P2-010`.

nonisolated struct LocalGuardrailRequest: Sendable, Equatable {
    let operation: BackendRuntimeOperation
    let executionMode: BackendExecutionMode
    let requestedRuntimeKind: BackendRuntimeKind?
    let requestedReasoningProfile: BackendReasoningProfile?
    let executionPolicyRef: String?
    let isHelperModel: Bool
    let hasActiveAdaptSession: Bool
    let isSidecarRequest: Bool

    init(
        operation: BackendRuntimeOperation,
        executionMode: BackendExecutionMode,
        requestedRuntimeKind: BackendRuntimeKind? = nil,
        requestedReasoningProfile: BackendReasoningProfile? = nil,
        executionPolicyRef: String? = nil,
        isHelperModel: Bool = false,
        hasActiveAdaptSession: Bool = false,
        isSidecarRequest: Bool = false
    ) {
        self.operation = operation
        self.executionMode = executionMode
        self.requestedRuntimeKind = requestedRuntimeKind
        self.requestedReasoningProfile = requestedReasoningProfile
        self.executionPolicyRef = executionPolicyRef
        self.isHelperModel = isHelperModel
        self.hasActiveAdaptSession = hasActiveAdaptSession
        self.isSidecarRequest = isSidecarRequest
    }
}

nonisolated enum LocalGuardrailVerdict: String, Sendable, Equatable {
    case allow
    case deny
    case deferToControlPlane = "defer_to_control_plane"
}

nonisolated enum LocalGuardrailReason: String, Sendable, Equatable {
    case standardLocalFlow = "standard_local_flow"
    case advancedProfileBlocked = "advanced_profile_blocked"
    case reservedCapabilityBlocked = "reserved_capability_blocked"
    case nonLocalExecutionReserved = "non_local_execution_reserved"
    case adaptationAllowedForHelper = "adaptation_allowed_for_helper"
    case adaptationDeniedForMainRuntime = "adaptation_denied_for_main_runtime"
    case sidecarAllowed = "sidecar_allowed"
    case adaptiveProfileAllowedWithSession = "adaptive_profile_allowed_with_session"
}

nonisolated struct LocalGuardrailDecision: Sendable, Equatable {
    let verdict: LocalGuardrailVerdict
    let reason: LocalGuardrailReason
    let guardrailState: String
    let planTracePresent: Bool
}

nonisolated struct LocalGuardrailScaffold {
    func evaluate(_ request: LocalGuardrailRequest) -> LocalGuardrailDecision {
        guard request.executionMode == .local else {
            return LocalGuardrailDecision(
                verdict: .deny,
                reason: .nonLocalExecutionReserved,
                guardrailState: "blocked",
                planTracePresent: true
            )
        }

        switch request.operation {
        case .adapt:
            return evaluateAdaptation(request)
        case .imageGenerate:
            return LocalGuardrailDecision(
                verdict: .deny,
                reason: .reservedCapabilityBlocked,
                guardrailState: "blocked",
                planTracePresent: true
            )
        case .generate, .embed:
            break
        }

        if Self.isAdaptiveProfile(
            request.requestedReasoningProfile,
            executionPolicyRef: request.executionPolicyRef
        ) {
            guard request.hasActiveAdaptSession else {
                return LocalGuardrailDecision(
                    verdict: .deny,
                    reason: .advancedProfileBlocked,
                    guardrailState: "blocked",
                    planTracePresent: true
                )
            }

            return LocalGuardrailDecision(
                verdict: .allow,
                reason: .adaptiveProfileAllowedWithSession,
                guardrailState: "adaptation_gated",
                planTracePresent: true
            )
        }

        if Self.isBlockedProfile(
            request.requestedReasoningProfile,
            executionPolicyRef: request.executionPolicyRef
        ) {
            return LocalGuardrailDecision(
                verdict: .deny,
                reason: .advancedProfileBlocked,
                guardrailState: "blocked",
                planTracePresent: true
            )
        }

        if request.isSidecarRequest {
            return LocalGuardrailDecision(
                verdict: .allow,
                reason: .sidecarAllowed,
                guardrailState: "sidecar_gated",
                planTracePresent: true
            )
        }

        return LocalGuardrailDecision(
            verdict: .allow,
            reason: .standardLocalFlow,
            guardrailState: "clear",
            planTracePresent: true
        )
    }

    private func evaluateAdaptation(_ request: LocalGuardrailRequest) -> LocalGuardrailDecision {
        guard request.isHelperModel else {
            return LocalGuardrailDecision(
                verdict: .deny,
                reason: .adaptationDeniedForMainRuntime,
                guardrailState: "blocked",
                planTracePresent: true
            )
        }

        guard request.requestedRuntimeKind == .mlx || request.requestedRuntimeKind == nil else {
            return LocalGuardrailDecision(
                verdict: .deny,
                reason: .adaptationDeniedForMainRuntime,
                guardrailState: "blocked",
                planTracePresent: true
            )
        }

        return LocalGuardrailDecision(
            verdict: .allow,
            reason: .adaptationAllowedForHelper,
            guardrailState: "adaptation_gated",
            planTracePresent: true
        )
    }

    private static func isAdaptiveProfile(
        _ profile: BackendReasoningProfile?,
        executionPolicyRef: String?
    ) -> Bool {
        switch profile {
        case .adaptive:
            return true
        case .standard, .deep, .experimental, .visualSidecar, .none:
            break
        }

        guard let executionPolicyRef else { return false }
        return executionPolicyRef.contains("policy.adaptive.")
    }

    private static func isBlockedProfile(
        _ profile: BackendReasoningProfile?,
        executionPolicyRef: String?
    ) -> Bool {
        switch profile {
        case .experimental, .visualSidecar:
            return true
        case .standard, .deep, .adaptive, .none:
            break
        }

        guard let executionPolicyRef else { return false }
        return executionPolicyRef.contains("policy.experimental.")
            || executionPolicyRef.contains("policy.visual_sidecar.")
    }
}
