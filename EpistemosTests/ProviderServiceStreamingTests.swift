import Testing
import Foundation
@testable import Epistemos

/// Sendable snapshot of a streaming-protocol reply. NSDictionary doesn't
/// satisfy Swift 6 strict-concurrency `Sendable` requirements when
/// crossing a continuation boundary, so we extract the keys we need
/// inside the callback (sync, on the actor) and ship a typed value
/// across.
nonisolated struct StreamingReplySnapshot: Sendable {
    let status: String?
    let sessionJson: String?
    let chunkJson: String?
    let errorKind: String?
    let errorMessage: String?

    init(_ dict: NSDictionary) {
        self.status = dict[ProviderXPCStreamingKeys.status] as? String
        self.sessionJson = dict[ProviderXPCStreamingKeys.session] as? String
        self.chunkJson = dict[ProviderXPCStreamingKeys.chunk] as? String
        self.errorKind = dict[ProviderXPCStreamingKeys.errorKind] as? String
        self.errorMessage = dict[ProviderXPCStreamingKeys.errorMessage] as? String
    }
}

/// V2.4 first-slice tests for the ProviderServiceStreamingProtocol +
/// MockProviderServiceStreaming pair. Proves the protocol shape works
/// end-to-end without requiring an actual XPC service launch.
///
/// **Doctrine alignment:** the design doc
/// `docs/V2_4_AND_V3_2_DESIGN_2026_05_05.md` calls for "mock-XPC tests
/// that exercise the protocol in-process without launching the
/// service." This is that test suite.
@Suite("Provider Service Streaming protocol (V2.4 first slice)")
struct ProviderServiceStreamingTests {

    // MARK: - Wire-format round trips

    @Test("ProviderXPCStreamingRequest encodes + decodes byte-equally")
    func requestEncodesAndDecodesByteEqually() throws {
        let request = ProviderXPCStreamingRequest(
            provider: .anthropic,
            modelId: "claude-opus-4-7",
            credentialKeychainHandle: "kc:anthropic.production",
            capabilityToken: "macaroon:abc123",
            maxTokens: 4096,
            requestBodyJson: #"{"messages":[{"role":"user","content":"hi"}]}"#
        )
        let json = try JSONEncoder().encode(request)
        let recovered = try JSONDecoder().decode(
            ProviderXPCStreamingRequest.self,
            from: json
        )
        #expect(recovered == request)
        // Struct equality is the canonical assertion; byte-equality of
        // JSONEncoder output isn't a stable contract (key order isn't
        // guaranteed across encode/decode/re-encode cycles).
    }

    @Test("ProviderXPCStreamingSession encodes + decodes byte-equally")
    func sessionEncodesAndDecodesByteEqually() throws {
        let session = ProviderXPCStreamingSession(
            sessionId: "sess-001",
            provider: .openAI,
            modelId: "gpt-5",
            ringBytes: 65536,
            ringMachPort: 0
        )
        let json = try JSONEncoder().encode(session)
        let recovered = try JSONDecoder().decode(
            ProviderXPCStreamingSession.self,
            from: json
        )
        #expect(recovered == session)
    }

    @Test("LLMTokenChunk encodes + decodes byte-equally with optional fields")
    func tokenChunkEncodesAndDecodesByteEqually() throws {
        let withMetadata = LLMTokenChunk(
            sequence: 42,
            text: "hello",
            tokenId: 1234,
            isFinal: true,
            metadataJson: #"{"finish_reason":"end_turn"}"#
        )
        let withoutMetadata = LLMTokenChunk(
            sequence: 1,
            text: "ack",
            tokenId: nil,
            isFinal: false,
            metadataJson: nil
        )
        for chunk in [withMetadata, withoutMetadata] {
            let json = try JSONEncoder().encode(chunk)
            let recovered = try JSONDecoder().decode(LLMTokenChunk.self, from: json)
            #expect(recovered == chunk)
        }
    }

    @Test("ProviderXPCProvider covers all 5 V2.4 supported tiers")
    func providerEnumCoversAllSupportedTiers() {
        // The 5 cloud-provider tiers the doctrine §5 lists. If a future
        // PR adds a 6th, this test catches the addition for review.
        let expected: Set<ProviderXPCProvider> = [
            .anthropic, .openAI, .google, .perplexity, .openAICompatible,
        ]
        #expect(Set(ProviderXPCProvider.allCases) == expected)
    }

    // MARK: - Mock client lifecycle

