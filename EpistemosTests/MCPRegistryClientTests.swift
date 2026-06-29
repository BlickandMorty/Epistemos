import Foundation
import Testing

@testable import Epistemos

@Suite("MCP registry client")
struct MCPRegistryClientTests {
    @Test("searchAll merges registry and GitHub entries without network dependency")
    func searchAllMergesSources() async throws {
        let client = MCPRegistryClient { request in
            let url = try #require(request.url)
            let body: String
            if url.host == "api.github.com" {
                body = """
                {
                  "items": [
                    {
                      "full_name": "anthropics/skills",
                      "description": "Agent skills",
                      "html_url": "https://github.com/anthropics/skills"
                    }
                  ]
                }
                """
            } else if url.host == "smithery.ai" {
                body = """
                {
                  "servers": [
                    {
                      "name": "Context7",
                      "description": "Current docs",
                      "remoteUrl": "https://mcp.context7.com/mcp",
                      "homepage": "https://context7.com"
                    }
                  ]
                }
                """
            } else {
                body = #"{"servers":[]}"#
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (Data(body.utf8), try #require(response))
        }

        let entries = await client.searchAll(query: "docs")
        let context7 = try #require(entries.first { $0.name == "Context7" })
        #expect(context7.installKind == .remoteURL)
        #expect(context7.isMASInstallable)
        #expect(context7.installTarget == "https://mcp.context7.com/mcp")

        let skills = try #require(entries.first { $0.name == "anthropics/skills" })
        #expect(skills.installKind == .skillRepo)
        #expect(!skills.isMASInstallable)
    }

    @Test("registry search trims and bounds outbound query text")
    func searchBoundsOutboundQueryText() async throws {
        let recorder = RegistryRequestRecorder()
        let client = MCPRegistryClient { request in
            let url = try #require(request.url)
            await recorder.record(url)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (Data(#"{"servers":[]}"#.utf8), try #require(response))
        }

        _ = await client.searchSmithery(query: "  \(String(repeating: "x", count: 200))  ")

        let url = try #require(await recorder.firstURL())
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = try #require(components.queryItems?.first { $0.name == "q" }?.value)
        #expect(query.count == 128)
        #expect(query.allSatisfy { $0 == "x" })
    }

    @Test("registry search skips oversized JSON bodies before parsing")
    func searchSkipsOversizedRegistryResponses() async throws {
        let client = MCPRegistryClient { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (Data(repeating: UInt8(ascii: "{"), count: 2 * 1024 * 1024 + 1), try #require(response))
        }

        let entries = await client.searchSmithery(query: "docs")
        #expect(entries.isEmpty)
    }

    @Test("registry search caps per-source record processing")
    func searchCapsPerSourceRecords() async throws {
        let records = (0..<40).map {
            #"{"name":"Server\#($0)","remoteUrl":"https://server\#($0).example.com/mcp"}"#
        }.joined(separator: ",")
        let body = #"{"servers":[\#(records)]}"#
        let client = MCPRegistryClient { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (Data(body.utf8), try #require(response))
        }

        let entries = await client.searchSmithery(query: "docs")
        #expect(entries.count == 32)
        #expect(!entries.map(\.name).contains("Server39"))
    }

    @Test("registry remote URL results reject credentials query strings and fragments")
    func searchFiltersSecretBearingRemoteURLTargets() async throws {
        let client = MCPRegistryClient { request in
            let url = try #require(request.url)
            let body = """
            {
              "servers": [
                { "name": "Userinfo", "remoteUrl": "https://abc123@example.com/mcp" },
                { "name": "Query", "remoteUrl": "https://example.com/mcp?token=abc123" },
                { "name": "Fragment", "remoteUrl": "https://example.com/mcp#token=abc123" },
                { "name": "Plain", "remoteUrl": "https://plain.example.com/mcp" }
              ]
            }
            """
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (Data(body.utf8), try #require(response))
        }

        let entries = await client.searchSmithery(query: "docs")
        #expect(entries.map(\.name) == ["Plain"])
        #expect(entries.first?.installTarget == "https://plain.example.com/mcp")
    }
}

private actor RegistryRequestRecorder {
    private var urls: [URL] = []

    func record(_ url: URL) {
        urls.append(url)
    }

    func firstURL() -> URL? {
        urls.first
    }
}
