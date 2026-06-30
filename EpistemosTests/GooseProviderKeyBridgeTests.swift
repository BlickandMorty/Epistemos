import Foundation
import Testing
@testable import Epistemos

@Suite("Goose provider key bridge")
struct GooseProviderKeyBridgeTests {
    @Test("bridge pushes Epistemos Keychain API keys through Goose provider config ACP")
    func bridgePushesEpistemosKeysThroughGooseProviderConfigACP() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"entries":[{"providerId":"openai"},{"providerId":"openrouter"},{"providerId":"google"},{"name":"missing-id"}]}}"#,
            #"{"jsonrpc":"2.0","id":3,"result":{"fields":[{"key":"OPENAI_API_KEY","value":null,"isSet":false,"isSecret":true,"required":false},{"key":"OPENAI_HOST","value":"https://api.openai.com","isSet":true,"isSecret":false,"required":false}]}}"#,
            #"{"jsonrpc":"2.0","id":4,"result":{"status":{"providerId":"openai","isConfigured":true},"refresh":{}}}"#,
            #"{"jsonrpc":"2.0","id":5,"result":{"fields":[{"key":"OPENROUTER_API_KEY","value":null,"isSet":false,"isSecret":true,"required":false}]}}"#,
            #"{"jsonrpc":"2.0","id":6,"result":{"status":{"providerId":"openrouter","isConfigured":true},"refresh":{}}}"#,
            #"{"jsonrpc":"2.0","id":7,"result":{"fields":[{"key":"GOOGLE_HOST","value":"https://generativelanguage.googleapis.com","isSet":true,"isSecret":false,"required":false}]}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")
        let keychain = TestKeychainStore(values: [
            CloudModelProvider.openAI.apiKeyKeychainKey: " sk-openai-bridge ",
            "epistemos.openrouter.apiKey": " sk-openrouter-bridge ",
            CloudModelProvider.google.apiKeyKeychainKey: "google-key-without-matching-goose-field",
        ])
        let bridge = GooseProviderKeyBridge(keychainLoad: keychain.load(_:))

        #expect(GooseProviderKeyBridge.candidateKeychainKeys(
            providerID: "openrouter",
            gooseSecretKey: "OPENROUTER_API_KEY"
        ).first == "epistemos.openrouter.apiKey")

        _ = try await client.initialize()
        let result = await bridge.syncConfiguredProviderKeys(to: client)

        #expect(result.applied == [
            .init(
                gooseProviderId: "openai",
                gooseSecretKey: "OPENAI_API_KEY",
                epistemosKeychainKey: CloudModelProvider.openAI.apiKeyKeychainKey,
                configured: true
            ),
            .init(
                gooseProviderId: "openrouter",
                gooseSecretKey: "OPENROUTER_API_KEY",
                epistemosKeychainKey: "epistemos.openrouter.apiKey",
                configured: true
            ),
        ])
        #expect(result.skipped.contains(.init(
            gooseProviderId: "*",
            gooseSecretKey: nil,
            reason: .missingProviderId
        )))
        #expect(result.skipped.contains(.init(
            gooseProviderId: "google",
            gooseSecretKey: nil,
            reason: .missingGooseSecretField
        )))

        let sent = await transport.sentMessages()
        let methods = sent.compactMap { jsonObject($0.raw)?["method"] }
        #expect(methods == [
            .string("initialize"),
            .string("_goose/unstable/providers/list"),
            .string("_goose/unstable/providers/config/read"),
            .string("_goose/unstable/providers/config/save"),
            .string("_goose/unstable/providers/config/read"),
            .string("_goose/unstable/providers/config/save"),
            .string("_goose/unstable/providers/config/read"),
        ])

        let saveParams = try #require(jsonObject(jsonObject(sent[3].raw)?["params"]))
        #expect(saveParams["providerId"] == .string("openai"))
        let fields = try #require(jsonArray(saveParams["fields"]))
        let field = try #require(jsonObject(fields.first))
        #expect(field["key"] == .string("OPENAI_API_KEY"))
        #expect(field["value"] == .string("sk-openai-bridge"))

        let openRouterSaveParams = try #require(jsonObject(jsonObject(sent[5].raw)?["params"]))
        #expect(openRouterSaveParams["providerId"] == .string("openrouter"))
        let googleSaveRequests = sent.filter { message in
            guard jsonObject(message.raw)?["method"] == .string("_goose/unstable/providers/config/save") else {
                return false
            }
            let params = jsonObject(jsonObject(message.raw)?["params"])
            return params?["providerId"] == .string("google")
        }
        #expect(googleSaveRequests.isEmpty)
        await client.close()
    }

    @Test("candidate Keychain keys bound provider and secret identifiers")
    func candidateKeychainKeysBoundProviderAndSecretIdentifiers() throws {
        let oversizedProviderID = String(
            repeating: "p",
            count: GooseACPProtocolBounds.maxInventoryIDCharacters + 1
        )
        let oversizedSecretKey = String(
            repeating: "S",
            count: GooseACPProtocolBounds.maxProviderConfigFieldKeyCharacters + 1
        )

        #expect(GooseProviderKeyBridge.candidateKeychainKeys(
            providerID: oversizedProviderID,
            gooseSecretKey: "OPENAI_API_KEY"
        ).isEmpty)
        #expect(GooseProviderKeyBridge.candidateKeychainKeys(
            providerID: "openai",
            gooseSecretKey: oversizedSecretKey
        ).isEmpty)
        #expect(GooseProviderKeyBridge.candidateKeychainKeys(
            providerID: "open\0ai",
            gooseSecretKey: "OPENAI_API_KEY"
        ).isEmpty)

        let keys = GooseProviderKeyBridge.candidateKeychainKeys(
            providerID: " OpenAI Compatible ",
            gooseSecretKey: " OPENAI_API_KEY "
        )
        #expect(keys.contains("epistemos.openai.compatible.apiKey"))
        #expect(keys.contains("epistemos.openai.apiKey"))
        #expect(keys.allSatisfy { $0.count <= GooseProviderKeyBridge.maxKeychainLookupKeyCharacters })

        let source = try loadRepoTextFile("Epistemos/Goose/GooseProviderKeyBridge.swift")
        #expect(source.contains("boundedKeychainSegmentSource("))
        #expect(source.contains("rawValue.utf8.count <= Self.maxCredentialValueCharacters"))
    }

    @Test("bridge skips oversized Keychain credentials before provider config save")
    func bridgeSkipsOversizedCredentialsBeforeSave() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"entries":[{"providerId":"openai"}]}}"#,
            #"{"jsonrpc":"2.0","id":3,"result":{"fields":[{"key":"OPENAI_API_KEY","value":null,"isSet":false,"isSecret":true,"required":false}]}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")
        let oversizedCredential = String(
            repeating: "s",
            count: GooseProviderKeyBridge.maxCredentialValueCharacters + 1
        )
        let bridge = GooseProviderKeyBridge(keychainLoad: { key in
            key == CloudModelProvider.openAI.apiKeyKeychainKey ? oversizedCredential : nil
        })

        _ = try await client.initialize()
        let result = await bridge.syncConfiguredProviderKeys(to: client)

        #expect(result.applied.isEmpty)
        #expect(result.skipped == [
            .init(
                gooseProviderId: "openai",
                gooseSecretKey: "OPENAI_API_KEY",
                reason: .oversizedEpistemosCredential
            ),
        ])

        let sent = await transport.sentMessages()
        let methods = sent.compactMap { jsonObject($0.raw)?["method"] }
        #expect(methods == [
            .string("initialize"),
            .string("_goose/unstable/providers/list"),
            .string("_goose/unstable/providers/config/read"),
        ])
        await client.close()
    }

    @Test("bridge skips NUL-containing Keychain credentials before provider config save")
    func bridgeSkipsNULCredentialsBeforeSave() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"entries":[{"providerId":"openai"}]}}"#,
            #"{"jsonrpc":"2.0","id":3,"result":{"fields":[{"key":"OPENAI_API_KEY","value":null,"isSet":false,"isSecret":true,"required":false}]}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")
        let bridge = GooseProviderKeyBridge(keychainLoad: { key in
            key == CloudModelProvider.openAI.apiKeyKeychainKey ? "sk\0secret" : nil
        })

        _ = try await client.initialize()
        let result = await bridge.syncConfiguredProviderKeys(to: client)

        #expect(result.applied.isEmpty)
        #expect(result.skipped == [
            .init(
                gooseProviderId: "openai",
                gooseSecretKey: "OPENAI_API_KEY",
                reason: .oversizedEpistemosCredential
            ),
        ])

        let sent = await transport.sentMessages()
        #expect(!sent.contains { jsonObject($0.raw)?["method"] == .string("_goose/unstable/providers/config/save") })
        await client.close()
    }
}

private func jsonObject(_ value: JSONValue?) -> [String: JSONValue]? {
    guard case .object(let object)? = value else { return nil }
    return object
}

private func jsonArray(_ value: JSONValue?) -> [JSONValue]? {
    guard case .array(let array)? = value else { return nil }
    return array
}

private func loadRepoTextFile(_ relativePath: String) throws -> String {
    try loadMirroredSourceTextFile(relativePath)
}
