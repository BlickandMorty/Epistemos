import Testing
@testable import Epistemos

/// Fix #2 STAGE 1 (research STOP_REINVENTING_AUDIT): the pure shadow machinery for
/// wiring the dead `RuntimeRouter` into live dispatch observe-only. These tests pin
/// the role mapping, verdict→lane extraction, and parity comparison deterministically.
@Suite("RuntimeRouter shadow machinery (fix #2 STAGE 1)")
struct RuntimeRouterShadowTests {

    @Test("operating mode maps to the router role taxonomy")
    func roleMapping() {
        #expect(RuntimeRouterShadow.role(forOperatingMode: .fast) == .quick)
        #expect(RuntimeRouterShadow.role(forOperatingMode: .thinking) == .reasoning)
        #expect(RuntimeRouterShadow.role(forOperatingMode: .pro) == .code)
        #expect(RuntimeRouterShadow.role(forOperatingMode: .agent) == .toolCaller)
    }

    @Test("acceptedLane: accept→its lane, escalate→target lane, reject→nil")
    func acceptedLane() {
        let cap = RuntimeCapability(tier: .currentApp, contextWindow: 8192)
        #expect(
            RuntimeRouterShadow.acceptedLane(from: .accept(lane: .mlx, capability: cap)) == .mlx
        )
        #expect(
            RuntimeRouterShadow.acceptedLane(
                from: .escalate(from: .mlx, to: .cloud(provider: "claude"), reason: .laneDisabled)
            ) == .cloud(provider: "claude")
        )
        #expect(
            RuntimeRouterShadow.acceptedLane(from: .reject(reason: .noLaneAvailable)) == nil
        )
    }

    @Test("parityMatches compares by stableID; nil (reject) never matches")
    func parity() {
        #expect(RuntimeRouterShadow.parityMatches(routerLane: .mlx, liveLane: .mlx) == true)
        #expect(
            RuntimeRouterShadow.parityMatches(
                routerLane: .cloud(provider: "claude"), liveLane: .cloud(provider: "claude")
            ) == true
        )
        // Different cloud providers do NOT match.
        #expect(
            RuntimeRouterShadow.parityMatches(
                routerLane: .cloud(provider: "openai"), liveLane: .cloud(provider: "claude")
            ) == false
        )
        #expect(RuntimeRouterShadow.parityMatches(routerLane: .gguf, liveLane: .mlx) == false)
        // A reject (nil router lane) never matches a live lane.
        #expect(RuntimeRouterShadow.parityMatches(routerLane: nil, liveLane: .mlx) == false)
    }

    @Test("missionPacket carries the mapped role, objective, and demand flags")
    func packetBuild() {
        let packet = RuntimeRouterShadow.missionPacket(
            operatingMode: .pro,
            objective: "find my note about X",
            requiresTools: true,
            privacySensitive: true,
            preferredLane: .mlx
        )
        #expect(packet.role == .code)
        #expect(packet.objective == "find my note about X")
        #expect(packet.requiresTools == true)
        #expect(packet.privacySensitive == true)
        #expect(packet.preferredLane == .mlx)
    }

    @Test("flag is OFF by default → the router is not consulted on the live path")
    func flagDefaultsOff() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_RUNTIMEROUTER_LIVE_V0"] == nil {
            #expect(RuntimeRouterShadow.armed == false)
        }
    }

    // MARK: - STAGE 1b: live ResolvedBrainDescriptor → RuntimeLane mapper

    @Test("liveLane maps cloud + Apple Intelligence directly; unavailable → nil")
    func liveLaneDirectCases() {
        let classify: (String) -> RuntimeLane = { _ in .mlx }
        #expect(
            RuntimeRouterShadow.liveLane(
                from: .cloud(provider: "claude", displayName: "Claude"), localLaneForModelID: classify
            ) == .cloud(provider: "claude")
        )
        #expect(
            RuntimeRouterShadow.liveLane(from: .appleIntelligence, localLaneForModelID: classify)
                == .appleIntelligence
        )
        #expect(
            RuntimeRouterShadow.liveLane(
                from: .unavailable(reason: "no model"), localLaneForModelID: classify
            ) == nil
        )
    }

    @Test("liveLane classifies a local model via the injected mlx/gguf classifier")
    func liveLaneLocalClassifier() {
        // The injected classifier mirrors LocalTextModelID.runtimeKind at the live site.
        let classify: (String) -> RuntimeLane = { id in id.contains("gguf") ? .gguf : .mlx }
        #expect(
            RuntimeRouterShadow.liveLane(
                from: .local(modelId: "google/gemma-4-E2B-it-qat-q4_0-gguf", displayName: "Gemma"),
                localLaneForModelID: classify
            ) == .gguf
        )
        #expect(
            RuntimeRouterShadow.liveLane(
                from: .local(modelId: "qwen3_4B4Bit", displayName: "Qwen"),
                localLaneForModelID: classify
            ) == .mlx
        )
    }

    @Test("liveLane parity: a resolved descriptor and the router's verdict agree by lane")
    func liveLaneParityRoundTrip() throws {
        let classify: (String) -> RuntimeLane = { _ in .mlx }
        let live = try #require(
            RuntimeRouterShadow.liveLane(
                from: .cloud(provider: "openai", displayName: "OpenAI"), localLaneForModelID: classify
            )
        )
        let routerLane = RuntimeRouterShadow.acceptedLane(
            from: .accept(
                lane: .cloud(provider: "openai"),
                capability: RuntimeCapability(tier: .currentApp, contextWindow: 8192)
            )
        )
        #expect(RuntimeRouterShadow.parityMatches(routerLane: routerLane, liveLane: live))
    }
}
