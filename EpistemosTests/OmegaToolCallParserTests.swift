import Testing
@testable import Epistemos

@Suite("ToolCallParser")
@MainActor
struct ToolCallParserTests {

    // MARK: - JSON Object Parsing

    @Test("Parses standard JSON tool call")
    func parseStandardJson() {
        let input = """
        {"name": "read_file", "arguments": {"path": "/tmp/test.txt"}}
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "read_file")
        #expect(calls[0].arguments["path"] as? String == "/tmp/test.txt")
    }

    @Test("Parses JSON with 'parameters' key instead of 'arguments'")
    func parseParametersKey() {
        let input = """
        {"name": "search_web", "parameters": {"query": "hello"}}
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "search_web")
        #expect(calls[0].arguments["query"] as? String == "hello")
    }

    // MARK: - JSON Array Parsing

    @Test("Parses array of tool calls")
    func parseArray() {
        let input = """
        [
            {"name": "open_url", "arguments": {"url": "https://apple.com"}},
            {"name": "get_page_title", "arguments": {}}
        ]
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 2)
        #expect(calls[0].name == "open_url")
        #expect(calls[1].name == "get_page_title")
    }

    // MARK: - Qwen Format

    @Test("Parses Qwen <tool_call> tags")
    func parseQwenFormat() {
        let input = """
        I'll help you with that.
        <tool_call>{"name": "list_files", "arguments": {"path": "."}}</tool_call>
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "list_files")
    }

    @Test("Parses multiple Qwen tool calls")
    func parseMultipleQwen() {
        let input = """
        <tool_call>{"name": "read_file", "arguments": {"path": "a.txt"}}</tool_call>
        Then we process it.
        <tool_call>{"name": "write_file", "arguments": {"path": "b.txt", "content": "done"}}</tool_call>
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 2)
        #expect(calls[0].name == "read_file")
        #expect(calls[1].name == "write_file")
    }

    // MARK: - Code Block Extraction

    @Test("Parses JSON from markdown code block")
    func parseCodeBlock() {
        let input = """
        Here's the plan:
        ```json
        {"name": "run_command", "arguments": {"command": "ls -la"}}
        ```
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "run_command")
    }

    // MARK: - Edge Cases

    @Test("Returns empty for plain text")
    func parsePlainText() {
        let calls = ToolCallParser.parse("Hello, how can I help you?")
        #expect(calls.isEmpty)
    }

    @Test("Returns empty for empty string")
    func parseEmpty() {
        let calls = ToolCallParser.parse("")
        #expect(calls.isEmpty)
    }

    @Test("Returns empty for malformed JSON")
    func parseMalformedJson() {
        let calls = ToolCallParser.parse("{name: broken json}")
        #expect(calls.isEmpty)
    }

    @Test("Handles JSON without name field")
    func parseNoName() {
        let calls = ToolCallParser.parse("{\"arguments\": {\"path\": \"/tmp\"}}")
        #expect(calls.isEmpty)
    }

    @Test("argumentsJson produces valid JSON string")
    func argumentsJsonOutput() {
        let input = """
        {"name": "test", "arguments": {"key": "value", "num": 42}}
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        let json = calls[0].argumentsJson
        #expect(!json.isEmpty)
        // Should be parseable JSON
        let data = json.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed != nil)
        #expect(parsed?["key"] as? String == "value")
    }
}
