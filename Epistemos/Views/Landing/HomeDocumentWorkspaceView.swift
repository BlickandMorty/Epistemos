import AppKit
import SwiftData
import SwiftUI

enum HomeDocumentSelection: Equatable, Sendable {
    case page(id: String, title: String, initialMode: NoteWorkspaceMode)
    case document(URL)

    var identity: String {
        switch self {
        case .page(let id, _, let initialMode):
            "page:\(id):\(initialMode.rawValue)"
        case .document(let url):
            "document:\(url.standardizedFileURL.path)"
        }
    }
}

@MainActor
enum HomeDocumentRouter {
    static func openPage(_ pageID: String, initialMode: NoteWorkspaceMode) {
        guard let bootstrap = AppBootstrap.shared else { return }
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == pageID }
        )
        let page = try? bootstrap.modelContainer.mainContext.fetch(descriptor).first
        let title = page.map { NoteTitleDisplay.resolvedTitle($0.title) } ?? "Untitled"
        reveal(
            .page(id: pageID, title: title, initialMode: initialMode),
            bootstrap: bootstrap
        )
        bootstrap.notesUI.openPage(pageID)
    }

    static func openDocument(_ url: URL) {
        guard let bootstrap = AppBootstrap.shared else { return }
        reveal(.document(url.standardizedFileURL), bootstrap: bootstrap)
    }

    private static func reveal(_ selection: HomeDocumentSelection, bootstrap: AppBootstrap) {
        if HologramController.shared.isVisible {
            HologramController.shared.hide()
        }
        bootstrap.uiState.homeTab = .home
        bootstrap.uiState.setActivePanel(.home)
        bootstrap.uiState.homeContent = .document(selection)
        HomeWindowIdentity.surfaceHomeWindow()
    }
}

struct HomeDocumentWorkspaceView: View {
    let selection: HomeDocumentSelection

    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.landing) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppWindowBackdropStyle.background(for: theme))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                returnHome()
            } label: {
                Label("Home", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .hoverGlass(flatBackground: .clear, cornerRadius: 10)
            .help("Return to Home")

            Text(title)
                .font(AppDisplayTypography.font(size: 13, weight: .semibold, allowDisplayFont: false))
                .lineLimit(1)

            Spacer(minLength: 12)

            Button {
                openInMultitask()
            } label: {
                Label("Open in Multitask", systemImage: "macwindow.on.rectangle")
            }
            .buttonStyle(.plain)
            .hoverGlass(flatBackground: .clear, cornerRadius: 10)
            .help("Open this file in the native multitask tab workspace")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .page(let id, _, let initialMode):
            NoteDetailWorkspaceView(
                pageId: id,
                presentation: .embeddedHome,
                initialMode: initialMode
            )
            .id(selection.identity)

        case .document(let url):
            HomePackageDocumentPreview(url: url)
                .id(selection.identity)
        }
    }

    private var title: String {
        switch selection {
        case .page(_, let title, _):
            title
        case .document(let url):
            url.deletingPathExtension().lastPathComponent
        }
    }

    private func returnHome() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
            ui.homeContent = .greeting
        }
    }

    private func openInMultitask() {
        switch selection {
        case .page(let id, _, let initialMode):
            NoteWindowManager.shared.open(pageId: id, initialMode: initialMode)
        case .document(let url):
            openNativeDocument(url)
        }
    }

    private func openNativeDocument(_ url: URL) {
        if url.pathExtension.lowercased() == "htmlworkspace" {
            do {
                try NSDocumentController.shared.openHTMLWorkspaceDocument(at: url)
            } catch {
                NSApplication.shared.presentError(error)
            }
            return
        }
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if let error {
                NSApplication.shared.presentError(error)
            }
        }
    }
}

private struct HomePackageDocumentPreview: View {
    let url: URL

    @Environment(UIState.self) private var ui
    @State private var snapshot = Snapshot.loading

    private enum Snapshot: Equatable, Sendable {
        case loading
        case loaded(title: String, format: String, text: String)
        case htmlWorkspace(HTMLWorkspacePackage)
        case failed(String)
    }

    var body: some View {
        Group {
            switch snapshot {
            case .loading:
                ProgressView("Loading \(url.lastPathComponent)…")
            case .failed(let message):
                ContentUnavailableView(
                    "Document unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .htmlWorkspace(let package):
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(package.manifest.title)
                            .font(AppDisplayTypography.font(size: 18, weight: .semibold))
                        Spacer()
                        Text("HTML Workspace · saved preview")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    HTMLWorkspacePreviewView(package: package, safeAPIEnabled: false)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(ui.theme.glassBorder.opacity(0.5), lineWidth: 0.7)
                        }
                }
                .padding(18)
            case .loaded(let title, let format, let text):
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(title)
                            .font(AppDisplayTypography.font(size: 18, weight: .semibold))
                        Spacer()
                        Text(format)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    ScrollView([.vertical, .horizontal]) {
                        Text(text)
                            .font(.system(size: 14, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(16)
                    }
                    .background(
                        ui.theme.resolved.background.color.opacity(ui.theme.isDark ? 0.72 : 0.82),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .padding(18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url.standardizedFileURL) {
            snapshot = await Self.load(url: url)
        }
    }

    private nonisolated static func load(url: URL) async -> Snapshot {
        await Task.detached(priority: .userInitiated) {
            let ext = url.pathExtension.lowercased()
            do {
                switch ext {
                case "epdoc":
                    let wrapper = try FileWrapper(url: url, options: [.immediate])
                    let package = try EpdocPackage(fileWrapper: wrapper)
                    let bytes: Data
                    if let projected = package.plainText {
                        bytes = projected
                    } else {
                        let blocks = ReadableBlocksProjector.project(
                            contentJSON: package.contentJSON,
                            artifactID: package.manifest.id,
                            artifactKind: package.manifest.kind,
                            documentTitle: package.manifest.title
                        )
                        bytes = ReadableBlocksProjector.plainText(from: blocks)
                    }
                    return .loaded(
                        title: package.manifest.title.isEmpty ? url.deletingPathExtension().lastPathComponent : package.manifest.title,
                        format: "JSON Document (.epdoc) · saved preview",
                        text: boundedUTF8(bytes)
                    )
                case "htmlworkspace":
                    let wrapper = try FileWrapper(url: url, options: [.immediate])
                    return .htmlWorkspace(try HTMLWorkspacePackage(fileWrapper: wrapper))
                default:
                    let bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
                    return .loaded(
                        title: url.lastPathComponent,
                        format: ext.isEmpty ? "File" : ext.uppercased(),
                        text: boundedUTF8(bytes)
                    )
                }
            } catch {
                return .failed(error.localizedDescription)
            }
        }.value
    }

    private nonisolated static func boundedUTF8(_ data: Data) -> String {
        let limit = 1_000_000
        let prefix = data.prefix(limit)
        let text = String(decoding: prefix, as: UTF8.self)
        return data.count > limit ? text + "\n\n[Preview truncated]" : text
    }
}
