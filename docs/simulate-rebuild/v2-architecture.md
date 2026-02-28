# Epistemos v2 — Ideal Architecture Specification
## Date: 2026-02-28

## Design Philosophy

1. **Second brain, not note-taking app.** Every feature must serve the cognitive exoskeleton vision: typed semantic links, semantic clustering, knowledge graph as navigation, AI as epistemic partner. If a feature doesn't make the user *think better*, cut it.

2. **Fewer LLM calls, smarter LLM calls.** One structured-output call that returns analysis + confidence + weaknesses + sources replaces five serial passes. Cost transparency is mandatory. Fake statistics are removed.

3. **Data stays small, fast, and honest.** Note bodies live on disk as files, not in SQLite. The graph is derived in-memory, not persisted as entities that get deleted and rebuilt. Queries never load more data than they need.

4. **Compose state, don't scatter it.** 5-6 state containers, one injection point, protocols for testability. No singletons for state — only for AppKit window bridges.

5. **The Rust engine earns its place.** Keep it for physics + rendering (it scales to 5000+ nodes), but wrap it in Swift for safety. The hot loop must be allocation-free. Highlighting is a uniform, not a geometry rebuild.

---

## Project Structure (Ideal)

```
Epistemos/
  App/
    EpistemosApp.swift          # Scene definitions, single .environment(appEnv)
    AppEnvironment.swift        # Groups all state + services, single init
    AppCoordinator.swift        # Chat orchestration (extracted from AppBootstrap)
  Engine/
    LLMClient.swift             # Protocol: generate/stream
    LLMProviders/               # Anthropic, OpenAI, Google, Ollama, AppleIntelligence
    PipelineService.swift       # 2-phase: stream answer + optional enrichment (1 call)
    TriageService.swift         # On-device vs cloud routing (keep as-is)
    CitationExtractor.swift     # Pure function (keep as-is)
    EntityExtractor.swift       # Rate-limited, cost-aware vault scanning
    ResearchService.swift       # Semantic Scholar (keep as-is)
    CostTracker.swift           # NEW: token counting + budget guards
    PromptLibrary.swift         # Named templates, versioned, testable
  Graph/
    GraphState.swift            # Slimmed: mode, selection, interaction. No physics params.
    GraphPhysicsConfig.swift    # Extracted: force params, presets, version counters
    GraphStore.swift            # In-memory adjacency list (keep as-is, NOT @Observable)
    GraphBuilder.swift          # Diff-based update (not delete-all-reinsert)
    FilterEngine.swift          # NOT @Observable, version-flagged
    GraphEngine.swift           # NEW: Swift wrapper around Rust FFI
  Models/
    SDPage.swift                # body → bodyFilePath (file on disk, not inline SQLite)
    SDFolder.swift
    SDChat.swift                # chatType → enum, hasDeepResearch → non-optional Bool
    SDMessage.swift
    SDPageVersion.swift
    GraphTypes.swift            # Node/edge types, metadata (keep as-is)
    Schema/                     # NEW: VersionedSchema, SchemaMigrationPlan
  State/
    ChatState.swift             # Slimmed: messages + streaming only
    UIState.swift               # Theme, nav, toasts, daily brief (merged)
    NotesState.swift            # Renamed from NotesUIState
    EngineState.swift           # NEW: groups inference, pipeline, SOAR config
    GraphPhysicsConfig.swift    # Physics parameters (extracted from GraphState)
  Sync/
    VaultSyncService.swift      # Unified write path through VaultActor
    VaultActor.swift            # Single @ModelActor for ALL SwiftData writes
    SearchIndexService.swift    # FTS5 (rebuild on launch, upsert on change)
    NoteFileStorage.swift       # NEW: read/write note bodies as .md files
  Theme/
    EpistemosTheme.swift        # Keep as-is (9/10 quality)
  Views/
    Chat/                       # Chat UI (keep, minor cleanup)
    Graph/
      MetalGraphView.swift      # Slimmed: uses GraphEngine wrapper
      HologramOverlay.swift     # Keep
      HologramController.swift  # Keep (singleton for AppKit)
      GraphFloatingControls.swift
    Landing/                    # Landing, command palette (extract prompt builders)
    MiniChat/                   # Split god-view into subviews
    Notes/
      NotesSidebar.swift        # Split into subviews (<500 lines each)
      NoteWindowManager.swift   # Split: window lifecycle vs tab management
      Writer/                   # Keep (good perf engineering)
    Settings/
    Shared/
    Shell/
  Intents/                      # Keep
  Resources/                    # Keep

graph-engine/                   # Rust physics + Metal rendering
  src/
    lib.rs                      # FFI surface (keep, clean)
    engine.rs                   # Orchestrator (keep, fix highlight pattern)
    simulation.rs               # d3-force Verlet (keep, pre-alloc scratch buffers)
    forces.rs                   # Force calculations (fix allocations)
    quadtree.rs                 # Barnes-Hut (keep, consider brute-force for N<1000)
    cluster.rs                  # Louvain (keep)
    renderer.rs                 # Metal rendering (remove motion blur, simplify edges)
    spatial.rs                  # Hit testing (keep)
    types.rs                    # Core types (keep)
  Removed:
    markdown.rs → separate crate (or keep for convenience)
    msdf.rs (already deleted)
    physics.rs (already deleted)

graph-engine-bridge/
  graph_engine.h                # C bridge (keep, 1:1 mirror)

EpistemosTests/
  Unit/
    Engine/
      PipelineServiceTests.swift    # NEW: 10+ mock-based tests
      LLMServiceTests.swift         # NEW: URL construction, headers
      TriageServiceTests.swift      # Keep
    Graph/
      GraphStoreTests.swift         # Keep
      FilterEngineTests.swift       # Keep
    Sync/
      VaultSyncServiceTests.swift   # NEW: bookmark round-trip
      SearchIndexTests.swift        # Fix: test real code, not duplicate
    SOAR/
      SOARTests.swift               # Keep
  Integration/
    PipelineIntegrationTests.swift  # NEW: full pipeline with mock LLM
```

