# Accordion Inspector Panel — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the fixed-height stacked inspector layout with a true accordion where one section expands at a time, eliminating all sizing/clipping issues.

**Architecture:** Single `@State expandedSection` enum drives which section body is visible. Collapsed sections show a compact header row with preview text. The expanded section fills all remaining vertical space via a flexible frame.

**Tech Stack:** SwiftUI (macOS 26), `.glassEffect()`, Swift Testing

---

### Task 1: Remove maxHeight from RelationshipBrowser

**Files:**
- Modify: `Epistemos/Views/Graph/RelationshipBrowser.swift:55`

**Step 1: Remove the height cap**

In `RelationshipBrowser.swift` line 55, delete `.frame(maxHeight: 220)`. The parent (accordion) will control height.

Replace:
```swift
                .frame(maxHeight: 220)
```
With: (delete line entirely)

**Step 2: Build to verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Epistemos/Views/Graph/RelationshipBrowser.swift
git commit -m "Remove hardcoded maxHeight from RelationshipBrowser

Accordion parent will control available height instead of internal cap."
```

---

### Task 2: Rewrite HologramNodeInspector as accordion

**Files:**
- Modify: `Epistemos/Views/Graph/HologramNodeInspector.swift` (full rewrite)

**Step 1: Replace the entire file**

Write this complete implementation:

```swift
import SwiftUI
import SwiftData

// MARK: - HologramNodeInspector
// Right-side floating panel: node details, AI summary, chat.
// True accordion layout — one section expanded at a time.
// Native macOS 26 Liquid Glass styling.

struct HologramNodeInspector: View {
    @Environment(GraphState.self) private var graphState
    let inspectorState: NodeInspectorState
    let modelContext: ModelContext

    enum Section: CaseIterable { case summary, relationships, chat }
    @State private var expandedSection: Section = .summary

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
                expandedSection = .summary
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
        // Each section: tappable header + conditionally shown body.
        // Expanded section body gets all remaining space.
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

                if section == .chat && expandedSection != .chat {
                    Picker("", selection: Bindable(inspectorState).chatScope) {
                        ForEach(NodeInspectorState.ChatScope.allCases, id: \.self) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
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
                    Text(inspectorState.summaryText)
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
            // Scope picker (when chat is expanded, show it inline here)
            HStack(alignment: .center) {
                Spacer()
                Picker("", selection: Bindable(inspectorState).chatScope) {
                    ForEach(NodeInspectorState.ChatScope.allCases, id: \.self) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Messages — fills available space
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

            // Input — pinned at bottom, always visible
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
```

**Step 2: Build to verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Epistemos/Views/Graph/HologramNodeInspector.swift
git commit -m "Rewrite inspector as true accordion layout

One section expanded at a time — summary, relationships, or chat.
Expanded section fills all available space. No more height caps.
Fixes summary truncation and chat input clipping in mini mode.
Defaults to summary-first on node selection."
```

---

### Task 3: Manual verification

**Step 1: Launch and test full-screen overlay**

Run the app. Open the knowledge graph (Cmd+G). Click a node.
Verify:
- Inspector appears with Summary expanded by default
- Summary text flows without truncation
- Click Relationships header → Summary collapses, Relationships expands with full height
- Click Chat header → Relationships collapses, Chat expands with input field visible at bottom
- Scope picker visible in Chat header when collapsed, inline when expanded
- Glass effect unchanged

**Step 2: Test mini mode**

Minimize the graph to mini panel. Click a node.
Verify:
- Inspector fades in (lazy from Issue 2 fix)
- All three sections work in accordion mode within 620px
- Chat input never clips off the bottom
- Summary has ~450px available when expanded

**Step 3: Test node switching**

While inspector is open with Chat expanded, click a different node.
Verify:
- Accordion resets to Summary expanded
- New node's data loads correctly
- Previous chat messages clear (per NodeInspectorState behavior)
