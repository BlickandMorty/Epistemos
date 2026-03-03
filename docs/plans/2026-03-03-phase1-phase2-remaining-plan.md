# Phase 1 + Phase 2 Remaining Features — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement all 8 remaining NOT DONE items from Phases 1 and 2 of the competitive execution roadmap — closing every hard gap with Logseq.

**Architecture:** Block-level FTS5 and embeddings build on the existing BTK op stream. Query system cleanup removes GraphQueryDSL in favor of QueryAST-only flow. Editable transclusion replaces the read-only overlay with a live NSTextStorage attributed range backed by BTK. Block properties surface via context menu and inline `@key=value` syntax.

**Tech Stack:** Swift (SwiftUI + AppKit + GRDB), Rust FFI (graph-engine), Metal, Swift Testing (`@Suite`, `@Test`, `#expect`)

**Source of Truth:** `/Users/jojo/Epistemos-Knowledge-Transfer/plans/2026-03-02-competitive-execution-roadmap.md`

---

## Task 1: Block-Level FTS5 Index

**Goal:** Create a `block_search` FTS5 virtual table in SearchIndexService that indexes individual blocks from BTK, enabling block-granularity full-text search.

**Files:**
- Modify: `Epistemos/Sync/SearchIndexService.swift` (lines 46-92 schema, 97-126 search, 130-145 upsert)
- Test: `EpistemosTests/Sync/SearchIndexServiceTests.swift` (create if needed, or add to existing)

**Step 1: Write the failing test**

Create a test file (or add to existing). The test inserts a block into the index and searches for it.

```swift
// EpistemosTests/Sync/BlockSearchTests.swift
import Testing
@testable import Epistemos

@Suite("Block FTS5 Search")
struct BlockSearchTests {

    @Test("Block upsert and search returns matching block")
    func blockUpsertAndSearch() throws {
        let service = try SearchIndexService(inMemory: true)
        service.upsertBlock(
            blockId: "block-001",
            pageId: "page-001",
            content: "Epistemology is the study of knowledge"
        )
        let results = try service.searchBlocks(query: "epistemology", limit: 10)
        #expect(results.count == 1)
        #expect(results[0].blockId == "block-001")
        #expect(results[0].pageId == "page-001")
        #expect(results[0].snippet.localizedCaseInsensitiveContains("epistemology"))
    }

    @Test("Block delete removes from search index")
    func blockDelete() throws {
        let service = try SearchIndexService(inMemory: true)
        service.upsertBlock(blockId: "b1", pageId: "p1", content: "quantum mechanics")
        service.deleteBlock(blockId: "b1")
        let results = try service.searchBlocks(query: "quantum", limit: 10)
        #expect(results.isEmpty)
    }

    @Test("Block search respects limit")
    func blockSearchLimit() throws {
        let service = try SearchIndexService(inMemory: true)
        for i in 0..<20 {
            service.upsertBlock(blockId: "b\(i)", pageId: "p1", content: "philosophy topic \(i)")
        }
        let results = try service.searchBlocks(query: "philosophy", limit: 5)
        #expect(results.count == 5)
    }

    @Test("Block update changes indexed content")
    func blockUpdate() throws {
        let service = try SearchIndexService(inMemory: true)
        service.upsertBlock(blockId: "b1", pageId: "p1", content: "old content about cats")
        service.upsertBlock(blockId: "b1", pageId: "p1", content: "new content about dogs")
        let oldResults = try service.searchBlocks(query: "cats", limit: 10)
        let newResults = try service.searchBlocks(query: "dogs", limit: 10)
        #expect(oldResults.isEmpty)
        #expect(newResults.count == 1)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "(Test.*FAIL|error:|BlockSearch)"`
Expected: FAIL — `SearchIndexService(inMemory:)` doesn't exist, `upsertBlock`/`searchBlocks`/`deleteBlock` don't exist.

**Step 3: Implement block FTS5 in SearchIndexService**

In `SearchIndexService.swift`:

**3a. Add `inMemory` initializer** (after existing init, ~line 28):

```swift
/// In-memory database for testing
init(inMemory: Bool) throws {
    if inMemory {
        self.dbQueue = try DatabaseQueue()
    } else {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Epistemos", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.dbQueue = try DatabaseQueue(path: dir.appendingPathComponent("search.sqlite").path)
    }
    try setupSchema(dbQueue)
}
```

If an `inMemory` init already exists, skip this step.

**3b. Add `block_search` table to `setupSchema()`** (after the `page_search` creation, ~line 66):

