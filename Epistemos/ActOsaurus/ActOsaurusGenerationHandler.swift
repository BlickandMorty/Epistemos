import Foundation

#if !EPISTEMOS_APP_STORE
/// The "generation-closure swap" for ACT (owner 2026-06-21): a `LocalAgentGenerationHandler` that
/// drives the LINKED OsaurusCore engine in-process via `ActOsaurusBridge.runTurnInProcess`. The
/// existing `LocalAgentLoop` is constructed with THIS generator when the act-Osaurus flag is on, so
/// act runs through Osaurus WITHOUT rewriting the agent loop (favor-reuse — the audit-map's
/// "generation-closure swap"). Single-shot for now (emits the full result to `onToken`); a
/// token-streaming variant via OsaurusCore's server lands next. NEVER a silent cloud route — the
/// bridge throws an honest `ActOsaurusError` when OsaurusCore can't serve (owner #1).
enum ActOsaurusGenerationHandler {
    /// Build the act generation closure driving `bridge` (default = the flag-resolved bridge).
    static func make(
        bridge: ActOsaurusBridge = ActOsaurusBridgeFactory.resolve()
    ) -> LocalAgentGenerationHandler {
        { prompt, systemPrompt, maxTokens, _, _, onToken in
            var messages: [OsaurusVendor.Message] = []
            if let systemPrompt, !systemPrompt.isEmpty {
                messages.append(OsaurusVendor.Message(role: .system, content: systemPrompt))
            }
            messages.append(OsaurusVendor.Message(role: .user, content: prompt))
            // Drives OsaurusCore in-process; throws an honest ActOsaurusError on failure (never cloud).
            let result = try await bridge.runTurnInProcess(messages: messages, maxTokens: maxTokens)
            await onToken(result)
            return result
        }
    }
}
#endif
