import Foundation

/// Deterministic pseudo-random generator keyed by `(session_id,
/// agent_id, event_id)` per Simulation Mode v1.6 Invariant I-13.
///
/// **Why deterministic.** The Companion Farm — and the broader
/// Simulation Theater — must be **pixel-identical replayable** given
/// the same event log + seed. Using `Float.random(in:)` or
/// `SystemRandomNumberGenerator` breaks that invariant because both
/// pull from a non-replayable kernel-level source.
///
/// **Algorithm.** SplitMix64 — a tiny, fast, statistically sound 64-bit
/// PRNG with no dependencies. Sebastiano Vigna's design; widely used as
/// a seeder and also as a standalone PRNG when speed > distribution
/// quality. For cosmetic randomness (orb breathing phase, hue jitter,
/// particle drift) it's more than adequate.
///
/// **NOT a cryptographic primitive.** Do not use this for anything
/// that needs unpredictability (capability-token nonces, vault keys).
/// For those use `CryptoKit.SymmetricKey(size:)` or
/// `SecRandomCopyBytes`.
nonisolated public struct DeterministicPRNG: RandomNumberGenerator {
    private var state: UInt64

    /// Construct from a stable seed string. Hashes the string into a
    /// UInt64 via FNV-1a (deterministic across platforms; matches the
    /// seed pattern used in CompanionModel.identityHash).
    public init(seedString: String) {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in seedString.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        // Avoid all-zero state which is degenerate for SplitMix64.
        self.state = hash == 0 ? 0xdeadbeefdeadbeef : hash
    }

    /// Construct from a numeric seed directly. Useful in tests.
    public init(seed: UInt64) {
        self.state = seed == 0 ? 0xdeadbeefdeadbeef : seed
    }

    /// Compose a seed from a Simulation triple per Invariant I-13.
    /// Spaces are illegal in canonical IDs so `:` separator is safe.
    public init(sessionId: String, agentId: String, eventId: String) {
        self.init(seedString: "\(sessionId):\(agentId):\(eventId)")
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Convenience: uniform [0, 1) Float64.
    public mutating func unitDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// Convenience: uniform [0, 1) Float (downcast).
    public mutating func unitFloat() -> Float {
        Float(unitDouble())
    }

    /// Convenience: uniform Int in [0, upperBound).
    public mutating func intIn(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(next() % UInt64(upperBound))
    }
}
