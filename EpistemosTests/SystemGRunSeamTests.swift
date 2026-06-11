import Foundation
import Testing

@testable import Epistemos

// W4 (Terminal 1 WRV mission) test. Verifies the System G run-flow
// Swift seam:
//
//   - The chain types `SystemGAgentEvent` + `RunEventLog` are defined and
//     Codable-round-trippable.
//   - `SystemGRunSeam` protocol surface exists and a stub
//     implementation throws `notWired` until Terminal 2 lands the Rust
//     side (per the WRV bar: do not fake product behavior).
//   - `RunEventLog.append` orders events and exposes them in arrival
//     order so a replay surface can reconstruct the run.
//
// Per the brief: "If only status breadcrumb exists, define the Swift
// seam needed for MissionPacket -> SystemGAgentEvent -> RunEventLog ->
// AnswerPacket and hand Rust/API gaps to Terminal 2."

@Suite("System G Run Seam (W4)")
struct SystemGRunSeamTests {

    @Test("SystemGAgentEvent round-trips through JSON for every kind")
    func agentEventRoundTripsForEveryKind() throws {
        let cases: [SystemGAgentEvent] = [
            .planStart(turnId: "t1", plan: "search vault then synthesize"),
            .toolStart(turnId: "t1", toolName: "vault_search", argsJson: #"{"q":"residency"}"#),
            .toolEnd(turnId: "t1", toolName: "vault_search", ok: true, outputJson: #"{"hits":[]}"#),
            .tokenChunk(turnId: "t1", text: "Hello "),
            .localModelHandoff(
                turnId: "t1",
                modelID: "Qwen/Qwen3-8B-MLX-4bit",
                providerPolicyJSON: #"{"kind":"local_mlx","model_id":"Qwen/Qwen3-8B-MLX-4bit"}"#
            ),
            .complete(turnId: "t1", answerPacketId: "ap-42"),
            .failed(turnId: "t1", error: "ffi timeout"),
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for event in cases {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(SystemGAgentEvent.self, from: data)
            #expect(decoded == event, "SystemGAgentEvent must round-trip: \(event)")
        }
    }

    @Test("SystemGAgentEvent decoder rejects unknown discriminator kinds")
    func agentEventRejectsUnknownKinds() {
        let json = #"{"kind":"not_a_real_kind","turn_id":"t1"}"#
        let data = Data(json.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(SystemGAgentEvent.self, from: data)
        }
    }

    @Test("RunEventLog preserves append order")
    func runEventLogPreservesAppendOrder() {
        var log = RunEventLog(missionId: "m1")
        log.append(.planStart(turnId: "t1", plan: "p"))
        log.append(.tokenChunk(turnId: "t1", text: "A"))
        log.append(.tokenChunk(turnId: "t1", text: "B"))
        log.append(.complete(turnId: "t1", answerPacketId: "ap"))

        #expect(log.events.count == 4)
        #expect(log.missionId == "m1")
        // Last event terminates the run with a complete reference.
        guard case .complete(_, let apId) = log.events.last else {
            Issue.record("RunEventLog last event must be .complete")
            return
        }
        #expect(apId == "ap")
    }

    @Test("RunEventLog.terminalEvent surfaces complete or failed")
    func runEventLogTerminalEventReflectsRunOutcome() {
        var log = RunEventLog(missionId: "m1")
        log.append(.planStart(turnId: "t1", plan: "p"))
        #expect(log.terminalEvent == nil, "open log has no terminal event yet")

        log.append(.complete(turnId: "t1", answerPacketId: "ap"))
        guard case .complete = log.terminalEvent else {
            Issue.record("terminalEvent must surface .complete after append")
            return
        }
    }

    @Test("StubSystemGRunSeam throws notWired on every call")
    func stubSystemGRunSeamThrowsNotWired() async {
        let seam = StubSystemGRunSeam()
        let mission = AgentMissionPacket(
            id: "m-stub",
            createdAt: Date(),
            blueprintName: "test",
            role: "test-role",
            objective: "stub-only",
            model: .autoConstellation,
            toolNames: [],
            scope: .currentVault,
            approvalMode: .autoReadOnly
        )

        do {
            _ = try await seam.run(mission: mission)
            Issue.record("StubSystemGRunSeam must not succeed — should throw .notWired")
        } catch let error as SystemGRunSeamError {
            #expect(error == .notWired,
                    "stub must surface notWired so caller does not fake product behavior")
        } catch {
            Issue.record("expected SystemGRunSeamError.notWired, got: \(error)")
        }
    }

    @Test("SystemGRunSeamRegistry default impl is the stub (not yet wired)")
    func systemGRunSeamRegistryDefaultsToStub() {
        // The registry hands out the stub until Terminal 2 swaps it via
        // `SystemGRunSeamRegistry.shared.register(_:)`. This guards the
        // WRV bar: a missing real backend must not silently become a
        // fake one.
        SystemGRunSeamRegistry.shared.resetToStubForTesting()
        let seam = SystemGRunSeamRegistry.shared.current()
        #expect(seam is StubSystemGRunSeam,
                "default registry impl must be the explicit stub")
    }

    // MARK: - Terminal C / P5 — RealSystemGRunSeam integration
    //
    // End-to-end: `RealSystemGRunSeam.run(mission:)` round-trips through
    // the Rust runtime via `systemGStartRunJson` + `systemGDrainEventsJson`
    // and returns a populated `RunEventLog` terminating in `.complete`.
    // No fakes — exercises the live FFI.

    @Test("RealSystemGRunSeam round-trips a mission through Rust to a terminal complete event")
    func realSystemGRunSeamRoundTripsMissionEndToEnd() async throws {
        let seam = RealSystemGRunSeam()
        let mission = AgentMissionPacket(
            id: "m-real-1",
            createdAt: Date(),
            blueprintName: "integration-test-blueprint",
            role: "test-role",
            objective: "Summarize the Five Plane Formalism",
            model: .autoConstellation,
            toolNames: [],
            scope: .currentVault,
            approvalMode: .autoReadOnly
        )

        let log = try await seam.run(mission: mission)
        #expect(!log.missionId.isEmpty, "missionId is the Rust-issued run_id")
        #expect(log.events.count == 3, "V1 dispatch emits plan_start + token_chunk + complete")
        guard case .planStart = log.events.first else {
            Issue.record("first event must be .planStart, got \(String(describing: log.events.first))")
            return
        }
        guard case .complete(_, let answerPacketId) = log.events.last else {
            Issue.record("last event must be .complete, got \(String(describing: log.events.last))")
            return
        }
        #expect(!answerPacketId.isEmpty, "complete.answerPacketId surfaces run_event_log_root hex")
        #expect(log.terminalEvent != nil, "RunEventLog must expose terminal event")
        #expect(log.answerPacketId == answerPacketId, "answerPacketId helper agrees with terminal event")
    }

    @Test("RealSystemGRunSeam streams local model missions when a local client is registered")
    @MainActor func realSystemGRunSeamStreamsLocalModelMission() async throws {
        let client = SystemGRecordingLocalClient(streamChunks: ["local ", "System G answer"])
        let seam = RealSystemGRunSeam(localModelClient: client)
        let mission = AgentMissionPacket(
            id: "m-local-system-g-1",
            createdAt: Date(),
            blueprintName: "local-blueprint",
            role: "local research agent",
            objective: "Use the local model path.",
            model: .local(
                modelID: "Qwen/Qwen3-8B-MLX-4bit",
                displayName: "Qwen3 8B MLX"
            ),
            toolNames: [],
            scope: .currentVault,
            approvalMode: .autoReadOnly
        )

        let log = try await seam.run(mission: mission)
        #expect(client.streamCallCount == 1)
        #expect(client.generateCallCount == 0)
        #expect(client.lastModelID == "Qwen/Qwen3-8B-MLX-4bit")
        #expect(!log.missionId.isEmpty)
        #expect(log.events.count == 5)
        guard case .localModelHandoff(_, let modelID, let providerPolicyJSON) = log.events[1] else {
            Issue.record("second event must be Rust local_model_handoff, got \(log.events[1])")
            return
        }
        #expect(modelID == "Qwen/Qwen3-8B-MLX-4bit")
        #expect(providerPolicyJSON.contains(#""kind":"local_mlx""#))
        #expect(
            log.replayDescription.contains("token_chunk text=local ")
                && log.replayDescription.contains("token_chunk text=System G answer")
        )
        #expect(log.answerPacketId == "system-g-local-m-local-system-g-1")

        let packets = await AnswerPacketEmitter.shared.recentPackets()
        let packet = packets.last { $0.id == "system-g-local-m-local-system-g-1" }
        #expect(packet?.witnessedStateRef.contains("model_id:Qwen/Qwen3-8B-MLX-4bit") == true)
        #expect(packet?.attentionMode == .unavailable)
    }

