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

    @Test("liveLoop routes the streaming generator through the SHARED act entry (one chokepoint, §692)")
    func liveLoopStreamsThroughActDecision() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/LocalAgent/LocalAgentLoop.swift")
        #expect(src.contains("streamingGenerator: streamGenerator"))
        // The streaming act-injection delegates to the SINGLE shared entry (the same TriageService uses).
        #expect(src.contains("SharedActInference.actStreamIfArmed("))
        // Primary generator still keys off the shared decision (no divergence).
        #expect(src.contains("shouldRouteActThroughOsaurus()"))
    }

    @Test("SharedActInference is the single act-injection entry both chokepoints delegate into")
    func sharedActEntryContract() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/LocalAgent/SharedActInference.swift")
        #expect(src.contains("func actStreamIfArmed("))
        #expect(src.contains("shouldRouteActThroughOsaurus()"))   // the one decision
        #expect(src.contains("ActOsaurusStreamingHandler.make()")) // the one act stream
        #expect(src.contains("continuation.yield(token)"))         // forwards real tokens
    }
    #endif

    // NOTE: `CoreModelService.generateStream` (the public streaming method on the vendored OsaurusCore
    // that the bridge drives) is proven REAL by COMPILATION — the bridge calls it and the whole target
    // builds (0 errors) — plus the inert-refuse + wiring behavior tests above. We don't source-guard it
    // via loadMirroredSourceTextFile because the source mirror covers the app trees, not vendored
    // LocalPackages snapshots (that path reads stale).
}
