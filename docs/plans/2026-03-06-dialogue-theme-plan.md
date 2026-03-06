# Dialogue Theme Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the Pixel Art graph theme with an FFT-style dialogue system — selecting a node spawns a dialogue box connected to it with AI chat, and the node sprouts an animated face.

**Architecture:** Metal renders the dialogue box shape (gradient bg, border, tail, nameplate) and face geometry on the selected node. SwiftUI overlays all text using RetroGaming.ttf pixel font. DialogueChatState manages AI streaming. Pixel art code is deleted entirely.

**Tech Stack:** Rust (graph-engine), Metal Shading Language, Swift/SwiftUI, RetroGaming.ttf

**Design doc:** `docs/plans/2026-03-06-dialogue-theme-design.md`

---

### Task 1: Delete Pixel Art Rendering Code (Rust)

Remove all pixel art rendering infrastructure from the Rust graph engine. This clears ~800 lines and the `VoxelPalette` system.

**Files:**
- Modify: `graph-engine/src/renderer.rs:58-92` (delete PixelNodeInstance, PixelEdgeInstance, PixelUniforms structs)
- Modify: `graph-engine/src/renderer.rs:223-236` (delete pixel_block_size, pixel_block_half_extent)
- Modify: `graph-engine/src/renderer.rs:589-817` (delete PIXEL_SHADER_SOURCE)
- Modify: `graph-engine/src/renderer.rs:818-920` (remove pixel fields from Renderer struct)
- Modify: `graph-engine/src/renderer.rs:1967-1997` (delete create_pixel_pipelines)
- Modify: `graph-engine/src/renderer.rs:2028-2149` (delete build_pixel_node_instances)
- Modify: `graph-engine/src/renderer.rs:2153-2226` (delete build_pixel_edge_instances)
- Modify: `graph-engine/src/renderer.rs:2229-2353` (delete draw_pixel)
- Modify: `graph-engine/src/types.rs:265-317` (delete VoxelPalette struct entirely)
- Modify: `graph-engine/src/engine.rs:53-58` (simplify clamp_zoom_for_theme — no Pixel branch)
- Modify: `graph-engine/src/engine.rs:596-599` (delete set_pixel_scale FFI)
- Modify: `graph-engine/src/ecs/bridge.rs` (delete block_type_for_node, has_glare_for_block)
- Modify: `graph-engine/src/ecs/components.rs` (remove block_type, has_glare from RenderComponent)
- Test: `graph-engine/src/renderer.rs` (delete pixel-specific tests, keep classic/LOD tests)

**Step 1: Delete pixel structs and shader from renderer.rs**

Remove these items:
- `PixelNodeInstance` struct (lines 58-69)
- `PixelEdgeInstance` struct (lines 72-80)
- `PixelUniforms` struct (lines 83-92)
- `pixel_block_size()` function (lines 223-232)
- `pixel_block_half_extent()` function (lines 234-236)
- `PIXEL_SHADER_SOURCE` constant (lines 589-817)

**Step 2: Remove pixel fields from Renderer struct**

In the Renderer struct (lines 818-920), delete these fields:
```rust
// DELETE these fields:
pixel_scale: u8,
pixel_palette: VoxelPalette,
pixel_offscreen_texture: Option<Texture>,
pixel_offscreen_width: u32,
pixel_offscreen_height: u32,
pixel_nearest_sampler: Option<SamplerState>,
pixel_node_pipeline: Option<RenderPipelineState>,
pixel_edge_pipeline: Option<RenderPipelineState>,
pixel_upscale_pipeline: Option<RenderPipelineState>,
pixel_node_buf: Option<Buffer>,
pixel_node_capacity: usize,
pixel_edge_buf: Option<Buffer>,
pixel_edge_capacity: usize,
```

And remove their initialization in `Renderer::new()`.

**Step 3: Delete pixel rendering functions**

Remove:
- `create_pixel_pipelines()` (lines 1967-1997)
- `build_pixel_node_instances()` (lines 2028-2149)
- `build_pixel_edge_instances()` (lines 2153-2226)
- `draw_pixel()` (lines 2229-2353)

**Step 4: Delete VoxelPalette from types.rs**

Remove the entire `VoxelPalette` struct and its `impl` block (lines 265-317).

**Step 5: Clean up engine.rs**

- In `clamp_zoom_for_theme()` (line 53): remove the `Pixel` match arm. Both themes now use `zoom.clamp(1.0, 10.0)`.
- Delete `graph_engine_set_pixel_scale()` FFI function (lines 596-599).
- Delete `set_pixel_scale()` method on Engine.
- In `set_light_mode()`: remove `pixel_palette` assignment.
- In the render dispatch: remove `VisualTheme::Pixel => draw_pixel()` branch.

**Step 6: Clean up ECS bridge**

In `graph-engine/src/ecs/bridge.rs`:
- Remove `block_type_for_node()` function
- Remove `has_glare_for_block()` function
- Remove references to `block_type` and `has_glare` in `World::from_graph()`

In `graph-engine/src/ecs/components.rs`:
- Remove `block_type: u8` and `has_glare: u8` from `RenderComponent`

**Step 7: Delete pixel-specific tests**

Remove tests for:
- PixelNodeInstance/PixelEdgeInstance alignment tests
- pixel_block_size tests
- draw_pixel tests
- VoxelPalette tests

Keep all classic/LOD/general tests.

**Step 8: Run tests**

Run: `cd graph-engine && cargo test 2>&1 | tail -5`
Expected: All tests pass with no pixel-related failures. Fix any compilation errors from removed symbols.

**Step 9: Commit**

