import Foundation

// ---------------------------------------------------------------------------
// MARK: - DeterministicPRNG
// ---------------------------------------------------------------------------

/// Seeded PRNG for deterministic replay — Invariant I-13.
///
/// All randomness in simulation mode MUST flow through this generator. Keyed by
/// `(session_id, agent_id, event_id)`. There is no `Date.now()`, no `random()`,
/// no `arc4random()`, and no system clock access.
///
/// The seed is derived from a deterministic hash of the key triple, ensuring that
/// the same session + agent + event always produces the same PRNG sequence. This
/// enables byte-for-byte replay of simulation runs for debugging and CI validation.
///
/// Algorithm: SplitMix64 — fast, high-quality, well-known, and fully deterministic.
public struct DeterministicPRNG {
    private var state: UInt64

    /// Initialize from a deterministic seed derived from session + agent + event.
    ///
    /// Uses a custom deterministic string hash (FNV-1a 64-bit) rather than Swift’s
    /// `Hasher`, which is seeded randomly per process for security.
    public init(sessionId: String, agentId: String, eventId: String) {
        var h: UInt64 = 0xcbf29ce484222325 // FNV-1a 64-bit offset basis
        let prime: UInt64 = 0x100000001b3    // FNV-1a 64-bit prime

        for string in [sessionId, agentId, eventId] {
            for byte in string.utf8 {
                h ^= UInt64(byte)
                h = h &* prime
            }
        }

        // Mix with a fixed constant to avoid collision with other hash users
        h ^= 0x9e3779b97f4a7c15 // golden ratio constant

        self.state = h
    }

    /// SplitMix64 — fast, high-quality, deterministic.
    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        z = z ^ (z >> 31)
        return z
    }

    /// Random Float in [0, 1)
    public mutating func nextFloat() -> Float {
        Float(next() >> 11) / Float(1 << 53)
    }

    /// Random Double in [0, 1)
    public mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// Random Bool
    public mutating func nextBool() -> Bool {
        (next() & 1) == 1
    }
}

// ---------------------------------------------------------------------------
// MARK: - ReplayEvent
// ---------------------------------------------------------------------------

/// A single event in the replay log, capturing every input that influenced state.
public struct ReplayEvent: Codable, Sendable {
    public let eventId: String
    public let agentId: String
    public let action: String
    public let timestamp: UInt64  // Unix timestamp — NOT Date, deterministic
    public let prngSequence: UInt64  // PRNG state at this event

    public init(
        eventId: String,
        agentId: String,
        action: String,
        timestamp: UInt64,
        prngSequence: UInt64
    ) {
        self.eventId = eventId
        self.agentId = agentId
        self.action = action
        self.timestamp = timestamp
        self.prngSequence = prngSequence
    }
}

// ---------------------------------------------------------------------------
// MARK: - ReplayContext
// ---------------------------------------------------------------------------

/// Replay context — captures the full deterministic state for a session.
///
/// Serialize this struct to JSON after a session to enable deterministic replay.
/// The `seed` is the initial PRNG state; `eventLog` is the ordered sequence of
/// all inputs that mutated simulation state.
public struct ReplayContext: Codable, Sendable {
    public let sessionId: String
    public let seed: UInt64
    public let eventLog: [ReplayEvent]

    public init(sessionId: String, seed: UInt64, eventLog: [ReplayEvent]) {
        self.sessionId = sessionId
        self.seed = seed
        self.eventLog = eventLog
    }
}
