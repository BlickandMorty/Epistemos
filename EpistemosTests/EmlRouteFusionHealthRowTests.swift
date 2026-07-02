import Testing
import Foundation

/// P5.H A1 (EML-2, visible determinism) — the retired route-fusion row must not
/// reappear as a dead local-vs-cloud router claim. The surviving EML surface is
/// the opt-in vault rerank status, pinned by EmlRerankGateStatusTests.
@Suite("EML route fusion health row")
struct EmlRouteFusionHealthRowTests {

    @Test("the retired route-fusion row stays absent")
    func retiredRouteFusionRowStaysAbsent() throws {
        let root = try sourceMirrorRootURL()
        let retiredRow = root.appendingPathComponent(
            "Epistemos/Views/Settings/EmlRouteFusionHealthRow.swift",
            isDirectory: false
        )

        #expect(!FileManager.default.fileExists(atPath: retiredRow.path))
    }

    @Test("the remaining EML row is rerank-only and opt-in")
    func remainingEMLRowIsRerankOnlyAndOptIn() throws {
        let row = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/EmlRerankGateHealthRow.swift"
        )
        let status = try loadMirroredSourceTextFile(
            "Epistemos/Engine/EmlRerankGateStatus.swift"
        )

        #expect(row.contains("EmlRerankGateStatus.status()"))
        #expect(status.contains("EPISTEMOS_EML_RERANK_V1"))
        #expect(status.contains("Off by default for zero behavior change until promoted."))
        #expect(!row.contains("Local-vs-cloud routing fuses"))
        #expect(!status.contains("Local-vs-cloud routing fuses"))
    }

    @Test("the retired row is not surfaced in the simplified foundation panel")
    func retiredRowIsNotSurfaced() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthPanel.swift"
        )
        #expect(!src.contains("EmlRouteFusionHealthRow()"))
        #expect(!src.contains("EmlObservatoryHealthRow()"))
    }
}
