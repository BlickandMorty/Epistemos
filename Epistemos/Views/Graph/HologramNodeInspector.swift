import SwiftUI
import SwiftData
import NaturalLanguage

// MARK: - HologramNodeInspector
// Right-side floating panel: node details, AI summary, chat.
// True accordion layout — one section expanded at a time.
// Native macOS 26 Liquid Glass styling.

struct HologramNodeInspector: View {
    @Environment(GraphState.self) private var graphState
    let inspectorState: NodeInspectorState
    let modelContext: ModelContext

    enum Section: CaseIterable { case profile, summary, relationships, chat }
    @State private var expandedSection: Section = .profile

    var body: some View {
        // Read selectedNodeId in body to establish @Observable tracking in NSHostingView.
        let currentId = graphState.selectedNodeId
        Group {
            if let node = inspectorState.selectedNode {
                inspectorContent(node)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.3), value: inspectorState.selectedNode != nil)
        .onChange(of: currentId) { _, newId in
            if let newId, let node = graphState.store.nodes[newId] {
                inspectorState.selectNode(node, store: graphState.store, modelContext: modelContext)
                expandedSection = .profile
            } else {
                inspectorState.clearSelection()
            }
        }
    }

    // MARK: - Content

    private func inspectorContent(_ node: GraphNodeRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection(node)
            Divider()
            accordionBody(node)
        }
        .frame(width: 380)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

        sectionHeader(.chat, icon: "bubble.left.and.bubble.right", title: "Chat", preview: chatPreview)
        if expandedSection == .chat {
            chatBody
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ section: Section, icon: String, title: String, preview: String) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) {
                expandedSection = section
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: expandedSection == section ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)

                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if expandedSection != section && !preview.isEmpty {
                    Text("— \(preview)")
                        .font(.caption)
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

    private var chatPreview: String {
        let count = inspectorState.chatMessages.count
        return count > 0 ? "\(count)" : ""
    }

    private var profilePreview: String {
        guard let p = inspectorState.profile else { return "" }
        return "\(p.archetype.title) · \(p.care.mood.displayName)"
    }

    // MARK: - Profile Body

    private var profileBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let p = inspectorState.profile {
                    // Archetype + Mood row
                    HStack(spacing: 8) {
                        Image(systemName: p.portrait.symbol)
                            .font(.title3)
                            .foregroundStyle(p.care.mood == .thriving ? .green : p.care.mood == .fragile ? .red : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.archetype.title)
                                .font(.callout.bold())
                            Text(p.care.mood.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(p.insight.tier.displayName)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }

                    // Stats meters
                    VStack(spacing: 6) {
                        statMeter(label: "Health", value: p.care.health, color: .green)
                        statMeter(label: "Focus", value: p.care.attention, color: .blue)
                        statMeter(label: "Mass", value: p.insight.prominence, color: .orange)
                    }

                    // Content info
                    HStack(spacing: 12) {
                        Label(p.insight.contentLabel, systemImage: "doc.text")
                        Label(p.insight.hierarchyLabel, systemImage: "arrow.up.arrow.down")
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

    private func statMeter(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.7))
                        .frame(width: geo.size.width * max(0, min(1, value)))
                }
            }
            .frame(height: 6)
            Text("\(Int(value * 100))%")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Header

    private func headerSection(_ node: GraphNodeRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(node.type.swiftUIColor)
                    .frame(width: 8, height: 8)
                Text(node.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    graphState.selectNode(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            Text(node.label)
                .font(.headline)
                .lineLimit(2)

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

    // MARK: - Chat Body

    private var chatBody: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        if inspectorState.chatMessages.isEmpty {
                            Text("Ask a question about this node…")
                                .font(.caption)
                                .foregroundStyle(.quaternary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        ForEach(inspectorState.chatMessages) { msg in
                            chatRow(msg).id(msg.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: inspectorState.chatMessages.count) { _, _ in
                    if let last = inspectorState.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("Ask…", text: Bindable(inspectorState).chatInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .onSubmit {
                        inspectorState.sendMessage(store: graphState.store, modelContext: modelContext)
                    }

                Button {
                    inspectorState.sendMessage(store: graphState.store, modelContext: modelContext)
                } label: {
                    Image(systemName: inspectorState.isChatStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(inspectorState.chatInput.isEmpty ? .tertiary : .primary)
                }
                .buttonStyle(.plain)
                .disabled(inspectorState.chatInput.isEmpty && !inspectorState.isChatStreaming)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Chat Row

    private func chatRow(_ message: InspectorChatMessage) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .assistant && message.text.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 40, minHeight: 20)
                } else {
                    Text(message.text)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                message.role == .user ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }
}
