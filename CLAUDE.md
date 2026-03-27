# Epistemos — Engineering Bible

## Golden Rules (non-negotiable)

1. **Zero copy-paste.** If code exists, call it. If two things look similar, extract a shared function. Three similar lines is better than a premature abstraction, but four is not.
2. **Direct communication.** No wrappers around wrappers. No indirection for indirection's sake. The shortest path from intent to execution wins.
3. **Performance is architecture.** Pre-allocate buffers. Debounce hot paths. Cache expensive results. Zero per-frame allocations in render loops. No `repeatForever` animations — gate with `windowOccluded` + `reduceMotion`.
4. **Minimal fixes.** Don't refactor adjacent code. Don't add features beyond what's asked. Don't add comments to code you didn't change. A bug fix is just a bug fix.
5. **Test-first.** Write a failing test before the fix. Edge cases: empty, nil, max, unicode, concurrent, rapid toggle.
6. **Read before writing.** Never modify a file you haven't read. Understand existing code before touching it.
7. **macOS Opulent only.** Never touch `~/Epistemos-RETRO/`, `src-tauri/`, or `~/meta-analytical-pfc/` from this repo. Those are separate projects.
8. **Manual integration test every feature.** For every new feature or code addition, ALWAYS run a manual integration test: (1) Build and launch the app, (2) Exercise the specific feature through the UI in multiple ways, (3) Watch macOS Console.app logs (`log stream --predicate 'process == "Epistemos"' --level debug`) for errors/warnings/crashes, (4) Map out the call chain between UI action → state → service → result, (5) Fix any issues found in logs before considering the feature complete. This applies to ALL changes, not just test-passing.

## Architecture Overview

**Opulent Edition** = Swift + Metal + Rust FFI. macOS native. Apple Design Award quality.

```
User → SwiftUI Views → @Observable State → Services (Engine/) → Rust FFI (graph-engine/)
                                         → SwiftData (Models/)
                                         → Apple Intelligence (TriageService)
```

### Key Files (read these first for any subsystem)

| Subsystem | Start Here | Then Read |
|-----------|-----------|-----------|
| AI Pipeline | `Engine/TriageService.swift` | `Engine/PipelineService.swift`, `Engine/LLMService.swift` |
| Graph | `Graph/GraphState.swift` | `Graph/GraphStore.swift`, `Graph/GraphBuilder.swift` |
| Graph Engine (Rust) | `graph-engine/src/lib.rs` | `src/renderer.rs`, `src/physics.rs`, `src/types.rs` |
| Note Editor | `Views/Notes/ProseEditorView.swift` | `Views/Notes/ProseEditorRepresentable2.swift`, `Views/Notes/ProseTextView2.swift` |
| Note Chat | `State/NoteChatState.swift` | `Views/Notes/NoteChatSidebar.swift`, `Views/Notes/NoteWindowManager.swift` |
| Note Windows | `Views/Notes/NoteWindowManager.swift` | `Views/Notes/NotesSidebar.swift` |
| Graph Overlay | `Views/Graph/HologramController.swift` | `Views/Graph/HologramOverlay.swift`, `Views/Graph/MetalGraphView.swift` |
| Environment | `App/AppEnvironment.swift` | `App/AppBootstrap.swift`, `App/EpistemosApp.swift` |
| Vault Sync | `Sync/VaultSyncService.swift` | `Sync/NoteFileStorage.swift` |
| Models | `Models/SDPage.swift` | `Models/SDGraphNode.swift`, `Models/GraphTypes.swift` |

### Bible & State Files

- `docs/future-work-audit.md` — THE BIBLE. 21 waves, 134 items. All planned work.
- `docs/audit-progress.md` — Audit state. Read this to know what's been fixed/deferred.

### Training & Model Files (READ BEFORE ANY TRAINING WORK)

- `docs/NANO-MASTER-TRAINING-GUIDE.md` — **THE training execution manual.** 5 pillars, all scripts, all hyperparameters. Ground every training decision here.
- `docs/TRAINING_GUIDE.md` — Quick-reference training guide (references Master Guide).
- `docs/INSTANT_RECALL_ARCHITECTURE.md` — Ω18-Ω21 vector memory + state injection.

### Training Research Papers (for deep context)

