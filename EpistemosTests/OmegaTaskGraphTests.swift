import Testing
@testable import Epistemos

// Legacy task graph tests are kept for reference while the old Omega task
// graph implementation remains retired from the live runtime.
#if false

@Suite("TaskGraph")
@MainActor
struct TaskGraphTests {

    @Test("Starts idle and empty")
    func initialState() {
        let graph = TaskGraph()
        #expect(graph.steps.isEmpty)
        #expect(graph.results.isEmpty)
        #expect(graph.status == .idle)
        #expect(!graph.isComplete)
        #expect(!graph.hasFailed)
    }

    @Test("Adds steps correctly")
    func addSteps() {
        let graph = TaskGraph()
        let step1 = AgentStep(description: "Step 1", assignedAgent: "file", toolName: "file.read")
        let step2 = AgentStep(description: "Step 2", assignedAgent: "terminal", toolName: "action.bash")
        graph.addStep(step1)
        graph.addStep(step2)
        #expect(graph.steps.count == 2)
    }

    @Test("Ready steps returns steps with no pending dependencies")
    func readyStepsNoDeps() {
        let graph = TaskGraph()
        let step1 = AgentStep(description: "A", assignedAgent: "file", toolName: "file.read")
        let step2 = AgentStep(description: "B", assignedAgent: "terminal", toolName: "action.bash")
        graph.addStep(step1)
        graph.addStep(step2)

        let ready = graph.readySteps()
        #expect(ready.count == 2) // both have no deps
    }

    @Test("Ready steps respects dependencies")
    func readyStepsWithDeps() {
        let graph = TaskGraph()
        let step1 = AgentStep(description: "A", assignedAgent: "file", toolName: "file.read")
        let step2 = AgentStep(description: "B", assignedAgent: "terminal", toolName: "action.bash", dependsOn: [step1.id])
        graph.addStep(step1)
        graph.addStep(step2)

        var ready = graph.readySteps()
        #expect(ready.count == 1)
        #expect(ready[0].id == step1.id)

        // Complete step 1
        graph.recordResult(.ok("{}", stepId: step1.id, durationMs: 10))

        ready = graph.readySteps()
        #expect(ready.count == 1)
        #expect(ready[0].id == step2.id)
    }

    @Test("Marks complete when all steps done")
    func completion() {
        let graph = TaskGraph()
        let step = AgentStep(description: "Only", assignedAgent: "file", toolName: "file.read")
        graph.addStep(step)
        #expect(!graph.isComplete)

        graph.recordResult(.ok("{}", stepId: step.id, durationMs: 5))
        #expect(graph.isComplete)
        #expect(graph.status == .completed)
    }

    @Test("Detects failure")
    func failure() {
        let graph = TaskGraph()
        let step = AgentStep(description: "Fail", assignedAgent: "file", toolName: "file.delete")
        graph.addStep(step)

        graph.recordResult(.fail("Permission denied", stepId: step.id, durationMs: 1))
        #expect(graph.hasFailed)
        #expect(graph.status == .failed)
    }

    @Test("Reset clears steps, results, and status")
    func reset() {
        let graph = TaskGraph()
        let step = AgentStep(description: "X", assignedAgent: "file", toolName: "file.read")
        graph.addStep(step)
        graph.recordResult(.ok("{}", stepId: step.id, durationMs: 1))
        #expect(graph.isComplete)

        graph.reset()
        #expect(graph.results.isEmpty)
        #expect(graph.steps.isEmpty)
        #expect(graph.status == .idle)
        #expect(!graph.isComplete)
    }
}
#endif
