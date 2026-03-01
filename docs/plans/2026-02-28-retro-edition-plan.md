# Epistemos Retro Edition — Implementation Plan

## Date: 2026-02-28
## Prerequisite: Design doc approved (`2026-02-28-retro-edition-design.md`)

---

## CRITICAL CONTEXT: DUAL-TRANSLATION

Every task in this plan translates from TWO sources:
- **[WEB]** = Adapting the web frontend (`~/meta-analytical-pfc/brainiacv2/`)
- **[MAC]** = Porting macOS Swift logic (`~/Epistemos/`)
- **[NEW]** = Net-new code (no equivalent in either source)

Each task explicitly marks which source it translates from.

---

## PHASE 1: SCAFFOLD (Day 1)
**Goal:** Empty Tauri app that opens a window with the web frontend loading.

### 1.1 Create Tauri Project [NEW]
- `npm create tauri-app@latest epistemos-retro`
- Choose: Next.js frontend, Rust backend
- Configure `tauri.conf.json`: window 1200x800, title "Epistemos", decorations true

### 1.2 Copy Web Frontend [WEB]
- Copy `brainiacv2/src/`, `brainiacv2/components/`, `brainiacv2/lib/`, `brainiacv2/hooks/` into `epistemos-retro/src/`
- Copy `brainiacv2/app/` (pages) — delete `app/api/` directory entirely (replaced by Tauri)
- Copy `package.json` dependencies (except `better-sqlite3`, `drizzle-orm` — replaced by Rust)
- Add `@tauri-apps/api` to dependencies
- Update `next.config.ts`: add `output: 'export'` for static generation (Tauri requirement)

### 1.3 Link Graph Engine [MAC]
- Copy `graph-engine/` from macOS repo into `src-tauri/graph-engine/`
- Add as workspace member in `src-tauri/Cargo.toml`
- Verify `cargo build` compiles the engine for Windows target

### 1.4 Verify Build [NEW]
- `npm run tauri dev` — should open window with web frontend
- Frontend won't work yet (API calls fail) — that's expected

**Checkpoint:** Window opens with the web UI visible (broken but rendering).

---

## PHASE 2: STORAGE FOUNDATION (Days 2-3)
**Goal:** Rust persistence layer that can store and retrieve notes, chats, blocks.

### 2.1 SQLite Schema [MAC → Rust]
**Source:** `Epistemos/Models/EpistemosSchema.swift`, `SDPage.swift`, `SDBlock.swift`, `SDChat.swift`, `SDMessage.swift`, `SDGraphNode.swift`, `SDGraphEdge.swift`
```rust
// storage/db.rs — translate SwiftData @Model to CREATE TABLE
fn create_tables(conn: &Connection) {
    // pages: id, title, file_path, summary, tags_json, is_journal, is_pinned, ...
    // blocks: id, page_id, parent_block_id, order, depth, content, is_collapsed, ...
    // chats: id, title, chat_type, has_deep_research, ...
    // messages: id, chat_id, role, content, dual_message_json, truth_json, ...
    // graph_nodes: id, type, label, source_id, metadata_json, weight, ...
    // graph_edges: id, source_node_id, target_node_id, type, weight, ...
    // folders: id, name, icon, parent_folder_id, ...
    // page_versions: id, page_id, hash, parent_hash, timestamp, changes_summary, ...
    // settings: key, value (KV store for config)
}
```

### 2.2 Rust Models [MAC → Rust]
**Source:** All `SD*.swift` model files
```rust
// storage/models.rs
#[derive(Debug, Serialize, Deserialize)]
pub struct Page { id: String, title: String, file_path: Option<String>, ... }
pub struct Block { id: String, page_id: String, parent_block_id: Option<String>, ... }
pub struct Chat { id: String, title: String, chat_type: String, ... }
pub struct Message { id: String, chat_id: String, role: String, content: String, ... }
pub struct GraphNode { id: String, node_type: u8, label: String, source_id: String, ... }
pub struct GraphEdge { id: String, source_node_id: String, target_node_id: String, ... }
```

