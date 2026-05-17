import Foundation

#if canImport(MLXStructured) && canImport(CMLXStructured)
import MLXStructured
#endif

#if canImport(JSONSchema)
import JSONSchema
#endif

nonisolated enum LocalToolGrammar {
    static let triFusionMutationToolName = "epdoc.apply_tri_fusion_mutation"
    static let triFusionMutationKinds = [
        "insert_block",
        "mutate_block",
        "link_block",
        "transclude_block",
    ]
    static let triFusionSourceFormats = ["json", "markdown", "html"]

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

    static var supportsSoftGuidanceToolCalling: Bool {
        true
    }

    static var supportsLocalAgentLoop: Bool {
        supportsStructuredToolCalling || supportsSoftGuidanceToolCalling
    }

    static var triFusionMutationSchemaJson: String {
        canonicalJSONString(triFusionMutationSchemaObject)
    }

    static func triFusionMutationToolDefinition() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: triFusionMutationToolName,
            agent: "epdoc",
            description: "Apply one structured Tri-Fusion mutation to an Epdoc document.",
            argumentsExample: """
            {"mutation_id":"tfm-1","document_id":"doc-1","base_document_hash":"0000000000000000000000000000000000000000000000000000000000000000","actor":{"kind":"agent","run_id":"run-1"},"source_format":"json","kind":"insert_block","artifact_id":"doc-1","rationale":"Insert a missing summary block.","after_block_id":"b1","block":{"type":"paragraph","attrs":{"id":"b2"},"content":[{"type":"text","text":"Summary"}]}}
            """,
            schemaJson: triFusionMutationSchemaJson,
            destructive: false,
            requiresConfirmation: true
        )
    }

    static func buildToolCallingPlan(
        tools: [OmegaToolDefinition],
        forceThinking: Bool
    ) -> ToolCallingPlan {
        let tools = AgentToolNameAliases.canonicalizedDefinitions(for: tools)
        let fallbackGrammar = ToolSchemaGrammar.compilePlanningGrammar(
            toolSchemas: tools.map(\.localPlanningSchema)
        )
        var notes: [String] = []

        if tools.isEmpty {
            notes.append("No tools were provided; grammar will allow free-form output only.")
        }
        if tools.contains(where: isTriFusionMutationTool(_:)) {
            notes.append(
                "Tri-Fusion mutation grammar is active for \(triFusionMutationToolName); JSON is the mutation substrate and Markdown/HTML are projections."
            )
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

private extension LocalToolGrammar {
    nonisolated static func isTriFusionMutationTool(_ tool: OmegaToolDefinition) -> Bool {
        AgentToolNameAliases.canonical(tool.name) == triFusionMutationToolName
    }

    nonisolated static var triFusionMutationSchemaObject: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": [
                "mutation_id",
                "document_id",
                "base_document_hash",
                "actor",
                "source_format",
                "kind",
                "artifact_id",
                "rationale",
            ],
            "properties": [
                "mutation_id": nonEmptyStringSchema,
                "document_id": nonEmptyStringSchema,
                "base_document_hash": [
                    "type": "string",
                    "pattern": "^[0-9a-f]{64}$",
                ],
                "actor": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["kind"],
                    "properties": [
                        "kind": ["type": "string", "enum": ["agent", "user", "system"]],
                        "run_id": nonEmptyStringSchema,
                    ],
                ],
                "source_format": [
                    "type": "string",
                    "enum": triFusionSourceFormats,
                ],
                "kind": [
                    "type": "string",
                    "enum": triFusionMutationKinds,
                ],
                "artifact_id": nonEmptyStringSchema,
                "rationale": nonEmptyStringSchema,
                "after_block_id": nonEmptyStringSchema,
                "block": proseMirrorNodeSchema,
                "block_id": nonEmptyStringSchema,
                "replacement": proseMirrorNodeSchema,
                "from_block_id": nonEmptyStringSchema,
                "to_block_id": nonEmptyStringSchema,
                "relation": nonEmptyStringSchema,
                "source_block_id": nonEmptyStringSchema,
                "transclusion_block_id": nonEmptyStringSchema,
            ],
            "oneOf": [
                mutationVariantSchema(kind: "insert_block", required: ["block"]),
                mutationVariantSchema(kind: "mutate_block", required: ["block_id", "replacement"]),
                mutationVariantSchema(kind: "link_block", required: ["from_block_id", "to_block_id", "relation"]),
                mutationVariantSchema(
                    kind: "transclude_block",
                    required: ["source_block_id", "transclusion_block_id"]
                ),
            ],
        ]
    }

    nonisolated static var nonEmptyStringSchema: [String: Any] {
        [
            "type": "string",
            "minLength": 1,
        ]
    }

    nonisolated static var proseMirrorNodeSchema: [String: Any] {
        [
            "type": "object",
            "required": ["type"],
            "properties": [
                "type": nonEmptyStringSchema,
                "attrs": [
                    "type": "object",
                    "additionalProperties": true,
                ],
                "content": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": true,
                    ],
                ],
                "text": [
                    "type": "string",
                ],
                "marks": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": true,
                    ],
                ],
            ],
            "additionalProperties": true,
        ]
    }

    nonisolated static func mutationVariantSchema(kind: String, required: [String]) -> [String: Any] {
        [
            "properties": [
                "kind": [
                    "type": "string",
                    "enum": [kind],
                ],
            ],
            "required": ["kind"] + required,
        ]
    }

    nonisolated static func canonicalJSONString(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(
                  withJSONObject: value,
                  options: [.sortedKeys]
              ),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"type":"object","properties":{},"additionalProperties":false}"#
        }
        return json
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
