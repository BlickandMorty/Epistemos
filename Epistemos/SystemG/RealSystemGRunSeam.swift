// RealSystemGRunSeam.swift
//
// Terminal C / P5 (2026-05-23) — replaces `StubSystemGRunSeam` with a
// real wire path that round-trips
// `AgentMissionPacket → SystemGAgentEvent stream → RunEventLog`
// through the Rust runtime via the UniFFI exports
// `systemGStartRunJson` + `systemGDrainEventsJson` (bridge.rs).
//
// Polling strategy: the seam encodes the mission, starts the run,
// then loops on `drain_events` until a terminal event arrives or the
// wall-clock timeout trips. Between polls it yields the task with a
// short `Task.sleep` so it does not pin the actor's queue. The Rust
// side is the source of truth for the event sequence + ordering; the
// Swift side only buffers + decodes.
//
// Registry wiring lives in `Epistemos/App/AppBootstrap.swift`:
//     SystemGRunSeamRegistry.shared.register(
//         RealSystemGRunSeam(localModelClient: localLLMClient)
//     )
// runs at app bootstrap so any production call to
// `SystemGRunSeamRegistry.shared.current().run(mission:)` reaches
// the real path. When the mission selects a local / auto model and the
// bootstrap supplies a local client, the seam streams the live local
// model into RunEventLog. Otherwise it falls back to the Rust V1
// deterministic witness seam. The `StubSystemGRunSeam` remains the default-default
// so tests + DEBUG callers see honest `notWired` rejection until
// they explicitly register.

import Foundation

