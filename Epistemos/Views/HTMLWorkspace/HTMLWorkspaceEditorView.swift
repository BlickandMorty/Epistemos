import AppKit
import SwiftUI
import UniformTypeIdentifiers
struct HTMLWorkspaceEditorView: View {
    @Binding var package: HTMLWorkspacePackage
    let theme: EpistemosTheme?
    let externalRevision: Int
    @Environment(\.colorScheme) private var colorScheme
    @State private var gooseRegenerator = HTMLWorkspaceGooseRegenerator()
    @State private var previewPackage: HTMLWorkspacePackage
    @State private var selectedPane: HTMLWorkspaceSourcePane = .html
    @State private var layoutMode: HTMLWorkspaceLayoutMode = .split
    @State private var previewUpdateTask: Task<Void, Never>?
    @State private var consoleExpanded = false
    @State private var inspectorVisible = false
    @State private var isExportingPDF = false
    @State private var statusText: String?
    @State private var liveDOMSnapshot: HTMLWorkspaceDOMSnapshot?
    @State private var selectedElementInspection: HTMLWorkspaceElementInspection?
    @State private var regenerateSheetPresented = false
    @State private var regenerateInstruction = ""
    @State private var regenerateStreamText = ""
    @State private var regenerateErrorText: String?
    @State private var regenerateTask: Task<Void, Never>?
    @State private var isRegenerating = false
    @State private var sourceCursorLine = 1
    @State private var sourceCursorColumn = 1
    @State private var sourceTotalLines = 1

    @AppStorage("codeEditor.wrapLines") private var sourceWrapLines = false
    @AppStorage("codeEditor.showInvisibles") private var sourceShowInvisibles = false
    @AppStorage("codeEditor.fontSize") private var sourceFontSize: Double = 15
    @AppStorage("codeEditor.useSpaces") private var sourceUseSpaces = true
    @AppStorage("codeEditor.tabWidth") private var sourceTabWidth = 4
    @AppStorage("epistemos.codeEditor.showLineGutter") private var sourceShowLineGutter = true

