please deep research this entire thing I want you to research the most the most high-performance high-powered way to do this so that performance does not dip at all so that it feels like magic because things happen doesn't feel like slowing down or anything like that this this is a swift sixth rust Uni FFI in metal app cognitive app that's a native macOS app and it's built to be sophisticated and robust and privacy further and things like that so you know I really wanna make sure that these things are working in that yeah I can get this interesting huge implementation. research the best practices as well at Coach snippet at Advice at executive Advice to help Claude implement it please------------so pleaseso I want to implement this, but I want to add one more thing so for the end for the ambient or instant recall, I want kind of it to be like this so imagine you're taking notes or sending a chat any of the chats there should be like a button that pops up on the message bar or that pops up somewhere on the note window window has active recall or instant recall or recall and you press it and it has a live view of all the notes related to the current text. You're doing so imagine if I have a note that's titled all things go all grocery list all features to add and then I type in AL and Then first the button has to appear because on dormant the button doesn't stay there. It's a dynamic then when you start typing the button here you click it and then there's a live view of all the notes related to Something or all of the chats related to something so even if you're typing, there's there's like a toggle for notes and chats on the notes you can like scroll up. You can literally hover over it and it'll show you the note and you can literally edit directly from there and also on chat you can't edit chess directly from it but when you click on calling and toggle chat chats that have basically the things that you're typing will show up in all you should be able to select it and it'll take you to it or you can right click it and say summarize and it'll summarize things from that chat so it should be dynamic in that way I really want to add that it's really important----------# Part 1: Deliberation — What's Unfinished, Why It Matters, and What Must Ship

**Date:** April 23, 2026 | **Purpose:** Exhaustive audit of every incomplete subsystem for Codex execution

---

## 1. Inventory of Incomplete Systems

### 🔴 CRITICAL — Core Features Not Wired End-to-End

#### C1: Contextual Shadows (Phase 18 — Instant Recall UI)
- **Rust side:** `epistemos-core/src/instant_recall/` has 13 modules — `InstantRecallIndex`, `TrigramEmbedder`, `HybridSearchPipeline`, `SegmentedIndex`, `TurboQuantVector`, `ButterflyRotation`, `KittyVector`, `ProgressiveKVCache`, `FusedResult`, `CrossEncoder`. All compile and pass tests.
- **Rust side:** `graph-engine/src/retrieval_index.rs` has `PreparedRetrievalStore` with HNSW via `usearch`, loads manifests, performs ANN search. Tests pass.
- **Swift side:** `KnowledgeFusion/InstantRecallService.swift` (10KB) exists.
- **NOT WIRED:** No debounce loop from the prose editor → encode → search → sidebar UI. The 200ms continuous encoding loop described in the North Star does not exist. No "Contextual Shadows" sidebar panel in any SwiftUI view. `EmbeddingService.swift` sends embeddings to graph-engine but does NOT feed them to instant recall for live retrieval. The retrieval_index in graph-engine is for prepared/batch retrieval, not live-as-you-type recall.
- **Gap:** Editor → debounce → encode → Rust binary HNSW search → return top-5 → render in sidebar. This is the #1 feature differentiator vs Obsidian/Notion.

#### C2: Agent Runtime Stub
- **Rust side:** `agent_core/src/` has 34 files + 6 subdirs — full agent loop, command center, context compiler, session persistence, approval system, security, tools, providers, routing, etc.
- **Swift side:** `StreamingDelegate.swift:64-73` has `runAgentSession()` that throws `AgentRuntimeBridgeError.bindingsUnavailable`. It's a dead stub.
- **Swift side:** `Epistemos/Omega/` has 8 files + 8 subdirs (GhostComputerAgent, MCPBridge, ResearchOrchestrator, Vision subsystem, etc.)
- **NOT WIRED:** The `agent_core` Rust crate compiles but its UniFFI bridge to Swift is not connected. `MCPBridge.swift` connects to `omega-mcp` for tool dispatch, but the actual agent loop (plan → execute → verify → iterate) doesn't run. `ChatCoordinator` routes agent-mode to cloud chat, not to the Rust orchestrator.
- **Gap:** `agent_core` → UniFFI bridge → Swift `AgentRuntime` → ChatCoordinator agent mode. Or: remove the stub and honestly route through cloud agents.

