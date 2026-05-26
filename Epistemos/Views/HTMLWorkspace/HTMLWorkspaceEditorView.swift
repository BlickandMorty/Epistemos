import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct HTMLWorkspaceEditorView: View {
    @Binding var package: HTMLWorkspacePackage
    @Environment(\.colorScheme) private var colorScheme
    @State private var previewPackage: HTMLWorkspacePackage
    @State private var selectedPane: HTMLWorkspaceSourcePane = .html
    @State private var layoutMode: HTMLWorkspaceLayoutMode = .split
    @State private var previewUpdateTask: Task<Void, Never>?
    @State private var consoleExpanded = false
    @State private var inspectorVisible = true
    @State private var isExportingPDF = false
    @State private var statusText: String?

    init(package: Binding<HTMLWorkspacePackage>) {
        self._package = package
        self._previewPackage = State(initialValue: package.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            workspaceBody
        }
        .onChange(of: package) { _, newValue in
            schedulePreviewUpdate(newValue)
        }
        .onChange(of: colorScheme) { _, _ in
            previewPackage = package
        }
        .onDisappear {
            previewUpdateTask?.cancel()
            previewUpdateTask = nil
        }
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
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(contentHash.prefix(10)) / \(HTMLWorkspaceDOMOutline.nodeCount(in: package.indexHTML)) DOM")
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

            Button {
                openMiniChatForCurrentPane()
            } label: {
                Label("MiniChat", systemImage: "bubble.left.and.text.bubble.right")
            }
            .labelStyle(.iconOnly)
            .help("Open MiniChat for this workspace")

            Button {
                copyPatchContext(for: selectedPane)
            } label: {
                Label("Copy patch context", systemImage: "curlybraces.square")
            }
            .labelStyle(.iconOnly)
            .help("Copy MiniChat patch context")

            Button {
                importHTML()
            } label: {
                Label("Import HTML", systemImage: "tray.and.arrow.down")
            }
            .labelStyle(.iconOnly)
            .help("Import HTML into this workspace")

            Button {
                exportHTML()
            } label: {
                Label("Export HTML", systemImage: "square.and.arrow.up")
            }
            .labelStyle(.iconOnly)
            .help("Export standalone HTML")

            Button {
                captureSnapshot()
            } label: {
                Label("Snapshot", systemImage: "camera.viewfinder")
            }
            .labelStyle(.iconOnly)
            .help("Capture local HTML snapshot")

            Button {
                exportPDF()
            } label: {
                Label("Export PDF", systemImage: isExportingPDF ? "hourglass" : "doc.richtext")
            }
            .labelStyle(.iconOnly)
            .disabled(isExportingPDF)
            .help("Export preview as PDF")

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
                    .foregroundStyle(selectedPane == pane ? .primary : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background {
                        if selectedPane == pane {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.accentColor.opacity(0.16))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            sourceRailStatus
        }
        .padding(8)
        .background(.bar)
    }

    private var sourceRailStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(package.manifest.sandboxPolicy.allowNetwork ? "Network" : "Offline")
                .font(.caption2.weight(.semibold))
            Text(dataStatus)
                .font(.caption2)
                .foregroundStyle(dataStatus == "Data OK" ? Color.secondary : Color.red)
                .lineLimit(2)
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
                Text(selectedPane.subtitle(for: package))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Text(selectedPane.metricText(for: package))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Menu {
                Section("Allowed Ops") {
                    ForEach(allowedOperations(for: selectedPane), id: \.self) { operation in
                        Text(operation)
                    }
                }
                Divider()
                Button("Copy Target Context") {
                    copyPatchContext(for: selectedPane)
                }
                Button("Chat With Pane") {
                    openMiniChatForCurrentPane()
                }
            } label: {
                Label("Pane actions", systemImage: "chevron.down.circle")
            }
            .labelStyle(.iconOnly)
            .menuStyle(.borderlessButton)
            .help("Pane actions")
            Button {
                copyPatchContext(for: selectedPane)
            } label: {
                Label("Copy target", systemImage: "scope")
            }
            .labelStyle(.iconOnly)
            .help("Copy MiniChat target for this pane")
            Button {
                openMiniChatForCurrentPane()
            } label: {
                Label("Chat with pane", systemImage: "bubble.left")
            }
            .labelStyle(.iconOnly)
            .help("Chat with this pane")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private var sourceEditor: some View {
        switch selectedPane {
        case .html:
            HTMLWorkspaceCodeEditor(text: $package.indexHTML, colorScheme: colorScheme)
        case .css:
            HTMLWorkspaceCodeEditor(text: $package.styleCSS, colorScheme: colorScheme)
        case .js:
            HTMLWorkspaceCodeEditor(text: $package.scriptJS, colorScheme: colorScheme)
        case .data:
            HTMLWorkspaceCodeEditor(text: $package.dataJSON, colorScheme: colorScheme)
        case .dom:
            HTMLWorkspaceCodeEditor(text: .constant(domOutlineText), isEditable: false, colorScheme: colorScheme)
        case .assets:
            HTMLWorkspaceCodeEditor(text: .constant(assetManifestText), isEditable: false, colorScheme: colorScheme)
        }
    }

    private var previewShell: some View {
        HSplitView {
            VStack(spacing: 0) {
                previewHeader
                Divider()
                HTMLWorkspacePreviewView(package: previewPackage, previewTheme: previewTheme)
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
            Text(package.manifest.sandboxPolicy.allowAppBridge ? "Safe API" : "No bridge")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(package.manifest.sandboxPolicy.allowNetwork ? "Network" : "Offline")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(package.manifest.sandboxPolicy.allowNetwork ? .orange : .green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
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
        .background(.bar)
    }

    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Inspector")
                .font(.headline)

            VStack(alignment: .leading, spacing: 7) {
                inspectorRow("Hash", String(contentHash.prefix(12)))
                inspectorRow("Sandbox", package.manifest.sandboxPolicy.allowNetwork ? "Network" : "Offline")
                inspectorRow("Bridge", package.manifest.sandboxPolicy.allowAppBridge ? "Safe API" : "Off")
                inspectorRow("DOM", "\(HTMLWorkspaceDOMOutline.nodeCount(in: package.indexHTML))")
                inspectorRow("Data", dataStatus)
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
        .background(.regularMaterial)
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
        HTMLWorkspaceDOMOutline.outline(for: package.indexHTML)
    }

    private var assetManifestText: String {
        guard !package.assets.isEmpty || !package.snapshots.isEmpty else {
            return "No assets or snapshots"
        }
        let assetRows = package.assets
            .sorted { $0.key < $1.key }
            .map { "asset/\($0.key)  \($0.value.count) bytes" }
        let snapshotRows = package.snapshots
            .sorted { $0.key < $1.key }
            .map { "snapshot/\($0.key)  \($0.value.count) bytes" }
        return (assetRows + snapshotRows).joined(separator: "\n")
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
            dataJSON: package.dataJSON
        )
    }

    private var previewTheme: HTMLWorkspacePreviewTheme {
        colorScheme == .dark ? .dark : .light
    }

    private var previewRenderIdentity: String {
        "\(previewPackage.manifest.id)-\(previewContentHash)-\(previewTheme.rawValue)"
    }

    private var previewContentHash: String {
        HTMLWorkspaceDocument.contentHash(
            indexHTML: previewPackage.indexHTML,
            styleCSS: previewPackage.styleCSS,
            scriptJS: previewPackage.scriptJS,
            dataJSON: previewPackage.dataJSON
        )
    }

    private var workspaceAttachment: ContextAttachment {
        ComposerReferenceHelpers.htmlWorkspaceAttachment(
            workspaceID: package.manifest.id,
            title: package.manifest.title,
            fileURL: currentHTMLWorkspaceDocument()?.fileURL,
            surfaceTarget: sourceTarget(for: selectedPane)
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

    private func openMiniChatForCurrentPane() {
        MiniChatWindowController.shared.openNewChat(attaching: workspaceAttachment)
        statusText = "MiniChat attached"
    }

    private func copyPatchContext(for pane: HTMLWorkspaceSourcePane) {
        let target = sourceTarget(for: pane)
        let context = """
        MiniChat Target:
        surface_id: \(target.surfaceID)
        surface_kind: \(target.surfaceKind.rawValue)
        pane: \(target.pane.rawValue)
        content_hash: \(target.contentHash)
        allowed_operations: \(target.allowedOperations.joined(separator: ", "))

        ```epistemos-html-workspace-patch
        {"workspace_id":"\(package.manifest.id)","expected_content_hash":"\(contentHash)","operations":[{"type":"insertBlock","html":"<section></section>","location":"append"}]}
        ```
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context, forType: .string)
        statusText = "Patch context copied"
    }

    private func captureSnapshot() {
        let name = "snapshot-\(Int(Date().timeIntervalSince1970)).html"
        do {
            package = try HTMLWorkspacePatchApplier.apply(.captureSnapshot(name: name), to: package)
            statusText = "Snapshot saved"
        } catch {
            statusText = "Snapshot failed"
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
            statusText = "Import failed"
        }
    }

    private func exportHTML() {
        guard let destination = chooseHTMLDestination() else {
            statusText = "HTML export cancelled"
            return
        }
        do {
            let html = HTMLWorkspacePreviewDocument.render(package: package, theme: previewTheme)
            try Data(html.utf8).write(to: destination, options: [.atomic])
            statusText = "HTML saved"
        } catch {
            statusText = "HTML export failed"
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
                statusText = "PDF saved"
            } catch {
                statusText = "PDF export failed"
            }
        }
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

    private func sourceTarget(for pane: HTMLWorkspaceSourcePane) -> MiniChatTarget {
        MiniChatTarget(
            surface: documentSurface(for: pane),
            pane: pane.documentSurfacePane,
            selectedRange: sourceRange(for: pane),
            snippet: pane == selectedPane ? selectedPaneSourceSnippet : sourceSnippet(for: pane),
            allowedOperations: allowedOperations(for: pane)
        )
    }

    private func sourceSnippet(for pane: HTMLWorkspaceSourcePane) -> String {
        let source = sourceText(for: pane)
        guard source.count > 4_000 else { return source }
        return String(source.prefix(4_000))
    }

    private func sourceRange(for pane: HTMLWorkspaceSourcePane) -> DocumentSourceRange {
        let source = sourceText(for: pane)
        let lines = max(1, source.split(separator: "\n", omittingEmptySubsequences: false).count)
        let lastLine = source.split(separator: "\n", omittingEmptySubsequences: false).last.map(String.init) ?? ""
        return DocumentSourceRange(
            startLine: 1,
            startColumn: 1,
            endLine: lines,
            endColumn: max(1, lastLine.count + 1)
        )
    }

    private func sourceText(for pane: HTMLWorkspaceSourcePane) -> String {
        switch pane {
        case .html: package.indexHTML
        case .css: package.styleCSS
        case .js: package.scriptJS
        case .data: package.dataJSON
        case .dom: domOutlineText
        case .assets: assetManifestText
        }
    }

    private func allowedOperations(for pane: HTMLWorkspaceSourcePane) -> [String] {
        switch pane {
        case .html:
            ["replaceHTML", "insertBlock", "insertChart", "captureSnapshot"]
        case .css:
            ["replaceCSS", "updateStyleRule"]
        case .js:
            ["replaceJS"]
        case .data:
            ["replaceDataJSON", "insertChart"]
        case .dom:
            ["insertBlock", "insertChart"]
        case .assets:
            ["addAsset", "captureSnapshot"]
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

private enum HTMLWorkspaceHTMLImporter {
    struct ImportedSources {
        var html: String
        var css: String
        var js: String
        var dataJSON: String
    }

    static func importSources(from source: String) -> ImportedSources {
        let dataJSON = firstCapture(
            pattern: #"(?is)<script[^>]*id\s*=\s*["']workspace-data["'][^>]*>(.*?)</script>"#,
            in: source
        ).map(decodeBasicHTMLEntities) ?? ""
        let css = captures(
            pattern: #"(?is)<style[^>]*>(.*?)</style>"#,
            in: source
        )
        .joined(separator: "\n\n")
        let js = captures(
            pattern: #"(?is)<script(?![^>]*type\s*=\s*["']application/json["'])[^>]*>(.*?)</script>"#,
            in: source
        )
        .filter { !$0.contains("Object.defineProperty(window, 'HTMLWorkspace'") }
        .joined(separator: "\n\n")

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

    private static func decodeBasicHTMLEntities(_ source: String) -> String {
        source
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

private enum HTMLWorkspaceSourcePane: String, CaseIterable, Identifiable {
    case html
    case css
    case js
    case data
    case dom
    case assets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .html: "HTML"
        case .css: "CSS"
        case .js: "JS"
        case .data: "Data"
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
        case .dom: .dom
        case .assets: .assets
        }
    }

    func subtitle(for package: HTMLWorkspacePackage) -> String {
        switch self {
        case .html: "DOM structure"
        case .css: "Presentation"
        case .js: "Local behavior"
        case .data: "Structured state"
        case .dom: "\(HTMLWorkspaceDOMOutline.nodeCount(in: package.indexHTML)) nodes"
        case .assets: "\(package.assets.count) assets, \(package.snapshots.count) snapshots"
        }
    }

    func metricText(for package: HTMLWorkspacePackage) -> String {
        switch self {
        case .html: Self.counts(for: package.indexHTML)
        case .css: Self.counts(for: package.styleCSS)
        case .js: Self.counts(for: package.scriptJS)
        case .data: Self.counts(for: package.dataJSON)
        case .dom: "\(HTMLWorkspaceDOMOutline.nodeCount(in: package.indexHTML)) nodes"
        case .assets: "\(package.assets.count + package.snapshots.count) files"
        }
    }

    private static func counts(for source: String) -> String {
        let lines = max(1, source.split(separator: "\n", omittingEmptySubsequences: false).count)
        return "\(lines) lines / \(source.count) chars"
    }
}