```swift
// Block-level FTS5 table
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

// Sync triggers for block_search
try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS indexed_blocks_ai AFTER INSERT ON indexed_blocks BEGIN
        INSERT INTO block_search(rowid, content) VALUES (new.rowid, new.content);
    END
""")
try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS indexed_blocks_ad AFTER DELETE ON indexed_blocks BEGIN
        INSERT INTO block_search(block_search, rowid, content) VALUES('delete', old.rowid, old.content);
    END
""")
try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS indexed_blocks_au AFTER UPDATE ON indexed_blocks BEGIN
        INSERT INTO block_search(block_search, rowid, content) VALUES('delete', old.rowid, old.content);
        INSERT INTO block_search(rowid, content) VALUES (new.rowid, new.content);
    END
""")
```

**3c. Add `BlockSearchResult` struct** (after `SearchResult`, ~line 268):

```swift
struct BlockSearchResult: Sendable {
    let blockId: String
    let pageId: String
    let snippet: String
    let rank: Double
}
```

**3d. Add `upsertBlock()` method** (after existing `upsert()`, ~line 145):

```swift
nonisolated func upsertBlock(blockId: String, pageId: String, content: String) {
    try? dbQueue.write { db in
        try db.execute(
            sql: "INSERT OR REPLACE INTO indexed_blocks (block_id, page_id, content) VALUES (?, ?, ?)",
            arguments: [blockId, pageId, content]
        )
    }
}
```

**3e. Add `deleteBlock()` method:**

```swift
nonisolated func deleteBlock(blockId: String) {
    try? dbQueue.write { db in
        try db.execute(sql: "DELETE FROM indexed_blocks WHERE block_id = ?", arguments: [blockId])
    }
}
```

**3f. Add `searchBlocks()` method:**

```swift
nonisolated func searchBlocks(query: String, limit: Int = 50) throws -> [BlockSearchResult] {
    let sanitized = Self.sanitizeFTS5Query(query)
    guard !sanitized.isEmpty else { return [] }

    return try dbQueue.read { db in
        let rows = try Row.fetchAll(db, sql: """
            SELECT b.block_id, b.page_id,
                   snippet(block_search, 0, '<b>', '</b>', '…', 32) AS snippet,
                   bm25(block_search) AS rank
            FROM block_search
            JOIN indexed_blocks b ON b.rowid = block_search.rowid
            WHERE block_search MATCH ?
            ORDER BY rank
            LIMIT ?
        """, arguments: [sanitized, limit])

        return rows.map { row in
            BlockSearchResult(
                blockId: row["block_id"],
                pageId: row["page_id"],
                snippet: row["snippet"],
                rank: row["rank"]
            )
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "(Test.*PASS|Test.*FAIL|BlockSearch)"`
Expected: All 4 tests PASS.

**Step 5: Commit**

```bash
git add Epistemos/Sync/SearchIndexService.swift EpistemosTests/Sync/BlockSearchTests.swift
git commit -m "feat: add block-level FTS5 index to SearchIndexService"
```

---

## Task 2: Block-Level Embeddings

**Goal:** Extend EmbeddingService to compute and push per-block embeddings to the Rust engine, enabling block-granularity semantic search.

**Files:**
- Modify: `Epistemos/Graph/EmbeddingService.swift` (lines 40-113)
- Test: `EpistemosTests/Graph/BlockEmbeddingTests.swift` (new)

**Step 1: Write the failing test**

```swift
// EpistemosTests/Graph/BlockEmbeddingTests.swift
import Testing
import NaturalLanguage
@testable import Epistemos

@Suite("Block Embeddings")
struct BlockEmbeddingTests {

    @Test("computeBlockEmbeddings returns vectors for each block")
    func computeBlockEmbeddings() async throws {
        let service = EmbeddingService()
        let blocks: [(id: String, content: String)] = [
            ("block-1", "Epistemology studies the nature of knowledge"),
            ("block-2", "Quantum mechanics describes subatomic particles"),
        ]
        let embeddings = service.computeBlockVectors(blocks: blocks)
        #expect(embeddings.count == 2)
        #expect(embeddings["block-1"] != nil)
        #expect(embeddings["block-2"] != nil)
        // Vectors should have same dimension
        #expect(embeddings["block-1"]!.count == embeddings["block-2"]!.count)
        #expect(embeddings["block-1"]!.count > 0)
    }

    @Test("Empty content produces no embedding")
    func emptyContentNoEmbedding() async throws {
        let service = EmbeddingService()
        let blocks: [(id: String, content: String)] = [
            ("block-empty", ""),
            ("block-short", "a"),
        ]
        let embeddings = service.computeBlockVectors(blocks: blocks)
        // Empty and single-char blocks may not produce embeddings (no recognized words)
        #expect(embeddings["block-empty"] == nil)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "(BlockEmbedding)"`
Expected: FAIL — `computeBlockVectors` doesn't exist.

**Step 3: Implement `computeBlockVectors()` in EmbeddingService**

Add this method to `EmbeddingService` (after `computeAndPush`, ~line 118):

