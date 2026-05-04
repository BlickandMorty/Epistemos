import Foundation

// MARK: - GenUIPayload (Stage A.2 / GenUI G.1 deliverable)
//
// Per `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` §4 G.1.
// Promotes the chat-block-only `Artifact` (Models/Artifact.swift) into
// the universal typed payload that every producer in the substrate —
// Hermes commands, tool results, agent emissions, MutationEnvelopes,
// cloud responses, system notifications — emits when it has structured
// output to render.
//
// Why this lives alongside `Artifact` and not as a replacement: the
// existing `Artifact` + `ArtifactBlockView` pipeline is the canonical
// chat-content-block renderer (json/yaml/csv/codeBlock/table/markdown/
// fileEdit). It stays canonical for those seven shapes. `GenUIPayload`
// is the broader sum that ALSO includes those seven shapes (via the
// .raw body case) plus the new structured shapes (keyValueTable,
// commandReceipt, actionPanel, errorReport, progressIndicator,
// capabilityList, searchResultSet, provenanceTrace) per §4 G.1.
//
// Cross-runtime compatibility: this struct is `Codable` so the Rust
// kernel can emit equivalent payloads (Phase G.4) and the Swift side
// renders them via the dispatcher.

nonisolated struct GenUIPayload: Identifiable, Codable, Sendable, Hashable {
    /// Stable per-payload UUID. Used by SwiftUI for diffing.
    let id: String
    /// The schema discriminator — drives renderer selection in the
    /// `GenUIDispatcher` registry.
    let schema: GenUISchema
    /// Display title for the rendered card / row / panel.
    let title: String
    /// Typed body envelope. Each `GenUIBody` case maps to one or more
    /// `GenUISchema` values; not every (schema, body) pairing is
    /// valid — see `GenUISchema.canonicalBody(...)` for the mapping.
    let body: GenUIBody
    /// Free-form metadata for renderer hints (e.g. "language=python"
    /// for codeBlock, "intent=switch_provider" for actionPanel).
    let metadata: [String: String]
    /// When the payload was emitted. Used by some renderers for
    /// recency-aware styling and by replay tooling for ordering.
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        schema: GenUISchema,
        title: String,
        body: GenUIBody,
        metadata: [String: String] = [:],
        createdAt: Date = .now
    ) {
        self.id = id
        self.schema = schema
        self.title = title
        self.body = body
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

// MARK: - Schema (the closed enum)

nonisolated enum GenUISchema: String, Codable, Sendable, CaseIterable, Hashable {
    // ── Existing chat-block shapes (mirror of ChatArtifactKind) ──
    /// JSON tree (rendered via existing ArtifactBlockView path)
    case json
    /// YAML key-value document (rendered via existing ArtifactBlockView)
    case yaml
    /// CSV table (rendered via existing ArtifactBlockView)
    case csv
    /// Code block with optional `language` metadata
    case codeBlock
    /// Generic table (rendered via existing ArtifactBlockView)
    case table
    /// Markdown content (rendered via existing ArtifactBlockView)
    case markdown
    /// File-edit diff
    case fileEdit

    // ── New structured shapes (Phase G.1) ──
    /// Two-column key/value table — `/status`, `/config show`,
    /// `/tokens`, `/cost` shape. Body must be `.keyValues(...)`.
    case keyValueTable
    /// Single terse line of system output — `/calc =`, `/clear` echo,
    /// info row. Body must be `.raw(...)`.
    case commandReceipt
    /// Row of buttons with optional payloads — for "Open Settings",
    /// "Retry", "Approve & continue". Body must be `.actions(...)`.
    case actionPanel
    /// Structured error: title + detail + optional hint + recovery
    /// actions. Body must be `.error(...)`.
    case errorReport
    /// Streaming inference / long-running task indicator. Body must
    /// be `.progress(...)`.
    case progressIndicator
    /// `/help` shape — list of commands with metadata (token,
    /// surface, tier, native equivalent). Body is `.rows(...)`.
    case capabilityList
    /// `/search` shape — list of titled hits with snippets + entity
    /// refs. Body is `.rows(...)` with canonical headers.
    case searchResultSet
    /// AgentEvent chain or replay summary; recursive payload.
    case provenanceTrace

    /// Whether the body shape matches what this schema expects.
    /// Renderers can `precondition(canonicalBody(payload.body))` to
    /// catch drift early; the GenUIDispatcher itself logs but doesn't
    /// crash on mismatch (renders a FallbackGenUIView instead).
    func canonicalBody(_ body: GenUIBody) -> Bool {
        switch (self, body) {
        case (.json, .raw),
             (.yaml, .raw),
             (.csv, .raw),
             (.codeBlock, .raw),
             (.markdown, .raw),
             (.fileEdit, .raw),
             (.commandReceipt, .raw):
            return true
        case (.table, .rows),
             (.capabilityList, .rows),
             (.searchResultSet, .rows):
            return true
        case (.keyValueTable, .keyValues):
            return true
        case (.actionPanel, .actions):
            return true
        case (.errorReport, .error):
            return true
        case (.progressIndicator, .progress):
            return true
        case (.provenanceTrace, .provenanceChain):
            return true
        default:
            return false
        }
    }
}

// MARK: - Body envelope

indirect nonisolated enum GenUIBody: Codable, Sendable, Hashable {
    /// Raw string content (json text, markdown source, code, csv text).
    case raw(String)
    /// Ordered (key, value) pairs for keyValueTable.
    case keyValues([GenUIKeyValue])
    /// Tabular rows with explicit headers for table / capabilityList /
    /// searchResultSet.
    case rows(headers: [String], cells: [[String]])
    /// Buttons for actionPanel.
    case actions([GenUIAction])
    /// Structured error.
    case error(title: String, detail: String, hint: String?, options: [GenUIAction])
    /// Progress with bounded total / current value (e.g. tokens
    /// streamed / total tokens).
    case progress(label: String, total: Double, value: Double)
    /// Recursive payload chain for provenance traces.
    case provenanceChain([GenUIPayload])
}

// MARK: - Helper structs

nonisolated struct GenUIKeyValue: Codable, Sendable, Hashable, Identifiable {
    var id: String { key }
    let key: String
    let value: String
    init(_ key: String, _ value: String) {
        self.key = key
        self.value = value
    }
}

nonisolated struct GenUIAction: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let label: String
    let kind: ActionKind
    /// Optional payload — for `.rerun` this is the command to re-run;
    /// for `.open` it's a URL or vault ref; for `.custom` it's whatever
    /// the renderer + handler agreed on.
    let payload: String?

    nonisolated enum ActionKind: String, Codable, Sendable, Hashable {
        case rerun
        case copy
        case save
        case open
        case dismiss
        case custom
    }

    init(
        id: String = UUID().uuidString,
        label: String,
        kind: ActionKind,
        payload: String? = nil
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.payload = payload
    }
}