```bash
git add -A graph-engine/src/
git commit -m "refactor(graph): delete pixel art theme rendering

Remove PixelNodeInstance, PixelEdgeInstance, PixelUniforms,
PIXEL_SHADER_SOURCE, VoxelPalette, draw_pixel(), and all
pixel-specific rendering infrastructure. ~800 lines removed."
```

---

### Task 2: Rename VisualTheme::Pixel → Dialogue (Rust + Swift)

**Files:**
- Modify: `graph-engine/src/types.rs:248-263` (rename enum variant)
- Modify: `graph-engine/src/engine.rs` (update all VisualTheme::Pixel references)
- Modify: `graph-engine/src/renderer.rs` (update visual_theme checks)
- Modify: `graph-engine-bridge/graph_engine.h:220-224` (update comment)
- Modify: `Epistemos/Models/GraphTypes.swift:13-25` (rename .pixel → .dialogue)
- Modify: `Epistemos/Graph/GraphState.swift:364-386` (update default, remove pixelScale)
- Modify: `Epistemos/Views/Graph/GraphFloatingControls.swift:175-227` (update toggle)
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift:356-359,665-669` (remove pixel_scale sync)

**Step 1: Rename in Rust types.rs**

```rust
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VisualTheme {
    Dialogue = 0, // FFT-style dialogue box on node selection
    Classic = 1,  // Original SDF circles + smooth lines
}

impl VisualTheme {
    pub fn from_u8(v: u8) -> Self {
        match v {
            1 => Self::Classic,
            _ => Self::Dialogue,
        }
    }
}
```

**Step 2: Update all Rust references**

Search for `VisualTheme::Pixel` and `Pixel` in engine.rs, renderer.rs — replace with `Dialogue`. In `clamp_zoom_for_theme()`, both branches now clamp to `1.0..10.0` so simplify to a single expression:

```rust
fn clamp_zoom_for_theme(_theme: VisualTheme, zoom: f32) -> f32 {
    zoom.clamp(1.0, 10.0)
}
```

**Step 3: Rename in Swift GraphTypes.swift**

```swift
enum GraphVisualTheme: UInt8, CaseIterable, Codable {
    case dialogue = 0
    case classic = 1

    var displayName: String {
        switch self {
        case .dialogue: "Dialogue"
        case .classic:  "Classic"
        }
    }
}
```

**Step 4: Update GraphState.swift**

- Change default from `.pixel` to `.dialogue`
- Delete `pixelScale` property entirely (lines 377-386)
- Keep `visualThemeVersion`

**Step 5: Update GraphFloatingControls.swift**

Replace the theme toggle (lines 175-227):
```swift
private var themeToggle: some View {
    HStack(spacing: 2) {
        themeButton(label: "Dialogue", icon: "bubble.left.fill", theme: .dialogue)
        themeButton(label: "Classic", icon: "circle.fill", theme: .classic)
    }
}
```

Delete the entire `pixelScaleControl` view (lines 203-227).
Remove the `pixelScaleControl` reference from the main body.

**Step 6: Update MetalGraphView.swift**

- Remove `graph_engine_set_pixel_scale()` calls at lines 358 and 668
- Keep `graph_engine_set_visual_theme()` calls

**Step 7: Update C header comment**

In `graph-engine-bridge/graph_engine.h` line 220:
```c
/// Set visual theme: 0 = Dialogue (default), 1 = Classic.
void graph_engine_set_visual_theme(Engine* engine, uint8_t theme);
```

Delete the `graph_engine_set_pixel_scale` declaration.

**Step 8: Run tests**

```bash
cd graph-engine && cargo test 2>&1 | tail -5
```

Then build Swift:
```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

**Step 9: Commit**

```bash
git add -A
git commit -m "refactor(graph): rename VisualTheme::Pixel to Dialogue

rawValue 0 preserved for UserDefaults compatibility.
Remove pixelScale property. Update theme toggle UI."
```

---

### Task 3: Add DialogueState and Box Shader (Rust)

Add the dialogue box rendering: dark blue gradient rectangle with white border, pointed tail to node, nameplate bar.

**Files:**
- Modify: `graph-engine/src/renderer.rs` (add DialogueState, dialogue shader, draw_dialogue_box)
- Modify: `graph-engine/src/engine.rs` (call draw_dialogue_box in render path)

**Step 1: Add DialogueState struct to renderer.rs**

Add near the top of the file, after existing struct definitions:

```rust
/// State for the FFT-style dialogue box overlay.
#[derive(Clone)]
struct DialogueState {
    active: bool,
    node_index: Option<usize>,
    is_streaming: bool,
    /// Box position in world coords (computed relative to node).
    box_world_rect: [f32; 4], // x, y, width, height
    /// Box position in screen coords (for SwiftUI overlay positioning).
    box_screen_rect: [f32; 4],
    /// Selected node center in screen coords.
    node_screen_pos: [f32; 2],
}

impl Default for DialogueState {
    fn default() -> Self {
        Self {
            active: false,
            node_index: None,
            is_streaming: false,
            box_world_rect: [0.0; 4],
            box_screen_rect: [0.0; 4],
            node_screen_pos: [0.0; 2],
        }
    }
}
```

**Step 2: Add dialogue fields to Renderer struct**

```rust
// In Renderer struct, add:
dialogue: DialogueState,
dialogue_pipeline: Option<RenderPipelineState>,
dialogue_vertex_buf: Option<Buffer>,
```

Initialize in `Renderer::new()`:
```rust
dialogue: DialogueState::default(),
dialogue_pipeline: None,
dialogue_vertex_buf: None,
```

