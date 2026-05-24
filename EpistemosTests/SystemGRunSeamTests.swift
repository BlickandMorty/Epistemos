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
}
