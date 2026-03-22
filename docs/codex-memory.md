# Epistemos — Codex Knowledge Transfer Document

> **Purpose:** Comprehensive app knowledge for any AI agent working on this codebase. Read this before touching anything. Updated 2026-03-06.

---

## 1. What Is Epistemos

A macOS-native knowledge graph + note-taking app. Think Obsidian meets force-directed graph visualization, with AI-powered analysis. Written in Swift (SwiftUI + AppKit + Metal) with a Rust graph engine via FFI.

**Target:** Apple Design Award quality. One user (the developer), shipping to macOS App Store.

**Two editions exist — NEVER cross-contaminate:**
- **Opulent** (this repo, `~/Epistemos/`) — Swift + Metal + Rust. macOS only.
- **Retro** (`~/Epistemos-RETRO/`) — Tauri + Next.js + Rust. Windows. Completely separate project.

---

## 2. Architecture

```
User → SwiftUI Views → @Observable State → Services (Engine/) → Rust FFI (graph-engine/)
                                          → SwiftData (Models/)
                                          → Apple Intelligence (TriageService)
```

### Layer Inventory

| Layer | Files | LOC (approx) | Key Classes |
|-------|-------|--------------|-------------|
| Swift source (non-test) | 177 | ~35K | — |
| Rust source | 49 | ~12K | — |
| @Observable state | 18 classes | — | GraphState, ChatState, NoteChatState, DialogueChatState, SOARState, PipelineState, UIState, PhysicsCoordinator |
| Services (Engine/) | 30 files | ~7K | TriageService, PipelineService, LLMService, SOARService, QueryEngine |
| SwiftData models | 9 models | — | SDPage, SDBlock, SDGraphNode, SDGraphEdge, SDFolder, SDChat, SDMessage, SDPageVersion |
| FFI functions | 68 | — | graph_engine.h bridge header |
| Tests | 1404 Swift (194 suites) + 549 Rust | — | Swift Testing framework (@Suite/@Test) |

### Data Flow

```
Notes (markdown files in vault)
  → VaultSyncService reads/writes to Application Support
  → SDPage (SwiftData) stores metadata
  → SDBlock (SwiftData) stores block-level structure
  → GraphBuilder generates SDGraphNode + SDGraphEdge
  → GraphStore holds compact Int-indexed graph in memory
  → GraphState bridges to Rust engine via FFI
  → Rust engine runs physics simulation + Metal rendering
  → MetalGraphView displays in SwiftUI via NSViewRepresentable
```

---

## 3. Design Philosophy

### Core Principles
1. **Performance is architecture.** Zero per-frame allocations. Pre-allocate buffers. Debounce hot paths. Cache expensive results. Gate animations with `windowOccluded`.
2. **Direct communication.** No wrappers around wrappers. Shortest path from intent to execution.
3. **DRY ruthlessly.** Three similar lines tolerable, four is not. Extract shared functions.
4. **Minimal changes.** Bug fix = bug fix. Don't refactor adjacent code. Don't add features beyond scope.
5. **Test-first.** Failing test before fix. Edge cases: empty, nil, max, unicode, concurrent, rapid toggle.
6. **Read before writing.** Never modify a file you haven't read first.

### Patterns (MUST follow)
- `@MainActor @Observable` for all state. Never `ObservableObject`.
- `withAppEnvironment(bootstrap)` for environment injection. Never manual `.environment()` chains.
- `nonisolated(unsafe)` for NSView properties from AppKit event handlers.
- `Task { @MainActor in }` for delayed work. Never `DispatchQueue.main.asyncAfter`.
- Swift Testing (`@Suite` + `@Test` + `#expect`). Never XCTest.
- `guard let` / `if let`. Never force unwrap (`!`).
- `do/catch`. Never `try!`.
- `Int(floatValue)` traps on NaN — always guard with `.isFinite` first.
- Rust: `#[repr(C)]` on FFI structs. `// SAFETY:` on every `unsafe`. `with_capacity()` in hot paths.

