# Audit Progress
Last updated: 2026-03-02 15:00

## Current Position
**AUDIT COMPLETE + POST-AUDIT SCAN CLEAN.** All hardening waves (1-13) fully reviewed. All Wave 17 bugs triaged (17.7-17.15). Deferred items re-evaluated — W7.4 and W13.2 confirmed implemented. Post-audit scan of 67 changed files (note-chat system, command palette rewrite, graph store optimization, Siri integration, graph physics tuning) found zero issues — all new code follows established patterns.

## Session Stats (cumulative)
Tests before: 549 (Rust) + 194 suites / 1403 tests (Swift) | Tests after: 549 (Rust) + 192 suites / 1404 tests (Swift)
Fixes total: 18 (16 prior + 2 deferred→done) | Deferred: 3 (W12.1, W17.13, W17.15)

## Pre-Audit Fixes
- [x] Keychain Data Protection migration (commit efd2ab6) — not audit item
- [x] 11 stale Rust test assertions fixed (commit 9abb941) — not audit item
- [x] Legacy keychain migration disabled (commit a13307a) — not audit item

## Completed (Waves 1-13)
- [x] 1.1: Per-Node Highlight Flag Buffer — ALREADY IMPLEMENTED
- [x] 1.2: Pre-Allocate Scratch Buffers — ALREADY IMPLEMENTED
- [x] 1.3: Pre-Allocate Field Line Buffer — ALREADY IMPLEMENTED
- [x] 1.4: Straight-Line Edges — ALREADY IMPLEMENTED
- [x] 1.5: Remove Motion Blur — ALREADY IMPLEMENTED
- [x] 1.6: List Virtualization — ALREADY IMPLEMENTED
- [x] 1.7: Search Debouncing — FIXED (commit d6204c4)
- [x] 1.8: Background Graph Loading — FIXED (commit 83fa3a4)
- [x] 1.9: Search Result Caching — NOT A BUG (150ms debounce + Rust FFI already mitigate)
- [x] 1.10: Frustum Culling — NOT A BUG (instanced rendering, GPU clips automatically)
- [x] 1.11: SwiftData Prefetch Relationships — FIXED (commit 3252068)
- [x] 2.5: Diff-Based Graph Rebuild — ALREADY IMPLEMENTED (GraphBuilder.persist)
- [x] 5.1: Front-Matter Parsing Edge Cases — FIXED (commit f4c223a, BOM + comments)
- [x] 5.2: Filename Collision Edge Case — FIXED (commit bb53d95)
- [x] 5.3: Version Pruning Race — NOT A BUG (@MainActor serialization)
- [x] 5.4: Empty Vault Context Crash Risk — NOT A BUG (zero callers, dead code)
- [x] 5.5: FTS5 Query Injection — FIXED (commit 8374d49)
- [x] 6.1: Graph Version Tracking — NOT A BUG (@MainActor)
- [x] 6.2: MetalGraphView Engine Handle Race — NOT A BUG (all FFI have nil guards)
- [x] 6.3: Pipeline Task Cancellation Race — FIXED (commit 21299e5)
- [x] 6.4: SwiftData Context Crossing — NOT A BUG (@MainActor isolation)
- [x] 7.2: Embedding Service Growth — NOT A BUG (full replacement per cycle)
- [x] 7.3: Note Body Memory-Mapped File Leak — NOT A BUG (mmap Data is function-scoped)
- [x] 8.1: FFI String Lifetime Safety — AUDITED SAFE + DOCUMENTED (commit b5e9e9a)
- [x] 8.2: Metal Layer Pointer Retain — NOT A BUG (Rust objc_retain)
- [x] 8.3: Missing Null Checks in FFI — NOT A BUG (all calls guarded)
- [x] 9.1: Batch Delete Cascade Violation — FIXED (commit 00d064c)
- [x] 9.2: Predicates with Arrays Crashing — ALREADY IMPLEMENTED (individual fetches)
- [x] 9.3: Transient Cache Invalidation — FIXED (commit 4ce963f)
- [x] 10.1: API Key iCloud Sync Risk — FIXED (commit 8c17c42)
- [x] 10.2: Spotlight Indexing Leaks Note Content — FIXED (commit f4c223a)
- [x] 10.3: Vault Path Exposure in Logs — FIXED (commit 9b8fc96)
- [x] 11.1: Silent Failures in Graph Operations — FIXED (commit f3ba40a)
- [x] 11.2: LLM Stream Error Handling — MOSTLY MITIGATED (stream errors surface to UI; enrichment fallbacks by design)
- [x] 11.3: File I/O Errors Not Distinguished — NOT A BUG (error details in log object)
- [x] 11 (Metal Safety): Shader compilation panics — FIXED (commit b346609)
- [x] 12.2: Dark Mode Detection Race — FIXED (commit d987851)
- [x] 13.1: Quadtree Degradation — NOT A BUG (MAX_DEPTH + distance_min clamp)
- [x] 13.3: Spotlight Reindex on Every Launch — NOT A BUG (UserDefaults persists)

