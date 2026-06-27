import Foundation
import Testing
@testable import Epistemos

@Suite("Goose settings mutation live integration")
@MainActor
struct GooseSettingsMutationLiveIntegrationTests {
    @Test(
        "live Goose ACP preference and defaults mutation runs in an isolated home"
    )
    func liveSettingsMutationUsesIsolatedHome() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-settings-mutation.log")
        try? FileManager.default.removeItem(at: proofURL)

        let isolatedHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("EpistemosGooseSettingsMutation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedHome, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedHome) }

        try await withLiveGooseRuntime(
            proofName: "settings-mutation",
            homeDirectory: isolatedHome,
            disableKeyring: true
        ) { _, connection, progressURL in
            guard let acpURL = connection.acpWebSocketURL else {
                throw GooseLiveIntegrationError.runtimeFailed("Live Goose runtime did not produce an ACP WebSocket URL.")
            }
            appendLiveProgress("acp url=\(redactedACPURL(acpURL))", to: progressURL)

            let client = GooseACPClient(
                transport: GooseACPURLSessionWebSocketTransport(url: acpURL),
                clientVersion: "phase0-settings-mutation-live-test"
            )
            do {
                _ = try await withLiveTimeout(
                    seconds: 12,
                    description: "ACP initialize response",
                    onTimeout: { await client.close() },
                    operation: { try await client.initialize() }
                )

                let keys: [GooseACPPreferenceKey] = [.gooseThinkingEffort, .autoCompactThreshold]
                let before = try await client.readGoosePreferences(keys: keys)
                _ = try await client.saveGoosePreferences(values: [
                    .init(key: .gooseThinkingEffort, value: .string("high")),
                    .init(key: .autoCompactThreshold, value: .double(0.5)),
                ])
                let saved = try await client.readGoosePreferences(keys: keys)
                _ = try await client.removeGoosePreferences(keys: keys)
                let after = try await client.readGoosePreferences(keys: keys)
                let providers = try await client.listGooseProviders()
                let statuses = try await client.readGooseProviderConfigStatus(providerIds: [])
                let candidate = try providerMutationCandidate(
                    from: providers.entries,
                    statuses: statuses.statuses
                )
                _ = try await client.saveGooseProviderConfig(
                    providerId: candidate.providerId,
                    fields: candidate.configKeys.map {
                        .init(key: $0, value: "epistemos-phase0-settings-live-proof")
                    }
                )
                let defaults = try await client.saveGooseDefaults(providerId: candidate.providerId)
                _ = try await client.deleteGooseProviderConfig(providerId: candidate.providerId)

                guard saved.value(for: .gooseThinkingEffort) == .string("high") else {
                    throw GooseLiveIntegrationError.runtimeFailed("gooseThinkingEffort did not round-trip through ACP preferences read.")
                }
                guard saved.value(for: .autoCompactThreshold) == .double(0.5) else {
                    throw GooseLiveIntegrationError.runtimeFailed("autoCompactThreshold did not round-trip through ACP preferences read.")
                }
                guard after.values.allSatisfy({ $0.value == .null }) else {
                    throw GooseLiveIntegrationError.runtimeFailed("Preferences stayed configured after remove.")
                }
                guard defaults.providerId == candidate.providerId else {
                    throw GooseLiveIntegrationError.runtimeFailed("Default provider did not round-trip through ACP defaults save.")
                }

                let proof = """
                phase0_live_settings_mutation=pass
                goose_base_url=\(connection.baseURL.absoluteString)
                goose_acp_url=\(redactedACPURL(acpURL))
                isolated_home=true
                keyring_disabled=true
                saved_goose_thinking_effort=\(saved.value(for: .gooseThinkingEffort) == .string("high"))
                saved_auto_compact_threshold=\(saved.value(for: .autoCompactThreshold) == .double(0.5))
                removed_preferences=\(after.values.allSatisfy { $0.value == .null })
                defaults_provider_id=\(defaults.providerId ?? "<missing>")
                defaults_save_matches=\(defaults.providerId == candidate.providerId)
                provider_config_cleanup=true
                before_values=\(before.values.count)
                """
                try proof.write(to: proofURL, atomically: true, encoding: .utf8)
                await client.close()
            } catch {
                await client.close()
                throw error
            }
        }

        let proof = try String(contentsOf: proofURL, encoding: .utf8)
        #expect(proof.contains("phase0_live_settings_mutation=pass"))
        #expect(proof.contains("isolated_home=true"))
        #expect(proof.contains("keyring_disabled=true"))
        #expect(proof.contains("removed_preferences=true"))
        #expect(proof.contains("defaults_save_matches=true"))
    }

