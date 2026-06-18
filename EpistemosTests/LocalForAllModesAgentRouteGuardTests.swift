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

    /// OWNER MANDATE 2026-06-18 (#1): Think AND Code/Pro were the remaining
    /// hidden-GPT routes — both unconditionally returned `.cloud(autoModel)` in
    /// the auto-route branch even with a working local tier model. This locks
    /// that both now fall to cloud ONLY when no local model (nor Apple
    /// Intelligence) can serve the tier — mirroring `.fast`/`.agent`.
    @Test("the .pro and .thinking auto-route branches are local-first too")
    func thinkAndCodeAutoRouteAreLocalFirst() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")

        let tierGuard = "if effectiveLocalTextModelID(for: operatingMode) == nil"

        // Anchor on the auto-route switch ONLY (this file has many
        // EpistemosOperatingMode switches): the branch lives inside
        // `if !userHasExplicitPin {` and ends at the 2026-06-17 hotfix comment.
        guard let regionStart = source.range(of: "if !userHasExplicitPin {"),
              let regionEnd = source.range(of: "Owner hotfix 2026-06-17",
                                           range: regionStart.upperBound..<source.endIndex) else {
            Issue.record("expected the auto-route switch region markers")
            return
        }
        let region = String(source[regionStart.upperBound..<regionEnd.lowerBound])
        #expect(region.contains(tierGuard))

        // Each of `.pro` and `.thinking` must carry that guard BEFORE any cloud
        // return — extract each case body and assert the guard precedes the
        // `.cloud(autoModel)` escalation (i.e. cloud is no longer unconditional).
        func caseBody(from start: String, to end: String) -> String? {
            guard let s = region.range(of: start),
                  let e = region.range(of: end, range: s.upperBound..<region.endIndex) else {
                return nil
            }
            return String(region[s.upperBound..<e.lowerBound])
        }

        // Order in source: case .pro: … case .agent: … case .thinking: … case .fast:
        guard let proBody = caseBody(from: "case .pro:", to: "case .agent:"),
              let thinkBody = caseBody(from: "case .thinking:", to: "case .fast:") else {
            Issue.record("expected .pro and .thinking cases in the documented order")
            return
        }

        for (label, body) in [("pro", proBody), ("thinking", thinkBody)] {
            #expect(body.contains(tierGuard), "\(label) must be guarded local-first")
            guard let guardRange = body.range(of: tierGuard) else { continue }
            if let cloudRange = body.range(of: ".cloud(autoModel)") {
                #expect(guardRange.lowerBound < cloudRange.lowerBound,
                        "\(label) cloud route must be inside the no-local guard, not unconditional")
            }
        }
    }
}