#### C3: Computer Use Stack (AX + Screen2AX + CGEvent)
- **Rust side:** `omega-ax/src/` has `ax_tree.rs`, `ax_ffi.rs`, `input.rs`, `permissions.rs`, `shortcuts.rs` — all compile.
- **Swift side:** `Omega/Vision/` has `Screen2AXFusion.swift`, `ScreenCaptureService.swift`, `VisualVerifyLoop.swift`, `AXorcistBridge.swift`, `TCCPermissionState.swift`, `AXMutationDetector.swift` — substantial code.
- **Swift side:** `Omega/Agents/GhostComputerAgent.swift` (33KB) — the orchestrator for screen actions.
- **NOT WIRED:** `GhostComputerAgent` exists but is not callable from any user-facing surface. No UI trigger. The perception pipeline (ScreenCaptureKit → SparsityDetector → AX tree / Screen2AX VLM fallback) is coded but not exercised in the running app. `VisualVerifyLoop` has no active consumer.
- **Gap:** Command Center slash command → GhostComputerAgent → perception pipeline → action execution → visual verify. Needs a UI entry point and end-to-end test.

#### C4: Knowledge-Core Transition (Two Runtimes Problem)
- **Live runtime:** BTK (BlockTree + OpLog + BtkQueryKernel) — SwiftData + GRDB search + vault markdown files
- **Staged runtime:** `graph-engine/src/knowledge_core/` — Cozo store (51KB), shared-memory ring (18KB), CRDT/Loro (11KB), parser (11KB)
- **Swift shadow:** `KnowledgeCoreBridge.swift` (32KB) — maps shared ring, drains diffs, records batch counters
- **Status per STATE_OF_SYSTEM.md:** "parallel-runtime transition state" — shadow runtime is off by default, behind `UserDefaults` flag
- **NOT WIRED:** Knowledge-core does not drive any production view model. `QueryRuntime`, `GraphStore`, and SwiftUI views still read from SwiftData/BTK. The staged Cozo store has no persisted backend. The Loro CRDT is not used by the live editor.
- **Gap:** Either promote knowledge-core to authoritative (replace SwiftData path) or defer it explicitly. Current state is technical debt.

---

### 🟡 PARTIAL — Code Exists But Gaps Remain

#### P1: Embedding FFI on MainActor (Performance Blocker)
- `EmbeddingService.swift:218-225` runs `sendEmbeddingBatch` and `graph_engine_recompute_semantic_neighbors` on MainActor → 50-100ms UI freeze on large graphs.
- **Fix:** Move to serial DispatchQueue. Code is in `A+_RELEASE_ROADMAP.md` Fix #5. Not applied.

#### P2: Graph Renderer Stutter
- `MetalGraphView.swift` CVDisplayLink callback runs `renderFrame()` on main thread.
- **Fix:** Background render queue. Code is in `A+_RELEASE_ROADMAP.md` Fix #6. Not applied.

#### P3: @Query Cascade During AI Streaming
- SwiftData `@Query` refetch storms during token streaming. NoteChatState saves trigger cascade.
- **Fix:** Debounce model saves during streaming. Code is in `A+_RELEASE_ROADMAP.md` Fix #7. Not applied.

#### P4: Local Model Catalog Gaps
- 9 of 18 models have no install metadata in `LocalModelCatalog` per V1 audit
- Context windows under-reported (50-87% wasted) for Qwen 3.5, DeepSeek R1, Gemma 4
- Temperature values wrong for Gemma 4 (0.7 → should be 1.0)
- Vision encoder integration: flags exist (`supportsVision: Bool`) but no encoder wired
- Tool-call extraction: no parsers for Gemma 4 `<start_function_call>`, Qwen `<tool_call_start>`, SmolLM3 XML

#### P5: GEPA / Hyperbolic Topology / Neural Cache (agent_core → epistemos-core Port)
- `agent_core/src/evolution/mutation_proposer.rs` (11KB) — skill mutation proposer, debug-only
- `agent_core/src/storage/hyperbolic_topology.rs` (23KB) — Poincaré disk topology, debug-only
- `agent_core/src/storage/neural_cache.rs` (12KB) — hot/warm/cold temporal cache, debug-only
- `VaultLifecycleService.swift` has pure-Swift reimplementations that NightBrain calls
- **Gap:** Per `IMPLEMENTATION_PLAN_FEATURES.md`, these should be ported to `epistemos-core` with UniFFI exports and wired through NightBrain. None of the ports have been executed.

#### P6: Capture Pipeline UI Integration
- `TextCapturePipeline.swift` (759 lines) — complete pipeline: clean → extract → persist → graph → trace
- `QuickCaptureView.swift` (14KB) and `TraceInspectorView.swift` (6KB) exist
- `runFromAudio()` method accepts `TranscribedAudio` but there's no `AudioTranscriber` implementation
- **Gap:** QuickCaptureView hotkey wiring, audio capture path, and integration into main app shell

