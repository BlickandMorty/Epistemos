import Foundation

nonisolated enum LocalMessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool
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

nonisolated enum HermesPromptBuilder {
    static func systemPrompt(
        tools: [OmegaToolDefinition],
        additionalInstructions: String? = nil
    ) -> String {
        let toolsJson = formattedToolsJSON(for: tools)
        let trimmedInstructions = additionalInstructions?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var prompt = """
        You are a function calling AI model. You are provided with function signatures within <tools></tools> XML tags. You may call one or more functions to assist with the user query. Don't make assumptions about what values to plug into functions. After calling and executing the functions, you will be provided with function results within <tool_response></tool_response> XML tags.
        <tools>
        \(toolsJson)
        </tools>
        For each function call, return a JSON object with function name and arguments within <tool_call></tool_call> XML tags.
        <tool_call>
        {"name": <function-name>, "arguments": <args-dict>}
        </tool_call>
        Use <scratch_pad></scratch_pad> for your reasoning before calling functions.
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
