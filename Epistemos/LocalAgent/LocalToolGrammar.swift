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

    struct ToolCallingPlan {
        let backend: Backend
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

    static func buildToolCallingPlan(
        tools: [OmegaToolDefinition],
        forceThinking: Bool
    ) -> ToolCallingPlan {
        let fallbackGrammar = ToolSchemaGrammar.compilePlanningGrammar(
            toolSchemas: tools.map(\.localPlanningSchema)
        )
        var notes: [String] = []

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
                supportsTrueMasking: true,
                fallbackGrammar: fallbackGrammar,
                notes: notes,
                grammar: grammar
            )
        } catch {
            notes.append("MLXStructured grammar construction failed: \(error.localizedDescription)")
            return ToolCallingPlan(
                backend: .omegaSoftGuidance,
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
        return ToolCallingPlan(
            backend: .omegaSoftGuidance,
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
