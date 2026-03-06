# Dialogue Theme — Design Document

## Goal

Replace the Pixel Art graph theme with a "Dialogue" theme inspired by Final Fantasy Tactics dialogue boxes. Selecting a node spawns an FFT-style dialogue box connected to it and animates a simple face (eyes + mouth) on the node. The dialogue box is a functional AI chat — the node responds in character based on its content.

## Architecture

**Hybrid rendering:** Metal draws the box visuals + node face. SwiftUI overlays all text (chat history + input) using RetroGaming.ttf pixel font.

```
User clicks node
  → Rust hit-test → selected_node set
  → Metal renders: dialogue box (gradient bg, border, tail, nameplate bar) + face on node
  → Swift reads box screen rect via FFI
  → DialogueOverlayView (SwiftUI) appears positioned over the Metal box
  → User chats with node via AI
```

### Layer Stack

```
[SwiftUI]  DialogueOverlayView — chat text + input (RetroGaming.ttf)
[Metal]    Dialogue box shape — gradient bg, white border, tail, nameplate
[Metal]    Node face — eyes + mouth on selected node
[Metal]    Graph — nodes + edges (Classic SDF renderer, unchanged)
```

## Visual Reference

Final Fantasy Tactics dialogue boxes:
- Dark blue gradient background with subtle border
- Character name plate at top of box
- Character portrait on the right side
- White text, types out letter-by-letter
- Box positioned near the speaking character with a pointed tail

## Components

### Rust / Metal (graph-engine/)

**1. Dialogue Box Shader** — new pass after nodes/edges, before glow
- Dark blue gradient rectangle with 2px white border and rounded corners
- Pointed tail (triangle) from box bottom-center to selected node position
- Nameplate bar at top of box, colored by node type
- Rendered as instanced quads with a dedicated pipeline

**2. Node Face** — additions to existing node shader
- When `dialogue_active == true` on selected node:
  - 2 small dot eyes (white circles) near top of node
  - Small mouth arc below eyes
- Blink: eyes close briefly every ~3 seconds (driven by `time` uniform)
- Talk: mouth oscillates open/closed at ~8Hz while `is_streaming == true`
- Kirby/slime aesthetic — minimal, charming

**3. Dialogue State in Renderer**
```rust
struct DialogueState {
    active: bool,
    node_index: Option<usize>,
    is_streaming: bool,
    box_screen_rect: [f32; 4],    // x, y, w, h in screen coords
    node_screen_pos: [f32; 2],    // selected node center in screen coords
}
```

**4. New FFI Functions**
- `graph_engine_dialogue_open(engine, node_uuid: *const c_char)` — activate dialogue on node
- `graph_engine_dialogue_close(engine)` — dismiss dialogue
- `graph_engine_dialogue_set_streaming(engine, streaming: u8)` — toggle mouth animation
- `graph_engine_dialogue_screen_rect(engine, out: *mut f32)` — write box rect (4 floats)
- `graph_engine_dialogue_node_screen_pos(engine, out: *mut f32)` — write node pos (2 floats)

**5. Delete Pixel Art Code**
Remove entirely:
- `VisualTheme::Pixel` → rename to `VisualTheme::Dialogue`
- `draw_pixel()`, `PIXEL_SHADER_SOURCE`
- `PixelNodeInstance`, `PixelEdgeInstance`, `PixelUniforms`
- `VoxelPalette` (light/dark palette system)
- `build_pixel_node_instances()`, `build_pixel_edge_instances()`
- `create_pixel_pipelines()`
- `pixel_block_size()`, `pixel_block_half_extent()`
- All pixel-related tests (rewrite for dialogue)

### Swift

**6. DialogueChatState** (`State/DialogueChatState.swift` — new)
- `@MainActor @Observable` class, similar pattern to NoteChatState
- One shared instance (only one dialogue active at a time)
- Properties: `inputText`, `messages: [DialogueMessage]`, `isStreaming`, `activeNodeId`
- `submitQuery()` builds system prompt from:
  - Node label + type
  - Note body content (if node has sourceId → load page body)
  - Linked node labels (graph adjacency)
