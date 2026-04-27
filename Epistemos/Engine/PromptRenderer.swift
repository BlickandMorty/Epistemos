import Foundation

// MARK: - N1 — PromptRenderer
//
// Renders a typed `Prompt` to a provider-specific representation. Four
// targets:
//
//   1. .anthropicMessages   → JSON suitable for api.anthropic.com/v1/messages
//                             with cache_control breakpoints (Relocation
//                             Trick applied: dynamic content moved to tail
//                             so static prefix stays byte-identical →
//                             documented 7%→84% cache-hit-rate improvement)
//   2. .openAIResponses     → JSON for OpenAI Responses API (no
//                             explicit cache_control; cache is automatic)
//   3. .afmGenerable        → A formatted instructions string + a
//                             registered Generable type id; the call site
//                             uses LanguageModelSession.respond(to:generating:)
//   4. .mlxLocalGrammar     → A flat text prompt + the active grammar
//                             schema reference for MLX local inference
//                             via LocalToolGrammar / MLXConstrainedGenerator
//
// The renderer never re-serializes content unnecessarily — every subtree
// is converted to its provider format exactly once.
//
// Doctrine refs:
//   - 01_DOCTRINE.md §6 #4 (no fallback inspector — closed render set)
//   - 01_DOCTRINE.md §6 #5 (no silent fallback — cache misses surface)

nonisolated public enum RenderTarget: String, Sendable, Hashable, CaseIterable {
    case anthropicMessages
    case openAIResponses
    case afmGenerable
    case mlxLocalGrammar
}

/// Output of a render pass. Variant enum so each target can carry its
/// natural payload type without erasing through `Any`.
nonisolated public enum RenderedPrompt: Sendable {
    /// Anthropic `messages` API request body (without the model field).
    /// Already contains cache_control markers per `cacheHints`.
    case anthropic(systemBlocks: [[String: AnyCodable]], messages: [[String: AnyCodable]])

    /// OpenAI Responses request payload (without model/temperature). No
    /// cache_control; OpenAI prefix-caches automatically.
    case openAI(payload: [String: AnyCodable])

    /// AFM instructions + the registered Generable schema id (or raw
    /// JSON Schema if no registry id). The call site instantiates the
    /// LanguageModelSession with these instructions.
    case afm(instructions: String, schemaRegistryId: String?, rawJSONSchema: String?)

    /// MLX local-grammar prompt + grammar id. The grammar is looked up
    /// in LocalToolGrammar for the structured generation pass.
    case mlxLocal(promptText: String, grammarId: String?)
}

