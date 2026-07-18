import Foundation
import GRDB
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 fusion-policy boundary tests must compile in the App Store target.")
#endif

@Suite("Free V1 fused retrieval policy boundary")
struct FreeV1FusionPolicyBoundaryTests {
    @Test("fused retrieval validates its bounded numeric policy before telemetry or SQLite")
    func fusedRetrievalPolicyIsValidatedAtEveryMappedBoundary() throws {
        let fusionQuery = try sourceText("Epistemos/Sync/RRFFusionQuery.swift")
        let searchIndex = try sourceText("Epistemos/Sync/SearchIndexService.swift")

        for requiredPolicyContract in [
            "enum FusionWeightsValidationError: Error, Equatable, Sendable",
            "static let maximumResultCount = 100",
            "static let maximumPerSourceResultCount = 200",
            "nonisolated func validated(now: Date) throws -> FusionWeights",
            "guard now.timeIntervalSince1970.isFinite else",
            "guard maxResults >= 1, maxResults <= Self.maximumResultCount else",
            "guard perSourceLimit >= maxResults,",
            "perSourceLimit <= Self.maximumPerSourceResultCount else",
            "try weights.validated(now: now)",
            "static func bindArguments("
        ] {
            #expect(fusionQuery.contains(requiredPolicyContract))
        }

        #expect(!fusionQuery.contains("public static func bindArguments("))

        let syncBody = try section(
            in: searchIndex,
            from: "nonisolated public func fusedSearch(",
            to: "    /// Async variant offloaded"
        )
        let asyncBody = try section(
            in: searchIndex,
            from: "public func fusedSearchAsync(",
            to: "    private nonisolated static func millisecondsSinceEpoch"
        )

        for body in [syncBody, asyncBody] {
            let validation = try #require(body.range(of: "let validatedWeights = try weights.validated(now: now)"))
            let signpost = try #require(body.range(of: "Sig.storage.beginInterval(\"fused_search\""))
            let normalizedTerms = try #require(body.range(of: "let terms = Self.normalizedSearchTerms(query)"))

            #expect(validation.lowerBound < signpost.lowerBound)
            #expect(validation.lowerBound < normalizedTerms.lowerBound)
            #expect(body.contains("weights: validatedWeights"))
            #expect(!body.contains("weights: weights"))
        }
    }

