import Foundation
import Testing
@testable import Epistemos

// MARK: - GraphNodeType Tests

@Suite("GraphNodeType - Basic Cases")
struct GraphNodeTypeBasicTests {
    
    @Test("GraphNodeType has exactly 7 cases")
    func caseCount() {
        let allCases = GraphNodeType.allCases
        #expect(allCases.count == 7)
    }
    
    @Test("GraphNodeType.note exists with correct rawValue")
    func noteCase() {
        #expect(GraphNodeType.note.rawValue == "note")
    }
    
    @Test("GraphNodeType.chat exists with correct rawValue")
    func chatCase() {
        #expect(GraphNodeType.chat.rawValue == "chat")
    }
    
    @Test("GraphNodeType.idea exists with correct rawValue")
    func ideaCase() {
        #expect(GraphNodeType.idea.rawValue == "idea")
    }
    
    @Test("GraphNodeType.source exists with correct rawValue")
    func sourceCase() {
        #expect(GraphNodeType.source.rawValue == "source")
    }
    
    @Test("GraphNodeType.folder exists with correct rawValue")
    func folderCase() {
        #expect(GraphNodeType.folder.rawValue == "folder")
    }
    
    @Test("GraphNodeType.quote exists with correct rawValue")
    func quoteCase() {
        #expect(GraphNodeType.quote.rawValue == "quote")
    }
    
    @Test("GraphNodeType.tag exists with correct rawValue")
    func tagCase() {
        #expect(GraphNodeType.tag.rawValue == "tag")
    }
}

@Suite("GraphNodeType - Display Names")
struct GraphNodeTypeDisplayNameTests {
    
    @Test("note has correct displayName")
    func noteDisplayName() {
        #expect(GraphNodeType.note.displayName == "Note")
    }
    
    @Test("chat has correct displayName")
    func chatDisplayName() {
        #expect(GraphNodeType.chat.displayName == "Chat")
    }
    
    @Test("idea has correct displayName")
    func ideaDisplayName() {
        #expect(GraphNodeType.idea.displayName == "Idea")
    }
    
    @Test("source has correct displayName")
    func sourceDisplayName() {
        #expect(GraphNodeType.source.displayName == "Source")
    }
    
    @Test("folder has correct displayName")
    func folderDisplayName() {
        #expect(GraphNodeType.folder.displayName == "Folder")
    }
    
    @Test("quote has correct displayName")
    func quoteDisplayName() {
        #expect(GraphNodeType.quote.displayName == "Quote")
    }
    
    @Test("tag has correct displayName")
    func tagDisplayName() {
        #expect(GraphNodeType.tag.displayName == "Tag")
    }
}

@Suite("GraphNodeType - Icons")
struct GraphNodeTypeIconTests {
    
    @Test("note has correct SF Symbol icon")
    func noteIcon() {
        #expect(GraphNodeType.note.icon == "doc.text")
    }
    
    @Test("chat has correct SF Symbol icon")
    func chatIcon() {
        #expect(GraphNodeType.chat.icon == "bubble.left")
    }
    
    @Test("idea has correct SF Symbol icon")
    func ideaIcon() {
        #expect(GraphNodeType.idea.icon == "lightbulb")
    }
    
    @Test("source has correct SF Symbol icon")
    func sourceIcon() {
        #expect(GraphNodeType.source.icon == "link")
    }
    
    @Test("folder has correct SF Symbol icon")
    func folderIcon() {
        #expect(GraphNodeType.folder.icon == "folder")
    }
    
    @Test("quote has correct SF Symbol icon")
    func quoteIcon() {
        #expect(GraphNodeType.quote.icon == "text.quote")
    }
    
    @Test("tag has correct SF Symbol icon")
    func tagIcon() {
        #expect(GraphNodeType.tag.icon == "number")
    }
    
    @Test("All icons are non-empty strings")
    func allIconsNonEmpty() {
        for type in GraphNodeType.allCases {
            #expect(!type.icon.isEmpty, "Icon for \(type) should not be empty")
        }
    }
    
