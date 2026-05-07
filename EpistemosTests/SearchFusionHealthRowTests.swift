import Foundation
import Testing

@testable import Epistemos

@Suite("Search Fusion Health Row")
struct SearchFusionHealthRowTests {
    @Test("Search Fusion Health row is mounted in Settings diagnostics")
    func searchFusionHealthRowIsMountedInSettings() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settings.contains("SearchFusionHealthRow()"))
        #expect(settings.contains("Search Fusion shows live latency + per-source hit distribution"))
        #expect(!settings.contains("setenv(\"EPISTEMOS_RRF_FUSION_V1\""))
    }

    @Test("Search Fusion Health row is read-only and event-driven")
    func searchFusionHealthRowIsReadOnlyAndEventDriven() throws {
        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SearchFusionHealthRow.swift")
        let metrics = try loadMirroredSourceTextFile("Epistemos/Sync/RRFFusionQuery.swift")

        #expect(row.contains("SearchFusionMetrics.shared.snapshot()"))
        #expect(row.contains("SearchFusionMetrics.didChangeNotification"))
        #expect(row.contains(".onReceive(NotificationCenter.default.publisher("))
        #expect(row.contains("Task { @MainActor in"))
        #expect(metrics.contains("didChangeNotification"))
        #expect(metrics.contains("NotificationCenter.default.post("))
        #expect(!row.contains("Button("))
        #expect(!row.contains(".task {"))
        #expect(!row.contains("while !Task.isCancelled"))
        #expect(!row.contains("Timer"))
        #expect(!row.contains("DispatchSourceTimer"))
        #expect(!row.contains("repeatForever"))
    }

    @Test("Search Fusion metrics summarize latency, hits, and errors")
    func searchFusionMetricsSummarizeLatencyHitsAndErrors() {
        SearchFusionMetrics.shared.reset()
        defer { SearchFusionMetrics.shared.reset() }

        SearchFusionMetrics.shared.record(
            latencyMs: 12.5,
            results: [
                result(kind: "page", id: "page-1"),
                result(kind: "block", id: "block-1"),
                result(kind: "page", id: "page-2"),
            ]
        )

        var snapshot = SearchFusionMetrics.shared.snapshot()
        #expect(snapshot.totalQueries == 1)
        #expect(snapshot.sampleCount == 1)
        #expect(snapshot.lastLatencyMs == 12.5)
        #expect(snapshot.p95LatencyMs == 12.5)
        #expect(snapshot.hitsBySource["page"] == 2)
        #expect(snapshot.hitsBySource["block"] == 1)
        #expect(snapshot.lastErrorDescription == nil)

        SearchFusionMetrics.shared.recordError(ProbeError())

        snapshot = SearchFusionMetrics.shared.snapshot()
        #expect(snapshot.lastErrorDescription == "probe failure")
        #expect(snapshot.lastErrorAt != nil)
    }

    @Test("Search Fusion metrics publish change notifications")
    func searchFusionMetricsPublishChangeNotifications() {
        SearchFusionMetrics.shared.reset()
        defer { SearchFusionMetrics.shared.reset() }

        let counter = NotificationCounter()
        let token = NotificationCenter.default.addObserver(
            forName: SearchFusionMetrics.didChangeNotification,
            object: SearchFusionMetrics.shared,
            queue: nil
        ) { _ in
            counter.increment()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        SearchFusionMetrics.shared.record(latencyMs: 7, results: [result(kind: "readable_block", id: "r-1")])
        SearchFusionMetrics.shared.recordError(ProbeError())

        #expect(counter.count() == 2)
    }

    private func result(kind: String, id: String) -> FusedResult {
        FusedResult(
            entityID: id,
            entityKind: kind,
            parentDocID: id,
            fusedScore: 1,
            bestSourceRank: 1,
            snippetBlockID: nil,
            snippet: "snippet",
            updatedAtUnix: 1
        )
    }
}

private struct ProbeError: Error, CustomStringConvertible {
    var description: String { "probe failure" }
}

private nonisolated final class NotificationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        value += 1
    }

    func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
