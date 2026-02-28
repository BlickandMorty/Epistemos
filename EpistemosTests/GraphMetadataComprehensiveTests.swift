import Foundation
import Testing
@testable import Epistemos

// MARK: - GraphNodeMetadata Tests

@Suite("GraphNodeMetadata - Initialization")
struct GraphNodeMetadataInitializationTests {
    
    @Test("Can create empty metadata")
    func createEmptyMetadata() {
        let meta = GraphNodeMetadata()
        #expect(meta.evidenceGrade == nil)
        #expect(meta.researchStage == nil)
        #expect(meta.url == nil)
        #expect(meta.authors == nil)
        #expect(meta.quoteText == nil)
        #expect(meta.year == nil)
        #expect(meta.journal == nil)
        #expect(meta.doi == nil)
        #expect(meta.abstract == nil)
        #expect(meta.clusterTheme == nil)
        #expect(meta.originChatId == nil)
        #expect(meta.originNoteId == nil)
    }
    
    @Test("Can create metadata with all fields")
    func createFullMetadata() {
        let meta = GraphNodeMetadata(
            evidenceGrade: "Strong",
            researchStage: 3,
            url: "https://example.com",
            authors: ["Alice", "Bob"],
            quoteText: "Important quote",
            year: 2024,
            journal: "Nature",
            doi: "10.1234/example",
            abstract: "This is an abstract",
            clusterTheme: "AI Research",
            originChatId: "chat-123",
            originNoteId: "note-456"
        )
        
        #expect(meta.evidenceGrade == "Strong")
        #expect(meta.researchStage == 3)
        #expect(meta.url == "https://example.com")
        #expect(meta.authors == ["Alice", "Bob"])
        #expect(meta.quoteText == "Important quote")
        #expect(meta.year == 2024)
        #expect(meta.journal == "Nature")
        #expect(meta.doi == "10.1234/example")
        #expect(meta.abstract == "This is an abstract")
        #expect(meta.clusterTheme == "AI Research")
        #expect(meta.originChatId == "chat-123")
        #expect(meta.originNoteId == "note-456")
    }
    
    @Test("Can create metadata with partial fields")
    func createPartialMetadata() {
        let meta = GraphNodeMetadata(
            evidenceGrade: "Moderate",
            url: "https://test.com",
            year: 2023
        )
        
        #expect(meta.evidenceGrade == "Moderate")
        #expect(meta.url == "https://test.com")
        #expect(meta.year == 2023)
        #expect(meta.researchStage == nil)
        #expect(meta.authors == nil)
    }
}

@Suite("GraphNodeMetadata - JSON Encoding")
struct GraphNodeMetadataEncodingTests {
    
    @Test("Empty metadata encodes to empty object")
    func encodeEmptyMetadata() throws {
        let meta = GraphNodeMetadata()
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "{}" || json.contains("{}"))
    }
    
    @Test("Metadata with evidenceGrade encodes correctly")
    func encodeEvidenceGrade() throws {
        let meta = GraphNodeMetadata(evidenceGrade: "High")
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"evidenceGrade\":\"High\""))
    }
    
    @Test("Metadata with researchStage encodes correctly")
    func encodeResearchStage() throws {
        let meta = GraphNodeMetadata(researchStage: 2)
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"researchStage\":2"))
    }
    
    @Test("Metadata with url encodes correctly")
    func encodeURL() throws {
        let meta = GraphNodeMetadata(url: "https://arxiv.org")
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("arxiv.org"))
    }
    
    @Test("Metadata with authors encodes correctly")
    func encodeAuthors() throws {
        let meta = GraphNodeMetadata(authors: ["Smith", "Jones"])
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"authors\""))
        #expect(json.contains("Smith"))
        #expect(json.contains("Jones"))
    }
    
    @Test("Metadata with quoteText encodes correctly")
    func encodeQuoteText() throws {
        let meta = GraphNodeMetadata(quoteText: "To be or not to be")
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"quoteText\""))
    }
    
    @Test("Metadata with year encodes correctly")
    func encodeYear() throws {
        let meta = GraphNodeMetadata(year: 2024)
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"year\":2024"))
    }
    
    @Test("Metadata with journal encodes correctly")
    func encodeJournal() throws {
        let meta = GraphNodeMetadata(journal: "Science")
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"journal\":\"Science\""))
    }
    
    @Test("Metadata with doi encodes correctly")
    func encodeDOI() throws {
        let meta = GraphNodeMetadata(doi: "10.1000/test")
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"doi\""))
    }
    
    @Test("Metadata with abstract encodes correctly")
    func encodeAbstract() throws {
        let meta = GraphNodeMetadata(abstract: "This is the abstract")
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"abstract\""))
    }
    
    @Test("Metadata with clusterTheme encodes correctly")
    func encodeClusterTheme() throws {
        let meta = GraphNodeMetadata(clusterTheme: "ML")
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"clusterTheme\":\"ML\""))
    }
    
    @Test("Metadata with originChatId encodes correctly")
    func encodeOriginChatId() throws {
        let meta = GraphNodeMetadata(originChatId: "chat-uuid")
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"originChatId\""))
    }
    
    @Test("Metadata with originNoteId encodes correctly")
    func encodeOriginNoteId() throws {
        let meta = GraphNodeMetadata(originNoteId: "note-uuid")
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"originNoteId\""))
    }
}

