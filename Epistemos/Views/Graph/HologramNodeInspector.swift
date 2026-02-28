import SwiftUI
import SwiftData

// MARK: - HologramNodeInspector
// Right-side floating panel: node details, AI summary, chat.
// Native macOS 26 Liquid Glass styling with consistent alignment.

struct HologramNodeInspector: View {
    @Environment(GraphState.self) private var graphState
    let inspectorState: NodeInspectorState
    let modelContext: ModelContext

    var body: some View {
        Group {
            if let node = inspectorState.selectedNode {
                inspectorContent(node)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.3), value: inspectorState.selectedNode != nil)
        .onChange(of: graphState.selectedNodeId) { _, newId in
            if let newId, let node = graphState.store.nodes[newId] {
                inspectorState.selectNode(node, store: graphState.store, modelContext: modelContext)
            } else {
                inspectorState.clearSelection()
            }
        }
    }

    private func inspectorContent(_ node: GraphNodeRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection(node)
            Divider()
            summarySection
            Divider()
            RelationshipBrowser(
                nodeId: node.id,
                store: graphState.store,
                onNavigate: { targetId in
                    graphState.selectNode(targetId)
                }
            )
            Divider()
            chatSection
        }
        .frame(width: 380)
        .frame(maxHeight: 960)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Summary", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if inspectorState.isSummarizing {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

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
                ScrollView {
                    Text(inspectorState.summaryText)
                        .font(.callout)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .transaction { $0.animation = nil } // Prevent layout jumps during streaming
                }
            }
        }
        .padding(16)
        .frame(maxHeight: 180)
    }

    // MARK: - Chat

    private var chatSection: some View {
        VStack(spacing: 0) {
            // Scope picker — consistent 16px padding with rest of panel.
            HStack(alignment: .center) {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: Bindable(inspectorState).chatScope) {
                    ForEach(NodeInspectorState.ChatScope.allCases, id: \.self) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(16)

            Divider()

            // Messages
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
                .frame(minHeight: 120, maxHeight: 560)
                .onChange(of: inspectorState.chatMessages.count) { _, _ in
                    if let last = inspectorState.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // Input — 16px horizontal to match rest of panel.
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
