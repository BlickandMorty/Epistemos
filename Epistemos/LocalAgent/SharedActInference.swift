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
                    for try await token in inner { continuation.yield(token) }
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
        return try await handler(prompt, systemPrompt, maxTokens, reasoningMode, noModelOverride, { _ in })
        #else
        return nil
        #endif
    }
}
