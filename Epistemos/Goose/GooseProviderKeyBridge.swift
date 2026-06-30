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
                guard let credential = epistemosCredential(
                    providerID: providerID,
                    gooseSecretKey: field.key
                ) else {
                    skipped.append(.init(
                        gooseProviderId: providerID,
                        gooseSecretKey: field.key,
                        reason: .missingEpistemosKey
                    ))
                    continue
                }
                updates.append(.init(key: field.key, value: credential.value))
                updateSources.append((field.key, credential.keychainKey))
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
        var keys: [String] = []
        appendUnique(AppBootstrap.agentCoreKeychainKey(forEnvironmentKey: gooseSecretKey), to: &keys)

        let providerSegment = normalizedKeychainSegment(providerID)
        appendUnique("epistemos.\(providerSegment).apiKey", to: &keys)
        appendUnique("epistemos.apiKey.\(providerSegment)", to: &keys)

        let envSegment = normalizedEnvironmentKeySegment(gooseSecretKey)
        if envSegment != providerSegment {
            appendUnique("epistemos.\(envSegment).apiKey", to: &keys)
            appendUnique("epistemos.apiKey.\(envSegment)", to: &keys)
        }

        return keys
    }

    private func epistemosCredential(
        providerID: String,
        gooseSecretKey: String
    ) -> (keychainKey: String, value: String)? {
        for keychainKey in Self.candidateKeychainKeys(
            providerID: providerID,
            gooseSecretKey: gooseSecretKey
        ) {
            guard let value = keychainLoad(keychainKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else {
                continue
            }
            return (keychainKey, value)
        }
        return nil
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

    private static func normalizedEnvironmentKeySegment(_ key: String) -> String {
        var segment = key.lowercased()
        for suffix in ["_api_key", "_access_token", "_token", "_key"] where segment.hasSuffix(suffix) {
            segment.removeLast(suffix.count)
            break
        }
        return normalizedKeychainSegment(segment)
    }

    private static func normalizedKeychainSegment(_ value: String) -> String {
        let scalars = value.lowercased().unicodeScalars
        let normalized = String(String.UnicodeScalarView(scalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? scalar : "."
        }))
        return normalized
            .split(separator: ".")
            .joined(separator: ".")
    }

    private static func appendUnique(_ value: String?, to values: inout [String]) {
        guard let value, !value.isEmpty, !values.contains(value) else { return }
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
