import Foundation

// MARK: - N1 — Prompt Tree (JSPF + PTF)
//
// JSPF (JSON-Schema Prompt Format) — typed, Codable, Sendable, Hashable
// representation of an agent prompt. The canonical fields decompose a
// monolithic prompt into 8 stable subtrees that can be:
//
//   1. composed deterministically (PromptComposer)
//   2. validated against StructureRegistry at compose time
//   3. cached separately per-subtree (identity, tools, ontology, output_schema
//      stay cached; memory + task churn turn-by-turn)
//   4. persisted as PTF (Prompt Tree Format) — same data laid out as a
//      directory at <vault>/.epistemos/prompts/<session>/<turn>/ so the
//      user (and any audit agent) can inspect exact shape on disk
//   5. rendered to multiple provider targets (Anthropic Messages, OpenAI
//      Responses, AFM @Generable, MLX local-grammar) via PromptRenderer
//
// The architectural keystone: by separating stable subtrees from volatile
// ones at compose time, PromptCache can apply Anthropic's 4-breakpoint
// cache_control with the "Relocation Trick" — moving dynamic content to
// the absolute tail so the static prefix stays byte-identical across
// turns. Documented improvement: cache hit rate 7% (monolithic) → 84%
// (relocated) on multi-turn agent loops, ≈59% input-token cost reduction.
// Sources:
//   - agent_core/src/prompt_caching.rs (existing 4-breakpoint logic)
//   - docs.anthropic.com/en/docs/build-with-claude/prompt-caching
//   - Gemini deep research (2026-04-27): "AI Pipeline and Prompt Caching Design"
//   - ProjectDiscovery case study: 7%→84% via relocation
//
// Doctrine refs:
//   - 01_DOCTRINE.md §6 #1 (no silent behavior — every prompt audit-able)
//   - 01_DOCTRINE.md §6 #14 (no orphan scaffolding — N1 ships ONE wired
//     call site or it doesn't ship)
//   - 01_DOCTRINE.md §6 #5 (no silent fallback — every prompt has a
//     typed, registered shape)
//   - PLAN_V2.md §3.4 (no silent behavior — surface every transformation)

// MARK: - Prompt (root JSPF type)

/// The canonical prompt value. A single source of truth for everything an
/// agent invocation will see. Codable for PTF persistence; Hashable for
/// stable cache-key derivation; Sendable for cross-actor passing.
nonisolated public struct Prompt: Codable, Sendable, Hashable {

    /// JSPF schema version. Bump when the Prompt struct's wire format
    /// changes incompatibly. Start at 1.
    public var version: Int

    /// Stable id for this prompt instance. Derived from the composer's
    /// inputs (session, turn, content hashes) so two composes with the
    /// same inputs produce the same id — useful for dedup + cache-key.
    public var id: String

    /// System role / persona. Stable across most chat sessions.
    public var identity: IdentitySection?

    /// Tool definitions available to the agent this turn. Stable per
    /// session, churns when the user toggles tool tier or available
    /// capabilities mid-session.
    public var tools: [ToolSpec]

    /// Memory subtree — recent chats, relevant notes, ontology refs.
    /// Highest-volatility section: most subtrees inside churn turn-by-turn.
    public var memory: MemorySection?

    /// The active task — what the user just asked, plus any task-mode
    /// metadata (effort tier, mode, etc.). Always churns per turn.
    public var task: TaskSection

    /// Hard rules + capability gates that must apply this turn. Mostly
    /// stable per session.
    public var constraints: [ConstraintSection]

    /// Expected response shape. Optional because not every prompt is
    /// constrained. When present, links to a StructureRegistry entry.
    public var outputSchema: OutputSchema?

    /// Cache-control hints (which subtrees are stable enough to cache).
    /// Computed by PromptCache.hints(for:) at render time, but captured
    /// in the Prompt so the PTF persistence shows what was hinted.
    public var cacheHints: CacheHints

    public init(
        version: Int = 1,
        id: String,
        identity: IdentitySection? = nil,
        tools: [ToolSpec] = [],
        memory: MemorySection? = nil,
        task: TaskSection,
        constraints: [ConstraintSection] = [],
        outputSchema: OutputSchema? = nil,
        cacheHints: CacheHints = .none
    ) {
        self.version = version
        self.id = id
        self.identity = identity
        self.tools = tools
        self.memory = memory
        self.task = task
        self.constraints = constraints
        self.outputSchema = outputSchema
        self.cacheHints = cacheHints
    }
}