/// Production implementation of `SystemGRunSeam`. Encodes the
/// supplied `AgentMissionPacket` as a `MissionPacket`-shaped JSON
/// payload, starts a Rust-side run, and polls `drain_events` until
/// a terminal `.complete` or `.failed` event arrives. Honors
/// cooperative cancellation: every poll iteration calls
/// `Task.checkCancellation()` so a swiftui-cancelled mission stops
/// promptly instead of waiting for the deadline.
nonisolated struct RealSystemGRunSeam: SystemGRunSeam {
    private final class LocalProviderBox: @unchecked Sendable {
        let client: any LocalConfigurableLLMClient

        init(client: any LocalConfigurableLLMClient) {
            self.client = client
        }
    }

    /// Per-poll sleep between `drain_events` calls. Short enough that
    /// the V1 deterministic runner (which emits the whole event
    /// sequence inside `start_run`) round-trips in <10 ms; long enough
    /// that a future async executor isn't hammered.
    static let pollIntervalNanos: UInt64 = 5_000_000  // 5 ms

    /// Wall-clock budget for a single mission. Mirrors the Rust-side
    /// `BudgetSpec.max_wall_ms` (currently 5_000 ms) plus headroom
    /// for FFI marshalling. If a mission exceeds this, the seam
    /// throws `SystemGRunSeamError.ffi("timeout: …")` rather than
    /// hanging the caller.
    static let runTimeoutSeconds: TimeInterval = 30.0

    private let localProvider: LocalProviderBox?
    private let localMaxTokens: Int

    init(
        localModelClient: (any LocalConfigurableLLMClient)? = nil,
        localMaxTokens: Int = 2_048
    ) {
        self.localProvider = localModelClient.map(LocalProviderBox.init(client:))
        self.localMaxTokens = localMaxTokens
    }

    func run(mission: AgentMissionPacket) async throws -> RunEventLog {
        let payload = MissionPacketWire(
            blueprintID: mission.blueprintName,
            userPrompt: mission.objective,
            vaultScope: mission.scope.rawValue
        )
        let missionJson = try Self.encodeJSON(payload, label: "mission")

        if let localProvider,
           let route = Self.localRoute(for: mission) {
            return try await runLocalModelMission(
                mission,
                missionJson: missionJson,
                route: route,
                localProvider: localProvider
            )
        }

        try Task.checkCancellation()

        let runId: String
        do {
            runId = try systemGStartRunJson(missionJson: missionJson)
        } catch {
            throw SystemGRunSeamError.ffi("start_run: \(error)")
        }

        var log = RunEventLog(missionId: runId)
        let deadline = Date().addingTimeInterval(Self.runTimeoutSeconds)
        let decoder = JSONDecoder()

        while Date() < deadline {
            try Task.checkCancellation()
            let rawJson: String
            do {
                rawJson = try systemGDrainEventsJson(runId: runId)
            } catch {
                throw SystemGRunSeamError.ffi("drain_events(run=\(runId)): \(error)")
            }
            guard let data = rawJson.data(using: .utf8) else {
                throw SystemGRunSeamError.decode("drain JSON is not valid utf-8 (run=\(runId))")
            }
            let batch: [SystemGAgentEvent]
            do {
                batch = try decoder.decode([SystemGAgentEvent].self, from: data)
            } catch {
                throw SystemGRunSeamError.decode("decode events (run=\(runId)): \(error)")
            }
            for event in batch {
                log.append(event)
                if event.isTerminal {
                    if case .complete = event {
                        let packet = try RunEventLogReplayProjection.answerPacket(from: log)
                        await AnswerPacketEmitter.shared.emit(packet)
                    }
                    return log
                }
            }
            try await Task.sleep(nanoseconds: Self.pollIntervalNanos)
        }
        throw SystemGRunSeamError.ffi(
            "timeout: no terminal event within \(Self.runTimeoutSeconds)s (run=\(runId))"
        )
    }

    private func runLocalModelMission(
        _ mission: AgentMissionPacket,
        missionJson: String,
        route: LocalRoute,
        localProvider: LocalProviderBox
    ) async throws -> RunEventLog {
        let modelLabel = route.modelID ?? "auto_constellation"
        let providerPolicyJson = try Self.localProviderPolicyJSON(modelID: modelLabel)

        try Task.checkCancellation()

        let runID: String
        do {
            runID = try systemGStartRunWithProviderJson(
                missionJson: missionJson,
                providerPolicyJson: providerPolicyJson
            )
        } catch {
            throw SystemGRunSeamError.ffi("start_run_with_provider: \(error)")
        }

        var log = RunEventLog(missionId: runID)
        let deadline = Date().addingTimeInterval(Self.runTimeoutSeconds)
        let decoder = JSONDecoder()

        while Date() < deadline {
            try Task.checkCancellation()
            let rawJson: String
            do {
                rawJson = try systemGDrainEventsJson(runId: runID)
            } catch {
                throw SystemGRunSeamError.ffi("drain_events(run=\(runID)): \(error)")
            }
            guard let data = rawJson.data(using: .utf8) else {
                throw SystemGRunSeamError.decode("drain JSON is not valid utf-8 (run=\(runID))")
            }
            let batch: [SystemGAgentEvent]
            do {
                batch = try decoder.decode([SystemGAgentEvent].self, from: data)
            } catch {
                throw SystemGRunSeamError.decode("decode provider events (run=\(runID)): \(error)")
            }
            for event in batch {
                log.append(event)
                switch event {
                case .localModelHandoff(let turnID, let handoffModelID, _):
                    return try await completeLocalModelHandoff(
                        mission,
                        route: route,
                        localProvider: localProvider,
                        runID: runID,
                        turnID: turnID,
                        modelLabel: handoffModelID,
                        log: log
                    )
                case .failed(_, let error):
                    throw SystemGRunSeamError.ffi(error)
                case .complete:
                    let packet = try RunEventLogReplayProjection.answerPacket(from: log)
                    await AnswerPacketEmitter.shared.emit(packet)
                    return log
                case .planStart, .toolStart, .toolEnd, .tokenChunk:
                    break
                }
            }
            try await Task.sleep(nanoseconds: Self.pollIntervalNanos)
        }
        throw SystemGRunSeamError.ffi(
            "timeout: no local_model_handoff within \(Self.runTimeoutSeconds)s (run=\(runID))"
        )
    }

    private func completeLocalModelHandoff(
        _ mission: AgentMissionPacket,
        route: LocalRoute,
        localProvider: LocalProviderBox,
        runID: String,
        turnID: String,
        modelLabel: String,
        log initialLog: RunEventLog
    ) async throws -> RunEventLog {
        var log = initialLog

        let systemPrompt = Self.localSystemPrompt(for: mission, route: route)
        let prompt = mission.commandCenterQuery
        let stream = await MainActor.run {
            localProvider.client.stream(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: localMaxTokens,
                reasoningMode: route.reasoningMode,
                modelID: route.modelID,
                steeringHintsJSON: nil
            )
        }

        var output = ""
        for try await chunk in stream {
            guard !chunk.isEmpty else { continue }
            output += chunk
            log.append(.tokenChunk(turnId: turnID, text: chunk))
        }

        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let fallback = try await Task { @MainActor in
                try await localProvider.client.generate(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: localMaxTokens,
                    reasoningMode: route.reasoningMode,
                    modelID: route.modelID,
                    steeringHintsJSON: nil
                )
            }.value
            let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedFallback.isEmpty else {
                throw SystemGRunSeamError.ffi(
                    "local_model_empty_output: model_id=\(modelLabel) produced no visible tokens"
                )
            }
            output = fallback
            log.append(.tokenChunk(turnId: turnID, text: fallback))
        }

        let packetID = "system-g-local-\(mission.id)"
        log.append(.complete(turnId: turnID, answerPacketId: packetID))
        await AnswerPacketEmitter.shared.emit(
            Self.localAnswerPacket(
                id: packetID,
                mission: mission,
                runID: runID,
                modelLabel: modelLabel,
                eventCount: log.events.count
            )
        )
        return log
    }

    private struct LocalRoute: Sendable {
        let modelID: String?
        let reasoningMode: LocalReasoningMode
    }

    private static func localRoute(for mission: AgentMissionPacket) -> LocalRoute? {
        switch mission.model {
        case .autoConstellation:
            return LocalRoute(modelID: nil, reasoningMode: .fast)
        case .local(let modelID, _):
            return LocalRoute(modelID: modelID, reasoningMode: .fast)
        case .cloud, .appleIntelligence:
            return nil
        }
    }

    private static func localSystemPrompt(
        for mission: AgentMissionPacket,
        route: LocalRoute
    ) -> String {
        [
            "You are System G inside Epistemos.",
            "Run the user's AgentBlueprint mission locally.",
            "Do not claim cloud execution.",
            "Emit a grounded answer that can be replayed from RunEventLog.",
            "Agent: \(mission.blueprintName)",
            "Role: \(mission.role)",
            "Model route: \(route.modelID ?? "auto_constellation")",
            "Scope: \(mission.scope.rawValue)",
            "Approval: \(mission.approvalMode.rawValue)",
            "Tools requested: \(mission.toolNames.joined(separator: ", "))",
        ].joined(separator: "\n")
    }

    private static func localProviderPolicyJSON(modelID: String) throws -> String {
        try encodeJSON(
            LocalProviderPolicyWire(kind: localProviderKind(for: modelID), modelID: modelID),
            label: "provider policy"
        )
    }

    private static func localProviderKind(for modelID: String) -> LocalProviderPolicyWire.Kind {
        let lowercased = modelID.lowercased()
        return lowercased.contains("gguf") ? .localGguf : .localMlx
    }

    private static func encodeJSON<T: Encodable>(_ value: T, label: String) throws -> String {
        let encoder = JSONEncoder()
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw SystemGRunSeamError.decode("encode \(label): \(error)")
        }
        guard let json = String(data: data, encoding: .utf8) else {
            throw SystemGRunSeamError.decode("\(label) JSON is not valid utf-8")
        }
        return json
    }

    private static func localAnswerPacket(
        id: String,
        mission: AgentMissionPacket,
        runID: String,
        modelLabel: String,
        eventCount: Int
    ) -> AnswerPacket {
        let claim = Claim(
            id: "claim-\(id)-local-model",
            text: "System G executed AgentBlueprint mission \(mission.id) through the local model route \(modelLabel) and reconstructed this AnswerPacket from RunEventLog \(runID).",
            status: .active,
            createdAtMs: 0,
            kind: .empirical
        )
        return AnswerPacket(
            id: id,
            claims: [claim],
            residencySignals: [.neutral],
            uiLabel: .plausibleButUnverified,
            attentionMode: .unavailable,
            interruptBucket: .unavailable,
            witnessedStateRef: "system_g_local_model:\(runID);model_id:\(modelLabel);events:\(eventCount)",
            semanticDeltaRef: "system_g_local_model:\(mission.id)",
            mutationEnvelopeRef: "run_event_log:\(runID)"
        )
    }

    // MARK: - Wire shape
    //
    // Mirrors `agent_core::agent_runtime_v2::mission::MissionPacket`.
    // CodingKeys map Swift camelCase to the snake_case wire shape the
    // Rust serde derive expects.
    private struct MissionPacketWire: Codable, Sendable {
        let blueprintID: String
        let userPrompt: String
        let vaultScope: String

        enum CodingKeys: String, CodingKey {
            case blueprintID = "blueprint_id"
            case userPrompt = "user_prompt"
            case vaultScope = "vault_scope"
        }
    }

    private struct LocalProviderPolicyWire: Codable, Sendable {
        enum Kind: String, Codable, Sendable {
            case localMlx = "local_mlx"
            case localGguf = "local_gguf"
        }

        let kind: Kind
        let modelID: String

        enum CodingKeys: String, CodingKey {
            case kind
            case modelID = "model_id"
        }
    }
}

