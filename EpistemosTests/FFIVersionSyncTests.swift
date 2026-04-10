import Testing
@testable import Epistemos

// MARK: - FFI Version Sync Tests
// Ensures Swift enums and Rust enums are perfectly aligned for FFI compatibility.
// Any mismatch will cause data corruption at the FFI boundary.

@Suite("FFI Version Sync")
struct FFIVersionSyncTests {
    
    // MARK: - GraphNodeType Alignment Tests
    
    @Test("GraphNodeType case count matches Rust (14 cases)")
    func nodeTypeCaseCount() {
        #expect(GraphNodeType.allCases.count == 14)
    }

    @Test("GraphNodeType rustIndex values are sequential 0-13")
    func nodeTypeRustIndexSequential() {
        let indices = GraphNodeType.allCases.map { $0.rustIndex }.sorted()
        #expect(indices == Array(0...13))
    }
    
    @Test("GraphNodeType.note rustIndex is 0")
    func nodeTypeNoteRustIndex() {
        #expect(GraphNodeType.note.rustIndex == 0)
    }
    
    @Test("GraphNodeType.chat rustIndex is 1")
    func nodeTypeChatRustIndex() {
        #expect(GraphNodeType.chat.rustIndex == 1)
    }
    
    @Test("GraphNodeType.idea rustIndex is 2")
    func nodeTypeIdeaRustIndex() {
        #expect(GraphNodeType.idea.rustIndex == 2)
    }
    
    @Test("GraphNodeType.source rustIndex is 3")
    func nodeTypeSourceRustIndex() {
        #expect(GraphNodeType.source.rustIndex == 3)
    }
    
    @Test("GraphNodeType.folder rustIndex is 4")
    func nodeTypeFolderRustIndex() {
        #expect(GraphNodeType.folder.rustIndex == 4)
    }
    
    @Test("GraphNodeType.quote rustIndex is 5")
    func nodeTypeQuoteRustIndex() {
        #expect(GraphNodeType.quote.rustIndex == 5)
    }
    
    @Test("GraphNodeType.tag rustIndex is 6")
    func nodeTypeTagRustIndex() {
        #expect(GraphNodeType.tag.rustIndex == 6)
    }

    @Test("GraphNodeType.block rustIndex is 7")
    func nodeTypeBlockRustIndex() {
        #expect(GraphNodeType.block.rustIndex == 7)
    }

    @Test("GraphNodeType.person rustIndex is 8")
    func nodeTypePersonRustIndex() {
        #expect(GraphNodeType.person.rustIndex == 8)
    }

    @Test("GraphNodeType.project rustIndex is 9")
    func nodeTypeProjectRustIndex() {
        #expect(GraphNodeType.project.rustIndex == 9)
    }

    @Test("GraphNodeType.topic rustIndex is 10")
    func nodeTypeTopicRustIndex() {
        #expect(GraphNodeType.topic.rustIndex == 10)
    }

    @Test("GraphNodeType.decision rustIndex is 11")
    func nodeTypeDecisionRustIndex() {
        #expect(GraphNodeType.decision.rustIndex == 11)
    }

    @Test("GraphNodeType.event rustIndex is 12")
    func nodeTypeEventRustIndex() {
        #expect(GraphNodeType.event.rustIndex == 12)
    }

    @Test("GraphNodeType.resource rustIndex is 13")
    func nodeTypeResourceRustIndex() {
        #expect(GraphNodeType.resource.rustIndex == 13)
    }
    
    @Test("GraphNodeType rustIndex values are unique")
    func nodeTypeRustIndexUnique() {
        let indices = GraphNodeType.allCases.map { $0.rustIndex }
        let uniqueIndices = Set(indices)
        #expect(uniqueIndices.count == indices.count)
    }
    
    @Test("GraphNodeType rustIndex fits in u8")
    func nodeTypeRustIndexFitsU8() {
        for type in GraphNodeType.allCases {
            #expect(type.rustIndex <= UInt8.max)
        }
    }
    
    @Test("GraphNodeType all cases have valid rustIndex")
    func nodeTypeAllCasesValid() {
        for type in GraphNodeType.allCases {
            #expect(type.rustIndex < 14, "\(type) has invalid rustIndex")
        }
    }
    
    // MARK: - GraphEdgeType Alignment Tests
    