    @Test(
        "live Goose ACP model defaults persist across goose serve restart"
    )
    func liveModelDefaultsPersistAcrossRestart() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-model-defaults-restart.log")
        try? FileManager.default.removeItem(at: proofURL)

        let isolatedHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("EpistemosGooseModelDefaults-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedHome, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedHome) }

        var selectedProviderID = ""
        var selectedModelID = ""
        try await withLiveGooseRuntime(
            proofName: "model-defaults-save",
            homeDirectory: isolatedHome,
            disableKeyring: true
        ) { _, connection, progressURL in
            guard let acpURL = connection.acpWebSocketURL else {
                throw GooseLiveIntegrationError.runtimeFailed("Live Goose runtime did not produce an ACP WebSocket URL.")
            }
            let client = GooseACPClient(
                transport: GooseACPURLSessionWebSocketTransport(url: acpURL),
                clientVersion: "phase0-model-defaults-save"
            )
            defer { Task { await client.close() } }

            _ = try await withLiveTimeout(
                seconds: 12,
                description: "ACP initialize response",
                onTimeout: { await client.close() },
                operation: { try await client.initialize() }
            )
            let providers = try await client.listGooseProviders()
            let statuses = try await client.readGooseProviderConfigStatus(providerIds: [])
            let candidate = try providerMutationCandidate(
                from: providers.entries,
                statuses: statuses.statuses
            )
            let models = try await client.listGooseProviderSupportedModels(providerId: candidate.providerId)
            guard let modelID = models.models.first,
                  !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw GooseLiveIntegrationError.runtimeFailed("\(candidate.providerId) returned no supported models for defaults persistence proof.")
            }
            _ = try await client.saveGooseProviderConfig(
                providerId: candidate.providerId,
                fields: candidate.configKeys.map {
                    .init(key: $0, value: "epistemos-phase0-model-defaults")
                }
            )
            let saved = try await client.saveGooseDefaults(providerId: candidate.providerId, modelId: modelID)
            guard saved.providerId == candidate.providerId, saved.modelId == modelID else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose defaults save did not echo provider/model.")
            }
            selectedProviderID = candidate.providerId
            selectedModelID = modelID
            appendLiveProgress("saved_defaults provider=\(selectedProviderID) model=\(selectedModelID)", to: progressURL)
        }

        try await withLiveGooseRuntime(
            proofName: "model-defaults-restart",
            homeDirectory: isolatedHome,
            disableKeyring: true
        ) { _, connection, progressURL in
            guard let acpURL = connection.acpWebSocketURL else {
                throw GooseLiveIntegrationError.runtimeFailed("Live Goose runtime did not produce an ACP WebSocket URL.")
            }
            let client = GooseACPClient(
                transport: GooseACPURLSessionWebSocketTransport(url: acpURL),
                clientVersion: "phase0-model-defaults-restart"
            )
            defer { Task { await client.close() } }

            _ = try await withLiveTimeout(
                seconds: 12,
                description: "ACP initialize response after restart",
                onTimeout: { await client.close() },
                operation: { try await client.initialize() }
            )
            let restored = try await client.readGooseDefaults()
            appendLiveProgress(
                "restored_defaults provider=\(restored.providerId ?? "<missing>") model=\(restored.modelId ?? "<missing>")",
                to: progressURL
            )

            let proof = """
            phase0_live_model_defaults_restart=pass
            goose_base_url=\(connection.baseURL.absoluteString)
            goose_acp_url=\(redactedACPURL(acpURL))
            isolated_home=true
            keyring_disabled=true
            saved_provider_id=\(selectedProviderID)
            saved_model_id=\(selectedModelID)
            restored_provider_id=\(restored.providerId ?? "<missing>")
            restored_model_id=\(restored.modelId ?? "<missing>")
            defaults_persisted=\(restored.providerId == selectedProviderID && restored.modelId == selectedModelID)
            """
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard restored.providerId == selectedProviderID,
                  restored.modelId == selectedModelID else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose defaults did not persist provider/model across restart.")
            }
        }

        let proof = try String(contentsOf: proofURL, encoding: .utf8)
        #expect(proof.contains("phase0_live_model_defaults_restart=pass"))
        #expect(proof.contains("defaults_persisted=true"))
        try GoosePhase0CapabilityMatrix.record(
            [.modelSwitchPersistence],
            proofURL: proofURL,
            via: "goose serve ACP defaultsSave/read across restart"
        )
    }
}

private extension GooseACPPreferencesReadResponse {
    func value(for key: GooseACPPreferenceKey) -> JSONValue? {
        values.first { $0.key == key }?.value
    }
}
