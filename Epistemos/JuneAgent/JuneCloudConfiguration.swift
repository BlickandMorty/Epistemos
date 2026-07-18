#if EPISTEMOS_BASE_JUNE
import Foundation
import Observation

nonisolated enum JuneCloudProvider: String, CaseIterable, Codable, Sendable {
    case openAI = "openai"
    case anthropic = "anthropic"

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        }
    }

    var keychainKey: String { "epistemos.june.\(rawValue).apiKey" }

    var environmentKey: String {
        switch self {
        case .openAI: "OPENAI_API_KEY"
        case .anthropic: "ANTHROPIC_API_KEY"
        }
    }

    var dataDestination: String {
        switch self {
        case .openAI: "OpenAI's cloud service"
        case .anthropic: "Anthropic's cloud service"
        }
    }
}

nonisolated enum JuneCloudModel: String, CaseIterable, Codable, Sendable {
    case openAIGPT55 = "openai:gpt-5.5"
    case openAIGPT54 = "openai:gpt-5.4"
    case openAIGPT54Mini = "openai:gpt-5.4-mini"
    case openAIGPT54Nano = "openai:gpt-5.4-nano"
    case openAIGPT52 = "openai:gpt-5.2"
    case openAIGPT41 = "openai:gpt-4.1"
    case openAIGPT41Mini = "openai:gpt-4.1-mini"
    case openAIO3Mini = "openai:o3-mini"
    case anthropicSonnet46 = "anthropic:claude-sonnet-4-6"
    case anthropicOpus47 = "anthropic:claude-opus-4-7"
    case anthropicHaiku45 = "anthropic:claude-haiku-4-5"

    static let defaultModel = JuneCloudModel.anthropicSonnet46

    var provider: JuneCloudProvider {
        rawValue.hasPrefix("openai:") ? .openAI : .anthropic
    }

    var displayName: String {
        switch self {
        case .openAIGPT55: "GPT-5.5"
        case .openAIGPT54: "GPT-5.4"
        case .openAIGPT54Mini: "GPT-5.4 mini"
        case .openAIGPT54Nano: "GPT-5.4 nano"
        case .openAIGPT52: "GPT-5.2"
        case .openAIGPT41: "GPT-4.1"
        case .openAIGPT41Mini: "GPT-4.1 mini"
        case .openAIO3Mini: "o3-mini"
        case .anthropicSonnet46: "Claude Sonnet 4.6"
        case .anthropicOpus47: "Claude Opus 4.7"
        case .anthropicHaiku45: "Claude Haiku 4.5"
        }
    }

    var agentCoreSlug: String {
        switch self {
        case .openAIGPT55: "openai_gpt55"
        case .openAIGPT54: "openai_gpt54"
        case .openAIGPT54Mini: "openai_gpt54_mini"
        case .openAIGPT54Nano: "openai_gpt54_nano"
        case .openAIGPT52: "openai_gpt52"
        case .openAIGPT41: "openai_gpt41"
        case .openAIGPT41Mini: "openai_gpt41_mini"
        case .openAIO3Mini: "openai_o3_mini"
        case .anthropicSonnet46: "claude_sonnet"
        case .anthropicOpus47: "claude_opus"
        case .anthropicHaiku45: "claude_haiku"
        }
    }

    var maxContextTokens: Int {
        switch self {
        case .openAIGPT55: 1_048_576
        case .openAIGPT54, .openAIGPT54Mini: 400_000
        case .openAIGPT54Nano: 131_072
        case .openAIGPT52, .openAIGPT41, .openAIGPT41Mini, .openAIO3Mini: 128_000
        case .anthropicSonnet46, .anthropicOpus47, .anthropicHaiku45: 200_000
        }
    }

    var supportsReasoning: Bool {
        self != .anthropicHaiku45
    }

    static func models(for provider: JuneCloudProvider) -> [JuneCloudModel] {
        allCases.filter { $0.provider == provider }
    }
}

@MainActor
@Observable
final class JuneCloudConfigurationStore {
    static let shared = JuneCloudConfigurationStore()

    private static let consentKeyPrefix = "epistemos.june.cloudConsent."
    private(set) var configuredProviders: Set<JuneCloudProvider>
    private(set) var consentedProviders: Set<JuneCloudProvider>

    private init() {
        configuredProviders = Set(JuneCloudProvider.allCases.filter {
            guard let key = Keychain.load(for: $0.keychainKey) else { return false }
            return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })
        consentedProviders = Set(JuneCloudProvider.allCases.filter {
            FoundationSafety.runtimeUserDefaults.bool(forKey: Self.consentKeyPrefix + $0.rawValue)
        })
    }

    func isConfigured(_ provider: JuneCloudProvider) -> Bool {
        configuredProviders.contains(provider)
    }

    func hasConsent(_ provider: JuneCloudProvider) -> Bool {
        consentedProviders.contains(provider)
    }

    @discardableResult
    func saveAPIKey(_ value: String, for provider: JuneCloudProvider) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, Keychain.save(trimmed, for: provider.keychainKey) else {
            return false
        }
        configuredProviders.insert(provider)
        return true
    }

    func deleteAPIKey(for provider: JuneCloudProvider) {
        Keychain.delete(for: provider.keychainKey)
        configuredProviders.remove(provider)
    }

    func setConsent(_ enabled: Bool, for provider: JuneCloudProvider) {
        let key = Self.consentKeyPrefix + provider.rawValue
        FoundationSafety.runtimeUserDefaults.set(enabled, forKey: key)
        if enabled {
            consentedProviders.insert(provider)
        } else {
            consentedProviders.remove(provider)
        }
    }
}

private actor JuneAgentCoreEnvironmentGate {
    private var held = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        guard held else {
            held = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        guard !waiters.isEmpty else {
            held = false
            return
        }
        waiters.removeFirst().resume()
    }
}

nonisolated enum JuneAgentCoreEnvironment {
    private static let gate = JuneAgentCoreEnvironmentGate()
    private static let managedKeys = Set(JuneCloudProvider.allCases.map(\.environmentKey))

    static func withCredential<T: Sendable>(
        for provider: JuneCloudProvider,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        guard let rawKey = Keychain.load(for: provider.keychainKey),
              !rawKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JuneGatewayError.cloudNotConfigured
        }

        await gate.acquire()
        let previous = managedKeys.reduce(into: [String: String?]()) { snapshot, key in
            snapshot[key] = getenv(key).map { String(cString: $0) }
        }
        for key in managedKeys { unsetenv(key) }
        setenv(provider.environmentKey, rawKey, 1)

        do {
            let result = try await operation()
            restore(previous)
            await gate.release()
            return result
        } catch {
            restore(previous)
            await gate.release()
            throw error
        }
    }

    private static func restore(_ snapshot: [String: String?]) {
        for (key, value) in snapshot {
            if let value {
                setenv(key, value, 1)
            } else {
                unsetenv(key)
            }
        }
    }
}
#endif
