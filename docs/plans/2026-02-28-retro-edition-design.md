# Epistemos Retro Edition — Architecture Design

## Date: 2026-02-28
## Status: Approved
## Platform: Tauri 2.x + Next.js + Rust + Rapier3D

---

## 1. Overview

Epistemos ships as two editions:
- **Opulent Edition** — macOS native (Swift + Metal + Rust). Premium Apple experience.
- **Retro Edition** — Windows/cross-platform (Tauri + Next.js + Rust). Web frontend, pure Rust backend.

The Retro Edition fuses the best of two existing codebases:
- **Layout/Design** from the web frontend (`~/meta-analytical-pfc/brainiacv2/`)
- **Logic/Features** from the macOS app (`~/Epistemos/`)

---

## 2. The Dual-Translation Approach

This is the critical nuance: the Retro Edition is NOT a simple port of one codebase. It translates TWO sources simultaneously:

### Translation 1: Web Frontend → Tauri Shell
**Source:** `~/meta-analytical-pfc/brainiacv2/` (Next.js 16 + React 19 + Tailwind 4)
**Target:** Same frontend, wrapped in Tauri native window

What changes:
- `fetch('/api/chat', { body })` → `invoke('chat_send', { query })`
- SSE streaming → `listen('chat-stream', callback)` (Tauri events)
- `fetch('/api/notes/...')` → `invoke('notes_create', { ... })`
- ~20 API call sites need wrapping
- SQLite access moves from better-sqlite3 to Rust rusqlite (Tauri commands)

What stays identical:
- All React components (chat, notes, graph, settings, analytics)
- All Tailwind styling + 6 themes
- All Zustand state management (13 slices)
- All Framer Motion animations
- All D3.js graph visualization
- All decorative elements (starfield, wallpapers, pixel mascots)

### Translation 2: macOS Logic → Rust Backend
**Source:** `~/Epistemos/` (Swift 6 + SwiftData + Rust FFI)
**Target:** Pure Rust modules inside `src-tauri/src/`

What gets ported to Rust:
| Swift Module | Rust Module | Key Logic |
|-------------|------------|-----------|
| PipelineService.swift | pipeline/mod.rs | 3-pass SOAR pipeline (stream → analyze → truth assess) |
| EnrichmentController.swift | pipeline/enrichment.rs | Background analysis orchestration |
| ResearchService.swift | pipeline/research.rs | Paper search, DOI import, novelty check |
| SOAREngine.swift | pipeline/soar.rs | Curriculum learning, edge-of-learnability |
| EntityExtractor.swift | graph/extractor.rs | LLM entity extraction (sources, quotes, tags) |
| GraphBuilder.swift | graph/builder.rs | Build graph from notes/entities |
| GraphStore.swift | graph/store.rs | In-memory adjacency list |
| QueryEngine/Executor/Parser | graph/query.rs | NL → DSL → results |
| ChatState.swift | commands/chat.rs | Chat CRUD + streaming |
| NoteFileStorage.swift | storage/vault.rs | .md file read/write |
| VaultSyncService.swift | storage/vault.rs | File watching + bidirectional sync |
| BlockParser.swift | storage/blocks.rs | Markdown ↔ block conversion |
| BlockReconciler.swift | storage/blocks.rs | Jaccard similarity matching |
| LLMClient.swift | llm/mod.rs | HTTP client for Anthropic/OpenAI/Google/Ollama |
| InferenceState.swift | commands/settings.rs | Provider config, API keys |
| SearchIndexService.swift | storage/search.rs | FTS5 indexing |

What does NOT get ported (macOS-only):
- SwiftUI views (replaced by existing web frontend)
- Metal rendering (replaced by D3/WebGPU)
- AppKit integration (NSTextView, NSPopover, etc.)
- Apple Intelligence (replaced by Windows native AI — see Section 10)
- SwiftData (replaced by rusqlite)
- Combine/Observation (replaced by Zustand)

---

## 3. Project Structure

