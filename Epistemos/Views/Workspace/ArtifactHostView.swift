import SwiftUI

// MARK: - ArtifactHostView (typed-spine renderer)
//
// Cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §6.
//
// Source-preserved exhaustive `@ViewBuilder` dispatch over `ArtifactRoute`.
// The switch yields a different concrete `View` per case — NO `AnyView`,
// per anti-pattern #7 of the canonical register
// (`docs/_consolidated/00_canonical_authority/MASTER_FUSION.md` §11).
//
// This host remains unmounted in v1 while artifact-specific resolvers are
// unfinished. If invoked from a preview or future integration, it renders
// an explicit v1-deferred panel instead of pretending the destination
// viewer exists.

/// Top-level dispatcher. Source-preserved for the typed artifact spine;
/// not a v1 production navigation surface until the route resolvers below
/// are replaced with real viewers.
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
        ArtifactRouteDeferredPanel(
            kind: .proseNote,
            id: artifactID,
            deferredReason: "The note resolver is not enabled for this v1 route."
        )
    }
}

// MARK: - Document host

nonisolated public struct DocumentHost: View {
    public let artifactID: ArtifactID

    public init(artifactID: ArtifactID) {
        self.artifactID = artifactID
    }

    public var body: some View {
        ArtifactRouteDeferredPanel(
            kind: .document,
            id: artifactID,
            deferredReason: "The Epdoc document host is available through the document window flow, not this artifact route."
        )
    }
}

// MARK: - Raw-thought-run host
//
// Wraps `RawThoughtsInspectorView` (`Epistemos/Views/RawThoughts/RawThoughtsInspectorView.swift`).
// The inspector takes a `RawThoughtsState.RunSummary`; this adapter looks
// up the summary by `RunID`. The lookup pipeline is deferred in this
// v1 route, so the host renders an explicit deferred panel.

nonisolated public struct RawThoughtRunHost: View {
    public let runID: RunID

    public init(runID: RunID) {
        self.runID = runID
    }

    public var body: some View {
        ArtifactRouteDeferredPanel(
            kind: .run,
            id: runID,
            deferredReason: "The run-summary resolver is not enabled for this v1 route."
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
        ArtifactRouteDeferredPanel(
            kind: .source,
            id: artifactID,
            deferredReason: "The source reader is deferred for the v1 artifact route."
        )
    }
}

nonisolated public struct CodeHost: View {
    public let artifactID: ArtifactID

    public init(artifactID: ArtifactID) {
        self.artifactID = artifactID
    }

    public var body: some View {
        ArtifactRouteDeferredPanel(
            kind: .code,
            id: artifactID,
            deferredReason: "The code artifact resolver is not enabled for this v1 route."
        )
    }
}

nonisolated public struct OutputHost: View {
    public let artifactID: ArtifactID

    public init(artifactID: ArtifactID) {
        self.artifactID = artifactID
    }

    public var body: some View {
        ArtifactRouteDeferredPanel(
            kind: .output,
            id: artifactID,
            deferredReason: "The output artifact viewer is deferred for the v1 artifact route."
        )
    }
}

// MARK: - ArtifactRouteDeferredPanel
//
// Honest "this route is not enabled in v1" surface. It is intentionally
// explicit so accidental preview/integration calls do not look like a
// working artifact viewer.

nonisolated struct ArtifactRouteDeferredPanel: View {
    let kind: ArtifactKind
    let id: String
    let deferredReason: String

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
                Text("Deferred in v1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(deferredReason)
                    .font(.body)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background)
    }
}
