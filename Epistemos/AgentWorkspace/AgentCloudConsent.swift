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

    static let claudeSonnet = AgentCloudProviderDescriptor(
        id: "claude_sonnet",
        displayName: "Anthropic Claude",
        dataDestination: "api.anthropic.com (Anthropic PBC, USA)"
    )

    static func descriptor(for slug: String) -> AgentCloudProviderDescriptor {
        switch slug {
        case "claude_sonnet", "claude_opus", "claude_haiku":
            return .claudeSonnet
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
    private static let defaultsKeyPrefix = "epistemos.agent.cloudConsent."

    private(set) var grantedProviderIDs: Set<String>

    init() {
        let defaults = UserDefaults.standard
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

    func grant(_ provider: AgentCloudProviderDescriptor) {
        grantedProviderIDs.insert(provider.id)
        UserDefaults.standard.set(true, forKey: Self.defaultsKeyPrefix + provider.id)
    }

    func revoke(_ providerID: String) {
        grantedProviderIDs.remove(providerID)
        UserDefaults.standard.removeObject(forKey: Self.defaultsKeyPrefix + providerID)
    }
}