---

## State Architecture (Reimagined)

```swift
// Single root — one injection, everywhere
@MainActor @Observable
final class AppEnvironment {
    // State containers (5, not 15)
    let chat: ChatState
    let ui: UIState            // includes daily brief, breathe
    let notes: NotesState
    let engine: EngineState    // groups inference, pipeline config, SOAR config
    let graph: GraphState

    // Services (plain classes, NOT @Observable)
    let services: ServiceContainer

    // Persistence
    let container: ModelContainer

    init() { /* wire everything once */ }
}

struct ServiceContainer {
    let llm: any LLMClientProtocol
    let triage: TriageService
    let pipeline: PipelineService
    let research: ResearchService
    let vault: VaultSyncService
    let search: SearchIndexService
    let coordinator: AppCoordinator  // chat orchestration
    let costTracker: CostTracker
}

// Injection: ONE call
.environment(appEnv)
```

---

## Data Layer (Reimagined)

### Note Bodies on Disk
```swift
// SDPage loses its body property
@Model final class SDPage {
    var id: String
    var title: String
    var tags: [String]
    var wordCount: Int
    var createdAt: Date
    var updatedAt: Date
    // NO body: String — bodies are .md files on disk
}

// Reading a note body
let body = try NoteFileStorage.readBody(pageId: page.id)
// Writing a note body
try NoteFileStorage.writeBody(pageId: page.id, content: newBody)
```

### Graph as Derived Data
```swift
// GraphBuilder.build() returns in-memory data (not SwiftData entities)
// Only user-created (isManual) nodes/edges live in SwiftData
// Structural graph is rebuilt from SDPage/SDFolder relationships at load time

// Diff-based rebuild instead of delete-all-reinsert:
func rebuild(context: ModelContext) {
    let expected = computeExpectedGraph(context: context)
    let current = store.currentSnapshot()
    let diff = computeDiff(current: current, expected: expected)
    apply(diff)  // targeted insert/update/delete
}
```