#### P7: MCP Server Validation
- `omega-mcp/src/` has 20 files — full MCP server with tool registry, dispatcher, orchestrator, recipe cache, vault access, PTY terminal, osascript execution
- `MCPBridge.swift` successfully creates dispatcher and registers builtin tools
- **Gap:** No runtime integration tests. No MCP client validation. Tool dispatch works in isolation but isn't exercised through a real agent loop.

---

### 🔮 FUTURE — Code Ready or Designed But Blocked/Unbuilt

#### F1: ODIA Nightly Self-Improvement Loop (Phase 16)
- Training pipeline code is ready in `KnowledgeFusion/Training/`
- Blocked on RunPod funds ($150+ for Nano, $800-1500 for Base)
- NightBrain has job slots but training execution is stubbed
- `TraceDataMixer` 40/20/20/20 composition not implemented

#### F2: Temporal Belief Tracking (Phase 20)
- North Star describes monthly LoRA adapter snapshots + cosine distance tracking
- No code exists for this. No adapter versioning. No epoch comparison infrastructure.

#### F3: MoLoRA Per-App Adapters (Phase 8 marked complete, but...)
- `KnowledgeFusion/MoLoRA/` directory exists
- `KnowledgeFusion/Adapters/` directory exists
- Router designed to swap adapters based on `NSWorkspace.shared.frontmostApplication`
- **Reality:** No trained adapters exist. No per-app training data collected. The router logic may exist but has nothing to route.

#### F4: Mirror Speculative Decoding (Phase 19)
- North Star cites arXiv 2510.13161v2 for Brain 2 (ANE) as draft model + Brain 1 (GPU) as verifier
- No implementation exists. Requires both brains to be operational.

#### F5: Safety Layer / Referee Model (Phase 22)
- No code exists. Future phase.

#### F6: CRDT Ghost-Brain (Phase 23)
- Loro is compiled in Rust (`knowledge_core/crdt.rs`, 11KB)
- `OutlineCrdt` struct exists with `LoroDoc`/`LoroTree` wrappers
- Not used by the live editor. No sync protocol. No collaboration layer.

#### F7: Advanced Reasoning — KG-Trie, R2F Unlearning, EMMET (Phase 24)
- North Star describes R2F (Recover-to-Forget) for selective knowledge unlearning
- North Star describes EMMET for batched fact editing (10K facts, 99.7% reduced overhead)
- No code exists for either.

---

## 2. Deliberation: What Actually Matters for V1

### The Honest Priority Stack

| Priority | Feature | Why | Risk if Skipped |
|----------|---------|-----|-----------------|
| **P0** | Contextual Shadows (C1) | THE differentiator. Without it, Epistemos is "Obsidian but macOS only" | Product dies on arrival |
| **P0** | Embedding FFI fix (P1) | 50-100ms UI freezes are unshippable | Users think app is broken |
| **P0** | Graph stutter fix (P2) | Your demo moment (Metal graph) looks broken | First impression destroyed |
| **P0** | @Query debounce (P3) | AI chat is unusable with refetch storms | Core feature feels broken |
| **P1** | Agent runtime decision (C2) | Either wire it or remove the stub cleanly | Crash on agent mode toggle |
| **P1** | Local model catalog fix (P4) | Users can't use models they installed | Broken promise |
| **P1** | Capture pipeline UI (P6) | Quick capture is a daily-driver feature | Missing workflow |
| **P2** | Computer Use (C3) | Impressive demo but not daily-driver for v1 | OK to defer to v1.1 |
| **P2** | Knowledge-core promotion (C4) | Architectural debt, not user-facing | OK to keep BTK live for v1 |
| **P2** | GEPA/Topology/Cache ports (P5) | Background intelligence, not user-visible | NightBrain runs Swift fallbacks |
| **P3** | ODIA training (F1) | Blocked on funds, not code | Defer |
| **P3** | Belief tracking (F2) | Requires trained adapters | Defer |
| **P3** | MoLoRA (F3) | Requires per-app training data | Defer |
| **P3** | Mirror-SD (F4) | Research feature | Defer |
| **P4** | Safety/CRDT/R2F (F5-F7) | Research/future phases | Defer |

### Key Design Decisions Needed

