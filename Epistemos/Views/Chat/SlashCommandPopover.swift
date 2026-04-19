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

struct SlashCommandPopover: View {
    let filter: String
    let onSelect: (ACCSlashCommand) -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    private var filteredCommands: [ACCSlashCommand] {
        let allCommands = ACCSlashCommand.allCases
        let query = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return allCommands }
        return allCommands.filter { command in
            command.rawValue.lowercased().contains(query)
                || command.displayName.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if filteredCommands.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredCommands) { command in
                            SlashCommandRow(command: command) {
                                onSelect(command)
                            }
                            if command != filteredCommands.last {
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
            Text("Slash commands")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if !filter.isEmpty {
                Text("Filter: \(filter)")
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
            Text("No commands match \"\(filter)\"")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 22)
    }

    private var footer: some View {
        HStack {
            Text("Type to filter · Esc to dismiss")
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
    let command: ACCSlashCommand
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: command.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.purple.opacity(0.8))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("/\(command.rawValue)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(command.displayName)
                            .font(.system(size: 12, weight: .medium))
                    }
                    Text(command.helpText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                modePill
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isHovering ? Color.secondary.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var modePill: some View {
        HStack(spacing: 3) {
            Image(systemName: command.defaultOperatingMode.systemImage)
                .font(.system(size: 8, weight: .semibold))
            Text(command.defaultOperatingMode.displayName)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.purple.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.purple.opacity(0.25), lineWidth: 0.5))
        .foregroundStyle(.purple.opacity(0.85))
    }
}