// MARK: - Sub-sections

/// Persona / system role. Stable across sessions; the heaviest cacheable
/// block in most prompts.
nonisolated public struct IdentitySection: Codable, Sendable, Hashable {
    public var role: String
    public var systemText: String
    public var capabilityManifest: String?

    public init(role: String, systemText: String, capabilityManifest: String? = nil) {
        self.role = role
        self.systemText = systemText
        self.capabilityManifest = capabilityManifest
    }
}

/// Description of a tool the agent can call this turn. Mirrors the
/// Anthropic Messages API tool schema field-for-field so the renderer
/// can pass-through with no remap.
nonisolated public struct ToolSpec: Codable, Sendable, Hashable {
    public var name: String
    public var description: String
    /// Provider-shaped JSON schema for input. Keep as String to avoid
    /// re-serializing through nested Codable types (the schema is
    /// authored once at registry load time).
    public var inputSchemaJSON: String

    public init(name: String, description: String, inputSchemaJSON: String) {
        self.name = name
        self.description = description
        self.inputSchemaJSON = inputSchemaJSON
    }
}

/// Memory subtree. Recent chats + relevant notes + ontology refs are
/// commonly carried into a turn. Composer fills only the parts the
/// caller asked for (no implicit retrieval).
nonisolated public struct MemorySection: Codable, Sendable, Hashable {
    /// Compact serialization of recent turns. ConversationState JSON
    /// when available (per AR2); raw history string otherwise.
    public var recentChats: String?

    /// Top-N relevant notes from the vault for this turn. Pre-formatted
    /// for the prompt — composer doesn't re-rank here, callers do.
    public var relevantNotes: [String]

    /// Ontology refs (concept id → display label) — stable per vault,
    /// excellent caching candidate.
    public var ontology: [String: String]

    public init(
        recentChats: String? = nil,
        relevantNotes: [String] = [],
        ontology: [String: String] = [:]
    ) {
        self.recentChats = recentChats
        self.relevantNotes = relevantNotes
        self.ontology = ontology
    }
}

/// The active task — what the user just asked. Always churns per turn.
nonisolated public struct TaskSection: Codable, Sendable, Hashable {
    public var objective: String
    public var mode: String?
    public var effortTier: String?

    public init(objective: String, mode: String? = nil, effortTier: String? = nil) {
        self.objective = objective
        self.mode = mode
        self.effortTier = effortTier
    }
}

/// Hard constraints + capability gates. Each is a labeled block so the
/// renderer can present them coherently regardless of provider.
nonisolated public struct ConstraintSection: Codable, Sendable, Hashable {
    public var label: String
    public var text: String

    public init(label: String, text: String) {
        self.label = label
        self.text = text
    }
}

/// Expected response shape. Either a free-form description, a registered
/// StructureRegistry id (preferred), or a raw JSON Schema string for ad-hoc
/// outputs. Composers should prefer the registered id so the local LLM can
/// look up the schema via MCP.
nonisolated public struct OutputSchema: Codable, Sendable, Hashable {
    public var registryId: String?
    public var rawJSONSchema: String?
    public var humanDescription: String?

    public init(
        registryId: String? = nil,
        rawJSONSchema: String? = nil,
        humanDescription: String? = nil
    ) {
        self.registryId = registryId
        self.rawJSONSchema = rawJSONSchema
        self.humanDescription = humanDescription
    }
}

