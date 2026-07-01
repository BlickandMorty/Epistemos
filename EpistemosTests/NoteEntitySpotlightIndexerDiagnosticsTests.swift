import Foundation
import Testing
@testable import Epistemos

@Suite("Note entity Spotlight diagnostics")
struct NoteEntitySpotlightIndexerDiagnosticsTests {
    @Test("Spotlight entity diagnostics redact thrown error details")
    func spotlightEntityDiagnosticsRedactThrownErrorDetails() {
        let error = NSError(
            domain: "CSSearchableIndexErrorDomain\n/Users/jojo/PrivateVault",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "/Users/jojo/PrivateVault/note.md indexing failed"
            ]
        )

        let message = NoteEntitySpotlightDiagnostics.logMessage(
            for: error,
            fallback: "indexAppEntities donation failed"
        )

        #expect(message.contains("indexAppEntities donation failed"))
        #expect(message.contains("domain=Error"))
        #expect(message.contains("code=1"))
        #expect(message.count <= NoteEntitySpotlightDiagnostics.maxLogMessageCharacters)
        #expect(!message.contains("/Users/jojo"))
        #expect(!message.contains("PrivateVault"))
        #expect(!message.contains("note.md"))
    }

    @Test("Spotlight entity logs route through redacted diagnostics")
    func spotlightEntityLogsRouteThroughRedactedDiagnostics() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Sync/NoteEntitySpotlightIndexer.swift")

        #expect(source.contains("NoteEntitySpotlightDiagnostics.logMessage"))
        #expect(source.contains("String(message.prefix(maxLogMessageCharacters + 32))"))
        #expect(source.contains("String(domain.prefix(maxDomainCharacters + 32))"))
        #expect(!source.contains("error.localizedDescription"))
        #expect(!source.contains("String(describing: error)"))
    }
}
