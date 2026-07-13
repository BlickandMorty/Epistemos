import Foundation

/// MAS-safe provider/model mapping for the in-process `agent_core` runner.
/// This stays compiled for June; the ACP loopback server that used to own this
/// helper is compile-parked out of App Store builds.
nonisolated enum GooseMASAgentCoreProviderSlug {
    #if EPISTEMOS_APP_STORE || MAS_SANDBOX
    /// Reverse admission used by the final in-process runner. Keeping this
    /// exact prevents a future caller from bypassing June's model catalog by
    /// passing a parked provider slug directly to agent_core.
    static func juneProvider(forResolvedSlug slug: String) -> CloudModelProvider? {
        switch slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "openai", "openai_gpt55", "openai_gpt54",
             "openai_gpt54_mini", "openai_gpt54_nano", "openai_gpt52",
             "openai_gpt41", "openai_gpt41_mini", "openai_o3_mini":
            return .openAI
        case "claude_sonnet", "claude_opus", "claude_haiku":
            return .anthropic
        default:
            return nil
        }
    }
    #endif

    /// Maps the user's saved model id onto an agent_core provider slug understood by
    /// `instantiate_provider` (bridge.rs). Returns nil when the selection carries no
    /// model-specific signal (empty, or equal to the bare provider family id), so the
    /// caller keeps the provider-default mapping.
    ///
    /// NOTE: agent_core's `run_agent_session` FFI accepts only a `provider_name`, and
    /// each slug binds a FIXED model inside the provider (e.g. `claude_opus` ->
    /// `ClaudeProvider::opus()`). This mapping therefore reaches the discrete set of
    /// slugs agent_core exposes; a fully arbitrary model_id would require a new
    /// optional `model_id` FFI parameter threaded into the provider constructors.
    static func resolve(forSelectedModel selectedModel: String?, providerID: String) -> String? {
        guard let raw = selectedModel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        if raw.caseInsensitiveCompare(providerID) == .orderedSame {
            return nil
        }
        let lower = raw.lowercased()
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        switch lower {
        case "openai:gpt-5.5": return "openai_gpt55"
        case "openai:gpt-5.4": return "openai_gpt54"
        case "openai:gpt-5.4-mini": return "openai_gpt54_mini"
        case "openai:gpt-5.4-nano": return "openai_gpt54_nano"
        case "openai:gpt-5.2": return "openai_gpt52"
        case "openai:gpt-4.1": return "openai_gpt41"
        case "openai:gpt-4.1-mini": return "openai_gpt41_mini"
        case "openai:o3-mini": return "openai_o3_mini"
        case "anthropic:claude-sonnet-4-6": return "claude_sonnet"
        case "anthropic:claude-opus-4-7": return "claude_opus"
        case "anthropic:claude-haiku-4-5": return "claude_haiku"
        default: return nil
        }
        #else
        if lower.contains("/") {
            return raw
        }
        if lower.contains("opus") { return "claude_opus" }
        if lower.contains("sonnet") { return "claude_sonnet" }
        if lower.contains("haiku") { return "claude_haiku" }
        if lower.contains("gemini") || lower.contains("google") {
            return lower.contains("flash") ? "gemini_flash" : "gemini_pro"
        }
        if lower.contains("gpt-5.5") { return "openai_gpt55" }
        if lower.contains("gpt-5.4-nano") { return "openai_gpt54_nano" }
        if lower.contains("gpt-5.4-mini") { return "openai_gpt54_mini" }
        if lower.contains("gpt-5.4") { return "openai_gpt54" }
        if lower.contains("gpt-5.2") { return "openai_gpt52" }
        if lower.contains("gpt-4.1-mini") { return "openai_gpt41_mini" }
        if lower.contains("gpt-4.1") { return "openai_gpt41" }
        if lower.contains("gpt-4o-mini") { return "openai_gpt4o_mini" }
        if lower.contains("gpt-4o") { return "openai_gpt4o" }
        if lower.hasPrefix("o1") || lower.contains(":o1") { return "openai_o1" }
        if lower.hasPrefix("o3-mini") || lower.contains(":o3-mini") { return "openai_o3_mini" }
        if lower.contains("gpt") || lower.contains("openai") || lower.hasPrefix("o1") || lower.hasPrefix("o3") {
            return "openai"
        }
        if lower.contains("kimi") {
            if lower.contains("thinking") { return "kimi_thinking" }
            if lower.contains("k2") { return "kimi_k2" }
            return "kimi"
        }
        if lower.contains("deepseek") {
            return lower.contains("reasoner") ? "deepseek_reasoner" : "deepseek"
        }
        if lower.contains("minimax") { return "minimax" }
        if lower.contains("glm") || lower.contains("zai") { return "zai" }
        if lower.contains("perplexity") || lower.contains("sonar") { return "perplexity" }
        if lower.contains("mistral") { return "mistral" }
        if lower.contains("grok") || lower == "xai" { return "grok" }
        return nil
        #endif
    }
}
