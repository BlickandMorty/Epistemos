# Epistemos Explorer — 2D Top-Down RPG Mode

> Approved design. Explorer is a separate experience mode, not a visual theme.

## Summary

Add a **third graph experience mode** — Explorer — that launches a standalone Bevy top-down RPG window. Graph nodes become NPCs and buildings in a procedurally generated world. The player walks around, talks to node-NPCs, and gets AI-powered dialogue driven by the existing persona/archetype system.

Explorer is **not** a `VisualTheme` variant. The Rust-facing `GraphVisualTheme` enum stays as-is (`.classic` / `.dialogue`). Explorer is a Swift-side presentation mode that lives alongside the graph view, not inside it.

The existing `.dialogue` mode (SwiftUI overlay, Metal rendering, personas, care state, two skins) is **kept intact**. Explorer is separate and additive.

```
GraphExperienceMode (Swift-only, not sent to Rust):
  .graph     → MetalGraphView with VisualTheme (.classic or .dialogue)
  .explorer  → Standalone Bevy window (NEW)
```

**Reference repos (copy heavily, then tweak):**
- [rusty-woods](https://github.com/janos-r/rusty-woods) — skeleton (Bevy + LDtk, top-down RPG, ~1000 LOC)
- [kimgoetzke/procedural-generation-2](https://github.com/kimgoetzke/procedural-generation-2) — generation pipeline (Perlin noise terrain)
- [fishfolk/jumpy](https://github.com/fishfolk/jumpy) — architecture patterns (state machine, animation banks, fixed timestep)
- [mxgmn/WaveFunctionCollapse](https://github.com/mxgmn/WaveFunctionCollapse) — WFC algorithm reference (v2 scope)

**Art assets:** Mystic Woods + Ninja Adventure packs (free, 4-directional walk cycles, RPG terrain tiles).

---

## Architecture

```
Epistemos (Swift/Metal)
  ├── Main Window
  │   ├── GraphExperienceMode == .graph
  │   │   └── MetalGraphView (classic or dialogue VisualTheme, unchanged)
  │   └── GraphExperienceMode == .explorer
  │       └── launches standalone Bevy window (new)
  │
  └── Data flow: GraphStore (current filtered projection) → JSON → Bevy
```

The Bevy app is a **separate binary** (`epistemos-explorer`) in a new workspace crate. Swift spawns it as a child process when Explorer mode activates. Bevy creates its own standalone window via winit (no child-window reparenting — that's brittle). Swift communicates via stdin/stdout JSON IPC for AI dialogue.

**No existing code is deleted.** The Rust-facing `GraphVisualTheme` enum is not modified. The dialogue mode, DialogueOverlayView, DialogueChatState, persona/archetype/care system, Metal dialogue shader — all stay. Explorer is purely additive.

### Graph Data Export

Explorer consumes the **current filtered/mode-scoped graph projection**, not the full graph. Whatever the user sees in the graph view is what gets exported:
- If in `.global` mode → full graph
- If in `.page(nodeId:)` mode → that page's subgraph
- If time-filtered or semantically filtered → the filtered subset

This means the JSON export reads from `GraphState`'s current visible nodes/edges, not from the raw `GraphStore`. The export includes persona snapshots (see below).

---

## What Copies From Where

### From rusty-woods (direct copy → tweak):

| What | Copy as-is | Tweak for Epistemos |
|---|---|---|
| Bevy app structure | main.rs, plugin registration, states | Add graph data loading state |
| Player movement (top-down WASD) | 4-dir movement + animation | Add NPC interaction key (E/Space) |
| Sprite rendering | Character + tilemap sprites | Same Mystic Woods + Ninja Adventure packs |
| Camera | Follow-player camera | Same |
| Door system | Level transitions | Repurpose as region transitions between graph clusters |
| NPC entities | Basic NPC placement | Populated from graph nodes with archetype-driven sprites |

### From kimgoetzke (generation pipeline — v1 subset):

| What | Copy approach | Tweak for Epistemos |
|---|---|---|
| Multi-fractal Perlin noise terrain | Chunk-based generation with biomes | Graph cluster density seeds biome placement |
| 16 tile variants with transparency | Layered tile transitions | Same |
| Async chunk generation | Background generation | Same |

### From Jumpy (architecture patterns):

| What | Copy pattern |
|---|---|
| Fixed 60fps timestep | Accumulator pattern |
| Player state machine | States as Bevy plugins: Idle, Walk, Talk |
| Animation banks | Named animations per state |
| Asset pack system | assets/ with sprite sheets + metadata |

### Deferred to v2:
- WFC decorative object placement (from kimgoetzke)
- Rapier2D physics (from rusty-woods) — v1 uses simple AABB collision
- Per-edge A* road pathfinding — v1 uses cluster-level roads only

---

## Crate Structure

```
Epistemos/
  ├── graph-engine/              (existing, UNCHANGED)
  ├── epistemos-explorer/        (NEW Bevy crate)
  │   ├── Cargo.toml
  │   ├── src/
  │   │   ├── main.rs            (Bevy app entry, plugin registration)
  │   │   ├── states.rs          (AppState: Loading, Generating, Playing, Talking)
  │   │   ├── graph_data.rs      (deserialize graph JSON → world gen input)
  │   │   ├── generation/
  │   │   │   ├── mod.rs
  │   │   │   ├── terrain.rs     (Perlin noise → biome/tile assignment)
  │   │   │   ├── placement.rs   (graph clusters → settlement positions, NPC placement)
  │   │   │   └── roads.rs       (cluster-level roads between settlements)
  │   │   ├── player.rs          (movement, animation, interaction)
  │   │   ├── npc.rs             (graph-node NPCs, archetype sprites, interaction zones)
  │   │   ├── dialogue.rs        (in-game RPG text box, typewriter, AI streaming)
  │   │   ├── camera.rs          (follow-player, smooth lerp)
  │   │   ├── tilemap.rs         (tile rendering, chunk management)
  │   │   └── ipc.rs             (stdin/stdout JSON protocol to Swift)
  │   └── assets/
  │       ├── tilesets/          (Mystic Woods terrain)
  │       ├── characters/        (Ninja Adventure sprites)
  │       └── ui/                (dialogue box frame, fonts)
  └── Epistemos/                 (Swift app — additions only)
      └── Views/Graph/
          └── ExplorerWindowController.swift  (NEW — process + window lifecycle)
```

---

## World Generation (v1 — cluster-level, not per-edge)

**Phase 1 — Cluster detection:**
```
Graph nodes → connected components / modularity clustering
Each cluster = a settlement region
Isolated nodes = lone outposts
```

**Phase 2 — Layout:**
```
Node positions come from stored GraphStore position hints (phyllotaxis layout),
  NOT from live Rust engine simulation positions.
  The Swift-side GraphStore already has x/y per node — these are exported in the JSON.
  If positions are too bunched or sparse, Bevy rescales to tile-space with a
  simple normalize-to-bounding-box pass.
Settlement centers = cluster centroids (average of member node positions).
Player spawns at the largest cluster's centroid.
```

Note: v1 does NOT require a position-export API from the Rust engine. `GraphStore` positions are sufficient. If live simulation positions are desired later (v2), an FFI function `graph_engine_export_positions()` would need to be added.

**Phase 3 — Terrain (Perlin noise):**
```
Multi-fractal Perlin noise → elevation map
Quantized into terrain types:
  Water → Shore → Grass → Dense Grass → Forest

Biome driven by cluster proximity:
  Near settlement center → Village biome (clearings, grass, paths)
  Between settlements → Woodland biome (mixed terrain)
  Far from any settlement → Wilderness biome (heavy forest, water)
```

16 tile variants per terrain type with transparency for layered transitions. Chunk-based, async generation.

**Phase 4 — Placement:**
```
For each graph node within a cluster:
  Place building at node's relative position within settlement
  Building template by node type:
    Note → cottage      Source → library
    Idea → workshop     Folder → town hall
    Tag → signpost
  Spawn NPC inside/near building
    NPC sprite by archetype:
    Archivist → scholar    Examiner → guard
    Dreamer → wizard       Gardener → farmer
    Guide → cartographer   Sentinel → knight
```

**Phase 5 — Roads (cluster-level only):**
```
For each pair of connected clusters:
  Pick the strongest inter-cluster edge (most connections)
  Lay a road between the two settlement centers
  Road follows terrain — prefers grass, avoids water
  Simple Bresenham-style path with terrain cost weighting
```

This avoids the per-edge explosion on dense graphs. A graph with 500 edges but 8 clusters only generates ~12 roads.

**v2 additions (not in v1):**
- WFC for decorative objects (trees, rocks, fences, ruins)
- Per-edge secondary paths within settlements
- Rapier2D for proper collision instead of AABB

---

## Player & NPC Systems

**Player:** WASD/arrows, 4-directional, ~120 px/s. Simple AABB collision against terrain and buildings (no Rapier in v1). State machine: Idle → Walk (on input), Walk → Idle (no input), Walk/Idle → Talk (E near NPC), Talk → Idle (dismiss). Sprite from Ninja Adventure, 4-frame walk cycles per direction.

**NPCs:** One per graph node. Static, face player when nearby. AABB interaction zone (~48px radius). When player enters zone: "E to talk" prompt appears. NpcData carries node_id, label, archetype, mood, health, attention, opening_line — all from a **persona snapshot exported by Swift** in the graph JSON (see Data Export below). Bevy does NOT reimplement persona derivation, care decay, or mood transitions. Swift owns all persona logic; Bevy just reads the snapshot.

**Dialogue box (Bevy-native, in-game):**
```
┌─────────────────────────────────────────────┐
│ ┌──────┐  ARCHIVE KEEPER                    │
│ │sprite│  "Research Notes"                  │
│ │ face │                                    │
│ └──────┘  I kept the receipts. Ask me       │
│           where the evidence bends.         │
│                                             │
│  > [text input]                    [Send]   │
└─────────────────────────────────────────────┘
```
RPG-style text box at bottom of screen. Archetype portrait on left. Typewriter text reveal. Text input for queries. Tokens streamed via IPC from Swift's TriageService.

---

## Swift Integration (Standalone Window)

**ExplorerWindowController** — new Swift class. Manages Bevy process lifecycle.

```swift
ExplorerWindowController {
    func launch(graphJSON: URL)     // spawn process
    func shutdown()                  // terminate process
    func handleQuery(nodeId:text:)   // game → Swift (AI request)
    func sendToken(_ text: String)   // Swift → game (AI response)
    func sendDone()                  // Swift → game (stream complete)
}
```

**Launch:** When user selects Explorer mode:
1. Swift exports current graph projection + persona snapshots → JSON at temp path
2. Spawns `epistemos-explorer --graph <path>` as child process
3. Bevy creates its own standalone window via winit (no reparenting)
4. Swift reads game's stdout on background thread for IPC

**Graph JSON schema:**
```json
{
  "nodes": [
    {
      "id": "uuid-123",
      "label": "Research Notes",
      "type": "note",
      "sourceId": "page-uuid",
      "x": 142.5,
      "y": -87.3,
      "persona": {
        "archetype": "archivist",
        "mood": "curious",
        "health": 0.72,
        "attention": 0.58,
        "openingLine": "I kept the receipts...",
        "summary": "Research Notes guards receipts...",
        "focusKeywords": ["methodology", "evidence"],
        "portrait": { "symbol": "books.vertical.fill", "crestLabel": "Catalog" }
      }
    }
  ],
  "edges": [
    { "from": "uuid-123", "to": "uuid-456", "type": "reference" }
  ]
}
```

Persona snapshots are computed by Swift using the existing `DialogueNodeProfile.derive()` + `DialogueCareState` at export time. Bevy reads them as-is — no derivation logic in Rust.

**IPC (line-delimited JSON over stdin/stdout):**
```
Game → Swift:  {"type":"query","requestId":"q1","nodeId":"abc","text":"Tell me about..."}
Game → Swift:  {"type":"cancel","requestId":"q1"}

Swift → Game:  {"type":"token","requestId":"q1","text":"The "}
Swift → Game:  {"type":"token","requestId":"q1","text":"key insight "}
Swift → Game:  {"type":"done","requestId":"q1"}
Swift → Game:  {"type":"error","requestId":"q1","message":"Service unavailable"}
```

Every query/response pair carries a `requestId` (monotonic counter). This prevents races when the player switches NPCs quickly or closes the dialogue while a stream is in-flight. Bevy ignores tokens with stale requestIds. Swift cancels in-flight TriageService streams on `cancel`.

Swift owns all persona/archetype/care logic. Bevy reads persona snapshots from the graph JSON export but never derives, decays, or transitions mood/health/attention itself.

### Explorer Care Sync

The initial persona snapshot exported at launch is a starting point, not frozen state. Care state stays live during an Explorer session via IPC:

```
After each dialogue interaction completes:
Swift → Game:  {"type":"care_update","nodeId":"abc","mood":"thriving","health":0.85,"attention":0.91}
```

Swift runs `DialogueNodeProfile.recordInteraction()` and `DialogueCareState.applyDecay()` on its side (same code path as `.dialogue` mode), then pushes the updated snapshot to Bevy. Bevy updates the NPC's displayed mood/health bars and portrait crest label — purely visual, no logic.

This means:
- Opening a dialogue → Swift runs `care.markOpened()` → pushes update
- Submitting a query → Swift runs `care.recordInteraction()` → pushes update after `done`
- Time decay → Swift runs `care.applyDecay()` before each interaction, same as existing code
- Bevy never computes care state — it only renders what Swift tells it

**Shutdown:** User switches away from Explorer mode → send `{"type":"quit"}` to stdin → terminate after 1s grace → clean up temp JSON.

**What stays untouched in existing code:**
- DialogueOverlayView.swift — unchanged
- DialogueChatState + all persona/archetype/care code — unchanged
- MetalGraphView dialogue overlay methods — unchanged
- Dialogue FFI functions — unchanged
- Metal dialogue shader — unchanged (still used by .dialogue mode)
- GraphFloatingControls — add Explorer button, keep dialogue toggle

**New Swift code:**
- `ExplorerWindowController.swift` — process lifecycle + IPC
- `GraphExperienceMode` enum (`.graph` / `.explorer`) on GraphState — Swift-only, not sent to Rust
- Explorer toggle button in GraphFloatingControls
- Graph JSON export function that reads current filtered projection + persona snapshots

---

## Dependencies (epistemos-explorer/Cargo.toml)

```toml
[package]
name = "epistemos-explorer"
version = "0.1.0"
edition = "2024"

[dependencies]
bevy = { version = "0.15", features = ["dynamic_linking"] }
noise = "0.9"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
rand = "0.8"
```

v1 omits `bevy_ecs_ldtk` (no LDtk maps yet) and `bevy_rapier2d` (AABB collision only).

Binary built via `cargo build --release -p epistemos-explorer`, copied into app bundle Resources/. Swift launches from `Bundle.main.url(forResource:)`.

**Size impact:** ~25-35MB binary + ~5MB assets = ~35MB added to app bundle.
**Startup time:** ~1-2s cold start (window + asset loading).

---

## Dead Code Policy

**Nothing is deleted in v1.** Explorer is additive.

The face geometry (eyes + mouth in renderer.rs) and Metal dialogue box shader are technically unused visually (user confirmed they don't render), but they're part of the `.dialogue` mode code path and should only be cleaned up in a separate housekeeping pass — not as part of Explorer development.

---

## v2 Roadmap (not in scope for v1)

- WFC decorative object placement (.toml rule files)
- Rapier2D physics replacing AABB collision
- Per-edge secondary paths within settlements
- LDtk building interior templates (bevy_ecs_ldtk)
- Child-window integration (Bevy window embedded in main window)
- Live graph sync (incremental updates instead of full JSON export)
- Heightmap techniques from proc-gen advice (mesa heights, bias fields, Voronoi lakes)
