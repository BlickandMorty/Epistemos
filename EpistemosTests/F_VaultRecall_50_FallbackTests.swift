import Foundation
import Testing
@testable import Epistemos

struct FVaultRecall50FallbackTests {
    @Test("soft vault fallback searches a contract-sized candidate pool")
    func softVaultFallbackSearchesContractSizedCandidatePool() async {
        let now = Date()
        let manifest = VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 120,
            isInventoryComplete: true,
            entries: [],
            recentBodies: [],
            generatedAt: now
        )
        var requestedLimits: [Int] = []

        _ = await ChatCoordinator.buildIndexedVaultLookupFallbackAnswer(
            query: "What notes in my vault mention train?",
            manifest: manifest,
            limit: 3
        ) { _, limit in
            requestedLimits.append(limit)
            return []
        }

        #expect(requestedLimits == [50])
    }
}