1. **Agent Runtime:** Wire `agent_core` Rust loop via UniFFI, or route agent mode to cloud-only with honest UI labeling?
2. **Knowledge-Core:** Promote to authoritative for v1, or explicitly defer and keep BTK live?
3. **Contextual Shadows:** Use `epistemos-core/instant_recall` (flat binary scan) or `graph-engine/retrieval_index` (HNSW) as the live path?
4. **Computer Use:** Ship as hidden feature flag, or fully remove from v1 UI?

---

## 3. Research References for Implementation

| Feature | Key Paper/Reference | Why It Matters |
|---------|-------------------|----------------|
| Binary HNSW Search | Malkov & Yashunin, "Efficient and Robust Approximate Nearest Neighbor using Hierarchical Navigable Small World Graphs" (arXiv 1603.09320) | Foundation for instant recall index |
| Model2Vec Encoding | Minishlab Model2Vec (2024) — static token embeddings, ~1ms/paragraph | Encoding speed target for continuous loop |
| Mamba-2 Architecture | Dao & Gu, "Transformers are SSMs" (arXiv 2405.21060) | Hybrid Mamba-Attention architecture rationale |
| Mirror Speculative Decoding | Apple MLR, arXiv 2510.13161v2 | Dual-brain concurrent inference (Phase 19) |
| PolarQuant | arXiv 2502.02617 | 4.2x compression for vector indices (Phase 21) |
| LoRA Fine-Tuning | Hu et al., "LoRA: Low-Rank Adaptation" (arXiv 2106.09685) | Foundation for personal model adaptation |
| MoLoRA | Multiple LoRA adapter routing per domain | Per-app adapter hot-swap |
| Recover-to-Forget (R2F) | Selective knowledge unlearning without catastrophic forgetting | Belief update system (Phase 24) |
| EMMET | Batched model editing (10K facts, 99.7% reduced precomputation) | Mass knowledge update (Phase 24) |
| Voyager Recipe Caching | Wang et al., "Voyager" (2023) — skill library for LLM agents | RecipeManager deterministic replay |
| Free Energy Principle (FEP) | Friston (2010) — active inference for folder traversal decisions | Hyperbolic topology `should_pierce_blanket()` |
| OmniParser V2 | Microsoft, YOLOv8 + Florence-2 for UI understanding | Screen2AX VLM fallback |
| usearch HNSW | Unum usearch crate — fast ANN with Hamming distance + ARM NEON | Rust-side vector index |
| Loro CRDT | Loro collaborative CRDT library | Block ordering + future sync (Phase 23) |

---

## 4. Summary for Part 2

Part 2 (the Implementation Plan) covers each P0/P1/P2 item with:
- Exact files to create/modify
- Wiring instructions (which function calls which)
- FFI bridge specifications
- Verification commands
- Acceptance criteria

See `part2_implementation_plan.md` for the execution document.
# Part 2: Implementation Plan — Wiring Every Incomplete Subsystem

**Date:** April 23, 2026 | **For:** Codex (Auditor/Builder) execution  
**Prerequisite:** Read `part1_deliberation.md` first for full context on each gap.

---

## How to Use This Document

Each section follows this format:
1. **Current State** — what exists and where
2. **Gap** — what's missing
3. **Wiring Plan** — exact files, functions, and connections
4. **Verification** — how to prove it works
5. **Acceptance Criteria** — definition of done

> [!IMPORTANT]
> Read `EPISTEMOS-NORTH-STAR.md`, `CLAUDE.md`, and `ARCHITECTURE_MAP.md` before executing.
> All changes must respect the 5-layer architecture. No layer skipping.

---

# P0-A: Contextual Shadows — Instant Recall UI

> **This is the single most important feature to ship.** Without it, Epistemos is "a nice markdown editor with a graph." With it, Epistemos is "the app that remembers everything you've ever written."

### Current State

| Component | Location | Status |
|-----------|----------|--------|
| `InstantRecallIndex` | `epistemos-core/src/instant_recall/index.rs` | ✅ Compiles, tests pass |
| `TrigramEmbedder` | `epistemos-core/src/instant_recall/embedder.rs` | ✅ Compiles |
| `HybridSearchPipeline` | `epistemos-core/src/instant_recall/fusion.rs` | ✅ Compiles |
| `InstantRecallService` | `Epistemos/KnowledgeFusion/InstantRecallService.swift` | ⚠️ Exists, wiring unclear |
| `PreparedRetrievalStore` | `graph-engine/src/retrieval_index.rs` | ✅ HNSW via usearch, tests pass |
| `EmbeddingService` | `Epistemos/Engine/EmbeddingService.swift` (not in Engine listing — may be in Graph/) | ⚠️ Sends embeddings to graph-engine, no recall loop |
| Editor debounce → encode | Nowhere | ❌ Does not exist |
| Contextual Shadows sidebar | Nowhere | ❌ Does not exist |

