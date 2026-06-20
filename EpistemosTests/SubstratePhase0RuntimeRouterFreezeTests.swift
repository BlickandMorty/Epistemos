import Testing
import Foundation

@testable import Epistemos

// SUBSTRATE Phase 0 (owner 2026-06-20, SUBSTRATE_BUILD_SEQUENCE): FREEZE the RuntimeRouter lane API.
// The lanes are the model-agnostic routing surface the substrate builds against; the future new
// model "is just a future lane" (additive). The frozen contract: each existing lane's `stableID`
// (the persistence + router-routing identity inside RouteVerdict / RuntimeRouterMetrics) never
// drifts, and the current model-agnostic floor (mlx/gguf/apple/cloud×4/stub) stays present. Adding
// a lane later is allowed; renaming/removing an existing one must be deliberate (fails this test).
@Suite("Substrate Phase 0 — RuntimeRouter lane API freeze")
struct SubstratePhase0RuntimeRouterFreezeTests {

    // The lane stableIDs are frozen — a rename silently corrupts persisted RouteVerdicts + metrics.
    @Test("RuntimeLane stableIDs are frozen")
    func laneStableIDsFrozen() {
        #expect(RuntimeLane.mlx.stableID == "mlx")
        #expect(RuntimeLane.gguf.stableID == "gguf")
        #expect(RuntimeLane.appleIntelligence.stableID == "apple_intelligence")
        #expect(RuntimeLane.cloud(provider: "claude").stableID == "cloud:claude")
        #expect(RuntimeLane.stub.stableID == "stub")
    }

    // The known lanes the router always offers (honest "lane present, maybe no executor wired").
    // Presence-of-floor, not exact-equality — so attaching the new-model lane later is additive.
    @Test("knownLanes include the current model-agnostic floor (mlx/gguf/apple/cloud×4/stub)")
    func knownLanesFloorPresent() {
        let ids = Set(RuntimeLane.knownLanes.map(\.stableID))
        for required in ["mlx", "gguf", "apple_intelligence",
                         "cloud:claude", "cloud:openai", "cloud:gemini", "cloud:perplexity", "stub"] {
            #expect(ids.contains(required))
        }
    }

    // RuntimeLane is Codable (persisted inside RouteVerdict / RuntimeRouterMetrics) — every known
    // lane, including the `cloud(provider:)` associated-value case, must round-trip stably.
    @Test("RuntimeLane Codable round-trips for every known lane")
    func laneCodableRoundTrips() throws {
        for lane in RuntimeLane.knownLanes {
            let data = try JSONEncoder().encode(lane)
            let decoded = try JSONDecoder().decode(RuntimeLane.self, from: data)
            #expect(decoded == lane)
        }
    }
}
