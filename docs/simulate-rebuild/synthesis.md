# Simulate Rebuild — Deep Synthesis
## Date: 2026-02-28

## Executive Summary

**Epistemos has the bones of something great — a native macOS knowledge system with a Rust-powered graph engine, Metal rendering, and a 10-stage AI pipeline — but it is drowning in accidental complexity.** The app has 16 @Observable state classes, 5 singletons, a god-object `AppBootstrap` with 78 cross-file references, an AI pipeline that fires 6+ LLM calls per query ($0.50-1.00 each) with fake statistics decorating the progress, a graph engine that re-uploads ALL geometry for a simple color highlight, and zero tests on the core product path (user query → streaming answer). The app feels slow because it *is* slow: `SDPage.body` stored inline in SQLite loads every note body into memory on any fetch, `GraphBuilder` deletes and re-inserts the entire graph on every mutation, and the physics engine allocates and frees thousands of HashMap entries per second in its hot loop. To become a true "second brain" that transcends Obsidian, Epistemos needs fewer features done perfectly — not more features done hastily.

---

## What Went Right — Patterns Worth Keeping

### Architecture & FFI (Agents 1, 6)
- **The Rust FFI boundary is textbook.** Opaque `*mut Engine` handle, null-guard macros, 1:1 C bridge header mirror. No Rust types leak into Swift. The `Atomic<Bool>` invalidation flag prevents CVDisplayLink use-after-free. Senior-level systems work.
- **The d3-force velocity Verlet physics are faithful.** Alpha decay, SoA layout, correct force application order. Not cargo-culted — someone understood the source material.
- **Barnes-Hut quadtree is correctly implemented** with theta=0.5, center-of-charge accumulation, and MAX_DEPTH=20 guard.
- **CVDisplayLink + frame coalescing + settled-idle** is production-grade. Triple buffering for ProMotion, `renderNeeded`/`framePending` atomics, 3 idle frames → GPU sleeps.

### State & Data (Agents 2, 4)
- **Consistent `@MainActor @Observable final class` pattern.** No legacy Combine/`@Published`. Fully committed to Observation framework.
- **GraphStore is deliberately NOT @Observable.** The comment explains why — Metal reads positions per frame, observation would add latency. Correct.
- **Token batching in ChatState.** 60ms flush interval prevents per-token SwiftUI redraws. `pendingStreamTokens` is deliberately unobserved.
- **SwiftData indexes declared on every model.** SDPage, SDFolder, SDChat, SDGraphNode, SDGraphEdge all have `#Index<>`.
- **Pre-built FetchDescriptors centralized** in `SDPage+Queries.swift`.
- **VaultIndexActor uses `@ModelActor`** for background work with batch-save every 200 changes + autoreleasepool.

### UI & Theme (Agent 3)
- **Theme system is 9/10 quality.** Six themes in three light/dark pairs, seven typography tokens, five motion constants. Every animation references `Motion.*`.
- **NotesSidebar value-type isolation.** Explicit awareness of @Observable tracking — maps `@Model` SDPage to `Equatable` value structs for list rendering.
- **PageStoragePool** object pooling for NSTextStorage instances — genuine performance engineering.

### AI & Testing (Agents 5, 7)
- **Triage routing is genuinely useful.** Complexity scoring routes to Apple Intelligence (free, on-device) or cloud API with bidirectional fallback on refusal/auth error.
- **LLMService provider abstraction** supports 6 providers. `LLMSnapshot` pattern correctly freezes config for background enrichment across actor boundaries.
- **55 Rust physics unit tests** verify physical invariants, convergence, numerical stability. The most critical computation has the best coverage.
- **Swift Testing framework** (`@Suite`, `@Test`, `#expect`) — forward-looking, no legacy XCTest.

---

## What Went Wrong — Honest Post-Mortem

### Architectural (System-Level)

**1. AppBootstrap is a god object that doubles as a service locator.**
- 78 references across 29 files via `AppBootstrap.shared`
- Owns ALL 13 state objects, ALL 6 services, the ModelContainer
- Orchestrates chat pipeline, vault context, toast routing, graph refresh
- Changing ANY subsystem requires touching AppBootstrap
- **Why it happened:** Solo developer moving fast — one object to rule them all. No pressure from code review or team conventions.

**2. 16 @Observable classes + 5 singletons = scattered state.**
- 15 environment injections duplicated in 3 places (EpistemosApp, UtilityWindowManager, HologramOverlay)
- Services (LLMService, TriageService, ResearchService, VaultSyncService) marked `@Observable` for environment convenience, not because views observe them
- Adding a 16th object requires updating 3+ injection sites
- **Why it happened:** Each new feature got its own state class. Nobody composed them into containers.

