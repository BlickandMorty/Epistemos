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
        let seam = SystemGRunSeamRegistry.shared.current()
        #expect(seam is StubSystemGRunSeam,
                "default registry impl must be the explicit stub")
    }
}
