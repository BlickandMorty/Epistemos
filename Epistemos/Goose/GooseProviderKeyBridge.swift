import Foundation

struct GooseProviderKeyBridge {
    enum SkipReason: Equatable, Sendable {
        case missingProviderId
        case missingGooseSecretField
        case missingEpistemosCredential
        case oversizedEpistemosCredential
        case providerConfigReadFailed
        case providerConfigSaveFailed
    }

    struct Applied: Equatable, Sendable {
        let gooseProviderId: String
        let gooseSecretKey: String
        let epistemosKeychainKey: String
        let configured: Bool
    }

    struct Skipped: Equatable, Sendable {
        let gooseProviderId: String
        let gooseSecretKey: String?
        let reason: SkipReason
    }

    struct SyncResult: Equatable, Sendable {
        var applied: [Applied] = []
        var skipped: [Skipped] = []
    }

    static let maxKeychainLookupKeyCharacters = 256
    static let maxCredentialValueCharacters = GooseACPProtocolBounds.maxProviderConfigFieldValueCharacters

    private let keychainLoad: (String) -> String?

    init(keychainLoad: @escaping (String) -> String?) {
        self.keychainLoad = keychainLoad
    }

    func syncConfiguredProviderKeys(to client: GooseACPClient) async -> SyncResult {
        var result = SyncResult()
        let providers: GooseACPProvidersListResponse
        do {
            providers = try await client.listGooseProviders()
        } catch {
            result.skipped.append(.init(
                gooseProviderId: "*",
                gooseSecretKey: nil,
                reason: .providerConfigReadFailed
            ))
            return result
        }

        for entry in providers.entries {
            guard let providerID = Self.providerID(from: entry) else {
                result.skipped.append(.init(
                    gooseProviderId: "*",
                    gooseSecretKey: nil,
                    reason: .missingProviderId
                ))
                continue
            }

            let config: GooseACPProviderConfigReadResponse
            do {
                config = try await client.readGooseProviderConfig(providerId: providerID)
            } catch {
                result.skipped.append(.init(
                    gooseProviderId: providerID,
                    gooseSecretKey: nil,
                    reason: .providerConfigReadFailed
                ))
                continue
            }

            let candidateFields = config.fields.filter { $0.isSecret && !$0.isSet }
            guard let field = candidateFields.first(where: { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                result.skipped.append(.init(
                    gooseProviderId: providerID,
                    gooseSecretKey: nil,
                    reason: .missingGooseSecretField
                ))
                continue
            }

            let candidates = Self.candidateKeychainKeys(providerID: providerID, gooseSecretKey: field.key)
            var selectedKey: String?
            var selectedValue: String?
            for key in candidates {
                guard let rawValue = keychainLoad(key)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !rawValue.isEmpty else {
                    continue
                }
                guard rawValue.utf8.count <= Self.maxCredentialValueCharacters,
                      !rawValue.contains("\0") else {
                    result.skipped.append(.init(
                        gooseProviderId: providerID,
                        gooseSecretKey: field.key,
                        reason: .oversizedEpistemosCredential
                    ))
                    selectedKey = nil
                    selectedValue = nil
                    break
                }
                selectedKey = key
                selectedValue = rawValue
                break
            }

            guard let selectedKey, let selectedValue else {
                if !result.skipped.contains(.init(
                    gooseProviderId: providerID,
                    gooseSecretKey: field.key,
                    reason: .oversizedEpistemosCredential
                )) {
                    result.skipped.append(.init(
                        gooseProviderId: providerID,
                        gooseSecretKey: field.key,
                        reason: .missingEpistemosCredential
                    ))
                }
                continue
            }

            do {
                let response = try await client.saveGooseProviderConfig(
                    providerId: providerID,
                    fields: [.init(key: field.key, value: selectedValue)]
                )
                result.applied.append(.init(
                    gooseProviderId: providerID,
                    gooseSecretKey: field.key,
                    epistemosKeychainKey: selectedKey,
                    configured: response.status.isConfigured
                ))
            } catch {
                result.skipped.append(.init(
                    gooseProviderId: providerID,
                    gooseSecretKey: field.key,
                    reason: .providerConfigSaveFailed
                ))
            }
        }

        return result
    }

    static func candidateKeychainKeys(providerID: String, gooseSecretKey: String) -> [String] {
        guard let providerSegment = boundedKeychainSegmentSource(
            providerID,
            maxCharacters: GooseACPProtocolBounds.maxInventoryIDCharacters
        ),
              let secretSegment = boundedKeychainSegmentSource(
                gooseSecretKey,
                maxCharacters: GooseACPProtocolBounds.maxProviderConfigFieldKeyCharacters
              ) else {
            return []
        }

        var candidates: [String] = []
        func append(_ key: String) {
            guard key.count <= maxKeychainLookupKeyCharacters,
                  !candidates.contains(key) else {
                return
            }
            candidates.append(key)
        }

        append("epistemos.\(providerSegment).apiKey")
        if secretSegment.hasSuffix(".api.key") {
            let prefix = String(secretSegment.dropLast(".api.key".count))
            if !prefix.isEmpty {
                append("epistemos.\(prefix).apiKey")
            }
        }

        for provider in CloudModelProvider.allCases {
            let normalizedProvider = boundedKeychainSegmentSource(
                provider.rawValue,
                maxCharacters: GooseACPProtocolBounds.maxInventoryIDCharacters
            )
            if normalizedProvider == providerSegment || secretSegment.hasPrefix(normalizedProvider ?? "") {
                append(provider.apiKeyKeychainKey)
            }
        }
        return candidates
    }

    static func boundedKeychainSegmentSource(_ rawValue: String, maxCharacters: Int) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.utf8.count <= maxCharacters,
              !trimmed.contains("\0") else {
            return nil
        }
        let scalars = trimmed.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "."
        }
        let collapsed = String(scalars)
            .lowercased()
            .split(separator: ".", omittingEmptySubsequences: true)
            .joined(separator: ".")
        guard !collapsed.isEmpty else { return nil }
        return collapsed
    }

    private static func providerID(from entry: JSONValue) -> String? {
        guard case .object(let object) = entry else { return nil }
        for key in ["providerId", "provider_id", "id"] {
            if case .string(let value)? = object[key],
               let providerID = boundedNonEmptyString(
                value,
                maxCharacters: GooseACPProtocolBounds.maxInventoryIDCharacters,
               ) {
                return providerID
            }
        }
        return nil
    }

    private static func boundedNonEmptyString(_ value: String, maxCharacters: Int) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxCharacters,
              !trimmed.contains("\0") else {
            return nil
        }
        return trimmed
    }
}
