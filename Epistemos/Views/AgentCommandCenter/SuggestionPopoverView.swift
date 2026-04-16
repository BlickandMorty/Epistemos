import SwiftUI

// MARK: - Suggestion Popover View
// Low-latency floating dropdown that renders filtered lists from registry sources.
// Unified / menu shows builtin modes + discovered skills in one dropdown.
// @mentions use contextProviders registry. Keyboard navigable.

struct SuggestionPopoverView: View {
    @Environment(AgentCommandCenterState.self) private var accState
    @Environment(UIState.self) private var ui

    private let terminalPanel = Color(red: 0.095, green: 0.096, blue: 0.096)
    private let terminalBorder = Color.white.opacity(0.10)
    private let maxVisibleRows = 8
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Group {
            switch accState.suggestionMenuState {
            case .hidden:
                EmptyView()

            case .slashMenu(let filter):
                slashMenuContent(filter: filter)

            case .contextMentions(let filter):
                mentionMenuContent(filter: filter)

            case .brains(let filter):
                brainMenuContent(filter: filter)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(terminalPanel.opacity(0.92))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.24), radius: 16, y: 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.border.opacity(0.72), lineWidth: 0.8)
        }
    }

    // MARK: - Slash Menu (unified: modes + skills)

    private func slashMenuContent(filter: String) -> some View {
        let builtinMatches = ACCSlashCommand.allCases.filter {
            filter.isEmpty || $0.rawValue.localizedCaseInsensitiveContains(filter) || $0.displayName.localizedCaseInsensitiveContains(filter)
        }
        let skillMatches = accState.availableSkills.filter {
            filter.isEmpty || $0.identifier.localizedCaseInsensitiveContains(filter) || $0.title.localizedCaseInsensitiveContains(filter)
        }

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if !builtinMatches.isEmpty {
                    sectionHeader("Modes & Commands")
                    ForEach(Array(builtinMatches.enumerated()), id: \.element.id) { index, cmd in
                        suggestionRow(
                            icon: cmd.icon,
                            title: "/\(cmd.rawValue)",
                            subtitle: cmd.helpText,
                            isHighlighted: index == accState.highlightedSuggestionIndex
                        ) {
                            selectSlashCommand(cmd)
                        }
                    }
                }

                if !skillMatches.isEmpty {
                    if !builtinMatches.isEmpty {
                        Divider().padding(.vertical, 4).opacity(0.3)
                    }
                    sectionHeader("Skills")
                    ForEach(Array(skillMatches.enumerated()), id: \.element.id) { index, skill in
                        let adjustedIndex = builtinMatches.count + index
                        suggestionRow(
                            icon: "wand.and.stars",
                            title: "/\(skill.identifier)",
                            subtitle: skill.description,
                            isHighlighted: adjustedIndex == accState.highlightedSuggestionIndex
                        ) {
                            selectSkill(skill)
                        }
                    }
                }

                if builtinMatches.isEmpty && skillMatches.isEmpty {
                    noResultsRow(for: filter)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxHeight: CGFloat(maxVisibleRows) * 40)
    }

    // MARK: - Mention Menu

    private func mentionMenuContent(filter: String) -> some View {
        let matches = accState.contextProviders.filter {
            filter.isEmpty || $0.token.localizedCaseInsensitiveContains(filter)
        }

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Context")
                ForEach(Array(matches.enumerated()), id: \.element.id) { index, provider in
                    suggestionRow(
                        icon: provider.icon,
                        title: "@\(provider.token)",
                        subtitle: provider.category.rawValue.capitalized,
                        isHighlighted: index == accState.highlightedSuggestionIndex
                    ) {
                        selectContextProvider(provider)
                    }
                }

                if matches.isEmpty {
                    noResultsRow(for: filter)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxHeight: CGFloat(maxVisibleRows) * 40)
    }

    // MARK: - Brain Menu

    private func brainMenuContent(filter: String) -> some View {
        let matches = accState.availableBrains.filter {
            filter.isEmpty || $0.displayName.localizedCaseInsensitiveContains(filter)
        }

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Brains")
                ForEach(Array(matches.enumerated()), id: \.element.id) { index, brain in
                    suggestionRow(
                        icon: brain.icon,
                        title: brain.displayName,
                        subtitle: brainSubtitle(brain),
                        isHighlighted: index == accState.highlightedSuggestionIndex
                    ) {
                        accState.selectedBrain = brain
                        accState.suggestionMenuState = .hidden
                    }
                }

                if matches.isEmpty {
                    noResultsRow(for: filter)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxHeight: CGFloat(maxVisibleRows) * 40)
    }

    // MARK: - Shared Row Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.42))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }

    private func suggestionRow(
        icon: String,
        title: String,
        subtitle: String,
        isHighlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isHighlighted ? Color.white.opacity(0.86) : Color.white.opacity(0.58))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.80))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.46))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isHighlighted ? theme.resolved.accent.color.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func noResultsRow(for filter: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.36))
            Text("No results for \"\(filter)\"")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.48))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func selectSlashCommand(_ cmd: ACCSlashCommand) {
        accState.activeSlashToken = .builtinMode(cmd)
        accState.selectedOperatingMode = cmd.defaultOperatingMode
        accState.suggestionMenuState = .hidden

        // Remove the /partial from input text
        if accState.inputText.hasPrefix("/") {
            if let spaceIndex = accState.inputText.firstIndex(of: " ") {
                accState.inputText = String(accState.inputText[accState.inputText.index(after: spaceIndex)...])
            } else {
                accState.inputText = ""
            }
        }
    }

    private func selectSkill(_ skill: SkillDiscoveryEntry) {
        accState.activeSlashToken = .skill(skill)
        accState.suggestionMenuState = .hidden

        // Remove the /partial from input text
        if accState.inputText.hasPrefix("/") {
            if let spaceIndex = accState.inputText.firstIndex(of: " ") {
                accState.inputText = String(accState.inputText[accState.inputText.index(after: spaceIndex)...])
            } else {
                accState.inputText = ""
            }
        }
    }

    private func selectContextProvider(_ provider: ACCContextProvider) {
        accState.activeMentions.append(ACCContextMention(
            id: provider.id,
            token: provider.token,
            resolvedLabel: provider.token,
            mentionType: ACCContextMention.MentionType(rawValue: provider.category.rawValue) ?? .custom
        ))
        accState.suggestionMenuState = .hidden

        // Remove the @partial from input text
        if let atRange = accState.inputText.range(of: "@\\w+$", options: .regularExpression) {
            accState.inputText.removeSubrange(atRange)
        }
    }

    private func brainSubtitle(_ brain: ACCBrainSelection) -> String {
        switch brain {
        case .local(_, _, let thinking, let vision, let tools):
            var badges: [String] = []
            if thinking { badges.append("🧠") }
            if vision { badges.append("👁") }
            if tools { badges.append("🔧") }
            return badges.isEmpty ? "Local" : "Local • \(badges.joined())"
        case .appleIntelligence:
            return "On-device"
        case .cloud(let provider):
            return provider.displayName
        }
    }
}
