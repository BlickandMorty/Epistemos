import Testing
import Foundation

/// P5.H A1 (EML-2, visible determinism) — locks that the route-fusion health
/// surface reads the SAME function the ConfidenceRouter consults
/// (`emlRouteFusionEnabled`), so the row can never claim a fusion the router
/// isn't applying. The flag truth table itself is locked in EmlRouteFusionTests.
@Suite("EML route fusion health row")
struct EmlRouteFusionHealthRowTests {

    @Test("the row reads the router's own flag function (single source of truth)")
    func rowReadsRouterFlag() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/EmlRouteFusionHealthRow.swift"
        )
        // It must consult the router's emlRouteFusionEnabled(), not a private
        // re-read of the env var — keeps the surface honest to the runtime.
        #expect(src.contains("ConfidenceRouter.emlRouteFusionEnabled()"))
        // Honest ON/off copy so the owner can see the state.
        #expect(src.contains("EML route fusion: ON"))
        #expect(src.contains("EPISTEMOS_EML_ROUTE_V1"))
    }

    @Test("the row is surfaced in the Substrate Health panel")
    func rowIsSurfaced() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthPanel.swift"
        )
        #expect(src.contains("EmlRouteFusionHealthRow()"))
    }
}
