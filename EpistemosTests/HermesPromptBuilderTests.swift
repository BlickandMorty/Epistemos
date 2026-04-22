import Foundation
import Testing
@testable import Epistemos

@Suite("Hermes Prompt Builder")
struct HermesPromptBuilderTests {
    @Test("system prompt wraps tool definitions in Hermes XML tags")
    func systemPromptWrapsToolDefinitionsInHermesXMLTags() {
        let prompt = HermesPromptBuilder.systemPrompt(tools: [sampleTool()])

        #expect(prompt.contains("<tools>"))
        #expect(prompt.contains("</tools>"))
        #expect(prompt.contains("<tool_call>"))
        #expect(prompt.contains("</tool_call>"))
        #expect(prompt.contains("<tool_response>"))
        #expect(prompt.contains("</tool_response>"))
        #expect(prompt.contains("<think></think>"))
        #expect(prompt.contains("Never place raw reasoning"))
        #expect(prompt.contains("\"name\":\"vault_search\""))
        #expect(prompt.contains("Semantic plus keyword hybrid search"))
    }

    @Test("build messages prepends system prompt and appends tool responses")
    func buildMessagesPrependsSystemPromptAndAppendsToolResponses() {
        let history = [
            LocalMessage(role: .user, content: "Find transformer notes."),
            LocalMessage(role: .assistant, content: "<scratch_pad>Searching.</scratch_pad>"),
        ]
        let toolResults = [
            LocalToolResult(
                toolName: "vault_search",
                resultJson: #"{"name":"vault_search","content":[{"path":"ml/transformers.md"}]}"#,
                isError: false
            ),
        ]

        let messages = HermesPromptBuilder.buildMessages(
            systemPrompt: "SYSTEM",
            history: history,
            toolResults: toolResults
        )

        #expect(messages.count == 4)
        #expect(messages[0].role == .system)
        #expect(messages[0].content == "SYSTEM")
        #expect(messages[1].role == .user)
        #expect(messages[2].role == .assistant)
        #expect(messages[3].role == .tool)
        #expect(messages[3].content.contains("<tool_response>"))
        #expect(messages[3].content.contains("\"name\":\"vault_search\""))
    }

    @Test("system prompt falls back to empty parameters for malformed schema")
    func systemPromptFallsBackToEmptyParametersForMalformedSchema() {
        let malformedTool = OmegaToolDefinition(
            name: "broken_tool",
            agent: "file",
            description: "Test malformed schema handling",
            argumentsExample: "{}",
            schemaJson: "{not valid json",
            destructive: false,
            requiresConfirmation: false
        )

        let prompt = HermesPromptBuilder.systemPrompt(tools: [malformedTool])

        #expect(prompt.contains("\"name\":\"broken_tool\""))
        #expect(prompt.contains("\"parameters\":{"))
    }

    @Test("system prompt carries direct-response guidance when no tools exist")
    func systemPromptCarriesDirectResponseGuidanceWhenNoToolsExist() {
        let prompt = HermesPromptBuilder.systemPrompt(
            tools: [],
            additionalInstructions: "Return ONLY valid JSON."
        )

        #expect(prompt.contains("<tools>"))
        // Empty tools array is pretty-printed by JSONSerialization as "[\n\n]", not "[]"
        #expect(prompt.contains("["))
        #expect(prompt.contains("]"))
        #expect(prompt.contains("No tools are available for this turn."))
        #expect(prompt.contains("Return ONLY valid JSON."))
    }

    private func sampleTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "vault_search",
            agent: "notes",
            description: "Semantic plus keyword hybrid search across the vault.",
            argumentsExample: #"{"query":"transformers"}"#,
            schemaJson: #"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}"#,
            destructive: false,
            requiresConfirmation: false
        )
    }
}
