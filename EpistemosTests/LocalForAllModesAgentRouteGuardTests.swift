import Testing
import Foundation

/// OWNER MANDATE 2026-06-18 (#1, LOCAL FOR ALL MODES): with no cloud explicitly
/// selected, Act/agentic must NOT silently route to GPT/cloud when the owner has
/// a local agent-capable model. This source-guard locks the fix in
/// `InferenceState.effectiveChatSurfaceSelection`: the `.agent` auto-route branch
/// must guard its cloud return on `effectiveLocalAgentTextModelID == nil` (cloud
/// only as the honest fallback when no local model can run the agent loop) —
/// never an unconditional `.cloud` for `.agent`.
///
/// Behavioral coverage of the local-agent resolution already lives in
/// LocalModelInfrastructureTests (.agent → .localMLX(...)). This guard prevents a
/// regression back to the unconditional cloud route the owner reported.
@Suite("Local-for-all-modes agent route guard")
struct LocalForAllModesAgentRouteGuardTests {

    @Test("the .agent auto-route branch falls to cloud only when no local agent model exists")
    func agentAutoRouteIsLocalFirst() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")

        // `.agent` is now its own case (not combined with `.pro`) ...
        #expect(source.contains("case .agent:"))
        // ... guarded so it only routes to cloud when no local agent model exists.
        #expect(source.contains("if effectiveLocalAgentTextModelID == nil {"))

        // Regression tripwire: the old unconditional `.pro, .agent:` → cloud
        // combined case must be gone.
        #expect(!source.contains("case .pro, .agent:"))
    }
}
