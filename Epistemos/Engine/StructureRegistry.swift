import Foundation

// MARK: - StructureRegistry
//
// Per `docs/STRUCTURING_AUDIT.md` §"Self-introspection": canonical
// catalog of every structured-data schema produced anywhere in the
// app. The local LLM (and any debug/diagnostic surface) can ask
// `StructureRegistry.shared.allSchemas` to answer "what does my host
// know about?" without guessing or scanning source code.
//
// Every entry maps an input surface (where messy data enters the
// app) to the structured shape it produces and the persistent store
// that shape lands in. Add a new entry whenever you wire up a new
// `@Generable` schema or AFM extraction step.
//
// This is INTROSPECTION metadata — it does NOT replace the actual
// schema declarations on the @Generable types. It's a fast lookup
// the LLM can use as an MCP resource.

public struct StructureSchemaDescriptor: Sendable, Identifiable, Hashable {

    /// Stable kebab-case id, e.g. `"intake_decision"`. Used as the
    /// MCP resource URI suffix.
    public let id: String

    /// Surface where messy input enters (matches `STRUCTURING_AUDIT.md`
    /// row labels — `paste`, `quick_capture`, `note_save`, etc.)
    public let surface: String

    /// Persistent store where the structured result lands.
    public let storage: StoragePlane

    /// Name of the Swift `@Generable` type that defines the schema.
    /// Used by the LLM to look up field-level docs.
    public let swiftType: String

    /// Build profiles where this surface is active. Lets the local
    /// LLM avoid recommending schemas that don't exist in the
    /// current build (e.g. iMessage intent in MAS).
    public let profiles: Set<BuildProfile>

    /// Maturity: which audit row state in `STRUCTURING_AUDIT.md`.
    public let maturity: SchemaMaturity

    /// One-line human-readable summary. Goes into MCP resource descriptions.
    public let summary: String

    public init(
        id: String,
        surface: String,
        storage: StoragePlane,
        swiftType: String,
        profiles: Set<BuildProfile>,
        maturity: SchemaMaturity,
        summary: String
    ) {
        self.id = id
        self.surface = surface
        self.storage = storage
        self.swiftType = swiftType
        self.profiles = profiles
        self.maturity = maturity
        self.summary = summary
    }
}

public enum StoragePlane: String, Sendable, CaseIterable {
    case swiftData               // SDPage, SDMessage, SDGraphNode, etc.
    case grdb                    // EventStore, conversation_state, oplog
    case sidecar                 // <Entity>.epistemos.json sibling
    case quarantineArchive       // W10.15 ambient retrieval
    case fileBacked              // AgentAuthorityStore, configs
    case inMemory                // No persistence (transient)
}

public enum BuildProfile: String, Sendable, CaseIterable {
    case mas                     // App Store / sandboxed
    case pro                     // Hardened Runtime / full-feature
}

public enum SchemaMaturity: String, Sendable, CaseIterable {
    case full                    // AFM @Generable + persisted
    case partial                 // Persisted but no AFM extraction
    case raw                     // Free text / in-memory only
}

// MARK: - Registry

/// Catalog of every structured-data schema in the app. Static so any
/// caller (UI, agent, local LLM via MCP resource) can read without
/// touching the actor.
public enum StructureRegistry {

    public static var allSchemas: [StructureSchemaDescriptor] { canonicalSchemas }

    /// Look up by stable id. Returns nil if the schema isn't
    /// registered (e.g. asking for a Pro-only schema in the MAS
    /// build — caller should check profiles too).
    public static func schema(id: String) -> StructureSchemaDescriptor? {
        canonicalSchemas.first { $0.id == id }
    }

    /// Filter to schemas active in the given build profile.
    public static func schemas(for profile: BuildProfile) -> [StructureSchemaDescriptor] {
        canonicalSchemas.filter { $0.profiles.contains(profile) }
    }

