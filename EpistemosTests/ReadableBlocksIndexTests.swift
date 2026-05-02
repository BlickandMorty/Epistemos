import Foundation
import GRDB
import Testing

@testable import Epistemos

/// Schema + writer + FTS5 round-trip tests for [`ReadableBlocksIndex`]
/// (T+4.4 of
/// `docs/audits/deliberation/T+4_cognitive_artifact_spine_deliberation_20260427.md`,
/// cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §5).
@Suite("ReadableBlocksIndex universal projection (T+4.4)")
nonisolated struct ReadableBlocksIndexTests {

    /// Spin up an in-memory GRDB pool with the migration applied.
    /// Returns the migrated pool.
    private static func makeMigratedPool() throws -> DatabaseQueue {
        let queue = try DatabaseQueue(path: ":memory:")
        var migrator = DatabaseMigrator()
        ReadableBlocksIndex.registerMigration(&migrator)
        try migrator.migrate(queue)
        return queue
    }

    @Test("Migration creates readable_blocks table + indexes")
    func migrationCreatesTableAndIndexes() throws {
        let queue = try Self.makeMigratedPool()
        try queue.read { db in
            let table = try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'readable_blocks')"
            ) ?? false
            #expect(table, "readable_blocks table must exist after migration")

            let artifactIndex = try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = 'readable_blocks_artifact_idx')"
            ) ?? false
            #expect(artifactIndex, "readable_blocks_artifact_idx must exist for hot per-artifact lookups")
        }
    }

    @Test("Search falls back to readable_blocks when FTS is unavailable")
    func searchFallsBackWithoutFTS() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try queue.write { db in
            try ReadableBlocksIndex.installSchema(in: db)
            try ReadableBlocksIndex.installVaultIDColumn(in: db)
            try ReadableBlocksIndex.insert(
                ReadableBlock(
                    artifactID: "doc-fallback",
                    artifactKind: .document,
                    blockID: "p-1",
                    blockKind: .paragraph,
                    titlePath: "Fallback",
                    body: "ordinary substring search should still find categorical content",
                    updatedAt: ReadableBlock.iso8601(Date())
                ),
                in: db
            )
        }
        try queue.read { db in
            let hits = try ReadableBlocksIndex.search("categorical", in: db)
            #expect(hits.count == 1)
            #expect(hits.first?.artifactID == "doc-fallback")
            #expect(hits.first?.blockID == "p-1")
        }
    }

    // MARK: - RRF Phase 1 — vault_id + recency / vault indexes

    @Test("RRF Phase 1 migration adds vault_id column to readable_blocks")
    func phase1MigrationAddsVaultIDColumn() throws {
        let queue = try Self.makeMigratedPool()
        try queue.read { db in
            // PRAGMA table_info returns one row per column; column 1 is name.
            let cols = try Row.fetchAll(db, sql: "PRAGMA table_info(readable_blocks)")
            let names = cols.compactMap { $0["name"] as String? }
            #expect(names.contains("vault_id"),
                    "v3_1 migration MUST add vault_id column — got columns \(names)")
        }
    }

    @Test("RRF Phase 1 migration adds updated_at + vault_id indexes")
    func phase1MigrationAddsRecencyAndVaultIndexes() throws {
        let queue = try Self.makeMigratedPool()
        try queue.read { db in
            let updatedAtIdx = try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = 'readable_blocks_updated_at_idx')"
            ) ?? false
            #expect(updatedAtIdx,
                    "v3_1 migration MUST create updated_at index for Phase-2 recency tie-breaker")

            let vaultIdIdx = try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = 'readable_blocks_vault_id_idx')"
            ) ?? false
            #expect(vaultIdIdx,
                    "v3_1 migration MUST create vault_id index for Phase-4 multi-vault scoping")
        }
    }

    @Test("Insert with vaultID round-trips through SQL")
    func vaultIDRoundTripsOnInsert() throws {
        let queue = try Self.makeMigratedPool()
        let block = ReadableBlock(
            artifactID: "doc-vault-1",
            artifactKind: .document,
            blockID: "p-1",
            blockKind: .paragraph,
            body: "vault-scoped content",
            updatedAt: ReadableBlock.iso8601(Date()),
            vaultID: "vault-personal-uuid"
        )
        try queue.write { db in
            try ReadableBlocksIndex.insert(block, in: db)
            let stored = try String.fetchOne(
                db,
                sql: "SELECT vault_id FROM readable_blocks WHERE artifact_id = ?",
                arguments: ["doc-vault-1"]
            )
            #expect(stored == "vault-personal-uuid",
                    "vault_id MUST persist verbatim through the writer — got \(stored ?? "nil")")
        }
    }

    @Test("Insert without vaultID stores NULL (pre-migration backwards-compat)")
    func vaultIDDefaultsToNullWhenOmitted() throws {
        let queue = try Self.makeMigratedPool()
        let block = ReadableBlock(
            artifactID: "doc-vault-2",
            artifactKind: .document,
            blockID: "p-1",
            blockKind: .paragraph,
            body: "no-vault content",
            updatedAt: ReadableBlock.iso8601(Date())
        )
        try queue.write { db in
            try ReadableBlocksIndex.insert(block, in: db)
            // Use Row.fetchOne to inspect raw column value — checking
            // for NULL is awkward via String.fetchOne which would
            // unwrap to nil in either NULL or missing-column case.
            let row = try Row.fetchOne(
                db,
                sql: "SELECT vault_id FROM readable_blocks WHERE artifact_id = ?",
                arguments: ["doc-vault-2"]
            )
            #expect(row != nil, "row must be inserted")
            let raw: String? = row?["vault_id"]
            #expect(raw == nil,
                    "omitted vaultID MUST persist as NULL for pre-migration backwards-compat — got \(raw ?? "non-nil")")
        }
    }

    @Test("RRF Phase 1 migration is idempotent (re-run on existing pool is safe)")
    func phase1MigrationIsIdempotent() throws {
        // Build a fresh pool, run migrations, write a row, run
        // migrations AGAIN. GRDB's migrator must skip already-run keys
        // and the row must survive intact.
        let queue = try DatabaseQueue(path: ":memory:")
        var migrator = DatabaseMigrator()
        ReadableBlocksIndex.registerMigration(&migrator)
        try migrator.migrate(queue)

        let block = ReadableBlock(
            artifactID: "doc-idem-1",
            artifactKind: .document,
            blockID: "p-1",
            blockKind: .paragraph,
            body: "survives second migrate",
            updatedAt: ReadableBlock.iso8601(Date()),
            vaultID: "vault-x"
        )
        try queue.write { db in
            try ReadableBlocksIndex.insert(block, in: db)
        }

        // Re-run migrations — must be a no-op.
        try migrator.migrate(queue)

        try queue.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM readable_blocks") ?? 0
            #expect(count == 1, "re-running migrations MUST NOT delete or duplicate rows; got \(count)")
            let vaultID = try String.fetchOne(
                db,
                sql: "SELECT vault_id FROM readable_blocks WHERE artifact_id = ?",
                arguments: ["doc-idem-1"]
            )
            #expect(vaultID == "vault-x",
                    "vault_id MUST survive re-migration intact")
        }
    }

    @Test("Insert + count round-trips a single block")
    func insertAndCount() throws {
        let queue = try Self.makeMigratedPool()
        let block = ReadableBlock(
            artifactID: "doc-1",
            artifactKind: .document,
            blockID: "block-001",
            blockKind: .paragraph,
            titlePath: "My Doc > Intro",
            body: "Hello world",
            updatedAt: ReadableBlock.iso8601(Date(timeIntervalSince1970: 0))
        )
        try queue.write { db in
            try ReadableBlocksIndex.insert(block, in: db)
            let n = try ReadableBlocksIndex.count(forArtifact: "doc-1", in: db)
            #expect(n == 1, "expected 1 row, got \(n)")
        }
    }

    @Test("replaceAllForArtifact deletes old rows then inserts new")
    func replaceAllReplacesPriorRows() throws {
        let queue = try Self.makeMigratedPool()
        let now = ReadableBlock.iso8601(Date())

        try queue.write { db in
            // Initial insert: 3 blocks for doc-1.
            for i in 0..<3 {
                try ReadableBlocksIndex.insert(
                    ReadableBlock(
                        artifactID: "doc-1",
                        artifactKind: .document,
                        blockID: "block-\(i)",
                        blockKind: .paragraph,
                        body: "old body \(i)",
                        updatedAt: now
                    ),
                    in: db
                )
            }
            #expect(try ReadableBlocksIndex.count(forArtifact: "doc-1", in: db) == 3)

            // Replace with 1 block — old rows must be gone.
            try ReadableBlocksIndex.replaceAllForArtifact(
                "doc-1",
                with: [
                    ReadableBlock(
                        artifactID: "doc-1",
                        artifactKind: .document,
                        blockID: "block-new",
                        blockKind: .heading,
                        body: "new body",
                        updatedAt: now
                    )
                ],
                in: db
            )
            #expect(try ReadableBlocksIndex.count(forArtifact: "doc-1", in: db) == 1,
                    "replaceAllForArtifact must purge prior rows before inserting")
        }
    }

    @Test("FTS5 search returns rows matching the query")
    func ftsSearchReturnsMatches() throws {
        let queue = try Self.makeMigratedPool()
        let now = ReadableBlock.iso8601(Date())

        try queue.write { db in
            try ReadableBlocksIndex.insert(
                ReadableBlock(
                    artifactID: "doc-1",
                    artifactKind: .document,
                    blockID: "b-1",
                    blockKind: .paragraph,
                    titlePath: "Kant Notes > Critique",
                    body: "The categorical imperative is a moral law.",
                    updatedAt: now
                ),
                in: db
            )
            try ReadableBlocksIndex.insert(
                ReadableBlock(
                    artifactID: "doc-2",
                    artifactKind: .document,
                    blockID: "b-2",
                    blockKind: .paragraph,
                    titlePath: nil,
                    body: "Rust ownership rules prevent data races.",
                    updatedAt: now
                ),
                in: db
            )
        }

        try queue.read { db in
            let hits = try ReadableBlocksIndex.search("categorical", in: db)
            #expect(hits.count == 1, "expected exactly 1 hit for `categorical`, got \(hits.count)")
            #expect(hits.first?.artifactID == "doc-1")
            #expect(hits.first?.blockID == "b-1")

            let none = try ReadableBlocksIndex.search("nonsenseword", in: db)
            #expect(none.isEmpty, "non-matching query must return zero hits, got \(none.count)")
        }
    }

    @Test("FTS5 stays in sync after replaceAllForArtifact")
    func ftsTracksReplaceAll() throws {
        let queue = try Self.makeMigratedPool()
        let now = ReadableBlock.iso8601(Date())

        try queue.write { db in
            try ReadableBlocksIndex.insert(
                ReadableBlock(
                    artifactID: "doc-1",
                    artifactKind: .document,
                    blockID: "b-1",
                    blockKind: .paragraph,
                    body: "first revision text",
                    updatedAt: now
                ),
                in: db
            )
        }
        try queue.read { db in
            let revisionHits = try ReadableBlocksIndex.search("revision", in: db)
            #expect(revisionHits.count == 1,
                    "FTS must return the row inserted via insert(...)")
        }

        try queue.write { db in
            try ReadableBlocksIndex.replaceAllForArtifact(
                "doc-1",
                with: [
                    ReadableBlock(
                        artifactID: "doc-1",
                        artifactKind: .document,
                        blockID: "b-1",
                        blockKind: .paragraph,
                        body: "second revision text",
                        updatedAt: now
                    )
                ],
                in: db
            )
        }
        try queue.read { db in
            // Old body purged.
            let firstHits = try ReadableBlocksIndex.search("first", in: db)
            #expect(firstHits.isEmpty,
                    "FTS index must not return purged content")
            // New body present.
            let secondHits = try ReadableBlocksIndex.search("second", in: db)
            #expect(secondHits.count == 1,
                    "FTS index must reflect rows inserted by replaceAllForArtifact")
        }
    }

    @Test("deleteAllForArtifact removes rows + cascades into FTS")
    func deleteAllRemovesFromFTS() throws {
        let queue = try Self.makeMigratedPool()
        let now = ReadableBlock.iso8601(Date())

        try queue.write { db in
            try ReadableBlocksIndex.insert(
                ReadableBlock(
                    artifactID: "doc-x",
                    artifactKind: .document,
                    blockID: "b-1",
                    blockKind: .paragraph,
                    body: "deletable content here",
                    updatedAt: now
                ),
                in: db
            )
            try ReadableBlocksIndex.deleteAllForArtifact("doc-x", in: db)
            #expect(try ReadableBlocksIndex.count(forArtifact: "doc-x", in: db) == 0)
        }
        try queue.read { db in
            let deletableHits = try ReadableBlocksIndex.search("deletable", in: db)
            #expect(deletableHits.isEmpty,
                    "FTS index must drop entries for deleted artifacts")
        }
    }

    @Test("replaceAllForArtifact preserves stable artifact id while title path changes")
    func replaceAllPreservesStableIDAcrossRename() throws {
        let queue = try Self.makeMigratedPool()
        let now = ReadableBlock.iso8601(Date())
        let artifactID = "doc-rename-stable"

        try queue.write { db in
            try ReadableBlocksIndex.replaceAllForArtifact(
                artifactID,
                with: [
                    ReadableBlock(
                        artifactID: artifactID,
                        artifactKind: .document,
                        blockID: "intro",
                        blockKind: .heading,
                        titlePath: "Old oldtitlepatchseven",
                        body: "stable body before rename",
                        updatedAt: now
                    )
                ],
                in: db
            )

            try ReadableBlocksIndex.replaceAllForArtifact(
                artifactID,
                with: [
                    ReadableBlock(
                        artifactID: artifactID,
                        artifactKind: .document,
                        blockID: "intro",
                        blockKind: .heading,
                        titlePath: "New newtitlepatchseven",
                        body: "stable body after rename",
                        updatedAt: now
                    )
                ],
                in: db
            )
        }

        try queue.read { db in
            let staleTitleHits = try ReadableBlocksIndex.search("oldtitlepatchseven", in: db)
            #expect(staleTitleHits.isEmpty,
                    "renaming/replacing a projection must remove stale title_path terms")

            let freshTitleHits = try ReadableBlocksIndex.search("newtitlepatchseven", in: db)
            #expect(freshTitleHits.count == 1)
            #expect(freshTitleHits.first?.artifactID == artifactID,
                    "artifact identity must stay stable across title/path projection updates")
            #expect(freshTitleHits.first?.blockID == "intro",
                    "search hit must still resolve to the exact block after rename")
        }
    }

    @Test("visible artifact kinds resolve to typed artifact and block search hits")
    func visibleArtifactKindsResolveToTypedSearchHits() throws {
        let queue = try Self.makeMigratedPool()
        let now = ReadableBlock.iso8601(Date())

        try queue.write { db in
            for kind in ArtifactKind.allCases {
                let token = "kindtoken\(kind.rawValue)"
                try ReadableBlocksIndex.insert(
                    ReadableBlock(
                        artifactID: "artifact-\(kind.snakeCaseString)",
                        artifactKind: kind,
                        blockID: "block-\(kind.snakeCaseString)",
                        blockKind: .paragraph,
                        titlePath: kind.displayName,
                        body: "searchable \(token) body",
                        updatedAt: now
                    ),
                    in: db
                )
            }
        }

        try queue.read { db in
            for kind in ArtifactKind.allCases {
                let token = "kindtoken\(kind.rawValue)"
                let hits = try ReadableBlocksIndex.search(token, in: db)
                #expect(hits.count == 1, "expected one hit for \(kind), got \(hits.count)")
                #expect(hits.first?.artifactID == "artifact-\(kind.snakeCaseString)")
                #expect(hits.first?.artifactKind == kind)
                #expect(hits.first?.blockID == "block-\(kind.snakeCaseString)")
            }
        }
    }

    @Test("ReadableBlockKind round-trips via Codable as snake_case-compatible raw values")
    func blockKindRoundTrip() throws {
        // ReadableBlockKind raw values are ASCII single-word — they're
        // safe as both rawValue strings AND on-the-wire JSON literals.
        for kind in ReadableBlockKind.allCases {
            let data = try JSONEncoder().encode(kind)
            let recovered = try JSONDecoder().decode(ReadableBlockKind.self, from: data)
            #expect(recovered == kind)
        }
    }

    @Test("ArtifactKind snake-case round-trips through SearchHit")
    func searchHitArtifactKindMapping() throws {
        let queue = try Self.makeMigratedPool()
        let now = ReadableBlock.iso8601(Date())

        try queue.write { db in
            try ReadableBlocksIndex.insert(
                ReadableBlock(
                    artifactID: "raw-1",
                    artifactKind: .rawThought,
                    blockID: "b-1",
                    blockKind: .quote,
                    body: "thought about kant",
                    updatedAt: now
                ),
                in: db
            )
        }
        try queue.read { db in
            let hits = try ReadableBlocksIndex.search("kant", in: db)
            #expect(hits.first?.artifactKind == .rawThought,
                    "SearchHit must round-trip the snake_case-stored ArtifactKind back to a typed enum case")
        }
    }
}
