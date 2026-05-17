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

    @Test("fused search traces expose contract confidence counts")
    func fusedSearchTracesExposeContractConfidenceCounts() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Sync/SearchIndexService.swift")

        #expect(source.contains("fusedSearchCompletionPayload"))
        #expect(source.contains("\"contract_sufficient_count\""))
        #expect(source.contains("\"high_confidence_count\""))
        #expect(source.contains("\"medium_confidence_count\""))
        #expect(source.contains("\"low_confidence_count\""))
        #expect(source.contains("metadata[\"contract_sufficient_count\"]"))
        #expect(source.contains("metadata[\"low_confidence_count\"]"))
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