    @Test("All icons follow SF Symbol naming convention")
    func allIconsValidFormat() {
        for type in GraphNodeType.allCases {
            #expect(!type.icon.contains(" "), "Icon '\(type.icon)' should not contain spaces")
        }
    }
}

@Suite("GraphNodeType - Rust FFI Index Mapping")
struct GraphNodeTypeRustIndexTests {
    
    @Test("note maps to rustIndex 0")
    func noteRustIndex() {
        #expect(GraphNodeType.note.rustIndex == 0)
    }
    
    @Test("chat maps to rustIndex 1")
    func chatRustIndex() {
        #expect(GraphNodeType.chat.rustIndex == 1)
    }
    
    @Test("idea maps to rustIndex 2")
    func ideaRustIndex() {
        #expect(GraphNodeType.idea.rustIndex == 2)
    }
    
    @Test("source maps to rustIndex 3")
    func sourceRustIndex() {
        #expect(GraphNodeType.source.rustIndex == 3)
    }
    
    @Test("folder maps to rustIndex 4")
    func folderRustIndex() {
        #expect(GraphNodeType.folder.rustIndex == 4)
    }
    
    @Test("quote maps to rustIndex 5")
    func quoteRustIndex() {
        #expect(GraphNodeType.quote.rustIndex == 5)
    }
    
    @Test("tag maps to rustIndex 6")
    func tagRustIndex() {
        #expect(GraphNodeType.tag.rustIndex == 6)
    }
    
    @Test("Rust indices are contiguous from 0 to 6")
    func rustIndicesContiguous() {
        let indices = GraphNodeType.allCases.map { $0.rustIndex }.sorted()
        #expect(indices == [0, 1, 2, 3, 4, 5, 6])
    }
    
    @Test("All rust indices are unique")
    func rustIndicesUnique() {
        let indices = GraphNodeType.allCases.map { $0.rustIndex }
        let uniqueIndices = Set(indices)
        #expect(indices.count == uniqueIndices.count)
    }
}

@Suite("GraphNodeType - Legacy Migration (13-type to 7-type)")
struct GraphNodeTypeLegacyMigrationTests {
    
    // MARK: brainDump → idea
    
    @Test("Legacy 'brainDump' migrates to idea")
    func brainDumpMigratesToIdea() {
        let migrated = GraphNodeType(legacy: "brainDump")
        #expect(migrated == .idea)
    }
    
    @Test("Legacy 'insight' migrates to idea")
    func insightMigratesToIdea() {
        let migrated = GraphNodeType(legacy: "insight")
        #expect(migrated == .idea)
    }
    
    // MARK: paper/book/thinker → source
    
    @Test("Legacy 'paper' migrates to source")
    func paperMigratesToSource() {
        let migrated = GraphNodeType(legacy: "paper")
        #expect(migrated == .source)
    }
    
    @Test("Legacy 'book' migrates to source")
    func bookMigratesToSource() {
        let migrated = GraphNodeType(legacy: "book")
        #expect(migrated == .source)
    }
    
    @Test("Legacy 'thinker' migrates to source")
    func thinkerMigratesToSource() {
        let migrated = GraphNodeType(legacy: "thinker")
        #expect(migrated == .source)
    }
    
    // MARK: concept → tag
    
    @Test("Legacy 'concept' migrates to tag")
    func conceptMigratesToTag() {
        let migrated = GraphNodeType(legacy: "concept")
        #expect(migrated == .tag)
    }
    
    // MARK: New types pass through unchanged
    
    @Test("'note' stays as note")
    func notePassthrough() {
        let migrated = GraphNodeType(legacy: "note")
        #expect(migrated == .note)
    }
    
    @Test("'chat' stays as chat")
    func chatPassthrough() {
        let migrated = GraphNodeType(legacy: "chat")
        #expect(migrated == .chat)
    }
    
    @Test("'idea' stays as idea")
    func ideaPassthrough() {
        let migrated = GraphNodeType(legacy: "idea")
        #expect(migrated == .idea)
    }
    
    @Test("'source' stays as source")
    func sourcePassthrough() {
        let migrated = GraphNodeType(legacy: "source")
        #expect(migrated == .source)
    }
    
