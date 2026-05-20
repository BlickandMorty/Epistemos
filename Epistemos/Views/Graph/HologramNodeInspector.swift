import SwiftUI
import SwiftData
import NaturalLanguage

// MARK: - HologramNodeInspector
// Right-side floating panel: node details and AI summary.
// True accordion layout — one section expanded at a time.
// Native macOS 26 Liquid Glass styling.

struct HologramNodeInspector: View {
    @Environment(UIState.self) private var ui
    @Environment(GraphState.self) private var graphState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let inspectorState: NodeInspectorState
    let modelContext: ModelContext

    enum Section: CaseIterable { case profile, summary, relationships }
    enum EditorDisplay: String, CaseIterable {
        case raw
        case formatted

        var label: String {
            switch self {
            case .raw: "Edit"
            case .formatted: "Preview"
            }
        }
    }
    @State private var expandedSection: Section = .profile
    @State private var editorText = ""
    @State private var lastPersistedBody = ""
    @State private var editorSaveTask: Task<Void, Never>?
    @State private var isEditorExpanded = false
    @State private var editorDisplay: EditorDisplay = .raw
    @State private var editorDisplayTrigger = 0

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        // Read selectedNodeId in body to establish @Observable tracking in NSHostingView.
        let currentId = graphState.selectedNodeId
        Group {
            if let node = inspectorState.selectedNode {
                inspectorContent(node)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onAppear {
            syncSelection(from: currentId)
        }
        .onChange(of: currentId) { _, newId in
            syncSelection(from: newId)
        }
    }

    private func syncSelection(from nodeId: String?) {
        if let nodeId, let node = graphState.store.nodes[nodeId] {
            let previousSelection = inspectorState.selectedNodeId
            inspectorState.selectNode(node, store: graphState.store, modelContext: modelContext)
            if previousSelection != nodeId {
                expandedSection = .profile
                isEditorExpanded = false
            }
            if graphState.requestEditorMode {
                graphState.requestEditorMode = false
                inspectorState.inspectorMode = .editor
            }
        } else {
            inspectorState.clearSelection()
            isEditorExpanded = false
        }
    }

    // MARK: - Content

    private var inspectorWidth: CGFloat {
        inspectorState.inspectorMode == .editor ? 620 : 380
    }

    private func inspectorContent(_ node: GraphNodeRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection(node)

            Divider()

            // 2026-05-19: removed the Profile/Editor segmented picker and the
            // Editor branch (with its Edit/Preview sub-toggle) per user
            // direction — simplifies the inspector to a single Profile +
            // accordion view. Open the note in the main editor to edit.
            accordionBody(node)
        }
        .frame(width: inspectorWidth)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: inspectorWidth)
        .unifiedFrostedGlass(theme: theme, in: RoundedRectangle(cornerRadius: 14, style: .continuous), interactive: true)
        .onChange(of: expandedSection) { _, newSection in
            guard newSection == .summary else { return }
            inspectorState.ensureSummary(for: node, store: graphState.store, modelContext: modelContext)
        }
    }

    private var modePicker: some View {
        Picker("", selection: Bindable(inspectorState).inspectorMode) {
            Text("Profile").tag(NodeInspectorState.InspectorMode.profile)
            Text("Editor").tag(NodeInspectorState.InspectorMode.editor)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onChange(of: inspectorState.inspectorMode) { _, newMode in
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
                isEditorExpanded = (newMode == .editor)
            }
        }
    }

    private func noteEditorBody(pageId: String) -> some View {
        let isCode = isCodeFile(pageId: pageId)
        
        return VStack(spacing: 0) {
            // Toolbar - only show toggle for prose files, not code files
            if !isCode {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(EditorDisplay.allCases, id: \.self) { display in
                            Button {
                                guard editorDisplay != display else { return }
                                editorDisplay = display
                                editorDisplayTrigger += 1
                            } label: {
                                ASCIIRippleText(
                                    text: display.label,
                                    font: .system(size: 12, weight: .semibold),
                                    color: editorDisplay == display ? .primary : .secondary,
                                    manualTrigger: editorDisplay == display ? editorDisplayTrigger : 0
                                )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(editorDisplay == display ? Color.primary.opacity(0.12) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .frame(width: 164)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().opacity(0.3)
            }

            // Editor content
            if let lang = detectedCodeLanguage(pageId: pageId) {
                // Code file: Only show Preview, no Edit mode
                CodeInspectorPreview(content: editorText, language: lang, theme: theme)
            } else {
                // Prose file: original editor
                if editorDisplay == .raw {
                    TextEditor(text: $editorText)
                        .font(.system(size: 14))
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .padding(16)
                } else {
                    ScrollView {
                        formattedMarkdownView(editorText)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .frame(minHeight: inspectorState.inspectorMode == .editor ? 500 : 300)
        .onAppear {
            Task { @MainActor in
                let body = currentBody(for: pageId)
                editorText = body
                lastPersistedBody = body
            }
        }
        .onChange(of: pageId) { oldId, newId in
            Task { @MainActor in
                // Flush old note BEFORE loading new one — prevents data loss
                flushEditorIfNeeded(pageId: oldId)
                let body = currentBody(for: newId)
                editorText = body
                lastPersistedBody = body
            }
        }
        .onChange(of: editorText) {
            guard editorText != lastPersistedBody else { return }
            debouncedEditorSave(pageId: pageId, text: editorText)
        }
        .onDisappear {
            flushEditorIfNeeded(pageId: pageId)
        }
    }

    private func currentBody(for pageId: String) -> String {
        NoteWindowManager.shared.currentBody(for: pageId)
    }

    private func pageFilePath(for pageId: String) -> String? {
        let predicate = #Predicate<SDPage> { $0.id == pageId }
        var desc = FetchDescriptor(predicate: predicate)
        desc.fetchLimit = 1

        do {
            return try modelContext.fetch(desc).first?.filePath
        } catch {
            Log.notes.error(
                "HologramNodeInspector: failed to fetch page metadata for \(String(pageId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    /// Detect code language for a page by looking up its file path.
    private func detectedCodeLanguage(pageId: String) -> String? {
        guard let path = pageFilePath(for: pageId) else { return nil }
        return CodeLanguage.detect(from: path)
    }
    
    /// Checks if the page is a code file (not .txt or .md)
    private func isCodeFile(pageId: String) -> Bool {
        guard let path = pageFilePath(for: pageId) else { return false }
        
        let ext = (path as NSString).pathExtension.lowercased()
        // Code files are those that CodeLanguage detects AND are not .txt or .md
        if ext == "txt" || ext == "md" || ext == "markdown" {
            return false
        }
        return CodeLanguage.detect(from: path) != nil
    }

    // MARK: - Editor Save Pipeline
    // Mirrors ProseEditorView: file write → dirty flag → modelContext.save().

    private func flushEditorIfNeeded(pageId: String) {
        editorSaveTask?.cancel()
        editorSaveTask = nil
        guard lastPersistedBody != editorText else { return }
        _ = NoteFileStorage.scheduleWriteBody(pageId: pageId, content: editorText)
        lastPersistedBody = editorText
        markPageDirty(pageId: pageId, body: editorText)
        NoteFileStorage.notifyBodyChanged(pageId: pageId)
    }

    private func debouncedEditorSave(pageId: String, text: String) {
        editorSaveTask?.cancel()
        editorSaveTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch is CancellationError {
                return
            } catch {
                Log.notes.error(
                    "HologramNodeInspector: editor debounce failed for \(String(pageId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                return
            }
            guard !Task.isCancelled else { return }
            guard text != lastPersistedBody else { return }
            guard await NoteFileStorage.writeBodyAsync(pageId: pageId, content: text) else {
                Log.notes.error(
                    "HologramNodeInspector: failed to persist body for \(String(pageId.prefix(8)), privacy: .public)"
                )
                return
            }
            lastPersistedBody = text
            markPageDirty(pageId: pageId, body: text)
            NoteFileStorage.notifyBodyChanged(pageId: pageId)
        }
    }

    private func markPageDirty(pageId: String, body: String) {
        let desc = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == pageId }
        )
        let page: SDPage
        do {
            guard let fetchedPage = try modelContext.fetch(desc).first else {
                Log.notes.warning(
                    "HologramNodeInspector: no page found while marking dirty for \(String(pageId.prefix(8)), privacy: .public)"
                )
                return
            }
            page = fetchedPage
        } catch {
            Log.notes.error(
                "HologramNodeInspector: failed to fetch page \(String(pageId.prefix(8)), privacy: .public) for dirty mark: \(error.localizedDescription, privacy: .public)"
            )
            return
        }

        page.applyInteractiveDerivedState(from: body)
        page.needsVaultSync = true
        do {
            try modelContext.save()
            if let modelContainer = AppBootstrap.shared?.modelContainer {
                Task {
                    await BlockMirrorSyncCoordinator.shared.scheduleSync(
                        pageId: pageId,
                        body: body,
                        modelContainer: modelContainer
                    )
                }
            }
            AppBootstrap.shared?.graphState.needsRefresh = true
        } catch {
            Log.notes.error(
                "HologramNodeInspector: failed to save dirty page \(String(pageId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    @ViewBuilder
    private func formattedMarkdownView(_ text: String) -> some View {
        let lines = text.components(separatedBy: "\n")
        LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                formattedLine(line)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func formattedLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#### ") {
            previewMarkdownText(
                markdown: String(trimmed.dropFirst(5)),
                font: .system(size: 14, weight: .semibold),
                color: .primary,
                rippleEnabled: false
            )
                .padding(.top, 4)
        } else if trimmed.hasPrefix("### ") {
            previewHeadingText(
                text: String(trimmed.dropFirst(4)),
                role: .h3
            )
                .padding(.top, 6)
        } else if trimmed.hasPrefix("## ") {
            previewHeadingText(
                text: String(trimmed.dropFirst(3)),
                role: .h2
            )
                .padding(.top, 8)
        } else if trimmed.hasPrefix("# ") {
            previewHeadingText(
                text: String(trimmed.dropFirst(2)),
                role: .h1
            )
                .padding(.top, 10)
        } else if trimmed.hasPrefix("- [ ] ") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "square")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                previewMarkdownText(
                    markdown: String(trimmed.dropFirst(6)),
                    font: .system(size: 13),
                    color: .primary,
                    rippleEnabled: false
                )
            }
        } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                previewMarkdownText(
                    markdown: String(trimmed.dropFirst(6)),
                    font: .system(size: 13),
                    color: .primary,
                    rippleEnabled: false
                )
                    .strikethrough(true, color: .secondary)
            }
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                previewMarkdownText(
                    markdown: String(trimmed.dropFirst(2)),
                    font: .system(size: 13),
                    color: .primary,
                    rippleEnabled: false
                )
            }
        } else if let match = trimmed.wholeMatch(of: /^(\d+)\.\s+(.+)$/) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(match.1).")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .trailing)
                previewMarkdownText(
                    markdown: String(match.2),
                    font: .system(size: 13),
                    color: .primary,
                    rippleEnabled: false
                )
            }
        } else if trimmed.hasPrefix("> ") {
            previewMarkdownText(
                markdown: String(trimmed.dropFirst(2)),
                font: .system(size: 13).italic(),
                color: .secondary,
                rippleEnabled: false
            )
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(.tertiary)
                        .frame(width: 3)
                }
        } else if trimmed.hasPrefix("```") {
            Text(trimmed)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            Divider().padding(.vertical, 4)
        } else if trimmed.isEmpty {
            Spacer().frame(height: 4)
        } else {
            previewMarkdownText(
                markdown: trimmed,
                font: .system(size: 13),
                color: .primary,
                rippleEnabled: false
            )
        }
    }

    private func previewMarkdownText(
        markdown: String,
        font: Font,
        color: Color,
        rippleEnabled: Bool = true
    ) -> some View {
        Text(inlineMarkdown(markdown))
            .font(font)
            .foregroundStyle(color)
            .asciiRippleOverlay(
                text: MarkdownRippleTextExtractor.displayText(from: markdown),
                font: font,
                color: color,
                enabled: rippleEnabled
            )
    }

    private func previewHeadingText(
        text: String,
        role: AppHeadingRole
    ) -> some View {
        // 2026-05-13 fifth pass: on Ember, panel preview headings
        // (which are H1-H3 surfaces inside the graph node inspector)
        // get the boxed glyph form via `boxedLabelText(_:)`. The
        // heading font itself is `role.font` (AppHeadingRole goes
        // through the UserDefaults-aware `displayFontName` resolver,
        // so Ember picks up ColorBasic-Regular here). The lowercase
        // transform switches ColorBasic to its boxed glyph variant.
        previewMarkdownText(
            markdown: theme.boxedLabelText(
                MarkdownHeadingDisplay.displayText(text, level: headingLevel(for: role), theme: theme)
            ),
            font: role.font,
            color: MarkdownHeadingDisplay.foregroundColor(for: theme, level: headingLevel(for: role)),
            rippleEnabled: false
        )
    }

    private func headingLevel(for role: AppHeadingRole) -> Int {
        switch role {
        case .h1: 1
        case .h2: 2
        case .h3: 3
        default: 1
        }
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    @ViewBuilder
    private func accordionBody(_ node: GraphNodeRecord) -> some View {
        sectionHeader(.profile, icon: "person.crop.circle", title: "Profile", preview: profilePreview)
        if expandedSection == .profile {
            profileBody
            Divider()
        }

        sectionHeader(.summary, icon: "sparkles", title: "Summary", preview: summaryPreview)
        if expandedSection == .summary {
            summaryBody
            Divider()
        }

        sectionHeader(.relationships, icon: "arrow.triangle.branch", title: "Relationships", preview: relationshipsPreview(node))
        if expandedSection == .relationships {
            RelationshipBrowser(
                nodeId: node.id,
                store: graphState.store,
                onNavigate: { graphState.selectNode($0) }
            )
            Divider()
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ section: Section, icon: String, title: String, preview: String) -> some View {
        // 2026-05-13 fifth pass: on Ember, section titles ("Profile",
        // "Summary", "Relationships") + their truncated preview text
        // route through `theme.boxedLabelText(_:)` which lowercases the
        // string so ColorBasic-Regular renders the white-on-black
        // boxed glyph form. Other themes pass through unchanged.
        let labelTitle = theme.boxedLabelText(title)
        let panelTitleFont = AppDisplayTypography.panelFont(size: 12, weight: .semibold, theme: theme)
        let panelPreviewFont = AppDisplayTypography.panelFont(size: 11, weight: .regular, theme: theme)
        return Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                expandedSection = section
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: expandedSection == section ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)

                Label {
                    Text(labelTitle)
                        .font(panelTitleFont)
                } icon: {
                    Image(systemName: icon)
                }
                .foregroundStyle(.secondary)

                if expandedSection != section && !preview.isEmpty {
                    let previewText = theme.boxedLabelText(preview)
                    Text("— \(previewText)")
                        .font(panelPreviewFont)
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Previews (collapsed state)

    private var summaryPreview: String {
        let text = inspectorState.summaryText
        if text.isEmpty { return inspectorState.isSummarizing ? "Loading…" : "" }
        let firstLine = text.prefix(while: { $0 != "\n" })
        return String(firstLine.prefix(60))
    }

    private func relationshipsPreview(_ node: GraphNodeRecord) -> String {
        let count = graphState.store.adjacency[node.id]?.count ?? 0
        return count > 0 ? "\(count)" : ""
    }

    private var profilePreview: String {
        guard let p = inspectorState.profile else { return "" }
        return "\(p.insight.hierarchyLabel) · \(p.insight.contentLabel)"
    }

    // MARK: - Profile Body

    private var profileBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let p = inspectorState.profile {
                    if !p.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(p.summary)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Node vitals: Age, Drift, Resonance
                    if let node = inspectorState.selectedNode {
                        nodeVitals(node)
                    }

                    // Content info
                    HStack(spacing: 12) {
                        Label(p.insight.contentLabel, systemImage: "doc.text")
                        Label(p.insight.hierarchyLabel, systemImage: "arrow.up.arrow.down")
                        Label(p.insight.tier.displayName, systemImage: "square.stack.3d.up")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                    // Keywords
                    if !p.focusKeywords.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(p.focusKeywords, id: \.self) { kw in
                                Text(kw)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                    }
                } else {
                    Text("No profile available.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Node Vitals (Age, Drift, Resonance)

    private func nodeVitals(_ node: GraphNodeRecord) -> some View {
        let store = graphState.store
        let edgeIds = store.edgesByNode[node.id] ?? []
        let edgeRecords = edgeIds.compactMap { store.edges[$0] }
        let inDegree = edgeRecords.filter { $0.targetNodeId == node.id }.count
        let outDegree = edgeRecords.filter { $0.sourceNodeId == node.id }.count
        let total = max(inDegree + outDegree, 1)
        let resonance = Double(inDegree) / Double(total) // 1.0 = pure sink, 0.0 = pure source

        let drift: Float = {
            guard let engine = graphState.engineHandle else { return 0 }
            return node.id.withCString { graph_engine_node_drift(engine, $0) }
        }()

        return HStack(spacing: 16) {
            // Age
            VStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(nodeAge(node.createdAt))
                    .font(.caption2.monospaced())
            }

            Divider().frame(height: 20)

            // 2026-05-19: removed the "Drift" metric (wind icon + Rust-engine
            // drift value) per user direction — the value was an internal
            // graph-physics debug signal, not user-meaningful. Age + in/out
            // edge ratio remain.

            // Resonance
            VStack(spacing: 2) {
                Image(systemName: resonance > 0.6 ? "arrow.down.circle" : resonance < 0.4 ? "arrow.up.circle" : "arrow.left.arrow.right.circle")
                    .font(.caption)
                    .foregroundStyle(resonance > 0.6 ? .purple : resonance < 0.4 ? .green : .secondary)
                Text("\(inDegree)↓ \(outDegree)↑")
                    .font(.caption2.monospaced())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func nodeAge(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        guard interval.isFinite else { return "?" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 2_592_000 { return "\(Int(interval / 86400))d" }
        return "\(Int(interval / 2_592_000))mo"
    }

    private func formatDrift(_ d: Float) -> String {
        if d < 100 { return String(format: "%.0f", d) }
        if d < 10_000 { return String(format: "%.1fk", d / 1000) }
        return String(format: "%.0fk", d / 1000)
    }

    // MARK: - Header

    private func headerSection(_ node: GraphNodeRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 2026-05-19: the NSPanel-level inspector toggle button (the
            // diagonal popout arrows) was being absolute-positioned at the
            // panel's trailing edge, occluding the SwiftUI close button. The
            // close X is now first (left of pin) and the trailing padding
            // reserves the corner for the popout-toggle overlay, so all
            // three controls are visible side-by-side.
            HStack(spacing: 6) {
                Circle()
                    .fill(node.type.swiftUIColor)
                    .frame(width: 8, height: 8)
                Text(node.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                // Close: deselects the node and dismisses the inspector.
                Button {
                    graphState.selectNode(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close inspector")

                // Pin: creates a persistent panel attached to this node
                Button {
                    if let nodeId = graphState.selectedNodeId,
                       let gnode = graphState.store.nodes[nodeId] {
                        let mgr = PinnedInspectorManager.shared
                        _ = mgr.pin(node: gnode, store: graphState.store, modelContext: modelContext)
                    }
                } label: {
                    Image(systemName: "pin")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Pin inspector to this node")
            }
            // Reserve trailing room for the NSPanel-level popout-toggle
            // overlay (the diagonal arrows at content.trailingAnchor - 10).
            .padding(.trailing, 36)

            TypewriterHeading(
                text: MarkdownHeadingDisplay.displayText(node.label, level: 1),
                role: .pageTitle,
                color: theme.fontAccent,
                animateOnAppear: true,
                animationKey: node.id,
                // 2026-05-13 sixth pass: route the selected-node title
                // through `theme.nodeTitleFontName` so Ember picks
                // ChonkyPixels instead of the case-driven ColorBasic
                // box glyphs.
                fontOverride: Font.custom(
                    theme.nodeTitleFontName,
                    size: AppHeadingRole.pageTitle.fontSize
                )
            )
            .lineLimit(3)

            HStack(spacing: 12) {
                let linkCount = graphState.store.adjacency[node.id]?.count ?? 0
                Label("\(linkCount) connections", systemImage: "link")
                if node.createdAt != .distantPast {
                    Label(node.createdAt.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(16)
    }

    // MARK: - Summary Body

    private var summaryBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if inspectorState.summaryText.isEmpty {
                    if inspectorState.isSummarizing {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 40)
                    } else {
                        Text("No summary available.")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                } else {
                    Text(inspectorState.displayedSummary)
                        .font(.callout)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .transaction { $0.animation = nil }
                }

                if inspectorState.isSummarizing && !inspectorState.summaryText.isEmpty {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .padding(16)
        }
    }
}