| Topic | Path |
|-------|------|
| Niche scripts & pipelines | `@/Users/jojo/Downloads/Legendary Nano Model...` |
| App-specific training | `@/Users/jojo/Downloads/App-Specific Training...` |
| Fine-tuning for App UI | `@/Users/jojo/Downloads/Fine-Tuning LLMs For App UI.md` |
| Knowledge fusion roadmap | `@/Users/jojo/Downloads/On-Device Knowledge Fusion Research Roadmap.md` |
| Dual-brain deep research | `@/Users/jojo/Downloads/Epistemos Omega — Dual-Brain...` |
| Master training manifesto | `@/Users/jojo/Downloads/EPISTEMOS-NANO-MASTER-TRAINING-GUIDE.md` |

### Training Non-Negotiables (from Master Guide)

1. **Deploy on MLX/Metal GPU, NOT ANE** — Mamba selective scan cannot run on ANE
2. **WSD scheduler, never cosine** — allows checkpoint reuse when new data arrives
3. **20% Epistemos app-specific data is sacred** — below 15% reflexes degrade, above 25% general capability suffers
4. **LoRA rank 16 for Nano** — not 8 (too constrained), not 32 (overfits nightly data)
5. **Never fuse adapters into base** — hot-swap via MoLoRA routing only
6. **4 layers of app self-knowledge**: Code Graph → Symbol QA → AX Atlas → Trajectories
7. **Version-triggered adapter regeneration** — every Epistemos build must refresh the adapter
8. **One variable at a time** — never change LR + data mix + rank simultaneously
9. **Mamba-2 now, Mamba-3 when tooling lands** — build with Mamba-2 (validated MOHAWK + MLX). Swap Mamba layers to Mamba-3 in Month 2-3. The 6 attention layers NEVER change — they do exact retrieval no SSM can replace. Keep layer abstraction parameterized for clean swap.

## Patterns to Follow

### Swift

- `@MainActor @Observable` for all state classes. Never `ObservableObject`.
- `withAppEnvironment(bootstrap)` for environment injection — never manual `.environment()` chains. Single source: `AppEnvironment.swift`. NoteWindowManager uses this too.
- `nonisolated(unsafe)` for NSView properties written from AppKit event handlers.
- `Task { @MainActor in }` for delayed work — never `DispatchQueue.main.asyncAfter`.
- Swift Testing framework (`@Suite` + `@Test` + `#expect`). Never XCTest.
- `guard let` / `if let` — never force unwrap (`!`).
- `do/catch` — never `try!`.
- `Int(floatValue)` traps on NaN/Infinity — always guard with `value.isFinite` first.

### Rust

- `#[repr(C)]` on all FFI structs. Match Swift layout.
- `// SAFETY:` comment required on every `unsafe` block.
- `with_capacity()` for all Vec allocations in hot paths.
- `#[test]` inline in modules or `tests/` directory.
- Zero `clone()` in render loop — borrow or use indices.

### SwiftUI + AppKit Bridge

- NSTextStorage changes go through `shouldChangeText`/`didChangeText` for undo support.
- Use `isFlushingTokens` flag to suppress binding sync during programmatic storage changes.
- Binding sync (Coordinator → SwiftUI) must be debounced (300ms) to prevent per-keystroke SwiftUI re-evaluation.
- Never call `page.loadBody()` in a SwiftUI view body — it reads from disk on every re-evaluation.

## Patterns to Avoid

- Manual `.environment()` chains — use `withAppEnvironment()`.
- `.repeatForever` animations — use `TimelineView` gated by `windowOccluded`.
- `DispatchQueue.main.asyncAfter` — use `Task.sleep`.
- `parent.text = tv.string` on every keystroke — debounce to 300ms.
- `page.needsVaultSync = true` during streaming — causes @Query refetch cascade.
- `loadBody()` in SwiftUI view body — disk read on every re-evaluation.
- `Int(Float.nan)` — traps. Always check `.isFinite` first.
- Committing without running `xcodebuild test` + `cargo test`.

## Critical Anti-Patterns (learned from real bugs)

### The Binding Cascade
Coordinator writes `parent.text` → SwiftUI `onChange` fires → sets `page.needsVaultSync = true` → `@Query` refetches → NoteTabView body re-evaluates → `loadBody()` (disk read) → `updateNSView` → text sync races with next callback. **Fix:** Debounce binding sync to 300ms. Never sync during AI streaming.