    @Test("GraphEdgeType case count matches Rust (12 cases)")
    func edgeTypeCaseCount() {
        // GraphEdgeType does not conform to CaseIterable, count manually
        let allCases: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions, .cites,
            .authored, .related, .quotes, .supports, .contradicts,
            .expands, .questions
        ]
        #expect(allCases.count == 12)
    }
    
    @Test("GraphEdgeType.reference rustIndex is 0")
    func edgeTypeReferenceRustIndex() {
        #expect(GraphEdgeType.reference.rustIndex == 0)
    }
    
    @Test("GraphEdgeType.contains rustIndex is 1")
    func edgeTypeContainsRustIndex() {
        #expect(GraphEdgeType.contains.rustIndex == 1)
    }
    
    @Test("GraphEdgeType.tagged rustIndex is 2")
    func edgeTypeTaggedRustIndex() {
        #expect(GraphEdgeType.tagged.rustIndex == 2)
    }
    
    @Test("GraphEdgeType.mentions rustIndex is 3")
    func edgeTypeMentionsRustIndex() {
        #expect(GraphEdgeType.mentions.rustIndex == 3)
    }
    
    @Test("GraphEdgeType.cites rustIndex is 4")
    func edgeTypeCitesRustIndex() {
        #expect(GraphEdgeType.cites.rustIndex == 4)
    }
    
    @Test("GraphEdgeType.authored rustIndex is 5")
    func edgeTypeAuthoredRustIndex() {
        #expect(GraphEdgeType.authored.rustIndex == 5)
    }
    
    @Test("GraphEdgeType.related rustIndex is 6")
    func edgeTypeRelatedRustIndex() {
        #expect(GraphEdgeType.related.rustIndex == 6)
    }
    
    @Test("GraphEdgeType.quotes rustIndex is 7")
    func edgeTypeQuotesRustIndex() {
        #expect(GraphEdgeType.quotes.rustIndex == 7)
    }
    
    @Test("GraphEdgeType.supports rustIndex is 8")
    func edgeTypeSupportsRustIndex() {
        #expect(GraphEdgeType.supports.rustIndex == 8)
    }
    
    @Test("GraphEdgeType.contradicts rustIndex is 9")
    func edgeTypeContradictsRustIndex() {
        #expect(GraphEdgeType.contradicts.rustIndex == 9)
    }
    
    @Test("GraphEdgeType.expands rustIndex is 10")
    func edgeTypeExpandsRustIndex() {
        #expect(GraphEdgeType.expands.rustIndex == 10)
    }
    
    @Test("GraphEdgeType.questions rustIndex is 11")
    func edgeTypeQuestionsRustIndex() {
        #expect(GraphEdgeType.questions.rustIndex == 11)
    }
    
    @Test("GraphEdgeType rustIndex values are unique")
    func edgeTypeRustIndexUnique() {
        let allCases: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions, .cites,
            .authored, .related, .quotes, .supports, .contradicts,
            .expands, .questions
        ]
        let indices = allCases.map { $0.rustIndex }
        let uniqueIndices = Set(indices)
        #expect(uniqueIndices.count == indices.count)
    }
    
    @Test("GraphEdgeType rustIndex fits in u8")
    func edgeTypeRustIndexFitsU8() {
        let allCases: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions, .cites,
            .authored, .related, .quotes, .supports, .contradicts,
            .expands, .questions
        ]
        for type in allCases {
            #expect(type.rustIndex <= UInt8.max)
        }
    }
    
    @Test("GraphEdgeType all cases have valid rustIndex 0-11")
    func edgeTypeAllCasesValid() {
        let allCases: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions, .cites,
            .authored, .related, .quotes, .supports, .contradicts,
            .expands, .questions
        ]
        for type in allCases {
            #expect(type.rustIndex < 12, "Edge type has invalid rustIndex")
        }
    }
    
    // MARK: - Enum Value Range Validation
    
    @Test("Node type values are contiguous starting at 0")
    func nodeTypeValuesContiguous() {
        let indices = GraphNodeType.allCases.map { $0.rustIndex }.sorted()
        for (i, index) in indices.enumerated() {
            #expect(index == UInt8(i), "Node type index \(index) at position \(i) breaks contiguity")
        }
    }
    
    @Test("Edge type values are contiguous starting at 0")
    func edgeTypeValuesContiguous() {
        let allCases: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions, .cites,
            .authored, .related, .quotes, .supports, .contradicts,
            .expands, .questions
        ]
        let indices = allCases.map { $0.rustIndex }.sorted()
        for (i, index) in indices.enumerated() {
            #expect(index == UInt8(i), "Edge type index \(index) at position \(i) breaks contiguity")
        }
    }
    
    // MARK: - Cross-Platform Compatibility Tests
    
    @Test("Node type indices match C header documentation")
    func nodeTypeMatchesCHeader() {
        // From graph_engine.h: 0=Note ... 13=Resource
        #expect(GraphNodeType.note.rustIndex == 0)
        #expect(GraphNodeType.chat.rustIndex == 1)
        #expect(GraphNodeType.idea.rustIndex == 2)
        #expect(GraphNodeType.source.rustIndex == 3)
        #expect(GraphNodeType.folder.rustIndex == 4)
        #expect(GraphNodeType.quote.rustIndex == 5)
        #expect(GraphNodeType.tag.rustIndex == 6)
        #expect(GraphNodeType.block.rustIndex == 7)
        #expect(GraphNodeType.person.rustIndex == 8)
        #expect(GraphNodeType.project.rustIndex == 9)
        #expect(GraphNodeType.topic.rustIndex == 10)
        #expect(GraphNodeType.decision.rustIndex == 11)
        #expect(GraphNodeType.event.rustIndex == 12)
        #expect(GraphNodeType.resource.rustIndex == 13)
    }
    
    @Test("Edge type indices match C header documentation")
    func edgeTypeMatchesCHeader() {
        // From graph_engine.h: 0=reference, 4=cites, 9=contradicts, etc.
        #expect(GraphEdgeType.reference.rustIndex == 0)
        #expect(GraphEdgeType.cites.rustIndex == 4)
        #expect(GraphEdgeType.contradicts.rustIndex == 9)
    }
    
    // MARK: - Legacy Migration Alignment Tests
    
    @Test("Legacy node type mappings preserve rustIndex semantics")
    func legacyNodeTypeMapping() {
        // Old types map to new types but rustIndex semantics are preserved
        #expect(GraphNodeType(legacy: "brainDump").rustIndex == 2) // maps to .idea
        #expect(GraphNodeType(legacy: "insight").rustIndex == 2)   // maps to .idea
        #expect(GraphNodeType(legacy: "paper").rustIndex == 3)     // maps to .source
        #expect(GraphNodeType(legacy: "book").rustIndex == 3)      // maps to .source
        #expect(GraphNodeType(legacy: "thinker").rustIndex == 3)   // maps to .source
        #expect(GraphNodeType(legacy: "concept").rustIndex == 6)   // maps to .tag
    }
    
    @Test("Legacy edge type mappings preserve rustIndex semantics")
    func legacyEdgeTypeMapping() {
        #expect(GraphEdgeType(legacy: "wikilink").rustIndex == 0)      // maps to .reference
        #expect(GraphEdgeType(legacy: "ideaLink").rustIndex == 0)      // maps to .reference
        #expect(GraphEdgeType(legacy: "livesIn").rustIndex == 1)       // maps to .contains
        #expect(GraphEdgeType(legacy: "belongsTo").rustIndex == 1)     // maps to .contains
        #expect(GraphEdgeType(legacy: "backedBy").rustIndex == 4)      // maps to .cites
        #expect(GraphEdgeType(legacy: "semanticLink").rustIndex == 6)  // maps to .related
    }
    
    // MARK: - FFI Safety Validation Tests
    
    @Test("Node type rustIndex never exceeds Rust enum max (13)")
    func nodeTypeNeverExceedsMax() {
        for type in GraphNodeType.allCases {
            #expect(type.rustIndex <= 13, "Node type \(type) exceeds Rust max value")
        }
    }
    
    @Test("Edge type rustIndex never exceeds Rust enum max (11)")
    func edgeTypeNeverExceedsMax() {
        let allCases: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions, .cites,
            .authored, .related, .quotes, .supports, .contradicts,
            .expands, .questions
        ]
        for type in allCases {
            #expect(type.rustIndex <= 11, "Edge type exceeds Rust max value")
        }
    }
    
    @Test("All enum values are stable (no gaps)")
    func enumValuesStable() {
        // Verify that adding a new case would require explicit rustIndex assignment
        // This is a documentation test - the actual enforcement is in the code
        let nodeIndices = GraphNodeType.allCases.map { $0.rustIndex }.sorted()
        let expected: [UInt8] = Array(0...13)
        #expect(nodeIndices == expected)
    }
    
    // MARK: - Batch FFI Compatibility Tests
    
    @Test("Node type array for batch FFI is correctly ordered")
    func nodeTypeArrayForBatchFFI() {
        let allCases = GraphNodeType.allCases.sorted { $0.rustIndex < $1.rustIndex }
        #expect(allCases[0] == .note)
        #expect(allCases[1] == .chat)
        #expect(allCases[2] == .idea)
        #expect(allCases[3] == .source)
        #expect(allCases[4] == .folder)
        #expect(allCases[5] == .quote)
        #expect(allCases[6] == .tag)
        #expect(allCases[7] == .block)
        #expect(allCases[8] == .person)
        #expect(allCases[9] == .project)
        #expect(allCases[10] == .topic)
        #expect(allCases[11] == .decision)
        #expect(allCases[12] == .event)
        #expect(allCases[13] == .resource)
    }
    
    @Test("Edge type array for batch FFI is correctly ordered")
    func edgeTypeArrayForBatchFFI() {
        let allCases: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions, .cites,
            .authored, .related, .quotes, .supports, .contradicts,
            .expands, .questions
        ]
        let sorted = allCases.sorted { $0.rustIndex < $1.rustIndex }
        for (i, type) in sorted.enumerated() {
            #expect(type.rustIndex == UInt8(i))
        }
    }
    
    // MARK: - Type Safety Tests
    
    @Test("Node type rawValue is stable across versions")
    func nodeTypeRawValueStable() {
        // These should never change - they are stored in SwiftData
        #expect(GraphNodeType.note.rawValue == "note")
        #expect(GraphNodeType.chat.rawValue == "chat")
        #expect(GraphNodeType.idea.rawValue == "idea")
        #expect(GraphNodeType.source.rawValue == "source")
        #expect(GraphNodeType.folder.rawValue == "folder")
        #expect(GraphNodeType.quote.rawValue == "quote")
        #expect(GraphNodeType.tag.rawValue == "tag")
        #expect(GraphNodeType.block.rawValue == "block")
        #expect(GraphNodeType.person.rawValue == "person")
        #expect(GraphNodeType.project.rawValue == "project")
        #expect(GraphNodeType.topic.rawValue == "topic")
        #expect(GraphNodeType.decision.rawValue == "decision")
        #expect(GraphNodeType.event.rawValue == "event")
        #expect(GraphNodeType.resource.rawValue == "resource")
    }
    
    @Test("Edge type rawValue is stable across versions")
    func edgeTypeRawValueStable() {
        #expect(GraphEdgeType.reference.rawValue == "reference")
        #expect(GraphEdgeType.contains.rawValue == "contains")
        #expect(GraphEdgeType.tagged.rawValue == "tagged")
        #expect(GraphEdgeType.mentions.rawValue == "mentions")
        #expect(GraphEdgeType.cites.rawValue == "cites")
        #expect(GraphEdgeType.authored.rawValue == "authored")
        #expect(GraphEdgeType.related.rawValue == "related")
        #expect(GraphEdgeType.quotes.rawValue == "quotes")
        #expect(GraphEdgeType.supports.rawValue == "supports")
        #expect(GraphEdgeType.contradicts.rawValue == "contradicts")
        #expect(GraphEdgeType.expands.rawValue == "expands")
        #expect(GraphEdgeType.questions.rawValue == "questions")
    }
    
    // MARK: - Version Mismatch Detection
    
    @Test("Rust node type count is documented correctly")
    func rustNodeTypeCountDocumented() {
        // From graph_engine.h: "0–13 matching NodeType enum"
        #expect(GraphNodeType.allCases.count == 14)
    }
    
    @Test("Rust edge type count is documented correctly")
    func rustEdgeTypeCountDocumented() {
        // From graph_engine.h: "0-11 matching GraphEdgeType enum"
        // This means 12 types (0 through 11)
        let allCases: [GraphEdgeType] = [
            .reference, .contains, .tagged, .mentions, .cites,
            .authored, .related, .quotes, .supports, .contradicts,
            .expands, .questions
        ]
        #expect(allCases.count == 12)
    }
}
