import Foundation

// MARK: - Safari Agent

/// Specialist agent for web browsing.
/// All tool execution goes through the Rust Tool Layer (omega-mcp osascript.rs)
/// per Anti-Drift Anchor 1 and Anchor 5.
@MainActor
final class SafariAgent: OmegaAgent, @unchecked Sendable {
    let name = "safari"
    let description = "Web browsing: open URLs, get page content, search the web via Safari"
    let toolNames = ["open_url", "get_page_url", "get_page_title", "search_web", "readpagecontent", "searchpapers"]

    func execute(step: AgentStep) async throws -> AgentStepResult {
        let start = ContinuousClock.now

        guard let args = try? JSONSerialization.jsonObject(with: Data(step.argumentsJson.utf8)) as? [String: Any] else {
            return .fail("Invalid arguments JSON", stepId: step.id, durationMs: 0)
        }

        // All execution goes through Rust Tool Layer via UniFFI
        let resultJson: String
        switch step.toolName {
        case "open_url":
            guard let url = args["url"] as? String else {
                return .fail("Missing 'url' argument", stepId: step.id, durationMs: 0)
            }
            resultJson = toolOpenUrl(url: url)

        case "get_page_url":
            resultJson = toolGetPageUrl()

        case "get_page_title":
            resultJson = toolGetPageTitle()

        case "search_web":
            guard let query = args["query"] as? String else {
                return .fail("Missing 'query' argument", stepId: step.id, durationMs: 0)
            }
            resultJson = toolSearchWeb(query: query)

        case "readpagecontent":
            let maxLength = args["maxLength"] as? Int ?? 4000
            resultJson = toolGetPageText(maxLength: UInt32(max(0, maxLength)))

        case "searchpapers":
            guard let query = args["query"] as? String else {
                return .fail("Missing 'query' argument", stepId: step.id, durationMs: 0)
            }
            let limit = args["limit"] as? Int ?? 5
            let yearMin = args["yearMin"] as? Int
            let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)
            return await searchSemanticScholar(query: query, limit: limit, yearMin: yearMin, stepId: step.id, startMs: elapsed)

        default:
            return .fail("Unknown tool: \(step.toolName)", stepId: step.id, durationMs: 0)
        }

        let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)

        // Parse the Rust ToolResult JSON
        let confidence = parseToolResultConfidence(resultJson)
        if let parsed = try? JSONSerialization.jsonObject(with: Data(resultJson.utf8)) as? [String: Any],
           let success = parsed["success"] as? Bool, success {
            return .ok(resultJson, stepId: step.id, durationMs: elapsed, confidence: confidence)
        } else {
            let errorMsg = extractError(from: resultJson)
            return .fail(errorMsg, stepId: step.id, durationMs: elapsed)
        }
    }

    /// Parse confidence from ToolResult (1.0 for success, 0.5 for partial, 0.0 for failure).
    private func parseToolResultConfidence(_ json: String) -> Double {
        guard let data = json.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = result["success"] as? Bool else {
            return 0.0
        }
        return success ? 0.95 : 0.0
    }

    // MARK: - Semantic Scholar Search (Swift-side HTTP)

    private func searchSemanticScholar(query: String, limit: Int, yearMin: Int?, stepId: UUID, startMs: UInt64) async -> AgentStepResult {
        var urlString = "https://api.semanticscholar.org/graph/v1/paper/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&fields=title,authors,year,citationCount,externalIds,abstract&limit=\(min(limit, 10))"
        if let year = yearMin {
            urlString += "&year=\(year)-"
        }

        guard let url = URL(string: urlString) else {
            return .fail("Invalid Semantic Scholar URL", stepId: stepId, durationMs: startMs)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let httpResponse = response as? HTTPURLResponse

            guard let statusCode = httpResponse?.statusCode, (200..<300).contains(statusCode) else {
                // Fallback to web search
                let fallbackJson = toolSearchWeb(query: "site:scholar.google.com \(query)")
                return .ok(fallbackJson, stepId: stepId, durationMs: startMs, confidence: 0.6)
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let papers = json["data"] as? [[String: Any]] else {
                return .fail("Failed to parse Semantic Scholar response", stepId: stepId, durationMs: startMs)
            }

            let results = papers.prefix(limit).map { paper -> String in
                let title = paper["title"] as? String ?? "Unknown"
                let year = paper["year"] as? Int ?? 0
                let citations = paper["citationCount"] as? Int ?? 0
                let abstract = paper["abstract"] as? String ?? ""
                let truncatedAbstract = String(abstract.prefix(200))
                let authors = (paper["authors"] as? [[String: Any]])?
                    .compactMap { $0["name"] as? String }
                    .prefix(3)
                    .joined(separator: ", ") ?? "Unknown"
                let ids = paper["externalIds"] as? [String: Any]
                let doi = ids?["DOI"] as? String
                let arxivId = ids?["ArXiv"] as? String
                let urlStr = doi.map { "https://doi.org/\($0)" } ?? arxivId.map { "https://arxiv.org/abs/\($0)" } ?? ""

                return "{\"title\":\(jsonEscape(title)),\"authors\":\(jsonEscape(authors)),\"year\":\(year),\"citations\":\(citations),\"url\":\(jsonEscape(urlStr)),\"abstract\":\(jsonEscape(truncatedAbstract))}"
            }

            let resultJson = "{\"success\":true,\"action\":\"searchpapers\",\"count\":\(results.count),\"results\":[\(results.joined(separator: ","))]}"
            return .ok(resultJson, stepId: stepId, durationMs: startMs, confidence: 0.90)
        } catch {
            // Fallback to web search on network error
            let fallbackJson = toolSearchWeb(query: "site:scholar.google.com \(query)")
            return .ok(fallbackJson, stepId: stepId, durationMs: startMs, confidence: 0.5)
        }
    }

    private func jsonEscape(_ s: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: [s]),
           let arr = String(data: data, encoding: .utf8) {
            return String(arr.dropFirst().dropLast())
        }
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
                       .replacingOccurrences(of: "\"", with: "\\\"")
                       .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private func extractError(from json: String) -> String {
        guard let data = json.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = result["error"] as? String else {
            return "Unknown error"
        }
        return error
    }
}
