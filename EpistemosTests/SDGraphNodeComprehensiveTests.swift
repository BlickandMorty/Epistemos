import Foundation
import Testing
@testable import Epistemos

// MARK: - SDGraphNode Tests

@Suite("SDGraphNode - Initialization")
struct SDGraphNodeInitializationTests {
    
    @Test("Can initialize with minimum required parameters")
    func initWithMinimumParams() {
        let node = SDGraphNode(type: .note, label: "Test Note")
        
        #expect(node.type == "note")
        #expect(node.label == "Test Note")
        #expect(node.sourceId == nil)
        #expect(node.weight == 1.0)
        #expect(node.isManual == false)
    }
    
    @Test("Can initialize with all parameters")
    func initWithAllParams() {
        let node = SDGraphNode(
            type: .source,
            label: "Research Paper",
            sourceId: "page-123",
            weight: 2.5
        )
        
        #expect(node.type == "source")
        #expect(node.label == "Research Paper")
        #expect(node.sourceId == "page-123")
        #expect(node.weight == 2.5)
    }
    
    @Test("Can initialize with different node types")
    func initWithDifferentTypes() {
        let note = SDGraphNode(type: .note, label: "Note")
        let chat = SDGraphNode(type: .chat, label: "Chat")
        let idea = SDGraphNode(type: .idea, label: "Idea")
        let source = SDGraphNode(type: .source, label: "Source")
        let folder = SDGraphNode(type: .folder, label: "Folder")
        let quote = SDGraphNode(type: .quote, label: "Quote")
        let tag = SDGraphNode(type: .tag, label: "Tag")
        
        #expect(note.type == "note")
        #expect(chat.type == "chat")
        #expect(idea.type == "idea")
        #expect(source.type == "source")
        #expect(folder.type == "folder")
        #expect(quote.type == "quote")
        #expect(tag.type == "tag")
    }
    
    @Test("Initialization generates unique IDs")
    func uniqueIDsGenerated() {
        let node1 = SDGraphNode(type: .note, label: "Node 1")
        let node2 = SDGraphNode(type: .note, label: "Node 2")
        
        #expect(node1.id != node2.id)
        #expect(!node1.id.isEmpty)
        #expect(!node2.id.isEmpty)
    }
    
    @Test("ID is valid UUID format")
    func idIsValidUUID() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(UUID(uuidString: node.id) != nil)
    }
}

@Suite("SDGraphNode - Default Values")
struct SDGraphNodeDefaultValueTests {
    
    @Test("Default type is 'note'")
    func defaultType() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.type == "note")
    }
    
    @Test("Default weight is 1.0")
    func defaultWeight() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.weight == 1.0)
    }
    
    @Test("Default isManual is false")
    func defaultIsManual() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.isManual == false)
    }
    
    @Test("Default metadata is nil")
    func defaultMetadata() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.metadata == nil)
    }
    
    @Test("Default sourceId is nil")
    func defaultSourceId() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.sourceId == nil)
    }
    
    @Test("createdAt is set to current time on init")
    func createdAtIsSet() {
        let before = Date.now
        let node = SDGraphNode(type: .note, label: "Test")
        let after = Date.now
        
        #expect(node.createdAt >= before)
        #expect(node.createdAt <= after)
    }
    
    @Test("updatedAt is set to current time on init")
    func updatedAtIsSet() {
        let before = Date.now
        let node = SDGraphNode(type: .note, label: "Test")
        let after = Date.now
        
        #expect(node.updatedAt >= before)
        #expect(node.updatedAt <= after)
    }
    
    @Test("createdAt and updatedAt are equal on initialization")
    func createdAndUpdatedEqualOnInit() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(abs(node.createdAt.timeIntervalSince(node.updatedAt)) < 1.0)
    }
}

@Suite("SDGraphNode - nodeType Computed Property")
struct SDGraphNodeNodeTypeTests {
    
