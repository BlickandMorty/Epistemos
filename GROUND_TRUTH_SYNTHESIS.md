# Epistemos — Ground Truth Synthesis
## Reconciling Kimi, Claude & Gemini Audits

**Date**: 2026-04-07  
**Status**: MUCH closer to release-ready than initially reported

---

## What Kimi Got Wrong

| Claim | Reality | Source |
|-------|---------|--------|
| "graph-engine.a is 865MB" | **61MB** actual | `ls -lh target/release/libgraph_engine.a` |
| "Semaphore value: 3 (triple-buffer)" | **value: 2** (double-buffer) | `MetalGraphView.swift:436` |
| "maximumDrawableCount = 3" | **= 2** | `MetalGraphView.swift:579` |
| "Missing -Os, LTO" | **Already set** | `project.pbxproj: DEAD_CODE_STRIPPING=YES, LLVM_LTO=YES` |
| "7 observers not cleaned up" | **4 observers, all cleaned** | `ProseEditorRepresentable2.swift:101-175, 765-775` |
| "Agent mode routes to dead code" | **Fixed** — routes to `chat.submitQuery()` | `ChatState.swift:437-445` |
| "Task.yield spin loops" | **Fixed** — uses `Task.sleep(for: .seconds(30))` | `AppCoordinator.swift:273` |
| "Cargo.toml needs opt-level=s" | **Already opt-level=z** (more aggressive) | `Cargo.toml:44` |

**Verdict**: Kimi's audit was based on stale information and incorrect file states.

---

## What Claude Got Right

1. **Semaphore already value: 2** ✅
2. **Xcode flags already optimized** ✅
3. **Cargo.toml already aggressive** ✅
4. **4 observers cleaned properly** ✅
5. **Agent routing fixed** ✅

**Claude's 3 Real P0 Blockers**:
1. `pushBlockEmbeddings` FFI without MainActor — **PARTIALLY CORRECT** (EmbeddingService.swift does use MainActor, but FFI call blocks main thread)
2. `runAgentSession` stub needs graceful fallback — **CONFIRMED**
3. **47MB MOHAWK training data** — **NOT VERIFIED** (need to locate)

---

## What Gemini Found

1. **Binding Cascade** — AI streaming triggers `@Query` refetches — **CONFIRMED RISK**
2. **FFI Pointer Crash** — `graph_engine_recompute_semantic_neighbors` async without actor — **CONFIRMED** (EmbeddingService.swift:223)
3. **Metal Semaphore Block** — Already value:2, but **framePending atomic + CVDisplayLink on main** causes stutter — **PARTIALLY CORRECT**
4. **Empty Polling Vectors** — Only 2 Task.yield instances, controlled — **NOT CRITICAL**

---

## The REAL Current State

### Binary Sizes (Ground Truth)

```
61M  graph-engine/target/release/libgraph_engine.a
38M  build-rust/libepistemos_core.dylib
11M  build-rust/libomega_mcp.dylib
2.4M build-rust/libomega_ax.dylib
----
~112MB total Rust binaries (not 1.2GB!)
```

**Current app bundle estimate**: ~150-200MB (not 1.2GB)

---

### What Actually Needs Fixing

#### 🔴 P0: Release Blockers

| Issue | Location | Fix |
|-------|----------|-----|
| **runAgentSession stub** | `StreamingDelegate.swift:72` | Wire to LocalAgentLoop or remove |
| **SHIP_MODE** | `build-rust.sh` | Set env var to skip omega-mcp/omega-ax/epistemos-core |
| **ShipGate.agentsEnabled** | `AppBootstrap.swift:22` | Toggle to `false` for release |
| **Embedding FFI on MainActor** | `EmbeddingService.swift:218-225` | Move to serial queue, not MainActor |

#### 🟡 P1: Performance Issues

| Issue | Location | Impact |
|-------|----------|--------|
| **CVDisplayLink on main thread** | `MetalGraphView.swift:692` | Graph stutter during interaction |
| **Binding cascade on AI streaming** | `NoteChatState→SwiftUI` | @Query refetch every token batch |
| **Synchronous vault context** | `ChatCoordinator.swift:161-217` | Blocks UI on large vaults |

#### 🟢 P2: Polish

| Issue | Location | Action |
|-------|----------|--------|
| **Feature-flag tree-sitter parsers** | `Cargo.toml:29-40` | Reduce 61MB → ~20MB if only Swift/JSON kept |
| **Exclude Omega stubs from build** | `project.pbxproj` | 43 files, 7,874 lines — dead code |
| **Find and remove 47MB MOHAWK data** | Unknown location | Investigate |

---

## Detailed Sector Analysis (Ground Truth)

### Sector 1: Graph Engine & Rendering — Grade: A-

**MetalGraphView.swift:**
- ✅ Double-buffered (semaphore value: 2)
- ✅ maximumDrawableCount = 2
- ⚠️ CVDisplayLink callback runs on main thread (stutter risk)
- ✅ Frame coalescing with Atomic<Bool> prevents pile-up