    @Test("fused per-source limits select explicit deterministic top-k rows")
    func fusedPerSourceLimitsOrderBeforeTruncation() throws {
        let fusionQuery = try sourceText("Epistemos/Sync/RRFFusionQuery.swift")
        let expectedContracts: [(text: String, count: Int)] = [
            (
                "ROW_NUMBER() OVER (ORDER BY bm25(page_search) ASC, indexed_pages.id ASC) AS rnk",
                2
            ),
            (
                "WHERE page_search MATCH :query\n            ORDER BY bm25(page_search) ASC, indexed_pages.id ASC\n            LIMIT :per_source_limit",
                2
            ),
            (
                "ROW_NUMBER() OVER (ORDER BY bm25(block_search) ASC, indexed_blocks.page_id ASC, indexed_blocks.block_id ASC) AS rnk",
                2
            ),
            (
                "WHERE block_search MATCH :query\n            ORDER BY bm25(block_search) ASC, indexed_blocks.page_id ASC, indexed_blocks.block_id ASC\n            LIMIT :per_source_limit",
                2
            ),
            (
                "ROW_NUMBER() OVER (ORDER BY bm25(readable_blocks_fts) ASC, readable_blocks.artifact_id ASC, readable_blocks.block_id ASC) AS rnk",
                1
            ),
            (
                "WHERE readable_blocks_fts MATCH :query\n            ORDER BY bm25(readable_blocks_fts) ASC, readable_blocks.artifact_id ASC, readable_blocks.block_id ASC\n            LIMIT :per_source_limit",
                1
            )
        ]

        for contract in expectedContracts {
            #expect(
                fusionQuery.components(separatedBy: contract.text).count - 1 == contract.count
            )
        }
        for unorderedLimit in [
            "WHERE page_search MATCH :query\n            LIMIT :per_source_limit",
            "WHERE block_search MATCH :query\n            LIMIT :per_source_limit",
            "WHERE readable_blocks_fts MATCH :query\n            LIMIT :per_source_limit"
        ] {
            #expect(!fusionQuery.contains(unorderedLimit))
        }
    }

    @Test("fused aggregation permits one ranked contribution per source/entity")
    func fusedAggregationDeduplicatesWithinEachSourceBeforeScoring() throws {
        let fusionQuery = try sourceText("Epistemos/Sync/RRFFusionQuery.swift")

        for requiredContract in [
            ("PARTITION BY source, entity_key\n                ORDER BY rnk ASC\n              ) AS source_rn", 1),
            ("PARTITION BY source, entity_id\n                ORDER BY rnk ASC\n              ) AS source_rn", 1),
            ("source_winners AS (", 2),
            ("FROM source_ranked\n            WHERE source_rn = 1", 2),
            ("FROM source_winners", 2)
        ] {
            #expect(
                fusionQuery.components(separatedBy: requiredContract.0).count - 1 == requiredContract.1
            )
        }

        #expect(!fusionQuery.contains("AS raw_fused_score\n            FROM unioned"))

        let mainQuery = try section(
            in: fusionQuery,
            from: "public static let sql: String = \"\"\"",
            to: "public static let pageBlockOnlySQL: String = \"\"\""
        )
        for requiredMainIdentityContract in [
            "('note:' || indexed_pages.id) AS entity_key",
            "('note:' || indexed_blocks.page_id) AS entity_key",
            "WHEN readable_blocks.artifact_kind = 'prose_note'",
            "THEN 'note:' || readable_blocks.artifact_id",
            "ELSE 'readable:' || readable_blocks.artifact_kind || ':' || readable_blocks.artifact_id",
            "PARTITION BY entity_key ORDER BY rnk ASC, source ASC",
            "MIN(rnk) OVER (PARTITION BY entity_key)",
            "MAX(updated_at_unix) OVER (PARTITION BY entity_key)",
            ") OVER (PARTITION BY entity_key)         AS raw_fused_score",
            "ORDER BY fused_score DESC, updated_at_unix DESC, entity_key ASC"
        ] {
            #expect(mainQuery.contains(requiredMainIdentityContract))
        }
        #expect(!mainQuery.contains("PARTITION BY entity_id"))
    }

    @Test("Swift fallback permits one ranked contribution per source/page")
    func fallbackFusionDeduplicatesEachSourceBeforeScoring() throws {
        let searchIndex = try sourceText("Epistemos/Sync/SearchIndexService.swift")
        let fallback = try section(
            in: searchIndex,
            from: "private nonisolated static func fusedSearchFallback(",
            to: "private nonisolated static func searchBlocksFallback("
        )

        for requiredContract in [
            "func sourceWinners<Result>(",
            "var seenPageIDs = Set<String>()",
            "guard seenPageIDs.insert(pageID(result)).inserted else { continue }",
            "for winner in sourceWinners(\n            try fusedSearchPagesFallback",
            "for winner in sourceWinners(\n            try fusedSearchBlocksFallback"
        ] {
            #expect(fallback.contains(requiredContract))
        }

        #expect(
            fallback.components(separatedBy: "sourceRank: winner.sourceRank").count - 1 == 2
        )
        #expect(!fallback.contains("for (offset, result) in try fusedSearchPagesFallback"))
        #expect(!fallback.contains("for (offset, result) in try fusedSearchBlocksFallback"))
    }

    @Test("fused policy rejects malformed numeric and work-budget inputs")
    func fusionPolicyRejectsMalformedNumericAndWorkBudgetInputs() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let validPolicy = FusionWeights(maxResults: 100, perSourceLimit: 200)
        #expect(try validPolicy.validated(now: now) == validPolicy)

        let invalidPolicies = [
            FusionWeights(pageWeight: -.infinity),
            FusionWeights(blockWeight: .nan),
            FusionWeights(universalWeight: 8.1),
            FusionWeights(halfLifeDays: .infinity),
            FusionWeights(halfLifeDays: 0.5),
            FusionWeights(maxResults: 0),
            FusionWeights(maxResults: -1),
            FusionWeights(maxResults: 101),
            FusionWeights(maxResults: .max),
            FusionWeights(maxResults: 50, perSourceLimit: 0),
            FusionWeights(maxResults: 50, perSourceLimit: 49),
            FusionWeights(maxResults: 50, perSourceLimit: 201),
            FusionWeights(maxResults: 50, perSourceLimit: .max),
        ]

        for policy in invalidPolicies {
            #expect(throws: FusionWeightsValidationError.self) {
                try policy.validated(now: now)
            }
        }

        let nonFiniteClock = Date(timeIntervalSince1970: .nan)
        #expect(throws: FusionWeightsValidationError.self) {
            try validPolicy.validated(now: nonFiniteClock)
        }
    }

    @Test("rejected fused policy leaves fusion metrics untouched")
    func rejectedFusedPolicyLeavesFusionMetricsUntouched() throws {
        let searchDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("free-v1-fusion-policy-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: searchDirectory) }

        let service = try SearchIndexService(
            databaseURL: searchDirectory.appendingPathComponent("search.sqlite")
        )
        SearchFusionMetrics.shared.reset()
        defer { SearchFusionMetrics.shared.reset() }

        #expect(throws: FusionWeightsValidationError.self) {
            try service.fusedSearch(query: "bounded-policy", weights: FusionWeights(maxResults: 0))
        }

        let metrics = SearchFusionMetrics.shared.snapshot()
        #expect(metrics.totalQueries == 0)
        #expect(metrics.lastErrorDescription == nil)
        #expect(metrics.lastErrorAt == nil)
    }

    @Test("normal and FTS-unavailable fusion share Unix recency semantics")
    func normalAndFallbackFusionUseConsistentRecencySemantics() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let weights = FusionWeights(
            pageWeight: 1,
            blockWeight: 1,
            universalWeight: 1,
            halfLifeDays: 1,
            maxResults: 5,
            perSourceLimit: 5
        )

        let fullFixture = try makeFusionFixture(now: now)
        defer { fullFixture.removeDatabase() }
        try assertNormalFusionContract(
            try fullFixture.service.fusedSearch(query: fullFixture.query, weights: weights, now: now),
            fixture: fullFixture,
            weights: weights,
            now: now
        )

        let twoSourceFixture = try makeFusionFixture(now: now)
        defer { twoSourceFixture.removeDatabase() }
        try await twoSourceFixture.service.databaseWriter().write { db in
            try db.execute(sql: "DROP TABLE readable_blocks_fts")
        }
        try assertNormalFusionContract(
            try twoSourceFixture.service.fusedSearch(
                query: twoSourceFixture.query,
                weights: weights,
                now: now
            ),
            fixture: twoSourceFixture,
            weights: weights,
            now: now
        )

        let fallbackFixture = try makeFusionFixture(now: now)
        defer { fallbackFixture.removeDatabase() }
        try await fallbackFixture.service.databaseWriter().write { db in
            try db.execute(sql: "DROP TABLE page_search")
            try db.execute(sql: "DROP TABLE block_search")
        }

        let syncFallback = try fallbackFixture.service.fusedSearch(
            query: fallbackFixture.query,
            weights: weights,
            now: now
        )
        let asyncFallback = try await fallbackFixture.service.fusedSearchAsync(
            query: fallbackFixture.query,
            weights: weights,
            now: now
        )
        #expect(syncFallback == asyncFallback)
        #expect(Set(syncFallback.map(\.entityID)).count == syncFallback.count)

        let oldPage = try #require(syncFallback.first { $0.entityID == fallbackFixture.oldPageID })
        let recentPage = try #require(syncFallback.first { $0.entityID == fallbackFixture.recentPageID })
        let oldBlock = try #require(syncFallback.first { $0.entityID == fallbackFixture.oldBlockPageID })
        let recentBlock = try #require(syncFallback.first { $0.entityID == fallbackFixture.recentBlockPageID })
        let orphanBlock = try #require(syncFallback.first { $0.entityID == fallbackFixture.orphanPageID })

        #expect(oldPage.updatedAtUnix == fallbackFixture.oldDate.timeIntervalSince1970)
        #expect(recentPage.updatedAtUnix == fallbackFixture.recentDate.timeIntervalSince1970)
        #expect(oldBlock.updatedAtUnix == fallbackFixture.oldDate.timeIntervalSince1970)
        #expect(recentBlock.updatedAtUnix == fallbackFixture.recentDate.timeIntervalSince1970)
        #expect(orphanBlock.updatedAtUnix == nil)
        #expect(recentPage.fusedScore > oldPage.fusedScore)
        #expect(recentBlock.fusedScore > oldBlock.fusedScore)
        #expect(recentPage.fusedScore > recentBlock.fusedScore)
        #expect(orphanBlock.fusedScore > recentBlock.fusedScore)

        #expect(
            abs(recentPage.fusedScore - expectedFusionScore(
                rank: 2,
                updatedAt: fallbackFixture.recentDate,
                weights: weights,
                now: now
            )) < 0.000_000_000_001
        )
        #expect(
            abs(recentBlock.fusedScore - expectedFusionScore(
                rank: 3,
                updatedAt: fallbackFixture.recentDate,
                weights: weights,
                now: now
            )) < 0.000_000_000_001
        )
        #expect(
            abs(orphanBlock.fusedScore - expectedFusionScore(
                rank: 2,
                updatedAt: nil,
                weights: weights,
                now: now
            )) < 0.000_000_000_001
        )

        let tiedWeights = FusionWeights(
            pageWeight: 0,
            blockWeight: 0,
            universalWeight: 1,
            halfLifeDays: 1,
            maxResults: 5,
            perSourceLimit: 5
        )
        let firstTieOrder = try fallbackFixture.service.fusedSearch(
            query: fallbackFixture.query,
            weights: tiedWeights,
            now: now
        )
        let secondTieOrder = try fallbackFixture.service.fusedSearch(
            query: fallbackFixture.query,
            weights: tiedWeights,
            now: now
        )
        #expect(firstTieOrder == secondTieOrder)
        #expect(firstTieOrder.map(\.entityID) == [
            fallbackFixture.recentBlockPageID,
            fallbackFixture.recentPageID,
            fallbackFixture.oldBlockPageID,
            fallbackFixture.oldPageID,
            fallbackFixture.orphanPageID,
        ])
    }

    private struct FusionFixture {
        let directory: URL
        let service: SearchIndexService
        let query: String
        let oldDate: Date
        let recentDate: Date
        let oldPageID = "a-old-page"
        let recentPageID = "z-recent-page"
        let oldBlockPageID = "a-old-block-page"
        let recentBlockPageID = "z-recent-block-page"
        let orphanPageID = "m-orphan-page"

        func removeDatabase() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func makeFusionFixture(now: Date) throws -> FusionFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("free-v1-fusion-recency-\(UUID().uuidString)", isDirectory: true)
        let oldDate = now.addingTimeInterval(-30 * 86_400)
        let recentDate = now.addingTimeInterval(-86_400)
        let fixture = FusionFixture(
            directory: directory,
            service: try SearchIndexService(databaseURL: directory.appendingPathComponent("search.sqlite")),
            query: "fallbackrecency\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))",
            oldDate: oldDate,
            recentDate: recentDate
        )

        try fixture.service.upsert(
            id: fixture.oldPageID,
            title: fixture.query,
            body: "equal lexical page evidence",
            tags: "",
            updatedAt: fixture.oldDate,
            notifyObservers: false
        )
        try fixture.service.upsert(
            id: fixture.recentPageID,
            title: fixture.query,
            body: "equal lexical page evidence",
            tags: "",
            updatedAt: fixture.recentDate,
            notifyObservers: false
        )
        try fixture.service.upsert(
            id: fixture.oldBlockPageID,
            title: "old block parent",
            body: "no page match",
            tags: "",
            updatedAt: fixture.oldDate,
            notifyObservers: false
        )
        try fixture.service.upsert(
            id: fixture.recentBlockPageID,
            title: "recent block parent",
            body: "no page match",
            tags: "",
            updatedAt: fixture.recentDate,
            notifyObservers: false
        )
        try fixture.service.replaceBlocksForPage(
            pageId: fixture.oldBlockPageID,
            blocks: [(blockId: "a-old-block", content: fixture.query)],
            notifyObservers: false
        )
        try fixture.service.replaceBlocksForPage(
            pageId: fixture.recentBlockPageID,
            blocks: [(blockId: "z-recent-block", content: fixture.query)],
            notifyObservers: false
        )
        try fixture.service.databaseWriter().write { db in
            try db.execute(
                sql: "INSERT INTO indexed_blocks (block_id, page_id, content) VALUES (?, ?, ?)",
                arguments: ["m-orphan-block", fixture.orphanPageID, fixture.query]
            )
        }
        return fixture
    }

    private func assertNormalFusionContract(
        _ results: [FusedResult],
        fixture: FusionFixture,
        weights: FusionWeights,
        now: Date
    ) throws {
        let oldPage = try #require(results.first { $0.entityID == fixture.oldPageID })
        let recentPage = try #require(results.first { $0.entityID == fixture.recentPageID })
        let oldBlock = try #require(results.first { $0.entityID == fixture.oldBlockPageID })
        let recentBlock = try #require(results.first { $0.entityID == fixture.recentBlockPageID })
        let orphanBlock = try #require(results.first { $0.entityID == fixture.orphanPageID })

        #expect(oldPage.updatedAtUnix == fixture.oldDate.timeIntervalSince1970)
        #expect(recentPage.updatedAtUnix == fixture.recentDate.timeIntervalSince1970)
        #expect(oldBlock.updatedAtUnix == fixture.oldDate.timeIntervalSince1970)
        #expect(recentBlock.updatedAtUnix == fixture.recentDate.timeIntervalSince1970)
        #expect(orphanBlock.updatedAtUnix == nil)
        #expect(recentPage.fusedScore > oldPage.fusedScore)
        #expect(recentBlock.fusedScore > oldBlock.fusedScore)
        #expect(orphanBlock.fusedScore > recentBlock.fusedScore)
        #expect(
            abs(oldPage.fusedScore - expectedFusionScore(
                rank: 1,
                updatedAt: fixture.oldDate,
                weights: weights,
                now: now
            )) < 0.000_000_000_001
        )
        #expect(
            abs(recentPage.fusedScore - expectedFusionScore(
                rank: 2,
                updatedAt: fixture.recentDate,
                weights: weights,
                now: now
            )) < 0.000_000_000_001
        )
        #expect(
            abs(oldBlock.fusedScore - expectedFusionScore(
                rank: 1,
                updatedAt: fixture.oldDate,
                weights: weights,
                now: now
            )) < 0.000_000_000_001
        )
        #expect(
            abs(recentBlock.fusedScore - expectedFusionScore(
                rank: 3,
                updatedAt: fixture.recentDate,
                weights: weights,
                now: now
            )) < 0.000_000_000_001
        )
        #expect(
            abs(orphanBlock.fusedScore - expectedFusionScore(
                rank: 2,
                updatedAt: nil,
                weights: weights,
                now: now
            )) < 0.000_000_000_001
        )
    }

    private func expectedFusionScore(
        rank: Int,
        updatedAt: Date?,
        weights: FusionWeights,
        now: Date
    ) -> Double {
        let rawScore = 1 / (Phase3FusionConsts.K_RRF + Double(rank))
        guard let updatedAt else { return rawScore }
        let ageDays = max(0, now.timeIntervalSince1970 - updatedAt.timeIntervalSince1970) / 86_400
        return rawScore * exp(-Phase3FusionConsts.RECENCY_LN_2 * ageDays / weights.halfLifeDays)
    }

    private func section(in source: String, from start: String, to end: String) throws -> String {
        let startRange = try #require(source.range(of: start))
        let endRange = try #require(source.range(of: end, range: startRange.upperBound..<source.endIndex))
        return String(source[startRange.lowerBound..<endRange.lowerBound])
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
