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
