// AnswerPacketEmitter.swift
//
// V6.2 AnswerPacket audit channel — turn-level emit + observability.
//
// Per `docs/fusion/helios v6.2.md` §1.3 + §3 and the laptop audit
// checklist (`docs/audits/V6_2_LAPTOP_MANUAL_AUDIT_CHECKLIST_2026_05_07.md`):
// every chat-turn completion produces one AnswerPacket, recorded in a
// bounded 32-packet ring for diagnostic, debug, and replay-export
// consumption.
//
// What this module IS:
//   * A turn-level audit sink. Every `StreamingDelegate.onComplete` call
//     produces one packet emitted here (`emit(packet)`).
//   * Thread-safe (actor isolation).
//   * Bounded (32-packet ring) so a long-running session can't
//     memory-leak.
//   * Observable via `snapshot()` + `didEmitNotification` so the
//     Settings diagnostics row + `LatestAnswerPacketSink` (the
//     MainActor mirror that feeds MessageBubble's chip row) refresh
//     event-driven, not polled.
//   * Source for per-mode + per-bucket monotonic histograms (V6.2
//     §1.4 attention modes and §1.5 calibration corpus buckets).
//
// State 2026-05-12 (`state: rendered FULL`):
//   ✓ chat path emits packet per turn at StreamingDelegate.onComplete
//   ✓ attention_mode populated from live InferenceState
//   ✓ interrupt_bucket sampled via InterruptScoreCpu.sampleTurnBucket
//   ✓ packet id threaded to ChatMessage.answerPacketId (Option B)
//   ✓ MessageBubble renders VRMLabelView + attention + bucket chips
//   ✓ Settings → Diagnostics shows count + histograms
//
// What's still pending for `state: canonical-product-surface`:
//   * Persisting the packet alongside the ChatMessage so scrollback
//     past the 32-packet ring still renders chips.
//   * Rust-side `agent_core::scope_rex::AnswerPacket::new` production
//     caller so claims + residency signals come from the live agent
//     runtime instead of empty placeholders.
//   * Substrate hooks: WBO (claim ledger), sheafResidual (cognitive
//     DAG), connectomeAlarm (routing layer) — currently default 0 in
//     `InterruptScoreCpu.sampleTurnBucket`.

import Foundation
import os

