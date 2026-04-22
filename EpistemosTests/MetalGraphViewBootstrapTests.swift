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

    @Test("startup refresh recommit snaps global camera")
    func startupRefreshRecommitSnapsGlobalCamera() {
        #expect(
            graphRecommitCameraAction(
                isPageMode: false,
                shouldSnapGlobalCamera: true
            ) == .snapGlobalFit
        )
    }

    @Test("ordinary global recommit keeps animated fit")
    func ordinaryGlobalRecommitKeepsAnimatedFit() {
        #expect(
            graphRecommitCameraAction(
                isPageMode: false,
                shouldSnapGlobalCamera: false
            ) == .animateGlobalFit
        )
    }

    @Test("page mode recommit still zooms close")
    func pageModeRecommitStillZoomsClose() {
        #expect(
            graphRecommitCameraAction(
                isPageMode: true,
                shouldSnapGlobalCamera: true
            ) == .pageModeCloseIn
        )
    }

    @Test("global default camera paths share the padded fit helper")
    func globalDefaultCameraPathsShareHelper() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Graph/MetalGraphView.swift")

        #expect(source.contains("applyDefaultGlobalCameraFrame(animated: false)"))
        #expect(source.contains("applyDefaultGlobalCameraFrame(animated: true)"))
        #expect(source.contains("GraphOverlayPhysicsPolicy.defaultGlobalCameraMagnification"))
    }

    @MainActor
    @Test("initial commit syncs mode and graph data versions")
    func initialCommitSyncsTrackedVersions() {
        let graphState = GraphState()
        graphState.modeVersion = 3
        graphState.graphDataVersion = 5

        let view = MetalGraphNSView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
        view.graphState = graphState

        view.commitGraphData()

        #expect(view.lastModeVersion == graphState.modeVersion)
        #expect(view.lastGraphDataVersion == graphState.graphDataVersion)
    }
}
