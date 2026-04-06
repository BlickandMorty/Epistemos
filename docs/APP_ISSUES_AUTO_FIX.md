# Epistemos — Runtime Issues for Auto-Fix

**Purpose:** Living document of runtime issues the app has encountered. AI agents (Claude Code, Codex, etc.) should read this on every session start, attempt to diagnose and fix any open issues when safe to do so, and update this doc when an issue is resolved or new information is gathered.

## How to Use This Doc

**On session start:**
1. Read this entire file.
2. For each `Status: Open` issue, decide if it's safe to investigate now (i.e., it doesn't conflict with the user's current request).
3. If you can fix an open issue WITHOUT blocking the user's current task, do it opportunistically and update the entry.
4. NEVER fix an issue if the user hasn't explicitly authorized destructive changes (deleting files, modifying shared state, force-push, etc.).

**When adding a new issue:**
- Copy the template below
- Fill in the symptom exactly as observed (paste logs/stack traces verbatim)
- Mark `Suspected Cause` as a hypothesis, not fact
- Mark `Status: Open`
- Add `Priority: P0/P1/P2/P3` (P0 = crash, P1 = data loss risk, P2 = functional bug, P3 = cosmetic)

**When updating:**
- Append a dated entry to `Investigation Log`
- Change `Status` when resolved: `Open` → `Investigating` → `Patched` → `Verified Fixed`
- Never delete old entries — the history is the audit trail

---

## Issue Template

```
### ISSUE-YYYY-MM-DD-###: Short Title

Status: Open | Investigating | Patched | Verified Fixed
Priority: P0 | P1 | P2 | P3
First Observed: YYYY-MM-DD
Affected Version: git SHA or tag

Symptom:
<exact log output / stack trace / reproduction steps>

Suspected Cause:
<hypothesis with references to file:line>

Safe Auto-Fix Attempts (no user approval needed):
- Read related files
- Add `#[cfg(debug_assertions)]` logging
- Write a failing test that reproduces the issue

Destructive Fixes (require user approval):
- Modifying FFI signatures
- Changing allocator patterns
- Removing/rewriting code paths

Investigation Log:
- YYYY-MM-DD: <what was tried, what was learned>
```

---

## Open Issues

### ISSUE-2026-04-04-001: Vec Drop malloc error during app lifecycle transition

Status: Open
Priority: P0 (crash, but during teardown, not blocking normal usage)
First Observed: 2026-04-04
Affected Version: branch `codex/post-audit-feature-work`

Symptom:
```
Window occlusion changed: visible=false
[Diagnostics] lifecycle_event name="app_resigned_active"
Epistemos(46884,0x16bcff000) malloc: *** error for object 0xb24e6c000: pointer being freed was not allocated
Epistemos(46884,0x16bcff000) malloc: *** set a breakpoint in malloc_error_break to debug

Stack frame 6: _$LT$alloc..raw_vec..RawVec$LT$T$C$A$GT$$u20$as$u20$core..ops..drop..Drop$GT$::drop
Debug session ended with code 9: killed
```

Reproduction: Launch app, let it load fully (vault import, graph build), then hide/minimize the window OR let the app become inactive (click another window). Crash happens during the lifecycle transition.

Suspected Cause:
A Rust `Vec` is being dropped with a backing pointer that wasn't allocated by the standard allocator. Most likely culprits:
- `graph-engine/src/lib.rs:2001` — `Vec::from_raw_parts(list.candidates, list.count as usize, list.count as usize)` — if Swift-side caller passes a ptr/len/cap triple that doesn't match the original allocation exactly, this crashes.
- `graph-engine/src/lib.rs:2327` — `Vec::from_raw_parts(buffer.ptr, buffer.len as usize, buffer.capacity as usize)` — same risk.
- Any Swift code that constructs a buffer, passes it to Rust expecting reclamation, but mismatches the allocator.

Why lifecycle transition triggers it:
When the window hides or app resigns active, teardown code runs (graph overlay soft-hide, MLX idle budget switch, wind particle cleanup). One of those paths drops a Vec that was constructed from FFI raw parts.

Safe Auto-Fix Attempts (no user approval needed):
- Audit both `Vec::from_raw_parts` call sites for ptr/len/cap consistency
- Add `#[cfg(debug_assertions)]` assertions: check ptr alignment, non-null, len <= cap
- Grep for matching Swift allocator calls that construct those buffers
- Write a debug-only panic with stack trace when `Vec::from_raw_parts` is called with suspicious args

Destructive Fixes (require user approval):
- Replacing `Vec::from_raw_parts` with `unsafe { std::slice::from_raw_parts }.to_vec()` (copies but safer)
- Changing the FFI contract to return ownership differently
- Adding an `AllocatedFromRust` marker type to prevent mismatched reclamation

Investigation Log:
- 2026-04-04: Identified from user's debug log. Ruled out recent changes (GPU N-body double-buffering, color conversions, folder depth computation, proactive compaction) — none of these allocate Vecs on the code paths executed by a 1127-node graph. Marked as pre-existing FFI boundary issue.

---

### ISSUE-2026-04-06-001: Pinned Inspector Panels Freeze When No Node Selected

Status: Investigating
Priority: P2
First Observed: 2026-04-06
Affected Version: main @ cdd931e4+

