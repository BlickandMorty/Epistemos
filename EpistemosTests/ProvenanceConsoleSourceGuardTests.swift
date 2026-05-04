import Foundation
import Testing
@testable import Epistemos

@Suite("Provenance Console source guards")
struct ProvenanceConsoleSourceGuardTests {
    @Test("Provenance Console doctrine lives in fusion and names the four planes")
    func doctrineLivesInFusionAndNamesFourPlanes() throws {
        let doctrine = try loadMirroredSourceTextFile("docs/fusion/PROVENANCE_CONSOLE_DOCTRINE_2026_05_04.md")

        for phrase in [
            "RunEventLog",
            "MutationEnvelope",
            "AgentEvent",
            "GraphEvent",
            "GenUIDispatcher",
            "read-only projection",
            "MAS feature trio",
        ] {
            #expect(doctrine.contains(phrase), "Doctrine must contain \(phrase)")
        }
    }

    @Test("EventStore exposes bounded recent AgentEvent projection reads")
    func eventStoreExposesBoundedRecentAgentEventProjectionReads() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/State/EventStore.swift")
        let projectionReader = try context(
            around: "nonisolated func recentAgentEvents(limit: Int = 100) -> [AgentProvenanceEvent]",
            in: source,
            followingLines: 32
        )

        #expect(projectionReader.contains("Self.agentEventReadLimitMaximum"))
        #expect(projectionReader.contains("ORDER BY occurred_at DESC, sequence DESC, id DESC"))
        #expect(projectionReader.contains("return Array(events.reversed())"))
        assertForbiddenTokensAbsent(
            [
                "saveAgentEvent(",
                "saveMutationEnvelope",
                "saveGraphEvent(",
                "insertGraphEvent",
                "claimMutationProjectionOutboxRows(",
                "markMutationProjectionOutboxProjected(",
                "recordMutationProjectionOutboxFailure(",
                "DispatchSourceTimer",
                "repeatForever",
            ],
            in: projectionReader,
            label: "EventStore.recentAgentEvents"
        )
    }

    @Test("Provenance Console projection is GenUI-first and read-only")
    func projectionIsGenUIFirstAndReadOnly() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/ProvenanceConsoleProjectionService.swift")

        #expect(source.contains("func snapshot(limit: Int = 40) -> ProvenanceConsoleSnapshot"))
        #expect(source.contains("eventStore.recentAgentEvents(limit: limit)"))
        #expect(source.contains("eventStore.recentGraphEvents(limit: limit)"))
        #expect(source.contains("GenUIPayload.provenanceTrace("))
        assertForbiddenTokensAbsent(
            [
                "saveAgentEvent(",
                "saveMutationEnvelope",
                "saveGraphEvent(",
                "claimMutationProjectionOutboxRows(",
                "markMutationProjectionOutboxProjected(",
                "recordMutationProjectionOutboxFailure(",
                "Button(role: .destructive)",
                "Timer",
                "DispatchSourceTimer",
                "repeatForever",
            ],
            in: source,
            label: "ProvenanceConsoleProjectionService"
        )
    }

    @Test("Settings mounts a read-only Provenance Console routed through GenUIDispatcher")
    func settingsMountsReadOnlyProvenanceConsole() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let view = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ProvenanceConsoleView.swift")
        let dispatcher = try loadMirroredSourceTextFile("Epistemos/Engine/GenUIDispatcher.swift")

        #expect(settings.contains("case provenance = \"Provenance Console\""))
        #expect(settings.contains("case .provenance: ProvenanceConsoleView()"))
        #expect(view.contains("ProvenanceConsoleProjectionService().snapshot(limit: 40)"))
        #expect(view.contains("GenUIDispatcher.shared.render(payload)"))
        #expect(view.contains(".onAppear { refresh() }"))
        #expect(dispatcher.contains("ProvenanceTraceGenUIView(payload: payload)"))
        assertForbiddenTokensAbsent(
            [
                "Button(role: .destructive)",
                "saveAgentEvent(",
                "saveMutationEnvelope",
                "saveGraphEvent(",
                "claimMutationProjectionOutboxRows(",
                "markMutationProjectionOutboxProjected(",
                "recordMutationProjectionOutboxFailure(",
                "Timer",
                "DispatchSourceTimer",
                "repeatForever",
            ],
            in: view,
            label: "ProvenanceConsoleView"
        )
    }

    private func context(
        around marker: String,
        in source: String,
        followingLines: Int
    ) throws -> String {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { $0.contains(marker) }) else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSDebugDescriptionErrorKey: "Missing marker: \(marker)"])
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