### The Zone Protection Gap
`shouldChangeTextIn` guards AI zone only during `isStreaming`. After streaming ends but before accept/discard, user edits above divider don't adjust offset → stale offset → data loss on accept. **Fix:** Guard whenever `hasDivider` is true, not just `isStreaming`.

### The Multi-Turn Double Insertion
Second query when `hasDivider` is already true — tokens appended raw without prompt header separator. **Fix:** Track `lastFlushedTurnCount`, insert header when turn count increases.

### The Environment Sync Drift
NoteWindowManager had a manual list of `.environment()` calls that drifted from `AppEnvironment.swift`. Any new state object added to AppEnvironment but not to NoteWindowManager caused runtime crashes. **Fix:** Use `withAppEnvironment(bootstrap)` everywhere. Single source of truth.

### The Unpersisted Dirty Flag
Setting `page.needsVaultSync = true` without `modelContext.save()` appears to work in memory but the `@Query(filter: #Predicate { $0.needsVaultSync == true })` in the sidebar never sees it, and `isDirtyVault` returns false after a context refresh. **Fix:** Always call `try? modelContext.save()` immediately after setting dirty flags. See `docs/bug-fixes/2026-03-03-note-saving-fix.md`.

## Service Architecture

### TriageService — AI Routing
Routes operations between local tiers. No cloud fallback.

**Current (bridge):** Qwen 3.5 4B on Metal GPU via MLX.
**Target (after MOHAWK):** Epistemos-Base 3B Mamba-2 hybrid replaces Qwen entirely.
Epistemos-Nano 1B on Metal GPU handles device actions. Qwen gets deleted.
**Critical**: Nano deploys on MLX/Metal GPU (NOT ANE). Mamba-2 selective scan cannot run on ANE.

- Apple Intelligence for the lightest rewrite / summarize / simple ask work
- Local model (currently Qwen, future Epistemos-Base) for reasoning, coding, graph analysis

Operations and their tiers:
| Operation | Complexity | Route |
|-----------|-----------|-------|
| `.rewrite` | 0.25 | Apple Intelligence when light enough, otherwise local Qwen |
| `.summarize` | 0.20 | Apple Intelligence when light enough, otherwise local Qwen |
| `.continueWriting` | 0.30 | Local Qwen |
| `.outline` | 0.40 | Local Qwen |
| `.expand` | 0.50 | Local Qwen |
| `.analyze` | 0.60 | Local Qwen |
| `.ask(query:)` | 0.20 + query complexity | Apple Intelligence when light enough, otherwise local Qwen |

### NoteChatState — Per-Note AI Chat
One instance per open note tab. Manages query → response cycle with 60ms token buffering.
- Callbacks wired by ProseEditorRepresentable2 Coordinator2: `onStreamStart`, `onTokenFlush`, `onAccept`, `onDiscard`.
- AI text lives in NSTextStorage below a `---` divider, not in a separate view.
- Accept strips divider, keeps response inline. Discard removes everything from divider onward.
- `noteBodyProvider` closure reads current body from storage (set by Coordinator).

### GraphStore — Compact Storage
Internal storage uses Int-indexed arrays for O(1) adjacency lookup:
- `_nodeIdx: [String: Int]` — node ID → stable compact index
- `_neighbors: [[Int]]` — compact adjacency lists (deduplicated)
- `_edgesOf: [[Int]]` — edge reverse index
- `_trigramIdx: [String: [Int]]` — trigram → posting list for fuzzy search
- Proxy types (`AdjacencyProxy`, `EdgesByNodeProxy`) preserve `store.adjacency[nodeId]` syntax.
- Public API unchanged: `nodes`, `edges`, `adjacency`, `edgesByNode` all work as before.

### GraphState — FFI Bridge
- `engineHandle: OpaquePointer?` — the Rust engine pointer.
- `pendingNodes` / `pendingEdges` — queue for incremental FFI updates, drained in render loop.
- `mode: .global | .page(nodeId:)` — determines graph scope.
- `buildPageSubgraph()` — extracts quotes, sources, wikilinks as ephemeral nodes.
- All mutations `@MainActor` serialized. No races.

