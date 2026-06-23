// SlashCommandPopover.swift
//
// Native Apple-style slash-command picker that attaches to the main
// chat composer. Mirrors the pre-fuse Agent Command Center's /command
// flow so skills + mode promotion still work in the fused chat surface.
//
// Renders a SwiftUI List with live filtering against ACCSlashCommand —
// feels like the macOS command palette / Spotlight row style users
// already recognize.
//
// 2026-04-18.

import SwiftUI

enum ComposerSlashCommandItem: Identifiable, Hashable {
    case command(ACCSlashCommand)
    case skill(SkillDiscoveryEntry)
    case osaurus(ActOsaurusSlashCommand)

    init(token: ParsedSlashToken) {
        switch token {
        case .builtinMode(let command):
            self = .command(command)
        case .skill(let skill):
            self = .skill(skill)
        }
    }

    var id: String {
        switch self {
        case .command(let command): "command:\(command.rawValue)"
        case .skill(let skill): "skill:\(skill.identifier)"
        case .osaurus(let command): "osaurus:\(command.rawValue)"
        }
    }

    var token: ParsedSlashToken? {
        switch self {
        case .command(let command): .builtinMode(command)
        case .skill(let skill): .skill(skill)
        case .osaurus: nil
        }
    }

    var command: ACCSlashCommand? {
        if case .command(let command) = self {
            return command
        }
        return nil
    }

    var osaurusCommand: ActOsaurusSlashCommand? {
        if case .osaurus(let command) = self {
            return command
        }
        return nil
    }

    var rawValue: String {
        switch self {
        case .command(let command): command.rawValue
        case .skill(let skill): skill.identifier
        case .osaurus(let command): command.rawValue
        }
    }

    var displayName: String {
        switch self {
        case .command(let command): command.displayName
        case .skill(let skill): skill.title
        case .osaurus(let command): command.displayName
        }
    }

    var helpText: String {
        switch self {
        case .command(let command): command.helpText
        case .skill(let skill): skill.description
        case .osaurus(let command): command.helpText
        }
    }

    var icon: String {
        switch self {
        case .command(let command): command.icon
        case .skill: "wand.and.stars"
        case .osaurus(let command): command.icon
        }
    }

    var detailLabel: String {
        switch self {
        case .command(let command): command.defaultOperatingMode.displayName
        case .skill(let skill): skill.category.isEmpty ? "Skill" : skill.category
        case .osaurus: "Act"
        }
    }

    var detailIcon: String {
        switch self {
        case .command(let command): command.defaultOperatingMode.systemImage
        case .skill: "sparkles"
        case .osaurus: "square.grid.2x2"
        }
    }

    var suggestedPrompt: String? {
        switch self {
        case .command(let command): command.suggestedPrompt
        case .skill: nil
        case .osaurus(let command): command.suggestedPrompt
        }
    }

    static func all(
        commands: [ACCSlashCommand],
        skills: [SkillDiscoveryEntry]
    ) -> [ComposerSlashCommandItem] {
        commands.map(ComposerSlashCommandItem.command)
            + skills.map(ComposerSlashCommandItem.skill)
    }

    static func surfaceItems(
        isOsaurusActMode: Bool,
        commands: [ACCSlashCommand],
        skills: [SkillDiscoveryEntry]
    ) -> [ComposerSlashCommandItem] {
        if isOsaurusActMode {
            return ActOsaurusSlashCommand.allCases.map(ComposerSlashCommandItem.osaurus)
                + skills.map(ComposerSlashCommandItem.skill)
        }
        return all(commands: commands, skills: skills)
    }
}

enum ComposerSlashMenuLogic {
    static func filter(in text: String) -> String? {
        let trimmedLeading = text.drop(while: \.isWhitespace)
        guard trimmedLeading.first == "/" else { return nil }

        let afterSlash = String(trimmedLeading.dropFirst())
        if afterSlash.contains(where: { $0.isWhitespace || $0.isNewline }) {
            return nil
        }
        return afterSlash
    }

    static func textAfterApplying(_ item: ComposerSlashCommandItem, to text: String) -> String {
        let leadingWhitespace = text.prefix { $0.isWhitespace }
        let afterLeading = text.dropFirst(leadingWhitespace.count)
        guard afterLeading.hasPrefix("/") else { return text }

        let slug = "/" + item.rawValue
        if afterLeading.hasPrefix(slug) {
            let suffix = afterLeading.dropFirst(slug.count)
            return String(leadingWhitespace) + suffix
        }

        let afterSlash = afterLeading.dropFirst()
        let partialEnd = afterSlash.firstIndex(where: { $0.isWhitespace }) ?? afterSlash.endIndex
        let remainder = afterSlash[partialEnd...]
        return String(leadingWhitespace) + String(remainder)
    }
}

