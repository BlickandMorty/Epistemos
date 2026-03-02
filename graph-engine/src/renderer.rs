use std::ffi::c_void;

use metal::foreign_types::ForeignType;
use metal::*;
use objc::rc::autoreleasepool;

use crate::types::{Graph, edge_type_color};

// Direct Objective-C runtime call — avoids macro import issues with Rust 2024 edition.
unsafe extern "C" {
    fn objc_retain(obj: *mut c_void) -> *mut c_void;
}

// ── GPU data structs (must match Metal shader layouts) ──────────────────────

/// Per-instance data for node rendering (SDF circle with depth).
#[repr(C)]
#[derive(Clone, Copy)]
struct NodeInstance {
    position: [f32; 2], // offset 0
    radius: f32,        // offset 8
    z: f32,             // offset 12 — depth for perspective/parallax
    color: [f32; 4],    // offset 16
}

/// Per-instance data for straight-line edge rendering.
#[repr(C)]
#[derive(Clone, Copy)]
struct LineEdgeInstance {
    p0: [f32; 2],     // offset 0
    p1: [f32; 2],     // offset 8
    color: [f32; 4],  // offset 16
}

/// Uniform data sent to all shaders (camera transform + animation).
#[repr(C)]
#[derive(Clone, Copy)]
struct Uniforms {
    viewport_size: [f32; 2],
    camera_offset: [f32; 2],
    camera_zoom: f32,
    time: f32,               // elapsed seconds — drives breathing animation
    _pad1: [f32; 2],         // was: ripple_origin (removed)
    _pad_ripple: f32,        // was: ripple_time (removed)
    focal_length: f32,       // perspective focal distance (2.0 default)
    camera_velocity: [f32; 2], // camera offset delta (world units/frame)
    zoom_velocity: f32,        // zoom delta per frame (for motion blur)
    lite_mode: f32,            // 0.0 = cinematic, 1.0 = balanced, 2.0 = performance
}

/// Compute z-depth from link count using 3 discrete tiers (Observatory layered planes).
/// Background (1-2 links) → -0.25, Midground (3-8 links) → 0.0, Foreground (9+ links) → 0.35.
/// Quantized tiers produce clean parallax layers like a star chart diorama.
fn z_for_link_count(link_count: u32) -> f32 {
    match link_count {
        0..=2 => -0.40,   // Background: leaf nodes recede deeper
        3..=5 => -0.10,   // Lower-mid: slightly behind
        6..=8 => 0.12,    // Upper-mid: slightly forward
        _ => 0.50,         // Foreground: hub nodes closest to viewer
    }
}

/// Highlighted edge color: brighter accent.
const EDGE_HIGHLIGHT_COLOR: [f32; 4] = [0.65, 0.85, 1.00, 0.6];
/// Dimmed node alpha when highlight is active (used in shader via flag buffer).
#[allow(dead_code)]
const DIM_ALPHA: f32 = 0.12;
/// Dimmed edge alpha when highlight is active.
const EDGE_DIM_ALPHA: f32 = 0.05;

/// Evaluate a quadratic bezier at parameter t in [0, 1].
/// Retained for field-line tessellation only (edges are now straight lines).
fn bezier_point(p0: [f32; 2], cp: [f32; 2], p1: [f32; 2], t: f32) -> [f32; 2] {
    let s = 1.0 - t;
    [
        s * s * p0[0] + 2.0 * s * t * cp[0] + t * t * p1[0],
        s * s * p0[1] + 2.0 * s * t * cp[1] + t * t * p1[1],
    ]
}

// ── Metal Shader Source ─────────────────────────────────────────────────────

const SHADER_SOURCE: &str = r#"
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float2 viewport_size;
    float2 camera_offset;
    float camera_zoom;
    float time;
    float2 _pad1;
    float _pad_ripple;
    float focal_length;
    float2 camera_velocity;
    float zoom_velocity;
    float lite_mode;   // 0.0 = cinematic, 1.0 = balanced, 2.0 = performance
};

// ── Node shaders (instanced circles with depth perspective) ──────────

struct NodeInstance {
    float2 position;
    float  radius;
    float  z;       // depth: positive = closer, negative = farther
    float4 color;
};

struct NodeVertexOut {
    float4 position [[position]];
    float4 color;
    float2 uv;
    float  depth;
    float  highlight_dim;  // 1.0 = normal, DIM_ALPHA = dimmed
    float  is_lite;        // 1.0 = lite mode, 0.0 = full mode
};

vertex NodeVertexOut node_vertex(
    uint vertex_id [[vertex_id]],
    uint instance_id [[instance_id]],
    constant NodeInstance* instances [[buffer(0)]],
    constant Uniforms& uniforms [[buffer(1)]],
    constant uchar* highlight_flags [[buffer(2)]]
) {
    float2 corners[6] = {
        float2(-1, -1), float2( 1, -1), float2(-1,  1),
        float2(-1,  1), float2( 1, -1), float2( 1,  1)
    };

    NodeInstance inst = instances[instance_id];
    float2 corner = corners[vertex_id];

    float depth;
    float effective_radius;
    if (uniforms.lite_mode > 1.5) {
        // Performance: flat 2D, no breathing, no perspective.
        depth = 0.0;
        effective_radius = inst.radius;
    } else if (uniforms.lite_mode > 0.5) {
        // Balanced: sphere shading but no breathing/perspective animation.
        // Use static depth for z-ordering only (no animated parallax).
        depth = inst.z;
        effective_radius = inst.radius;
    } else {
        // Cinematic: breathing animation + perspective depth.
        float breath_speed = inst.z > 0.2 ? 0.7 : (inst.z > -0.1 ? 0.5 : 0.3);
        float breath = sin(uniforms.time * breath_speed + float(instance_id) * 2.39996) * 0.18;
        depth = inst.z + breath;
        float perspective_scale = uniforms.focal_length / (uniforms.focal_length - depth);
        effective_radius = inst.radius * perspective_scale;
    }

    float2 base_pos = inst.position;
    float2 world_pos = base_pos + corner * effective_radius;

    float2 screen = (world_pos - uniforms.camera_offset) * uniforms.camera_zoom;
    float2 ndc = screen / (uniforms.viewport_size * 0.5) * float2(1, -1);
    float ndc_z = 0.5 - depth * 0.1;

    // Highlight flags: 0 = normal, 1 = highlighted (boosted), 2+ = dimmed (flag/255).
    uchar flag = highlight_flags[instance_id];
    float highlight_dim = flag == 0 ? 1.0 : (flag == 1 ? 1.35 : (float(flag) / 255.0));

    NodeVertexOut out;
    out.position = float4(ndc, ndc_z, 1.0);
    out.color = inst.color;
    out.uv = corner;
    out.depth = depth;
    out.highlight_dim = highlight_dim;
    out.is_lite = uniforms.lite_mode;
    return out;
}