**3. The AI pipeline fires 6+ LLM calls per query with fake progress.**
- 10-stage loop produces decorative statistics from regex keyword matching (SignalGenerator)
- "Confidence," "entropy," "dissonance," "TDA betti numbers" are polynomials over query length
- 5 enrichment passes generate ~17K output tokens at $0.50-1.00 per research query
- No token counting, no cost estimation, no user-visible cost indicator
- **Why it happened:** Features were added because they were technically interesting ("wouldn't it be cool if we simulated 5 engine arbitration"), not because users needed them.

### Structural (Module-Level)

**4. SDPage.body stored inline in SQLite — memory bomb.**
- Every `FetchDescriptor<SDPage>` loads full note bodies into memory
- `allPageTimestamps()` fetches all pages including bodies just for `.id` and `.updatedAt`
- A 5000-page vault would load 50MB+ into a single array
- External storage was explicitly migrated AWAY FROM because of a SwiftData bug
- **Why it happened:** Workaround for a SwiftData bug became permanent. Nobody measured the memory impact.

**5. GraphBuilder deletes and re-inserts ALL graph data on every mutation.**
- Called on vault import, sync, node creation, edge connection, entity extraction
- For 1000 notes: thousands of DELETE + INSERT SQL operations per session
- **Why it happened:** Diffing is harder than delete-all-reinsert. The simpler approach worked at small scale.

**6. `upload_graph()` called 8 times — highlighting = rebuild ALL geometry.**
- Clicking a node to highlight its neighbors rebuilds all N node instances + all E*8 edge instances
- Highlighting is a color change, not a geometry change
- Should be a per-node flag buffer (~N bytes), not a full re-upload (~N*sizeof(Instance) bytes)
- **Why it happened:** The simplest approach that worked. No profiling to reveal the cost.

**7. Per-tick heap allocations in physics hot loop.**
- `force_collide()`: fresh HashMap with ~N inner Vecs every tick (120 allocations/second)
- `force_many_body()`: fresh Vec<Body> + quadtree tree every tick (~500+ heap allocs/tick)
- Field line Metal buffer: `new_buffer_with_data()` every frame when hovering
- **Why it happened:** No allocation-awareness in the force calculations. Standard Rust patterns (return new collections) don't work in hot loops.

### Cosmetic (Code Quality)

**8. Zero tests on the AI pipeline — the core product feature.**
- PipelineService, LLMService, ResearchService, AppBootstrap+ChatOrchestration: zero test coverage
- VaultSyncService (data-loss risk code): zero tests
- SearchIndexTests tests a DUPLICATE of the logic, not the real code
- No CI/CD pipeline at all — tests only run when someone remembers Cmd+U

**9. Conversation history concatenated as raw text.**
- Prior messages joined as `"User: ...\nAssistant: ..."` strings instead of provider-native message arrays
- JSON extraction duplicated in 3 separate implementations
- SOAR uses regex heuristics to evaluate its own improvement (checking for words like "however," "first")

---

## Cross-Cutting Tensions

### Tension 1: Rust vs. Swift for <1000 Nodes
The Metal Smith says Rust is "marginally justified" for physics at this scale — Swift would be 2x slower (0.3ms vs 0.6ms), which is invisible. But the Rust engine works, is well-tested (55 unit tests), and scales to 5000+ nodes. The Architect says the FFI is clean but MetalGraphNSView is 940 lines of `withCString`/pointer boilerplate. **Resolution: Keep Rust, but wrap the FFI in a Swift `GraphEngine` class** that absorbs the boilerplate.

### Tension 2: SwiftData Graph Entities vs. In-Memory-Only Graph
The Data Artisan says SDGraphNode/SDGraphEdge should be removed from SwiftData entirely — the graph is rebuilt from pages/folders on launch anyway. The Architect notes GraphBuilder already does this. But GraphState.createNode() persists manual nodes to SwiftData with `isManual` flag. **Resolution: Keep SwiftData for manual nodes, but make the structural graph purely derived and in-memory.** Delete the delete-all-reinsert cycle.