    init(
        package: Binding<HTMLWorkspacePackage>,
        theme: EpistemosTheme? = nil,
        externalRevision: Int = 0
    ) {
        self._package = package
        self.theme = theme
        self.externalRevision = externalRevision
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
        .onChange(of: externalRevision) { _, _ in
            liveDOMSnapshot = nil
            previewPackage = package
        }
        .onChange(of: inspectorVisible) { _, visible in
            if !visible {
                selectedElementInspection = nil
            }
        }
        .onDisappear {
            previewUpdateTask?.cancel()
            previewUpdateTask = nil
            regenerateTask?.cancel()
            regenerateTask = nil
            gooseRegenerator.stop()
        }
        .sheet(isPresented: $regenerateSheetPresented) {
            HTMLWorkspaceRegenerateSheet(
                instruction: $regenerateInstruction,
                streamedText: regenerateStreamText,
                errorText: regenerateErrorText,
                isRegenerating: isRegenerating,
                onCancel: {
                    if isRegenerating {
                        regenerateTask?.cancel()
                        regenerateTask = nil
                        isRegenerating = false
                        statusText = "Regenerate stopped"
                    }
                    regenerateSheetPresented = false
                },
                onSubmit: beginRegenerateSurface
            )
            .frame(width: 620, height: 520)
            .preferredColorScheme(workspaceColorScheme)
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

            Button {
                openRegenerateSheet()
            } label: {
                Label("Regenerate", systemImage: isRegenerating ? "hourglass" : "wand.and.sparkles")
            }
            .labelStyle(.iconOnly)
            .disabled(isRegenerating)
            .help("Regenerate surface")

            Button {
                self.setAppBridgeEnabled(!package.manifest.sandboxPolicy.allowAppBridge)
            } label: {
                Label(
                    package.manifest.sandboxPolicy.allowAppBridge ? "Disable App Bridge" : "Enable App Bridge",
                    systemImage: package.manifest.sandboxPolicy.allowAppBridge
                        ? "point.3.connected.trianglepath.dotted"
                        : "point.3.filled.connected.trianglepath.dotted"
                )
            }
            .labelStyle(.iconOnly)
            .help(package.manifest.sandboxPolicy.allowAppBridge ? "Disable app bridge" : "Enable app bridge")

            Button {
                self.setPythonRuntimeEnabled(!package.manifest.sandboxPolicy.allowPythonRuntime)
            } label: {
                Label(
                    package.manifest.sandboxPolicy.allowPythonRuntime ? "Disable Python" : "Enable Python",
                    systemImage: package.manifest.sandboxPolicy.allowPythonRuntime
                        ? "chevron.left.forwardslash.chevron.right"
                        : "chevron.left.forwardslash.chevron.right"
                )
            }
            .labelStyle(.iconOnly)
            .help(package.manifest.sandboxPolicy.allowPythonRuntime ? "Disable Python runtime" : "Enable Python runtime")

            Menu {
                Button("Regenerate Surface", systemImage: isRegenerating ? "hourglass" : "wand.and.sparkles") {
                    openRegenerateSheet()
                }
                .disabled(isRegenerating)
                Divider()
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
        HTMLWorkspaceSourceRail(
            selectedPane: $selectedPane,
            package: package,
            theme: workspaceTheme,
            panelFill: panelFill,
            dataStatus: dataStatus,
            statusText: statusText
        )
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
            workspaceCodeEditor(text: $package.indexHTML, language: selectedPane.codeEditorLanguage)
        case .css:
            workspaceCodeEditor(text: $package.styleCSS, language: selectedPane.codeEditorLanguage)
        case .js:
            workspaceCodeEditor(text: $package.scriptJS, language: selectedPane.codeEditorLanguage)
        case .data:
            workspaceCodeEditor(text: $package.dataJSON, language: selectedPane.codeEditorLanguage)
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
        HTMLWorkspaceReadOnlySourcePane(
            title: title,
            systemImage: systemImage,
            text: text,
            emptyText: emptyText,
            theme: workspaceTheme
        )
    }

    private func workspaceCodeEditor(text: Binding<String>, language: String) -> some View {
        MarkEditCodeEditorRepresentable(
            text: text,
            cursorLine: $sourceCursorLine,
            cursorColumn: $sourceCursorColumn,
            totalLines: $sourceTotalLines,
            language: language,
            theme: workspaceTheme,
            fontSize: sourceFontSize,
            wrapLines: sourceWrapLines,
            showLineNumbers: sourceShowLineGutter,
            showInvisibles: sourceShowInvisibles,
            useSpaces: sourceUseSpaces,
            tabWidth: sourceTabWidth,
            selectionRequest: nil
        )
        .id("workspace-code-editor-\(selectedPane.rawValue)")
        .background(MarkdownPreviewSurfaceStyle.canvasBackground(for: workspaceTheme))
    }

    private var previewShell: some View {
        HSplitView {
            VStack(spacing: 0) {
                previewHeader
                Divider()
                HTMLWorkspacePreviewView(
                    package: previewPackage,
                    safeAPIEnabled: true,
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
                    },
                    isElementInspectorEnabled: inspectorVisible,
                    onElementInspection: { inspection in
                        selectedElementInspection = inspection
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
        HTMLWorkspacePreviewHeader(
            package: package,
            bridgeStatusText: bridgeStatusText,
            pythonRuntimeStatusText: pythonRuntimeStatusText,
            headerFill: headerFill
        )
    }

    private var consolePanel: some View {
        HTMLWorkspaceConsolePanel(
            isExpanded: $consoleExpanded,
            errors: package.consoleErrors,
            panelFill: panelFill
        )
    }

    private var inspectorPanel: some View {
        HTMLWorkspaceInspectorPanel(
            package: package,
            contentHash: contentHash,
            domNodeCount: domNodeCount,
            domSourceLabel: domSnapshot.source.label,
            selectedElementInspection: selectedElementInspection,
            dataStatus: dataStatus,
            generationProvenanceText: generationProvenanceText,
            bridgeStatusText: bridgeStatusText,
            pythonRuntimeStatusText: pythonRuntimeStatusText,
            panelFill: panelFill
        )
    }

    private var bridgeStatusText: String {
        package.manifest.sandboxPolicy.allowAppBridge ? "Bridge live" : "No bridge"
    }

    private var pythonRuntimeStatusText: String {
        guard package.manifest.sandboxPolicy.allowPythonRuntime else { return "Python off" }
        return HTMLWorkspacePythonRuntime.isAvailable ? "Python live" : "Python missing"
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
        HTMLWorkspacePreviewThemeGuard.css(for: workspaceTheme)
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
        // Keep theme out of the SwiftUI identity: appearance flips should update the
        // live WKWebView, not tear it down while script handlers or loads are active.
        HTMLWorkspacePreviewIdentity.viewIdentity(for: previewPackage)
    }

    private func saveDocument() {
        if let document = currentHTMLWorkspaceDocument() {
            document.save(nil)
        } else {
            NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
        }
        statusText = "Save requested"
    }

    private func setAppBridgeEnabled(_ enabled: Bool) {
        guard package.manifest.sandboxPolicy.allowAppBridge != enabled else { return }
        var updated = package
        updated.manifest.sandboxPolicy.allowAppBridge = enabled
        updated.manifest.sandboxPolicy.safeAPIVersion = max(1, updated.manifest.sandboxPolicy.safeAPIVersion)
        updated.manifest.updatedAt = Int64(Date().timeIntervalSince1970 * 1_000)
        updated.manifest.contentHash = HTMLWorkspaceDocument.contentHash(
            indexHTML: updated.indexHTML,
            styleCSS: updated.styleCSS,
            scriptJS: updated.scriptJS,
            dataJSON: updated.dataJSON,
            routes: updated.routes
        )
        package = updated
        schedulePreviewUpdate(updated)
        statusText = enabled ? "App bridge enabled" : "App bridge disabled"
    }

    private func setPythonRuntimeEnabled(_ enabled: Bool) {
        guard package.manifest.sandboxPolicy.allowPythonRuntime != enabled else { return }
        var updated = package
        updated.manifest.sandboxPolicy.allowPythonRuntime = enabled
        updated.manifest.updatedAt = Int64(Date().timeIntervalSince1970 * 1_000)
        updated.manifest.contentHash = HTMLWorkspaceDocument.contentHash(
            indexHTML: updated.indexHTML,
            styleCSS: updated.styleCSS,
            scriptJS: updated.scriptJS,
            dataJSON: updated.dataJSON,
            routes: updated.routes
        )
        package = updated
        schedulePreviewUpdate(updated)
        if enabled, !HTMLWorkspacePythonRuntime.isAvailable {
            statusText = "Python enabled, but Pyodide assets are missing from this build"
        } else {
            statusText = enabled ? "Python runtime enabled" : "Python runtime disabled"
        }
    }

    private func openRegenerateSheet() {
        regenerateErrorText = nil
        regenerateStreamText = ""
        regenerateSheetPresented = true
    }

    private func beginRegenerateSurface() {
        guard !isRegenerating else { return }
        let instruction = regenerateInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else {
            regenerateErrorText = "Enter a regenerate request."
            return
        }

        let sourcePackage = package
        let expectedHash = HTMLWorkspaceDocument.contentHash(
            indexHTML: sourcePackage.indexHTML,
            styleCSS: sourcePackage.styleCSS,
            scriptJS: sourcePackage.scriptJS,
            dataJSON: sourcePackage.dataJSON,
            routes: sourcePackage.routes
        )
        let prompt = HTMLWorkspaceRegeneratePromptBuilder.prompt(
            instruction: instruction,
            package: sourcePackage,
            expectedContentHash: expectedHash
        )

        regenerateTask?.cancel()
        regenerateStreamText = ""
        regenerateErrorText = nil
        isRegenerating = true
        statusText = "Regenerating surface"

        regenerateTask = Task { @MainActor in
            defer {
                isRegenerating = false
                regenerateTask = nil
            }
            do {
                var response = ""
                let workspaceURL = currentHTMLWorkspaceDocument()?.fileURL
                for try await chunk in gooseRegenerator.streamRegeneration(
                    systemPrompt: HTMLWorkspaceRegeneratePromptBuilder.systemPrompt,
                    prompt: prompt,
                    workspaceURL: workspaceURL
                ) {
                    guard !Task.isCancelled else { throw CancellationError() }
                    response += chunk
                    regenerateStreamText = response
                }

                let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
                    from: response,
                    package: sourcePackage,
                    expectedContentHash: expectedHash
                )
                let result = try HTMLWorkspaceRegenerateApplication.apply(
                    patchResponse,
                    to: package,
                    expectedContentHash: expectedHash
                )
                package = result.package
                previewPackage = result.package
                selectedPane = .html
                layoutMode = .split
                regenerateErrorText = nil
                statusText = "Regenerated surface"
            } catch is CancellationError {
                statusText = "Regenerate stopped"
            } catch {
                regenerateErrorText = error.localizedDescription
                statusText = failedStatus("Regenerate", error: error)
            }
        }
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
