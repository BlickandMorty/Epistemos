import AppKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum GraphSurfacePresentation: Equatable {
    case overlay
    case embeddedHome

    var isEmbeddedHome: Bool { self == .embeddedHome }
}

// UAS: graph/embedded-route-metrics
// Plane: RuntimePlane::UI
// Residency: ResidencyTier::CurrentApp
enum EmbeddedGraphRouteMetrics {
    static let routeCornerRadius: CGFloat = 28
    static let borderWidth: CGFloat = 0.75
}

private struct GraphSurfacePresentationKey: EnvironmentKey {
    static let defaultValue: GraphSurfacePresentation = .overlay
}

extension EnvironmentValues {
    var graphSurfacePresentation: GraphSurfacePresentation {
        get { self[GraphSurfacePresentationKey.self] }
        set { self[GraphSurfacePresentationKey.self] = newValue }
    }
}

struct GraphWorkspaceContainer: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.graphSurfacePresentation) private var graphSurfacePresentation

    // Injected by the surrounding HologramOverlayHostedViewBuilder
    @Environment(\.modelContext) private var modelContext
    @State private var htmlWorkspaceDockVisible = false
    @State private var selectedHTMLWorkspaceID: String?

    private var theme: EpistemosTheme {
        graphSurfacePresentation.isEmbeddedHome
            ? ui.theme.surfaceVariant(.landing)
            : ui.theme
    }

    var body: some View {
        // 2026-05-19 — the shape-blur boundary used to live here, but on
        // the .canvas route this whole container's host view is hidden by
        // HologramOverlay's routeObserver. Moved to `ShapedGraphBoundaryHost`
        // mounted as a separate always-visible NSHostingView on the overlay
        // so the shape-blur is also visible while the user is on the canvas.
        ZStack {
            routeContent

            graphHTMLWorkspaceDockLayer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(EmbeddedGraphRouteChrome(
            isEnabled: graphSurfacePresentation.isEmbeddedHome,
            theme: theme
        ))
        .animation(
            graphSurfacePresentation.isEmbeddedHome ? nil :
                (reduceMotion ? nil : .snappy(duration: 0.3, extraBounce: 0.1)),
            value: graphState.currentRoute
        )
    }

    @ViewBuilder
    private var graphPageBackdrop: some View {
        if graphSurfacePresentation.isEmbeddedHome {
            embeddedPageSurface
                .ignoresSafeArea()
                .allowsHitTesting(true)
        } else {
            // 2026-05-20: zero-copy backdrop — same pattern as graphNoteBackdrop.
            // Folder page inherits the graph window's existing NSVisualEffectView
            // blur (set up in HologramOverlay) instead of stacking its own
            // unifiedFrostedGlass on top. One blur = one compositing pass per
            // frame. Required for 120 FPS on the folder route.
            Color.clear
                .ignoresSafeArea()
                .allowsHitTesting(true)
        }
    }

    @ViewBuilder
    private var routeContent: some View {
        switch graphState.currentRoute {
        case .canvas:
            Color.clear
                .allowsHitTesting(false)

        case .note(let id):
            graphNoteBackdrop

            GraphNotePage(sourceId: id)
                .id(id)
                .background(pageContentBackground)

        case .folder(let id):
            graphPageBackdrop

            VStack(spacing: 0) {
                graphPageHeader(title: "Folder")

                GraphFolderPage(folderId: id)
                    .id(id)
                    .background(pageContentBackground)
            }
        }
    }

    @ViewBuilder
    private var graphHTMLWorkspaceDockLayer: some View {
        if !graphState.currentRoute.isCanvas {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                GraphHTMLWorkspaceDock(
                    isExpanded: $htmlWorkspaceDockVisible,
                    selectedWorkspaceID: $selectedHTMLWorkspaceID,
                    theme: theme,
                    preferredDirectory: vaultSync.vaultURL
                )
                .padding(.trailing, 14)
                .padding(.vertical, 18)
            }
            .allowsHitTesting(true)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var graphNoteBackdrop: some View {
        if graphSurfacePresentation.isEmbeddedHome {
            embeddedPageSurface
                .ignoresSafeArea()
                .allowsHitTesting(true)
        } else {
            Color.clear
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var embeddedPageSurface: some View {
        Rectangle()
            .fill(theme.resolved.background.color)
    }

    @ViewBuilder
    private var pageContentBackground: some View {
        if graphSurfacePresentation.isEmbeddedHome {
            embeddedPageSurface
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func graphPageHeader(title: String) -> some View {
        if graphSurfacePresentation.isEmbeddedHome {
            embeddedGraphPageHeader(title: title)
        } else {
            overlayGraphPageHeader(title: title)
        }
    }

    private func embeddedGraphPageHeader(title: String) -> some View {
        HStack(spacing: 8) {
            navButton(
                systemName: "chevron.backward",
                label: "Back",
                enabled: graphState.canGoBack
            ) {
                graphState.goBack()
            }

            navButton(
                systemName: "chevron.forward",
                label: "Forward",
                enabled: graphState.canGoForward
            ) {
                graphState.goForward()
            }

            Button {
                graphState.returnToCanvas()
            } label: {
                Label("Canvas", systemImage: "circle.grid.3x3.fill")
                    .font(.system(size: 13, weight: .medium))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(theme.card.opacity(theme.isDark ? 0.82 : 0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.glassBorder.opacity(0.65), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help("Return to graph canvas")

            Divider()
                .frame(height: 18)
                .opacity(0.3)
                .padding(.horizontal, 4)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(theme.resolved.background.color)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.glassBorder.opacity(theme.isDark ? 0.45 : 0.65))
                .frame(height: 0.5)
        }
    }

    private func overlayGraphPageHeader(title: String) -> some View {
        HStack(spacing: 8) {
            navButton(
                systemName: "chevron.backward",
                label: "Back",
                enabled: graphState.canGoBack
            ) {
                graphState.goBack()
            }

            navButton(
                systemName: "chevron.forward",
                label: "Forward",
                enabled: graphState.canGoForward
            ) {
                graphState.goForward()
            }

            Button {
                graphState.returnToCanvas()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Graph")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                // 2026-05-20: zero-copy button chrome. Theme tint + thin
                // stroke instead of `.ultraThinMaterial` — this button
                // sits inside the graph window which already carries the
                // single NSVisualEffectView blur. Material here would be
                // a redundant blur kernel pass. See UnifiedFrostedGlass.swift
                // for the broader single-blur policy.
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.glassBg.opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(theme.glassBorder, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help("Return to graph canvas")

            Spacer()

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Color.clear
                .frame(width: 160, height: 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // 2026-05-20 (revised): `nativeGlass: true` — opts the toolbar strip
        // into the macOS 26 native Liquid Glass shader. One optimized GPU
        // pass on top of the window's wallpaper blur. Reads as a real
        // native macOS toolbar instead of a flat tinted rectangle.
        .unifiedFrostedGlass(theme: theme, in: Rectangle(), nativeGlass: true)
    }

    @ViewBuilder
    private func navButton(
        systemName: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 22)
                // 2026-05-20: zero-copy button chrome — see Graph button
                // above. Tint + stroke instead of `.ultraThinMaterial`.
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.glassBg.opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(theme.glassBorder, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.35)
        .help(label)
    }
}

private struct GraphHTMLWorkspaceItem: Identifiable {
    let document: HTMLWorkspaceDocument

    var id: String { document.package.manifest.id }

    var title: String {
        let manifestTitle = document.package.manifest.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !manifestTitle.isEmpty { return manifestTitle }
        return document.fileURL?.deletingPathExtension().lastPathComponent ?? "HTML Workspace"
    }

    var subtitle: String {
        if let url = document.fileURL {
            return url.lastPathComponent
        }
        return "Unsaved workspace"
    }

    var previewIdentity: String { HTMLWorkspacePreviewIdentity.viewIdentity(for: document.package) }
}

private struct GraphHTMLWorkspaceDock: View {
    @Binding var isExpanded: Bool
    @Binding var selectedWorkspaceID: String?

    let theme: EpistemosTheme
    let preferredDirectory: URL?

    private var previewTheme: HTMLWorkspacePreviewTheme {
        theme.isDark ? .dark : .light
    }

    private var workspaces: [GraphHTMLWorkspaceItem] {
        NSDocumentController.shared.documents
            .compactMap { $0 as? HTMLWorkspaceDocument }
            .filter { document in
                document.windowControllers.contains { controller in
                    controller.window?.isVisible == true || controller.window?.isKeyWindow == true
                }
            }
            .map(GraphHTMLWorkspaceItem.init)
    }

    private var selected: GraphHTMLWorkspaceItem? {
        let items = workspaces
        if let selectedWorkspaceID,
           let exact = items.first(where: { $0.id == selectedWorkspaceID }) {
            return exact
        }
        return items.first
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                isExpanded.toggle()
            } label: {
                Image(systemName: "curlybraces.square")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .background(dockButtonBackground)
            .help("HTML Workspace")

            if isExpanded {
                dockPanel
                    .frame(width: 340)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: isExpanded)
        .onAppear {
            if selectedWorkspaceID == nil {
                selectedWorkspaceID = workspaces.first?.id
            }
        }
    }

    private var dockPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("HTML Workspace", systemImage: "curlybraces.square")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button {
                    createWorkspace()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("New HTML Workspace")

                Button {
                    openWorkspacePackage()
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
                .help("Open HTML Workspace")
            }

            if workspaces.isEmpty {
                emptyState
            } else {
                workspaceList
                selectedPreview
                selectedActions
            }
        }
        .padding(12)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.74 : 0.56), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(theme.isDark ? 0.28 : 0.12), radius: 18, y: 8)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No open HTML workspaces")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Button {
                createWorkspace()
            } label: {
                Label("New Workspace", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var workspaceList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(workspaces) { item in
                Button {
                    selectedWorkspaceID = item.id
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selected?.id == item.id ? "checkmark.circle.fill" : "doc.richtext")
                            .foregroundStyle(selected?.id == item.id ? Color.accentColor : Color.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(item.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background {
                        if selected?.id == item.id {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.14))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var selectedPreview: some View {
        if let selected {
            HTMLWorkspacePreviewView(
                package: selected.document.package,
                safeAPIEnabled: false,
                previewTheme: previewTheme
            )
            .id(selected.previewIdentity)
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(theme.glassBorder.opacity(0.55), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private var selectedActions: some View {
        if let selected {
            HStack(spacing: 8) {
                Button {
                    selected.document.showWindows()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }

                Button {
                    exportHTML(for: selected)
                } label: {
                    Label("HTML", systemImage: "square.and.arrow.up")
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var dockButtonBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(theme.card.opacity(theme.isDark ? 0.82 : 0.94))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.glassBorder.opacity(0.68), lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(theme.isDark ? 0.24 : 0.10), radius: 12, y: 6)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.card.opacity(theme.isDark ? 0.92 : 0.96))
    }

    private func createWorkspace() {
        do {
            let document = try NSDocumentController.shared.createUntitledHTMLWorkspaceDocument(
                in: preferredDirectory
            )
            if let workspace = document as? HTMLWorkspaceDocument {
                selectedWorkspaceID = workspace.package.manifest.id
            }
        } catch {
            NSApplication.shared.presentError(error)
        }
    }

    private func openWorkspacePackage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "htmlworkspace")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let workspace = try NSDocumentController.shared.openHTMLWorkspaceDocument(at: url)
            selectedWorkspaceID = workspace.package.manifest.id
        } catch {
            NSApplication.shared.presentError(error)
        }
    }

    private func exportHTML(for item: GraphHTMLWorkspaceItem) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFileName(item.title)).html"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            let html = HTMLWorkspacePreviewDocument.render(
                package: item.document.package,
                theme: previewTheme
            )
            try Data(html.utf8).write(to: destination, options: [.atomic])
        } catch {
            NSApplication.shared.presentError(error)
        }
    }

    private func safeFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = value
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "HTML Workspace" : cleaned
    }
}

// UAS: graph/embedded-route-chrome
// Plane: RuntimePlane::UI
// Residency: ResidencyTier::CurrentApp
private struct EmbeddedGraphRouteChrome: ViewModifier {
    let isEnabled: Bool
    let theme: EpistemosTheme

    func body(content: Content) -> some View {
        if isEnabled {
            let shape = RoundedRectangle(
                cornerRadius: EmbeddedGraphRouteMetrics.routeCornerRadius,
                style: .continuous
            )

            content
                .clipShape(shape)
                .overlay(
                    shape.strokeBorder(
                        theme.glassBorder.opacity(theme.isDark ? 0.72 : 0.58),
                        lineWidth: EmbeddedGraphRouteMetrics.borderWidth
                    )
                )
                .contentShape(shape)
        } else {
            content
        }
    }
}
