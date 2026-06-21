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

    @Test("lane(forRuntimeKind:) classifies a local model's runtime to its lane")
    func laneForRuntimeKind() {
        #expect(RuntimeRouterShadow.lane(forRuntimeKind: .gguf) == .gguf)
        #expect(RuntimeRouterShadow.lane(forRuntimeKind: .mlx) == .mlx)
        // .remote only appears for non-local descriptors → falls back to .mlx.
        #expect(RuntimeRouterShadow.lane(forRuntimeKind: .remote) == .mlx)
    }

    @Test("the live composition (liveLane + lane(forRuntimeKind:)) classifies local picks end-to-end")
    func liveLaneComposedWithRuntimeKind() {
        // Mirrors the live site: a .local descriptor classified via runtimeKind.
        let classify: (String) -> RuntimeLane = { id in
            RuntimeRouterShadow.lane(forRuntimeKind: id.contains("gguf") ? .gguf : .mlx)
        }
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

    // MARK: - STAGE 1b LIVE WIRING (source-guard)

    // The live compile() seam is FFI-backed (not unit-runnable headless), so a source-guard pins
    // the observe-only contract: compile() calls recordLiveParity AND still returns `compiled`
    // unchanged, and the recorder is `armed`-gated (pure no-op when the flag is OFF — the
    // launch/hot-path safety the SS-CLEAN LAUNCH-SMOKE gate requires).
    @Test("compile() wires observe-only recordLiveParity and returns compiled unchanged")
    func stage1bLiveWiringIsObserveOnly() throws {
        let compiler = try loadMirroredSourceTextFile(
            "Epistemos/Engine/CommandCenterRequestCompiler.swift")
        #expect(compiler.contains("RuntimeRouterShadow.recordLiveParity("))
        #expect(compiler.contains("resolved: compiled.resolvedRuntime.resolved)"))
        #expect(compiler.contains("return compiled"))
        // The recorder is flag-gated → pure no-op when OFF (router never consulted on the hot path).
        let shadow = try loadMirroredSourceTextFile(
            "Epistemos/LocalAgent/RuntimeRouterShadow.swift")
        #expect(shadow.contains("guard armed else { return }"))
    }

    // The health row surfaces the observe-only parity rate so the owner can watch the router agree
    // with the live path (toward 100%) BEFORE STAGE 2 makes it authoritative. "—" until observed.
    @Test("RuntimeRouterHealthRow surfaces the STAGE 1b parityRate stat")
    func healthRowSurfacesParityRate() throws {
        let row = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/RuntimeRouterHealthRow.swift")
        #expect(row.contains("router.metrics.parityRate"))
        #expect(row.contains("label: \"Parity\""))
    }
}
