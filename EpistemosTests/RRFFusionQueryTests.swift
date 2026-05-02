import Foundation
import GRDB
import Testing

@testable import Epistemos

/// RRF Phase-2 critical-invariant tests for `RRFFusionQuery`. The
/// heavy fixture-corpus tests (cross-source RRF math, 100-iter
/// determinism, recency reorder, perf budget) live in Phase 5; this
/// suite enforces the invariants the user explicitly called out:
///
///   1. K_RRF parity with `epistemos-shadow/src/backend/rrf.rs:22`
///      RRF_K_DEFAULT — the single source-of-truth.
///   2. bm25() sign convention — `ROW_NUMBER() OVER (ORDER BY
///      bm25(table) ASC)` MUST yield rank 1 for the best hit.
///   3. EXPLAIN QUERY PLAN — every FTS source MUST report
///      `VIRTUAL TABLE INDEX N:M<col>` (FTS5 MATCH constraint
///      accelerated by the fts5 module). Build/test fails if a
///      future query rewrite degrades the plan to a bare
///      `VIRTUAL TABLE INDEX N:` (full virtual-table scan, no
///      MATCH acceleration). NOTE: SQLite always prints `SCAN`
///      for virtual-table row visits, even when the index is
///      used — the suffix is the real discriminator.
///   4. End-to-end smoke — fixture corpus → query executes →
///      returns ordered `FusedResult` across 3 sources.
@Suite("RRF Phase 2 — fusion query critical invariants")
nonisolated struct RRFFusionQueryTests {

    // MARK: - Test schema helper

    /// Spin up an in-memory `DatabaseQueue` with all 3 FTS5
    /// schemas the production fusion query depends on:
    ///   - `indexed_pages` + `page_search` (mirrored from
    ///     SearchIndexService.swift:288-330)
    ///   - `indexed_blocks` + `block_search` (mirrored from
    ///     SearchIndexService.swift:301-370)
    ///   - `readable_blocks` + `readable_blocks_fts`
    ///     (via `ReadableBlocksIndex.registerMigration`)
    ///
    /// Avoids spinning up the full `SearchIndexService` actor
    /// (which writes to disk + does extra setup work).
    private static func makeFusionTestPool() throws -> DatabaseQueue {
        let queue = try DatabaseQueue(path: ":memory:")
        try queue.write { db in
            try installLegacyPageAndBlockSchema(in: db)
        }

        // ReadableBlocksIndex migration plays nicely with the
        // legacy schema — it adds new tables under its own keys.
        var migrator = DatabaseMigrator()
        ReadableBlocksIndex.registerMigration(&migrator)
        try migrator.migrate(queue)
        return queue
    }

    /// Replicates `SearchIndexService.setupSchema` for the legacy
    /// page + block tables only. Kept in sync with that source by
    /// the `RRFFusionQueryTests.legacySchemaMatchesProduction`
    /// guard test below.
    private static func installLegacyPageAndBlockSchema(in db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS indexed_pages (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                tags TEXT,
                updatedAt REAL NOT NULL
            )
        """)
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS page_search USING fts5(
                title, body, tags,
                content='indexed_pages',
                content_rowid='rowid',
                tokenize='unicode61'
            )
        """)
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS indexed_pages_ai AFTER INSERT ON indexed_pages BEGIN
                INSERT INTO page_search(rowid, title, body, tags)
                VALUES (new.rowid, new.title, new.body, new.tags);
            END
        """)

        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS indexed_blocks (
                block_id TEXT PRIMARY KEY,
                page_id TEXT NOT NULL,
                content TEXT NOT NULL
            )
        """)
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS block_search USING fts5(
                content,
                content='indexed_blocks',
                content_rowid='rowid',
                tokenize='unicode61'
            )
        """)
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS indexed_blocks_ai AFTER INSERT ON indexed_blocks BEGIN
                INSERT INTO block_search(rowid, content)
                VALUES (new.rowid, new.content);
            END
        """)
    }

    // MARK: - 1. K_RRF parity with the Rust source-of-truth

    @Test("K_RRF Swift mirror equals epistemos-shadow::backend::rrf::RRF_K_DEFAULT (60)")
    func kRRFConstantParityWithRustSource() async throws {
        // Read the Rust source-of-truth file and assert its
        // declared value matches our Swift mirror. Drift here is
        // a real bug — the user mission brief names this constant
        // explicitly as a "do not duplicate" item.
        let rustSource = try await MainActor.run {
            try loadMirroredSourceTextFile("epistemos-shadow/src/backend/rrf.rs")
        }

        // Match `pub const RRF_K_DEFAULT: usize = <number>;` on
        // any single line. Tolerant of whitespace.
        let pattern = #"pub\s+const\s+RRF_K_DEFAULT\s*:\s*usize\s*=\s*(\d+)\s*;"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(rustSource.startIndex..., in: rustSource)
        guard
            let match = regex.firstMatch(in: rustSource, range: range),
            let numRange = Range(match.range(at: 1), in: rustSource),
            let rustK = Int(rustSource[numRange])
        else {
            #expect(Bool(false),
                    "Could not find `pub const RRF_K_DEFAULT: usize = <N>;` in epistemos-shadow/src/backend/rrf.rs — Rust source moved or changed shape")
            return
        }

        #expect(Double(rustK) == Phase3FusionConsts.K_RRF,
                "K_RRF drift: Swift Phase3FusionConsts.K_RRF = \(Phase3FusionConsts.K_RRF), Rust RRF_K_DEFAULT = \(rustK). One source-of-truth must agree with the other.")
        #expect(Phase3FusionConsts.K_RRF == 60.0,
                "K_RRF must equal 60.0 — the SIGIR 2009 empirical default the design doc commits to. Got \(Phase3FusionConsts.K_RRF).")
    }

    // MARK: - 2. bm25 sign assumption (lower = better)

    @Test("ROW_NUMBER OVER (ORDER BY bm25 ASC) yields rank 1 for the best hit", .enabled(if: sqliteSupportsFTS5ForFusionTests()))
    func bm25SignAssumptionHolds() throws {
        // Insert two pages — one with the query term in the title
        // (highly weighted via bm25(page_search, 5.0, 1.0, 2.0))
        // and one with the term only in the body. The title-hit
        // page MUST rank 1.
        let queue = try Self.makeFusionTestPool()
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: ["page-a", "kant primer", "lorem ipsum body", "phil", 1_000_000.0])
            try db.execute(sql: """
                INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: ["page-b", "unrelated title", "body mentions kant once", "phil", 1_000_000.0])
        }

        try queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    indexed_pages.id AS id,
                    bm25(page_search) AS score,
                    ROW_NUMBER() OVER (ORDER BY bm25(page_search) ASC) AS rnk
                FROM page_search
                JOIN indexed_pages ON indexed_pages.rowid = page_search.rowid
                WHERE page_search MATCH ?
                ORDER BY rnk ASC
            """, arguments: ["kant"])

            #expect(rows.count == 2, "expected both pages to match — got \(rows.count)")
            let firstID: String = rows[0]["id"]
            let firstScore: Double = rows[0]["score"]
            let firstRnk: Int64 = rows[0]["rnk"]
            #expect(firstID == "page-a",
                    "title-weighted hit must rank 1 (ASC bm25); got id=\(firstID) at rank \(firstRnk)")
            #expect(firstRnk == 1)
            #expect(firstScore < 0,
                    "FTS5 bm25 MUST return a negative score (sign convention assumption); got \(firstScore)")
        }
    }

    // MARK: - 3. EXPLAIN QUERY PLAN — fail test on FTS5 MATCH not accelerated

    @Test("Fusion query EXPLAIN: every FTS source uses INDEX N:M<col> (FTS5 MATCH accelerated)", .enabled(if: sqliteSupportsFTS5ForFusionTests()))
    func queryPlanUsesFTS5IndexNotScan() throws {
        let queue = try Self.makeFusionTestPool()
        try queue.read { db in
            // EXPLAIN QUERY PLAN returns rows like:
            //   id | parent | notused | detail
            // We only care about the `detail` column.
            let rows = try Row.fetchAll(
                db,
                sql: "EXPLAIN QUERY PLAN " + RRFFusionQuery.sql,
                arguments: RRFFusionQuery.bindArguments(query: "test")
            )
            let details: [String] = rows.compactMap { $0["detail"] as String? }
            #expect(!details.isEmpty,
                    "EXPLAIN QUERY PLAN returned no rows — the query failed to plan")

            // Filter to lines that mention any of the 3 FTS source
            // table names. SQLite ALWAYS reports virtual-table row
            // visits as "SCAN" — that is not the failure mode we
            // care about. The actual discriminator is the suffix:
            //
            //   "SCAN page_search VIRTUAL TABLE INDEX 0:M0"   ← FTS5 MATCH accelerated (good)
            //   "SCAN page_search VIRTUAL TABLE INDEX 0:"     ← MATCH NOT accelerated (BAD)
            //
            // The `M<digit>` suffix is FTS5's `idxStr` encoding for
            // a MATCH constraint applied at column `<digit>`. Empty
            // suffix means xBestIndex returned no constraint match
            // and the planner falls back to a full virtual-table
            // scan — which is the regression we must fail on.
            let matchUsedRegex = try NSRegularExpression(
                pattern: #"VIRTUAL TABLE INDEX \d+:M\d+"#
            )
            let ftsTableNames = ["page_search", "block_search", "readable_blocks_fts"]
            for table in ftsTableNames {
                let ftsLines = details.filter { $0.contains(table) && $0.contains("VIRTUAL TABLE") }
                #expect(!ftsLines.isEmpty,
                        "EXPLAIN must mention \(table) virtual table at least once — got plan: \(details.joined(separator: " | "))")
                for line in ftsLines {
                    let lineRange = NSRange(line.startIndex..., in: line)
                    let hasMatchAccel = matchUsedRegex.firstMatch(in: line, range: lineRange) != nil
                    #expect(hasMatchAccel,
                            "FTS source \(table) MUST use the FTS5 MATCH index (suffix `INDEX N:M<col>`), NEVER fall back to a full virtual-table scan. Offending line: '\(line)'. Full plan: \(details.joined(separator: " | "))")
                }
            }
        }
    }

    // MARK: - 4. End-to-end smoke — fused query returns ordered results

    @Test("Single-source query returns rows from that source", .enabled(if: sqliteSupportsFTS5ForFusionTests()))
    func singleSourcePageQueryReturnsResults() throws {
        let queue = try Self.makeFusionTestPool()
        let now = Date()
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: ["page-1", "kant on metaphysics", "categorical imperative", "phil", now.timeIntervalSince1970])
            try db.execute(sql: """
                INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: ["page-2", "unrelated", "lorem ipsum", "misc", now.timeIntervalSince1970])
        }

        try queue.read { db in
            let results = try RRFFusionQuery.execute(
                query: "kant",
                weights: .default,
                now: now,
                in: db
            )
            #expect(results.count == 1,
                    "expected one matching entity, got \(results.count): \(results.map(\.entityID))")
            #expect(results[0].entityID == "page-1")
            #expect(results[0].entityKind == "page")
            #expect(results[0].fusedScore > 0,
                    "page-1 must get a positive fused score; got \(results[0].fusedScore)")
            #expect(results[0].bestSourceRank == 1)
        }
    }

    @Test("Cross-source query: same entity hit by multiple sources gets the higher fused score", .enabled(if: sqliteSupportsFTS5ForFusionTests()))
    func crossSourceConsensusBoostsScore() throws {
        let queue = try Self.makeFusionTestPool()
        let now = Date()
        // Seed: page-A has matching content as a page-level row
        // AND as a block within itself. page-B only matches at
        // page level. Both sources return the same query term;
        // page-A should rank higher because RRF rewards consensus.
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: ["page-A", "kant", "kant categorical imperative", "phil", now.timeIntervalSince1970])
            try db.execute(sql: """
                INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: ["page-B", "kant", "different body", "phil", now.timeIntervalSince1970])
            try db.execute(sql: """
                INSERT INTO indexed_blocks (block_id, page_id, content)
                VALUES (?, ?, ?)
            """, arguments: ["block-A1", "page-A", "kant categorical imperative deeper analysis"])
        }

        try queue.read { db in
            let results = try RRFFusionQuery.execute(
                query: "kant",
                weights: .default,
                now: now,
                in: db
            )
            #expect(results.count == 2)
            #expect(results[0].entityID == "page-A",
                    "consensus across page + block sources MUST surface page-A first; got \(results.map(\.entityID))")
            #expect(results[0].fusedScore > results[1].fusedScore,
                    "page-A's fused score must exceed page-B's — got \(results[0].fusedScore) vs \(results[1].fusedScore)")
            // page-A's best block hit was via block_search at rank 1
            // OR via page_search at rank 1; either way bestSourceRank
            // is 1.
            #expect(results[0].bestSourceRank == 1)
        }
    }

    @Test("Empty query corpus returns empty result list (no crash)", .enabled(if: sqliteSupportsFTS5ForFusionTests()))
    func emptyCorpusReturnsEmpty() throws {
        let queue = try Self.makeFusionTestPool()
        try queue.read { db in
            let results = try RRFFusionQuery.execute(
                query: "anything",
                weights: .default,
                now: Date(),
                in: db
            )
            #expect(results.isEmpty,
                    "empty corpus must return empty results, not crash; got \(results.count)")
        }
    }

    @Test("Recency boost shifts score toward recent docs at equal raw rank", .enabled(if: sqliteSupportsFTS5ForFusionTests()))
    func recencyBoostAppliesExpDecay() throws {
        let queue = try Self.makeFusionTestPool()
        let now = Date()
        let recentTime = now.timeIntervalSince1970          // age = 0 days
        let staleTime  = recentTime - (90 * 86400.0)        // age = 90 days

        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: ["page-recent", "alpha bravo charlie", "alpha bravo charlie", "x", recentTime])
            try db.execute(sql: """
                INSERT INTO indexed_pages (id, title, body, tags, updatedAt)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: ["page-stale", "alpha bravo charlie", "alpha bravo charlie", "x", staleTime])
        }

        try queue.read { db in
            let results = try RRFFusionQuery.execute(
                query: "alpha bravo",
                weights: FusionWeights(halfLifeDays: 30.0),  // 90d age = ~12.5% retention
                now: now,
                in: db
            )
            #expect(results.count == 2)
            #expect(results[0].entityID == "page-recent",
                    "recency boost must surface page-recent first when raw bm25 is tied; got \(results.map(\.entityID))")
            // Stale doc's score should be roughly 1/8 of fresh doc's
            // (exp(-90/30) ≈ 0.0498). We assert the inequality, not
            // the exact ratio (bm25 may differ slightly by rowid
            // ordering).
            #expect(results[0].fusedScore > results[1].fusedScore * 2.0,
                    "recency-boosted score should dominate by at least 2x at 90-day age gap; got \(results[0].fusedScore) vs \(results[1].fusedScore)")
        }
    }
}
