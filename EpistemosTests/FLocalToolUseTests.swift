import Foundation
import Testing
@testable import Epistemos

// MARK: - F-LocalToolUse (Phase 2 Terminal T1 — 2026-05-24)
//
// Falsifier for the §T1 acceptance gate:
//   "F-LocalToolUse PASS for every local model in the catalog that
//    claims canActAsAgent = true."
//
// The falsifier walks every `LocalTextModelID` with `canActAsAgent`
// = true and verifies, for a tool-invoking fixture prompt, that:
//
//   1. The chosen lane (from the per-role chain via `RuntimeRouter`)
//      is a LOCAL lane (MLX or GGUF) — agent-capable local models
//      must not silently escalate to cloud for a normal tool call.
//   2. The lane's capability surface includes a tool-call grammar
//      compatible with the model's native grammar
//      (`LocalToolGrammar.nativeGrammar(forModelID:)`).
//   3. The lane's `toolCallMode` is not `.none`.
//
// These three properties together prove the claim "every local
// agent-capable model has a real on-the-wire path through the
// router." A failure here means the router would either route the
// model to cloud (silent-escalation hazard) or to a lane that
// cannot honor its tool-call grammar (grammar-drift hazard).

@MainActor
@Suite("F-LocalToolUse — local tool grammar honored by chosen lane")
struct FLocalToolUseTests {
    /// Tool-invoking fixture prompt. The router does not run the
    /// model — F-LocalToolUse exercises the *routing decision*, not
    /// inference. The fixture only needs to communicate
    /// `requiresTools = true` + a tool-call grammar requirement.
    static let fixtureObjective = "Read note 'mom-meeting' and call vault.search for related items."

    @Test("F-LocalToolUse — every canActAsAgent local model has a viable local lane")
    func everyAgentCapableModelHasAViableLocalLane() {
        let router = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes(), persistsToUserDefaults: false)
        let agentCapable = LocalTextModelID.allCases.filter(\.canActAsAgent)
        #expect(!agentCapable.isEmpty, "the catalog must surface at least one canActAsAgent model")

        var failures: [String] = []

        for model in agentCapable {
            let result = evaluate(model: model, router: router)
            if let failure = result {
                failures.append(failure)
            }
        }

        if !failures.isEmpty {
            let joined = failures.joined(separator: "\n  • ")
            Issue.record(
                "F-LocalToolUse FAIL — \(failures.count) agent-capable models routed unsafely:\n  • \(joined)"
            )
        }
    }

    @Test("F-LocalToolUse — fixture round-trip on the smallest agent-capable model")
    func smallestAgentCapableModelRoundTripsThroughLocalLane() {
        let router = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes(), persistsToUserDefaults: false)
        let model = LocalTextModelID.qwen3_4B4Bit
        #expect(model.canActAsAgent)

        let packet = MissionPacket(
            uasAddress: "uas:f-localtooluse:smallest",
            role: .toolCaller,
            objective: Self.fixtureObjective,
            requiresTools: true,
            requiresGrammar: true,
            preferredLane: .mlx
        )
        let verdict = router.route(packet)
        if case .accept(let lane, let capability) = verdict {
            #expect(lane.isLocal, "smallest agent-capable model must accept locally; got \(lane.stableID)")
            #expect(capability.toolCallMode != .none, "lane must support tool calls; got \(capability.toolCallMode)")
            let nativeGrammar = LocalToolGrammar.nativeGrammar(forModelID: model.rawValue)
            #expect(
                capability.grammarSupport.contains(nativeGrammar.rawValue) || capability.toolCallMode == .softGuidance,
                "lane must honor \(nativeGrammar.rawValue) (or accept soft-guidance)"
            )
        } else {
            Issue.record("expected .accept, got \(verdict)")
        }
    }

    // MARK: - Helpers

    /// Evaluate one local agent-capable model. Returns nil on PASS
    /// or a human-readable failure message on FAIL.
    private func evaluate(model: LocalTextModelID, router: RuntimeRouter) -> String? {
        let packet = MissionPacket(
            uasAddress: "uas:f-localtooluse:\(model.rawValue)",
            role: .toolCaller,
            objective: Self.fixtureObjective,
            requiresTools: true,
            requiresGrammar: true,
            preferredLane: .mlx
        )
        let verdict = router.route(packet)

        guard case .accept(let lane, let capability) = verdict else {
            return "\(model.rawValue): router did not produce an accept verdict (\(verdict))"
        }

        if !lane.isLocal {
            return "\(model.rawValue): chose non-local lane \(lane.stableID) — silent cloud escalation hazard"
        }

        if capability.toolCallMode == .none {
            return "\(model.rawValue): chosen lane \(lane.stableID) advertises toolCallMode=.none"
        }

        let nativeGrammar = LocalToolGrammar.nativeGrammar(forModelID: model.rawValue)
        let grammarHonored = capability.grammarSupport.contains(nativeGrammar.rawValue)
            || capability.toolCallMode == .softGuidance

        if !grammarHonored {
            return "\(model.rawValue): native grammar \(nativeGrammar.rawValue) not honored by lane \(lane.stableID); grammarSupport=\(capability.grammarSupport)"
        }

        return nil
    }
}