fragment float4 node_fragment(NodeVertexOut in [[stage_in]]) {
    float dist = length(in.uv);

    if (in.highlight_dim < 0.001) discard_fragment();

    // ── Performance: flat colored circle, ~3 ALU ops ──
    if (in.is_lite > 1.5) {
        float alpha = 1.0 - smoothstep(0.85, 1.0, dist);
        if (alpha < 0.01) discard_fragment();
        return float4(in.color.rgb, in.color.a * alpha * in.highlight_dim);
    }

    // ── Balanced + Cinematic: pixel art + sphere shading ──
    float pixel_strength = 0.6;
    float grid = 12.0;
    float2 quv = floor(in.uv * grid + 0.5) / grid;
    float2 final_uv = mix(in.uv, quv, pixel_strength);
    float qdist = length(final_uv);

    float smooth_alpha = 1.0 - smoothstep(0.85, 1.0, dist);
    float pixel_alpha = qdist < 0.92 ? 1.0 : 0.0;
    float alpha = mix(smooth_alpha, pixel_alpha, pixel_strength);
    if (alpha < 0.01) discard_fragment();

    float r2 = dot(final_uv, final_uv);
    float nz = sqrt(max(1.0 - r2, 0.0));

    float3 light_dir = normalize(float3(-0.35, -0.5, 0.8));
    float3 normal = float3(final_uv.x, final_uv.y, nz);
    float diffuse = max(dot(normal, light_dir), 0.0);
    float lighting = 0.45 + 0.55 * diffuse;

    float bands = 4.0;
    float stepped_lighting = floor(lighting * bands + 0.5) / bands;
    lighting = mix(lighting, stepped_lighting, pixel_strength);

    float3 view_dir = float3(0, 0, 1);
    float3 half_vec = normalize(light_dir + view_dir);
    float spec = pow(max(dot(normal, half_vec), 0.0), 32.0);

    float2 grid_pos = floor(in.uv * grid + 0.5);
    bool checker = fmod(grid_pos.x + grid_pos.y, 2.0) < 1.0;
    float pixel_spec = (spec > 0.3 && checker) ? 0.4 : 0.0;
    spec = mix(spec * 0.3, pixel_spec, pixel_strength);

    float rim = 1.0 - nz;
    float rim_glow = pow(rim, 3.0) * 0.35;
    float3 lit_color = in.color.rgb * lighting + spec + in.color.rgb * rim_glow;

    // Balanced: no depth-of-field fade (all nodes same opacity).
    // Cinematic: far nodes fade slightly for depth effect.
    float depth_fade = (in.is_lite < 0.5 && in.depth < -0.1) ? 0.65 : 1.0;
    float edge_softness = (in.is_lite < 0.5 && in.depth < -0.1) ? 0.75 : 0.85;
    float dof_alpha = 1.0 - smoothstep(edge_softness, 1.0, dist);
    float final_alpha = mix(dof_alpha, alpha, pixel_strength);

    return float4(lit_color, in.color.a * final_alpha * depth_fade * in.highlight_dim);
}

// ── Straight-line edge shaders ─────────────────────────────────────

struct LineEdgeInstance {
    float2 p0;
    float2 p1;
    float4 color;
};

struct LineVertexOut {
    float4 position [[position]];
    float4 color [[flat]];
    float  dist_from_center;
};

vertex LineVertexOut line_edge_vertex(
    uint vertex_id [[vertex_id]],
    uint instance_id [[instance_id]],
    constant LineEdgeInstance* instances [[buffer(0)]],
    constant Uniforms& u [[buffer(1)]]
) {
    LineEdgeInstance inst = instances[instance_id];

    float2 screen0 = (inst.p0 - u.camera_offset) * u.camera_zoom;
    float2 ndc0 = screen0 / (u.viewport_size * 0.5) * float2(1, -1);
    float2 screen1 = (inst.p1 - u.camera_offset) * u.camera_zoom;
    float2 ndc1 = screen1 / (u.viewport_size * 0.5) * float2(1, -1);

    // Direction and perpendicular in NDC space — constant screen-pixel width.
    float2 dir = ndc1 - ndc0;
    float len = length(dir);
    if (len < 0.00001) dir = float2(1, 0);
    else dir /= len;

    float2 perp = float2(-dir.y, dir.x);

    // 1.5px constant screen width: NDC offset = pixels * (2.0 / viewport_size).
    float2 pixel_to_ndc = 2.0 / u.viewport_size;
    float half_width_px = 0.75;
    float2 offset = perp * half_width_px * pixel_to_ndc;

    // Expand quad in NDC: 6 vertices = 2 triangles per segment.
    float2 base_ndc[6] = {
        ndc0 - offset, ndc0 + offset,
        ndc1 - offset, ndc1 - offset,
        ndc0 + offset, ndc1 + offset,
    };

    float dist_vals[6] = { -1, 1, -1, -1, 1, 1 };

    LineVertexOut out;
    out.position = float4(base_ndc[vertex_id], 0.0, 1.0);
    out.color = inst.color;
    out.dist_from_center = dist_vals[vertex_id];
    return out;
}

