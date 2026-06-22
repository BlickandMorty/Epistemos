import Foundation

#if !EPISTEMOS_APP_STORE
/// The STREAMING "generation-closure swap" for ACT (owner 2026-06-21): a `LocalAgentStreamingGeneratorFactory`
/// that drives the LINKED OsaurusCore engine in-process via `ActOsaurusBridge.runTurnStreamingInProcess` and
/// forwards every token as it decodes (STREAM EVERYTHING — CLAUDE.md). The shared act composer's
/// `streamingGenerator` is swapped to THIS when the act-Osaurus flag is on, so act streams like the rest of
/// chat WITHOUT rewriting the agent loop. NEVER a silent cloud route — a bridge failure finishes the stream
/// with an honest `ActOsaurusError` (owner #1).
enum ActOsaurusStreamingHandler {
    /// Build the act streaming closure driving `bridge` (default = the flag-resolved bridge).
    static func make(
        bridge: ActOsaurusBridge = ActOsaurusBridgeFactory.resolve()
    ) -> LocalAgentStreamingGeneratorFactory {
        { prompt, systemPrompt, maxTokens, _, modelID in
            AsyncThrowingStream<String, Error> { continuation in
                let task = Task {
                    do {
                        // Drives OsaurusCore's real token stream in-process; forwards each chunk.
                        // P0-A (owner 2026-06-22): thread the act surface's SELECTED model through
                        // so the owner's chosen model is generated (not just the configured core
                        // model), routed via the model bridge. nil → bridge uses the core default.
                        let stream = try await bridge.runTurnStreamingInProcess(
                            prompt: prompt,
                            systemPrompt: systemPrompt,
                            maxTokens: maxTokens,
                            requestedModel: modelID
                        )
                        for try await token in stream {
                            continuation.yield(token)
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
}
#endif
