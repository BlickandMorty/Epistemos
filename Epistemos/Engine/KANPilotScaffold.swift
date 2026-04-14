import Foundation

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
