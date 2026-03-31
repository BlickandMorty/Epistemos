import SwiftUI

// MARK: - Hermes Skills View

/// Displays skills and tools from the real Hermes agent system.
/// Pulls from two sources:
/// 1. Hermes installed skills (via admin bridge command)
/// 2. Hermes registered tools (via MCP tools/list)
struct HermesSkillsView: View {
    let viewModel: AgentViewModel

    @State private var searchQuery = ""
    @State private var selectedCategory: HermesSkillCategory = .all
    @State private var selectedSkill: HermesSkillItem?
    @State private var hermesTools: [HermesToolItem] = []
    @State private var isLoadingTools = false

    private var allItems: [HermesSkillItem] {
        var items: [HermesSkillItem] = []

        // Hermes registered tools (from MCP tools/list)
        for tool in hermesTools {
            items.append(HermesSkillItem(
                name: tool.name,
                description: tool.description,
                category: HermesSkillCategory.categorize(tool.name),
                source: .tool,
                enabled: true,
                tags: []
            ))
        }

        // Hermes installed skills (from admin bridge)
        if let admin = viewModel.adminViewModel {
            for skill in admin.installedSkills {
                items.append(HermesSkillItem(
                    name: skill.name,
                    description: skill.description,
                    category: .skill,
                    source: .skill,
                    enabled: skill.enabled,
                    tags: skill.tags
                ))
            }
        }

        return items
    }

    private var filteredItems: [HermesSkillItem] {
        var result = allItems

        if selectedCategory != .all {
            result = result.filter { $0.category == selectedCategory }
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query)
                    || $0.description.lowercased().contains(query)
            }
        }

        return result.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            categoryPicker
            Divider()
            skillList
        }
        .sheet(item: $selectedSkill) { skill in
            HermesSkillDetailSheet(skill: skill)
        }
        .task {
            await refreshTools()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(.blue)
                Text("Hermes Skills & Tools")
                    .font(.title2.bold())
                Spacer()
                if isLoadingTools {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("\(filteredItems.count) items")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Button {
                    Task { await refreshTools() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Refresh from Hermes")
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search skills & tools...", text: $searchQuery)
                    .textFieldStyle(.plain)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding()
    }

    // MARK: - Categories

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(HermesSkillCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.label)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                selectedCategory == category ? Color.accentColor.opacity(0.2) : Color.clear,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // MARK: - List

    private var skillList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(filteredItems) { item in
                    HermesSkillRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSkill = item
                        }
                }

                if filteredItems.isEmpty {
                    ContentUnavailableView {
                        Label("No Skills Found", systemImage: "wrench.and.screwdriver")
                    } description: {
                        if hermesTools.isEmpty {
                            Text("Hermes is not connected. Start a session first.")
                        } else {
                            Text("Try adjusting your search or category filter.")
                        }
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: - Data Loading

    private func refreshTools() async {
        isLoadingTools = true
        defer { isLoadingTools = false }

        // Fetch registered Hermes tools via MCP
        if let tools = await viewModel.fetchHermesTools() {
            hermesTools = tools
        }

        // Refresh admin skills list
        viewModel.adminViewModel?.refreshSkills()
    }
}

// MARK: - Skill Row

private struct HermesSkillRow: View {
    let item: HermesSkillItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.category.icon)
                .font(.title3)
                .foregroundStyle(item.category.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                    Text(item.source == .skill ? "Skill" : "Tool")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            (item.source == .skill ? Color.purple : Color.blue).opacity(0.15),
                            in: Capsule()
                        )
                        .foregroundStyle(item.source == .skill ? .purple : .blue)
                }
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Circle()
                .fill(item.enabled ? .green : .gray.opacity(0.3))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.background, in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Detail Sheet

private struct HermesSkillDetailSheet: View {
    let skill: HermesSkillItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: skill.category.icon)
                    .font(.title2)
                    .foregroundStyle(skill.category.color)
                VStack(alignment: .leading) {
                    Text(skill.name)
                        .font(.title3.bold())
                    Text(skill.source == .skill ? "Hermes Skill" : "Hermes Tool")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }

            Divider()

            Text(skill.description)
                .font(.body)

            if !skill.tags.isEmpty {
                HermesSkillFlowLayout(spacing: 4) {
                    ForEach(skill.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 250)
    }
}

// MARK: - Types

struct HermesSkillItem: Identifiable {
    var id: String { "\(source.rawValue):\(name)" }
    let name: String
    let description: String
    let category: HermesSkillCategory
    let source: HermesSkillSource
    let enabled: Bool
    let tags: [String]
}

enum HermesSkillSource: String {
    case tool
    case skill
}

enum HermesSkillCategory: String, CaseIterable {
    case all
    case terminal
    case file
    case web
    case memory
    case agent
    case skill
    case other

    var label: String {
        switch self {
        case .all: "All"
        case .terminal: "Terminal"
        case .file: "File"
        case .web: "Web"
        case .memory: "Memory"
        case .agent: "Agent"
        case .skill: "Skills"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .terminal: "terminal"
        case .file: "doc"
        case .web: "globe"
        case .memory: "brain"
        case .agent: "person.2"
        case .skill: "puzzlepiece"
        case .other: "ellipsis.circle"
        }
    }

    var color: Color {
        switch self {
        case .all: .primary
        case .terminal: .purple
        case .file: .orange
        case .web: .blue
        case .memory: .green
        case .agent: .red
        case .skill: .teal
        case .other: .gray
        }
    }

    /// Categorize a Hermes tool by name prefix.
    static func categorize(_ toolName: String) -> HermesSkillCategory {
        let name = toolName.lowercased()
        if name.contains("terminal") || name.contains("command") || name.contains("shell") { return .terminal }
        if name.contains("file") || name.contains("read") || name.contains("write") || name.contains("patch") { return .file }
        if name.contains("web") || name.contains("search") || name.contains("browser") || name.contains("url") { return .web }
        if name.contains("memory") || name.contains("vault") { return .memory }
        if name.contains("delegate") || name.contains("agent") || name.contains("clarify") { return .agent }
        return .other
    }
}

// MARK: - Flow Layout

/// Simple flow layout for tag chips.
private struct HermesSkillFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return ArrangeResult(size: CGSize(width: maxWidth, height: totalHeight), positions: positions)
    }
}

// MARK: - Tool Item (from MCP)

struct HermesToolItem: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let description: String
}