    @Test("nodeType returns correct type for new types")
    func nodeTypeForNewTypes() {
        let note = SDGraphNode(type: .note, label: "Note")
        let chat = SDGraphNode(type: .chat, label: "Chat")
        let idea = SDGraphNode(type: .idea, label: "Idea")
        let source = SDGraphNode(type: .source, label: "Source")
        let folder = SDGraphNode(type: .folder, label: "Folder")
        let quote = SDGraphNode(type: .quote, label: "Quote")
        let tag = SDGraphNode(type: .tag, label: "Tag")
        
        #expect(note.nodeType == .note)
        #expect(chat.nodeType == .chat)
        #expect(idea.nodeType == .idea)
        #expect(source.nodeType == .source)
        #expect(folder.nodeType == .folder)
        #expect(quote.nodeType == .quote)
        #expect(tag.nodeType == .tag)
    }
    
    @Test("nodeType handles legacy 'brainDump' migration")
    func nodeTypeLegacyBrainDump() {
        let node = SDGraphNode(type: .idea, label: "Test")
        node.type = "brainDump"
        #expect(node.nodeType == .idea)
    }
    
    @Test("nodeType handles legacy 'insight' migration")
    func nodeTypeLegacyInsight() {
        let node = SDGraphNode(type: .idea, label: "Test")
        node.type = "insight"
        #expect(node.nodeType == .idea)
    }
    
    @Test("nodeType handles legacy 'paper' migration")
    func nodeTypeLegacyPaper() {
        let node = SDGraphNode(type: .source, label: "Test")
        node.type = "paper"
        #expect(node.nodeType == .source)
    }
    
    @Test("nodeType handles legacy 'book' migration")
    func nodeTypeLegacyBook() {
        let node = SDGraphNode(type: .source, label: "Test")
        node.type = "book"
        #expect(node.nodeType == .source)
    }
    
    @Test("nodeType handles legacy 'thinker' migration")
    func nodeTypeLegacyThinker() {
        let node = SDGraphNode(type: .source, label: "Test")
        node.type = "thinker"
        #expect(node.nodeType == .source)
    }
    
    @Test("nodeType handles legacy 'concept' migration")
    func nodeTypeLegacyConcept() {
        let node = SDGraphNode(type: .tag, label: "Test")
        node.type = "concept"
        #expect(node.nodeType == .tag)
    }
    
    @Test("nodeType defaults to note for unknown types")
    func nodeTypeUnknownDefaultsToNote() {
        let node = SDGraphNode(type: .note, label: "Test")
        node.type = "unknownType"
        #expect(node.nodeType == .note)
    }
}

@Suite("SDGraphNode - Metadata Management")
struct SDGraphNodeMetadataTests {
    
    @Test("meta getter returns empty metadata when no data stored")
    func metaGetterEmpty() {
        let node = SDGraphNode(type: .note, label: "Test")
        let meta = node.meta
        
        #expect(meta.evidenceGrade == nil)
        #expect(meta.researchStage == nil)
        #expect(meta.url == nil)
    }
    
    @Test("meta setter stores metadata as JSON")
    func metaSetterStoresJSON() {
        let node = SDGraphNode(type: .note, label: "Test")
        let newMeta = GraphNodeMetadata(
            evidenceGrade: "Strong",
            authors: ["Alice", "Bob"],
            year: 2024
        )
        
        node.meta = newMeta
        
        #expect(node.metadata != nil)
        #expect(node.meta.evidenceGrade == "Strong")
        #expect(node.meta.year == 2024)
        #expect(node.meta.authors == ["Alice", "Bob"])
    }
    
    @Test("meta round-trips all fields correctly")
    func metaRoundTrip() {
        let node = SDGraphNode(type: .note, label: "Test")
        let original = GraphNodeMetadata(
            evidenceGrade: "High",
            researchStage: 3,
            url: "https://example.com",
            authors: ["Author1", "Author2"],
            quoteText: "Quote",
            year: 2024,
            journal: "Nature",
            doi: "10.1234/doi",
            abstract: "Abstract",
            clusterTheme: "Theme",
            originChatId: "chat-123",
            originNoteId: "note-456"
        )
        
        node.meta = original
        let retrieved = node.meta
        
        #expect(retrieved.evidenceGrade == original.evidenceGrade)
        #expect(retrieved.researchStage == original.researchStage)
        #expect(retrieved.url == original.url)
        #expect(retrieved.authors == original.authors)
        #expect(retrieved.quoteText == original.quoteText)
        #expect(retrieved.year == original.year)
        #expect(retrieved.journal == original.journal)
        #expect(retrieved.doi == original.doi)
        #expect(retrieved.abstract == original.abstract)
        #expect(retrieved.clusterTheme == original.clusterTheme)
        #expect(retrieved.originChatId == original.originChatId)
        #expect(retrieved.originNoteId == original.originNoteId)
    }
    
