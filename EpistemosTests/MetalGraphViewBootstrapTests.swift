import Testing
@testable import Epistemos

@Suite("Metal Graph View Bootstrap")
struct MetalGraphViewBootstrapTests {

    @Test("loaded but uncommitted graph bootstraps the first commit")
    func loadedGraphBootstrapsInitialCommit() {
        #expect(
            graphInitialRenderBootstrapState(
                isCommitted: false,
                isGraphLoaded: true
            ) == .bootstrapCommit
        )
    }

    @Test("unloaded graph waits instead of rendering or committing")
    func unloadedGraphWaitsForData() {
        #expect(
            graphInitialRenderBootstrapState(
                isCommitted: false,
                isGraphLoaded: false
            ) == .awaitingData
        )
    }

    @Test("committed graph renders normally")
    func committedGraphRendersNormally() {
        #expect(
            graphInitialRenderBootstrapState(
                isCommitted: true,
                isGraphLoaded: true
            ) == .renderCommittedGraph
        )
    }
}
