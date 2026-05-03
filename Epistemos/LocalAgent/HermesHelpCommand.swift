import Foundation

/// Native unified-command-help surface for `/help` per
/// `HERMES_CAPABILITY_PARITY_TARGET_2026_05_03.md` — Session row.
///
/// Lists every command from `HermesCapabilityRegistry` grouped by
/// surface, optionally filtered by tier or surface. **Core-safe**: no
/// network, no subprocess, no provider call. Deterministic / pure.
nonisolated struct HermesHelpCommand: Equatable, Sendable {
    enum Filter: Equatable, Sendable {
        case all
        case tier(HermesCapabilityTier)
        case surface(HermesCapabilitySurface)
    }

    let filter: Filter

    var requiresApproval: Bool { false }

    // MARK: - Parse

    /// Parse `/help`, `/help <tier>`, `/help <surface>`. Returns `nil`
    /// for non-`/help` input. Unknown filter argument falls back to
    /// `.all` (so the user always gets a useful response).
    static func parse(_ rawCommand: String) -> HermesHelpCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/help" || trimmed.hasPrefix("/help ") else {
            return nil
        }
        let arg = trimmed.dropFirst("/help".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !arg.isEmpty else {
            return HermesHelpCommand(filter: .all)
        }
        if let tier = HermesCapabilityTier(rawValue: arg) {
            return HermesHelpCommand(filter: .tier(tier))
        }
        if let surface = HermesCapabilitySurface(rawValue: arg) {
            return HermesHelpCommand(filter: .surface(surface))
        }
        return HermesHelpCommand(filter: .all)
    }

    // MARK: - Render

    /// Rendered help text grouped by surface. Stable section ordering
    /// (matches `HermesCapabilitySurface.allCases` order in the registry)
    /// so screen-readers + UI consumers get deterministic output.
    func renderText(registry: [HermesCapability] = HermesCapabilityRegistry.all) -> String {
        let filtered = registry.filter { capability in
            switch filter {
            case .all: return true
            case .tier(let t): return capability.tier == t
            case .surface(let s): return capability.surface == s
            }
        }
        guard !filtered.isEmpty else {
            return "No commands match the selected filter."
        }

        var lines: [String] = []
        switch filter {
        case .all:
            lines.append("Available commands:")
        case .tier(let t):
            lines.append("Commands in tier \(t.rawValue):")
        case .surface(let s):
            lines.append("Commands in surface \(s.rawValue):")
        }
        lines.append("")

        for surface in HermesCapabilitySurface.allCases {
            let group = filtered.filter { $0.surface == surface }
            guard !group.isEmpty else { continue }
            lines.append("[\(surface.rawValue)]")
            for capability in group {
                let approval = capability.requiresApproval ? " (approval)" : ""
                let tierLabel = capability.tier == .core ? "" : " [\(capability.tier.rawValue)]"
                lines.append("  \(capability.commandPattern)\(tierLabel)\(approval)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