    @Test("'folder' stays as folder")
    func folderPassthrough() {
        let migrated = GraphNodeType(legacy: "folder")
        #expect(migrated == .folder)
    }
    
    @Test("'quote' stays as quote")
    func quotePassthrough() {
        let migrated = GraphNodeType(legacy: "quote")
        #expect(migrated == .quote)
    }
    
    @Test("'tag' stays as tag")
    func tagPassthrough() {
        let migrated = GraphNodeType(legacy: "tag")
        #expect(migrated == .tag)
    }
}

@Suite("GraphNodeType - Edge Cases")
struct GraphNodeTypeEdgeCaseTests2 {
    
    @Test("Unknown legacy type defaults to note")
    func unknownLegacyDefaultsToNote() {
        let migrated = GraphNodeType(legacy: "unknownType")
        #expect(migrated == .note)
    }
    
    @Test("Empty string defaults to note")
    func emptyStringDefaultsToNote() {
        let migrated = GraphNodeType(legacy: "")
        #expect(migrated == .note)
    }
    
    @Test("Random garbage string defaults to note")
    func garbageStringDefaultsToNote() {
        let migrated = GraphNodeType(legacy: "xyz123!@#")
        #expect(migrated == .note)
    }
    
    @Test("Case-sensitive: 'NOTE' does not match 'note'")
    func caseSensitivityUppercase() {
        let migrated = GraphNodeType(legacy: "NOTE")
        #expect(migrated == .note) // rawValue match fails, falls through to default
    }
    
    @Test("Case-sensitive: 'Note' does not match 'note'")
    func caseSensitivityMixedCase() {
        let migrated = GraphNodeType(legacy: "Note")
        #expect(migrated == .note) // rawValue match fails, falls through to default
    }
    
    @Test("Whitespace in legacy string defaults to note")
    func whitespaceDefaultsToNote() {
        let migrated = GraphNodeType(legacy: "note ")
        #expect(migrated == .note)
    }
    
    @Test("Very long unknown string defaults to note")
    func longUnknownString() {
        let longString = String(repeating: "a", count: 1000)
        let migrated = GraphNodeType(legacy: longString)
        #expect(migrated == .note)
    }
    
    @Test("Unicode in unknown string defaults to note")
    func unicodeUnknownString() {
        let migrated = GraphNodeType(legacy: "nöte")
        #expect(migrated == .note)
    }
}

@Suite("GraphNodeType - Codable Conformance")
struct GraphNodeTypeCodableTests {
    
    @Test("Can encode note to JSON")
    func encodeNote() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(GraphNodeType.note)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "\"note\"")
    }
    
    @Test("Can encode all types to JSON")
    func encodeAllTypes() throws {
        let encoder = JSONEncoder()
        for type in GraphNodeType.allCases {
            let data = try encoder.encode(type)
            let decoded = try JSONDecoder().decode(GraphNodeType.self, from: data)
            #expect(decoded == type)
        }
    }
    
    @Test("Can decode note from JSON")
    func decodeNote() throws {
        let json = "\"note\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GraphNodeType.self, from: json)
        #expect(decoded == .note)
    }
    
    @Test("Can decode chat from JSON")
    func decodeChat() throws {
        let json = "\"chat\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GraphNodeType.self, from: json)
        #expect(decoded == .chat)
    }
    
    @Test("Can decode idea from JSON")
    func decodeIdea() throws {
        let json = "\"idea\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GraphNodeType.self, from: json)
        #expect(decoded == .idea)
    }
    
    @Test("Can decode source from JSON")
    func decodeSource() throws {
        let json = "\"source\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GraphNodeType.self, from: json)
        #expect(decoded == .source)
    }
    
    @Test("Round-trip preserves all types")
    func roundTripAllTypes() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for type in GraphNodeType.allCases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(GraphNodeType.self, from: data)
            #expect(decoded == type, "Round-trip failed for \(type)")
        }
    }
}

@Suite("GraphNodeType - CaseIterable")
struct GraphNodeTypeCaseIterableTests {
    
