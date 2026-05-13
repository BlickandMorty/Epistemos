import Testing
import Foundation
@testable import Epistemos

/// V6.2 verification tests for the Swift Rust-side AnswerPacket
/// production-caller bridge. Proves the FFI added at
/// `agent_core/src/bridge.rs::produce_answer_packet_json` is reachable
/// from Swift and the canonical AnswerPacket JSON it returns decodes
/// through the same Codable contract the Swift consumer already uses.
@Suite("Rust AnswerPacket Producer Client (V6.2)")
struct RustAnswerPacketProducerClientTests {

    private func sampleRequest(
        attention: RustAnswerPacketAttentionWire = .dynamic,
        vrm: RustAnswerPacketVrmLabelWire = .verified,
        stop: String = "end_turn",
        tokens: UInt32 = 120
    ) -> RustAnswerPacketProduceRequest {
        RustAnswerPacketProduceRequest(
            packetId: "swift-test-\(UUID().uuidString)",
            stopReason: stop,
            outputTokens: tokens,
            attentionMode: attention,
            vrmLabel: vrm,
            witnessedStateId: "ws-swift-test",
            mutationEnvelopeId: "me-swift-test",
            createdAtMs: 1715000000000
        )
    }

    #if canImport(agent_coreFFI)
    @Test("Producer FFI returns a non-empty JSON string for a typical turn")
    func producerReturnsJson() {
        let json = RustAnswerPacketProducerClient.produceJson(request: sampleRequest())
        #expect(json != nil, "FFI must succeed when agent_coreFFI is linked")
        #expect(!(json ?? "").isEmpty)
    }

    @Test("Producer JSON contains the canonical AnswerPacket field names")
    func producerJsonShape() throws {
        let json = RustAnswerPacketProducerClient.produceJson(request: sampleRequest())
        let payload = try #require(json)
        // Doctrine pin — every AnswerPacket carries these top-level
        // fields by Codable contract. If any move/rename, the Swift
        // consumer breaks.
        let fields = [
            "\"id\"",
            "\"claims\"",
            "\"residency_signals\"",
            "\"ui_label\"",
            "\"attention_mode\"",
            "\"witnessed_state_ref\"",
            "\"mutation_envelope_ref\"",
        ]
        for f in fields {
            #expect(payload.contains(f),
                "AnswerPacket JSON must contain \(f); got \(payload)")
        }
    }

    @Test("Default end_turn produces exactly one Empirical self-witness claim")
    func defaultTurnProducesOneSelfWitnessClaim() throws {
        let req = sampleRequest(attention: .unavailable, vrm: .plausibleButUnverified)
        let json = try #require(RustAnswerPacketProducerClient.produceJson(request: req))
        let data = try #require(json.data(using: .utf8))
        let payload = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let claims = try #require(payload["claims"] as? [[String: Any]])
        #expect(claims.count == 1,
            "default end_turn must emit exactly one self-witness claim; got \(claims.count)")
        let firstKind = claims.first?["kind"] as? String
        #expect(firstKind == "empirical",
            "self-witness kind must be empirical; got \(firstKind ?? "nil")")
    }

    @Test("Tool-use turn produces a second Empirical claim documenting the tool request")
    func toolUseTurnProducesSecondClaim() throws {
        let req = sampleRequest(attention: .dynamic, vrm: .verified, stop: "tool_use")
        let json = try #require(RustAnswerPacketProducerClient.produceJson(request: req))
        let data = try #require(json.data(using: .utf8))
        let payload = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let claims = try #require(payload["claims"] as? [[String: Any]])
        #expect(claims.count == 2,
            "tool_use turn must emit two empirical claims; got \(claims.count)")
        let kinds = claims.compactMap { $0["kind"] as? String }
        #expect(kinds.allSatisfy { $0 == "empirical" },
            "both claims must be empirical; got \(kinds)")
        let texts = claims.compactMap { $0["text"] as? String }
        #expect(texts.contains { $0.contains("tool execution") },
            "one claim must reference tool execution; got \(texts)")
    }

    @Test("Static-fallback turn emits the StaticFallbackAcknowledged claim required for doctrine consistency")
    func staticFallbackTurnEmitsAckClaim() throws {
        let req = sampleRequest(attention: .staticFallback, vrm: .speculative)
        let json = try #require(RustAnswerPacketProducerClient.produceJson(request: req))
        let data = try #require(json.data(using: .utf8))
        let payload = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let claims = try #require(payload["claims"] as? [[String: Any]])
        let kinds = claims.compactMap { $0["kind"] as? String }
        #expect(kinds.contains("static_fallback_acknowledged"),
            "static_fallback attention mode must emit a StaticFallbackAcknowledged claim; got \(kinds)")
        // Attention-mode wire form check.
        let attentionMode = payload["attention_mode"] as? String
        #expect(attentionMode == "static_fallback",
            "attention_mode must serialize as static_fallback; got \(attentionMode ?? "nil")")
    }

    @Test("Residency signals: at least one neutral signal per turn")
    func residencySignalsContainNeutralPlaceholder() throws {
        let req = sampleRequest()
        let json = try #require(RustAnswerPacketProducerClient.produceJson(request: req))
        let data = try #require(json.data(using: .utf8))
        let payload = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let signals = try #require(payload["residency_signals"] as? [[String: Any]])
        #expect(signals.count >= 1,
            "every turn must emit at least one residency signal; got \(signals.count)")
        // Neutral signal has verification_score = 0.5 — the canonical
        // "no opinion" placeholder until the Residency Governor wires.
        if let first = signals.first, let score = first["verification_score"] as? Double {
            #expect(abs(score - 0.5) < 1e-3,
                "neutral residency must report verification_score = 0.5; got \(score)")
        }
    }

    @Test("Empty packet id falls back to the sentinel \"unset-turn\"")
    func emptyPacketIdFallsBackToSentinel() throws {
        var req = sampleRequest()
        req = RustAnswerPacketProduceRequest(
            packetId: "",
            stopReason: req.stopReason,
            outputTokens: req.outputTokens,
            attentionMode: req.attentionMode,
            vrmLabel: req.vrmLabel,
            witnessedStateId: req.witnessedStateId,
            mutationEnvelopeId: req.mutationEnvelopeId,
            createdAtMs: req.createdAtMs
        )
        let json = try #require(RustAnswerPacketProducerClient.produceJson(request: req))
        #expect(json.contains("unset-turn"),
            "empty packet_id must fall back to the unset-turn sentinel; got \(json)")
    }
    #else
    @Test("Producer returns nil when agent_coreFFI is not linked (graceful degradation)")
    func producerReturnsNilWithoutFFI() {
        let json = RustAnswerPacketProducerClient.produceJson(request: sampleRequest())
        #expect(json == nil,
            "without agent_coreFFI, the client must return nil instead of crashing")
    }
    #endif
}
