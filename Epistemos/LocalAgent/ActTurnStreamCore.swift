import Foundation

// ACT SURFACE UNIFICATION (0.47) — the ONE shared Act streaming core.
//
// Main act (ChatState.runActOsaurusTurn), Mini Chat (ThreadState), and the graph/note inline paths all
// consume the SAME `SharedActInference.actEventStreamIfArmed` event stream, with byte-identical event
// handling (delta accumulation, finalVisibleText projection, tool-block construction, cancellation-partial).
// Before this, each surface hand-rolled that loop — three divergent copies that could drift. This collapses
// the EVENT SEMANTICS into one tested implementation while each surface keeps its OWN state layer via the
// sink closures (ChatState messages/streamingText vs. ThreadState per-chatID setters). It does NOT unify the
// render/persistence state — only the streaming core, which is where the duplication actually lived.

/// Caller-supplied sinks. Each Act surface wires these to its own state. All run on the MainActor (the act
/// runners drive UI state). Defaults are no-ops so a surface only wires what it renders (e.g. main act v1
/// ignores tool blocks; Mini Chat shows them live).
struct ActTurnStreamSinks {
    /// The cumulative, user-visible answer text so far (already `finalVisibleText`-projected).
    var onVisibleText: @MainActor (String) -> Void = { _ in }
    /// A raw thinking-trace delta (caller accumulates/clears as it wishes).
    var onThinkingDelta: @MainActor (String) -> Void = { _ in }
    /// A tool invocation started (id/name/raw input JSON) — for live "running tool" affordances.
    var onToolStarted: @MainActor (_ id: String, _ name: String, _ inputJson: String) -> Void = { _, _, _ in }
    /// A tool invocation completed (id/result/isError).
    var onToolCompleted: @MainActor (_ id: String, _ result: String, _ isError: Bool) -> Void = { _, _, _ in }
}

/// The structured outcome of consuming an act event stream. `toolBlocks` are built identically for every
/// surface (toolUse + toolResult, in arrival order); a surface that doesn't render tools simply ignores them.
struct ActTurnStreamResult: Equatable {
    /// The final user-visible answer (`finalVisibleText` of the full accumulated text).
    var finalVisibleText: String
    /// The raw accumulated text deltas (pre-projection), for callers that need it.
    var rawAccumulated: String
    /// Tool-use + tool-result blocks in arrival order (empty when the turn used no tools).
    var toolBlocks: [MessageContentBlock]
    /// True when the turn ended via cancellation (the result carries the partial answer/blocks so far).
    var wasCancelled: Bool
}

/// Consumes an Act event stream to completion and drives the sinks. Throws on a REAL stream error (callers
/// render the honest failure); cancellation is NOT thrown — it returns a partial `ActTurnStreamResult` with
/// `wasCancelled == true`, so every surface handles cancellation the same way (append the partial if non-empty).
enum ActTurnStreamCore {
    @MainActor
    static func consume(
        _ stream: AsyncThrowingStream<ActOsaurusStreamEvent, Error>,
        sinks: ActTurnStreamSinks
    ) async throws -> ActTurnStreamResult {
        var accumulated = ""
        var toolBlocks: [MessageContentBlock] = []
        do {
            for try await event in stream {
                if Task.isCancelled {
                    return Self.result(accumulated, toolBlocks, cancelled: true)
                }
                switch event {
                case .textDelta(let text):
                    accumulated += text
                    sinks.onVisibleText(UserFacingModelOutput.finalVisibleText(from: accumulated))
                case .thinkingDelta(let text):
                    sinks.onThinkingDelta(text)
                case .toolStarted(let id, let name, let inputJson):
                    toolBlocks.append(.toolUse(id: id, name: name, input: Self.decodeToolInput(inputJson)))
                    sinks.onToolStarted(id, name, inputJson)
                case .toolCompleted(let id, let result, let isError):
                    toolBlocks.append(.toolResult(toolUseId: id, content: result, isError: isError))
                    sinks.onToolCompleted(id, result, isError)
                case .generationStats:
                    // Telemetry is recorded upstream (SharedActInference → ActTurnStatsStore); no visible-text effect.
                    break
                }
            }
        } catch is CancellationError {
            return Self.result(accumulated, toolBlocks, cancelled: true)
        }
        return Self.result(accumulated, toolBlocks, cancelled: false)
    }

    @MainActor
    private static func result(
        _ accumulated: String, _ blocks: [MessageContentBlock], cancelled: Bool
    ) -> ActTurnStreamResult {
        ActTurnStreamResult(
            finalVisibleText: UserFacingModelOutput.finalVisibleText(from: accumulated),
            rawAccumulated: accumulated,
            toolBlocks: blocks,
            wasCancelled: cancelled
        )
    }

    /// Shared tool-input decode (was duplicated as MiniChat's `decodeMiniChatToolInput`): a JSON object →
    /// `[String: JSONValue]`, falling back to `{"raw": <inputJson>}` on malformed input so a tool call is
    /// never silently dropped.
    static func decodeToolInput(_ inputJson: String) -> [String: JSONValue] {
        guard let data = inputJson.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data)
        else {
            return ["raw": .string(inputJson)]
        }
        return decoded
    }
}
