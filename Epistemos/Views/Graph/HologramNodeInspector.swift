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
    @Environment(\.graphSurfacePresentation) private var graphSurfacePresentation
    let inspectorState: NodeInspectorState
    let modelContext: ModelContext

    enum Section: CaseIterable { case profile, summary, relationships }
    @State private var expandedSection: Section = .profile
    @State private var editorText = ""
    @State private var lastPersistedBody = ""
    @State private var editorSaveTask: Task<Void, Never>?
    @State private var panelIsRevealed = true
    @State private var panelDismissTask: Task<Void, Never>?

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        // Read selectedNodeId in body to establish @Observable tracking in NSHostingView.
        let currentId = graphState.selectedNodeId
        Group {
            if let node = inspectorState.selectedNode {
                inspectorContent(node)
                    .id(node.id)
                    .scaleEffect(panelIsRevealed ? 1.0 : 0.985, anchor: .topLeading)
                    .opacity(panelIsRevealed ? 1.0 : 0.0)
                    .blur(radius: panelIsRevealed ? 0 : 7)
                    .offset(y: panelIsRevealed ? 0 : 4)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: panelIsRevealed)
                    .transition(.opacity)
            }
        }
        .onAppear {
            syncSelection(from: currentId)
            restartPanelReveal()
        }
        .onChange(of: currentId) { _, newId in
            syncSelection(from: newId)
            restartPanelReveal()
        }
        .onDisappear {
            panelDismissTask?.cancel()
            panelDismissTask = nil
        }
    }

    private func syncSelection(from nodeId: String?) {
        if let nodeId, let node = graphState.store.nodes[nodeId] {
            let previousSelection = inspectorState.selectedNodeId
            inspectorState.selectNode(node, store: graphState.store, modelContext: modelContext)
            if previousSelection != nodeId {
                expandedSection = .profile
            }
            if graphState.requestEditorMode {
                graphState.requestEditorMode = false
                inspectorState.inspectorMode = .editor
            }
        } else {
            inspectorState.clearSelection()
        }
    }

    // MARK: - Content

    private var inspectorWidth: CGFloat {
        graphSurfacePresentation.isEmbeddedHome ? 320 : 330
    }

    private var inspectorHeight: CGFloat {
        graphSurfacePresentation.isEmbeddedHome ? 500 : 520
    }

    private var graphInspectorPreviewBottomPadding: CGFloat {
        graphSurfacePresentation.isEmbeddedHome ? 64 : 72
    }

    private var compactNodeTitleFontSize: CGFloat {
        graphSurfacePresentation.isEmbeddedHome ? 20 : 21
    }

    private let graphInspectorPreviewBodyFontSize: CGFloat = 13

    private func graphInspectorPreviewFont(
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        ClaudeAppTypography.assistantFont(size: size, weight: weight)
    }

    private func inspectorContent(_ node: GraphNodeRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            compactHeader(node)
            Divider().opacity(0.35)
            if node.type == .note, node.sourceId != nil {
                modePicker
                Divider().opacity(0.35)
            }
            if node.type == .note, let pageId = node.sourceId,
               inspectorState.inspectorMode == .editor {
                noteEditorBody(pageId: pageId)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        compactVitals(node)
                        compactRelationships(node)
                    }
                }
                .scrollIndicators(.visible)
            }
        }
        .frame(width: inspectorWidth)
        .frame(height: inspectorHeight, alignment: .top)
        .clipped()
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: inspectorWidth)
        .unifiedFrostedGlass(theme: theme, in: RoundedRectangle(cornerRadius: 14, style: .continuous), interactive: true)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(node.type.swiftUIColor)
                .frame(width: 3, height: 46)
                .offset(x: -1)
        }
    }

    private func restartPanelReveal() {
        panelDismissTask?.cancel()
        panelDismissTask = nil
        guard !reduceMotion else {
            panelIsRevealed = true
            return
        }
        panelIsRevealed = false
        Task { @MainActor in
            await Task.yield()
            withAnimation(.smooth(duration: 0.18)) {
                panelIsRevealed = true
            }
        }
    }

    private func dismissInspector() {
        panelDismissTask?.cancel()
        guard !reduceMotion else {
            graphState.selectNode(nil)
            return
        }

        withAnimation(.smooth(duration: 0.14)) {
            panelIsRevealed = false
        }
        panelDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(120))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            graphState.selectNode(nil)
        }
    }

    private struct CompactEdgeStats {
        let inbound: Int
        let outbound: Int
        let total: Int

        var flowLabel: String {
            total == 0 ? "Isolated" : "\(inbound) in / \(outbound) out"
        }

        var resonanceLabel: String {
            guard total > 0 else { return "No links" }
            let sinkRatio = Double(inbound) / Double(total)
            if sinkRatio > 0.62 { return "Sink" }
            if sinkRatio < 0.38 { return "Source" }
            return "Balanced"
        }
    }

    private func compactHeader(_ node: GraphNodeRecord) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Button {
                    dismissInspector()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Close inspector")

                Circle()
                    .fill(node.type.swiftUIColor)
                    .frame(width: 8, height: 8)

                Text(node.type.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)
            }

            TypewriterHeading(
                text: MarkdownHeadingDisplay.displayText(node.label, level: 1),
                role: .pageTitle,
                color: theme.fontAccent,
                animateOnAppear: true,
                animationKey: node.id,
                fontOverride: Font.custom(
                    theme.nodeTitleFontName,
                    size: compactNodeTitleFontSize
                )
            )
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let abstract = compactAbstract(for: node), !abstract.isEmpty {
                Text(abstract)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 11)
        .padding(.bottom, 10)
    }

    private func compactVitals(_ node: GraphNodeRecord) -> some View {
        let profile = inspectorState.profile
        let stats = compactEdgeStats(for: node)

        return VStack(alignment: .leading, spacing: 8) {
            compactFactRow(
                "Connections",
                value: "\(stats.total)",
                detail: stats.flowLabel,
                systemImage: "link"
            )
            compactFactRow(
                "Layer",
                value: profile?.insight.hierarchyLabel ?? "Layer -",
                detail: profile?.insight.tier.displayName ?? stats.resonanceLabel,
                systemImage: "square.stack.3d.up"
            )
            compactFactRow(
                "Dates",
                value: compactDate(node.createdAt),
                detail: "Updated \(nodeAge(node.updatedAt))",
                systemImage: "calendar"
            )
        }
        .padding(12)
    }

    private func compactRelationships(_ node: GraphNodeRecord) -> some View {
        let related = compactRelatedNodes(for: node)

        return VStack(alignment: .leading, spacing: 8) {
            Divider().opacity(0.35)

            HStack(spacing: 6) {
                Label("Relationships", systemImage: "arrow.triangle.branch")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(graphState.store.adjacency[node.id]?.count ?? 0)")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            if related.isEmpty {
                Text("No visible connections")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 3)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(related, id: \.id) { relatedNode in
                        Button {
                            graphState.selectNode(relatedNode.id)
                            graphState.pendingCenterNodeId = relatedNode.id
                        } label: {
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(relatedNode.type.swiftUIColor)
                                    .frame(width: 6, height: 6)
                                Text(relatedNode.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.82))
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text(relatedNode.type.displayName)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func compactFactRow(_ label: String, value: String, detail: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 76, alignment: .leading)

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary.opacity(0.84))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }

    private func compactEdgeStats(for node: GraphNodeRecord) -> CompactEdgeStats {
        let store = graphState.store
        let edgeIds = store.edgesByNode[node.id] ?? []
        let edgeRecords = edgeIds.compactMap { store.edges[$0] }
        let inbound = edgeRecords.filter { $0.targetNodeId == node.id }.count
        let outbound = edgeRecords.filter { $0.sourceNodeId == node.id }.count
        return CompactEdgeStats(inbound: inbound, outbound: outbound, total: inbound + outbound)
    }

    private func compactRelatedNodes(for node: GraphNodeRecord) -> [GraphNodeRecord] {
        Array(graphState.store.adjacency[node.id] ?? [])
            .compactMap { graphState.store.nodes[$0] }
            .filter { $0.id != node.id }
            .sorted { lhs, rhs in
                lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
    }

    private func compactAbstract(for node: GraphNodeRecord) -> String? {
        if let abstract = node.metadata.abstract?.trimmingCharacters(in: .whitespacesAndNewlines),
           !abstract.isEmpty {
            return abstract
        }
        if let quote = node.metadata.quoteText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !quote.isEmpty {
            return quote
        }
        return inspectorState.profile?.summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func compactDate(_ date: Date) -> String {
        guard date != .distantPast else { return "-" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var modePicker: some View {
        Picker("", selection: Bindable(inspectorState).inspectorMode) {
            Text("Profile").tag(NodeInspectorState.InspectorMode.profile)
            Text("Preview").tag(NodeInspectorState.InspectorMode.editor)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func noteEditorBody(pageId: String) -> some View {
        return VStack(spacing: 0) {
            if let lang = detectedCodeLanguage(pageId: pageId) {
                CodeInspectorPreview(content: editorText, language: lang, theme: theme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    formattedMarkdownView(editorText)
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                        .padding(.bottom, graphInspectorPreviewBottomPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Spacer().frame(height: 4)
        } else {
            rawMarkdownLineText(line)
        }
    }

    private func rawMarkdownLineText(_ line: String, color: Color = .primary) -> some View {
        Text(verbatim: line)
            .font(graphInspectorPreviewFont(size: graphInspectorPreviewBodyFontSize))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            let newSection = section
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                expandedSection = newSection
            }
            guard newSection == .summary else { return }
            if let node = inspectorState.selectedNode {
                inspectorState.ensureSummary(for: node, store: graphState.store, modelContext: modelContext)
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

    // MARK: - Node Vitals (Age, Resonance)

    private func nodeVitals(_ node: GraphNodeRecord) -> some View {
        let store = graphState.store
        let edgeIds = store.edgesByNode[node.id] ?? []
        let edgeRecords = edgeIds.compactMap { store.edges[$0] }
        let inDegree = edgeRecords.filter { $0.targetNodeId == node.id }.count
        let outDegree = edgeRecords.filter { $0.sourceNodeId == node.id }.count
        let total = max(inDegree + outDegree, 1)
        let resonance = Double(inDegree) / Double(total) // 1.0 = pure sink, 0.0 = pure source

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
