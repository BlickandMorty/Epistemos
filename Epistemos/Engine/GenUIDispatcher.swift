import SwiftUI

// MARK: - GenUIDispatcher (Stage A.3 / GenUI G.2 deliverable)
//
// Per `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` §4 G.2.
// Static schema switch mapping `GenUISchema` values to renderer types.
// The canonical answer to "given this typed payload, what view do I draw?"
// -- every producer in the substrate emits a `GenUIPayload`; every
// consumer renders it via this dispatcher.
//
// Doctrinal posture:
// - Single canonical dispatcher; never duplicate
// - Unrecognized schemas fall back to FallbackGenUIView (raw JSON
//   dump + copy button) so the renderer can't crash on schema drift
// - Renderers are pure SwiftUI views; no observable / state owned
//   by the dispatcher itself
//
// The seven existing chat-block schemas (json, yaml, csv, codeBlock,
// table, markdown, fileEdit) route through `ArtifactBackedRenderer`
// which adapts the payload back into the existing canonical
// `Artifact` + `ArtifactBlockView` pipeline. This way the dispatcher
// is additive -- the existing pipeline stays as the canonical
// chat-block renderer; only the new structured schemas need new
// renderers.

@MainActor
final class GenUIDispatcher {
    static let shared = GenUIDispatcher()

    private init() {}

    // MARK: - Public API

    /// Render a payload. If a schema has no dedicated renderer yet,
    /// returns FallbackGenUIView (raw JSON dump + copy). Never crashes.
    @ViewBuilder
    func render(_ payload: GenUIPayload) -> some View {
        switch payload.schema {
        case .json, .yaml, .csv, .codeBlock, .table, .markdown, .fileEdit:
            ArtifactBackedGenUIView(payload: payload)
        case .keyValueTable:
            KeyValueTableGenUIView(payload: payload)
        case .commandReceipt:
            CommandReceiptGenUIView(payload: payload)
        case .actionPanel:
            ActionPanelGenUIView(payload: payload)
        case .errorReport:
            ErrorReportGenUIView(payload: payload)
        case .progressIndicator:
            ProgressIndicatorGenUIView(payload: payload)
        case .capabilityList:
            CapabilityListGenUIView(payload: payload)
        case .searchResultSet:
            SearchResultSetGenUIView(payload: payload)
        case .provenanceTrace:
            ProvenanceTraceGenUIView(payload: payload)
        }
    }

    /// Diagnostic: every schema with a deterministic dispatch branch.
    /// Used by the Provenance Console diagnostics row + by tests.
    /// Returns a sorted array (NOT a Set) so iteration order is stable
    /// across runs. Swift's Set iteration is randomized per-process
    /// per-launch, which would make the diagnostic surface non-replayable.
    var registeredSchemas: [GenUISchema] {
        GenUISchema.allCases.sorted { $0.rawValue < $1.rawValue }
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
        // Per RCA13 P1-019: until the GenUI G.3 host-closure plumbing
        // lands, action panels must not render clickable buttons that
        // do nothing — the previous implementation showed a styled
        // pill with an empty closure, which lied about whether the
        // user could act. We render the action labels as inert chips
        // with reduced contrast + a "preview" hint so the schema is
        // still visible (so producers can keep emitting it) but the
        // UI is honest about the action not being wired yet.
        if case let .actions(actions) = payload.body {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    Text(action.label)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(.primary.opacity(0.04))
                        )
                        .overlay(
                            Capsule().stroke(.primary.opacity(0.10), lineWidth: 0.5)
                        )
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(action.label) — preview, action not yet wired")
                }
                Spacer(minLength: 0)
                Image(systemName: "hourglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .help("Action panel preview — host wiring pending (RCA13 P1-019)")
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
                    ForEach(headers.indices, id: \.self) { idx in
                        Text(headers[idx])
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, 2)
                ForEach(cells.indices, id: \.self) { rowIdx in
                    HStack(spacing: 12) {
                        let row = cells[rowIdx]
                        ForEach(row.indices, id: \.self) { colIdx in
                            Text(row[colIdx])
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

private struct ProvenanceTraceGenUIView: View {
    let payload: GenUIPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !payload.title.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "timeline.selection")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                    Text(payload.title)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            if case let .provenanceChain(events) = payload.body, !events.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(events) { event in
                        ProvenanceTraceEventRow(payload: event)
                    }
                }
            } else {
                Text("No committed provenance events yet")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
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

private struct ProvenanceTraceEventRow: View {
    let payload: GenUIPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !payload.title.isEmpty {
                Text(payload.title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            switch payload.body {
            case .keyValues(let pairs):
                ForEach(pairs) { pair in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(pair.key)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 92, alignment: .leading)
                        Text(pair.value)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
            case .raw(let text):
                Text(text)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            default:
                Text(payload.schema.rawValue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 10)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.secondary.opacity(0.24))
                .frame(width: 2)
        }
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
            if let json = try? GenUIPayload.canonicalJSONEncoder().encode(payload),
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
