import Testing
@testable import Epistemos

@Suite("Structured Output Schemas")
struct StructuredOutputSchemaTests {
    @Test("file edit structured schemas do not expose legacy tool names")
    func fileEditStructuredSchemasDoNotExposeLegacyToolNames() {
        let names = FileEditTool.all.map(\.name)

        #expect(names == [
            "file_patch",
            "file_replace",
            "file_insert_at_line",
            "file_delete_lines",
        ])
        #expect(!names.contains("edit_file"))
        #expect(!names.contains("replace_file"))
        #expect(!names.contains("insert_at_line"))
        #expect(!names.contains("delete_lines"))
    }
}
