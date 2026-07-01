import Foundation
import Testing
@testable import Epistemos

@Suite("Assistant response chrome diagnostics")
struct AssistantResponseChromeDiagnosticsTests {
    @Test("text export diagnostics redact external write failures")
    func textExportDiagnosticsRedactExternalWriteFailures() {
        let message = TextExportDiagnostics.externalFailureMessage(
            NSError(
                domain: "/Users/jojo/PrivateVault/export.swift",
                code: 5,
                userInfo: [
                    NSLocalizedDescriptionKey: "Could not write /Users/jojo/PrivateVault/answer.md"
                ]
            )
        )

        #expect(message.contains("Write failed"))
        #expect(message.contains("code=5"))
        #expect(message.count <= TextExportDiagnostics.maxFailureMessageCharacters)
        for forbidden in [
            "/Users/jojo",
            "PrivateVault",
            "export.swift",
            "answer.md",
        ] {
            #expect(!message.contains(forbidden))
        }

        let longFileName = String(repeating: "a", count: TextExportDiagnostics.maxFileNameCharacters + 32) + ".md"
        #expect(TextExportDiagnostics.displayFileName("  \(longFileName)\n").count == TextExportDiagnostics.maxFileNameCharacters)
    }

    @Test("assistant response chrome source does not expose raw export errors")
    func assistantResponseChromeSourceDoesNotExposeRawExportErrors() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Shared/AssistantResponseChrome.swift")

        #expect(source.contains("TextExportDiagnostics.externalFailureMessage(error)"))
        #expect(source.contains("TextExportDiagnostics.displayFileName(destination.lastPathComponent)"))
        #expect(source.contains("String(message.prefix(maxFailureMessageCharacters + 32))"))
        #expect(source.contains("String(domain.prefix(maxDomainCharacters + 32))"))
        #expect(!source.contains("error.localizedDescription"))
        #expect(!source.contains("String(describing: error)"))
    }
}
