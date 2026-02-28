import Foundation
import os

// MARK: - Research Service
// Academic research tools — paper search, novelty check, peer review,
// citation search, and idea generation. Paper search hits Semantic Scholar's
// public API; everything else uses real LLM calls with structured JSON output.

@MainActor @Observable
final class ResearchService {

    // MARK: - Dependencies

    private let research: ResearchState
    private let llm: LLMService

    init(research: ResearchState, llm: LLMService) {
        self.research = research
        self.llm = llm
    }

    // MARK: - Paper Search (Semantic Scholar API)

    func searchPapers(query: String, yearRange: String? = nil) async throws -> [ResearchPaper] {
        // SAFETY: Hardcoded well-known URL — URLComponents always succeeds.
        var components = URLComponents(string: "https://api.semanticscholar.org/graph/v1/paper/search")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "fields", value: "title,authors,year,journal,externalIds,abstract,citationCount")
        ]
        if let years = yearRange {
            queryItems.append(URLQueryItem(name: "year", value: years))
        }
        components.queryItems = queryItems

        guard let url = components.url else { throw ResearchError.invalidQuery }

        var request = URLRequest(url: url)
        request.setValue("Epistemos/4.0 (research-assistant)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ResearchError.apiError("No HTTP response from Semantic Scholar")
        }
        guard http.statusCode == 200 else {
            if http.statusCode == 429 {
                throw ResearchError.apiError("Rate limited by Semantic Scholar. Try again in a few seconds.")
            }
            throw ResearchError.apiError("Semantic Scholar returned status \(http.statusCode)")
        }

        let decoded = try JSONDecoder().decode(SemanticScholarResponse.self, from: data)
        return decoded.papers.map { paper in
            ResearchPaper(
                id: paper.paperId ?? UUID().uuidString,
                title: paper.title ?? "Untitled",
                authors: paper.authors?.compactMap(\.name) ?? [],
                year: paper.year,
                journal: paper.journal?.name,
                doi: paper.externalIds?["DOI"],
                abstract: paper.abstract,
                citationCount: paper.citationCount,
                source: "semantic_scholar",
                addedAt: .now
            )
        }
    }

    // MARK: - DOI Import

    func importDOI(_ doi: String) async throws -> SavedPaper {
        guard let encodedDOI = doi.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.semanticscholar.org/graph/v1/paper/DOI:\(encodedDOI)?fields=title,authors,year,journal,abstract,citationCount") else {
            throw ResearchError.invalidQuery
        }
        let (data, response) = try await URLSession.shared.data(from: url)

        if let http = response as? HTTPURLResponse, http.statusCode == 200 {
            do {
                let s2 = try JSONDecoder().decode(S2Paper.self, from: data)
                let paper = SavedPaper(
                    title: s2.title ?? "Untitled",
                    authors: s2.authors?.compactMap(\.name).joined(separator: ", ") ?? "Unknown",
                    year: s2.year.map(String.init),
                    journal: s2.journal?.name,
                    doi: doi,
                    abstract: s2.abstract
                )
                research.addSavedPaper(paper)
                return paper
            } catch {
                Log.research.error("Failed to decode S2Paper for DOI \(doi, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        // Fallback — save with DOI only
        let paper = SavedPaper(title: "Paper from DOI: \(doi)", authors: "Unknown Authors", doi: doi)
        research.addSavedPaper(paper)
        return paper
    }

    // MARK: - Novelty Check (LLM-powered)

    func checkNovelty(title: String, description: String, hypothesis: String? = nil, keywords: [String]? = nil) async throws -> NoveltyResult {
        let maxRounds = 3
        var previousQueries: [String] = []
        var allPapers: [ResearchPaper] = []

        for round in 1...maxRounds {
            let querySystemPrompt = """
            You are a research literature expert. Given a research idea, formulate a precise search query for Semantic Scholar that would find the most similar existing published work.

            Your query should:
            - Use technical terms from the field
            - Include key methodology and application domain terms
            - Be specific enough to find closely related work, not just vaguely similar papers
            - Avoid repeating previous queries that found nothing relevant

            Previous queries tried: \(previousQueries.isEmpty ? "None" : previousQueries.joined(separator: "; "))

            Respond with ONLY the search query text, no explanation.
            """

            var queryUserPrompt = "Research idea to check for novelty:\n\nTitle: \(title)\nDescription: \(description)"
            if let hyp = hypothesis { queryUserPrompt += "\nHypothesis: \(hyp)" }
            if let kw = keywords, !kw.isEmpty { queryUserPrompt += "\nKeywords: \(kw.joined(separator: ", "))" }

            let searchQuery = try await llm.generate(prompt: queryUserPrompt, systemPrompt: querySystemPrompt, maxTokens: 200)
            let cleanQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"")))
            previousQueries.append(cleanQuery)

            let papers = (try? await searchPapers(query: cleanQuery)) ?? []
            allPapers.append(contentsOf: papers)

            let paperSummaries = allPapers.prefix(20).enumerated().map { i, p in
                "[\(i+1)] \(p.title) (\(p.authors.prefix(3).joined(separator: ", ")), \(p.year ?? 0)) — \(p.citationCount ?? 0) citations\n   \(p.abstract?.prefix(200) ?? "No abstract")"
            }.joined(separator: "\n\n")

            let evalSystemPrompt = """
            You are a research novelty evaluator. Assess whether a proposed research idea is sufficiently novel compared to existing published literature.

            An idea is "novel" if it presents a meaningfully different approach, application, or combination not found in existing work.
            An idea is "not_novel" if existing papers substantially cover the same ground.
            Choose "search_more" only if you believe different search terms might reveal more relevant papers.

            This is round \(round) of \(maxRounds). \(round == maxRounds ? "This is the last round — you must choose novel or not_novel." : "")

            Respond in JSON: { "decision": "novel" | "not_novel" | "search_more", "confidence": 0.0-1.0, "summary": "..." }
            """

            let evalUserPrompt = "Research idea:\nTitle: \(title)\nDescription: \(description)\n\nPapers found:\n\(paperSummaries.isEmpty ? "No papers found." : paperSummaries)"

            let evalResponse = try await llm.generate(prompt: evalUserPrompt, systemPrompt: evalSystemPrompt, maxTokens: 500)
            let json = extractJSON(from: evalResponse)

            if let data = json.data(using: .utf8) {
                let result: NoveltyEvaluation
                do {
                    result = try JSONDecoder().decode(NoveltyEvaluation.self, from: data)
                } catch {
                    Log.research.error("Failed to decode NoveltyEvaluation: \(error.localizedDescription, privacy: .public)")
                    continue
                }
                if result.decision != "search_more" || round == maxRounds {
                    return NoveltyResult(
                        isNovel: result.decision == "novel",
                        confidence: result.confidence,
                        searchRounds: round,
                        papersReviewed: allPapers.count,
                        summary: result.summary,
                        closestPapers: Array(allPapers.prefix(5))
                    )
                }
            }
        }

        return NoveltyResult(isNovel: true, confidence: 0.5, searchRounds: maxRounds, papersReviewed: allPapers.count, summary: "Unable to determine with confidence.", closestPapers: Array(allPapers.prefix(5)))
    }

    // MARK: - Paper Review (LLM-powered)

    func reviewPaper(title: String, abstract: String, fullText: String?) async throws -> ReviewResult {
        let systemPrompt = """
        You are an expert reviewer for a top-tier machine learning conference (NeurIPS/ICML/ICLR). Provide a thorough, fair, and constructive review.

        Scoring Guidelines (1-4 each):
        - Originality: How novel? 1=derivative, 4=groundbreaking
        - Quality: Technically sound? 1=flawed, 4=excellent
        - Clarity: Well-written? 1=unreadable, 4=exemplary
        - Significance: Important? 1=negligible, 4=transformative
        - Soundness: Claims well-supported? 1=major holes, 4=rock-solid
        - Presentation: Figures/tables/writing? 1=poor, 4=excellent
        - Contribution: Advances the field? 1=minimal, 4=significant
        - Confidence (1-5): Your confidence in this review

        Overall (1-10): 1-3=reject, 4-5=borderline reject, 6-7=borderline accept, 8-10=accept

        Respond in JSON:
        {
          "decision": "Strong Accept" | "Weak Accept" | "Borderline" | "Weak Reject" | "Strong Reject",
          "overallScore": 6.5,
          "scores": { "originality": 3, "quality": 3, "clarity": 3, "significance": 2, "soundness": 3, "presentation": 3, "contribution": 2, "confidence": 3 },
          "strengths": ["..."],
          "weaknesses": ["..."],
          "summary": "..."
        }
        """

        var userPrompt = "Please review the following paper:\n\nTitle: \(title)\n\nAbstract: \(abstract)"
        if let text = fullText, !text.isEmpty {
            userPrompt += "\n\nPaper Content:\n\(String(text.prefix(6000)))"
        }

        let response = try await llm.generate(prompt: userPrompt, systemPrompt: systemPrompt, maxTokens: 2000)
        let json = extractJSON(from: response)

        guard let data = json.data(using: .utf8) else {
            throw ResearchError.parseError("Failed to parse review response")
        }
        let parsed: ReviewResultJSON
        do {
            parsed = try JSONDecoder().decode(ReviewResultJSON.self, from: data)
        } catch {
            Log.research.error("Failed to decode ReviewResultJSON: \(error.localizedDescription, privacy: .public)")
            throw ResearchError.parseError("Failed to parse review response: \(error.localizedDescription)")
        }

        return ReviewResult(
            decision: ReviewDecision(rawValue: parsed.decision) ?? .borderline,
            overallScore: parsed.overallScore,
            scores: ReviewScores(
                originality: parsed.scores.originality,
                quality: parsed.scores.quality,
                clarity: parsed.scores.clarity,
                significance: parsed.scores.significance,
                soundness: parsed.scores.soundness,
                presentation: parsed.scores.presentation,
                contribution: parsed.scores.contribution,
                confidence: parsed.scores.confidence
            ),
            strengths: parsed.strengths,
            weaknesses: parsed.weaknesses,
            summary: parsed.summary
        )
    }

    // MARK: - Citation Search (LLM-powered)

    func searchCitations(text: String, context: String?) async throws -> CitationSearchResult {
        let claimSystemPrompt = """
        You are an expert academic editor specializing in citation coverage.

        Identify statements and claims that need citations from published literature. Focus on:
        - Factual claims about the state of the field
        - References to specific methods, techniques, or algorithms
        - Claims about performance, benchmarks, or comparisons
        - Theoretical foundations or established results
        - Statistical facts or empirical findings

        Do NOT flag:
        - The paper's own novel contributions
        - Obvious common knowledge
        - Statements that are the author's own analysis

        Respond in JSON: { "claims": [{ "claim": "...", "searchQuery": "..." }] }
        """

        let contextPrefix = context.map { "Context: This text is about \($0)\n\n" } ?? ""
        let claimUserPrompt = "\(contextPrefix)Text to analyze:\n\n\(String(text.prefix(6000)))"

        let claimResponse = try await llm.generate(prompt: claimUserPrompt, systemPrompt: claimSystemPrompt, maxTokens: 1500)
        let claimJSON = extractJSON(from: claimResponse)

        guard let claimData = claimJSON.data(using: .utf8) else {
            return CitationSearchResult(claimsFound: 0, papersMatched: 0, uniqueReferences: 0, matches: [])
        }
        let claims: ClaimExtractionResult
        do {
            claims = try JSONDecoder().decode(ClaimExtractionResult.self, from: claimData)
        } catch {
            Log.research.error("Failed to decode ClaimExtractionResult: \(error.localizedDescription, privacy: .public)")
            return CitationSearchResult(claimsFound: 0, papersMatched: 0, uniqueReferences: 0, matches: [])
        }

        var matches: [CitationMatch] = []
        for (i, claim) in claims.claims.prefix(10).enumerated() {
            if i > 0 { try? await Task.sleep(for: .milliseconds(200)) }
            guard let papers = try? await searchPapers(query: claim.searchQuery), let bestPaper = papers.first else { continue }

            matches.append(CitationMatch(
                claim: claim.claim,
                paperTitle: bestPaper.title,
                bibtexKey: generateBibtexKey(paper: bestPaper),
                explanation: "Matches claim: \(claim.claim.prefix(100))",
                relevanceScore: 0.7
            ))
        }

        return CitationSearchResult(
            claimsFound: claims.claims.count,
            papersMatched: matches.count,
            uniqueReferences: Set(matches.map(\.bibtexKey)).count,
            matches: matches
        )
    }

    // MARK: - Idea Generation (LLM-powered)

    func generateIdeas(topic: String, context: String?, constraints: String?, count: Int) async throws -> [ResearchIdea] {
        var ideas: [ResearchIdea] = []

        for i in 0..<count {
            let existingIdeas = ideas.map { "- \($0.title): \($0.description)" }.joined(separator: "\n")

            let systemPrompt = """
            You are an ambitious AI researcher at a top institution generating novel research ideas.

            Your ideas should be:
            - Novel: Not already published or widely explored
            - Feasible: Achievable with current methods and reasonable compute
            - Interesting: Would generate excitement and have meaningful impact
            - Well-defined: Clear experiment plan another researcher could follow
            - Specific: Not vague or overly broad

            Focus on creative yet grounded ideas. Avoid overly incremental work but also avoid moonshots that cannot be tested.

            Respond in JSON:
            {
              "title": "...",
              "description": "...",
              "feasibility": "Low" | "Medium" | "High",
              "novelty": "Low" | "Medium" | "High",
              "interestingness": "Low" | "Medium" | "High"
            }
            """

            var userPrompt = "Research topic: \(topic)"
            if let ctx = context { userPrompt += "\nAdditional context: \(ctx)" }
            if let cons = constraints { userPrompt += "\nConstraints: \(cons)" }
            if !existingIdeas.isEmpty {
                userPrompt += "\n\nThe following ideas have ALREADY been generated. Your new idea must be DIFFERENT:\n\(existingIdeas)"
            }
            userPrompt += "\n\nGenerate idea #\(i + 1) of \(count)."

            let response = try await llm.generate(prompt: userPrompt, systemPrompt: systemPrompt, maxTokens: 800)
            let json = extractJSON(from: response)

            if let data = json.data(using: .utf8) {
                let parsed: IdeaJSON
                do {
                    parsed = try JSONDecoder().decode(IdeaJSON.self, from: data)
                } catch {
                    Log.research.error("Failed to decode IdeaJSON: \(error.localizedDescription, privacy: .public)")
                    continue
                }
                let score = try await scoreIdea(parsed)

                ideas.append(ResearchIdea(
                    id: UUID().uuidString,
                    title: parsed.title,
                    description: parsed.description,
                    score: score,
                    feasibility: parsed.feasibility,
                    novelty: parsed.novelty,
                    interestingness: parsed.interestingness
                ))
            }
        }

        return ideas.sorted { $0.score > $1.score }
    }

    // MARK: - Helpers

    private func scoreIdea(_ idea: IdeaJSON) async throws -> Double {
        let systemPrompt = """
        You are an expert research evaluator. Score this idea on a 0.0-1.0 scale.
        - 0.0-0.2: Poor / fundamentally flawed
        - 0.2-0.4: Below average / significant issues
        - 0.4-0.6: Average / decent but not exceptional
        - 0.6-0.8: Good / strong idea with minor issues
        - 0.8-1.0: Excellent / top-tier research idea

        Respond with ONLY a number between 0.0 and 1.0, nothing else.
        """

        let userPrompt = "Title: \(idea.title)\nDescription: \(idea.description)\nFeasibility: \(idea.feasibility)\nNovelty: \(idea.novelty)"
        let response = try await llm.generate(prompt: userPrompt, systemPrompt: systemPrompt, maxTokens: 20)
        return Double(response.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.5
    }

    private func generateBibtexKey(paper: ResearchPaper) -> String {
        let firstAuthor = paper.authors.first?.components(separatedBy: " ").last ?? "unknown"
        let year = paper.year.map(String.init) ?? "nd"
        let firstWord = paper.title.components(separatedBy: " ").first?.lowercased() ?? "paper"
        return "\(firstAuthor.lowercased())\(year)\(firstWord)"
    }

    private func extractJSON(from response: String) -> String {
        let cleaned = response.replacingOccurrences(
            of: "<thinking>[\\s\\S]*?</thinking>",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else {
            return ""
        }
        return String(cleaned[start...end])
    }
}

// MARK: - Semantic Scholar API Types

private struct SemanticScholarResponse: Decodable {
    var total: Int?
    var data: [S2Paper]?
    var results: [S2Paper]?

    var papers: [S2Paper] { data ?? results ?? [] }
}

private struct S2Paper: Decodable {
    var paperId: String?
    var title: String?
    var authors: [S2Author]?
    var year: Int?
    var journal: S2Journal?
    var externalIds: [String: String]?
    var abstract: String?
    var citationCount: Int?

    private enum CodingKeys: String, CodingKey {
        case paperId, title, authors, year, journal, externalIds, abstract, citationCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        paperId = try c.decodeIfPresent(String.self, forKey: .paperId)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        authors = try c.decodeIfPresent([S2Author].self, forKey: .authors)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        journal = try c.decodeIfPresent(S2Journal.self, forKey: .journal)
        abstract = try c.decodeIfPresent(String.self, forKey: .abstract)
        citationCount = try c.decodeIfPresent(Int.self, forKey: .citationCount)

        // Lossy decode: S2 returns mixed types (String + Int) in externalIds
        do {
            if let raw = try c.decodeIfPresent([String: FlexValue].self, forKey: .externalIds) {
                externalIds = raw.mapValues(\.stringValue)
            } else {
                externalIds = nil
            }
        } catch {
            Log.research.warning("⚠️ externalIds decode failed: \(error.localizedDescription, privacy: .public)")
            externalIds = nil
        }
    }
}

private enum FlexValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)

    var stringValue: String {
        switch self {
        case .string(let s): s
        case .int(let i): String(i)
        case .double(let d): String(d)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s) }
        else if let i = try? container.decode(Int.self) { self = .int(i) }
        else if let d = try? container.decode(Double.self) { self = .double(d) }
        else { self = .string("") }
    }
}

