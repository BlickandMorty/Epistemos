import SwiftUI

// Native slash-command popover (clone-map #4) — a flat, compact list of the engine's commands (from
// loadResources → resources.commands) filtered by the text after "/". OpenCode-minimal: no donor chrome, monospace,
// boxy. The host shows it above the input when the field starts with "/", passes the query, and on select inserts /
// runs the command. Standalone + reusable; the input wiring lands in the integration pass.
struct WorkSlashCommandPopover: View {
    let commands: [WorkEngineCommand]
    /// The text typed after the leading "/" (used to filter); empty shows all.
    var query: String = ""
    var theme: EpistemosTheme = .nativeDefault
    var onSelect: (WorkEngineCommand) -> Void = { _ in }

    private var accent: Color { theme.resolved.accent.color }
    private var boxBackground: Color { WorkSurfaceStyle.background(for: theme, role: .popover) }

    private var filtered: [WorkEngineCommand] {
        let needle = query.lowercased()
        guard !needle.isEmpty else { return commands }
        return commands.filter {
            $0.name.lowercased().hasPrefix(needle) || $0.name.lowercased().contains(needle)
        }
    }

    var body: some View {
        if !filtered.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered) { command in
                            Button { onSelect(command) } label: { row(command) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
            .padding(4)
            .frame(maxWidth: 460, alignment: .leading)
            .background(boxBackground)
            .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(theme.border, lineWidth: 0.8))
        }
    }

    private func row(_ command: WorkEngineCommand) -> some View {
        HStack(spacing: 8) {
            Text("/\(command.name)")
                .font(WorkPixelFont.body(12, weight: .semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 190, alignment: .leading)
            if let description = command.description, !description.isEmpty {
                Text(description)
                    .font(WorkPixelFont.body(11))
                    .foregroundStyle(theme.mutedForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(minHeight: 26)
        .contentShape(Rectangle())
    }
}

#Preview {
    WorkSlashCommandPopover(commands: [
        WorkEngineCommand(name: "init", description: "guided AGENTS.md setup"),
        WorkEngineCommand(name: "compact", description: "compact the conversation"),
    ]).frame(width: 320, height: 120)
}
