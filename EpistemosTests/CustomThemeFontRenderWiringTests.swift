import Testing
import Foundation

@testable import Epistemos

// L1160 custom-theme-font VERIFY (owner: "picking a font on the custom theme changes rendered text,
// every level"). Commit 4b0a5e59e fixed the live re-render + persistence; CustomThemeFontOverrideTests
// pins the override STORAGE. This pins the other half — that the surviving note render surface routes
// themeable text through the custom-font path (AppDisplayTypography), so a refactor can't silently
// hardcode a font and break the custom theme. Scope note: the note EDITOR BODY uses a readable system
// font BY DESIGN (the custom/display fonts are pixel-art display faces, not legible for body editing).
@Suite("L1160 — custom theme font reaches the themeable render surfaces")
struct CustomThemeFontRenderWiringTests {

    @Test("note headings route through AppDisplayTypography (the override-reading custom-font path)")
    func noteHeadingsUseThemeFont() throws {
        let storage = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkdownContentStorage.swift")
        // Note H1–H6 use the heading font that reads the custom-theme override, so a picked custom
        // font applies to them at every level.
        #expect(storage.contains("AppDisplayTypography.nsHeadingFont"))
    }
}
