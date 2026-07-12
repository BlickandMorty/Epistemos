import Foundation

// P6.1 (owner 2026-06-19): the provider→logo MAP — a single TESTED source of truth
// for which brand glyph represents each model provider (cloud + local + account
// runtimes + Apple). Real lobehub B&W SVGs are used where staged in the asset
// catalog; EVERY brand also has an SF-Symbol fallback so something always renders
// (the staged SVG set is partial — render of the real logos is the owner's in-app
// check). Pure + unit-tested; derivation honors the account-runtime distinction.
enum ProviderBrand: String, CaseIterable, Sendable, Equatable {
    case claude          // Anthropic
    case chatGPT         // OpenAI
    case gemini          // Google
    case claudeCode      // Anthropic account runtime
    #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
    case codex           // OpenAI account runtime
    #endif
    case gemma           // local Google Gemma
    case qwen            // local Alibaba Qwen
    case apple           // Apple Intelligence
    case kimi            // Moonshot
    case zai             // Z.AI / GLM
    case minimax
    case deepseek
    case llama           // local Meta Llama
    case mistral         // local Mistral / Devstral
    case liquid          // local Liquid LFM
    case smolLM          // local SmolLM (HuggingFace mark)
    case jamba           // local Jamba (AI21 mark)
    case falcon          // local Falcon (TII mark)
    case generic         // unknown / lobehub generic

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .chatGPT: "ChatGPT"
        case .gemini: "Gemini"
        case .claudeCode: "Claude Code"
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        case .codex: "Codex"
        #endif
        case .gemma: "Gemma"
        case .qwen: "Qwen"
        case .apple: "Apple Intelligence"
        case .kimi: "Kimi"
        case .zai: "Z.AI"
        case .minimax: "MiniMax"
        case .deepseek: "DeepSeek"
        case .llama: "Llama"
        case .mistral: "Mistral"
        case .liquid: "LFM"
        case .smolLM: "SmolLM"
        case .jamba: "Jamba"
        case .falcon: "Falcon"
        case .generic: "Model"
        }
    }

    /// Asset-catalog name for the staged lobehub SVG (MIT, from
    /// lobehub/lobe-icons static-svg — the B&W marks). nil → SF-Symbol fallback.
    var assetName: String? {
        switch self {
        case .claude: "ProviderLogoClaude"
        case .chatGPT: "ProviderLogoOpenAI"
        case .gemini: "ProviderLogoGemini"
        case .claudeCode: "ProviderLogoClaudeCode"
        case .gemma: "ProviderLogoGemma"
        case .qwen: "ProviderLogoQwen"
        case .apple: "ProviderLogoApple"
        case .kimi: "ProviderLogoKimi"
        case .zai: "ProviderLogoZai"
        case .minimax: "ProviderLogoMiniMax"
        case .deepseek: "ProviderLogoDeepSeek"
        case .llama: "ProviderLogoLlama"
        case .mistral: "ProviderLogoMistral"
        case .liquid: "ProviderLogoLiquid"
        case .smolLM: "ProviderLogoHuggingFace"
        case .jamba: "ProviderLogoAI21"
        case .falcon: "ProviderLogoFalcon"
        // .generic → SF-Symbol fallback (no brand SVG).
        default: nil
        }
    }

    /// SF-Symbol fallback so SOMETHING always renders (render-safe without assets).
    var sfSymbolFallback: String {
        switch self {
        case .claude, .claudeCode: "sparkle"
        case .chatGPT: "bubble.left.and.text.bubble.right"
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        case .codex: "bubble.left.and.text.bubble.right"
        #endif
        case .gemini: "diamond"
        case .gemma: "g.circle"
        case .qwen: "q.circle"
        case .apple: "apple.logo"
        case .kimi: "moon.stars"
        case .zai: "z.circle"
        case .minimax: "m.circle"
        case .deepseek: "d.circle"
        case .llama: "l.circle"
        case .mistral: "wind"
        case .liquid: "drop"
        case .smolLM: "s.circle"
        case .jamba: "j.circle"
        case .falcon: "bird"
        case .generic: "cpu"
        }
    }

    // MARK: - Derivation

    /// The brand for a cloud provider, honoring the account-runtime distinction
    /// (OpenAI→Codex / Anthropic→Claude Code) when those runtimes are active.
    static func cloud(_ provider: CloudModelProvider, accountRuntime: Bool = false) -> ProviderBrand {
        switch provider {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        case .openAI: accountRuntime ? .codex : .chatGPT
        #else
        case .openAI: .chatGPT
        #endif
        case .anthropic: accountRuntime ? .claudeCode : .claude
        case .google: .gemini
        case .kimi: .kimi
        case .zai: .zai
        case .minimax: .minimax
        case .deepseek: .deepseek
        }
    }

    /// The brand for a local model id (best-effort by family substring).
    static func local(modelID: String) -> ProviderBrand {
        let id = modelID.lowercased()
        if id.contains("gemma") { return .gemma }
        // deepseek BEFORE qwen: the R1-Distill-Qwen ids contain "qwen" but are
        // DeepSeek models — checking qwen first mislabeled them with the Qwen logo.
        if id.contains("deepseek") { return .deepseek }
        // qwq = Alibaba's QwQ reasoning line — Qwen family (was falling to generic).
        if id.contains("qwen") || id.contains("qwopus") || id.contains("qwq") { return .qwen }
        if id.contains("llama") { return .llama }
        if id.contains("mistral") || id.contains("devstral") { return .mistral }
        if id.contains("lfm") || id.contains("liquid") { return .liquid }
        if id.contains("smol") { return .smolLM }
        if id.contains("jamba") { return .jamba }
        if id.contains("falcon") { return .falcon }
        if id.contains("minimax") { return .minimax }
        if id.contains("glm") || id.contains("zhipu") { return .zai }
        if id.contains("kimi") { return .kimi }
        return .generic
    }

    /// Best-effort brand from a human display LABEL (e.g. the per-message
    /// "answered by" badge: "Claude Opus 4.7", "GPT-5.4", "Gemini 3.1 Pro",
    /// "Qwen 3 4B"). Order matters — the account-runtime names are checked first.
    static func fromLabel(_ label: String) -> ProviderBrand {
        let l = label.lowercased()
        if l.contains("claude code") { return .claudeCode }
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        if l.contains("codex") { return .codex }
        #endif
        if l.contains("claude") { return .claude }
        if l.contains("gpt") || l.contains("chatgpt") || l.contains("openai") { return .chatGPT }
        if l.contains("gemini") { return .gemini }
        if l.contains("gemma") { return .gemma }
        // deepseek BEFORE qwen (R1-Distill-Qwen labels contain "qwen").
        if l.contains("deepseek") { return .deepseek }
        if l.contains("qwen") || l.contains("qwopus") || l.contains("qwq") { return .qwen }
        if l.contains("llama") { return .llama }
        if l.contains("mistral") || l.contains("devstral") { return .mistral }
        if l.contains("lfm") || l.contains("liquid") { return .liquid }
        if l.contains("smol") { return .smolLM }
        if l.contains("jamba") { return .jamba }
        if l.contains("falcon") { return .falcon }
        if l.contains("kimi") || l.contains("moonshot") { return .kimi }
        if l.contains("apple") { return .apple }
        if l.contains("minimax") { return .minimax }
        if l.contains("glm") || l.contains("z.ai") || l.contains("zai") { return .zai }
        return .generic
    }
}
