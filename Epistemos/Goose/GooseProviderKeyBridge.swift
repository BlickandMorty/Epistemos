import Foundation

nonisolated struct GooseProviderKeyBridge: Sendable {
    typealias KeychainLoad = @Sendable (String) -> String?

    nonisolated struct AppliedProvider: Equatable, Sendable {
        let gooseProviderId: String
        let gooseSecretKey: String
        let epistemosKeychainKey: String
        let configured: Bool
    }

    nonisolated struct SkippedProvider: Equatable, Sendable {
        enum Reason: Equatable, Sendable {
            case providerInventoryUnavailable
            case missingProviderId
            case configReadFailed
            case missingGooseSecretField
            case missingEpistemosKey
            case oversizedEpistemosCredential
            case configSaveFailed
        }

        let gooseProviderId: String
        let gooseSecretKey: String?
        let reason: Reason
    }

    nonisolated struct Result: Equatable, Sendable {
        let applied: [AppliedProvider]
        let skipped: [SkippedProvider]
    }

    private let keychainLoad: KeychainLoad
    nonisolated static let maxCredentialValueCharacters = GooseACPProtocolBounds.maxProviderConfigFieldValueCharacters
    nonisolated static let maxKeychainLookupKeyCharacters = 1_024

    init(keychainLoad: @escaping KeychainLoad = { key in GooseProviderKeyBridge.defaultKeychainLoad(key) }) {
        self.keychainLoad = keychainLoad
    }

    func syncConfiguredProviderKeys(to client: GooseACPClient) async -> Result {
        var applied: [AppliedProvider] = []
        var skipped: [SkippedProvider] = []

        let inventory: GooseACPProvidersListResponse
        do {
            inventory = try await client.listGooseProviders()
        } catch {
            return Result(applied: [], skipped: [
                .init(
                    gooseProviderId: "*",
                    gooseSecretKey: nil,
                    reason: .providerInventoryUnavailable
                ),
            ])
        }

        let providerIDs = Self.providerIDs(from: inventory.entries, skipped: &skipped)
        for providerID in providerIDs {
            let config: GooseACPProviderConfigReadResponse
            do {
                config = try await client.readGooseProviderConfig(providerId: providerID)
            } catch {
                skipped.append(.init(
                    gooseProviderId: providerID,
                    gooseSecretKey: nil,
                    reason: .configReadFailed
                ))
                continue
            }

            let secretFields = config.fields.filter(\.isSecret)
            guard !secretFields.isEmpty else {
                skipped.append(.init(
                    gooseProviderId: providerID,
                    gooseSecretKey: nil,
                    reason: .missingGooseSecretField
                ))
                continue
            }

            var updates: [GooseACPProviderConfigFieldUpdate] = []
            var updateSources: [(gooseSecretKey: String, epistemosKeychainKey: String)] = []
            for field in secretFields {
                switch epistemosCredential(
                    providerID: providerID,
                    gooseSecretKey: field.key
                ) {
                case .found(let credential):
                    updates.append(.init(key: field.key, value: credential.value))
                    updateSources.append((field.key, credential.keychainKey))
                case .missing:
                    skipped.append(.init(
                        gooseProviderId: providerID,
                        gooseSecretKey: field.key,
                        reason: .missingEpistemosKey
                    ))
                case .oversized:
                    skipped.append(.init(
                        gooseProviderId: providerID,
                        gooseSecretKey: field.key,
                        reason: .oversizedEpistemosCredential
                    ))
                }
            }

            guard !updates.isEmpty else { continue }
            do {
                let response = try await client.saveGooseProviderConfig(providerId: providerID, fields: updates)
                applied.append(contentsOf: updateSources.map { source in
                    AppliedProvider(
                        gooseProviderId: providerID,
                        gooseSecretKey: source.gooseSecretKey,
                        epistemosKeychainKey: source.epistemosKeychainKey,
                        configured: response.status.isConfigured
                    )
                })
            } catch {
                for update in updates {
                    skipped.append(.init(
                        gooseProviderId: providerID,
                        gooseSecretKey: update.key,
                        reason: .configSaveFailed
                    ))
                }
            }
        }

        return Result(applied: applied, skipped: skipped)
    }

    nonisolated static func candidateKeychainKeys(providerID: String, gooseSecretKey: String) -> [String] {
        guard let boundedSecretKey = boundedKeychainSegmentSource(
            gooseSecretKey,
            maxCharacters: GooseACPProtocolBounds.maxProviderConfigFieldKeyCharacters
        ),
              let providerSegment = normalizedKeychainSegment(
                providerID,
                maxCharacters: GooseACPProtocolBounds.maxInventoryIDCharacters
              ),
              let envSegment = normalizedEnvironmentKeySegment(boundedSecretKey) else {
            return []
        }
        var keys: [String] = []
        appendUnique(AppBootstrap.agentCoreKeychainKey(forEnvironmentKey: boundedSecretKey), to: &keys)
        appendUnique("epistemos.\(providerSegment).apiKey", to: &keys)
        appendUnique("epistemos.apiKey.\(providerSegment)", to: &keys)

        if envSegment != providerSegment {
            appendUnique("epistemos.\(envSegment).apiKey", to: &keys)
            appendUnique("epistemos.apiKey.\(envSegment)", to: &keys)
        }

        return keys
    }

    private enum CredentialLookupResult {
        case found(keychainKey: String, value: String)
        case missing
        case oversized
    }

    private func epistemosCredential(
        providerID: String,
        gooseSecretKey: String
    ) -> CredentialLookupResult {
        var sawOversizedCredential = false
        for keychainKey in Self.candidateKeychainKeys(
            providerID: providerID,
            gooseSecretKey: gooseSecretKey
        ) {
            guard let rawValue = keychainLoad(keychainKey) else {
                continue
            }
            guard rawValue.utf8.count <= Self.maxCredentialValueCharacters,
                  !rawValue.utf8.contains(0) else {
                sawOversizedCredential = true
                continue
            }
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            return .found(keychainKey: keychainKey, value: value)
        }
        return sawOversizedCredential ? .oversized : .missing
    }

    private static func providerIDs(
        from entries: [JSONValue],
        skipped: inout [SkippedProvider]
    ) -> [String] {
        var seen = Set<String>()
        return entries.compactMap { entry in
            guard let providerID = entry.objectValue?["providerId"]?.stringValue ??
                entry.objectValue?["id"]?.stringValue,
                !providerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                skipped.append(.init(
                    gooseProviderId: "*",
                    gooseSecretKey: nil,
                    reason: .missingProviderId
                ))
                return nil
            }
            let trimmed = providerID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count <= GooseACPProtocolBounds.maxInventoryIDCharacters else {
                skipped.append(.init(
                    gooseProviderId: "*",
                    gooseSecretKey: nil,
                    reason: .missingProviderId
                ))
                return nil
            }
            guard seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }

    private static func normalizedEnvironmentKeySegment(_ key: String) -> String? {
        var segment = key.lowercased()
        for suffix in ["_api_key", "_access_token", "_token", "_key"] where segment.hasSuffix(suffix) {
            segment.removeLast(suffix.count)
            break
        }
        return normalizedKeychainSegment(
            segment,
            maxCharacters: GooseACPProtocolBounds.maxProviderConfigFieldKeyCharacters
        )
    }

    private static func normalizedKeychainSegment(_ value: String, maxCharacters: Int) -> String? {
        guard let bounded = boundedKeychainSegmentSource(value, maxCharacters: maxCharacters) else {
            return nil
        }
        let scalars = bounded.lowercased().unicodeScalars
        let normalized = String(String.UnicodeScalarView(scalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? scalar : "."
        }))
        let segment = normalized
            .split(separator: ".")
            .joined(separator: ".")
        return segment.isEmpty ? nil : segment
    }

    private static func boundedKeychainSegmentSource(_ value: String, maxCharacters: Int) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxCharacters,
              !trimmed.utf8.contains(0) else {
            return nil
        }
        return trimmed
    }

    private static func appendUnique(_ value: String?, to values: inout [String]) {
        guard let value,
              !value.isEmpty,
              value.count <= maxKeychainLookupKeyCharacters,
              !value.utf8.contains(0),
              !values.contains(value) else { return }
        values.append(value)
    }

    private static func defaultKeychainLoad(_ key: String) -> String? {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return nil }
        return Keychain.load(for: key)
    }
}

private extension JSONValue {
    nonisolated var objectValue: [String: JSONValue]? {
        guard case .object(let object) = self else { return nil }
        return object
    }

    nonisolated var stringValue: String? {
        guard case .string(let string) = self else { return nil }
        return string
    }
}