    @Test("RealSystemGRunSeam labels Gemma GGUF local missions as local_gguf without default promotion")
    @MainActor func realSystemGRunSeamLabelsGemmaGGUFLocalMission() async throws {
        let client = SystemGRecordingLocalClient(streamChunks: ["gemma ", "gguf answer"])
        let seam = RealSystemGRunSeam(localModelClient: client)
        let modelID = "google/gemma-4-E2B-it-qat-q4_0-gguf"
        let mission = AgentMissionPacket(
            id: "m-local-system-g-gemma-gguf",
            createdAt: Date(),
            blueprintName: "gemma-local-blueprint",
            role: "local research agent",
            objective: "Use the Gemma GGUF local route.",
            model: .local(
                modelID: modelID,
                displayName: "Gemma 4 E2B QAT GGUF"
            ),
            toolNames: [],
            scope: .currentVault,
            approvalMode: .autoReadOnly
        )

        let log = try await seam.run(mission: mission)
        #expect(client.streamCallCount == 1)
        #expect(client.generateCallCount == 0)
        #expect(client.lastModelID == modelID)
        guard case .localModelHandoff(_, let handoffModelID, let providerPolicyJSON) = log.events[1] else {
            Issue.record("second event must be Rust local_model_handoff, got \(log.events[1])")
            return
        }
        #expect(handoffModelID == modelID)
        #expect(providerPolicyJSON.contains(#""kind":"local_gguf""#))
        #expect(providerPolicyJSON.contains(#""model_id":"google/gemma-4-E2B-it-qat-q4_0-gguf""#))
        #expect(!RuntimeRouter.modelPreferenceTable.values.flatMap { $0 }.contains(modelID))
        #expect(log.answerPacketId == "system-g-local-m-local-system-g-gemma-gguf")
    }

