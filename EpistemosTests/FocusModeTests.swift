import Foundation
import Testing
@testable import Epistemos

@Suite("Focus Mode")
struct FocusModeTests {

    @Test("Focus mode state toggles correctly")
    @MainActor func focusModeToggle() {
        let state = NotesUIState()
        #expect(!state.isFocusMode)
        state.isFocusMode = true
        #expect(state.isFocusMode)
        state.isFocusMode = false
        #expect(!state.isFocusMode)
    }

    @Test("Focus mode active paragraph detection")
    func activeParagraphRange() {
        let text = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."
        let nsText = text as NSString

        // Cursor in second paragraph (position 18 = start of "Second")
        let cursorPos = 18
        let range = nsText.paragraphRange(for: NSRange(location: cursorPos, length: 0))
        #expect(range.location == 18)
        #expect(nsText.substring(with: range).hasPrefix("Second"))
    }

    @Test("Session word target tracks delta")
    @MainActor func sessionWordTarget() {
        let state = NotesUIState()
        state.sessionStartWordCount = 100
        state.sessionWordTarget = 500
        let current = 300
        let delta = current - state.sessionStartWordCount
        #expect(delta == 200)
        if let target = state.sessionWordTarget {
            let progress = Double(delta) / Double(target)
            #expect(progress > 0.39 && progress < 0.41)
        }
    }

    @Test("TOC parser extracts headings with correct offsets")
    func tocParserHeadings() {
        let md = "# Title\n\nSome text\n\n## Section A\n\nMore text\n\n### Subsection\n\n## Section B"
        let items = TOCParser.parse(md)
        let headings = items.filter { $0.kind == .heading }
        #expect(headings.count == 4)
        #expect(headings[0].title == "Title")
        #expect(headings[0].level == 1)
        #expect(headings[1].title == "Section A")
        #expect(headings[1].level == 2)
        #expect(headings[2].title == "Subsection")
        #expect(headings[2].level == 3)
        #expect(headings[3].title == "Section B")
        #expect(headings[3].level == 2)
    }
}