### 2.3 CRUD Operations [MAC → Rust]
**Source:** SwiftData ModelContext operations scattered across Swift files
```rust
// storage/db.rs
impl Database {
    pub fn create_page(&self, page: &Page) -> Result<()>;
    pub fn get_page(&self, id: &str) -> Result<Option<Page>>;
    pub fn update_page(&self, page: &Page) -> Result<()>;
    pub fn delete_page(&self, id: &str) -> Result<()>;
    pub fn list_pages(&self) -> Result<Vec<Page>>;
    // Same pattern for Block, Chat, Message, GraphNode, GraphEdge
}
```

### 2.4 Vault File Sync [MAC → Rust]
**Source:** `Epistemos/Sync/NoteFileStorage.swift`, `VaultSyncService.swift`
```rust
// storage/vault.rs
pub fn write_body(vault_path: &Path, page_id: &str, body: &str) -> Result<PathBuf>;
pub fn read_body(file_path: &Path) -> Result<String>;
pub fn start_watcher(vault_path: &Path, tx: Sender<VaultEvent>) -> Result<()>;
```

### 2.5 Block Parser + Reconciler [MAC → Rust]
**Source:** `Epistemos/Sync/BlockParser.swift`, `BlockReconciler.swift`
- Direct translation of the algorithms (already Rust-friendly logic)
- Jaccard similarity, two-pass bipartite matching

**Checkpoint:** `cargo test` passes for all storage operations. Can round-trip note → .md file → blocks → .md file.

---

## PHASE 3: TAURI BRIDGE (Days 3-4)
**Goal:** Frontend can create/read/update/delete notes and chats via Tauri invoke.

### 3.1 Tauri Commands [NEW + MAC]
**Source (logic):** Swift service files. **Source (API shape):** Web `app/api/` routes.
```rust
// commands/notes.rs
#[tauri::command]
async fn notes_list(state: State<'_, AppState>) -> Result<Vec<Page>, String>;

#[tauri::command]
async fn notes_create(state: State<'_, AppState>, title: String) -> Result<Page, String>;

#[tauri::command]
async fn notes_update(state: State<'_, AppState>, id: String, body: String) -> Result<(), String>;

// commands/chat.rs
#[tauri::command]
async fn chat_send(state: State<'_, AppState>, query: String, chat_id: String) -> Result<(), String>;
// (streaming happens via app.emit, not return value)
```

### 3.2 Frontend Bridge [WEB → Tauri]
**Source:** `brainiacv2/app/api/` route handlers — map each to an invoke call
```typescript
// lib/tauri-bridge.ts
import { invoke } from '@tauri-apps/api/core';

export async function listNotes(): Promise<Page[]> {
    return invoke('notes_list');
}
export async function createNote(title: string): Promise<Page> {
    return invoke('notes_create', { title });
}
export async function updateNote(id: string, body: string): Promise<void> {
    return invoke('notes_update', { id, body });
}
export async function sendChat(query: string, chatId: string): Promise<void> {
    return invoke('chat_send', { query, chatId });
}
// ... ~15 more commands mapping to existing API routes
```

### 3.3 Replace Fetch Calls [WEB]
**Source:** Every `fetch('/api/...')` in the web frontend
- Search all files for `fetch(` patterns
- Replace with corresponding `tauri-bridge.ts` function calls
- ~20 call sites to update

### 3.4 Streaming Events [WEB + NEW]
**Source (pattern):** `brainiacv2/app/api/assistant/route.ts` (SSE streaming)
```typescript
// hooks/use-tauri-stream.ts
import { listen } from '@tauri-apps/api/event';

export function useChatStream(onChunk: (chunk: StreamChunk) => void) {
    useEffect(() => {
        const unlisten = listen('chat-stream', (event) => {
            onChunk(event.payload as StreamChunk);
        });
        return () => { unlisten.then(fn => fn()); };
    }, []);
}
```

**Checkpoint:** Can create a note in the UI, see it in the sidebar, edit it, and see it persist across app restart.

---

## PHASE 4: LLM CLIENT (Days 4-5)
**Goal:** Chat works end-to-end with streaming responses.

### 4.1 LLM Client Trait [MAC → Rust]
**Source:** `Epistemos/Engine/LLMClient.swift`
```rust
// llm/mod.rs
#[async_trait]
pub trait LlmClient: Send + Sync {
    async fn stream(&self, messages: Vec<ChatMessage>, config: &LlmConfig)
        -> Result<impl Stream<Item = Result<String>>>;
    async fn structured_output<T: DeserializeOwned>(&self, prompt: &str, schema: &str)
        -> Result<T>;
}
```

