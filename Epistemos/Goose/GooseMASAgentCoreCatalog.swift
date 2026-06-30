import Foundation
import os

#if canImport(agent_coreFFI)
import agent_coreFFI
#endif

nonisolated struct GooseMASAgentCoreCatalog: Codable, Equatable, Sendable {
    struct ConfigKey: Codable, Equatable, Sendable {
        let name: String
        let required: Bool
        let secret: Bool
        let primary: Bool
        let oauthFlow: Bool
        let deviceCodeFlow: Bool
        let defaultValue: String?

        private enum CodingKeys: String, CodingKey {
            case name
            case required
            case secret
            case primary
            case oauthFlow
            case deviceCodeFlow
            case defaultValue = "default"
        }
    }

    struct Model: Codable, Equatable, Sendable {
        let id: String
        let name: String
        let contextLimit: Int
        let family: String?
        let reasoning: Bool
        let recommended: Bool
    }

    struct Provider: Codable, Equatable, Sendable {
        let providerId: String
        let providerName: String
        let providerType: String
        let category: String
        let configured: Bool
        let refreshing: Bool
        let stale: Bool
        let supportsRefresh: Bool
        let defaultModel: String
        let description: String
        let masBounded: Bool
        let configKeys: [ConfigKey]
        let setupSteps: [String]
        let models: [Model]
    }

    struct Extension: Codable, Equatable, Sendable {
        let id: String
        let name: String
        let enabled: Bool
        let transport: String
        let description: String
    }

    struct ProGatedCapability: Codable, Equatable, Sendable {
        let id: String
        let name: String
        let reason: String
    }

    let schemaVersion: Int
    let backend: String
    let policyProfile: String
    let providers: [Provider]
    let extensions: [Extension]
    let proGatedCapabilities: [ProGatedCapability]
    let diagnostics: [String]

    private static let log = Logger(subsystem: "com.epistemos.goose", category: "GooseMASAgentCoreCatalog")

    init(
        schemaVersion: Int = 1,
        backend: String = "agent_core",
        policyProfile: String = "mas_sandbox",
        providers: [Provider],
        extensions: [Extension],
        proGatedCapabilities: [ProGatedCapability],
        diagnostics: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.backend = backend
        self.policyProfile = policyProfile
        self.providers = providers
        self.extensions = extensions
        self.proGatedCapabilities = proGatedCapabilities
        self.diagnostics = diagnostics
    }

    static func load() -> Self {
        #if canImport(agent_coreFFI)
        do {
            return try decode(json: gooseMasAcpCatalogJson())
        } catch {
            let message = EngineLogDiagnostics.logMessage(
                for: error,
                fallback: "Goose MAS catalog FFI failed"
            )
            log.error("\(message, privacy: .public)")
            return fallback(diagnostic: message)
        }
        #else
        return fallback(diagnostic: "agent_coreFFI unavailable; MAS ACP catalog is empty")
        #endif
    }

    static func decode(json: String) throws -> Self {
        let data = Data(json.utf8)
        let catalog = try JSONDecoder().decode(Self.self, from: data)
        guard catalog.schemaVersion == 1 else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Unsupported Goose MAS catalog schema \(catalog.schemaVersion)"
            ))
        }
        return catalog
    }

    static func fallback(diagnostic: String) -> Self {
        Self(
            providers: [],
            extensions: [],
            proGatedCapabilities: [
                ProGatedCapability(
                    id: "goose.subprocess",
                    name: "goose serve subprocess",
                    reason: "The MAS backend could not load agent_core catalog bindings."
                )
            ],
            diagnostics: [diagnostic]
        )
    }

    func initializeResult() -> [String: Any] {
        [
            "protocolVersion": 1,
            "agentInfo": [
                "name": "Epistemos",
                "version": backend == "agent_core" ? "agent_core-mas" : backend,
            ],
            "agentCapabilities": [
                "auth": [:],
                "loadSession": true,
                "mcpCapabilities": [
                    "http": true,
                    "sse": false,
                ],
                "promptCapabilities": [
                    "audio": false,
                    "embeddedContext": true,
                    "image": false,
                ],
                "sessionCapabilities": [
                    "close": [:],
                    "list": [:],
                ],
            ],
            "authMethods": [
                [
                    "id": "epistemos-provider",
                    "name": "Configure Provider",
                    "description": "Configure a cloud provider in Epistemos settings to set up your API key.",
                ],
            ],
            "_meta": metadata(),
        ]
    }

    func providersResult() -> [String: Any] {
        let entries = providers.map { $0.jsonObject() }
        return [
            "entries": entries,
            "providers": entries,
            "_meta": metadata(),
        ]
    }

    func providerCatalogResult() -> [String: Any] {
        let entries = providers.map { $0.jsonObject() }
        return [
            "entries": entries,
            "providers": entries,
            "catalog": entries,
            "_meta": metadata(),
        ]
    }

    func providerStatusResult() -> [String: Any] {
        [
            "statuses": providers.map {
                [
                    "providerId": $0.providerId,
                    "configured": $0.configured,
                    "stale": $0.stale,
                    "refreshing": $0.refreshing,
                ]
            },
            "_meta": metadata(),
        ]
    }

    func extensionsResult() -> [String: Any] {
        [
            "extensions": extensions.map { $0.jsonObject() },
            "proGatedCapabilities": proGatedCapabilities.map { $0.jsonObject() },
            "_meta": metadata(),
        ]
    }

    func unsupportedCapabilityData(capability: String) -> [String: Any] {
        [
            "capability": capability,
            "tier": "pro",
            "policyProfile": policyProfile,
            "proGatedCapabilities": proGatedCapabilities.map { $0.jsonObject() },
        ]
    }

    func metadata() -> [String: Any] {
        [
            "goose": [
                "backend": backend,
                "policyProfile": policyProfile,
                "masBounded": true,
                "diagnostics": diagnostics,
            ],
        ]
    }
}

private extension Encodable {
    nonisolated func jsonObject() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return object
    }
}
