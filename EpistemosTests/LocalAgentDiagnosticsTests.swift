import Foundation
import Testing
@testable import Epistemos

@Suite("Local agent diagnostics")
struct LocalAgentDiagnosticsTests {
    @Test("Diagnostics counters persist per model and grammar")
    func diagnosticsCountersPersistPerModelAndGrammar() throws {
        let suiteName = "LocalAgentDiagnosticsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let modelID = LocalTextModelID.qwen3_8B4Bit.rawValue
        LocalAgentDiagnostics.record(
            .softGuidanceToolPlan,
            modelID: modelID,
            nativeGrammar: .qwenXML,
            defaults: defaults,
            now: Date(timeIntervalSince1970: 10)
        )
        LocalAgentDiagnostics.record(
            .toolParseFailure,
            modelID: modelID,
            nativeGrammar: .qwenXML,
            defaults: defaults,
            now: Date(timeIntervalSince1970: 20)
        )
        LocalAgentDiagnostics.record(
            .explicitToolRepair,
            modelID: LocalTextModelID.localAgent43_36B3Bit.rawValue,
            nativeGrammar: .hermesJSON,
            defaults: defaults,
            now: Date(timeIntervalSince1970: 30)
        )

        let snapshot = LocalAgentDiagnostics.snapshot(
            defaults: defaults,
            capturedAt: Date(timeIntervalSince1970: 40)
        )

        #expect(snapshot.modelCounters.count == 2)
        #expect(snapshot.totalSoftGuidanceToolPlans == 1)
        #expect(snapshot.totalToolParseFailures == 1)
        #expect(snapshot.totalExplicitToolRepairs == 1)
        #expect(snapshot.schemaDriftSummary.contains("2 events across 2 models"))
        #expect(snapshot.modelCounters.first { $0.modelID == modelID }?.grammar == .qwenXML)

        LocalAgentDiagnostics.clear(defaults: defaults)
        #expect(LocalAgentDiagnostics.snapshot(defaults: defaults).modelCounters.isEmpty)
    }

    @Test("Diagnostics snapshot exposes constellation route table")
    func diagnosticsSnapshotExposesConstellationRouteTable() {
        let snapshot = LocalAgentDiagnostics.snapshot()

        #expect(snapshot.constellationRoles.count == ConfidenceRouter.TaskClass.allCases.count)
        #expect(snapshot.constellationSummary.contains("task roles"))
        #expect(snapshot.hotRoleSummary.contains("Fast Chat"))
        #expect(snapshot.constellationRoles.first { $0.taskClass == .coding }?.primaryModelID == LocalTextModelID.qwen3Coder30BA3B4Bit.rawValue)
    }
}