Symptom:
When user pins an inspector to a node, then deselects (clicks background), the pinned
panel freezes in place and no longer follows its node as physics settles or camera moves.
Panel DOES follow when a node is selected (any node, not just the pinned one).

Suspected Cause:
The 30fps RunLoop timer (`pinnedPanelTimer`) calls `updatePinnedInspectorPositions()` which
queries `graph_engine_node_screen_pos(engineHandle, nodeId, &posBuf)`. The function reads
stored world positions + camera state — should work even when engine is idle.

The real issue is likely the RENDER LOOP being idle. When nothing is selected and physics
has settled, `graph_engine_render()` returns 0. Even though `needsRender` stays true for
pinned panels (MetalGraphView.swift:1380), the Rust engine's internal idle skip
(engine.rs:854 `idle_frame_count > 3 → return 0`) means the engine stops calling
`renderer.draw()`. The camera animation (lerp toward target) stops updating because
`update_camera()` only runs inside render(). So `node_screen_pos()` returns coordinates
based on a stale camera state.

The fix: either (a) force the engine to stay "alive" when pinned panels exist (add a flag
the engine checks in the idle skip), or (b) compute screen positions entirely from known
camera state on the Swift side without going through Rust.

Relevant files:
- HologramOverlay.swift:985 (updatePinnedInspectorPositions)
- HologramOverlay.swift:1024 (startPinnedPanelTimer)
- MetalGraphView.swift:1380 (needsRender = result != 0 || hasPinnedPanels)
- engine.rs:850 (idle_frame_count skip — returns 0 before draw)
- engine.rs:947 (node_screen_pos — reads renderer.camera_offset/zoom)
- engine.rs:830 (update_camera called inside render path)

Investigation Log:
- 2026-04-06: Timer confirmed running via code inspection. engineHandle confirmed non-nil.
  Root cause narrowed to Rust idle skip preventing camera state refresh. The timer queries
  node_screen_pos which uses renderer.camera_offset/zoom — these stop updating when the
  engine is idle because update_camera() is inside the render path that gets skipped.

---

### ISSUE-2026-04-06-002: Beach Ball Spinner During Graph Interaction

Status: Investigating
Priority: P1
First Observed: 2026-04-06
Affected Version: main @ 025db832

Symptom:
macOS spinning beach ball appears during certain graph interactions, indicating the main
thread is blocked for >2 seconds. Happens sporadically, especially after graph has been
open for a while.

Suspected Cause:
Two main-thread blocking operations:

1. `graph_engine_commit()` runs a synchronous pre-settle physics loop on the main thread.
   For 1131 nodes: up to 120 ticks with 16ms budget. NOT likely the beach ball cause alone
   (16ms is one frame, not 2 seconds).

2. `graph_engine_recompute_semantic_neighbors` — runs KNN cosine similarity across all
   embeddings. With 1131 nodes and 768-dim embeddings, that's O(n^2 * dim) ≈ 1 billion
   float ops. This was recently moved to MainActor dispatch (commit 025db832) to fix a
   data race, which means it now blocks the main thread during the entire computation.
   THIS IS THE BEACH BALL.

Fix approach: Split into compute (background) + swap (main, instant). Rust computes the
new Vec<(u32,u32,f32)> on the calling thread, then uses a Mutex or atomic swap to install
it. The render loop reads through the Mutex. No main-thread blocking, no data race.

Relevant files:
- EmbeddingService.swift:215 (call site — moved to MainActor.run)
- lib.rs:1640 (graph_engine_recompute_semantic_neighbors)
- engine.rs (engine.semantic_neighbors assignment)
- embedding.rs (all_knn_pairs — the O(n^2) computation)
- engine.rs:commit() lines 421-439 (pre-settle loop)

Investigation Log:
- 2026-04-06: Traced beach ball to commit 025db832 which moved recompute_semantic_neighbors
  to MainActor. The KNN computation is O(n^2*dim) — for 1131 nodes * 768 dims this is
  ~1 billion float ops, easily >2 seconds on main thread. Need to split compute from swap.

---

## Resolved Issues

_(none yet — move entries here as they are Verified Fixed)_

---

## Standing Checks (run on every session start)

These are sanity checks to run proactively:

1. **FFI allocator consistency**: grep for `from_raw_parts` + `mem::forget` pairs, verify they match
2. **try? in durable paths**: `grep -rn 'try?' Epistemos/Sync/ Epistemos/Bridge/ | grep -v test | wc -l` → should be 0
3. **Force unwraps outside tests**: `grep -rn 'try!\|\.unwrap()' Epistemos/ --include='*.swift' | grep -v Test | wc -l` → should be 0
4. **ObservableObject usage**: `grep -rn 'ObservableObject' Epistemos/ --include='*.swift' | grep -v test | grep -v comment | wc -l` → should be 0 (we use `@Observable`)
5. **UserDefaults API keys**: `grep -rn 'UserDefaults.*[Aa]pi[Kk]ey' Epistemos/ --include='*.swift' | wc -l` → should be 0 (Keychain only)
6. **Rust test count**: `cargo test --manifest-path graph-engine/Cargo.toml 2>&1 | grep "test result"` — should show `2451 passed` (or the current expected count)

If any of these regress, add a new issue entry.
