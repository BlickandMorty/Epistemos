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

nonisolated enum AgentBlueprintModelBadgeTone: String, Codable, Sendable, Equatable {
    case good
    case neutral
    case warning
    case disabled
}

nonisolated struct AgentBlueprintModelBadge: Codable, Sendable, Equatable, Hashable {
    let title: String
    let tone: AgentBlueprintModelBadgeTone
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

    var badges: [AgentBlueprintModelBadge] {
        switch self {
        case .autoConstellation:
            [
                .init(title: "HONEST", tone: .good),
                .init(title: "LOCAL-FIRST", tone: .good),
                .init(title: "ROUTER", tone: .neutral),
                .init(title: "STRICT-GRAMMAR", tone: .good),
            ]
        case .local(let modelID, _):
            [
                .init(title: "HONEST", tone: .good),
                .init(title: "LOCAL", tone: .good),
                .init(title: LocalToolGrammar.nativeGrammar(forModelID: modelID).displayName, tone: .neutral),
                .init(title: "STRICT-GRAMMAR", tone: .good),
            ]
        case .cloud:
            [
                .init(title: "HONEST", tone: .good),
                .init(title: "CLOUD", tone: .warning),
                .init(title: "ESCALATION", tone: .warning),
            ]
        case .appleIntelligence:
            [
                .init(title: "EXPERIMENTAL", tone: .warning),
                .init(title: "APPLE", tone: .neutral),
                .init(title: "FAST-ONLY", tone: .neutral),
                .init(title: "NO-TOOLS", tone: .warning),
            ]
        }
    }

    var badgeLine: String {
        badges.map(\.title).joined(separator: ", ")
    }

    var executionPolicy: String {
        switch self {
        case .autoConstellation, .local:
            "local_only"
        case .cloud:
            "cloud_escalation_explicit"
        case .appleIntelligence:
            "local_platform_fast_only"
        }
    }

    var cloudEscalation: String {
        switch self {
        case .cloud:
            "explicit_model_selection"
        case .autoConstellation, .local, .appleIntelligence:
            "disabled"
        }
    }

    var strictGrammarStatus: String {
        switch self {
        case .autoConstellation, .local:
            "enabled"
        case .cloud:
            "provider_native"
        case .appleIntelligence:
            "no_tools"
        }
    }

    var grammarProfile: String {
        switch self {
        case .autoConstellation:
            "router_native_strict"
        case .local(let modelID, _):
            LocalToolGrammar.nativeGrammar(forModelID: modelID).rawValue
        case .cloud:
            "provider_native"
        case .appleIntelligence:
            "apple_fast_only"
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
    static let artifactContract = "note_artifact_and_answer_packet"

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
            "model_badges: \(model.badgeLine)",
            "execution_policy: \(model.executionPolicy)",
            "cloud_escalation: \(model.cloudEscalation)",
            "strict_grammar: \(model.strictGrammarStatus)",
            "grammar_profile: \(model.grammarProfile)",
            "artifact_contract: \(Self.artifactContract)",
            "scope: \(scope.rawValue)",
            "approval_mode: \(approvalMode.rawValue)",
            "tools: \(toolNames.joined(separator: ", "))",
            "scope_instruction: \(scope.missionInstruction)",
            "approval_instruction: \(approvalMode.missionInstruction)",
            "objective:",
            objective,
        ].joined(separator: "\n")
    }

    static func runtimeMetadata(fromCommandCenterQuery query: String) -> [String: String] {
        let lines = query
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        guard lines.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "AgentBlueprint MissionPacket" }) else {
            return [:]
        }

        var metadata: [String: String] = ["agent_blueprint": "true"]
        let mappings: [(field: String, key: String)] = [
            ("mission_packet_id", "mission_packet_id"),
            ("agent_name", "agent_blueprint_name"),
            ("model", "agent_blueprint_model"),
            ("model_badges", "agent_blueprint_model_badges"),
            ("execution_policy", "agent_blueprint_execution_policy"),
            ("cloud_escalation", "agent_blueprint_cloud_escalation"),
            ("strict_grammar", "agent_blueprint_strict_grammar"),
            ("grammar_profile", "agent_blueprint_grammar_profile"),
            ("artifact_contract", "agent_blueprint_artifact_contract"),
            ("scope", "agent_blueprint_scope"),
            ("approval_mode", "agent_blueprint_approval_mode"),
            ("tools", "agent_blueprint_tools"),
        ]

        for mapping in mappings {
            if let value = oneLineField(mapping.field, in: lines) {
                metadata[mapping.key] = bounded(value)
            }
        }
        return metadata
    }

    private static func oneLineField(_ name: String, in lines: [String]) -> String? {
        let prefix = "\(name):"
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        let value = String(line.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func bounded(_ value: String, maxLength: Int = 160) -> String {
        guard value.count > maxLength else { return value }
        return "\(value.prefix(maxLength - 3))..."
    }
}

nonisolated struct AgentBlueprintRunRecord: Codable, Sendable, Equatable, Identifiable {
    let packet: AgentMissionPacket
    let queuedAt: Date

    var id: String { packet.id }
}

nonisolated enum AgentBlueprintRunStore {
    static let defaultsKey = "epistemos.agentBlueprint.recentMissionPackets"
    static let defaultLimit = 8

    private struct Snapshot: Codable, Equatable {
        let schemaVersion: Int
        let records: [AgentBlueprintRunRecord]
    }

    static func load(
        defaults: UserDefaults = .standard,
        limit: Int = defaultLimit
    ) -> [AgentBlueprintRunRecord] {
        guard
            let data = defaults.data(forKey: defaultsKey),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
            snapshot.schemaVersion == 1
        else {
            return []
        }

        return Array(normalize(snapshot.records).prefix(max(0, limit)))
    }

    @discardableResult
    static func record(
        _ packet: AgentMissionPacket,
        queuedAt: Date = Date(),
        defaults: UserDefaults = .standard,
        limit: Int = defaultLimit
    ) -> [AgentBlueprintRunRecord] {
        let records = [AgentBlueprintRunRecord(packet: packet, queuedAt: queuedAt)] + load(
            defaults: defaults,
            limit: max(defaultLimit, limit)
        )
        return save(records, defaults: defaults, limit: limit)
    }

    @discardableResult
    static func save(
        _ records: [AgentBlueprintRunRecord],
        defaults: UserDefaults = .standard,
        limit: Int = defaultLimit
    ) -> [AgentBlueprintRunRecord] {
        let bounded = Array(normalize(records).prefix(max(0, limit)))
        guard !bounded.isEmpty else {
            defaults.removeObject(forKey: defaultsKey)
            return []
        }

        let snapshot = Snapshot(schemaVersion: 1, records: bounded)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: defaultsKey)
        }
        return bounded
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: defaultsKey)
    }

    private static func normalize(_ records: [AgentBlueprintRunRecord]) -> [AgentBlueprintRunRecord] {
        var seen = Set<String>()
        return records
            .sorted { lhs, rhs in
                if lhs.queuedAt != rhs.queuedAt {
                    return lhs.queuedAt > rhs.queuedAt
                }
                return lhs.packet.createdAt > rhs.packet.createdAt
            }
            .filter { record in
                seen.insert(record.id).inserted
            }
    }
}
