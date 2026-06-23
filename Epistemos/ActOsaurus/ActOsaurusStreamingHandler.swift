import Foundation

#if !EPISTEMOS_APP_STORE
/// The STREAMING "generation-closure swap" for ACT (owner 2026-06-21): a `LocalAgentStreamingGeneratorFactory`
/// that drives the LINKED OsaurusCore chat-session engine in-process via
/// `ActOsaurusBridge.runTurnStreamingInProcess` and forwards visible assistant deltas. The shared act
/// composer's `streamingGenerator` is swapped to THIS when the act-Osaurus flag is on, so Epistemos keeps the
/// visible chat UI while Osaurus owns the model/tool/prompt loop underneath. NEVER a silent cloud route — a
/// bridge failure finishes the stream with an honest `ActOsaurusError` (owner #1).
enum ActOsaurusStreamingHandler {
    typealias EventGeneratorFactory = @Sendable (
        _ prompt: String,
        _ systemPrompt: String?,
        _ maxTokens: Int,
        _ reasoningMode: LocalReasoningMode,
        _ modelID: String?
    ) async -> AsyncThrowingStream<ActOsaurusStreamEvent, Error>

    /// Build the act streaming closure driving `bridge` (default = the flag-resolved bridge).
    static func make(
        bridge: ActOsaurusBridge = ActOsaurusBridgeFactory.resolve()
    ) -> LocalAgentStreamingGeneratorFactory {
        let eventFactory = makeEventStream(bridge: bridge)
        return { prompt, systemPrompt, maxTokens, reasoningMode, modelID in
            AsyncThrowingStream<String, Error> { continuation in
                let task = Task {
                    do {
                        let stream = await eventFactory(prompt, systemPrompt, maxTokens, reasoningMode, modelID)
                        for try await event in stream {
                            if case .textDelta(let token) = event {
                                continuation.yield(token)
                            }
                        }
                        continuation.finish()
                    } catch {
                        // Honest: surface the failure on the stream — never silently swap to cloud.
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }

    /// Build the semantic act stream. This is the bridge-native path Epistemos can use
    /// to render Osaurus thinking/tool/result state as Epistemos message blocks.
    static func makeEventStream(
        bridge: ActOsaurusBridge = ActOsaurusBridgeFactory.resolve()
    ) -> EventGeneratorFactory {
        { prompt, systemPrompt, maxTokens, _, modelID in
            AsyncThrowingStream<ActOsaurusStreamEvent, Error> { continuation in
                let task = Task {
                    do {
                        // P0-A (owner 2026-06-22): thread the act surface's SELECTED model through
                        // so the owner's chosen model is generated (not just the configured core
                        // model), routed via the model bridge. nil → bridge uses the core default.
                        let stream = try await bridge.runTurnEventStreamInProcess(
                            prompt: prompt,
                            systemPrompt: systemPrompt,
                            maxTokens: maxTokens,
                            requestedModel: modelID
                        )
                        for try await event in stream {
                            continuation.yield(event)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }
}
#endif