### Gap

The 200ms debounce loop (editor text → encode → search → surface results) described in North Star §"The Continuous Encoding Loop" has no implementation. There is no sidebar panel showing related notes.

### Wiring Plan

#### Step 1: Expose InstantRecall via UniFFI from epistemos-core

**File:** `epistemos-core/src/uniffi_exports.rs`
```rust
pub use crate::instant_recall::{
    InstantRecallIndex, InstantRecallConfig, RecallResult,
    TrigramEmbedder,
};
```

**File:** `epistemos-core/uniffi/epistemos_core.udl` — add:
```webidl
dictionary RecallResult {
    string doc_id;
    string text;
    f32 score;
};

// Free functions for Swift to call:
string instant_recall_encode(string text, u32 dimension);
sequence<RecallResult> instant_recall_search(string query_embedding_json, u32 top_k);
void instant_recall_insert(string doc_id, string text);
void instant_recall_remove(string doc_id);
u64 instant_recall_count();
```

Implement a module-level singleton `InstantRecallIndex` in Rust behind a `OnceLock<Mutex<InstantRecallIndex>>` so Swift can call stateless free functions.

#### Step 2: Create Swift bridge service

**File [NEW]:** `Epistemos/Engine/ContextualShadowsService.swift`

```swift
@MainActor @Observable
final class ContextualShadowsService {
    private(set) var relatedNotes: [ShadowResult] = []
    private var debounceTask: Task<Void, Never>?
    
    struct ShadowResult: Identifiable {
        let id: String  // page ID
        let title: String
        let snippet: String
        let score: Float
    }
    
    /// Called by the prose editor on every text change.
    /// Debounces at 200ms, then encodes + searches.
    func onEditorTextChanged(_ text: String) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await performRecall(text)
        }
    }
    
    private func performRecall(_ text: String) async {
        // 1. Get last paragraph or last 200 chars
        let queryText = extractQueryContext(from: text)
        guard !queryText.isEmpty else { relatedNotes = []; return }
        
        // 2. Call Rust FFI to encode + search (off main actor)
        let results = await Task.detached {
            // encode via TrigramEmbedder
            let encoded = instantRecallEncode(text: queryText, dimension: 1024)
            // search
            return instantRecallSearch(queryEmbeddingJson: encoded, topK: 5)
        }.value
        
        // 3. Map to ShadowResult with page metadata
        relatedNotes = results.map { r in
            ShadowResult(id: r.docId, title: titleForPage(r.docId), 
                        snippet: String(r.text.prefix(120)), score: r.score)
        }
    }
}
```

#### Step 3: Wire editor → service

**File:** `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` (or wherever the editor coordinator lives)

In the text-change handler (likely `textDidChange` or similar NSTextStorageDelegate):
```swift
// After existing debounced save logic:
contextualShadowsService?.onEditorTextChanged(currentText)
```

#### Step 4: Create Contextual Shadows sidebar view

**File [NEW]:** `Epistemos/Views/Notes/ContextualShadowsPanel.swift`

SwiftUI view that reads `ContextualShadowsService.relatedNotes` and renders:
- Note title (clickable → navigate to note)
- 2-line snippet
- Relevance score indicator
- Fade in/out animation on appearance/change
- Typewriter-style popover aesthetic per North Star

#### Step 5: Index vault on startup

**File:** `Epistemos/App/AppBootstrap.swift`

During app init, after vault is loaded:
```swift
// Index all existing notes into InstantRecall
Task.detached(priority: .utility) {
    let pages = try modelContext.fetch(FetchDescriptor<SDPage>())
    for page in pages {
        if let body = page.loadBody() {
            instantRecallInsert(docId: page.id, text: body)
        }
    }
}
```

Wire incremental updates: when a note is saved, call `instantRecallInsert`. When deleted, call `instantRecallRemove`.

#### Step 6: Wire into note editing view

Inject `ContextualShadowsService` via environment. Show `ContextualShadowsPanel` as a sidebar or trailing panel in the note editor layout.

### Verification

```bash
cd epistemos-core && cargo test instant_recall
bash build-epistemos-core.sh
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos build
```

Manual: Open a note, type a paragraph. Within 500ms, sidebar should show 0-5 related notes. Verify by typing content that matches an existing note.

