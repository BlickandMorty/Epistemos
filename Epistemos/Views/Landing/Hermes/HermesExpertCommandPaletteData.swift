import Foundation

/// View-side helper that filters `HermesCapabilityRegistry.all` for the
/// expert mode inline palette. Pure deterministic over the snapshot
/// registry — no I/O, no provider call. Safe from any actor.
nonisolated enum HermesExpertCommandPaletteData {

    struct Match: Identifiable, Equatable, Sendable {
        let id: String
        let commandToken: String
        let commandPattern: String
        let surface: HermesCapabilitySurface
        let tier: HermesCapabilityTier
        let nativeEquivalent: String
        let owner: HermesCapabilityOwner

        init(_ capability: HermesCapability) {
            self.commandToken = capability.commandToken
            self.commandPattern = capability.commandPattern
            self.surface = capability.surface
            self.tier = capability.tier
            self.nativeEquivalent = capability.nativeEquivalent
            self.owner = capability.owner
            self.id = capability.commandPattern
        }
    }

    /// Returns up to `limit` matches for the given draft. Match rules:
    /// - Strip leading whitespace.
    /// - If draft is "/" or empty (after trim), return the first `limit`
    ///   capabilities (most-common Core surfaces first via the
    ///   registry's existing order).
    /// - Otherwise, fuzzy-prefix-match the command token (case-insensitive).
    /// - Sort: exact prefix matches first, then prefix-of-token matches,
    ///   then substring matches.
    static func matches(for draft: String, limit: Int = 6) -> [Match] {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        let registry = HermesCapabilityRegistry.all

        guard trimmed.count > 1 else {
            // Bare "/" or empty: surface the first N entries — these are
            // ordered by the registry author for discoverability.
            return Array(registry.prefix(limit)).map(Match.init)
        }

        let needle = trimmed.lowercased()
        let scored: [(score: Int, capability: HermesCapability)] = registry.compactMap { cap in
            let token = cap.commandToken.lowercased()
            let pattern = cap.commandPattern.lowercased()

            if token == needle { return (0, cap) }
            if token.hasPrefix(needle) { return (1, cap) }
            if pattern.hasPrefix(needle) { return (2, cap) }
            if token.contains(needle) { return (3, cap) }
            if pattern.contains(needle) { return (4, cap) }
            return nil
        }

        let sorted = scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            return lhs.capability.commandPattern.count < rhs.capability.commandPattern.count
        }

        return Array(sorted.prefix(limit)).map { Match($0.capability) }
    }
}