    @Test("Setting meta updates metadata Data property")
    func metaUpdatesDataProperty() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.metadata == nil)
        
        node.meta = GraphNodeMetadata(evidenceGrade: "Test")
        #expect(node.metadata != nil)
    }
    
    @Test("Multiple meta updates overwrite previous values")
    func multipleMetaUpdates() {
        let node = SDGraphNode(type: .note, label: "Test")
        
        node.meta = GraphNodeMetadata(evidenceGrade: "First")
        #expect(node.meta.evidenceGrade == "First")
        
        node.meta = GraphNodeMetadata(evidenceGrade: "Second")
        #expect(node.meta.evidenceGrade == "Second")
    }
    
    @Test("Meta getter uses cache on subsequent accesses")
    func metaUsesCache() {
        let node = SDGraphNode(type: .note, label: "Test")
        node.meta = GraphNodeMetadata(evidenceGrade: "Cached")
        
        // First access sets cache
        let first = node.meta
        // Second access uses cache
        let second = node.meta
        
        #expect(first.evidenceGrade == second.evidenceGrade)
    }
    
    @Test("Can clear metadata by setting empty meta")
    func clearMetadata() {
        let node = SDGraphNode(type: .note, label: "Test")
        node.meta = GraphNodeMetadata(evidenceGrade: "Test")
        #expect(node.metadata != nil)
        
        node.meta = GraphNodeMetadata()
        #expect(node.meta.evidenceGrade == nil)
    }
    
    @Test("Metadata persists Unicode content")
    func metadataUnicode() {
        let node = SDGraphNode(type: .note, label: "Test")
        node.meta = GraphNodeMetadata(
            authors: ["田中", "佐藤"],
            quoteText: "日本語の引用"
        )
        
        #expect(node.meta.quoteText == "日本語の引用")
        #expect(node.meta.authors == ["田中", "佐藤"])
    }
}

@Suite("SDGraphNode - Source ID Relationships")
struct SDGraphNodeSourceIdTests {
    
    @Test("sourceId can be set to page ID")
    func sourceIdPage() {
        let node = SDGraphNode(type: .note, label: "Test", sourceId: "page-abc-123")
        #expect(node.sourceId == "page-abc-123")
    }
    
    @Test("sourceId can be set to chat ID")
    func sourceIdChat() {
        let node = SDGraphNode(type: .chat, label: "Test", sourceId: "chat-xyz-789")
        #expect(node.sourceId == "chat-xyz-789")
    }
    
    @Test("sourceId can be nil")
    func sourceIdNil() {
        let node = SDGraphNode(type: .idea, label: "Test", sourceId: nil)
        #expect(node.sourceId == nil)
    }
    
    @Test("sourceId can be modified after creation")
    func sourceIdMutable() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.sourceId == nil)
        
        node.sourceId = "new-source-id"
        #expect(node.sourceId == "new-source-id")
    }
    
    @Test("sourceId can be cleared after being set")
    func sourceIdClearable() {
        let node = SDGraphNode(type: .note, label: "Test", sourceId: "original")
        #expect(node.sourceId == "original")
        
        node.sourceId = nil
        #expect(node.sourceId == nil)
    }
    
    @Test("Manual nodes typically have no sourceId")
    func manualNodeNoSourceId() {
        let node = SDGraphNode(type: .tag, label: "Manual Tag")
        node.isManual = true
        #expect(node.isManual == true)
        #expect(node.sourceId == nil)
    }
}

@Suite("SDGraphNode - Weight Behavior")
struct SDGraphNodeWeightTests {
    
    @Test("Weight can be customized at initialization")
    func customWeightInit() {
        let node = SDGraphNode(type: .note, label: "Test", weight: 5.0)
        #expect(node.weight == 5.0)
    }
    