### Acceptance Criteria
- [ ] `instantRecallInsert/Search/Remove` callable from Swift
- [ ] Editor text changes trigger debounced recall
- [ ] Sidebar panel shows related notes with fade animation
- [ ] Vault indexed on startup
- [ ] Incremental index updates on note save/delete
- [ ] Search latency < 10ms for 1K notes (measured in test)

---

# P0-B: Performance Fixes (Three Items)

### Fix 1: Embedding FFI Off MainActor

**File:** `Epistemos/Engine/EmbeddingService.swift` (around line 218)

**Current:**
```swift
await MainActor.run {
    Self.sendEmbeddingBatch(payload, to: engineHandle.raw)
    graph_engine_recompute_semantic_neighbors(engineHandle.raw, 8, 0.3)
}
```

**Replace with:**
```swift
private static let ffiQueue = DispatchQueue(label: "epistemos.embedding.ffi", qos: .utility)

await withCheckedContinuation { continuation in
    Self.ffiQueue.async {
        Self.sendEmbeddingBatch(payload, to: engineHandle.raw)
        graph_engine_recompute_semantic_neighbors(engineHandle.raw, 8, 0.3)
        continuation.resume()
    }
}
```

### Fix 2: Graph Renderer Background Thread

**File:** `Epistemos/Views/Graph/MetalGraphView.swift` (around line 692)

**Current:**
```swift
@objc private func handleDisplayLinkTick(_ link: CADisplayLink) {
    renderFrame()
}
```

**Replace with:**
```swift
private let renderQueue = DispatchQueue(label: "epistemos.metal.render", qos: .userInteractive)

@objc private func handleDisplayLinkTick(_ link: CADisplayLink) {
    renderQueue.async { [weak self] in
        self?.renderFrame()
    }
}
```

### Fix 3: @Query Debounce During AI Streaming

**File:** `Epistemos/State/NoteChatState.swift` (or wherever streaming token batches trigger model saves)

Add a `Debouncer` that delays `modelContext.save()` calls during active streaming to 500ms intervals instead of per-token-batch.

### Verification
```bash
xcodebuild build
# Manual: Open large vault → pan graph → should be 60fps smooth
# Manual: Stream long AI response → Activity Monitor should show stable CPU
```

### Acceptance Criteria
- [ ] No MainActor FFI calls in EmbeddingService
- [ ] Graph render callback on background queue
- [ ] AI streaming doesn't trigger @Query cascade
- [ ] No visible stutter on graph pan/zoom with 500+ nodes

---

# P1-A: Agent Runtime Decision

### Option A: Wire agent_core (Recommended if agent features ship in v1)

1. **Build UniFFI bridge** for `agent_core` → generate Swift bindings
2. **Replace stub** in `StreamingDelegate.swift:64-73` with real call to `agent_core::agent_loop::run_session()`
3. **Wire ChatCoordinator** agent mode to use Rust agent loop instead of cloud fallback
4. **Gate behind ShipGate** — only enable when `ShipGate.agentsEnabled = true`

### Option B: Clean removal (Recommended for v1 ship)

1. **Remove stub** in `StreamingDelegate.swift` — delete `runAgentSession()`
2. **Remove dead call** in `ChatCoordinator.swift` that references `runRustAgentPath()`
3. **Set** `ShipGate.agentsEnabled = false` in `AppBootstrap.swift`
4. **Hide** Omega navigation surfaces that reference agent mode (already partially done per RELEASE_READINESS_AUDIT)

> [!IMPORTANT]
> Choose one. Do not leave the throwing stub. It crashes agent mode.

### Verification
```bash
xcodebuild build
# If Option A: Toggle agent mode → should route to Rust agent loop
# If Option B: Agent mode toggle should be hidden or route to cloud chat cleanly
```

---

# P1-B: Local Model Catalog Hardening

### Step 1: Fix Context Windows

**File:** `Epistemos/State/InferenceState.swift` (or `LocalModelInfrastructure.swift`)

Update context window values per model specs:
| Model | Current | Correct |
|-------|---------|---------|
| Qwen 3.5 0.8B/2B/4B | 32,768 | 262,144 |
| Qwen 3.5 9B/27B/35B | 131,072 | 262,144 |
| DeepSeek R1 7B | 65,536 | 128,000 |
| Gemma 4 12B | 131,072 | 256,000 |

### Step 2: Fix Temperature Values

| Model | Current | Correct |
|-------|---------|---------|
| Gemma 4 | 0.7 | 1.0 |
| DeepSeek R1 | 0.5 | 0.6 |

### Step 3: Add Missing Catalog Entries

