import Foundation

#if canImport(MLXStructured) && canImport(CMLXStructured)
import MLXStructured
#endif

#if canImport(JSONSchema)
import JSONSchema
#endif

nonisolated enum LocalToolGrammar {
    enum Backend: String, Equatable, Sendable {
        case mlxStructured
        case omegaSoftGuidance
    }

    enum NativeToolGrammar: String, Equatable, Sendable, CaseIterable {
        case qwenXML = "qwen_xml"
        case hermesJSON = "hermes_json"
        case deepSeekCoder = "deepseek_coder"
        case llama33 = "llama_3_3"
        case mistralSmall = "mistral_small"
        case phi4 = "phi_4"
        case phi4Mini = "phi_4_mini"
        case canonicalXML = "canonical_xml"

        var displayName: String {
            switch self {
            case .qwenXML: "Qwen XML"
            case .hermesJSON: "Hermes JSON"
            case .deepSeekCoder: "DeepSeek-Coder"
            case .llama33: "Llama 3.3"
            case .mistralSmall: "Mistral Small"
            case .phi4: "Phi-4"
            case .phi4Mini: "Phi-4-mini"
            case .canonicalXML: "Canonical XML"
            }
        }

        var promptInstructions: String {
            switch self {
            case .qwenXML, .canonicalXML:
                """
                Tool grammar profile: \(displayName). Emit exactly one JSON object with "name" and "arguments" inside <tool_call></tool_call> when a tool is needed. Keep the object compact and valid JSON.
                """
            case .hermesJSON:
                """
                Tool grammar profile: Hermes JSON compatibility. Emit a single JSON tool object or array using "name" and "arguments"; for streaming tool turns, wrap that JSON inside <tool_call></tool_call> so the local detector can execute immediately.
                """
            case .deepSeekCoder:
                """
                Tool grammar profile: DeepSeek-Coder. JSON or fenced JSON tool calls are accepted, but the preferred local streaming form is <tool_call>{"name":"tool.name","arguments":{...}}</tool_call>.
                """
            case .llama33:
                """
                Tool grammar profile: Llama 3.3. Emit a JSON function call with "name" and either "arguments" or "parameters"; the canonical local wrapper is <tool_call></tool_call>.
                """
            case .mistralSmall:
                """
                Tool grammar profile: Mistral Small. [TOOL_CALLS] JSON-array output is accepted, but the canonical local streaming wrapper remains <tool_call></tool_call>.
                """
            case .phi4:
                """
                Tool grammar profile: Phi-4. <|tool_call|> JSON blocks are accepted, but the canonical local streaming wrapper remains <tool_call></tool_call>.
                """
            case .phi4Mini:
                """
                Tool grammar profile: Phi-4-mini. Prefer a compact single JSON call; <|tool_call|> blocks and canonical <tool_call></tool_call> wrappers are both accepted.
                """
            }
        }
    }

    struct ToolCallingPlan {
        let backend: Backend
        let nativeGrammar: NativeToolGrammar
        let supportsTrueMasking: Bool
        let fallbackGrammar: ToolSchemaGrammar.CompiledGrammar
        let notes: [String]

        #if canImport(MLXStructured) && canImport(CMLXStructured) && canImport(JSONSchema)
        let grammar: Grammar?
        #endif
    }

    struct JsonOutputPlan {
        let backend: Backend
        let supportsTrueMasking: Bool
        let notes: [String]

        #if canImport(MLXStructured) && canImport(CMLXStructured) && canImport(JSONSchema)
        let grammar: Grammar?
        #endif
    }

    static var supportsStructuredToolCalling: Bool {
        #if canImport(MLXStructured) && canImport(CMLXStructured) && canImport(JSONSchema)
        true
        #else
        false
        #endif
    }

    static var supportsSoftGuidanceToolCalling: Bool {
        true
    }

    static var supportsLocalAgentLoop: Bool {
        supportsStructuredToolCalling || supportsSoftGuidanceToolCalling
    }

    static func nativeGrammar(forModelID modelID: String?) -> NativeToolGrammar {
        guard let modelID else { return .canonicalXML }

        let normalized = modelID.lowercased()
        if normalized.contains("phi-4-mini") || normalized.contains("phi4-mini") {
            return .phi4Mini
        }
        if normalized.contains("phi-4") || normalized.contains("phi4") {
            return .phi4
        }
        if normalized.contains("mistral-small") || normalized.contains("mistral_small") {
            return .mistralSmall
        }
        if normalized.contains("llama-3.3") || normalized.contains("llama3.3") {
            return .llama33
        }
        if normalized.contains("deepseek-coder") || normalized.contains("deepseekcoder") {
            return .deepSeekCoder
        }
        if normalized.contains("hermes") || normalized.contains("localagent43") || normalized.contains("local-agent") {
            return .hermesJSON
        }
        if normalized.contains("qwen") || normalized.contains("qwq") || normalized.contains("qwopus") {
            return .qwenXML
        }
        return .canonicalXML
    }

    static func buildToolCallingPlan(
        tools: [OmegaToolDefinition],
        forceThinking: Bool,
        modelID: String? = nil
    ) -> ToolCallingPlan {
        let tools = AgentToolNameAliases.canonicalizedDefinitions(for: tools)
        let nativeGrammar = nativeGrammar(forModelID: modelID)
        let fallbackGrammar = ToolSchemaGrammar.compilePlanningGrammar(
            toolSchemas: tools.map(\.localPlanningSchema)
        )
        var notes: [String] = [
            "Native tool grammar profile: \(nativeGrammar.displayName) (\(nativeGrammar.rawValue))."
        ]

        if tools.isEmpty {
            notes.append("No tools were provided; grammar will allow free-form output only.")
        }

        #if canImport(MLXStructured) && canImport(CMLXStructured) && canImport(JSONSchema)
        let resolvedTools = tools.map(resolveStructuredTool(_:))
        notes.append(contentsOf: resolvedTools.compactMap(\.note))

        do {
            let grammar = try Grammar {
                SequenceFormat {
                    if forceThinking {
                        TagFormat(begin: "<think>", end: "</think>") {
                            AnyTextFormat()
                        }
                    }

                    if !resolvedTools.isEmpty {
                        TriggeredTagsFormat(triggers: ["<tool_call>"]) {
                            for tool in resolvedTools {
                                TagFormat(
                                    begin: "<tool_call>\n{\"name\": \"\(tool.name)\", \"arguments\": ",
                                    end: "}\n</tool_call>"
                                ) {
                                    JSONSchemaFormat(schema: tool.schema)
                                }
                            }
                        }
                    }

                    AnyTextFormat()
                }
            }

            return ToolCallingPlan(
                backend: .mlxStructured,
                nativeGrammar: nativeGrammar,
                supportsTrueMasking: true,
                fallbackGrammar: fallbackGrammar,
                notes: notes,
                grammar: grammar
            )
        } catch {
            notes.append("MLXStructured grammar construction failed: \(error.localizedDescription)")
            LocalAgentDiagnostics.record(
                .strictGrammarFallback,
                modelID: modelID,
                nativeGrammar: nativeGrammar
            )
            return ToolCallingPlan(
                backend: .omegaSoftGuidance,
                nativeGrammar: nativeGrammar,
                supportsTrueMasking: false,
                fallbackGrammar: fallbackGrammar,
                notes: notes,
                grammar: nil
            )
        }
        #else
        notes.append(
            "MLXStructured, CMLXStructured, or JSONSchema is unavailable in this target; using the existing soft-guidance fallback boundary."
        )
        LocalAgentDiagnostics.record(
            .strictGrammarFallback,
            modelID: modelID,
            nativeGrammar: nativeGrammar
        )
        return ToolCallingPlan(
            backend: .omegaSoftGuidance,
            nativeGrammar: nativeGrammar,
            supportsTrueMasking: false,
            fallbackGrammar: fallbackGrammar,
            notes: notes
        )
        #endif
    }

    static func buildJsonOutputPlan(schemaJson: String) -> JsonOutputPlan {
        var notes: [String] = []

        #if canImport(MLXStructured) && canImport(CMLXStructured) && canImport(JSONSchema)
        do {
            let schema = try JSONSchema(jsonString: schemaJson)
            let grammar = try Grammar.schema(schema)
            return JsonOutputPlan(
                backend: .mlxStructured,
                supportsTrueMasking: true,
                notes: notes,
                grammar: grammar
            )
        } catch {
            notes.append("Structured JSON schema degraded to soft guidance: \(error.localizedDescription)")
            return JsonOutputPlan(
                backend: .omegaSoftGuidance,
                supportsTrueMasking: false,
                notes: notes,
                grammar: nil
            )
        }
        #else
        notes.append(
            "Structured JSON output is unavailable because MLXStructured, CMLXStructured, or JSONSchema is not linked into this target."
        )
        return JsonOutputPlan(
            backend: .omegaSoftGuidance,
            supportsTrueMasking: false,
            notes: notes
        )
        #endif
    }
}

#if canImport(MLXStructured) && canImport(CMLXStructured) && canImport(JSONSchema)
private struct StructuredToolSpec {
    let name: String
    let schema: JSONSchema
    let note: String?
}

private extension LocalToolGrammar {
    nonisolated static func resolveStructuredTool(_ tool: OmegaToolDefinition) -> StructuredToolSpec {
        do {
            return StructuredToolSpec(
                name: tool.name,
                schema: try JSONSchema(jsonString: tool.schemaJson),
                note: nil
            )
        } catch {
            return StructuredToolSpec(
                name: tool.name,
                schema: JSONSchema.object(additionalProperties: .boolean(true)),
                note: "Tool '\(tool.name)' fell back to a permissive object schema for structured decoding."
            )
        }
    }
}
#endif

private extension OmegaToolDefinition {
    nonisolated var localPlanningSchema: [String: Any] {
        var schema: [String: Any] = [
            "name": name,
            "description": description,
        ]

        if let data = schemaJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            schema["inputSchema"] = parsed
        } else {
            schema["inputSchema"] = [
                "type": "object",
                "properties": [:],
            ]
        }

        return schema
    }
}
