import Testing
import Foundation
@testable import Epistemos

/// SHARED ACT COMPOSER (owner 2026-06-21 #1) — "one shared act composer across all chats". Locks the
/// fix for the real gap this found: the act=Osaurus generation swap lived ONLY in DeviceAgentService,
/// so the owner's main chat surfaces (ChatCoordinator, PipelineService, IMessageDriverService — all
/// built via LocalAgentLoop.liveLoop) stayed on raw MLX and never reached the act engine. The fix is a
/// SINGLE shared routing decision (`shouldRouteActThroughOsaurus`) applied at the liveLoop chokepoint
/// AND reused by DeviceAgentService, so the swap can never silently diverge again.
@Suite("Shared act composer — one act-routing decision across all chat surfaces")
struct SharedActComposerTests {
    @Test("shared decision: DEFAULT-ON for Pro, OFF for App Store")
    func decisionHonesty() {
        #if EPISTEMOS_APP_STORE
        // MAS: act-Osaurus is a Pro/direct-distribution surface (OsaurusCore isn't linked) → the
        // router NEVER routes, even with the flag set; the in-process MLX path stays.
        #expect(LocalAgentLoop.shouldRouteActThroughOsaurus(environment: [:]) == false)
        #expect(LocalAgentLoop.shouldRouteActThroughOsaurus(
            environment: [ActOsaurusGateStatus.flagName: "1"]) == false)
        #else
        // Pro: act enters Osaurus by default, with Epistemos home/theme grafts.
        // The experimental gate is gone, so the router returns true regardless of
        // env flags.
        #expect(LocalAgentLoop.shouldRouteActThroughOsaurus(environment: [:]) == true)
        #expect(LocalAgentLoop.shouldRouteActThroughOsaurus(
            environment: [ActOsaurusGateStatus.flagName: "1"]) == true)
        #expect(LocalAgentLoop.shouldRouteActThroughOsaurus(
            environment: [ActOsaurusGateStatus.flagName: "0"]) == true)
        #endif
    }

    @Test("visible Act stream strips Osaurus sentinel telemetry")
    func visibleActStreamStripsOsaurusSentinels() {
        let raw = "\u{FFFE}prefill:{\"detail\":\"solo\",\"completedUnitCount\":0,\"stage\":\"queued\",\"totalUnitCount\":201}"
            + "\u{FFFE}prefill:{\"totalUnitCount\":201,\"detail\":\"decode_ready\",\"stage\":\"complete\",\"completedUnitCount\":201}"
            + "Hello from Osaurus."
            + "\u{FFFE}stats:45;15.4368;stop=stop,prefill=159.4012"

        #expect(ActOsaurusVisibleStreamFilter.visibleStoredText(from: raw) == "Hello from Osaurus.")
        #expect(ActOsaurusVisibleStreamFilter.visibleDelta(from: "\u{FFFE}prefill:{\"stage\":\"queued\"}") == nil)
        #expect(ActOsaurusVisibleStreamFilter.visibleDelta(from: "Hello\u{FFFE}stats:1;2.0") == "Hello")
        #expect(UserFacingModelOutput.finalVisibleText(from: raw) == "Hello from Osaurus.")
        #expect(UserFacingModelOutput.streamingVisibleText(from: raw) == "Hello from Osaurus.")
    }

    @Test("liveLoop chokepoint routes through the shared decision (all chat surfaces get act)")
    func liveLoopUsesSharedDecision() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/LocalAgent/LocalAgentLoop.swift")
        // The shared decision exists and is applied where liveLoop builds its primary generator.
        #expect(src.contains("func shouldRouteActThroughOsaurus("))
        #expect(src.contains("shouldRouteActThroughOsaurus()"))
        #expect(src.contains("ActOsaurusGenerationHandler.make()"))
        // The fix touches the SHARED chokepoint, not a per-surface fork.
        #expect(src.contains("primaryGenerator"))
    }

    @Test("DeviceAgentService reuses the SAME shared decision (no divergence)")
    func deviceAgentReusesSharedDecision() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Omega/Inference/DeviceAgentService.swift")
        #expect(src.contains("LocalAgentLoop.shouldRouteActThroughOsaurus()"))
        // The old divergent inline flag-read must be gone from this site.
        #expect(!src.contains("ActOsaurusGateStatus.isEnabled(ProcessInfo.processInfo.environment[ActOsaurusGateStatus.flagName])"))
    }

    @Test("the main chat surfaces really build via liveLoop (so the chokepoint covers them)")
    func mainSurfacesUseLiveLoop() throws {
        for path in [
            "Epistemos/App/ChatCoordinator.swift",
            "Epistemos/Engine/PipelineService.swift",
            "Epistemos/Omega/iMessageDriver/IMessageDriverService.swift",
        ] {
            let src = try loadMirroredSourceTextFile(path)
            #expect(src.contains("LocalAgentLoop.liveLoop("), "\(path) should build via liveLoop")
        }
    }

    @Test("TriageService (Note chat + Graph chat path) ALSO routes through the SAME shared act decision")
    func triageSurfacesGetActToo() throws {
        // The OTHER shared chokepoint: Note chat + Graph chat stream via TriageService.localStreamOrFallback,
        // not liveLoop. It must honor the SAME shouldRouteActThroughOsaurus() decision so EVERY chat surface
        // gets act/Osaurus (owner #1) — and so the two chokepoints can't diverge.
        let svc = try loadMirroredSourceTextFile("Epistemos/Engine/TriageService.swift")
        // TriageService delegates the act-injection to the SINGLE shared entry (one chokepoint, §692) —
        // the SAME one liveLoop uses, so they can't diverge.
        #expect(svc.contains("SharedActInference.actStreamIfArmed("))
        // Both surfaces really route through TriageService (so the chokepoint covers them).
        let note = try loadMirroredSourceTextFile("Epistemos/State/NoteChatState.swift")
        #expect(note.contains("triageService.stream"))
        let graph = try loadMirroredSourceTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")
        #expect(graph.contains("triage.streamGeneral") || graph.contains("triageService"))
    }
}
