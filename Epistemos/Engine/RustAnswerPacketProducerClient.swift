import Foundation
import os

// MARK: - V6.2 Rust AnswerPacket production-caller client (2026-05-12)
//
// Swift bridge to `bridge::produce_answer_packet_json` in agent_core.
// The Rust side constructs a fully-populated AnswerPacket from a
// turn-completion's runtime inputs (stop reason, output tokens,
// attention mode, VRM label, witnessed-state id, mutation-envelope id)
// and serializes it to canonical JSON. This Swift client wraps that
// FFI surface so call sites can request a Rust-produced packet without
// touching uniFFI types directly.
//
// **Doctrine context.** The V6.2 AnswerPacket emission ladder
// (docs/audits/V6_2_SESSION_PROGRESS_2026_05_12.md) classifies this
// commit as advancing `state: partially populated → state: populated`:
// the Rust schema now has a production caller in agent_core, and Swift
// can read its JSON output. Wiring the Swift `AnswerPacketEmitter` to
// CONSUME this client (replacing or augmenting the Swift-side stub)
// is a follow-up. Today the client lives so the parity tests can
// compare Rust-produced vs Swift-produced packets and future
// production consumers can adopt the Rust path incrementally.
//
// **Honest-handle doctrine.** The FFI returns a JSON string rather
// than a uniFFI struct so the Rust schema can evolve (add fields,
// rename internals) without forcing every Swift caller to update its
// decoder. The Swift consumer decodes through the canonical
// `AnswerPacket` Codable contract; new fields land via
// `decodeIfPresent` defaults the same way `RustCognitiveDagStats`
// handles forward-compat.

/// Wire-form attention mode strings accepted by `produceAnswerPacketJson`.
/// Match the canonical `snake_case` serialization of
/// `agent_core::scope_rex::answer_packet::AttentionMode`.
nonisolated enum RustAnswerPacketAttentionWire: String, Sendable {
    case dynamic = "dynamic"
    case staticFallback = "static_fallback"
    case unavailable = "unavailable"
}

/// Wire-form VRM label strings accepted by `produceAnswerPacketJson`.
nonisolated enum RustAnswerPacketVrmLabelWire: String, Sendable {
    case verified = "verified"
    case plausibleButUnverified = "plausible_but_unverified"
    case speculative = "speculative"
    case blocked = "blocked"
}

/// Inputs the Swift caller assembles before requesting a Rust-produced
/// packet. Mirrors the production caller's `TurnCompletionInputs`
/// Rust struct one-for-one.
nonisolated struct RustAnswerPacketProduceRequest: Sendable, Equatable {
    let packetId: String
    let stopReason: String
    let outputTokens: UInt32
    let attentionMode: RustAnswerPacketAttentionWire
    let vrmLabel: RustAnswerPacketVrmLabelWire
    let witnessedStateId: String
    let mutationEnvelopeId: String
    let createdAtMs: Int64
}

/// Swift wrapper around `produceAnswerPacketJson(...)`. Falls back to
/// `nil` on FFI failure or when `agent_coreFFI` is not linked — the
/// caller can degrade to the Swift-side stub constructor without
/// crashing.
nonisolated enum RustAnswerPacketProducerClient {

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "RustAnswerPacketProducerClient"
    )

    /// Produce a Rust-side AnswerPacket and return the canonical JSON.
    /// Cheap O(1) FFI hop + one serde serialize on the Rust side.
    /// Safe to call from any thread (no shared state mutation).
    static func produceJson(request: RustAnswerPacketProduceRequest) -> String? {
        #if canImport(agent_coreFFI)
        do {
            return try produceAnswerPacketJson(
                packetId: request.packetId,
                stopReason: request.stopReason,
                outputTokens: request.outputTokens,
                attentionModeWire: request.attentionMode.rawValue,
                vrmLabelWire: request.vrmLabel.rawValue,
                witnessedStateId: request.witnessedStateId,
                mutationEnvelopeId: request.mutationEnvelopeId,
                createdAtMs: request.createdAtMs
            )
        } catch {
            log.error("produceAnswerPacketJson FFI failed (\(String(describing: error), privacy: .public))")
            return nil
        }
        #else
        return nil
        #endif
    }
}
