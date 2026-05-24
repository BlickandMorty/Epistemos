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
import os

/// Production implementation of `SystemGRunSeam`. Encodes the
/// supplied `AgentMissionPacket` as a `MissionPacket`-shaped JSON
/// payload, starts a Rust-side run, and polls `drain_events` until
/// a terminal `.complete` or `.failed` event arrives.
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
            blueprint_id: mission.blueprintName,
            user_prompt: mission.objective,
            vault_scope: mission.scope.rawValue
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

        let runId: String
        do {
            runId = try systemGStartRunJson(missionJson: missionJson)
        } catch {
            throw SystemGRunSeamError.ffi(String(describing: error))
        }

        var log = RunEventLog(missionId: runId)
        let deadline = Date().addingTimeInterval(Self.runTimeoutSeconds)
        let decoder = JSONDecoder()

        while Date() < deadline {
            let rawJson: String
            do {
                rawJson = try systemGDrainEventsJson(runId: runId)
            } catch {
                throw SystemGRunSeamError.ffi(String(describing: error))
            }
            guard let data = rawJson.data(using: .utf8) else {
                throw SystemGRunSeamError.decode("drain JSON is not valid utf-8")
            }
            let batch: [SystemGAgentEvent]
            do {
                batch = try decoder.decode([SystemGAgentEvent].self, from: data)
            } catch {
                throw SystemGRunSeamError.decode("decode events: \(error)")
            }
            for event in batch {
                log.append(event)
                if event.isTerminal {
                    return log
                }
            }
            try await Task.sleep(nanoseconds: Self.pollIntervalNanos)
        }
        throw SystemGRunSeamError.ffi("timeout: no terminal event within \(Self.runTimeoutSeconds)s")
    }

    // MARK: - Wire shape
    //
    // Matches `agent_core::agent_runtime_v2::mission::MissionPacket`
    // exactly. Snake_case field names match the Rust serde derive
    // (no `rename_all` is applied, fields are already snake_case in
    // the Rust struct).
    private struct MissionPacketWire: Codable, Sendable {
        let blueprint_id: String
        let user_prompt: String
        let vault_scope: String
    }
}