enum ActOsaurusSlashCommand: String, CaseIterable, Hashable {
    case clear
    case model
    case agent
    case tools
    case configure
    case help

    var displayName: String {
        switch self {
        case .clear: "Clear"
        case .model: "Model"
        case .agent: "Agent"
        case .tools: "Tools"
        case .configure: "Configure"
        case .help: "Help"
        }
    }

    var helpText: String {
        switch self {
        case .clear: "Clear the current Act conversation"
        case .model: "Open the Act model picker inside this composer"
        case .agent: "Use the default Act agent"
        case .tools: "Show Act tool and skill controls"
        case .configure: "Open Act configuration in Epistemos settings"
        case .help: "Show Act commands and shortcuts"
        }
    }

    var icon: String {
        switch self {
        case .clear: "trash"
        case .model: "cpu"
        case .agent: "person.crop.square"
        case .tools: "slider.horizontal.3"
        case .configure: "gearshape"
        case .help: "questionmark.circle"
        }
    }

    var suggestedPrompt: String? {
        switch self {
        case .help:
            "Show Act commands and capabilities."
        case .agent:
            "Use the Act default agent for this request: "
        case .tools:
            "Use Act tools for this request: "
        case .model, .configure, .clear:
            nil
        }
    }
}

struct SlashCommandPopover: View {
    let items: [ComposerSlashCommandItem]
    let filter: String
    var selectedItem: ComposerSlashCommandItem? = nil
    let onSelect: (ComposerSlashCommandItem) -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    private var filteredItems: [ComposerSlashCommandItem] {
        Self.filteredItems(items: items, filter: filter)
    }

    init(
        commands: [ACCSlashCommand],
        filter: String,
        selectedCommand: ACCSlashCommand? = nil,
        onSelect: @escaping (ACCSlashCommand) -> Void
    ) {
        self.items = commands.map(ComposerSlashCommandItem.command)
        self.filter = filter
        self.selectedItem = selectedCommand.map(ComposerSlashCommandItem.command)
        self.onSelect = { item in
            if case .command(let command) = item {
                onSelect(command)
            }
        }
    }

    init(
        items: [ComposerSlashCommandItem],
        filter: String,
        selectedItem: ComposerSlashCommandItem? = nil,
        onSelect: @escaping (ComposerSlashCommandItem) -> Void
    ) {
        self.items = items
        self.filter = filter
        self.selectedItem = selectedItem
        self.onSelect = onSelect
    }

    static func filteredCommands(commands: [ACCSlashCommand], filter: String) -> [ACCSlashCommand] {
        filteredItems(items: commands.map(ComposerSlashCommandItem.command), filter: filter)
            .compactMap(\.command)
    }

    static func filteredItems(
        items: [ComposerSlashCommandItem],
        filter: String
    ) -> [ComposerSlashCommandItem] {
        let query = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.rawValue.lowercased().contains(query)
                || item.displayName.lowercased().contains(query)
                || item.helpText.lowercased().contains(query)
                || item.detailLabel.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if filteredItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredItems) { item in
                            SlashCommandRow(
                                item: item,
                                isSelected: selectedItem == item
                            ) {
                                onSelect(item)
                            }
                            if item != filteredItems.last {
                                Divider().opacity(0.15)
                                    .padding(.leading, 40)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }

            footer
        }
        .frame(minWidth: 360, idealWidth: 440, maxWidth: 520)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "command")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Commands + Skills")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if !filter.isEmpty {
                Text(filter)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.06))
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("No commands or skills match \"\(filter)\"")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 22)
    }

    private var footer: some View {
        HStack {
            Text("Type to filter commands and skills")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.04))
    }
}

private struct SlashCommandRow: View {
    let item: ComposerSlashCommandItem
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.purple.opacity(0.8))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("/\(item.rawValue)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(item.displayName)
                            .font(.system(size: 12, weight: .medium))
                    }
                    Text(item.helpText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                modePill
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background((isHovering || isSelected) ? Color.secondary.opacity(0.08) : Color.clear)
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.purple.opacity(0.72))
                        .frame(width: 2)
                        .padding(.vertical, 8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var modePill: some View {
        HStack(spacing: 3) {
            Image(systemName: item.detailIcon)
                .font(.system(size: 8, weight: .semibold))
            Text(item.detailLabel)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.purple.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.purple.opacity(0.25), lineWidth: 0.5))
        .foregroundStyle(.purple.opacity(0.85))
    }
}