// MARK: - Convenience constructors (so producers don't write boilerplate)

extension GenUIPayload {
    /// Single-line terse echo. Schema = `.commandReceipt`, body = `.raw(text)`.
    static func receipt(_ text: String, title: String = "") -> GenUIPayload {
        .init(schema: .commandReceipt, title: title, body: .raw(text))
    }

    /// Key-value panel. Schema = `.keyValueTable`.
    static func keyValueTable(
        title: String,
        _ pairs: [(String, String)],
        id: String = UUID().uuidString,
        metadata: [String: String] = [:],
        createdAt: Date = .now
    ) -> GenUIPayload {
        .init(
            id: id,
            schema: .keyValueTable,
            title: title,
            body: .keyValues(pairs.map { GenUIKeyValue($0.0, $0.1) }),
            metadata: metadata,
            createdAt: createdAt
        )
    }

    /// Markdown card. Schema = `.markdown`.
    static func markdownCard(
        title: String,
        _ markdown: String,
        id: String = UUID().uuidString,
        metadata: [String: String] = [:],
        createdAt: Date = .now
    ) -> GenUIPayload {
        .init(
            id: id,
            schema: .markdown,
            title: title,
            body: .raw(markdown),
            metadata: metadata,
            createdAt: createdAt
        )
    }

    /// YAML card. Schema = `.yaml`.
    static func yamlCard(title: String, _ yaml: String) -> GenUIPayload {
        .init(schema: .yaml, title: title, body: .raw(yaml), metadata: ["language": "yaml"])
    }

    /// Capability list (used by `/help`, `/model list`, etc.).
    static func capabilityList(
        title: String,
        headers: [String],
        rows: [[String]]
    ) -> GenUIPayload {
        .init(
            schema: .capabilityList,
            title: title,
            body: .rows(headers: headers, cells: rows)
        )
    }

    /// Search result set.
    static func searchResults(query: String, rows: [[String]]) -> GenUIPayload {
        .init(
            schema: .searchResultSet,
            title: "Search '\(query)'",
            body: .rows(headers: ["#", "title", "snippet"], cells: rows),
            metadata: ["query": query]
        )
    }

    /// Recursive provenance chain. Schema = `.provenanceTrace`.
    static func provenanceTrace(
        title: String,
        events: [GenUIPayload],
        metadata: [String: String] = [:]
    ) -> GenUIPayload {
        .init(
            schema: .provenanceTrace,
            title: title,
            body: .provenanceChain(events),
            metadata: metadata
        )
    }

    /// Structured error.
    static func errorReport(title: String, detail: String, hint: String? = nil, options: [GenUIAction] = []) -> GenUIPayload {
        .init(
            schema: .errorReport,
            title: title,
            body: .error(title: title, detail: detail, hint: hint, options: options)
        )
    }
}
