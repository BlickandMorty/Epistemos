import Foundation
import GRDB
import Testing

@testable import Epistemos

@Suite("F-VaultRecall-50 RRF contract")
nonisolated struct FVaultRecall50RRFFusionTests {
    @Test("recency SQL uses true half-life decay")
    func recencySQLUsesTrueHalfLifeDecay() {
        #expect(RRFFusionQuery.sql.contains("-:recency_ln_2"))
        #expect(RRFFusionQuery.sql.contains("MAX(:now_unix - updated_at_unix, 0.0)"))
        #expect(RRFFusionQuery.sql.contains("/ MAX(:half_life_days, 0.000001)"))

        let oneHalfLifeRetention = exp(-Phase3FusionConsts.RECENCY_LN_2 * 30.0 / 30.0)
        #expect(abs(oneHalfLifeRetention - 0.5) < 0.000000000001,
                "30 days at a 30-day half-life must retain half the score; got \(oneHalfLifeRetention)")
    }

    @Test("RRF SQL projects source provenance flags")
    func rrfSQLProjectsSourceProvenanceFlags() {
        #expect(RRFFusionQuery.sql.contains("AS page_source_hit"))
        #expect(RRFFusionQuery.sql.contains("AS block_source_hit"))
        #expect(RRFFusionQuery.sql.contains("AS readable_block_source_hit"))
        #expect(RRFFusionQuery.sql.contains("AS display_title"))
    }

    @Test("fused result provenance summary is renderable")
    func fusedResultProvenanceSummaryIsRenderable() {
        let result = FusedResult(
            entityID: "page-provenance",
            entityKind: "page",
            parentDocID: "page-provenance",
            fusedScore: 0.42,
            bestSourceRank: 1,
            snippetBlockID: nil,
            snippet: "vault recall context",
            updatedAtUnix: 2_000_000,
            matchReasons: ["Page match", "Best source rank #1"]
        )

        #expect(result.provenanceSummary == "Page match, Best source rank #1")
        #expect(result.sourceHitCount == 1)
        #expect(result.confidenceBand == .medium)
        #expect(result.isContractSufficient)
    }

    @Test("low-confidence fused results are not contract sufficient")
    func lowConfidenceFusedResultsAreNotContractSufficient() {
        let result = FusedResult(
            entityID: "tail-hit",
            entityKind: "page",
            parentDocID: "tail-hit",
            fusedScore: 0.001,
            bestSourceRank: 80,
            snippetBlockID: nil,
            snippet: "weak tail hit",
            updatedAtUnix: nil,
            matchReasons: ["Page match", "Best source rank #80"],
            sourceHitCount: 1,
            confidenceBand: .low
        )

        #expect(!result.isContractSufficient)
        #expect(RRFFusionQuery.exactEscalationReasons(
            query: "rank only",
            results: [result]
        ).contains("top_hit_low_confidence"))
    }

    @Test("fused results without visible surface are not contract sufficient")
    func fusedResultsWithoutVisibleSurfaceAreNotContractSufficient() {
        let result = FusedResult(
            entityID: "hidden-page",
            entityKind: "page",
            parentDocID: "hidden-page",
            fusedScore: 0.42,
            bestSourceRank: 1,
            snippetBlockID: nil,
            snippet: nil,
            updatedAtUnix: nil,
            matchReasons: ["Page match", "Best source rank #1"],
            sourceHitCount: 1,
            confidenceBand: .high
        )

        #expect(!result.isContractSufficient)
        #expect(RRFFusionQuery.exactEscalationReasons(
            query: "rank only",
            results: [result]
        ).contains("top_hit_source_rank_only"))
        #expect(!result.hasVisibleEvidenceSurface)
        #expect(RRFFusionQuery.exactEscalationReasons(
            query: "hidden page",
            results: [result]
        ).contains("top_hit_evidence_hidden"))
    }

    @Test("source-rank-only fused results are not contract sufficient")
    func sourceRankOnlyFusedResultsAreNotContractSufficient() {
        let result = FusedResult(
            entityID: "rank-only",
            entityKind: "page",
            parentDocID: "rank-only",
            fusedScore: 0.42,
            bestSourceRank: 1,
            snippetBlockID: nil,
            snippet: nil,
            updatedAtUnix: nil,
            matchReasons: ["Best source rank #1"],
            sourceHitCount: 1,
            confidenceBand: .high
        )

        #expect(!result.isContractSufficient)
    }

    @Test("recency-only fused results are not contract sufficient")
    func recencyOnlyFusedResultsAreNotContractSufficient() {
        let result = FusedResult(
            entityID: "recency-only",
            entityKind: "page",
            displayTitle: "Recently Updated",
            parentDocID: "recency-only",
            fusedScore: 0.42,
            bestSourceRank: 1,
            snippetBlockID: nil,
            snippet: nil,
            updatedAtUnix: nil,
            matchReasons: ["Updated today"],
            sourceHitCount: 1,
            confidenceBand: .medium
        )
        let reasons = RRFFusionQuery.exactEscalationReasons(
            query: "recent update",
            results: [result]
        )

        #expect(!result.hasVisibleEvidenceReason)
        #expect(!result.hasSourceRankReason)
        #expect(!result.isContractSufficient)
        #expect(reasons.contains("no_contract_sufficient_results"))
        #expect(reasons.contains("top_hit_no_visible_evidence_reason"))
    }

    @Test("fused exact escalation explains weak or ambiguous evidence")
    func fusedExactEscalationExplainsWeakOrAmbiguousEvidence() {
        let reasons = RRFFusionQuery.exactEscalationReasons(
            query: "vault recall alpha",
            results: [
                FusedResult(
                    entityID: "rank-only",
                    entityKind: "page",
                    parentDocID: "rank-only",
                    fusedScore: 0.42,
                    bestSourceRank: 1,
                    snippetBlockID: nil,
                    snippet: nil,
                    updatedAtUnix: nil,
                    matchReasons: ["Best source rank #1"],
                    sourceHitCount: 1,
                    confidenceBand: .high
                ),
                FusedResult(
                    entityID: "runner-up",
                    entityKind: "page",
                    parentDocID: "runner-up",
                    fusedScore: 0.415,
                    bestSourceRank: 2,
                    snippetBlockID: nil,
                    snippet: "vault recall alpha",
                    updatedAtUnix: nil,
                    matchReasons: ["Page match", "Best source rank #2"],
                    sourceHitCount: 1,
                    confidenceBand: .high
                )
            ]
        )

        #expect(reasons.contains("top_hit_source_rank_only"))
        #expect(reasons.contains("top_hit_evidence_hidden"))
        #expect(reasons.contains("low_top_score_margin"))
    }

    @Test("fused search traces expose contract confidence counts")
    func fusedSearchTracesExposeContractConfidenceCounts() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Sync/SearchIndexService.swift")

        #expect(source.contains("fusedSearchCompletionPayload"))
        #expect(source.contains("\"contract_sufficient_count\""))
        #expect(source.contains("\"vault_context_contract_schema\""))
        #expect(source.contains("\"high_confidence_count\""))
        #expect(source.contains("\"medium_confidence_count\""))
        #expect(source.contains("\"low_confidence_count\""))
        #expect(source.contains("\"top_score_margin\""))
        #expect(source.contains("\"uses_current_contract_shape\""))
        #expect(source.contains("\"exact_escalation_target_limit\""))
        #expect(source.contains("\"exact_escalation_target_count\": exactEscalationTargets.count"))
        #expect(source.contains("\"exact_escalation_query_count_limit\""))
        #expect(source.contains("\"exact_escalation_snippet_char_limit\""))
        #expect(source.contains("\"exact_escalation_query_char_limit\""))
        #expect(source.contains("\"exact_escalation_query_count\": exactEscalationQueries.count"))
        #expect(source.contains("\"exact_escalation_required\""))
        #expect(source.contains("\"exact_escalation_reasons\""))
        #expect(source.contains("\"exact_escalation_targets\""))
        #expect(source.contains("\"exact_escalation_queries\""))
        #expect(source.contains("SearchFusionMetrics.vaultContextContractSchema"))
        #expect(source.contains("SearchFusionMetrics.exactEscalationTargetLimit"))
        #expect(source.contains("SearchFusionMetrics.exactEscalationQueryCountLimit"))
        #expect(source.contains("SearchFusionMetrics.exactEscalationSnippetCharLimit"))
        #expect(source.contains("SearchFusionMetrics.exactEscalationQueryCharLimit"))
        #expect(source.contains("fusedSearchUsesCurrentContractShape"))
        #expect(source.contains("exactEscalationTargetCount: escalationMetrics.targetCount"))
        #expect(source.contains("exactEscalationQueryCount: escalationMetrics.queryCount"))
        #expect(source.contains("metadata[\"contract_sufficient_count\"]"))
        #expect(source.contains("metadata[\"vault_context_contract_schema\"]"))
        #expect(source.contains("metadata[\"high_confidence_count\"]"))
        #expect(source.contains("metadata[\"low_confidence_count\"]"))
        #expect(source.contains("metadata[\"medium_confidence_count\"]"))
        #expect(source.contains("metadata[\"top_score_margin\"]"))
        #expect(source.contains("metadata[\"uses_current_contract_shape\"]"))
        #expect(source.contains("metadata[\"exact_escalation_required\"]"))
        #expect(source.contains("metadata[\"exact_escalation_reasons\"]"))
        #expect(source.contains("metadata[\"exact_escalation_query_count\"]"))
        #expect(source.contains("metadata[\"exact_escalation_target_count\"]"))
        #expect(source.contains("metadata[\"exact_escalation_target_limit\"]"))
        #expect(source.contains("metadata[\"exact_escalation_query_count_limit\"]"))
        #expect(source.contains("metadata[\"exact_escalation_snippet_char_limit\"]"))
        #expect(source.contains("metadata[\"exact_escalation_query_char_limit\"]"))
    }

    @Test("fused exact escalation targets normalize visible snippet hints")
    func fusedExactEscalationTargetsNormalizeVisibleSnippetHints() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Sync/SearchIndexService.swift")

        #expect(source.contains("private nonisolated static func trimmedEscalationSnippet"))
        #expect(source.contains("target[\"display_title\"] = displayTitle"))
        #expect(source.contains("target[\"snippet\"] = snippet"))
        #expect(source.contains("target[\"match_keys\"] = matchKeys"))
        #expect(source.contains("private nonisolated static func exactEscalationTargetMatchKeys"))
        #expect(source.contains("appendExactEscalationQuery(&matchKeys, result.displayTitle)"))
        #expect(source.contains("appendExactEscalationQuery(&matchKeys, result.parentDocID)"))
        #expect(source.contains("appendExactEscalationQuery(&matchKeys, result.entityID)"))
        #expect(source.contains("replacingOccurrences(of: \"<b>\", with: \"\")"))
        #expect(source.contains("replacingOccurrences(of: \"</b>\", with: \"\")"))
        #expect(source.contains("replacingOccurrences(of: \"…\", with: \" \")"))
        #expect(source.contains("String(trimmed.prefix(SearchFusionMetrics.exactEscalationSnippetCharLimit))"))
    }

    @Test("fused exact escalation emits bounded deduped query candidates")
    func fusedExactEscalationEmitsBoundedDedupedQueryCandidates() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Sync/SearchIndexService.swift")

        #expect(source.contains("fusedSearchExactEscalationQueries"))
        #expect(source.contains("appendExactEscalationQuery(&queries, query)"))
        #expect(source.contains("Self.fusedSearchCompletionPayload(\n                    query: query,"))
        #expect(source.contains("Self.fusedSearchCompletionMetadata(\n                baseMetadata: baseMetadata,\n                query: query,"))
        #expect(!source.contains("Self.fusedSearchCompletionPayload(\n                    query: sanitized,"))
        #expect(!source.contains("Self.fusedSearchCompletionMetadata(\n                baseMetadata: baseMetadata,\n                query: sanitized,"))
        #expect(source.contains("appendExactEscalationQuery(&queries, result.displayTitle)"))
        #expect(source.contains("appendExactEscalationQuery(&queries, result.parentDocID)"))
        #expect(source.contains("appendExactEscalationQuery(&queries, result.entityID)"))
        #expect(source.contains("appendExactEscalationQuery(&queries, result.snippet)"))
        #expect(source.contains("replacingOccurrences(of: \"<b>\", with: \"\")"))
        #expect(source.contains("replacingOccurrences(of: \"</b>\", with: \"\")"))
        #expect(source.contains("replacingOccurrences(of: \"…\", with: \" \")"))
        #expect(source.contains("split(whereSeparator: { $0.isWhitespace })"))
        #expect(source.contains("String(trimmed.prefix(SearchFusionMetrics.exactEscalationQueryCharLimit))"))
        #expect(source.contains("options: [.caseInsensitive]"))
    }

    @Test("search fusion metrics retain contract confidence counts")
    func searchFusionMetricsRetainContractConfidenceCounts() {
        SearchFusionMetrics.shared.reset()
        defer { SearchFusionMetrics.shared.reset() }

        SearchFusionMetrics.shared.record(
            latencyMs: 9.5,
            query: "grounded vault result",
            results: [
                FusedResult(
                    entityID: "grounded-page",
                    entityKind: "page",
                    parentDocID: "grounded-page",
                    fusedScore: 0.42,
                    bestSourceRank: 1,
                    snippetBlockID: nil,
                    snippet: "grounded vault result",
                    updatedAtUnix: nil,
                    matchReasons: ["Page match", "Best source rank #1"],
                    confidenceBand: .high
                ),
                FusedResult(
                    entityID: "rank-only-page",
                    entityKind: "page",
                    parentDocID: "rank-only-page",
                    fusedScore: 0.41,
                    bestSourceRank: 1,
                    snippetBlockID: nil,
                    snippet: nil,
                    updatedAtUnix: nil,
                    matchReasons: ["Best source rank #1"],
                    confidenceBand: .high
                ),
                FusedResult(
                    entityID: "tail-page",
                    entityKind: "page",
                    parentDocID: "tail-page",
                    fusedScore: 0.001,
                    bestSourceRank: 80,
                    snippetBlockID: nil,
                    snippet: nil,
                    updatedAtUnix: nil,
                    matchReasons: ["Page match", "Best source rank #80"],
                    confidenceBand: .low
                )
            ],
            exactEscalationTargetCount: 3,
            exactEscalationQueryCount: 7
        )

        let snapshot = SearchFusionMetrics.shared.snapshot()
        #expect(snapshot.contractSufficientCount == 1)
        #expect(snapshot.highConfidenceCount == 2)
        #expect(snapshot.mediumConfidenceCount == 0)
        #expect(snapshot.lowConfidenceCount == 1)
        #expect(abs((snapshot.topScoreMargin ?? 0) - 0.01) < 0.000001)
        #expect(snapshot.exactEscalationRequired)
        #expect(snapshot.exactEscalationReasons.contains("low_top_score_margin"))
        #expect(snapshot.exactEscalationTargetCount == 3)
        #expect(snapshot.exactEscalationQueryCount == 7)
        #expect(snapshot.vaultContextContractSchema == "vault_context_contract_2026_05_17")
        #expect(snapshot.exactEscalationTargetLimit == 5)
        #expect(snapshot.exactEscalationQueryCountLimit == 21)
        #expect(snapshot.exactEscalationSnippetCharLimit == 240)
        #expect(snapshot.exactEscalationQueryCharLimit == 160)
        #expect(snapshot.hasCurrentContractSchema)
        #expect(snapshot.capFieldsMatchContract)
        #expect(snapshot.countFieldsWithinContractBounds)
        #expect(snapshot.usesCurrentContractShape)
    }

    @Test("fused metrics reject no-visible-evidence top hits")
    func fusedMetricsRejectNoVisibleEvidenceTopHits() {
        SearchFusionMetrics.shared.reset()
        defer { SearchFusionMetrics.shared.reset() }

        SearchFusionMetrics.shared.record(
            latencyMs: 2.8,
            query: "recent update",
            results: [
                FusedResult(
                    entityID: "recency-only-page",
                    entityKind: "page",
                    displayTitle: "Recently Updated",
                    parentDocID: "recency-only-page",
                    fusedScore: 0.42,
                    bestSourceRank: 1,
                    snippetBlockID: nil,
                    snippet: nil,
                    updatedAtUnix: nil,
                    matchReasons: ["Updated today"],
                    confidenceBand: .medium
                )
            ],
            exactEscalationTargetCount: 1,
            exactEscalationQueryCount: 1
        )

        let snapshot = SearchFusionMetrics.shared.snapshot()
        #expect(snapshot.contractSufficientCount == 0)
        #expect(snapshot.mediumConfidenceCount == 1)
        #expect(snapshot.exactEscalationRequired)
        #expect(snapshot.exactEscalationReasons.contains("no_contract_sufficient_results"))
        #expect(snapshot.exactEscalationReasons.contains("top_hit_no_visible_evidence_reason"))
        #expect(!snapshot.exactEscalationReasons.contains("top_hit_source_rank_only"))
        #expect(snapshot.exactEscalationTargetCount == 1)
        #expect(snapshot.exactEscalationQueryCount == 1)
        #expect(snapshot.usesCurrentContractShape)
    }

    @Test("fused metrics error snapshots clear stale exact-escalation state")
    func fusedMetricsErrorSnapshotsClearStaleExactEscalationState() {
        SearchFusionMetrics.shared.reset()
        defer { SearchFusionMetrics.shared.reset() }

        SearchFusionMetrics.shared.record(
            latencyMs: 4.2,
            query: "ambiguous vault result",
            results: [
                FusedResult(
                    entityID: "grounded-page",
                    entityKind: "page",
                    parentDocID: "grounded-page",
                    fusedScore: 0.42,
                    bestSourceRank: 1,
                    snippetBlockID: nil,
                    snippet: "grounded vault result",
                    updatedAtUnix: nil,
                    matchReasons: ["Page match", "Best source rank #1"],
                    confidenceBand: .high
                )
            ],
            exactEscalationTargetCount: 3,
            exactEscalationQueryCount: 7
        )
        let successSnapshot = SearchFusionMetrics.shared.snapshot()
        #expect(!successSnapshot.exactEscalationRequired)
        #expect(successSnapshot.exactEscalationTargetCount == 0)
        #expect(successSnapshot.exactEscalationQueryCount == 0)

        SearchFusionMetrics.shared.recordError(NSError(
            domain: "FVaultRecall50",
            code: 1,
            userInfo: nil
        ))

        let snapshot = SearchFusionMetrics.shared.snapshot()
        #expect(snapshot.lastErrorDescription != nil)
        #expect(!snapshot.exactEscalationRequired)
        #expect(snapshot.exactEscalationReasons.isEmpty)
        #expect(snapshot.exactEscalationTargetCount == 0)
        #expect(snapshot.exactEscalationQueryCount == 0)
        #expect(snapshot.contractSufficientCount == 0)
        #expect(snapshot.highConfidenceCount == 0)
        #expect(snapshot.topScoreMargin == nil)
        #expect(snapshot.hitsBySource.isEmpty)
        #expect(snapshot.countFieldsWithinContractBounds)
        #expect(snapshot.usesCurrentContractShape)
    }

    @Test("fused metrics reject exact-query count overflow")
    func fusedMetricsRejectExactQueryCountOverflow() {
        SearchFusionMetrics.shared.reset()
        defer { SearchFusionMetrics.shared.reset() }

        SearchFusionMetrics.shared.record(
            latencyMs: 3.1,
            query: "ambiguous vault result",
            results: [
                FusedResult(
                    entityID: "weak-page",
                    entityKind: "page",
                    parentDocID: "weak-page",
                    fusedScore: 0.01,
                    bestSourceRank: 1,
                    snippetBlockID: nil,
                    snippet: nil,
                    updatedAtUnix: nil,
                    matchReasons: ["Best source rank #1"],
                    confidenceBand: .low
                )
            ],
            exactEscalationTargetCount: 1,
            exactEscalationQueryCount: SearchFusionMetrics.exactEscalationQueryCountLimit + 1
        )

        let snapshot = SearchFusionMetrics.shared.snapshot()
        #expect(snapshot.exactEscalationRequired)
        #expect(snapshot.exactEscalationQueryCount > snapshot.exactEscalationQueryCountLimit)
        #expect(!snapshot.countFieldsWithinContractBounds)
        #expect(!snapshot.usesCurrentContractShape)
    }

    @Test("fused metrics reject exact-target count overflow")
    func fusedMetricsRejectExactTargetCountOverflow() {
        SearchFusionMetrics.shared.reset()
        defer { SearchFusionMetrics.shared.reset() }

        SearchFusionMetrics.shared.record(
            latencyMs: 3.2,
            query: "ambiguous vault result",
            results: [
                FusedResult(
                    entityID: "weak-page",
                    entityKind: "page",
                    parentDocID: "weak-page",
                    fusedScore: 0.01,
                    bestSourceRank: 1,
                    snippetBlockID: nil,
                    snippet: nil,
                    updatedAtUnix: nil,
                    matchReasons: ["Best source rank #1"],
                    confidenceBand: .low
                )
            ],
            exactEscalationTargetCount: SearchFusionMetrics.exactEscalationTargetLimit + 1,
            exactEscalationQueryCount: 1
        )

        let snapshot = SearchFusionMetrics.shared.snapshot()
        #expect(snapshot.exactEscalationRequired)
        #expect(snapshot.exactEscalationTargetCount > snapshot.exactEscalationTargetLimit)
        #expect(!snapshot.countFieldsWithinContractBounds)
        #expect(!snapshot.usesCurrentContractShape)
    }

    @Test("recency half-life keeps exactly half the score at one half-life", .enabled(if: sqliteSupportsFTS5ForFusionTests()))
    func recencyHalfLifeKeepsHalfScoreAtOneHalfLife() throws {
        let queue = try Self.makeQueue()
        let updatedAt = Date(timeIntervalSince1970: 2_000_000)
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: [
                "page-half-life",
                "vault recall alpha",
                "vault recall alpha context",
                "vault",
                updatedAt.timeIntervalSince1970,
            ])
        }

        let freshScore = try Self.singleScore(
            query: "vault recall",
            now: updatedAt,
            in: queue
        )
        let agedScore = try Self.singleScore(
            query: "vault recall",
            now: updatedAt.addingTimeInterval(30 * 86_400),
            in: queue
        )

        let ratio = agedScore / freshScore
        #expect(ratio > 0.499 && ratio < 0.501,
                "30 days at a 30-day half-life must retain half the score; got ratio \(ratio)")
    }

    @Test("fused results carry source and rank provenance reasons", .enabled(if: sqliteSupportsFTS5ForFusionTests()))
    func fusedResultsCarryProvenanceReasons() throws {
        let queue = try Self.makeQueue()
        let updatedAt = Date(timeIntervalSince1970: 2_000_000)
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: [
                "page-provenance",
                "vault recall provenance",
                "vault recall context",
                "vault",
                updatedAt.timeIntervalSince1970,
            ])
            try db.execute(sql: """
                INSERT INTO indexed_blocks (block_id, page_id, content)
                VALUES (?, ?, ?)
            """, arguments: [
                "block-provenance",
                "page-provenance",
                "vault recall block context",
            ])
            try db.execute(sql: """
                INSERT INTO block_search(rowid, content)
                SELECT rowid, content
                FROM indexed_blocks
                WHERE block_id = ?
            """, arguments: ["block-provenance"])
        }

        let results = try queue.read { db in
            try RRFFusionQuery.execute(
                query: "vault recall",
                weights: FusionWeights(halfLifeDays: 30.0),
                now: updatedAt,
                in: db
            )
        }

        let first = try #require(results.first)
        #expect(first.matchReasons.contains("Page match"))
        #expect(first.matchReasons.contains("Block match"))
        #expect(first.matchReasons.contains("Best source rank #1"))
        #expect(first.matchReasons.contains("Updated today"))
        #expect(first.provenanceSummary.contains("Page match"))
        #expect(first.sourceHitCount == 2)
        #expect(first.confidenceBand == .high)
        #expect(first.isContractSufficient)
        #expect(first.displayTitle == "vault recall provenance")
    }

    private static func singleScore(
        query: String,
        now: Date,
        in queue: DatabaseQueue
    ) throws -> Double {
        try queue.read { db in
            let results = try RRFFusionQuery.execute(
                query: query,
                weights: FusionWeights(halfLifeDays: 30.0),
                now: now,
                in: db
            )
            #expect(results.count == 1)
            return try #require(results.first?.fusedScore)
        }
    }

    private static func makeQueue() throws -> DatabaseQueue {
        let queue = try DatabaseQueue(path: ":memory:")
        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE indexed_pages (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    body TEXT NOT NULL,
                    tags TEXT,
                    updatedAt REAL NOT NULL
                )
            """)
            try db.execute(sql: """
                CREATE VIRTUAL TABLE page_search USING fts5(
                    title, body, tags,
                    content='indexed_pages',
                    content_rowid='rowid',
                    tokenize='unicode61'
                )
            """)
            try db.execute(sql: """
                CREATE TRIGGER indexed_pages_ai AFTER INSERT ON indexed_pages BEGIN
                    INSERT INTO page_search(rowid, title, body, tags)
                    VALUES (new.rowid, new.title, new.body, new.tags);
                END
            """)
            try db.execute(sql: """
                CREATE TABLE indexed_blocks (
                    block_id TEXT PRIMARY KEY,
                    page_id TEXT NOT NULL,
                    content TEXT NOT NULL
                )
            """)
            try db.execute(sql: """
                CREATE VIRTUAL TABLE block_search USING fts5(
                    content,
                    content='indexed_blocks',
                    content_rowid='rowid',
                    tokenize='unicode61'
                )
            """)
            try db.execute(sql: """
                CREATE TABLE readable_blocks (
                    id INTEGER PRIMARY KEY,
                    artifact_id TEXT NOT NULL,
                    artifact_kind TEXT NOT NULL,
                    block_id TEXT NOT NULL,
                    block_kind TEXT NOT NULL,
                    title_path TEXT,
                    body TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
            """)
            try db.execute(sql: """
                CREATE VIRTUAL TABLE readable_blocks_fts USING fts5(
                    title_path,
                    body,
                    content='readable_blocks',
                    content_rowid='id',
                    tokenize='unicode61'
                )
            """)
        }
        return queue
    }
}
