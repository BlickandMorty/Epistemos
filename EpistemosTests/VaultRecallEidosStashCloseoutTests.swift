import Foundation
import Testing

@Suite("VaultRecall Eidos Stash Closeout")
struct VaultRecallEidosStashCloseoutTests {
    @Test("closeout records stale stash work as preserved not replayed")
    func closeoutRecordsStaleStashWorkAsPreservedNotReplayed() throws {
        let closeout = try loadMirroredSourceTextFile(
            "docs/audits/VAULT_RECALL_EIDOS_STASH_CLOSEOUT_2026_05_26.md"
        )
        let visibility = try loadMirroredSourceTextFile(
            "docs/audits/VAULT_RECALL_VISIBILITY_2026_05_24.md"
        )
        let blocker = try loadMirroredSourceTextFile(
            "docs/audits/VAULT_RECALL_VISIBILITY_BLOCKER_2026_05_24.md"
        )
        let livingIndex = try loadMirroredSourceTextFile(
            "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md"
        )

        #expect(closeout.contains("stash@{3}"))
        #expect(closeout.contains("chat/VaultRecall/Eidos slice of `stash@{6}`"))
        #expect(closeout.contains("closed for current product recovery"))
        #expect(closeout.contains("neither stash was popped, dropped, checked out, or bulk-applied"))
        #expect(visibility.contains("Terminal A's Eidos bridge is now present"))
        #expect(visibility.contains("F-VaultRecall-50"))
        #expect(visibility.contains("F-Eidos-Bridge-RoundTrip"))
        #expect(!visibility.contains("must still be run on M2 Pro for final acceptance"))
        #expect(blocker.contains("No stop-condition blocker remains"))
        #expect(livingIndex.contains("VaultRecall/Eidos visibility from `stash@{3}`"))
    }

    @Test("current product path evidence remains present")
    func currentProductPathEvidenceRemainsPresent() throws {
        let coordinator = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")
        let eventStore = try loadMirroredSourceTextFile("Epistemos/State/EventStore.swift")
        let messageBubble = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")
        let eidosBridge = try loadMirroredSourceTextFile("Epistemos/Eidos/EidosBridge.swift")
        let vaultTests = try loadMirroredSourceTextFile("EpistemosTests/VaultRecallWiringTests.swift")
        let eidosTests = try loadMirroredSourceTextFile("EpistemosTests/EidosBridgeProductionTests.swift")

        #expect(coordinator.contains("private func recordVaultRecallTrace("))
        #expect(coordinator.contains("VaultRecallTraceSink.shared.record("))
        #expect(coordinator.contains("EventStore.shared?.appendVaultRecallTrace("))
        #expect(eventStore.contains("vault_recall_trace"))
        #expect(messageBubble.contains("AnswerPacketBadge("))
        #expect(messageBubble.contains("VaultRecallProvenanceCard("))
        #expect(eidosBridge.contains("nonisolated public static func validateCitations("))
        #expect(vaultTests.contains("SearchIndexService production results emit real VaultRecall trace"))
        #expect(eidosTests.contains("SearchIndexService page upsert also feeds the production Eidos vault index"))
    }
}
