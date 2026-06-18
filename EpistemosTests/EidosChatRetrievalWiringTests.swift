import Testing
import Foundation

/// OBS-1/OBS-3 (owner P5.H Eidos chat-wiring) — locks that the chat context
/// path runs a flag-gated Eidos retrieval so the "Retrieved by Eidos" panel
/// (EidosRetrievedSection, which reads EidosMetrics) goes live. The Eidos vault
/// index is already opened at bootstrap (EidosVaultBootstrapper.openProduction-
/// IndexIfReady); the missing link was that EidosBridge.search was never called
/// from chat. This guards the wiring + that it stays behind EPISTEMOS_EIDOS_V0
/// (default OFF → no behavior change).
@Suite("Eidos chat retrieval wiring")
struct EidosChatRetrievalWiringTests {

    @Test("buildContextAttachments runs a flag-gated Eidos retrieval")
    func eidosRetrievalIsWiredBehindFlag() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")

        // Flag-gated Eidos retrieval call.
        #expect(src.contains("if EidosFlags.isEnabled"))
        #expect(src.contains("EidosBridge.search(query: eidosQuery)"))

        // It lives inside the chat context-assembly path.
        guard let build = src.range(of: "func buildContextAttachments"),
              let eidos = src.range(of: "EidosBridge.search(query: eidosQuery)")
        else {
            Issue.record("expected buildContextAttachments + the Eidos search call to be present")
            return
        }
        #expect(build.upperBound <= eidos.lowerBound,
                "the Eidos retrieval is wired inside buildContextAttachments")
    }
}
