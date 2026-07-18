import Foundation
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 VaultRecall trace-removal tests must compile in the App Store target.")
#endif

@Suite("Free V1 local retrieval trace removal")
struct FreeV1VaultRecallTraceRemovalTests {
    @Test("active Free search owners retain retrieval but emit no VaultRecall traces")
    func freeSearchOwnersHaveNoVaultRecallTraceSurface() throws {
        let queryRuntime = try sourceText("Epistemos/Engine/QueryRuntime.swift")
        let searchIndex = try sourceText("Epistemos/Sync/SearchIndexService.swift")
        let vaultSync = try sourceText("Epistemos/Sync/VaultSyncService.swift")
        let vaultSyncFull = try #require(
            sourceSection(
                named: "func searchFull(query: String, limit: Int = 20) -> [SearchResult] {",
                in: vaultSync,
                endingBefore: "    func searchFullAsync(query: String, limit: Int = 20) async -> [SearchResult] {"
            )
        )
        let vaultSyncAsync = try #require(
            sourceSection(
                named: "func searchFullAsync(query: String, limit: Int = 20) async -> [SearchResult] {",
                in: vaultSync,
                endingBefore: "    /// Translate a `FusedResult`"
            )
        )

        for source in [queryRuntime, searchIndex, vaultSync] {
            #expect(!source.contains("VaultRecall"))
            #expect(!source.contains("recordProductionTrace"))
            #expect(!source.contains("installTraceProvider"))
        }
        #expect(!queryRuntime.contains("\\(query, privacy: .private)"))

        for retainedQueryRuntimeCall in [
            "Self.eidosPacket(query: checkedQuery, limit: checkedLimit)",
            "searchIndex.fusedSearch(",
            "searchIndex.search(query: checkedQuery, limit: checkedLimit)",
            "searchIndex.searchBlocks(query: checkedQuery, limit: checkedLimit)"
        ] {
            #expect(queryRuntime.contains(retainedQueryRuntimeCall))
        }
        for retainedSearchIndexContract in [
            "normalizedSearchTerms(_ raw: String)",
            "uniqueSearchTerms(",
            "sanitizeFTS5Query(_ raw: String)"
        ] {
            #expect(searchIndex.contains(retainedSearchIndexContract))
        }
        for retainedVaultSyncCall in [
            "svc.fusedSearch(",
            "svc.search(query: checkedQuery, limit: checkedLimit)",
            "svc.searchAsync(query: checkedQuery, limit: checkedLimit)"
        ] {
            #expect(vaultSync.contains(retainedVaultSyncCall))
        }
        try assertValidatedDispatch(
            in: vaultSyncFull,
            fusedCall: "svc.fusedSearch(",
            legacyCall: "svc.search(query: checkedQuery, limit: checkedLimit)"
        )
        try assertValidatedDispatch(
            in: vaultSyncAsync,
            fusedCall: "svc.fusedSearchAsync(",
            legacyCall: "svc.searchAsync(query: checkedQuery, limit: checkedLimit)"
        )
    }

    @Test("Contextual Shadows preserves local fallback recall without recording a trace")
    func contextualShadowsLocalFallbackHasNoTraceOrContentBearingErrorLog() throws {
        let source = try sourceText("Epistemos/State/ContextualShadowsState.swift")
        let fallback = try #require(
            sourceSection(
                named: "nonisolated private static func appSearchFallbackHits(",
                in: source,
                endingBefore: "    nonisolated static func recallQuery(from text: String) -> String {"
            )
        )

        for forbidden in [
            "VaultRecall",
            "vaultRecallTrace",
            "recordProductionTrace",
            "Date().timeIntervalSince(started)",
            "String(describing: error)"
        ] {
            #expect(!fallback.contains(forbidden))
        }
        for retainedFallbackContract in [
            "searchIndexService.searchAsync(",
            "Self.convert(raw: results, originDocId: originDocId)",
            "Self.rankedUniqueHits(",
            "instantRecall.searchAsync("
        ] {
            #expect(fallback.contains(retainedFallbackContract))
        }
    }

    private func sourceSection(named start: String, in source: String, endingBefore end: String) -> String? {
        guard let startRange = source.range(of: start),
              let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex) else {
            return nil
        }
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }

    private func assertValidatedDispatch(
        in source: String,
        fusedCall: String,
        legacyCall: String
    ) throws {
        let limitGuard = try #require(
            source.range(of: "guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit)")
        )
        let queryGuard = try #require(
            source.range(of: "guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query)")
        )

        for dispatch in [fusedCall, legacyCall] {
            let dispatchRange = try #require(source.range(of: dispatch))
            #expect(limitGuard.lowerBound < dispatchRange.lowerBound)
            #expect(queryGuard.lowerBound < dispatchRange.lowerBound)
        }
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
