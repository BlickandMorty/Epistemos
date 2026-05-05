import Foundation
import Testing

@Suite("Epdoc visibility source guards")
nonisolated struct EpdocVisibilitySourceGuardTests {
    @Test("File menu exposes New Document through the native epdoc document controller path")
    func fileMenuExposesNewDocument() throws {
        let source = try Self.loadSourceText("Epistemos/App/EpistemosApp.swift")

        #expect(source.contains("Button(\"New Document\")"),
                "The replaced File > New group must expose a visible .epdoc creation path.")
        #expect(source.contains("createEpdocDocument()"),
                "New Document should route through one dedicated command helper, not duplicate AppKit plumbing inline.")
        #expect(source.contains("makeUntitledDocument(ofType: \"com.epistemos.epdoc\")"),
                "The command must force the canonical .epdoc UTI instead of relying on AppKit's default type choice.")
        #expect(source.contains("document.makeWindowControllers()"))
        #expect(source.contains("document.showWindows()"))
    }

    nonisolated private static func loadSourceText(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
