import Foundation
import Testing
@testable import Epistemos

@Suite("Goose provider mutation live integration")
@MainActor
struct GooseProviderMutationLiveIntegrationTests {
    @Test(
        "live Goose ACP provider config save/read/delete runs in an isolated home"
    )
    func liveProviderConfigMutationUsesIsolatedHome() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-provider-config-mutation.log")
        try? FileManager.default.removeItem(at: proofURL)

        let isolatedHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("EpistemosGooseProviderMutation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedHome, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedHome) }

        try await withLiveGooseRuntime(
            proofName: "provider-config-mutation",
            homeDirectory: isolatedHome,
            disableKeyring: true
        ) { _, connection, progressURL in
            guard let acpURL = connection.acpWebSocketURL else {
                throw GooseLiveIntegrationError.runtimeFailed("Live Goose runtime did not produce an ACP WebSocket URL.")
            }
            appendLiveProgress("acp url=\(redactedACPURL(acpURL))", to: progressURL)

            let client = GooseACPClient(
                transport: GooseACPURLSessionWebSocketTransport(url: acpURL),
                clientVersion: "phase0-provider-mutation-live-test"
            )
            do {
                _ = try await withLiveTimeout(
                    seconds: 12,
                    description: "ACP initialize response",
                    onTimeout: { await client.close() },
                    operation: { try await client.initialize() }
                )

                let providers = try await client.listGooseProviders()
                let allStatuses = try await client.readGooseProviderConfigStatus(providerIds: [])
                let candidate = try providerMutationCandidate(
                    from: providers.entries,
                    statuses: allStatuses.statuses
                )

                let before = try await client.readGooseProviderConfigStatus(providerIds: [candidate.providerId])
                let configUpdates = candidate.configKeys.map {
                    GooseACPProviderConfigFieldUpdate(
                        key: $0,
                        value: isolatedGooseProviderConfigValue(for: $0)
                    )
                }
                let save = try await client.saveGooseProviderConfig(
                    providerId: candidate.providerId,
                    fields: configUpdates
                )
                let read = try await client.readGooseProviderConfig(providerId: candidate.providerId)
                let expectedFirstValue = try #require(configUpdates.first?.value)
                let field = try #require(read.fields.first { $0.key == candidate.configKeys[0] })
                let delete = try await client.deleteGooseProviderConfig(providerId: candidate.providerId)
                let after = try await client.readGooseProviderConfigStatus(providerIds: [candidate.providerId])

                guard before.statuses.first?.isConfigured == false else {
                    throw GooseLiveIntegrationError.runtimeFailed("\(candidate.providerId) was already configured before mutation.")
                }
                guard save.status.providerId == candidate.providerId, save.status.isConfigured else {
                    throw GooseLiveIntegrationError.runtimeFailed("\(candidate.providerId) did not report configured after save.")
                }
                guard field.value == expectedFirstValue else {
                    throw GooseLiveIntegrationError.runtimeFailed("\(candidate.configKeys[0]) did not round-trip through ACP config read.")
                }
                guard delete.status.providerId == candidate.providerId, !delete.status.isConfigured else {
                    throw GooseLiveIntegrationError.runtimeFailed("\(candidate.providerId) stayed configured after delete.")
                }
                guard after.statuses.first?.providerId == candidate.providerId,
                      after.statuses.first?.isConfigured == false else {
                    throw GooseLiveIntegrationError.runtimeFailed("\(candidate.providerId) status stayed configured after delete.")
                }

                let beforeStatus = before.statuses.first?.isConfigured.description ?? "<missing>"
                let proof = """
                phase0_live_provider_config_mutation=pass
                goose_base_url=\(connection.baseURL.absoluteString)
                goose_acp_url=\(redactedACPURL(acpURL))
                isolated_home=true
                keyring_disabled=true
                provider_id=\(candidate.providerId)
                config_keys=\(candidate.configKeys.joined(separator: ","))
                before_configured=\(beforeStatus)
                save_configured=\(save.status.isConfigured)
                read_value_matches=true
                delete_configured=\(delete.status.isConfigured)
                after_configured=\(after.statuses.first?.isConfigured.description ?? "<missing>")
                """
                try proof.write(to: proofURL, atomically: true, encoding: .utf8)
                await client.close()
            } catch {
                await client.close()
                throw error
            }
        }

        let proof = try String(contentsOf: proofURL, encoding: .utf8)
        #expect(proof.contains("phase0_live_provider_config_mutation=pass"))
        #expect(proof.contains("isolated_home=true"))
        #expect(proof.contains("keyring_disabled=true"))
        try GoosePhase0CapabilityMatrix.record(
            [.addProvider, .setKey],
            proofURL: proofURL,
            via: "goose serve ACP provider config save/read/delete"
        )
    }

    @Test(
        "live Goose ACP provider authenticate rejects non-OAuth providers without mutation"
    )
    func liveProviderAuthenticateRejectsNonOAuthProvider() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-provider-authenticate-rejection.log")
        try? FileManager.default.removeItem(at: proofURL)

