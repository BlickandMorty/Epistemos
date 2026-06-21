import Foundation

/// L1201 / L2124 — owner: "powerful out of the box" — ship a curated default set of the best
/// agent powers as a one-tap "enable recommended power set". Research said the powers are mostly
/// native already → curate + gate + expose. This is the curation: a recommended core power set,
/// matched against the LIVE available tool catalog so the preset only ever enables tools that
/// actually exist + are wired (real/working-only by construction; and because it filters the
/// profile's `availableTools`, it is implicitly MAS/Pro-gated — a Pro-only tool simply isn't in
/// the catalog on a MAS build).
///
/// Exposed behind EPISTEMOS_BEST_OF_PRESET_V0 (default OFF) so the one-tap appears only when
/// opted in; the curation + apply are pure/tested regardless.
enum EpistemosBestOfPreset {

    /// Default OFF. Set `EPISTEMOS_BEST_OF_PRESET_V0=1` to surface the one-tap preset control.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_BEST_OF_PRESET_V0"] == "1"
    }

    /// Name fragments for the recommended core power set — the broadly-useful agent capabilities
    /// (vault read/search/write, web research, thinking, memory, listing). Matched case-insensitively
    /// as substrings so the preset adapts to the real catalog's exact tool names (e.g. "vault_search",
    /// "web_fetch") without hardcoding ids that might drift.
    static let recommendedNameFragments: [String] = [
        "vault", "search", "read", "write", "note", "web", "fetch", "think", "memory", "list",
    ]

    /// The subset of `availableToolNames` that belongs to the recommended power set. Pure: the
    /// caller enables exactly these (additively, leaving any other user choices intact).
    static func recommendedToolNames(from availableToolNames: [String]) -> [String] {
        availableToolNames.filter { name in
            let lower = name.lowercased()
            return recommendedNameFragments.contains { lower.contains($0) }
        }
    }
}
