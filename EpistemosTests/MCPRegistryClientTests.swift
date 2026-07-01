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

    @Test("registry search rejects redirected response URLs")
    func searchRejectsRedirectedRegistryResponses() async throws {
        let client = MCPRegistryClient { _ in
            let responseURL = try #require(URL(string: "https://example.com/api/servers"))
            let response = HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            let body = """
            {
              "servers": [
                { "name": "Redirected", "remoteUrl": "https://redirected.example.com/mcp" }
              ]
            }
            """
            return (Data(body.utf8), try #require(response))
        }

        let entries = await client.searchSmithery(query: "docs")
        #expect(entries.isEmpty)
    }

    @Test("registry search rejects same-host response URL query rewrites")
    func searchRejectsSameHostResponseURLQueryRewrites() async throws {
        let client = MCPRegistryClient { _ in
            let responseURL = try #require(URL(string: "https://smithery.ai/api/servers?q=other"))
            let response = HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            let body = """
            {
              "servers": [
                { "name": "Rewritten", "remoteUrl": "https://rewritten.example.com/mcp" }
              ]
            }
            """
            return (Data(body.utf8), try #require(response))
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

    @Test("GitHub repo results reject query strings and fragments")
    func searchGitHubFiltersSecretBearingRepoURLs() async throws {
        let client = MCPRegistryClient { request in
            let url = try #require(request.url)
            let body = """
            {
              "items": [
                {
                  "full_name": "owner/query",
                  "description": "Query",
                  "html_url": "https://github.com/owner/query?token=abc123"
                },
                {
                  "full_name": "owner/fragment",
                  "description": "Fragment",
                  "html_url": "https://github.com/owner/fragment#token=abc123"
                },
                {
                  "full_name": "owner/plain",
                  "description": "Plain",
                  "html_url": "https://github.com/owner/plain"
                }
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

        let entries = await client.searchGitHub(query: "docs")
        #expect(entries.map(\.name) == ["owner/plain"])
        #expect(entries.first?.installTarget == "https://github.com/owner/plain")
    }

    @Test("registry homepage URLs reject unsafe channels")
    func searchFiltersSecretBearingHomepageURLs() async throws {
        let client = MCPRegistryClient { request in
            let url = try #require(request.url)
            let body = """
            {
              "servers": [
                {
                  "name": "Plain",
                  "remoteUrl": "https://plain.example.com/mcp",
                  "homepage": "https://plain.example.com/docs"
                },
                {
                  "name": "Query",
                  "remoteUrl": "https://query.example.com/mcp",
                  "homepage": "https://query.example.com/docs?token=abc123"
                },
                {
                  "name": "Userinfo",
                  "remoteUrl": "https://userinfo.example.com/mcp",
                  "homepage": "https://abc123@userinfo.example.com/docs"
                }
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
        #expect(entries.first { $0.name == "Plain" }?.homepage == "https://plain.example.com/docs")
        #expect(entries.first { $0.name == "Query" }?.homepage == nil)
        #expect(entries.first { $0.name == "Userinfo" }?.homepage == nil)
    }

    @Test("registry string fields are bounded")
    func searchBoundsRegistryStringFields() async throws {
        let longText = String(repeating: "A", count: MCPRegistryClient.maxRegistryFieldLength + 128)
        let body = """
        {
          "servers": [
            {
              "name": "\(longText)",
              "description": "\(longText)",
              "remoteUrl": "https://bounded.example.com/mcp"
            }
          ]
        }
        """
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

        let entry = try #require(await client.searchSmithery(query: "docs").first)
        #expect(entry.name.count == MCPRegistryClient.maxRegistryFieldLength)
        #expect(entry.description.count == MCPRegistryClient.maxRegistryFieldLength)
    }

    @Test("searchAll ignores non-positive limits before fetching")
    func searchAllIgnoresNonPositiveLimits() async throws {
        let client = MCPRegistryClient { _ in
            Issue.record("searchAll(limit: 0) should not fetch registry data")
            throw URLError(.badURL)
        }

        #expect(await client.searchAll(query: "docs", limit: 0).isEmpty)
        #expect(await client.searchAll(query: "docs", limit: -1).isEmpty)
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
