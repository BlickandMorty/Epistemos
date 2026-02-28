import Foundation
import Testing
@testable import Epistemos

// MARK: - SDGraphEdge Tests

@Suite("SDGraphEdge - Initialization")
struct SDGraphEdgeInitializationTests {
    
    @Test("Can initialize with minimum required parameters")
    func initWithMinimumParams() {
        let edge = SDGraphEdge(
            source: "node-a",
            target: "node-b",
            type: .reference
        )
        
        #expect(edge.sourceNodeId == "node-a")
        #expect(edge.targetNodeId == "node-b")
        #expect(edge.type == "reference")
        #expect(edge.weight == 1.0)
    }
    
    @Test("Can initialize with all parameters")
    func initWithAllParams() {
        let edge = SDGraphEdge(
            source: "source-node",
            target: "target-node",
            type: .cites,
            weight: 2.5
        )
        
        #expect(edge.sourceNodeId == "source-node")
        #expect(edge.targetNodeId == "target-node")
        #expect(edge.type == "cites")
        #expect(edge.weight == 2.5)
    }
    
    @Test("Can initialize with different edge types")
    func initWithDifferentTypes() {
        let reference = SDGraphEdge(source: "a", target: "b", type: .reference)
        let contains = SDGraphEdge(source: "a", target: "b", type: .contains)
        let tagged = SDGraphEdge(source: "a", target: "b", type: .tagged)
        let mentions = SDGraphEdge(source: "a", target: "b", type: .mentions)
        let cites = SDGraphEdge(source: "a", target: "b", type: .cites)
        let authored = SDGraphEdge(source: "a", target: "b", type: .authored)
        let related = SDGraphEdge(source: "a", target: "b", type: .related)
        let quotes = SDGraphEdge(source: "a", target: "b", type: .quotes)
        let supports = SDGraphEdge(source: "a", target: "b", type: .supports)
        let contradicts = SDGraphEdge(source: "a", target: "b", type: .contradicts)
        let expands = SDGraphEdge(source: "a", target: "b", type: .expands)
        let questions = SDGraphEdge(source: "a", target: "b", type: .questions)
        
        #expect(reference.type == "reference")
        #expect(contains.type == "contains")
        #expect(tagged.type == "tagged")
        #expect(mentions.type == "mentions")
        #expect(cites.type == "cites")
        #expect(authored.type == "authored")
        #expect(related.type == "related")
        #expect(quotes.type == "quotes")
        #expect(supports.type == "supports")
        #expect(contradicts.type == "contradicts")
        #expect(expands.type == "expands")
        #expect(questions.type == "questions")
    }
    
    @Test("Initialization generates unique IDs")
    func uniqueIDsGenerated() {
        let edge1 = SDGraphEdge(source: "a", target: "b", type: .reference)
        let edge2 = SDGraphEdge(source: "a", target: "b", type: .reference)
        
        #expect(edge1.id != edge2.id)
        #expect(!edge1.id.isEmpty)
        #expect(!edge2.id.isEmpty)
    }
    
    @Test("ID is valid UUID format")
    func idIsValidUUID() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(UUID(uuidString: edge.id) != nil)
    }
}

@Suite("SDGraphEdge - Default Values")
struct SDGraphEdgeDefaultValueTests {
    
    @Test("Default type is 'reference'")
    func defaultType() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(edge.type == "reference")
    }
    
    @Test("Default weight is 1.0")
    func defaultWeight() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(edge.weight == 1.0)
    }
    
    @Test("Default isManual is false")
    func defaultIsManual() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(edge.isManual == false)
    }
    
    @Test("createdAt is set to current time on init")
    func createdAtIsSet() {
        let before = Date.now
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        let after = Date.now
        
        #expect(edge.createdAt >= before)
        #expect(edge.createdAt <= after)
    }
}

@Suite("SDGraphEdge - edgeType Computed Property")
struct SDGraphEdgeEdgeTypeTests {
    