### Anti-Patterns (learned from real bugs)
- **Binding Cascade:** Coordinator writes `parent.text` → onChange → `needsVaultSync = true` → @Query refetch → body re-evaluates → disk read. **Fix:** Debounce 300ms. Never sync during streaming.
- **Zone Protection Gap:** `shouldChangeTextIn` only guards during streaming. After stream ends but before accept/discard, edits above divider corrupt offset. **Fix:** Guard whenever `hasDivider` is true.
- **Multi-Turn Double Insertion:** Second query with existing divider appends tokens raw without header. **Fix:** Track `lastFlushedTurnCount`, insert header on increase.
- **Environment Sync Drift:** NoteWindowManager's manual `.environment()` list drifted from AppEnvironment. **Fix:** `withAppEnvironment()` everywhere.
- **Unpersisted Dirty Flag:** Setting `needsVaultSync = true` without `modelContext.save()` — @Query predicate never sees it. **Fix:** Always `try? modelContext.save()` immediately.

---

## 4. Key Subsystems

### 4.1 Graph Engine (Rust)

**Entry:** `graph-engine/src/lib.rs` → `renderer.rs`, `physics.rs`, `types.rs`

68 FFI functions. Force-directed physics simulation at 120 ticks/sec. Metal rendering with instanced draw calls. Two visual themes:

```rust
// graph-engine/src/types.rs
pub enum VisualTheme {
    Dialogue = 0,  // FFT-style dialogue overlay
    Classic = 1,   // SDF circles + smooth lines
}
```

**ECS Architecture:** World/Component/System pattern for nodes, edges, physics. Cluster caching. Edge aggregation. Render culling and LOD on ECS.

**Hot paths:** `force_collide()` — collision grid rebuilt every tick. `force_many_body()` — quadtree N-body. `rebuild_classic_buffers()` — geometry upload to Metal. All pre-allocate with `with_capacity()`.

**Dead code in renderer.rs (intentional — dialogue mode):**
- `DialogueState`, `DialogueVertex`, `DialogueUniforms`, `DialogueBoxGeometry`
- `DIALOGUE_SHADER_SOURCE`, face geometry in `rebuild_classic_buffers()`
- `ensure_dialogue_pipeline()`, `dialogue_box_geometry()`, `build_dialogue_vertices()`
- These support `.dialogue` mode's Metal rendering path. The SwiftUI overlay replaced the visual, but the Metal code stays as the `.dialogue` mode infrastructure. Do NOT delete unless explicitly asked.

### 4.2 GraphStore (Compact Storage)

Int-indexed arrays for O(1) adjacency:
- `_nodeIdx: [String: Int]` — node ID → stable compact index
- `_neighbors: [[Int]]` — deduplicated adjacency lists
- `_edgesOf: [[Int]]` — edge reverse index
- `_trigramIdx: [String: [Int]]` — trigram posting lists for fuzzy search
- `AdjacencyProxy` / `EdgesByNodeProxy` wrappers preserve `store.adjacency[nodeId]` syntax

Saves ~46MB at 50K nodes vs previous String-keyed dictionaries.

### 4.3 AI Pipeline

**TriageService** routes by complexity:
- light rewrite / summarize / simple ask → Apple Intelligence when the context stays small
- deeper reasoning / coding / graph / long-context work → local Qwen 3.5
- no cloud fallback in the live app

**PipelineService** runs 3-pass analytical pipeline:
- Pass 1: Streaming answer
- Pass 2+3: Background enrichment (detached tasks)
- Proper task cancellation with thread-safe FinishOnce guard
- Enrichment tasks tracked by query ID, cancelled on new query

**Known issue (Wave 2.3):** SignalGenerator (~500 LOC) generates fake confidence/entropy/dissonance from regex keyword matching. These are polynomials over query length, not real epistemic signals. Needs replacement with real SOAR scores or deletion.

### 4.4 Note Editor

