//
//  ActOsaurusSendHarnessTests.swift
//  EpistemosTests
//
//  SEND-TEXT HARNESS (queue 0.23 / gate (d) for 0.4) — the auditor-mandated repeatable
//  real-state test (P0 AUDITOR CORRECTION, addendum c0072a78d): a SUCCESSFUL in-process
//  act send returns a NON-EMPTY reply with served-model == selected-model, exercising the
//  SAME live entry point the 0.4 (c) cite names:
//
//    SharedActInference.actStreamIfArmed → ActOsaurusStreamingHandler.make(bridge:)
//      → OsaurusActBridge.runTurnStreamingInProcess(requestedModel:)
//        → OsaurusCore.CoreModelService.generateStream(requestedModel:)
//          → EpistemosBridgedModelService (CoreModelService.swift:61 localServices)
//            → the registered EpistemosModelProvider
//
//  Deterministic by design: a fake provider echoes the SERVED modelId into the reply, so
//  the test asserts served==selected WITHOUT a live MLX/model load (gate (e) — the real
//  model runtime — is proven separately by the loop's live GUI send). 0 skipped / 0 xfail.
//

import Foundation
import Testing

#if !EPISTEMOS_APP_STORE
import OsaurusCore
@testable import Epistemos

@Suite(.serialized)
struct ActOsaurusSendHarnessTests {

    /// Stands in for the owner's registered model provider. Echoes the SERVED `modelId`
    /// back into the streamed reply so the test can assert served-model == selected-model
    /// (and that a non-empty reply actually streamed). No live inference required.
    private struct HarnessProvider: EpistemosModelProvider {
        let ids: [String]
        func availableModelIds() -> [String] { ids }
        func streamGenerate(prompt: String, modelId: String, maxTokens: Int)
            -> AsyncThrowingStream<String, Error>
        {
            AsyncThrowingStream { continuation in
                continuation.yield("ACK ")
                continuation.yield(modelId)  // SERVED model id echoed into the reply
                continuation.finish()
            }
        }
    }

    @Test("act send harness: in-process entry point streams a non-empty reply; served-model == selected-model")
    func actSend_servedEqualsSelected() async throws {
        let selected = "epi-harness-2b"
        EpistemosModelBridge.register(HarnessProvider(ids: [selected]))

        // Drive the REAL act in-process entry point (the same OsaurusActBridge method the
        // shared act composer's streaming factory calls — ActOsaurusStreamingHandler.make).
        let bridge = OsaurusActBridge()
        let stream = try await bridge.runTurnStreamingInProcess(
            prompt: "ping", systemPrompt: nil, maxTokens: 32, requestedModel: selected)

        var reply = ""
        for try await token in stream { reply += token }

        // (d) A SUCCESSFUL in-process send returns a NON-EMPTY reply...
        #expect(!reply.isEmpty)
        // ...and served-model == selected-model (the served id echoed back equals the requested model).
        #expect(reply == "ACK \(selected)")
        #expect(reply.contains(selected))
    }

    @Test("act send harness: a model no provider serves does NOT silently substitute — honest failure")
    func actSend_unknownModelFailsHonestly() async throws {
        EpistemosModelBridge.register(HarnessProvider(ids: ["epi-harness-2b"]))

        let bridge = OsaurusActBridge()
        // A model id NO registered service handles must NOT silently route to some other model
        // (no silent Codex/Qwen substitution — owner #1). It surfaces an honest throw OR an empty
        // stream; either way it must NOT yield a fabricated reply for a different model.
        var produced = ""
        var threw = false
        do {
            let stream = try await bridge.runTurnStreamingInProcess(
                prompt: "ping", systemPrompt: nil, maxTokens: 32, requestedModel: "model-no-one-serves-xyz")
            for try await token in stream { produced += token }
        } catch {
            threw = true
        }
        // Honest: either it threw, or it produced nothing — never a silent substituted reply.
        #expect(threw || produced.isEmpty)
        #expect(!produced.contains("epi-harness-2b"))  // never served the wrong (registered) model
    }
}
#endif