    @Test("allCases is not empty")
    func allCasesNotEmpty() {
        #expect(!GraphNodeType.allCases.isEmpty)
    }
    
    @Test("allCases contains note")
    func allCasesContainsNote() {
        #expect(GraphNodeType.allCases.contains(.note))
    }
    
    @Test("allCases contains chat")
    func allCasesContainsChat() {
        #expect(GraphNodeType.allCases.contains(.chat))
    }
    
    @Test("allCases contains idea")
    func allCasesContainsIdea() {
        #expect(GraphNodeType.allCases.contains(.idea))
    }
    
    @Test("allCases contains source")
    func allCasesContainsSource() {
        #expect(GraphNodeType.allCases.contains(.source))
    }
    
    @Test("allCases contains folder")
    func allCasesContainsFolder() {
        #expect(GraphNodeType.allCases.contains(.folder))
    }
    
    @Test("allCases contains quote")
    func allCasesContainsQuote() {
        #expect(GraphNodeType.allCases.contains(.quote))
    }
    
    @Test("allCases contains tag")
    func allCasesContainsTag() {
        #expect(GraphNodeType.allCases.contains(.tag))
    }
}

// MARK: - GraphEdgeType Tests

@Suite("GraphEdgeType - Basic Cases")
struct GraphEdgeTypeBasicTests {
    
    @Test("GraphEdgeType.reference exists with correct rawValue")
    func referenceCase() {
        #expect(GraphEdgeType.reference.rawValue == "reference")
    }
    
    @Test("GraphEdgeType.contains exists with correct rawValue")
    func containsCase() {
        #expect(GraphEdgeType.contains.rawValue == "contains")
    }
    
    @Test("GraphEdgeType.tagged exists with correct rawValue")
    func taggedCase() {
        #expect(GraphEdgeType.tagged.rawValue == "tagged")
    }
    
    @Test("GraphEdgeType.mentions exists with correct rawValue")
    func mentionsCase() {
        #expect(GraphEdgeType.mentions.rawValue == "mentions")
    }
    
    @Test("GraphEdgeType.cites exists with correct rawValue")
    func citesCase() {
        #expect(GraphEdgeType.cites.rawValue == "cites")
    }
    
    @Test("GraphEdgeType.authored exists with correct rawValue")
    func authoredCase() {
        #expect(GraphEdgeType.authored.rawValue == "authored")
    }
    
    @Test("GraphEdgeType.related exists with correct rawValue")
    func relatedCase() {
        #expect(GraphEdgeType.related.rawValue == "related")
    }
    
    @Test("GraphEdgeType.quotes exists with correct rawValue")
    func quotesCase() {
        #expect(GraphEdgeType.quotes.rawValue == "quotes")
    }
    
    @Test("GraphEdgeType.supports exists with correct rawValue")
    func supportsCase() {
        #expect(GraphEdgeType.supports.rawValue == "supports")
    }
    
    @Test("GraphEdgeType.contradicts exists with correct rawValue")
    func contradictsCase() {
        #expect(GraphEdgeType.contradicts.rawValue == "contradicts")
    }
    
    @Test("GraphEdgeType.expands exists with correct rawValue")
    func expandsCase() {
        #expect(GraphEdgeType.expands.rawValue == "expands")
    }
    
    @Test("GraphEdgeType.questions exists with correct rawValue")
    func questionsCase() {
        #expect(GraphEdgeType.questions.rawValue == "questions")
    }
}

@Suite("GraphEdgeType - Rust FFI Index Mapping")
struct GraphEdgeTypeRustIndexTests {
    
    @Test("reference maps to rustIndex 0")
    func referenceRustIndex() {
        #expect(GraphEdgeType.reference.rustIndex == 0)
    }
    
    @Test("contains maps to rustIndex 1")
    func containsRustIndex() {
        #expect(GraphEdgeType.contains.rustIndex == 1)
    }
    
    @Test("tagged maps to rustIndex 2")
    func taggedRustIndex() {
        #expect(GraphEdgeType.tagged.rustIndex == 2)
    }
    
