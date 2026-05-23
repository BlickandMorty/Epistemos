// SystemGRunSeam.swift
//
// W4 from the Terminal 1 WRV mission
// (`docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md`):
//
// > W4: System G full run surface. Do not fake it. If only status
// > breadcrumb exists, define the Swift seam needed for MissionPacket
// > → AgentEvent → RunEventLog → AnswerPacket and hand Rust/API gaps
// > to Terminal 2.
//
// Today `Epistemos/SystemG/SystemGWiring.swift` exposes only a
// **status-read** breadcrumb (mode + capability gates + build tier).
// `AgentMissionPacket` (`Epistemos/LocalAgent/AgentBlueprint.swift`)
// and `AnswerPacket` (`Epistemos/Models/AnswerPacket.swift`) are the
// chain endpoints that already exist. The middle two stages
// (`AgentEvent`, `RunEventLog`) have no Swift types — `EventStore.swift`
// explicitly defers them ("RunEventLog/AgentEvent emission remains
// deferred to later gates").
//
// This file defines the Swift seam exactly per the brief: types +
// protocol + a `notWired` stub. **No product behavior is faked.**
// Until Terminal 2 lands the Rust side, every call to
// `SystemGRunSeamRegistry.shared.current().run(mission:)` throws
// `SystemGRunSeamError.notWired`. The presence of the seam lets
// callers integrate against a stable Swift surface today without
// painting fake-success outcomes into the UI.
//
// ## FFI gap handoff to Terminal 2
//
// To swap the stub for a real implementation, Terminal 2 needs to
// export the following from `agent_core::bridge`:
//
// ```
// /// Start a System G run for the encoded `AgentMissionPacket`.
// /// Returns a `run_id` the Swift seam uses to pull events.
// #[uniffi::export]
// pub fn system_g_start_run_json(mission_json: String)
//     -> Result<String, AgentErrorFFI>;
//
// /// Drain the next batch of `AgentEvent`s for the given run. Returns
// /// a JSON array of events in arrival order. Empty array means "no
// /// events yet, poll again." A trailing `complete` or `failed` event
// /// closes the run; subsequent polls return an empty array.
// #[uniffi::export]
// pub fn system_g_drain_events_json(run_id: String)
//     -> Result<String, AgentErrorFFI>;
// ```
//
// `AgentEvent` JSON shape on the Rust side must match the Swift
// `CodingKeys` here exactly (`#[serde(rename_all = "snake_case")]` on
// `AgentEvent` + per-variant lowercase discriminator under a top-
// level `kind` field; each variant carries the `turn_id` and its
// payload fields). The `system_g_drain_events_json` shape is array-
// of-`AgentEvent`-JSON-objects so a single `JSONDecoder().decode`
// pulls a batch.
//
// Streaming variant (UniFFI callbacks instead of polling) is also
// acceptable and can be wired by re-implementing `RealSystemGRunSeam`
// to subscribe to the callback channel. The protocol surface here
// returns `RunEventLog` from a single `async throws` call, which
// composes either polling or callbacks under the hood — callers do
// not care which.

import Foundation

// MARK: - AgentEvent
//
// Discriminated by a top-level `kind` field so the JSON wire shape
// stays stable as variants are added. Each variant carries the
// `turn_id` that groups events from one logical agent turn under a
// `MissionPacket`. A run may emit multiple turns (e.g. an agent that
// makes several tool calls before answering) — the turn_id lets the
// replay UI thread tokens through their owning planner step.
//
// Adding a new variant is additive: existing decoders see an unknown
// `kind` value and throw a `DecodingError.dataCorrupted` per the
// `agentEventRejectsUnknownKinds` test, so Terminal 2 must bump the
// Swift mirror in lockstep with any new Rust event kind.