**Step 3: Write the dialogue box Metal shader**

Add `DIALOGUE_SHADER_SOURCE` constant:

```rust
const DIALOGUE_SHADER_SOURCE: &str = r#"
#include <metal_stdlib>
using namespace metal;

struct DialogueVertex {
    float2 position [[attribute(0)]];
    float4 color    [[attribute(1)]];
};

struct DialogueOut {
    float4 position [[position]];
    float4 color;
};

struct DialogueUniforms {
    float2 viewport_size;
    float2 camera_offset;
    float  camera_zoom;
    float  time;
    float2 _pad;
};

vertex DialogueOut dialogue_vertex(
    const device DialogueVertex* vertices [[buffer(0)]],
    constant DialogueUniforms& uniforms  [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    DialogueOut out;
    float2 world_pos = vertices[vid].position;
    float2 screen = (world_pos - uniforms.camera_offset) * uniforms.camera_zoom;
    screen.x =  screen.x / (uniforms.viewport_size.x * 0.5);
    screen.y = -screen.y / (uniforms.viewport_size.y * 0.5);
    out.position = float4(screen, 0.0, 1.0);
    out.color = vertices[vid].color;
    return out;
}

fragment float4 dialogue_fragment(DialogueOut in [[stage_in]]) {
    return in.color;
}
"#;
```

**Step 4: Implement create_dialogue_pipeline()**

```rust
fn create_dialogue_pipeline(&mut self) {
    let library = match self.device.new_library_with_source(
        DIALOGUE_SHADER_SOURCE,
        &CompileOptions::new(),
    ) {
        Ok(lib) => lib,
        Err(e) => {
            eprintln!("dialogue shader compile error: {e}");
            return;
        }
    };
    let vert = library.get_function("dialogue_vertex", None).unwrap();
    let frag = library.get_function("dialogue_fragment", None).unwrap();

    let desc = RenderPipelineDescriptor::new();
    desc.set_vertex_function(Some(&vert));
    desc.set_fragment_function(Some(&frag));

    let vertex_desc = VertexDescriptor::new();
    // position: float2 at offset 0
    vertex_desc.attributes().object_at(0).unwrap().set_format(MTLVertexFormat::Float2);
    vertex_desc.attributes().object_at(0).unwrap().set_offset(0);
    vertex_desc.attributes().object_at(0).unwrap().set_buffer_index(0);
    // color: float4 at offset 8
    vertex_desc.attributes().object_at(1).unwrap().set_format(MTLVertexFormat::Float4);
    vertex_desc.attributes().object_at(1).unwrap().set_offset(8);
    vertex_desc.attributes().object_at(1).unwrap().set_buffer_index(0);
    // stride: 24 bytes (float2 + float4)
    vertex_desc.layouts().object_at(0).unwrap().set_stride(24);
    vertex_desc.layouts().object_at(0).unwrap().set_step_rate(1);
    vertex_desc.layouts().object_at(0).unwrap().set_step_function(MTLVertexStepFunction::PerVertex);
    desc.set_vertex_descriptor(Some(&vertex_desc));

    let attach = desc.color_attachments().object_at(0).unwrap();
    attach.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
    attach.set_blending_enabled(true);
    attach.set_source_rgb_blend_factor(MTLBlendFactor::SourceAlpha);
    attach.set_destination_rgb_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
    attach.set_source_alpha_blend_factor(MTLBlendFactor::One);
    attach.set_destination_alpha_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);

    self.dialogue_pipeline = self.device.new_render_pipeline_state(&desc).ok();
}
```

**Step 5: Implement compute_dialogue_box_position()**

Computes the box rect in world coordinates, positioned above the selected node:

```rust
const DIALOGUE_BOX_WIDTH: f32 = 280.0;
const DIALOGUE_BOX_HEIGHT: f32 = 160.0;
const DIALOGUE_BOX_OFFSET_Y: f32 = -30.0; // above node
const DIALOGUE_TAIL_HEIGHT: f32 = 20.0;

fn compute_dialogue_box_position(&mut self, world: &World) {
    let Some(node_idx) = self.dialogue.node_index else { return };
    if node_idx >= world.transform.len() { return; }

    let nx = world.transform[node_idx].x;
    let ny = world.transform[node_idx].y;

    // Box in world coords: centered above node
    let half_w = DIALOGUE_BOX_WIDTH / (2.0 * self.camera_zoom);
    let half_h = DIALOGUE_BOX_HEIGHT / (2.0 * self.camera_zoom);
    let box_center_x = nx;
    let box_center_y = ny + DIALOGUE_BOX_OFFSET_Y / self.camera_zoom - half_h - DIALOGUE_TAIL_HEIGHT / self.camera_zoom;

    self.dialogue.box_world_rect = [
        box_center_x - half_w,
        box_center_y - half_h,
        half_w * 2.0,
        half_h * 2.0,
    ];

    // Convert to screen coords for SwiftUI overlay
    let vw = self.viewport_width as f32;
    let vh = self.viewport_height as f32;
    let sx = (box_center_x - self.camera_x) * self.camera_zoom + vw * 0.5;
    let sy = (box_center_y - self.camera_y) * self.camera_zoom + vh * 0.5;
    let sw = DIALOGUE_BOX_WIDTH;
    let sh = DIALOGUE_BOX_HEIGHT;
    self.dialogue.box_screen_rect = [sx - sw * 0.5, sy - sh * 0.5, sw, sh];

    // Node screen pos
    let nsx = (nx - self.camera_x) * self.camera_zoom + vw * 0.5;
    let nsy = (ny - self.camera_y) * self.camera_zoom + vh * 0.5;
    self.dialogue.node_screen_pos = [nsx, nsy];
}
```

