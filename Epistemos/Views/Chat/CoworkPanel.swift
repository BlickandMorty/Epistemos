import SwiftUI

// REOPENED COWORK LAYOUT (P7.6, owner 2026-06-19): the cohesive cowork surface —
// Progress / Context / Working-folder / Queue / Connectors as one panel of sections
// (the owner's Claude-Desktop layout), each wired to REAL run telemetry with HONEST
// empty states (never fake data). Reachable from chat (the cowork button). Reads
// ChatState from the environment; the staged queue message is passed in (it lives in
// the composer's local state). The detailed Context view stays the badge popover
// (CoworkContextPanel); here Context is a compact summary so the panel reads at a
// glance.
struct CoworkPanel: View {
    @Environment(ChatState.self) private var chat
    /// The composer's staged follow-up (ComposerMessageQueue.pending), passed in.
    let queuedMessage: String?

    private var filesTouched: [CoworkRunContext.TouchedFile] {
        // File mutation is MAS-forbidden → naturally empty outside Pro (gate explicit).
        guard ToolSurfacePolicy.resolvedDistribution(.currentBuild) != .coreAppStore else { return [] }
        return CoworkRunContext.filesTouched(
            in: chat.messages.last(where: { $0.role == .assistant })?.contentBlocks
        )
    }
    private var workingFolder: String? { CoworkRunContext.workingFolder(for: filesTouched) }

    /// The REAL tool/connector inventory the agent can use on THIS build — already
    /// distribution-gated by ToolSurfacePolicy (fewer on MAS, more on Pro), so it's
    /// honest per-build, never fake.
    private var surfacedTools: [OmegaToolDefinition] { OmegaToolRegistry.surfacedTools() }
    private var connectorsByAgent: [(agent: String, tools: [OmegaToolDefinition])] {
        let groups = Dictionary(grouping: surfacedTools, by: { $0.agent })
        return groups.keys.sorted().map { (agent: $0, tools: groups[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Cowork", systemImage: "rectangle.split.2x1")
                    .font(.headline)
                Spacer()
            }
            .padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    progressSection
                    contextSection
                    workingFolderSection
                    queueSection
                    connectorsSection
                }
                .padding(16)
            }
        }
        .frame(width: 360, height: 520)
    }

    // MARK: - Sections (each REAL telemetry + honest empty state)

    /// Progress — the live run status.
    private var progressSection: some View {
        section("Progress", systemImage: "gauge.with.dots.needle.33percent") {
            HStack(spacing: 8) {
                Circle()
                    .fill(chat.isAgentExecuting ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(chat.isAgentExecuting ? "Running · \(chat.currentCapability.displayName)" : "Idle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Context — compact summary (window usage + attachment counts). Tap the context
    /// badge for the full CoworkContextPanel.
    private var contextSection: some View {
        section("Context", systemImage: "rectangle.compress.vertical") {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: min(max(chat.contextUsageFraction, 0), 1))
                Text(contextSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var contextSummary: String {
        let notes = chat.pendingContextAttachments.count
        let files = chat.pendingAttachments.count
        let pct = Int((chat.contextUsageFraction * 100).rounded())
        if notes == 0 && files == 0 {
            return "\(pct)% of window used · no attachments — tap the context badge for detail."
        }
        var parts: [String] = []
        if notes > 0 { parts.append("\(notes) note\(notes == 1 ? "" : "s")") }
        if files > 0 { parts.append("\(files) file\(files == 1 ? "" : "s")") }
        return "\(pct)% of window · \(parts.joined(separator: ", ")) — tap the context badge for detail."
    }

    /// Working folder — the files the agent actually mutated this run (Pro only).
    private var workingFolderSection: some View {
        section("Working folder", systemImage: "folder") {
            if let folder = workingFolder, !filesTouched.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text((folder as NSString).lastPathComponent)
                        .font(.callout.weight(.medium))
                    ForEach(filesTouched) { file in
                        Text("\(file.action.verb) \(file.fileName)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                emptyText("No files changed this run.")
            }
        }
    }

    /// Queue — the staged follow-up that auto-sends when the run finishes.
    private var queueSection: some View {
        section("Queue", systemImage: "text.append") {
            if let queued = queuedMessage, !queued.isEmpty {
                Text(queued)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else {
                emptyText("No message queued. Type + send while a run is active to stage one.")
            }
        }
    }

    /// Connectors — the REAL tool/MCP inventory the agent can use on this build,
    /// grouped by connector (agent), with an honest empty state.
    private var connectorsSection: some View {
        section("Connectors", systemImage: "point.3.connected.trianglepath.dotted") {
            if surfacedTools.isEmpty {
                emptyText("No tools are surfaced on this build.")
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(surfacedTools.count) tool\(surfacedTools.count == 1 ? "" : "s") across \(connectorsByAgent.count) connector\(connectorsByAgent.count == 1 ? "" : "s")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    ForEach(connectorsByAgent, id: \.agent) { group in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(group.agent.capitalized)
                                .font(.caption2.weight(.semibold))
                            Text(group.tools.map(\.name).joined(separator: ", "))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Building blocks

    private func section<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
