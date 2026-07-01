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
    @State private var selectedRouteName: String?
    @State private var previewRouteName: String?
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
    @State private var regenerateContextQuery = ""
    @State private var regenerateContextStatusText: String?
    @State private var regenerateContextTask: Task<Void, Never>?
    @State private var regenerateContextRefreshNonce = 0
    @State private var isRefreshingRegenerateContext = false
    @State private var pendingRegeneratePatchResponse: String?
    @State private var pendingRegenerateExpectedContentHash: String?
    @State private var regenerateErrorText: String?
    @State private var regenerateTask: Task<Void, Never>?
    @State private var isRegenerating = false
    @State private var sourceCursorLine = 1
    @State private var sourceCursorColumn = 1
    @State private var sourceTotalLines = 1
    @State private var appBridgeProbeNonce = 0
    @State private var consoleProbeNonce = 0
    @State private var pythonProbeNonce = 0

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
            workspaceBody
        }
        .onChange(of: package) { _, newValue in
            liveDOMSnapshot = nil
            if let selectedRouteName, newValue.routes[selectedRouteName] == nil {
                self.selectedRouteName = newValue.routes.keys.sorted().first
            }
            if let previewRouteName, newValue.routes[previewRouteName] == nil {
                self.previewRouteName = nil
            }
            schedulePreviewUpdate(newValue)
        }
        .onChange(of: colorScheme) { _, _ in
            previewPackage = package
        }
        .onChange(of: theme) { _, _ in
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
            regenerateContextTask?.cancel()
            regenerateContextTask = nil
            gooseRegenerator.stop()
        }
        .sheet(isPresented: $regenerateSheetPresented) {
            HTMLWorkspaceRegenerateSheet(
                instruction: $regenerateInstruction,
                streamedText: $regenerateStreamText,
                contextQuery: $regenerateContextQuery,
                workspaceID: package.manifest.id,
                expectedContentHash: package.currentContentHash,
                errorText: regenerateErrorText,
                contextStatusText: regenerateContextStatusLine,
                isRegenerating: isRegenerating,
                isRefreshingContext: isRefreshingRegenerateContext,
                hasPendingPreview: pendingRegeneratePatchResponse != nil && pendingRegenerateExpectedContentHash != nil,
                hasVaultContext: package.manifest.dataFeed != nil,
                contextItems: HTMLWorkspaceRegenerateContextItem.items(from: package),
                canRestorePreviousSurface: package.manifest.generationProvenance?.reversibleSnapshotName != nil,
                onCancel: {
                    if isRegenerating {
                        regenerateTask?.cancel()
                        regenerateTask = nil
                        isRegenerating = false
                        statusText = "Regenerate stopped"
                    }
                    restorePreviewAfterRegenerate()
                    regenerateSheetPresented = false
                },
                onCopyPrompt: copyRegeneratePrompt,
                onRefreshContext: refreshRegenerateVaultContext,
                onClearContext: clearRegenerateVaultContext,
                onFocusContextItem: focusRegenerateContextItem,
                onRunPreset: runRegeneratePreset,
                onSubmit: beginRegenerateSurface,
                onApplyPreview: applyPendingRegeneratePreview,
                onPreviewStream: previewRegenerateStreamText,
                onApplyStream: applyRegenerateStreamText,
                onRestorePreview: restorePreviewAfterRegenerate,
                onRestorePreviousSurface: restorePreviousSurface
            )
            .frame(width: 700, height: 640)
            .preferredColorScheme(workspaceTheme.isDark ? .dark : .light)
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
                    .foregroundStyle(workspaceTheme.textTertiary)
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
                Button("Restore Previous Surface", systemImage: "arrow.uturn.backward.circle", action: restorePreviousSurface)
                .disabled(package.manifest.generationProvenance?.reversibleSnapshotName == nil || isRegenerating)
                Divider()
                Button("Import HTML", systemImage: "tray.and.arrow.down") {
                    importHTML()
                }
                Button("Export HTML", systemImage: "square.and.arrow.up") {
                    exportHTML()
                }
                Button("Export Site Folder", systemImage: "folder") {
                    exportSiteFolder()
                }
                Button("Capture Snapshot", systemImage: "camera.viewfinder") {
                    captureSnapshot()
                }
                Button("Add Route", systemImage: "map") {
                    addRoute()
                }
                .disabled(isRegenerating)
                Button("Remove Route", systemImage: "map.fill") {
                    removeRoute()
                }
                .disabled(package.routes.isEmpty || isRegenerating)
                Button("Add Asset", systemImage: "plus.square.on.square") {
                    addAsset()
                }
                .disabled(isRegenerating)
                Button("Remove Asset", systemImage: "shippingbox.fill") {
                    removeAsset()
                }
                .disabled(package.assets.isEmpty || isRegenerating)
                Button("Test Runtime Bridges", systemImage: "stethoscope", action: testRuntimeBridgeProbes)
                    .disabled(isRegenerating)
                Button("Test App Bridge", systemImage: "point.3.connected.trianglepath", action: testAppBridge)
                .disabled(!package.manifest.sandboxPolicy.allowAppBridge || isRegenerating)
                Button("Insert App Bridge Demo", systemImage: "point.3.connected.trianglepath", action: insertAppBridgeDemo)
                .disabled(isRegenerating)
                Button("Test Console Capture", systemImage: "terminal", action: testConsoleCapture).disabled(isRegenerating)
                Button("Test Python Runtime", systemImage: "chevron.left.forwardslash.chevron.right", action: testPythonRuntime)
                .disabled(!package.manifest.sandboxPolicy.allowPythonRuntime || isRegenerating)
                Button("Insert Python Demo", systemImage: "chevron.left.forwardslash.chevron.right", action: insertPythonDemo)
                .disabled(isRegenerating)
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
                VStack(spacing: 0) {
                    sourceHeader
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
                .foregroundStyle(workspaceTheme.textTertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(selectedPane.fileName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(workspaceTheme.resolved.foreground.color)
                Text(selectedPaneSubtitle)
                    .font(.caption2)
                    .foregroundStyle(workspaceTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Text(selectedPaneMetricText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(workspaceTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(workspaceMetricFill, in: Capsule())
            Menu {
                Section("Allowed Ops") {
                    ForEach(selectedPane.allowedPatchOperations, id: \.self) { operation in
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
            .menuIndicator(.hidden)
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
            if package.routes.isEmpty {
                readOnlySourcePane(
                    title: "Routes",
                    systemImage: "map",
                    text: routeManifestText,
                    emptyText: "No package routes."
                )
            } else {
                routeSourceEditor
            }
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

    private var routeSourceEditor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "map")
                    .foregroundStyle(workspaceTheme.resolved.accent.color)
                Text("routes/")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(workspaceTheme.resolved.foreground.color)
                Picker("Route", selection: routeSelectionBinding) {
                    ForEach(sortedRouteNames, id: \.self) { routeName in
                        Text(routeName).tag(routeName)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(headerFill)

            if let routeName = activeRouteName {
                workspaceCodeEditor(
                    text: routeBodyBinding(for: routeName),
                    language: "html",
                    identity: "routes-\(routeName)"
                )
            }
        }
    }

    private func workspaceCodeEditor(
        text: Binding<String>,
        language: String,
        identity: String? = nil
    ) -> some View {
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
        .id("workspace-code-editor-\(identity ?? selectedPane.rawValue)")
        .background(MarkdownPreviewSurfaceStyle.canvasBackground(for: workspaceTheme))
    }

    private var previewShell: some View {
        HSplitView {
            VStack(spacing: 0) {
                previewHeader
                HTMLWorkspacePreviewView(
                    package: previewPackage,
                    routeName: previewRouteName,
                    safeAPIEnabled: true,
                    previewTheme: previewTheme,
                    themeGuardCSSOverride: previewThemeGuardCSS,
                    themeIdentity: workspaceThemeIdentity,
                    onConsoleError: { error in
                        package = (try? HTMLWorkspacePatchApplier.apply(.recordConsoleError(error), to: package)) ?? package
                    },
                    onDOMSnapshot: { snapshot in
                        liveDOMSnapshot = snapshot
                    },
                    isElementInspectorEnabled: inspectorVisible,
                    onElementInspection: { inspection in
                        selectedElementInspection = inspection
                    },
                    appBridgeProbeNonce: appBridgeProbeNonce,
                    consoleProbeNonce: consoleProbeNonce,
                    pythonProbeNonce: pythonProbeNonce
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
            routeNames: sortedRouteNames,
            previewRouteName: $previewRouteName,
            bridgeStatusText: bridgeStatusText,
            pythonRuntimeStatusText: pythonRuntimeStatusText,
            headerFill: headerFill,
            theme: workspaceTheme
        )
    }

    private var consolePanel: some View {
        HTMLWorkspaceConsolePanel(
            isExpanded: $consoleExpanded,
            errors: package.consoleErrors,
            panelFill: panelFill,
            theme: workspaceTheme,
            onClear: clearConsole
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
            panelFill: panelFill,
            theme: workspaceTheme,
            onCopySelector: copyInspectorSelector,
            onCreateStyleRule: addInspectorStyleRule,
            onCopyStyleRulePatch: copyInspectorStyleRulePatch,
            onUpdateStyleDeclaration: updateInspectorStyleDeclaration,
            onCopyStyleDeclarationPatch: copyInspectorStyleDeclarationPatch
        )
    }

    private var bridgeStatusText: String {
        package.manifest.sandboxPolicy.allowAppBridge ? "Bridge enabled" : "No bridge"
    }

    private var pythonRuntimeStatusText: String {
        guard package.manifest.sandboxPolicy.allowPythonRuntime else { return "Python off" }
        return HTMLWorkspacePythonRuntime.availabilityStatusText
    }

    private var generationProvenanceText: String {
        guard let provenance = package.manifest.generationProvenance else {
            return "Local / unstamped"
        }
        return provenance.displayText(currentContentHash: contentHash)
    }

    private var regenerateContextStatusLine: String? {
        regenerateContextStatusText
            ?? HTMLWorkspaceDataFeedStatus.detailLine(for: package)
            ?? HTMLWorkspaceDataFeedStatus.compactLine(for: package)
    }

    private var selectedPaneSubtitle: String {
        selectedPane.subtitle(for: package, domSnapshot: domSnapshot)
    }

    private var selectedPaneMetricText: String {
        selectedPane.metricText(for: package, domSnapshot: domSnapshot)
    }

    private var sortedRouteNames: [String] {
        package.routes.keys.sorted()
    }

    private var activeRouteName: String? {
        let routeNames = sortedRouteNames
        guard !routeNames.isEmpty else { return nil }
        if let selectedRouteName, routeNames.contains(selectedRouteName) {
            return selectedRouteName
        }
        return routeNames.first
    }

    private var routeSelectionBinding: Binding<String> {
        Binding(
            get: { activeRouteName ?? "" },
            set: {
                selectedRouteName = $0
                previewRouteName = $0
            }
        )
    }

    private func routeBodyBinding(for routeName: String) -> Binding<String> {
        Binding(
            get: { package.routes[routeName, default: ""] },
            set: { package.routes[routeName] = $0 }
        )
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
        let routeAssetRows = package.routes.isEmpty
            ? []
            : package.assets
                .sorted { $0.key < $1.key }
                .map { "routes/assets/\($0.key)  route-relative mirror" }
        let snapshotRows = package.snapshots
            .sorted { $0.key < $1.key }
            .map { "snapshot/\($0.key)  \($0.value.count) bytes" }
        return (assetRows + routeAssetRows + snapshotRows).joined(separator: "\n")
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
        package.currentContentHash
    }

    private var previewTheme: HTMLWorkspacePreviewTheme {
        workspaceTheme.isDark ? .dark : .light
    }

    private var workspaceTheme: EpistemosTheme {
        (theme ?? (colorScheme == .dark ? EpistemosTheme.oledSoft : EpistemosTheme.light))
            .surfaceVariant(.other)
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

    private var workspaceMetricFill: Color {
        workspaceTheme.resolved.card.color.opacity(workspaceTheme.isDark ? 0.30 : 0.54)
    }

    private var previewRenderIdentity: String {
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
        updated.manifest.contentHash = updated.currentContentHash
        package = updated
        previewUpdateTask?.cancel()
        previewUpdateTask = nil
        liveDOMSnapshot = nil
        previewPackage = updated
        statusText = enabled ? "App bridge enabled" : "App bridge disabled"
    }

    private func setPythonRuntimeEnabled(_ enabled: Bool) {
        guard package.manifest.sandboxPolicy.allowPythonRuntime != enabled else { return }
        var updated = package
        updated.manifest.sandboxPolicy.allowPythonRuntime = enabled
        updated.manifest.updatedAt = Int64(Date().timeIntervalSince1970 * 1_000)
        updated.manifest.contentHash = updated.currentContentHash
        package = updated
        previewUpdateTask?.cancel()
        previewUpdateTask = nil
        liveDOMSnapshot = nil
        previewPackage = updated
        if enabled, !HTMLWorkspacePythonRuntime.isAvailable {
            statusText = "Python enabled, \(HTMLWorkspacePythonRuntime.availabilityStatusText)"
        } else {
            statusText = enabled ? "Python runtime enabled" : "Python runtime disabled"
        }
    }

    private func openRegenerateSheet() {
        regenerateErrorText = nil
        regenerateStreamText = ""
        if let feedQuery = package.manifest.dataFeed?.normalizedQuery, !feedQuery.isEmpty {
            regenerateContextQuery = feedQuery
        } else if regenerateContextQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            regenerateContextQuery = package.manifest.title
        }
        regenerateContextStatusText = HTMLWorkspaceDataFeedStatus.detailLine(for: package)
            ?? HTMLWorkspaceDataFeedStatus.compactLine(for: package)
        clearPendingRegeneratePreview()
        regenerateSheetPresented = true
    }

    private func refreshRegenerateVaultContext() {
        let query = regenerateContextQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            regenerateContextStatusText = "Vault context query required"
            statusText = "Vault context query required"
            return
        }

        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: query, limit: HTMLWorkspaceDataFeed.defaultLimit)
        regenerateContextTask?.cancel()
        regenerateContextRefreshNonce &+= 1
        let refreshNonce = regenerateContextRefreshNonce
        isRefreshingRegenerateContext = true
        package.manifest.dataFeed = feed
        package.dataJSON = HTMLWorkspaceDataFeedJSONEnvelope.staleDataJSON(
            feed: feed,
            error: "Feed pending"
        )
        regenerateContextStatusText = "Vault context pending"
        statusText = "Refreshing vault context"

        guard let vaultSync = AppBootstrap.shared?.vaultSync else {
            package.dataJSON = HTMLWorkspaceDataFeedRenderer.staleRender(
                feed: feed,
                error: "Vault feed unavailable"
            )
            isRefreshingRegenerateContext = false
            regenerateContextTask = nil
            regenerateContextStatusText = "Vault feed unavailable"
            statusText = "Vault feed unavailable"
            return
        }

        regenerateContextTask = Task { @MainActor in
            defer {
                if regenerateContextRefreshNonce == refreshNonce {
                    isRefreshingRegenerateContext = false
                    regenerateContextTask = nil
                }
            }

            let results = await vaultSync.searchFullAsync(
                query: feed.normalizedQuery,
                limit: feed.effectiveLimit
            )
            guard !Task.isCancelled, regenerateContextRefreshNonce == refreshNonce else { return }
            package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(feed: feed, results: results)
            regenerateContextStatusText = "Vault context attached: \(results.count) \(results.count == 1 ? "result" : "results")"
            statusText = regenerateContextStatusText
        }
    }

    private func clearRegenerateVaultContext() {
        regenerateContextTask?.cancel()
        regenerateContextTask = nil
        regenerateContextRefreshNonce &+= 1
        isRefreshingRegenerateContext = false
        package.manifest.dataFeed = nil
        regenerateContextStatusText = "Vault context cleared"
        statusText = "Vault context cleared"
    }

    private func focusRegenerateContextItem(_ item: HTMLWorkspaceRegenerateContextItem) {
        let directive = "Use vault context item \"\(item.title)\" (\(item.pageID)) as a primary source; keep its provenance visible and do not invent missing details."
        let current = regenerateInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty {
            regenerateInstruction = directive
        } else if !current.contains(item.pageID) {
            regenerateInstruction = current + "\n" + directive
        }
        regenerateContextStatusText = "Focused \(item.title)"
        statusText = "Vault context item focused"
    }

    private func beginRegenerateSurface() {
        beginRegenerateSurface(instructionOverride: nil)
    }

    private func runRegeneratePreset(_ preset: HTMLWorkspaceRegeneratePreset) {
        regenerateInstruction = preset.instruction
        if preset.family == .vaultData {
            runVaultDataRegeneratePreset(preset)
            return
        }
        beginRegenerateSurface(instructionOverride: preset.instruction)
    }

    private func runVaultDataRegeneratePreset(_ preset: HTMLWorkspaceRegeneratePreset) {
        let query = regenerateContextQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? package.manifest.title.trimmingCharacters(in: .whitespacesAndNewlines)
            : regenerateContextQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            regenerateContextStatusText = "Vault context query required"
            statusText = "Vault context query required"
            return
        }

        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: query, limit: HTMLWorkspaceDataFeed.defaultLimit)
        regenerateContextQuery = query
        regenerateContextTask?.cancel()
        regenerateContextRefreshNonce &+= 1
        let refreshNonce = regenerateContextRefreshNonce
        isRefreshingRegenerateContext = true
        package.manifest.dataFeed = feed
        package.dataJSON = HTMLWorkspaceDataFeedJSONEnvelope.staleDataJSON(
            feed: feed,
            error: "Feed pending"
        )
        regenerateContextStatusText = "Vault context pending"
        statusText = "Refreshing vault context"

        guard let vaultSync = AppBootstrap.shared?.vaultSync else {
            package.dataJSON = HTMLWorkspaceDataFeedRenderer.staleRender(
                feed: feed,
                error: "Vault feed unavailable"
            )
            isRefreshingRegenerateContext = false
            regenerateContextTask = nil
            regenerateContextStatusText = "Vault feed unavailable"
            beginRegenerateSurface(instructionOverride: preset.instruction)
            return
        }

        regenerateContextTask = Task { @MainActor in
            defer {
                if regenerateContextRefreshNonce == refreshNonce {
                    isRefreshingRegenerateContext = false
                    regenerateContextTask = nil
                }
            }

            let results = await vaultSync.searchFullAsync(
                query: feed.normalizedQuery,
                limit: feed.effectiveLimit
            )
            guard !Task.isCancelled, regenerateContextRefreshNonce == refreshNonce else { return }
            package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(feed: feed, results: results)
            regenerateContextStatusText = "Vault context attached: \(results.count) \(results.count == 1 ? "result" : "results")"
            statusText = "Vault context ready"
            beginRegenerateSurface(instructionOverride: preset.instruction)
        }
    }

    private func beginRegenerateSurface(instructionOverride: String?) {
        guard !isRegenerating else { return }
        let sourceInstruction = instructionOverride ?? regenerateInstruction
        let instruction = sourceInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else {
            regenerateErrorText = "Enter a regenerate request."
            return
        }
        regenerateInstruction = instruction

        let sourcePackage = package
        let expectedHash = sourcePackage.currentContentHash
        let prompt = HTMLWorkspaceRegeneratePromptBuilder.prompt(
            instruction: instruction,
            package: sourcePackage,
            expectedContentHash: expectedHash
        )

        regenerateTask?.cancel()
        previewUpdateTask?.cancel()
        previewUpdateTask = nil
        clearPendingRegeneratePreview()
        previewRouteName = nil
        previewPackage = HTMLWorkspaceRegeneratePreview.loadingPackage(
            from: sourcePackage,
            instruction: instruction
        )
        liveDOMSnapshot = nil
        layoutMode = .split
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
                var previewCandidateHash: String?
                let workspaceURL = currentHTMLWorkspaceDocument()?.fileURL
                for try await chunk in gooseRegenerator.streamRegeneration(
                    systemPrompt: HTMLWorkspaceRegeneratePromptBuilder.systemPrompt,
                    prompt: prompt,
                    workspaceURL: workspaceURL
                ) {
                    guard !Task.isCancelled else { throw CancellationError() }
                    response += chunk
                    regenerateStreamText = response
                    if let candidate = HTMLWorkspaceRegeneratePreview.candidatePackage(
                        from: response,
                        basePackage: sourcePackage,
                        expectedContentHash: expectedHash
                    ),
                       candidate.manifest.contentHash != previewCandidateHash {
                        previewCandidateHash = candidate.manifest.contentHash
                        previewPackage = candidate
                        liveDOMSnapshot = nil
                    }
                }

                let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
                    from: response,
                    package: sourcePackage,
                    expectedContentHash: expectedHash
                )
                _ = try HTMLWorkspaceRegenerateApplication.apply(
                    patchResponse,
                    to: package,
                    expectedContentHash: expectedHash
                )
                if let candidate = HTMLWorkspaceRegeneratePreview.candidatePackage(
                    from: response,
                    basePackage: sourcePackage,
                    expectedContentHash: expectedHash
                ) {
                    previewPackage = candidate
                }
                pendingRegeneratePatchResponse = patchResponse
                pendingRegenerateExpectedContentHash = expectedHash
                previewRouteName = nil
                liveDOMSnapshot = nil
                selectedPane = .html
                layoutMode = .split
                regenerateErrorText = nil
                statusText = "Regenerate preview ready"
            } catch is CancellationError {
                restorePreviewAfterRegenerate()
                statusText = "Regenerate stopped"
            } catch {
                restorePreviewAfterRegenerate()
                regenerateErrorText = error.localizedDescription
                statusText = failedStatus("Regenerate", error: error)
            }
        }
    }

    private func clearPendingRegeneratePreview() {
        pendingRegeneratePatchResponse = nil
        pendingRegenerateExpectedContentHash = nil
    }

    private func copyRegeneratePrompt() {
        let instruction = regenerateInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else {
            regenerateErrorText = "Enter a regenerate request."
            return
        }

        let prompt = HTMLWorkspaceRegeneratePromptBuilder.clipboardPrompt(
            instruction: instruction,
            package: package,
            expectedContentHash: package.currentContentHash
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        regenerateErrorText = nil
        statusText = "Regenerate prompt copied"
    }

    private func restorePreviewAfterRegenerate() {
        previewUpdateTask?.cancel()
        previewUpdateTask = nil
        previewRouteName = nil
        liveDOMSnapshot = nil
        previewPackage = package
        clearPendingRegeneratePreview()
    }

    private func previewRegenerateStreamText() {
        guard !isRegenerating else { return }
        let response = regenerateStreamText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !response.isEmpty else {
            regenerateErrorText = "No regenerate response to preview."
            return
        }
        clearPendingRegeneratePreview()

        let sourcePackage = package
        let expectedHash = sourcePackage.currentContentHash
        guard let candidate = HTMLWorkspaceRegeneratePreview.candidatePackage(
            from: response,
            basePackage: sourcePackage,
            expectedContentHash: expectedHash
        ) else {
            regenerateErrorText = "Stream must contain a complete regenerate response for the visible workspace and current hash."
            statusText = "Regenerate preview unavailable"
            return
        }

        do {
            let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
                from: response,
                package: sourcePackage,
                expectedContentHash: expectedHash
            )
            _ = try HTMLWorkspaceRegenerateApplication.apply(
                patchResponse,
                to: package,
                expectedContentHash: expectedHash
            )
            pendingRegeneratePatchResponse = patchResponse
            pendingRegenerateExpectedContentHash = expectedHash
        } catch {
            regenerateErrorText = error.localizedDescription
            statusText = failedStatus("Regenerate preview", error: error)
            return
        }

        previewUpdateTask?.cancel()
        previewUpdateTask = nil
        previewRouteName = nil
        previewPackage = candidate
        liveDOMSnapshot = nil
        selectedPane = .html
        layoutMode = .split
        regenerateErrorText = nil
        statusText = "Regenerate preview ready"
    }

    private func applyPendingRegeneratePreview() {
        guard !isRegenerating else { return }
        guard let patchResponse = pendingRegeneratePatchResponse,
              let expectedHash = pendingRegenerateExpectedContentHash else {
            regenerateErrorText = "No regenerate preview to apply."
            return
        }

        do {
            let result = try HTMLWorkspaceRegenerateApplication.apply(
                patchResponse,
                to: package,
                expectedContentHash: expectedHash
            )
            package = result.package
            previewRouteName = nil
            previewPackage = result.package
            liveDOMSnapshot = nil
            selectedPane = .html
            layoutMode = .split
            clearPendingRegeneratePreview()
            regenerateErrorText = nil
            regenerateSheetPresented = false
            statusText = "Regenerate preview applied"
        } catch {
            regenerateErrorText = error.localizedDescription
            statusText = failedStatus("Regenerate apply", error: error)
        }
    }

    private func applyRegenerateStreamText() {
        guard !isRegenerating else { return }
        let response = regenerateStreamText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !response.isEmpty else {
            regenerateErrorText = "No regenerate response to apply."
            return
        }

        let expectedHash = package.currentContentHash
        do {
            let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
                from: response,
                package: package,
                expectedContentHash: expectedHash
            )
            let result = try HTMLWorkspaceRegenerateApplication.apply(
                patchResponse,
                to: package,
                expectedContentHash: expectedHash
            )
            package = result.package
            previewRouteName = nil
            previewPackage = result.package
            liveDOMSnapshot = nil
            selectedPane = .html
            layoutMode = .split
            clearPendingRegeneratePreview()
            regenerateErrorText = nil
            regenerateSheetPresented = false
            statusText = "Regenerate stream applied"
        } catch {
            regenerateErrorText = error.localizedDescription
            statusText = failedStatus("Regenerate apply", error: error)
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
        allowed_operations: \(pane.allowedPatchOperations.joined(separator: ", "))

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

    private func clearConsole() {
        guard !package.consoleErrors.isEmpty else { return }
        do {
            package = try HTMLWorkspacePatchApplier.apply(.clearConsole, to: package)
            statusText = "Console cleared"
        } catch {
            statusText = failedStatus("Console", error: error)
        }
    }

    private func copyInspectorSelector(_ selector: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selector, forType: .string)
        statusText = "Selector copied"
    }

    private func addInspectorStyleRule(_ inspection: HTMLWorkspaceElementInspection) {
        selectedPane = .css
        layoutMode = .split

        guard let styleRulePatch = inspection.styleRulePatch else {
            statusText = "No inspected styles to add"
            return
        }

        do {
            package = try HTMLWorkspacePatchApplier.apply(.updateStyleRule(styleRulePatch), to: package)
            previewPackage = package
            liveDOMSnapshot = nil
            statusText = "Inspected styles added"
        } catch {
            statusText = failedStatus("Style rule", error: error)
        }
    }

    private func copyInspectorStyleRulePatch(_ inspection: HTMLWorkspaceElementInspection) {
        guard let styleRulePatch = inspection.styleRulePatch else {
            statusText = "No inspected styles to copy"
            return
        }
        copyInspectorStylePatch(styleRulePatch)
    }

    private func updateInspectorStyleDeclaration(
        _ inspection: HTMLWorkspaceElementInspection,
        property: String,
        value: String
    ) {
        selectedPane = .css
        layoutMode = .split

        guard let styleRulePatch = inspection.styleRulePatch(property: property, value: value) else {
            statusText = "Style property and value required"
            return
        }

        do {
            package = try HTMLWorkspacePatchApplier.apply(.updateStyleRule(styleRulePatch), to: package)
            previewPackage = package
            liveDOMSnapshot = nil
            statusText = "Style updated"
        } catch {
            statusText = failedStatus("Style update", error: error)
        }
    }

    private func copyInspectorStyleDeclarationPatch(
        _ inspection: HTMLWorkspaceElementInspection,
        property: String,
        value: String
    ) {
        guard let styleRulePatch = inspection.styleRulePatch(property: property, value: value) else {
            statusText = "Style property and value required"
            return
        }
        copyInspectorStylePatch(styleRulePatch)
    }

    private func copyInspectorStylePatch(_ styleRulePatch: HTMLWorkspaceStyleRulePatch) {
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: package.manifest.id,
            expectedContentHash: package.currentContentHash,
            operations: [.updateStyleRule(styleRulePatch)]
        )
        do {
            let data = try JSONEncoder.epdocCanonical.encode(batch)
            guard let json = String(data: data, encoding: .utf8) else {
                statusText = "Style patch encoding failed"
                return
            }
            let patch = """
            ```\(HTMLWorkspacePatchCommandParser.fencedLanguage)
            \(json)
            ```
            """
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(patch, forType: .string)
            selectedPane = .css
            layoutMode = .split
            statusText = "Style patch copied"
        } catch {
            statusText = failedStatus("Style patch", error: error)
        }
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

    private func addRoute() {
        let nameField = NSTextField(string: "about.html")
        nameField.placeholderString = "about.html"

        let htmlTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 420, height: 160))
        htmlTextView.isRichText = false
        htmlTextView.isAutomaticQuoteSubstitutionEnabled = false
        htmlTextView.isAutomaticDashSubstitutionEnabled = false
        htmlTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        htmlTextView.string = """
        <main>
          <h1>New Route</h1>
        </main>
        """

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 160))
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = htmlTextView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.addArrangedSubview(NSTextField(labelWithString: "Route name"))
        stack.addArrangedSubview(nameField)
        stack.addArrangedSubview(NSTextField(labelWithString: "HTML"))
        stack.addArrangedSubview(scrollView)
        stack.setFrameSize(NSSize(width: 420, height: 230))
        nameField.frame.size.width = 420

        let alert = NSAlert()
        alert.messageText = "Add Route"
        alert.informativeText = "Create or replace a package-local routes/<name> HTML page."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = stack

        guard alert.runModal() == .alertFirstButtonReturn else {
            statusText = "Route unchanged"
            return
        }

        let name = normalizedRouteName(nameField.stringValue)
        let html = htmlTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !html.isEmpty else {
            statusText = "Route name and HTML required"
            return
        }

        do {
            package = try HTMLWorkspacePatchApplier.apply(.setRoute(name: name, html: html), to: package)
            previewPackage = package
            liveDOMSnapshot = nil
            selectedRouteName = name
            previewRouteName = name
            selectedPane = .routes
            layoutMode = .split
            statusText = "Route \(name) saved"
        } catch {
            statusText = failedStatus("Route", error: error)
        }
    }

    private func removeRoute() {
        let routeNames = package.routes.keys.sorted()
        guard !routeNames.isEmpty else {
            statusText = "No routes to remove"
            return
        }

        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 28), pullsDown: false)
        popUp.addItems(withTitles: routeNames)

        let alert = NSAlert()
        alert.messageText = "Remove Route"
        alert.informativeText = "Remove a package-local route from routes/."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = popUp

        guard alert.runModal() == .alertFirstButtonReturn,
              let name = popUp.selectedItem?.title,
              !name.isEmpty else {
            statusText = "Route unchanged"
            return
        }

        do {
            package = try HTMLWorkspacePatchApplier.apply(.removeRoute(name: name), to: package)
            previewPackage = package
            liveDOMSnapshot = nil
            selectedRouteName = sortedRouteNames.first
            if previewRouteName == name {
                previewRouteName = nil
            }
            selectedPane = .routes
            layoutMode = .split
            statusText = "Route \(name) removed"
        } catch {
            statusText = failedStatus("Route", error: error)
        }
    }

    private func normalizedRouteName(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              URL(fileURLWithPath: trimmed).pathExtension.isEmpty else {
            return trimmed
        }
        return trimmed + ".html"
    }

    private func addAsset() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else {
            statusText = "Asset unchanged"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let name = url.lastPathComponent
            package = try HTMLWorkspacePatchApplier.apply(
                .addAsset(HTMLWorkspaceAsset(name: name, data: data)),
                to: package
            )
            previewPackage = package
            liveDOMSnapshot = nil
            selectedPane = .assets
            layoutMode = .split
            statusText = "Asset \(name) added"
        } catch {
            statusText = failedStatus("Asset", error: error)
        }
    }

    private func removeAsset() {
        let assetNames = package.assets.keys.sorted()
        guard !assetNames.isEmpty else {
            statusText = "No assets to remove"
            return
        }

        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 28), pullsDown: false)
        popUp.addItems(withTitles: assetNames)

        let alert = NSAlert()
        alert.messageText = "Remove Asset"
        alert.informativeText = "Remove a package-local asset from assets/."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = popUp

        guard alert.runModal() == .alertFirstButtonReturn,
              let name = popUp.selectedItem?.title,
              !name.isEmpty else {
            statusText = "Asset unchanged"
            return
        }

        do {
            package = try HTMLWorkspacePatchApplier.apply(.removeAsset(name: name), to: package)
            previewPackage = package
            liveDOMSnapshot = nil
            selectedPane = .assets
            layoutMode = .split
            statusText = "Asset \(name) removed"
        } catch {
            statusText = failedStatus("Asset", error: error)
        }
    }

    private func restorePreviousSurface() {
        guard let name = package.manifest.generationProvenance?.reversibleSnapshotName else {
            statusText = "No restore snapshot"
            return
        }
        do {
            package = try HTMLWorkspacePatchApplier.apply(.restoreSnapshot(name: name), to: package)
            previewPackage = package
            liveDOMSnapshot = nil
            selectedPane = .html
            layoutMode = .split
            statusText = "Previous surface restored"
        } catch {
            statusText = failedStatus("Restore", error: error)
        }
    }

    private func testAppBridge() {
        guard package.manifest.sandboxPolicy.allowAppBridge else {
            statusText = "App bridge disabled"
            return
        }
        consoleExpanded = true
        layoutMode = .split
        appBridgeProbeNonce &+= 1
        statusText = "App bridge probe requested"
    }

    private func testConsoleCapture() {
        consoleExpanded = true
        layoutMode = .split
        consoleProbeNonce &+= 1
        statusText = "Console capture probe requested"
    }

    private func testPythonRuntime() {
        guard package.manifest.sandboxPolicy.allowPythonRuntime else {
            statusText = "Python runtime disabled"
            return
        }
        consoleExpanded = true
        layoutMode = .split
        pythonProbeNonce &+= 1
        statusText = HTMLWorkspacePythonRuntime.isAvailable
            ? "Python runtime probe requested"
            : "Python runtime probe requested; \(HTMLWorkspacePythonRuntime.availabilityStatusText)"
    }

    private func testRuntimeBridgeProbes() {
        consoleExpanded = true
        layoutMode = .split
        appBridgeProbeNonce &+= 1
        consoleProbeNonce &+= 1
        pythonProbeNonce &+= 1
        statusText = "Runtime bridge probes requested"
    }

    private func insertAppBridgeDemo() {
        do {
            let updated = try HTMLWorkspaceAppBridgeDemoScaffold.apply(to: package)
            package = updated
            previewPackage = updated
            selectedPane = .js
            layoutMode = .split
            consoleExpanded = true
            statusText = "App bridge demo inserted"
        } catch {
            statusText = failedStatus("App bridge demo", error: error)
        }
    }

    private func insertPythonDemo() {
        do {
            let updated = try HTMLWorkspacePythonDemoScaffold.apply(to: package)
            package = updated
            previewPackage = updated
            selectedPane = .js
            layoutMode = .split
            consoleExpanded = true
            statusText = HTMLWorkspacePythonRuntime.isAvailable
                ? "Python demo inserted"
                : "Python demo inserted; \(HTMLWorkspacePythonRuntime.availabilityStatusText)"
        } catch {
            statusText = failedStatus("Python demo", error: error)
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

    private func exportSiteFolder() {
        guard let destination = chooseSiteFolderDestination() else {
            statusText = "Site export cancelled"
            return
        }
        do {
            let summary = try HTMLWorkspaceSiteFolderExporter.export(
                package: package,
                theme: previewTheme,
                to: destination
            )
            statusText = summary.statusText
        } catch {
            statusText = failedStatus("Site export", error: error)
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

    private func chooseSiteFolderDestination() -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(safeFileName(package.manifest.title.isEmpty ? "HTML Workspace" : package.manifest.title))-site"
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
