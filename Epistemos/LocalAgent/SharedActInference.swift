import Foundation

/// ONE INFERENCE CHOKEPOINT — phase 1 (owner 2026-06-21, addendum §692). The SINGLE act-injection point
/// that BOTH inference chokepoints delegate into — `LocalAgentLoop.liveLoop` (main/MiniChat/Pipeline/
/// iMessage) AND `TriageService.localStreamOrFallback` (Note chat + Graph chat) — so the act=Osaurus
/// routing can never diverge between them again (it was the exact class of bug behind "graph chat bypasses
/// act"). This is the additive first step toward the full "one brain" entry; flag-off/act-off it returns
/// `nil`, so each caller falls back to its existing MLX path BYTE-IDENTICALLY (no behavior change when act
/// is off — the safety the directive requires for live inference).
enum SharedActInference {
    /// The act=Osaurus local stream when act is armed, else `nil` (caller uses its own MLX fallback).
    /// Wraps the shared `ActOsaurusStreamingHandler` (which drives OsaurusCore's real token stream via the
    /// bridge) — honest failure on the stream, never a silent cloud route. Always `nil` on the App Store
    /// build (act-Osaurus is a Pro / direct-distribution surface).
    nonisolated static func actStreamIfArmed(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) -> AsyncThrowingStream<String, Error>? {
        #if !EPISTEMOS_APP_STORE
        guard LocalAgentLoop.shouldRouteActThroughOsaurus() else { return nil }
        return AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                do {
                    // ActOsaurusStreamingHandler.make() is MainActor-isolated; hop to obtain the @Sendable
                    // factory, then drive it from this task. The factory yields OsaurusCore's real tokens.
                    let factory = await MainActor.run { ActOsaurusStreamingHandler.make() }
                    let inner = await factory(prompt, systemPrompt, maxTokens, reasoningMode, modelID)
                    var streamFilter = ActOsaurusVisibleStreamFilter.StreamState()
                    for try await token in inner {
                        if let visibleToken = streamFilter.visibleDelta(from: token) {
                            continuation.yield(visibleToken)
                        }
                    }
                    if let visibleTail = streamFilter.flushVisibleTail() {
                        continuation.yield(visibleTail)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        #else
        return nil
        #endif
    }

    /// Typed sibling of `actStreamIfArmed`: when act is armed, this exposes the same
    /// Osaurus turn as native events so Epistemos surfaces can render thinking/tool/result
    /// state without parsing or displaying Osaurus protocol text.
    nonisolated static func actEventStreamIfArmed(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) -> AsyncThrowingStream<ActOsaurusStreamEvent, Error>? {
        #if !EPISTEMOS_APP_STORE
        guard LocalAgentLoop.shouldRouteActThroughOsaurus() else { return nil }
        return AsyncThrowingStream<ActOsaurusStreamEvent, Error> { continuation in
            let task = Task {
                do {
                    let factory = await MainActor.run { ActOsaurusStreamingHandler.makeEventStream() }
                    let inner = await factory(prompt, systemPrompt, maxTokens, reasoningMode, modelID)
                    var streamFilter = ActOsaurusVisibleStreamFilter.StreamState()
                    for try await event in inner {
                        switch event {
                        case .textDelta(let text):
                            if let visibleText = streamFilter.visibleDelta(from: text) {
                                continuation.yield(.textDelta(visibleText))
                            }
                        case .thinkingDelta, .toolStarted, .toolCompleted:
                            continuation.yield(event)
                        }
                    }
                    if let visibleTail = streamFilter.flushVisibleTail() {
                        continuation.yield(.textDelta(visibleTail))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        #else
        return nil
        #endif
    }

    /// NON-STREAMING sibling of `actStreamIfArmed` (completeness — owner's "every surface, one source of
    /// truth"): the act=Osaurus generated TEXT when armed, else `nil` (caller uses its MLX path). Reuses the
    /// shared `ActOsaurusGenerationHandler`. HONEST: when armed it returns the act text OR THROWS — it never
    /// returns nil-to-fall-back-to-MLX on an act failure (no silent route swap). For the non-streaming local
    /// path (`TriageService.localGenerateOrFallback`), so it can't diverge from the streaming path.
    static func actTextIfArmed(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode
    ) async throws -> String? {
        #if !EPISTEMOS_APP_STORE
        guard LocalAgentLoop.shouldRouteActThroughOsaurus() else { return nil }
        let handler = await MainActor.run { ActOsaurusGenerationHandler.make() }
        let noModelOverride: String? = nil
        let text = try await handler(prompt, systemPrompt, maxTokens, reasoningMode, noModelOverride, { _ in })
        return ActOsaurusVisibleStreamFilter.visibleStoredText(from: text)
        #else
        return nil
        #endif
    }
}

nonisolated enum ActOsaurusVisibleStreamFilter {
    private static let sentinel: Character = "\u{FFFE}"
    private static let replacementSentinel: Character = "\u{FFFD}"
    private static let prefillPrefix = "prefill:"
    private static let knownSentinelPrefixes = [
        "billing:",
        "done:",
        "prefill:",
        "reasoning:",
        "secret:",
        "stats:",
        "tool:"
    ]

    struct StreamState {
        private var buffered = ""

        mutating func visibleDelta(from delta: String) -> String? {
            buffered.append(delta)
            let visible = ActOsaurusVisibleStreamFilter.drainVisibleText(from: &buffered, flushIncomplete: false)
            return visible.isEmpty ? nil : visible
        }

        mutating func flushVisibleTail() -> String? {
            let visible = ActOsaurusVisibleStreamFilter.drainVisibleText(from: &buffered, flushIncomplete: true)
            buffered.removeAll(keepingCapacity: true)
            return visible.isEmpty ? nil : visible
        }
    }

    static func visibleDelta(from delta: String) -> String? {
        let visible = visibleStoredText(from: delta)
        return visible.isEmpty ? nil : visible
    }

    static func visibleStoredText(from text: String) -> String {
        var state = StreamState()
        var output = ""
        output.append(state.visibleDelta(from: text) ?? "")
        output.append(state.flushVisibleTail() ?? "")
        return output
    }

    private static func drainVisibleText(from buffer: inout String, flushIncomplete: Bool) -> String {
        var output = ""

        while !buffer.isEmpty {
            guard let sentinelIndex = firstProtocolSentinelIndex(in: buffer) else {
                output.append(buffer)
                buffer.removeAll(keepingCapacity: true)
                break
            }

            if sentinelIndex > buffer.startIndex {
                output.append(contentsOf: buffer[..<sentinelIndex])
                buffer.removeSubrange(..<sentinelIndex)
                continue
            }

            switch indexAfterSkippingSentinel(at: buffer.startIndex, in: buffer, flushIncomplete: flushIncomplete) {
            case .skipped(let end):
                buffer.removeSubrange(..<end)
            case .needsMoreInput:
                if flushIncomplete {
                    buffer.removeAll(keepingCapacity: true)
                }
                return output
            }
        }

        return output
    }

    private enum SentinelSkipResult {
        case skipped(String.Index)
        case needsMoreInput
    }

    private static func indexAfterSkippingSentinel(
        at start: String.Index,
        in text: String,
        flushIncomplete: Bool
    ) -> SentinelSkipResult {
        var index = text.index(after: start)
        if index == text.endIndex {
            return flushIncomplete ? .skipped(index) : .needsMoreInput
        }

        if isPartialKnownPrefix(String(text[index...])) {
            return flushIncomplete ? .skipped(text.endIndex) : .needsMoreInput
        }

        if text[index...].hasPrefix(prefillPrefix) {
            index = text.index(index, offsetBy: prefillPrefix.count, limitedBy: text.endIndex) ?? text.endIndex
            return indexAfterSkippingPrefillPayload(
                from: index,
                in: text,
                flushIncomplete: flushIncomplete
            )
        }

        return .skipped(indexAfterSkippingOpaqueSentinelPayload(from: index, in: text))
    }

    private static func indexAfterSkippingPrefillPayload(
        from start: String.Index,
        in text: String,
        flushIncomplete: Bool
    ) -> SentinelSkipResult {
        guard start < text.endIndex else {
            return flushIncomplete ? .skipped(text.endIndex) : .needsMoreInput
        }

        guard start < text.endIndex, text[start] == "{" else {
            return .skipped(indexAfterSkippingOpaqueSentinelPayload(from: start, in: text))
        }

        var index = start
        var depth = 0
        var inString = false
        var escaped = false
        while index < text.endIndex {
            let character = text[index]
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else if character == "\"" {
                inString = true
            } else if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                index = text.index(after: index)
                if depth <= 0 { return .skipped(index) }
                continue
            }
            index = text.index(after: index)
        }
        return flushIncomplete ? .skipped(text.endIndex) : .needsMoreInput
    }

    private static func indexAfterSkippingOpaqueSentinelPayload(
        from start: String.Index,
        in text: String
    ) -> String.Index {
        var index = start
        while index < text.endIndex {
            if isProtocolSentinel(at: index, in: text) {
                return index
            }
            index = text.index(after: index)
        }
        return text.endIndex
    }

    private static func firstProtocolSentinelIndex(in text: String) -> String.Index? {
        var index = text.startIndex
        while index < text.endIndex {
            if isProtocolSentinel(at: index, in: text) {
                return index
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func isProtocolSentinel(at index: String.Index, in text: String) -> Bool {
        let character = text[index]
        if character == sentinel {
            return true
        }
        guard character == replacementSentinel else {
            return false
        }
        let after = text.index(after: index)
        let tail = String(text[after...])
        return knownSentinelPrefixes.contains { tail.hasPrefix($0) }
            || isPartialKnownPrefix(tail)
    }

    private static func isPartialKnownPrefix(_ tail: String) -> Bool {
        knownSentinelPrefixes.contains { prefix in
            prefix.hasPrefix(tail) && tail.count < prefix.count
        }
    }
}
