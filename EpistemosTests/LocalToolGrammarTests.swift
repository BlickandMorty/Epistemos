import Foundation
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

    @Test("Tri-Fusion mutation tool is confirmation gated and schema scoped")
    func triFusionMutationToolIsConfirmationGatedAndSchemaScoped() throws {
        let tool = LocalToolGrammar.triFusionMutationToolDefinition()

        #expect(tool.name == LocalToolGrammar.triFusionMutationToolName)
        #expect(tool.requiresConfirmation)
        #expect(!tool.destructive)

        let schema = try parsedJSONObject(tool.schemaJson)
        let required = try #require(schema["required"] as? [String])
        #expect(Set(required).isSuperset(of: [
            "mutation_id",
            "document_id",
            "base_document_hash",
            "actor",
            "source_format",
            "kind",
            "artifact_id",
            "rationale",
        ]))

        let properties = try #require(schema["properties"] as? [String: Any])
        #expect(properties["patch"] == nil)
        #expect(properties["diff"] == nil)
        #expect(properties["raw_markdown"] == nil)
        #expect(properties["raw_html"] == nil)
        #expect(properties["before_text"] == nil)
        #expect(properties["after_text"] == nil)

        let sourceFormat = try #require(properties["source_format"] as? [String: Any])
        #expect(sourceFormat["enum"] as? [String] == LocalToolGrammar.triFusionSourceFormats)

        let kind = try #require(properties["kind"] as? [String: Any])
        #expect(kind["enum"] as? [String] == LocalToolGrammar.triFusionMutationKinds)

        let oneOf = try #require(schema["oneOf"] as? [[String: Any]])
        #expect(oneOf.count == LocalToolGrammar.triFusionMutationKinds.count)
        for expectedKind in LocalToolGrammar.triFusionMutationKinds {
            #expect(oneOf.contains { variant in
                guard let properties = variant["properties"] as? [String: Any],
                      let kind = properties["kind"] as? [String: Any],
                      let cases = kind["enum"] as? [String] else {
                    return false
                }
                return cases == [expectedKind]
            })
        }
    }

    @Test("Tri-Fusion mutation tool activates constrained planning guidance")
    func triFusionMutationToolActivatesConstrainedPlanningGuidance() {
        let plan = LocalToolGrammar.buildToolCallingPlan(
            tools: [LocalToolGrammar.triFusionMutationToolDefinition()],
            forceThinking: true
        )

        #expect(plan.fallbackGrammar.validToolNames == [LocalToolGrammar.triFusionMutationToolName])
        #expect(plan.fallbackGrammar.sourceSchema.contains("insert_block"))
        #expect(plan.fallbackGrammar.sourceSchema.contains("transclude_block"))
        #expect(plan.notes.contains {
            $0.contains("Tri-Fusion mutation grammar is active")
                && $0.contains(LocalToolGrammar.triFusionMutationToolName)
        })
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

    private func parsedJSONObject(_ json: String) throws -> [String: Any] {
        let data = Data(json.utf8)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
