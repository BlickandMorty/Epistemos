import Testing
import Foundation
import NaturalLanguage
@testable import Epistemos

// MARK: - Search Performance Tests

@Suite("Search Performance")
@MainActor
struct SearchPerformanceTests {
    private func bestDuration(
        warmupRuns: Int = 1,
        measuredRuns: Int = 3,
        _ operation: () -> Void
    ) -> Duration {
        let clock = ContinuousClock()

        for _ in 0..<warmupRuns {
            operation()
        }

        var best: Duration?
        for _ in 0..<measuredRuns {
            let start = clock.now
            operation()
            let elapsed = clock.now - start
            if let currentBest = best {
                if elapsed < currentBest {
                    best = elapsed
                }
            } else {
                best = elapsed
            }
        }

        return best ?? .zero
    }
    
    // MARK: - Rust FST Search Latency
    
    @Test("Rust FST search latency - small graph")
    func rustFSTSearchSmall() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 100)
        store.loadDirect(nodes: nodes, edges: edges)
        
        // Note: Without actual Rust engine, we test the Swift fallback
        // In production with Rust, this would use FST index
        let searchTime = bestDuration {
            let _ = store.fuzzySearch(query: "Node", limit: 20)
        }
        
        #expect(searchTime < .milliseconds(100), "Rust FST search took \(searchTime), expected < 100ms")
    }
    
    @Test("Rust FST search latency - medium graph")
    func rustFSTSearchMedium() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 500)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let searchTime = bestDuration {
            let _ = store.fuzzySearch(query: "Test", limit: 20)
        }
        
        #expect(searchTime < .milliseconds(100), "Rust FST search on 500 nodes took \(searchTime)")
    }
    
    @Test("Rust FST search latency - large graph")
    func rustFSTSearchLarge() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 2000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let searchTime = bestDuration {
            let _ = store.fuzzySearch(query: "Node", limit: 20)
        }
        
        #expect(searchTime < .milliseconds(175), "Rust FST search on 2000 nodes took \(searchTime)")
    }
    
    @Test("Rust FST search - multiple queries")
    func rustFSTMultipleQueries() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let queries = ["Node", "Test", "Source", "Note", "Idea", "Concept", "Research", "Data"]
        var totalTime: Duration = .zero
        
        measure {
            let start = ContinuousClock().now
            for query in queries {
                let _ = store.fuzzySearch(query: query, limit: 20)
            }
            totalTime = ContinuousClock().now - start
        }
        
        let avgTime = Double(totalTime.components.attoseconds) / Double(queries.count)
        #expect(totalTime < .milliseconds(Int(queries.count) * 50),
                "Multiple queries took \(totalTime), average per query too slow")
    }
    
    // MARK: - Hybrid Search Latency
    
    @Test("Hybrid search latency")
    func hybridSearchLatency() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 500)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let searchTime = bestDuration {
            // Simulate hybrid search: text + semantic
            let textResults = store.fuzzySearch(query: "test query", limit: 20)
            
            // Simulate semantic portion
            var semanticWork = 0.0
            for i in 0..<100 {
                semanticWork += sin(Double(i)) * 0.01
            }
            
            let _ = textResults
        }
        
        #expect(searchTime < .milliseconds(25), "Hybrid search took \(searchTime)")
    }
    
    // MARK: - Search with Increasing Result Counts
    
    @Test("Search with increasing result limits")
    func searchWithIncreasingLimits() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let limits = [10, 20, 50, 100]
        
        for limit in limits {
            let searchTime = bestDuration {
                let _ = store.fuzzySearch(query: "Node", limit: limit)
            }
            
            #expect(searchTime < .milliseconds(100),
                    "Search with limit \(limit) took \(searchTime)")
        }
    }
    
    @Test("Search result accuracy")
    func searchResultAccuracy() async throws {
        let store = GraphStore()
        
        // Create nodes with known names
        let nodeNames = [
            "Apple Pie Recipe",
            "Apple iPhone Review",
            "Banana Bread",
            "Application Architecture",
            "Pineapple Express",
            "Green Apple Salad",
            "App Development Guide"
        ]
        
        let nodes = nodeNames.map { name in
            SDGraphNode(type: .note, label: name, sourceId: nil)
        }
        store.loadDirect(nodes: nodes, edges: [])
        
        let results = store.fuzzySearch(query: "apple", limit: 10)
        
        // Should find apple-related results
        #expect(results.count >= 4, "Should find at least 4 apple-related results")
        
        // Exact match should be first
        if let first = results.first {
            #expect(first.node.label.lowercased().contains("apple"), 
                    "First result should contain 'apple': \(first.node.label)")
        }
    }
    
    // MARK: - Highlight Search Performance
    
    @Test("Highlight search performance")
    func highlightSearchPerformance() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 500)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let highlightTime = bestDuration {
            // Simulate highlight search
            let results = store.fuzzySearch(query: "test", limit: 50)
            
            // Apply highlighting to results
            for hit in results {
                let _ = hit.node.label.lowercased().contains("test")
            }
        }
        
        #expect(highlightTime < .milliseconds(100), "Highlight search took \(highlightTime)")
    }
    
    // MARK: - Semantic Search Vector Computation
    
    @Test("Semantic search vector computation time")
    func semanticVectorComputation() async throws {
        // Test NLEmbedding performance
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else {
            // Skip if embedding not available
            return
        }
        
        let testTexts = [
            "short text",
            "medium length text about machine learning and AI",
            "long text about the history of artificial intelligence and its impact on society and technology"
        ]
        
        for text in testTexts {
            var computeTime: Duration = .zero
            
            measure {
                let start = ContinuousClock().now
                
                // Simulate vector computation
                let words = text.lowercased()
                    .components(separatedBy: .alphanumerics.inverted)
                    .filter { $0.count > 1 }
                
                var vector = [Double](repeating: 0, count: embedding.dimension)
                var count = 0
                
                for word in words {
                    if let vec = embedding.vector(for: word) {
                        for (i, v) in vec.enumerated() {
                            vector[i] += v
                        }
                        count += 1
                    }
                }
                
                if count > 0 {
                    for i in 0..<vector.count {
                        vector[i] /= Double(count)
                    }
                }
                
                computeTime = ContinuousClock().now - start
            }
            
            // Vector computation should be fast
            #expect(computeTime < .milliseconds(50), 
                    "Vector computation for '\(text.prefix(20))...' took \(computeTime)")
        }
    }
    
    @Test("Semantic search with multiple query terms")
    func semanticSearchMultipleTerms() async throws {
        let queries = [
            "machine learning",
            "artificial intelligence neural networks",
            "deep learning computer vision natural language processing"
        ]
        
        for query in queries {
            var computeTime: Duration = .zero
            
            measure {
                let start = ContinuousClock().now
                
                // Simulate multi-term semantic processing
                let terms = query.split(separator: " ")
                var results: [[Double]] = []
                
                for term in terms {
                    let vec = [Double](repeating: Double(term.count) * 0.01, count: 512)
                    results.append(vec)
                }
                
                // Average vectors
                var avg = [Double](repeating: 0, count: 512)
                for vec in results {
                    for i in 0..<512 {
                        avg[i] += vec[i]
                    }
                }
                for i in 0..<512 {
                    avg[i] /= Double(results.count)
                }
                
                computeTime = ContinuousClock().now - start
            }
            
            #expect(computeTime < .milliseconds(10), 
                    "Semantic search for '\(query)' took \(computeTime)")
        }
    }
    
    // MARK: - Search Index Performance
    
    @Test("Search index build performance")
    func searchIndexBuildPerformance() async throws {
        let pageCounts = [100, 500, 1000]
        
        for count in pageCounts {
            var buildTime: Duration = .zero
            
            measure {
                let start = ContinuousClock().now
                
                // Simulate index building
                var index: [String: [(id: String, score: Double)]] = [:]
                for i in 0..<count {
                    let word = "word\(i % 1000)"
                    let entry = (id: "page\(i)", score: Double.random(in: 0...1))
                    index[word, default: []].append(entry)
                }
                
                buildTime = ContinuousClock().now - start
            }
            
            // Index building should scale linearly
            let expectedMax = Double(count) * 0.05 // 0.05ms per page
            #expect(buildTime < .milliseconds(Int(expectedMax)), 
                    "Index build for \(count) pages took \(buildTime)")
        }
    }
    
    @Test("Search index query performance")
    func searchIndexQueryPerformance() async throws {
        // Build a test index
        var index: [String: [(id: String, score: Double)]] = [:]
        for i in 0..<10000 {
            let word = "word\(i % 1000)"
            let entry = (id: "page\(i)", score: Double.random(in: 0...1))
            index[word, default: []].append(entry)
        }
        
        var queryTime: Duration = .zero
        let queryCount = 100
        
        measure {
            let start = ContinuousClock().now
            
            for i in 0..<queryCount {
                let word = "word\(i % 1000)"
                let _ = index[word]?.sorted { $0.score > $1.score }.prefix(20)
            }
            
            queryTime = ContinuousClock().now - start
        }
        
        let avgTime = Double(queryTime.components.attoseconds) / Double(queryCount)
        #expect(queryTime < .milliseconds(queryCount / 2), 
                "100 index queries took \(queryTime), average \(avgTime)ms")
    }
    
    // MARK: - FTS5 Search Performance
    
    @Test("FTS5 query preparation performance")
    func fts5QueryPreparation() async throws {
        let rawQueries = [
            "simple query",
            "query with \"quotes\" and *wildcards*",
            "complex query with OR AND NOT operators",
            "query with special chars: @#$%^&*()"
        ]
        
        for raw in rawQueries {
            let prepTime = bestDuration {
                // Simulate FTS5 sanitization
                let sanitized = raw.lowercased()
                    .components(separatedBy: .alphanumerics.inverted)
                    .filter { $0.count >= 2 }
                    .map { $0.replacingOccurrences(of: "\"", with: "") }
                    .filter { !$0.isEmpty }
                    .map { "\"\($0)\"*" }
                    .joined(separator: " ")
                
                let _ = sanitized
            }
            
            #expect(prepTime < .milliseconds(10),
                    "FTS5 prep for '\(raw)' took \(prepTime)")
        }
    }
    
    // MARK: - BM25 Ranking Performance
    
    @Test("BM25 ranking computation performance")
    func bm25RankingPerformance() async throws {
        let docCounts = [100, 500, 1000]
        
        for docCount in docCounts {
            var rankTime: Duration = .zero
            
            measure {
                let start = ContinuousClock().now
                
                // Simulate BM25 scoring
                var scores: [(id: String, score: Double)] = []
                for i in 0..<docCount {
                    let tf = Double.random(in: 0...10)
                    let idf = log(1000.0 / Double(i + 1))
                    let k1 = 1.5
                    let b = 0.75
                    let docLen = Double.random(in: 100...1000)
                    let avgDocLen = 500.0
                    
                    let score = idf * (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * (docLen / avgDocLen)))
                    scores.append((id: "doc\(i)", score: score))
                }
                
                // Sort by score
                scores.sort { $0.score > $1.score }
                
                rankTime = ContinuousClock().now - start
            }
            
            #expect(rankTime < .milliseconds(Int(Double(docCount) * 0.1)), 
                    "BM25 ranking for \(docCount) docs took \(rankTime)")
        }
    }
    
    // MARK: - Search Caching Performance
    
    @Test("Search result caching performance")
    func searchResultCaching() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 500)
        store.loadDirect(nodes: nodes, edges: edges)
        
        // First search
        let firstResults = store.fuzzySearch(query: "test", limit: 20)
        
        // Simulate caching
        var cache: [String: [GraphStore.SearchHit]] = [:]
        cache["test"] = firstResults
        
        let cachedLookupTime = bestDuration {
            let _ = cache["test"]
        }
        
        #expect(cachedLookupTime < .milliseconds(5),
                "Cached lookup took \(cachedLookupTime)")
    }
    
    // MARK: - Concurrent Search Performance
    
    @Test("Concurrent search query handling")
    func concurrentSearchQueries() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let queries = ["Node", "Test", "Graph", "Search", "Query", "Result", "Data", "Info"]
        
        let totalTime = bestDuration {
            // Simulate concurrent searches
            for query in queries {
                Task {
                    let _ = store.fuzzySearch(query: query, limit: 20)
                }
            }
        }
        
        #expect(totalTime < .milliseconds(25),
                "Concurrent search dispatch took \(totalTime)")
    }
    
    // MARK: - Prefix Search Performance
    
    @Test("Prefix search performance")
    func prefixSearchPerformance() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 1000)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let prefixes = ["N", "No", "Nod", "Node", "Test", "T", "Te", "Tes"]
        
        for prefix in prefixes {
            let searchTime = bestDuration {
                let _ = store.fuzzySearch(query: prefix, limit: 20)
            }
            
            #expect(searchTime < .milliseconds(100),
                    "Prefix search '\(prefix)' took \(searchTime)")
        }
    }
    
    // MARK: - Search Scoring Performance
    
    @Test("Search scoring algorithm performance")
    func searchScoringPerformance() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 500)
        store.loadDirect(nodes: nodes, edges: edges)
        
        var scoringTime: Duration = .zero
        
        measure {
            let start = ContinuousClock().now
            
            // Search multiple terms to exercise scoring
            let terms = ["a", "e", "i", "o", "u"]
            for term in terms {
                let results = store.fuzzySearch(query: term, limit: 50)
                
                // Verify scores are in descending order
                var prevScore: Float = 2.0
                for hit in results {
                    #expect(hit.score <= prevScore, "Results not properly sorted by score")
                    prevScore = hit.score
                }
            }
            
            scoringTime = ContinuousClock().now - start
        }
        
        #expect(scoringTime < .milliseconds(100),
                "Scoring took \(scoringTime)")
    }
    
    // MARK: - Edge Case Search Performance
    
    @Test("Empty query handling")
    func emptyQueryHandling() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 100)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let emptyQueryTime = bestDuration {
            let results = store.fuzzySearch(query: "", limit: 20)
            
            #expect(results.isEmpty, "Empty query should return empty results")
        }
        
        #expect(emptyQueryTime < .milliseconds(10),
                "Empty query handling took \(emptyQueryTime)")
    }
    
    @Test("Long query handling")
    func longQueryHandling() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 500)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let longQuery = String(repeating: "search ", count: 50)
        
        let longQueryTime = bestDuration {
            let _ = store.fuzzySearch(query: longQuery, limit: 20)
        }
        
        #expect(longQueryTime < .milliseconds(25),
                "Long query took \(longQueryTime)")
    }
    
    @Test("Special character query handling")
    func specialCharacterQueryHandling() async throws {
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 100)
        store.loadDirect(nodes: nodes, edges: edges)
        
        let specialQueries = ["@test", "#node", "$data", "%info", "^graph", "&search"]
        
        for query in specialQueries {
            let queryTime = bestDuration {
                let _ = store.fuzzySearch(query: query, limit: 20)
            }
            
            #expect(queryTime < .milliseconds(10),
                    "Special query '\(query)' took \(queryTime)")
        }
    }
}

