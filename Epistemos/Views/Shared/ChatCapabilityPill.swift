import SwiftUI

/// Small rounded badge that shows the user which ChatCapability tier the
/// active chat is running in. Used across main chat, mini chat, note chat,
/// and graph chat so the same signal reads the same way everywhere.
///
/// Kept deliberately tiny — it reads at a glance, never steals focus, and
/// animates a subtle pulse while agent work is in flight so the user knows
/// a long-running turn is actually progressing.
///
/// Optional `detail` appends a live sub-signal: when the agent is executing
    /// a specific tool, the pill reads e.g. "Agent • web.search" so the user
/// sees what the agent is doing right now without needing the command
/// center open. Pass nil to hide the detail.
struct ChatCapabilityPill: View {
    let capability: ChatCapability
    let detail: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(capability: ChatCapability, detail: String? = nil) {
        self.capability = capability
        self.detail = detail
    }

    var body: some View {
        if capability.isAgentActive {
            pillBody
                .breathe(amplitude: 0.01, period: 1.6)
        } else {
            pillBody
        }
    }

    private var pillBody: some View {
        HStack(spacing: 4) {
            Image(systemName: capability.iconSystemName)
                .font(.system(size: 10, weight: .semibold))
            Text(capability.displayName)
                .font(.system(size: 11, weight: .medium, design: .rounded))
            if let detail, !detail.isEmpty {
                Text("•")
                    .font(.system(size: 10, weight: .regular))
                    .opacity(0.55)
                Text(detail)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(background)
        .overlay(border)
        .clipShape(Capsule())
        .help(detail.map { "\(capability.displayName): \($0)" } ?? capability.shortExplanation)
        .accessibilityLabel(
            Text(
                detail.map { "\(capability.displayName) running \($0)" }
                    ?? "\(capability.displayName) — \(capability.shortExplanation)"
            )
        )
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: detail)
    }

    private var tint: Color {
        switch capability {
        case .local: .green
        case .thinking: .indigo
        case .research: .teal
        case .cloud: .blue
        case .agent: .purple
        }
    }

    private var background: some View {
        Capsule()
            .fill(tint.opacity(0.14))
    }

    private var border: some View {
        Capsule()
            .strokeBorder(tint.opacity(0.35), lineWidth: 0.75)
    }
}

nonisolated enum ComposerModelToolTruth {
    struct Summary: Sendable, Equatable {
        let pillDetail: String?
        let label: String
        let detail: String
        let toolsAvailable: Bool
        let systemImage: String
    }

    struct CompatibilityRow: Identifiable, Sendable, Equatable {
        let id: String
        let selection: ChatModelSelection
        let operatingMode: EpistemosOperatingMode
        let title: String
        let sourceLabel: String
        let summary: Summary
        let providerNativeToolNames: [String]
        let skillCount: Int
        let isCurrent: Bool

        var appToolStateLabel: String {
            summary.toolsAvailable ? "app tools" : "inventory only"
        }

        var providerNativeStateLabel: String {
            providerNativeToolNames.isEmpty
                ? "no provider-native"
                : "\(providerNativeToolNames.count) provider-native"
        }

        var skillStateLabel: String {
            skillCount == 0 ? "no skills" : "\(skillCount) skills visible"
        }

        var skillHandlingDetail: String {
            guard skillCount > 0 else {
                return "No installed skills are currently discovered for this route."
            }
            if summary.toolsAvailable {
                return "Skills can shape the request, but execution still requires a runtime or tool event."
            }
            return "Skills are visible as slash/instruction context; this route cannot execute app tools directly."
        }
    }

    static func detail(
        for selection: ChatModelSelection,
        capability: ChatCapability
    ) -> String? {
        guard capability == .agent || capability == .research else {
            return nil
        }

        return toolDetail(for: selection)
    }

    static func summary(
        for selection: ChatModelSelection,
        capability: ChatCapability,
        operatingMode: EpistemosOperatingMode
    ) -> Summary {
        switch selection {
        case .cloud(let model):
            return cloudSummary(
                for: model,
                capability: capability,
                operatingMode: operatingMode
            )
        case .localMLX(let modelID):
            return localSummary(
                modelID: modelID,
                capability: capability,
                operatingMode: operatingMode
            )
        case .appleIntelligence:
            return Summary(
                pillDetail: detail(for: selection, capability: capability),
                label: "Apple Intelligence direct stream",
                detail: "No app tool loop",
                toolsAvailable: false,
                systemImage: "apple.logo"
            )
        }
    }

    static func compatibilityRows(
        currentSelection: ChatModelSelection,
        operatingMode: EpistemosOperatingMode,
        localModelIDs: [String],
        cloudModels: [CloudTextModelID],
        providerNativeToolNames: (ChatModelSelection) -> [String],
        skillCount: Int
    ) -> [CompatibilityRow] {
        var candidates: [(selection: ChatModelSelection, isCurrent: Bool)] = [
            (currentSelection, true)
        ]
        candidates.append(contentsOf: localModelIDs.map { (.localMLX($0), false) })
        candidates.append(contentsOf: cloudModels.map { (.cloud($0), false) })

        var seen: Set<String> = []
        return candidates.compactMap { candidate in
            guard seen.insert(candidate.selection.rawValue).inserted else {
                return nil
            }
            let capability = capability(for: candidate.selection, operatingMode: operatingMode)
            let summary = summary(
                for: candidate.selection,
                capability: capability,
                operatingMode: operatingMode
            )
            return CompatibilityRow(
                id: candidate.selection.rawValue,
                selection: candidate.selection,
                operatingMode: operatingMode,
                title: candidate.selection.displayName,
                sourceLabel: sourceLabel(for: candidate.selection, isCurrent: candidate.isCurrent),
                summary: summary,
                providerNativeToolNames: providerNativeToolNames(candidate.selection),
                skillCount: skillCount,
                isCurrent: candidate.isCurrent
            )
        }
    }

    private static func capability(
        for selection: ChatModelSelection,
        operatingMode: EpistemosOperatingMode
    ) -> ChatCapability {
        if operatingMode == .agent {
            return .agent
        }
        if operatingMode == .thinking {
            if case .cloud = selection {
                return .cloud
            }
            return .thinking
        }
        if case .cloud = selection {
            return .cloud
        }
        return .local
    }

    private static func sourceLabel(
        for selection: ChatModelSelection,
        isCurrent: Bool
    ) -> String {
        if isCurrent {
            return "current effective route"
        }
        switch selection {
        case .localMLX:
            return "local installed/prepared"
        case .cloud(let model):
            return "\(model.provider.displayName) preferred"
        case .appleIntelligence:
            return "Apple fallback"
        }
    }

    private static func toolDetail(for selection: ChatModelSelection) -> String {
        switch selection {
        case .localMLX(let modelID):
            let badge = RuntimeRouter.agentCapabilityBadgeData(forLocalModelID: modelID)
            switch badge.toolCallMode {
            case .native:
                return "native tools"
            case .softGuidance:
                return "soft-guidance tools"
            case .none:
                return "no tools"
            }
        case .cloud(let model):
            return model.provider.supportsAgentTier ? "managed tools" : "no tools"
        case .appleIntelligence:
            return "no tools"
        }
    }

    private static func cloudSummary(
        for model: CloudTextModelID,
        capability: ChatCapability,
        operatingMode: EpistemosOperatingMode
    ) -> Summary {
        let pillDetail = detail(for: .cloud(model), capability: capability)
        switch operatingMode {
        case .agent, .pro:
            guard model.provider.supportsAgentTier else {
                return Summary(
                    pillDetail: pillDetail,
                    label: "Cloud direct stream (managed tools unavailable)",
                    detail: "\(model.provider.displayName) is not promoted to the managed agent tier; switch to OpenAI/Anthropic or a local tool-capable model for app tools.",
                    toolsAvailable: false,
                    systemImage: "exclamationmark.triangle"
                )
            }
            return Summary(
                pillDetail: pillDetail,
                label: operatingMode == .agent
                    ? "Rust managed agent (cloud + tools)"
                    : "Cloud chat_pro (bounded tool loop)",
                detail: "\(pillDetail ?? "managed tools") · \(model.provider.displayName) promoted agent runtime",
                toolsAvailable: true,
                systemImage: operatingMode == .agent ? "sparkles" : "tray.full"
            )
        case .thinking:
            return Summary(
                pillDetail: pillDetail,
                label: "Thinking (direct stream)",
                detail: "Extended reasoning; no app tool loop",
                toolsAvailable: false,
                systemImage: "brain"
            )
        case .fast:
            return Summary(
                pillDetail: pillDetail,
                label: "Cloud direct stream",
                detail: "Provider streaming, no app tool loop",
                toolsAvailable: false,
                systemImage: "cloud"
            )
        }
    }

    private static func localSummary(
        modelID: String,
        capability: ChatCapability,
        operatingMode: EpistemosOperatingMode
    ) -> Summary {
        let pillDetail = detail(for: .localMLX(modelID), capability: capability)
        switch operatingMode {
        case .agent:
            let badge = RuntimeRouter.agentCapabilityBadgeData(forLocalModelID: modelID)
            guard badge.toolCallMode != .none else {
                return Summary(
                    pillDetail: pillDetail,
                    label: "Local agent unavailable",
                    detail: "\(badge.title) · \(badge.reason)",
                    toolsAvailable: false,
                    systemImage: "exclamationmark.triangle"
                )
            }
            return Summary(
                pillDetail: pillDetail,
                label: badge.toolCallMode == .native
                    ? "Local agent loop (native tools)"
                    : "Local agent loop (soft-guidance tools)",
                detail: "\(badge.title) · \(badge.reason)",
                toolsAvailable: badge.state != .off,
                systemImage: "bolt.circle"
            )
        case .pro:
            return Summary(
                pillDetail: pillDetail,
                label: "Local Pro (extended thinking)",
                detail: "On-device model with extended reasoning; no app tool loop",
                toolsAvailable: false,
                systemImage: "brain.head.profile"
            )
        case .thinking:
            return Summary(
                pillDetail: pillDetail,
                label: "Thinking (direct stream)",
                detail: "Extended reasoning; no app tool loop",
                toolsAvailable: false,
                systemImage: "brain"
            )
        case .fast:
            return Summary(
                pillDetail: pillDetail,
                label: "Local direct stream",
                detail: "On-device generation, no app tool loop",
                toolsAvailable: false,
                systemImage: "bolt"
            )
        }
    }
}

#Preview("All capabilities") {
    VStack(alignment: .leading, spacing: 10) {
        ForEach(ChatCapability.allCases, id: \.self) { capability in
            HStack(spacing: 10) {
                ChatCapabilityPill(capability: capability)
                Text(capability.shortExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .frame(width: 500)
    .environment(UIState())
}