```
epistemos-retro/
├── src-tauri/                          # RUST BACKEND
│   ├── Cargo.toml                      # Workspace: tauri + graph-engine + rapier3d
│   ├── tauri.conf.json                 # Window: 1200x800, title, permissions
│   ├── src/
│   │   ├── main.rs                     # Tauri entry + command registration
│   │   ├── state.rs                    # AppState (db pool, graph store, pipeline)
│   │   ├── commands/                   # Tauri invoke handlers
│   │   │   ├── mod.rs
│   │   │   ├── chat.rs                 # chat_send, chat_list, chat_delete
│   │   │   ├── notes.rs                # notes_create, notes_update, notes_list, notes_delete
│   │   │   ├── graph.rs                # graph_load, graph_query, graph_search
│   │   │   ├── research.rs             # research_search, research_import
│   │   │   └── settings.rs             # settings_get, settings_set
│   │   ├── pipeline/                   # SOAR pipeline (from Swift)
│   │   │   ├── mod.rs                  # PipelineService::run()
│   │   │   ├── triage.rs               # Stage 1: classify query
│   │   │   ├── enrichment.rs           # Stages 2-7: analysis passes
│   │   │   ├── synthesis.rs            # Stages 8-10: compose answer
│   │   │   ├── signals.rs              # SignalUpdate struct
│   │   │   └── soar.rs                 # SOAR learning engine
│   │   ├── storage/                    # Persistence
│   │   │   ├── mod.rs
│   │   │   ├── db.rs                   # rusqlite schema + migrations
│   │   │   ├── models.rs               # Page, Block, Chat, Message, GraphNode, GraphEdge
│   │   │   ├── vault.rs                # .md file sync (notify crate)
│   │   │   ├── blocks.rs              # BlockParser + BlockReconciler
│   │   │   └── search.rs              # FTS5 indexing
│   │   ├── graph/                      # Graph logic
│   │   │   ├── mod.rs
│   │   │   ├── builder.rs              # Build graph from notes/entities
│   │   │   ├── extractor.rs            # LLM entity extraction
│   │   │   ├── store.rs                # In-memory adjacency list
│   │   │   └── query.rs                # DSL executor
│   │   ├── physics/                    # Rapier3D integration
│   │   │   ├── mod.rs
│   │   │   ├── world.rs                # RigidBodySet, ColliderSet, JointSet
│   │   │   ├── bridge.rs               # Node ID ↔ RigidBodyHandle mapping
│   │   │   └── streaming.rs            # 60fps position streaming to frontend
│   │   └── llm/                        # LLM client abstraction
│   │       ├── mod.rs                  # LlmClient trait
│   │       ├── anthropic.rs            # Claude API
│   │       ├── openai.rs               # GPT API
│   │       ├── google.rs               # Gemini API
│   │       ├── ollama.rs               # Local Ollama (GPU: GPT-OSS 20B)
│   │       └── foundry.rs              # Microsoft Foundry Local (NPU/GPU auto-routing)
│   └── graph-engine/                   # EXISTING Rust engine (workspace member)
│       ├── Cargo.toml
│       └── src/
│
├── src/                                # NEXT.JS FRONTEND (from brainiacv2)
│   ├── app/                            # Pages — mostly unchanged
│   │   ├── layout.tsx
│   │   ├── globals.css
│   │   ├── (shell)/                    # Main app routes
│   │   └── api/                        # DELETED — replaced by Tauri commands
│   ├── components/                     # All UI components — unchanged
│   ├── lib/
│   │   ├── tauri-bridge.ts             # NEW: invoke() wrapper functions
│   │   ├── tauri-events.ts             # NEW: event listener hooks
│   │   ├── store/                      # Zustand slices — unchanged
│   │   └── engine/                     # Types + prompts — unchanged
│   └── hooks/
│       └── use-tauri-stream.ts         # NEW: streaming hook via Tauri events
│
├── package.json
├── next.config.ts                      # Adapted for Tauri (output: 'export')
└── docs/
    └── retro-edition-design.md         # This document
```

---

## 4. Technology Stack

### Rust Backend (src-tauri/)
| Crate | Purpose |
|-------|---------|
| `tauri` 2.x | Native window, IPC, file system, system tray |
| `rapier3d` | 3D rigid body physics for graph |
| `rusqlite` | SQLite persistence (Page, Block, Chat, Message, Graph) |
| `reqwest` | HTTP client for LLM APIs + Foundry Local REST API |
| `ort` | ONNX Runtime Rust bindings (NPU/GPU inference for embeddings) |
| `foundry-local` | Microsoft Foundry Local Rust crate (model management + NPU routing) |
| `tokio` | Async runtime for streaming, file I/O |
| `serde` / `serde_json` | Serialization for Tauri commands |
| `notify` | File system watcher for vault sync |
| `uuid` | ID generation |
| `chrono` | Timestamps |

