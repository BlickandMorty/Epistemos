import Foundation
import Observation
import os

// MARK: - Provider Capabilities
// Describes what the currently selected LLM provider supports.
// Used to gate UI features that require large context, streaming, or deep research.

struct ProviderCapabilities: Sendable {
    let supportsLargeContext: Bool
    let supportsStreaming: Bool
    let supportsDeepResearch: Bool
    let supportsExternalAPIs: Bool
    let contextNote: String?
}

// MARK: - Inference State
// Manages LLM provider selection, API keys, and model choices.
// API keys are stored in Keychain — never in UserDefaults.

@MainActor @Observable
final class InferenceState {
    var inferenceMode: InferenceMode = .analytical
    var apiProvider: LLMProviderType = .anthropic

    // Per-provider API keys — each stored separately in Keychain
    var anthropicKey: String = ""
    var openaiKey: String = ""
    var googleKey: String = ""
    var kimiKey: String = ""

    // Computed: returns the key for the currently active provider
    var apiKey: String {
        switch apiProvider {
        case .anthropic: anthropicKey
        case .openai: openaiKey
        case .google: googleKey
        case .kimi: kimiKey
        case .ollama, .appleIntelligence: ""
        }
    }

    var openaiModel: String = "gpt-5.3"
    var anthropicModel: String = "claude-sonnet-4-6"
    var googleModel: String = "gemini-2.5-flash"
    var kimiModel: String = "kimi-k2.5"
    var ollamaBaseUrl: String = "http://localhost:11434"
    var ollamaModel: String = "llama3.2"
    var ollamaAvailable: Bool = false
    var ollamaModels: [String] = []
    var appleIntelligenceAvailable: Bool = false
    var appleIntelligenceUnavailableReason: String?

    /// Max tokens for user-visible chat responses. 0 = no cap (model default, ~16k).
    /// Enrichment passes (research mode) always use their own explicit limits.
    var chatOutputTokens: Int = 0

    init() {
        let (available, reason) = AppleIntelligenceService.shared.checkAvailability()
        self.appleIntelligenceAvailable = available
        self.appleIntelligenceUnavailableReason = reason

        // Restore persisted provider + model selection
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: "epistemos.apiProvider"),
           let provider = LLMProviderType(rawValue: saved) {
            self.apiProvider = provider
        }
        if let model = defaults.string(forKey: "epistemos.anthropicModel") { self.anthropicModel = model }
        if let model = defaults.string(forKey: "epistemos.openaiModel") { self.openaiModel = model }
        if let model = defaults.string(forKey: "epistemos.googleModel") { self.googleModel = model }
        if let model = defaults.string(forKey: "epistemos.kimiModel") { self.kimiModel = model }
        if let url = defaults.string(forKey: "epistemos.ollamaBaseUrl"), !url.isEmpty { self.ollamaBaseUrl = url }
        if let model = defaults.string(forKey: "epistemos.ollamaModel") { self.ollamaModel = model }
        self.chatOutputTokens = defaults.integer(forKey: "epistemos.chatOutputTokens")  // 0 if unset

        // Restore per-provider API keys from Keychain
        self.anthropicKey = Keychain.load(for: "epistemos.apiKey.anthropic") ?? ""
        self.openaiKey = Keychain.load(for: "epistemos.apiKey.openai") ?? ""
        self.googleKey = Keychain.load(for: "epistemos.apiKey.google") ?? ""
        self.kimiKey = Keychain.load(for: "epistemos.apiKey.kimi") ?? ""

        // Migrate: Apple Intelligence is no longer a selectable provider.
        // It runs automatically underneath whatever cloud API the user picks.
        if self.apiProvider == .appleIntelligence {
            self.apiProvider = .anthropic
            defaults.set(LLMProviderType.anthropic.rawValue, forKey: "epistemos.apiProvider")
        }

        // Migrate deprecated models to current replacements.
        let geminiMigrations: [String: String] = [
            "gemini-2.0-flash": "gemini-2.5-flash",
            "gemini-2.0-flash-lite": "gemini-2.5-flash",
            "gemini-1.5-pro": "gemini-2.5-pro",
            "gemini-1.5-flash": "gemini-2.5-flash",
        ]
        if let replacement = geminiMigrations[self.googleModel] {
            self.googleModel = replacement
            defaults.set(replacement, forKey: "epistemos.googleModel")
        }

