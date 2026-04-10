import Testing
@testable import Epistemos

// Legacy confirmation gate tests are kept for reference while the retired
// Omega approval/pause surfaces are no longer part of the live runtime.
#if false

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

    @Test("Stale timeout from a prior request does not deny the active confirmation")
    func staleTimeoutDoesNotDenyNewerRequest() async {
        let gate = ConfirmationGate(timeout: .milliseconds(60))
        let firstStep = AgentStep(
            description: "First",
            assignedAgent: "file",
            toolName: "read_file",
            riskLevel: .critical
        )
        let secondStep = AgentStep(
            description: "Second",
            assignedAgent: "file",
            toolName: "write_file",
            riskLevel: .critical
        )

        let firstTask = Task { @MainActor in
            await gate.requestConfirmation(for: firstStep)
        }

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(40))

        let secondTask = Task { @MainActor in
            await gate.requestConfirmation(for: secondStep)
        }

        let firstResult = await firstTask.value
        #expect(!firstResult)

        try? await Task.sleep(for: .milliseconds(30))
        #expect(gate.pendingConfirmation?.description == secondStep.description)

        gate.approve()
        let secondResult = await secondTask.value

        #expect(secondResult)
        #expect(gate.pendingConfirmation == nil)
    }
}

@Suite("ResearchPauseHandler")
@MainActor
struct ResearchPauseHandlerTests {
    @Test("Providing research resumes and clears state")
    func provideResponseClearsPending() async {
        let handler = ResearchPauseHandler(timeout: .seconds(5))

        let task = Task { @MainActor in
            await handler.requestResearch(questions: ["Q1"], context: "ctx")
        }

        await Task.yield()
        #expect(handler.activeRequest != nil)

        handler.provideResponse("answer")
        let response = await task.value

        #expect(response == "answer")
        #expect(handler.activeRequest == nil)
    }

    @Test("Timeout auto-skips and clears state")
    func timeoutSkips() async {
        let handler = ResearchPauseHandler(timeout: .milliseconds(20))

        let response = await handler.requestResearch(questions: ["Q1"], context: "ctx")

        #expect(response.isEmpty)
        #expect(handler.activeRequest == nil)
    }

    @Test("Cancellation skips and clears state")
    func cancellationSkips() async {
        let handler = ResearchPauseHandler(timeout: .seconds(5))

        let task = Task { @MainActor in
            await handler.requestResearch(questions: ["Q1"], context: "ctx")
        }

        await Task.yield()
        task.cancel()
        let response = await task.value

        #expect(response.isEmpty)
        #expect(handler.activeRequest == nil)
    }

    @Test("Stale timeout from a prior request does not skip the active research prompt")
    func staleTimeoutDoesNotSkipNewerRequest() async {
        let handler = ResearchPauseHandler(timeout: .milliseconds(60))

        let firstTask = Task { @MainActor in
            await handler.requestResearch(questions: ["Q1"], context: "ctx-1")
        }

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(40))

        let secondTask = Task { @MainActor in
            await handler.requestResearch(questions: ["Q2"], context: "ctx-2")
        }

        let firstResponse = await firstTask.value
        #expect(firstResponse.isEmpty)

        try? await Task.sleep(for: .milliseconds(30))
        #expect(handler.activeRequest?.context == "ctx-2")

        handler.provideResponse("answer-2")
        let secondResponse = await secondTask.value

        #expect(secondResponse == "answer-2")
        #expect(handler.activeRequest == nil)
    }
}
#endif