fragment float4 line_edge_fragment(LineVertexOut in [[stage_in]]) {
    float alpha = 1.0 - smoothstep(0.6, 1.0, abs(in.dist_from_center));
    if (alpha < 0.01) discard_fragment();
    return float4(in.color.rgb, in.color.a * alpha);
}

"#;

// ── Highlight State ─────────────────────────────────────────────────────────

/// Neighbor highlight state for shift+click.
pub struct HighlightState {
    /// Set of node IDs that should be highlighted (root + neighbors).
    pub highlighted_ids: rustc_hash::FxHashSet<u32>,
    /// Whether highlighting is active.
    pub active: bool,
}

impl Default for HighlightState {
    fn default() -> Self {
        Self::new()
    }
}

impl HighlightState {
    pub fn new() -> Self {
        Self {
            highlighted_ids: rustc_hash::FxHashSet::default(),
            active: false,
        }
    }
}

// ── Renderer ────────────────────────────────────────────────────────────────

pub struct Renderer {
    device: Device,
    command_queue: CommandQueue,
    layer: MetalLayer,
    node_pipeline: RenderPipelineState,
    edge_pipeline: RenderPipelineState,
    node_instance_buf: Option<Buffer>,
    edge_instance_buf: Option<Buffer>,
    uniform_buf: Buffer,
    node_instance_capacity: usize,
    edge_instance_capacity: usize,
    // Camera state
    pub camera_offset: [f32; 2],
    pub camera_zoom: f32,
    pub target_offset: [f32; 2],
    pub target_zoom: f32,
    pub is_animating: bool,
    last_frame_time: std::time::Instant,
    // Counts (buffer layout: [glow_count glows] [node_count nodes] [highlight_count rings])
    glow_count: usize,
    node_count: usize,
    edge_instance_count: usize,
    highlight_count: usize,
    // Highlight
    pub highlight: HighlightState,
    // Per-instance highlight flag buffer (one u8 per instance: 0=normal, non-zero=dim factor×255).
    highlight_flag_buf: Option<Buffer>,
    highlight_flag_capacity: usize,
    // Magnetic field lines (hover interaction).
    field_line_buf: Option<Buffer>,
    pub(crate) field_line_count: usize,
    field_line_capacity: usize,
    field_line_hovered_id: Option<u32>,
    // Reusable scratch buffer for field line segments (avoids per-frame allocation).
    field_line_scratch: Vec<LineEdgeInstance>,
    // Reusable highlight flag vector (avoids per-frame allocation).
    highlight_flag_scratch: Vec<u8>,
    // Background clear color (transparent for hologram overlay)
    pub clear_color: [f64; 4],
    // Quality level: 0 = Cinematic (full effects), 1 = Balanced (sphere shading, no animation),
    // 2 = Performance (flat circles, no effects). Replaces binary lite_mode.
    pub quality_level: u8,
    // Epoch for elapsed time tracking.
    pub start_time: std::time::Instant,
    // Previous-frame camera state (retained for future effects / velocity computation).
    #[allow(dead_code)]
    prev_camera_zoom: f32,
    #[allow(dead_code)]
    prev_camera_offset: [f32; 2],
}

impl Renderer {
    #[inline]
    fn node_color(&self, node_type: &crate::types::NodeType) -> [f32; 4] {
        node_type.color()
    }

    pub fn new(device_ptr: *mut c_void, layer_ptr: *mut c_void) -> Option<Self> {
        if device_ptr.is_null() || layer_ptr.is_null() {
            return None;
        }

        let device: Device = unsafe {
            let dev_ref: &DeviceRef = &*(device_ptr as *const DeviceRef);
            dev_ref.to_owned()
        };

        let layer: MetalLayer = unsafe {
            let l = MetalLayer::from_ptr(layer_ptr as *mut _);
            objc_retain(layer_ptr);
            l
        };

        layer.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
        layer.set_device(&device);

        let command_queue = device.new_command_queue();

        let library = device
            .new_library_with_source(SHADER_SOURCE, &CompileOptions::new())
            .ok()?;

        let node_vert = library.get_function("node_vertex", None).ok()?;
        let node_frag = library.get_function("node_fragment", None).ok()?;
        let edge_vert = library.get_function("line_edge_vertex", None).ok()?;
        let edge_frag = library.get_function("line_edge_fragment", None).ok()?;

        // Helper to create a pipeline with alpha blending.
        // Returns None if pipeline creation fails (e.g. incompatible GPU).
        let make_pipeline =
            |vert: &Function, frag: &Function| -> Option<RenderPipelineState> {
                let desc = RenderPipelineDescriptor::new();
                desc.set_vertex_function(Some(vert));
                desc.set_fragment_function(Some(frag));
                let color_attach = desc.color_attachments().object_at(0)?;
                color_attach.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
                color_attach.set_blending_enabled(true);
                color_attach.set_source_rgb_blend_factor(MTLBlendFactor::SourceAlpha);
                color_attach.set_destination_rgb_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
                color_attach.set_source_alpha_blend_factor(MTLBlendFactor::One);
                color_attach.set_destination_alpha_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
                device.new_render_pipeline_state(&desc).ok()
            };

        let node_pipeline = make_pipeline(&node_vert, &node_frag)?;
        let edge_pipeline = make_pipeline(&edge_vert, &edge_frag)?;

        let uniform_buf = device.new_buffer(
            std::mem::size_of::<Uniforms>() as u64,
            MTLResourceOptions::StorageModeShared,
        );

        Some(Self {
            device,
            command_queue,
            layer,
            node_pipeline,
            edge_pipeline,
            node_instance_buf: None,
            edge_instance_buf: None,
            uniform_buf,
            node_instance_capacity: 0,
            edge_instance_capacity: 0,
            camera_offset: [0.0, 0.0],
            camera_zoom: 1.0,
            target_offset: [0.0, 0.0],
            target_zoom: 1.0,
            is_animating: false,
            last_frame_time: std::time::Instant::now(),
            glow_count: 0,
            node_count: 0,
            edge_instance_count: 0,
            highlight_count: 0,
            highlight: HighlightState::new(),
            highlight_flag_buf: None,
            highlight_flag_capacity: 0,
            highlight_flag_scratch: Vec::new(),
            field_line_buf: None,
            field_line_count: 0,
            field_line_capacity: 0,
            field_line_hovered_id: None,
            field_line_scratch: Vec::new(),
            clear_color: [0.07, 0.07, 0.09, 1.0],
            quality_level: 0,  // Cinematic by default
            start_time: std::time::Instant::now(),
            prev_camera_zoom: 1.0,
            prev_camera_offset: [0.0, 0.0],
        })
    }

