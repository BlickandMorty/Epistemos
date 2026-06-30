import Foundation
import Testing
@testable import Epistemos

@Suite("Engine log diagnostics")
struct EngineLogDiagnosticsTests {
    @Test("engine diagnostics redact thrown error details")
    func engineDiagnosticsRedactThrownErrorDetails() {
        let error = NSError(
            domain: "NSCocoaErrorDomain\n/Users/jojo/PrivateVault",
            code: 260,
            userInfo: [
                NSLocalizedDescriptionKey: "/Users/jojo/PrivateVault/knowledge_index.md missing"
            ]
        )

        let message = EngineLogDiagnostics.logMessage(
            for: error,
            fallback: "KnowledgeIndexBuilder: failed to write knowledge index"
        )

        #expect(message.contains("KnowledgeIndexBuilder: failed to write knowledge index"))
        #expect(message.contains("domain=Error"))
        #expect(message.contains("code=260"))
        #expect(message.count <= EngineLogDiagnostics.maxLogMessageCharacters)
        #expect(!message.contains("/Users/jojo"))
        #expect(!message.contains("PrivateVault"))
        #expect(!message.contains("knowledge_index.md"))
    }

    @Test("Dataview and KnowledgeIndex logs route through redacted diagnostics")
    func dataviewAndKnowledgeIndexLogsRouteThroughRedactedDiagnostics() throws {
        let dataview = try loadMirroredSourceTextFile("Epistemos/Engine/DataviewService.swift")
        let knowledgeIndex = try loadMirroredSourceTextFile("Epistemos/Engine/KnowledgeIndexBuilder.swift")

        for source in [dataview, knowledgeIndex] {
            #expect(source.contains("EngineLogDiagnostics.logMessage"))
            #expect(!source.contains("error.localizedDescription"))
            #expect(!source.contains("String(describing: error)"))
        }
    }

    @Test("engine persistence logs route through redacted diagnostics")
    func enginePersistenceLogsRouteThroughRedactedDiagnostics() throws {
        let paths = [
            "Epistemos/Engine/CapabilityManifestBuilder.swift",
            "Epistemos/Engine/MutationOpLogProjectionWorker.swift",
            "Epistemos/Engine/QuarantineArchive.swift",
        ]

        for path in paths {
            let source = try loadMirroredSourceTextFile(path)
            #expect(source.contains("EngineLogDiagnostics.logMessage"))
            #expect(!source.contains("error.localizedDescription"))
            #expect(!source.contains("String(describing: error)"))
        }
    }

    @Test("engine FFI fallback logs route through redacted diagnostics")
    func engineFFIFallbackLogsRouteThroughRedactedDiagnostics() throws {
        let paths = [
            "Epistemos/Engine/RustAnswerPacketProducerClient.swift",
            "Epistemos/Engine/RustProvenanceLedgerClient.swift",
            "Epistemos/Engine/RustCognitiveDagClient.swift",
            "Epistemos/Engine/ResonanceService.swift",
            "Epistemos/Engine/FSRSDecayState.swift",
        ]

        for path in paths {
            let source = try loadMirroredSourceTextFile(path)
            #expect(source.contains("EngineLogDiagnostics.logMessage"))
            #expect(!source.contains("String(describing: error)"))
            #expect(!source.contains("error.localizedDescription"))
        }
    }

    @Test("shadow service logs route through redacted diagnostics")
    func shadowServiceLogsRouteThroughRedactedDiagnostics() throws {
        let paths = [
            "Epistemos/Engine/ShadowIndexingService.swift",
            "Epistemos/Engine/ShadowSearchService.swift",
        ]

        for path in paths {
            let source = try loadMirroredSourceTextFile(path)
            #expect(source.contains("EngineLogDiagnostics.logMessage"))
            #expect(!source.contains("String(describing: error)"))
            #expect(!source.contains("error.localizedDescription"))
        }
    }
}
