import Foundation
import Testing
@testable import Epistemos

// Legacy Omega planning/runtime permission tests are kept for reference while
// the retired planning service types are no longer shipped.
#if false

@Suite("Omega Planning Service")
@MainActor
struct OmegaPlanningServiceTests {
    @Test("planning attempt times out slow local generation")
    func planningAttemptTimesOut() async {
        let result = await OmegaPlanningService.runPlanningAttempt(timeout: .milliseconds(50)) {
            try await Task.sleep(for: .milliseconds(200))
            return "late"
        }

        switch result {
        case .timedOut:
            break
        case .success:
            Issue.record("Expected planning attempt to time out")
        case .failure(let error):
            Issue.record("Expected timeout, got error: \(error)")
        }
    }

    @Test("plain research task does not preemptively require computer-use permissions")
    func runtimePermissionsForPlainResearch() {
        let requirements = AgentRuntimePermissionRequirements.forContext(
            taskDescription: "research: hegemony",
            plannedSteps: []
        )

        #expect(!requirements.needsAccessibility)
        #expect(!requirements.needsScreenRecording)
        #expect(!requirements.needsAutomation)
        #expect(!requirements.requiresAny)
    }

    @Test("automation tools require accessibility and automation permissions")
    func runtimePermissionsForAutomationTools() {
        let step = AgentStep(
            description: "Click Login",
            assignedAgent: "automation",
            toolName: "click_element"
        )

        let requirements = AgentRuntimePermissionRequirements.forContext(
            taskDescription: "",
            plannedSteps: [step]
        )

        #expect(requirements.needsAccessibility)
        #expect(requirements.needsAutomation)
        #expect(!requirements.needsScreenRecording)
    }

    @Test("screen capture tools require screen recording permission")
    func runtimePermissionsForScreenCaptureTools() {
        let step = AgentStep(
            description: "Capture window",
            assignedAgent: "computer",
            toolName: "screenshot"
        )

        let requirements = AgentRuntimePermissionRequirements.forContext(
            taskDescription: "",
            plannedSteps: [step]
        )

        #expect(!requirements.needsAccessibility)
        #expect(requirements.needsScreenRecording)
        #expect(!requirements.needsAutomation)
    }
}
#endif