### 4.2 Provider Implementations [MAC → Rust]
**Source:** `Epistemos/Engine/LLMClient.swift` (provider switching logic)
- `llm/anthropic.rs` — Claude API via reqwest (Messages API, streaming SSE)
- `llm/openai.rs` — GPT API via reqwest (Chat Completions, streaming)
- `llm/google.rs` — Gemini API via reqwest (generateContent, streaming)
- `llm/ollama.rs` — Local Ollama via reqwest (localhost:11434)

### 4.3 Pipeline Service (Minimal) [MAC → Rust]
**Source:** `Epistemos/Engine/PipelineService.swift`
- Start with Pass 1 only (streaming direct answer)
- Port: triage → routing → stream tokens via `app.emit('chat-stream', chunk)`
- Passes 2 and 3 (enrichment, truth assessment) come in Phase 7

### 4.4 Settings Commands [MAC → Rust]
**Source:** `Epistemos/State/InferenceState.swift`
```rust
#[tauri::command]
async fn settings_set(state: State<'_, AppState>, key: String, value: String);
#[tauri::command]
async fn settings_get(state: State<'_, AppState>, key: String) -> Option<String>;
```

**Checkpoint:** Type a question in the chat UI, see streaming response from Claude/GPT/Gemini. Settings page saves API key.

---

## PHASE 5: RAPIER3D GRAPH (Days 5-7)
**Goal:** Knowledge graph with 3D physics, rendered in the web frontend.

### 5.1 Rapier3D World [NEW]
**Source concept:** `graph-engine/src/simulation.rs` (existing force sim logic for reference)
```rust
// physics/world.rs
pub struct PhysicsWorld {
    rigid_body_set: RigidBodySet,
    collider_set: ColliderSet,
    impulse_joint_set: ImpulseJointSet,
    node_map: HashMap<String, RigidBodyHandle>,
    // ...
}
```
- add_node: create RigidBody with mass based on link_count/word_count
- add_link: create ImpulseJoint (spring) between two bodies
- step: advance simulation one tick
- positions: return all body positions as Vec<{id, x, y, z}>

### 5.2 Graph Builder [MAC → Rust]
**Source:** `Epistemos/Graph/GraphBuilder.swift`
- Scan all pages → create note nodes
- Extract tags → tag nodes + tagged edges
- Extract ideas → idea nodes + contains edges
- Extract blocks → block nodes + contains edges
- Wire folders via contains edges

### 5.3 Graph Store [MAC → Rust]
**Source:** `Epistemos/Graph/GraphStore.swift`
- In-memory adjacency list
- shortestPath(), nodesLinkedBy(), neighbors()
- Load from rusqlite on startup

### 5.4 Physics Streaming [NEW]
- Background thread: 60fps physics tick + emit positions
- Frontend: D3.js force layout replaced with position receiver
- Existing D3 graph components handle rendering, just swap force source

### 5.5 Graph Commands [MAC + WEB]
```rust
#[tauri::command]
async fn graph_load(state: State<'_, AppState>) -> Result<GraphData, String>;
#[tauri::command]
async fn graph_search(state: State<'_, AppState>, query: String) -> Result<Vec<SearchResult>>;
#[tauri::command]
async fn graph_query(state: State<'_, AppState>, nl_query: String) -> Result<QueryResult>;
```

**Checkpoint:** Open graph view, see nodes with Rapier3D physics. Click node → info panel. Search works.

---

## PHASE 6: ENTITY EXTRACTION (Days 7-8)
**Goal:** AI automatically extracts entities and relationships from notes.

### 6.1 Extractor [MAC → Rust]
**Source:** `Epistemos/Graph/EntityExtractor.swift`
- Port extraction prompt templates (identical text)
- Port JSON parsing logic for extracted entities
- Port batch processing (5 notes at a time)
- Create semantic edges: cites, supports, contradicts, expands, questions

### 6.2 Graph Rebuild [MAC → Rust]
**Source:** `Epistemos/Graph/GraphBuilder.swift` (entity-aware rebuild)
- After extraction: create SDGraphNode + SDGraphEdge records
- Feed new nodes to PhysicsWorld
- Emit graph-updated event

**Checkpoint:** Write a note mentioning "Einstein" and "relativity" → entity extractor creates Source node + relationship edges → graph updates live.

---

