import Testing
@testable import Epistemos

@Suite("GraphTypes")
struct GraphTypesTests {

    // MARK: - GraphNodeType

    @Test("all cases count is 7")
    func caseCount() {
        #expect(GraphNodeType.allCases.count == 7)
    }

    @Test("rustIndex is unique and sequential")
    func rustIndexUnique() {
        let indices = GraphNodeType.allCases.map { $0.rustIndex }
        #expect(Set(indices).count == GraphNodeType.allCases.count)
        // Should be 0..6
        #expect(indices.sorted() == [0, 1, 2, 3, 4, 5, 6])
    }

    @Test("rustIndex matches expected values")
    func rustIndexValues() {
        #expect(GraphNodeType.note.rustIndex == 0)
        #expect(GraphNodeType.chat.rustIndex == 1)
        #expect(GraphNodeType.idea.rustIndex == 2)
        #expect(GraphNodeType.source.rustIndex == 3)
        #expect(GraphNodeType.folder.rustIndex == 4)
        #expect(GraphNodeType.quote.rustIndex == 5)
        #expect(GraphNodeType.tag.rustIndex == 6)
    }

    @Test("all types have display names and icons")
    func displayNamesAndIcons() {
        for type in GraphNodeType.allCases {
            #expect(!type.displayName.isEmpty, "\(type) should have a display name")
            #expect(!type.icon.isEmpty, "\(type) should have an icon")
        }
    }

    // MARK: - Legacy Migration

    @Test("brainDump migrates to idea")
    func legacyBrainDump() {
        #expect(GraphNodeType(legacy: "brainDump") == .idea)
    }

    @Test("insight migrates to idea")
    func legacyInsight() {
        #expect(GraphNodeType(legacy: "insight") == .idea)
    }

    @Test("paper migrates to source")
    func legacyPaper() {
        #expect(GraphNodeType(legacy: "paper") == .source)
    }

    @Test("book migrates to source")
    func legacyBook() {
        #expect(GraphNodeType(legacy: "book") == .source)
    }

    @Test("thinker migrates to source")
    func legacyThinker() {
        #expect(GraphNodeType(legacy: "thinker") == .source)
    }

    @Test("concept migrates to tag")
    func legacyConcept() {
        #expect(GraphNodeType(legacy: "concept") == .tag)
    }

    @Test("note passes through")
    func legacyNote() {
        #expect(GraphNodeType(legacy: "note") == .note)
    }

    @Test("unknown defaults to note")
    func legacyUnknown() {
        #expect(GraphNodeType(legacy: "nonexistent") == .note)
    }

    @Test("existing valid types pass through legacy init")
    func legacyPassthrough() {
        #expect(GraphNodeType(legacy: "chat") == .chat)
        #expect(GraphNodeType(legacy: "folder") == .folder)
        #expect(GraphNodeType(legacy: "quote") == .quote)
        #expect(GraphNodeType(legacy: "tag") == .tag)
    }

    // MARK: - GraphEdgeType Legacy Migration

    @Test("wikilink migrates to reference")
    func edgeLegacyWikilink() {
        #expect(GraphEdgeType(legacy: "wikilink") == .reference)
    }

    @Test("ideaLink migrates to reference")
    func edgeLegacyIdeaLink() {
        #expect(GraphEdgeType(legacy: "ideaLink") == .reference)
    }

    @Test("livesIn migrates to contains")
    func edgeLegacyLivesIn() {
        #expect(GraphEdgeType(legacy: "livesIn") == .contains)
    }

    @Test("belongsTo migrates to contains")
    func edgeLegacyBelongsTo() {
        #expect(GraphEdgeType(legacy: "belongsTo") == .contains)
    }

    @Test("tagged passes through")
    func edgeLegacyTagged() {
        #expect(GraphEdgeType(legacy: "tagged") == .tagged)
    }

    @Test("mentionedIn migrates to mentions")
    func edgeLegacyMentionedIn() {
        #expect(GraphEdgeType(legacy: "mentionedIn") == .mentions)
    }

    @Test("backedBy migrates to cites")
    func edgeLegacyBackedBy() {
        #expect(GraphEdgeType(legacy: "backedBy") == .cites)
    }

    @Test("authored migrates to authored")
    func edgeLegacyAuthored() {
        #expect(GraphEdgeType(legacy: "authored") == .authored)
    }

    @Test("semanticLink migrates to related")
    func edgeLegacySemanticLink() {
        #expect(GraphEdgeType(legacy: "semanticLink") == .related)
    }

    @Test("said migrates to quotes")
    func edgeLegacySaid() {
        #expect(GraphEdgeType(legacy: "said") == .quotes)
    }

    @Test("unknown edge type defaults to reference")
    func edgeLegacyUnknown() {
        #expect(GraphEdgeType(legacy: "nonexistent") == .reference)
    }
}
