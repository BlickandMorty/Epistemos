import SwiftUI
import SwiftData
#if !EPISTEMOS_FREE_V1
import NaturalLanguage
#endif

private enum HologramInspectorPreviewPolicy {
    static let maxBodyCharacters = 24_000
    static let loadPriority: TaskPriority = .utility

    static func boundedBody(_ body: String) -> String {
        guard body.count > maxBodyCharacters else { return body }
        return String(body.prefix(maxBodyCharacters))
    }
}

// MARK: - HologramNodeInspector
// Right-side floating panel for node details and note previews.
// Native macOS 26 Liquid Glass styling.

struct HologramNodeInspector: View {
    @Environment(UIState.self) private var ui
    @Environment(GraphState.self) private var graphState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.graphSurfacePresentation) private var graphSurfacePresentation
    let inspectorState: NodeInspectorState
    let modelContext: ModelContext

    @State private var editorText = ""
    @State private var editorPreviewFilePath: String?
    @State private var editorPreviewTask: Task<Void, Never>?
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
        .onChange(of: graphState.currentRoute) { _, route in
            guard !route.isCanvas else { return }
            cancelEditorPreview()
        }
        .onDisappear {
            cancelPanelTasks()
            cancelEditorPreview()
        }
    }

    private func syncSelection(from nodeId: String?) {
        if let nodeId, let node = graphState.store.nodes[nodeId] {
            inspectorState.selectNode(node)
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
        AssistantTextTypography.assistantFont(size: size, weight: weight)
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

    private func cancelPanelTasks() {
        panelDismissTask?.cancel()
        panelDismissTask = nil
    }

    private func cancelEditorPreview() {
        editorPreviewTask?.cancel()
        editorPreviewTask = nil
        editorText = ""
        editorPreviewFilePath = nil
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

                // Owner 2026-07-03: explicit "Open Node" affordance — a clear second
                // way to enter/open the selected node (besides double-click).
                Button {
                    graphState.openNode(node.id)
                } label: {
                    Label("Open Node", systemImage: "arrow.up.forward.square")
                        .font(.system(size: 11, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Open this node")
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
        let stats = compactEdgeStats(for: node)

        return VStack(alignment: .leading, spacing: 8) {
            compactFactRow(
                "Connections",
                value: "\(stats.total)",
                detail: stats.flowLabel,
                systemImage: "link"
            )
            compactFactRow(
                "Type",
                value: node.type.displayName,
                detail: stats.resonanceLabel,
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
        return nil
    }

    private func compactDate(_ date: Date) -> String {
        guard date != .distantPast else { return "-" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var modePicker: some View {
        Picker("", selection: Bindable(inspectorState).inspectorMode) {
            Text("Overview").tag(NodeInspectorState.InspectorMode.overview)
            Text("Preview").tag(NodeInspectorState.InspectorMode.editor)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func noteEditorBody(pageId: String) -> some View {
        return VStack(spacing: 0) {
            if let lang = detectedCodeLanguage(filePath: editorPreviewFilePath) {
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
            loadEditorPreview(pageId: pageId)
        }
        .onChange(of: pageId) { _, newId in
            loadEditorPreview(pageId: newId)
        }
    }

    private func loadEditorPreview(pageId: String) {
        editorPreviewTask?.cancel()
        guard graphState.currentRoute.isCanvas else {
            cancelEditorPreview()
            return
        }
        editorPreviewTask = Task(priority: HologramInspectorPreviewPolicy.loadPriority) { @MainActor in
            await Task.yield()
            guard !Task.isCancelled,
                  graphState.currentRoute.isCanvas else {
                return
            }
            let loaded = await loadEditorPreviewSnapshot(pageId: pageId)
            guard !Task.isCancelled,
                  graphState.currentRoute.isCanvas else {
                return
            }
            editorPreviewFilePath = loaded.filePath
            editorText = loaded.body
        }
    }

    private struct EditorPreviewSnapshot: Sendable {
        let filePath: String?
        let body: String
    }

    private func loadEditorPreviewSnapshot(pageId: String) async -> EditorPreviewSnapshot {
        let predicate = #Predicate<SDPage> { $0.id == pageId }
        var desc = FetchDescriptor(predicate: predicate)
        desc.fetchLimit = 1

        do {
            guard let page = try modelContext.fetch(desc).first else {
                return EditorPreviewSnapshot(filePath: nil, body: "")
            }
            let filePath = page.filePath
            if let liveBody = NoteWindowManager.shared.editorBody(for: pageId) {
                return EditorPreviewSnapshot(
                    filePath: filePath,
                    body: HologramInspectorPreviewPolicy.boundedBody(liveBody)
                )
            }
            let inlineBody = page.body
            let body = await Task.detached(priority: HologramInspectorPreviewPolicy.loadPriority) {
                await SDPage.loadBodyAsyncFromPrimitives(
                    pageId: pageId,
                    filePath: filePath,
                    inlineBody: inlineBody,
                    mapped: false,
                    fast: true
                )
            }.value
            return EditorPreviewSnapshot(
                filePath: filePath,
                body: HologramInspectorPreviewPolicy.boundedBody(body)
            )
        } catch {
            Log.notes.error(
                "HologramNodeInspector: failed to fetch page metadata for \(String(pageId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return EditorPreviewSnapshot(filePath: nil, body: "")
        }
    }

    /// Detect code language for a page by looking up its file path.
    private func detectedCodeLanguage(filePath: String?) -> String? {
        guard let path = filePath else { return nil }
        return CodeLanguage.detect(from: path)
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

    private func nodeAge(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        guard interval.isFinite else { return "?" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 2_592_000 { return "\(Int(interval / 86400))d" }
        return "\(Int(interval / 2_592_000))mo"
    }

}