### PhysicsCoordinator — Cross-View State
`@Observable` singleton for graph ↔ sidebar hover signaling:
- `graphHoveredNodeId: String?` — written by MetalGraphNSView on mouseMoved.
- Read by `GraphReactiveModifier` on sidebar rows for highlight effect.
- Zero cost when idle (no timers, no per-frame work).

## FFI Boundary (Swift <-> Rust)

Header: `graph-engine-bridge/graph_engine.h` (42 functions)
- All FFI calls must have nil engine guards.
- String encoding: UTF-8 both sides, validate on return.
- Memory ownership: Rust allocates, Rust frees. Swift never frees Rust memory directly.
- Node types: Note(0), Chat(1), Idea(2), Source(3), Folder(4), Quote(5), Tag(6), Block(7)
- Edge types: reference(0)..questions(11) — 12 total including semantic edges.

## Note Editor Internals

### ProseEditorRepresentable2 + ProseTextView2 (the heart of editing)
TextKit 2 editor bridge wrapping `ProseTextView2` (`NSTextView` backed by `NSTextLayoutManager`).
- **Coordinator2** owns: binding sync debounce (300ms), table alignment, AI callbacks, fold/indent helpers, and transclusion overlay coordination.
- **MarkdownContentStorage** — delegate-backed structural + inline markdown styling for the TK2 stack.
- **ProseTextView2** — NSTextView subclass with wikilink handling, AI context menu notifications, structural edit helpers, and divider protection.

### Text Flow
```
User types → ProseTextView2.didChangeText() → reparseAndInvalidate()
           → Coordinator2.textDidChange() → debounced binding sync (300ms)
           → ProseEditorView debounced disk/model save
AI streams → NoteChatState.appendStreamingText() → 60ms buffer
           → flushTokens() → onTokenFlush callback
           → Coordinator2.flushNoteChatTokens() → insert into storage
           → isFlushingTokens flag prevents binding sync cascade
```

### AI Context Menu Operations
Right-click in editor → ProseTextView2 builds menu → posts notification with operation string.
NoteTabView receives notification → `handleAIContextMenuOperation()` maps to `(NotesOperation, systemPrompt, userPrompt)` → `noteChatState.submitQuery()`.

Operations: rewrite, summarize, expand, simplify, toList, toTable, continue, outline, structure, restructure.

## View Modifiers (Theme/PhysicsModifiers.swift)

| Modifier | Purpose | Cost |
|----------|---------|------|
| `.physicsHover(.subtle/.medium/.lift)` | Scale + shadow on hover | Zero when idle |
| `.physicsPress()` | Scale down on press, spring back | Zero when idle |
| `.breathe()` | 30Hz subtle oscillation | TimelineView, gated by `windowOccluded` |
| `.springEntrance(index:)` | Staggered appear animation | One-shot |
| `.graphReactive(nodeId:)` | Highlight when graph hovers matching node | Requires `PhysicsCoordinator` in environment |
| `.glassEffect()` | macOS 26 liquid glass | System-provided |
| `.siriGlow()` | Animated border glow (streaming indicator) | Active only during streaming |

## Testing

```bash
# Swift (1403 tests, 194 suites)
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test

# Rust (549 tests)
cd graph-engine && cargo test

# Quick build check
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
```

Test file naming:
- `EpistemosTests/<System>Tests.swift` — core tests
- `EpistemosTests/<System>EdgeCaseTests.swift` — boundary + edge cases
- `EpistemosTests/<System>ComprehensiveTests.swift` — thorough coverage
- `EpistemosTests/<System>AuditTests.swift` — audit-specific tests

## Audit Status

**AUDIT COMPLETE.** Waves 1-13 fully reviewed. 16 fixes committed, 9 already implemented, 15 not-a-bug.
Remaining deferred (architecture changes, not minimal fixes):
- W7.4: Graph Store Memory — DONE (compact Int-indexed arrays)
- W13.2: Fuzzy Search Scalability — DONE (trigram index)
- W17.13: App Crashes Creating Note — needs actual crash log to reproduce

## File Layout