        // Migrate deprecated OpenAI models
        let openaiMigrations: [String: String] = [
            "gpt-4o": "gpt-5.3",
            "gpt-4o-mini": "gpt-4.1-mini",
            "gpt-5.2": "gpt-5.3",
            "gpt-5.1": "gpt-5.3",
        ]
        if let replacement = openaiMigrations[self.openaiModel] {
            self.openaiModel = replacement
            defaults.set(replacement, forKey: "epistemos.openaiModel")
        }
    }

    func setInferenceMode(_ mode: InferenceMode) { inferenceMode = mode }

    func setApiProvider(_ provider: LLMProviderType) {
        apiProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "epistemos.apiProvider")
    }

    private func keychainKey(for provider: LLMProviderType) -> String {
        switch provider {
        case .anthropic: "epistemos.apiKey.anthropic"
        case .openai: "epistemos.apiKey.openai"
        case .google: "epistemos.apiKey.google"
        case .kimi: "epistemos.apiKey.kimi"
        case .ollama, .appleIntelligence: "epistemos.apiKey.none"
        }
    }

    func setApiKey(_ key: String) {
        switch apiProvider {
        case .anthropic: anthropicKey = key
        case .openai: openaiKey = key
        case .google: googleKey = key
        case .kimi: kimiKey = key
        case .ollama, .appleIntelligence: return
        }
        let kcKey = keychainKey(for: apiProvider)
        if key.isEmpty {
            Keychain.delete(for: kcKey)
        } else {
            Keychain.save(key, for: kcKey)
        }
    }

    var activeKeyPlaceholder: String {
        switch apiProvider {
        case .anthropic: "sk-ant-..."
        case .openai: "sk-..."
        case .google: "AIza..."
        case .kimi: "sk-..."
        case .ollama: "No key needed"
        case .appleIntelligence: "No key needed"
        }
    }

    var needsApiKey: Bool {
        switch apiProvider {
        case .anthropic, .openai, .google, .kimi: true
        case .ollama, .appleIntelligence: false
        }
    }

    // MARK: - Provider Capabilities

    var capabilities: ProviderCapabilities {
        switch apiProvider {
        case .anthropic, .openai, .google, .kimi, .appleIntelligence:
            ProviderCapabilities(
                supportsLargeContext: true,
                supportsStreaming: true,
                supportsDeepResearch: true,
                supportsExternalAPIs: true,
                contextNote: nil
            )
        case .ollama:
            ProviderCapabilities(
                supportsLargeContext: false,
                supportsStreaming: true,
                supportsDeepResearch: true,
                supportsExternalAPIs: true,
                contextNote: "Context window varies by model. Deep research works best with models ≥7B parameters."
            )
        }
    }

    // MARK: - Model Selection Helpers

    /// The currently active model ID for the selected provider.
    var activeModel: String {
        switch apiProvider {
        case .anthropic: anthropicModel
        case .openai: openaiModel
        case .google: googleModel
        case .kimi: kimiModel
        case .ollama: ollamaModel
        case .appleIntelligence: ""
        }
    }

    /// Sets the active model for the currently selected provider.
    func setActiveModel(_ model: String) {
        switch apiProvider {
        case .anthropic: setAnthropicModel(model)
        case .openai: setOpenAIModel(model)
        case .google: setGoogleModel(model)
        case .kimi: setKimiModel(model)
        case .ollama: setOllamaModel(model)
        case .appleIntelligence: break
        }
    }

    /// Available models for the currently selected provider.
    /// Returns (displayName, modelId) tuples.
    var availableModels: [(name: String, id: String)] {
        switch apiProvider {
        case .anthropic: Self.anthropicModels
        case .openai: Self.openaiModels
        case .google: Self.googleModels
        case .kimi: Self.kimiModels
        case .ollama: ollamaModels.map { ($0, $0) }
        case .appleIntelligence: []
        }
    }

    /// Human-readable display name for a model ID.
    var activeModelDisplayName: String {
        availableModels.first { $0.id == activeModel }?.name ?? activeModel
    }

    // Canonical model lists — single source of truth for Settings + dropdowns.
    static let anthropicModels: [(name: String, id: String)] = [
        ("Sonnet 4.6", "claude-sonnet-4-6"),
        ("Opus 4.6", "claude-opus-4-6"),
        ("Sonnet 4.5", "claude-sonnet-4-5-20250929"),
        ("Sonnet 4", "claude-sonnet-4-20250514"),
        ("Haiku 4.5", "claude-haiku-4-5-20251001"),
    ]

    static let openaiModels: [(name: String, id: String)] = [
        // GPT-5 series — flagship chat models
        ("GPT-5.3", "gpt-5.3"),
        ("GPT-5.2", "gpt-5.2"),
        ("GPT-5.1", "gpt-5.1"),
        ("GPT-4.1", "gpt-4.1"),
        ("GPT-4.1 mini", "gpt-4.1-mini"),
        // o-series — reasoning / thinking models (chain-of-thought server-side)
        ("o1 Pro", "o1-pro"),
        ("o3", "o3"),
        ("o3-mini", "o3-mini"),
    ]

    static let googleModels: [(name: String, id: String)] = [
        ("Gemini 2.5 Flash", "gemini-2.5-flash"),
        ("Gemini 2.5 Pro", "gemini-2.5-pro"),
        ("Gemini 3 Flash", "gemini-3-flash-preview"),
        ("Gemini 3 Pro", "gemini-3-pro-preview"),
        ("Gemini 3.1 Pro", "gemini-3.1-pro-preview"),
    ]

    static let kimiModels: [(name: String, id: String)] = [
        ("Kimi K2.5", "kimi-k2.5"),
        ("Kimi K2", "kimi-k2"),
        ("Moonshot 128K", "moonshot-v1-128k"),
    ]

    func setOpenAIModel(_ model: String) {
        openaiModel = model
        UserDefaults.standard.set(model, forKey: "epistemos.openaiModel")
    }

    func setAnthropicModel(_ model: String) {
        anthropicModel = model
        UserDefaults.standard.set(model, forKey: "epistemos.anthropicModel")
    }

    func setGoogleModel(_ model: String) {
        googleModel = model
        UserDefaults.standard.set(model, forKey: "epistemos.googleModel")
    }

    func setKimiModel(_ model: String) {
        kimiModel = model
        UserDefaults.standard.set(model, forKey: "epistemos.kimiModel")
    }

    /// Validates and sets the Ollama base URL.
    /// SECURITY: Rejects non-localhost URLs to prevent SSRF (CWE-918).
    func setOllamaBaseUrl(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            ollamaBaseUrl = "http://localhost:11434"
            UserDefaults.standard.set(ollamaBaseUrl, forKey: "epistemos.ollamaBaseUrl")
            return
        }
        if let parsed = URL(string: trimmed), let host = parsed.host?.lowercased() {
            let allowedHosts: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]"]
            guard allowedHosts.contains(host) else {
                Log.security.warning("Rejected non-localhost Ollama URL: \(host, privacy: .private)")
                return
            }
            guard parsed.scheme == "http" || parsed.scheme == "https" else {
                Log.security.warning("Rejected non-HTTP Ollama URL scheme: \(parsed.scheme ?? "nil", privacy: .public)")
                return
            }
        } else {
            Log.security.warning("Rejected unparseable Ollama URL")
            return
        }
        ollamaBaseUrl = trimmed
        UserDefaults.standard.set(trimmed, forKey: "epistemos.ollamaBaseUrl")
    }

    func setOllamaModel(_ model: String) {
        ollamaModel = model
        UserDefaults.standard.set(model, forKey: "epistemos.ollamaModel")
    }

    func setOllamaStatus(available: Bool, models: [String]) {
        ollamaAvailable = available
        ollamaModels = models
    }

    func setChatOutputTokens(_ tokens: Int) {
        chatOutputTokens = max(0, tokens)
        UserDefaults.standard.set(chatOutputTokens, forKey: "epistemos.chatOutputTokens")
    }
}