```swift
/// Compute embedding vectors for a batch of blocks. Returns blockId → vector.
/// Pure computation — does NOT push to Rust. Caller pushes.
nonisolated func computeBlockVectors(blocks: [(id: String, content: String)]) -> [String: [Float]] {
    guard let nlEmbedding = NLEmbedding.wordEmbedding(for: .english) else { return [:] }
    let dim = nlEmbedding.dimension

    var result: [String: [Float]] = [:]
    result.reserveCapacity(blocks.count)

    for (blockId, content) in blocks {
        let words = content.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }
        guard !words.isEmpty else { continue }

        var sum = [Float](repeating: 0, count: dim)
        var count: Float = 0

        for word in words {
            guard let vec = nlEmbedding.vector(for: word) else { continue }
            let floatVec = vec.map { Float($0) }
            for i in 0..<dim {
                sum[i] += floatVec[i]
            }
            count += 1
        }

        guard count > 0 else { continue }
        let invCount = 1.0 / count
        for i in 0..<dim {
            sum[i] *= invCount
        }
        result[blockId] = sum
    }

    return result
}
```

Then add a method to push block embeddings to Rust (after `computeBlockVectors`):

```swift
/// Push pre-computed block embeddings to the Rust graph engine.
func pushBlockEmbeddings(_ embeddings: [String: [Float]]) {
    guard let engine = graphState?.engineHandle else { return }
    let dim = embeddings.values.first?.count ?? 0
    guard dim > 0 else { return }

    for (blockId, vector) in embeddings {
        vector.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            blockId.withCString { cId in
                graph_engine_set_node_embedding(engine, cId, base, UInt32(dim))
            }
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "(BlockEmbedding)"`
Expected: Both tests PASS.

**Step 5: Commit**

```bash
git add Epistemos/Graph/EmbeddingService.swift EpistemosTests/Graph/BlockEmbeddingTests.swift
git commit -m "feat: add per-block embedding computation to EmbeddingService"
```

---

## Task 3: Block Search in Command Palette

**Goal:** Add block-level search results to the command palette, interleaved with existing page results, showing snippet + parent page title.

**Files:**
- Modify: `Epistemos/Views/Landing/CommandPaletteOverlay.swift` (lines 963-1010 search handler, 1014-1046 filteredResults, 1197-1245 body results)
- Modify: `Epistemos/State/VaultSyncState.swift` or wherever `searchFull` is defined — to add block search

**Step 1: Add block search method to VaultSyncState (or SearchIndexService)**

First, find where `vaultSync.searchFull()` is called from the palette. The palette calls `computeBodyResults()` which uses `vaultSync.searchFull()`. We need a parallel path for blocks.

Add to `SearchIndexService` (if not already accessible via VaultSyncState):

```swift
/// Search blocks and return results with page context.
nonisolated func searchBlocksWithContext(
    query: String,
    limit: Int = 20,
    excludePageIds: Set<String> = []
) throws -> [BlockSearchResult] {
    let sanitized = Self.sanitizeFTS5Query(query)
    guard !sanitized.isEmpty else { return [] }

    return try dbQueue.read { db in
        let rows = try Row.fetchAll(db, sql: """
            SELECT b.block_id, b.page_id,
                   snippet(block_search, 0, '<b>', '</b>', '…', 32) AS snippet,
                   bm25(block_search) AS rank
            FROM block_search
            JOIN indexed_blocks b ON b.rowid = block_search.rowid
            WHERE block_search MATCH ?
            ORDER BY rank
            LIMIT ?
        """, arguments: [sanitized, limit])

        return rows.compactMap { row -> BlockSearchResult? in
            let pageId: String = row["page_id"]
            guard !excludePageIds.contains(pageId) else { return nil }
            return BlockSearchResult(
                blockId: row["block_id"],
                pageId: row["page_id"],
                snippet: row["snippet"],
                rank: row["rank"]
            )
        }
    }
}
```

**Step 2: Add block results category to CommandPaletteOverlay**

In `CommandPaletteOverlay.swift`:

**2a. Add a new result category.** Find where `PaletteItem` or result categories are defined. Add a `.blockMatch` category (or similar) alongside the existing categories.

**2b. Add `computeBlockResults()` method** (alongside `computeBodyResults()`, ~line 1197):

```swift
private func computeBlockResults() {
    guard searchText.count >= 2 else {
        cachedBlockResults = []
        return
    }
    let seen = seenPageIds  // Already populated by title + graph results
    Task.detached(priority: .userInitiated) { [searchText, seen] in
        guard let searchIndex = /* access SearchIndexService */ else { return }
        let blockResults = try? searchIndex.searchBlocksWithContext(
            query: searchText,
            limit: 10,
            excludePageIds: seen
        )
        await MainActor.run {
            self.cachedBlockResults = (blockResults ?? []).map { block in
                PaletteItem(
                    id: "block:\(block.blockId)",
                    title: block.snippet.replacingOccurrences(of: "<b>", with: "")
                        .replacingOccurrences(of: "</b>", with: ""),
                    subtitle: "Block in page",  // Resolve page title if available
                    icon: "cube.transparent",
                    category: .blockMatch,
                    action: .navigateToBlock(pageId: block.pageId, blockId: block.blockId)
                )
            }
        }
    }
}
```