/// V6.2 first-wiring AnswerPacket audit sink. Singleton actor so the
/// `StreamingDelegate.onComplete` callback (which is `nonisolated`) can
/// hop in via `Task { await AnswerPacketEmitter.shared.emit(...) }`.
public actor AnswerPacketEmitter {
    public static let shared = AnswerPacketEmitter()

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "AnswerPacket"
    )

    /// Bounded ring size. 32 turns × a typical few-KB packet ≈ 100 KB.
    /// Tight enough for memory-safety, deep enough that the diagnostics
    /// row can show a useful rolling window.
    public static let maxRingSize = 32

    /// Posted (on the main queue) whenever a packet is emitted so the
    /// Settings → Diagnostics AnswerPacketHealthRow can refresh without
    /// polling. `object` is `AnswerPacketEmitter.shared`. Read the
    /// fresh state via `await snapshot()`.
    public nonisolated static let didEmitNotification = Notification.Name(
        "com.epistemos.answerPacket.didEmit"
    )

    private var ring: [AnswerPacket] = []
    private var totalEmitted: Int = 0
    private var firstEmittedAt: Date?
    private var lastEmittedAt: Date?
    // Monotonic per-mode + per-bucket emit counters. Survive ring
    // eviction so the diagnostics-row "histogram" view reflects the
    // full session, not just the current ring window.
    private var modeCounts: [AttentionMode: Int] = [:]
    private var bucketCounts: [InterruptBucket: Int] = [:]

    private init() {
        ring.reserveCapacity(Self.maxRingSize)
    }

    /// Immutable snapshot of the emitter's audit state for read-only
    /// consumers (the Settings health row, the future replay-export
    /// surface). Returned by value so the caller doesn't hold actor
    /// isolation while it renders.
    public struct Snapshot: Sendable, Equatable {
        public let count: Int
        public let totalEmitted: Int
        public let firstEmittedAt: Date?
        public let lastEmittedAt: Date?
        public let latest: AnswerPacket?
        /// Monotonic per-attention-mode emit count. Sums to
        /// `totalEmitted`. Useful for verifying V6.2 §1.4 attention-
        /// mode invariants over a session.
        public let modeCounts: [AttentionMode: Int]
        /// Monotonic per-interrupt-bucket emit count. Sums to
        /// `totalEmitted`. Useful for verifying V6.2 §1.5 bucket
        /// distribution (a healthy session has a mix of LOW/MED/HIGH;
        /// all-LOW would suggest the bucket sampler isn't getting
        /// signal).
        public let bucketCounts: [InterruptBucket: Int]
    }

    /// Read-only snapshot of the emitter's state. Cheap — clones a
    /// small fixed-size record + the latest packet + the two
    /// histogram dicts (≤4 entries each).
    public func snapshot() -> Snapshot {
        Snapshot(
            count: ring.count,
            totalEmitted: totalEmitted,
            firstEmittedAt: firstEmittedAt,
            lastEmittedAt: lastEmittedAt,
            latest: ring.last,
            modeCounts: modeCounts,
            bucketCounts: bucketCounts
        )
    }

    /// Emit an AnswerPacket for a completed chat turn. Drops the oldest
    /// packet if the ring is at capacity.
    public func emit(_ packet: AnswerPacket) {
        ring.append(packet)
        if ring.count > Self.maxRingSize {
            ring.removeFirst(ring.count - Self.maxRingSize)
        }
        totalEmitted &+= 1
        // Monotonic histogram counters — survive ring eviction.
        modeCounts[packet.attentionMode, default: 0] &+= 1
        bucketCounts[packet.interruptBucket, default: 0] &+= 1
        let now = Date()
        if firstEmittedAt == nil {
            firstEmittedAt = now
        }
        lastEmittedAt = now
        Self.log.notice(
            "emit id=\(packet.id, privacy: .public) attentionMode=\(packet.attentionMode.rawValue, privacy: .public) interruptBucket=\(packet.interruptBucket.rawValue, privacy: .public) uiLabel=\(packet.uiLabel.rawValue, privacy: .public) ring=\(self.ring.count)/\(Self.maxRingSize)"
        )
        // Post on the main queue so the Settings → Diagnostics
        // health-row receiver doesn't need to hop threads.
        Task { @MainActor in
            NotificationCenter.default.post(
                name: AnswerPacketEmitter.didEmitNotification,
                object: AnswerPacketEmitter.shared
            )
        }
    }

    /// Snapshot of recent packets in chronological order
    /// (oldest first, newest last). Safe to consume from a sync caller
    /// via `await`.
    public func recentPackets() -> [AnswerPacket] {
        ring
    }

    /// Most recent packet, if any.
    public var last: AnswerPacket? {
        ring.last
    }

    /// Current ring depth.
    public var count: Int {
        ring.count
    }

    /// Total packets ever emitted (monotonic; survives ring eviction).
    /// Useful for the diagnostics-row "packets seen this session" stat.
    public var emittedTotal: Int {
        totalEmitted
    }

    /// Test-only: drop every recorded packet and reset the monotonic
    /// counter. Marked `internal` so production callers can't accidentally
    /// blow away the audit trail; tests reach it via `@testable import`.
    internal func resetForTesting() {
        ring.removeAll(keepingCapacity: true)
        totalEmitted = 0
        firstEmittedAt = nil
        lastEmittedAt = nil
        modeCounts.removeAll(keepingCapacity: true)
        bucketCounts.removeAll(keepingCapacity: true)
    }
}

// MARK: - Construction helpers