**Fix needed**: Move render to background thread.

### Sector 2: Embedding Service — Grade: B

**EmbeddingService.swift:**
- ✅ Embeddings computed on detached Task (background)
- ⚠️ FFI call `graph_engine_recompute_semantic_neighbors` on MainActor (blocks UI)
- ✅ Safety comment explains rationale

**Fix needed**: Move FFI call to serial queue, not MainActor.

### Sector 3: Agent Systems — Grade: C

**4 Systems Confirmed:**

| System | Location | Status | Action |
|--------|----------|--------|--------|
| OrchestratorState | `Omega/Orchestrator/` | Dead stub | Delete |
| LocalAgentLoop | `LocalAgent/` | Working (local only) | Keep, wire for local agent mode |
| AgentViewModel | `Agent/`, `ViewModels/` | Working (cloud) | Keep for cloud mode |
| Rust agent_core | `ChatCoordinator:371` | Stubbed | Remove or implement |

**runAgentSession stub:**
```swift
// StreamingDelegate.swift:72
func runAgentSession(...) async throws -> AgentResultFFI {
    throw AgentRuntimeBridgeError.bindingsUnavailable  // STUB!
}
```

**Fix needed**: Route cloud agent queries through AgentViewModel (Hermes) until Rust agent_core ready.

### Sector 4: Editor — Grade: B+

**ProseEditorRepresentable2.swift:**
- ✅ 4 observers added
- ✅ 4 observers removed in `handleDismantle()`
- ✅ 300ms debounce on binding sync
- ✅ `isFlushingTokens` flag prevents cascade during AI streaming

**Risk**: Binding cascade still possible if debounce fails.

### Sector 5: Chat & Routing — Grade: B

**ChatState.swift:**
- ✅ `.agent` mode now routes to `chat.submitQuery()` (fixed!)
- ⚠️ `ChatCoordinator.runRustAgentPath()` always fails (calls stub)

### Sector 6: Build System — Grade: B

**build-rust.sh:**
- ✅ Supports SHIP_MODE environment variable
- ✅ Cargo.toml optimized (opt-level=z, lto=true, strip=symbols)
- ⚠️ SHIP_MODE not set in Xcode scheme by default

---

## Definitive Fix List for Claude Code

### Week 1: Release Blockers

```bash
# 1. Enable SHIP_MODE in Xcode scheme
# Add to Build > Pre-actions: export SHIP_MODE=release

# 2. Toggle ShipGate for release
# AppBootstrap.swift:22 — change to false

# 3. Fix runAgentSession stub
# Option A: Wire to LocalAgentLoop (fastest)
# Option B: Route to AgentViewModel (cloud)
# Option C: Remove entirely

# 4. Fix EmbeddingService FFI blocking
# EmbeddingService.swift:218-225 — use serial queue instead of MainActor
```

### Week 2: Performance

```bash
# 1. Move CVDisplayLink to background thread
# MetalGraphView.swift:692

# 2. Add @Query throttling for AI streaming
# NoteChatState or SwiftData layer

# 3. Async vault context building
# ChatCoordinator.swift:161-217
```

### Week 3: Size Optimization

```bash
# 1. Feature-flag tree-sitter parsers
# Cargo.toml: only include Swift, JSON for v1

# 2. Exclude Omega folder from build
# project.pbxproj: remove Epistemos/Omega/** references

# 3. Find and remove 47MB MOHAWK data
# Search for .bin, .onnx, .mlmodelc files
```

---

## Final Grades (Ground Truth)

| Sector | Grade | Status |
|--------|-------|--------|
| Graph Engine | A- | Production-ready, minor stutter fix needed |
| Editor | B+ | Solid, observer cleanup verified |
| Embedding | B | Background compute good, FFI placement wrong |
| Agent Systems | C | Fragmented but functional stubs exist |
| Chat/Routing | B | Agent mode fixed, cloud path stubbed |
| Build System | B | Optimized flags, needs SHIP_MODE activation |
| FFI Safety | B | MainActor serialization good, placement wrong |

**Overall**: App is **much closer to release** than initial audit suggested. Main blockers are:
1. ShipGate toggle
2. SHIP_MODE activation
3. runAgentSession stub removal
4. Embedding FFI queue fix

---

## Files to Modify

| File | Lines | Change |
|------|-------|--------|
| `AppBootstrap.swift:22` | 1 | `agentsEnabled = false` |
| `StreamingDelegate.swift:72` | 6 | Wire to LocalAgentLoop or remove |
| `EmbeddingService.swift:218` | 8 | Serial queue instead of MainActor |
| `MetalGraphView.swift:692` | 10 | Background render thread |
| `Cargo.toml:29-40` | 12 | Feature flags for parsers |
| `project.pbxproj` | - | Exclude Omega/, add SHIP_MODE |

**Total lines to change**: ~40 lines

---

*This synthesis reconciles the three audits and provides ground-truth based on actual file contents, not stale information.*