**2c. Call `computeBlockResults()` from `handleSearchChange()`** at ~line 986, inside the debounce alongside `computeBodyResults()`:

```swift
computeBlockResults()
```

**2d. Include `cachedBlockResults` in `filteredResults`** at ~line 1014, interleaved by score.

**Step 3: Add navigation-to-block action**

When a block result is clicked, navigate to the page and scroll to the block offset. The action handler should:
1. Open the page via `NoteWindowManager.openWindow(for: pageId)`
2. After page loads, find the block's character offset in NSTextStorage and scroll to it

This requires looking up the block content in the page body and scrolling. For now, a simple substring search after page open is sufficient.

**Step 4: Run build to verify compilation**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Epistemos/Views/Landing/CommandPaletteOverlay.swift Epistemos/Sync/SearchIndexService.swift
git commit -m "feat: add block search results to command palette"
```

---

## Task 4: NL Parser → QueryAST Only (Remove GraphQueryDSL)

**Goal:** Remove the legacy `GraphQueryDSL` enum and `parse()` method from QueryParser. All query execution flows through QueryAST → QueryCompiler → QueryRuntime.

**Files:**
- Modify: `Epistemos/Engine/QueryParser.swift` (lines 18-29 remove `parse()`, lines 48-160 remove `heuristicParse()`)
- Modify: `Epistemos/Engine/QueryTypes.swift` (remove `GraphQueryDSL`, `NodeFilter`, `EdgeFilter`, `AggregationType`, `SetCombiner`, `MetadataFilter` — lines 35-96)
- Modify: `Epistemos/Engine/QueryExecutor.swift` (delete entire file — superseded by QueryRuntime)
- Audit: All callers of `QueryParser.parse()` and `QueryExecutor.execute()`

**Step 1: Audit all callers**

From the survey, `QueryParser.parse()` has **no callers in new code** — all new code uses `QueryParser.parseToAST()` via `QueryRuntime.query()`. The legacy `QueryExecutor` is also unused in new code.

Verify by searching:

Run: `grep -rn "QueryParser\.parse(" Epistemos/` (should find only the definition)
Run: `grep -rn "QueryExecutor" Epistemos/` (should find only the definition file)
Run: `grep -rn "GraphQueryDSL" Epistemos/` (should find only QueryTypes.swift + QueryParser.swift)

If any callers exist, migrate them to `QueryRuntime.query()` or `QueryParser.parseToAST()` first.

**Step 2: Write the verification test**

```swift
// EpistemosTests/Engine/QueryASTMigrationTests.swift
import Testing
@testable import Epistemos

@Suite("QueryAST Migration — GraphQueryDSL removed")
struct QueryASTMigrationTests {

    @Test("QueryParser.parseToAST handles all previously-supported NL patterns")
    func allNLPatternsWork() {
        // Type filter
        let typeAST = QueryParser.parseToAST("show me all notes")
        #expect(typeAST != nil)

        // Date filter
        let dateAST = QueryParser.parseToAST("notes from last week")
        #expect(dateAST != nil)

        // Semantic search
        let semAST = QueryParser.parseToAST("similar to consciousness")
        #expect(semAST != nil)

        // Content search
        let contentAST = QueryParser.parseToAST("find epistemology")
        #expect(contentAST != nil)

        // Path query
        let pathAST = QueryParser.parseToAST("how is Kant connected to Hegel")
        #expect(pathAST != nil)
    }

    @Test("QueryRuntime.query routes NL input through AST path")
    func runtimeNLRoute() {
        // This test verifies the unified flow compiles and runs
        // (actual results depend on graph data, so just verify no crash)
        // QueryRuntime needs backends — skip if can't construct
    }
}
```

**Step 3: Run test to verify it passes (baseline)**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "(QueryASTMigration)"`
Expected: Tests pass (parseToAST already works for all patterns).

**Step 4: Remove legacy code**

**4a. In `QueryParser.swift`:**
- Delete `parse()` method (lines 18-29)
- Delete `heuristicParse()` method (lines 48-160)
- Delete `extractDateFilter()` helper (lines 319-345) — only used by heuristicParse
- Keep: `parseToAST()`, `heuristicParseToAST()`, `extractDateFilterAST()`, string helpers

