# Epistemos Explorer — 2D Top-Down RPG Mode

## Summary

Replace the Metal-rendered dialogue box/face theme with an embedded Bevy game: a top-down RPG where graph nodes become NPCs and buildings in a procedurally generated world. The player walks around, talks to node-NPCs, and gets AI-powered dialogue driven by the existing persona/archetype system.

**Reference repos (copy heavily, then tweak):**
- [rusty-woods](https://github.com/janos-r/rusty-woods) — skeleton (Bevy + LDtk + Rapier, top-down RPG, ~1000 LOC)
- [kimgoetzke/procedural-generation-2](https://github.com/kimgoetzke/procedural-generation-2) — generation pipeline (Perlin noise + WFC + A*)
- [fishfolk/jumpy](https://github.com/fishfolk/jumpy) — architecture patterns (state machine, animation banks, fixed timestep)
- [mxgmn/WaveFunctionCollapse](https://github.com/mxgmn/WaveFunctionCollapse) — WFC algorithm reference

**Art assets:** Mystic Woods + Ninja Adventure packs (free, 4-directional walk cycles, RPG terrain tiles).

---

## Architecture

```
Epistemos (Swift/Metal)
  ├── Main Window
  │   ├── theme == .classic → MetalGraphView (existing, unchanged)
  │   └── theme == .dialogue → Bevy child window (new)
  │       ├── Borderless NSWindow, synced position/size
  │       ├── Bevy app with ECS game loop
  │       └── Renders tilemap + player + NPCs
  │
  └── Data flow: GraphStore → JSON → Bevy world gen
```

The Bevy app is a **separate binary** (`epistemos-explorer`) in a new workspace crate. Swift spawns it as a child process when the Dialogue theme activates, reparents its window as a borderless child of the main window, and communicates via stdin/stdout JSON IPC.

---

## What Copies From Where

### From rusty-woods (direct copy → tweak):

| What | Copy as-is | Tweak for Epistemos |
|---|---|---|
| Bevy app structure | main.rs, plugin registration, states | Add graph data loading state |
| Player movement (top-down WASD) | 4-dir movement + animation | Add NPC interaction key (E/Space) |
| Rapier2D collision | Wall/object colliders | NPC interaction zones (sensors) |
| Sprite rendering | Character + tilemap sprites | Same Mystic Woods + Ninja Adventure packs |
| Camera | Follow-player camera | Same |
| Door system | Level transitions | Repurpose as region transitions between graph clusters |
| NPC entities | Basic NPC placement | Populated from graph nodes with archetype-driven sprites |

### From kimgoetzke (generation pipeline):

| What | Copy approach | Tweak for Epistemos |
|---|---|---|
| Multi-fractal Perlin noise terrain | Chunk-based generation with biomes | Graph topology seeds biome placement |
| WFC for decorative objects | .toml rule files, multi-tile objects | Node buildings use WFC-placed templates |
| A* pathfinding for roads | Paths between settlements | Paths follow graph edges |
| Async chunk generation | Background generation | Same |
| 16 tile variants with transparency | Layered tile transitions | Same |

### From Jumpy (architecture patterns):

| What | Copy pattern |
|---|---|
| Fixed 60fps timestep | Accumulator pattern for determinism |
| Player state machine | States as Bevy plugins: Idle, Walk, Talk |
| Animation banks | Named animations per state |
| Asset pack system | assets/ with sprite sheets + metadata |

---

## Crate Structure

```
Epistemos/
  ├── graph-engine/              (existing — dialogue dead code removed)
  ├── epistemos-explorer/        (NEW Bevy crate)
  │   ├── Cargo.toml
  │   ├── src/
  │   │   ├── main.rs            (Bevy app entry, plugin registration)
  │   │   ├── states.rs          (AppState: Loading, Generating, Playing, Dialogue)
  │   │   ├── graph_data.rs      (deserialize graph JSON → world gen input)
  │   │   ├── generation/
  │   │   │   ├── mod.rs
  │   │   │   ├── terrain.rs     (Perlin noise → biome/tile assignment)
  │   │   │   ├── placement.rs   (graph nodes → NPC/building positions)
  │   │   │   ├── roads.rs       (A* paths along graph edges)
  │   │   │   └── wfc.rs         (WFC decorative object placement)
  │   │   ├── player.rs          (movement, animation, interaction)
  │   │   ├── npc.rs             (graph-node NPCs, archetype sprites)
  │   │   ├── dialogue.rs        (in-game RPG text box, typewriter, AI streaming)
  │   │   ├── camera.rs          (follow-player, smooth lerp)
  │   │   ├── tilemap.rs         (tile rendering, chunk loading)
  │   │   └── ipc.rs             (stdin/stdout JSON protocol to Swift)
  │   └── assets/
  │       ├── tilesets/          (Mystic Woods terrain)
  │       ├── characters/        (Ninja Adventure sprites)
  │       └── ui/                (dialogue box frame, fonts)
  └── Epistemos/                 (Swift app)
      └── Views/Graph/
          └── ExplorerWindowController.swift
```

---

## World Generation

**Phase 1 — Layout from graph topology:**
Graph nodes reuse their existing force-directed layout positions, rescaled to tile space. Cluster detection groups connected components into village regions. Isolated nodes become distant outposts.

**Phase 2 — Terrain (Perlin noise):**
Multi-fractal Perlin noise → elevation map, quantized into 5 terrain types per biome (water, shore, grass, dense grass, forest). Three biomes driven by graph density: Village (high node density, clearings), Woodland (medium, mixed), Wilderness (low/no nodes, heavy forest and water). 16 tile variants per terrain type with transparency for layered transitions. Chunk-based, async.

**Phase 3 — Placement:**
Each graph node places a building + NPC. Building template by node type: Note→cottage, Source→library, Idea→workshop, Folder→town hall, Tag→signpost. NPC sprite by archetype: Archivist→scholar, Examiner→guard, Dreamer→wizard, Gardener→farmer, Guide→cartographer, Sentinel→knight.

**Phase 4 — Roads (A*):**
For each graph edge, A* pathfinds from node A's building to node B's building, laying road tiles. Roads avoid water, prefer flat terrain.

**Phase 5 — Decoration (WFC):**
WFC with .toml adjacency rules places trees, rocks, flowers, fences around buildings. Ruins in wilderness. Bridges over water crossings.

---

## Player & NPC Systems

**Player:** WASD/arrows, 4-directional, ~120 px/s. State machine: Idle → Walk (on input), Walk → Idle (no input), Walk/Idle → Talk (E near NPC), Talk → Idle (dismiss). Sprite from Ninja Adventure, 4-frame walk cycles per direction.

**NPCs:** One per graph node. Static, face player when nearby. Sensor collider (radius ~48px) triggers "E to talk" prompt. NpcData carries node_id, label, archetype, mood, health, attention, opening_line — all from Codex's persona system.

**Dialogue box (Bevy-native):**
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

## Swift Integration (Child Window)

**ExplorerWindowController** manages Bevy process + child window lifecycle.

**Launch:** Theme → .dialogue triggers: serialize GraphStore → JSON, spawn `epistemos-explorer --graph <path>`, grab winit window by PID, reparent as borderless child via `NSWindow.addChildWindow(_:ordered:)`, sync frame.

**IPC (line-delimited JSON over stdin/stdout):**
```
Game → Swift:  {"type":"query","nodeId":"abc","text":"Tell me about..."}
Swift → Game:  {"type":"token","text":"The "}
Swift → Game:  {"type":"done"}
```

**Shutdown:** Theme toggle or window close → send `{"type":"quit"}`, terminate after 1s grace, remove child window, clean up temp JSON.

---

## Dependencies

```toml
[dependencies]
bevy = { version = "0.15", features = ["dynamic_linking"] }
bevy_ecs_ldtk = "0.11"
bevy_rapier2d = "0.29"
noise = "0.9"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
rand = "0.8"
```

Binary built via `cargo build --release -p epistemos-explorer`, copied into app bundle Resources/. Swift launches from `Bundle.main.url(forResource:)`.

---

## Dead Code Removal

### graph-engine/src/renderer.rs — DELETE:
- `DialogueState`, `DialogueVertex`, `DialogueUniforms`, `DialogueBoxGeometry` structs
- `DIALOGUE_SHADER_SOURCE` (Metal shading language)
- `DIALOGUE_BOX_SCREEN_WIDTH/HEIGHT/TAIL/GAP` constants
- `clamp_dialogue_box_left()`, `ensure_dialogue_pipeline()`, `dialogue_box_geometry()`, `compute_dialogue_box_position()`, `build_dialogue_vertices()`, `prepare_dialogue_box()`, `draw_dialogue_commands()`
- `dialogue_pipeline`, `dialogue_vertex_buf`, `dialogue_vertex_scratch`, `dialogue_uniform_buf` Renderer fields
- Face geometry block in `rebuild_classic_buffers()` (~50 lines: eyes + mouth)
- 4 dialogue-related tests

### graph-engine/src/lib.rs — DELETE FFI functions:
- `graph_engine_dialogue_open/close/set_streaming/screen_rect/node_screen_pos/is_active`

### Swift — DELETE:
- `DialogueOverlayView.swift`
- `MetalGraphNSView`: `dialogueHostingView`, `updateDialogueOverlay`, `hideDialogueOverlay`, `submitDialogueQuery`, `dismissDialogue`, `dialogueRectBuf`

### Swift — KEEP (repurposed):
- `DialogueChatState` + all persona/archetype/care code → IPC handler
- `DialoguePresentationTheme` → sent to Bevy as CLI arg for UI palette
- `VisualTheme::Dialogue` → triggers explorer launch
- `GraphFloatingControls` dialogue theme toggle → sends palette change over IPC
