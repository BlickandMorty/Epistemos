import AppKit
import SwiftUI
struct HTMLWorkspaceEditorView: View {
    @Binding var package: HTMLWorkspacePackage
    let theme: EpistemosTheme?
    let externalRevision: Int
    @Environment(\.colorScheme) private var colorScheme
    @State var gooseRegenerator = HTMLWorkspaceGooseRegenerator()
    @State var previewPackage: HTMLWorkspacePackage
    @State var selectedPane: HTMLWorkspaceSourcePane = .html
    @State var selectedRouteName: String?
    @State var previewRouteName: String?
    @State var layoutMode: HTMLWorkspaceLayoutMode = .split
    @State var previewUpdateTask: Task<Void, Never>?
    @State var consoleExpanded = false
    @State private var inspectorVisible = false
    @State var isExportingPDF = false
    @State var statusText: String?
    @State var liveDOMSnapshot: HTMLWorkspaceDOMSnapshot?
    @State var selectedElementInspection: HTMLWorkspaceElementInspection?
    @State var regenerateSheetPresented = false
    @State var regenerateInstruction = ""
    @State var regenerateStreamText = ""
    @State var regenerateContextQuery = ""
    @State var regenerateContextStatusText: String?
    @State var regenerateContextTask: Task<Void, Never>?
    @State var regenerateContextRefreshNonce = 0
    @State var isRefreshingRegenerateContext = false
    @State var pendingRegeneratePatchResponse: String?
    @State var pendingRegenerateExpectedContentHash: String?
    @State var regenerateErrorText: String?
    @State var regenerateTask: Task<Void, Never>?
    @State var isRegenerating = false
    @State private var sourceCursorLine = 1
    @State private var sourceCursorColumn = 1
    @State private var sourceTotalLines = 1
    @State var appBridgeProbeNonce = 0
    @State var consoleProbeNonce = 0
    @State var pythonProbeNonce = 0

    @AppStorage("codeEditor.wrapLines") private var sourceWrapLines = false
    @AppStorage("codeEditor.showInvisibles") private var sourceShowInvisibles = false
    @AppStorage("codeEditor.invisiblesDefaultReset.20260702") private var didResetInvisiblesDefault = false
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
            expirePendingRegeneratePreviewIfNeeded(for: newValue)
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
        .onAppear {
            resetInvisiblesDefaultIfNeeded()
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
                hasPendingPreview: canApplyPendingRegeneratePreview,
                hasVaultContext: package.manifest.dataFeed != nil,
                contextItems: regenerateContextItems,
                canRestorePreviousSurface: restoreSnapshotName != nil,
                restoreSnapshotName: restoreSnapshotName,
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
                onRequestContextShortcut: refreshPreviewContextShortcut,
                onFocusContextItem: focusRegenerateContextItem,
                onRunPreset: runRegeneratePreset,
                onSubmit: beginRegenerateSurface,
                onApplyPreview: applyPendingRegeneratePreview,
                onPreviewStream: previewRegenerateStreamText,
                onApplyStream: applyRegenerateStreamText,
                onRestorePreview: restorePreviewAfterRegenerate,
                onRestorePreviousSurface: restorePreviousSurface
            )
            .frame(width: 680, height: 560)
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
            .labelStyle(.titleAndIcon)
            .help("Save")

            Button {
                openRegenerateSheet()
            } label: {
                Label("Regenerate", systemImage: isRegenerating ? "hourglass" : "wand.and.sparkles")
            }
            .labelStyle(.titleAndIcon)
            .disabled(isRegenerating)
            .help("Regenerate surface")