/// Cache-hint plan for a Prompt. The composer can pre-compute hints
/// (defaults to .none); the renderer asks PromptCache.hints(for:) when it
/// needs the final cache_control markers. Kept on Prompt so PTF
/// persistence shows what was hinted at compose time.
nonisolated public struct CacheHints: Codable, Sendable, Hashable {
    /// Subtrees the composer marked as stable enough to cache. Renderer
    /// filters by provider (Anthropic = up to 4; OpenAI = ignored).
    public var stableSubtrees: [PromptSubtree]

    /// Whether the renderer should apply the Relocation Trick — moving
    /// dynamic content (memory.recentChats + task) to the tail of the
    /// rendered prompt so the cached prefix stays byte-identical across
    /// turns. Default true for Anthropic, ignored elsewhere.
    public var applyRelocationTrick: Bool

    public static let none = CacheHints(stableSubtrees: [], applyRelocationTrick: false)

    /// Default for chat turns: cache identity + tools + ontology +
    /// output_schema (the four stablest subtrees), apply relocation.
    public static let chatDefault = CacheHints(
        stableSubtrees: [.identity, .tools, .ontology, .outputSchema],
        applyRelocationTrick: true
    )

    public init(stableSubtrees: [PromptSubtree], applyRelocationTrick: Bool) {
        self.stableSubtrees = stableSubtrees
        self.applyRelocationTrick = applyRelocationTrick
    }
}

/// Stable subtree identifier — used by CacheHints and by PromptNode
/// when laying out the PTF directory. Keep this enum closed; new
/// subtrees require a JSPF version bump.
nonisolated public enum PromptSubtree: String, Codable, Sendable, Hashable, CaseIterable {
    case identity
    case tools
    case memory
    case ontology
    case task
    case constraints
    case outputSchema
}

// MARK: - PromptNode (PTF directory representation)

/// PTF (Prompt Tree Format) on-disk representation. A `Prompt` flattens
/// to a directory of files via `PromptNode.tree(for:)`; the directory
/// round-trips back to a `Prompt` via `PromptNode.assemble(from:)`.
///
/// Files written under `<vault>/.epistemos/prompts/<session>/<turn>/`:
///   - manifest.json       (Prompt envelope: version + id + cacheHints)
///   - identity.json       (IdentitySection if present)
///   - tools.json          (Array of ToolSpec)
///   - memory.json         (MemorySection if present)
///   - task.json           (TaskSection)
///   - constraints.json    (Array of ConstraintSection)
///   - output_schema.json  (OutputSchema if present)
nonisolated public enum PromptNode: Sendable {

    /// File names in the PTF directory. Stable; do not rename without a
    /// JSPF version bump + migration.
    nonisolated public enum Filename: String, Sendable, CaseIterable {
        case manifest = "manifest.json"
        case identity = "identity.json"
        case tools = "tools.json"
        case memory = "memory.json"
        case task = "task.json"
        case constraints = "constraints.json"
        case outputSchema = "output_schema.json"
    }

    /// Minimal envelope persisted alongside the subtree files so a
    /// reader knows which JSPF version produced them and what the
    /// composer's cache plan was.
    nonisolated public struct Manifest: Codable, Sendable, Hashable {
        public var version: Int
        public var id: String
        public var cacheHints: CacheHints

        public init(version: Int, id: String, cacheHints: CacheHints) {
            self.version = version
            self.id = id
            self.cacheHints = cacheHints
        }
    }
}

// MARK: - PromptComposer