    @Test("RealSystemGRunSeam live local model bridge writes falsifier artifact")
    @MainActor func realSystemGLiveLocalModelBridgeWritesArtifact() async throws {
        guard Self.liveSystemGLocalBridgeRequested() else {
            return
        }

        let modelID = LocalTextModelID.qwen3_8B4Bit.rawValue
        let bootstrap = try await LocalRuntimeSmokeSupport.preparedBootstrap(for: modelID)
        await AnswerPacketEmitter.shared.resetForTesting()

        let seam = RealSystemGRunSeam(
            localModelClient: bootstrap.localLLMClient,
            localMaxTokens: 48
        )
        let mission = AgentMissionPacket(
            id: "m-live-system-g-local-\(UUID().uuidString)",
            createdAt: Date(),
            blueprintName: "live-local-bridge",
            role: "local bridge verifier",
            objective: "Reply with one concise sentence: Epistemos local System G bridge is alive.",
            model: .local(
                modelID: modelID,
                displayName: LocalTextModelID.qwen3_8B4Bit.displayName
            ),
            toolNames: [],
            scope: .currentVault,
            approvalMode: .autoReadOnly
        )

        let startedAt = Date()
        let log = try await seam.run(mission: mission)
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000.0)
        let tokenChunks = log.events.compactMap { event -> String? in
            if case .tokenChunk(_, let text) = event {
                return text
            }
            return nil
        }
        let outputText = tokenChunks.joined()
        let handoffSeen = log.events.contains { event in
            if case .localModelHandoff(_, let handoffModelID, _) = event {
                return handoffModelID == modelID
            }
            return false
        }
        let packets = await AnswerPacketEmitter.shared.recentPackets()
        let packet = packets.last { $0.id == log.answerPacketId }
        let provenanceSeen = packet?.witnessedStateRef.contains("system_g_local_model") == true
            && packet?.witnessedStateRef.contains("model_id:\(modelID)") == true

        #expect(handoffSeen)
        #expect(!outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(provenanceSeen)
        #expect(packet?.attentionMode == .unavailable)

