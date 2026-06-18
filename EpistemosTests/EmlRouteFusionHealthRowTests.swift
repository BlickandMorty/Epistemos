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
        #expect(src.contains("EPISTEMOS_EML_ROUTE_V1"))
    }

    @Test("the row honestly states the primitive is NOT yet live")
    func rowIsHonestAboutNotLive() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/EmlRouteFusionHealthRow.swift"
        )
        // ConfidenceRouter.route() is legacy/uncalled; the row must NOT claim a
        // live routing behavior. It says "armed (not yet live)" / "not yet
        // wired", and names the real live seam (TriageService).
        #expect(src.contains("not yet live") || src.contains("not yet wired") || src.contains("NOT yet wired"))
        #expect(src.contains("TriageService"))
        // It must NOT claim local-vs-cloud routing actively fuses (the dead path).
        #expect(!src.contains("Local-vs-cloud routing fuses"))
    }

    @Test("the row is surfaced in the Substrate Health panel")
    func rowIsSurfaced() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthPanel.swift"
        )
        #expect(src.contains("EmlRouteFusionHealthRow()"))
    }
}