// MARK: - W-16 replay first step
//
// Deterministic textual replay of a RunEventLog. Same log → byte-equal
// output. The W-16 SwiftUI replay surface will render a richer view;
// this method is the minimum honest replay primitive that proves the
// pipeline reconstructs the run from RunEventLog alone (no provider
// re-call, no clock dependency, no random IDs).

extension RunEventLog {
    /// Produce a single-line-per-event replay of the log. Format is
    /// deterministic and stable for log greps / audit diffs. Lines
    /// are formatted as:
    ///
    ///     [turnId] kind detail
    ///
    /// where `detail` is the variant payload rendered without
    /// per-call randomness. Two runs that produced byte-equal logs
    /// produce byte-equal `replayDescription` outputs.
    var replayDescription: String {
        var lines: [String] = []
        lines.reserveCapacity(events.count + 1)
        lines.append("RunEventLog mission=\(missionId) events=\(events.count)")
        for event in events {
            lines.append("  " + describe(event))
        }
        return lines.joined(separator: "\n")
    }

    private func describe(_ event: SystemGAgentEvent) -> String {
        switch event {
        case .planStart(let turnId, let plan):
            return "[\(turnId)] plan_start plan=\(plan)"
        case .toolStart(let turnId, let toolName, let argsJson):
            return "[\(turnId)] tool_start tool=\(toolName) args=\(argsJson)"
        case .toolEnd(let turnId, let toolName, let ok, let outputJson):
            return "[\(turnId)] tool_end tool=\(toolName) ok=\(ok) output=\(outputJson)"
        case .tokenChunk(let turnId, let text):
            return "[\(turnId)] token_chunk text=\(text)"
        case .localModelHandoff(let turnId, let modelID, let providerPolicyJSON):
            return "[\(turnId)] local_model_handoff model_id=\(modelID) provider_policy_json=\(providerPolicyJSON)"
        case .complete(let turnId, let answerPacketId):
            return "[\(turnId)] complete answer_packet_id=\(answerPacketId)"
        case .failed(let turnId, let error):
            return "[\(turnId)] failed error=\(error)"
        }
    }
}
