import AppKit
import Testing
@testable import Epistemos

@Suite("ProseTextView2 Appearance")
struct ProseTextView2AppearanceTests {
    @Test("native editor backgrounds stay transparent so the note can fill the window under the toolbar")
    func nativeEditorBackgroundsStayTransparent() {
        #expect(ProseTextView2.editorBackgroundColor(for: .systemLight) == .clear)
        #expect(ProseTextView2.editorBackgroundColor(for: .systemDark) == .clear)
    }

    @MainActor
    @Test("theme application disables opaque editor fills for native system appearances")
    func themeApplicationDisablesOpaqueBackgroundsForNativeThemes() {
        let (scrollView, textView) = ProseTextView2.makeTextKit2()

        #expect(scrollView.borderType == .noBorder)
        #expect(scrollView.backgroundColor == .clear)

        textView.applyTheme(.systemDark)
        #expect(!textView.drawsBackground)
        #expect(textView.backgroundColor == .clear)

        textView.applyTheme(.oled)
        #expect(textView.drawsBackground)
    }
}
