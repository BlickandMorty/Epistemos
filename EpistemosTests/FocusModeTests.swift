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
}