    /// Pre-allocate GPU buffers with headroom. Call once after commit.
    /// +2 for highlight rings, +hub_count for glow instances.
    pub fn allocate_buffers(&mut self, graph: &Graph, entrance: Option<&[crate::engine::EntranceNodeState]>) {
        let hub_count = graph.nodes.iter().filter(|n| n.visible && n.link_count >= 9).count();
        let confidence_glow_count = graph.nodes.iter().filter(|n| n.visible && n.confidence > 0.0).count();
        let node_count = graph.nodes.len() + 2 + hub_count + confidence_glow_count;
        let edge_count = graph.edges.len();

        if node_count > self.node_instance_capacity || self.node_instance_buf.is_none() {
            let capacity = (node_count * 3 / 2).max(64);
            let buf_size = (capacity * std::mem::size_of::<NodeInstance>()) as u64;
            self.node_instance_buf = Some(
                self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.node_instance_capacity = capacity;
        }

        if edge_count > self.edge_instance_capacity || self.edge_instance_buf.is_none() {
            let capacity = (edge_count * 3 / 2).max(64);
            let buf_size = (capacity * std::mem::size_of::<LineEdgeInstance>()) as u64;
            self.edge_instance_buf = Some(
                self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.edge_instance_capacity = capacity;
        }

        self.upload_graph(graph, entrance);
    }

    /// Full upload of graph data to GPU buffers.
    /// `entrance`: optional per-node entrance animation state (z-offset, alpha, spiral displacement).
    pub fn upload_graph(&mut self, graph: &Graph, entrance: Option<&[crate::engine::EntranceNodeState]>) {
        // Hub glow instances go first (rendered behind regular nodes via NDC z).
        let mut glow_instances: Vec<NodeInstance> = Vec::new();
        let mut instances: Vec<NodeInstance> = Vec::with_capacity(graph.nodes.len());

        for (gi, node) in graph.nodes.iter().enumerate() {
            if !node.visible { continue; }
            let mut color = self.node_color(&node.node_type);
            // Highlight dimming is handled by the GPU via highlight_flag_buf (buffer(2)).
            // Colors are always at full alpha here.

            // Performance: flat 2D (z=0), no entrance offsets, no glow.
            let is_performance = self.quality_level >= 2;
            let is_cinematic = self.quality_level == 0;
            let mut z = if is_performance { 0.0 } else { z_for_link_count(node.link_count) };
            let mut pos = [node.x, node.y];

            // Apply entrance animation offsets (z-depth, alpha, spiral displacement).
            // Available in Cinematic and Balanced modes.
            if !is_performance {
                if let Some(ent) = entrance {
                    if let Some(state) = ent.get(gi) {
                        z += state.z_offset;
                        color[3] *= state.alpha;
                        pos[0] += state.dx;
                        pos[1] += state.dy;
                    }
                }
            }

            // Glow effects: only in Cinematic mode (not Balanced or Performance).
            if is_cinematic {
                // Hub glow: foreground nodes (9+ links) get a faint radial glow behind them.
                if node.link_count >= 9 {
                    let glow_alpha = 0.08;
                    let ent_alpha = entrance
                        .and_then(|e| e.get(gi))
                        .map_or(1.0, |s| s.alpha);
                    glow_instances.push(NodeInstance {
                        position: pos,
                        radius: node.radius * 4.0,
                        z: z - 0.15,
                        color: [color[0], color[1], color[2], glow_alpha * ent_alpha],
                    });
                }

                // Confidence glow: nodes with confidence > 0 get a soft radial glow.
                if node.confidence > 0.0 {
                    let conf = node.confidence.clamp(0.0, 1.0);
                    let glow_radius = node.radius * (2.0 + conf * 2.0);
                    let glow_alpha = 0.04 + conf * 0.21;
                    let ent_alpha = entrance
                        .and_then(|e| e.get(gi))
                        .map_or(1.0, |s| s.alpha);
                    glow_instances.push(NodeInstance {
                        position: pos,
                        radius: glow_radius,
                        z: z - 0.12,
                        color: [color[0], color[1], color[2], glow_alpha * ent_alpha],
                    });
                }
            }

            instances.push(NodeInstance {
                position: pos,
                radius: node.radius,
                z,
                color,
            });
        }

        // Glow instances first (behind), then regular nodes (in front).
        let mut all_instances = glow_instances;
        self.glow_count = all_instances.len();
        all_instances.extend(instances);

        self.node_count = all_instances.len() - self.glow_count;
        let total_node_instances = all_instances.len();
        if total_node_instances == 0 {
            self.node_instance_buf = None;
            self.edge_instance_buf = None;
            self.edge_instance_count = 0;
            return;
        }

        // Re-allocate node buffer if too small (graph grew since last allocate_buffers).
        // +2 for highlight ring instances appended by set_highlights().
        if total_node_instances + 2 > self.node_instance_capacity || self.node_instance_buf.is_none() {
            let capacity = ((total_node_instances + 2) * 3 / 2).max(64);
            let buf_size = (capacity * std::mem::size_of::<NodeInstance>()) as u64;
            self.node_instance_buf = Some(
                self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.node_instance_capacity = capacity;
        }

        // Write node data into pre-allocated buffer in-place.
        if let Some(buf) = &self.node_instance_buf {
            unsafe {
                std::ptr::copy_nonoverlapping(
                    all_instances.as_ptr(),
                    buf.contents() as *mut NodeInstance,
                    total_node_instances,
                );
            }
        }

        // Straight-line edge instances (one LineEdgeInstance per edge).
        // During entrance, edges only appear when both endpoints have mostly arrived.
        let mut edge_instances: Vec<LineEdgeInstance> =
            Vec::with_capacity(graph.edges.len());

        for edge in &graph.edges {
            let si = graph.id_to_index.get(&edge.source);
            let ti = graph.id_to_index.get(&edge.target);
            if let (Some(&si), Some(&ti)) = (si, ti) {
                let src = &graph.nodes[si];
                let tgt = &graph.nodes[ti];
                if !src.visible || !tgt.visible { continue; }

                // Entrance edge reveal.
                let mut edge_alpha = 1.0f32;
                if let Some(ent) = entrance {
                    let src_a = ent.get(si).map_or(1.0, |s| s.alpha);
                    let tgt_a = ent.get(ti).map_or(1.0, |s| s.alpha);
                    let min_a = src_a.min(tgt_a);
                    if min_a < 0.7 { continue; }
                    edge_alpha = ((min_a - 0.7) / 0.3).clamp(0.0, 1.0);
                }

                // Edge type color: use semantic color based on edge type.
                let base_edge = edge_type_color(edge.edge_type);
                let mut color = if self.highlight.active {
                    let src_lit = self.highlight.highlighted_ids.contains(&src.id);
                    let tgt_lit = self.highlight.highlighted_ids.contains(&tgt.id);
                    if src_lit && tgt_lit {
                        EDGE_HIGHLIGHT_COLOR
                    } else {
                        [base_edge[0], base_edge[1], base_edge[2], EDGE_DIM_ALPHA]
                    }
                } else {
                    base_edge
                };
                color[3] *= edge_alpha;

                // Apply entrance displacement to endpoints.
                let mut p0 = [src.x, src.y];
                let mut p1 = [tgt.x, tgt.y];
                if let Some(ent) = entrance {
                    if let Some(s) = ent.get(si) {
                        p0[0] += s.dx;
                        p0[1] += s.dy;
                    }
                    if let Some(s) = ent.get(ti) {
                        p1[0] += s.dx;
                        p1[1] += s.dy;
                    }
                }

                edge_instances.push(LineEdgeInstance { p0, p1, color });
            }
        }

        self.edge_instance_count = edge_instances.len();

        if self.edge_instance_count > 0 {
            // Re-allocate edge buffer if too small.
            if self.edge_instance_count > self.edge_instance_capacity || self.edge_instance_buf.is_none() {
                let capacity = (self.edge_instance_count * 3 / 2).max(64);
                let buf_size = (capacity * std::mem::size_of::<LineEdgeInstance>()) as u64;
                self.edge_instance_buf = Some(
                    self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
                );
                self.edge_instance_capacity = capacity;
            }

            // Write edge data into pre-allocated buffer in-place.
            if let Some(buf) = &self.edge_instance_buf {
                unsafe {
                    std::ptr::copy_nonoverlapping(
                        edge_instances.as_ptr(),
                        buf.contents() as *mut LineEdgeInstance,
                        self.edge_instance_count,
                    );
                }
            }
        } else {
            self.edge_instance_buf = None;
        }
    }

    /// Update positions in-place (called every frame after sync_positions).
    /// Buffer layout: [glow_count glows] [node_count nodes] [highlight rings].
    /// `entrance`: optional per-node entrance states for wormhole animation.
    pub fn update_positions(&mut self, graph: &Graph, entrance: Option<&[crate::engine::EntranceNodeState]>) {
        let mut visible_count = 0usize;
        let mut glow_idx = 0usize;
        if let Some(buf) = &self.node_instance_buf {
            unsafe {
                let ptr = buf.contents() as *mut NodeInstance;
                for (gi, node) in graph.nodes.iter().enumerate() {
                    if !node.visible { continue; }

                    let mut pos = [node.x, node.y];
                    let mut z = z_for_link_count(node.link_count);
                    let mut ent_alpha = 1.0f32;

                    // Apply entrance offsets.
                    if let Some(ent) = entrance {
                        if let Some(state) = ent.get(gi) {
                            z += state.z_offset;
                            ent_alpha = state.alpha;
                            pos[0] += state.dx;
                            pos[1] += state.dy;
                        }
                    }

                    // Update glow instances (hub glow + confidence glow).
                    // Highlight dimming handled by GPU via highlight_flag_buf.
                    if node.link_count >= 9 && glow_idx < self.glow_count {
                        let glow = &mut *ptr.add(glow_idx);
                        glow.position = pos;
                        glow.z = z - 0.1;
                        let base_glow = 0.08;
                        glow.color[3] = base_glow * ent_alpha;
                        glow_idx += 1;
                    }
                    if node.confidence > 0.0 && glow_idx < self.glow_count {
                        let conf = node.confidence.clamp(0.0, 1.0);
                        let glow = &mut *ptr.add(glow_idx);
                        glow.position = pos;
                        glow.z = z - 0.05;
                        let base_alpha = 0.04 + conf * 0.10;
                        glow.color[3] = base_alpha * ent_alpha;
                        glow_idx += 1;
                    }

                    // Update regular node instance (offset past glow instances).
                    let inst = &mut *ptr.add(self.glow_count + visible_count);
                    inst.position = pos;
                    inst.z = z;

                    // Colors at full alpha — highlight dimming via GPU flag buffer.
                    let mut color = self.node_color(&node.node_type);
                    color[3] *= ent_alpha;
                    inst.color = color;

                    visible_count += 1;
                }
            }
        }
        self.glow_count = glow_idx;
        self.node_count = visible_count;

        if self.node_count == 0 {
            self.edge_instance_count = 0;
            return;
        }

        // Update straight-line edge positions in-place.
        // During entrance, edges fade in as both endpoints arrive.
        if let Some(buf) = &self.edge_instance_buf {
            let mut inst_idx = 0usize;
            unsafe {
                let ptr = buf.contents() as *mut LineEdgeInstance;
                for edge in &graph.edges {
                    let si = graph.id_to_index.get(&edge.source);
                    let ti = graph.id_to_index.get(&edge.target);
                    if let (Some(&si), Some(&ti)) = (si, ti) {
                        let src = &graph.nodes[si];
                        let tgt = &graph.nodes[ti];
                        if !src.visible || !tgt.visible { continue; }

                        // Entrance edge reveal: skip edges where endpoints haven't arrived.
                        let mut edge_alpha = 1.0f32;
                        if let Some(ent) = entrance {
                            let src_a = ent.get(si).map_or(1.0, |s| s.alpha);
                            let tgt_a = ent.get(ti).map_or(1.0, |s| s.alpha);
                            let min_a = src_a.min(tgt_a);
                            if min_a < 0.7 { continue; } // both endpoints must be mostly arrived
                            edge_alpha = ((min_a - 0.7) / 0.3).clamp(0.0, 1.0);
                        }

                        // Edge type color: use semantic color based on edge type.
                        let base_edge = edge_type_color(edge.edge_type);
                        let hi_edge = EDGE_HIGHLIGHT_COLOR;
                        let dim_edge_alpha = EDGE_DIM_ALPHA;

                        let mut color = if self.highlight.active {
                            let src_lit = self.highlight.highlighted_ids.contains(&src.id);
                            let tgt_lit = self.highlight.highlighted_ids.contains(&tgt.id);
                            if src_lit && tgt_lit {
                                hi_edge
                            } else {
                                [base_edge[0], base_edge[1], base_edge[2], dim_edge_alpha]
                            }
                        } else {
                            base_edge
                        };
                        color[3] *= edge_alpha;

                        // Apply entrance displacement to edge endpoints.
                        let mut p0 = [src.x, src.y];
                        let mut p1 = [tgt.x, tgt.y];
                        if let Some(ent) = entrance {
                            if let Some(s) = ent.get(si) {
                                p0[0] += s.dx;
                                p0[1] += s.dy;
                            }
                            if let Some(s) = ent.get(ti) {
                                p1[0] += s.dx;
                                p1[1] += s.dy;
                            }
                        }

                        // Bounds check: during entrance, more edges may become visible
                        // than were allocated in upload_graph(). Clamp to capacity.
                        if inst_idx >= self.edge_instance_capacity { break; }

                        let inst = &mut *ptr.add(inst_idx);
                        inst.p0 = p0;
                        inst.p1 = p1;
                        inst.color = color;
                        inst_idx += 1;
                    }
                }
            }
            self.edge_instance_count = inst_idx;
        } else {
            self.edge_instance_count = 0;
        }
    }

    /// Append highlight ring instances after glow + regular node instances.
    pub fn set_highlights(&mut self, selected: Option<u32>, hovered: Option<u32>, graph: &Graph) {
        let Some(buf) = &self.node_instance_buf else { return };
        let ptr = buf.contents() as *mut NodeInstance;
        let mut idx = self.glow_count + self.node_count;
        let capacity = self.node_instance_capacity;

        if idx < capacity
            && let Some(sel_id) = selected
            && let Some(&gi) = graph.id_to_index.get(&sel_id)
            && let Some(node) = graph.nodes.get(gi)
            && node.visible
        {
            let color = self.node_color(&node.node_type);
            unsafe {
                *ptr.add(idx) = NodeInstance {
                    position: [node.x, node.y],
                    radius: node.radius + 6.0,
                    z: z_for_link_count(node.link_count),
                    color: [color[0], color[1], color[2], 0.6],
                };
            }
            idx += 1;
        }

        if idx < capacity
            && let Some(hov_id) = hovered
            && Some(hov_id) != selected
            && let Some(&gi) = graph.id_to_index.get(&hov_id)
            && let Some(node) = graph.nodes.get(gi)
            && node.visible
        {
            unsafe {
                *ptr.add(idx) = NodeInstance {
                    position: [node.x, node.y],
                    radius: node.radius + 2.0,
                    z: z_for_link_count(node.link_count),
                    color: [1.0, 1.0, 1.0, 0.2],
                };
            }
            idx += 1;
        }

        self.highlight_count = idx - self.glow_count - self.node_count;
    }

    /// Rebuild the per-instance highlight flag buffer.
    /// Called every frame — cheap (N bytes) and ensures highlight changes are always visible,
    /// even when physics is settled and update_positions isn't running.
    pub fn rebuild_highlight_flags(&mut self, graph: &Graph) {
        let total = self.glow_count + self.node_count + self.highlight_count;
        if total == 0 { return; }

        // Encode dim factor: 0 = normal (1.0), non-zero = dim (value/255).
        // DIM_ALPHA (0.12) → 31, glow dim (DIM_ALPHA * 0.4 ≈ 0.05) → 13.
        const NODE_DIM: u8 = 31;   // 0.12 * 255 ≈ 31
        const GLOW_DIM: u8 = 13;   // glow dim factor ≈ 0.05

        // Reuse pre-allocated scratch buffer (avoids heap allocation every frame).
        self.highlight_flag_scratch.clear();
        self.highlight_flag_scratch.reserve(total);

        if self.highlight.active {
            // Glow flags — must mirror update_positions exactly: cap at self.glow_count.
            // Without this cap, visibility/link_count changes would misalign the flag buffer
            // with the instance buffer, causing the wrong node to get highlighted.
            // Flag encoding: 0 = normal, 1 = highlighted (boosted), GLOW_DIM/NODE_DIM = dimmed.
            let mut glow_flags = 0usize;
            for node in graph.nodes.iter().filter(|n| n.visible) {
                let lit = self.highlight.highlighted_ids.contains(&node.id);
                if node.link_count >= 9 && glow_flags < self.glow_count {
                    self.highlight_flag_scratch.push(if lit { 1 } else { GLOW_DIM });
                    glow_flags += 1;
                }
                if node.confidence > 0.0 && glow_flags < self.glow_count {
                    self.highlight_flag_scratch.push(if lit { 1 } else { GLOW_DIM });
                    glow_flags += 1;
                }
            }
            // Pad or truncate to exactly glow_count (safety net).
            self.highlight_flag_scratch.resize(self.glow_count, 0);

            // Regular node flags: 1 = highlighted (bright), NODE_DIM = dimmed
            for node in graph.nodes.iter().filter(|n| n.visible) {
                let lit = self.highlight.highlighted_ids.contains(&node.id);
                self.highlight_flag_scratch.push(if lit { 1 } else { NODE_DIM });
            }
        } else {
            // No highlight — all normal
            self.highlight_flag_scratch.resize(self.glow_count + self.node_count, 0);
        }

        // Highlight rings — never dimmed
        for _ in 0..self.highlight_count {
            self.highlight_flag_scratch.push(0);
        }

        // Upload to GPU buffer
        let needed = self.highlight_flag_scratch.len();
        if needed > self.highlight_flag_capacity || self.highlight_flag_buf.is_none() {
            let capacity = (needed * 3 / 2).max(64);
            self.highlight_flag_buf = Some(
                self.device.new_buffer(capacity as u64, MTLResourceOptions::StorageModeShared),
            );
            self.highlight_flag_capacity = capacity;
        }
        if let Some(buf) = &self.highlight_flag_buf {
            unsafe {
                std::ptr::copy_nonoverlapping(
                    self.highlight_flag_scratch.as_ptr(),
                    buf.contents() as *mut u8,
                    needed,
                );
            }
        }
    }

    /// Generate magnetic field lines for a hovered node.
    /// Creates 2-3 bezier curves per neighbor, slightly offset, for a field-line fan effect.
    /// Lines are rendered using the existing edge shader.
    pub fn update_field_lines(&mut self, hovered: Option<u32>, graph: &Graph, time: f32) {
        if hovered == self.field_line_hovered_id && hovered.is_some() {
            // Same node still hovered — just update positions with time animation.
            if hovered.is_none() { return; }
        }
        self.field_line_hovered_id = hovered;

        let Some(hov_id) = hovered else {
            self.field_line_count = 0;
            return;
        };

        // O(1) lookup via id_to_index instead of O(N) linear scan.
        let Some(&hov_idx) = graph.id_to_index.get(&hov_id) else {
            self.field_line_count = 0;
            return;
        };
        let hov_node = &graph.nodes[hov_idx];
        if !hov_node.visible {
            self.field_line_count = 0;
            return;
        }

        let hov_pos = [hov_node.x, hov_node.y];
        let hov_color = self.node_color(&hov_node.node_type);
        let field_color = [hov_color[0], hov_color[1], hov_color[2], 0.12];

        // Reuse scratch buffer for field line segments.
        self.field_line_scratch.clear();
        const FIELD_LINES_PER_NEIGHBOR: usize = 3;
        const FIELD_SEGMENTS: usize = 6;

        // Find neighbors — scan edges for this node.
        for edge in &graph.edges {
            let neighbor_id = if edge.source == hov_id {
                edge.target
            } else if edge.target == hov_id {
                edge.source
            } else {
                continue;
            };

            // O(1) lookup instead of O(N) linear scan.
            let Some(&n_idx) = graph.id_to_index.get(&neighbor_id) else { continue; };
            let neighbor = &graph.nodes[n_idx];
            if !neighbor.visible { continue; }

            let n_pos = [neighbor.x, neighbor.y];
            let dx = n_pos[0] - hov_pos[0];
            let dy = n_pos[1] - hov_pos[1];
            let dist = (dx * dx + dy * dy).sqrt().max(1.0);
            let px = -dy / dist;
            let py = dx / dist;

            // Generate multiple field lines with different offsets.
            for line_i in 0..FIELD_LINES_PER_NEIGHBOR {
                let offset_t = (line_i as f32 - 1.0) * dist * 0.15;
                let shimmer = (time * 0.8 + line_i as f32 * 1.5).sin() * dist * 0.04;
                let cp_offset = offset_t + shimmer;

                let cp = [
                    (hov_pos[0] + n_pos[0]) * 0.5 + px * cp_offset,
                    (hov_pos[1] + n_pos[1]) * 0.5 + py * cp_offset,
                ];

                let mut prev = hov_pos;
                for seg in 1..=FIELD_SEGMENTS {
                    let t = seg as f32 / FIELD_SEGMENTS as f32;
                    let next = bezier_point(hov_pos, cp, n_pos, t);
                    self.field_line_scratch.push(LineEdgeInstance {
                        p0: prev,
                        p1: next,
                        color: field_color,
                    });
                    prev = next;
                }
            }
        }

        self.field_line_count = self.field_line_scratch.len();
        if self.field_line_count > 0 {
            if self.field_line_count > self.field_line_capacity || self.field_line_buf.is_none() {
                let capacity = (self.field_line_count * 3 / 2).max(64);
                let buf_size = (capacity * std::mem::size_of::<LineEdgeInstance>()) as u64;
                self.field_line_buf = Some(
                    self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
                );
                self.field_line_capacity = capacity;
            }
            if let Some(buf) = &self.field_line_buf {
                unsafe {
                    std::ptr::copy_nonoverlapping(
                        self.field_line_scratch.as_ptr(),
                        buf.contents() as *mut LineEdgeInstance,
                        self.field_line_count,
                    );
                }
            }
        }
    }

    /// Camera smoothing factor. Higher = faster. 3.0 = gentle cinematic glide.
    const CAMERA_LAMBDA: f32 = 3.0;

    pub fn update_camera(&mut self) {
        let now = std::time::Instant::now();
        let dt = (now - self.last_frame_time).as_secs_f32().min(0.1);
        self.last_frame_time = now;

        if !self.is_animating {
            return;
        }

        let t = 1.0 - (-Self::CAMERA_LAMBDA * dt).exp();

        self.camera_offset[0] += (self.target_offset[0] - self.camera_offset[0]) * t;
        self.camera_offset[1] += (self.target_offset[1] - self.camera_offset[1]) * t;
        self.camera_zoom += (self.target_zoom - self.camera_zoom) * t;

        let dx = self.target_offset[0] - self.camera_offset[0];
        let dy = self.target_offset[1] - self.camera_offset[1];
        let offset_diff = (dx * dx + dy * dy).sqrt();
        let zoom_diff = (self.target_zoom - self.camera_zoom).abs();
        if offset_diff < 0.1 && zoom_diff < 0.001 {
            self.camera_offset = self.target_offset;
            self.camera_zoom = self.target_zoom;
            self.is_animating = false;
        }
    }

    pub fn draw(&mut self, viewport_width: u32, viewport_height: u32) {
        autoreleasepool(|| {
            let drawable = match self.layer.next_drawable() {
                Some(d) => d,
                None => return,
            };

            let uniforms = Uniforms {
                viewport_size: [viewport_width as f32, viewport_height as f32],
                camera_offset: self.camera_offset,
                camera_zoom: self.camera_zoom,
                time: self.start_time.elapsed().as_secs_f32(),
                _pad1: [0.0, 0.0],
                _pad_ripple: -1.0,
                focal_length: 2.0,
                camera_velocity: [0.0, 0.0],
                zoom_velocity: 0.0,
                lite_mode: self.quality_level as f32,
            };
            unsafe {
                let ptr = self.uniform_buf.contents() as *mut Uniforms;
                *ptr = uniforms;
            }

            // Render directly to drawable texture (no offscreen pass).
            let render_desc = RenderPassDescriptor::new();
            let Some(color) = render_desc.color_attachments().object_at(0) else {
                return;
            };
            color.set_texture(Some(drawable.texture()));
            color.set_load_action(MTLLoadAction::Clear);
            color.set_clear_color(MTLClearColor::new(
                self.clear_color[0],
                self.clear_color[1],
                self.clear_color[2],
                self.clear_color[3],
            ));
            color.set_store_action(MTLStoreAction::Store);

            let cmd_buf = self.command_queue.new_command_buffer();
            let encoder = cmd_buf.new_render_command_encoder(render_desc);

            // Draw edges first (behind nodes)
            if self.edge_instance_count > 0
                && let Some(inst_buf) = &self.edge_instance_buf
            {
                encoder.set_render_pipeline_state(&self.edge_pipeline);
                encoder.set_vertex_buffer(0, Some(inst_buf), 0);
                encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                encoder.draw_primitives_instanced(
                    MTLPrimitiveType::Triangle,
                    0,
                    6,
                    self.edge_instance_count as u64,
                );
            }

            // Draw magnetic field lines (hover interaction, between edges and nodes).
            if self.field_line_count > 0
                && let Some(fl_buf) = &self.field_line_buf
            {
                encoder.set_render_pipeline_state(&self.edge_pipeline);
                encoder.set_vertex_buffer(0, Some(fl_buf), 0);
                encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                encoder.draw_primitives_instanced(
                    MTLPrimitiveType::Triangle,
                    0,
                    6,
                    self.field_line_count as u64,
                );
            }

            // Draw nodes: glow instances + regular nodes + highlight rings.
            let total_instances = self.glow_count + self.node_count + self.highlight_count;
            if total_instances > 0
                && let Some(inst_buf) = &self.node_instance_buf
            {
                encoder.set_render_pipeline_state(&self.node_pipeline);
                encoder.set_vertex_buffer(0, Some(inst_buf), 0);
                encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                // Bind highlight flag buffer (buffer(2)). If not yet allocated,
                // allocate a zero-filled default buffer so the shader reads 0 (normal).
                if self.highlight_flag_buf.is_none() {
                    let cap = total_instances.max(64);
                    let buf = self.device.new_buffer(cap as u64, MTLResourceOptions::StorageModeShared);
                    // Zero-fill (StorageModeShared is zero-initialized on macOS).
                    self.highlight_flag_buf = Some(buf);
                    self.highlight_flag_capacity = cap;
                }
                if let Some(flag_buf) = &self.highlight_flag_buf {
                    encoder.set_vertex_buffer(2, Some(flag_buf), 0);
                }
                encoder.draw_primitives_instanced(
                    MTLPrimitiveType::Triangle,
                    0,
                    6,
                    total_instances as u64,
                );
            }

            encoder.end_encoding();

            cmd_buf.present_drawable(drawable);
            cmd_buf.commit();
        });
    }
}