### Frontend (src/)
Unchanged from brainiacv2 except API call layer:
| Package | Purpose |
|---------|---------|
| `@tauri-apps/api` | `invoke()`, `listen()`, window management |
| `next` 16 | App router, SSR → SSG (output: 'export') |
| `react` 19 | UI framework |
| `tailwindcss` 4 | Styling + 6 themes |
| `zustand` 5 | State management (13 slices) |
| `framer-motion` 12 | Animations |
| `d3-*` | Graph visualization |
| `@ai-sdk/*` | REMOVED — AI calls go through Tauri invoke |

---

## 5. Rapier3D Physics Architecture

### Why Rapier3D (not 2D, not custom)
- **3D ⊃ 2D**: Set z=0 for flat mode. Enables camera orbiting, depth clustering, DNA helix.
- **Performance**: ~1ms/tick for 10K bodies. RTX 4060 target GPU handles rendering trivially.
- **Rigid body dynamics**: Mass-based gravity, collision, restitution (bounce), sleeping bodies, joint constraints.
- **"Cognitive exoskeleton"**: Node importance maps to physical mass. Confident ideas are heavy. Uncertain ideas are light and susceptible to gravitational pull.

### Integration
```rust
// physics/world.rs
pub struct PhysicsWorld {
    rigid_body_set: RigidBodySet,
    collider_set: ColliderSet,
    impulse_joint_set: ImpulseJointSet,
    gravity: Vector3<f32>,           // Gentle downward or center-pull
    integration_params: IntegrationParameters,
    physics_pipeline: PhysicsPipeline,
    node_map: HashMap<String, RigidBodyHandle>,  // node UUID → body
}

impl PhysicsWorld {
    pub fn add_node(&mut self, id: &str, mass: f32, pos: [f32; 3]) -> RigidBodyHandle;
    pub fn add_link(&mut self, from: &str, to: &str, stiffness: f32);
    pub fn step(&mut self);  // Single physics tick
    pub fn positions(&self) -> Vec<NodePosition>;  // Stream to frontend
}
```

### Streaming to Frontend
```rust
// physics/streaming.rs — 60fps Tauri event emission
fn physics_loop(app: AppHandle, world: Arc<Mutex<PhysicsWorld>>) {
    loop {
        let positions = {
            let mut w = world.lock().unwrap();
            w.step();
            w.positions()  // Vec<{id, x, y, z, radius}>
        };
        app.emit("graph-positions", &positions).ok();
        std::thread::sleep(Duration::from_millis(16));  // ~60fps
    }
}
```

### Frontend Consumption
```typescript
// lib/tauri-events.ts
import { listen } from '@tauri-apps/api/event';

export function useGraphPositions(onUpdate: (positions: NodePosition[]) => void) {
    useEffect(() => {
        const unlisten = listen('graph-positions', (event) => {
            onUpdate(event.payload as NodePosition[]);
        });
        return () => { unlisten.then(fn => fn()); };
    }, []);
}
```

---

## 6. Data Flow

### Chat Query Flow
```
User types query
  → Zustand dispatch (message slice)
  → invoke('chat_send', { query, chatId, controls })
  → Rust: PipelineService::run()
    → Pass 1: stream tokens via app.emit('chat-stream', chunk)
    → Pass 2: background enrichment → emit('chat-enrichment', analysis)
    → Pass 3: truth assessment → emit('chat-truth', assessment)
  → Frontend: listen() hooks update Zustand slices in real-time
```

### Note Save Flow
```
User edits note
  → Zustand dispatch (notes slice)
  → invoke('notes_update', { pageId, body })
  → Rust: storage::vault::write_body(page_id, body)
  → Rust: storage::blocks::reconcile(page_id, body)
  → Rust: graph::builder::rebuild_for_page(page_id)
  → emit('graph-updated', { affected_nodes })
```

### Graph Query Flow
```
User types NL query in sidebar
  → invoke('graph_query', { query })
  → Rust: graph::query::parse(query)  // NL → DSL
  → Rust: graph::query::execute(dsl)   // DSL → results
  → Return Vec<QueryResult> to frontend
  → Frontend highlights matching nodes in D3
```