- Routes through TriageService (same as NoteChatState)
- Token buffering: 60ms flush interval, same pattern
- Feeds streaming state to Rust via `graph_engine_dialogue_set_streaming()`

**7. AI Personality (System Prompt)**
```
You are "{node.label}", a character in a knowledge graph.
Your personality comes from your content:

--- CONTENT ---
{noteBody.prefix(50_000)}
--- END ---

You speak in character. Be playful and helpful.
Your connections: {linkedNodeLabels.joined(separator: ", ")}
The user is your creator. Help them learn and remember your content.
Keep responses concise (2-3 sentences unless asked for more).
```

**8. DialogueOverlayView** (`Views/Graph/DialogueOverlayView.swift` — new)
- SwiftUI view overlaid on MetalGraphView
- Positioned using screen rect from `graph_engine_dialogue_screen_rect()` FFI
- Uses `Font.custom("RetroGaming", size: 14)` for all text
- Chat history: scrollable list of messages, white text on transparent bg
- Typewriter animation: timer reveals response characters progressively (~30 chars/sec)
- Input field at bottom: styled with RetroGaming font, blinking cursor
- Enter submits, Escape dismisses

**9. GraphFloatingControls Updates**
- Remove: "Pixel" theme button, pixel scale slider
- Add: "Dialogue" theme button (icon: `bubble.left.fill`)
- Toggle: "Classic" / "Dialogue"

**10. GraphState Updates**
- `GraphVisualTheme.pixel` → `.dialogue` (rawValue 0 preserved)
- Remove: `pixelScale` property
- Add: `isDialogueActive: Bool` (read from Rust state)
- Keep: `visualThemeVersion` change tracking

**11. MetalGraphView Updates**
- On node selection when theme == .dialogue:
  - Call `graph_engine_dialogue_open(engine, nodeUuid)`
  - Show DialogueOverlayView
- On deselection / escape:
  - Call `graph_engine_dialogue_close(engine)`
  - Hide DialogueOverlayView
- Each frame: read `dialogue_screen_rect` to reposition overlay

**12. Font Bundle**
- Add `RetroGaming.ttf` to Xcode project resources
- Register font in Info.plist (`ATSApplicationFontsPath` or `UIAppFonts`)
- Available as `Font.custom("RetroGaming", size:)` in SwiftUI

## Data Flow

### Opening Dialogue
```
1. User clicks node in Metal view
2. MetalGraphNSView.mouseUp() → graphState.selectNode(uuid)
3. If graphState.visualTheme == .dialogue:
   → graph_engine_dialogue_open(engine, uuid)
   → Rust: dialogue_state.active = true, compute box position
   → Metal renders box + tail + face on node
4. Swift reads screen_rect via FFI each frame
5. DialogueOverlayView appears, positioned over the Metal box
6. Greeting message: "What's up?" (from AI, short personality intro)
```

### Chatting
```
1. User types in SwiftUI text field (RetroGaming.ttf)
2. User presses Enter
3. DialogueChatState.submitQuery(text, nodeContent, linkedNodes)
4. TriageService routes to AI backend
5. graph_engine_dialogue_set_streaming(engine, 1) → mouth opens/closes
6. Tokens stream in → 60ms buffer → typewriter reveal in SwiftUI
7. Stream ends → graph_engine_dialogue_set_streaming(engine, 0)
8. Response fully visible. User can type again.
```

### Dismissing
```
1. User presses Escape or clicks background
2. graph_engine_dialogue_close(engine)
3. Metal: box + face removed
4. DialogueOverlayView hidden
5. Chat history preserved in DialogueChatState until node reselected
```

## What Stays Unchanged

- Classic theme renderer (SDF circles, edges, glow) — untouched
- EpistemosTheme (6 UI themes) — untouched
- ThemePair system — untouched
- NoteChatState (per-note editor chat) — untouched, separate system
- Node types, edge types — untouched
- Physics, ECS, simulation — untouched

## Scope Explicitly Excluded (Future Work)

- Living nodes / death mechanics / health system
- Node sprite animations beyond face
- Bevy / external game engine integration
- Quiz mode / active questioning from nodes
- Per-node personality configuration
- Chat history persistence across sessions
