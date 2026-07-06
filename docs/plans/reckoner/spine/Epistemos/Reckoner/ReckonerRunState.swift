// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// Gating CORRECT (#if KINDRED_ENABLED; states are a strict subset of KINDRED RunState ✓). ONE FIX:
// the emit() TODO targets "agent_core presence publish" — KINDRED's BINDING amendment moved the v1
// presence hub to SWIFT (CompanionState.swift; /host ws + native producers). Emit to the Swift hub.
// SEAM RENEGOTIATION REQUIRED (Card 2 update): KINDRED's CompanionPresence has no Data-tab Surface
// variant, no datasetId in Location, no live `detail` field — "mascot pins to the Data tab
// streaming 'cleaning column C'" needs those three additions on the KINDRED side (K-AMEND 11).
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// F3 presence: RECKONER emits run-state so the companion pins to the Data tab
// ("cleaning column C"). 1CODE-ONLY — compiled out on MAS via the locked
// KINDRED_ENABLED trait; June invokes identical tools with no presence.
// (Dependencies / hand-off seam: the presence bus, run-state enum, clock rules,
// and mascot binding are owned by EPI-RP-05-KINDRED; RECKONER publishes onto
// that bus and NEVER invents a parallel channel.)

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
