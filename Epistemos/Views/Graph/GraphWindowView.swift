import AppKit
import SwiftData
import SwiftUI

// MARK: - GraphWindowView
// Main graph window layout with sidebar, Metal canvas, filter pills, and timeline scrubber.

struct GraphWindowView: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Environment(LLMService.self) private var llmService
    @Environment(\.modelContext) private var modelContext

    @State private var showSidebar = true
    @State private var showTimeline = true
    @State private var showPhysicsSettings = false
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
                    // Rust Metal canvas — replaces SpriteKit
                    MetalGraphView(graphState: graphState)
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
                    showPhysicsSettings.toggle()
                } label: {
                    Image(systemName: "atom")
                }
                .help("Physics Settings")
                .popover(isPresented: $showPhysicsSettings, arrowEdge: .bottom) {
                    GraphPhysicsSettings()
                }

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
            } else {
                // Always refresh structural data on window reopen (Obsidian-style reset).
                // The MetalGraphView coordinator's hasLoadedData is reset in
                // viewDidMoveToWindow, so the next updateNSView pushes fresh data
                // to the Rust engine → physics restart + fit-all camera.
                graphState.refreshStructuralData(context: modelContext)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
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

    // MARK: - Sidebar: Navigate

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
