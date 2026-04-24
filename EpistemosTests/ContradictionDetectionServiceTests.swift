import Foundation
import Testing
@testable import Epistemos

@Suite("Contradiction Detection Service")
@MainActor
struct ContradictionDetectionServiceTests {
    @Test("unwired write resolutions do not mark contradictions resolved")
    func unwiredWriteResolutionsDoNotMarkResolved() async throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("contradiction-service-\(UUID().uuidString)", isDirectory: true)
        let memoryURL = vaultURL.appendingPathComponent("memory", isDirectory: true)
        try FileManager.default.createDirectory(at: memoryURL, withIntermediateDirectories: true)
        try """
        ## Project Status
        - The launch budget is 100 dollars.
        """.write(
            to: memoryURL.appendingPathComponent("knowledge.md"),
            atomically: true,
            encoding: .utf8
        )
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let registry = VaultRegistry()
        registry.register(identity: .personal, path: vaultURL)
        let service = ContradictionDetectionService(vaultRegistry: registry)

        let contradictions = await service.detectContradictions(
            incomingText: "The launch budget is 200 dollars.",
            in: .personal
        )

        let contradiction = try #require(contradictions.first)
        await service.resolveContradiction(contradiction, with: .acceptNew)

        #expect(service.pendingContradictions.contains { $0.id == contradiction.id })
        #expect(service.resolvedContradictions.isEmpty)
    }
}
