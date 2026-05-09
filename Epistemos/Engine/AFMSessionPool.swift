import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AFMSessionPool (AP4 + AP6 — shared AFM warm sessions)
//
// Perf agent's Wins #4 + #6 fused: independent
// `LanguageModelSession` instances in OntologyClassifier,
// IntakeValve, ConversationStateClassifier, SessionTelemetryClassifier
// each pay a 1-3 s cold-start AND a separate KV-cache warmup. The
// pool keeps a single `LanguageModelSession` per (useCase,
// instructions-hash) so all four classifiers share warm weights.
//
// Per the perf agent's measurement:
//   IntakeValve + OntologyClassifier + ConversationState today:
//     300 ms + 300 ms + 200 ms = 800 ms latency
//     ~750 + 3× session spin-up = ~900 token-equivalent cost
//   With AFMSessionPool:
//     60 ms + 40 ms + 40 ms = 140 ms latency
//     ~450 tokens (shared prefix cached) + 1× warmup = ~500 cost
//   → 40 % token reduction + 5.7× latency cut across the trio.
//
// Lifetime contract:
//   - 10-minute idle recycle (matches existing AppleIntelligenceService
//     pattern — prevents KV-cache bloat)
//   - no passive launch prewarm. FoundationModels / TokenGenerationCore
//     sessions are created only after explicit classifier work begins.
//   - reset() called on memory pressure / vault switch invalidates
//     all cached sessions
//
// Sendable contract: pool is an actor so concurrent reads from
// multiple classifiers don't race.

@available(macOS 26.0, *)
public actor AFMSessionPool {

    public static let shared = AFMSessionPool()

    nonisolated private static let log = Logger(
        subsystem: "com.epistemos",
        category: "AFMSessionPool"
    )

    /// Cached (session, createdAt, useCase) tuples keyed by a hash
    /// of (useCaseRaw, instructions). The hash is the
    /// instructions-string SHA truncated for log readability; the
    /// pool resolves to the same session for the same hash.
    #if canImport(FoundationModels)
    private struct PooledSession {
        let session: LanguageModelSession
        let createdAt: Date
        let useCaseLabel: String
    }
    private var pool: [String: PooledSession] = [:]
    #endif

    public static let sessionLifetime: TimeInterval = 600  // 10 min

    private init() {}

    // MARK: - Pool API

    #if canImport(FoundationModels)

    /// Returns a warm `LanguageModelSession` for the given use case
    /// + instructions. Creates one on first call; reuses for ≤10 min;
    /// recycles after that to prevent KV-cache bloat.
    public func session(
        useCase: SystemLanguageModel.UseCase = .contentTagging,
        instructions: String,
        useCaseLabel: String = "contentTagging"
    ) -> LanguageModelSession {
        let key = Self.poolKey(useCaseLabel: useCaseLabel, instructions: instructions)
        let now = Date()
        if let pooled = pool[key],
           now.timeIntervalSince(pooled.createdAt) < Self.sessionLifetime {
            return pooled.session
        }
        let model = SystemLanguageModel(useCase: useCase)
        let s = LanguageModelSession(model: model, instructions: instructions)
        pool[key] = PooledSession(
            session: s, createdAt: now, useCaseLabel: useCaseLabel
        )
        Self.log.info(
            "AFMSessionPool created session useCase=\(useCaseLabel, privacy: .public) instructionsLen=\(instructions.count, privacy: .public)"
        )
        return s
    }

    /// Explicit classifier prewarm. This must only run after a user-triggered
    /// classifier path asks for it; passive app launch must not call it.
    public func prewarmForExplicitClassifierWork(instructions: String) async {
        guard pool.isEmpty else { return }
        let _ = session(
            useCase: .contentTagging,
            instructions: instructions,
            useCaseLabel: "contentTagging-explicit"
        )
        Self.log.info("AFMSessionPool prewarmed for explicit classifier work")
    }

    /// Force-evict every pooled session. Call on memory-pressure
    /// notification or when the active vault switches.
    public func reset() {
        pool.removeAll()
        Self.log.debug("AFMSessionPool reset (all sessions evicted)")
    }

    /// Evict any pooled session older than the lifetime window.
    /// Optional GC pass — could fire from a NightBrain housekeeping
    /// job to reclaim daemon memory between user sessions.
    ///
    /// AUDIT FIX: previous implementation computed
    /// `now.timeIntervalSince(Date())` which is essentially zero
    /// (the gap between two near-simultaneous Date() calls), then
    /// subtracted sessionLifetime — yielding a cutoff of ~-600 in
    /// timeIntervalSinceReferenceDate space, which the
    /// `createdAt.timeIntervalSinceReferenceDate > cutoff` filter
    /// always satisfies. EFFECT: ALL sessions retained forever; the
    /// helper was a no-op (not the eviction it advertised).
    /// Worse: the README said it was a 10-min recycle but the
    /// recycle never actually fired. Fixed to use the canonical
    /// `now - sessionLifetime` cutoff.
    public func sweepStale(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Self.sessionLifetime)
        pool = pool.filter { _, p in p.createdAt > cutoff }
    }

    #endif

    // MARK: - Hash helpers

    nonisolated public static func poolKey(useCaseLabel: String, instructions: String) -> String {
        // Cheap, stable, collision-resistant-enough for the pool.
        // The instructions string is small (<2KB) so we can safely
        // hash via Swift's built-in Hasher.
        var hasher = Hasher()
        hasher.combine(useCaseLabel)
        hasher.combine(instructions)
        return "\(useCaseLabel):\(hasher.finalize())"
    }
}
