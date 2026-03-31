import SwiftUI

// MARK: - Skill Store

struct SkillStoreView: View {
    @Environment(OrchestratorState.self) private var orchestrator
    var adminViewModel: HermesAdminViewModel?

    @State private var searchQuery = ""
    @State private var selectedCategory: SkillCategory = .all
    @State private var selectedSkill: SkillDisplayItem?

    private var allSkills: [SkillDisplayItem] {
        var items: [SkillDisplayItem] = []

        // Native Omega tools from Rust catalog
        for tool in OmegaToolRegistry.all {
            items.append(SkillDisplayItem(
                name: tool.name,
                description: tool.description,
                agent: tool.agent,
                category: SkillCategory.from(agent: tool.agent),
                source: .native,
                enabled: true,
                destructive: tool.destructive,
                requiresConfirmation: tool.requiresConfirmation,
                schemaJson: tool.schemaJson,
                argumentsExample: tool.argumentsExample
            ))
        }

        // Hermes skills from admin view model
        if let admin = adminViewModel {
            for skill in admin.installedSkills {
                items.append(SkillDisplayItem(
                    name: skill.name,
                    description: skill.description,
                    agent: "hermes",
                    category: .custom,
                    source: .hermes,
                    enabled: skill.enabled,
                    destructive: false,
                    requiresConfirmation: false,
                    schemaJson: nil,
                    argumentsExample: nil
                ))
            }
        }

        return items
    }

    private var filteredSkills: [SkillDisplayItem] {
        var result = allSkills

        if selectedCategory != .all {
            result = result.filter { $0.category == selectedCategory }
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query)
                    || $0.description.lowercased().contains(query)
                    || $0.agent.lowercased().contains(query)
            }
        }

        return result
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
            SkillDetailSheet(skill: skill)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(.blue)
                Text("Skills")
                    .font(.title2.bold())
                Spacer()
                Text("\(filteredSkills.count) skills")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search skills...", text: $searchQuery)
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
                ForEach(SkillCategory.allCases, id: \.self) { category in
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

    // MARK: - Skill List

    private var skillList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(filteredSkills) { skill in
                    SkillRow(skill: skill)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSkill = skill
                        }
                }

                if filteredSkills.isEmpty {
                    ContentUnavailableView {
                        Label("No Skills Found", systemImage: "wrench.and.screwdriver")
                    } description: {
                        Text("Try adjusting your search or category filter.")
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}

// MARK: - Skill Row

private struct SkillRow: View {
    let skill: SkillDisplayItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: skill.category.icon)
                .font(.title3)
                .foregroundStyle(skill.category.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(skill.name)
                        .font(.body.weight(.medium))
                    if skill.destructive {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if skill.source == .hermes {
                        Text("Hermes")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.purple.opacity(0.15), in: Capsule())
                            .foregroundStyle(.purple)
                    }
                }
                Text(skill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Circle()
                .fill(skill.enabled ? .green : .gray.opacity(0.3))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.background, in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Skill Detail Sheet

private struct SkillDetailSheet: View {
    let skill: SkillDisplayItem
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
                    Text(skill.agent.capitalized + " Agent")
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

            if skill.destructive {
                Label("This skill can modify or delete data", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if skill.requiresConfirmation {
                Label("Requires user confirmation before execution", systemImage: "shield.checkered")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            if let schema = skill.schemaJson, !schema.isEmpty, schema != "{}" {
                GroupBox("Input Schema") {
                    ScrollView {
                        Text(schema)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 150)
                }
            }

            if let example = skill.argumentsExample, !example.isEmpty, example != "{}" {
                GroupBox("Example Arguments") {
                    Text(example)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - Types

struct SkillDisplayItem: Identifiable {
    var id: String { "\(source.rawValue):\(name)" }
    let name: String
    let description: String
    let agent: String
    let category: SkillCategory
    let source: SkillSource
    let enabled: Bool
    let destructive: Bool
    let requiresConfirmation: Bool
    let schemaJson: String?
    let argumentsExample: String?
}

enum SkillSource: String {
    case native
    case hermes
}

enum SkillCategory: String, CaseIterable {
    case all
    case safari
    case file
    case notes
    case terminal
    case automation
    case custom

    var label: String {
        switch self {
        case .all: "All"
        case .safari: "Safari"
        case .file: "File"
        case .notes: "Notes"
        case .terminal: "Terminal"
        case .automation: "Automation"
        case .custom: "Custom"
        }
    }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .safari: "safari"
        case .file: "doc"
        case .notes: "note.text"
        case .terminal: "terminal"
        case .automation: "gearshape.2"
        case .custom: "puzzlepiece"
        }
    }

    var color: Color {
        switch self {
        case .all: .primary
        case .safari: .blue
        case .file: .orange
        case .notes: .green
        case .terminal: .purple
        case .automation: .red
        case .custom: .teal
        }
    }

    static func from(agent: String) -> SkillCategory {
        switch agent.lowercased() {
        case "safari": .safari
        case "file": .file
        case "notes": .notes
        case "terminal": .terminal
        case "automation": .automation
        default: .custom
        }
    }
}