// `nonisolated extension` so `turnCompletionStub` can be called from
// the unstructured `Task { … }` inside `StreamingDelegate.onComplete`.
// Without this the module's default MainActor isolation would make the
// static factory MainActor-bound; AnswerPacket itself is `nonisolated`
// (see Models/AnswerPacket.swift) so its members can be too.
nonisolated extension AnswerPacket {
    /// Build a V6.2 AnswerPacket for a completed chat turn.
    ///
    /// State promotion ladder (canon-hardening WRV markers):
    /// - Without `attentionMode` → the original `state: emitted`
    ///   first-wiring shape (defaults to `.unavailable`).
    /// - With a resolved `attentionMode` → `state: partially populated`
    ///   wiring (per-model attention-mode threaded through from the
    ///   live runtime via `AnswerPacketEmitter.currentAttentionMode()`).
    /// - **2026-05-13: `state: canonical-product-surface`.** This
    ///   factory first attempts to build the packet via
    ///   `RustAnswerPacketProducerClient.produceJson(...)` (the
    ///   `agent_core::scope_rex::produce::produce_turn_completion_packet`
    ///   production caller). When the FFI is linked + the JSON decodes,
    ///   the returned packet carries non-empty claims (Empirical
    ///   self-witness every turn, Empirical tool-use observation when
    ///   stop_reason == "tool_use", StaticFallbackAcknowledged when
    ///   attention_mode == .staticFallback) and one neutral
    ///   ResidencySignal — the canonical Rust-produced shape. The
    ///   Swift-side `interruptBucket` (computed by the V6.2 substrate-
    ///   hook observers) is then stamped on top, because the Rust
    ///   producer does not have visibility into the Swift InterruptScore
    ///   observers yet.
    /// - Fallback: if the FFI is not linked or the JSON decode fails,
    ///   the original Swift stub path runs (empty claims + signals).
    ///   This keeps the audit ring populated even when the Rust path
    ///   is unavailable.
    nonisolated public static func turnCompletionStub(
        stopReason: String,
        inputTokens: Int,
        outputTokens: Int,
        attentionMode: AttentionMode = .unavailable,
        interruptBucket: InterruptBucket = .unavailable,
        timestamp: Date = Date()
    ) -> AnswerPacket {
        let turnId = "turn-\(Int(timestamp.timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8))"
        let witnessedRef = "stop:\(stopReason);in:\(inputTokens);out:\(outputTokens)"

        // Preferred path: ask the Rust production caller for a packet
        // populated with claims + residency. Falls through to the Swift
        // stub path if the FFI is unlinked or the decode fails.
        if let rustPacket = packetFromRustProducer(
            packetId: turnId,
            stopReason: stopReason,
            outputTokens: outputTokens,
            attentionMode: attentionMode,
            witnessedStateRef: witnessedRef,
            mutationEnvelopeRef: turnId,
            timestamp: timestamp
        ) {
            // Rust producer doesn't compute interruptBucket — that's a
            // Swift-side V6.2 substrate-hook observer's job. Stamp it
            // on top of the Rust-produced packet so the audit channel
            // carries both the canonical claims AND the runtime bucket.
            var stamped = rustPacket
            stamped.interruptBucket = interruptBucket
            return stamped
        }

        // Fallback path — Rust FFI absent or decode failed. Emit the
        // original empty-claims stub so the audit ring still gets a
        // well-formed packet for this turn. This path is exercised
        // in test builds that don't link agent_coreFFI.
        return AnswerPacket(
            id: turnId,
            claims: [],
            residencySignals: [],
            uiLabel: .plausibleButUnverified,
            attentionMode: attentionMode,
            interruptBucket: interruptBucket,
            witnessedStateRef: witnessedRef,
            semanticDeltaRef: nil,
            mutationEnvelopeRef: turnId
        )
    }

    /// Bridge from runtime inputs → Rust producer FFI → decoded Swift
    /// AnswerPacket. Returns nil on any failure so the caller can
    /// fall through to the Swift stub path.
    nonisolated private static func packetFromRustProducer(
        packetId: String,
        stopReason: String,
        outputTokens: Int,
        attentionMode: AttentionMode,
        witnessedStateRef: String,
        mutationEnvelopeRef: String,
        timestamp: Date
    ) -> AnswerPacket? {
        // Wire-form mapping: Swift enum → snake_case Rust contract.
        let attentionWire: RustAnswerPacketAttentionWire
        switch attentionMode {
        case .dynamic: attentionWire = .dynamic
        case .staticFallback: attentionWire = .staticFallback
        case .unavailable: attentionWire = .unavailable
        }
        let request = RustAnswerPacketProduceRequest(
            packetId: packetId,
            stopReason: stopReason,
            outputTokens: UInt32(max(0, outputTokens)),
            attentionMode: attentionWire,
            vrmLabel: .plausibleButUnverified,
            witnessedStateId: witnessedStateRef,
            mutationEnvelopeId: mutationEnvelopeRef,
            createdAtMs: Int64(timestamp.timeIntervalSince1970 * 1000)
        )
        guard let json = RustAnswerPacketProducerClient.produceJson(request: request),
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(AnswerPacket.self, from: data)
    }
}