nonisolated public enum PromptRenderer {

    /// Render a prompt for the given target. The renderer is pure —
    /// no I/O, no logging — so callers can render multiple variants
    /// without side effects.
    public static func render(_ prompt: Prompt, target: RenderTarget) -> RenderedPrompt {
        switch target {
        case .anthropicMessages:
            return renderAnthropic(prompt)
        case .openAIResponses:
            return renderOpenAI(prompt)
        case .afmGenerable:
            return renderAFM(prompt)
        case .mlxLocalGrammar:
            return renderMLX(prompt)
        }
    }

    // MARK: - Anthropic Messages (with Relocation Trick)

    /// Renders for Anthropic's Messages API. Applies the Relocation
    /// Trick when `prompt.cacheHints.applyRelocationTrick` is true:
    ///
    /// 1. Build a static system prefix containing identity + tools-doc
    ///    + ontology + constraints + outputSchema description (in a
    ///    deterministic order).
    /// 2. Tag the prefix with cache_control: ephemeral so it lives in
    ///    the cache for 5 minutes.
    /// 3. Move dynamic content (memory.recentChats + task.objective +
    ///    constraint blocks marked dynamic) into the FIRST user message
    ///    wrapped in <session-context> XML so the model doesn't
    ///    confuse it with a direct user command.
    /// 4. The actual user objective is the LAST message content block,
    ///    cache_control: ephemeral on it (3rd breakpoint = current turn).
    ///
    /// Total breakpoints used: 3 (system, session-context user message,
    /// objective user message) — well within Anthropic's 4-breakpoint
    /// cap, leaving one slot for tool registry growth.
    private static func renderAnthropic(_ prompt: Prompt) -> RenderedPrompt {
        let useRelocation = prompt.cacheHints.applyRelocationTrick
        let systemText = anthropicSystemPrefix(prompt, useRelocation: useRelocation)

        // System block with cache_control marker.
        let systemBlocks: [[String: AnyCodable]] = [
            [
                "type": AnyCodable("text"),
                "text": AnyCodable(systemText),
                "cache_control": AnyCodable(["type": "ephemeral"])
            ]
        ]

        var messages: [[String: AnyCodable]] = []

        // Session-context user message (relocated dynamic content).
        if useRelocation {
            let sessionContextText = anthropicSessionContextBlock(prompt)
            if !sessionContextText.isEmpty {
                messages.append([
                    "role": AnyCodable("user"),
                    "content": AnyCodable([
                        [
                            "type": "text",
                            "text": sessionContextText
                            // No cache_control here — this churns
                            // turn-by-turn (recentChats updates) so
                            // marking would invalidate every turn.
                        ] as [String: Any]
                    ])
                ])
            }
        }

        // Objective user message (the actual ask). Last breakpoint.
        let objectiveText: String = {
            if useRelocation {
                return prompt.task.objective
            } else {
                // No relocation: mash everything into the user turn
                // (legacy compose behavior — still valid, just no
                // cache hit on the prefix).
                return monolithicUserPrompt(prompt)
            }
        }()

        messages.append([
            "role": AnyCodable("user"),
            "content": AnyCodable([
                [
                    "type": "text",
                    "text": objectiveText,
                    "cache_control": ["type": "ephemeral"]
                ] as [String: Any]
            ])
        ])

        return .anthropic(systemBlocks: systemBlocks, messages: messages)
    }

    /// Builds the static system prefix. Order is deterministic:
    /// identity → tools-doc → ontology → constraints → outputSchema.
    /// Memory.recentChats + task.objective are NOT included here when
    /// relocation is on — they go to the user message tail.
    static func anthropicSystemPrefix(
        _ prompt: Prompt,
        useRelocation: Bool
    ) -> String {
        var parts: [String] = []

        if let identity = prompt.identity {
            parts.append("# Identity")
            parts.append(identity.systemText)
            if let manifest = identity.capabilityManifest, !manifest.isEmpty {
                parts.append("\n# Capabilities")
                parts.append(manifest)
            }
        }

        if !prompt.tools.isEmpty {
            parts.append("\n# Tools")
            parts.append(prompt.tools.map { tool in
                """
                ## \(tool.name)
                \(tool.description)

                Schema: \(tool.inputSchemaJSON)
                """
            }.joined(separator: "\n\n"))
        }

        if let memory = prompt.memory, !memory.ontology.isEmpty {
            parts.append("\n# Ontology")
            parts.append(memory.ontology
                .sorted { $0.key < $1.key }
                .map { "- \($0.key): \($0.value)" }
                .joined(separator: "\n"))
        }

        if !prompt.constraints.isEmpty {
            parts.append("\n# Constraints")
            for c in prompt.constraints {
                parts.append("## \(c.label)\n\(c.text)")
            }
        }

        if let schema = prompt.outputSchema {
            parts.append("\n# Expected Output")
            if let id = schema.registryId {
                parts.append("Schema: \(id) (StructureRegistry)")
            }
            if let desc = schema.humanDescription {
                parts.append(desc)
            }
            if let raw = schema.rawJSONSchema {
                parts.append("```json\n\(raw)\n```")
            }
        }

        // When relocation is OFF we still keep memory in the prefix.
        // (This is the legacy path — useful for callers that don't
        // want cache invalidation policy.)
        if !useRelocation, let memory = prompt.memory {
            if let recent = memory.recentChats, !recent.isEmpty {
                parts.append("\n# Recent Conversation")
                parts.append(recent)
            }
            if !memory.relevantNotes.isEmpty {
                parts.append("\n# Relevant Notes")
                parts.append(memory.relevantNotes.joined(separator: "\n\n"))
            }
        }

        return parts.joined(separator: "\n\n")
    }

    /// Wraps relocated dynamic content in <session-context> XML so the
    /// model treats it as supplementary context, not a direct command.
    /// (Per Gemini deep-research 2026-04-27: without this framing, the
    /// model frequently misinterprets injected memory as a new user
    /// command requiring an immediate response.)
    static func anthropicSessionContextBlock(_ prompt: Prompt) -> String {
        guard let memory = prompt.memory else { return "" }
        var parts: [String] = []

        if let recent = memory.recentChats, !recent.isEmpty {
            parts.append("<recent-chats>\n\(recent)\n</recent-chats>")
        }
        if !memory.relevantNotes.isEmpty {
            parts.append("<relevant-notes>")
            for note in memory.relevantNotes {
                parts.append("  <note>\(note)</note>")
            }
            parts.append("</relevant-notes>")
        }

        guard !parts.isEmpty else { return "" }
        return """
            <session-context>
            \(parts.joined(separator: "\n\n"))
            </session-context>
            """
    }

    /// Fallback for when relocation is OFF — reproduces the existing
    /// monolithic prompt shape. Used for parity testing.
    static func monolithicUserPrompt(_ prompt: Prompt) -> String {
        var parts: [String] = []
        if let memory = prompt.memory {
            if let recent = memory.recentChats, !recent.isEmpty {
                parts.append("Recent conversation:\n\(recent)")
            }
            if !memory.relevantNotes.isEmpty {
                parts.append("Relevant notes:\n\(memory.relevantNotes.joined(separator: "\n\n"))")
            }
        }
        parts.append(prompt.task.objective)
        return parts.joined(separator: "\n\n")
    }

    // MARK: - OpenAI Responses

    /// OpenAI doesn't expose explicit cache_control — its caching is
    /// automatic when the same prefix is sent. So the renderer just
    /// produces a clean payload; the prefix stability still wins us
    /// the cache hit.
    private static func renderOpenAI(_ prompt: Prompt) -> RenderedPrompt {
        let systemText = anthropicSystemPrefix(prompt, useRelocation: false)
        var input: [[String: Any]] = []
        input.append([
            "role": "system",
            "content": [["type": "text", "text": systemText]]
        ])
        input.append([
            "role": "user",
            "content": [["type": "text", "text": prompt.task.objective]]
        ])
        let payload: [String: AnyCodable] = [
            "input": AnyCodable(input)
        ]
        return .openAI(payload: payload)
    }

    // MARK: - AFM @Generable

    /// AFM rendering is special — the schema is a Swift type, not bytes.
    /// The renderer returns the instructions string + the registered
    /// schema id (callers look up the actual `Generable.Type` via the
    /// AFMSchemaResolver, out of scope for N1's first PR but anchored
    /// here for the follow-up).
    private static func renderAFM(_ prompt: Prompt) -> RenderedPrompt {
        var instructions = anthropicSystemPrefix(prompt, useRelocation: false)
        // AFM gets the objective appended in the same string — there's
        // no separate "messages" array.
        if !instructions.isEmpty { instructions += "\n\n" }
        instructions += "# Task\n\(prompt.task.objective)"

        return .afm(
            instructions: instructions,
            schemaRegistryId: prompt.outputSchema?.registryId,
            rawJSONSchema: prompt.outputSchema?.rawJSONSchema
        )
    }

    // MARK: - MLX Local Grammar

    /// MLX local inference uses a flat text prompt. The grammar id (if
    /// any) is consulted by LocalToolGrammar / MLXConstrainedGenerator
    /// downstream. Renderer just produces the text.
    private static func renderMLX(_ prompt: Prompt) -> RenderedPrompt {
        var lines: [String] = []
        lines.append(anthropicSystemPrefix(prompt, useRelocation: false))
        lines.append("\n## Objective")
        lines.append(prompt.task.objective)
        return .mlxLocal(
            promptText: lines.joined(separator: "\n\n"),
            grammarId: prompt.outputSchema?.registryId
        )
    }
}

// MARK: - AnyCodable shim

/// Minimal type-erased Codable for emitting JSON from heterogeneous
/// dictionaries. Local to N1 — not a public API. The Anthropic /
/// OpenAI render outputs are converted to JSON via JSONSerialization at
/// the call site, so AnyCodable here is for type-checked dict assembly
/// only.
nonisolated public struct AnyCodable: @unchecked Sendable {
    public let value: Any
    public init(_ value: Any) { self.value = value }
}

extension AnyCodable: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let b = try? container.decode(Bool.self) {
            value = b
        } else if let i = try? container.decode(Int.self) {
            value = i
        } else if let d = try? container.decode(Double.self) {
            value = d
        } else if let s = try? container.decode(String.self) {
            value = s
        } else if let a = try? container.decode([AnyCodable].self) {
            value = a.map { $0.value }
        } else if let o = try? container.decode([String: AnyCodable].self) {
            value = o.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable: unsupported type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let b as Bool:
            try container.encode(b)
        case let i as Int:
            try container.encode(i)
        case let d as Double:
            try container.encode(d)
        case let s as String:
            try container.encode(s)
        case let arr as [Any]:
            try container.encode(arr.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable: unsupported type \(type(of: value))"
                )
            )
        }
    }
}
