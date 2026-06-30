import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct HTMLWorkspaceEditorView: View {
    @Binding var package: HTMLWorkspacePackage
    let theme: EpistemosTheme?
    @Environment(\.colorScheme) private var colorScheme
    @State private var previewPackage: HTMLWorkspacePackage
    @State private var selectedPane: HTMLWorkspaceSourcePane = .html
    @State private var layoutMode: HTMLWorkspaceLayoutMode = .split
    @State private var previewUpdateTask: Task<Void, Never>?
    @State private var consoleExpanded = false
    @State private var inspectorVisible = false
    @State private var isExportingPDF = false
    @State private var statusText: String?
    @State private var liveDOMSnapshot: HTMLWorkspaceDOMSnapshot?

    init(package: Binding<HTMLWorkspacePackage>, theme: EpistemosTheme? = nil) {
        self._package = package
        self.theme = theme
        self._previewPackage = State(initialValue: package.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            workspaceBody
        }
        .onChange(of: package) { _, newValue in
            liveDOMSnapshot = nil
            schedulePreviewUpdate(newValue)
        }
        .onChange(of: colorScheme) { _, _ in
            previewPackage = package
        }
        .onChange(of: theme) { _, _ in
            // SS-THX (owner 2026-06-20): the preview palette tracked only @Environment(\.colorScheme)
            // (OS appearance), so changing the in-app theme/PAIR — which flows in via the `theme`
            // prop from HTMLWorkspaceDocumentThemedRoot's ui.theme — never repainted the preview
            // ("never changes because of the theme process"). Refresh the preview snapshot on the
            // theme prop too, mirroring the colorScheme refresh.
            previewPackage = package
        }
        .onDisappear {
            previewUpdateTask?.cancel()
            previewUpdateTask = nil
        }
        .background(workspaceTheme.resolved.background.color)
        .htmlWorkspaceDataFeed(package: $package, statusText: $statusText)
    }

    @ViewBuilder
    private var workspaceBody: some View {
        switch layoutMode {
        case .source:
            sourceShell
        case .preview:
            previewShell
        case .split:
            HSplitView {
                sourceShell
                    .frame(minWidth: 380, idealWidth: 560)
                previewShell
                    .frame(minWidth: 420)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(package.manifest.title.isEmpty ? "HTML Workspace" : package.manifest.title)
                    .font(.headline)
                    .foregroundStyle(workspaceTheme.resolved.foreground.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(contentHash.prefix(10)) / \(domNodeCount) \(domSnapshot.source.label) DOM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Picker("Layout", selection: $layoutMode) {
                ForEach(HTMLWorkspaceLayoutMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)

            Button {
                saveDocument()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .labelStyle(.iconOnly)
            .help("Save")

            Menu {
                Button("Import HTML", systemImage: "tray.and.arrow.down") {
                    importHTML()
                }
                Button("Export HTML", systemImage: "square.and.arrow.up") {
                    exportHTML()
                }
                Button("Capture Snapshot", systemImage: "camera.viewfinder") {
                    captureSnapshot()
                }
                Button("Export PDF", systemImage: isExportingPDF ? "hourglass" : "doc.richtext") {
                    exportPDF()
                }
                .disabled(isExportingPDF)
            } label: {
                Label("Artifacts", systemImage: "shippingbox.and.arrow.backward")
            }
            .labelStyle(.iconOnly)
            .help("Import, export, snapshot, and PDF")

            Button {
                consoleExpanded.toggle()
            } label: {
                Label("Console", systemImage: consoleExpanded ? "terminal.fill" : "terminal")
            }
            .labelStyle(.iconOnly)
            .help("Console")

            Button {
                inspectorVisible.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .labelStyle(.iconOnly)
            .help("Inspector")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(headerFill)
        .tint(workspaceTheme.resolved.accent.color)
        .buttonStyle(HTMLWorkspaceToolbarIconButtonStyle(theme: workspaceTheme))
    }

    private var sourceShell: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sourceRail
                    .frame(width: 118)
                Divider()
                VStack(spacing: 0) {
                    sourceHeader
                    Divider()
                    sourceEditor
                    consolePanel
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sourceRail: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(HTMLWorkspaceSourcePane.allCases) { pane in
                Button {
                    selectedPane = pane
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: pane.systemImage)
                            .frame(width: 16)
                        Text(pane.title)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12, weight: selectedPane == pane ? .semibold : .regular))
                    .foregroundStyle(selectedPane == pane ? workspaceTheme.resolved.accent.color : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background {
                        if selectedPane == pane {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(workspaceTheme.resolved.accent.color.opacity(workspaceTheme.isDark ? 0.20 : 0.14))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            sourceRailStatus
        }
        .padding(8)
        .background(panelFill)
    }

    private var sourceRailStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(package.manifest.sandboxPolicy.allowNetwork ? "Network" : "Offline")
                .font(.caption2.weight(.semibold))
            Text(dataStatus)
                .font(.caption2)
                .foregroundStyle(dataStatus == "Data OK" ? Color.secondary : Color.red)
                .lineLimit(2)
            if let feedSummary = HTMLWorkspaceDataFeedStatus.compactLine(for: package) {
                Divider()
                    .padding(.vertical, 2)
                Text(feedSummary)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(feedSummary.contains("stale") ? Color.orange : Color.secondary)
                    .lineLimit(2)
                if let feedDetail = HTMLWorkspaceDataFeedStatus.detailLine(for: package) {
                    Text(feedDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .truncationMode(.middle)
                }
            }
            if let statusText {
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    private var sourceHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: selectedPane.systemImage)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(selectedPane.fileName)
                    .font(.subheadline.weight(.semibold))
                Text(selectedPaneSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Text(selectedPaneMetricText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
            Menu {
                Section("Allowed Ops") {
                    ForEach(allowedOperations(for: selectedPane), id: \.self) { operation in
                        Text(operation)
                    }
                }
                if selectedPane == .data {
                    Divider()
                    Section("Data Feed") {
                        Button("Configure Vault Search Feed", systemImage: "magnifyingglass") {
                            configureVaultSearchFeed()
                        }
                        Button("Clear Data Feed", systemImage: "xmark.circle") {
                            clearVaultSearchFeed()
                        }
                        .disabled(package.manifest.dataFeed == nil)
                    }
                }
                Divider()
                Button("Copy Target Context") {
                    copyPatchContext(for: selectedPane)
                }
            } label: {
                Label("Pane actions", systemImage: "chevron.down.circle")
            }
            .labelStyle(.iconOnly)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)  // SS-DD: clean icon-only glyph, no stray chevron
            .help("Pane actions")
            Button {
                copyPatchContext(for: selectedPane)
            } label: {
                Label("Copy target", systemImage: "scope")
            }
            .labelStyle(.iconOnly)
            .help("Copy target context for this pane")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(headerFill)
        .tint(workspaceTheme.resolved.accent.color)
    }

    @ViewBuilder
    private var sourceEditor: some View {
        switch selectedPane {
        case .html:
            workspaceCodeEditor(text: $package.indexHTML)
        case .css:
            workspaceCodeEditor(text: $package.styleCSS)
        case .js:
            workspaceCodeEditor(text: $package.scriptJS)
        case .data:
            workspaceCodeEditor(text: $package.dataJSON)
        case .dom:
            readOnlySourcePane(
                title: domPaneTitle,
                systemImage: "point.3.connected.trianglepath.dotted",
                text: domOutlineText,
                emptyText: "No DOM nodes reported yet. Open the preview or edit HTML to populate this outline."
            )
        case .routes:
            readOnlySourcePane(
                title: "Routes",
                systemImage: "map",
                text: routeManifestText,
                emptyText: "No package routes. Use setRoute to add routes/<name> HTML pages."
            )
        case .assets:
            readOnlySourcePane(
                title: "Assets",
                systemImage: "shippingbox",
                text: assetManifestText,
                emptyText: "No assets or snapshots. Import or capture to populate this manifest."
            )
        }
    }

    private func readOnlySourcePane(
        title: String,
        systemImage: String,
        text: String,
        emptyText: String
    ) -> some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .foregroundStyle(workspaceTheme.resolved.accent.color)
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer(minLength: 0)
                }
                Text(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emptyText : text)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(workspaceTheme.resolved.foreground.color)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(MarkdownPreviewSurfaceStyle.canvasBackground(for: workspaceTheme))
    }

    private func workspaceCodeEditor(text: Binding<String>) -> some View {
        HTMLWorkspaceCodeEditor(
            text: text,
            isEditable: true,
            colorScheme: colorScheme,
            theme: workspaceTheme
        )
        .id("workspace-code-editor-\(selectedPane.rawValue)")
        .background(MarkdownPreviewSurfaceStyle.canvasBackground(for: workspaceTheme))
    }

    private var previewShell: some View {
        HSplitView {
            VStack(spacing: 0) {
                previewHeader
                Divider()
                HTMLWorkspacePreviewView(package: previewPackage,
                    previewTheme: previewTheme,
                    themeGuardCSSOverride: previewThemeGuardCSS,
                    themeIdentity: workspaceThemeIdentity,
                    onConsoleError: { error in
                        // SS-HW console capture → record into the document's console pipeline (the
                        // consolePanel reads package.consoleErrors). Only `package` is updated, never
                        // `previewPackage`, so a runtime error never re-renders the preview (no loop).
                        package = (try? HTMLWorkspacePatchApplier.apply(.recordConsoleError(error), to: package)) ?? package
                    },
                    onDOMSnapshot: { snapshot in
                        liveDOMSnapshot = snapshot
                    }
                )
                    .id(previewRenderIdentity)
                    .frame(minWidth: 360)
            }

            if inspectorVisible {
                inspectorPanel
                    .frame(minWidth: 210, idealWidth: 250, maxWidth: 310)
            }
        }
    }

    private var previewHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "safari")
                .foregroundStyle(.secondary)
            Text("Preview")
                .font(.subheadline.weight(.semibold))
            Text("WKWebView")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(bridgeStatusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(package.manifest.sandboxPolicy.allowNetwork ? "Network" : "Offline")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(package.manifest.sandboxPolicy.allowNetwork ? .orange : .green)
            HTMLWorkspaceDataFeedStatusStrip(package: package, compact: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(headerFill)
    }

    private var consolePanel: some View {
        DisclosureGroup(isExpanded: $consoleExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                if package.consoleErrors.isEmpty {
                    Text("No errors")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(package.consoleErrors.suffix(8).enumerated()), id: \.offset) { _, error in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(error.message)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                            if let source = error.source {
                                Text("\(source):\(error.line):\(error.column)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            HStack {
                Text("Console")
                Spacer()
                if !package.consoleErrors.isEmpty {
                    Text("\(package.consoleErrors.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(panelFill)
    }

    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Inspector")
                .font(.headline)

            VStack(alignment: .leading, spacing: 7) {
                inspectorRow("Hash", String(contentHash.prefix(12)))
                inspectorRow("Sandbox", package.manifest.sandboxPolicy.allowNetwork ? "Network" : "Offline")
                inspectorRow("Bridge", bridgeStatusText)
                inspectorRow("DOM", "\(domNodeCount) \(domSnapshot.source.label)")
                inspectorRow("Data", dataStatus)
                inspectorRow("Provenance", generationProvenanceText)
                inspectorRow("Routes", "\(package.routes.count)")
                inspectorRow("Assets", "\(package.assets.count)")
                inspectorRow("Snapshots", "\(package.snapshots.count)")
                inspectorRow("Errors", "\(package.consoleErrors.count)")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Patch Ops")
                    .font(.subheadline.weight(.semibold))
                capabilityGrid
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(panelFill)
    }

    private func inspectorRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.caption)
    }

    private var bridgeStatusText: String {
        package.manifest.sandboxPolicy.allowAppBridge ? "Safe API deferred" : "No bridge"
    }

    private var generationProvenanceText: String {
        guard let provenance = package.manifest.generationProvenance else {
            return "Local / unstamped"
        }
        return provenance.displayText(currentContentHash: contentHash)
    }

    private var selectedPaneSubtitle: String {
        selectedPane.subtitle(for: package, domSnapshot: domSnapshot)
    }

    private var selectedPaneMetricText: String {
        selectedPane.metricText(for: package, domSnapshot: domSnapshot)
    }

    private var capabilityGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(["HTML", "CSS", "JS", "Data", "DOM", "Chart", "Asset", "PDF"], id: \.self) { label in
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    private var domOutlineText: String {
        domSnapshot.outline
    }

    private var domPaneTitle: String {
        domSnapshot.source == .live ? "Live DOM Outline" : "Source DOM Outline"
    }

    private var domNodeCount: Int {
        domSnapshot.nodeCount
    }

    private var domSnapshot: HTMLWorkspaceDOMSnapshot {
        liveDOMSnapshot ?? HTMLWorkspaceDOMOutline.snapshot(for: package.indexHTML)
    }

    private var assetManifestText: String {
        guard !package.assets.isEmpty || !package.snapshots.isEmpty else {
            return "No assets or snapshots"
        }
        let assetRows = package.assets
            .sorted { $0.key < $1.key }
            .map { "assets/\($0.key)  \($0.value.count) bytes" }
        let snapshotRows = package.snapshots
            .sorted { $0.key < $1.key }
            .map { "snapshot/\($0.key)  \($0.value.count) bytes" }
        return (assetRows + snapshotRows).joined(separator: "\n")
    }

    private var routeManifestText: String {
        guard !package.routes.isEmpty else {
            return "No routes"
        }
        return package.routes
            .sorted { $0.key < $1.key }
            .map { name, html in
                let lines = max(1, html.split(separator: "\n", omittingEmptySubsequences: false).count)
                return "routes/\(name)  \(lines) lines / \(Data(html.utf8).count) bytes"
            }
            .joined(separator: "\n")
    }

    private var dataStatus: String {
        guard let data = package.dataJSON.data(using: .utf8) else { return "Data invalid" }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return "Data OK"
        } catch {
            return "Data invalid"
        }
    }

    private var contentHash: String {
        HTMLWorkspaceDocument.contentHash(
            indexHTML: package.indexHTML,
            styleCSS: package.styleCSS,
            scriptJS: package.scriptJS,
            dataJSON: package.dataJSON,
            routes: package.routes
        )
    }

    private var previewTheme: HTMLWorkspacePreviewTheme {
        workspaceTheme.isDark ? .dark : .light
    }

    private var workspaceTheme: EpistemosTheme {
        (theme ?? (colorScheme == .dark ? EpistemosTheme.oledSoft : EpistemosTheme.light))
            .surfaceVariant(.other)
    }

    private var workspaceColorScheme: ColorScheme {
        workspaceTheme.isDark ? .dark : .light
    }

    private var previewThemeGuardCSS: String {
        let background = MarkdownPreviewSurfaceStyle
            .canvasNSColor(for: workspaceTheme)
            .rgbSafeForCodeEditorTheme()
            .withAlphaComponent(1.0)
            .htmlWorkspaceCSSColor
        let foregroundSource = workspaceTheme.isDark
            ? NSColor(deviceWhite: 0.94, alpha: 1.0)
            : workspaceTheme.resolved.foreground.nsColor
        let mutedSource = workspaceTheme.isDark
            ? NSColor(deviceWhite: 0.80, alpha: 1.0)
            : workspaceTheme.resolved.mutedForeground.nsColor
        let foreground = foregroundSource
            .rgbSafeForCodeEditorTheme()
            .htmlWorkspaceCSSColor
        let muted = mutedSource
            .rgbSafeForCodeEditorTheme()
            .htmlWorkspaceCSSColor
        let card = workspaceTheme.resolved.card.nsColor
            .rgbSafeForCodeEditorTheme()
            .withAlphaComponent(1.0)
            .htmlWorkspaceCSSColor
        let border = workspaceTheme.resolved.glassBorder.nsColor
            .rgbSafeForCodeEditorTheme()
            .htmlWorkspaceCSSColor(opacity: workspaceTheme.isDark ? 0.48 : 0.32)
        let accent = workspaceTheme.resolved.accent.nsColor
            .rgbSafeForCodeEditorTheme()
            .htmlWorkspaceCSSColor
        let scheme = workspaceTheme.isDark ? "dark" : "light"

        return """
        :root {
          color-scheme: \(scheme);
          --epistemos-workspace-bg: \(background);
          --epistemos-workspace-fg: \(foreground);
          --epistemos-workspace-muted: \(muted);
          --epistemos-workspace-card: \(card);
          --epistemos-workspace-border: \(border);
          --epistemos-workspace-accent: \(accent);
          --epistemos-workspace-title-font: "MatrixTypeDisplay-Regular", "MatrixTypeDisplay", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
          --epistemos-workspace-heading-font: "ChonkyPixels", "MatrixTypeDisplay-Regular", "MatrixTypeDisplay", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
          --epistemos-workspace-body-font: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
        }

        html[data-epistemos-theme] body,
        html[data-epistemos-theme],
        html[data-epistemos-theme] main.workspace {
          background: var(--epistemos-workspace-bg) !important;
          color: var(--epistemos-workspace-fg) !important;
        }

        html[data-epistemos-theme="dark"] body,
        html[data-epistemos-theme="dark"] body :where(*):not(svg):not(path),
        html[data-epistemos-theme="dark"] body :is(p, li, span, div, small, strong, em, label, td, th, blockquote, pre, code, dd, dt, figcaption, summary, legend) {
          color: var(--epistemos-workspace-fg) !important;
        }

        html[data-epistemos-theme="dark"] body :is(.muted, .secondary, .subtle, .caption, .eyebrow, .meta, [data-muted]) {
          color: var(--epistemos-workspace-muted) !important;
        }

        html[data-epistemos-theme="light"] body :is(p, li, span, small, strong, em, label, td, th, blockquote, pre, code, dd, dt, figcaption, summary, legend) {
          color: inherit;
        }

        html[data-epistemos-theme] body :is(h1, h2, h3, h4, h5, h6) {
          color: var(--epistemos-workspace-fg) !important;
        }

        html[data-epistemos-theme] body a {
          color: var(--epistemos-workspace-accent) !important;
        }

        html[data-epistemos-theme] body :is(hr, table, th, td, fieldset, input, textarea, select) {
          border-color: var(--epistemos-workspace-border) !important;
        }

        html[data-epistemos-theme] :is(.metric-card, [data-metrics] article, .card, section[data-card]) {
          background: var(--epistemos-workspace-card);
          border-color: var(--epistemos-workspace-border);
        }
        """
    }

    private var workspaceThemeIdentity: String {
        [
            previewTheme.rawValue,
            MarkdownPreviewSurfaceStyle.canvasNSColor(for: workspaceTheme).htmlWorkspaceCSSColor,
            workspaceTheme.resolved.foreground.nsColor.htmlWorkspaceCSSColor,
            workspaceTheme.resolved.accent.nsColor.htmlWorkspaceCSSColor,
        ].joined(separator: "|")
    }

    private var panelFill: Color {
        workspaceTheme.card.opacity(workspaceTheme.isDark ? 0.78 : 0.94)
    }

    private var headerFill: Color {
        workspaceTheme.resolved.background.color.opacity(workspaceTheme.isDark ? 0.68 : 0.90)
    }

    private var previewRenderIdentity: String {
        // SS-U (owner: "dark/light mode often crashes"): do NOT fold the theme hash
        // into the preview WebView's SwiftUI identity. A light/dark flip changes the
        // theme but NOT the content — if the theme is in the `.id`, every flip
        // changes the identity and forces SwiftUI to dismantle+recreate the
        // WKWebView mid-render. Tearing down a WKWebView with an attached
        // script-message handler / in-flight loadHTMLString during a re-identity is a
        // known WebKit fault window (it fired on every toggle while the workspace
        // preview was open → "often crashes"). With the theme OUT of the identity an
        // appearance flip instead drives updateNSView, which re-renders the LIVE
        // WebView with the new previewTheme (HTMLWorkspacePreviewView.loadPreview) —
        // no teardown, no crash. Identity stays shell-only: HTML/CSS/JS edits still
        // recreate as intended, while data.json-only changes flow through
        // HTMLWorkspacePreviewView's in-place data patch.
        HTMLWorkspacePreviewIdentity.viewIdentity(for: previewPackage)
    }

    private var workspaceAttachment: ContextAttachment {
        ComposerReferenceHelpers.htmlWorkspaceAttachment(
            workspaceID: package.manifest.id,
            title: package.manifest.title,
            fileURL: currentHTMLWorkspaceDocument()?.fileURL
        )
    }

    private func saveDocument() {
        if let document = currentHTMLWorkspaceDocument() {
            document.save(nil)
        } else {
            NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
        }
        statusText = "Save requested"
    }

    private func copyPatchContext(for pane: HTMLWorkspaceSourcePane) {
        let surface = documentSurface(for: pane)
        let context = """
        Document Target:
        surface_id: \(surface.id)
        surface_kind: \(surface.kind.rawValue)
        pane: \(pane.documentSurfacePane.rawValue)
        content_hash: \(surface.contentHash)
        allowed_operations: \(allowedOperations(for: pane).joined(separator: ", "))

        ```epistemos-html-workspace-patch
        {"workspace_id":"\(package.manifest.id)","expected_content_hash":"\(contentHash)","operations":[\(patchExampleOperation(for: pane))]}
        ```
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context, forType: .string)
        statusText = "Patch context copied"
    }

    private func patchExampleOperation(for pane: HTMLWorkspaceSourcePane) -> String {
        switch pane {
        case .routes:
            #"{"type":"setRoute","name":"about.html","html":"<main></main>"}"#
        default:
            #"{"type":"insertBlock","html":"<section></section>","location":"append"}"#
        }
    }

    private func configureVaultSearchFeed() {
        let existingFeed = package.manifest.dataFeed
        let queryField = NSTextField(string: existingFeed?.query ?? "")
        queryField.placeholderString = "Vault search query"
        let limitField = NSTextField(string: "\(existingFeed?.limit ?? HTMLWorkspaceDataFeed.defaultLimit)")
        limitField.placeholderString = "Limit"
        let limitFormatter = NumberFormatter()
        limitFormatter.allowsFloats = false
        limitFormatter.minimum = NSNumber(value: 1)
        limitFormatter.maximum = NSNumber(value: HTMLWorkspaceDataFeed.maxLimit)
        limitField.formatter = limitFormatter

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.addArrangedSubview(NSTextField(labelWithString: "Query"))
        stack.addArrangedSubview(queryField)
        stack.addArrangedSubview(NSTextField(labelWithString: "Limit"))
        stack.addArrangedSubview(limitField)
        stack.setFrameSize(NSSize(width: 360, height: 96))
        queryField.frame.size.width = 360
        limitField.frame.size.width = 120

        let alert = NSAlert()
        alert.messageText = "Vault Search Feed"
        alert.informativeText = "Refresh data.json from VaultSyncService.searchFullAsync."
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = stack

        guard alert.runModal() == .alertFirstButtonReturn else {
            statusText = "Vault feed unchanged"
            return
        }
        let query = queryField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            statusText = "Vault feed query required"
            return
        }
        let requestedLimit = Int(limitField.stringValue) ?? existingFeed?.limit ?? HTMLWorkspaceDataFeed.defaultLimit
        let limit = HTMLWorkspaceDataFeed.clampedLimit(requestedLimit)
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: query, limit: limit)
        if package.isStarterTemplateContent {
            var updatedPackage = package
            updatedPackage.applyVaultSearchDashboardTemplate(query: query, limit: limit)
            package = updatedPackage
        } else {
            package.manifest.dataFeed = feed
            package.dataJSON = HTMLWorkspaceDataFeedJSONEnvelope.staleDataJSON(
                feed: feed,
                error: "Feed pending"
            )
        }
        statusText = "Vault feed configured"
        selectedPane = .data
    }

    private func clearVaultSearchFeed() {
        package.manifest.dataFeed = nil
        statusText = "Vault feed cleared"
        selectedPane = .data
    }

    private func captureSnapshot() {
        let name = "snapshot-\(Int(Date().timeIntervalSince1970)).html"
        do {
            package = try HTMLWorkspacePatchApplier.apply(.captureSnapshot(name: name), to: package)
            statusText = "Snapshot saved"
        } catch {
            statusText = failedStatus("Snapshot", error: error)
        }
    }

    private func importHTML() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.html]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else {
            statusText = "Import cancelled"
            return
        }
        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            let imported = HTMLWorkspaceHTMLImporter.importSources(from: source)
            package.indexHTML = imported.html
            if !imported.css.isEmpty {
                package.styleCSS = imported.css
            }
            if !imported.js.isEmpty {
                package.scriptJS = imported.js
            }
            if !imported.dataJSON.isEmpty {
                package.dataJSON = imported.dataJSON
            }
            if package.manifest.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                package.manifest.title == "Untitled HTML Workspace" {
                package.manifest.title = url.deletingPathExtension().lastPathComponent
            }
            statusText = "HTML imported"
        } catch {
            statusText = failedStatus("Import", error: error)
        }
    }

    private func exportHTML() {
        guard let destination = chooseHTMLDestination() else {
            statusText = "HTML export cancelled"
            return
        }
        do {
            let html = HTMLWorkspacePreviewDocument.render(
                package: package,
                theme: previewTheme,
                resourceMode: .inlinePackageAssets
            )
            try Data(html.utf8).write(to: destination, options: [.atomic])
            statusText = package.routes.isEmpty ? "HTML saved" : "HTML saved (index route only)"
        } catch {
            statusText = failedStatus("HTML export", error: error)
        }
    }

    private func exportPDF() {
        guard !isExportingPDF else { return }
        guard let destination = choosePDFDestination() else {
            statusText = "PDF export cancelled"
            return
        }
        isExportingPDF = true
        statusText = "Exporting PDF"
        let exportPackage = package
        Task { @MainActor in
            defer { isExportingPDF = false }
            do {
                let data = try await HTMLWorkspacePDFExporter.export(package: exportPackage, theme: previewTheme)
                try data.write(to: destination, options: [.atomic])
                statusText = exportPackage.routes.isEmpty ? "PDF saved" : "PDF saved (index route only)"
            } catch {
                statusText = failedStatus("PDF export", error: error)
            }
        }
    }

    private func failedStatus(_ action: String, error: Error) -> String {
        let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else { return "\(action) failed" }
        return "\(action) failed: \(detail)"
    }

    private var selectedPaneSourceSnippet: String {
        sourceSnippet(for: selectedPane)
    }

    private func documentSurface(for pane: HTMLWorkspaceSourcePane) -> DocumentSurface {
        DocumentSurface(
            id: package.manifest.id,
            kind: .htmlWorkspace,
            title: package.manifest.title.isEmpty ? "HTML Workspace" : package.manifest.title,
            fileURL: currentHTMLWorkspaceDocument()?.fileURL,
            currentSelection: sourceRange(for: pane),
            capabilities: [.read, .write, .patch, .exportHTML, .exportPDF, .importContent, .preview],
            contentHash: contentHash
        )
    }

    private func sourceSnippet(for pane: HTMLWorkspaceSourcePane) -> String {
        let source = sourceText(for: pane)
        guard source.count > 4_000 else { return source }
        return String(source.prefix(4_000))
    }

    private func sourceRange(for pane: HTMLWorkspaceSourcePane) -> DocumentSourceRange {
        DocumentSourceRange.fullDocumentRange(for: sourceText(for: pane))
    }

    private func sourceText(for pane: HTMLWorkspaceSourcePane) -> String {
        switch pane {
        case .html: package.indexHTML
        case .css: package.styleCSS
        case .js: package.scriptJS
        case .data: package.dataJSON
        case .routes: routeManifestText
        case .dom: domOutlineText
        case .assets: assetManifestText
        }
    }

    private func allowedOperations(for pane: HTMLWorkspaceSourcePane) -> [String] {
        switch pane {
        case .html:
            ["replaceDocument", "regenerate", "replaceHTML", "insertBlock", "insertChart", "setRoute", "removeRoute", "captureSnapshot"]
        case .css:
            ["replaceDocument", "regenerate", "replaceCSS", "updateStyleRule"]
        case .js:
            ["replaceDocument", "regenerate", "replaceJS"]
        case .data:
            ["replaceDocument", "regenerate", "replaceDataJSON", "setDataFeed", "insertChart"]
        case .routes:
            ["setRoute", "removeRoute", "replaceDocument", "regenerate"]
        case .dom:
            ["replaceDocument", "regenerate", "insertBlock", "insertChart", "setRoute", "removeRoute"]
        case .assets:
            ["replaceDocument", "regenerate", "addAsset", "removeAsset", "captureSnapshot"]
        }
    }

    private func choosePDFDestination() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFileName(package.manifest.title.isEmpty ? "HTML Workspace" : package.manifest.title)).pdf"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func chooseHTMLDestination() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFileName(package.manifest.title.isEmpty ? "HTML Workspace" : package.manifest.title)).html"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func safeFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = value
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "HTML Workspace" : cleaned
    }

    private func currentHTMLWorkspaceDocument() -> HTMLWorkspaceDocument? {
        let documents = NSDocumentController.shared.documents.compactMap { $0 as? HTMLWorkspaceDocument }
        return documents.first { $0.package.manifest.id == package.manifest.id }
            ?? NSDocumentController.shared.currentDocument as? HTMLWorkspaceDocument
    }

    private func schedulePreviewUpdate(_ newPackage: HTMLWorkspacePackage) {
        previewUpdateTask?.cancel()
        previewUpdateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            previewPackage = newPackage
        }
    }
}

private enum HTMLWorkspaceLayoutMode: String, CaseIterable, Identifiable {
    case split
    case source
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .split: "Split"
        case .source: "Source"
        case .preview: "Preview"
        }
    }
}

nonisolated enum HTMLWorkspaceHTMLImporter {
    struct ImportedSources {
        var html: String
        var css: String
        var js: String
        var dataJSON: String
    }

    private static let generatedStyleIDs: Set<String> = [
        "epistemos-font-face",
        "epistemos-theme-guard",
        "epistemos-theme-host",
    ]
    private static let generatedScriptIDs: Set<String> = [
        "epistemos-workspace-runtime",
    ]

    static func importSources(from source: String) -> ImportedSources {
        let dataJSON = firstCapture(
            pattern: #"(?is)<script[^>]*id\s*=\s*["']workspace-data["'][^>]*>(.*?)</script>"#,
            in: source
        ).map(decodeScriptData) ?? ""
        let css = styleBodies(in: source)
        .joined(separator: "\n\n")
        let js = scriptBodies(in: source).joined(separator: "\n\n")

        let rawBody = firstCapture(pattern: #"(?is)<body[^>]*>(.*?)</body>"#, in: source) ?? source
        let cleanedBody = rawBody
            .replacingOccurrences(
                of: #"(?is)<script[^>]*>.*?</script>"#,
                with: "",
                options: [.regularExpression]
            )
            .replacingOccurrences(
                of: #"(?is)<style[^>]*>.*?</style>"#,
                with: "",
                options: [.regularExpression]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ImportedSources(
            html: cleanedBody.isEmpty ? "<main></main>" : cleanedBody,
            css: css,
            js: js,
            dataJSON: dataJSON
        )
    }

    private static func captures(pattern: String, in source: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard let captureRange = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func firstCapture(pattern: String, in source: String) -> String? {
        captures(pattern: pattern, in: source).first
    }

    private static func styleBodies(in source: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: #"(?is)<style\b([^>]*)>(.*?)</style>"#) else {
            return []
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard let attributesRange = Range(match.range(at: 1), in: source),
                  let bodyRange = Range(match.range(at: 2), in: source) else { return nil }
            let attributes = String(source[attributesRange])
            if let styleID = capturedID(in: attributes)?.lowercased(), generatedStyleIDs.contains(styleID) {
                return nil
            }
            return String(source[bodyRange])
        }
    }

    private static func scriptBodies(in source: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: #"(?is)<script\b([^>]*)>(.*?)</script>"#) else {
            return []
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard let attributesRange = Range(match.range(at: 1), in: source),
                  let bodyRange = Range(match.range(at: 2), in: source) else { return nil }
            let attributes = String(source[attributesRange])
            if !shouldImportScript(type: capturedAttribute("type", in: attributes)) {
                return nil
            }
            if let scriptID = capturedID(in: attributes)?.lowercased(),
               generatedScriptIDs.contains(scriptID) || scriptID == "workspace-data" {
                return nil
            }
            let body = String(source[bodyRange])
            if body.contains("Object.defineProperty(window, 'HTMLWorkspace'") {
                return nil
            }
            return body
        }
    }

    private static func shouldImportScript(type rawType: String?) -> Bool {
        guard let rawType else { return true }
        let normalized = rawType
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !normalized.isEmpty else { return true }
        return normalized == "module"
            || normalized == "text/javascript"
            || normalized == "application/javascript"
            || normalized == "text/ecmascript"
            || normalized == "application/ecmascript"
    }

    private static func capturedID(in attributes: String) -> String? {
        capturedAttribute("id", in: attributes)
    }

    private static func capturedAttribute(_ name: String, in attributes: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        guard let expression = try? NSRegularExpression(pattern: #"(?is)\b\#(escapedName)\s*=\s*["']([^"']+)["']"#) else {
            return nil
        }
        let range = NSRange(attributes.startIndex..<attributes.endIndex, in: attributes)
        guard let match = expression.firstMatch(in: attributes, range: range),
              let idRange = Range(match.range(at: 1), in: attributes) else {
            return nil
        }
        return String(attributes[idRange])
    }

    private static func decodeBasicHTMLEntities(_ source: String) -> String {
        source
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func decodeScriptData(_ source: String) -> String {
        decodeBasicHTMLEntities(source)
            .replacingOccurrences(of: #"<\/script"#, with: "</script", options: [.caseInsensitive])
            .replacingOccurrences(of: #"<\!--"#, with: "<!--")
    }
}

private enum HTMLWorkspaceSourcePane: String, CaseIterable, Identifiable {
    case html
    case css
    case js
    case data
    case routes
    case dom
    case assets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .html: "HTML"
        case .css: "CSS"
        case .js: "JS"
        case .data: "Data"
        case .routes: "Routes"
        case .dom: "DOM"
        case .assets: "Assets"
        }
    }

    var fileName: String {
        switch self {
        case .html: "index.html"
        case .css: "style.css"
        case .js: "main.js"
        case .data: "data.json"
        case .routes: "routes/"
        case .dom: "DOM Outline"
        case .assets: "Package"
        }
    }

    var systemImage: String {
        switch self {
        case .html: "chevron.left.forwardslash.chevron.right"
        case .css: "paintbrush"
        case .js: "curlybraces"
        case .data: "tablecells"
        case .routes: "map"
        case .dom: "point.3.connected.trianglepath.dotted"
        case .assets: "shippingbox"
        }
    }

    var documentSurfacePane: DocumentSurfacePane {
        switch self {
        case .html: .html
        case .css: .css
        case .js: .js
        case .data: .data
        case .routes: .routes
        case .dom: .dom
        case .assets: .assets
        }
    }

    func subtitle(
        for package: HTMLWorkspacePackage,
        domSnapshot: HTMLWorkspaceDOMSnapshot? = nil
    ) -> String {
        let resolvedDOMSnapshot = domSnapshot ?? HTMLWorkspaceDOMOutline.snapshot(for: package.indexHTML)
        return switch self {
        case .html: "DOM structure"
        case .css: "Presentation"
        case .js: "Local behavior"
        case .data: "Structured state"
        case .routes: "\(package.routes.count) routes"
        case .dom: "\(resolvedDOMSnapshot.nodeCount) \(resolvedDOMSnapshot.source.label) nodes"
        case .assets: "\(package.assets.count) assets, \(package.snapshots.count) snapshots"
        }
    }

    func metricText(
        for package: HTMLWorkspacePackage,
        domSnapshot: HTMLWorkspaceDOMSnapshot? = nil
    ) -> String {
        let resolvedDOMSnapshot = domSnapshot ?? HTMLWorkspaceDOMOutline.snapshot(for: package.indexHTML)
        return switch self {
        case .html: Self.counts(for: package.indexHTML)
        case .css: Self.counts(for: package.styleCSS)
        case .js: Self.counts(for: package.scriptJS)
        case .data: Self.counts(for: package.dataJSON)
        case .routes: "\(package.routes.count) routes"
        case .dom: "\(resolvedDOMSnapshot.nodeCount) \(resolvedDOMSnapshot.source.label) nodes"
        case .assets: "\(package.assets.count + package.snapshots.count) files"
        }
    }

    private static func counts(for source: String) -> String {
        let lines = max(1, source.split(separator: "\n", omittingEmptySubsequences: false).count)
        return "\(lines) lines / \(source.count) chars"
    }
}

private struct HTMLWorkspaceToolbarIconButtonStyle: ButtonStyle {
    let theme: EpistemosTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(theme.resolved.accent.color)
            .frame(width: 32, height: 30)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.resolved.accent.color.opacity(configuration.isPressed ? 0.22 : 0.11))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.resolved.accent.color.opacity(theme.isDark ? 0.26 : 0.20), lineWidth: 0.75)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

private extension NSColor {
    var htmlWorkspaceCSSColor: String {
        htmlWorkspaceCSSColor(opacity: nil)
    }

    func htmlWorkspaceCSSColor(opacity overrideOpacity: CGFloat?) -> String {
        let color = usingColorSpace(.sRGB) ?? self
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        let alpha = overrideOpacity ?? color.alphaComponent
        if alpha >= 0.999 {
            return String(format: "#%02X%02X%02X", red, green, blue)
        }
        return String(format: "rgba(%d, %d, %d, %.3f)", red, green, blue, alpha)
    }
}