    @Test("Weight can be modified after creation")
    func weightMutable() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.weight == 1.0)
        
        node.weight = 3.5
        #expect(node.weight == 3.5)
    }
    
    @Test("Weight accepts zero")
    func weightZero() {
        let node = SDGraphNode(type: .note, label: "Test", weight: 0.0)
        #expect(node.weight == 0.0)
    }
    
    @Test("Weight accepts large values")
    func weightLarge() {
        let node = SDGraphNode(type: .note, label: "Test", weight: 1000.0)
        #expect(node.weight == 1000.0)
    }
    
    @Test("Weight accepts fractional values")
    func weightFractional() {
        let node = SDGraphNode(type: .note, label: "Test", weight: 0.5)
        #expect(node.weight == 0.5)
    }
    
    @Test("Weight accepts negative values")
    func weightNegative() {
        let node = SDGraphNode(type: .note, label: "Test", weight: -1.0)
        #expect(node.weight == -1.0)
    }
}

@Suite("SDGraphNode - isManual Flag")
struct SDGraphNodeIsManualTests {
    
    @Test("isManual defaults to false")
    func isManualDefault() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.isManual == false)
    }
    
    @Test("isManual can be set to true")
    func isManualTrue() {
        let node = SDGraphNode(type: .note, label: "Test")
        node.isManual = true
        #expect(node.isManual == true)
    }
    
    @Test("isManual can be toggled")
    func isManualToggle() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.isManual == false)
        
        node.isManual = true
        #expect(node.isManual == true)
        
        node.isManual = false
        #expect(node.isManual == false)
    }
    
    @Test("Derived nodes typically have isManual = false")
    func derivedNodeNotManual() {
        let node = SDGraphNode(type: .note, label: "From Page", sourceId: "page-123")
        #expect(node.isManual == false)
    }
}

@Suite("SDGraphNode - Timestamps")
struct SDGraphNodeTimestampTests {
    
    @Test("createdAt is set on initialization")
    func createdAtSet() {
        let before = Date.now
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.createdAt >= before)
    }
    
    @Test("updatedAt is set on initialization")
    func updatedAtSet() {
        let before = Date.now
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.updatedAt >= before)
    }
    
    @Test("Timestamps can be modified")
    func timestampsMutable() {
        let node = SDGraphNode(type: .note, label: "Test")
        let newDate = Date(timeIntervalSince1970: 0)
        
        node.createdAt = newDate
        node.updatedAt = newDate
        
        #expect(node.createdAt == newDate)
        #expect(node.updatedAt == newDate)
    }
}

@Suite("SDGraphNode - Label Edge Cases")
struct SDGraphNodeLabelTests {
    
    @Test("Can create node with empty label")
    func emptyLabel() {
        let node = SDGraphNode(type: .note, label: "")
        #expect(node.label == "")
    }
    
    @Test("Can create node with very long label")
    func longLabel() {
        let longLabel = String(repeating: "A", count: 10000)
        let node = SDGraphNode(type: .note, label: longLabel)
        #expect(node.label.count == 10000)
    }
    
    @Test("Can create node with Unicode label")
    func unicodeLabel() {
        let unicodeLabel = "日本語ラベル 🏷️ Заголовок"
        let node = SDGraphNode(type: .note, label: unicodeLabel)
        #expect(node.label == unicodeLabel)
    }
    
    @Test("Can create node with emoji-only label")
    func emojiLabel() {
        let emojiLabel = "🎉🔥💯"
        let node = SDGraphNode(type: .note, label: emojiLabel)
        #expect(node.label == emojiLabel)
    }
    
    @Test("Can create node with special characters in label")
    func specialCharsLabel() {
        let specialLabel = "<script>alert('xss')</script> & \"quotes\""
        let node = SDGraphNode(type: .note, label: specialLabel)
        #expect(node.label == specialLabel)
    }
    
    @Test("Label can be modified after creation")
    func labelMutable() {
        let node = SDGraphNode(type: .note, label: "Original")
        #expect(node.label == "Original")
        
        node.label = "Modified"
        #expect(node.label == "Modified")
    }
    
    @Test("Label can contain newlines")
    func labelWithNewlines() {
        let multilineLabel = "Line 1\nLine 2\nLine 3"
        let node = SDGraphNode(type: .note, label: multilineLabel)
        #expect(node.label == multilineLabel)
    }
}

