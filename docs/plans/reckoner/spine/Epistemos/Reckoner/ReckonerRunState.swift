// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// MAS-ONLY PIVOT (2026-07-07): Kindred presence is parked. Do not activate this path for MAS.
// Active proof is zero Kindred/presence symbols in `Epistemos-AppStore`; any visible status must
// derive from real June/agent_core state through MAS-safe UI.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// F3 parked presence reference: prior Reckoner-to-Kindred run-state is historical.
// June invokes identical tools with no companion presence.

import Foundation

#if KINDRED_ENABLED
struct ReckonerActivity: Sendable {
    let companionId: String
    let datasetId: String
    let phase: Phase
    let detail: String            // "cleaning column C" — from the REAL tool op

    enum Phase: String, Sendable {
        case reading, editing, toolRunning, awaitingApproval, done, error
        // Values map 1:1 onto the companion run-state enum; no new states invented.
    }
}

enum ReckonerPresence {
    /// Publish onto the companion bus (coalesced, clock-guarded upstream).
    static func emit(_ activity: ReckonerActivity) {
        // TODO: agent_core presence publish; location = Data tab + datasetId so
        // the mascot pins to the tab and the roster reads "cleaning column C".
    }
}
#endif