| Purpose | Location |
|---------|----------|
| App bootstrap + environment | `Epistemos/App/` |
| State classes (@Observable) | `Epistemos/State/` |
| Services (AI, pipeline, triage) | `Epistemos/Engine/` |
| Graph state + builder | `Epistemos/Graph/` |
| Graph engine (Rust) | `graph-engine/src/` |
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
| Omega agents | `Epistemos/Omega/Agents/` |
| Omega orchestrator | `Epistemos/Omega/Orchestrator/` |
| Omega inference | `Epistemos/Omega/Inference/` |
| Omega vision | `Epistemos/Omega/Vision/` |
| Omega distribution | `Epistemos/Omega/Distribution/` |
| Omega knowledge | `Epistemos/Omega/Knowledge/` |
| Omega views | `Epistemos/Views/Omega/` |
| MOHAWK training | `Epistemos/KnowledgeFusion/MOHAWK/` |
| ODIA traces | `Epistemos/KnowledgeFusion/SyntheticData/` |
| Reasoning loop | `Epistemos/Omega/Inference/ReasoningLoopService.swift` |
| Reasoning traces | `Epistemos/Omega/Inference/ReasoningTraceLogger.swift` |
| Instant recall arch | `docs/INSTANT_RECALL_ARCHITECTURE.md` |
| **Training master guide** | **`docs/NANO-MASTER-TRAINING-GUIDE.md`** |
| Training quick-ref | `docs/TRAINING_GUIDE.md` |
| Audit bible | `docs/future-work-audit.md` |
| Audit progress | `docs/audit-progress.md` |

## Omega Phase Roadmap

| Phase | Name | Status | Core Deliverables |
|-------|------|--------|-------------------|
| Ω10 | Bug Fixes + Wiring | ✅ Done | NotesAgent, FileAgent, logging, ConfirmationGate |
| Ω11 | Constrained Decoding | ✅ Done | LogitProcessor, mlx-swift-structured SPM |
| Ω12 | Dual-Brain Foundation | ✅ Done | DeviceAgentService, HardwareTierManager, DualBrainRouter |
| Ω13 | Computer Use Stack | ✅ Done | AX selectors, Screen2AX fusion, visual verify |
| Ω14 | Knowledge Graph Integration | ✅ Done | AgentGraphMemory, RecipeGraphSkills, GhostBrain |
| Ω15 | MOHAWK Distillation | ✅ Prep | mohawk_train.py (real training loops), RunPod automation |
| Ω16 | Training Pipeline | ✅ Prep | ODIA → TrainingScheduler wired, TraceDataMixer |
| Ω17 | App Store Distribution | ✅ Prep | AppStoreHelper, SMAppService skeleton |
| Ω18 | Instant Recall Index | 🚧 In Progress | graph-engine `usearch` HNSW live; remaining work is continuous encoding + Contextual Shadows wiring |
| Ω19 | Mamba State Injection | Planned | CoreML Mamba-2, state prefill, speculative decoding (Mirror-SD/ReDrafter 2-3x) |
| Ω20 | Personal LoRA | Planned | MambaPEFT on in/x/dt/out_proj, LOGRA data Shapley, nightly fine-tune |
| Ω21 | TurboQuant | Planned | PolarQuant + QJL residual in Rust, 3.5 bits/channel |
| Ω22 | Safety Layer | Planned | Referee Model (INT4 1B on ANE), Seatbelt sandboxing, zero-trust MCP gateway |
| Ω23 | CRDT Ghost-Brain | Planned | Dual-buffer co-authoring (user buf + shadow buf), ghost text via CRDT convergence |
| Ω24 | Advanced Reasoning | Stretch | KG-Trie graph-constrained reasoning, R2F selective unlearning, EMMET fact editing |

### Stretch Goals (from research, not scheduled)

- **Voyager-style skill caching**: Hash successful DAGs as immutable recipes (partial in RecipeGraphSkills)
- **Mirror-SD speculative decoding**: Nano drafts, Base verifies — breaks serial barrier (Ω19)
- **LOGRA In-Run Data Shapley**: Prune negative-value training examples automatically (Ω20)
- **HW-NAS**: Multi-objective Pareto optimization for M-series AMX/UMA alignment
- **Neural Cloud shader**: Metal force-directed graph with pulsing nodes showing agent activity
- **Codex 5.4 auditor workflow**: Deterministic quality anchors via Plan.md/Implement.md cycle
