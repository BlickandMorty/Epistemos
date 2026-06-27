import Foundation
import Testing
@testable import Epistemos

@Suite("Goose ACP session lifecycle client")
struct GooseACPSessionLifecycleClientTests {
    @Test("client sends ACP new session recipe metadata like Goose Web UI")
    func clientSendsNewSessionRecipeMetadata() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"sessionId":"recipe-session"}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let session = try await client.newSession(
            cwd: "/repo",
            metadata: ["recipeId": .string("recipe-123")]
        )

        #expect(session.sessionId == "recipe-session")
        let sent = await transport.sentMessages()
        let params = try #require(sent.dropFirst().first?.raw.objectValue?["params"]?.objectValue)
        #expect(params["cwd"] == .string("/repo"))
        #expect(params["mcpServers"] == .array([]))
        #expect(params["_meta"]?.objectValue?["recipeId"] == .string("recipe-123"))
        await client.close()
    }

    @Test("client sends ACP session list, load, and fork requests")
    func clientSendsSessionLifecycleRequests() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"sessions":[{"sessionId":"session-1","cwd":"/repo","additionalDirectories":["/extra"],"title":"Phase 0","updatedAt":"2026-06-27T00:00:00Z","_meta":{"type":"user"}}],"nextCursor":"cursor-2","_meta":{"source":"goose"}}}"#,
            #"{"jsonrpc":"2.0","id":3,"result":{"modes":{"currentModeId":"auto"},"models":{"providerId":"mock","modelId":"mock-model"},"configOptions":[{"id":"temperature"}],"_meta":{"loaded":true}}}"#,
            #"{"jsonrpc":"2.0","id":4,"result":{"sessionId":"fork-1","modes":{"currentModeId":"auto"},"models":{"providerId":"mock","modelId":"mock-model"},"configOptions":[{"id":"temperature"}],"_meta":{"forked":true}}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let sessions = try await client.listSessions(
            cursor: "cursor-1",
            cwd: "/repo",
            additionalDirectories: ["/extra"],
            metadata: ["types": .array([.string("user"), .string("scheduled")])]
        )
        let loaded = try await client.loadSession(sessionId: "session-1", cwd: "/repo")
        let forked = try await client.forkSession(
            sessionId: "session-1",
            cwd: "/repo",
            conversationBefore: 1_718_000_120
        )

        #expect(sessions.sessions.first?.sessionId == "session-1")
        #expect(sessions.sessions.first?.additionalDirectories == ["/extra"])
        #expect(sessions.nextCursor == "cursor-2")
        #expect(sessions.metadata?.objectValue?["source"] == .string("goose"))
        #expect(loaded.models?.objectValue?["modelId"] == .string("mock-model"))
        #expect(loaded.metadata?.objectValue?["loaded"] == .bool(true))
        #expect(forked.sessionId == "fork-1")
        #expect(forked.metadata?.objectValue?["forked"] == .bool(true))

        let sent = await transport.sentMessages()
        let methods = sent.compactMap(\.method)
        #expect(methods == [.initialize, .listSessions, .loadSession, .forkSession])

        let listParams = try #require(sent.dropFirst().first?.raw.objectValue?["params"]?.objectValue)
        #expect(listParams["cwd"] == .string("/repo"))
        #expect(listParams["cursor"] == .string("cursor-1"))
        #expect(listParams["additionalDirectories"] == .array([.string("/extra")]))
        #expect(listParams["_meta"]?.objectValue?["types"] == .array([.string("user"), .string("scheduled")]))

        let loadParams = try #require(sent.dropFirst(2).first?.raw.objectValue?["params"]?.objectValue)
        #expect(loadParams["sessionId"] == .string("session-1"))
        #expect(loadParams["cwd"] == .string("/repo"))
        #expect(loadParams["mcpServers"] == .array([]))

        let forkParams = try #require(sent.dropFirst(3).first?.raw.objectValue?["params"]?.objectValue)
        #expect(forkParams["sessionId"] == .string("session-1"))
        #expect(forkParams["cwd"] == .string("/repo"))
        #expect(forkParams["mcpServers"] == nil)
        #expect(forkParams["_meta"]?.objectValue?["conversationBefore"] == .int(1_718_000_120))
        await client.close()
    }
}

private extension JSONValue {
    var objectValue: [String: JSONValue]? {
        guard case .object(let object) = self else { return nil }
        return object
    }
}
