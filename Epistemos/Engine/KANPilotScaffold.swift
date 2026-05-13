import Foundation

// MARK: - KANPilotScaffold
//
// SCAFFOLD ONLY — RCA-P2-010 classification 2026-05-13.
//
// Phase-1.5 pilot scaffold for a KAN-style routing predictor that
// would bias retrieval candidate scoring off the main path. The
// struct ships with `enabled: false` defaults + a single production
// callsite (`EpistemosTests/PhaseOneFiveScaffoldingTests.swift:147`).
// No app target wires it in — every public API returns the
// `.disabled` status when constructed with defaults.
//
// Activation tracked under audit register `RCA-P2-010`. Future
// promotion needs (a) the KAN predictor weights, (b) the
// IntakeValve / SearchIndex caller, (c) the gating policy.

nonisolated enum KANPilotScope: String, Sendable, Equatable {
    case offMainPath = "off_main_path"
}

nonisolated struct KANPilotRequest: Sendable, Equatable {
    let objective: String
    let candidateIDs: [String]
}

nonisolated struct KANPilotRoutingHint: Sendable, Equatable {
    let candidateID: String
    let score: Double
}

nonisolated enum KANPilotStatus: String, Sendable, Equatable {
    case disabled
    case ready
}

nonisolated struct KANPilotResult: Sendable, Equatable {
    let status: KANPilotStatus
    let hints: [KANPilotRoutingHint]
}

nonisolated struct KANPilotScaffold {
    let scope: KANPilotScope
    let enabled: Bool

    init(
        scope: KANPilotScope = .offMainPath,
        enabled: Bool = false
    ) {
        self.scope = scope
        self.enabled = enabled
    }

    func evaluate(_ request: KANPilotRequest) -> KANPilotResult {
        guard enabled, !request.objective.isEmpty, !request.candidateIDs.isEmpty else {
            return KANPilotResult(status: .disabled, hints: [])
        }

        return KANPilotResult(
            status: .ready,
            hints: request.candidateIDs.enumerated().map { index, candidateID in
                KANPilotRoutingHint(
                    candidateID: candidateID,
                    score: 1.0 / Double(index + 1)
                )
            }
        )
    }
}
