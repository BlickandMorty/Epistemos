import Foundation

// MARK: - Tool Schema → JSON Grammar Compiler

/// Compiles Omega tool schemas into a deterministic JSON grammar (EBNF-style rules)
/// that can be used for constrained decoding. The grammar ensures the model can ONLY
/// produce valid JSON matching one of the registered tool call schemas.
///
/// Output format: a set of production rules compatible with EBNF logit masking.
/// Each rule describes valid next-token sets at each position in the output.
enum ToolSchemaGrammar {

    /// A compiled grammar ready for constrained decoding.
    struct CompiledGrammar: Sendable {
        /// The EBNF grammar string.
        let ebnf: String
        /// Tool names that are valid in this grammar.
        let validToolNames: [String]
        /// The JSON schema that was compiled.
        let sourceSchema: String
    }

    /// Compile tool schemas (from MCPBridge) into a constrained JSON grammar.
    /// The grammar enforces the output is a JSON array of step objects matching:
    /// `[{"description":"...","agent":"...","tool":"...","arguments":{...},"risk":"low|medium|high|critical"}]`
    static func compilePlanningGrammar(toolSchemas: [[String: Any]]) -> CompiledGrammar {
        let toolNames = toolSchemas.compactMap { $0["name"] as? String }
        let agentNames = Set(toolNames.compactMap { resolveAgent(for: $0) })

        let ebnf = buildPlanningEBNF(
            toolNames: toolNames,
            agentNames: Array(agentNames).sorted()
        )

        let schemaJson = (try? JSONSerialization.data(
            withJSONObject: toolSchemas,
            options: [.sortedKeys]
        )).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        return CompiledGrammar(
            ebnf: ebnf,
            validToolNames: toolNames,
            sourceSchema: schemaJson
        )
    }

    /// Compile a grammar that constrains output to a single tool call JSON object.
    /// Used for single-step execution (Brain 2 device actions).
    static func compileSingleToolCallGrammar(
        toolName: String,
        argumentSchema: [String: Any]
    ) -> CompiledGrammar {
        let ebnf = buildSingleToolCallEBNF(
            toolName: toolName,
            argProperties: argumentSchema
        )

        let schemaJson = (try? JSONSerialization.data(
            withJSONObject: argumentSchema,
            options: [.sortedKeys]
        )).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        return CompiledGrammar(
            ebnf: ebnf,
            validToolNames: [toolName],
            sourceSchema: schemaJson
        )
    }

    // MARK: - EBNF Construction

    /// Build EBNF for the planning output format: JSON array of step objects.
    private static func buildPlanningEBNF(
        toolNames: [String],
        agentNames: [String]
    ) -> String {
        let toolEnum = toolNames.map { "\"\($0)\"" }.joined(separator: " | ")
        let agentEnum = agentNames.map { "\"\($0)\"" }.joined(separator: " | ")
        let riskEnum = "\"low\" | \"medium\" | \"high\" | \"critical\""

        return """
        root        ::= "[" ws step ("," ws step)* ws "]"
        step        ::= "{" ws
                        "\"description\"" ws ":" ws string "," ws
                        "\"agent\"" ws ":" ws agent "," ws
                        "\"tool\"" ws ":" ws tool "," ws
                        "\"arguments\"" ws ":" ws object "," ws
                        "\"risk\"" ws ":" ws risk
                        ws "}"
        agent       ::= \(agentEnum)
        tool        ::= \(toolEnum)
        risk        ::= \(riskEnum)
        object      ::= "{" ws (keyvalue ("," ws keyvalue)*)? ws "}"
        keyvalue    ::= string ws ":" ws value
        array       ::= "[" ws (value ("," ws value)*)? ws "]"
        value       ::= string | number | object | array | "true" | "false" | "null"
        string      ::= "\"" chars "\""
        chars       ::= char*
        char        ::= [^"\\\\] | "\\\\" escape
        escape      ::= ["\\\\"/bfnrt] | "u" hexdigit hexdigit hexdigit hexdigit
        hexdigit    ::= [0-9a-fA-F]
        number      ::= "-"? integer fraction? exponent?
        integer     ::= "0" | [1-9] [0-9]*
        fraction    ::= "." [0-9]+
        exponent    ::= [eE] [+-]? [0-9]+
        ws          ::= [ \\t\\n\\r]*
        """
    }

    /// Build EBNF for a single tool call with typed argument constraints.
    private static func buildSingleToolCallEBNF(
        toolName: String,
        argProperties: [String: Any]
    ) -> String {
        var argRules = ""
        var argFields: [String] = []

        if let properties = argProperties["properties"] as? [String: [String: Any]] {
            let required = Set((argProperties["required"] as? [String]) ?? [])
            let sorted = properties.keys.sorted()

            for key in sorted {
                guard let prop = properties[key] else { continue }
                let typeStr = prop["type"] as? String ?? "string"
                let ruleName = "arg_\(key)"
                argRules += "        \(ruleName) ::= \(jsonTypeRule(typeStr))\n"

                if required.contains(key) {
                    argFields.append("\"\\\"\(key)\\\"\" ws \":\" ws \(ruleName)")
                }
            }
        }

        let argsBody: String
        if argFields.isEmpty {
            argsBody = "\"{\" ws \"}\""
        } else {
            argsBody = "\"{\" ws " + argFields.joined(separator: " \",\" ws ") + " ws \"}\""
        }

        var lines: [String] = []
        lines.append("root        ::= \"{\" ws")
        lines.append("                \"\\\"type\\\"\" ws \":\" ws \"\\\"AXPress\\\"\" ws \"|\" ws \"\\\"CGClick\\\"\" ws \"|\" ws \"\\\"KeyInject\\\"\" \",\" ws")
        lines.append("                \"\\\"tool\\\"\" ws \":\" ws \"\\\"\(toolName)\\\"\" \",\" ws")
        lines.append("                \"\\\"arguments\\\"\" ws \":\" ws args")
        lines.append("                ws \"}\"")
        lines.append("args        ::= \(argsBody)")
        lines.append(argRules)
        lines.append("value       ::= string | number | \"true\" | \"false\" | \"null\"")
        lines.append("string      ::= \"\\\"\" [^\"\\\\\\\\]* \"\\\"\"")
        lines.append("number      ::= \"-\"? (\"0\" | [1-9] [0-9]*) (\".\" [0-9]+)?")
        lines.append("ws          ::= [ \\t\\n\\r]*")
        return lines.joined(separator: "\n")
    }

    private static func jsonTypeRule(_ type: String) -> String {
        switch type {
        case "string":
            return "string"
        case "number", "integer":
            return "number"
        case "boolean":
            return "\"true\" | \"false\""
        case "array":
            return "\"[\" ws (value (\",\" ws value)*)? ws \"]\""
        case "object":
            return "\"{\" ws (string ws \":\" ws value (\",\" ws string ws \":\" ws value)*)? ws \"}\""
        default:
            return "value"
        }
    }

    // MARK: - Agent Resolution (mirrors OmegaPlanningService)

    private static func resolveAgent(for toolName: String) -> String? {
        let toolToAgent: [String: String] = [
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
            "run_shortcut": "automation",
        ]
        return toolToAgent[toolName]
    }
}