**ProseEditorRepresentable** — NSViewRepresentable wrapping ClickableTextView (NSTextView subclass).
- **MarkdownTextStorage** — live syntax highlighting via `processEditing()`
- **Coordinator** — 300ms debounced binding sync, 500ms table alignment, AI zone callbacks
- **NoteChatState** — per-note AI chat, 60ms token buffering, inline in NSTextStorage below `---` divider
- Accept strips divider, discard removes from divider onward
- `isFlushingTokens` flag prevents binding sync cascade during streaming

### 4.5 Dialogue System (Recently Built)

**DialogueChatState** — Graph-level AI chat via node selection in dialogue theme mode.

**6 Archetypes** (content-derived):
- Archivist (guards evidence), Examiner (pressures claims), Dreamer (tests possibilities)
- Gardener (connects notes), Guide (maps patterns), Sentinel (watches drift)

**DialogueCareState** — Tamagotchi-style health/attention/mood:
- Health decays 0.015/hour idle, attention 0.08/hour
- Interactions boost both
- 5 mood states: thriving, curious, steady, lonely, fragile

**DialoguePresentationTheme** — tactics (parchment) / nocturne (moonlit) palettes with 19-color DialoguePalette struct.

**DialogueOverlayView** — ACTIVELY BEING DEVELOPED. Do not modify without explicit permission. Currently uses GeometryReader layout with portrait panel, mood pills, health/focus meters, keyword chips.

### 4.6 SOAR (Stepping On A Rock)

Learning system with Student/Teacher/Detector/Reward components. 12 files total. Integrated into PipelineService during triage. Probes "learnability edge" on every query. If at edge, runs iterative refinement.

**Status:** Implemented but may be disabled by default. Config persisted via UserDefaults.

### 4.7 BTK (Block Transaction Kernel)

**Problem:** BlockReconciler runs Jaccard similarity every 5s. Heavy edits lose block IDs → dead citations.

**Solution:** Append-only op log in Rust. 6 Rust modules under `graph-engine/src/block_kernel/`:
- `op.rs` — 8 op variants + BlockId
- `op_log.rs` — append-only Vec with sequence numbers
- `block_tree.rs` — materialized from ops
- `projection.rs` — block tree → markdown (round-trip safe)
- `translator.rs` — text edits → ops

**Status:** Rust implementation exists. Swift FFI wiring NOT complete. `BlockEditTranslator.swift` exists as the Swift-side entry point. Integration into ProseEditorRepresentable pending.

### 4.8 Explorer Mode (Approved Design, Not Yet Built)

**Design doc:** `docs/plans/2026-03-06-explorer-platformer-design.md`

Standalone Bevy window (separate binary `epistemos-explorer`). Top-down RPG where graph nodes become NPCs/buildings. Procedural terrain via Perlin noise. Cluster-level roads. IPC via stdin/stdout JSON. Swift exports persona snapshots, Bevy renders them.

**GraphExperienceMode** (Swift-only, not in Rust):
```
.graph    → MetalGraphView (classic or dialogue VisualTheme)
.explorer → Standalone Bevy window
```

**Status:** Design approved by review. Implementation not started.

---

## 5. Vault & Storage

- Note bodies stored as markdown files in Application Support (not inline SQLite)
- SDPage stores metadata (title, dates, flags, folder relationship)
- SDBlock stores block-level structure (hierarchical outline)
- SDPageVersion stores version history (pruned to 10K global limit)
- VaultSyncService handles file ↔ model sync
- NoteFileStorage handles raw file I/O
- SpotlightIndexer indexes for system search (title + tags only, not body content — privacy fix)

---

## 6. Audit Status (Complete)

**53 items reviewed across Waves 1-13. Final scan clean.**

| Category | Count |
|----------|-------|
| Fixed with commit | 18 |
| Already implemented | 11 |
| Not a bug / mitigated | 18 |
| Deferred (architecture) | 1 (W17.15 — graph overlay NSPanel migration) |
| Deferred (needs crash log) | 1 (W17.13 — crash creating note) |
| Out of scope (UI feature) | 1 (W12.1 — zero-state handling) |

