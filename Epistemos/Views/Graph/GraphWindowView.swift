import AppKit
import SwiftData
import SwiftUI

// MARK: - GraphWindowView
// Main graph window layout with sidebar, SpriteKit canvas, filter pills, and timeline scrubber.

struct GraphWindowView: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Environment(LLMService.self) private var llmService
    @Environment(\.modelContext) private var modelContext

    @State private var showSidebar = true
    @State private var showTimeline = true
    @State private var sidebarTab: SidebarTab = .info

    private var theme: EpistemosTheme { ui.theme }

    enum SidebarTab: String, CaseIterable, Hashable {
        case ideas = "Ideas"
        case navigate = "Navigate"
        case info = "Info"

        var icon: String {
            switch self {
            case .ideas: "lightbulb"
            case .navigate: "scope"
            case .info: "info.circle"
            }
        }
    }

    // MARK: - Filter key lookup

    /// Maps keyboard characters 1-9 to their corresponding GraphNodeType.
    private static let filterKeyMap: [Character: GraphNodeType] = {
        var map: [Character: GraphNodeType] = [:]
        for nodeType in GraphNodeType.allCases {
            let key = nodeType.filterKey
            if key >= 1, key <= 9 {
                map[Character("\(key)")] = nodeType
            }
        }
        return map
    }()

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                sidebarView
                    .frame(width: 260)
                    .transition(.move(edge: .leading))

                Rectangle()
                    .fill(theme.border)
                    .frame(width: 1)
            }

            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottom) {
                    // SpriteKit canvas — full size
                    GraphSpriteView(
                        graphState: graphState,
                        onNodeRightClicked: { nodeId, screenPoint in
                            showContextMenu(nodeId: nodeId, screenPoint: screenPoint)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Timeline scrubber — bottom overlay
                    if showTimeline {
                        GraphTimelineScrubber()
                            .padding(.horizontal, Spacing.lg)
                            .padding(.bottom, Spacing.md)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // Filter pills — top-right overlay
                GraphFilterPills()
                    .padding(.top, Spacing.md)
                    .padding(.trailing, Spacing.md)
            }
        }
        .onKeyPress(.space) {
            graphState.pendingResetView = true
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "f")) { _ in
            if let nodeId = graphState.selectedNodeId {
                graphState.pendingCenterNodeId = nodeId
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "t")) { _ in
            withAnimation(Motion.quick) {
                showTimeline.toggle()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            graphState.selectNode(nil)
            graphState.clearFocus()
            graphState.filter.clearHidden()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "123456789")) { press in
            guard let ch = press.characters.first else { return .handled }
            if let nodeType = Self.filterKeyMap[ch] {
                withAnimation(Motion.quick) {
                    graphState.filter.toggleType(nodeType)
                }
            }
            return .handled
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(Motion.smooth) {
                        showSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    graphState.pendingResetView = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Reset View")

                Button {
                    graphState.refreshStructuralData(context: modelContext)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh Structural Graph")

                Button {
                    graphState.scanVault(context: modelContext, llmService: llmService)
                } label: {
                    if graphState.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .help("AI Scan Vault — Extract Entities")
                .disabled(graphState.isScanning)
            }
        }
        .onAppear {
            if !graphState.isLoaded {
                graphState.loadGraph(context: modelContext)
            } else if graphState.needsRefresh {
                graphState.refreshStructuralData(context: modelContext)
            }
        }
    }

    // MARK: - Context Menu

    private func showContextMenu(nodeId: String, screenPoint: CGPoint) {
        guard let node = graphState.store.nodes[nodeId] else { return }

        let menu = NSMenu(title: "Node Actions")

        // Show Only Connected
        let showConnected = NSMenuItem(title: "Show Only Connected", action: nil, keyEquivalent: "")
        menu.addItem(showConnected)
        showConnected.representedObject = ContextAction {
            graphState.focusOnNode(nodeId)
        }

        // Open in Editor
        let openItem = NSMenuItem(title: "Open in Editor", action: nil, keyEquivalent: "")
        menu.addItem(openItem)
        if node.type == .note, let sourceId = node.sourceId {
            openItem.representedObject = ContextAction {
                NoteWindowManager.shared.open(pageId: sourceId)
            }
        } else if node.type == .chat {
            openItem.representedObject = ContextAction {
                Log.app.info("Open chat not implemented yet")
            }
        } else if let sourceId = node.sourceId {
            openItem.representedObject = ContextAction {
                NoteWindowManager.shared.open(pageId: sourceId)
            }
        } else {
            openItem.isEnabled = false
        }

        menu.addItem(.separator())

        // Pin to Center
        let pinItem = NSMenuItem(title: "Pin to Center", action: nil, keyEquivalent: "")
        menu.addItem(pinItem)
        pinItem.representedObject = ContextAction {
            if let record = graphState.store.nodes[nodeId] {
                Task { await graphState.simulation.pinNode(nodeId, at: record.position) }
            }
        }

        // Hide This Node
        let hideItem = NSMenuItem(title: "Hide This Node", action: nil, keyEquivalent: "")
        menu.addItem(hideItem)
        hideItem.representedObject = ContextAction {
            graphState.filter.hideNode(nodeId)
        }

        menu.addItem(.separator())

        // Clear Focus
        let clearItem = NSMenuItem(title: "Clear Focus", action: nil, keyEquivalent: "")
        menu.addItem(clearItem)
        clearItem.representedObject = ContextAction {
            graphState.clearFocus()
            graphState.filter.clearHidden()
        }

        // Use ContextMenuDelegate to handle actions
        let delegate = ContextMenuDelegate()
        menu.delegate = delegate

        // Present the menu — attach all items to the delegate for action dispatch
        for item in menu.items where item.representedObject is ContextAction {
            item.target = delegate
            item.action = #selector(ContextMenuDelegate.performAction(_:))
        }

        // Pop up at mouse location in screen coordinates
        // NSMenu.popUp needs a view and local point. Use the key window's content view.
        if let window = NSApp.keyWindow, let contentView = window.contentView {
            let windowPoint = window.convertPoint(fromScreen: screenPoint)
            let localPoint = contentView.convert(windowPoint, from: nil)
            // Retain delegate for duration of menu interaction
            objc_setAssociatedObject(menu, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            menu.popUp(positioning: nil, at: localPoint, in: contentView)
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $sidebarTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            Rectangle()
                .fill(theme.border)
                .frame(height: 0.5)

            // Tab content
            switch sidebarTab {
            case .ideas:
                IdeasPortalView()
            case .navigate:
                navigatePlaceholder
            case .info:
                infoPanel
            }
        }
        .background(theme.sidebarBackground)
    }

    // MARK: - Sidebar: Navigate (placeholder for Task 9)

    private var navigatePlaceholder: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "scope")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text("Navigate")
                .font(.epHeading)
                .foregroundStyle(theme.textSecondary)
            Text("Coming soon — search & browse graph")
                .font(.epCaption)
                .foregroundStyle(theme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sidebar: Info Panel

    private var infoPanel: some View {
        ScrollView {
            if let node = graphState.selectedNode {
                nodeInfoView(node)
            } else {
                emptyInfoView
            }
        }
    }

    private var emptyInfoView: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "hand.tap")
                .font(.system(size: 28))
                .foregroundStyle(theme.textTertiary)
            Text("Select a node")
                .font(.epBody)
                .foregroundStyle(theme.textSecondary)
            Text("Click a node in the graph to see details")
                .font(.epCaption)
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.lg)
    }

    @ViewBuilder
    private func nodeInfoView(_ node: GraphNodeRecord) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: node.type.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(nodeColor(for: node.type))
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(nodeColor(for: node.type).opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.label)
                        .font(.epHeading)
                        .foregroundStyle(theme.foreground)
                        .lineLimit(2)

                    Text(node.type.displayName)
                        .font(.epCaption)
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Rectangle()
                .fill(theme.border)
                .frame(height: 0.5)

            // Metadata fields
            VStack(alignment: .leading, spacing: Spacing.sm) {
                metadataRow("Weight", value: String(format: "%.1f", node.weight))
                metadataRow("Created", value: node.createdAt.formatted(date: .abbreviated, time: .shortened))

                if let sourceId = node.sourceId {
                    metadataRow("Source ID", value: String(sourceId.prefix(12)) + "...")
                }

                if let grade = node.metadata.evidenceGrade {
                    metadataRow("Evidence", value: grade)
                }

                if let url = node.metadata.url {
                    metadataRow("URL", value: url)
                }

                if let authors = node.metadata.authors, !authors.isEmpty {
                    metadataRow("Authors", value: authors.joined(separator: ", "))
                }

                if let year = node.metadata.year {
                    metadataRow("Year", value: "\(year)")
                }
            }

            Rectangle()
                .fill(theme.border)
                .frame(height: 0.5)

            // Connections
            let neighbors = graphState.store.neighbors(of: node.id)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Connections (\(neighbors.count))")
                    .font(.epCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.textSecondary)

                if neighbors.isEmpty {
                    Text("No connections")
                        .font(.epCaption)
                        .foregroundStyle(theme.textTertiary)
                } else {
                    ForEach(neighbors.prefix(20), id: \.id) { neighbor in
                        Button {
                            graphState.selectNode(neighbor.id)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: neighbor.type.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(nodeColor(for: neighbor.type))
                                Text(neighbor.label)
                                    .font(.epCaption)
                                    .foregroundStyle(theme.foreground)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Focus button
            Button {
                graphState.focusOnNode(node.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .font(.system(size: 12))
                    Text("Focus on this node")
                        .font(.epCaption)
                }
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.accent.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.accent.opacity(0.2), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.lg)
    }

    // MARK: - Helpers

    private func metadataRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.epSmall)
                .foregroundStyle(theme.textTertiary)
            Text(value)
                .font(.epCaption)
                .foregroundStyle(theme.foreground)
                .lineLimit(2)
        }
    }

    private func nodeColor(for type: GraphNodeType) -> Color {
        switch type {
        case .note:      return .blue
        case .idea:      return .yellow
        case .brainDump: return .purple
        case .chat:      return .green
        case .insight:   return .teal
        case .thinker:   return .orange
        case .paper:     return .red
        case .book:      return .brown
        case .source:    return .indigo
        case .concept:   return .pink
        case .quote:     return .cyan
        case .tag, .folder: return .gray
        }
    }
}

// MARK: - Context Menu Support

/// Wraps a closure for use as NSMenuItem.representedObject.
private final class ContextAction {
    let action: @MainActor () -> Void
    init(_ action: @escaping @MainActor () -> Void) {
        self.action = action
    }
}

/// NSObject delegate that dispatches NSMenuItem actions by invoking the ContextAction closure.
private final class ContextMenuDelegate: NSObject, NSMenuDelegate {
    @objc func performAction(_ sender: NSMenuItem) {
        guard let contextAction = sender.representedObject as? ContextAction else { return }
        contextAction.action()
    }
}