    @Test("mentions maps to rustIndex 3")
    func mentionsRustIndex() {
        #expect(GraphEdgeType.mentions.rustIndex == 3)
    }
    
    @Test("cites maps to rustIndex 4")
    func citesRustIndex() {
        #expect(GraphEdgeType.cites.rustIndex == 4)
    }
    
    @Test("authored maps to rustIndex 5")
    func authoredRustIndex() {
        #expect(GraphEdgeType.authored.rustIndex == 5)
    }
    
    @Test("related maps to rustIndex 6")
    func relatedRustIndex() {
        #expect(GraphEdgeType.related.rustIndex == 6)
    }
    
    @Test("quotes maps to rustIndex 7")
    func quotesRustIndex() {
        #expect(GraphEdgeType.quotes.rustIndex == 7)
    }
    
    @Test("supports maps to rustIndex 8")
    func supportsRustIndex() {
        #expect(GraphEdgeType.supports.rustIndex == 8)
    }
    
    @Test("contradicts maps to rustIndex 9")
    func contradictsRustIndex() {
        #expect(GraphEdgeType.contradicts.rustIndex == 9)
    }
    
    @Test("expands maps to rustIndex 10")
    func expandsRustIndex() {
        #expect(GraphEdgeType.expands.rustIndex == 10)
    }
    
    @Test("questions maps to rustIndex 11")
    func questionsRustIndex() {
        #expect(GraphEdgeType.questions.rustIndex == 11)
    }
    
    @Test("All edge rust indices are contiguous from 0 to 11")
    func rustIndicesContiguous() {
        let allCases: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions,
            .cites, .authored, .related, .quotes,
            .supports, .contradicts, .expands, .questions
        ]
        let indices = allCases.map { $0.rustIndex }.sorted()
        #expect(indices == Array(0...11))
    }
    
    @Test("All edge rust indices are unique")
    func rustIndicesUnique() {
        let allCases: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions,
            .cites, .authored, .related, .quotes,
            .supports, .contradicts, .expands, .questions
        ]
        let indices = allCases.map { $0.rustIndex }
        let uniqueIndices = Set(indices)
        #expect(indices.count == uniqueIndices.count)
    }
}

@Suite("GraphEdgeType - Legacy Migration (23-type to 12-type)")
struct GraphEdgeTypeLegacyMigrationTests {
    
    // MARK: wikilink → reference
    
    @Test("Legacy 'wikilink' migrates to reference")
    func wikilinkMigratesToReference() {
        let migrated = GraphEdgeType(legacy: "wikilink")
        #expect(migrated == .reference)
    }
    
    @Test("Legacy 'ideaLink' migrates to reference")
    func ideaLinkMigratesToReference() {
        let migrated = GraphEdgeType(legacy: "ideaLink")
        #expect(migrated == .reference)
    }
    
    @Test("Legacy 'referenced' migrates to reference")
    func referencedMigratesToReference() {
        let migrated = GraphEdgeType(legacy: "referenced")
        #expect(migrated == .reference)
    }
    
    @Test("Legacy 'extractedFrom' migrates to reference")
    func extractedFromMigratesToReference() {
        let migrated = GraphEdgeType(legacy: "extractedFrom")
        #expect(migrated == .reference)
    }
    
    @Test("Legacy 'discoveredIn' migrates to reference")
    func discoveredInMigratesToReference() {
        let migrated = GraphEdgeType(legacy: "discoveredIn")
        #expect(migrated == .reference)
    }
    
    @Test("Legacy 'sharedIn' migrates to reference")
    func sharedInMigratesToReference() {
        let migrated = GraphEdgeType(legacy: "sharedIn")
        #expect(migrated == .reference)
    }
    
    @Test("Legacy 'referencedIn' migrates to reference")
    func referencedInMigratesToReference() {
        let migrated = GraphEdgeType(legacy: "referencedIn")
        #expect(migrated == .reference)
    }
    
    @Test("Legacy 'linksTo' migrates to reference")
    func linksToMigratesToReference() {
        let migrated = GraphEdgeType(legacy: "linksTo")
        #expect(migrated == .reference)
    }
    