    /// Filter to a specific maturity tier — useful when the cognitive
    /// layer wants to know "what unstructured surfaces exist that I
    /// could improve?"
    public static func schemas(maturity: SchemaMaturity) -> [StructureSchemaDescriptor] {
        canonicalSchemas.filter { $0.maturity == maturity }
    }

    /// JSON projection for the MCP resource. Same data, machine-
    /// readable so the on-device LLM can ingest the catalog as a
    /// structured tool result.
    public static func jsonCatalog() -> String {
        let entries = canonicalSchemas.map { s in
            [
                "id": s.id,
                "surface": s.surface,
                "storage": s.storage.rawValue,
                "swift_type": s.swiftType,
                "profiles": s.profiles.map(\.rawValue).sorted(),
                "maturity": s.maturity.rawValue,
                "summary": s.summary,
            ] as [String: Any]
        }
        let envelope: [String: Any] = [
            "version": 1,
            "generated_at": ISO8601DateFormatter().string(from: Date()),
            "schemas": entries,
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys, .prettyPrinted]),
            let str = String(data: data, encoding: .utf8)
        else {
            return "{\"version\":1,\"schemas\":[]}"
        }
        return str
    }
}

// MARK: - Canonical entries
//
// Mirrors `docs/STRUCTURING_AUDIT.md` rows. When you add a new
// `@Generable` schema or wire a new structuring step, add an entry
// here so the registry stays the single source of truth.

