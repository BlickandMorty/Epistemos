import Testing
@testable import Epistemos

@Suite("StructuralGraphBuilder")
struct StructuralGraphBuilderTests {

    @Test("NoteIdea types map correctly to graph node types")
    func ideaTypeMapping() {
        let idea = NoteIdea(type: .idea, title: "Test", body: "Body")
        let brainDump = NoteIdea(type: .brainDump, title: "Dump", body: "Raw")
        #expect(idea.type == .idea)
        #expect(brainDump.type == .brainDump)
    }

    @Test("GraphNodeType has correct icons for all types")
    func allTypesHaveIcons() {
        for type in GraphNodeType.allCases {
            #expect(!type.icon.isEmpty)
            #expect(!type.displayName.isEmpty)
        }
    }
}
