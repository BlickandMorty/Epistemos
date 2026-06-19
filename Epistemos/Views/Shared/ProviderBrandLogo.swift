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
    case codex           // OpenAI account runtime
    case gemma           // local Google Gemma
    case qwen            // local Alibaba Qwen
    case apple           // Apple Intelligence
    case kimi            // Moonshot
    case zai             // Z.AI / GLM
    case minimax
    case deepseek
    case generic         // unknown / lobehub generic

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .chatGPT: "ChatGPT"
        case .gemini: "Gemini"
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .gemma: "Gemma"
        case .qwen: "Qwen"
        case .apple: "Apple Intelligence"
        case .kimi: "Kimi"
        case .zai: "Z.AI"
        case .minimax: "MiniMax"
        case .deepseek: "DeepSeek"
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
        case .codex: "ProviderLogoCodex"
        case .gemma: "ProviderLogoGemma"
        case .qwen: "ProviderLogoQwen"
        case .apple: "ProviderLogoApple"
        case .kimi: "ProviderLogoKimi"
        // .zai / .minimax / .deepseek / .generic → SF-Symbol fallback (no SVG yet).
        default: nil
        }
    }

    /// SF-Symbol fallback so SOMETHING always renders (render-safe without assets).
    var sfSymbolFallback: String {
        switch self {
        case .claude, .claudeCode: "sparkle"
        case .chatGPT, .codex: "bubble.left.and.text.bubble.right"
        case .gemini: "diamond"
        case .gemma: "g.circle"
        case .qwen: "q.circle"
        case .apple: "apple.logo"
        case .kimi: "moon.stars"
        case .zai: "z.circle"
        case .minimax: "m.circle"
        case .deepseek: "d.circle"
        case .generic: "cpu"
        }
    }

    // MARK: - Derivation

    /// The brand for a cloud provider, honoring the account-runtime distinction
    /// (OpenAI→Codex / Anthropic→Claude Code) when those runtimes are active.
    static func cloud(_ provider: CloudModelProvider, accountRuntime: Bool = false) -> ProviderBrand {
        switch provider {
        case .openAI: accountRuntime ? .codex : .chatGPT
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
        if id.contains("qwen") || id.contains("qwopus") { return .qwen }
        return .generic
    }

    /// Best-effort brand from a human display LABEL (e.g. the per-message
    /// "answered by" badge: "Claude Opus 4.7", "GPT-5.4", "Gemini 3.1 Pro",
    /// "Qwen 3 4B"). Order matters — the account-runtime names are checked first.
    static func fromLabel(_ label: String) -> ProviderBrand {
        let l = label.lowercased()
        if l.contains("claude code") { return .claudeCode }
        if l.contains("codex") { return .codex }
        if l.contains("claude") { return .claude }
        if l.contains("gpt") || l.contains("chatgpt") || l.contains("openai") { return .chatGPT }
        if l.contains("gemini") { return .gemini }
        if l.contains("gemma") { return .gemma }
        if l.contains("qwen") || l.contains("qwopus") { return .qwen }
        if l.contains("kimi") || l.contains("moonshot") { return .kimi }
        if l.contains("apple") { return .apple }
        if l.contains("deepseek") { return .deepseek }
        if l.contains("minimax") { return .minimax }
        if l.contains("glm") || l.contains("z.ai") || l.contains("zai") { return .zai }
        return .generic
    }
}
