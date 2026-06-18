import Testing
@testable import Epistemos

/// P7.6 — locks the cowork CONNECTORS mapping: a connector is "connected" ONLY
/// when a REAL wired MCP server matches it (never a fake toggle); unwired
/// connectors stay honestly disconnected.
@Suite("Cowork connector directory")
struct CoworkConnectorDirectoryTests {

    private func server(_ name: String, host: String, auth: Bool = false) -> MCPUrlServerDirectory.ServerInfo {
        MCPUrlServerDirectory.ServerInfo(name: name, url: "https://\(host)/mcp", declaresAuth: auth)
    }

    @Test("no wired servers → every connector is disconnected")
    func allDisconnectedWhenNoServers() {
        let statuses = CoworkConnectorDirectory.statuses(servers: [])
        #expect(statuses.count == CoworkConnectorDirectory.known.count)
        #expect(statuses.allSatisfy { !$0.isConnected })
        #expect(CoworkConnectorDirectory.connectedCount(servers: []) == 0)
    }

    @Test("a server matched by name connects exactly that connector")
    func matchByName() {
        let servers = [server("Slack", host: "example.com", auth: true)]
        let statuses = CoworkConnectorDirectory.statuses(servers: servers)
        let slack = statuses.first { $0.connector.id == "slack" }
        #expect(slack?.isConnected == true)
        #expect(slack?.declaresAuth == true)
        // No other connector falsely connects.
        #expect(statuses.filter(\.isConnected).count == 1)
        #expect(CoworkConnectorDirectory.connectedCount(servers: servers) == 1)
    }

    @Test("a server matched by host keyword connects (case-insensitive)")
    func matchByHost() {
        let servers = [server("My Mail", host: "mcp.GMAIL.com")]
        let gmail = CoworkConnectorDirectory.statuses(servers: servers).first { $0.connector.id == "gmail" }
        #expect(gmail?.isConnected == true)
        #expect(gmail?.declaresAuth == false)  // server declared no auth
    }

    @Test("an unrelated server connects nothing (no phantom connection)")
    func unrelatedServerConnectsNothing() {
        let servers = [server("Weather", host: "weather.example.com")]
        #expect(CoworkConnectorDirectory.connectedCount(servers: servers) == 0)
    }

    @Test("status order follows the known connector order")
    func statusOrderStable() {
        let ids = CoworkConnectorDirectory.statuses(servers: []).map(\.connector.id)
        #expect(ids == CoworkConnectorDirectory.known.map(\.id))
        #expect(ids == ["slack", "gmail", "drive", "notion"])
    }
}
