import Foundation
import Testing
@testable import Epistemos

@Suite("Phase 1.5 Scaffolding")
struct PhaseOneFiveScaffoldingTests {
    @Test("local guardrail scaffold stays deleted")
    func localGuardrailScaffoldStaysDeleted() throws {
        let url = try sourceMirrorURL(for: "Epistemos/Engine/LocalGuardrailScaffold.swift")
        #expect(!FileManager.default.fileExists(atPath: url.path),
                "LocalGuardrailScaffold was an unwired local-agent scaffold and must not be restored")
    }

    @Test("KAN pilot scaffold stays off the main path and disabled by default")
    func kanPilotScaffoldStaysOffMainPathAndDisabledByDefault() {
        let pilot = KANPilotScaffold()
        let result = pilot.evaluate(
            KANPilotRequest(
                objective: "Score these note links for novelty.",
                candidateIDs: ["note-a", "note-b", "note-c"]
            )
        )

        #expect(pilot.scope == .offMainPath)
        #expect(result.status == .disabled)
        #expect(result.hints.isEmpty)
    }
}
