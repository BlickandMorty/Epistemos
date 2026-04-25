# Data, Persistence, and Indexing Audit

Date: 2026-04-25
Hard rules:
- Derived indexes can rebuild.
- User data must not depend on opaque cache only.
- App must tolerate missing/corrupt indexes.
- Index rebuilds must be backgrounded and visible.
- Saves must be debounced/batched where needed.
- Deletions must update all derived indexes.

## Data path table

| Data path | Source of truth | Derived stores | Sync mechanism | Failure risk | Fix |
|---|---|---|---|---|---|
| Note body | SwiftData `SDPage.body` (legacy inline, cleared post-save) + `NoteFileStorage` managed sidecar with Blake3 checksum | vault `.md` (export-only), FTS5 `page_search`+`block_search`, InstantRecall HNSW, Spotlight, graph blocks | `loadBodyAsync` cascade: managed sidecar → R.3 gateway → inline → vault file | LOW — atomic write + checksum + multi-fallback | none |
| Note metadata (title, blocks, properties) | SwiftData `SDPage` | FTS5 indexed_pages → triggers → page_search; block_search; SDGraphNode/Edge | Save trigger; index update on save | LOW | none |
| Chat message | SwiftData `SDChat`+`SDMessage` | none derived (messages don't currently feed FTS5) | n/a | MEDIUM — chat messages are not searchable in FTS5 | (P2) add chat message indexing if Contextual Shadows includes Chats tab |
| Thinking trace | `SDMessage.thinkingTrace` (string field) + `thinkingDurationSeconds` | none | persisted on completion | LOW | none |
| Reasoning summary (provider-side) | persisted in `SDMessage.thinkingTrace` per Master Plan; per-provider verified separately | none | n/a | LOW | verify all four providers route correctly (USER_WIRING_GAPS G15) |
| Run transcript / trace | `agent_core/src/storage/session_store.rs:5-8`: `transcript.jsonl`, `trace.json`, `summary.md`, `artifacts/` | none | session lifecycle | MEDIUM — no per-run "Raw Thoughts" folder + manifest + events.jsonl yet | (P0) add Raw Thoughts artifact per USER_WIRING_GAPS G2 |
| Embeddings | `graph-engine/src/retrieval_index.rs` HNSW + manifest + embeddings binary + documents JSON | InstantRecallService Swift | rebuild via `rebuildIndexAsync` | LOW — bounds-checked, safe | none |
| Search index (FTS5) | GRDB virtual tables `page_search`+`block_search` | n/a (terminal index) | INSERT/DELETE/UPDATE triggers on `indexed_pages` | LOW — FTS5 manages deletions; graceful fallback if module absent | none |
| Graph nodes/edges | SwiftData `SDGraphNode`+`SDGraphEdge` | Rust graph engine in-memory model | bridge update on mutation | LOW | (P2) add Document/RawThought node types when those land |
| Knowledge Core (staged) | SwiftData + watcher | Rust Cozo `DbInstance` (in-memory) | shadow runtime | LOW (off by default; not in production view models) | DEFER per deterministic perf Sprint 3 |
| Vault `.md` files | exported from SwiftData; Apple-Notes-style hybrid | n/a | save trigger; manual sync; conflict detection via `VaultSyncConflict` | LOW — well-structured | none |
| Permission grants | SQLite via `SqlitePermissionService` (path passed via `permission_store_init_at_path`) | n/a | persisted per grant | LOW — survives relaunch | none |
| Audit log (verified_write) | SQLite via `SqliteResourceAuditLog` | n/a | per write | LOW (in-memory by default; on-disk path via `verified_write_init_audit_at_path`) | (P2) ensure on-disk path wired in production |
| Settings / UserDefaults | UserDefaults (bookmark, lastVaultPath, etc.) | n/a | live | LOW | none |
| API keys | macOS Keychain via SecItem* (per CLAUDE.md non-negotiable) | n/a | live | LOW | none |
| Spotlight index | macOS Spotlight via SpotlightIndexer | n/a | per save (verify R.3 gateway path) | LOW | none |

## Migration / rebuild paths

- **Vault re-index on import**: `InstantRecallService.rebuildIndexAsync` is async + off-MainActor; sync `rebuildIndex` exists at `:258` and must be hard-deprecated (PERFORMANCE_CONCURRENCY_AUDIT P1).
- **FTS5 corruption**: graceful fallback if FTS5 module absent (`SearchIndexService.swift:287+326`); rebuild possible by re-running INSERT triggers.
- **HNSW corruption**: rebuild from manifest + embeddings on load.
- **Database migration**: GRDB migrator pattern; SwiftData lightweight migration; no heavy schema changes pending.

## Hard-rule compliance

| Rule | Status | Evidence |
|---|---|---|
| Derived indexes can rebuild | YES | InstantRecall + FTS5 + Spotlight all have rebuild paths |
| User data not in opaque cache only | YES | NoteFileStorage with Blake3 sidecar + vault `.md` export |
| Tolerate missing/corrupt indexes | YES | FTS5 graceful fallback; HNSW rebuild on load |
| Index rebuilds backgrounded + visible | PARTIAL | Async path exists; visibility (progress UI) absent |
| Saves debounced/batched | YES | 300ms binding + 5s disk per ProseEditor; debounced binding sync |
| Deletions update derived indexes | YES | FTS5 trigger on DELETE; SwiftData cascade |

## Risks

1. **HIGH (P1)**: Chat messages not in FTS5 — Contextual Shadows Chats tab will need a separate index strategy or chat message FTS5 inclusion.
2. **HIGH (P0)**: Raw Thoughts artifact persistence missing (USER_WIRING_GAPS G2).
3. **MEDIUM**: index-rebuild progress not surfaced to user. Add progress bar in vault import / re-index flow.
4. **MEDIUM**: verified-write audit log path defaults to in-memory; ensure production wires `verified_write_init_audit_at_path`.
5. **LOW**: SwiftData @Query refetch storms during AI streaming (ANTI-PATTERN per AGENTS.md). Mitigated by `page.needsVaultSync` discipline (always `try? modelContext.save()` after dirty flag per AGENTS.md §"The Unpersisted Dirty Flag").

## Verdict

Persistence is sound. Multi-fallback read cascade is robust. Atomic writes with checksums are real. Derived indexes are rebuildable. The two real product gaps are: Raw Thoughts artifact persistence (P0) and chat message FTS5 inclusion (P1). Everything else is polish.

Confidence: HIGH (file:line evidence verified across SwiftData, NoteFileStorage, SearchIndexService, InstantRecallService, retrieval_index.rs).