    @Test("edgeType returns correct type for new types")
    func edgeTypeForNewTypes() {
        let reference = SDGraphEdge(source: "a", target: "b", type: .reference)
        let contains = SDGraphEdge(source: "a", target: "b", type: .contains)
        let tagged = SDGraphEdge(source: "a", target: "b", type: .tagged)
        let mentions = SDGraphEdge(source: "a", target: "b", type: .mentions)
        let cites = SDGraphEdge(source: "a", target: "b", type: .cites)
        let authored = SDGraphEdge(source: "a", target: "b", type: .authored)
        let related = SDGraphEdge(source: "a", target: "b", type: .related)
        let quotes = SDGraphEdge(source: "a", target: "b", type: .quotes)
        let supports = SDGraphEdge(source: "a", target: "b", type: .supports)
        let contradicts = SDGraphEdge(source: "a", target: "b", type: .contradicts)
        let expands = SDGraphEdge(source: "a", target: "b", type: .expands)
        let questions = SDGraphEdge(source: "a", target: "b", type: .questions)
        
        #expect(reference.edgeType == .reference)
        #expect(contains.edgeType == .contains)
        #expect(tagged.edgeType == .tagged)
        #expect(mentions.edgeType == .mentions)
        #expect(cites.edgeType == .cites)
        #expect(authored.edgeType == .authored)
        #expect(related.edgeType == .related)
        #expect(quotes.edgeType == .quotes)
        #expect(supports.edgeType == .supports)
        #expect(contradicts.edgeType == .contradicts)
        #expect(expands.edgeType == .expands)
        #expect(questions.edgeType == .questions)
    }
    
    @Test("edgeType handles legacy 'wikilink' migration")
    func edgeTypeLegacyWikilink() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "wikilink"
        #expect(edge.edgeType == .reference)
    }
    
    @Test("edgeType handles legacy 'ideaLink' migration")
    func edgeTypeLegacyIdeaLink() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "ideaLink"
        #expect(edge.edgeType == .reference)
    }
    
    @Test("edgeType handles legacy 'referenced' migration")
    func edgeTypeLegacyReferenced() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "referenced"
        #expect(edge.edgeType == .reference)
    }
    
    @Test("edgeType handles legacy 'extractedFrom' migration")
    func edgeTypeLegacyExtractedFrom() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "extractedFrom"
        #expect(edge.edgeType == .reference)
    }
    
    @Test("edgeType handles legacy 'discoveredIn' migration")
    func edgeTypeLegacyDiscoveredIn() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "discoveredIn"
        #expect(edge.edgeType == .reference)
    }
    
    @Test("edgeType handles legacy 'sharedIn' migration")
    func edgeTypeLegacySharedIn() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "sharedIn"
        #expect(edge.edgeType == .reference)
    }
    
    @Test("edgeType handles legacy 'referencedIn' migration")
    func edgeTypeLegacyReferencedIn() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "referencedIn"
        #expect(edge.edgeType == .reference)
    }
    
    @Test("edgeType handles legacy 'linksTo' migration")
    func edgeTypeLegacyLinksTo() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "linksTo"
        #expect(edge.edgeType == .reference)
    }
    
    @Test("edgeType handles legacy 'exploredIn' migration")
    func edgeTypeLegacyExploredIn() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "exploredIn"
        #expect(edge.edgeType == .reference)
    }
    
    @Test("edgeType handles legacy 'livesIn' migration")
    func edgeTypeLegacyLivesIn() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "livesIn"
        #expect(edge.edgeType == .contains)
    }
    
    @Test("edgeType handles legacy 'belongsTo' migration")
    func edgeTypeLegacyBelongsTo() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "belongsTo"
        #expect(edge.edgeType == .contains)
    }
    
    @Test("edgeType handles legacy 'mentionedIn' migration")
    func edgeTypeLegacyMentionedIn() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "mentionedIn"
        #expect(edge.edgeType == .mentions)
    }
    
    @Test("edgeType handles legacy 'discussedIn' migration")
    func edgeTypeLegacyDiscussedIn() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "discussedIn"
        #expect(edge.edgeType == .mentions)
    }
    
    @Test("edgeType handles legacy 'appearsIn' migration")
    func edgeTypeLegacyAppearsIn() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "appearsIn"
        #expect(edge.edgeType == .mentions)
    }
    
    @Test("edgeType handles legacy 'backedBy' migration")
    func edgeTypeLegacyBackedBy() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "backedBy"
        #expect(edge.edgeType == .cites)
    }
    
    @Test("edgeType handles legacy 'citedIn' migration")
    func edgeTypeLegacyCitedIn() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "citedIn"
        #expect(edge.edgeType == .cites)
    }
    
    @Test("edgeType handles legacy 'attributedTo' migration")
    func edgeTypeLegacyAttributedTo() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "attributedTo"
        #expect(edge.edgeType == .authored)
    }
    
    @Test("edgeType handles legacy 'semanticLink' migration")
    func edgeTypeLegacySemanticLink() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "semanticLink"
        #expect(edge.edgeType == .related)
    }
    
    @Test("edgeType handles legacy 'relatesTo' migration")
    func edgeTypeLegacyRelatesTo() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "relatesTo"
        #expect(edge.edgeType == .related)
    }
    
    @Test("edgeType handles legacy 'relatedConcept' migration")
    func edgeTypeLegacyRelatedConcept() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "relatedConcept"
        #expect(edge.edgeType == .related)
    }
    
    @Test("edgeType handles legacy 'said' migration")
    func edgeTypeLegacySaid() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "said"
        #expect(edge.edgeType == .quotes)
    }
    
    @Test("edgeType defaults to reference for unknown types")
    func edgeTypeUnknownDefaultsToReference() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "unknownType"
        #expect(edge.edgeType == .reference)
    }
}

