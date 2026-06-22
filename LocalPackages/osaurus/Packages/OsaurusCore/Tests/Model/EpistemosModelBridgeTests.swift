//
//  EpistemosModelBridgeTests.swift
//  osaurusTests
//
//  Proves the EPISTEMOS MODEL BRIDGE seam — the OsaurusCore side of "the owner's
//  custom GGUF/QAT models work in the Osaurus act chat" (owner 2026-06-22; addendum
//  item 4 "OWNER'S MODELS IN CHAT / Epistemos Picks gap"). The Epistemos app registers
//  an `EpistemosModelProvider`; `EpistemosBridgedModelService` adapts it into the
//  Osaurus `ModelService` protocol so `ChatEngine`/`CoreModelService` can route
//  generation to the owner's models. Real-state test, no naive stub: it registers a
//  fake provider and asserts availability + handles() + actual streamed routing.
//

import Foundation
import Testing

@testable import OsaurusCore

/// Serialized: these tests mutate the process-global provider registry, so they must
/// not interleave with each other (register/reset races would be flaky otherwise).
@Suite(.serialized)
struct EpistemosModelBridgeTests {

    /// Stands in for the Epistemos app's real provider — exposes model ids and echoes
    /// deterministic tokens, so the bridge's routing is verifiable without the app module.
    private struct FakeProvider: EpistemosModelProvider {
        let ids: [String]
        let tokens: [String]
        func availableModelIds() -> [String] { ids }
        func streamGenerate(prompt: String, modelId: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
            let tokens = self.tokens
            return AsyncThrowingStream { continuation in
                for token in tokens { continuation.yield(token) }
                continuation.finish()
            }
        }
    }

    @Test("bridged service declines nil / unknown models — never falsely claims to handle")
    func bridgedServiceDeclinesUnknown() {
        let svc = EpistemosBridgedModelService()
        // Deterministic regardless of registration state: a nil model is never handled,
        // and a model id no provider exposes is never handled.
        #expect(svc.handles(requestedModel: nil) == false)
        #expect(svc.handles(requestedModel: "definitely-not-registered-xyz") == false)
    }

    @Test("registering the owner's provider makes its models available + routable through the bridge")
    func registeredOwnerModelsRouteThroughBridge() async throws {
        EpistemosModelBridge.register(FakeProvider(ids: ["epi-qat-2b", "epi-gguf-7b"], tokens: ["Hel", "lo"]))
        // Hygiene: clear the process-global registration so it can't leak into other tests.
        defer { EpistemosModelBridge.resetForTesting() }

        // The owner's models are surfaced — this is exactly what providedModelIds() feeds the act UI.
        let ids = EpistemosModelBridge.providedModelIds()
        #expect(ids.contains("epi-qat-2b"))
        #expect(ids.contains("epi-gguf-7b"))

        let svc = EpistemosBridgedModelService()
        #expect(svc.isAvailable())                                         // a provider is registered
        #expect(svc.handles(requestedModel: "epi-qat-2b"))                 // owner's model → handled
        #expect(svc.handles(requestedModel: "epi-gguf-7b"))
        #expect(svc.handles(requestedModel: "apple-foundation") == false)  // not the owner's → declined

        // Generation actually routes to the provider's stream (the owner's model answers in chat).
        let stream = try await svc.streamDeltas(
            messages: [ChatMessage(role: "user", content: "hi")],
            parameters: GenerationParameters(temperature: 0.7, maxTokens: 64),
            requestedModel: "epi-qat-2b",
            stopSequences: []
        )
        var out = ""
        for try await delta in stream { out += delta }
        #expect(out == "Hello")
    }

    @Test("with no provider registered the bridge is honestly inert (byte-identical default)")
    func inertWhenNoProvider() {
        EpistemosModelBridge.resetForTesting()
        defer { EpistemosModelBridge.resetForTesting() }
        let svc = EpistemosBridgedModelService()
        #expect(svc.isAvailable() == false)
        #expect(svc.handles(requestedModel: "epi-qat-2b") == false)
        #expect(EpistemosModelBridge.providedModelIds().isEmpty)
    }

    // Owner 2026-06-22 (#1 concern): the act surface seeds the default-agent model to the owner's
    // first model so the FIRST send uses THEIR model. The seed decision is pure + must (a) seed the
    // owner's first model on a fresh install, (b) NEVER re-seed once seeded (don't clobber the
    // owner's later choice), (c) skip — WITHOUT latching — when no owner model is registered yet
    // (so a later mount retries once the bridge is up).
    @Test("owner default-model seed decision: seeds first model once, skips when seeded or empty")
    func ownerDefaultModelSeedDecision() {
        // Fresh + owner has models → seed the first.
        #expect(EpistemosOsaurusChatHost.ownerModelToSeed(
            alreadySeeded: false, ownerModels: ["epi-qat-2b", "epi-gguf-7b"]) == "epi-qat-2b")
        // Already seeded → never re-seed (don't clobber the owner's later picker choice).
        #expect(EpistemosOsaurusChatHost.ownerModelToSeed(
            alreadySeeded: true, ownerModels: ["epi-qat-2b"]) == nil)
        // Not seeded but no owner model yet → skip (caller must NOT latch, so it retries later).
        #expect(EpistemosOsaurusChatHost.ownerModelToSeed(
            alreadySeeded: false, ownerModels: []) == nil)
    }
}
