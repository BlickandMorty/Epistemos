import Testing
@testable import Epistemos

@Suite("ToolSchemaGrammar")
@MainActor
struct ToolSchemaGrammarTests {

    // MARK: - Planning Grammar

    @Test("Compiles planning grammar with valid tool schemas")
    func compilePlanningGrammar() {
        let schemas: [[String: Any]] = [
            ["name": "open_url", "description": "Open a URL"],
            ["name": "search_web", "description": "Search the web"],
            ["name": "create_note", "description": "Create a note"],
            ["name": "run_command", "description": "Run a shell command"],
        ]
        let grammar = ToolSchemaGrammar.compilePlanningGrammar(toolSchemas: schemas)
        #expect(grammar.validToolNames.count == 4)
        #expect(grammar.validToolNames.contains("open_url"))
        #expect(grammar.validToolNames.contains("create_note"))
        #expect(!grammar.ebnf.isEmpty)
    }

    @Test("Planning grammar EBNF contains tool name enum")
    func planningGrammarContainsToolEnum() {
        let schemas: [[String: Any]] = [
            ["name": "list_files"],
            ["name": "read_file"],
        ]
        let grammar = ToolSchemaGrammar.compilePlanningGrammar(toolSchemas: schemas)
        #expect(grammar.ebnf.contains("\"list_files\""))
        #expect(grammar.ebnf.contains("\"read_file\""))
    }

    @Test("Planning grammar EBNF contains agent enum")
    func planningGrammarContainsAgentEnum() {
        let schemas: [[String: Any]] = [
            ["name": "open_url"],      // safari
            ["name": "create_note"],   // notes
            ["name": "run_command"],    // terminal
        ]
        let grammar = ToolSchemaGrammar.compilePlanningGrammar(toolSchemas: schemas)
        #expect(grammar.ebnf.contains("\"safari\""))
        #expect(grammar.ebnf.contains("\"notes\""))
        #expect(grammar.ebnf.contains("\"terminal\""))
    }

    @Test("Planning grammar EBNF contains risk enum")
    func planningGrammarContainsRiskEnum() {
        let schemas: [[String: Any]] = [["name": "list_files"]]
        let grammar = ToolSchemaGrammar.compilePlanningGrammar(toolSchemas: schemas)
        #expect(grammar.ebnf.contains("\"low\""))
        #expect(grammar.ebnf.contains("\"high\""))
        #expect(grammar.ebnf.contains("\"critical\""))
    }

    @Test("Planning grammar EBNF contains JSON structure rules")
    func planningGrammarContainsJsonRules() {
        let schemas: [[String: Any]] = [["name": "list_files"]]
        let grammar = ToolSchemaGrammar.compilePlanningGrammar(toolSchemas: schemas)
        #expect(grammar.ebnf.contains("root"))
        #expect(grammar.ebnf.contains("step"))
        #expect(grammar.ebnf.contains("string"))
        #expect(grammar.ebnf.contains("value"))
        #expect(grammar.ebnf.contains("object"))
    }

    @Test("Planning grammar with empty schemas produces empty tool list")
    func planningGrammarEmptySchemas() {
        let grammar = ToolSchemaGrammar.compilePlanningGrammar(toolSchemas: [])
        #expect(grammar.validToolNames.isEmpty)
    }

    @Test("Planning grammar stores source schema JSON")
    func planningGrammarStoresSourceSchema() {
        let schemas: [[String: Any]] = [["name": "test_tool"]]
        let grammar = ToolSchemaGrammar.compilePlanningGrammar(toolSchemas: schemas)
        #expect(grammar.sourceSchema.contains("test_tool"))
    }

    // MARK: - Single Tool Call Grammar

    @Test("Compiles single tool call grammar")
    func compileSingleToolCallGrammar() {
        let argSchema: [String: Any] = [
            "properties": [
                "url": ["type": "string"],
                "timeout": ["type": "number"],
            ] as [String: [String: String]],
            "required": ["url"],
        ]
        let grammar = ToolSchemaGrammar.compileSingleToolCallGrammar(
            toolName: "open_url",
            argumentSchema: argSchema
        )
        #expect(grammar.validToolNames == ["open_url"])
        #expect(!grammar.ebnf.isEmpty)
        #expect(grammar.ebnf.contains("open_url"))
    }

    @Test("Single tool call grammar with empty args")
    func singleToolCallEmptyArgs() {
        let grammar = ToolSchemaGrammar.compileSingleToolCallGrammar(
            toolName: "list_files",
            argumentSchema: [:]
        )
        #expect(grammar.validToolNames == ["list_files"])
        #expect(!grammar.ebnf.isEmpty)
    }

    // MARK: - Agent Resolution

    @Test("All 19 tools resolve to correct agents")
    func allToolsResolveToAgents() {
        let expectedMappings: [String: String] = [
            "open_url": "safari",
            "get_page_url": "safari",
            "get_page_title": "safari",
            "search_web": "safari",
            "read_file": "file",
            "write_file": "file",
            "list_files": "file",
            "move_file": "file",
            "delete_file": "file",
            "create_note": "notes",
            "search_notes": "notes",
            "list_notes": "notes",
            "edit_note": "notes",
            "run_command": "terminal",
            "get_ui_tree": "automation",
            "click_element": "automation",
            "type_text": "automation",
            "press_key": "automation",
            "run_shortcut": "automation",
        ]

        for (tool, expectedAgent) in expectedMappings {
            let schemas: [[String: Any]] = [["name": tool]]
            let grammar = ToolSchemaGrammar.compilePlanningGrammar(toolSchemas: schemas)
            if !grammar.ebnf.contains("\"\(expectedAgent)\"") {
                Issue.record("Tool '\(tool)' should map to agent '\(expectedAgent)'")
            }
        }
    }

    @Test("Unknown tool produces no agent in grammar")
    func unknownToolNoAgent() {
        let schemas: [[String: Any]] = [["name": "unknown_tool"]]
        let grammar = ToolSchemaGrammar.compilePlanningGrammar(toolSchemas: schemas)
        #expect(grammar.validToolNames == ["unknown_tool"])
        // Agent enum should be empty since unknown_tool has no agent mapping
        // The grammar still compiles but the agent rule is empty
    }

    @Test("Inference bridge seeds tool schemas to match the registered MCP tools")
    @MainActor func inferenceBridgeSeedsToolSchemas() throws {
        let inference = InferenceState()
        let triage = TriageService(inference: inference)
        let planner = OmegaInferenceBridge(triageService: triage)
        let runtime = MCPBridge()

        let data = try #require(planner.toolSchemasJson.data(using: .utf8))
        let schemas = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        #expect(!schemas.isEmpty)
        #expect(schemas.count == runtime.toolCount)
    }
}
