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

    @Test("system prompt prefers direct answers when context or tool results already suffice")
    func systemPromptPrefersDirectAnswersWhenContextAlreadySuffices() {
        let prompt = HermesPromptBuilder.systemPrompt(tools: [sampleTool()])

        #expect(prompt.contains("If the answer is already in the conversation context"))
        #expect(prompt.contains("After receiving a <tool_response>"))
        #expect(prompt.contains("Never repeat the same tool call"))
    }

    @Test("system prompt keeps Hermes as a direct gateway membrane")
    func systemPromptKeepsHermesAsDirectGatewayMembrane() {
        let prompt = HermesPromptBuilder.systemPrompt(tools: [sampleTool()])

        #expect(prompt.contains("LocalAgent is the tool-call and external-intelligence membrane"))
        #expect(prompt.contains("not the graph, Rex, or the deterministic substrate authority"))
        #expect(prompt.contains("Use tools only for missing context or explicit external side effects"))
        #expect(prompt.contains("Do not route already-available local substrate answers through tools"))
    }

    @Test("system prompt preserves fast unified gateway semantics")
    func systemPromptPreservesFastUnifiedGatewaySemantics() {
        let prompt = HermesPromptBuilder.systemPrompt(tools: [sampleTool()])

        #expect(prompt.contains("LocalAgent is the single fast gateway for cloud models, CLI delegation, MCP/web tools, and explicit external side effects"))
        #expect(prompt.contains("Keep deterministic local substrate answers on the direct path"))
        #expect(prompt.contains("must not add a gateway hop when no external context is needed"))
        #expect(prompt.contains("Return external evidence as structured artifacts and provenance, not graph or Rex authority"))
    }

    @Test("system prompt separates Core local prompting from Pro external gateway")
    func systemPromptSeparatesCoreLocalPromptingFromProExternalGateway() {
        let prompt = HermesPromptBuilder.systemPrompt(tools: [sampleTool()])

        #expect(prompt.contains("Cloud/provider/CLI/MCP/browser/Docker orchestration is Pro/Research only"))
        #expect(prompt.contains("LocalAgent-family prompt formatting may stay Core-safe only when it runs in-process over local context"))
    }

    @Test("system prompt keeps explicit file paths stable for local tool loops")
    func systemPromptKeepsExplicitFilePathsStable() {
        let prompt = HermesPromptBuilder.systemPrompt(tools: [sampleTool(), writeTool(), readTool()])

        #expect(prompt.contains("File tools can use the exact filesystem path the user provided"))
        #expect(prompt.contains("including absolute paths and ~/ home expansion"))
        #expect(prompt.contains("vault-relative path inside the active managed runtime vault"))
        #expect(prompt.contains("Do not invent alternate paths, filenames, or directories."))
        #expect(prompt.contains("Use the exact path the user provided instead of rewriting it to tmp/example.txt"))
        #expect(prompt.contains("If asked to write a file and then read it back, call write_file first and then read_file on that same exact path."))
        #expect(prompt.contains("Do not answer an explicit file read/write request from the requested contents alone"))
    }

    @Test("system prompt keeps explicit vault note writes honest for local tool loops")
    func systemPromptKeepsExplicitVaultNoteWritesHonest() {
        let prompt = HermesPromptBuilder.systemPrompt(
            tools: [sampleTool(), vaultWriteTool(), vaultReadTool()]
        )

        #expect(prompt.contains("For vault note creation or updates, use vault_write"))
        #expect(prompt.contains("If the user gives a note title but not a path"))
        #expect(prompt.contains("If asked to create or update a note and then read it back"))
        #expect(prompt.contains("Do not claim a note was created, updated, or read back"))
    }

    @Test("system prompt includes an immediate file-tool example for smaller local tiers")
    func systemPromptIncludesImmediateFileToolExampleForSmallerLocalTiers() {
        let prompt = HermesPromptBuilder.systemPrompt(tools: [writeTool(), readTool()])

        #expect(prompt.contains("emit the next <tool_call> immediately"))
        #expect(prompt.contains("User: Write exactly hello to tmp/example.txt and then read it back."))
        #expect(prompt.contains(#"{"name":"write_file","arguments":{"path":"tmp/example.txt","content":"hello"}}"#))
        #expect(prompt.contains(#"{"name":"read_file","arguments":{"path":"tmp/example.txt"}}"#))
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

    private func writeTool() -> OmegaToolDefinition {
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

    private func readTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "read_file",
            agent: "file",
            description: "Read a file.",
            argumentsExample: #"{"path":"tmp/example.txt"}"#,
            schemaJson: #"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#,
            destructive: false,
            requiresConfirmation: false
        )
    }

    private func vaultWriteTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "vault_write",
            agent: "notes",
            description: "Create or update a vault note.",
            argumentsExample: #"{"path":"Quick Thought.md","content":"hello"}"#,
            schemaJson: #"{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}"#,
            destructive: false,
            requiresConfirmation: false
        )
    }

    private func vaultReadTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "vault_read",
            agent: "notes",
            description: "Read a vault note.",
            argumentsExample: #"{"path":"Quick Thought.md"}"#,
            schemaJson: #"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#,
            destructive: false,
            requiresConfirmation: false
        )
    }
}
