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
        #expect(snapshot.routeProfiles.count == ConfidenceRouter.TaskClass.allCases.count)
        #expect(snapshot.constellationSummary.contains("task roles"))
        #expect(snapshot.constellationSummary.contains("idle unload 30s/deep"))
        #expect(snapshot.routePolicySummary.contains("task-class routes"))
        #expect(snapshot.routePolicySummary.contains("native grammar routes"))
        #expect(snapshot.hotRoleSummary.contains("Fast Chat"))
        #expect(snapshot.constellationRoles.first { $0.taskClass == .coding }?.primaryModelID == LocalTextModelID.qwen3Coder30BA3B4Bit.rawValue)
    }

    @Test("Active constellation snapshot marks hot warm cold states")
    func activeConstellationSnapshotMarksRuntimeStates() {
        let coder = LocalTextModelID.qwen3Coder30BA3B4Bit
        let chat = LocalTextModelID.qwen3_8B4Bit
        let toolCaller = LocalTextModelID.localAgent43_36B3Bit
        let roles = [
            LocalAgentDiagnostics.ConstellationRole(
                taskClass: .coding,
                primaryModelID: coder.rawValue,
                primaryModelName: coder.displayName,
                grammar: .qwenXML
            ),
            LocalAgentDiagnostics.ConstellationRole(
                taskClass: .fastChat,
                primaryModelID: chat.rawValue,
                primaryModelName: chat.displayName,
                grammar: .qwenXML
            ),
            LocalAgentDiagnostics.ConstellationRole(
                taskClass: .toolUse,
                primaryModelID: toolCaller.rawValue,
                primaryModelName: toolCaller.displayName,
                grammar: .hermesJSON
            ),
        ]

        let models = LocalAgentDiagnostics.activeConstellationModels(
            activeAgentModelID: coder.rawValue,
            activeChatModelID: chat.rawValue,
            latestRuntimeModelID: nil,
            installedModelIDs: [chat.rawValue],
            roles: roles,
            strictMaskingAvailable: false
        )

        #expect(models.first?.modelID == coder.rawValue)
        #expect(models.first { $0.modelID == coder.rawValue }?.state == .hot)
        #expect(models.first { $0.modelID == chat.rawValue }?.state == .warm)
        #expect(models.first { $0.modelID == toolCaller.rawValue }?.state == .cold)
        #expect(models.first { $0.modelID == coder.rawValue }?.schemaMode == "SOFT")
        #expect(models.first { $0.modelID == coder.rawValue }?.rolesSummary == "Coding")
    }
}
