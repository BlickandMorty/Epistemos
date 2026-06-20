import Testing
import Foundation

@testable import Epistemos

// SS-DD (owner 2026-06-20, with screenshot): icon-only borderlessButton Menus rendered the
// default Menu chevron next to/overlapping the SF Symbol → the code-editor eye + gear looked
// "deformed." .menuIndicator(.hidden) hides the chevron (the menu still opens; functionality
// unchanged) — applied to the screenshotted code-editor eye/gear + the icon-only sweep sites.
// Deferred: the Epdoc toolbar/gutter menus (owner is actively rewriting Epdoc via SS-EDGE).
// Left as-is: AdapterSelectorView (a TEXT "Active Adapter" menu that legitimately wants a
// disclosure chevron).
@Suite("SS-DD icon-menu chevron cleanup")
struct SSDDChevronCleanupTests {

    @Test("the code-editor eye + gear menus hide the chevron (the screenshotted fix)")
    func codeEditorMenusHideChevron() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        // Both icon-only borderlessButton menus (eye + gear) carry .menuIndicator(.hidden).
        let count = src.components(separatedBy: ".menuIndicator(.hidden)").count - 1
        #expect(count >= 2)
    }

    @Test("the icon-only sweep sites hide the chevron too")
    func sweepSitesHideChevron() throws {
        for path in [
            "Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift",
            "Epistemos/Views/Chat/ArtifactBlockView.swift",
            "Epistemos/Views/Notes/DiffSheetView.swift",
        ] {
            let src = try loadMirroredSourceTextFile(path)
            #expect(src.contains(".menuIndicator(.hidden)"), "missing .menuIndicator(.hidden) in \(path)")
        }
    }
}
