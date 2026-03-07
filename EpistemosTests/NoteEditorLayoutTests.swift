import Testing
@testable import Epistemos

@Suite("Note Editor Layout")
struct NoteEditorLayoutTests {
    @Test("top spacing stays tight below the toolbar")
    func topSpacingStaysTightBelowToolbar() {
        #expect(ProseEditorRepresentable.verticalInset == 56)
        #expect(MarkdownTextStorage.leadingH1SpacingBefore == 24)
        #expect(MarkdownTextStorage.sectionH1SpacingBefore == 18)
    }
}
