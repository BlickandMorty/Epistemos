import Foundation
import Testing

@Suite("Graph Node Type Runtime Sync")
struct GraphNodeTypeRuntimeSyncTests {
    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }

    @Test("Rust NodeType enum includes the semantic entity variants")
    func rustNodeTypeEnumIncludesSemanticEntityVariants() throws {
        let source = try loadRepoTextFile("graph-engine/src/types.rs")

        #expect(source.contains("Person = 8"))
        #expect(source.contains("Project = 9"))
        #expect(source.contains("Topic = 10"))
        #expect(source.contains("Decision = 11"))
        #expect(source.contains("Event = 12"))
        #expect(source.contains("Resource = 13"))
    }

    @Test("C header documents all graph node type values")
    func cHeaderDocumentsAllGraphNodeTypeValues() throws {
        let header = try loadRepoTextFile("graph-engine-bridge/graph_engine.h")

        #expect(header.contains("8=Person"))
        #expect(header.contains("9=Project"))
        #expect(header.contains("10=Topic"))
        #expect(header.contains("11=Decision"))
        #expect(header.contains("12=Event"))
        #expect(header.contains("13=Resource"))
    }
}
