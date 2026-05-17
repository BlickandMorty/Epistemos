import Testing
import Foundation
@testable import Epistemos

@Suite("AnswerPacket Codable — V6.2 schema round-trip + backward-compat contracts")
struct AnswerPacketCodableTests {

    // MARK: - Wire-form round-trip

    @Test("AnswerPacket round-trips through JSON with answerPacketId-aware fields")
    func answerPacketRoundTripsAllFields() throws {
        let original = AnswerPacket(
            id: "pkt-12345",
            claims: [],
            residencySignals: [.neutral],
            uiLabel: .verified,
            attentionMode: .staticFallback,
            interruptBucket: .high,
            witnessedStateRef: "stop:end_turn;in:42;out:101",
            semanticDeltaRef: nil,
            mutationEnvelopeRef: "pkt-12345"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnswerPacket.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.uiLabel == original.uiLabel)
        #expect(decoded.attentionMode == original.attentionMode)
        #expect(decoded.interruptBucket == original.interruptBucket)
        #expect(decoded.witnessedStateRef == original.witnessedStateRef)
        #expect(decoded.mutationEnvelopeRef == original.mutationEnvelopeRef)
        #expect(decoded == original,
            "full Equatable comparison must round-trip cleanly")
    }

    @Test("AnswerPacket Codable wire form uses snake_case key for interrupt_bucket")
    func answerPacketWireFormUsesSnakeCase() throws {
        let packet = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 1,
            outputTokens: 1,
            interruptBucket: .medium
        )
        let data = try JSONEncoder().encode(packet)
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("\"interrupt_bucket\":\"medium\""),
            "wire form must use snake_case `interrupt_bucket`, got \(json)")
        #expect(json.contains("\"attention_mode\""),
            "wire form must use snake_case `attention_mode`, got \(json)")
    }

    // MARK: - Backward compat

    @Test("V1 packet (no interrupt_bucket key) decodes as .unavailable")
    func v1PacketDecodesUnavailableBucket() throws {
        let v1Json = """
        {
            "id": "v1-legacy",
            "claims": [],
            "residency_signals": [],
            "ui_label": "plausible_but_unverified",
            "attention_mode": "unavailable",
            "witnessed_state_ref": "stop:end_turn;in:0;out:0",
            "mutation_envelope_ref": "v1-legacy"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnswerPacket.self, from: v1Json)
        #expect(decoded.id == "v1-legacy")
        #expect(decoded.interruptBucket == .unavailable,
            "legacy packets without interrupt_bucket must decode as .unavailable; got \(decoded.interruptBucket)")
    }

    @Test("V0 packet (no attention_mode key) decodes as .unavailable")
    func v0PacketDecodesUnavailableAttentionMode() throws {
        let v0Json = """
        {
            "id": "v0-legacy",
            "claims": [],
            "residency_signals": [],
            "ui_label": "verified",
            "witnessed_state_ref": "stop:end_turn;in:0;out:0",
            "mutation_envelope_ref": "v0-legacy"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnswerPacket.self, from: v0Json)
        #expect(decoded.attentionMode == .unavailable)
        #expect(decoded.interruptBucket == .unavailable)
    }

    // MARK: - ChatMessage answerPacketId binding

    @Test("ChatMessage round-trips with answerPacketId field")
    func chatMessageRoundTripsAnswerPacketId() throws {
        let original = ChatMessage(
            id: "msg-abc",
            chatId: "chat-1",
            role: .assistant,
            content: "Hi there",
            answerPacketId: "pkt-deadbeef",
            agentRunId: "run-agent-123"
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: encoded)

        #expect(decoded.id == "msg-abc")
        #expect(decoded.content == "Hi there")
        #expect(decoded.answerPacketId == "pkt-deadbeef",
            "answerPacketId must round-trip cleanly")
        #expect(decoded.agentRunId == "run-agent-123",
            "agentRunId must round-trip cleanly")
    }

    @Test("Legacy ChatMessage (no answerPacketId) decodes as nil")
    func legacyChatMessageDecodesNilAnswerPacketId() throws {
        // Minimal legacy ChatMessage JSON — only fields that
        // pre-2026-05-12 schemas had. The new optional answerPacketId
        // field must decode as nil for any persisted message that
        // predates Option B.
        let legacyJson = """
        {
            "id": "legacy-msg-1",
            "chatId": "legacy-chat-1",
            "role": "assistant",
            "content": "Hello from before V6.2",
            "attachments": [],
            "isError": false,
            "createdAt": 700000000.0,
            "isVaultBriefing": false,
            "artifacts": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: legacyJson)
        #expect(decoded.id == "legacy-msg-1")
        #expect(decoded.answerPacketId == nil,
            "pre-V6.2 ChatMessage must decode answerPacketId as nil; got \(decoded.answerPacketId ?? "non-nil")")
        #expect(decoded.agentRunId == nil,
            "legacy ChatMessage must decode missing agentRunId as nil")
    }

    @Test("ChatMessage with nil answerPacketId emits absent key (not key:null) — clean wire form")
    func chatMessageOmitsNilAnswerPacketIdInJSON() throws {
        let message = ChatMessage(
            id: "msg-no-packet",
            chatId: "chat-1",
            role: .assistant,
            content: "No packet"
            // answerPacketId not specified — defaults nil
        )
        let encoded = try JSONEncoder().encode(message)
        let json = String(decoding: encoded, as: UTF8.self)

        // Swift's default Codable encodes nil optionals as omitted keys.
        // If a future change flips to `encodeIfPresent → encode(nil)`,
        // this test will catch it.
        #expect(!json.contains("\"answerPacketId\":null"),
            "nil answerPacketId must NOT emit as key:null — got \(json)")
        #expect(!json.contains("\"agentRunId\":null"),
            "nil agentRunId must NOT emit as key:null — got \(json)")
    }

    // MARK: - Enum wire forms

    @Test("AttentionMode wire form uses snake_case for staticFallback")
    func attentionModeWireFormSnakeCase() throws {
        let modes: [AttentionMode] = [.dynamic, .staticFallback, .unavailable]
        let encoded = try JSONEncoder().encode(modes)
        let json = String(decoding: encoded, as: UTF8.self)

        #expect(json.contains("\"dynamic\""))
        #expect(json.contains("\"static_fallback\""))
        #expect(json.contains("\"unavailable\""))
        #expect(!json.contains("\"staticFallback\""),
            "wire form must use snake_case, not camelCase")
    }

    @Test("InterruptBucket wire form matches V6.2 §1.5 bucket names")
    func interruptBucketWireFormCanonical() throws {
        let buckets: [InterruptBucket] = [.low, .medium, .high, .unavailable]
        let encoded = try JSONEncoder().encode(buckets)
        let json = String(decoding: encoded, as: UTF8.self)

        // V6.2 §1.5 lock-in: bucket names are "low", "medium", "high".
        // Any rename would break replay tooling that grep's the wire
        // form, so this test catches the regression at the Swift side.
        #expect(json.contains("\"low\""))
        #expect(json.contains("\"medium\""))
        #expect(json.contains("\"high\""))
        #expect(json.contains("\"unavailable\""))
    }

    // MARK: - AnswerPacket nonisolated conformance proof

    @Test("AnswerPacket Equatable is usable in nonisolated context")
    nonisolated func answerPacketEquatableCrossesActorBoundary() {
        // If this test compiles, the `nonisolated public struct
        // AnswerPacket` declaration is doing its job: the Equatable
        // conformance is nonisolated and can be used from nonisolated
        // call sites (here, this test function itself is `nonisolated`).
        //
        // Before commit 6d2bd399e this test wouldn't compile — the
        // module's `defaultIsolation: MainActor` would have made the
        // Equatable conformance MainActor-isolated, breaking nonisolated
        // use. This test locks the fix into place.
        let a = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 1,
            outputTokens: 1,
            attentionMode: .dynamic,
            interruptBucket: .low
        )
        let b = a
        #expect(a == b)
    }
}