**4b. In `QueryTypes.swift`:**
- Delete `GraphQueryDSL` enum (lines 35-44)
- Delete `NodeFilter` struct (lines 47-54) — BUT CHECK: `QueryPlan.QueryStep.graphStoreFilter` uses `NodeFilter`. If `NodeFilter` is used by the plan layer, KEEP IT.
- Delete `EdgeFilter` struct (lines 58-62) — same check
- Delete `AggregationType` enum (lines 82-88) — check if used by QueryPlan
- Delete `SetCombiner` enum (lines 92-96)
- Delete `MetadataFilter` struct (lines 75-78)
- Keep: `SearchScope`, `CompOp`, `PropertyValue`, `NodeRef`, `QueryPlan`, `QueryStep`, `PlanCombiner`, `QueryResult`, `QueryResultNode`, `QueryResultEdge`, `QueryAggregation`, `OrderBy`, `DateField`

**IMPORTANT:** `NodeFilter` and `EdgeFilter` are used by `QueryPlan.QueryStep` (`.graphStoreFilter(NodeFilter)`, `.graphStoreEdgeFilter(EdgeFilter)`). These MUST be kept. Only delete `GraphQueryDSL`, `AggregationType` (if unused by plan), `SetCombiner`, `MetadataFilter`.

**4c. Delete `QueryExecutor.swift`** (entire file — 316 lines). It dispatches `GraphQueryDSL` and is superseded by `QueryRuntime`.

**Step 5: Run build + tests to verify nothing breaks**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (no remaining references to deleted types)

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "(FAIL|error:)" | head -20`
Expected: No new failures.

**Step 6: Commit**

```bash
git add -u Epistemos/Engine/
git add EpistemosTests/Engine/QueryASTMigrationTests.swift
git commit -m "refactor: remove GraphQueryDSL, QueryExecutor — all queries now flow through QueryAST"
```

---

## Task 5: Structured Query in Command Palette

**Goal:** Wire the `?` prefix syntax in the command palette search field to the existing `StructuredQueryParser` → `QueryCompiler` → `QueryRuntime` pipeline.

**Files:**
- Modify: `Epistemos/Views/Landing/CommandPaletteOverlay.swift` (lines 963-1010 search handler)

**Step 1: Detect `?` prefix in search handler**

In `handleSearchChange()` (~line 963), add a check at the top:

```swift
if searchText.hasPrefix("?") {
    computeStructuredQueryResults()
    return  // Skip 3-tier search for structured queries
}
```

**Step 2: Add `computeStructuredQueryResults()` method**

```swift
private func computeStructuredQueryResults() {
    guard searchText.count >= 2 else {
        cachedStructuredResults = []
        return
    }
    guard let queryEngine = /* access QueryEngine from environment */ else { return }

    queryEngine.execute(query: searchText)
    // QueryEngine.execute already routes ? prefix through StructuredQueryParser
    // via QueryRuntime.query() — see QueryRuntime.swift:76-87

    // Convert QueryResult nodes to PaletteItems
    if let result = queryEngine.currentResult {
        cachedStructuredResults = result.nodes.prefix(20).map { node in
            PaletteItem(
                id: "query:\(node.id)",
                title: node.label,
                subtitle: node.type.rawValue.capitalized + (node.snippet.map { " — \($0)" } ?? ""),
                icon: iconForNodeType(node.type),
                category: .queryResult,
                action: .navigate(pageId: node.sourceId ?? node.id)
            )
        }
    }
}
```

**Step 3: Add `.queryResult` category** if it doesn't exist, and include `cachedStructuredResults` in `filteredResults`.

**Step 4: Add visual indicator** — when `searchText.hasPrefix("?")`, show a small "Structured Query" badge or change the search field's accessory icon.

**Step 5: Run build to verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add Epistemos/Views/Landing/CommandPaletteOverlay.swift
git commit -m "feat: wire structured query (? prefix) in command palette to QueryRuntime"
```

---

## Task 6: Block Property System UI

**Goal:** Two entry points for setting block properties: (1) right-click context menu on a block, (2) inline `@key=value` syntax parsed by MarkdownTextStorage.

**Files:**
- Modify: `Epistemos/Views/Notes/MarkdownTextStorage.swift` (lines 537-708 inline styles)
- Modify: `Epistemos/Views/Notes/ProseEditorRepresentable.swift` (Coordinator, context menu)
- Create: `Epistemos/Views/Notes/BlockPropertySheet.swift` (SwiftUI sheet for property editing)

### Part A: Inline `@key=value` Parsing

**Step 1: Write the failing test**

```swift
// EpistemosTests/Views/BlockPropertyParsingTests.swift
import Testing
@testable import Epistemos

@Suite("Block Property Inline Parsing")
struct BlockPropertyParsingTests {

    @Test("Parse @key=value at end of line")
    func parseInlineProperty() {
        let line = "This is a claim @type=claim @confidence=0.7"
        let props = BlockPropertyParser.parse(line)
        #expect(props.count == 2)
        #expect(props["type"] == .string("claim"))
        #expect(props["confidence"] == .float(0.7))
    }

    @Test("No properties in line without @")
    func noProperties() {
        let line = "Just a normal line of text"
        let props = BlockPropertyParser.parse(line)
        #expect(props.isEmpty)
    }

    @Test("Property at middle of line ignored — only trailing")
    func propertyMidLineIgnored() {
        let line = "Email me @user=bob and then @type=note"
        let props = BlockPropertyParser.parse(line)
        // Only trailing @type=note is captured
        #expect(props.count == 1)
        #expect(props["type"] == .string("note"))
    }

    @Test("Boolean property")
    func booleanProperty() {
        let line = "A block @pinned=true"
        let props = BlockPropertyParser.parse(line)
        #expect(props["pinned"] == .bool(true))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "(BlockProperty)"`
