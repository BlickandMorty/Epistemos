import Testing
@testable import Epistemos

@Suite("Local Tool Grammar")
struct LocalToolGrammarTests {
    @Test("known constellation model ids resolve native grammars")
    func knownConstellationModelIDsResolveNativeGrammars() {
        let cases: [(String?, LocalToolGrammar.NativeToolGrammar)] = [
            (nil, .canonicalXML),
            ("mlx-community/Qwen3-8B-4bit", .qwenXML),
            ("NousResearch/Hermes-3-Llama-3.1-8B", .hermesJSON),
            ("mlx-community/DeepSeek_Coder-V2-Lite-Instruct-4bit", .deepSeekCoder),
            ("meta-llama/Llama_3_3-70B-Instruct-4bit", .llama33),
            ("mistralai/Mistral Small 3.1-24B-Instruct-2503", .mistralSmall),
            ("microsoft/Phi_4-mini-instruct", .phi4Mini),
            ("microsoft/Phi_4", .phi4),
        ]

        for (modelID, expected) in cases {
            #expect(
                LocalToolGrammar.nativeGrammar(forModelID: modelID) == expected,
                "modelID \(modelID ?? "nil") should resolve \(expected.rawValue)"
            )
        }
    }

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

    @Test("tool calling plan canonicalizes legacy names before constrained prompting")
    func toolCallingPlanCanonicalizesLegacyNamesBeforeConstrainedPrompting() {
        let plan = LocalToolGrammar.buildToolCallingPlan(
            tools: [legacySearchTool(), legacyWriteTool()],
            forceThinking: true
        )

        #expect(plan.fallbackGrammar.validToolNames == ["vault.search", "file.write"])
        #expect(plan.fallbackGrammar.sourceSchema.contains("\"vault.search\""))
        #expect(plan.fallbackGrammar.sourceSchema.contains("\"file.write\""))
        #expect(!plan.fallbackGrammar.sourceSchema.contains("vault_search"))
        #expect(!plan.fallbackGrammar.sourceSchema.contains("write_file"))
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

    private func legacySearchTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "vault_search",
            agent: "notes",
            description: "Search the vault.",
            argumentsExample: #"{"query":"transformers"}"#,
            schemaJson: #"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}"#,
            destructive: false,
            requiresConfirmation: false
        )
    }

    private func legacyWriteTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "write_file",
            agent: "file",
            description: "Write a file.",
            argumentsExample: #"{"path":"tmp/example.txt","content":"hello"}"#,
            schemaJson: #"{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}"#,
            destructive: false,
            requiresConfirmation: false
        )
    }
}
