import Testing
import Foundation

/// OWNER MANDATE 2026-06-18 (#1, LOCAL FOR ALL MODES): with no cloud explicitly
/// selected, Act/agentic must NOT silently route to GPT/cloud. This source-guard locks the fix in
/// `InferenceState.effectiveChatSurfaceSelection`: the `.agent` auto-route branch
/// must guard its cloud return on both no local agent route and configured cloud
/// access — never an unconditional `.cloud` for `.agent`.
///
/// Native local-agent surfaces were pruned on 2026-06-26, so this guard prevents
/// a regression back to unconditional cloud routing without pretending local Act
/// is currently live.
@Suite("Local-for-all-modes agent route guard")
struct LocalForAllModesAgentRouteGuardTests {

    @Test("the .agent auto-route branch falls to cloud only when no local agent model exists")
    func agentAutoRouteIsLocalFirst() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")

        // `.agent` is now its own case (not combined with `.pro`) ...
        #expect(source.contains("case .agent:"))
        // ... guarded so it only routes to cloud when no local agent route exists
        // and cloud access is actually configured.
        guard let methodStart = source.range(of: "func effectiveChatSurfaceSelection"),
              let switchStart = source.range(
                of: "switch operatingMode",
                range: methodStart.upperBound..<source.endIndex
              ),
              let start = source.range(of: "case .agent:", range: switchStart.upperBound..<source.endIndex),
              let end = source.range(of: "case .thinking:", range: start.upperBound..<source.endIndex) else {
            Issue.record("expected the .agent auto-route branch")
            return
        }
        let agentBody = String(source[start.upperBound..<end.lowerBound])
        #expect(agentBody.contains("if effectiveLocalAgentTextModelID == nil"))
        #expect(agentBody.contains("hasConfiguredCloudAccess(for: autoModel.provider)"))
        if let guardRange = agentBody.range(of: "if effectiveLocalAgentTextModelID == nil"),
           let cloudAccessRange = agentBody.range(of: "hasConfiguredCloudAccess(for: autoModel.provider)"),
           let cloudRange = agentBody.range(of: ".cloud(autoModel)") {
            #expect(guardRange.lowerBound < cloudRange.lowerBound)
            #expect(cloudAccessRange.lowerBound < cloudRange.lowerBound)
        }

        // Regression tripwire: the old unconditional `.pro, .agent:` → cloud
        // combined case must be gone from this routing switch.
        let routingRegion = String(source[switchStart.upperBound..<end.lowerBound])
        #expect(!routingRegion.contains("case .pro, .agent:"))
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