**Step 6: Implement build_dialogue_vertices() and draw_dialogue_box()**

Builds triangle list for box background, border, and tail:

```rust
#[repr(C)]
#[derive(Clone, Copy)]
struct DialogueVertex {
    position: [f32; 2],
    color: [f32; 4],
}

fn build_dialogue_vertices(&self, world: &World) -> Vec<DialogueVertex> {
    if !self.dialogue.active { return Vec::new(); }
    let Some(node_idx) = self.dialogue.node_index else { return Vec::new(); };
    if node_idx >= world.transform.len() { return Vec::new(); }

    let [bx, by, bw, bh] = self.dialogue.box_world_rect;
    let nx = world.transform[node_idx].x;
    let ny = world.transform[node_idx].y;
    let mut verts = Vec::with_capacity(24);

    // Box background (2 triangles) — dark blue gradient
    let bg_top = [0.08, 0.10, 0.22, 0.92];
    let bg_bot = [0.04, 0.06, 0.14, 0.92];
    // Triangle 1 (top-left, top-right, bottom-left)
    verts.push(DialogueVertex { position: [bx, by], color: bg_top });
    verts.push(DialogueVertex { position: [bx + bw, by], color: bg_top });
    verts.push(DialogueVertex { position: [bx, by + bh], color: bg_bot });
    // Triangle 2 (top-right, bottom-right, bottom-left)
    verts.push(DialogueVertex { position: [bx + bw, by], color: bg_top });
    verts.push(DialogueVertex { position: [bx + bw, by + bh], color: bg_bot });
    verts.push(DialogueVertex { position: [bx, by + bh], color: bg_bot });

    // Tail triangle (from box bottom-center to node)
    let tail_w = 12.0 / self.camera_zoom;
    let tail_color = bg_bot;
    verts.push(DialogueVertex { position: [bx + bw * 0.5 - tail_w, by + bh], color: tail_color });
    verts.push(DialogueVertex { position: [bx + bw * 0.5 + tail_w, by + bh], color: tail_color });
    verts.push(DialogueVertex { position: [nx, ny], color: tail_color });

    // Nameplate bar (2 triangles at top of box)
    let bar_h = 22.0 / self.camera_zoom;
    let node_type = world.hierarchy[node_idx].node_type;
    let bar_color = self.node_color_for_u8(node_type);
    let bar_color_dim = [bar_color[0] * 0.6, bar_color[1] * 0.6, bar_color[2] * 0.6, 0.7];
    verts.push(DialogueVertex { position: [bx, by], color: bar_color_dim });
    verts.push(DialogueVertex { position: [bx + bw, by], color: bar_color_dim });
    verts.push(DialogueVertex { position: [bx, by + bar_h], color: bar_color_dim });
    verts.push(DialogueVertex { position: [bx + bw, by], color: bar_color_dim });
    verts.push(DialogueVertex { position: [bx + bw, by + bar_h], color: bar_color_dim });
    verts.push(DialogueVertex { position: [bx, by + bar_h], color: bar_color_dim });

    // Border (4 thin quads around box) — white
    let bw_px = 2.0 / self.camera_zoom; // 2px border
    let border = [1.0, 1.0, 1.0, 0.7_f32];
    // Top edge
    verts.extend(quad_verts([bx, by], [bx + bw, by + bw_px], border));
    // Bottom edge
    verts.extend(quad_verts([bx, by + bh - bw_px], [bx + bw, by + bh], border));
    // Left edge
    verts.extend(quad_verts([bx, by], [bx + bw_px, by + bh], border));
    // Right edge
    verts.extend(quad_verts([bx + bw - bw_px, by], [bx + bw, by + bh], border));

    verts
}

fn quad_verts(min: [f32; 2], max: [f32; 2], color: [f32; 4]) -> [DialogueVertex; 6] {
    [
        DialogueVertex { position: [min[0], min[1]], color },
        DialogueVertex { position: [max[0], min[1]], color },
        DialogueVertex { position: [min[0], max[1]], color },
        DialogueVertex { position: [max[0], min[1]], color },
        DialogueVertex { position: [max[0], max[1]], color },
        DialogueVertex { position: [min[0], max[1]], color },
    ]
}

pub fn draw_dialogue_box(&mut self, encoder: &RenderCommandEncoderRef, world: &World) {
    if !self.dialogue.active { return; }
    if self.dialogue_pipeline.is_none() {
        self.create_dialogue_pipeline();
    }
    let Some(pipeline) = &self.dialogue_pipeline else { return };

    self.compute_dialogue_box_position(world);
    let vertices = self.build_dialogue_vertices(world);
    if vertices.is_empty() { return; }

    let buf_size = (vertices.len() * std::mem::size_of::<DialogueVertex>()) as u64;
    if self.dialogue_vertex_buf.is_none()
        || self.dialogue_vertex_buf.as_ref().unwrap().length() < buf_size
    {
        self.dialogue_vertex_buf = Some(
            self.device.new_buffer(buf_size.max(4096), MTLResourceOptions::StorageModeShared),
        );
    }
    let buf = self.dialogue_vertex_buf.as_ref().unwrap();
    unsafe {
        std::ptr::copy_nonoverlapping(
            vertices.as_ptr(),
            buf.contents() as *mut DialogueVertex,
            vertices.len(),
        );
    }

    #[repr(C)]
    struct DialogueUniforms {
        viewport_size: [f32; 2],
        camera_offset: [f32; 2],
        camera_zoom: f32,
        time: f32,
        _pad: [f32; 2],
    }
    let uniforms = DialogueUniforms {
        viewport_size: [self.viewport_width as f32, self.viewport_height as f32],
        camera_offset: [self.camera_x, self.camera_y],
        camera_zoom: self.camera_zoom,
        time: self.time,
        _pad: [0.0; 2],
    };

    encoder.set_render_pipeline_state(pipeline);
    encoder.set_vertex_buffer(0, Some(buf), 0);
    encoder.set_vertex_bytes(
        1,
        std::mem::size_of::<DialogueUniforms>() as u64,
        &uniforms as *const _ as *const _,
    );
    encoder.draw_primitives(MTLPrimitiveType::Triangle, 0, vertices.len() as u64);
}
```