@Suite("SDGraphEdge - Source/Target Node Relationships")
struct SDGraphEdgeNodeRelationshipTests {
    
    @Test("sourceNodeId can be any string ID")
    func sourceNodeIdString() {
        let edge = SDGraphEdge(
            source: "node-uuid-123",
            target: "node-uuid-456",
            type: .reference
        )
        #expect(edge.sourceNodeId == "node-uuid-123")
    }
    
    @Test("targetNodeId can be any string ID")
    func targetNodeIdString() {
        let edge = SDGraphEdge(
            source: "node-a",
            target: "node-b",
            type: .reference
        )
        #expect(edge.targetNodeId == "node-b")
    }
    
    @Test("sourceNodeId can be modified after creation")
    func sourceNodeIdMutable() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(edge.sourceNodeId == "a")
        
        edge.sourceNodeId = "new-source"
        #expect(edge.sourceNodeId == "new-source")
    }
    
    @Test("targetNodeId can be modified after creation")
    func targetNodeIdMutable() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(edge.targetNodeId == "b")
        
        edge.targetNodeId = "new-target"
        #expect(edge.targetNodeId == "new-target")
    }
    
    @Test("Edge direction matters")
    func edgeDirectionMatters() {
        let edge1 = SDGraphEdge(source: "a", target: "b", type: .reference)
        let edge2 = SDGraphEdge(source: "b", target: "a", type: .reference)
        
        #expect(edge1.sourceNodeId == edge2.targetNodeId)
        #expect(edge1.targetNodeId == edge2.sourceNodeId)
    }
    
    @Test("Self-loops are possible")
    func selfLoopPossible() {
        let edge = SDGraphEdge(source: "self", target: "self", type: .related)
        #expect(edge.sourceNodeId == edge.targetNodeId)
        #expect(edge.sourceNodeId == "self")
    }
    
    @Test("Empty string IDs are allowed")
    func emptyStringIds() {
        let edge = SDGraphEdge(source: "", target: "", type: .reference)
        #expect(edge.sourceNodeId == "")
        #expect(edge.targetNodeId == "")
    }
}

@Suite("SDGraphEdge - Weight Behavior")
struct SDGraphEdgeWeightTests {
    
    @Test("Weight can be customized at initialization")
    func customWeightInit() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference, weight: 3.0)
        #expect(edge.weight == 3.0)
    }
    
    @Test("Weight can be modified after creation")
    func weightMutable() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(edge.weight == 1.0)
        
        edge.weight = 5.5
        #expect(edge.weight == 5.5)
    }
    
    @Test("Weight accepts zero")
    func weightZero() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference, weight: 0.0)
        #expect(edge.weight == 0.0)
    }
    
    @Test("Weight accepts large values")
    func weightLarge() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference, weight: 10000.0)
        #expect(edge.weight == 10000.0)
    }
    
    @Test("Weight accepts fractional values")
    func weightFractional() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference, weight: 0.75)
        #expect(edge.weight == 0.75)
    }
    
    @Test("Weight accepts negative values")
    func weightNegative() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference, weight: -2.0)
        #expect(edge.weight == -2.0)
    }
    
    @Test("Semantic edges can have different weights")
    func semanticEdgeWeights() {
        let supports = SDGraphEdge(source: "a", target: "b", type: .supports, weight: 2.0)
        let contradicts = SDGraphEdge(source: "a", target: "b", type: .contradicts, weight: -1.0)
        
        #expect(supports.weight == 2.0)
        #expect(contradicts.weight == -1.0)
    }
}