Expected: FAIL — `BlockPropertyParser` doesn't exist.

**Step 3: Implement `BlockPropertyParser`**

```swift
// Epistemos/Sync/BlockPropertyParser.swift
import Foundation

enum BlockPropertyParser {
    /// Parse trailing @key=value pairs from a block line.
    /// Only captures properties at the end of the line (after all prose content).
    static func parse(_ line: String) -> [String: PropertyValue] {
        var result: [String: PropertyValue] = [:]
        // Match @key=value patterns at end of line
        let pattern = #/@(\w+)=([^\s@]+)/#
        // Find the rightmost contiguous sequence of @key=value
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var remaining = trimmed[...]

        // Walk backward to find where properties start
        var propStart = trimmed.endIndex
        while let match = remaining.lastMatch(of: pattern) {
            let beforeMatch = remaining[remaining.startIndex..<match.range.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            if beforeMatch.isEmpty || beforeMatch.last == " " || match.range.lowerBound == remaining.startIndex {
                propStart = match.range.lowerBound
                remaining = remaining[remaining.startIndex..<match.range.lowerBound]
            } else {
                break
            }
        }

        // Parse all @key=value from propStart onward
        let propSubstring = trimmed[propStart...]
        for match in propSubstring.matches(of: pattern) {
            let key = String(match.output.1)
            let rawValue = String(match.output.2)
            result[key] = parseValue(rawValue)
        }

        return result
    }

    private static func parseValue(_ raw: String) -> PropertyValue {
        if let f = Float(raw) { return .float(f) }
        if let i = Int(raw) { return .int(i) }
        if raw == "true" { return .bool(true) }
        if raw == "false" { return .bool(false) }
        return .string(raw)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "(BlockProperty)"`
Expected: All 4 tests PASS.

**Step 5: Commit**

```bash
git add Epistemos/Sync/BlockPropertyParser.swift EpistemosTests/Views/BlockPropertyParsingTests.swift
git commit -m "feat: add BlockPropertyParser for inline @key=value syntax"
```

### Part B: Visual styling of inline properties

**Step 6: Add property chip rendering in MarkdownTextStorage**

In `MarkdownTextStorage.swift`, in `restyleLines()` (~line 213), after processing existing line patterns, add detection for trailing `@key=value`:

```swift
// After other line-level styling, detect inline properties
if line.contains("@") {
    // Find all @key=value patterns and style as capsule chips
    let propPattern = #/@(\w+)=([^\s@]+)/#
    for match in lineText.matches(of: propPattern) {
        let matchRange = /* convert to NSRange within full document */
        addAttributes([
            .font: NSFont.systemFont(ofSize: smallSize, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
            .backgroundColor: (isDark ? NSColor.white : NSColor.black).withAlphaComponent(0.06),
            // Custom attribute for click handling
            .init("EpistemosBlockProperty"): "\(match.output.1)=\(match.output.2)"
        ], range: matchRange)
    }
}
```

### Part C: Context menu property editor

**Step 7: Add "Set Property..." to ClickableTextView context menu**

In the ClickableTextView (or its context menu handler), add a menu item that:
1. Identifies which block the cursor is in (via BTK)
2. Opens a `BlockPropertySheet` (SwiftUI sheet) showing existing properties
3. On save, emits `SetProperty` BTK ops

This requires a SwiftUI sheet — create `BlockPropertySheet.swift`:

```swift
// Epistemos/Views/Notes/BlockPropertySheet.swift
import SwiftUI

struct BlockPropertySheet: View {
    let blockId: String
    @State private var properties: [(key: String, value: String)] = []
    @State private var newKey = ""
    @State private var newValue = ""
    let onSave: ([(String, PropertyValue)]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Block Properties")
                .font(.headline)

            ForEach(Array(properties.enumerated()), id: \.offset) { idx, prop in
                HStack {
                    TextField("Key", text: Binding(
                        get: { properties[idx].key },
                        set: { properties[idx].key = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                    TextField("Value", text: Binding(
                        get: { properties[idx].value },
                        set: { properties[idx].value = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button(role: .destructive) {
                        properties.remove(at: idx)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("New key", text: $newKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                TextField("New value", text: $newValue)
                    .textFieldStyle(.roundedBorder)
                Button {
                    guard !newKey.isEmpty else { return }
                    properties.append((newKey, newValue))
                    newKey = ""
                    newValue = ""
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    let parsed = properties.map { (key, val) in
                        (key, BlockPropertyParser.parseValue(val))
                    }
                    onSave(parsed)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
```