@Suite("GraphNodeMetadata - JSON Decoding")
struct GraphNodeMetadataDecodingTests {
    
    @Test("Can decode empty JSON object")
    func decodeEmptyJSON() throws {
        let json = "{}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.evidenceGrade == nil)
        #expect(meta.researchStage == nil)
    }
    
    @Test("Can decode JSON with evidenceGrade")
    func decodeEvidenceGrade() throws {
        let json = "{\"evidenceGrade\":\"Strong\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.evidenceGrade == "Strong")
    }
    
    @Test("Can decode JSON with researchStage")
    func decodeResearchStage() throws {
        let json = "{\"researchStage\":3}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.researchStage == 3)
    }
    
    @Test("Can decode JSON with url")
    func decodeURL() throws {
        let json = "{\"url\":\"https://test.com\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.url == "https://test.com")
    }
    
    @Test("Can decode JSON with authors array")
    func decodeAuthors() throws {
        let json = "{\"authors\":[\"Alice\",\"Bob\",\"Charlie\"]}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.authors == ["Alice", "Bob", "Charlie"])
    }
    
    @Test("Can decode JSON with quoteText")
    func decodeQuoteText() throws {
        let json = "{\"quoteText\":\"Test quote\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.quoteText == "Test quote")
    }
    
    @Test("Can decode JSON with year")
    func decodeYear() throws {
        let json = "{\"year\":2024}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.year == 2024)
    }
    
    @Test("Can decode JSON with journal")
    func decodeJournal() throws {
        let json = "{\"journal\":\"Nature\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.journal == "Nature")
    }
    
    @Test("Can decode JSON with doi")
    func decodeDOI() throws {
        let json = "{\"doi\":\"10.1234/test\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.doi == "10.1234/test")
    }
    
    @Test("Can decode JSON with abstract")
    func decodeAbstract() throws {
        let json = "{\"abstract\":\"This is abstract\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.abstract == "This is abstract")
    }
    
    @Test("Can decode JSON with clusterTheme")
    func decodeClusterTheme() throws {
        let json = "{\"clusterTheme\":\"Theme1\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.clusterTheme == "Theme1")
    }
    
    @Test("Can decode JSON with originChatId")
    func decodeOriginChatId() throws {
        let json = "{\"originChatId\":\"chat-123\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.originChatId == "chat-123")
    }
    
    @Test("Can decode JSON with originNoteId")
    func decodeOriginNoteId() throws {
        let json = "{\"originNoteId\":\"note-456\"}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        #expect(meta.originNoteId == "note-456")
    }
    
