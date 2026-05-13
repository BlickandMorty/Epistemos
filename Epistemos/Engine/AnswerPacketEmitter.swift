// AnswerPacketEmitter.swift
//
// V6.2 first wiring for the AnswerPacket audit channel.
//
// Per `docs/fusion/helios v6.2.md` §1.3 + §3 and the laptop audit
// checklist (`docs/audits/V6_2_LAPTOP_MANUAL_AUDIT_CHECKLIST_2026_05_07.md`
// "Next Required Passes"), the AnswerPacket type is currently
// `state: implemented, not state: wired` — the schema is defined in
// `Epistemos/Models/AnswerPacket.swift` but no live agent path emits a
// packet at turn completion. This module is the FIRST WIRING: it records
// a packet per chat-turn completion in a bounded ring buffer for
// diagnostic, debug, and replay-export consumption.
//
// What this module IS:
//   * A turn-level audit sink. Every `StreamingDelegate.onComplete` call
//     produces one packet recorded here.
//   * Thread-safe (actor isolation).
//   * Bounded (ring buffer of last 32 packets) so a long-running session
//     can't memory-leak.
//   * Observable via `count`, `last`, and `recentPackets()` for future
//     diagnostics-row consumption.
//
// What this module is NOT (yet, by design):
//   * The Rust-side `AnswerPacket::new` builder (`agent_core/src/
//     scope_rex/answer_packet.rs`) is not yet wired into the agent
//     runtime. Claims / residency signals / witnessedStateRef are
//     populated with neutral / placeholder values at this layer. A
//     follow-on commit will pull these from FFI.
//   * VRMLabelView consumption on the message bubble is a separate
//     commit. Today the packet is recorded but not rendered. This
//     module is the audit-channel piece; the visual piece is the
//     orthogonal "label visible per bubble" follow-on.
//
// Promotion ladder per the canon-hardening protocol:
//
//   today:        state: emitted (first wiring — this commit)
//   next commit:  state: populated (Rust-side claims + attention_mode
//                                   threaded through via FFI)
//   later commit: state: rendered (VRMLabelView per message bubble)
//   release:      state: canonical-product-surface (ship in MAS build)

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

    private var ring: [AnswerPacket] = []
    private var totalEmitted: Int = 0

    private init() {
        ring.reserveCapacity(Self.maxRingSize)
    }

    /// Emit an AnswerPacket for a completed chat turn. Drops the oldest
    /// packet if the ring is at capacity.
    public func emit(_ packet: AnswerPacket) {
        ring.append(packet)
        if ring.count > Self.maxRingSize {
            ring.removeFirst(ring.count - Self.maxRingSize)
        }
        totalEmitted &+= 1
        Self.log.notice(
            "emit id=\(packet.id, privacy: .public) attentionMode=\(packet.attentionMode.rawValue, privacy: .public) uiLabel=\(packet.uiLabel.rawValue, privacy: .public) ring=\(self.ring.count)/\(Self.maxRingSize)"
        )
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
    }
}

// MARK: - Construction helpers

extension AnswerPacket {
    /// Build a V6.2 AnswerPacket for a completed chat turn.
    ///
    /// State promotion ladder:
    /// - Without `attentionMode` → the original `state: emitted`
    ///   first-wiring shape (defaults to `.unavailable`).
    /// - With a resolved `attentionMode` → `state: populated` partial
    ///   wiring (per-model attention-mode threaded through from the
    ///   live runtime via `AnswerPacketEmitter.currentAttentionMode()`).
    ///
    /// claims + residencySignals remain empty until the next
    /// promotion: Rust-side FFI threads real claim/signal values
    /// from the agent runtime.
    public static func turnCompletionStub(
        stopReason: String,
        inputTokens: Int,
        outputTokens: Int,
        attentionMode: AttentionMode = .unavailable,
        timestamp: Date = Date()
    ) -> AnswerPacket {
        let turnId = "turn-\(Int(timestamp.timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8))"
        return AnswerPacket(
            id: turnId,
            claims: [],
            residencySignals: [],
            uiLabel: .plausibleButUnverified,
            attentionMode: attentionMode,
            witnessedStateRef: "stop:\(stopReason);in:\(inputTokens);out:\(outputTokens)",
            semanticDeltaRef: nil,
            mutationEnvelopeRef: turnId
        )
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
    public static func resolveAttentionMode(
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