### Tension 3: Rich AI Pipeline vs. 1-2 Good LLM Calls
The Engine Whisperer says enrichment should be 1-2 structured output calls, not 5 serial passes. The Manifesto wants even MORE AI (semantic clustering, typed relationships, ambient capture). **Resolution: Simplify the current pipeline FIRST (remove fake signals, consolidate enrichment), then add genuine AI features (semantic embeddings, typed links) that use structured output.** The pipeline should be cheaper and better, not cheaper and simpler.

### Tension 4: Feature Breadth vs. Feature Depth
The app has: notes, chat, graph, research, SOAR, daily brief, mini chat, breathe mode, intents, command palette, ambient manifests, version history. Each is 60-80% done. The Manifesto wants to add: mmap vault, SIMD search, ambient capture, shader text effects, Merkle history, CRDTs. **Resolution: Freeze features. Polish what exists. Then add only the features that make Epistemos a *second brain*, not a *note-taking app*.**

### Tension 5: Solo Developer Speed vs. Team Scalability
78 `AppBootstrap.shared` references, zero CI, no protocols for DI, callback closures instead of proper injection. This codebase can only be maintained by the person who wrote it. The DX Guardian says a team of 3 would break the AI pipeline within a week. **Resolution: Extract protocols, add a Makefile, add 5 pipeline tests, add CI. This is the minimum investment to allow anyone else to contribute.**

---

## The Three Lenses — Unified View

### The Minimalist Says...
Kill the 10-stage pipeline loop, SignalGenerator, PromptComposer steering directives, SOAR (or reduce to prompt injection), 5-engine arbitration, motion blur post-process, bezier edge tessellation, BreatheOverlay subsystem, EventBus (3 subscribers don't need a bus), and DailyBriefState (merge into UIState). Move SDPage.body to files. Remove ContentRouter pass-through. This removes ~3000 lines of code and makes the app faster, cheaper to run, and easier to understand.

### The Purist Says...
Use SwiftData VersionedSchema. Use provider-native message formats. Use structured output for JSON responses. Use `@Relationship` for graph edges. Use `@Attribute(.externalStorage)` for note bodies (or file-based storage). Use SwiftUI `Window` scenes instead of raw NSPanel. Don't override Cmd+H. Extract protocols for dependency injection. Use `propertiesToFetch` (or raw queries) to avoid loading bodies. The codebase works because of Swift's safety nets, not because it follows Apple's guidance.

### The Street-Smart Dev Says...
Fix the three things that cause 90% of the lag: (1) per-node highlight buffer instead of full upload_graph(), (2) pre-allocated scratch buffers in force calculations, (3) move SDPage.body out of inline SQLite. Add a Makefile and 5 pipeline tests. Group the 15 environment objects into 5. Extract ChatCoordinator from AppBootstrap. Everything else can wait. The graph engine in Rust is fine — keep it. The theme system is great — don't touch it. The triage routing is clever — extend it. Stop building features and start profiling.

---

## The Highest-Leverage Single Change

**Move SDPage.body out of inline SQLite storage to file-based storage.**

This is the foundational performance fix. Every fetch of SDPage currently loads the entire note body into memory. Every "fetch all pages" operation (timestamps, context building, graph building, search sync, auto-save, version capture) pulls megabytes of text. A 5000-note vault would load 50MB+ on any page list operation. Moving body to Application Support files means SDPage rows become tiny metadata (title, dates, tags, word count — maybe 200 bytes each). The entire vault index fits in 1MB instead of 50MB. Every operation that touches "all pages" becomes instant. This single change eliminates the memory scaling problem, speeds up graph builds, speeds up search sync, and makes the app feel lightweight at any vault size.

---

## Lessons for Next Time

1. **Always store large blobs outside SQLite.** The "inline is simpler" tradeoff becomes a trap at >1000 records.
2. **Never fire >2 LLM calls per user action without explicit cost/time disclosure.** Users don't know they're spending $1 per query.
3. **Test the money path first.** 55 physics tests and zero pipeline tests means the least-breakable code is the most-tested. Invert that.
4. **Compose state, don't scatter it.** 16 @Observable classes should be 5-6 composed containers. One injection point, not fifteen.
5. **Profile before optimizing, profile before adding features.** The lag was never "missing features" — it was allocation in hot loops and full graph re-uploads.
6. **Singletons are for AppKit bridges only.** AppBootstrap.shared being accessed from views that HAVE the environment is a code smell, not a convenience.
7. **Fake metrics erode trust.** One honest number (the LLM's self-assessed confidence) is worth more than ten decorative polynomials.
8. **Bezier edges are visual noise.** Straight lines are what every production graph tool uses. Curves look cool in demos and hurt readability in real use.
