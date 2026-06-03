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

nonisolated struct AgentBlueprintRuntimeContractField: Codable, Sendable, Equatable, Hashable {
    let label: String
    let value: String
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
                Self.localAgentCapabilityBadge(forModelID: modelID),
                .init(title: "LOCAL", tone: .good),
                .init(title: LocalToolGrammar.nativeGrammar(forModelID: modelID).displayName, tone: .neutral),
                Self.localGrammarConfidenceBadge(forModelID: modelID),
            ].filter { !$0.title.isEmpty }
        case .cloud:
            [
                .init(title: "HONEST", tone: .good),
                .init(title: "CLOUD", tone: .warning),
                .init(title: "ESCALATION", tone: .warning),
            ]
        case .appleIntelligence:
            [
                .init(title: "OFF", tone: .disabled),
                .init(title: "APPLE", tone: .neutral),
                .init(title: "FAST-ONLY", tone: .neutral),
                .init(title: "NO-TOOLS", tone: .disabled),
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
        case .autoConstellation:
            "enabled"
        case .local(let modelID, _):
            Self.localStrictGrammarStatus(forModelID: modelID)
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

    var requiresExplicitBrainOverride: Bool {
        switch self {
        case .autoConstellation:
            false
        case .local, .cloud, .appleIntelligence:
            true
        }
    }

    static func localAgentCapabilityBadge(forModelID modelID: String) -> AgentBlueprintModelBadge {
        let data = RuntimeRouter.agentCapabilityBadgeData(forLocalModelID: modelID)
        return .init(title: data.title, tone: badgeTone(for: data.state))
    }

    static func localGrammarConfidenceBadge(forModelID modelID: String) -> AgentBlueprintModelBadge {
        let data = RuntimeRouter.agentCapabilityBadgeData(forLocalModelID: modelID)
        switch data.state {
        case .honest:
            return .init(title: "STRICT-GRAMMAR", tone: .good)
        case .experimental:
            return .init(title: "SOFT-GUIDED", tone: .warning)
        case .off:
            return .init(title: "NO-TOOLS", tone: .disabled)
        }
    }

    static func localStrictGrammarStatus(forModelID modelID: String) -> String {
        switch RuntimeRouter.agentCapabilityBadgeData(forLocalModelID: modelID).state {
        case .honest:
            return "enabled"
        case .experimental:
            return "soft_guidance"
        case .off:
            return "no_tools"
        }
    }

    private static func badgeTone(for state: RuntimeAgentCapabilityState) -> AgentBlueprintModelBadgeTone {
        switch state {
        case .honest:
            return .good
        case .experimental:
            return .warning
        case .off:
            return .disabled
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

    var runtimeContractFields: [AgentBlueprintRuntimeContractField] {
        let metadata = Self.runtimeMetadata(fromCommandCenterQuery: commandCenterQuery)
        let cloudGuard = metadata["agent_blueprint_cloud_guard"] ?? "not_applicable"
        let networkPolicy = metadata["agent_blueprint_network_policy"] ?? "not_applicable"

        return [
            AgentBlueprintRuntimeContractField(
                label: "Execution",
                value: model.executionPolicy,
                tone: model.executionPolicy == "local_only" ? .good : .warning
            ),
            AgentBlueprintRuntimeContractField(
                label: "Cloud guard",
                value: cloudGuard,
                tone: cloudGuard == "zero_cloud_required" ? .good : .warning
            ),
            AgentBlueprintRuntimeContractField(
                label: "Network",
                value: networkPolicy,
                tone: networkPolicy == "local_runtime_only" ? .good : .warning
            ),
            AgentBlueprintRuntimeContractField(
                label: "Strict grammar",
                value: model.strictGrammarStatus,
                tone: model.strictGrammarStatus == "enabled" ? .good : .neutral
            ),
            AgentBlueprintRuntimeContractField(
                label: "Grammar",
                value: model.grammarProfile,
                tone: model.grammarProfile == "provider_native" ? .warning : .neutral
            ),
            AgentBlueprintRuntimeContractField(
                label: "Artifact",
                value: Self.artifactContract,
                tone: .good
            ),
        ]
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
        if requiresLocalOnlyRuntime(metadata: metadata) {
            metadata["agent_blueprint_cloud_guard"] = "zero_cloud_required"
            metadata["agent_blueprint_network_policy"] = "local_runtime_only"
        } else if allowsExplicitCloudEscalation(metadata: metadata) {
            metadata["agent_blueprint_cloud_guard"] = "explicit_cloud_allowed"
            metadata["agent_blueprint_network_policy"] = "user_selected_cloud"
        }
        return metadata
    }

    static func requiresLocalOnlyRuntime(metadata: [String: String]) -> Bool {
        normalizedRuntimeField(metadata["agent_blueprint_execution_policy"]) == "local_only"
            && normalizedRuntimeField(metadata["agent_blueprint_cloud_escalation"]) == "disabled"
    }

    static func allowsExplicitCloudEscalation(metadata: [String: String]) -> Bool {
        normalizedRuntimeField(metadata["agent_blueprint_execution_policy"]) == "cloud_escalation_explicit"
            && normalizedRuntimeField(metadata["agent_blueprint_cloud_escalation"]) == "explicit_model_selection"
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

    private static func normalizedRuntimeField(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

nonisolated struct AgentBlueprintRunRecord: Codable, Sendable, Equatable, Identifiable {
    let packet: AgentMissionPacket
    let queuedAt: Date

    var id: String { packet.id }

    func replaySnapshot(
        from events: [AgentProvenanceEvent],
        packets: [AnswerPacket] = []
    ) -> AgentBlueprintRunReplaySnapshot? {
        let missionEvents = events.filter { event in
            event.metadata["mission_packet_id"] == packet.id
        }
        guard let latestMissionEvent = missionEvents.max(by: Self.eventSortAscending) else {
            return nil
        }

        let runID = latestMissionEvent.runID
        let runEvents = events
            .filter { $0.runID == runID }
            .sorted(by: Self.eventSortAscending)
        let latestEvent = runEvents.last ?? latestMissionEvent
        let answerPacketID = Self.latestAnswerPacketID(in: runEvents)
        let answerPacketDisplay = Self.answerPacketDisplayFields(
            in: runEvents,
            packets: packets,
            answerPacketID: answerPacketID
        )
        return AgentBlueprintRunReplaySnapshot(
            runID: runID,
            eventCount: runEvents.count,
            latestEventKind: latestEvent.kind.rawValue,
            latestOccurredAt: Date(timeIntervalSince1970: Double(latestEvent.occurredAtMs) / 1_000),
            answerPacketId: answerPacketID,
            answerPacketUILabel: answerPacketDisplay.uiLabel,
            answerPacketAttentionMode: answerPacketDisplay.attentionMode,
            answerPacketInterruptBucket: answerPacketDisplay.interruptBucket,
            replayStatus: Self.replayStatus(
                runID: runID,
                runEvents: runEvents,
                answerPacketID: answerPacketID,
                packets: packets
            )
        )
    }

    private static func eventSortAscending(
        _ lhs: AgentProvenanceEvent,
        _ rhs: AgentProvenanceEvent
    ) -> Bool {
        if lhs.occurredAtMs != rhs.occurredAtMs {
            return lhs.occurredAtMs < rhs.occurredAtMs
        }
        if lhs.sequence != rhs.sequence {
            return lhs.sequence < rhs.sequence
        }
        return lhs.eventID < rhs.eventID
    }

    private static func latestAnswerPacketID(in events: [AgentProvenanceEvent]) -> String? {
        events.reversed().compactMap { clean($0.metadata["answer_packet_id"]) }.first
    }

    private static func answerPacketDisplayFields(
        in events: [AgentProvenanceEvent],
        packets: [AnswerPacket],
        answerPacketID: String?
    ) -> (uiLabel: String?, attentionMode: String?, interruptBucket: String?) {
        let matchingPacket = answerPacketID.flatMap { id in
            packets.first { $0.id == id }
        }
        let matchingEvents = events.reversed().filter { event in
            guard let answerPacketID else { return true }
            return clean(event.metadata["answer_packet_id"]) == answerPacketID
        }
        return (
            uiLabel: firstMetadataValue("answer_packet_ui_label", in: matchingEvents)
                ?? matchingPacket?.uiLabel.rawValue,
            attentionMode: firstMetadataValue("answer_packet_attention_mode", in: matchingEvents)
                ?? matchingPacket?.attentionMode.rawValue,
            interruptBucket: firstMetadataValue("answer_packet_interrupt_bucket", in: matchingEvents)
                ?? matchingPacket?.interruptBucket.rawValue
        )
    }

    private static func firstMetadataValue(
        _ key: String,
        in events: [AgentProvenanceEvent]
    ) -> String? {
        events.compactMap { clean($0.metadata[key]) }.first
    }

    private static func replayStatus(
        runID: String,
        runEvents: [AgentProvenanceEvent],
        answerPacketID: String?,
        packets: [AnswerPacket]
    ) -> AgentBlueprintReplayStatus {
        if runEvents.contains(where: isFailedTerminalRun) {
            return .failed
        }
        guard let answerPacketID else {
            return .missingPacket
        }
        guard let packet = packets.first(where: { $0.id == answerPacketID }) else {
            return .missingPacket
        }
        guard packet.witnessedStateRef.contains("run_event_log:\(runID)") else {
            return .invalidProof
        }
        let hasStart = runEvents.contains { $0.kind == .runStarted }
        let hasCompletion = runEvents.contains { $0.kind == .runCompleted }
        guard hasStart && hasCompletion else {
            return .missingEvent
        }
        return .verified
    }

    private static func isFailedTerminalRun(_ event: AgentProvenanceEvent) -> Bool {
        guard event.kind == .runCompleted else { return false }
        let outcome = clean(event.metadata["outcome"])?.lowercased()
        let stopReason = clean(event.metadata["stop_reason"])?.lowercased()
        return outcome == "failed"
            || stopReason == "error"
            || stopReason == "failed"
            || stopReason == "cancelled"
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

nonisolated enum AgentBlueprintReplayStatus: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case verified
    case missingEvent = "missing_event"
    case missingPacket = "missing_packet"
    case invalidProof = "invalid_proof"
    case failed

    var displayName: String {
        switch self {
        case .verified:
            "Replay verified"
        case .missingEvent:
            "Missing event"
        case .missingPacket:
            "Missing packet"
        case .invalidProof:
            "Invalid proof"
        case .failed:
            "Run failed"
        }
    }

    var summaryLabel: String {
        switch self {
        case .verified:
            "replay verified"
        case .missingEvent:
            "missing event"
        case .missingPacket:
            "missing packet"
        case .invalidProof:
            "invalid proof"
        case .failed:
            "failed"
        }
    }
}

nonisolated struct AgentBlueprintRunReplaySnapshot: Sendable, Equatable {
    let runID: String
    let eventCount: Int
    let latestEventKind: String
    let latestOccurredAt: Date
    let answerPacketId: String?
    let answerPacketUILabel: String?
    let answerPacketAttentionMode: String?
    let answerPacketInterruptBucket: String?
    let replayStatus: AgentBlueprintReplayStatus

    var shortRunID: String {
        String(runID.prefix(12))
    }

    var summary: String {
        "\(eventCount) events · \(replayStatus.summaryLabel)"
    }

    var answerPacketReplayDetail: String? {
        let parts = [
            answerPacketUILabel,
            answerPacketAttentionMode,
            answerPacketInterruptBucket
        ].compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }
}

nonisolated enum AgentBlueprintRunEventProjectionError: Error, Equatable, Sendable {
    case answerPacketMismatch(expected: String?, actual: String)
    case invalidAnswerPacketProof(runID: String, packetID: String)
}

nonisolated enum AgentBlueprintRunEventProjector {
    static func events(
        packet: AgentMissionPacket,
        log: RunEventLog,
        answerPacket: AnswerPacket
    ) throws -> [AgentProvenanceEvent] {
        if log.answerPacketId != answerPacket.id {
            throw AgentBlueprintRunEventProjectionError.answerPacketMismatch(
                expected: log.answerPacketId,
                actual: answerPacket.id
            )
        }
        guard answerPacket.witnessedStateRef.contains("run_event_log:\(log.missionId)") else {
            throw AgentBlueprintRunEventProjectionError.invalidAnswerPacketProof(
                runID: log.missionId,
                packetID: answerPacket.id
            )
        }

        let baseMs = timestampMs(packet.createdAt)
        var projected: [AgentProvenanceEvent] = []
        projected.reserveCapacity(log.events.count)
        for (index, event) in log.events.enumerated() {
            projected.append(provenanceEvent(
                packet: packet,
                log: log,
                answerPacket: answerPacket,
                event: event,
                index: index,
                baseMs: baseMs
            ))
        }
        return projected
    }

    private static func provenanceEvent(
        packet: AgentMissionPacket,
        log: RunEventLog,
        answerPacket: AnswerPacket,
        event: SystemGAgentEvent,
        index: Int,
        baseMs: Int64
    ) -> AgentProvenanceEvent {
        var metadata = baseMetadata(packet: packet, log: log, answerPacket: answerPacket, event: event)
        let kind: AgentProvenanceEventKind
        let tool: AgentToolProvenance?

        switch event {
        case .planStart(let turnId, let plan):
            kind = .runStarted
            tool = nil
            metadata["system_g_turn_id"] = turnId
            metadata["plan"] = plan
        case .tokenChunk(let turnId, let text):
            kind = .summaryDelta
            tool = nil
            metadata["system_g_turn_id"] = turnId
            metadata["token_delta_chars"] = "\(text.count)"
        case .localModelHandoff(let turnId, let modelID, let providerPolicyJSON):
            kind = .routerDecision
            tool = nil
            metadata["system_g_turn_id"] = turnId
            metadata["provider"] = "local_mlx"
            metadata["model_id"] = modelID
            metadata["provider_policy_json"] = providerPolicyJSON
        case .complete(let turnId, let answerPacketId):
            kind = .runCompleted
            tool = nil
            metadata["system_g_turn_id"] = turnId
            metadata["answer_packet_id"] = answerPacketId
            metadata["outcome"] = "completed"
            metadata["stop_reason"] = "end_turn"
        case .failed(let turnId, let error):
            kind = .runCompleted
            tool = nil
            metadata["system_g_turn_id"] = turnId
            metadata["outcome"] = "failed"
            metadata["stop_reason"] = "error"
            metadata["error"] = error
        case .toolStart(let turnId, let toolName, let argsJson):
            kind = .toolCallStarted
            let callID = toolCallID(log: log, index: index, toolName: toolName)
            tool = AgentToolProvenance(
                toolCallID: callID,
                toolName: toolName,
                argumentsJSON: argsJson,
                resultJSON: nil,
                durationMs: nil,
                approvalID: nil,
                status: .started
            )
            metadata["system_g_turn_id"] = turnId
            metadata["tool_call_id"] = callID
        case .toolEnd(let turnId, let toolName, let ok, let outputJson):
            kind = ok ? .toolCallCompleted : .toolCallFailed
            let callID = toolCallID(log: log, index: index, toolName: toolName)
            tool = AgentToolProvenance(
                toolCallID: callID,
                toolName: toolName,
                argumentsJSON: "{}",
                resultJSON: outputJson,
                durationMs: nil,
                approvalID: nil,
                status: ok ? .completed : .failed,
                errorMessage: ok ? nil : outputJson
            )
            metadata["system_g_turn_id"] = turnId
            metadata["tool_call_id"] = callID
        }

        return AgentProvenanceEvent(
            eventID: "system-g-\(log.missionId)-\(index)",
            runID: log.missionId,
            traceID: "mission_packet:\(packet.id)",
            sequence: UInt64(index),
            kind: kind,
            actor: .agent(id: "system_g", modelID: packet.model.routingID),
            occurredAtMs: safeOffset(baseMs: baseMs, offset: index),
            tool: tool,
            metadata: metadata
        )
    }

    private static func baseMetadata(
        packet: AgentMissionPacket,
        log: RunEventLog,
        answerPacket: AnswerPacket,
        event: SystemGAgentEvent
    ) -> [String: String] {
        var metadata = AgentMissionPacket.runtimeMetadata(
            fromCommandCenterQuery: packet.commandCenterQuery
        )
        metadata["source"] = "agent_blueprint_system_g_replay"
        metadata["system_g_run_id"] = log.missionId
        metadata["system_g_event_kind"] = systemGKind(event)
        metadata["run_event_log_event_count"] = "\(log.events.count)"
        metadata["deterministic_replay"] = "verified"
        metadata["answer_packet_id"] = answerPacket.id
        metadata["answer_packet_ui_label"] = answerPacket.uiLabel.rawValue
        metadata["answer_packet_attention_mode"] = answerPacket.attentionMode.rawValue
        metadata["answer_packet_interrupt_bucket"] = answerPacket.interruptBucket.rawValue
        metadata["answer_packet_replay_status"] = AgentBlueprintReplayStatus.verified.rawValue
        metadata["answer_packet_witness"] = answerPacket.witnessedStateRef
        return metadata
    }

    private static func systemGKind(_ event: SystemGAgentEvent) -> String {
        switch event {
        case .planStart:
            "plan_start"
        case .toolStart:
            "tool_start"
        case .toolEnd:
            "tool_end"
        case .tokenChunk:
            "token_chunk"
        case .localModelHandoff:
            "local_model_handoff"
        case .complete:
            "complete"
        case .failed:
            "failed"
        }
    }

    private static func toolCallID(log: RunEventLog, index: Int, toolName: String) -> String {
        let cleaned = toolName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        return "system-g-\(log.missionId)-tool-\(index)-\(cleaned)"
    }

    private static func timestampMs(_ date: Date) -> Int64 {
        let ms = date.timeIntervalSince1970 * 1_000
        guard ms.isFinite,
              ms >= Double(Int64.min),
              ms <= Double(Int64.max) else {
            return 0
        }
        return Int64(ms.rounded())
    }

    private static func safeOffset(baseMs: Int64, offset: Int) -> Int64 {
        let boundedOffset = Int64(max(offset, 0))
        guard baseMs <= Int64.max - boundedOffset else {
            return baseMs
        }
        return baseMs + boundedOffset
    }
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

enum AgentBlueprintBrainResolver {
    static func modelChoice(for brain: ACCBrainSelection?) -> AgentBlueprintModelChoice {
        guard let brain else { return .autoConstellation }
        switch brain {
        case .local(let modelID, let displayName, _, _, _):
            return .local(modelID: modelID, displayName: displayName)
        case .cloud(let provider):
            return .cloud(provider: provider.rawValue, displayName: provider.displayName)
        case .appleIntelligence:
            return .appleIntelligence
        }
    }

    static func brainSelection(
        for choice: AgentBlueprintModelChoice,
        availableBrains: [ACCBrainSelection]
    ) -> ACCBrainSelection? {
        switch choice {
        case .autoConstellation:
            return nil
        case .local(let modelID, _):
            return availableBrains.first { brain in
                brain.id == "local:\(modelID)"
            } ?? availableBrains.first { brain in
                brain.id.lowercased() == "local:\(modelID)".lowercased()
            }
        case .cloud(let provider, _):
            return availableBrains.first { brain in
                brain.id == "cloud:\(provider)"
            } ?? availableBrains.first { brain in
                brain.id.lowercased() == "cloud:\(provider)".lowercased()
            }
        case .appleIntelligence:
            return availableBrains.first { $0.id == "apple" }
        }
    }
}
