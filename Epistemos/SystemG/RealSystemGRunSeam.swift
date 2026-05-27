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
//     SystemGRunSeamRegistry.shared.register(RealSystemGRunSeam())
// runs at app bootstrap so any production call to
// `SystemGRunSeamRegistry.shared.current().run(mission:)` reaches
// the real path. The `StubSystemGRunSeam` remains the default-default
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

    init() {}

    func run(mission: AgentMissionPacket) async throws -> RunEventLog {
        let payload = MissionPacketWire(
            blueprintID: mission.blueprintName,
            userPrompt: mission.objective,
            vaultScope: mission.scope.rawValue
        )
        let encoder = JSONEncoder()
        let missionJsonData: Data
        do {
            missionJsonData = try encoder.encode(payload)
        } catch {
            throw SystemGRunSeamError.decode("encode mission: \(error)")
        }
        guard let missionJson = String(data: missionJsonData, encoding: .utf8) else {
            throw SystemGRunSeamError.decode("mission JSON is not valid utf-8")
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
        case .complete(let turnId, let answerPacketId):
            return "[\(turnId)] complete answer_packet_id=\(answerPacketId)"
        case .failed(let turnId, let error):
            return "[\(turnId)] failed error=\(error)"
        }
    }
}
