import Testing
@testable import Epistemos

@Suite("ODIA Trace Generator")
@MainActor
struct ODIATraceTests {

    @Test("Generates traces from successful results")
    func generateSuccessTraces() {
        let generator = StructuredODIATraceGenerator()
        let step = AgentStep(description: "Read file", assignedAgent: "file", toolName: "read_file", argumentsJson: "{\"path\":\"test.txt\"}")
        let result = AgentStepResult.ok("{\"content\":\"hello\"}", stepId: step.id, durationMs: 42, confidence: 0.95)

        let traces = generator.generateStructuredTraces(from: [result], taskDescription: "Read a file", steps: [step])
        #expect(traces.count == 1)
        #expect(traces[0].observe.taskDescription == "Read a file")
        #expect(traces[0].decide.agentName == "file")
        #expect(traces[0].decide.toolName == "read_file")
        #expect(traces[0].decide.confidence == 0.95)
        #expect(traces[0].interact.toolCall == "read_file")
        #expect(traces[0].assess.success)
    }

    @Test("Filters out failed results")
    func filterFailures() {
        let generator = StructuredODIATraceGenerator()
        let step = AgentStep(description: "Fail", assignedAgent: "file", toolName: "delete_file")
        let result = AgentStepResult.fail("Permission denied", stepId: step.id, durationMs: 1)

        let traces = generator.generateStructuredTraces(from: [result], taskDescription: "Delete", steps: [step])
        #expect(traces.isEmpty) // Failed results excluded from training
    }

    @Test("Handles multiple steps")
    func multipleSteps() {
        let generator = StructuredODIATraceGenerator()
        let step1 = AgentStep(description: "Step 1", assignedAgent: "file", toolName: "read_file")
        let step2 = AgentStep(description: "Step 2", assignedAgent: "terminal", toolName: "run_command")
        let r1 = AgentStepResult.ok("{}", stepId: step1.id, durationMs: 10)
        let r2 = AgentStepResult.ok("{}", stepId: step2.id, durationMs: 20)

        let traces = generator.generateStructuredTraces(from: [r1, r2], taskDescription: "Multi", steps: [step1, step2])
        #expect(traces.count == 2)
        #expect(traces[0].observe.stepIndex == 0)
        #expect(traces[1].observe.stepIndex == 1)
        #expect(traces[0].observe.totalSteps == 2)
    }

    @Test("toJSONL produces valid JSONL")
    func jsonlOutput() {
        let generator = StructuredODIATraceGenerator()
        let step = AgentStep(description: "Test", assignedAgent: "file", toolName: "read_file")
        let result = AgentStepResult.ok("{}", stepId: step.id, durationMs: 5)
        let traces = generator.generateStructuredTraces(from: [result], taskDescription: "Test", steps: [step])

        let jsonl = generator.toJSONL(traces)
        #expect(!jsonl.isEmpty)
        // Each line should be valid JSON
        for line in jsonl.split(separator: "\n") {
            let data = Data(line.utf8)
            let parsed = try? JSONSerialization.jsonObject(with: data)
            #expect(parsed != nil, "Line should be valid JSON: \(line)")
        }
    }

    @Test("Empty results produce no traces")
    func emptyResults() {
        let generator = StructuredODIATraceGenerator()
        let traces = generator.generateStructuredTraces(from: [], taskDescription: "Nothing", steps: [])
        #expect(traces.isEmpty)
        #expect(generator.toJSONL(traces).isEmpty)
    }
}
