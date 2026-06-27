import CryptoKit
import Foundation
import Testing
@testable import Epistemos

@Suite("Goose provider catalog live integration", .serialized)
@MainActor
struct GooseProviderCatalogLiveIntegrationTests {
    @Test("live Goose ACP enumerates provider and model catalog from Goose only")
    func liveProviderModelCatalogComesFromGooseACP() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-provider-catalog-fidelity.log")
        try? FileManager.default.removeItem(at: proofURL)

        try await withLiveGooseACPClient(proofName: "provider-catalog-fidelity") { binary, connection, client, progressURL in
            _ = try await withLiveTimeout(
                seconds: 12,
                description: "ACP initialize for provider catalog fidelity",
                onTimeout: { await client.close() },
                operation: { try await client.initialize() }
            )

            let providers = try await withLiveTimeout(
                seconds: 20,
                description: "Goose ACP providers/list catalog",
                onTimeout: { await client.close() },
                operation: { try await client.listGooseProviders() }
            )
            let setupCatalog = try await withLiveTimeout(
                seconds: 20,
                description: "Goose ACP providers/setup/catalog/list catalog",
                onTimeout: { await client.close() },
                operation: { try await client.listGooseProviderSetupCatalog() }
            )
            let customProviderCatalog = try await withLiveTimeout(
                seconds: 20,
                description: "Goose ACP providers/catalog/list catalog",
                onTimeout: { await client.close() },
                operation: { try await client.listGooseProviderCatalog() }
            )
            guard let templateProvider = customProviderCatalog.providers.first else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose ACP providers/catalog/list returned zero custom provider templates.")
            }
            let providerTemplate = try await withLiveTimeout(
                seconds: 20,
                description: "Goose ACP providers/catalog/template for \(templateProvider.providerId)",
                onTimeout: { await client.close() },
                operation: { try await client.readGooseProviderCatalogTemplate(providerId: templateProvider.providerId) }
            )
            let inventory = try providers.entries.map { try $0.decoded(GooseProviderCatalogInventoryEntry.self) }
            let providerIDs = inventory.map(\.providerId).sorted()
            let providerModelIDs = inventory.flatMap { entry in
                entry.models.map { "\(entry.providerId)/\($0.id)" }
            }.sorted()
            let setupProviderIDs = setupCatalog.providers.map(\.providerId).sorted()
            let customProviderIDs = customProviderCatalog.providers.map(\.providerId).sorted()
            let templateModelIDs = providerTemplate.template.models.map(\.id).sorted()
            let templateProviderPresent = customProviderIDs.contains(providerTemplate.template.providerId)
            let digestInput = ([
                "providers=\(providerIDs.joined(separator: ","))",
                "providerModels=\(providerModelIDs.joined(separator: ","))",
                "setupProviders=\(setupProviderIDs.joined(separator: ","))",
                "customProviders=\(customProviderIDs.joined(separator: ","))",
                "templateProvider=\(providerTemplate.template.providerId)",
                "templateModels=\(templateModelIDs.joined(separator: ","))",
            ]).joined(separator: "\n")
            let digest = gooseCatalogSHA256Hex(Data(digestInput.utf8))

            appendLiveProgress(
                "provider_catalog providers=\(providerIDs.count) provider_models=\(providerModelIDs.count) setup=\(setupProviderIDs.count) custom=\(customProviderIDs.count) template_provider=\(providerTemplate.template.providerId) template_models=\(templateModelIDs.count) digest=\(digest)",
                to: progressURL
            )

            let proof = [
                "phase0_live_provider_catalog_fidelity=pass",
                "goose_binary=\(binary.lastPathComponent)",
                "goose_binary_path=\(binary.path)",
                "goose_base_url=\(connection.baseURL.absoluteString)",
                "goose_acp_url=\(connection.acpWebSocketURL.map(redactedACPURL) ?? "<missing>")",
                "catalog_source=goose_serve_acp_only",
                "providers_list_method=_goose/unstable/providers/list",
                "setup_catalog_method=_goose/unstable/providers/setup/catalog/list",
                "custom_catalog_method=_goose/unstable/providers/catalog/list",
                "catalog_template_method=_goose/unstable/providers/catalog/template",
                "supported_models_method=not_used_for_catalog_inventory_avoids_configured_provider_initialization",
                "provider_count=\(providerIDs.count)",
                "provider_model_count=\(providerModelIDs.count)",
                "setup_provider_count=\(setupProviderIDs.count)",
                "custom_provider_count=\(customProviderIDs.count)",
                "template_provider_id=\(providerTemplate.template.providerId)",
                "template_model_count=\(providerTemplate.template.models.count)",
                "template_provider_present_in_catalog=\(templateProviderPresent)",
                "catalog_digest_sha256=\(digest)",
            ].joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard !providerIDs.isEmpty else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose ACP providers/list returned zero providers.")
            }
            guard !providerModelIDs.isEmpty else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose ACP providers/list returned zero provider models.")
            }
            guard !setupProviderIDs.isEmpty else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose ACP providers/setup/catalog/list returned zero providers.")
            }
            guard providerTemplate.template.providerId == templateProvider.providerId,
                  !providerTemplate.template.models.isEmpty else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose ACP providers/catalog/template returned an invalid template for \(templateProvider.providerId).")
            }
            guard templateProviderPresent else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose ACP providers/catalog/template returned a provider not present in providers/catalog/list.")
            }
            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_provider_catalog_fidelity=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live provider catalog fidelity proof log was not written.")
            }
            try GoosePhase0CapabilityMatrix.record(
                [.providerCatalog],
                proofURL: proofURL,
                via: "goose serve ACP provider/model catalog methods",
                details: [
                    "provider_count": "\(providerIDs.count)",
                    "provider_model_count": "\(providerModelIDs.count)",
                    "setup_provider_count": "\(setupProviderIDs.count)",
                    "custom_provider_count": "\(customProviderIDs.count)",
                    "template_provider": providerTemplate.template.providerId,
                    "template_model_count": "\(templateModelIDs.count)",
                    "catalog_digest_sha256": digest,
                ]
            )
        }
    }
}

private struct GooseProviderCatalogInventoryEntry: Decodable {
    let providerId: String
    let providerName: String
    let models: [GooseProviderCatalogInventoryModel]

    private enum CodingKeys: String, CodingKey {
        case providerId
        case providerName
        case models
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerId = try container.decode(String.self, forKey: .providerId)
        providerName = try container.decode(String.self, forKey: .providerName)
        models = try container.decodeIfPresent([GooseProviderCatalogInventoryModel].self, forKey: .models) ?? []
    }
}

private struct GooseProviderCatalogInventoryModel: Decodable {
    let id: String
}

private func gooseCatalogSHA256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
