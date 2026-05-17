import Foundation

nonisolated enum AgentBlueprintApprovalMode: String, Codable, Sendable, CaseIterable, Equatable {
    case askEveryTool = "ask_every_tool"
    case approveOncePerSession = "approve_once_per_session"
    case autoReadOnly = "auto_read_only"

    var displayName: String {
        switch self {
        case .askEveryTool:
            "Ask every tool"
        case .approveOncePerSession:
            "Approve once per session"
        case .autoReadOnly:
            "Auto read-only"
        }
    }

    var missionInstruction: String {
        switch self {
        case .askEveryTool:
            "Ask before every tool call that is not explicitly read-only."
        case .approveOncePerSession:
            "Ask once for the session and continue only within that approved scope."
        case .autoReadOnly:
            "Run read-only tools without interruption and ask before any mutation."
        }
    }
}

nonisolated enum AgentBlueprintScope: String, Codable, Sendable, CaseIterable, Equatable {
    case currentVault = "current_vault"
    case allNotes = "all_notes"
    case currentWorkspace = "current_workspace"

    var displayName: String {
        switch self {
        case .currentVault:
            "Current vault"
        case .allNotes:
            "All notes"
        case .currentWorkspace:
            "Current workspace"
        }
    }

    var missionInstruction: String {
        switch self {
        case .currentVault:
            "Limit retrieval and writes to the active vault unless the user approves a wider scope."
        case .allNotes:
            "Use the full notes corpus as retrieval context while preserving normal write approvals."
        case .currentWorkspace:
            "Use currently open workspace context first, then ask before expanding scope."
        }
    }
}

nonisolated enum AgentBlueprintModelChoice: Codable, Sendable, Equatable, Hashable {
    case autoConstellation
    case local(modelID: String, displayName: String)
    case cloud(provider: String, displayName: String)
    case appleIntelligence

    var displayName: String {
        switch self {
        case .autoConstellation:
            "Auto (constellation)"
        case .local(_, let displayName), .cloud(_, let displayName):
            displayName
        case .appleIntelligence:
            "Apple Intelligence"
        }
    }

    var routingID: String {
        switch self {
        case .autoConstellation:
            "auto_constellation"
        case .local(let modelID, _):
            "local:\(modelID)"
        case .cloud(let provider, _):
            "cloud:\(provider)"
        case .appleIntelligence:
            "apple_intelligence"
        }
    }
}

nonisolated struct AgentBlueprintDraft: Codable, Sendable, Equatable {
    var name: String
    var role: String
    var objective: String
    var model: AgentBlueprintModelChoice
    var toolNames: [String]
    var scope: AgentBlueprintScope
    var approvalMode: AgentBlueprintApprovalMode

    func missionPacket(
        id: String = UUID().uuidString,
        createdAt: Date = Date()
    ) -> AgentMissionPacket {
        AgentMissionPacket(
            id: id,
            createdAt: createdAt,
            blueprintName: Self.clean(name, fallback: "Research Assistant"),
            role: Self.clean(role, fallback: "Research assistant"),
            objective: Self.clean(objective, fallback: "Produce a grounded research artifact."),
            model: model,
            toolNames: Self.normalizedToolNames(toolNames),
            scope: scope,
            approvalMode: approvalMode
        )
    }

    private static func clean(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func normalizedToolNames(_ names: [String]) -> [String] {
        Array(
            Set(
                names
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }
}

nonisolated struct AgentMissionPacket: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let createdAt: Date
    let blueprintName: String
    let role: String
    let objective: String
    let model: AgentBlueprintModelChoice
    let toolNames: [String]
    let scope: AgentBlueprintScope
    let approvalMode: AgentBlueprintApprovalMode

    var commandCenterQuery: String {
        [
            "AgentBlueprint MissionPacket",
            "mission_packet_id: \(id)",
            "created_at_unix: \(String(format: "%.3f", createdAt.timeIntervalSince1970))",
            "agent_name: \(blueprintName)",
            "role: \(role)",
            "model: \(model.routingID)",
            "scope: \(scope.rawValue)",
            "approval_mode: \(approvalMode.rawValue)",
            "tools: \(toolNames.joined(separator: ", "))",
            "scope_instruction: \(scope.missionInstruction)",
            "approval_instruction: \(approvalMode.missionInstruction)",
            "objective:",
            objective,
        ].joined(separator: "\n")
    }
}