**Step 8: Run build to verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 9: Commit**

```bash
git add Epistemos/Views/Notes/BlockPropertySheet.swift Epistemos/Views/Notes/MarkdownTextStorage.swift
git commit -m "feat: add block property UI — inline chips + context menu editor"
```

---

## Task 7: Editable Transclusion

**Goal:** Replace the read-only `TransclusionOverlayView` with a live attributed range in `MarkdownTextStorage`. Edits within a transclusion range route through BTK as `UpdateBlock` targeting the source block.

**Files:**
- Modify: `Epistemos/Views/Notes/MarkdownTextStorage.swift` (processEditing, applySpanStyle for BlockReference)
- Modify: `Epistemos/Views/Notes/ProseEditorRepresentable.swift` (Coordinator — shouldChangeText, textDidChange)
- Modify: `Epistemos/Views/Notes/TransclusionOverlayView.swift` (eventually remove, but keep for fallback during transition)

### Part A: Custom attributes for transclusion ranges

**Step 1: Define custom NSAttributedString.Key values**

In `MarkdownTextStorage.swift` (top of file, after imports):

```swift
extension NSAttributedString.Key {
    static let transclusionBlockId = NSAttributedString.Key("EpistemosTransclusionBlockId")
    static let transclusionSourcePageId = NSAttributedString.Key("EpistemosTransclusionSourcePageId")
    static let transclusionOriginalRange = NSAttributedString.Key("EpistemosTransclusionOriginalRange")
}
```

### Part B: Expand `((blockId))` into source content

**Step 2: In `applySpanStyle()` for BlockReference (kind 24), ~line 680:**

Currently block references get accent pill + underline + cursor pointer + custom attribute `EpistemosBlockRef`. Instead of just styling the `((blockId))` syntax, we expand it inline.

**IMPORTANT:** This is the most complex change. The expansion must:
1. Detect `((blockId))` in the text
2. Look up the block content via BTK (FFI)
3. Replace the visual representation with the expanded content + background tint
4. Keep the original `((blockId))` in the underlying text (for saving to disk)
5. Only expand visually — the model text stays as `((blockId))`

**Approach: Use NSLayoutManager glyph substitution, not NSTextStorage text replacement.**

Actually, the simpler approach is: keep the `((blockId))` text in storage, but use a custom `NSTextAttachment` or an overlaid `NSView` at the glyph rect. This avoids destabilizing NSTextStorage.

**Revised approach — attributed overlay:**

The existing `TransclusionOverlayManager` already positions overlays at `((blockRef))` locations. Instead of replacing the overlay system entirely, we **make the overlays editable**:

1. Replace `TransclusionOverlayView` (NSView with `hitTest → nil`) with `EditableTransclusionView` (NSTextView subclass)
2. The editable view shows the source block content and accepts edits
3. Edits route through BTK as `UpdateBlock`
4. Source block changes propagate to all views via BTK op notification

**Step 3: Create `EditableTransclusionView`**

```swift
// Epistemos/Views/Notes/EditableTransclusionView.swift
import AppKit

/// An editable text view overlay that displays a transclusion's source block content.
/// Edits are routed through BTK to update the source block.
final class EditableTransclusionView: NSTextView {
    let blockId: String
    let sourcePageId: String
    var onEdit: ((String, String) -> Void)?  // (blockId, newContent) → BTK UpdateBlock

    init(blockId: String, sourcePageId: String, content: String) {
        self.blockId = blockId
        self.sourcePageId = sourcePageId
        super.init(frame: .zero)
        self.string = content
        setupAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupAppearance() {
        isEditable = true
        isSelectable = true
        drawsBackground = true
        backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05)
        font = .systemFont(ofSize: 13)
        textContainerInset = NSSize(width: 4, height: 2)
        isFieldEditor = false
        isRichText = false

        // Left accent border
        wantsLayer = true
        let accent = CALayer()
        accent.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
        accent.frame = CGRect(x: 0, y: 0, width: 3, height: 10000)
        layer?.addSublayer(accent)
    }

    override func didChangeText() {
        super.didChangeText()
        onEdit?(blockId, string)
    }
}
```

**Step 4: Update `TransclusionOverlayManager` to use `EditableTransclusionView`**

Replace the creation of `TransclusionOverlayView` with `EditableTransclusionView`. Wire the `onEdit` callback to the Coordinator's BTK translator:

```swift
// In TransclusionOverlayManager (when creating overlays):
let overlay = EditableTransclusionView(
    blockId: blockId,
    sourcePageId: sourcePageId,
    content: blockContent
)
overlay.onEdit = { [weak self] blockId, newContent in
    // Route through BTK: UpdateBlock(blockId, newContent)
    self?.onBlockEdit?(blockId, newContent)
}
```

