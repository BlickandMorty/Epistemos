import SwiftUI

// MARK: - ArtifactHostView (typed-spine renderer)
//
// T+4.7 of `docs/audits/deliberation/T+4_cognitive_artifact_spine_deliberation_20260427.md`
// (cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §6).
//
// Compile-time exhaustive `@ViewBuilder` dispatch over `ArtifactRoute`.
// The switch yields a different concrete `View` per case — NO `AnyView`,
// per anti-pattern #7 of the canonical register
// (`docs/_consolidated/00_canonical_authority/MASTER_FUSION.md` §11).
//
// The route's destination View is wrapped in a thin "host" struct so
// the protected `ProseEditorView` and `CodeEditorView` surfaces stay
// untouched (per CLAUDE.md DO NOT list). The host resolves the
// `ArtifactID` / `RunID` to whatever its destination needs (a SwiftData
// `SDPage`, a `RunSummary`, etc.) and only then constructs the editor.
//
// For routes whose final destination editor hasn't shipped yet
// (`DocumentEditorHostView` lands in T+4.6, `SourceReaderView` /
// `OutputArtifactView` in later slices), the host displays an explicit
// "pending implementation" placeholder. These are NOT silent fallbacks
// (anti-pattern #11) — they declare exactly which kind + id was
// requested and which slice will fill them in.

/// Top-level dispatcher. Hand it a route and it renders the right
/// surface for that artifact kind.
nonisolated public struct ArtifactHostView: View {
    public let route: ArtifactRoute

    public init(route: ArtifactRoute) {
        self.route = route
    }

    @ViewBuilder
    public var body: some View {
        switch route {
        case .proseNote(let id):
            ProseNoteHost(artifactID: id)
        case .document(let id):
            DocumentHost(artifactID: id)
        case .rawThoughtRun(let id):
            RawThoughtRunHost(runID: id)
        case .source(let id):
            SourceHost(artifactID: id)
        case .code(let id):
            CodeHost(artifactID: id)
        case .output(let id):
            OutputHost(artifactID: id)
        }
    }
}

// MARK: - ProseNote host
//
// Resolves the `ArtifactID` (a `SDPage` SwiftData id) and presents the
// existing `ProseEditorView` (`Epistemos/Views/Notes/ProseEditorView.swift`,
// PROTECTED per CLAUDE.md DO NOT list — never edited from this slice).

nonisolated public struct ProseNoteHost: View {
    public let artifactID: ArtifactID

    public init(artifactID: ArtifactID) {
        self.artifactID = artifactID
    }

    public var body: some View {
        // T+4.7 wires the route → host adapter; the actual SDPage
        // resolution + ProseEditorView construction depends on a
        // `SwiftData.ModelContext` injection that ships in T+4.9
        // (Agent patch + provenance workflow links). Surface an
        // explicit pending-resolution panel until then so the user
        // sees what was requested and which slice will close the loop.
        ArtifactRoutePendingPanel(
            kind: .proseNote,
            id: artifactID,
            pendingSliceLabel: "T+4.9 (SDPage resolver wiring)"
        )
    }
}

// MARK: - Document host (Tiptap-in-WKWebView host arrives in T+4.6)

nonisolated public struct DocumentHost: View {
    public let artifactID: ArtifactID

    public init(artifactID: ArtifactID) {
        self.artifactID = artifactID
    }

    public var body: some View {
        ArtifactRoutePendingPanel(
            kind: .document,
            id: artifactID,
            pendingSliceLabel: "T+4.6 (Document editor host: Tiptap + WKWebView)"
        )
    }
}

// MARK: - Raw-thought-run host
//
// Wraps `RawThoughtsInspectorView` (`Epistemos/Views/RawThoughts/RawThoughtsInspectorView.swift`).
// The inspector takes a `RawThoughtsState.RunSummary`; this adapter looks
// up the summary by `RunID`. Until the lookup pipeline is wired in T+4.3
// (Raw Thoughts to 100%), present a pending panel so the user sees which
// run was requested.

nonisolated public struct RawThoughtRunHost: View {
    public let runID: RunID

    public init(runID: RunID) {
        self.runID = runID
    }

    public var body: some View {
        ArtifactRoutePendingPanel(
            kind: .run,
            id: runID,
            pendingSliceLabel: "T+4.3 (Raw Thoughts substrate to 100% — RunSummary resolver)"
        )
    }
}

// MARK: - Source / Code / Output hosts

nonisolated public struct SourceHost: View {
    public let artifactID: ArtifactID

    public init(artifactID: ArtifactID) {
        self.artifactID = artifactID
    }

    public var body: some View {
        ArtifactRoutePendingPanel(
            kind: .source,
            id: artifactID,
            pendingSliceLabel: "T+4.5 (.epdoc package + Source reader)"
        )
    }
}

nonisolated public struct CodeHost: View {
    public let artifactID: ArtifactID

    public init(artifactID: ArtifactID) {
        self.artifactID = artifactID
    }

    public var body: some View {
        // `CodeEditorView` (`Epistemos/Views/Notes/CodeEditorView.swift`,
        // line 1183) takes a richer parameter set than just an artifact
        // id — its full integration goes through the editor host
        // pipeline that lands in T+4.9 (agent patch / provenance
        // graph edges).
        ArtifactRoutePendingPanel(
            kind: .code,
            id: artifactID,
            pendingSliceLabel: "T+4.9 (Code artifact resolver wiring)"
        )
    }
}

nonisolated public struct OutputHost: View {
    public let artifactID: ArtifactID

    public init(artifactID: ArtifactID) {
        self.artifactID = artifactID
    }

    public var body: some View {
        ArtifactRoutePendingPanel(
            kind: .output,
            id: artifactID,
            pendingSliceLabel: "T+4.5 / T+4.9 (Output artifact viewer)"
        )
    }
}

// MARK: - ArtifactRoutePendingPanel (explicit placeholder)
//
// Honest "this slice hasn't connected yet" surface. Visible enough for
// the user to know the route reached its router; specific enough that a
// dev reader can find the next slice in the dependency chain.

nonisolated struct ArtifactRoutePendingPanel: View {
    let kind: ArtifactKind
    let id: String
    let pendingSliceLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .foregroundStyle(.secondary)
                Text(kind.displayName)
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Artifact id")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(id)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Pending slice")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(pendingSliceLabel)
                    .font(.body)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background)
    }
}