nonisolated enum AgentEvent: Codable, Hashable, Sendable {
    case planStart(turnId: String, plan: String)
    case toolStart(turnId: String, toolName: String, argsJson: String)
    case toolEnd(turnId: String, toolName: String, ok: Bool, outputJson: String)
    case tokenChunk(turnId: String, text: String)
    case complete(turnId: String, answerPacketId: String)
    case failed(turnId: String, error: String)

    /// The turn this event belongs to. Threading tokens / tool spans
    /// by `turn_id` lets a replay UI cluster the event stream into
    /// per-step lanes.
var turnId: String {
        switch self {
        case .planStart(let t, _):       return t
        case .toolStart(let t, _, _):    return t
        case .toolEnd(let t, _, _, _):   return t
        case .tokenChunk(let t, _):      return t
        case .complete(let t, _):        return t
        case .failed(let t, _):          return t
        }
    }

    /// `true` for `complete` / `failed`. The seam's last event is
    /// always terminal; `RunEventLog.terminalEvent` filters for it.
var isTerminal: Bool {
        switch self {
        case .complete, .failed: return true
        default:                 return false
        }
    }

    private enum Kind: String, Codable {
        case planStart  = "plan_start"
        case toolStart  = "tool_start"
        case toolEnd    = "tool_end"
        case tokenChunk = "token_chunk"
        case complete
        case failed
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case turnId         = "turn_id"
        case plan
        case toolName       = "tool_name"
        case argsJson       = "args_json"
        case ok
        case outputJson     = "output_json"
        case text
        case answerPacketId = "answer_packet_id"
        case error
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        let turnId = try c.decode(String.self, forKey: .turnId)
        switch kind {
        case .planStart:
            self = .planStart(
                turnId: turnId,
                plan: try c.decode(String.self, forKey: .plan)
            )
        case .toolStart:
            self = .toolStart(
                turnId: turnId,
                toolName: try c.decode(String.self, forKey: .toolName),
                argsJson: try c.decode(String.self, forKey: .argsJson)
            )
        case .toolEnd:
            self = .toolEnd(
                turnId: turnId,
                toolName: try c.decode(String.self, forKey: .toolName),
                ok: try c.decode(Bool.self, forKey: .ok),
                outputJson: try c.decode(String.self, forKey: .outputJson)
            )
        case .tokenChunk:
            self = .tokenChunk(
                turnId: turnId,
                text: try c.decode(String.self, forKey: .text)
            )
        case .complete:
            self = .complete(
                turnId: turnId,
                answerPacketId: try c.decode(String.self, forKey: .answerPacketId)
            )
        case .failed:
            self = .failed(
                turnId: turnId,
                error: try c.decode(String.self, forKey: .error)
            )
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .planStart(let turnId, let plan):
            try c.encode(Kind.planStart, forKey: .kind)
            try c.encode(turnId, forKey: .turnId)
            try c.encode(plan, forKey: .plan)
        case .toolStart(let turnId, let toolName, let argsJson):
            try c.encode(Kind.toolStart, forKey: .kind)
            try c.encode(turnId, forKey: .turnId)
            try c.encode(toolName, forKey: .toolName)
            try c.encode(argsJson, forKey: .argsJson)
        case .toolEnd(let turnId, let toolName, let ok, let outputJson):
            try c.encode(Kind.toolEnd, forKey: .kind)
            try c.encode(turnId, forKey: .turnId)
            try c.encode(toolName, forKey: .toolName)
            try c.encode(ok, forKey: .ok)
            try c.encode(outputJson, forKey: .outputJson)
        case .tokenChunk(let turnId, let text):
            try c.encode(Kind.tokenChunk, forKey: .kind)
            try c.encode(turnId, forKey: .turnId)
            try c.encode(text, forKey: .text)
        case .complete(let turnId, let answerPacketId):
            try c.encode(Kind.complete, forKey: .kind)
            try c.encode(turnId, forKey: .turnId)
            try c.encode(answerPacketId, forKey: .answerPacketId)
        case .failed(let turnId, let error):
            try c.encode(Kind.failed, forKey: .kind)
            try c.encode(turnId, forKey: .turnId)
            try c.encode(error, forKey: .error)
        }
    }
}