---

## 7. Migration Notes

### What Transfers Cleanly (Copy/Adapt)
- LLM prompt templates (identical across both editions)
- Markdown parsing (Rust already does this)
- Block parser/reconciler logic (translate Swift → Rust)
- Graph builder algorithm (structural, not UI-dependent)
- Entity extraction prompts and parsing
- Query DSL types and executor logic
- Signal system types (confidence, entropy, dissonance)
- Pipeline stage definitions and ordering

### What Requires Reimplementation
- SwiftData → rusqlite (schema + migrations + queries)
- @Observable → Zustand (state management already exists in web app)
- Metal rendering → D3/WebGPU (graph visualization already exists in web app)
- Apple Intelligence → not available on Windows (use cloud LLM fallback)
- NSTextView → web editor (already exists in web app)
- Combine subscriptions → Tauri event listeners

### What's New (Not in Either Source)
- Rapier3D physics integration (replaces both custom Rust sim and D3 force)
- Tauri command layer (invoke/emit bridge)
- tauri-bridge.ts (frontend API wrapper)
- Physics position streaming at 60fps

---

## 8. Testing Strategy

### Rust Backend
- Unit tests for each module (storage, pipeline, graph, physics)
- Integration tests: full chat flow (query → pipeline → response)
- Rapier3D: physics convergence tests (reuse patterns from existing 551 Rust tests)

### Frontend
- Existing web app tests (vitest) should pass with mocked invoke()
- E2E: Playwright tests via Tauri webdriver

### Cross-Platform
- CI: GitHub Actions with Windows runner
- Build: `cargo tauri build` produces .msi installer

---

## 9. Windows Native AI — On-Device Intelligence

### The Parity Goal

macOS has **Apple Intelligence** — system-level on-device AI via the Foundation Models framework (NPU-optimized Phi Silica, 650 tokens/sec at 1.5W). The Retro Edition achieves parity using three native Windows AI technologies.

### Target Hardware: Dell XPS 16

The XPS 16 has **three AI accelerators**:
1. **Intel NPU** (AI Boost) — low-power, always-on inference (~1.5W)
2. **NVIDIA RTX 4060 GPU** — high-throughput CUDA inference
3. **CPU** — universal fallback

### Three-Layer Local AI Stack

#### Layer 1: Microsoft Foundry Local (Primary — Apple Intelligence Equivalent)
- **What:** Microsoft's on-device model server with OpenAI-compatible REST API
- **API:** `http://localhost:{PORT}/v1/chat/completions` — identical to OpenAI API
- **Rust integration:** `foundry-local` crate (model management) + `reqwest` (inference)
- **Hardware routing:** Auto-detects NPU, CUDA GPU, AMD, Intel — selects optimal execution provider per model
- **Models:** Phi-3.5-mini (NPU-optimized), DeepSeek-R1 distilled, custom ONNX models via Olive compiler
- **Delivery:** Bundled or first-run download (~2-4GB). `foundry model run phi-3.5-mini` starts serving
- **Use cases:** Triage classification, query parsing, summarization, entity extraction — all the quick local tasks

#### Layer 2: Ollama (GPU Powerhouse)
- **What:** Local model server for larger models needing full GPU
- **API:** `http://localhost:11434/api/chat` — OpenAI-compatible
- **Rust integration:** `reqwest` (same HTTP client pattern)
- **Models:** GPT-OSS 20B (4-bit, needs ~12GB VRAM), Qwen3-8B, Llama variants
- **Use cases:** Full SOAR pipeline passes, deep analysis, anything needing frontier-class reasoning locally

#### Layer 3: ONNX Runtime via `ort` Crate (Embeddings & Classification)
- **What:** Direct Rust-native ONNX model inference with DirectML execution provider
- **Rust integration:** `ort` crate — ergonomic API, supports NPU/GPU/CPU providers
- **Models:** Small ONNX models for embeddings (all-MiniLM-L6-v2), classifiers, triage
- **Use cases:** 384-dim embedding generation, similarity search, fast classification
- **Why separate:** Sub-millisecond inference, no HTTP overhead, runs inline in Rust code