**Step 7: Call draw_dialogue_box in the classic draw() path**

In the `draw()` function (classic renderer), after edge rendering and before the final pass, add:

```rust
self.draw_dialogue_box(encoder, world);
```

**Step 8: Write tests**

```rust
#[test]
fn dialogue_state_default_inactive() {
    let state = DialogueState::default();
    assert!(!state.active);
    assert!(state.node_index.is_none());
    assert!(!state.is_streaming);
}

#[test]
fn dialogue_box_vertices_empty_when_inactive() {
    // Renderer with dialogue.active = false produces no vertices
    // (test via build_dialogue_vertices returning empty vec)
}

#[test]
fn dialogue_vertex_struct_size() {
    assert_eq!(std::mem::size_of::<DialogueVertex>(), 24);
}
```

**Step 9: Run tests**

```bash
cd graph-engine && cargo test 2>&1 | tail -5
```

**Step 10: Commit**

```bash
git add -A graph-engine/src/
git commit -m "feat(graph): add dialogue box Metal shader and renderer

Dark blue gradient box with white border, pointed tail to
selected node, colored nameplate bar. Positioned above the
selected node in world coordinates."
```

---

### Task 4: Add Face Geometry on Selected Node (Rust)

Add simple eyes + mouth to the selected node when dialogue is active.

**Files:**
- Modify: `graph-engine/src/renderer.rs` (add face instances to classic node scratch)

**Step 1: Add face rendering in the classic node collection**

After the main node loop in `draw()` (where `classic_node_scratch` is populated), add face instances for the dialogue-active node:

```rust
// After main node collection, add face geometry if dialogue active
if self.dialogue.active {
    if let Some(node_idx) = self.dialogue.node_index {
        if node_idx < world.transform.len() {
            let nx = world.transform[node_idx].x;
            let ny = world.transform[node_idx].y;
            let r = world.transform[node_idx].radius;
            let eye_r = r * 0.12;
            let eye_spacing = r * 0.28;
            let eye_y = ny - r * 0.15;
            let mouth_y = ny + r * 0.25;

            // Blink: eyes close briefly every ~3 seconds
            let blink_cycle = (self.time * 0.33).fract();
            let eyes_visible = blink_cycle < 0.92 || blink_cycle > 0.96;

            if eyes_visible {
                // Left eye (white circle)
                self.classic_node_scratch.push(NodeInstance {
                    position: [nx - eye_spacing, eye_y],
                    radius: eye_r,
                    z: 0.99,
                    color: [1.0, 1.0, 1.0, 1.0],
                });
                self.classic_velocity_scratch.push([0.0, 0.0]);

                // Right eye (white circle)
                self.classic_node_scratch.push(NodeInstance {
                    position: [nx + eye_spacing, eye_y],
                    radius: eye_r,
                    z: 0.99,
                    color: [1.0, 1.0, 1.0, 1.0],
                });
                self.classic_velocity_scratch.push([0.0, 0.0]);
            }

            // Mouth: oscillates when streaming
            let mouth_r = if self.dialogue.is_streaming {
                eye_r * (0.6 + 0.4 * (self.time * 8.0).sin().abs())
            } else {
                eye_r * 0.5
            };
            self.classic_node_scratch.push(NodeInstance {
                position: [nx, mouth_y],
                radius: mouth_r,
                z: 0.99,
                color: [1.0, 1.0, 1.0, 0.9],
            });
            self.classic_velocity_scratch.push([0.0, 0.0]);
        }
    }
}
```

**Step 2: Run tests**

```bash
cd graph-engine && cargo test 2>&1 | tail -5
```

**Step 3: Commit**

```bash
git add graph-engine/src/renderer.rs
git commit -m "feat(graph): add face geometry on dialogue-active node

Simple eyes (blink every ~3s) and mouth (oscillates during
AI streaming) rendered as additional NodeInstance circles."
```

---

### Task 5: Add Dialogue FFI Functions (Rust + C Header)

Expose dialogue state to Swift via FFI.

**Files:**
- Modify: `graph-engine/src/engine.rs` (add FFI functions)
- Modify: `graph-engine-bridge/graph_engine.h` (declare FFI functions)

**Step 1: Add dialogue methods to Engine**