## Completed (Wave 17 — Bug Triage)
- [x] 17.12: Chat Cannot Access Note Bodies — NOT A BUG (design: @-mentions load full bodies, ambient is lightweight by design)
- [x] 17.14: Password Prompt on Every Launch — FIXED (commit a13307a, legacy migration disabled)
- [x] 17.7: Fix Search Highlight Glitch — NOT A BUG (by design: Ask item selected when no search results; selection correctly skips to first result when results exist)
- [x] 17.9: Fix Daily Briefs — NOT A BUG (already routes through Apple Intelligence for .brainstorm; cloud fallback by design for .epistemicLens; feature fully functional)
- [x] 17.10: Launch & Shortcut Fixes — ALREADY IMPLEMENTED (1100×720 default window, Cmd+H→landing, status bar Home, Cmd+N new note, Cmd+2 notes)
- [x] 17.8: Fix Missing Vault Notes — NEEDS REPRODUCTION (activePagesDescriptor filters only isArchived; all non-archived pages flow to sidebar + graph; no architectural gap found; nested pages show flat but aren't missing)

## Previously Deferred → Now Fixed
- [x] 1.8: Background Graph Loading — FIXED (commit 83fa3a4, BackgroundGraphActor @ModelActor)
- [x] 1.12: Incremental FFI Graph Updates — FIXED (commit 97f4a59, pending queue + render loop drain)
- [x] 7.1: Unbounded Version Storage — FIXED (commit 79be726, 10K global limit)

## Post-Audit Fix (2026-03-03)
- [x] 17.16: Note-Saving Bug — FIXED (commit 7db6a00, removed premature modelContext.save() calls)

## Previously Deferred → Now Confirmed Implemented
- [x] 7.4: Graph Store Memory Explosion — IMPLEMENTED (Int-indexed arrays: _nodeIdx, _neighbors, _edgesOf + AdjacencyProxy/EdgesByNodeProxy wrappers)
- [x] 13.2: Fuzzy Search Scalability — IMPLEMENTED (trigram index: _trigramIdx with posting lists)

## Remaining Deferred
- [ ] 12.1: Zero-State Handling — UI feature (EmptyStateView), not hardening. Reclassified OUT_OF_SCOPE.
- [ ] 17.13: App Crashes Creating Note — Full code path traced: handleWikilinkClick → createPage → context.save() → open(). All @MainActor serialized. No race or crash vector found. Needs actual crash log to reproduce.
- [ ] 17.15: Graph Overlay Not Robust — Architecture change: NSWindow→NSPanel, ~300 lines refactor. Overlay works but uses fragile borderless window + manual z-order + Metal view reparenting during minimize. Fix requires NSPanel + NSWindowController migration.

## Out of Scope (features, not hardening)
- Waves 2.1-2.4, 2.6-2.8: Architecture refactoring
- Wave 3: Build infrastructure and testing
- Wave 4: Second brain features
- Wave 2.8: UserDefaults/SwiftData split-brain (needs new SDSavedPaper model)
- Waves 14-21: Vision & Growth features

## Summary
| Category | Count |
|----------|-------|
| Items reviewed | 53 |
| Fixed with commit | 18 |
| Already implemented | 11 (9 prior + W7.4 + W13.2) |
| Not a bug / mitigated | 18 (15 prior + W17.7 + W17.8 + W17.9) |
| Already implemented (Wave 17) | 1 (W17.10) |
| Deferred (architecture) | 1 (W17.15) |
| Deferred (needs crash log) | 1 (W17.13) |
| Reclassified out of scope | 1 (W12.1) |
| Out of scope (features) | ~50+ (Waves 14-20) |
| Final scan pass | CLEAN (no crash risks found) |
| Post-audit scan (2026-03-02) | CLEAN (67 files, 0 issues) |

## Current Session Log
| # | Wave.Item | Description | Gate | Status | Commit |
|---|-----------|-------------|------|--------|--------|
| 1 | 1.1 | Highlight flag buffer | — | ALREADY DONE | — |
| 2 | 1.2 | Physics scratch buffers | — | ALREADY DONE | — |
| 3 | 1.3 | Field line buffer | — | ALREADY DONE | — |
| 4 | 1.4 | Straight-line edges | — | ALREADY DONE | — |
| 5 | 1.5 | Motion blur removal | — | ALREADY DONE | — |
| 6 | 1.6 | List virtualization | — | ALREADY DONE | — |
| 7 | 1.7 | Search debouncing | 3/4 | FIXED | d6204c4 |
| 8 | 1.9 | Search result caching | — | NOT A BUG | — |
| 9 | 1.10 | Frustum culling | — | NOT A BUG | — |
| 10 | 1.11 | Prefetch relationships | 4/4 | FIXED | 3252068 |
| 11 | 2.5 | Diff-based graph rebuild | — | ALREADY DONE | — |
| 12 | 5.1 | Front-matter parsing | 4/4 | FIXED | f4c223a |
| 13 | 5.2 | Filename collision | 4/4 | FIXED | bb53d95 |
| 14 | 5.3 | Version pruning race | — | NOT A BUG | — |
| 15 | 5.4 | Empty vault context | — | NOT A BUG | — |
| 16 | 5.5 | FTS5 query injection | 4/4 | FIXED | 8374d49 |
| 17 | 6.1 | Graph version atomicity | — | NOT A BUG | — |
| 18 | 6.2 | Engine handle race | — | NOT A BUG | — |
| 19 | 6.3 | Pipeline cancellation | 4/4 | FIXED | 21299e5 |
| 20 | 6.4 | SwiftData context crossing | — | NOT A BUG | — |
| 21 | 7.2 | Embedding growth | — | NOT A BUG | — |
| 22 | 7.3 | Mmap file leak | — | NOT A BUG | — |
| 23 | 8.1 | FFI string lifetime | — | AUDITED SAFE | b5e9e9a |
| 24 | 8.2 | Metal layer retain | — | NOT A BUG | — |
| 25 | 8.3 | FFI null checks | — | NOT A BUG | — |
| 26 | 9.1 | Batch delete cascade | 4/4 | FIXED | 00d064c |
| 27 | 9.2 | Predicates with arrays | — | ALREADY DONE | — |
| 28 | 9.3 | Transient cache | 4/4 | FIXED | 4ce963f |
| 29 | 10.1 | API key iCloud sync | 4/4 | FIXED | 8c17c42 |
| 30 | 10.2 | Spotlight body exposure | 4/4 | FIXED | f4c223a |
| 31 | 10.3 | Vault path privacy | 4/4 | FIXED | 9b8fc96 |
| 32 | 11.1 | GraphBuilder silent fails | 4/4 | FIXED | f3ba40a |
| 33 | 11.2 | LLM stream errors | — | MITIGATED | — |
| 34 | 11.3 | File I/O errors | — | NOT A BUG | — |
| 35 | 11 | Metal shader panics | 4/4 | FIXED | b346609 |
| 36 | 12.2 | Dark mode detection | 4/4 | FIXED | d987851 |
| 37 | 13.1 | Quadtree degradation | — | NOT A BUG | — |
| 38 | 13.3 | Spotlight reindex | — | NOT A BUG | — |
| 39 | 17.12 | Chat note bodies | — | NOT A BUG | — |
| 40 | 17.13 | Crash creating note | — | DEFERRED | — |
| 41 | 17.14 | Password prompt | — | FIXED | a13307a |
| 42 | 1.8 | Background graph loading | 4/4 | FIXED | 83fa3a4 |
| 43 | 7.1 | Global version pruning | 4/4 | FIXED | 79be726 |
| 44 | 1.12 | Incremental FFI updates | 4/4 | FIXED | 97f4a59 |
| 45 | 7.4 | Graph Store Int-indexed | — | CONFIRMED DONE | — |
| 46 | 13.2 | Trigram fuzzy search | — | CONFIRMED DONE | — |
| 47 | 17.7 | Search highlight glitch | — | NOT A BUG | — |
| 48 | 17.8 | Missing vault notes | — | NEEDS REPRO | — |
| 49 | 17.9 | Daily briefs broken | — | NOT A BUG | — |
| 50 | 17.10 | Launch & shortcuts | — | ALREADY DONE | — |
| 51 | 17.15 | Graph overlay robustness | — | DEFERRED | — |
| 52 | — | Final scan: try!/as!/fatalError | — | CLEAN | — |
| 53 | — | Final scan: nonisolated(unsafe) | — | CLEAN | — |
| 54 | — | Post-audit: 67 files changed scan | — | CLEAN | — |