@Suite("SDGraphEdge - isManual Flag")
struct SDGraphEdgeIsManualTests {
    
    @Test("isManual defaults to false")
    func isManualDefault() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(edge.isManual == false)
    }
    
    @Test("isManual can be set to true")
    func isManualTrue() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.isManual = true
        #expect(edge.isManual == true)
    }
    
    @Test("isManual can be toggled")
    func isManualToggle() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(edge.isManual == false)
        
        edge.isManual = true
        #expect(edge.isManual == true)
        
        edge.isManual = false
        #expect(edge.isManual == false)
    }
}

@Suite("SDGraphEdge - Timestamps")
struct SDGraphEdgeTimestampTests {
    
    @Test("createdAt is set on initialization")
    func createdAtSet() {
        let before = Date.now
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(edge.createdAt >= before)
    }
    
    @Test("createdAt can be modified")
    func createdAtMutable() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        let newDate = Date(timeIntervalSince1970: 1000)
        
        edge.createdAt = newDate
        #expect(edge.createdAt == newDate)
    }
}

@Suite("SDGraphEdge - Type Mutation")
struct SDGraphEdgeTypeMutationTests {
    
    @Test("Type can be changed after creation")
    func typeMutable() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(edge.type == "reference")
        #expect(edge.edgeType == .reference)
        
        edge.type = "cites"
        #expect(edge.type == "cites")
        #expect(edge.edgeType == .cites)
    }
    
    @Test("Changing type to legacy value triggers migration")
    func typeChangeToLegacy() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        edge.type = "wikilink"
        #expect(edge.edgeType == .reference)
    }
    
    @Test("edgeType reflects current type string")
    func edgeTypeReflectsCurrent() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(edge.edgeType == .reference)
        
        edge.type = "contains"
        #expect(edge.edgeType == .contains)
        
        edge.type = "authored"
        #expect(edge.edgeType == .authored)
    }
}

@Suite("SDGraphEdge - Complex Scenarios")
struct SDGraphEdgeComplexTests {
    
    @Test("Reference edge between two notes")
    func referenceEdgeBetweenNotes() {
        let edge = SDGraphEdge(
            source: "note-uuid-1",
            target: "note-uuid-2",
            type: .reference,
            weight: 1.0
        )
        
        #expect(edge.edgeType == .reference)
        #expect(edge.sourceNodeId == "note-uuid-1")
        #expect(edge.targetNodeId == "note-uuid-2")
        #expect(edge.isManual == false)
    }
    
    @Test("Contains edge for folder relationship")
    func containsEdgeForFolder() {
        let edge = SDGraphEdge(
            source: "folder-uuid",
            target: "note-uuid",
            type: .contains,
            weight: 1.0
        )
        
        #expect(edge.edgeType == .contains)
        #expect(edge.sourceNodeId == "folder-uuid")
        #expect(edge.targetNodeId == "note-uuid")
    }
    
    @Test("Authored edge between author and work")
    func authoredEdge() {
        let edge = SDGraphEdge(
            source: "author-uuid",
            target: "paper-uuid",
            type: .authored,
            weight: 1.0
        )
        
        #expect(edge.edgeType == .authored)
    }
    
    @Test("Citation edge with weight")
    func citationEdge() {
        let edge = SDGraphEdge(
            source: "paper-a",
            target: "paper-b",
            type: .cites,
            weight: 2.5
        )
        
        #expect(edge.edgeType == .cites)
        #expect(edge.weight == 2.5)
    }
    
    @Test("Semantic support edge")
    func semanticSupportEdge() {
        let edge = SDGraphEdge(
            source: "evidence-note",
            target: "claim-note",
            type: .supports,
            weight: 3.0
        )
        
        #expect(edge.edgeType == .supports)
        #expect(edge.weight == 3.0)
        #expect(edge.isManual == false)
    }
    
