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

        #expect(names.contains("file.read"))
        #expect(names.contains("file.write"))
        #expect(!names.contains("action.bash"))
        #expect(!names.contains("action.terminal"))
        #expect(!names.contains("get_ui_tree"))
        #expect(!names.contains("see"))
        #expect(!names.contains("click"))
        #expect(!names.contains("browser.complete_task"))
    }

    @Test("MCP Bridge Core App Store catalog hides Pro gateway tools")
    @MainActor func mcpBridgeCoreAppStoreCatalogHidesProGatewayTools() throws {
        let data = try #require(MCPBridge.builtinCatalogJson(
            distribution: .coreAppStore
        ).data(using: .utf8))
        let catalog = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let names = Set(catalog.compactMap { $0["name"] as? String })

        #expect(names.contains("file.read"))
        #expect(names.contains("file.write"))
        #expect(!names.contains("action.bash"))
        #expect(!names.contains("action.terminal"))
        #expect(!names.contains("get_ui_tree"))
        #expect(!names.contains("see"))
        #expect(!names.contains("click"))
        #expect(!names.contains("browser.complete_task"))
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
        var seenCanonicalNames: Set<String> = []
        let rawVisibleNames = rawCatalog.compactMap { entry -> String? in
            guard let name = entry["name"] as? String else { return nil }
            let canonicalName = AgentToolNameAliases.canonical(name)
            guard ToolSurfacePolicy.isSurfacedToolName(
                canonicalName,
                distribution: .proResearch
            ),
                  seenCanonicalNames.insert(canonicalName).inserted else {
                return nil
            }
            return canonicalName
        }

        #expect(bridgeNames == rawVisibleNames)
        let browserTask = try #require(bridgeCatalog.first {
            ($0["name"] as? String) == "browser.complete_task"
        })
        #expect(browserTask["agent"] as? String == "browser")
        #expect((browserTask["description"] as? String)?.contains("browser-use Chromium sub-agent") == true)
        let readFile = try #require(bridgeCatalog.first { ($0["name"] as? String) == "file.read" })
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

    @Test("Omega visible tool surfaces expose unique canonical tool names")
    @MainActor func omegaVisibleToolSurfacesExposeUniqueCanonicalToolNames() throws {
        let bridge = MCPBridge()

        for distribution in [
            ToolSurfacePolicy.Distribution.coreAppStore,
            .proResearch,
        ] {
            let surfacedNames = OmegaToolRegistry.surfacedTools(
                distribution: distribution
            ).map(\.name)
            Self.expectUniqueCanonicalNames(
                surfacedNames,
                label: "surfacedTools \(distribution)"
            )

            let schemaNames = OmegaToolRegistry.planningSchemas(
                distribution: distribution
            ).compactMap { $0["name"] as? String }
            Self.expectUniqueCanonicalNames(
                schemaNames,
                label: "planningSchemas \(distribution)"
            )

            let catalogData = try #require(OmegaToolRegistry.catalogJson(
                distribution: distribution
            ).data(using: .utf8))
            let catalog = try #require(try JSONSerialization.jsonObject(
                with: catalogData
            ) as? [[String: Any]])
            let catalogNames = catalog.compactMap { $0["name"] as? String }
            Self.expectUniqueCanonicalNames(
                catalogNames,
                label: "catalogJson \(distribution)"
            )

            let listResponse = bridge.dispatch(
                #"{"jsonrpc":"2.0","method":"tools/list","id":99}"#,
                distribution: distribution
            )
            let listJson = try Self.jsonObject(from: listResponse)
            let result = try #require(listJson["result"] as? [String: Any])
            let tools = try #require(result["tools"] as? [[String: Any]])
            let listNames = tools.compactMap { $0["name"] as? String }
            Self.expectUniqueCanonicalNames(
                listNames,
                label: "tools/list \(distribution)"
            )
        }

        let inspectorNames = bridge.toolsByAgent.values.flatMap { tools in
            tools.map(\.name)
        }
        Self.expectUniqueCanonicalNames(
            inspectorNames,
            label: "MCPBridge.toolsByAgent"
        )
    }

    @Test("Omega Core App Store planning prompt hides Pro agent groups")
    func omegaCoreAppStorePlanningPromptHidesExperimentalAgentGroups() {
        let block = OmegaToolRegistry.planningPromptBlock(distribution: .coreAppStore)

        #expect(block.contains("- file.read:"))
        #expect(!block.contains("- action.bash:"))
        #expect(!block.contains("- action.terminal:"))
        #expect(!block.contains("- get_ui_tree:"))
        #expect(!block.contains("- see:"))
        #expect(!block.contains("- click:"))
        #expect(!block.contains("- browser.complete_task:"))
    }

    @Test("Omega Pro planning prompt exposes browser-use as subordinate MCP tool")
    func omegaProPlanningPromptExposesBrowserUseAsSubordinateMCPTool() {
        let block = OmegaToolRegistry.planningPromptBlock(distribution: .proResearch)

        #expect(block.contains("BROWSER MCP sub-agent (Pro browser-use):"))
        #expect(block.contains("- browser.complete_task:"))
        #expect(block.contains("Goose remains the user-facing agent"))
    }

    @Test("Omega Core App Store dispatch list hides Pro gateway tools")
    func omegaCoreAppStoreDispatchListHidesProGatewayTools() throws {
        let bridge = MCPBridge()
        let response = bridge.dispatch(
            #"{"jsonrpc":"2.0","method":"tools/list","id":1}"#,
            distribution: .coreAppStore
        )
        let json = try Self.jsonObject(from: response)
        let result = try #require(json["result"] as? [String: Any])
        let tools = try #require(result["tools"] as? [[String: Any]])
        let names = Set(tools.compactMap { $0["name"] as? String })

        #expect(names.contains("file.read"))
        #expect(names.contains("file.write"))
        #expect(!names.contains("action.bash"))
        #expect(!names.contains("action.terminal"))
        #expect(!names.contains("get_ui_tree"))
        #expect(!names.contains("see"))
        #expect(!names.contains("click"))
        #expect(!names.contains("browser.complete_task"))
    }

    @Test("Omega Pro Research dispatch list preserves full registered tools")
    func omegaProResearchDispatchListPreservesFullRegisteredTools() throws {
        let bridge = MCPBridge()
        let response = bridge.dispatch(
            #"{"jsonrpc":"2.0","method":"tools/list","id":4}"#,
            distribution: .proResearch
        )
        let json = try Self.jsonObject(from: response)
        let result = try #require(json["result"] as? [String: Any])
        let tools = try #require(result["tools"] as? [[String: Any]])
        let names = Set(tools.compactMap { $0["name"] as? String })

        #expect(names.count == OmegaToolRegistry.surfacedTools(
            distribution: .proResearch
        ).count)
        #expect(names.contains("action.bash"))
        #expect(names.contains("browser.complete_task"))
    }

    @Test("Omega Pro dispatch routes browser-use task through app-hosted MCP")
    func omegaProDispatchRoutesBrowserUseTaskThroughAppHostedMCP() throws {
        let bridge = MCPBridge()
        let response = bridge.dispatch(
            #"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"browser.complete_task","arguments":{"task":"Open example.com and report the title","max_steps":4}},"id":5}"#,
            distribution: .proResearch
        )
        let json = try Self.jsonObject(from: response)
        let result = try #require(json["result"] as? [String: Any])

        #expect(result["status"] as? String == "pending")
        #expect(result["tool_name"] as? String == "browser.complete_task")
        #expect(json["error"] == nil || json["error"] is NSNull)
    }

    @Test("Omega Core App Store dispatch denies Pro gateway tool calls")
    func omegaCoreAppStoreDispatchDeniesProGatewayToolCalls() throws {
        let bridge = MCPBridge()
        for toolName in [
            "action.bash",
            "action.terminal",
            "get_ui_tree",
            "see",
            "click",
            "browser.complete_task",
        ] {
            let request = """
            {"jsonrpc":"2.0","method":"tools/call","params":{"name":"\(toolName)","arguments":{}},"id":2}
            """
            let response = bridge.dispatch(request, distribution: .coreAppStore)
            let json = try Self.jsonObject(from: response)
            let error = try #require(json["error"] as? [String: Any])

            #expect(error["code"] as? Int == -32601)
            #expect((error["message"] as? String)?.contains("Tool not found: \(toolName)") == true)
            #expect(json["result"] == nil)
        }
    }

    @Test("Omega Core App Store dispatch still allows Core-safe tool calls")
    func omegaCoreAppStoreDispatchStillAllowsCoreSafeToolCalls() throws {
        let bridge = MCPBridge()
        let response = bridge.dispatch(
            #"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"read_file","arguments":{"path":"/tmp/test"}},"id":3}"#,
            distribution: .coreAppStore
        )
        let json = try Self.jsonObject(from: response)
        let result = try #require(json["result"] as? [String: Any])

        #expect(result["status"] as? String == "pending")
        #expect(result["tool_name"] as? String == "file.read")
        #expect(json["error"] == nil || json["error"] is NSNull)
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

    @Test("Command center tool inventory uses the surfaced tier catalog")
    func commandCenterToolInventoryUsesSurfacedTierCatalog() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/State/AgentCommandCenterState.swift"
        )

        #expect(source.contains("ToolCatalogLoader"))
        #expect(source.contains("defaultToolCatalogLoader"))
        #expect(source.contains("ToolTierBridge("))
        #expect(source.contains("ChatToolTier.from(operatingMode: operatingMode)"))
        #expect(source.contains("ToolSurfacePolicy.surfacedTools("))
        #expect(source.contains("toolSurfaceDistribution"))
        #expect(source.contains("availableTools = tools"))
        #expect(source.contains("mcpToolsByAgent = Dictionary(grouping: tools, by: \\.agent)"))
        #expect(!source.contains("OmegaToolRegistry.surfacedTools()"))
        #expect(!source.contains("OmegaToolRegistry.all.filter(\\.requiresConfirmation)"))
        #expect(!source.contains("Dictionary(grouping: OmegaToolRegistry.all"))
    }

    @Test("Skills settings inventory uses discovery catalog separately from tool execution")
    func skillsSettingsInventoryUsesDiscoveryCatalog() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SkillsSettingsView.swift"
        )

        #expect(source.contains("Text(\"Skill Hub\")"))
        #expect(source.contains("discoveryCard(vaultPath: vaultSync.vaultURL?.path)"))
        #expect(source.contains("Text(\"Create Skill\")"))
        #expect(source.contains("Text(\"Install Skill\")"))
        #expect(source.contains("SkillDiscoveryCatalog.discoverSkillEntries(forceRefresh: true)"))
        #expect(source.contains("callSkillManager(payload: payload, vaultPath: vaultPath)"))
        #expect(source.contains("InstallSource.isUnlockedInCurrentBuild") || source.contains("installSource.isUnlockedInCurrentBuild"))
        #expect(!source.contains("ToolTierBridge("))
        #expect(!source.contains("OmegaToolRegistry.surfacedTools()"))
    }

    private static func jsonObject(from response: String) throws -> [String: Any] {
        let data = try #require(response.data(using: .utf8))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func expectUniqueCanonicalNames(
        _ names: [String],
        label: String
    ) {
        let canonicalNames = names.map(AgentToolNameAliases.canonical)
        #expect(
            canonicalNames == names,
            "\(label) must already expose canonical names"
        )
        #expect(
            Set(canonicalNames).count == canonicalNames.count,
            "\(label) must not expose duplicate canonical tool names"
        )
        #expect(
            !Set(canonicalNames).contains("think"),
            "\(label) must not expose internal scratchpad tools"
        )
    }
}
