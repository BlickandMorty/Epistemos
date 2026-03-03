# Phase 1 + Phase 2 Remaining Features — Design

**Date:** 2026-03-03
**Source of Truth:** `competitive-execution-roadmap.md`

## Goal

Implement all 8 remaining NOT DONE items from Phases 1 and 2 of the competitive execution roadmap. These close every hard gap with Logseq (block identity, query substrate, transclusion, search granularity).

## Features

### Phase 1 Remaining

| # | Feature | Key File(s) | Depends On |
|---|---------|-------------|------------|
| 1 | Block-level FTS5 index | SearchIndexService.swift | BTK (exists) |
| 2 | Block-level embeddings | EmbeddingService.swift | BTK (exists) |
| 3 | Block search in command palette | CommandPaletteOverlay.swift | #1, #2 |
| 4 | Retire BlockReconciler | BlockReconciler.swift (delete) | All of above |

### Phase 2 Remaining

| # | Feature | Key File(s) | Depends On |
|---|---------|-------------|------------|
| 5 | NL parser → QueryAST only | QueryParser.swift, QueryTypes.swift | — |
| 6 | Structured query in palette | CommandPaletteOverlay.swift, QueryParser.swift | #5 |
| 7 | Block property system UI | MarkdownTextStorage.swift, ClickableTextView | BTK SetProperty (exists) |
| 8 | Editable transclusion | MarkdownTextStorage.swift, TransclusionOverlayView.swift | BTK (exists) |

## Architecture

### 1. Block-Level FTS5 Index

New `block_search` FTS5 virtual table in SearchIndexService, alongside existing `page_search`:

```sql
CREATE VIRTUAL TABLE block_search USING fts5(
    block_id UNINDEXED,
    page_id UNINDEXED,
    content,
    tokenize='unicode61'
);
```

Trigger: BTK ops via notification. InsertBlock → INSERT, UpdateBlock → UPDATE, DeleteBlock → DELETE.

Search API: `searchBlocks(query:limit:) -> [(blockId, pageId, snippet, rank)]`

### 2. Block-Level Embeddings

Extend EmbeddingService with `computeBlockEmbeddings(pageId:changedBlockIds:)`. Same NLEmbedding word-averaging + vDSP SIMD pipeline. Push per-block embeddings to Rust via `graph_engine_set_node_embedding()` (blocks are node type 7).

Batch: after a BTK op batch, compute embeddings for all changed blocks in one pass. Debounced to avoid recomputing on every keystroke.

### 3. Block Search in Command Palette

Mixed results in CommandPaletteOverlay. Add block results between existing graph and body search tiers:

- Block results: icon (cube.transparent), snippet with highlighted match, parent page title subtitle
- Click: navigate to page via NoteWindowManager, scroll to block offset
- Ranking: BM25 from FTS5, interleaved with page results by score

### 4. Retire BlockReconciler

After all block infrastructure verified:
1. Remove `BlockReconciler.reconcile()` call from `ProseEditorView.debouncedSave()`
2. Remove `BlockReconciler.initialPopulate()` call from page open path
3. Delete `BlockReconciler.swift`
4. Remove BTK feature flag guard (BTK becomes default)

### 5. NL Parser → QueryAST Only

Currently `QueryParser` has dual output: `parse()` → GraphQueryDSL, `parseToAST()` → QueryAST.

1. Audit all callers of `parse()` — migrate to `parseToAST()`
2. Remove `parse()` method and `GraphQueryDSL` enum
3. Clean up `QueryTypes.swift` — remove DSL types, keep QueryAST types
4. All query execution flows through QueryCompiler → QueryRuntime

### 6. Structured Query in Command Palette

`?` prefix in search field triggers structured parser:
- `?type=note & created:last_week`
- `?tag=claim & confidence<0.5`
- `?"machine learning" & type=block`

Detection: in CommandPaletteOverlay's search handler, check `searchText.hasPrefix("?")`. Route to `StructuredQueryParser.parse()` → QueryAST → QueryCompiler → QueryRuntime.

Results displayed in same list as NL results with structured query badge.

### 7. Block Property System UI

Two entry points:
- **Context menu:** Right-click block in editor → "Set Property..." → key/value sheet. Sheet shows existing properties + add new. Saves via BTK `SetProperty` op.
- **Inline syntax:** `@key=value` at end of block line. Parsed by MarkdownTextStorage, displayed as inline chips (capsule background, dimmed). Stored as BTK SetProperty ops.

### 8. Editable Transclusion

Replace read-only `TransclusionOverlayView` with live attributed range in `MarkdownTextStorage`:

1. In `processEditing()`, when encountering `((blockId))`, replace syntax with source block content + custom attributes (`.transclusionBlockId`, `.transclusionSourcePageId`, background tint)
2. In `shouldChangeText(in:replacementString:)`, detect edits in transclusion range → route through BTK as `UpdateBlock` targeting source block
3. BTK op stream notifies other pages transcluding same block → update their ranges
4. Provenance badge on hover: "from [[PageName]]" with click-to-navigate

## Implementation Order

1. Block FTS5 → Block Embeddings → Block Palette Search
2. NL Parser cleanup → Structured Query Palette
3. Block Property UI
4. Editable Transclusion
5. Retire BlockReconciler (last)

## Risks

- **BTK in-memory only:** Block FTS5 serves as a secondary persistence layer (rebuilt from SwiftData on launch, kept live by BTK ops). This is fine for now.
- **Editable transclusion complexity:** NSTextStorage range management is fragile. Must handle cursor position, undo/redo, and multi-window editing of same source block. Incremental approach: start with single-window, add multi-window propagation after.
- **GraphQueryDSL removal:** Must audit all callers exhaustively. Any missed caller = compile error (good — the compiler catches it).
