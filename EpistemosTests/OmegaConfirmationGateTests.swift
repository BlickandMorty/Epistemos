import Testing
@testable import Epistemos

@Suite("ConfirmationGate")
@MainActor
struct ConfirmationGateTests {

    @Test("Low risk auto-executes")
    func lowRisk() {
        let gate = ConfirmationGate()
        let step = AgentStep(description: "Read file", assignedAgent: "file", toolName: "read_file", riskLevel: .low)
        let decision = gate.evaluate(step: step)
        if case .autoExecute = decision { } else {
            Issue.record("Expected autoExecute for low risk")
        }
    }

    @Test("Medium risk executes with logging")
    func mediumRisk() {
        let gate = ConfirmationGate()
        let step = AgentStep(description: "List files", assignedAgent: "file", toolName: "list_files", riskLevel: .medium)
        let decision = gate.evaluate(step: step)
        if case .executeWithLogging = decision { } else {
            Issue.record("Expected executeWithLogging for medium risk")
        }
    }

    @Test("High risk requires preview")
    func highRisk() {
        let gate = ConfirmationGate()
        let step = AgentStep(description: "Move file", assignedAgent: "file", toolName: "move_file", riskLevel: .high)
        let decision = gate.evaluate(step: step)
        if case .requirePreview = decision { } else {
            Issue.record("Expected requirePreview for high risk")
        }
    }

    @Test("Critical risk requires explicit confirmation")
    func criticalRisk() {
        let gate = ConfirmationGate()
        let step = AgentStep(description: "Delete all", assignedAgent: "file", toolName: "delete_file", riskLevel: .critical)
        let decision = gate.evaluate(step: step)
        if case .requireExplicitConfirmation = decision { } else {
            Issue.record("Expected requireExplicitConfirmation for critical risk")
        }
    }

    @Test("Approve clears pending confirmation")
    func approveClearsPending() {
        let gate = ConfirmationGate()
        gate.pendingConfirmation = ConfirmationRequest(
            stepId: UUID(),
            description: "test",
            toolName: "test",
            argumentsJson: "{}",
            riskLevel: .critical
        )
        #expect(gate.pendingConfirmation != nil)
        gate.approve()
        #expect(gate.pendingConfirmation == nil)
    }

    @Test("Deny clears pending confirmation")
    func denyClearsPending() {
        let gate = ConfirmationGate()
        gate.pendingConfirmation = ConfirmationRequest(
            stepId: UUID(),
            description: "test",
            toolName: "test",
            argumentsJson: "{}",
            riskLevel: .high
        )
        gate.deny()
        #expect(gate.pendingConfirmation == nil)
    }
}
