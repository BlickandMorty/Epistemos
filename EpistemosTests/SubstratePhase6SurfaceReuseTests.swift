import Testing
import Foundation

@testable import Epistemos

// SUBSTRATE Phase 6 (owner 2026-06-20, SUBSTRATE_BUILD_SEQUENCE): "surface reuse" — every surface
// consumes the substrate via the frozen interfaces, not a divergent private path. This guards the
// answer-producing surfaces: each routes its per-answer provenance receipt through the ONE shared
// AnswerPacketEmitter (which persists + bounds it, Phase 2), so no surface can silently drop the
// substrate (losing the AnswerPacket / its durable history). Source-guard because the live emit
// paths are async + provider-backed (not unit-runnable headless).
@Suite("Substrate Phase 6 — surface reuse (answer surfaces emit through the shared substrate)")
struct SubstratePhase6SurfaceReuseTests {

    @Test("the answer-producing surfaces emit AnswerPackets through AnswerPacketEmitter.shared")
    func answerSurfacesEmitThroughSharedSubstrate() throws {
        // The streaming/chat completion surface must funnel its AnswerPacket
        // through the single substrate emitter — the one path that persists it.
        for file in [
            "Epistemos/Bridge/StreamingDelegate.swift",
        ] {
            let src = try loadMirroredSourceTextFile(file)
            #expect(
                src.contains("AnswerPacketEmitter.shared.emit("),
                "\(file) must route its AnswerPacket through the shared substrate emitter (surface reuse)")
        }
    }

    @Test("the shared emitter persists every emitted packet (the durable substrate reuse path)")
    func sharedEmitterPersists() throws {
        // The reuse point is durable: emit() funnels into the Phase 2 persistence seam, so a packet
        // produced by ANY surface survives relaunch (not just the in-memory ring).
        let emitter = try loadMirroredSourceTextFile("Epistemos/Engine/AnswerPacketEmitter.swift")
        #expect(emitter.contains("Self.persist("))
        #expect(emitter.contains("func persistedRecent(limit: Int)"))
    }
}
