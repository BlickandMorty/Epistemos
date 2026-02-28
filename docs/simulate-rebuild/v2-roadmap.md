# Epistemos v2 — Implementation Roadmap

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Transform Epistemos from a note-taking app into a cognitive exoskeleton — fix critical performance issues, clean up architecture, then add second-brain features.

**Architecture:** Native macOS SwiftUI + Rust graph engine (Metal rendering, d3-force physics) + AI pipeline (Claude/multi-provider)

**Tech Stack:** Swift 6 / SwiftUI / SwiftData / Metal / Rust (FFI via C bridge) / Anthropic API

---

## Wave 1: Performance (Critical — Fixes Lag)

These tasks fix the immediate performance problems the user is experiencing. Each is independent and can be implemented in parallel.

### Task 1.1: Per-Node Highlight Flag Buffer

**Why:** `upload_graph()` is called 8 times for simple highlight/dim operations. Each call rebuilds ALL node instances + ALL edge instances (O(N + E*8)). Highlighting is a color change, not a geometry change.

**Files:**
- Modify: `graph-engine/src/engine.rs` — add highlight_flags Vec, change highlight methods
- Modify: `graph-engine/src/renderer.rs` — add highlight buffer, modify node/edge shaders to read flag
- Modify: `graph-engine/src/lib.rs` — update FFI functions

**Changes:**

1. Add `highlight_flags: Vec<u8>` to Engine (0 = normal, 1 = highlighted, 2 = dimmed)
2. Add `highlight_buffer: Option<Buffer>` to Renderer
3. In `highlight_neighbors_by_id()`, `search_highlight()`, `clear_highlight()`, `mouse_down()` background click: update the flags Vec and upload ONLY the flag buffer (N bytes), NOT call `upload_graph()`
4. Modify node fragment shader: read highlight flag from buffer, apply alpha multiplier (1.0 for highlighted, 0.15 for dimmed, 1.0 for normal)
5. Modify edge fragment shader: same pattern
6. Remove all `upload_graph()` calls from highlight/search/click paths (keep only in `commit()` and `refresh_visibility()`)

**Verification:** `cd graph-engine && cargo test` — all pass. Open graph, shift-click node — neighbors highlight instantly without lag.

---

### Task 1.2: Pre-Allocate Scratch Buffers in Physics

**Why:** `force_collide()` allocates a fresh HashMap with ~N inner Vecs every tick (120 times/second). `force_many_body()` allocates Vec<Body> every tick. These are thousands of heap alloc/free per second in the hottest loop.

**Files:**
- Modify: `graph-engine/src/simulation.rs` — add scratch buffer fields
- Modify: `graph-engine/src/forces.rs` — accept &mut scratch buffers instead of allocating

**Changes:**

1. Add to `Simulation` struct:
   ```rust
   collision_grid: HashMap<(i32, i32), Vec<usize>>,
   bodies_scratch: Vec<Body>,
   ```
2. Change `force_collide()` signature to take `&mut HashMap<(i32,i32), Vec<usize>>` — clear and reuse instead of allocating
3. Change `force_many_body()` to take `&mut Vec<Body>` — clear and reuse
4. Use `rustc_hash::FxHashMap` instead of `std::collections::HashMap` for collision grid (faster hashing)
5. Add `rustc-hash` to Cargo.toml dependencies

**Verification:** `cargo test` — all pass. Profile: zero HashMap allocations in hot loop.

---

### Task 1.3: Pre-Allocate Field Line Metal Buffer

**Why:** `renderer.rs` line 1064 creates a new Metal buffer via `new_buffer_with_data()` every frame when a node is hovered. Metal buffer creation may involve kernel calls.

**Files:**
- Modify: `graph-engine/src/renderer.rs` — pre-allocate field line buffer, update in-place

**Changes:**

1. Add `field_line_capacity: usize` field to track allocated capacity
2. In `update_field_lines()`: if existing buffer has enough capacity, `copy_nonoverlapping` into it. Only allocate a new buffer if capacity is exceeded.
3. Clear field lines by setting count to 0, not by dropping the buffer

**Verification:** `cargo test` — all pass. Hover over nodes rapidly — no lag spikes.

---

### Task 1.4: Straight-Line Edges (Remove Bezier Tessellation)

**Why:** Every edge is tessellated into 8 line segments on CPU, creating `EDGE_SEGMENTS * edge_count` instances. For 1000 edges = 8000 instances. Every production graph tool (Obsidian, Logseq, Gephi) uses straight lines.

**Files:**
- Modify: `graph-engine/src/renderer.rs` — replace bezier with single-segment edges

**Changes:**

1. Change `EDGE_SEGMENTS` from 8 to 1, OR remove the tessellation loop entirely
2. Remove `gravitational_control_point()`, `bezier_point()` functions
3. Each edge = one `LineEdgeInstance` from source position to target position
4. Update `update_positions()` to directly set edge endpoints without bezier evaluation
5. Reduce edge instance buffer allocation by 8x

