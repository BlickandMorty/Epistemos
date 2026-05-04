import Foundation

// MARK: - Tool Call Parser

/// Pure function: parses tool call JSON from LLM output.
/// Handles multiple formats: standard JSON, Qwen <tool_call> tags, and best-effort repair.
nonisolated enum ToolCallParser {

    /// Parsed tool call from LLM output.
    nonisolated struct ParsedToolCall {
        let name: String
        let arguments: [String: Any]

        var argumentsJson: String {
            guard let data = try? JSONSerialization.data(withJSONObject: arguments),
                  let str = String(data: data, encoding: .utf8) else { return "{}" }
            return str.replacingOccurrences(of: "\\/", with: "/")
        }
    }

    /// Parse tool calls from model output text.
    /// Tries multiple strategies in priority order.
    static func parse(_ text: String) -> [ParsedToolCall] {
        #if canImport(agent_coreFFI)
        if let calls = parseWithRustHermes(text), !calls.isEmpty {
            return calls
        }
        #endif

        // Strategy 1: Qwen-style <tool_call> tags
        if let calls = parseQwenToolCalls(text), !calls.isEmpty {
            return calls
        }

        // Strategy 1b: legacy Qwen XML function/parameter tags
        if let calls = parseLegacyQwenXmlToolCalls(text), !calls.isEmpty {
            return calls
        }

        // Strategy 1c: structured XML-like plans emitted by smaller local models
        if let calls = parseStructuredXmlToolCalls(text), !calls.isEmpty {
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

        // Strategy 5: Extract JSON from inline markdown code spans
        if let calls = parseFromInlineCode(text) {
            return calls
        }

        // Strategy 6: Recover valid JSON tool calls embedded inside
        // reasoning tags or surrounding prose.
        if let calls = parseEmbeddedJsonFragments(text) {
            return calls
        }

        return []
    }

    #if canImport(agent_coreFFI)
    private struct RustHermesToolCall: Decodable {
        let name: String
        let argumentsJson: String

        private enum CodingKeys: String, CodingKey {
            case name
            case argumentsJson = "arguments_json"
        }
    }

    private static func parseWithRustHermes(_ text: String) -> [ParsedToolCall]? {
        guard let json = try? hermesParseToolCalls(text: text),
              let data = json.data(using: .utf8),
              let calls = try? JSONDecoder().decode([RustHermesToolCall].self, from: data) else {
            return nil
        }

        return calls.compactMap { call in
            guard let data = call.argumentsJson.data(using: .utf8),
                  let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return ParsedToolCall(name: call.name, arguments: [:])
            }
            return ParsedToolCall(name: call.name, arguments: args)
        }
    }
    #endif

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

    /// Parse legacy Qwen XML tool calls:
    /// `<tool_call><function=name><parameter=key>value</parameter></function></tool_call>`
    private static func parseLegacyQwenXmlToolCalls(_ text: String) -> [ParsedToolCall]? {
        let pattern = #"(?:<tool_call>\s*)?<function=([^>]+)>(.*?)</function>(?:\s*</tool_call>)?"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        if matches.isEmpty { return nil }

        var calls: [ParsedToolCall] = []
        calls.reserveCapacity(matches.count)

        for match in matches {
            let rawName = nsText.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let functionBody = nsText.substring(with: match.range(at: 2))

            guard !rawName.isEmpty else { continue }

            let parameters = parseLegacyQwenXmlParameters(functionBody)
            calls.append(ParsedToolCall(name: rawName, arguments: parameters))
        }

        return calls.isEmpty ? nil : calls
    }

    private static func parseLegacyQwenXmlParameters(_ text: String) -> [String: Any] {
        let pattern = #"<parameter=([^>]+)>(.*?)</parameter>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            return [:]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return [:] }

        var parameters: [String: Any] = [:]
        parameters.reserveCapacity(matches.count)

        for match in matches {
            let rawKey = nsText.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawKey.isEmpty else { continue }

            let rawValue = nsText.substring(with: match.range(at: 2))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            parameters[rawKey] = coerceLegacyQwenXmlValue(rawValue)
        }

        return parameters
    }

    private static func coerceLegacyQwenXmlValue(_ value: String) -> Any {
        if value.isEmpty {
            return ""
        }

        if let data = value.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
           ) {
            return parsed
        }

        switch value.lowercased() {
        case "true":
            return true
        case "false":
            return false
        case "null":
            return NSNull()
        default:
            break
        }

        if let intValue = Int(value) {
            return intValue
        }
        if let doubleValue = Double(value), doubleValue.isFinite {
            return doubleValue
        }

        return value
    }

    // MARK: - Structured XML-like Plans

    /// Parse local-model XML-ish plans such as:
    /// `<scratch_pad><name>vault_recall</name><arguments><query>...</query></arguments></scratch_pad>`
    /// and malformed variants like:
    /// `<tool_call<name>read_file</name<arguments>...</arguments></tool_call>`
    private static func parseStructuredXmlToolCalls(_ text: String) -> [ParsedToolCall]? {
        let normalized = normalizeLooseXml(text)
        let candidates = candidateStructuredXmlBodies(from: normalized)

        var calls: [ParsedToolCall] = []
        calls.reserveCapacity(candidates.count)

        for candidate in candidates {
            guard let name = extractSimpleXmlTag(named: "name", in: candidate),
                  !name.isEmpty else {
                continue
            }

            let argumentsBody = extractSimpleXmlTag(named: "arguments", in: candidate) ?? ""
            let arguments = parseStructuredXmlArguments(argumentsBody)
            calls.append(
                ParsedToolCall(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    arguments: arguments
                )
            )
        }

        return calls.isEmpty ? nil : calls
    }

    private static func normalizeLooseXml(_ text: String) -> String {
        var normalized = text
        normalized = normalized.replacingOccurrences(
            of: "<tool_call<",
            with: "<tool_call><"
        )
        normalized = normalized.replacingOccurrences(
            of: #"</([A-Za-z0-9_:-]+)<"#,
            with: "</$1><",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"<([A-Za-z0-9_:-]+)\s*/>"#,
            with: "<$1></$1>",
            options: .regularExpression
        )
        return normalized
    }

    private static func candidateStructuredXmlBodies(from text: String) -> [String] {
        let wrapperPattern = #"<(?:tool_call|scratch_pad)>(.*?)</(?:tool_call|scratch_pad)>"#
        guard let regex = try? NSRegularExpression(
            pattern: wrapperPattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            return [text]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return [text]
        }

        let extracted = matches.map {
            nsText.substring(with: $0.range(at: 1))
        }

        return extracted.isEmpty ? [text] : extracted
    }

    private static func extractSimpleXmlTag(
        named tagName: String,
        in text: String
    ) -> String? {
        let escapedTag = NSRegularExpression.escapedPattern(for: tagName)
        let pattern = #"<\#(escapedTag)>(.*?)</\#(escapedTag)>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseStructuredXmlArguments(_ text: String) -> [String: Any] {
        guard !text.isEmpty else { return [:] }

        let pattern = #"<([A-Za-z0-9_:-]+)>(.*?)</\1>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            return [:]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return [:] }

        var arguments: [String: Any] = [:]
        arguments.reserveCapacity(matches.count)

        for match in matches {
            let rawKey = nsText.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawKey.isEmpty else { continue }
            let rawValue = nsText.substring(with: match.range(at: 2))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            arguments[rawKey] = coerceLegacyQwenXmlValue(rawValue)
        }

        return arguments
    }

    // MARK: - JSON Object

    /// Parse a single JSON tool call: {"name":"...", "arguments":{...}}
    private static func parseJsonToolCall(_ text: String) -> ParsedToolCall? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return parsedToolCall(from: json)
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
            guard let call = parsedToolCall(from: item) else { continue }
            calls.append(call)
        }

        return calls.isEmpty ? nil : calls
    }

    // MARK: - Code Block Extraction

    /// Extract JSON from markdown code blocks: ```json ... ```
    private static func parseFromCodeBlock(_ text: String) -> [ParsedToolCall]? {
        let pattern = "```(?:json|tool_call)?\\s*\\n?(.*?)\\n?```"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else {
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

    /// Extract JSON from inline markdown code spans: `{"toolName":"...", ...}`
    private static func parseFromInlineCode(_ text: String) -> [ParsedToolCall]? {
        let pattern = #"`([^`\n]+)`"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let content = nsText.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let call = parseJsonToolCall(content) {
                return [call]
            }

            if let calls = parseJsonArrayToolCalls(content) {
                return calls
            }
        }

        return nil
    }

    private static func parseEmbeddedJsonFragments(_ text: String) -> [ParsedToolCall]? {
        let fragments = embeddedJsonFragments(in: text)
        guard !fragments.isEmpty else { return nil }

        for fragment in fragments {
            if let call = parseJsonToolCall(fragment) {
                return [call]
            }

            if let calls = parseJsonArrayToolCalls(fragment) {
                return calls
            }
        }

        return nil
    }

    private static func embeddedJsonFragments(in text: String) -> [String] {
        let characters = Array(text)
        guard !characters.isEmpty else { return [] }

        var fragments: [String] = []
        var index = 0
        while index < characters.count {
            let character = characters[index]
            guard character == "{" || character == "[" else {
                index += 1
                continue
            }

            guard let endIndex = matchingJsonEnd(in: characters, startingAt: index) else {
                index += 1
                continue
            }

            let fragment = String(characters[index...endIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !fragment.isEmpty {
                fragments.append(fragment)
            }
            index = endIndex + 1
        }

        return fragments
    }

    private static func matchingJsonEnd(
        in characters: [Character],
        startingAt startIndex: Int
    ) -> Int? {
        var stack: [Character] = [characters[startIndex]]
        var isInsideString = false
        var isEscaped = false
        var index = startIndex + 1

        while index < characters.count {
            let character = characters[index]
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
                index += 1
                continue
            }

            switch character {
            case "\"":
                isInsideString = true
            case "{", "[":
                stack.append(character)
            case "}":
                guard stack.last == "{" else { return nil }
                stack.removeLast()
                if stack.isEmpty {
                    return index
                }
            case "]":
                guard stack.last == "[" else { return nil }
                stack.removeLast()
                if stack.isEmpty {
                    return index
                }
            default:
                break
            }
            index += 1
        }

        return nil
    }

    private static func parsedToolCall(from json: [String: Any]) -> ParsedToolCall? {
        if let name = stringValue(forCaseInsensitiveKey: "name", in: json) {
            let arguments = dictionaryValue(forCaseInsensitiveKey: "arguments", in: json)
                ?? dictionaryValue(forCaseInsensitiveKey: "parameters", in: json)
                ?? [:]
            return ParsedToolCall(name: name, arguments: arguments)
        }

        if let function = stringValue(forCaseInsensitiveKey: "function", in: json) {
            let arguments = dictionaryValue(forCaseInsensitiveKey: "arguments", in: json)
                ?? dictionaryValue(forCaseInsensitiveKey: "parameters", in: json)
                ?? parseArgumentsJSONString(value(forCaseInsensitiveKey: "argumentsJson", in: json))
                ?? parseArgumentsJSONString(value(forCaseInsensitiveKey: "parametersJson", in: json))
                ?? [:]
            return ParsedToolCall(name: function, arguments: arguments)
        }

        if let toolName = stringValue(forCaseInsensitiveKey: "toolName", in: json) {
            let arguments = dictionaryValue(forCaseInsensitiveKey: "arguments", in: json)
                ?? dictionaryValue(forCaseInsensitiveKey: "parameters", in: json)
                ?? parseArgumentsJSONString(value(forCaseInsensitiveKey: "argumentsJson", in: json))
                ?? [:]
            return ParsedToolCall(name: toolName, arguments: arguments)
        }

        if let tool = stringValue(forCaseInsensitiveKey: "tool", in: json) {
            let arguments = dictionaryValue(forCaseInsensitiveKey: "arguments", in: json)
                ?? dictionaryValue(forCaseInsensitiveKey: "args", in: json)
                ?? [:]
            return ParsedToolCall(name: tool, arguments: arguments)
        }

        return nil
    }

    private static func parseArgumentsJSONString(_ value: Any?) -> [String: Any]? {
        guard let raw = value as? String,
              let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private static func value(
        forCaseInsensitiveKey key: String,
        in json: [String: Any]
    ) -> Any? {
        if let exact = json[key] {
            return exact
        }

        let loweredKey = key.lowercased()
        return json.first { candidate, _ in
            candidate.lowercased() == loweredKey
        }?.value
    }

    private static func stringValue(
        forCaseInsensitiveKey key: String,
        in json: [String: Any]
    ) -> String? {
        value(forCaseInsensitiveKey: key, in: json) as? String
    }

    private static func dictionaryValue(
        forCaseInsensitiveKey key: String,
        in json: [String: Any]
    ) -> [String: Any]? {
        value(forCaseInsensitiveKey: key, in: json) as? [String: Any]
    }
}
