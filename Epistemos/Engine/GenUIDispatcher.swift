import OSLog
import SwiftUI

// MARK: - GenUIDispatcher (Stage A.3 / GenUI G.2 deliverable)
//
// Per `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` §4 G.2.
// Static registry mapping `GenUISchema` values to renderer types. The
// canonical answer to "given this typed payload, what view do I draw?"
// — every producer in the substrate emits a `GenUIPayload`; every
// consumer renders it via this dispatcher.
//
// Doctrinal posture:
// - Single canonical dispatcher; never duplicate
// - Static registry seeded at AppBootstrap; no per-call-site
//   renderer wiring
// - Unrecognized schemas fall back to FallbackGenUIView (raw JSON
//   dump + copy button) so the renderer can't crash on schema drift
// - Renderers are pure SwiftUI views; no observable / state owned
//   by the dispatcher itself
//
// The seven existing chat-block schemas (json, yaml, csv, codeBlock,
// table, markdown, fileEdit) route through `ArtifactBackedRenderer`
// which adapts the payload back into the existing canonical
// `Artifact` + `ArtifactBlockView` pipeline. This way the dispatcher
// is additive — the existing pipeline stays as the canonical
// chat-block renderer; only the new structured schemas need new
// renderers.

@MainActor
final class GenUIDispatcher {
    static let shared = GenUIDispatcher()

    private static let log = Logger(subsystem: "com.epistemos", category: "GenUIDispatcher")

    /// Registered renderer factories. Each factory takes a payload and
    /// returns an `AnyView`. Factories are pure functions — no captured
    /// state — so registration order doesn't matter.
    private var renderers: [GenUISchema: (GenUIPayload) -> AnyView] = [:]

    private init() {
        registerCanonicalDefaults()
    }

    // MARK: - Public API

    /// Register a renderer for a schema. If a renderer is already
    /// registered, the new one replaces it (caller's responsibility
    /// to know what they're doing). Logs the replacement.
    func register(_ schema: GenUISchema, _ factory: @escaping (GenUIPayload) -> AnyView) {
        if renderers[schema] != nil {
            Self.log.warning("GenUIDispatcher: replacing existing renderer for \(schema.rawValue, privacy: .public)")
        }
        renderers[schema] = factory
    }

    /// Render a payload. If no renderer is registered for the schema,
    /// returns FallbackGenUIView (raw JSON dump + copy). Never crashes.
    @ViewBuilder
    func render(_ payload: GenUIPayload) -> some View {
        if let factory = renderers[payload.schema] {
            factory(payload)
        } else {
            FallbackGenUIView(payload: payload)
        }
    }

    /// Diagnostic: every schema currently registered. Used by the
    /// (future) Provenance Console diagnostics row + by tests.
    var registeredSchemas: Set<GenUISchema> {
        Set(renderers.keys)
    }

    // MARK: - Canonical defaults

    /// Seeds the dispatcher with renderers for every `GenUISchema`
    /// case. Called from init so no AppBootstrap step is required;
    /// the dispatcher is usable from first import. Custom renderers
    /// (e.g. a Provenance-Console-specific provenanceTrace renderer)
    /// can `register(_:_:)` over the default at AppBootstrap time.
    private func registerCanonicalDefaults() {
        // Chat-block schemas → existing ArtifactBlockView pipeline
        // via the adapter. Doctrinally: the seven chat-block schemas
        // are the partial implementation; the adapter preserves their
        // canonical renderer while the dispatcher adds the new shapes.
        let artifactBackedSchemas: [GenUISchema] = [.json, .yaml, .csv, .codeBlock, .table, .markdown, .fileEdit]
        for schema in artifactBackedSchemas {
            renderers[schema] = { payload in
                AnyView(ArtifactBackedGenUIView(payload: payload))
            }
        }

        // New structured schemas
        renderers[.keyValueTable]    = { payload in AnyView(KeyValueTableGenUIView(payload: payload)) }
        renderers[.commandReceipt]   = { payload in AnyView(CommandReceiptGenUIView(payload: payload)) }
        renderers[.actionPanel]      = { payload in AnyView(ActionPanelGenUIView(payload: payload)) }
        renderers[.errorReport]      = { payload in AnyView(ErrorReportGenUIView(payload: payload)) }
        renderers[.progressIndicator] = { payload in AnyView(ProgressIndicatorGenUIView(payload: payload)) }
        renderers[.capabilityList]   = { payload in AnyView(CapabilityListGenUIView(payload: payload)) }
        renderers[.searchResultSet]  = { payload in AnyView(SearchResultSetGenUIView(payload: payload)) }
        renderers[.provenanceTrace]  = { payload in AnyView(FallbackGenUIView(payload: payload)) }
        // Note: provenanceTrace gets a real renderer when the
        // Provenance Console (T2) ships; until then it falls back to
        // the JSON dump.
    }
}