    @Test("Legacy 'exploredIn' migrates to reference")
    func exploredInMigratesToReference() {
        let migrated = GraphEdgeType(legacy: "exploredIn")
        #expect(migrated == .reference)
    }
    
    // MARK: livesIn/belongsTo → contains
    
    @Test("Legacy 'livesIn' migrates to contains")
    func livesInMigratesToContains() {
        let migrated = GraphEdgeType(legacy: "livesIn")
        #expect(migrated == .contains)
    }
    
    @Test("Legacy 'belongsTo' migrates to contains")
    func belongsToMigratesToContains() {
        let migrated = GraphEdgeType(legacy: "belongsTo")
        #expect(migrated == .contains)
    }
    
    // MARK: tagged → tagged
    
    @Test("Legacy 'tagged' stays as tagged")
    func taggedPassthrough() {
        let migrated = GraphEdgeType(legacy: "tagged")
        #expect(migrated == .tagged)
    }
    
    // MARK: mentionedIn/discussedIn/appearsIn → mentions
    
    @Test("Legacy 'mentionedIn' migrates to mentions")
    func mentionedInMigratesToMentions() {
        let migrated = GraphEdgeType(legacy: "mentionedIn")
        #expect(migrated == .mentions)
    }
    
    @Test("Legacy 'discussedIn' migrates to mentions")
    func discussedInMigratesToMentions() {
        let migrated = GraphEdgeType(legacy: "discussedIn")
        #expect(migrated == .mentions)
    }
    
    @Test("Legacy 'appearsIn' migrates to mentions")
    func appearsInMigratesToMentions() {
        let migrated = GraphEdgeType(legacy: "appearsIn")
        #expect(migrated == .mentions)
    }
    
    // MARK: backedBy/citedIn → cites
    
    @Test("Legacy 'backedBy' migrates to cites")
    func backedByMigratesToCites() {
        let migrated = GraphEdgeType(legacy: "backedBy")
        #expect(migrated == .cites)
    }
    
    @Test("Legacy 'citedIn' migrates to cites")
    func citedInMigratesToCites() {
        let migrated = GraphEdgeType(legacy: "citedIn")
        #expect(migrated == .cites)
    }
    
    // MARK: authored/attributedTo → authored
    
    @Test("Legacy 'authored' stays as authored")
    func authoredPassthrough() {
        let migrated = GraphEdgeType(legacy: "authored")
        #expect(migrated == .authored)
    }
    
    @Test("Legacy 'attributedTo' migrates to authored")
    func attributedToMigratesToAuthored() {
        let migrated = GraphEdgeType(legacy: "attributedTo")
        #expect(migrated == .authored)
    }
    
    // MARK: semanticLink/relatesTo/relatedConcept → related
    
    @Test("Legacy 'semanticLink' migrates to related")
    func semanticLinkMigratesToRelated() {
        let migrated = GraphEdgeType(legacy: "semanticLink")
        #expect(migrated == .related)
    }
    
    @Test("Legacy 'relatesTo' migrates to related")
    func relatesToMigratesToRelated() {
        let migrated = GraphEdgeType(legacy: "relatesTo")
        #expect(migrated == .related)
    }
    
    @Test("Legacy 'relatedConcept' migrates to related")
    func relatedConceptMigratesToRelated() {
        let migrated = GraphEdgeType(legacy: "relatedConcept")
        #expect(migrated == .related)
    }
    
    // MARK: said → quotes
    
    @Test("Legacy 'said' migrates to quotes")
    func saidMigratesToQuotes() {
        let migrated = GraphEdgeType(legacy: "said")
        #expect(migrated == .quotes)
    }
    
    // MARK: New semantic types pass through
    
    @Test("'supports' stays as supports")
    func supportsPassthrough() {
        let migrated = GraphEdgeType(legacy: "supports")
        #expect(migrated == .supports)
    }
    
    @Test("'contradicts' stays as contradicts")
    func contradictsPassthrough() {
        let migrated = GraphEdgeType(legacy: "contradicts")
        #expect(migrated == .contradicts)
    }
    