**Key fixes applied:**
- Search debouncing (150ms on all entry points)
- Background graph loading (BackgroundGraphActor)
- SwiftData prefetch relationships
- Front-matter parsing (BOM + comments)
- Filename collision (UUID suffix)
- FTS5 query injection sanitization
- Pipeline cancellation race
- Batch delete cascade
- Transient cache invalidation
- API key iCloud sync risk
- Spotlight body exposure
- Vault path privacy in logs
- GraphBuilder silent failures
- Metal shader compilation panics
- Dark mode detection race
- Incremental FFI graph updates
- Global version pruning (10K limit)
- Note-saving bug (premature modelContext.save())

**Post-audit scan (2026-03-02):** 67 changed files scanned, zero issues found.

---

## 7. Known Issues & Deferred Work

### P0 — Must Fix Before v2
- **W2.8: savedPapers split-brain** — UserDefaults vs SwiftData. Paper metadata in two stores. Needs `SDSavedPaper` model. Risk: data loss on iCloud sync.
- **W17.13: Crash creating note** — Reported but no crash log obtained. Full code path traced, no race found. Needs reproduction.
- **W2.3: SignalGenerator fake signals** — ~500 LOC generating polynomial "confidence" from regex. Not real epistemic analysis. Misleads users.

### P1 — Should Fix Before v2
- **W2.2: AppBootstrap god object** — ~700 lines, 78 references across 29 files via `.shared`. Needs AppCoordinator extraction.
- **W17.15: Graph overlay fragility** — Uses NSWindow + manual z-order + Metal reparenting during minimize. Needs NSPanel + NSWindowController migration (~300 LOC refactor).
- **BTK wiring gap** — Rust kernel exists, Swift FFI integration incomplete. BlockReconciler still runs as fallback.

### P2 — Nice to Have
- **W2.6: EventBus removal** — Only 3 subscribers, bus pattern is overkill.
- **W2.7: Conversation history format** — Join-as-string instead of provider-native message arrays.
- **W2.1: AppEnvironment container** — Already partially solved by `withAppEnvironment()`, but 15 separate injections still exist.

### Canceled / Superseded
- **Pixel art theme** — Built (2-pass rendering, square blocks, jagged edges), then renamed to Dialogue theme, then replaced by SwiftUI overlay approach. Pixel rendering infrastructure deleted (commit b1a3609).
- **Face geometry on nodes** — Kirby-style eyes+mouth drawn in Metal on dialogue-active node. Built, confirmed not rendering visually. Code stays as dialogue mode infrastructure.
- **LDtk integration** — Deferred to Explorer v2.
- **Rapier2D physics** — Deferred to Explorer v2 (AABB collision for v1).

---

## 8. Recent History (Last 2 Weeks)

### Graph Engine Evolution (Feb 25 → Mar 5)
1. ECS World/Component/System architecture added
2. Physics systems adapter for ECS
3. VisualTheme enum + VoxelPalette for pixel art mode
4. Two-pass pixel art rendering with square blocks
5. FFI bridge + Swift theme system + UI toggle
6. Render culling and LOD moved onto ECS
7. Cluster cache + edge aggregation integrated
8. Zoom-triggered edge pipeline removed (perf fix)
9. Physics settings made truthful and deterministic

### Dialogue Theme (Mar 5 → Mar 6)
1. VisualTheme::Pixel renamed to VisualTheme::Dialogue
2. Pixel art infrastructure deleted
3. DialogueState + FFT-style box shader added
4. Face geometry on dialogue-active node added
5. DialogueChatState for graph chat
6. DialogueOverlayView with RetroGaming font
7. Integration with MetalGraphView + HologramOverlay
8. Persona system (6 archetypes) + care state (Tamagotchi health/mood)
9. Presentation themes (tactics/nocturne palettes)

### Explorer Mode Design (Mar 6)
1. Design brainstormed and written
2. Three rounds of Codex review
3. Final design approved: standalone Bevy window, IPC, persona snapshots
4. Implementation not yet started

### Bug Fixes (Mar 3 → Mar 6)
1. Note-saving bug fixed (premature modelContext.save())
2. App startup cleanup landed
3. Pending app fixes landed

---

## 9. Testing