private struct S2Author: Codable {
    var name: String?
}

private struct S2Journal: Codable {
    var name: String?
}

// MARK: - LLM Response Parse Types

private struct NoveltyEvaluation: Codable {
    var decision: String
    var confidence: Double
    var summary: String
}

private struct ReviewResultJSON: Codable {
    var decision: String
    var overallScore: Double
    var scores: ReviewScoresJSON
    var strengths: [String]
    var weaknesses: [String]
    var summary: String
}

private struct ReviewScoresJSON: Codable {
    var originality: Int
    var quality: Int
    var clarity: Int
    var significance: Int
    var soundness: Int
    var presentation: Int
    var contribution: Int
    var confidence: Int
}

private struct ClaimExtractionResult: Codable {
    var claims: [ClaimEntry]
}

private struct ClaimEntry: Codable {
    var claim: String
    var searchQuery: String
}

private struct IdeaJSON: Codable {
    var title: String
    var description: String
    var feasibility: String
    var novelty: String
    var interestingness: String
}

// MARK: - Research Errors

nonisolated enum ResearchError: Error, LocalizedError {
    case invalidQuery
    case apiError(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidQuery: "Invalid search query"
        case .apiError(let msg): "API error: \(msg)"
        case .parseError(let msg): "Parse error: \(msg)"
        }
    }
}