```rust
pub fn dialogue_open(&mut self, node_uuid: &str) {
    if let Some(&id) = self.world.uuid_to_id.get(node_uuid) {
        if let Some(idx) = self.world.index_of(id) {
            self.renderer.dialogue.active = true;
            self.renderer.dialogue.node_index = Some(idx);
            self.renderer.dialogue.is_streaming = false;
            self.needs_render.store(true, Ordering::Relaxed);
        }
    }
}

pub fn dialogue_close(&mut self) {
    self.renderer.dialogue.active = false;
    self.renderer.dialogue.node_index = None;
    self.renderer.dialogue.is_streaming = false;
    self.needs_render.store(true, Ordering::Relaxed);
}

pub fn dialogue_set_streaming(&mut self, streaming: bool) {
    self.renderer.dialogue.is_streaming = streaming;
    if streaming {
        self.needs_render.store(true, Ordering::Relaxed);
    }
}

pub fn dialogue_screen_rect(&self) -> [f32; 4] {
    self.renderer.dialogue.box_screen_rect
}

pub fn dialogue_node_screen_pos(&self) -> [f32; 2] {
    self.renderer.dialogue.node_screen_pos
}

pub fn dialogue_is_active(&self) -> bool {
    self.renderer.dialogue.active
}
```

**Step 2: Add FFI extern functions**

```rust
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_dialogue_open(engine: *mut Engine, node_uuid: *const c_char) {
    ffi_engine!(engine);
    let uuid = unsafe { std::ffi::CStr::from_ptr(node_uuid) };
    if let Ok(s) = uuid.to_str() {
        engine.dialogue_open(s);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_dialogue_close(engine: *mut Engine) {
    ffi_engine!(engine);
    engine.dialogue_close();
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_dialogue_set_streaming(engine: *mut Engine, streaming: u8) {
    ffi_engine!(engine);
    engine.dialogue_set_streaming(streaming != 0);
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_dialogue_screen_rect(engine: *mut Engine, out: *mut f32) {
    ffi_engine!(engine);
    let rect = engine.dialogue_screen_rect();
    unsafe {
        *out.add(0) = rect[0];
        *out.add(1) = rect[1];
        *out.add(2) = rect[2];
        *out.add(3) = rect[3];
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_dialogue_node_screen_pos(engine: *mut Engine, out: *mut f32) {
    ffi_engine!(engine);
    let pos = engine.dialogue_node_screen_pos();
    unsafe {
        *out.add(0) = pos[0];
        *out.add(1) = pos[1];
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_dialogue_is_active(engine: *mut Engine) -> u8 {
    ffi_engine_or!(engine, 0);
    if engine.dialogue_is_active() { 1 } else { 0 }
}
```

**Step 3: Update C header**

Add to `graph-engine-bridge/graph_engine.h`:

```c
/// Open dialogue box on the node with given UUID.
void graph_engine_dialogue_open(Engine* engine, const char* node_uuid);

/// Close the active dialogue box.
void graph_engine_dialogue_close(Engine* engine);

/// Set streaming state (mouth animation). 1 = streaming, 0 = idle.
void graph_engine_dialogue_set_streaming(Engine* engine, uint8_t streaming);

/// Write dialogue box screen rect (x, y, w, h) to output buffer (4 floats).
void graph_engine_dialogue_screen_rect(Engine* engine, float* out);

/// Write selected node screen position (x, y) to output buffer (2 floats).
void graph_engine_dialogue_node_screen_pos(Engine* engine, float* out);

/// Returns 1 if dialogue is active, 0 otherwise.
uint8_t graph_engine_dialogue_is_active(Engine* engine);
```

**Step 4: Write tests**

```rust
#[test]
fn dialogue_open_close_lifecycle() {
    // Create engine with a node, open dialogue, verify active,
    // close dialogue, verify inactive
}

#[test]
fn dialogue_screen_rect_zeroed_when_inactive() {
    // Verify screen rect is [0,0,0,0] when no dialogue active
}
```

**Step 5: Run tests**

```bash
cd graph-engine && cargo test 2>&1 | tail -5
```

**Step 6: Commit**

```bash
git add graph-engine/src/engine.rs graph-engine-bridge/graph_engine.h
git commit -m "feat(graph): add dialogue FFI functions

graph_engine_dialogue_open/close/set_streaming/screen_rect/
node_screen_pos/is_active for Swift integration."
```

---

### Task 6: Bundle RetroGaming.ttf Font (Swift)

**Files:**
- Add: `Epistemos/Resources/RetroGaming.ttf` (copy from ~/RetroGaming.ttf)
- Modify: `Epistemos/Info.plist` (register font)

**Step 1: Copy font into project**

```bash
mkdir -p Epistemos/Resources
cp ~/RetroGaming.ttf Epistemos/Resources/RetroGaming.ttf
```

**Step 2: Add to Xcode project**

Add `Epistemos/Resources/RetroGaming.ttf` to the Xcode project target.

**Step 3: Register in Info.plist**

Add under the root dict:
```xml
<key>ATSApplicationFontsPath</key>
<string>.</string>
```

Or add an `Fonts provided by application` entry:
```xml
<key>UIAppFonts</key>
<array>
    <string>RetroGaming.ttf</string>
</array>
```

**Step 4: Verify font loads**

Create a quick test in SwiftUI:
```swift
Text("Test").font(.custom("RetroGaming", size: 14))
```

**Step 5: Commit**

```bash
git add Epistemos/Resources/RetroGaming.ttf Epistemos/Info.plist
git commit -m "feat: bundle RetroGaming.ttf pixel font for dialogue UI"
```

---

### Task 7: Create DialogueChatState (Swift)

**Files:**
- Create: `Epistemos/State/DialogueChatState.swift`

**Step 1: Create the state class**

Model after NoteChatState (at `State/NoteChatState.swift`) but simplified for graph node dialogue:

```swift
import Foundation

/// Manages AI chat for the FFT-style graph dialogue box.
/// One shared instance — only one dialogue active at a time.
@MainActor @Observable
final class DialogueChatState {

    struct Message: Identifiable {
        let id = UUID()
        let role: Role
        var text: String

        enum Role { case user, assistant }
    }

    // MARK: - Public State

    var messages: [Message] = []
    var inputText = ""
    var isStreaming = false
    var activeNodeId: String?
    var activeNodeLabel: String = ""
    var revealedCharCount: Int = 0

    // MARK: - Callbacks

    /// Called when streaming starts/stops — drives mouth animation via FFI.
    var onStreamingChanged: ((Bool) -> Void)?

    // MARK: - Private

    private var streamingTask: Task<Void, Never>?
    private var pendingTokens = ""
    private var flushTask: Task<Void, Never>?
    private var typewriterTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func open(nodeId: String, label: String) {
        if activeNodeId == nodeId { return } // already open on this node
        activeNodeId = nodeId
        activeNodeLabel = label
        messages = []
        inputText = ""
        isStreaming = false
        revealedCharCount = 0

        // Greeting message
        messages.append(Message(role: .assistant, text: "What's up?"))
        startTypewriter()
    }

    func close() {
        streamingTask?.cancel()
        flushTask?.cancel()
        typewriterTask?.cancel()
        activeNodeId = nil
        isStreaming = false
    }

    // MARK: - Query

    func submitQuery(
        noteBody: String,
        linkedNodeLabels: [String],
        triageService: TriageService,
        llmService: LLMService
    ) {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        inputText = ""

        messages.append(Message(role: .user, text: query))
        messages.append(Message(role: .assistant, text: ""))
        revealedCharCount = 0

        let systemPrompt = buildSystemPrompt(noteBody: noteBody, linkedNodeLabels: linkedNodeLabels)

        isStreaming = true
        onStreamingChanged?(true)

        streamingTask = Task { [weak self] in
            do {
                let stream = triageService.stream(
                    prompt: query,
                    systemPrompt: systemPrompt,
                    operation: .ask(query: query),
                    contentLength: noteBody.count,
                    query: query
                )
                for try await chunk in stream {
                    self?.appendStreamingText(chunk)
                }
                self?.flushTokens()
            } catch {
                if !Task.isCancelled {
                    self?.messages[self!.messages.count - 1].text += "\n[Error: \(error.localizedDescription)]"
                }
            }
            self?.isStreaming = false
            self?.onStreamingChanged?(false)
        }
    }

    // MARK: - Token Buffering (60ms, same as NoteChatState)

    private func appendStreamingText(_ text: String) {
        pendingTokens += text
        if pendingTokens.utf8.count > 65_536 {
            flushTokens()
            return
        }
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            self?.flushTokens()
        }
    }

    private func flushTokens() {
        flushTask?.cancel()
        flushTask = nil
        guard !pendingTokens.isEmpty else { return }
        let delta = pendingTokens
        pendingTokens = ""
        guard !messages.isEmpty else { return }
        messages[messages.count - 1].text += delta
        startTypewriter()
    }

    // MARK: - Typewriter Animation (~30 chars/sec)

    private func startTypewriter() {
        typewriterTask?.cancel()
        let totalChars = messages.last?.text.count ?? 0
        guard revealedCharCount < totalChars else { return }
        typewriterTask = Task { [weak self] in
            while let self, self.revealedCharCount < (self.messages.last?.text.count ?? 0) {
                self.revealedCharCount += 1
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(noteBody: String, linkedNodeLabels: [String]) -> String {
        """
        You are "\(activeNodeLabel)", a character in a knowledge graph.
        Your personality comes from your content:

        --- CONTENT ---
        \(noteBody.prefix(50_000))
        --- END ---

        You speak in character. Be playful and helpful.
        Your connections: \(linkedNodeLabels.joined(separator: ", "))
        The user is your creator. Help them learn and remember your content.
        Keep responses concise (2-3 sentences unless asked for more).
        """
    }
}
```

**Step 2: Run Swift build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

**Step 3: Commit**

```bash
git add Epistemos/State/DialogueChatState.swift
git commit -m "feat: add DialogueChatState for graph node AI chat

Per-node AI personality from note content. 60ms token buffering.
Typewriter reveal animation at ~30 chars/sec."
```

---

### Task 8: Create DialogueOverlayView (Swift)

**Files:**
- Create: `Epistemos/Views/Graph/DialogueOverlayView.swift`

**Step 1: Create the overlay view**

```swift
import SwiftUI

/// SwiftUI overlay positioned over the Metal-rendered dialogue box.
/// Uses RetroGaming.ttf for the authentic FFT dialogue aesthetic.
struct DialogueOverlayView: View {
    @Bindable var chatState: DialogueChatState
    var screenRect: CGRect  // from FFI: dialogue box screen position
    var onSubmit: (String) -> Void
    var onDismiss: () -> Void

    @FocusState private var inputFocused: Bool

    private let retroFont = Font.custom("RetroGaming", size: 13)
    private let retroFontSmall = Font.custom("RetroGaming", size: 11)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Nameplate
            Text(chatState.activeNodeLabel)
                .font(retroFontSmall)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(chatState.messages.enumerated()), id: \.element.id) { index, message in
                            messageView(message, isLast: index == chatState.messages.count - 1)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .onChange(of: chatState.messages.count) {
                    if let last = chatState.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // Input field
            HStack(spacing: 4) {
                Text(">")
                    .font(retroFont)
                    .foregroundStyle(.white.opacity(0.6))
                TextField("", text: $chatState.inputText)
                    .font(retroFont)
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .onSubmit {
                        onSubmit(chatState.inputText)
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(width: screenRect.width - 4, height: screenRect.height - 4)
        .position(x: screenRect.midX, y: screenRect.midY)
        .onAppear { inputFocused = true }
        .onExitCommand { onDismiss() }
    }

    @ViewBuilder
    private func messageView(_ message: DialogueChatState.Message, isLast: Bool) -> some View {
        let displayText: String = {
            if isLast && message.role == .assistant && chatState.revealedCharCount < message.text.count {
                return String(message.text.prefix(chatState.revealedCharCount))
            }
            return message.text
        }()

        Text(displayText)
            .font(retroFont)
            .foregroundStyle(message.role == .user ? .cyan : .white)
            .id(message.id)
    }
}
```