// MARK: - Adapter to existing ArtifactBlockView pipeline
//
// For the seven chat-block schemas, build an `Artifact` from the
// payload + delegate rendering to the canonical `ArtifactBlockView`.
// This is the doctrine-compliant way to keep the existing renderer
// canonical while routing through the new dispatcher API.

private struct ArtifactBackedGenUIView: View {
    let payload: GenUIPayload

    var body: some View {
        if let artifact = makeArtifact(from: payload) {
            ArtifactBlockView(artifact: artifact)
        } else {
            FallbackGenUIView(payload: payload)
        }
    }

    private func makeArtifact(from payload: GenUIPayload) -> Artifact? {
        let kind: ChatArtifactKind
        switch payload.schema {
        case .json:      kind = .json
        case .yaml:      kind = .yaml
        case .csv:       kind = .csv
        case .codeBlock: kind = .codeBlock
        case .table:     kind = .table
        case .markdown:  kind = .markdown
        case .fileEdit:  kind = .fileEdit
        default: return nil
        }
        guard case let .raw(content) = payload.body else {
            // table-shape schemas can land here too; serialize rows
            if case let .rows(headers, cells) = payload.body {
                return Artifact(
                    id: payload.id,
                    kind: kind,
                    title: payload.title,
                    language: payload.metadata["language"],
                    content: serializeRows(headers: headers, cells: cells),
                    schemaName: payload.schema.rawValue,
                    createdAt: payload.createdAt
                )
            }
            return nil
        }
        return Artifact(
            id: payload.id,
            kind: kind,
            title: payload.title,
            language: payload.metadata["language"],
            content: content,
            schemaName: payload.schema.rawValue,
            createdAt: payload.createdAt
        )
    }

    private func serializeRows(headers: [String], cells: [[String]]) -> String {
        var lines: [String] = []
        lines.append(headers.joined(separator: "\t"))
        for row in cells {
            lines.append(row.joined(separator: "\t"))
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - New canonical renderers

private struct KeyValueTableGenUIView: View {
    let payload: GenUIPayload
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !payload.title.isEmpty {
                Text(payload.title)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if case let .keyValues(pairs) = payload.body {
                let maxKeyWidth = pairs.map { $0.key.count }.max() ?? 12
                ForEach(pairs) { pair in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(pair.key)
                            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: CGFloat(maxKeyWidth) * 7.5, alignment: .leading)
                        Text(pair.value)
                            .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

private struct CommandReceiptGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        if case let .raw(text) = payload.body {
            Text(text)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ActionPanelGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        if case let .actions(actions) = payload.body {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    Button(action: { /* GenUI G.3 — wire via host closure when needed */ }) {
                        Text(action.label)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ErrorReportGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        if case let .error(title, detail, hint, _) = payload.body {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                if let hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.red.opacity(0.08))
            )
        }
    }
}

private struct ProgressIndicatorGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        if case let .progress(label, total, value) = payload.body {
            HStack(spacing: 8) {
                ProgressView(value: value, total: total)
                    .controlSize(.small)
                Text(label)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CapabilityListGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        if case let .rows(headers, cells) = payload.body {
            VStack(alignment: .leading, spacing: 4) {
                if !payload.title.isEmpty {
                    Text(payload.title)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                }
                HStack(spacing: 12) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                        Text(header)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, 2)
                ForEach(Array(cells.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 12) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}

private struct SearchResultSetGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        // searchResultSet uses .rows; reuse the capability-list shape
        // but with title-prominent first column. Same renderer body
        // works for now; a search-specific layout can replace this
        // when the search panel's result-set view stabilizes.
        CapabilityListGenUIView(payload: payload)
    }
}

// MARK: - Fallback (never crashes on schema drift)

struct FallbackGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.app.dashed")
                    .foregroundStyle(.tertiary)
                Text("GenUI fallback (no renderer for schema='\(payload.schema.rawValue)')")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if let json = try? JSONEncoder().encode(payload),
               let text = String(data: json, encoding: .utf8) {
                Text(text)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .lineLimit(20)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