    @Test("Can decode JSON with all fields")
    func decodeFullJSON() throws {
        let json = """
        {
            "evidenceGrade": "High",
            "researchStage": 5,
            "url": "https://example.com",
            "authors": ["Author1", "Author2"],
            "quoteText": "Quote",
            "year": 2024,
            "journal": "Journal",
            "doi": "10.1234/doi",
            "abstract": "Abstract text",
            "clusterTheme": "Theme",
            "originChatId": "chat-id",
            "originNoteId": "note-id"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let meta = try decoder.decode(GraphNodeMetadata.self, from: json)
        
        #expect(meta.evidenceGrade == "High")
        #expect(meta.researchStage == 5)
        #expect(meta.url == "https://example.com")
        #expect(meta.authors == ["Author1", "Author2"])
        #expect(meta.quoteText == "Quote")
        #expect(meta.year == 2024)
        #expect(meta.journal == "Journal")
        #expect(meta.doi == "10.1234/doi")
        #expect(meta.abstract == "Abstract text")
        #expect(meta.clusterTheme == "Theme")
        #expect(meta.originChatId == "chat-id")
        #expect(meta.originNoteId == "note-id")
    }
}

@Suite("GraphNodeMetadata - Round-Trip")
struct GraphNodeMetadataRoundTripTests {
    
    @Test("Empty metadata round-trips correctly")
    func roundTripEmpty() throws {
        let original = GraphNodeMetadata()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded == original)
    }
    
    @Test("Full metadata round-trips correctly")
    func roundTripFull() throws {
        let original = GraphNodeMetadata(
            evidenceGrade: "Strong",
            researchStage: 3,
            url: "https://example.com",
            authors: ["Alice", "Bob"],
            quoteText: "Quote",
            year: 2024,
            journal: "Nature",
            doi: "10.1234/doi",
            abstract: "Abstract",
            clusterTheme: "Theme",
            originChatId: "chat-123",
            originNoteId: "note-456"
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded == original)
        #expect(decoded.evidenceGrade == original.evidenceGrade)
        #expect(decoded.researchStage == original.researchStage)
        #expect(decoded.url == original.url)
        #expect(decoded.authors == original.authors)
        #expect(decoded.quoteText == original.quoteText)
        #expect(decoded.year == original.year)
        #expect(decoded.journal == original.journal)
        #expect(decoded.doi == original.doi)
        #expect(decoded.abstract == original.abstract)
        #expect(decoded.clusterTheme == original.clusterTheme)
        #expect(decoded.originChatId == original.originChatId)
        #expect(decoded.originNoteId == original.originNoteId)
    }
    
    @Test("Partial metadata round-trips correctly")
    func roundTripPartial() throws {
        let original = GraphNodeMetadata(
            evidenceGrade: "Moderate",
            authors: ["Single Author"],
            year: 2023
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded == original)
        #expect(decoded.evidenceGrade == "Moderate")
        #expect(decoded.year == 2023)
        #expect(decoded.authors == ["Single Author"])
        #expect(decoded.researchStage == nil)
        #expect(decoded.url == nil)
    }
}

@Suite("GraphNodeMetadata - Unicode Support")
struct GraphNodeMetadataUnicodeTests {
    
    @Test("Can handle Unicode in evidenceGrade")
    func unicodeEvidenceGrade() throws {
        let meta = GraphNodeMetadata(evidenceGrade: "強い")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded.evidenceGrade == "強い")
    }
    
    @Test("Can handle Unicode in quoteText")
    func unicodeQuoteText() throws {
        let meta = GraphNodeMetadata(quoteText: "これは引用です 🎉")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded.quoteText == "これは引用です 🎉")
    }
    
    @Test("Can handle Unicode in authors")
    func unicodeAuthors() throws {
        let meta = GraphNodeMetadata(authors: ["田中", "山田", "佐藤 👤"])
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded.authors == ["田中", "山田", "佐藤 👤"])
    }
    
    @Test("Can handle Unicode in abstract")
    func unicodeAbstract() throws {
        let meta = GraphNodeMetadata(abstract: "Résumé: α + β = γ 🧬")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded.abstract == "Résumé: α + β = γ 🧬")
    }
    
    @Test("Can handle special characters in doi")
    func specialCharactersDOI() throws {
        let meta = GraphNodeMetadata(doi: "10.1000/abc-def_ghi")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded.doi == "10.1000/abc-def_ghi")
    }
    
    @Test("Can handle emoji in clusterTheme")
    func emojiClusterTheme() throws {
        let meta = GraphNodeMetadata(clusterTheme: "AI 🤖 Research")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded.clusterTheme == "AI 🤖 Research")
    }
}

@Suite("GraphNodeMetadata - Large Data")
struct GraphNodeMetadataLargeDataTests {
    
    @Test("Can handle large authors array")
    func largeAuthorsArray() throws {
        let manyAuthors = (1...100).map { "Author \($0)" }
        let meta = GraphNodeMetadata(authors: manyAuthors)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded.authors?.count == 100)
        #expect(decoded.authors?.first == "Author 1")
        #expect(decoded.authors?.last == "Author 100")
    }
    
    @Test("Can handle very long abstract")
    func veryLongAbstract() throws {
        let longAbstract = String(repeating: "Lorem ipsum dolor sit amet. ", count: 1000)
        let meta = GraphNodeMetadata(abstract: longAbstract)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded.abstract?.count == longAbstract.count)
        #expect(decoded.abstract == longAbstract)
    }
    
    @Test("Can handle long URL")
    func longURL() throws {
        let longURL = "https://example.com/" + String(repeating: "path/", count: 50) + "final"
        let meta = GraphNodeMetadata(url: longURL)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded.url == longURL)
    }
    
    @Test("Can handle empty authors array")
    func emptyAuthorsArray() throws {
        let meta = GraphNodeMetadata(authors: [])
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(GraphNodeMetadata.self, from: data)
        
        #expect(decoded.authors == [])
    }
}

@Suite("GraphNodeMetadata - Equatable")
struct GraphNodeMetadataEquatableTests {
    
    @Test("Two empty metadata are equal")
    func emptyMetadataEqual() {
        let meta1 = GraphNodeMetadata()
        let meta2 = GraphNodeMetadata()
        #expect(meta1 == meta2)
    }
    
    @Test("Two identical metadata are equal")
    func identicalMetadataEqual() {
        let meta1 = GraphNodeMetadata(evidenceGrade: "High", year: 2024)
        let meta2 = GraphNodeMetadata(evidenceGrade: "High", year: 2024)
        #expect(meta1 == meta2)
    }
    
    @Test("Metadata with different values are not equal")
    func differentMetadataNotEqual() {
        let meta1 = GraphNodeMetadata(evidenceGrade: "High")
        let meta2 = GraphNodeMetadata(evidenceGrade: "Low")
        #expect(meta1 != meta2)
    }
    
    @Test("Metadata with nil vs value are not equal")
    func nilVsValueNotEqual() {
        let meta1 = GraphNodeMetadata()
        let meta2 = GraphNodeMetadata(evidenceGrade: "High")
        #expect(meta1 != meta2)
    }
    
    @Test("Metadata order of authors matters for equality")
    func authorsOrderMatters() {
        let meta1 = GraphNodeMetadata(authors: ["Alice", "Bob"])
        let meta2 = GraphNodeMetadata(authors: ["Bob", "Alice"])
        #expect(meta1 != meta2)
    }
}

@Suite("GraphNodeMetadata - Sendable Conformance")
struct GraphNodeMetadataSendableTests {
    
    @Test("GraphNodeMetadata can be used in concurrent context")
    func sendableConformance() async {
        let meta = GraphNodeMetadata(
            evidenceGrade: "Strong",
            authors: ["Alice", "Bob"]
        )
        
        await withTaskGroup(of: GraphNodeMetadata.self) { group in
            group.addTask { meta }
            group.addTask { meta }
            
            var results: [GraphNodeMetadata] = []
            for await result in group {
                results.append(result)
            }
            #expect(results.count == 2)
            #expect(results.allSatisfy { $0 == meta })
        }
    }
}