### Schema Versioning
```swift
enum EpistemosSchema: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [SDPage.self, SDFolder.self, ...] }
}

enum EpistemosMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [EpistemosSchema.self] }
    static var stages: [MigrationStage] { [] }
}
```

---

## Engine Architecture (Reimagined)

### 2-Phase Pipeline (Not 10-Stage)
```
Phase 1: Stream answer (1 LLM call)
  - System prompt: epistemic contract + vault context + conversation history
  - Native message format (provider's messages array, not string concatenation)
  - Real-time token streaming to ChatState

Phase 2 (optional, research mode): Structured enrichment (1 LLM call)
  - Single call with structured output (tool use / JSON mode)
  - Returns: {
      analysis: String,
      laymanSummary: String,
      confidence: Float,     // LLM's honest self-assessment
      weaknesses: [String],
      sources: [Citation],
      truthAssessment: TruthAssessment
    }
  - Replaces 5 serial passes with 1 structured call
  - Cost: ~$0.10-0.20 instead of $0.50-1.00
```

### LLM Client Protocol
```swift
protocol LLMClientProtocol: Sendable {
    func generate(messages: [LLMMessage], config: LLMConfig) async throws -> LLMResponse
    func stream(messages: [LLMMessage], config: LLMConfig) -> AsyncThrowingStream<StreamChunk, Error>
}

struct LLMResponse {
    let text: String
    let inputTokens: Int
    let outputTokens: Int
    let stopReason: StopReason
}
```

### Cost Tracking
```swift
@MainActor @Observable
final class CostTracker {
    var sessionTokensIn: Int = 0
    var sessionTokensOut: Int = 0
    var estimatedSessionCost: Double { /* compute from provider pricing */ }

    func record(response: LLMResponse, provider: LLMProvider) { ... }
    func estimateCost(for operation: PipelineOperation) -> Double { ... }
}
```

---

## Rust Engine (Reimagined)

### Swift Wrapper
```swift
@MainActor
final class GraphEngine {
    private var handle: OpaquePointer?

    init(device: MTLDevice, layer: CAMetalLayer) { ... }
    deinit { handle.map { graph_engine_destroy($0) } }

    func addNode(uuid: String, position: SIMD2<Float>, type: GraphNodeType, ...) { ... }
    func addEdge(sourceUUID: String, targetUUID: String, weight: Float) { ... }
    func commit(entrance: Bool) { ... }
    func render(size: CGSize) -> Bool { ... }
    func screenToWorld(_ screenPos: CGPoint) -> SIMD2<Float> { ... }

    // Highlight via per-node flag buffer (NOT full re-upload)
    func setHighlight(nodeUUIDs: Set<String>) { ... }
    func clearHighlight() { ... }

    var hoveredNodeUUID: String? { ... }
    var selectedNodeUUID: String? { ... }
}
```

### Performance Fixes
```
1. Highlight buffer: per-node u8 flag, uploaded separately (N bytes vs N*sizeof(Instance))
2. Scratch buffers: pre-allocated HashMap/Vec on Simulation struct, cleared and reused per tick
3. Field line buffer: pre-allocated Metal buffer, updated in-place
4. Straight-line edges: 1 instance per edge instead of 8
5. No motion blur: single render pass to drawable
6. Brute-force many-body for N<1000 (skip quadtree construction)
```

---

## Testing Strategy

### What to Test (Priority Order)
1. **Pipeline contract** — mock LLM, verify event ordering, error handling, cancellation
2. **Vault bookmark resolution** — round-trip test, migration test
3. **LLM request construction** — headers, body format per provider
4. **Graph diff builder** — compute expected vs actual, verify minimal mutations
5. **Cost tracker** — token counting, budget guards
6. **Everything currently tested** — physics (55 tests), SOAR, triage, graph store, filter engine

### How to Test
- Protocol-based DI: `LLMClientProtocol`, `VaultStorageProtocol`
- In-memory SwiftData: `ModelConfiguration(isStoredInMemoryOnly: true)`
- CI: `cargo test && xcodebuild test` on every push