```bash
# Swift (1404 tests, 194 suites)
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test

# Rust (549 tests)
cd graph-engine && cargo test

# Quick build check
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
```

Test naming: `<System>Tests.swift`, `<System>EdgeCaseTests.swift`, `<System>ComprehensiveTests.swift`, `<System>AuditTests.swift`.

---

## 10. File Map

| Purpose | Location |
|---------|----------|
| App bootstrap + environment | `Epistemos/App/` |
| State classes (@Observable) | `Epistemos/State/` |
| Services (AI, pipeline, triage) | `Epistemos/Engine/` |
| SOAR subsystem | `Epistemos/Engine/SOAR/` |
| Graph state + builder + store | `Epistemos/Graph/` |
| Graph engine (Rust) | `graph-engine/src/` |
| Block Transaction Kernel (Rust) | `graph-engine/src/block_kernel/` |
| FFI bridge header | `graph-engine-bridge/graph_engine.h` |
| SwiftData models | `Epistemos/Models/` |
| Vault sync + file I/O | `Epistemos/Sync/` |
| Views — Graph | `Epistemos/Views/Graph/` |
| Views — Notes | `Epistemos/Views/Notes/` |
| Views — Chat | `Epistemos/Views/Chat/` |
| Views — Landing | `Epistemos/Views/Landing/` |
| Views — Shell | `Epistemos/Views/Shell/` |
| Theme + modifiers | `Epistemos/Theme/` |
| Tests (Swift) | `EpistemosTests/` |
| Design docs | `docs/plans/` |
| Audit bible (21 waves) | `docs/future-work-audit.md` |
| Audit progress | `docs/audit-progress.md` |
| Bug fix docs | `docs/bug-fixes/` |

---

## 11. Key Files to Read First

For ANY subsystem, start with these:

| Subsystem | Start Here | Then Read |
|-----------|-----------|-----------|
| AI Pipeline | `Engine/TriageService.swift` | `PipelineService.swift`, `LLMService.swift` |
| Graph | `Graph/GraphState.swift` | `GraphStore.swift`, `GraphBuilder.swift` |
| Graph Engine | `graph-engine/src/lib.rs` | `renderer.rs`, `physics.rs`, `types.rs` |
| Note Editor | `Views/Notes/ProseEditorRepresentable.swift` | `MarkdownTextStorage.swift` |
| Note Chat | `State/NoteChatState.swift` | `NoteChatOrb.swift`, `NoteWindowManager.swift` |
| Dialogue | `State/DialogueChatState.swift` | `Views/Graph/DialogueOverlayView.swift` |
| Environment | `App/AppEnvironment.swift` | `AppBootstrap.swift` |
| Vault Sync | `Sync/VaultSyncService.swift` | `NoteFileStorage.swift` |
| Models | `Models/SDPage.swift` | `SDGraphNode.swift`, `GraphTypes.swift` |
| Audit State | `docs/audit-progress.md` | `docs/future-work-audit.md` |

---

## 12. Things That Will Bite You

1. **Never call `loadBody()` in a SwiftUI view body** — reads from disk on every re-evaluation.
2. **Never set `needsVaultSync = true` without `modelContext.save()`** — @Query predicate won't see it.
3. **Never use `.repeatForever` animations** — use `TimelineView` gated by `windowOccluded`.
4. **Never add `.environment()` manually** — use `withAppEnvironment(bootstrap)`.
5. **Binding sync MUST be debounced 300ms** — otherwise SwiftUI re-evaluates per keystroke.
6. **`Int(Float.nan)` traps** — always check `.isFinite` first.
7. **DialogueOverlayView is actively being worked on** — do not modify without asking.
8. **The Rust dialogue Metal code (face geometry, shader, box geometry) looks dead but isn't** — it supports `.dialogue` mode infrastructure. Don't delete.
9. **GraphExperienceMode doesn't exist in code yet** — it's part of the Explorer design doc, not implemented.
10. **SOAR's SignalGenerator produces fake numbers** — don't trust its confidence/entropy/dissonance outputs.