// MARK: - Attention mode resolver (state: populated promotion)

extension AnswerPacketEmitter {
    /// Resolve the live `AttentionMode` for the current chat-model
    /// selection. Hops to MainActor to read `AppBootstrap.shared?
    /// .inferenceState.preferredChatModelSelection`.
    ///
    /// Per V6.2 §1.3 + §1.4: the AttentionMode field on the emitted
    /// AnswerPacket must carry runtime truth about which inference
    /// path produced the token — quadratic-attention transformer
    /// (`.dynamic`), recurrent-state SSM Mamba2/Falcon-H1/Jamba
    /// (`.staticFallback`), or unknown (`.unavailable`).
    public static func currentAttentionMode() async -> AttentionMode {
        await MainActor.run { attentionModeFromMainActor() }
    }

    @MainActor
    private static func attentionModeFromMainActor() -> AttentionMode {
        guard let bootstrap = AppBootstrap.shared else {
            return .unavailable
        }
        return resolveAttentionMode(
            selection: bootstrap.inferenceState.preferredChatModelSelection
        )
    }

    /// Pure resolver — public so tests can exercise the mapping
    /// without standing up an AppBootstrap. Active app callers go
    /// through `currentAttentionMode()`.
    ///
    /// Mapping:
    /// - `.localMLX(id)` where the model `isSSM` → `.staticFallback`.
    ///   The SSM family (Mamba2, Falcon-H1, Jamba, LFM 2.5) has a
    ///   fixed-size recurrent hidden state, not a quadratic KV cache.
    ///   That IS V6.2's "static fallback" attention path.
    /// - `.localMLX(id)` for any non-SSM model → `.dynamic` (a
    ///   transformer using full quadratic attention).
    /// - `.cloud(_)` → `.dynamic` (Claude, GPT, etc. all use quadratic
    ///   attention).
    /// - `.appleIntelligence` → `.dynamic` (FoundationModels is a
    ///   transformer).
    /// - Unknown local model id → `.unavailable`.
    /// Internal because `ChatModelSelection` is module-internal —
    /// promoting this resolver to `public` would require also exporting
    /// `ChatModelSelection` from `InferenceState.swift`, which isn't
    /// needed for any current consumer.
    internal static func resolveAttentionMode(
        selection: ChatModelSelection
    ) -> AttentionMode {
        switch selection {
        case .appleIntelligence:
            return .dynamic
        case .cloud:
            return .dynamic
        case .localMLX(let id):
            guard let modelID = LocalTextModelID(rawValue: id) else {
                return .unavailable
            }
            return modelID.isSSM ? .staticFallback : .dynamic
        }
    }
}