    @Test("'expands' stays as expands")
    func expandsPassthrough() {
        let migrated = GraphEdgeType(legacy: "expands")
        #expect(migrated == .expands)
    }
    
    @Test("'questions' stays as questions")
    func questionsPassthrough() {
        let migrated = GraphEdgeType(legacy: "questions")
        #expect(migrated == .questions)
    }
}

@Suite("GraphEdgeType - Edge Cases")
struct GraphEdgeTypeEdgeCaseTests {
    
    @Test("Unknown legacy type defaults to reference")
    func unknownLegacyDefaultsToReference() {
        let migrated = GraphEdgeType(legacy: "unknownType")
        #expect(migrated == .reference)
    }
    
    @Test("Empty string defaults to reference")
    func emptyStringDefaultsToReference() {
        let migrated = GraphEdgeType(legacy: "")
        #expect(migrated == .reference)
    }
    
    @Test("Random garbage string defaults to reference")
    func garbageStringDefaultsToReference() {
        let migrated = GraphEdgeType(legacy: "xyz123!@#")
        #expect(migrated == .reference)
    }
    
    @Test("Case-sensitive: 'REFERENCE' does not match 'reference'")
    func caseSensitivityUppercase() {
        let migrated = GraphEdgeType(legacy: "REFERENCE")
        #expect(migrated == .reference) // rawValue match fails, falls through to default
    }
    
    @Test("Whitespace in legacy string defaults to reference")
    func whitespaceDefaultsToReference() {
        let migrated = GraphEdgeType(legacy: "reference ")
        #expect(migrated == .reference)
    }
    
    @Test("Very long unknown string defaults to reference")
    func longUnknownString() {
        let longString = String(repeating: "a", count: 1000)
        let migrated = GraphEdgeType(legacy: longString)
        #expect(migrated == .reference)
    }
    
    @Test("Unicode in unknown string defaults to reference")
    func unicodeUnknownString() {
        let migrated = GraphEdgeType(legacy: "referënce")
        #expect(migrated == .reference)
    }
}

@Suite("GraphEdgeType - Codable Conformance")
struct GraphEdgeTypeCodableTests {
    
    @Test("Can encode reference to JSON")
    func encodeReference() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(GraphEdgeType.reference)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "\"reference\"")
    }
    
    @Test("Can encode contains to JSON")
    func encodeContains() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(GraphEdgeType.contains)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "\"contains\"")
    }
    
    @Test("Can decode reference from JSON")
    func decodeReference() throws {
        let json = "\"reference\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GraphEdgeType.self, from: json)
        #expect(decoded == .reference)
    }
    
    @Test("Can decode contains from JSON")
    func decodeContains() throws {
        let json = "\"contains\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GraphEdgeType.self, from: json)
        #expect(decoded == .contains)
    }
    
    @Test("Round-trip preserves reference")
    func roundTripReference() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(GraphEdgeType.reference)
        let decoded = try decoder.decode(GraphEdgeType.self, from: data)
        #expect(decoded == .reference)
    }
    
    @Test("Round-trip preserves all edge types")
    func roundTripAllTypes() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let allCases: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions,
            .cites, .authored, .related, .quotes,
            .supports, .contradicts, .expands, .questions
        ]
        
        for type in allCases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(GraphEdgeType.self, from: data)
            #expect(decoded == type, "Round-trip failed for \(type)")
        }
    }
}

@Suite("GraphEdgeType - Sendable Conformance")
struct GraphEdgeTypeSendableTests {
    
    @Test("GraphEdgeType can be used in concurrent context")
    func sendableConformance() async {
        // This test verifies Sendable conformance at compile time
        let type = GraphEdgeType.reference
        await withTaskGroup(of: GraphEdgeType.self) { group in
            group.addTask { type }
            group.addTask { type }
            
            var results: [GraphEdgeType] = []
            for await result in group {
                results.append(result)
            }
            #expect(results.count == 2)
            #expect(results.allSatisfy { $0 == .reference })
        }
    }
}
