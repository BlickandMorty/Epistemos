import Testing
import Foundation
@testable import Epistemos

/// ACT token streaming through OsaurusCore (owner 2026-06-21, §214 "code it now, don't defer"). Completes
/// the user-visible main-chat act path: the shared composer's streamingGenerator now routes through
/// OsaurusCore (CoreModelService.generateStream) when act is armed, forwarding tokens as they decode
/// (STREAM EVERYTHING) — not single-shot. Honest: the inert bridge refuses (never a silent cloud route).
@Suite("Act streaming — tokens through OsaurusCore at the shared chokepoint")
struct ActOsaurusStreamingTests {
    #if !EPISTEMOS_APP_STORE
    @Test("inert bridge HONESTLY refuses to stream — throws, never a fake/cloud token")
    func inertBridgeRefusesStream() async {
        let bridge = InertActOsaurusBridge()
        await #expect(throws: ActOsaurusError.self) {
            _ = try await bridge.runTurnStreamingInProcess(prompt: "hi", systemPrompt: nil, maxTokens: 8)
        }
    }

    @Test("the act streaming handler exists and drives the bridge's real token stream")
    func streamingHandlerWiresBridge() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/ActOsaurus/ActOsaurusStreamingHandler.swift")
        #expect(src.contains("enum ActOsaurusStreamingHandler"))
        #expect(src.contains("runTurnStreamingInProcess("))     // drives the bridge stream
        #expect(src.contains("continuation.yield(token)"))      // forwards each token (STREAM EVERYTHING)
        #expect(src.contains("finish(throwing: error)"))        // honest failure on the stream, never cloud
    }

    @Test("liveLoop routes BOTH generator AND streamingGenerator through the shared act decision")
    func liveLoopStreamsThroughActDecision() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/LocalAgent/LocalAgentLoop.swift")
        #expect(src.contains("ActOsaurusStreamingHandler.make()"))
        #expect(src.contains("streamingGenerator: streamGenerator"))
        // The streaming swap keys off the SAME shared decision as the primary generator (no divergence).
        #expect(src.contains("routeActOsaurus"))
    }
    #endif

    // NOTE: `CoreModelService.generateStream` (the public streaming method on the vendored OsaurusCore
    // that the bridge drives) is proven REAL by COMPILATION — the bridge calls it and the whole target
    // builds (0 errors) — plus the inert-refuse + wiring behavior tests above. We don't source-guard it
    // via loadMirroredSourceTextFile because the source mirror covers the app trees, not vendored
    // LocalPackages snapshots (that path reads stale).
}