#### Phi Silica (System-Level — Bonus)
- **What:** Microsoft's NPU-tuned model built into Windows Copilot Runtime
- **API:** WinRT `Microsoft.Windows.AI.Text.LanguageModel` (C#/C++ only)
- **Rust access:** Via `windows-rs` crate WinRT bindings (`windows::Win32::AI::MachineLearning::WinML`)
- **Status:** Limited Access Feature (requires unlock token from Microsoft)
- **Decision:** Use Foundry Local instead — it already handles NPU routing without the LAF restriction. Phi Silica is a nice-to-have if Microsoft opens it up.

### Hardware Routing Strategy

| Task | Layer | Hardware | Latency |
|------|-------|----------|---------|
| Triage classification | Foundry Local | NPU | ~50ms |
| Query parsing (NL → DSL) | Foundry Local | NPU | ~100ms |
| Text summarization | Foundry Local | NPU | ~200ms |
| Embedding generation | ort (ONNX) | NPU/GPU | <5ms |
| Entity extraction | Foundry Local or Ollama | GPU | ~500ms |
| SOAR deep analysis (Pass 2) | Ollama (GPT-OSS 20B) | RTX 4060 GPU | ~2-5s |
| Truth assessment (Pass 3) | Cloud LLM (Claude/GPT) | Cloud | ~3-8s |
| Full pipeline (Pass 1 stream) | Cloud or Ollama | Cloud/GPU | ~1-3s |

### Comparison: macOS vs Windows Local AI

| Feature | macOS (Opulent) | Windows (Retro) |
|---------|----------------|-----------------|
| System-level on-device AI | Apple Intelligence (Foundation Models) | Foundry Local (Phi-3.5 on NPU) |
| NPU acceleration | Apple Neural Engine | Intel AI Boost NPU |
| GPU inference | Metal (Apple Silicon unified memory) | CUDA (RTX 4060 dedicated VRAM) |
| Embedding model | MLX + SIMD Accelerate | ort crate + DirectML |
| Heavy local generation | GPT-OSS 20B via MLX | GPT-OSS 20B via Ollama |
| Cloud fallback | Claude/GPT/Gemini | Claude/GPT/Gemini (identical) |
| Rust integration | Custom FFI | `foundry-local` + `ort` + `reqwest` |

### LLM Client Architecture

```rust
// llm/mod.rs — unified trait, 6 providers
#[async_trait]
pub trait LlmClient: Send + Sync {
    async fn stream(&self, messages: Vec<ChatMessage>, config: &LlmConfig)
        -> Result<impl Stream<Item = Result<String>>>;
    async fn structured_output<T: DeserializeOwned>(&self, prompt: &str, schema: &str)
        -> Result<T>;
}

// Cloud providers (identical to macOS)
pub struct AnthropicClient;    // llm/anthropic.rs
pub struct OpenAiClient;       // llm/openai.rs
pub struct GoogleClient;       // llm/google.rs

// Local providers (Windows-native)
pub struct OllamaClient;       // llm/ollama.rs — GPU (GPT-OSS 20B)
pub struct FoundryClient;      // llm/foundry.rs — NPU/GPU auto-routed (Phi-3.5)

// Direct ONNX (not through LlmClient — used inline for embeddings)
pub struct OnnxEmbedder;       // llm/embeddings.rs — ort crate, sub-ms inference
```

### Triage Router (Equivalent to macOS On-Device/Cloud Routing)

```rust
// pipeline/triage.rs — decides which provider handles each task
impl TriageRouter {
    fn route(&self, task: &PipelineTask) -> ProviderChoice {
        match task.complexity {
            Low => {
                // Quick classification, parsing, summarization
                // → Foundry Local on NPU (50-200ms, 1.5W)
                if self.foundry_available { ProviderChoice::Foundry }
                else { ProviderChoice::Cloud(self.default_cloud) }
            }
            Medium => {
                // Entity extraction, moderate generation
                // → Ollama on GPU or Foundry on GPU
                if self.ollama_available { ProviderChoice::Ollama }
                else { ProviderChoice::Cloud(self.default_cloud) }
            }
            High => {
                // Deep analysis, truth assessment, frontier reasoning
                // → Cloud LLM (Claude Sonnet/Opus)
                ProviderChoice::Cloud(self.default_cloud)
            }
        }
    }
}
```

---

## 10. Implementation Order

See implementation plan document for detailed wave-by-wave breakdown.
Priority: get a working chat + notes + graph loop first, then layer features.