// MARK: - Result Types

struct NoveltyResult: Sendable {
    var isNovel: Bool
    var confidence: Double
    var searchRounds: Int
    var papersReviewed: Int
    var summary: String
    var closestPapers: [ResearchPaper]
}

struct ReviewResult: Sendable {
    var decision: ReviewDecision
    var overallScore: Double
    var scores: ReviewScores
    var strengths: [String]
    var weaknesses: [String]
    var summary: String
}

enum ReviewDecision: String, Sendable {
    case strongAccept = "Strong Accept"
    case weakAccept = "Weak Accept"
    case borderline = "Borderline"
    case weakReject = "Weak Reject"
    case strongReject = "Strong Reject"
}

struct ReviewScores: Sendable {
    var originality: Int
    var quality: Int
    var clarity: Int
    var significance: Int
    var soundness: Int
    var presentation: Int
    var contribution: Int
    var confidence: Int
}

struct CitationSearchResult: Sendable {
    var claimsFound: Int
    var papersMatched: Int
    var uniqueReferences: Int
    var matches: [CitationMatch]
}

struct CitationMatch: Identifiable, Sendable {
    var id: String = UUID().uuidString
    var claim: String
    var paperTitle: String
    var bibtexKey: String
    var explanation: String
    var relevanceScore: Double
}

struct ResearchIdea: Identifiable, Sendable {
    var id: String
    var title: String
    var description: String
    var score: Double
    var feasibility: String
    var novelty: String
    var interestingness: String
}