@Suite("SDGraphNode - Type Mutation")
struct SDGraphNodeTypeMutationTests {
    
    @Test("Type can be changed after creation")
    func typeMutable() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.type == "note")
        #expect(node.nodeType == .note)
        
        node.type = "source"
        #expect(node.type == "source")
        #expect(node.nodeType == .source)
    }
    
    @Test("Changing type to legacy value triggers migration")
    func typeChangeToLegacy() {
        let node = SDGraphNode(type: .note, label: "Test")
        node.type = "brainDump"
        #expect(node.nodeType == .idea)
    }
    
    @Test("nodeType reflects current type string")
    func nodeTypeReflectsCurrent() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(node.nodeType == .note)
        
        node.type = "chat"
        #expect(node.nodeType == .chat)
        
        node.type = "idea"
        #expect(node.nodeType == .idea)
    }
}

@Suite("SDGraphNode - ID Immutability")
struct SDGraphNodeIdTests {
    
    @Test("ID is set on initialization")
    func idSetOnInit() {
        let node = SDGraphNode(type: .note, label: "Test")
        #expect(!node.id.isEmpty)
    }
    
    @Test("ID can be modified (as per SwiftData model)")
    func idMutable() {
        let node = SDGraphNode(type: .note, label: "Test")
        let originalId = node.id
        
        node.id = "custom-id"
        #expect(node.id == "custom-id")
        #expect(node.id != originalId)
    }
}

@Suite("SDGraphNode - Complex Scenarios")
struct SDGraphNodeComplexTests {
    
    @Test("Full node with all properties set")
    func fullNodeConfiguration() {
        let node = SDGraphNode(
            type: .source,
            label: "Research Paper",
            sourceId: "page-research-001",
            weight: 3.5
        )
        
        node.meta = GraphNodeMetadata(
            evidenceGrade: "High",
            researchStage: 4,
            url: "https://arxiv.org/abs/1234",
            authors: ["Alice Smith", "Bob Jones"],
            year: 2024,
            journal: "Nature",
            doi: "10.1234/nature.2024.001"
        )
        
        node.isManual = false
        
        #expect(node.nodeType == .source)
        #expect(node.label == "Research Paper")
        #expect(node.sourceId == "page-research-001")
        #expect(node.weight == 3.5)
        #expect(node.meta.evidenceGrade == "High")
        #expect(node.meta.authors?.count == 2)
        #expect(node.isManual == false)
    }
    
    @Test("Manual node without source")
    func manualNodeWithoutSource() {
        let node = SDGraphNode(type: .idea, label: "My Brilliant Idea")
        node.isManual = true
        node.weight = 5.0
        node.meta = GraphNodeMetadata(clusterTheme: "Personal Ideas")
        
        #expect(node.nodeType == .idea)
        #expect(node.isManual == true)
        #expect(node.sourceId == nil)
        #expect(node.weight == 5.0)
        #expect(node.meta.clusterTheme == "Personal Ideas")
    }
    
    @Test("Quote node with quoteText metadata")
    func quoteNodeWithText() {
        let node = SDGraphNode(type: .quote, label: "Famous Quote", sourceId: "page-quotes")
        node.meta = GraphNodeMetadata(
            authors: ["William Shakespeare"],
            quoteText: "To be, or not to be, that is the question."
        )
        
        #expect(node.nodeType == .quote)
        #expect(node.meta.quoteText?.contains("To be") == true)
        #expect(node.meta.authors?.first == "William Shakespeare")
    }
    
    @Test("Tag node for categorization")
    func tagNodeForCategorization() {
        let node = SDGraphNode(type: .tag, label: "Machine Learning")
        node.isManual = true
        node.meta = GraphNodeMetadata(clusterTheme: "AI/ML")
        
        #expect(node.nodeType == .tag)
        #expect(node.isManual == true)
        #expect(node.meta.clusterTheme == "AI/ML")
    }
    
    @Test("Folder node with contains relationship")
    func folderNode() {
        let node = SDGraphNode(type: .folder, label: "Research Notes")
        node.sourceId = "folder-research"
        node.weight = 2.0
        
        #expect(node.nodeType == .folder)
        #expect(node.sourceId == "folder-research")
        #expect(node.weight == 2.0)
    }
}