/// Static factories for typed Prompts. Each entry point is tied to a
/// specific call site (chat turn, summarize note, etc.) so the
/// constraints + cacheHints can be tuned per use case. Keep this as
/// `public enum` (no instance state) — composers are pure.
///
/// Adding a new factory: also register a corresponding entry in
/// `StructureRegistry.canonicalSchemas` so the local LLM can ask
/// "what kinds of prompts does this app produce?" via MCP.
nonisolated public enum PromptComposer {

    /// Compose a Prompt for a chat turn. The base for N1's WRV anchor
    /// in ChatCoordinator.swift. Inputs are the same ones the existing
    /// agent invocation already has — no new context retrieval.
    ///
    /// The composer is deterministic: same inputs → same Prompt id → same
    /// rendered bytes → cache hit on the second turn.
    public static func compose(
        forChatTurn sessionId: String,
        turnIndex: Int,
        identitySystemText: String,
        capabilityManifest: String?,
        toolDefinitionsJSON: String?,
        relevantNotes: [String] = [],
        recentChatsJSON: String? = nil,
        ontology: [String: String] = [:],
        objective: String,
        mode: String? = nil,
        effortTier: String? = nil,
        constraintBlocks: [ConstraintSection] = [],
        outputSchema: OutputSchema? = nil
    ) -> Prompt {
        let identity = IdentitySection(
            role: "epistemos.assistant",
            systemText: identitySystemText,
            capabilityManifest: capabilityManifest
        )

        let tools: [ToolSpec] = parseToolDefinitions(toolDefinitionsJSON)

        let memory: MemorySection?
        if recentChatsJSON != nil || !relevantNotes.isEmpty || !ontology.isEmpty {
            memory = MemorySection(
                recentChats: recentChatsJSON,
                relevantNotes: relevantNotes,
                ontology: ontology
            )
        } else {
            memory = nil
        }

        let task = TaskSection(
            objective: objective,
            mode: mode,
            effortTier: effortTier
        )

        // Stable id derived from session + turn + content hash so
        // re-composing the same inputs yields the same Prompt id.
        let id = stableId(
            sessionId: sessionId,
            turnIndex: turnIndex,
            objective: objective
        )

        return Prompt(
            version: 1,
            id: id,
            identity: identity,
            tools: tools,
            memory: memory,
            task: task,
            constraints: constraintBlocks,
            outputSchema: outputSchema,
            cacheHints: .chatDefault
        )
    }

    // MARK: - Helpers (internal)

    /// Best-effort parse of a JSON-encoded `[ToolDefinition]` shape into
    /// `ToolSpec`s. The existing ChatCoordinator already produces this
    /// JSON via `Self.encodedToolDefinitionsJSON(...)`. We only require:
    ///   - top-level is an array
    ///   - each entry has `name` (String), `description` (String),
    ///     and `input_schema` (object)
    /// Anything else is ignored — this is intentionally lenient because
    /// tool registries evolve and we don't want N1 to fail if a tool
    /// gains a new field.
    static func parseToolDefinitions(_ json: String?) -> [ToolSpec] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        let parsed: Any?
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            return []
        }
        guard let arr = parsed as? [[String: Any]] else { return [] }
        return arr.compactMap { dict -> ToolSpec? in
            guard
                let name = dict["name"] as? String,
                let description = dict["description"] as? String
            else {
                return nil
            }
            let schemaJSON: String
            if let schemaObj = dict["input_schema"] {
                if let schemaData = try? JSONSerialization.data(
                    withJSONObject: schemaObj,
                    options: [.sortedKeys]
                ),
                   let schemaStr = String(data: schemaData, encoding: .utf8) {
                    schemaJSON = schemaStr
                } else {
                    schemaJSON = "{}"
                }
            } else {
                schemaJSON = "{}"
            }
            return ToolSpec(
                name: name,
                description: description,
                inputSchemaJSON: schemaJSON
            )
        }
    }

    /// Deterministic id derivation. Hashing the objective directly means
    /// the same user prompt at the same turn produces the same id —
    /// helpful for replay and cache hits across "regenerate response"
    /// flows. Length is bounded for filesystem safety (PTF uses this in
    /// directory names).
    static func stableId(
        sessionId: String,
        turnIndex: Int,
        objective: String
    ) -> String {
        var hasher = Hasher()
        hasher.combine(sessionId)
        hasher.combine(turnIndex)
        hasher.combine(objective)
        let h = hasher.finalize()
        return "\(sessionId):\(turnIndex):\(String(format: "%016x", UInt64(bitPattern: Int64(h))))"
    }
}
