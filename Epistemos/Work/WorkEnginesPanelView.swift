import SwiftUI

// Native engines roster / status panel (clone-map #9 settings-lite + #11 diagnostics): shows the owner's full
// multi-engine roster with live connected/adapter state + the active engine's capability counts (models/agents/
// commands from loadResources). Flat/compact OpenCode-minimal; maps to OpenGUI's ProjectHarnessStatusBanner. Uses only
// data the supervisor already exposes (status.connectedHarnesses + resources) — no new bridge wrapper. Opens from the
// Work header gear. Read-only surfacing; provider auth/MCP config stay in runtime/provider settings work, not here.
struct WorkEnginesPanelView: View {
    let connectedHarnesses: [String]
    var resources: WorkEngineResources = .empty
    var context: WorkAppContextSnapshot = .empty
    var theme: EpistemosTheme = .nativeDefault

    private var accent: Color { theme.resolved.accent.color }

    // The owner's engine roster (order = engine priority) + display label + whether OpenGUI ships an adapter today.
    private static let roster: [(id: String, label: String, hasAdapter: Bool)] = [
        ("opencode", "OpenCode", true),
        ("codex", "Codex", true),
        ("claude-code", "Claude Code", true),
        ("pi", "Pi / OMP", true),
        ("goose", "Goose", false),
        ("hermes", "Hermes", false),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("ENGINES")
            ForEach(Self.roster, id: \.id) { engine in engineRow(engine) }
            Divider().overlay(theme.border).padding(.vertical, 4)
            label("CAPABILITIES (active engine)")
            capabilityRow("models", resources.flatModels.count)
            capabilityRow("agents", resources.agents.count)
            capabilityRow("commands", resources.commands.count)
            if !context.isEmpty {
                Divider().overlay(theme.border).padding(.vertical, 4)
                label("EPISTEMOS CONTEXT")
                ForEach(context.rows()) { row in contextRow(row) }
                Divider().overlay(theme.border).padding(.vertical, 4)
                label("RUNTIME SKILLS")
                let skills = provisionedSkills
                if skills.isEmpty {
                    emptySkillRow
                } else {
                    ForEach(skills.prefix(6)) { skill in skillRow(skill) }
                    if skills.count > 6 {
                        capabilityRow("more", skills.count - 6)
                    }
                }
            }
            if !resources.providers.isEmpty {
                Divider().overlay(theme.border).padding(.vertical, 4)
                label("PROVIDERS")
                ForEach(resources.providers) { provider in providerRow(provider) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(WorkPixelFont.body(10, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
    }

    private func engineRow(_ engine: (id: String, label: String, hasAdapter: Bool)) -> some View {
        let connected = connectedHarnesses.contains(engine.id)
        let statusText: String
        let dot: Color
        if connected { statusText = "connected"; dot = accent }
        else if engine.hasAdapter { statusText = "available"; dot = theme.mutedForeground }
        else { statusText = "not wired"; dot = theme.mutedForeground.opacity(0.4) }
        return HStack(spacing: 8) {
            Circle().fill(dot).frame(width: 6, height: 6)
            Text(engine.label)
                .font(WorkPixelFont.body(12))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Text(statusText)
                .font(WorkPixelFont.body(10))
                .foregroundStyle(theme.mutedForeground)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 2)
        .frame(minHeight: 20)
    }

    // A provider row: name + a "default" badge if it has a default model + its model count (provider-auth surfacing).
    private func providerRow(_ provider: WorkEngineProvider) -> some View {
        HStack(spacing: 8) {
            Text(provider.name)
                .font(WorkPixelFont.body(11))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            if resources.defaultModelByProvider[provider.id] != nil {
                Text("default")
                    .font(WorkPixelFont.body(9))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            Spacer(minLength: 0)
            Text("\(provider.models.count) models")
                .font(WorkPixelFont.body(10)).foregroundStyle(theme.mutedForeground)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 1)
        .frame(minHeight: 18)
    }

    private func capabilityRow(_ name: String, _ count: Int) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(WorkPixelFont.body(11))
                .foregroundStyle(theme.mutedForeground)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(WorkPixelFont.body(11, weight: .semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 1)
        .frame(minHeight: 18)
    }

    private func contextRow(_ row: WorkAppContextSnapshot.Row) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(row.label)
                .font(WorkPixelFont.body(11))
                .foregroundStyle(theme.mutedForeground)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Text(row.value)
                .font(WorkPixelFont.body(10))
                .foregroundStyle(theme.resolved.foreground.color)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 180, alignment: .trailing)
        }
        .padding(.vertical, 1)
        .frame(minHeight: 18)
    }

    private var provisionedSkills: [WorkProvisionedSkill] {
        guard let workspacePath = context.workspacePath else { return [] }
        return WorkSkillsProvisioner.provisionedSkills(workspace: URL(fileURLWithPath: workspacePath))
    }

    private var emptySkillRow: some View {
        Text("none visible")
            .font(WorkPixelFont.body(11))
            .foregroundStyle(theme.mutedForeground)
            .padding(.vertical, 1)
            .frame(minHeight: 18, maxWidth: .infinity, alignment: .leading)
    }

    private func skillRow(_ skill: WorkProvisionedSkill) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(skill.title)
                    .font(WorkPixelFont.body(11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Text(skill.id)
                    .font(WorkPixelFont.body(9))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 96, alignment: .trailing)
            }
            Text(skill.description)
                .font(WorkPixelFont.body(10))
                .foregroundStyle(theme.mutedForeground)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    WorkEnginesPanelView(
        connectedHarnesses: ["opencode", "codex"],
        context: WorkAppContextSnapshot(
            workspacePath: "/Users/example/Project",
            vaultPath: "/Users/example/EpistemosVault",
            managedSkillsCount: 3,
            nativeToolsAvailable: true))
        .frame(width: 280, height: 360)
}
