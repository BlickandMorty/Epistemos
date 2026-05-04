# Data + Persistence + Indexing Audit

Date: 2026-04-28

Verdict: The source-of-truth doctrine is mostly coherent now: Prose remains native/file-backed, `.epdoc` uses canonical ProseMirror JSON, Raw Thoughts are run artifacts, and readable blocks are derived search projections. The remaining risk is app-level propagation: component tests prove core projection/index behavior, but every live save/index/delete path still needs runtime proof before ship claims.

## Required Data Path Table

| Data path | Source of truth | Derived stores | Sync mechanism | Failure risk | Fix |
|---|---|---|---|---|---|
| Prose note body | Existing note file / SwiftData page model | FTS/search, graph, recall index | Vault sync and search index services | stale search/graph if save path skips index update | Verify save -> index -> graph smoke |
| `.epdoc` document | `Title.epdoc/content.pm.json` via `EpdocPackage.contentJSON` | `projections/shadow.md`, `plain.txt`, `search_blocks.jsonl`, readable blocks, graph | `EpdocDocument.fileWrapper(ofType:)` plus projection/index hooks | derived projection stale or missing | Regenerate projections; never make shadow canonical |
| `.epdoc` manifest | `manifest.json` | graph/search metadata | NSDocument package read/write | manifest updated before canonical write could misrepresent saved body | Atomic package write ordering test |
| Raw Thoughts run | run `manifest.json` plus `events.jsonl` / provider/tool files | UI scan, graph nodes, search projection | Rust emitter plus Swift Raw Thoughts scan/inspector | malformed manifest, missing reverse links, runtime browse gap | run-link/search/graph tests; partial-line recovery is component-proven |
| Provider reasoning surfaces | provider-exposed thinking/reasoning summaries/encrypted content | Raw Thoughts timeline, summaries | agent loop event capture | live replay path not smoked | keep byte-identical storage tests green; add live replay/run smoke if replay ships |
| Search/readable blocks | Derived from artifact canonical bodies | FTS5/readable_blocks tables | `ReadableBlocksIndex.replaceAllForArtifact` | table stale or empty if producer not called | Component tests for typed hits/delete/rename are green; live producer wiring still needs smoke |
| Instant Recall embeddings | Derived from notes/artifacts | HNSW/retrieval index | async rebuild/update | stale recall or launch/typing stall | async-only rebuild and visible index status |
| Graph nodes/edges | Derived from typed artifacts and explicit links | graph store/renderer | graph builder/index update | graph explosion or stale edges after delete | typed edge tests and deletion handling |
| Code files | User source file | syntax spans, outline, symbols, graph/provenance | code editor save/index | wrong UTF-8/UTF-16 ranges; full-file hot path | Unicode tests and visible-range indexing |
| Model/provider settings | User defaults/keychain/config | Settings UI state | Settings services | MAS copy or provider state mismatch | settings tests and privacy manifest drift tests |

## Source-of-Truth Rules

- Prose stays native and is not replaced by `.epdoc`.
- `.epdoc` canonical rich body is `content.pm.json`; `shadow.md` is derived.
- External `shadow.md` edits must become a reviewable import/new version, not silent canonical overwrite.
- Raw Thoughts store observable provider/app-owned surfaces only.
- Search/readable blocks are rebuildable and never canonical.
- Graph semantic/structural edges are rebuildable unless user-explicit.

## Current Evidence

- `.epdoc` package code exists in `Epistemos/Models/EpdocPackage.swift`.
- `.epdoc` NSDocument save/open code exists in `Epistemos/Engine/EpdocDocument.swift`.
- Markdown projection code exists in `Epistemos/Models/ProseMirrorMarkdownProjector.swift`.
- Readable blocks schema and FTS exist in `Epistemos/Sync/ReadableBlocksIndex.swift`; typed hit, delete, and stable-ID rename/update behavior is covered by `/tmp/epistemos_derived_store_patch7_tests.log`.
- Search service integrates readable-block setup in `Epistemos/Sync/SearchIndexService.swift`.
- Raw Thoughts Rust storage exists in `agent_core/src/storage/raw_thoughts.rs`.
- Raw Thoughts Swift browser state exists in `Epistemos/State/RawThoughtsState.swift`.
- Raw Thoughts UI section exists in `Epistemos/Views/RawThoughts/RawThoughtsSection.swift`.

## Gaps

| Gap | Priority | Required proof |
|---|---:|---|
| `.epdoc` package save -> shadow -> search_blocks -> readable_blocks integration is code/test proven; live WebView open/edit/save remains manual-runtime only | P1 | Runtime create/edit/save `.epdoc`; query exact block; open artifact/block |
| Raw Thoughts partial JSONL recovery and Anthropic redacted-thinking byte preservation are component-proven; run-link/search/graph proof remains incomplete | P1 | create a real run, browse it, open linked artifacts, and verify search/graph linkage if enabled |
| Deletion/rename/move propagation is component-proven for readable blocks and basic GraphStore cleanup, but not live app-wide across recall/search/graph | P1 | delete/rename artifact in the app and verify derived stores update or rebuild |
| Chat artifacts may not be indexed distinctly for recall/search | P1 | chat run/message indexed with artifact kind and block id |
| Instant Recall sync rebuild path remains callable | P1 | production callers async-only |
| Code editor derived syntax/index data needs Unicode mapping tests | P1 | UTF-8 byte offsets to UTF-16 ranges fixtures |

## Hard Rules

- Derived indexes can rebuild.
- User data must not depend on opaque cache only.
- App must tolerate missing/corrupt derived indexes.
- Index rebuilds must be backgrounded and visible.
- Saves must be debounced or batched where needed.
- Deletions must update all derived indexes or mark them stale for rebuild.

## Minimal Verification Matrix

| Flow | Required result |
|---|---|
| Save Prose note | file/SwiftData saved, FTS updated, graph/recent state not stale |
| Save `.epdoc` | `content.pm.json` canonical, projections regenerated, search hit opens block; code/test proof is green, runtime smoke deferred |
| Corrupt `.epdoc` projection | app regenerates projection from canonical body; covered by `/tmp/epistemos_epdoc_projection_tests.log` for stale/external projections |
| Append Raw Thoughts events | manifest/events valid; UI sees run; search/graph link created if enabled |
| Partial Raw Thoughts final line | previous valid events remain readable; covered by `/tmp/epistemos_raw_thoughts_state_patch5_tests.log` |
| Delete artifact | search/readable blocks/recall/graph derived state removed or rebuilt; readable-block delete + GraphStore cleanup component proof is green |
| Rename/move artifact | stable artifact ID preserved; path updates; readable-block title/path replacement component proof is green |