// MARK: - RunEventLog
//
// Append-only collection of `AgentEvent`s tied to one mission. Value-
// typed so callers can snapshot the run state cheaply (the replay UI
// gets a Sendable copy and renders without races).

nonisolated struct RunEventLog: Codable, Hashable, Sendable {
let missionId: String
private(set) var events: [AgentEvent]

init(missionId: String, events: [AgentEvent] = []) {
        self.missionId = missionId
        self.events = events
    }

mutating func append(_ event: AgentEvent) {
        events.append(event)
    }

    /// The terminal `.complete` or `.failed` event if the run has
    /// concluded. `nil` while the run is still open.
var terminalEvent: AgentEvent? {
        events.last(where: { $0.isTerminal })
    }

    /// `answerPacketId` from the terminal `.complete` event, if any.
    /// Callers resolve the packet via `AnswerPacketEmitter.shared
    /// .recentPackets()`.
var answerPacketId: String? {
        guard case .complete(_, let id) = terminalEvent else { return nil }
        return id
    }
}

// MARK: - SystemGRunSeam protocol + errors
//
// Single `async throws` entry point that consumes a mission and
// returns the completed run log. The implementation owns whichever
// polling / callback strategy talks to Rust — callers see only the
// composed log. Real implementations are expected to populate
// `AnswerPacketEmitter.shared` along the way so the `complete` event's
// `answerPacketId` resolves.

nonisolated enum SystemGRunSeamError: Error, Equatable, Sendable {
    /// The seam has no real backend wired yet. Terminal 2's
    /// `system_g_start_run_json` / `system_g_drain_events_json` FFI is
    /// still pending per the file-head spec.
    case notWired
    /// FFI returned a payload that failed to decode against the Swift
    /// AgentEvent schema.
    case decode(String)
    /// FFI surfaced an error from the Rust runtime; carries the
    /// original `AgentErrorFFI.message`.
    case ffi(String)
}

nonisolated protocol SystemGRunSeam: Sendable {
    func run(mission: AgentMissionPacket) async throws -> RunEventLog
}

// MARK: - StubSystemGRunSeam
//
// The default registered seam. **Throws `notWired` on every call** so
// any caller that integrates against the protocol sees an immediate,
// honest failure instead of fabricated success. When Terminal 2 lands
// the Rust side, `RealSystemGRunSeam` replaces this via
// `SystemGRunSeamRegistry.shared.register(_:)`.

nonisolated struct StubSystemGRunSeam: SystemGRunSeam {
init() {}

func run(mission: AgentMissionPacket) async throws -> RunEventLog {
        throw SystemGRunSeamError.notWired
    }
}

// MARK: - SystemGRunSeamRegistry
//
// Process-wide single-instance registry. Defaults to `StubSystemGRunSeam`
// until Terminal 2's real implementation registers itself at app
// bootstrap. `current()` returns whatever is registered without
// retaining a reference, so swap-in / swap-out is atomic.

nonisolated final class SystemGRunSeamRegistry: @unchecked Sendable {
static let shared = SystemGRunSeamRegistry()

    private let lock = NSLock()
    private var seam: SystemGRunSeam = StubSystemGRunSeam()

    private init() {}

func current() -> SystemGRunSeam {
        lock.lock(); defer { lock.unlock() }
        return seam
    }

func register(_ seam: SystemGRunSeam) {
        lock.lock()
        self.seam = seam
        lock.unlock()
    }

    /// Test hook — restores the default stub. Production code must not
    /// call this; the seam is sticky for the process lifetime by
    /// design.
func resetToStubForTesting() {
        lock.lock()
        self.seam = StubSystemGRunSeam()
        lock.unlock()
    }
}
