import Foundation

// MARK: - Tool Call Parser

/// Pure function: parses tool call JSON from LLM output.
/// Handles multiple formats: standard JSON, Qwen <tool_call> tags, and best-effort repair.
enum ToolCallParser {

    /// Parsed tool call from LLM output.
    struct ParsedToolCall: Sendable {
        let name: String
        let arguments: [String: Any]

        var argumentsJson: String {
            guard let data = try? JSONSerialization.data(withJSONObject: arguments),
                  let str = String(data: data, encoding: .utf8) else { return "{}" }
            return str
        }
    }

    /// Parse tool calls from model output text.
    /// Tries multiple strategies in priority order.
    static func parse(_ text: String) -> [ParsedToolCall] {
        // Strategy 1: Qwen-style <tool_call> tags
        if let calls = parseQwenToolCalls(text), !calls.isEmpty {
            return calls
        }

        // Strategy 2: JSON object with "name" and "arguments" at top level
        if let call = parseJsonToolCall(text) {
            return [call]
        }

        // Strategy 3: JSON array of tool calls
        if let calls = parseJsonArrayToolCalls(text) {
            return calls
        }

        // Strategy 4: Extract JSON from markdown code blocks
        if let calls = parseFromCodeBlock(text) {
            return calls
        }

        return []
    }

    // MARK: - Qwen Format

    /// Parse Qwen-style: <tool_call>{"name":"...", "arguments":{...}}</tool_call>
    private static func parseQwenToolCalls(_ text: String) -> [ParsedToolCall]? {
        let pattern = "<tool_call>(.*?)</tool_call>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        if matches.isEmpty { return nil }

        var calls: [ParsedToolCall] = []
        for match in matches {
            let jsonStr = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let call = parseJsonToolCall(jsonStr) {
                calls.append(call)
            }
        }

        return calls.isEmpty ? nil : calls
    }

    // MARK: - JSON Object

    /// Parse a single JSON tool call: {"name":"...", "arguments":{...}}
    private static func parseJsonToolCall(_ text: String) -> ParsedToolCall? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            return nil
        }

        let arguments = json["arguments"] as? [String: Any] ?? json["parameters"] as? [String: Any] ?? [:]
        return ParsedToolCall(name: name, arguments: arguments)
    }

    // MARK: - JSON Array

    /// Parse an array of tool calls.
    private static func parseJsonArrayToolCalls(_ text: String) -> [ParsedToolCall]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = trimmed.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        var calls: [ParsedToolCall] = []
        for item in array {
            guard let name = item["name"] as? String else { continue }
            let arguments = item["arguments"] as? [String: Any] ?? item["parameters"] as? [String: Any] ?? [:]
            calls.append(ParsedToolCall(name: name, arguments: arguments))
        }

        return calls.isEmpty ? nil : calls
    }

    // MARK: - Code Block Extraction

    /// Extract JSON from markdown code blocks: ```json ... ```
    private static func parseFromCodeBlock(_ text: String) -> [ParsedToolCall]? {
        let pattern = "```(?:json)?\\s*\\n?(.*?)\\n?```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let content = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)

            // Try as single tool call
            if let call = parseJsonToolCall(content) {
                return [call]
            }

            // Try as array
            if let calls = parseJsonArrayToolCalls(content) {
                return calls
            }
        }

        return nil
    }
}
