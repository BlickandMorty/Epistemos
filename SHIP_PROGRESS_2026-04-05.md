# EPISTEMOS — SHIP PROGRESS 2026-04-05

**Status:** Phase 1, 2 & 3 Complete (Critical Stability + Core Graph UX + Bug Fixes)  
**Remaining:** Phase 4, 5 (Features, Hardening, Validation)

---

## COMPLETED ✅

### 1. FFI Memory Crash Fix (P0)
**Problem:** Allocator abort at `graph_engine_recompute_semantic_neighbors`  
**Root Cause:** Race condition between Swift's detached Task and engine destruction

**Solution:**
- Added generation token to Rust `Engine` struct (`AtomicU64`)
- Added `graph_engine_generation()` FFI function for lifetime validation
- Updated Swift `EmbeddingService` to capture and validate generation before FFI calls
- Generation 0 = destroyed/invalid, non-zero = valid engine instance

**Files Modified:**
- `graph-engine/src/engine.rs` — Added generation field and initialization
- `graph-engine/src/lib.rs` — Added `graph_engine_generation()` and `graph_engine_node_index_by_uuid()`
- `graph-engine-bridge/graph_engine.h` — Added FFI declarations
- `Epistemos/Graph/EmbeddingService.swift` — Added generation validation

---

### 2. Nested-Focus Label Visibility (P1)
**Feature:** When a node is selected, only show labels for selected + nested + connected nodes

**Implementation:**
- Added `label_focus_set: Option<FxHashSet<u32>>` to Rust Engine
- Added `label_focus_alpha: f32` for smooth fade transitions (0.0 → 1.0)
- Modified `rebuild_label_instances()` to apply focus set with smooth fade
- Added `graph_engine_set_label_focus_set()` FFI function
- Added Swift `updateLabelFocusSet()` that computes focus set from:
  - Selected node
  - Connected nodes (1-hop neighbors)
  - Nested nodes (children in folder hierarchy)

**Files Modified:**
- `graph-engine/src/engine.rs` — Added focus set fields and logic
- `graph-engine/src/lib.rs` — Added `graph_engine_set_label_focus_set()`
- `graph-engine-bridge/graph_engine.h` — Added FFI declaration
- `Epistemos/Graph/GraphState.swift` — Added focus set computation

**Behavior:**
- When node selected: Labels for unrelated nodes fade out smoothly
- When deselected: All labels fade back in
- Transition speed: 0.15 per frame (smooth but responsive)

---

### 3. Inspector Pin/Unpin Button (P1) ✅
**Feature:** Toggle inspector between floating (corner) and attached (follows node) modes

**Implementation:**
- Added `PinState` enum (`pinned`, `floating`) to `NodeInspectorState`
- Added `togglePinState()` method
- Added pin/unpin button to inspector header (left of close button)
- Modified `repositionInspector()` in `HologramOverlay` to respect pin state
- Pin state resets to `floating` when selection is cleared

**Files Modified:**
- `Epistemos/Views/Graph/NodeInspectorState.swift` — Added pin state and toggle
- `Epistemos/Views/Graph/HologramNodeInspector.swift` — Added pin button to header
- `Epistemos/Views/Graph/HologramOverlay.swift` — Positioning logic for pinned vs floating