**Verification:** `cargo test` — all pass. Graph renders with straight edges. 8x fewer edge instances.

---

### Task 1.5: Remove Motion Blur Post-Process

**Why:** Two offscreen Private-storage textures + blit copy per frame + full-screen shader pass. Subtle visual effect that costs 2 extra render passes and ~16MB VRAM.

**Files:**
- Modify: `graph-engine/src/renderer.rs` — remove post-process pipeline

**Changes:**

1. Remove `offscreen_texture`, `prev_frame_texture`, `post_process_pipeline` fields
2. Remove `create_post_process_pipeline()` function
3. Remove blit copy in `draw()`
4. Render directly to `drawable.texture()` instead of offscreen texture
5. Remove the motion blur fragment shader from `SHADER_SOURCE`
6. Remove offscreen texture recreation in `on_resize()`

**Verification:** `cargo test` — all pass. Graph renders normally without post-process. Saves ~16MB VRAM.

---

### Task 1.6: SDPage.body to File Storage

**Why:** Every `FetchDescriptor<SDPage>` loads full note bodies into memory. A 5000-note vault loads 50MB+. This is the root cause of "everything is slow."

**Files:**
- Create: `Epistemos/Sync/NoteFileStorage.swift` — read/write note bodies as .md files
- Modify: `Epistemos/Models/SDPage.swift` — remove body property, add bodyFilePath
- Modify: `Epistemos/Sync/VaultSyncService.swift` — use NoteFileStorage for body access
- Modify: `Epistemos/Sync/VaultIndexActor.swift` — use NoteFileStorage
- Modify: `Epistemos/Views/Notes/Writer/WriterTextStorage.swift` — load body from file
- Modify: All files that access `page.body` — use NoteFileStorage.readBody(pageId:) instead
- Modify: `Epistemos/App/AppBootstrap.swift` — add migration on first launch

**Changes:**

1. Create `NoteFileStorage` with:
   - `static func storageDirectory() -> URL` — Application Support/Epistemos/notes/
   - `static func readBody(pageId: String) throws -> String`
   - `static func writeBody(pageId: String, content: String) throws`
   - `static func deleteBody(pageId: String) throws`
2. Add migration: on first launch, iterate all SDPage, write body to file, clear SDPage.body
3. Remove `var body: String` from SDPage (or keep as empty string for backward compat)
4. Update every `page.body` read to use `NoteFileStorage.readBody(pageId: page.id)`
5. Update every `page.body = newText` write to use `NoteFileStorage.writeBody(pageId: page.id, content: newText)`

**Verification:** Build succeeds. Launch app — migration runs. Notes load correctly. Memory usage drops significantly on vault with 100+ notes.

---

## Wave 2: Architecture Cleanup

### Task 2.1: AppEnvironment Container

**Why:** 15 separate `.environment()` injections duplicated in EpistemosApp, UtilityWindowManager, and HologramOverlay. Adding a 16th requires updating 3+ files.

**Files:**
- Create: `Epistemos/App/AppEnvironment.swift`
- Modify: `Epistemos/App/EpistemosApp.swift` — single .environment(appEnv)
- Modify: `Epistemos/App/UtilityWindowManager.swift` — single injection
- Modify: Views that use `@Environment(SomeState.self)` — change to `@Environment(AppEnvironment.self)`

**Changes:**

1. Create `AppEnvironment` that groups state into 5 containers:
   - `chat: ChatState`
   - `ui: UIState` (absorb DailyBriefState, BreatheState)
   - `notes: NotesState` (renamed from NotesUIState)
   - `engine: EngineState` (groups InferenceState, PipelineState, SOARConfig)
   - `graph: GraphState`
   - Plus services as a `ServiceContainer` struct
2. Inject once: `.environment(appEnv)`
3. Views access via `@Environment(AppEnvironment.self) var env` then `env.chat`, `env.graph`, etc.

---

### Task 2.2: Extract AppCoordinator

**Why:** AppBootstrap is a ~700-line god object that creates state, orchestrates chat, manages persistence, wires daily brief, handles vault events. Changing any subsystem requires touching it.

**Files:**
- Create: `Epistemos/App/AppCoordinator.swift` — chat orchestration
- Modify: `Epistemos/App/AppBootstrap.swift` — slimmed to just initialization
- Modify: `Epistemos/App/AppBootstrap+ChatOrchestration.swift` — move to AppCoordinator
- Modify: `Epistemos/App/AppBootstrap+NotesContext.swift` — move to AppCoordinator

**Changes:**

1. Move `handleQuery()`, `cancelActiveQuery()`, `generateChatTitle()`, `extractAndSaveCitations()`, `buildNotesContext()`, `executeVaultActions()` into `AppCoordinator`
2. AppBootstrap shrinks to: create state objects, create services, create coordinator, done
3. AppCoordinator gets dependencies via init injection (not singleton access)

---

