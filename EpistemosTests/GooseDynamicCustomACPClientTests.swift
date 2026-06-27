import Foundation
import Testing
@testable import Epistemos

@Suite("Goose dynamic custom ACP client")
struct GooseDynamicCustomACPClientTests {
    @Test("client sends unknown Goose custom ACP methods without a Swift wrapper")
    func clientSendsUnknownGooseCustomACPMethods() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"ok":true,"source":"goose","items":[{"id":"catalog"}]}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let result = try await client.sendGooseCustomRequest(
            method: "_goose/unstable/future/capability",
            params: .object(["probe": .string("catalog")])
        )

        #expect(jsonObject(result)?["ok"] == .bool(true))
        #expect(jsonObject(jsonArray(jsonObject(result)?["items"])?.first)?["id"] == .string("catalog"))

        let sent = await transport.sentMessages()
        let customMessage = try #require(sent.dropFirst().first)
        #expect(jsonObject(customMessage.raw)?["method"] == .string("_goose/unstable/future/capability"))
        #expect(jsonObject(jsonObject(customMessage.raw)?["params"])?["probe"] == .string("catalog"))
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
