import Testing
import Foundation
@testable import Epistemos

/// ACT SURFACE UNIFICATION (0.47) — the shared streaming core that main act (ChatState), Mini Chat
/// (ThreadState), and graph/note all consume. These lock in the unified event semantics: delta
/// accumulation → finalVisibleText, thinking routed separately, tool blocks built in arrival order,
/// generationStats ignored, cancellation → partial (not a throw), real errors propagate.
@Suite("Act streaming core — unified event semantics")
@MainActor
struct ActTurnStreamCoreTests {
    /// A finite event stream from a fixed list (completes cleanly).
    private func stream(_ events: [ActOsaurusStreamEvent]) -> AsyncThrowingStream<ActOsaurusStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            for e in events { continuation.yield(e) }
            continuation.finish()
        }
    }

    @Test("text deltas accumulate into finalVisibleText + fire the visible-text sink once per delta")
    func accumulatesText() async throws {
        var seen: [String] = []
        let result = try await ActTurnStreamCore.consume(
            stream([.textDelta("Hello"), .textDelta(", "), .textDelta("user")]),
            sinks: ActTurnStreamSinks(onVisibleText: { seen.append($0) })
        )
        #expect(result.finalVisibleText == "Hello, user")
        #expect(result.rawAccumulated == "Hello, user")
        #expect(result.wasCancelled == false)
        #expect(seen.count == 3)
        #expect(seen.last == "Hello, user")
    }

    @Test("toolUse + toolResult blocks build in arrival order and fire the tool sinks")
    func buildsToolBlocks() async throws {
        var started: [String] = []
        var completed: [String] = []
        let result = try await ActTurnStreamCore.consume(
            stream([
                .toolStarted(id: "t1", name: "search", inputJson: #"{"q":"x"}"#),
                .toolCompleted(id: "t1", result: "ok", isError: false),
                .textDelta("done"),
            ]),
            sinks: ActTurnStreamSinks(
                onToolStarted: { id, _, _ in started.append(id) },
                onToolCompleted: { id, _, _ in completed.append(id) }
            )
        )
        #expect(started == ["t1"])
        #expect(completed == ["t1"])
        #expect(result.toolBlocks.count == 2)
        #expect(result.finalVisibleText == "done")
        guard case .toolUse(let id, let name, let input) = result.toolBlocks[0] else {
            Issue.record("expected toolUse first: \(result.toolBlocks)"); return
        }
        #expect(id == "t1")
        #expect(name == "search")
        #expect(input["q"] == .string("x"))
        guard case .toolResult(let toolUseId, let content, let isError) = result.toolBlocks[1] else {
            Issue.record("expected toolResult second"); return
        }
        #expect(toolUseId == "t1")
        #expect(content == "ok")
        #expect(isError == false)
    }

    @Test("thinking deltas route to the thinking sink, never to visible text")
    func thinkingSink() async throws {
        var thinking = ""
        var visibleCalls = 0
        let result = try await ActTurnStreamCore.consume(
            stream([.thinkingDelta("reason "), .thinkingDelta("more"), .textDelta("answer")]),
            sinks: ActTurnStreamSinks(
                onVisibleText: { _ in visibleCalls += 1 },
                onThinkingDelta: { thinking += $0 }
            )
        )
        #expect(thinking == "reason more")
        #expect(result.finalVisibleText == "answer")
        #expect(visibleCalls == 1)   // only the single textDelta drove visible text
    }

    @Test("generationStats events are ignored (telemetry-only, no visible-text effect)")
    func statsIgnored() async throws {
        let result = try await ActTurnStreamCore.consume(
            stream([
                .generationStats(ttftSeconds: 0.1, tokensPerSecond: 5, tokenCount: 3),
                .textDelta("hi"),
            ]),
            sinks: ActTurnStreamSinks()
        )
        #expect(result.finalVisibleText == "hi")
        #expect(result.toolBlocks.isEmpty)
    }

    @Test("a real stream error propagates so the caller renders the honest failure")
    func streamErrorThrows() async {
        let failing = AsyncThrowingStream<ActOsaurusStreamEvent, Error> { continuation in
            continuation.yield(.textDelta("partial"))
            continuation.finish(throwing: AgentRuntimeError(message: "boom"))
        }
        await #expect(throws: (any Error).self) {
            _ = try await ActTurnStreamCore.consume(failing, sinks: ActTurnStreamSinks())
        }
    }

    @Test("malformed tool input falls back to {raw:...} (never silently drops a tool call)")
    func decodeFallback() {
        let bad = ActTurnStreamCore.decodeToolInput("not json")
        #expect(bad["raw"] == .string("not json"))
        // Valid JSON object decodes to keys (numeric case is JSONValue's concern; just assert presence).
        let ok = ActTurnStreamCore.decodeToolInput(#"{"a":1,"b":"two"}"#)
        #expect(ok["a"] != nil)
        #expect(ok["b"] == .string("two"))
    }
}
