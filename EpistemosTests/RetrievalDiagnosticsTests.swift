import Foundation
import Testing
@testable import Epistemos

@Suite("Retrieval diagnostics")
struct RetrievalDiagnosticsTests {
    @Test("retrieval diagnostics redact thrown error details")
    func retrievalDiagnosticsRedactThrownErrorDetails() {
        let error = NSError(
            domain: "NSCocoaErrorDomain\n/Users/jojo/PrivateVault",
            code: 513,
            userInfo: [
                NSLocalizedDescriptionKey: "/Users/jojo/PrivateVault/retrieval.swift failed"
            ]
        )

        let message = RetrievalDiagnostics.statusMessage(
            for: error,
            fallback: "Vault recall trace failed"
        )

        #expect(message.contains("Vault recall trace failed"))
        #expect(message.contains("domain=Error"))
        #expect(message.contains("code=513"))
        #expect(message.count <= RetrievalDiagnostics.maxStatusMessageCharacters)
        #expect(!message.contains("/Users/jojo"))
        #expect(!message.contains("PrivateVault"))
        #expect(!message.contains("retrieval.swift"))
    }

    @Test("retrieval surfaces do not publish raw thrown errors")
    func retrievalSurfacesDoNotPublishRawThrownErrors() throws {
        let diagnostics = try loadMirroredSourceTextFile("Epistemos/Engine/RetrievalDiagnostics.swift")
        #expect(diagnostics.contains("String(message.prefix(maxStatusMessageCharacters + 32))"))
        #expect(diagnostics.contains("String(domain.prefix(maxDomainCharacters + 32))"))

        let paths = [
            "Epistemos/Eidos/EidosBridge.swift",
            "Epistemos/Eidos/EidosWiring.swift",
            "Epistemos/FUlp/FUlpWiring.swift",
            "Epistemos/VaultRecall/VaultRecallWiring.swift",
        ]

        for path in paths {
            let source = try loadMirroredSourceTextFile(path)
            #expect(source.contains("RetrievalDiagnostics.statusMessage"))
            #expect(!source.contains("String(describing: error)"))
            #expect(!source.contains("error.localizedDescription"))
        }
    }

    @Test("Eidos bridge failures do not echo raw validation payloads")
    func eidosBridgeFailuresDoNotEchoRawValidationPayloads() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Eidos/EidosBridge.swift")

        #expect(!source.contains("validation JSON shape unrecognized: \\(raw)"))
        #expect(!source.contains("batch validation JSON shape unrecognized: \\(raw)"))
        #expect(!source.contains("bridgeFailure(String(describing: error))"))
        #expect(!source.contains("failed doc=\\(documentId"))
        #expect(!source.contains("failed query=\\\"\\(query"))
    }
}
