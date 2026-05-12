import Foundation

nonisolated enum LocalMessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool

    var promptHeading: String {
        switch self {
        case .system: return "System"
        case .user: return "User"
        case .assistant: return "Assistant"
        case .tool: return "Tool"
        }
    }
}

nonisolated struct LocalMessage: Codable, Equatable, Sendable {
    let role: LocalMessageRole
    let content: String
}

nonisolated struct LocalToolResult: Codable, Equatable, Sendable {
    let toolName: String
    let resultJson: String
    let isError: Bool
}

nonisolated enum LocalAgentPromptBuilder {
    static func systemPrompt(
        tools: [OmegaToolDefinition],
        additionalInstructions: String? = nil,
        knowledgeIndex: String? = nil
    ) -> String {
        let tools = AgentToolNameAliases.canonicalizedDefinitions(for: tools)

        #if canImport(agent_coreFFI)
        if let prompt = rustSystemPrompt(
            tools: tools,
            additionalInstructions: additionalInstructions,
            knowledgeIndex: knowledgeIndex
        ) {
            return prompt
        }
        #endif

        let toolsJson = formattedToolsJSON(for: tools)
        let trimmedInstructions = additionalInstructions?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Knowledge index is injected FIRST for maximum attention / prefix-cache position
        var prompt = ""
        if let knowledgeIndex, !knowledgeIndex.isEmpty {
            prompt += knowledgeIndex + "\n"
        }

        prompt += """
        You are a function calling AI model. You are provided with function signatures within <tools></tools> XML tags. You may call one or more functions to assist with the user query. Don't make assumptions about what values to plug into functions. After calling and executing the functions, you will be provided with function results within <tool_response></tool_response> XML tags.
        <tools>
        \(toolsJson)
        </tools>
        For each function call, return a JSON object with function name and arguments within <tool_call></tool_call> XML tags.
        <tool_call>
        {"name": <function-name>, "arguments": <args-dict>}
        </tool_call>
        Keep hidden reasoning inside <think></think> tags. If the model falls back to legacy formatting, <scratch_pad></scratch_pad> is also allowed. Never place raw reasoning or analysis notes outside those hidden tags.
        LocalAgent is the tool-call and external-intelligence membrane; it is not the graph, Rex, or the deterministic substrate authority.
        LocalAgent is the single fast gateway for cloud models, CLI delegation, MCP/web tools, and explicit external side effects.
        \(LocalAgentGatewayPolicy.externalTierBoundaryLine)
        \(LocalAgentGatewayPolicy.localCoreBoundaryLine)
        Use tools only for missing context or explicit external side effects. Do not route already-available local substrate answers through tools.
        Keep deterministic local substrate answers on the direct path; must not add a gateway hop when no external context is needed.
        Return external evidence as structured artifacts and provenance, not graph or Rex authority.
        """

        prompt += """
        
        If the answer is already in the conversation context, attached note text, or other provided material, answer directly without calling a tool.
        After receiving a <tool_response>, summarize it for the user unless the response clearly says it failed or more information is still required.
        Never repeat the same tool call when the previous <tool_response> already gave you the needed information.
        For vault notes, never guess a filesystem path from a title. Use vault.search first and then vault.read with the returned vault-relative path.
        For vault note creation or updates, use vault.write with a human-readable vault-relative .md path and the full markdown content.
        If the user gives a note title but not a path, choose a vault-relative .md path that matches the requested title.
        If asked to create or update a note and then read it back, call vault.write first and then vault.read on that same exact note path.
        Do not claim a note was created, updated, or read back before the required <tool_response> confirms it.
        File tools can use the exact filesystem path the user provided, including absolute paths and ~/ home expansion, or a vault-relative path inside the active managed runtime vault (or ScratchVault when no vault is attached).
        Do not invent alternate paths, filenames, or directories.
        Use the exact path the user provided instead of rewriting it to tmp/example.txt or guessing a nearby path.
        If asked to write a file and then read it back, call file.write first and then file.read on that same exact path.
        Do not answer an explicit file read/write request from the requested contents alone before the required <tool_response> confirms the operation succeeded.
        For concrete file, note, or search requests, emit the next <tool_call> immediately instead of describing a plan first.
        Example:
        User: Write exactly hello to tmp/example.txt and then read it back.
        Assistant:
        <tool_call>
        {"name":"file.write","arguments":{"path":"tmp/example.txt","content":"hello"}}
        </tool_call>
        After the file.write <tool_response> arrives:
        <tool_call>
        {"name":"file.read","arguments":{"path":"tmp/example.txt"}}
        </tool_call>
        """

        if tools.isEmpty {
            prompt += "\nNo tools are available for this turn. Respond directly without emitting <tool_call> tags."
        }

        if let trimmedInstructions, !trimmedInstructions.isEmpty {
            prompt += "\n\(trimmedInstructions)"
        }

        return prompt
    }

    static func buildMessages(
        systemPrompt: String,
        history: [LocalMessage],
        toolResults: [LocalToolResult]? = nil
    ) -> [LocalMessage] {
        var messages = [LocalMessage(role: .system, content: systemPrompt)]
        messages.append(contentsOf: history)

        guard let toolResults, !toolResults.isEmpty else {
            return messages
        }

        let resultContent = toolResults
            .map { $0.wrappedResponse }
            .joined(separator: "\n")
        messages.append(LocalMessage(role: .tool, content: resultContent))
        return messages
    }

    private static func formattedToolsJSON(for tools: [OmegaToolDefinition]) -> String {
        let records = tools.map(toolRecord(for:))
        guard let data = try? JSONSerialization.data(
            withJSONObject: records,
            options: [.sortedKeys]
        ),
        let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private static func toolRecord(for tool: OmegaToolDefinition) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": tool.name,
                "description": tool.description,
                "parameters": tool.parametersSchema,
            ],
        ]
    }

    #if canImport(agent_coreFFI)
    private static func rustSystemPrompt(
        tools: [OmegaToolDefinition],
        additionalInstructions: String?,
        knowledgeIndex: String?
    ) -> String? {
        let toolRecords = tools.map { tool -> [String: Any] in
            [
                "name": tool.name,
                "description": tool.description,
                "parameters": tool.parametersSchema,
            ]
        }
        var input: [String: Any] = ["tools": toolRecords]
        if let additionalInstructions {
            input["additional_instructions"] = additionalInstructions
        }
        if let knowledgeIndex {
            input["knowledge_index"] = knowledgeIndex
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: input,
            options: [.sortedKeys]
        ),
        let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return try? runtimeBuildSystemPrompt(inputJson: json)
    }
    #endif
}

private extension OmegaToolDefinition {
    nonisolated var parametersSchema: [String: Any] {
        guard let data = schemaJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [
                "type": "object",
                "properties": [:],
            ]
        }
        return json
    }
}

private extension LocalToolResult {
    nonisolated var wrappedResponse: String {
        "<tool_response>\n\(resultJson)\n</tool_response>"
    }
}