## PHASE 7: FULL PIPELINE (Days 8-10)
**Goal:** Complete SOAR 3-pass pipeline with all 10 stages.

### 7.1 Pass 2: Deep Analysis [MAC → Rust]
**Source:** `Epistemos/Engine/EnrichmentController.swift`, `PromptComposer+Consolidated.swift`
- Background task after Pass 1 completes
- Structured output: rawAnalysis, uncertaintyTags, laymanSummary, reflection
- Emit via `app.emit('chat-enrichment', analysis)`

### 7.2 Pass 3: Truth Assessment [MAC → Rust]
**Source:** `Epistemos/Engine/PipelineService.swift` (truth assessment pass)
- Confidence calibration, evidence grading, safety assessment
- Emit via `app.emit('chat-truth', assessment)`

### 7.3 Signal System [MAC → Rust]
**Source:** `Epistemos/Engine/PipelineService.swift` (signal updates per stage)
```rust
pub struct SignalUpdate {
    pub confidence: f64,
    pub entropy: f64,
    pub dissonance: f64,
    pub health_score: f64,
    pub safety_state: SafetyState,
}
```
- Emit signal updates per stage: `app.emit('pipeline-signal', signal)`
- Frontend animates signal dashboard (existing web component)

### 7.4 SOAR Learning [MAC → Rust]
**Source:** `Epistemos/Engine/SOAREngine.swift`, `SOARService.swift`
- Edge-of-learnability detection
- Curriculum learning loop
- Only if `soar_config.enabled`

**Checkpoint:** Full chat experience matches macOS — streaming answer + enrichment panel + truth assessment + signal dashboard.

---

## PHASE 8: SEARCH & QUERY (Days 10-11)
**Goal:** Fuzzy search and natural language graph queries.

### 8.1 FTS5 Search Index [MAC → Rust]
**Source:** `Epistemos/Sync/SearchIndexService.swift`
- rusqlite FTS5 virtual table
- Index note titles + bodies
- BM25 ranking

### 8.2 Query Engine [MAC → Rust]
**Source:** `Epistemos/Engine/QueryParser.swift`, `QueryExecutor.swift`, `QueryEngine.swift`
- Heuristic parser (regex patterns for common NL queries)
- Executor dispatches to graph store / FTS5 / semantic search

### 8.3 Rust FST Search [MAC → Rust]
**Source:** `graph-engine/src/lib.rs` (graph_engine_search)
- Direct access — no FFI bridge needed
- Fuzzy search across all node labels

**Checkpoint:** Command palette searches work. NL queries in graph sidebar work.

---

## PHASE 9: RESEARCH TOOLS (Days 11-12)
**Goal:** Paper search, DOI import, novelty check.

### 9.1 Semantic Scholar API [MAC → Rust]
**Source:** `Epistemos/Engine/ResearchService.swift`
- Paper search by query
- DOI/ArXiv import
- Citation search

### 9.2 Novelty Check [MAC → Rust]
**Source:** `Epistemos/Engine/ResearchService.swift`
- Iterative query generation
- Cross-reference with existing vault

**Checkpoint:** Research library page works — search papers, import, see in graph.

---

## PHASE 10: POLISH & SHIP (Days 12-14)
**Goal:** Production-ready Windows app.

### 10.1 Vault Sync Watcher [MAC → Rust]
- `notify` crate file watcher
- Bidirectional: external .md edits sync to SQLite

### 10.2 Theme Persistence [WEB + NEW]
- Save selected theme to rusqlite settings
- Load on app start

### 10.3 Window Management [NEW]
- Remember window size/position
- System tray icon (optional)
- Keyboard shortcuts (Ctrl+N new note, Ctrl+S save)

### 10.4 Installer [NEW]
- `cargo tauri build` → .msi installer
- App icon, metadata

### 10.5 Testing [NEW]
- Rust unit tests for all modules
- Frontend: mock invoke() for existing vitest tests
- E2E: basic Playwright smoke test

**Checkpoint:** Install .msi on clean Windows machine. Full app works.

---

## SOURCE FILE REFERENCE

For each Rust module, here are the EXACT Swift files to translate from:

| Rust Module | Swift Source File(s) | Key Functions to Port |
|------------|---------------------|----------------------|
| `storage/db.rs` | `Models/EpistemosSchema.swift`, all `SD*.swift` | Schema, migrations |
| `storage/models.rs` | `Models/SDPage.swift`, `SDBlock.swift`, `SDChat.swift`, `SDMessage.swift` | Struct definitions |
| `storage/vault.rs` | `Sync/NoteFileStorage.swift`, `Sync/VaultSyncService.swift` | writeBody, readBody, watchVault |
| `storage/blocks.rs` | `Sync/BlockParser.swift`, `Sync/BlockReconciler.swift` | parse(), reconcile(), jaccardSimilarity() |
| `storage/search.rs` | `Sync/SearchIndexService.swift` | indexPage, search, rebuildIndex |
| `commands/chat.rs` | `State/ChatState.swift` | sendMessage, loadHistory, deleteChat |
| `commands/notes.rs` | `State/ChatState.swift` (note context), `Views/Notes/ProseEditorView.swift` | createPage, updateBody, deletePage |
| `commands/graph.rs` | `Graph/GraphState.swift` | loadGraph, searchNodes, queryGraph |
| `commands/settings.rs` | `State/InferenceState.swift` | getProvider, setApiKey, setQuality |
| `pipeline/mod.rs` | `Engine/PipelineService.swift` | run() — 3-pass orchestration |
| `pipeline/triage.rs` | `Engine/PipelineService.swift` (triage stage) | classifyQuery |
| `pipeline/enrichment.rs` | `Engine/EnrichmentController.swift`, `PromptComposer+Consolidated.swift` | deepAnalysis, laymanSummary |
| `pipeline/signals.rs` | `Engine/PipelineService.swift` (SignalUpdate) | SignalUpdate struct |
| `pipeline/soar.rs` | `Engine/SOAREngine.swift`, `SOARService.swift` | runCurriculum, detectEdge |
| `pipeline/research.rs` | `Engine/ResearchService.swift` | searchPapers, importDOI, noveltyCheck |
| `graph/builder.rs` | `Graph/GraphBuilder.swift` | buildGraph, scanPages, extractTags |
| `graph/extractor.rs` | `Graph/EntityExtractor.swift` | extractEntities, parseExtractionResult |
| `graph/store.rs` | `Graph/GraphStore.swift` | addNode, addEdge, shortestPath, neighbors |
| `graph/query.rs` | `Engine/QueryParser.swift`, `QueryExecutor.swift` | parseNL, executeDSL |
| `llm/mod.rs` | `Engine/LLMClient.swift` | LlmClient trait |
| `llm/anthropic.rs` | `Engine/LLMClient.swift` (Anthropic case) | stream, structuredOutput |
| `llm/openai.rs` | `Engine/LLMClient.swift` (OpenAI case) | stream, structuredOutput |
| `physics/world.rs` | `graph-engine/src/simulation.rs` (reference only) | PhysicsWorld with rapier3d |

---

## FRONTEND ADAPTATION CHECKLIST

Files in the web frontend that need modification:

| File Pattern | Change | Source |
|-------------|--------|--------|
| `app/api/**` | DELETE entirely | [WEB] |
| `next.config.ts` | Add `output: 'export'` | [NEW] |
| `lib/store/slices/message.ts` | Replace fetch → invoke | [WEB→Tauri] |
| `lib/store/slices/notes.ts` | Replace fetch → invoke | [WEB→Tauri] |
| `lib/store/slices/research.ts` | Replace fetch → invoke | [WEB→Tauri] |
| `lib/store/slices/inference.ts` | Replace fetch → invoke | [WEB→Tauri] |
| `components/chat/ChatInput.tsx` | Use invoke for send | [WEB→Tauri] |
| `components/notes/NoteEditor.tsx` | Use invoke for save | [WEB→Tauri] |
| `components/assistant/MiniChat.tsx` | Use invoke for send | [WEB→Tauri] |
| `hooks/use-chat-stream.ts` (or equivalent) | SSE → listen() | [WEB→Tauri] |
| `package.json` | Add @tauri-apps/api, remove better-sqlite3 | [NEW] |
| NEW `lib/tauri-bridge.ts` | invoke() wrapper functions | [NEW] |
| NEW `lib/tauri-events.ts` | listen() event hooks | [NEW] |
| NEW `hooks/use-tauri-stream.ts` | Streaming via Tauri events | [NEW] |

Everything else (components, styling, animations, themes) remains UNCHANGED.
