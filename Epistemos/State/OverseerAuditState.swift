import Foundation
import Observation

/// Transparency-only record of recent Overseer planning decisions. Every
/// main-chat turn that runs through ChatCoordinator.buildOverseerExecutionPlan
/// pushes its ExecutionPlan here so the Settings → "Overseer" panel can
/// surface what the auto-router is actually doing.
///
/// Read-only audit trail. No user controls for the Overseer live here
/// yet — the panel is diagnostic-first by design. Phase 3 can add
/// controls once we've lived with the visibility alone.
@MainActor @Observable
final class OverseerAuditState {
    /// One entry per planned turn. Most recent first, capped so old
    /// plans don't balloon memory.
    private(set) var recentPlans: [OverseerAuditEntry] = []

    /// How many entries to keep. Matches "last ten turns" in the
    /// settings UI.
    static let capacity: Int = 10

    func record(
        turnID: String,
        objective: String,
        plan: OverseerComplexityRouter.ExecutionPlan,
        recordedAt: Date = Date()
    ) {
        let entry = OverseerAuditEntry(
            turnID: turnID,
            objective: objective,
            plan: plan,
            recordedAt: recordedAt
        )
        recentPlans.insert(entry, at: 0)
        if recentPlans.count > Self.capacity {
            recentPlans.removeLast(recentPlans.count - Self.capacity)
        }
    }

    /// Clear the audit trail — used by "Reset history" button in the
    /// settings panel and during workspace switches so the trail doesn't
    /// bleed across unrelated vaults.
    func clear() {
        recentPlans.removeAll(keepingCapacity: false)
    }
}

/// One row in the Overseer audit trail.
nonisolated struct OverseerAuditEntry: Identifiable, Sendable {
    let turnID: String
    let objective: String
    let plan: OverseerComplexityRouter.ExecutionPlan
    let recordedAt: Date

    var id: String { turnID }

    /// Shortened objective for the row title — full text is in the
    /// expanded detail view.
    var headline: String {
        let trimmed = objective
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        return String(trimmed.prefix(80))
    }

    /// Human-readable route label for the pill in the row.
    var routeDisplayName: String {
        switch plan.route {
        case .localOnly: "Local only"
        case .overseerLocalExecution: "Overseer + local tools"
        case .managedAgentSession: "Managed tools (cloud)"
        }
    }
}