        let isolatedHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("EpistemosGooseProviderAuthenticate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedHome, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedHome) }

        try await withLiveGooseRuntime(
            proofName: "provider-authenticate-rejection",
            homeDirectory: isolatedHome,
            disableKeyring: true
        ) { _, connection, progressURL in
            guard let acpURL = connection.acpWebSocketURL else {
                throw GooseLiveIntegrationError.runtimeFailed("Live Goose runtime did not produce an ACP WebSocket URL.")
            }
            appendLiveProgress("acp url=\(redactedACPURL(acpURL))", to: progressURL)

            let client = GooseACPClient(
                transport: GooseACPURLSessionWebSocketTransport(url: acpURL),
                clientVersion: "phase0-provider-authenticate-live-test"
            )
            do {
                _ = try await withLiveTimeout(
                    seconds: 12,
                    description: "ACP initialize response",
                    onTimeout: { await client.close() },
                    operation: { try await client.initialize() }
                )

                let providers = try await client.listGooseProviders()
                let allStatuses = try await client.readGooseProviderConfigStatus(providerIds: [])
                let candidate = try providerMutationCandidate(
                    from: providers.entries,
                    statuses: allStatuses.statuses
                )
                let before = try await client.readGooseProviderConfigStatus(providerIds: [candidate.providerId])
                let authError = try await providerAuthenticateError(
                    client: client,
                    providerId: candidate.providerId
                )
                let after = try await client.readGooseProviderConfigStatus(providerIds: [candidate.providerId])

                guard before.statuses.first?.isConfigured == false,
                      after.statuses.first?.isConfigured == false else {
                    throw GooseLiveIntegrationError.runtimeFailed("\(candidate.providerId) config status changed during authenticate rejection.")
                }

                let proof = """
                phase0_live_provider_authenticate_rejection=pass
                goose_base_url=\(connection.baseURL.absoluteString)
                goose_acp_url=\(redactedACPURL(acpURL))
                isolated_home=true
                keyring_disabled=true
                provider_id=\(candidate.providerId)
                error_code=\(authError.code)
                error_message=\(authError.message)
                error_data=\(jsonString(authError.data) ?? "<missing>")
                before_configured=\(before.statuses.first?.isConfigured.description ?? "<missing>")
                after_configured=\(after.statuses.first?.isConfigured.description ?? "<missing>")
                """
                try proof.write(to: proofURL, atomically: true, encoding: .utf8)
                await client.close()
            } catch {
                await client.close()
                throw error
            }
        }

        let proof = try String(contentsOf: proofURL, encoding: .utf8)
        #expect(proof.contains("phase0_live_provider_authenticate_rejection=pass"))
        #expect(proof.contains("isolated_home=true"))
        #expect(proof.contains("keyring_disabled=true"))
        #expect(proof.contains("error_code=-32602"))
        #expect(proof.contains("after_configured=false"))
    }
}

private func providerAuthenticateError(
    client: GooseACPClient,
    providerId: String
) async throws -> (code: Int, message: String, data: JSONValue?) {
    do {
        _ = try await client.authenticateGooseProviderConfig(providerId: providerId)
    } catch GooseACPProtocolError.jsonRPCError(let code, let message, let data) {
        guard code == -32602 else {
            throw GooseLiveIntegrationError.runtimeFailed("Provider authenticate returned unexpected JSON-RPC code \(code).")
        }
        guard jsonString(data)?.contains("Provider does not support native authentication") == true else {
            throw GooseLiveIntegrationError.runtimeFailed("Provider authenticate rejection did not include the native-auth unsupported reason.")
        }
        return (code, message, data)
    }
    throw GooseLiveIntegrationError.runtimeFailed("Provider authenticate unexpectedly succeeded for \(providerId).")
}

private func jsonString(_ value: JSONValue?) -> String? {
    guard case .string(let string)? = value else { return nil }
    return string
}

struct ProviderMutationCandidate {
    let providerId: String
    let configKeys: [String]
    let defaultModelId: String?
}

struct ProviderInventoryEntry: Decodable {
    let providerId: String
    let configKeys: [ProviderInventoryConfigKey]
    let defaultModel: String?
    let models: [ProviderInventoryModel]?
}

struct ProviderInventoryModel: Decodable {
    let id: String
}

struct ProviderInventoryConfigKey: Decodable {
    let name: String
    let required: Bool
    let secret: Bool
    let `default`: String?
    let oauthFlow: Bool?
    let deviceCodeFlow: Bool?
}

func providerMutationCandidate(
    from entries: [JSONValue],
    statuses: [GooseACPProviderConfigStatus]
) throws -> ProviderMutationCandidate {
    let configuredByProvider = Dictionary(uniqueKeysWithValues: statuses.map { ($0.providerId, $0.isConfigured) })
    let decoded = try entries.map { try $0.decoded(ProviderInventoryEntry.self) }
    for entry in decoded {
        guard configuredByProvider[entry.providerId] == false else {
            continue
        }
        guard entry.configKeys.allSatisfy({ $0.oauthFlow != true && $0.deviceCodeFlow != true }) else {
            continue
        }
        let required = entry.configKeys.filter { key in
            key.required && key.default == nil
        }
        guard !required.isEmpty,
              required.allSatisfy({ !$0.secret }) else {
            continue
        }
        return ProviderMutationCandidate(
            providerId: entry.providerId,
            configKeys: required.map(\.name),
            defaultModelId: entry.defaultModel ?? entry.models?.first?.id
        )
    }
    throw GooseLiveIntegrationError.runtimeFailed("No required non-secret non-OAuth provider config key available for live mutation proof.")
}

func isolatedGooseProviderConfigValue(
    for key: String,
    fallback: String = "epistemos-phase0-live-proof"
) -> String {
    let uppercased = key.uppercased()
    if uppercased.contains("ENDPOINT")
        || uppercased.contains("BASE_URL")
        || uppercased.contains("HOST") {
        return "https://example.invalid"
    }
    return fallback
}
