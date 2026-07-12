import Foundation
import Observation

// Guideline 5.1.2(i) consent (Plan 1-MAS §4, Nov-2025 rule): explicit user
// permission BEFORE the first byte of vault/personal data reaches a cloud
// provider — per provider, revocable. Consent state is a preference, not a
// secret (UserDefaults is correct; keys/tokens stay in Keychain).

nonisolated struct AgentCloudProviderDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let dataDestination: String

    static let openAI = AgentCloudProviderDescriptor(
        id: "openAI",
        displayName: "OpenAI",
        dataDestination: "api.openai.com (OpenAI)"
    )

    static let anthropic = AgentCloudProviderDescriptor(
        id: "anthropic",
        displayName: "Anthropic",
        dataDestination: "api.anthropic.com (Anthropic)"
    )

    static func descriptor(for provider: CloudModelProvider) -> AgentCloudProviderDescriptor {
        switch provider {
        case .openAI:
            return .openAI
        case .anthropic:
            return .anthropic
        case .google, .zai, .kimi, .minimax, .deepseek:
            return AgentCloudProviderDescriptor(
                id: provider.rawValue,
                displayName: provider.displayName,
                dataDestination: "the provider's configured HTTPS API"
            )
        }
    }

    static func descriptor(for slug: String) -> AgentCloudProviderDescriptor {
        switch slug {
        case "claude_sonnet", "claude_opus", "claude_haiku":
            return .anthropic
        case let value where value.hasPrefix("openai:"):
            return .openAI
        default:
            return AgentCloudProviderDescriptor(
                id: slug,
                displayName: slug,
                dataDestination: "the configured cloud provider"
            )
        }
    }
}

@MainActor
@Observable
final class AgentCloudConsentStore {
    static let shared = AgentCloudConsentStore()

    private static let defaultsKeyPrefix = "epistemos.agent.cloudConsent."

    private(set) var grantedProviderIDs: Set<String>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var granted: Set<String> = []
        for (key, value) in defaults.dictionaryRepresentation()
        where key.hasPrefix(Self.defaultsKeyPrefix) && (value as? Bool) == true {
            granted.insert(String(key.dropFirst(Self.defaultsKeyPrefix.count)))
        }
        grantedProviderIDs = granted
    }

    func hasConsent(for providerID: String) -> Bool {
        grantedProviderIDs.contains(providerID)
    }

    func hasConsent(for provider: CloudModelProvider) -> Bool {
        hasConsent(for: AgentCloudProviderDescriptor.descriptor(for: provider).id)
    }

    func setConsent(_ isGranted: Bool, for provider: CloudModelProvider) {
        let descriptor = AgentCloudProviderDescriptor.descriptor(for: provider)
        if isGranted {
            grant(descriptor)
        } else {
            revoke(descriptor.id)
        }
    }

    func grant(_ provider: AgentCloudProviderDescriptor) {
        grantedProviderIDs.insert(provider.id)
        defaults.set(true, forKey: Self.defaultsKeyPrefix + provider.id)
    }

    func revoke(_ providerID: String) {
        grantedProviderIDs.remove(providerID)
        defaults.removeObject(forKey: Self.defaultsKeyPrefix + providerID)
    }
}
