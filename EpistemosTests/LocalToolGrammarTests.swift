import Testing
@testable import Epistemos

@Suite("Local Tool Grammar")
struct LocalToolGrammarTests {
    @Test("tool calling plan keeps the fallback allowlist aligned")
    func toolCallingPlanKeepsTheFallbackAllowlistAligned() {
        let plan = LocalToolGrammar.buildToolCallingPlan(
            tools: [sampleTool()],
            forceThinking: true
        )

        #expect(plan.fallbackGrammar.validToolNames == ["vault.search"])
        #expect(plan.supportsTrueMasking == LocalToolGrammar.supportsStructuredToolCalling)
        #expect(
            plan.backend == (
                LocalToolGrammar.supportsStructuredToolCalling ? .mlxStructured : .omegaSoftGuidance
            )
        )
    }

    @Test("malformed schemas degrade without dropping the tool name")
    func malformedSchemasDegradeWithoutDroppingTheToolName() {
        let plan = LocalToolGrammar.buildToolCallingPlan(
            tools: [malformedTool()],
            forceThinking: false
        )

        #expect(plan.fallbackGrammar.validToolNames == ["broken_tool"])
        #expect(!plan.notes.isEmpty)
    }

    private func sampleTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "vault.search",
            agent: "notes",
            description: "Search the vault.",
            argumentsExample: #"{"query":"transformers"}"#,
            schemaJson: #"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}"#,
            destructive: false,
            requiresConfirmation: false
        )
    }

    private func malformedTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "broken_tool",
            agent: "notes",
            description: "Malformed schema path.",
            argumentsExample: "{}",
            schemaJson: "{not valid json",
            destructive: false,
            requiresConfirmation: false
        )
    }
}
