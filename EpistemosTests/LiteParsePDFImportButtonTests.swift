import Testing
import Foundation
@testable import Epistemos

/// R-LITEPARSE — the note-sidebar IMPORT button: gated, bulk-capable, routes through the
/// honest import controller, and is mounted in the sidebar.
@Suite("LiteParse PDF import button (sidebar)")
struct LiteParsePDFImportButtonTests {

    @Test("the button is flag-gated, bulk-capable, and routes through the import controller")
    func buttonWiring() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/LiteParse/LiteParsePDFImportButton.swift")
        // reads the Plan 3 gate status before rendering.
        #expect(src.contains("LiteParseImportGateStatus.status().isActive"))
        // a bulk PDF picker
        #expect(src.contains("allowedContentTypes = [.pdf]"))
        #expect(src.contains("allowsMultipleSelection = true"))
        // routes every file through the controller (honest per-file status, never a fake note)
        #expect(src.contains("LiteParsePDFImportController.importPage"))
        #expect(src.contains("case .notWired"))
        #expect(src.contains("ToolbarCapsuleButton("))
        #expect(src.contains("role: .toolbarUtility"))
        #expect(src.contains("chromePolicy: .bareUntilPressed"))
        #expect(src.contains("maxStatusLines"))
        #expect(src.contains("maxStatusMessageCharacters"))
        #expect(src.contains("maxFileNameDisplayCharacters"))
        #expect(src.contains("boundedStatusLine"))
        #expect(src.contains("boundedStatusMessage"))
        #expect(src.contains("normalizedDisplayText(bounded)"))
        #expect(src.contains("boundedStatusMessageText"))
        #expect(src.contains("normalizedStatusMessageText"))
        #expect(src.contains("CharacterSet.controlCharacters"))
        #expect(src.contains("CharacterSet.newlines"))
        #expect(src.contains("Source PDF: \\(Self.displayName(sourcePDFRelativePath"))
        #expect(src.contains("allowOverflowMarker"))
        #expect(src.contains("displayName(url.lastPathComponent)"))
        #expect(!src.contains(".buttonStyle(.plain)"))
        #expect(!src.contains(".buttonStyle(.borderless)"))
    }

    @Test("the button is mounted in the notes sidebar")
    func mountedInSidebar() throws {
        let sidebar = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        #expect(sidebar.contains("LiteParsePDFImportButton()"))
    }
}
