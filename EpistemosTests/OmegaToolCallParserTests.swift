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

    @Test("Parses JSON with function and parameters keys")
    func parseFunctionParametersKey() {
        let input = """
        {"function": "neural_recall", "parameters": {"query": "Hegemony", "temporal_minutes_ago": 60}}
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "neural_recall")
        #expect(calls[0].arguments["query"] as? String == "Hegemony")
        #expect(calls[0].arguments["temporal_minutes_ago"] as? Int == 60)
    }

    @Test("Parses training-style JSON with toolName and argumentsJson")
    func parseToolNameArgumentsJson() {
        let input = #"""
        {"toolName":"run_command","argumentsJson":"{\"command\":\"git diff --stat\"}","agentName":"terminal"}
        """#
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "run_command")
        #expect(calls[0].arguments["command"] as? String == "git diff --stat")
    }

    @Test("Parses training-style JSON with tool and arguments")
    func parseToolArguments() {
        let input = """
        {"tool":"open_url","arguments":{"url":"https://apple.com"}}
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "open_url")
        #expect(calls[0].arguments["url"] as? String == "https://apple.com")
    }

    @Test("Parses uppercase wrapper keys from local model output")
    func parseUppercaseWrapperKeys() {
        let input = """
        {"NAME":"RELEASE_PROBE","ARGUMENTS":{"REQUEST":""}}
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "RELEASE_PROBE")
        #expect(calls[0].arguments["REQUEST"] as? String == "")
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

    @Test("Parses legacy Qwen XML function and parameter tags")
    func parseLegacyQwenXmlFunctionParameters() {
        let input = """
        <tool_call><function=search_web><parameter=query>agentic tool calling</parameter><parameter=limit>2</parameter></function></tool_call>
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "search_web")
        #expect(calls[0].arguments["query"] as? String == "agentic tool calling")
        #expect(calls[0].arguments["limit"] as? Int == 2)
    }

    @Test("Parses bare legacy Qwen XML function bodies")
    func parseBareLegacyQwenXmlFunctionBody() {
        let input = """
        <function=read_file><parameter=path>/tmp/test.txt</parameter></function>
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "read_file")
        #expect(calls[0].arguments["path"] as? String == "/tmp/test.txt")
    }

    @Test("Parses structured scratch pad tool plans without surfacing them as raw XML")
    func parseStructuredScratchPadToolPlan() {
        let input = """
        <scratch_pad>
        <name>vault_recall</name>
        <arguments>
        <query>Metal and Rust neuroscience</query>
        <top_k>5</top_k>
        </arguments>
        </scratch_pad>
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "vault_recall")
        #expect(calls[0].arguments["query"] as? String == "Metal and Rust neuroscience")
        #expect(calls[0].arguments["top_k"] as? Int == 5)
    }

    @Test("Repairs malformed XML-like tool call bodies from local models")
    func parseMalformedXmlLikeToolCallBody() {
        let input = """
        <tool_call<name>read_file</name<arguments><path>~/workspace/neurology/metal_philosophy_notes.txt</path><limit>500</limit><offset>1</offset></arguments></tool_call>
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "read_file")
        #expect(calls[0].arguments["path"] as? String == "~/workspace/neurology/metal_philosophy_notes.txt")
        #expect(calls[0].arguments["limit"] as? Int == 500)
        #expect(calls[0].arguments["offset"] as? Int == 1)
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

    @Test("Parses JSON from tool_call fenced code block")
    func parseToolCallFence() {
        let input = """
        ```tool_call
        {"name":"read_file","arguments":{"path":"All Things Must Go"}}
        ```
        """
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "read_file")
        #expect(calls[0].arguments["path"] as? String == "All Things Must Go")
    }

    @Test("Parses training-style JSON from inline markdown code")
    func parseInlineMarkdownCode() {
        let input = #"""
        **[ACT]:** `{"toolName":"read_file","argumentsJson":"{\"path\":\"CLAUDE.md\"}","agentName":"file"}`
        """#
        let calls = ToolCallParser.parse(input)
        #expect(calls.count == 1)
        #expect(calls[0].name == "read_file")
        #expect(calls[0].arguments["path"] as? String == "CLAUDE.md")
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