Add install metadata for the 9 missing models in `LocalModelCatalog`. Each needs: HuggingFace repo ID, expected size, minimum RAM, context window, temperature, capability flags.

### Step 4: Tool-Call Extraction Parsers

**File [NEW]:** `Epistemos/Engine/ToolCallParsers/` directory with parsers for:
- Gemma 4: `<start_function_call>` / `<end_function_call>` format
- Qwen: `<tool_call_start>` / `<tool_call_end>` format  
- SmolLM3: XML `<tool_call>` format
- Generic: JSON-in-markdown code fences

Each parser implements a `ToolCallParser` protocol that extracts tool name + arguments from model output.

### Verification
```bash
xcodebuild test -only-testing:EpistemosTests/LocalModelInfrastructureTests
```

---

# P1-C: Capture Pipeline UI Integration

### Current State
- `TextCapturePipeline.swift` — complete, 759 lines, tested
- `QuickCaptureView.swift` — 14KB, exists
- `TraceInspectorView.swift` — 6KB, exists
- No global hotkey wiring
- No audio transcriber

### Wiring Plan

#### Step 1: Global Hotkey for Quick Capture

**File:** `Epistemos/App/AppBootstrap.swift` or dedicated `HotkeyService.swift`

Register global hotkey (e.g., ⌘⇧Space or user-configurable) that presents `QuickCaptureView` as a floating panel.

#### Step 2: Wire QuickCaptureView → TextCapturePipeline

Ensure `QuickCaptureView` calls `TextCapturePipeline.run(rawText:modelContext:)` on submit and displays the `CaptureResult`.

#### Step 3: Add to App Shell

Add Quick Capture as an accessible entry point:
- Menu bar item
- Toolbar button in main window
- Keyboard shortcut

#### Step 4: Wire TraceInspectorView

Make `TraceInspectorView` accessible from Settings or a developer menu. It should display `TraceCollector.shared` events.

### Acceptance Criteria
- [ ] Hotkey opens capture panel
- [ ] Typed text → structured note with title, summary, entities, tasks
- [ ] Note appears in vault and graph after capture
- [ ] Trace events visible in inspector

---

# P2-A: Computer Use Stack End-to-End

> [!NOTE]
> This can ship as a hidden feature flag for v1. Full polish is v1.1.

### Wiring Plan

#### Step 1: Perception Pipeline Test Harness

Create a test that exercises:
```
ScreenCaptureKit frame → SparsityDetector (count AX elements)
  → IF ≥5: Native AX tree via omega-ax
  → IF <5: Screen2AX VLM fallback via MLX
  → Structured AX tree JSON
```

**File [NEW]:** `EpistemosTests/ComputerUseIntegrationTests.swift`

#### Step 2: Wire GhostComputerAgent to Command Center

`GhostComputerAgent.swift` (33KB) needs a UI trigger. Options:
- Slash command `/agent do <task>` in the Command Center
- Dedicated "Computer Use" panel in settings
- Agent mode in chat with `@computer` prefix

#### Step 3: Visual Verify Loop Consumer

`VisualVerifyLoop.swift` captures frames and verifies actions succeeded. Wire it as the feedback loop for `GhostComputerAgent` action execution.

#### Step 4: TCC Permission Flow

`TCCPermissionState.swift` checks screen recording and accessibility permissions. Ensure the app prompts for these on first computer-use attempt with clear explanation.

### Acceptance Criteria (Feature-Flagged)
- [ ] `UserDefaults "epistemos.computerUse.enabled"` flag gates the feature
- [ ] Perception pipeline produces AX tree JSON from a screen capture
- [ ] GhostComputerAgent can execute a simple task (e.g., "open Safari")
- [ ] Visual verify confirms action success
- [ ] Permission prompts appear correctly

---

# P2-B: Port agent_core Features to epistemos-core

> [!NOTE]
> These run as NightBrain background jobs. Not user-visible for v1 but improve intelligence over time. Swift fallbacks already exist in `VaultLifecycleService.swift`.

### GEPA (mutation_proposer.rs → epistemos-core)

Follow `IMPLEMENTATION_PLAN_FEATURES.md` Phase 1 exactly:
1. Create `epistemos-core/src/evolution/` with `mod.rs` + `mutation_proposer.rs`
2. Adapt imports (replace `agent_core::storage::memory_classifier` with Jaccard similarity)
3. Add `#[derive(uniffi::Record)]` to public structs
4. Export via UDL
5. Wire `VaultLifecycleService` to call Rust FFI with Swift fallback
6. Add GEPA settings to AI Settings panel

