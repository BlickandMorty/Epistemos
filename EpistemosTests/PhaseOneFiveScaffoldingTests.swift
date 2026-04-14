import Foundation
import Testing
@testable import Epistemos

@Suite("Phase 1.5 Scaffolding")
struct PhaseOneFiveScaffoldingTests {
    @Test("agent message protocol allows only the documented hierarchy edges")
    func agentMessageProtocolAllowsOnlyDocumentedEdges() throws {
        let allowed = HierarchicalAgentMessage(
            messageID: "msg-1",
            taskID: "task-1",
            parentTaskID: nil,
            senderRole: .mainAgent,
            senderID: "main",
            recipientRole: .subAgent,
            recipientID: "graph-helper",
            messageType: .instruction,
            instruction: "Score the retrieved candidates for graph relevance.",
            constraints: AgentMessageConstraints(
                recursionDepthLimit: 1,
                reviewRoundLimit: 1,
                allowedTools: ["pkm_search"]
            ),
            budgetRef: "budget.local.standard",
            evidenceRefs: ["note:alpha"],
            confidence: 0.82,
            requestedAction: .execute,
            timestamp: Date(timeIntervalSince1970: 0)
        )

        let validated = try allowed.validated()
        #expect(validated.senderRole == .mainAgent)
        #expect(validated.recipientRole == .subAgent)

        let disallowed = HierarchicalAgentMessage(
            messageID: "msg-2",
            taskID: "task-1",
            parentTaskID: "task-0",
            senderRole: .subAgent,
            senderID: "graph-helper",
            recipientRole: .subAgent,
            recipientID: "reranker",
            messageType: .instruction,
            instruction: "Talk directly to another specialist.",
            constraints: AgentMessageConstraints(
                recursionDepthLimit: 1,
                reviewRoundLimit: 1,
                allowedTools: []
            ),
            budgetRef: "budget.local.standard",
            evidenceRefs: [],
            confidence: nil,
            requestedAction: .execute,
            timestamp: Date(timeIntervalSince1970: 1)
        )

        #expect(throws: AgentHierarchyProtocolError.self) {
            try disallowed.validated()
        }
    }

    @Test("local guardrail scaffold allows standard local work and blocks later-phase profiles")
    func localGuardrailScaffoldAllowsStandardAndBlocksLaterPhaseProfiles() {
        let guardrail = LocalGuardrailScaffold()

        let standardDecision = guardrail.evaluate(
            LocalGuardrailRequest(
                operation: .generate,
                executionMode: .local,
                requestedRuntimeKind: .gguf,
                requestedReasoningProfile: .standard,
                executionPolicyRef: "policy.standard.local"
            )
        )
        #expect(standardDecision.verdict == .allow)
        #expect(standardDecision.guardrailState == "clear")
        #expect(standardDecision.planTracePresent)

        let adaptiveDecision = guardrail.evaluate(
            LocalGuardrailRequest(
                operation: .generate,
                executionMode: .local,
                requestedRuntimeKind: .mlx,
                requestedReasoningProfile: .adaptive,
                executionPolicyRef: "policy.adaptive.helper"
            )
        )
        #expect(adaptiveDecision.verdict == .deny)
        #expect(adaptiveDecision.guardrailState == "blocked")
    }

    @Test("local guardrail scaffold explicitly allows adaptive helper flow only with an active session")
    func localGuardrailScaffoldAllowsAdaptiveFlowOnlyWithActiveSession() {
        let guardrail = LocalGuardrailScaffold()

        let deniedDecision = guardrail.evaluate(
            LocalGuardrailRequest(
                operation: .generate,
                executionMode: .local,
                requestedRuntimeKind: .mlx,
                requestedReasoningProfile: .adaptive,
                executionPolicyRef: "policy.adaptive.helper",
                hasActiveAdaptSession: false
            )
        )
        #expect(deniedDecision.verdict == .deny)
        #expect(deniedDecision.reason == .advancedProfileBlocked)

        let allowedDecision = guardrail.evaluate(
            LocalGuardrailRequest(
                operation: .generate,
                executionMode: .local,
                requestedRuntimeKind: .mlx,
                requestedReasoningProfile: .adaptive,
                executionPolicyRef: "policy.adaptive.helper",
                hasActiveAdaptSession: true
            )
        )
        #expect(allowedDecision.verdict == .allow)
        #expect(allowedDecision.reason == .adaptiveProfileAllowedWithSession)
        #expect(allowedDecision.guardrailState == "adaptation_gated")
    }

    @Test("local guardrail scaffold makes sidecar activation explicit")
    func localGuardrailScaffoldMakesSidecarActivationExplicit() {
        let guardrail = LocalGuardrailScaffold()

        let decision = guardrail.evaluate(
            LocalGuardrailRequest(
                operation: .generate,
                executionMode: .local,
                requestedRuntimeKind: .gguf,
                requestedReasoningProfile: .standard,
                executionPolicyRef: "policy.standard.local",
                isSidecarRequest: true
            )
        )

        #expect(decision.verdict == .allow)
        #expect(decision.reason == .sidecarAllowed)
        #expect(decision.guardrailState == "sidecar_gated")
        #expect(decision.planTracePresent)
    }

    @Test("KAN pilot scaffold stays off the main path and disabled by default")
    func kanPilotScaffoldStaysOffMainPathAndDisabledByDefault() {
        let pilot = KANPilotScaffold()
        let result = pilot.evaluate(
            KANPilotRequest(
                objective: "Score these note links for novelty.",
                candidateIDs: ["note-a", "note-b", "note-c"]
            )
        )

        #expect(pilot.scope == .offMainPath)
        #expect(result.status == .disabled)
        #expect(result.hints.isEmpty)
    }
}
