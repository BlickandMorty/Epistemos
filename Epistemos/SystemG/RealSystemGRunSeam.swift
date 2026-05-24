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
