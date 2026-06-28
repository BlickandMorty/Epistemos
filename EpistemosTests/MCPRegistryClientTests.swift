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
}