    @Test("Manual edge created by user")
    func manualEdge() {
        let edge = SDGraphEdge(
            source: "node-a",
            target: "node-b",
            type: .related,
            weight: 1.0
        )
        edge.isManual = true
        
        #expect(edge.edgeType == .related)
        #expect(edge.isManual == true)
    }
    
    @Test("Tagged edge for categorization")
    func taggedEdge() {
        let edge = SDGraphEdge(
            source: "note-uuid",
            target: "tag-uuid",
            type: .tagged,
            weight: 1.0
        )
        
        #expect(edge.edgeType == .tagged)
    }
    
    @Test("Quotes edge for quotations")
    func quotesEdge() {
        let edge = SDGraphEdge(
            source: "quote-node",
            target: "source-node",
            type: .quotes,
            weight: 1.5
        )
        
        #expect(edge.edgeType == .quotes)
        #expect(edge.weight == 1.5)
    }
    
    @Test("Contradiction edge")
    func contradictsEdge() {
        let edge = SDGraphEdge(
            source: "note-a",
            target: "note-b",
            type: .contradicts,
            weight: -2.0
        )
        
        #expect(edge.edgeType == .contradicts)
        #expect(edge.weight == -2.0)
    }
    
    @Test("Questions edge")
    func questionsEdge() {
        let edge = SDGraphEdge(
            source: "question-note",
            target: "topic-note",
            type: .questions,
            weight: 1.0
        )
        
        #expect(edge.edgeType == .questions)
    }
    
    @Test("Expands edge for elaboration")
    func expandsEdge() {
        let edge = SDGraphEdge(
            source: "detailed-note",
            target: "summary-note",
            type: .expands,
            weight: 2.0
        )
        
        #expect(edge.edgeType == .expands)
        #expect(edge.weight == 2.0)
    }
}

@Suite("SDGraphEdge - Edge Cases")
struct SDGraphEdgeEdgeCaseTests {
    
    @Test("Can create edge with very long node IDs")
    func longNodeIds() {
        let longId = String(repeating: "a", count: 1000)
        let edge = SDGraphEdge(source: longId, target: longId, type: .reference)
        
        #expect(edge.sourceNodeId.count == 1000)
        #expect(edge.targetNodeId.count == 1000)
    }
    
    @Test("Can create edge with Unicode node IDs")
    func unicodeNodeIds() {
        let unicodeId = "ノード-🆔-Заголовок"
        let edge = SDGraphEdge(source: unicodeId, target: unicodeId, type: .reference)
        
        #expect(edge.sourceNodeId == unicodeId)
        #expect(edge.targetNodeId == unicodeId)
    }
    
    @Test("Can create edge with special characters in IDs")
    func specialCharNodeIds() {
        let specialId = "node <script> & \"test\""
        let edge = SDGraphEdge(source: specialId, target: specialId, type: .reference)
        
        #expect(edge.sourceNodeId == specialId)
    }
    
    @Test("Can create multiple edges between same nodes with different types")
    func multipleEdgesSameNodes() {
        let source = "node-a"
        let target = "node-b"
        
        let reference = SDGraphEdge(source: source, target: target, type: .reference)
        let cites = SDGraphEdge(source: source, target: target, type: .cites)
        let relates = SDGraphEdge(source: source, target: target, type: .related)
        
        #expect(reference.edgeType == .reference)
        #expect(cites.edgeType == .cites)
        #expect(relates.edgeType == .related)
        
        #expect(reference.id != cites.id)
        #expect(cites.id != relates.id)
    }
    
    @Test("Very small positive weight")
    func verySmallWeight() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference, weight: 0.0001)
        #expect(edge.weight == 0.0001)
    }
    
    @Test("Very large weight")
    func veryLargeWeight() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference, weight: 1e10)
        #expect(edge.weight == 1e10)
    }
}

@Suite("SDGraphEdge - ID Immutability Check")
struct SDGraphEdgeIdTests {
    
    @Test("ID is set on initialization")
    func idSetOnInit() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        #expect(!edge.id.isEmpty)
    }
    
    @Test("ID can be modified (as per SwiftData model)")
    func idMutable() {
        let edge = SDGraphEdge(source: "a", target: "b", type: .reference)
        let originalId = edge.id
        
        edge.id = "custom-edge-id"
        #expect(edge.id == "custom-edge-id")
        #expect(edge.id != originalId)
    }
}
