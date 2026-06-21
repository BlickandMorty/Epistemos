import Testing

@testable import Epistemos

// SUBSTRATE STAGE-2 (owner 2026-06-21): the router's lane becomes AUTHORITATIVE when armed
// (EPISTEMOS_RUNTIMEROUTER_LIVE_V0), parity-gated. This guards the pure selection CONTRACT headless
// (no live FFI): flag-OFF is byte-identical to STAGE 1b (no live-chat / SS-CR regression); flag-ON
// the router wins but NEVER strands a turn. The live descriptor swap that consumes this contract is
// the owner's parity-gated flip (see CommandCenterRequestCompiler.compile()).
@Suite("RuntimeRouter STAGE-2 — authoritative-lane selection contract")
struct RuntimeRouterStage2Tests {

    @Test("flag OFF: the live (FFI) lane wins — byte-identical to STAGE 1b (no regression)")
    func flagOffKeepsLive() {
        #expect(RuntimeRouterShadow.authoritativeLane(liveLane: .mlx, routerLane: .gguf, armed: false) == .mlx)
        #expect(RuntimeRouterShadow.wouldOverrideLive(liveLane: .mlx, routerLane: .gguf, armed: false) == false)
    }

    @Test("flag ON: the router's lane is authoritative")
    func flagOnRouterWins() {
        #expect(RuntimeRouterShadow.authoritativeLane(liveLane: .mlx, routerLane: .gguf, armed: true) == .gguf)
        #expect(RuntimeRouterShadow.wouldOverrideLive(liveLane: .mlx, routerLane: .gguf, armed: true) == true)
    }

    @Test("flag ON + parity match: no-op (both lanes equal → the live descriptor stands)")
    func flagOnMatchedIsNoOp() {
        #expect(RuntimeRouterShadow.authoritativeLane(liveLane: .mlx, routerLane: .mlx, armed: true) == .mlx)
        #expect(RuntimeRouterShadow.wouldOverrideLive(liveLane: .mlx, routerLane: .mlx, armed: true) == false)
    }

    @Test("flag ON + router has no lane (.unavailable): fall back to live, never strand the turn")
    func flagOnRouterNilFallsBack() {
        #expect(RuntimeRouterShadow.authoritativeLane(liveLane: .mlx, routerLane: nil, armed: true) == .mlx)
        #expect(RuntimeRouterShadow.wouldOverrideLive(liveLane: .mlx, routerLane: nil, armed: true) == false)
    }

    @Test("flag ON + cloud override: a different lane (cloud) overrides local")
    func flagOnCloudOverride() {
        let cloud: RuntimeLane = .cloud(provider: "claude")
        #expect(RuntimeRouterShadow.authoritativeLane(liveLane: .mlx, routerLane: cloud, armed: true) == cloud)
        #expect(RuntimeRouterShadow.wouldOverrideLive(liveLane: .mlx, routerLane: cloud, armed: true) == true)
    }
}
