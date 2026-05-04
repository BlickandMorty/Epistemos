# EPISTEMOS — SHIP SCOPE V1
**Date:** 2026-04-05  
**Status:** Active Implementation  
**Goal:** Ship-hardened release with core graph UX fixes

---

## IN SCOPE (Must Complete)

### P0 — Critical Stability
| # | Item | Files | Status |
|---|------|-------|--------|
| 1 | **FFI Memory Crash Fix** | `EmbeddingService.swift:215`, `graph-engine/src/lib.rs` | Pending |
|   | Fix allocator abort at `graph_engine_recompute_semantic_neighbors` | | |
|   | Audit ownership: who allocates, who frees, who owns after handoff | | |

### P1 — Core Graph UX
| # | Item | Files | Status |
|---|------|-------|--------|
| 2 | **Nested-Focus Label Visibility** | `GraphState.swift`, `MetalGraphView.swift`, Rust renderer | Pending |
|   | Selected folder node → show its labels + nested content labels | | |
|   | Show connected/linked nodes (wikiLinks, chat→note links) | | |
|   | All other nodes: hide labels with smooth fade | | |
|   | Deselect → restore all labels | | |
| 3 | **Inspector Pin/Unpin** | `HologramNodeInspector.swift`, `NodeInspectorState.swift` | Pending |
|   | Add pin button to inspector panel | | |
|   | Unpinned (default): float in right corner, not attached to node | | |
|   | Pinned: attach to selected node (current behavior) | | |
| 4 | **Light Mode Rework** | `EpistemosTheme.swift`, `MetalGraphView.swift`, Rust renderer | Pending |
|   | "Dark mode without darkening" — pure glass aesthetic | | |
|   | Darker nodes in light mode (inverse of dark mode) | | |
|   | Fix zoom flicker | | |
|   | Fix deselected nodes turning super-white | | |
| 5 | **Header Deletion Bug** | `NoteTableOfContents.swift` or related editor files | Pending |
|   | Fix collapse button remaining after header deletion | | |

### P2 — Feature Completion
| # | Item | Files | Status |
|---|------|-------|--------|
| 6 | **Full-Screen Inspect Node Mode** | New: `GraphInspectModeView.swift` | Pending |
|   | Dedicated immersive visualization for selected node | | |
|   | Show nested nodes/children/local cluster | | |
|   | Unrelated nodes invisible/de-emphasized | | |
|   | Preserve navigation, selection, camera state | | |
| 7 | **Direct Node Creation in Graph** | `MetalGraphView.swift`, `GraphState.swift` | Pending |
|   | Double-click (or similar) to add node | | |
|   | Immediate edit mode | | |
|   | Correct persistence and graph update | | |
| 8 | **Wikilink/Chat Link Wiring** | `GraphBuilder.swift`, `VaultSyncService.swift` | Pending |
|   | wikiLinks `[[Note]]` → graph edges | | |
|   | Chat→note links → graph edges | | |
|   | Avoid duplicate edges | | |

### P3 — KnowledgeFusion Hardening
| # | Item | Files | Status |
|---|------|-------|--------|
| 9 | **KF FFI Boundaries** | `KnowledgeFusion/**/*.swift` | Pending |
|   | Audit all Swift→Python bridge calls | | |
|   | Harden error handling in training pipeline | | |
|   | Ensure proper cancellation of async training tasks | | |
|   | Memory pressure handling | | |

---

## EXPLICITLY OUT OF SCOPE

| Item | Reason |
|------|--------|
| Agent system changes | User confirmed: leave as-is, do not cut/hide |
| Custom 1B base model | Deferred per release decision |
| MOHAWK distillation | Deferred |
| Mamba-2 hybrid | Deferred |
| Explorer mode (Bevy) | Design approved, implementation deferred |
| 3D graph/visual innovations | Post-release |
| Mind map layout modes | Post-release |
| Windows port | Separate project (Epistemos-RETRO) |

---

## DEFERRED TRACKS (Documented for Post-Release)

### Baymax SDK Research
- **Status:** Skip for now
- **Reason:** Zero references in repo, unclear what this refers to
- **Action:** User to clarify if needed post-release

### Agentic Research Track
- **Status:** Leave as-is
- **Files:** `Omega/`, `Agent/`, `KnowledgeFusion/Autoresearch/`
- **Action:** Continue in parallel non-blocking track post-release

### Model Research Track
- **Status:** Qwen 3.5 is production model
- **Action:** Track GPT-OSS, MLX improvements for future integration

---

## IMPLEMENTATION ORDER

```
Phase 1: Critical Stability
  └── 1. FFI crash fix (audit + fix)

Phase 2: Core Graph UX
  ├── 2. Nested-focus label visibility
  ├── 3. Inspector pin/unpin
  ├── 4. Light mode rework
  └── 5. Header deletion bug

Phase 3: Feature Completion
  ├── 6. Full-screen inspect mode
  ├── 7. Direct node creation
  └── 8. Wikilink wiring

Phase 4: Hardening
  └── 9. KnowledgeFusion hardening

Phase 5: Validation
  └── Build, test, crash hunt
```

---

## SUCCESS CRITERIA

- [ ] No allocator aborts in FFI boundary
- [ ] Graph labels show/hide smoothly based on selection
- [ ] Inspector pins/unpins without layout corruption
- [ ] Light mode is usable (glass aesthetic, proper contrast)
- [ ] Header deletion clears collapse button immediately
- [ ] Inspect mode enters/exits without state corruption
- [ ] Nodes can be created directly in graph
- [ ] wikiLinks appear as graph edges
- [ ] All Swift tests pass
- [ ] All Rust tests pass
- [ ] Fresh app build succeeds and launches

---

## RISK REGISTER

| Risk | Mitigation |
|------|------------|
| FFI fix breaks existing embedding flow | Comprehensive testing, gradual rollout |
| Label visibility changes hurt performance | Benchmark with large graphs |
| Light mode rework introduces contrast issues | User testing, iterative refinement |
| Inspect mode adds complexity | Thorough state preservation testing |