**Step 2: Run Swift build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

**Step 3: Commit**

```bash
git add Epistemos/Views/Graph/DialogueOverlayView.swift
git commit -m "feat: add DialogueOverlayView with RetroGaming.ttf

SwiftUI overlay positioned over Metal dialogue box.
Typewriter text reveal, scrolling chat, pixel font input."
```

---

### Task 9: Wire Dialogue into MetalGraphView + HologramOverlay (Swift)

Connect node selection to the dialogue system.

**Files:**
- Modify: `Epistemos/Views/Graph/MetalGraphView.swift` (add dialogue FFI calls)
- Modify: `Epistemos/Views/Graph/HologramOverlay.swift` (add DialogueOverlayView)
- Modify: `Epistemos/App/AppEnvironment.swift` (add DialogueChatState to environment)

**Step 1: Add DialogueChatState to AppEnvironment**

In `AppEnvironment.swift`, add `dialogueChatState` as a shared instance:

```swift
let dialogueChatState = DialogueChatState()
```

Wire it through `withAppEnvironment()`.

**Step 2: Update MetalGraphView mouseUp()**

In `mouseUp()` (around line 841), after setting `graphState.selectNode(uuid)`:

```swift
// If dialogue theme and node selected, open dialogue
if graphState.visualTheme == .dialogue, let uuid {
    if let engine {
        uuid.withCString { cstr in
            graph_engine_dialogue_open(engine, cstr)
        }
    }
    let label = graphState.store.nodes[uuid]?.label ?? "Unknown"
    dialogueChatState.open(nodeId: uuid, label: label)
} else if graphState.visualTheme == .dialogue {
    // Clicked background — close dialogue
    if let engine {
        graph_engine_dialogue_close(engine)
    }
    dialogueChatState.close()
}
```

**Step 3: Add dialogue screen rect reading to render loop**

In `renderFrame()`, after `graph_engine_render()`, read the dialogue rect:

```swift
if graph_engine_dialogue_is_active(engine) != 0 {
    var rect: [Float] = [0, 0, 0, 0]
    graph_engine_dialogue_screen_rect(engine, &rect)
    dialogueScreenRect = CGRect(
        x: CGFloat(rect[0]),
        y: CGFloat(rect[1]),
        width: CGFloat(rect[2]),
        height: CGFloat(rect[3])
    )
} else {
    dialogueScreenRect = .zero
}
```

Add `@Published var dialogueScreenRect: CGRect = .zero` to the NSView or pass via a binding.

**Step 4: Wire streaming callback**

```swift
dialogueChatState.onStreamingChanged = { [weak self] streaming in
    guard let engine = self?.engine else { return }
    graph_engine_dialogue_set_streaming(engine, streaming ? 1 : 0)
}
```

**Step 5: Add DialogueOverlayView to HologramOverlay**

In `HologramOverlay.swift`, overlay the dialogue view when active:

```swift
if graphState.visualTheme == .dialogue,
   dialogueChatState.activeNodeId != nil,
   dialogueScreenRect != .zero
{
    DialogueOverlayView(
        chatState: dialogueChatState,
        screenRect: dialogueScreenRect,
        onSubmit: { query in
            let noteBody = loadNoteBody(for: dialogueChatState.activeNodeId)
            let linked = graphState.store.linkedNodeLabels(for: dialogueChatState.activeNodeId ?? "")
            dialogueChatState.submitQuery(
                noteBody: noteBody,
                linkedNodeLabels: linked,
                triageService: triageService,
                llmService: llmService
            )
        },
        onDismiss: {
            graph_engine_dialogue_close(engine)
            dialogueChatState.close()
        }
    )
}
```

**Step 6: Build and test**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

**Step 7: Commit**

```bash
git add -A Epistemos/
git commit -m "feat(graph): wire dialogue system into selection flow

Node selection opens dialogue box when Dialogue theme active.
DialogueOverlayView positioned via FFI screen rect.
Streaming state drives mouth animation via FFI."
```

---

### Task 10: Integration Testing and Polish

**Files:**
- Modify: Various (fix compilation issues, adjust positioning)
- Test: Manual testing of full flow

**Step 1: Run full test suite**

```bash
cd graph-engine && cargo test 2>&1 | tail -5
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | tail -20
```

**Step 2: Manual testing checklist**

- [ ] Switch to Dialogue theme via floating controls
- [ ] Click a node → face appears (eyes + mouth)
- [ ] Dialogue box renders (dark blue gradient, white border, tail)
- [ ] DialogueOverlayView appears with RetroGaming.ttf text
- [ ] Type a message → submit → AI streams response
- [ ] Typewriter animation reveals text progressively
- [ ] Mouth oscillates during streaming
- [ ] Click background → dialogue dismisses
- [ ] Switch back to Classic theme → dialogue system inactive
- [ ] Eyes blink every ~3 seconds
- [ ] Box repositions when node moves (physics)
- [ ] Box stays on-screen when near viewport edges

**Step 3: Fix issues found during testing**

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat(graph): dialogue theme integration polish

Fix positioning, edge cases, and visual refinements
from manual testing."
```