### Hyperbolic Topology (hyperbolic_topology.rs → epistemos-core)

Follow `IMPLEMENTATION_PLAN_FEATURES.md` Phase 2:
1. Create `epistemos-core/src/topology/` with `hyperbolic.rs`
2. Implement `should_pierce_blanket()` with FEP calculation (see Part 1 paper reference: Friston 2010)
3. Export `build_vault_topology()` and `topology_to_context()` via UDL
4. Create `HyperbolicTopologyService.swift` actor
5. Wire to vault search ranking and TriageService context injection
6. Add NightBrain topology refresh job

### Neural Cache (neural_cache.rs → epistemos-core)

Follow `IMPLEMENTATION_PLAN_FEATURES.md` Phase 3:
1. Create `epistemos-core/src/cache/` with `neural.rs`
2. Port hot/warm/cold tier logic
3. Export `neural_retrieve()` and `neural_retrieve_temporal()` via UDL
4. Create `TemporalRetrievalService.swift`
5. Wire to search for "what did I work on last Tuesday?" queries
6. Integrate with BM25 index

### Verification for All Three
```bash
cd epistemos-core && cargo test evolution
cd epistemos-core && cargo test topology
cd epistemos-core && cargo test cache
bash build-epistemos-core.sh
xcodebuild build
```

---

# Deferred Items (P3/P4 — Document But Do Not Execute)

| Item | Phase | Blocker | Action |
|------|-------|---------|--------|
| ODIA Nightly Training | 16 | RunPod funds ($150-1500) | Code ready. Execute when funded. |
| Temporal Belief Tracking | 20 | Requires trained LoRA adapters | Design adapter versioning schema. Build after ODIA. |
| MoLoRA Per-App | 8 (claimed complete) | No trained adapters exist | Collect per-app trace data first via execution logger. |
| Mirror Speculative Decoding | 19 | Requires both brains operational | Implement after Brain 2 (Device Action Agent) is trained. Ref: arXiv 2510.13161v2 |
| TurboQuant (PolarQuant + QJL) | 21 | 3-6 month research effort | Ref: arXiv 2502.02617. `turbo_quant.rs` exists in instant_recall. |
| Safety Layer / Referee | 22 | Future phase | Design spec needed first. |
| CRDT Ghost-Brain | 23 | Loro compiled but no sync protocol | Design collaboration protocol. `knowledge_core/crdt.rs` is foundation. |
| R2F Unlearning + EMMET | 24 | Research phase | No code exists. Pure research. |

---

# Release Hardening Checklist (From Existing Audits)

These items from `A+_RELEASE_ROADMAP.md` and `V1_RELEASE_GATE_AUDIT.md` must also be completed:

- [ ] Exclude MOHAWK training data from bundle (47MB saved) — `project.pbxproj`
- [ ] Set `ShipGate.agentsEnabled = false` — `AppBootstrap.swift:22`
- [ ] Enable `SHIP_MODE=release` in build script — `build-rust.sh`
- [ ] Feature-flag tree-sitter parsers (keep Swift + JSON only) — `Cargo.toml`
- [ ] Create `PrivacyInfo.xcprivacy` — App Store requirement
- [ ] Populate `model_manifest.json` with all release models
- [ ] Remove dead Gemma 4 12B catalog entry
- [ ] Clean warning debt (Swift 6 sendability, Mamba chat template, CodeEdit paths)
- [ ] Run full local model release sweep with runtime evidence
- [ ] Complete OpenAI cloud validation sweep
- [ ] Manual graph feel pass (60fps pan/zoom/drag)
- [ ] Signing, notarization, packaging, artifact smoke

---

# Execution Order

```
Week 1 (P0):
  ├── P0-B: Three performance fixes (1 day)
  ├── P0-A Steps 1-2: InstantRecall FFI + Swift bridge (2 days)
  ├── P0-A Steps 3-4: Editor wiring + sidebar UI (2 days)
  └── P0-A Steps 5-6: Vault indexing + integration (1 day)

Week 2 (P1):
  ├── P1-A: Agent runtime decision + execution (1 day)
  ├── P1-B: Local model catalog fixes (2 days)
  └── P1-C: Capture pipeline UI wiring (2 days)

Week 3 (P2):
  ├── P2-A: Computer use feature-flagged wiring (3 days)
  └── P2-B: GEPA + Topology + Neural Cache ports (2 days)

Week 4 (Hardening):
  └── Release checklist items + full test sweep
```

---

*This plan covers every incomplete item from Part 1. Execute in priority order. Do not skip P0 items.*