@Suite("MiniChat Search Performance")
@MainActor
struct MiniChatSearchPerformanceTests {
    final class BodyProbe {
        private(set) var loadCount = 0
        private let body: String

        init(body: String) {
            self.body = body
        }

        func load() -> String {
            loadCount += 1
            return body
        }

        func reset() {
            loadCount = 0
        }
    }

    private func legacyVaultSearch(
        query: String,
        activeId: String?,
        pages: [MiniChatSearchCandidate]
    ) -> [(title: String, snippet: String)] {
        let terms = query.lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 }

        guard !terms.isEmpty else { return [] }

        var matches = pages.filter { candidate in
            guard candidate.id != activeId else { return false }
            let title = candidate.title.lowercased()
            return terms.contains { title.contains($0) }
        }

        if matches.count < 3 {
            let titleIds = Set(matches.map(\.id))
            let bodyMatches = pages.prefix(30).filter { candidate in
                guard candidate.id != activeId, !titleIds.contains(candidate.id) else { return false }
                let body = candidate.snapshot().lowercasedBody
                return terms.contains { body.contains($0) }
            }
            matches.append(contentsOf: bodyMatches)
        }

        return Array(matches.prefix(3).map { candidate in
            let snapshot = candidate.snapshot()
            return (title: candidate.title, snippet: snapshot.shortSnippet)
        })
    }

    @Test("MiniChatNoteSnapshot loads body once and reuses snippets")
    func noteSnapshotLoadsBodyOnce() {
        let body = String(repeating: "abc", count: 1000)
        let probe = BodyProbe(body: body)

        let snapshot = MiniChatNoteSnapshot(title: "Active", tags: ["swift"]) {
            probe.load()
        }

        #expect(probe.loadCount == 1)
        #expect(snapshot.hasBody)
        #expect(snapshot.shortSnippet == String(body.prefix(300)))
        #expect(snapshot.promptSnippet == String(body.prefix(2000)))
    }

    @Test("MiniChat vault search caches body loads for final snippets")
    func vaultSearchCachesBodyLoads() {
        let active = BodyProbe(body: "active page should be skipped")
        let titleMatch = BodyProbe(body: "title match body")
        let bodyMatchA = BodyProbe(body: "Deep research notes about graph loading and sync reconciliation")
        let bodyMatchB = BodyProbe(body: "These focus areas cover editor smoothness and graph metadata")
        let bodyMiss = BodyProbe(body: "completely unrelated")

        let pages = [
            MiniChatSearchCandidate(id: "active", title: "Active Note", bodyProvider: active.load),
            MiniChatSearchCandidate(id: "title", title: "Deep Work Summary", bodyProvider: titleMatch.load),
            MiniChatSearchCandidate(id: "body-a", title: "Graph Notes", bodyProvider: bodyMatchA.load),
            MiniChatSearchCandidate(id: "body-b", title: "Editor Notes", bodyProvider: bodyMatchB.load),
            MiniChatSearchCandidate(id: "miss", title: "Random", bodyProvider: bodyMiss.load),
        ]

        let legacy = legacyVaultSearch(query: "deep focus", activeId: "active", pages: pages)
        let legacyLoads = [active, titleMatch, bodyMatchA, bodyMatchB, bodyMiss]
            .map(\.loadCount)
            .reduce(0, +)

        for probe in [active, titleMatch, bodyMatchA, bodyMatchB, bodyMiss] {
            probe.reset()
        }

        let optimized = MiniChatVaultSearch.snippets(query: "deep focus", activeId: "active", pages: pages)
        let optimizedLoads = [active, titleMatch, bodyMatchA, bodyMatchB, bodyMiss]
            .map(\.loadCount)
            .reduce(0, +)

        #expect(optimized.count == legacy.count)
        #expect(optimized.map(\.title) == legacy.map(\.title))
        #expect(optimized.map(\.snippet) == legacy.map(\.snippet))
        #expect(legacyLoads == 6)
        #expect(optimizedLoads == 4)
        #expect(bodyMatchA.loadCount == 1)
        #expect(bodyMatchB.loadCount == 1)
    }

    @Test("MiniChat vault search reuses eager snapshots without touching body providers")
    func vaultSearchUsesEagerSnapshotsWithoutReloadingBodies() {
        let titleMatch = BodyProbe(body: "title match body")
        let bodyMatch = BodyProbe(body: "Deep research notes about graph loading and sync reconciliation")
        let miss = BodyProbe(body: "completely unrelated")

        let pages = [
            MiniChatSearchCandidate(
                id: "title",
                title: "Deep Work Summary",
                snapshot: MiniChatNoteSnapshot(title: "Deep Work Summary", bodyProvider: titleMatch.load)
            ),
            MiniChatSearchCandidate(
                id: "body",
                title: "Graph Notes",
                snapshot: MiniChatNoteSnapshot(title: "Graph Notes", bodyProvider: bodyMatch.load)
            ),
            MiniChatSearchCandidate(
                id: "miss",
                title: "Random",
                snapshot: MiniChatNoteSnapshot(title: "Random", bodyProvider: miss.load)
            ),
        ]

        for probe in [titleMatch, bodyMatch, miss] {
            probe.reset()
        }

        let matches = MiniChatVaultSearch.snippets(
            query: "deep focus",
            activeId: nil,
            pages: pages
        )

        let loads = [titleMatch, bodyMatch, miss].map(\.loadCount).reduce(0, +)

        #expect(matches.map(\.title) == ["Deep Work Summary", "Graph Notes"])
        #expect(loads == 0)
    }
}
