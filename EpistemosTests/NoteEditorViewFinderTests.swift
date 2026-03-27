import AppKit
import Testing
@testable import Epistemos

@Suite("Note Editor View Finder")
struct NoteEditorViewFinderTests {
    @MainActor
    private final class WindowFixtureRetainer {
        static let shared = WindowFixtureRetainer()
        private var windows: [NSWindow] = []

        func retain(_ window: NSWindow) {
            window.orderOut(nil)
            windows.append(window)
        }
    }

    @MainActor
    private func retainWindowFixture(_ window: NSWindow) {
        WindowFixtureRetainer.shared.retain(window)
    }

    @Test("findTextView skips generic editable text views")
    @MainActor
    func findTextViewSkipsGenericEditableTextViews() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

        let generic = NSTextView(frame: .zero)
        generic.isEditable = true
        root.addSubview(generic)

        let (editorScrollView, noteEditor) = makeProseTextView(pageId: "page-a")
        let container = NSView(frame: .zero)
        container.addSubview(editorScrollView)
        root.addSubview(container)

        let found = NoteEditorViewFinder.findTextView(in: root)

        #expect(found === noteEditor)
    }

    @Test("findTextView returns the note editor matching the requested page")
    @MainActor
    func findTextViewReturnsMatchingPageEditor() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let (firstScrollView, _) = makeProseTextView(pageId: "page-a")
        let (secondScrollView, second) = makeProseTextView(pageId: "page-b")

        root.addSubview(firstScrollView)
        root.addSubview(secondScrollView)

        let found = NoteEditorViewFinder.findTextView(in: root, matchingPageId: "page-b")

        #expect(found === second)
    }

    @Test("findTextView returns nil when no note editor matches the requested page")
    @MainActor
    func findTextViewReturnsNilForMissingPageMatch() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let (editorScrollView, _) = makeProseTextView(pageId: "page-a")
        root.addSubview(editorScrollView)

        let found = NoteEditorViewFinder.findTextView(in: root, matchingPageId: "page-z")

        #expect(found == nil)
    }

    @Test("findEditorTextView does not fall back to another note when the requested page is missing")
    @MainActor
    func findEditorTextViewDoesNotFallbackToAnotherNote() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.tabbingIdentifier = "epistemos-note-tabs"

        let root = NSView(frame: window.frame)
        let (editorScrollView, _) = makeProseTextView(pageId: "page-a")
        root.addSubview(editorScrollView)
        window.contentView = root
        window.makeKeyAndOrderFront(nil)
        defer { retainWindowFixture(window) }

        let found = NoteEditorViewFinder.findEditorTextView(for: "page-z")

        #expect(found == nil)
    }

    @MainActor
    private func makeProseTextView(pageId: String) -> (NSScrollView, ProseTextView2) {
        let (scrollView, textView) = ProseTextView2.makeTextKit2()
        textView.isEditable = true
        textView.pageId = pageId
        return (scrollView, textView)
    }
}
