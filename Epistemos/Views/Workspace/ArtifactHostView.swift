import AppKit
import Combine
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
// Most artifact-specific resolvers remain unfinished in v1 and still
// render explicit deferred panels. HTML Workspace is the first live route:
// it reuses the existing WKWebView preview for already-open workspace
// packages and shows an honest missing-workspace panel otherwise.

/// Top-level dispatcher. Source-preserved for the typed artifact spine.
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
        case .htmlWorkspace(let id):
            HTMLWorkspaceArtifactHost(workspaceID: id)
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

// MARK: - Retired run host
//
// The native raw-thought timeline surface was retired with the old native
// agent stack. Existing routes render an explicit deferred panel instead of
// reviving that UI.

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

// MARK: - HTML Workspace host

nonisolated public struct HTMLWorkspaceArtifactHost: View {
    public let workspaceID: ArtifactID
    @State private var observedPackage: HTMLWorkspacePackage?

    public init(workspaceID: ArtifactID) {
        self.workspaceID = workspaceID
    }

    @MainActor
    @ViewBuilder
    public var body: some View {
        Group {
            if let package = currentPackage {
                VStack(spacing: 0) {
                    HTMLWorkspacePreviewView(
                        package: package,
                        safeAPIEnabled: false,
                        previewTheme: nil
                    )
                    .id(HTMLWorkspacePreviewIdentity.viewIdentity(for: package))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if package.manifest.dataFeed != nil {
                        Divider()
                        HTMLWorkspaceDataFeedStatusStrip(package: package)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(.background)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            } else {
                HTMLWorkspaceMissingPanel(workspaceID: workspaceID)
            }
        }
        .onAppear {
            refreshOpenPackage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlWorkspacePackageDidChange)) { notification in
            guard (notification.userInfo?["workspaceID"] as? String) == workspaceID else { return }
            if let document = notification.object as? HTMLWorkspaceDocument {
                observedPackage = document.package
            } else {
                refreshOpenPackage()
            }
        }
    }

    @MainActor
    private var currentPackage: HTMLWorkspacePackage? {
        observedPackage ?? Self.openDocument(matching: workspaceID)?.package
    }

    @MainActor
    private func refreshOpenPackage() {
        observedPackage = Self.openDocument(matching: workspaceID)?.package
    }

    @MainActor
    private static func openDocument(matching workspaceID: String) -> HTMLWorkspaceDocument? {
        let targetID = workspaceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetID.isEmpty else { return nil }

        let controller = NSDocumentController.shared
        return controller.documents
            .compactMap { $0 as? HTMLWorkspaceDocument }
            .first { $0.package.manifest.id == targetID }
    }

}

nonisolated struct HTMLWorkspaceMissingPanel: View {
    let workspaceID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "curlybraces.square")
                    .foregroundStyle(.secondary)
                Text("HTML Workspace")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Workspace id")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(workspaceID)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Workspace not open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Open the matching .htmlworkspace package to render its live preview here.")
                    .font(.body)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background)
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