### Task 2.3: Consolidate AI Pipeline (5 → 1-2 LLM Calls)

**Why:** Research mode fires 5 enrichment passes at ~17K output tokens ($0.50-1.00/query, 2-5 min latency). Structured output can return the same information in 1 call.

**Files:**
- Modify: `Epistemos/Engine/PipelineService.swift` — 2-phase pipeline
- Modify: `Epistemos/Engine/EnrichmentController.swift` — single structured call
- Delete: `Epistemos/Engine/SignalGenerator.swift` — fake statistics
- Modify: `Epistemos/Engine/PromptComposer.swift` — remove steering directives
- Modify: `Epistemos/State/PipelineState.swift` — simplify stages

**Changes:**

1. Replace 10-stage loop with 2 phases: stream answer + optional enrichment
2. Replace 5 enrichment passes with 1 structured-output LLM call that returns: analysis, laymanSummary, confidence, weaknesses, sources, truthAssessment
3. Delete SignalGenerator entirely (~500 lines)
4. Remove steering math from PromptComposer
5. Use provider-native message format for conversation history (not string concatenation)
6. Add `CostTracker` for token counting

---

### Task 2.4: GraphEngine Swift Wrapper

**Why:** MetalGraphNSView has 940 lines with raw `withCString`/pointer/UInt8 boilerplate for FFI calls. A typed Swift wrapper centralizes this.

**Files:**
- Create: `Epistemos/Graph/GraphEngine.swift`
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` — use wrapper

**Changes:**

1. Create `GraphEngine` class that owns the opaque pointer
2. Expose typed Swift methods: `addNode(uuid:position:type:...)`, `render(size:)`, `setHighlight(nodeUUIDs:)`, etc.
3. Replace all `graph_engine_*()` calls in MetalGraphNSView with wrapper calls
4. MetalGraphNSView drops from ~940 to ~500 lines

---

### Task 2.5: Diff-Based Graph Rebuild

**Why:** `GraphBuilder.persist()` deletes ALL non-manual graph data and re-inserts everything on every mutation. For 1000 notes, this is thousands of DELETE + INSERT SQL operations.

**Files:**
- Modify: `Epistemos/Graph/GraphBuilder.swift` — diff-based update
- Modify: `Epistemos/Graph/GraphState.swift` — remove gratuitous rebuild calls

**Changes:**

1. `persist()` computes expected nodes/edges, fetches current, computes diff
2. Only INSERT new, UPDATE changed, DELETE removed
3. Remove `buildStructuralGraph()` calls from `createNode()`, `connectNodes()` — manual nodes don't need structural rebuild
4. Rebuild only on: vault import completion, explicit refresh

---

## Wave 3: Quality

### Task 3.1: Build Infrastructure

- Create `Makefile` with targets: `test` (cargo test + xcodebuild test), `build-rust`, `lint`
- Add GitHub Actions CI: `cargo test && xcodebuild test` on push
- Add `.swiftlint.yml` with basic rules

### Task 3.2: Protocol-Based DI + Pipeline Tests

- Extract `LLMClientProtocol` from `LLMService`
- Write 5-10 mock-based pipeline tests
- Fix `SearchIndexTests` to test real code (make `sanitizeFTS5Query` internal)

### Task 3.3: SwiftData VersionedSchema

- Define current schema as V1
- Add `SchemaMigrationPlan`
- Remove UserDefaults migration flags

---

## Wave 4: Second Brain Features

### Task 4.1: Typed Semantic Links
- Modify `EntityExtractor` to use structured output for edge classification (support/contradict/expand/cite)
- Add edge type visualization in graph (color coding, label on hover)

### Task 4.2: Semantic Clustering via Embeddings
- Generate 384-dim embeddings for notes (via LLM or on-device model)
- Pass embeddings to Rust engine
- Add SIMD cosine similarity force: nodes attract based on semantic similarity
- Cluster by meaning, not just structural links

### Task 4.3: Rust FST Fuzzy Search
- Add `fst` crate to graph-engine
- Build FST index from note titles + content during commit
- Expose `graph_engine_search(query) -> results` via FFI
- Replace GRDB FTS5 in command palette with Rust FST
- Sub-1ms search across entire vault

---

## Execution Order

| Wave | Tasks | Dependencies | Est. Effort |
|------|-------|-------------|-------------|
| 1 | 1.1-1.5 (Rust perf) | Independent, parallel | 3-4 days |
| 1 | 1.6 (SDPage.body) | Independent | 2-3 days |
| 2 | 2.1-2.2 (State/AppBootstrap) | After Wave 1 | 2-3 days |
| 2 | 2.3 (AI Pipeline) | Independent | 2-3 days |
| 2 | 2.4-2.5 (GraphEngine/Rebuild) | After 1.1 | 2 days |
| 3 | 3.1-3.3 (Quality) | After Wave 2 | 2-3 days |
| 4 | 4.1-4.3 (Second Brain) | After Wave 3 | 5-7 days |