            Menu {
                Section("Surface") {
                    Button("Restore Previous Surface", systemImage: "arrow.uturn.backward.circle", action: restorePreviousSurface)
                        .disabled(restoreSnapshotName == nil || isRegenerating)
                        .help(restorePreviousSurfaceHelpText)
                    Button("Capture Snapshot", systemImage: "camera.viewfinder") {
                        captureSnapshot()
                    }
                }
                Section("Files") {
                    Button("Import HTML", systemImage: "tray.and.arrow.down") {
                        importHTML()
                    }
                    Button("Export HTML", systemImage: "square.and.arrow.up") {
                        exportHTML()
                    }
                    Button("Export Site Folder", systemImage: "folder") {
                        exportSiteFolder()
                    }
                    Button("Export PDF", systemImage: isExportingPDF ? "hourglass" : "doc.richtext") {
                        exportPDF()
                    }
                    .disabled(isExportingPDF)
                }
                Section("Package") {
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
                }
                Section("Runtime") {
                    Button(
                        package.manifest.sandboxPolicy.allowAppBridge ? "Disable App Bridge" : "Enable App Bridge",
                        systemImage: package.manifest.sandboxPolicy.allowAppBridge
                            ? "point.3.connected.trianglepath.dotted"
                            : "point.3.filled.connected.trianglepath.dotted"
                    ) {
                        self.setAppBridgeEnabled(!package.manifest.sandboxPolicy.allowAppBridge)
                    }
                    Button(
                        package.manifest.sandboxPolicy.allowPythonRuntime ? "Disable Python Runtime" : "Enable Python Runtime",
                        systemImage: "chevron.left.forwardslash.chevron.right"
                    ) {
                        self.setPythonRuntimeEnabled(!package.manifest.sandboxPolicy.allowPythonRuntime)
                    }
                    Button("Test Runtime Bridges", systemImage: "stethoscope", action: testRuntimeBridgeProbes)
                        .disabled(isRegenerating)
                    Button("Test App Bridge", systemImage: "point.3.connected.trianglepath", action: testAppBridge)
                        .disabled(!package.manifest.sandboxPolicy.allowAppBridge || isRegenerating)
                    Button("Insert App Bridge Demo", systemImage: "point.3.connected.trianglepath", action: insertAppBridgeDemo)
                        .disabled(isRegenerating)
                    Button("Test Console Capture", systemImage: "terminal", action: testConsoleCapture)
                        .disabled(isRegenerating)
                    Button("Test Python Runtime", systemImage: "chevron.left.forwardslash.chevron.right", action: testPythonRuntime)
                        .disabled(!package.manifest.sandboxPolicy.allowPythonRuntime || isRegenerating)
                    Button("Insert Python Demo", systemImage: "chevron.left.forwardslash.chevron.right", action: insertPythonDemo)
                        .disabled(isRegenerating)
                }
            } label: {
                Label("Tools", systemImage: "slider.horizontal.3")
            }
            .labelStyle(.titleAndIcon)
            .help("Workspace tools")

            Button {
                consoleExpanded.toggle()
            } label: {
                Label("Console", systemImage: consoleExpanded ? "terminal.fill" : "terminal")
            }
            .labelStyle(.titleAndIcon)
            .help("Console")

            Button {
                inspectorVisible.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .labelStyle(.titleAndIcon)
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
                ZStack(alignment: .topTrailing) {
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
                            statusText = "Selected \(boundedInspectorSelectorStatus(inspection.selector))"
                        },
                        appBridgeProbeNonce: appBridgeProbeNonce,
                        consoleProbeNonce: consoleProbeNonce,
                        pythonProbeNonce: pythonProbeNonce
                    )
                    .id(previewRenderIdentity)
                    .frame(minWidth: 360)
                }
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

    private var selectedPaneSubtitle: String {
        selectedPane.subtitle(for: package, domSnapshot: domSnapshot)
    }

    private var selectedPaneMetricText: String {
        selectedPane.metricText(for: package, domSnapshot: domSnapshot)
    }

    var sortedRouteNames: [String] {
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

    var domOutlineText: String {
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

    var assetManifestText: String {
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

    var routeManifestText: String {
        guard !package.routes.isEmpty else {
            return "No routes"
        }
        return package.routes
            .sorted { $0.key < $1.key }
            .map { name, html in
                "routes/\(name)  \(HTMLWorkspaceSourcePane.agentTokenEstimateText(for: html))"
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

    var contentHash: String {
        package.currentContentHash
    }

    var previewTheme: HTMLWorkspacePreviewTheme {
        workspaceTheme.isDark ? .dark : .light
    }

    private func resetInvisiblesDefaultIfNeeded() {
        guard !didResetInvisiblesDefault else { return }
        sourceShowInvisibles = false
        didResetInvisiblesDefault = true
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
        clearPendingRegeneratePreview()
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
            stampPackageContentRevision()
        }
        statusText = "Vault feed configured"
        selectedPane = .data
    }

    private func clearVaultSearchFeed() {
        clearPendingRegeneratePreview()
        package.manifest.dataFeed = nil
        package.dataJSON = HTMLWorkspaceDataFeedStatus.clearedDataJSON(from: package.dataJSON)
        stampPackageContentRevision()
        statusText = "Vault feed cleared"
        selectedPane = .data
    }

    func stampPackageContentRevision() {
        package.manifest.updatedAt = Int64(Date().timeIntervalSince1970 * 1_000)
        package.manifest.contentHash = package.currentContentHash
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

    private func schedulePreviewUpdate(_ newPackage: HTMLWorkspacePackage) {
        previewUpdateTask?.cancel()
        previewUpdateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            previewPackage = newPackage
        }
    }
}