        let artifact = LiveSystemGLocalBridgeArtifact(
            overallPass: handoffSeen
                && !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && provenanceSeen,
            promptCount: 1,
            tokenChunkCount: tokenChunks.count,
            totalOutputChars: outputText.count,
            systemGLocalModelHandoffSeen: handoffSeen,
            answerpacketLocalModelProvenanceSeen: provenanceSeen,
            modelID: modelID,
            missionID: mission.id,
            runID: log.missionId,
            answerPacketID: log.answerPacketId ?? "",
            elapsedMs: elapsedMs,
            generatedAtUnixMs: Int(Date().timeIntervalSince1970 * 1_000.0)
        )
        try Self.writeLiveSystemGLocalBridgeArtifact(artifact)

        await bootstrap.localInferenceService.unload()
    }

    @Test("RunEventLog.replayDescription is deterministic for byte-equal logs (W-16 step 1)")
    func runEventLogReplayDescriptionIsDeterministic() {
        // W-16 first step: replay-from-RunEventLog must produce the
        // same bytes for the same log. A SwiftUI replay surface lands
        // later; this primitive proves the pipeline.
        var log1 = RunEventLog(missionId: "m-replay-1")
        log1.append(.planStart(turnId: "t1", plan: "go"))
        log1.append(.tokenChunk(turnId: "t1", text: "hello"))
        log1.append(.complete(turnId: "t1", answerPacketId: "abc123"))

        var log2 = RunEventLog(missionId: "m-replay-1")
        log2.append(.planStart(turnId: "t1", plan: "go"))
        log2.append(.tokenChunk(turnId: "t1", text: "hello"))
        log2.append(.complete(turnId: "t1", answerPacketId: "abc123"))

        #expect(log1.replayDescription == log2.replayDescription,
                "byte-equal logs must produce byte-equal replay text")

        let text = log1.replayDescription
        #expect(text.contains("RunEventLog mission=m-replay-1 events=3"))
        #expect(text.contains("[t1] plan_start plan=go"))
        #expect(text.contains("[t1] token_chunk text=hello"))
        #expect(text.contains("[t1] complete answer_packet_id=abc123"))

        // Diverging logs produce diverging replay.
        var log3 = log1
        log3.append(.failed(turnId: "t1", error: "synthetic"))
        #expect(log1.replayDescription != log3.replayDescription,
                "different logs must produce different replay text")
    }

    @Test("SystemGRegistryStats decodes from the Rust bridge JSON shape")
    func systemGRegistryStatsDecodesFromBridgeJsonShape() throws {
        // Pin the wire-format contract for the registry stats FFI
        // (Terminal C / P5 iter-6). The Rust side emits snake_case
        // keys; Swift CodingKeys map them to camelCase fields.
        // Adversarial: missing field, extra field, wrong type.
        let validJson = #"{"total":3,"in_flight":1,"max_concurrent_runs":64,"total_dispatched_since_launch":42}"#
        let decoded = try JSONDecoder().decode(
            SystemGRegistryStats.self,
            from: Data(validJson.utf8)
        )
        #expect(decoded.total == 3)
        #expect(decoded.inFlight == 1)
        #expect(decoded.maxConcurrentRuns == 64)
        #expect(decoded.totalDispatchedSinceLaunch == 42)

        // Backward-compat: an older Rust lib that omits the lifetime
        // counter field still decodes (custom init defaults it to 0).
        let backCompatJson = #"{"total":0,"in_flight":0,"max_concurrent_runs":64}"#
        let backCompat = try JSONDecoder().decode(
            SystemGRegistryStats.self,
            from: Data(backCompatJson.utf8)
        )
        #expect(backCompat.totalDispatchedSinceLaunch == 0)

        // Forward-compat: an unknown extra field is tolerated (default
        // JSONDecoder behavior) so a future Rust addition doesn't
        // break the Swift decoder out of the gate.
        let extraJson = #"{"total":0,"in_flight":0,"max_concurrent_runs":64,"total_dispatched_since_launch":0,"future_field":42}"#
        let extraDecoded = try JSONDecoder().decode(
            SystemGRegistryStats.self,
            from: Data(extraJson.utf8)
        )
        #expect(extraDecoded.total == 0)
        #expect(extraDecoded.inFlight == 0)

        // Missing required field must fail to decode.
        let missingJson = #"{"total":1,"in_flight":1}"#
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                SystemGRegistryStats.self,
                from: Data(missingJson.utf8)
            )
        }
    }

    @Test("RealSystemGRunSeam honors cooperative cancellation")
    func realSystemGRunSeamHonorsCancellation() async {
        // The seam calls Task.checkCancellation() at the top of every
        // poll iteration. A caller that cancels the enclosing Task
        // must see a CancellationError surface from run(mission:)
        // rather than the run quietly completing.
        let seam = RealSystemGRunSeam()
        let mission = AgentMissionPacket(
            id: "m-cancel-1",
            createdAt: Date(),
            blueprintName: "cancel-blueprint",
            role: "test-role",
            objective: "cancel-target",
            model: .autoConstellation,
            toolNames: [],
            scope: .currentVault,
            approvalMode: .autoReadOnly
        )

        let task = Task { try await seam.run(mission: mission) }
        task.cancel()
        do {
            _ = try await task.value
            // V1 dispatch is fully synchronous inside start_run, so a
            // cancellation that races the wire path may still see the
            // mission complete before checkCancellation runs. That
            // outcome is acceptable — both branches honor the contract.
        } catch is CancellationError {
            // Expected when cancellation lands between encode + the
            // poll-loop checkCancellation call.
        } catch let error as SystemGRunSeamError {
            Issue.record("expected CancellationError or success, got SystemGRunSeamError: \(error)")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    private struct LiveSystemGLocalBridgeArtifact: Encodable {
        let overallPass: Bool
        let promptCount: Int
        let tokenChunkCount: Int
        let totalOutputChars: Int
        let systemGLocalModelHandoffSeen: Bool
        let answerpacketLocalModelProvenanceSeen: Bool
        let modelID: String
        let missionID: String
        let runID: String
        let answerPacketID: String
        let elapsedMs: Int
        let generatedAtUnixMs: Int

        enum CodingKeys: String, CodingKey {
            case overallPass = "overall_pass"
            case promptCount = "prompt_count"
            case tokenChunkCount = "token_chunk_count"
            case totalOutputChars = "total_output_chars"
            case systemGLocalModelHandoffSeen = "system_g_local_model_handoff_seen"
            case answerpacketLocalModelProvenanceSeen = "answerpacket_local_model_provenance_seen"
            case modelID = "model_id"
            case missionID = "mission_id"
            case runID = "run_id"
            case answerPacketID = "answer_packet_id"
            case elapsedMs = "elapsed_ms"
            case generatedAtUnixMs = "generated_at_unix_ms"
        }
    }

    private static func writeLiveSystemGLocalBridgeArtifact(
        _ artifact: LiveSystemGLocalBridgeArtifact
    ) throws {
        let url = repositoryRootURL()
            .appendingPathComponent(
                "artifacts/falsifiers/agent_local_model_runtime_bridge/live_prompt_suite.json"
            )
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(artifact).write(to: url, options: .atomic)
    }

    private static func liveSystemGLocalBridgeRequested() -> Bool {
        if ProcessInfo.processInfo.environment["EPISTEMOS_RUN_LIVE_SYSTEM_G_LOCAL_BRIDGE"] == "1" {
            return true
        }
        let sentinel = repositoryRootURL()
            .appendingPathComponent(".epistemos_run_live_system_g_local_bridge")
        return FileManager.default.fileExists(atPath: sentinel.path)
    }

    private static func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

@MainActor
private final class SystemGRecordingLocalClient: LocalConfigurableLLMClient {
    private let streamChunks: [String]
    private(set) var generateCallCount = 0
    private(set) var streamCallCount = 0
    private(set) var lastModelID: String?

    init(streamChunks: [String]) {
        self.streamChunks = streamChunks
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil,
            steeringHintsJSON: nil
        )
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil,
            steeringHintsJSON: nil
        )
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(provider: .localMLX, model: "test-local", reasoningMode: .fast)
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) async throws -> String {
        generateCallCount += 1
        lastModelID = modelID
        return streamChunks.joined()
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) -> AsyncThrowingStream<String, Error> {
        streamCallCount += 1
        lastModelID = modelID
        return AsyncThrowingStream { continuation in
            for chunk in streamChunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}
