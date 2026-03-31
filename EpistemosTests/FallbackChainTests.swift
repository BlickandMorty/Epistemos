import Testing
@testable import Epistemos

@Suite("FallbackChainResolver")
@MainActor
struct FallbackChainTests {

    let resolver = FallbackChainResolver()

    // MARK: - GUI → CLI Fallback

    @Test("GUI click failure suggests CLI fallback")
    func clickFallback() {
        let step = makeStep(agent: "computer", tool: "click", args: ["element": "Submit Button"])
        let result = AgentStepResult.fail("Element not found", stepId: step.id, durationMs: 100)
        let fallback = resolver.resolveFallback(failedStep: step, failedResult: result)
        #expect(fallback != nil)
        #expect(fallback?.agent == "terminal")
        #expect(fallback?.toolName == "run_persistent")
    }

    @Test("GUI type failure suggests CLI fallback")
    func typeFallback() {
        let step = makeStep(agent: "computer", tool: "type", args: ["text": "hello world"])
        let result = AgentStepResult.fail("No focused element", stepId: step.id, durationMs: 50)
        let fallback = resolver.resolveFallback(failedStep: step, failedResult: result)
        #expect(fallback != nil)
        #expect(fallback?.agent == "terminal")
        #expect(fallback?.argumentsJson.contains("pbcopy") == true)
    }

    // MARK: - CLI → GUI Fallback

    @Test("CLI run_command failure suggests GUI fallback")
    func cliToGuiFallback() {
        let step = makeStep(agent: "terminal", tool: "run_command", args: ["command": "open -a Safari"])
        let result = AgentStepResult.fail("Command not in allow-list", stepId: step.id, durationMs: 10)
        let fallback = resolver.resolveFallback(failedStep: step, failedResult: result)
        #expect(fallback != nil)
        #expect(fallback?.agent == "computer")
        #expect(fallback?.toolName == "keys")
    }

    @Test("CLI run_persistent failure suggests GUI fallback")
    func persistentToGuiFallback() {
        let step = makeStep(agent: "terminal", tool: "run_persistent", args: ["command": "npm start"])
        let result = AgentStepResult.fail("Timeout", stepId: step.id, durationMs: 30000)
        let fallback = resolver.resolveFallback(failedStep: step, failedResult: result)
        #expect(fallback != nil)
        #expect(fallback?.agent == "computer")
    }

    // MARK: - Automation ↔ Computer Cross-Fallback

    @Test("Automation click_element falls back to computer click")
    func automationToComputer() {
        let step = makeStep(agent: "automation", tool: "click_element", args: ["element": "OK"])
        let result = AgentStepResult.fail("AX error", stepId: step.id, durationMs: 200)
        let fallback = resolver.resolveFallback(failedStep: step, failedResult: result)
        #expect(fallback != nil)
        #expect(fallback?.agent == "computer")
        #expect(fallback?.toolName == "click")
    }

    // MARK: - No Fallback

    @Test("No fallback for tools without mapping")
    func noFallback() {
        let step = makeStep(agent: "notes", tool: "create_note", args: ["title": "Test"])
        let result = AgentStepResult.fail("Write error", stepId: step.id, durationMs: 100)
        let fallback = resolver.resolveFallback(failedStep: step, failedResult: result)
        #expect(fallback == nil)
    }

    @Test("No fallback for search_notes")
    func noFallbackSearchNotes() {
        let step = makeStep(agent: "notes", tool: "search_notes", args: ["query": "test"])
        let result = AgentStepResult.fail("Index error", stepId: step.id, durationMs: 50)
        let fallback = resolver.resolveFallback(failedStep: step, failedResult: result)
        #expect(fallback == nil)
    }

    // MARK: - Helpers

    private func makeStep(agent: String, tool: String, args: [String: Any]) -> AgentStep {
        let argsJson: String
        if let data = try? JSONSerialization.data(withJSONObject: args),
           let json = String(data: data, encoding: .utf8) {
            argsJson = json
        } else {
            argsJson = "{}"
        }
        return AgentStep(
            id: UUID(),
            description: "test step",
            assignedAgent: agent,
            toolName: tool,
            argumentsJson: argsJson,
            riskLevel: .low,
            dependsOn: []
        )
    }
}
