import Foundation
import Testing
@testable import Epistemos

@Suite("GraphEvent Consumer Projection Guards")
struct GraphEventConsumerProjectionGuardTests {
    @Test("EventStore projection consumer remains a bounded read-only fold")
    func eventStoreProjectionConsumerRemainsBoundedReadOnlyFold() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/State/EventStore.swift")
        let projectionConsumer = try context(
            around: "nonisolated func graphEventProjectionSnapshot(limit: Int = 100) -> DurableGraphProjectionSnapshot",
            in: source,
            followingLines: 5
        )

        #expect(projectionConsumer.contains("DurableGraphEventProjection.snapshot(from: recentGraphEvents(limit: limit))"))
        assertForbiddenTokensAbsent(
            [
                "saveGraphEvent(",
                "saveMutationEnvelope",
                "insertGraphEvent",
                "sqlite3_prepare_v2",
                "GraphEventAuditProjectionService",
                "GraphState",
                "GraphStore",
                "SearchIndexService",
                "DispatchSourceTimer",
                "repeatForever",
            ],
            in: projectionConsumer,
            label: "EventStore.graphEventProjectionSnapshot"
        )
    }

    @Test("audit projection service stays read-only and UI-free")
    func auditProjectionServiceStaysReadOnlyAndUIFree() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/GraphEventAuditProjectionService.swift")

        #expect(source.contains("typealias SnapshotProvider = @Sendable (Int) -> DurableGraphProjectionSnapshot"))
        #expect(source.contains("eventStoreProvider()?.graphEventProjectionSnapshot(limit: limit)"))
        #expect(source.contains("DurableGraphEventProjection.snapshot(from: [])"))
        #expect(source.contains("func auditReport(limit: Int = 100) -> GraphEventAuditProjectionReport"))
        assertForbiddenTokensAbsent(
            [
                "saveGraphEvent(",
                "saveMutationEnvelope",
                "recentGraphEvents(",
                "graphEvents(",
                "GraphState",
                "GraphStore",
                "SearchIndexService",
                "QueryRuntime",
                "HaloController",
                "TraceInspectorView",
                "GraphEventVisibilityRow",
                "Timer",
                "DispatchSourceTimer",
                "repeatForever",
                "while !Task.isCancelled",
                "Epistemos/Views/Graph",
                "graph-engine",
                "OpLog",
            ],
            in: source,
            label: "GraphEventAuditProjectionService"
        )
    }

    @Test("settings projection row stays appear-refresh only")
    func settingsProjectionRowStaysAppearRefreshOnly() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/GraphEventVisibilityRow.swift")

        #expect(source.contains(".onAppear { refresh() }"))
        #expect(source.contains("EventStore.shared?.graphEventProjectionSnapshot(limit: 100)"))
        #expect(source.contains("GraphEventAuditProjectionService().auditReport(limit: 100)"))
        #expect(source.contains("No projection snapshot yet"))
        #expect(source.contains("No audit projection report yet"))
        assertForbiddenTokensAbsent(
            [
                ".task",
                "Task {",
                "Task.detached",
                "Timer",
                "DispatchSourceTimer",
                "repeatForever",
                "while !Task.isCancelled",
                "saveGraphEvent(",
                "saveMutationEnvelope",
                "GraphState",
                "GraphStore",
                "SearchIndexService",
                "QueryRuntime",
                "HaloController",
                "TraceInspectorView",
                "Epistemos/Views/Graph",
                "repair",
            ],
            in: source,
            label: "GraphEventVisibilityRow"
        )
    }

    @Test("Halo projection ribbon stays panel-open read-only")
    func haloProjectionRibbonStaysPanelOpenReadOnly() throws {
        let controller = try loadMirroredSourceTextFile("Epistemos/Engine/HaloController.swift")
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Halo/ShadowPanelContent.swift")

        #expect(controller.contains("GraphProjectionReportProvider = @MainActor (Int) -> GraphEventAuditProjectionReport"))
        #expect(controller.contains("GraphEventAuditProjectionService().auditReport(limit: limit)"))
        #expect(controller.contains("private static let graphProjectionReportLimit = 100"))
        #expect(controller.contains("func refreshGraphProjectionReport(limit: Int = HaloController.graphProjectionReportLimit)"))
        #expect(controller.contains("refreshGraphProjectionReport()"))
        #expect(panel.contains("graphProjectionRibbon"))
        #expect(panel.contains("controller.graphProjectionReport"))
        #expect(panel.contains("Graph projection idle"))
        assertForbiddenTokensAbsent(
            [
                "saveGraphEvent(",
                "saveMutationEnvelope",
                "EventStore.shared",
                "GraphState",
                "GraphStore",
                "SearchIndexService",
                "QueryRuntime",
                "TraceInspectorView",
                "GraphEventVisibilityRow",
                "Timer",
                "DispatchSourceTimer",
                "repeatForever",
                "while !Task.isCancelled",
                "Epistemos/Views/Graph",
                "graph-engine",
                "OpLog",
            ],
            in: controller,
            label: "HaloController projection path"
        )
        assertForbiddenTokensAbsent(
            [
                "saveGraphEvent(",
                "saveMutationEnvelope",
                "EventStore",
                "GraphState",
                "GraphStore",
                "SearchIndexService",
                "QueryRuntime",
                "TraceInspectorView",
                "Timer",
                "DispatchSourceTimer",
                "repeatForever",
                "Task",
                "Epistemos/Views/Graph",
                "graph-engine",
                "OpLog",
            ],
            in: panel,
            label: "ShadowPanelContent projection ribbon"
        )
    }

    @Test("Trace Inspector and QueryRuntime projection consumers stay bounded and non-mutating")
    func traceInspectorAndQueryRuntimeProjectionConsumersStayBoundedAndNonMutating() throws {
        let traceInspector = try loadMirroredSourceTextFile("Epistemos/Views/Capture/TraceInspectorView.swift")
        let queryRuntime = try loadMirroredSourceTextFile("Epistemos/Engine/QueryRuntime.swift")

        #expect(traceInspector.contains("GraphEventAuditProjectionService().auditReport(limit: 100)"))
        #expect(traceInspector.contains("loadTask?.cancel()"))
        #expect(traceInspector.contains("Task.detached(priority: .utility)"))
        #expect(traceInspector.contains("guard !Task.isCancelled else { return }"))
        #expect(queryRuntime.contains("EPISTEMOS_GRAPH_EVENT_QUERY_PROJECTION_V1"))
        #expect(queryRuntime.contains("GraphEventProjectionHint.apply("))
        #expect(queryRuntime.contains("EventStore.shared?.graphEventProjectionSnapshot(limit: 100)"))
        #expect(queryRuntime.contains("GraphEventProjectionHint.emptySnapshot"))
        assertForbiddenTokensAbsent(
            [
                "saveGraphEvent(",
                "saveMutationEnvelope",
                "GraphState",
                "GraphStore",
                "SearchIndexService",
                "QueryRuntime",
                "HaloController",
                "GraphEventVisibilityRow",
                "Timer",
                "DispatchSourceTimer",
                "repeatForever",
                "Epistemos/Views/Graph",
                "graph-engine",
                "OpLog",
            ],
            in: traceInspector,
            label: "TraceInspectorView projection path"
        )
        assertForbiddenTokensAbsent(
            [
                "saveGraphEvent(",
                "saveMutationEnvelope",
                "GraphEventAuditProjectionService",
                "InstantRecallService",
                "MeaningAnchorService",
                "DispatchSourceTimer",
                "repeatForever",
                "Epistemos/Views/Graph",
                "graph-engine",
                "OpLog",
            ],
            in: queryRuntime,
            label: "QueryRuntime projection hint"
        )
    }

    private func context(
        around needle: String,
        in source: String,
        followingLines: Int
    ) throws -> String {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { $0.contains(needle) }) else {
            throw CocoaError(.coderReadCorrupt)
        }
        let end = min(lines.count, start + followingLines + 1)
        return lines[start..<end].joined(separator: "\n")
    }

    private func assertForbiddenTokensAbsent(
        _ tokens: [String],
        in source: String,
        label: String
    ) {
        for token in tokens {
            #expect(!source.contains(token), "\(label) must not contain \(token)")
        }
    }
}
