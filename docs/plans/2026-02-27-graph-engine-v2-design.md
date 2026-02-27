# Graph Engine V2: Cluster Physics, Labels, Attractor, Performance

**Date:** 2026-02-27
**Status:** Approved

---

## 1. Cluster Physics + Center Gravity

### Cluster Detection
- Louvain community detection in Rust (`forces.rs`), runs once per `commit()`
- Assigns `cluster_id: u32` to each node
- O(n + m) per pass, converges in 2-3 passes

### Cluster Force (new force in simulation loop)
- Each cluster gets a centroid (mean position of members)
- **Intra-cluster attraction**: nodes pull toward their cluster centroid → "bubble" effect
- **Inter-cluster repulsion**: cluster centroids repel each other → separates bubbles
- Tunable: `cluster_strength` (0–1, default 0.3)

### Center Gravity Enhancement
- Add `center_mode`: attract (current), repel (anti-gravity), off
- Negative center_strength = repel (pushes outward from origin)
- Existing slider extended to support all three modes

### Settings UI
- "Cluster Bubbles" slider (0–1)
- "Center Mode" segmented control: Attract | Off | Repel

---

## 2. GPU Node Labels with Distance Fade

### Rendering Pipeline
- New Metal render pass after nodes (labels always on top)
- Uses existing MSDF atlas (`inter-msdf-atlas.png` + JSON)
- `GlyphInstance` structs already prepared in `msdf.rs`

### Metal Shaders
- **Vertex shader**: transforms glyph quad positions using camera uniforms
- **Fragment shader**: MSDF sampling for crisp edges at any zoom, alpha fade

### Distance-Based Fade
- `screen_radius = node.radius * camera_zoom`
- Below `fade_start` → alpha 0 (invisible)
- Above `fade_end` → alpha 1 (fully opaque)
- Smooth lerp between

### Settings
- "Label Fade Start" slider (default: 8px screen radius)
- "Label Fade End" slider (default: 20px screen radius)
- "Label Size" slider (0.5x–2x)
- "Show Labels" toggle

---

## 3. Cursor Attractor (AI + Manual)

### Attract Force (Rust)
- New force: `force_attract` — pulls subset of nodes toward target point
- Target = cursor position in world coordinates
- Non-attracted nodes unaffected
- Strength tunable, distance falloff

### FFI Bridge
- `graph_engine_set_attract_target(x, y)`
- `graph_engine_set_attracted_nodes(uuids, count)`
- `graph_engine_clear_attract()`
- `graph_engine_set_attract_strength(strength)`

### AI Mode (Swift)
- Search input in floating controls bar
- FTS5 `SearchIndexService` matches nodes by label/content
- Matching UUIDs sent to Rust
- Live updates as user types (debounced 200ms)
- AI can programmatically set the attractor term

### Manual Mode
- Toggle: all nodes attracted to cursor (gravity well)
- Or shift+click to pick specific nodes

### Settings
- Attract Strength slider (0–1)
- Concept search input field
- Mode toggle: AI / Manual / Off

---

## 4. Chat Glitch Fix

### Root Cause
- `selectNode()` sets `selectedNode` (triggers animation) but clears `summaryText = ""`
- Panel slides in empty for ~300ms
- Multiple `@Observable` property changes cascade during animation

### Fix
1. Set `isSummarizing = true` before `selectedNode` → spinner ready on animation start
2. Add placeholder state (node label + type) so panel never appears empty
3. Fix missing else branch in summary display logic
4. Use `.transaction { $0.animation = nil }` on streaming text to prevent layout jumps

---

## 5. Performance Optimization

### Physics Thread
- Reduce `PHYSICS_HZ` from 120 to 60
- Fix settled detection: use max velocity magnitude, ignore warmth noise
- Increase settled sleep from 100ms to 200ms
- Wake only on input events or force param changes

### Render Thread
- Skip display link callbacks when idle (idleFrameCount counter)
- Only rebuild SpatialIndex when positions changed

### Force Calculation
- Adaptive Barnes-Hut theta: 0.5 for <500 nodes, 0.7 for larger graphs

### Metal
- Ensure GPU buffer reuse (no per-frame allocation)
- Verify triple buffering active

---

## 6. Testing Strategy

- Add Rust unit tests for each new force (cluster, attract)
- Add Rust tests for Louvain detection
- Add MSDF label generation tests
- Run full Swift + Rust test suites after each feature
- Verify no regressions
