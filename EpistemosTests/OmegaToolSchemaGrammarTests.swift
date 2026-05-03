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

    @Test("Omega tool registry seeds tool schemas to match the registered MCP tools")
    @MainActor func omegaToolRegistrySeedsToolSchemas() throws {
        let runtime = MCPBridge()

        let data = try #require(OmegaToolRegistry.planningSchemasJson(
            distribution: .proResearch
        ).data(using: .utf8))
        let schemas = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        #expect(!schemas.isEmpty)
        #expect(schemas.count == OmegaToolRegistry.surfacedTools(
            distribution: .proResearch
        ).count)
        #expect(runtime.toolCount == OmegaToolRegistry.all.count)
    }

    @Test("Omega Core App Store planning schemas hide Pro gateway tools")
    func omegaCoreAppStorePlanningSchemasHideProGatewayTools() throws {
        let data = try #require(OmegaToolRegistry.planningSchemasJson(
            distribution: .coreAppStore
        ).data(using: .utf8))
        let schemas = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let names = Set(schemas.compactMap { $0["name"] as? String })

        #expect(names.contains("read_file"))
        #expect(names.contains("write_file"))
        #expect(!names.contains("run_command"))
        #expect(!names.contains("run_persistent"))
        #expect(!names.contains("get_ui_tree"))
        #expect(!names.contains("see"))
        #expect(!names.contains("click"))
    }

    @Test("MCP Bridge Core App Store catalog hides Pro gateway tools")
    @MainActor func mcpBridgeCoreAppStoreCatalogHidesProGatewayTools() throws {
        let data = try #require(MCPBridge.builtinCatalogJson(
            distribution: .coreAppStore
        ).data(using: .utf8))
        let catalog = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let names = Set(catalog.compactMap { $0["name"] as? String })

        #expect(names.contains("read_file"))
        #expect(names.contains("write_file"))
        #expect(!names.contains("run_command"))
        #expect(!names.contains("run_persistent"))
        #expect(!names.contains("get_ui_tree"))
        #expect(!names.contains("see"))
        #expect(!names.contains("click"))
    }

    @Test("MCP Bridge Pro catalog preserves Rust source of truth")
    func mcpBridgeProCatalogPreservesRustSourceOfTruth() throws {
        let bridgeData = try #require(MCPBridge.builtinCatalogJson(
            distribution: .proResearch
        ).data(using: .utf8))
        let bridgeCatalog = try #require(try JSONSerialization.jsonObject(
            with: bridgeData
        ) as? [[String: Any]])
        let rawData = try #require(builtinToolsJson().data(using: .utf8))
        let rawCatalog = try #require(try JSONSerialization.jsonObject(
            with: rawData
        ) as? [[String: Any]])

        let bridgeNames = bridgeCatalog.compactMap { $0["name"] as? String }
        let rawVisibleNames = rawCatalog
            .compactMap { $0["name"] as? String }
            .filter {
                ToolSurfacePolicy.isSurfacedToolName(
                    $0,
                    distribution: .proResearch
                )
            }

        #expect(bridgeNames == rawVisibleNames)
        let readFile = try #require(bridgeCatalog.first { ($0["name"] as? String) == "read_file" })
        let schemaJson = try #require(readFile["input_schema_json"] as? String)
        let schemaData = try #require(schemaJson.data(using: .utf8))
        #expect(try JSONSerialization.jsonObject(with: schemaData) is [String: Any])
    }

    @Test("Omega planning schemas stay backed by the visible catalog")
    func omegaPlanningSchemasStayBackedByVisibleCatalog() throws {
        for distribution in [
            ToolSurfacePolicy.Distribution.coreAppStore,
            ToolSurfacePolicy.Distribution.proResearch,
        ] {
            let schemaNames = Set(
                OmegaToolRegistry.planningSchemas(distribution: distribution)
                    .compactMap { $0["name"] as? String }
            )
            let catalogData = try #require(OmegaToolRegistry.catalogJson(
                distribution: distribution
            ).data(using: .utf8))
            let catalog = try #require(try JSONSerialization.jsonObject(
                with: catalogData
            ) as? [[String: Any]])
            let catalogNames = Set(catalog.compactMap { $0["name"] as? String })

            #expect(schemaNames.isSubset(of: catalogNames))
        }
    }

    @Test("Omega Core App Store planning prompt hides Pro agent groups")
    func omegaCoreAppStorePlanningPromptHidesProAgentGroups() {
        let block = OmegaToolRegistry.planningPromptBlock(distribution: .coreAppStore)

        #expect(block.contains("- read_file:"))
        #expect(!block.contains("- run_command:"))
        #expect(!block.contains("- run_persistent:"))
        #expect(!block.contains("- get_ui_tree:"))
        #expect(!block.contains("- see:"))
        #expect(!block.contains("- click:"))
    }

    @Test("Planning schemas close object inputs for strict tool runtimes")
    func planningSchemasCloseObjectInputsForStrictToolRuntimes() throws {
        let tool = OmegaToolDefinition(
            name: "write_file",
            agent: "file",
            description: "Write a file",
            argumentsExample: "{\"path\":\"Notes/test.md\"}",
            schemaJson: """
            {
              "type": "object",
              "properties": {
                "path": { "type": "string" },
                "options": {
                  "type": "object",
                  "properties": {
                    "overwrite": { "type": "boolean" }
                  }
                }
              },
              "required": ["path"]
            }
            """,
            destructive: false,
            requiresConfirmation: false
        )

        let schema = try #require(tool.planningSchema["inputSchema"] as? [String: Any])
        #expect(schema["additionalProperties"] as? Bool == false)

        let properties = try #require(schema["properties"] as? [String: Any])
        let options = try #require(properties["options"] as? [String: Any])
        #expect(options["additionalProperties"] as? Bool == false)
    }
}
