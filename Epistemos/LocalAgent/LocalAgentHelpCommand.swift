import Foundation

/// Native unified-command-help surface for `/help` per
/// `HERMES_CAPABILITY_PARITY_TARGET_2026_05_03.md` — Session row.
///
/// Lists every command from `LocalAgentCapabilityRegistry` grouped by
/// surface, optionally filtered by tier or surface. **Core-safe**: no
/// network, no subprocess, no provider call. Deterministic / pure.
nonisolated struct LocalAgentHelpCommand: Equatable, Sendable {
    enum Filter: Equatable, Sendable {
        case all
        case tier(LocalAgentCapabilityTier)
        case surface(LocalAgentCapabilitySurface)
    }

    let filter: Filter

    var requiresApproval: Bool { false }

    // MARK: - Parse

    /// Parse `/help`, `/help <tier>`, `/help <surface>`. Returns `nil`
    /// for non-`/help` input. Unknown filter argument falls back to
    /// `.all` (so the user always gets a useful response).
    static func parse(_ rawCommand: String) -> LocalAgentHelpCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/help" || trimmed.hasPrefix("/help ") else {
            return nil
        }
        let arg = trimmed.dropFirst("/help".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !arg.isEmpty else {
            return LocalAgentHelpCommand(filter: .all)
        }
        if let tier = LocalAgentCapabilityTier(rawValue: arg) {
            return LocalAgentHelpCommand(filter: .tier(tier))
        }
        if let surface = LocalAgentCapabilitySurface(rawValue: arg) {
            return LocalAgentHelpCommand(filter: .surface(surface))
        }
        return LocalAgentHelpCommand(filter: .all)
    }

    // MARK: - Render

    /// Rendered help text grouped by surface. Stable section ordering
    /// (matches `LocalAgentCapabilitySurface.allCases` order in the registry)
    /// so screen-readers + UI consumers get deterministic output.
    func renderText(registry: [LocalAgentCapability] = LocalAgentCapabilityRegistry.all) -> String {
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

        for surface in LocalAgentCapabilitySurface.allCases {
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