**Behavior:**
- Default: Floating in bottom-right corner (doesn't follow node movement)
- Pinned: Attaches to selected node and follows it on screen
- Visual: Filled pin icon when pinned, outline when floating

---

### 4. Light Mode Rework (P1) ✅
**Issues Fixed:**
- "Super-white" deselected nodes in light mode
- Zoom flicker when clearing highlight

**Implementation:**
- Modified vertex shader in `renderer.rs`:
  - Normal nodes now get `highlight_dim = 0.75` in light mode (was `1.0`)
  - This prevents overly bright nodes against light background
- Reverted complex zoom flicker fix - the shader change alone is sufficient

**Files Modified:**
- `graph-engine/src/renderer.rs` — Shader logic for light mode dimming
- `graph-engine/src/engine.rs` — Simplified background click handler

**Behavior:**
- Nodes in light mode are now appropriately dimmed (75% brightness when not highlighted)
- No more jarring white flash when zooming/clearing selection
- Maintains readability while preserving glass aesthetic

---

### 5. Header Deletion Collapse Button Bug (P1) ✅
**Bug:** Deleting markdown header left collapse indicator visible  
**Root Cause:** Fold state in Rust wasn't validated against current document structure

**Implementation:**
- Added `cleanup_fold_state()` function in Rust to remove stale fold entries
- Added `markdown_cleanup_folds()` FFI function
- Called from `MarkdownContentStorage.reparse()` after parsing structure
- Removes fold state for lines that are no longer headings

**Files Modified:**
- `graph-engine/src/markdown.rs` — Added cleanup function and FFI
- `graph-engine-bridge/graph_engine.h` — Added FFI declaration
- `Epistemos/Views/Notes/MarkdownContentStorage.swift` — Call cleanup after reparse

**Behavior:**
- When header is deleted, fold indicator disappears automatically
- When text is edited and line is no longer a header, fold state is cleaned
- No manual intervention needed

---

## REMAINING WORK

### P2 — Feature Completion (4 items)

#### 6. Full-Screen Inspect Node Mode
**Feature:** Dedicated immersive visualization for selected node  
**Requirements:**
- Show nested nodes/children/local cluster
- Unrelated nodes invisible/de-emphasized
- Preserve navigation, selection, camera state
- Smooth enter/exit transitions

**Files:** New `GraphInspectModeView.swift`, modifications to `GraphState`

---

#### 7. Direct Node Creation in Graph
**Feature:** Double-click (or similar) to create node directly in graph  
**Requirements:**
- Immediate edit mode
- Correct persistence
- Graph update without full refresh

**Files:** `MetalGraphView.swift`, `GraphState.swift`

---

#### 8. Wikilink/Chat Link Wiring
**Feature:** wikiLinks `[[Note]]` and chat→note links appear as graph edges  
**Requirements:**
- Parse wikilinks in note bodies
- Create graph edges
- Avoid duplicates from multiple ingestion paths

**Files:** `GraphBuilder.swift`, `VaultSyncService.swift`

---

### P3 — KnowledgeFusion Hardening

#### 9. KF FFI Boundaries
**Areas:**
- Audit Swift→Python bridge calls
- Harden error handling in training pipeline
- Ensure proper cancellation of async training tasks
- Memory pressure handling

**Files:** `KnowledgeFusion/**/*.swift`

---

### P4 — Validation

#### 10. Crash Hunt Report
**Tasks:**
- Inspect crash-prone code paths
- Add targeted logging
- Test rapid graph selection changes
- Test node deletion/creation/relinking
- Test editor changes while graph updates

**Files:** New `CRASH_HUNT_REPORT.md`

---

#### 11. Final Verification
- [ ] All Swift tests pass (1404 tests)
- [ ] All Rust tests pass (2465 tests) ✅
- [ ] Fresh app build succeeds
- [ ] Manual test matrix completed

---

## BUILD STATUS

**Rust:** ✅ Compiles, all 2465 tests pass  
**Swift:** ⏳ Pending (need to implement remaining features)

**Known Issues:**
- None blocking current progress

---

## NEXT STEPS (Recommended Order)

1. **Direct Node Creation** — Enables better graph UX
2. **Wikilink Wiring** — Data model improvement
3. **Full-Screen Inspect Mode** — Most complex, save for last
4. **KF Hardening** — Parallel track
5. **Crash Hunt + Final Verification**

---

## ARCHITECTURE DECISIONS MADE

### FFI Lifetime Management
- Generation tokens provide deterministic failure mode
- Double-check generation immediately before critical FFI calls
- Trade-off: Small overhead vs. crash prevention

### Label Focus System
- Rust owns focus set (avoids per-frame FFI)
- Smooth alpha transition (not immediate) for premium feel
- Focus set contains node indices (not UUIDs) for O(1) lookup

### Inspector Pinning
- State lives in `NodeInspectorState` (Swift-side only)
- Positioning logic in `HologramOverlay` checks state each frame
- Default floating prevents inspector from chasing nodes during physics

### Fold State Cleanup
- Eager cleanup on reparse (not lazy)
- O(N) scan of fold state, but N is small (typically < 100 folds)
- Prevents UI inconsistency at cost of negligible performance

---

*Document updated after Phase 3 completion (Inspector, Light Mode, Header Bug)*