private let canonicalSchemas: [StructureSchemaDescriptor] = [
    .init(
        id: "intake_decision",
        surface: "paste",
        storage: .quarantineArchive,
        swiftType: "IntakeDecision",
        profiles: [.mas, .pro],
        maturity: .full,
        summary: "W10.14 IntakeValve route — matchExisting / newConcept / ambient / noise. AFM tier-C classifies pasted content before it lands in the editor."
    ),
    .init(
        id: "ontology_node",
        surface: "note_save",
        storage: .swiftData,
        swiftType: "OntologyNode",
        profiles: [.mas, .pro],
        maturity: .full,
        summary: "W10.1 OntologyClassifier — recursive @Generable enum that tags content with parentDomain / childConcept / depth. Emits SDGraphNode rows."
    ),
    .init(
        id: "session_telemetry",
        surface: "session_close",
        storage: .grdb,
        swiftType: "SessionTelemetry",
        profiles: [.mas, .pro],
        maturity: .full,
        summary: "W10.9 SessionTelemetryClassifier — AFM-distilled @Generable summary of an agent session (reasoning, outcomes, follow-ups)."
    ),
    .init(
        id: "capture_result",
        surface: "quick_capture",
        storage: .swiftData,
        swiftType: "CaptureResult",
        profiles: [.mas, .pro],
        maturity: .partial,
        summary: "TextCapturePipeline output — title + entities + tasks + sourceSpans + graphWriteSummary. Codable today; AFM @Generable wrap is gap G1."
    ),
    .init(
        id: "conversation_state",
        surface: "chat_turn",
        storage: .grdb,
        swiftType: "ConversationState",
        profiles: [.mas, .pro],
        maturity: .full,
        summary: "W10.16 ConversationStateClassifier — real-time stenographer rebuild of the active chat (depth markers, emotional valence, open threads)."
    ),
    .init(
        id: "fsrs_decay_state",
        surface: "review_event",
        storage: .grdb,
        swiftType: "FSRSDecayState",
        profiles: [.mas, .pro],
        maturity: .partial,
        summary: "W10.2 FSRS-6 spaced-repetition state per note. AFM not involved — algorithmic only — so maturity is Partial by definition."
    ),
    .init(
        id: "search_intent",
        surface: "search_query",
        storage: .inMemory,
        swiftType: "SearchIntent",
        profiles: [.mas, .pro],
        maturity: .raw,
        summary: "Gap G2 — pre-classify search queries (BM25 vs HNSW vs graph traversal) via IntakeValve tier B + AFM tier C."
    ),
    .init(
        id: "intent_classification",
        surface: "chat_input",
        storage: .swiftData,
        swiftType: "IntentClassification",
        profiles: [.mas, .pro],
        maturity: .raw,
        summary: "Gap G1 — wrap free-form chat input in @Generable IntentClassification (intent, confidence, entities, context flags) before SDMessage creation."
    ),
    .init(
        id: "vault_path_validator",
        surface: "settings_path_input",
        storage: .fileBacked,
        swiftType: "VaultPathValidator",
        profiles: [.mas, .pro],
        maturity: .raw,
        summary: "Gap G5 — validate user-entered vault paths (exists / readable / indexable) at settings save with audit trail."
    ),
    .init(
        id: "epdoc_block",
        surface: "epdoc_save",
        storage: .sidecar,
        swiftType: "EpdocBlock",
        profiles: [.mas, .pro],
        maturity: .raw,
        summary: "Gap G6 — extract Tiptap/ProseMirror DOM into structured @Generable EpdocBlock[] (code, headings, links, transclusions) on .epdoc package save."
    ),
    .init(
        id: "screen_element",
        surface: "screen_capture",
        storage: .inMemory,
        swiftType: "ScreenElement",
        profiles: [.pro],
        maturity: .raw,
        summary: "Gap G8 (Pro only) — Screen2AXFusion → @Generable ScreenElement[] with role / label / bounding box / inferred semantic. AX permission-gated."
    ),
    .init(
        id: "imessage_intent",
        surface: "imessage_inbound",
        storage: .swiftData,
        swiftType: "MessageIntent",
        profiles: [.pro],
        maturity: .raw,
        summary: "Gap G9 (Pro only) — light @Generable classification on inbound iMessage (command / question / confirmation) before DriverChannelToolExecutor dispatch."
    ),

    // MARK: - N1 — Prompt Tree (JSPF + PTF) shape descriptors
    //
    // The prompt itself is structured data the app produces. Cataloging
    // each subtree here means the local LLM (via MCP resource) can
    // answer "what shapes do you send?" by reading the registry — no
    // guesswork. Adding these entries also makes the StructuredSurfaces
    // settings tab (Settings → Agent → Structures) display the prompt
    // shape alongside the @Generable schemas.

    .init(
        id: "prompt_root",
        surface: "agent_invocation",
        storage: .fileBacked,
        swiftType: "Prompt",
        profiles: [.mas, .pro],
        maturity: .full,
        summary: "N1 root JSPF — Codable+Sendable+Hashable Prompt struct composed deterministically from typed inputs. Persisted to PTF at <vault>/.epistemos/prompts/<session>/<turn>/manifest.json."
    ),
    .init(
        id: "prompt_identity",
        surface: "agent_invocation",
        storage: .fileBacked,
        swiftType: "IdentitySection",
        profiles: [.mas, .pro],
        maturity: .full,
        summary: "N1 identity subtree — system role + persona + capability manifest. Heaviest stable cacheable block; one of four breakpoints in Anthropic Messages render."
    ),
    .init(
        id: "prompt_tools",
        surface: "agent_invocation",
        storage: .fileBacked,
        swiftType: "[ToolSpec]",
        profiles: [.mas, .pro],
        maturity: .full,
        summary: "N1 tools subtree — array of ToolSpec mirroring the Anthropic Messages tool schema field-for-field. Stable per session; cached as a single breakpoint."
    ),
    .init(
        id: "prompt_memory",
        surface: "agent_invocation",
        storage: .fileBacked,
        swiftType: "MemorySection",
        profiles: [.mas, .pro],
        maturity: .full,
        summary: "N1 memory subtree — recent chats (ConversationState JSON when available) + relevant notes + ontology refs. Highest-volatility section; relocated to user-message tail per Relocation Trick when Anthropic-targeted."
    ),
    .init(
        id: "prompt_task",
        surface: "agent_invocation",
        storage: .fileBacked,
        swiftType: "TaskSection",
        profiles: [.mas, .pro],
        maturity: .full,
        summary: "N1 task subtree — the active objective + mode + effort tier. Always churns per turn; placed at prompt tail with cache_control: ephemeral as the current-turn breakpoint."
    ),
]