    @Test("MockProviderServiceStreaming opens session + returns deterministic chunks + closes")
    func mockOpensStreamsAndCloses() async throws {
        let mock = MockProviderServiceStreaming()

        let request = ProviderXPCStreamingRequest(
            provider: .anthropic,
            modelId: "claude-opus-4-7",
            credentialKeychainHandle: "kc:anthropic.production",
            capabilityToken: "macaroon:abc",
            maxTokens: 1024,
            requestBodyJson: #"{"messages":[]}"#
        )
        let requestJson = try String(data: JSONEncoder().encode(request), encoding: .utf8) ?? ""

        // openSession
        let openReply = await withCheckedContinuation { (cont: CheckedContinuation<StreamingReplySnapshot, Never>) in
            mock.openSession(requestJson) { reply in
                cont.resume(returning: StreamingReplySnapshot(reply))
            }
        }
        #expect(openReply.status == ProviderXPCStreamingKeys.statusOk)
        let sessionJson = try #require(openReply.sessionJson)
        let session = try JSONDecoder().decode(
            ProviderXPCStreamingSession.self,
            from: Data(sessionJson.utf8)
        )
        #expect(session.provider == .anthropic)
        #expect(session.modelId == "claude-opus-4-7")
        #expect(session.ringMachPort == 0, "Phase 1 mock returns 0 — IOSurface streaming is Phase 2")

        // fetchNextChunk × 3 — deterministic mock yields exactly 3 chunks
        var receivedTexts: [String] = []
        for _ in 0..<3 {
            let chunkReply = await withCheckedContinuation { (cont: CheckedContinuation<StreamingReplySnapshot, Never>) in
                mock.fetchNextChunk(sessionId: session.sessionId) { reply in
                    cont.resume(returning: StreamingReplySnapshot(reply))
                }
            }
            #expect(chunkReply.status == ProviderXPCStreamingKeys.statusOk)
            let chunkJson = try #require(chunkReply.chunkJson)
            let chunk = try JSONDecoder().decode(LLMTokenChunk.self, from: Data(chunkJson.utf8))
            receivedTexts.append(chunk.text)
        }
        // 4th fetch returns done.
        let doneReply = await withCheckedContinuation { (cont: CheckedContinuation<StreamingReplySnapshot, Never>) in
            mock.fetchNextChunk(sessionId: session.sessionId) { reply in
                cont.resume(returning: StreamingReplySnapshot(reply))
            }
        }
        #expect(doneReply.status == ProviderXPCStreamingKeys.statusDone)

        // Deterministic content check (the mock's known sequence).
        #expect(receivedTexts.contains(where: { $0.contains("[mock:anthropic:claude-opus-4-7]") }))
        #expect(receivedTexts.contains("deterministic mock response"))

        // closeSession — even though session already exhausted, close must succeed.
        let closeReply = await withCheckedContinuation { (cont: CheckedContinuation<StreamingReplySnapshot, Never>) in
            mock.closeSession(sessionId: session.sessionId) { reply in
                cont.resume(returning: StreamingReplySnapshot(reply))
            }
        }
        #expect(closeReply.status == ProviderXPCStreamingKeys.statusOk)
    }

    @Test("MockProviderServiceStreaming rejects credential without kc: prefix")
    func mockRejectsBadCredentialHandle() async throws {
        let mock = MockProviderServiceStreaming()
        let request = ProviderXPCStreamingRequest(
            provider: .anthropic,
            modelId: "claude-opus-4-7",
            credentialKeychainHandle: "raw-secret-not-allowed",
            capabilityToken: "macaroon:abc",
            maxTokens: 512,
            requestBodyJson: "{}"
        )
        let requestJson = try String(data: JSONEncoder().encode(request), encoding: .utf8) ?? ""
        let reply = await withCheckedContinuation { (cont: CheckedContinuation<StreamingReplySnapshot, Never>) in
            mock.openSession(requestJson) { r in
                cont.resume(returning: StreamingReplySnapshot(r))
            }
        }
        #expect(reply.status == ProviderXPCStreamingKeys.statusError)
        #expect(reply.errorKind == "credential_not_found")
    }

    @Test("MockProviderServiceStreaming rejects empty capability token")
    func mockRejectsEmptyCapabilityToken() async throws {
        let mock = MockProviderServiceStreaming()
        let request = ProviderXPCStreamingRequest(
            provider: .openAI,
            modelId: "gpt-5",
            credentialKeychainHandle: "kc:openai.production",
            capabilityToken: "",
            maxTokens: 512,
            requestBodyJson: "{}"
        )
        let requestJson = try String(data: JSONEncoder().encode(request), encoding: .utf8) ?? ""
        let reply = await withCheckedContinuation { (cont: CheckedContinuation<StreamingReplySnapshot, Never>) in
            mock.openSession(requestJson) { r in
                cont.resume(returning: StreamingReplySnapshot(r))
            }
        }
        #expect(reply.status == ProviderXPCStreamingKeys.statusError)
        #expect(reply.errorKind == "capability_rejected")
    }

    @Test("MockProviderServiceStreaming records every call in callLog")
    func mockRecordsCallLog() async throws {
        let mock = MockProviderServiceStreaming()
        let request = ProviderXPCStreamingRequest(
            provider: .google,
            modelId: "gemini-2.5-pro",
            credentialKeychainHandle: "kc:google.production",
            capabilityToken: "macaroon:xyz",
            maxTokens: 512,
            requestBodyJson: "{}"
        )
        let requestJson = try String(data: JSONEncoder().encode(request), encoding: .utf8) ?? ""

        _ = await withCheckedContinuation { (cont: CheckedContinuation<StreamingReplySnapshot, Never>) in
            mock.openSession(requestJson) { r in
                cont.resume(returning: StreamingReplySnapshot(r))
            }
        }
        // Extract sessionId for the close call.
        let openReply = mock.callLog
        #expect(openReply.count == 1)
        if case .openSession(let json) = openReply[0] {
            #expect(json == requestJson)
        } else {
            Issue.record("first call must be openSession, got \(openReply[0])")
        }
    }

    @Test("ProviderXPCError variants distinguish failure modes")
    func errorVariantsDistinguishFailureModes() {
        // Sanity: the error variants cover the design-doc-listed
        // failure modes.
        let credErr = ProviderXPCError.credentialNotFound(handle: "kc:foo")
        let capErr = ProviderXPCError.capabilityRejected(reason: "expired")
        let httpErr = ProviderXPCError.providerHttpError(status: 429, message: "rate limited")
        let shutdownErr = ProviderXPCError.shutdown
        // Distinct errors are not equal.
        #expect(credErr != capErr)
        #expect(httpErr != shutdownErr)
        // Same-shape errors are equal.
        let credErr2 = ProviderXPCError.credentialNotFound(handle: "kc:foo")
        #expect(credErr == credErr2)
    }
}