### Coverage Targets
- Engine/ (AI pipeline): 80%+ — this is the product
- Sync/ (data integrity): 70%+ — this is user data
- Graph/ (physics): 90%+ — already there
- Views/: 0% — correct for SwiftUI, test state objects instead

---

## "Second Brain" Features — Integration with Manifesto

### Phase 1: Foundation (fix what exists)
- Move SDPage.body to files
- Fix graph engine performance (highlight buffer, scratch buffers)
- Consolidate AI pipeline (2-phase, structured output)
- Group state containers (5 from 15)
- Add CI + 15 tests on critical paths
- Diff-based graph rebuild

### Phase 2: Semantic Intelligence (make it a second brain)
- **Typed semantic links:** AI categorizes edges as support/contradict/expand/cite during entity extraction. Use structured output.
- **Semantic clustering via embeddings:** Generate 384-dim embeddings for notes, pass to Rust, use SIMD cosine similarity to influence cluster force.
- **Rust FST fuzzy search:** Replace GRDB FTS5 with sub-1ms Rust FST. Levenshtein-distance matching. Semantic discovery via embedding similarity.

### Phase 3: Deep Integration (cognitive exoskeleton)
- **Graph query DSL:** "Show me all notes that contradict Idea X" or "Find the shortest path of supporting arguments between A and B"
- **Time-travel graph:** Temporal index in Rust. Slider in Swift UI to visualize graph evolution over time.
- **Ambient capture:** Rust audio pipeline with VAD + Whisper. Spoken thoughts auto-categorized by TriageService and anchored to relevant notes.
- **Confidence visualization:** Subtle Metal shader effects on text driven by SOAR confidence scores (halos, shimmer for high-dissonance claims).

---

## Migration Path

| Change | Current → Ideal | Impact | Risk | Effort |
|--------|----------------|--------|------|--------|
| SDPage.body to files | Inline SQLite → disk files | **Critical** — fixes memory scaling | Medium (migration needed) | 2-3 days |
| Highlight buffer | upload_graph() x8 → per-node flags | **Critical** — fixes graph interaction lag | Low | 1 day |
| Scratch buffer pre-allocation | Per-tick HashMap/Vec alloc → reuse | **Critical** — fixes physics CPU burn | Low | 1 day |
| Consolidate enrichment | 5 LLM calls → 1-2 structured | **High** — 5x cheaper, 3x faster | Low | 2 days |
| Remove fake signals | SignalGenerator → delete | **High** — removes 500 lines of noise | None | 2 hours |
| AppEnvironment container | 15 injections → 1 | **High** — eliminates injection duplication | Low | 3 hours |
| Extract AppCoordinator | AppBootstrap god object → coordinator | **High** — separation of concerns | Medium | 4 hours |
| GraphEngine Swift wrapper | Raw FFI calls → typed API | **Medium** — MetalGraphNSView loses 300 lines | Low | 3 hours |
| Diff-based graph rebuild | Delete-all-reinsert → targeted diff | **Medium** — eliminates rebuild cost | Medium | 2 days |
| Pipeline tests (5-10) | Zero coverage → core path tested | **Medium** — prevents regression | Low | 4 hours |
| CI pipeline | None → cargo test + xcodebuild test | **Medium** — automated quality gate | Low | 2 hours |
| SwiftData VersionedSchema | UserDefaults flags → proper versioning | **Medium** — crash-free migrations | Low | 1 day |
| Straight-line edges | 8-segment bezier → 1 segment | **Low** — 8x fewer edge instances | None | 2 hours |
| Remove motion blur | 2 extra passes → single pass | **Low** — saves VRAM + GPU work | None | 1 hour |
| Typed semantic links | Binary links → support/contradict/cite | **High (Phase 2)** — core second-brain feature | Medium | 3-5 days |
| Semantic clustering | Force-only → embedding cosine similarity | **High (Phase 2)** — nodes cluster by meaning | Medium | 5-7 days |
