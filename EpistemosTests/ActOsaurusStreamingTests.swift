import Testing
import Foundation
@testable import Epistemos

/// ACT token streaming through OsaurusCore (owner 2026-06-21, §214 "code it now, don't defer"). Completes
/// the user-visible main-chat act path: the shared composer's streamingGenerator now routes through
/// the headless Osaurus chat session when act is armed, forwarding visible text while preserving a typed
/// event path for thinking/tool/result state. Honest: the inert bridge refuses (never a silent cloud route).
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
        #expect(src.contains("makeEventStream("))                  // semantic stream is the source of truth
        #expect(src.contains("runTurnEventStreamInProcess("))      // drives the headless chat-session stream
        #expect(src.contains("case .textDelta(let token)"))        // text wrapper forwards only visible text
        #expect(src.contains("finish(throwing: error)"))           // honest failure on the stream, never cloud
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
        #expect(src.contains("func actEventStreamIfArmed("))
        #expect(src.contains("shouldRouteActThroughOsaurus()"))   // the one decision
        #expect(src.contains("ActOsaurusStreamingHandler.make()")) // the one act stream
        #expect(src.contains("ActOsaurusStreamingHandler.makeEventStream()")) // the one semantic stream
        #expect(src.contains("streamFilter.visibleDelta(from: token)"))
        #expect(src.contains("streamFilter.visibleDelta(from: text)"))
        #expect(src.contains("continuation.yield(.textDelta(visibleTail))"))
    }

    @Test("completeness: the NON-streaming local path also routes act (no per-surface drift, §38/§86)")
    func nonStreamingPathAlsoRoutesAct() throws {
        let shared = try loadMirroredSourceTextFile("Epistemos/LocalAgent/SharedActInference.swift")
        // Non-streaming sibling exists, honest (throws on act failure, never silent MLX fallback).
        #expect(shared.contains("func actTextIfArmed("))
        #expect(shared.contains("ActOsaurusGenerationHandler.make()"))
        // TriageService's non-streaming local path delegates to it (so generateGeneral surfaces get act too).
        let triage = try loadMirroredSourceTextFile("Epistemos/Engine/TriageService.swift")
        #expect(triage.contains("SharedActInference.actTextIfArmed("))
    }
    #endif

    // NOTE: `EpistemosOsaurusChatSessionBridge.streamTurnEvents` is the public headless Osaurus
    // session entry Epistemos uses for native rendering. The text stream wraps that event stream
    // rather than calling the raw model service directly.
}