**Step 5: Wire BTK UpdateBlock in Coordinator**

In `ProseEditorRepresentable.Coordinator`, when setting up the TransclusionOverlayManager:

```swift
transclusionManager?.onBlockEdit = { [weak self] blockId, newContent in
    guard let translator = self?.blockEditTranslator else { return }
    // Apply UpdateBlock op via BTK
    translator.applyUpdateBlock(blockId: blockId, content: newContent)
}
```

**Step 6: Add provenance badge on hover**

Override `mouseMoved(with:)` in `EditableTransclusionView` to show a tooltip:

```swift
override func resetCursorRects() {
    addCursorRect(bounds, cursor: .iBeam)
}

override var toolTip: String? {
    get { "from [[\(sourcePageId)]]" }
    set { }
}
```

**Step 7: Run build to verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 8: Commit**

```bash
git add Epistemos/Views/Notes/EditableTransclusionView.swift Epistemos/Views/Notes/TransclusionOverlayManager.swift Epistemos/Views/Notes/ProseEditorRepresentable.swift
git commit -m "feat: editable transclusion — EditableTransclusionView replaces read-only overlay"
```

---

## Task 8: Retire BlockReconciler

**Goal:** Remove `BlockReconciler.swift` and all its call sites. BTK is now the sole block management system.

**Prerequisites:** All previous tasks completed and verified. BTK enabled and stable.

**Files:**
- Delete: `Epistemos/Sync/BlockReconciler.swift`
- Modify: `Epistemos/Views/Notes/ProseEditorView.swift` (~line 141-142, remove reconcile call)
- Modify: `Epistemos/Views/Notes/ProseEditorView.swift` (~line 159, remove initialPopulate call)
- Modify: `Epistemos/Views/Notes/ProseEditorRepresentable.swift` (lines 322-340, remove BTK feature flag check — BTK is always on)

**Step 1: Verify BTK is working before removal**

Run: `defaults write com.epistemos.app epistemos.btk.enabled -bool true`

Open the app. Create a note, type text, verify blocks are created via BTK. Edit text, verify block IDs are stable. Check `((blockRef))` references survive heavy editing.

**Step 2: Remove feature flag guard in ProseEditorView**

In `ProseEditorView.swift` at ~line 141:

**Before:**
```swift
if !UserDefaults.standard.bool(forKey: "epistemos.btk.enabled") {
    BlockReconciler.reconcile(pageId: pageId, markdown: newValue, context: modelContext)
}
```

**After:** Delete these lines entirely.

Similarly, remove the `initialPopulate` call at ~line 159 and its surrounding guard.

**Step 3: Remove feature flag guard in ProseEditorRepresentable**

In `ProseEditorRepresentable.swift` at ~lines 322-340:

**Before:**
```swift
if UserDefaults.standard.bool(forKey: "epistemos.btk.enabled"),
   let graphState = graphState {
    coord.blockEditTranslator = BlockEditTranslator(pageId: pageId, graphState: graphState)
} else {
    coord.blockEditTranslator = nil
}
```

**After:**
```swift
if let graphState = graphState {
    coord.blockEditTranslator = BlockEditTranslator(pageId: pageId, graphState: graphState)
}
```

**Step 4: Delete `BlockReconciler.swift`**

```bash
rm Epistemos/Sync/BlockReconciler.swift
```

Remove it from the Xcode project if needed (it should auto-detect the missing file).

**Step 5: Run build + tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (no remaining references to BlockReconciler)

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "(FAIL|error:)" | head -20`
Expected: No new failures. Any tests that tested BlockReconciler directly should also be deleted.

**Step 6: Delete BlockReconciler tests**

```bash
find EpistemosTests -name "*BlockReconciler*" -delete
```

**Step 7: Commit**

```bash
git add -u
git commit -m "refactor: retire BlockReconciler — BTK is now the sole block management system"
```

---

## Verification Checklist

After all 8 tasks are complete:

1. [ ] `cd graph-engine && cargo test` — all Rust tests pass
2. [ ] `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build` — clean build
3. [ ] `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test` — all Swift tests pass
4. [ ] Block FTS5: search for block content in command palette returns block-level results
5. [ ] Block embeddings: per-block vectors computed and pushed to Rust
6. [ ] NL parser: `QueryParser.parseToAST()` is the only parser entry point; `GraphQueryDSL` deleted
7. [ ] Structured query: `?type=note & created:last_week` in command palette returns correct results
8. [ ] Block properties: `@type=claim` at end of block line renders as styled chip
9. [ ] Block properties: right-click block → "Set Property..." opens editor
10. [ ] Editable transclusion: `((blockId))` shows editable source content; edits propagate to source block
11. [ ] BlockReconciler: deleted; no feature flag checks remain; BTK is always active
