import Testing
@testable import Epistemos

@Suite("Cognitive DAG Visualizer Panel")
struct CognitiveDagVisualizerPanelTests {
    @Test("count rows sort by count descending then label and cap at five")
    func countRowsSortByCountThenLabelAndCapAtFive() {
        let rows = CognitiveDagVisualizerModel.sortedCountRows(
            [
                "claim": 2,
                "note": 9,
                "agent_trace": 4,
                "anchor": 4,
                "zero": 0,
                "witness": 7,
                "page_gather": 1,
            ]
        )

        #expect(rows.map(\.label) == ["note", "witness", "agent_trace", "anchor", "claim"])
        #expect(rows.map(\.count) == [9, 7, 4, 4, 2])
    }

    @Test("model projects substrate DAG counts without approximating values")
    func modelProjectsSubstrateDagCounts() {
        let dag = SubstrateHealthUnifiedSnapshot.CognitiveDagCounts(
            ffiReachable: true,
            nodeCount: 42,
            edgeCount: 17,
            schemaVersion: 3,
            merkleRootHex: "0123456789abcdef",
            nodeKindCounts: ["claim": 3, "note": 8],
            edgeKindCounts: ["supports": 5, "cites": 2],
            falsifier: "docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md",
            wRow: "W-26"
        )

        let model = CognitiveDagVisualizerModel(dag: dag)

        #expect(model.isReachable)
        #expect(model.nodeCount == 42)
        #expect(model.edgeCount == 17)
        #expect(model.schemaVersion == 3)
        #expect(model.merkleRootShort == "0123456789ab")
        #expect(model.nodeRows.map(\.label) == ["note", "claim"])
        #expect(model.edgeRows.map(\.label) == ["supports", "cites"])
    }

    @Test("panel is a throttled read-only FFI projection")
    func panelIsThrottledReadOnlyProjection() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Graph/CognitiveDagVisualizerPanel.swift"
        )

        #expect(source.contains("SubstrateHealthUnifiedClient.snapshot()"))
        #expect(source.contains("Task.sleep(for: .seconds(refreshInterval))"))
        #expect(source.contains("CognitiveDagVisualizerModel(dag: snapshot.cognitiveDagCounts)"))
        #expect(source.contains("if next != model"))
        #expect(!source.contains("TimelineView"))
        #expect(!source.contains("repeatForever"))
    }

    @Test("graph route mounts visualizer outside the Metal render loop")
    func graphRouteMountsVisualizerOutsideMetalRenderLoop() throws {
        let container = try loadMirroredSourceTextFile(
            "Epistemos/Views/Graph/GraphWorkspaceContainer.swift"
        )
        let metalGraph = try loadMirroredSourceTextFile(
            "Epistemos/Views/Graph/MetalGraphView.swift"
        )

        #expect(container.contains("graphCognitiveDagVisualizerLayer"))
        #expect(container.contains("if graphState.currentRoute.isCanvas"))
        #expect(container.contains("CognitiveDagVisualizerPanel(theme: theme)"))
        #expect(!metalGraph.contains("CognitiveDagVisualizerPanel"))
    }
}
