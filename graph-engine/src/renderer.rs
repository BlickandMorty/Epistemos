use std::ffi::c_void;

use metal::foreign_types::ForeignType;
use metal::*;
use objc::rc::autoreleasepool;
use rustc_hash::FxHashMap;

use crate::ecs::World;
use crate::types::{VisualTheme, edge_type_color, edge_type_color_light};

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

/// State for the FFT-style dialogue box overlay.
#[derive(Clone)]
pub(crate) struct DialogueState {
    pub active: bool,
    pub node_index: Option<usize>,
    pub is_streaming: bool,
    /// Box rect in screen coords (x, y, w, h) for SwiftUI overlay.
    pub box_screen_rect: [f32; 4],
    /// Selected node center in screen coords.
    pub node_screen_pos: [f32; 2],
}

impl Default for DialogueState {
    fn default() -> Self {
        Self {
            active: false,
            node_index: None,
            is_streaming: false,
            box_screen_rect: [0.0; 4],
            node_screen_pos: [0.0; 2],
        }
    }
}

/// Per-vertex data for dialogue box rendering (position + color).
#[repr(C)]
#[derive(Clone, Copy)]
struct DialogueVertex {
    position: [f32; 2],
    color: [f32; 4],
}

/// Uniform data for dialogue shader (simpler than main uniforms).
#[repr(C)]
#[derive(Clone, Copy)]
struct DialogueUniforms {
    viewport_size: [f32; 2],
    camera_offset: [f32; 2],
    camera_zoom: f32,
    time: f32,
    _pad: [f32; 2],
}

const DIALOGUE_BOX_SCREEN_WIDTH: f32 = 280.0;
const DIALOGUE_BOX_SCREEN_HEIGHT: f32 = 160.0;
const DIALOGUE_TAIL_SCREEN_HEIGHT: f32 = 20.0;
const DIALOGUE_GAP_SCREEN: f32 = 10.0;

/// Uniform data sent to all shaders (camera transform + animation).
#[repr(C)]
#[derive(Clone, Copy)]
struct Uniforms {
    viewport_size: [f32; 2],
    camera_offset: [f32; 2],
    camera_zoom: f32,
    time: f32,               // elapsed seconds — drives breathing animation
    pulse_origin: [f32; 2],  // world-space origin of click pulse wave
    pulse_time: f32,         // time of pulse start (0 = no active pulse)
    focal_length: f32,       // perspective focal distance (2.0 default)
    camera_velocity: [f32; 2], // camera offset delta (world units/frame)
    zoom_velocity: f32,        // zoom delta per frame (for motion blur)
    lite_mode: f32,            // 0.0 = cinematic, 1.0 = balanced, 2.0 = performance
    impact_intensity: f32,     // 1.0 on heavy collision → 0.0 (chromatic aberration)
    _pad: f32,                 // pad to 64 bytes (Metal 16-byte struct alignment)
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct ViewBounds {
    min_x: f32,
    min_y: f32,
    max_x: f32,
    max_y: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct LodProfile {
    draw_edges: bool,
    draw_glow: bool,
    cluster_nodes: bool,
    edge_degree_threshold: u32,
    max_edges_per_node: u16,
}

#[derive(Clone, Copy, Debug, Default)]
struct DensityCluster {
    sum_x: f32,
    sum_y: f32,
    sum_vx: f32,
    sum_vy: f32,
    sum_color: [f32; 4],
    max_link_count: u32,
    count: u32,
}

pub(crate) fn viewport_bounds(
    camera_offset: [f32; 2],
    camera_zoom: f32,
    viewport_size: [f32; 2],
    padding: f32,
) -> ViewBounds {
    let zoom = camera_zoom.max(0.01);
    let half_w = viewport_size[0] * 0.5 / zoom + padding;
    let half_h = viewport_size[1] * 0.5 / zoom + padding;
    ViewBounds {
        min_x: camera_offset[0] - half_w,
        min_y: camera_offset[1] - half_h,
        max_x: camera_offset[0] + half_w,
        max_y: camera_offset[1] + half_h,
    }
}

pub(crate) fn lod_profile_for_zoom(_zoom: f32, quality_level: u8) -> LodProfile {
    match quality_level {
        0 => LodProfile {
            draw_edges: true,
            draw_glow: true,
            cluster_nodes: false,
            edge_degree_threshold: u32::MAX,
            max_edges_per_node: u16::MAX,
        },
        1 => LodProfile {
            draw_edges: true,
            draw_glow: false,
            cluster_nodes: false,
            edge_degree_threshold: u32::MAX,
            max_edges_per_node: u16::MAX,
        },
        _ => LodProfile {
            draw_edges: true,
            draw_glow: false,
            cluster_nodes: false,
            edge_degree_threshold: 36,
            max_edges_per_node: 10,
        },
    }
}

fn density_cell_size_world(zoom: f32) -> f32 {
    (48.0 / zoom.max(0.05)).clamp(72.0, 360.0)
}

fn density_proxy_screen_radius(count: u32) -> f32 {
    (6.0 + (count as f32).sqrt() * 2.5).clamp(6.0, 18.0)
}

pub(crate) fn bounds_intersects_circle(bounds: ViewBounds, center: [f32; 2], radius: f32) -> bool {
    center[0] + radius >= bounds.min_x
        && center[0] - radius <= bounds.max_x
        && center[1] + radius >= bounds.min_y
        && center[1] - radius <= bounds.max_y
}

pub(crate) fn segment_intersects_bounds(bounds: ViewBounds, p0: [f32; 2], p1: [f32; 2]) -> bool {
    let dx = p1[0] - p0[0];
    let dy = p1[1] - p0[1];
    if dx.abs() <= f32::EPSILON && dy.abs() <= f32::EPSILON {
        return p0[0] >= bounds.min_x
            && p0[0] <= bounds.max_x
            && p0[1] >= bounds.min_y
            && p0[1] <= bounds.max_y;
    }

    fn clip(p: f32, q: f32, t0: &mut f32, t1: &mut f32) -> bool {
        if p.abs() <= f32::EPSILON {
            return q >= 0.0;
        }

        let r = q / p;
        if p < 0.0 {
            if r > *t1 {
                return false;
            }
            if r > *t0 {
                *t0 = r;
            }
        } else if p > 0.0 {
            if r < *t0 {
                return false;
            }
            if r < *t1 {
                *t1 = r;
            }
        }
        true
    }

    let mut t0 = 0.0;
    let mut t1 = 1.0;
    clip(-dx, p0[0] - bounds.min_x, &mut t0, &mut t1)
        && clip(dx, bounds.max_x - p0[0], &mut t0, &mut t1)
        && clip(-dy, p0[1] - bounds.min_y, &mut t0, &mut t1)
        && clip(dy, bounds.max_y - p0[1], &mut t0, &mut t1)
        && t0 <= t1
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
const EDGE_HIGHLIGHT_COLOR: [f32; 4] = [0.70, 0.90, 1.00, 0.75];
/// Base alpha multiplier for all nodes — subtler ambient presence.
const BASE_NODE_ALPHA: f32 = 0.72;
/// Dimmed node alpha when highlight is active — near-ghost for unfocused nodes.
#[allow(dead_code)]
const DIM_ALPHA: f32 = 0.04;
/// Dimmed edge alpha when highlight is active.
const EDGE_DIM_ALPHA: f32 = 0.02;

/// Hot orange color for maximally stressed edges.
const TENSION_COLOR: [f32; 4] = [1.0, 0.3, 0.1, 0.8];
/// Stretch percentage at which edge reaches max tension color (50% = k_yield).
const TENSION_K_YIELD: f32 = 0.5;

// ── Glow constants (shared between upload_graph and update_positions) ─────
const HUB_GLOW_Z_OFFSET: f32 = -0.12;
const HUB_GLOW_ALPHA: f32 = 0.08;
const HUB_GLOW_RADIUS_FACTOR: f32 = 2.5;
const CONF_GLOW_Z_OFFSET: f32 = -0.06;
const CONF_GLOW_RADIUS_BASE: f32 = 1.5;
const CONF_GLOW_RADIUS_SCALE: f32 = 1.0;
const CONF_GLOW_ALPHA_BASE: f32 = 0.03;
const CONF_GLOW_ALPHA_SCALE: f32 = 0.08;

/// Evaluate a quadratic bezier at parameter t in [0, 1].
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
    float2 pulse_origin;
    float pulse_time;
    float focal_length;
    float2 camera_velocity;
    float zoom_velocity;
    float lite_mode;   // 0.0 = cinematic, 1.0 = balanced, 2.0 = performance
    float impact_intensity; // chromatic aberration on collision
    float _pad;             // 16-byte alignment padding
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
    float2 world_pos;      // world-space base position for pulse wave
};

vertex NodeVertexOut node_vertex(
    uint vertex_id [[vertex_id]],
    uint instance_id [[instance_id]],
    constant NodeInstance* instances [[buffer(0)]],
    constant Uniforms& uniforms [[buffer(1)]],
    constant uchar* highlight_flags [[buffer(2)]],
    constant float2* velocities [[buffer(3)]]
) {
    float2 corners[6] = {
        float2(-1, -1), float2( 1, -1), float2(-1,  1),
        float2(-1,  1), float2( 1, -1), float2( 1,  1)
    };

    NodeInstance inst = instances[instance_id];
    float2 corner = corners[vertex_id];

    // Squash & stretch: deform quad along velocity direction (cinematic only).
    float2 vel = velocities[instance_id];
    float speed = length(vel);
    if (uniforms.lite_mode < 0.5 && speed > 1.0) {
        float stretch_amount = min(speed * 0.002, 0.25);
        float2 dir = vel / speed;
        float2 perp = float2(-dir.y, dir.x);
        float stretch = 1.0 + stretch_amount;
        float compress = 1.0 / stretch;
        corner = dir * dot(corner, dir) * stretch + perp * dot(corner, perp) * compress;
    }

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
    float highlight_dim = flag == 0 ? 1.0 : (flag == 1 ? 1.50 : (float(flag) / 255.0));

    NodeVertexOut out;
    out.position = float4(ndc, ndc_z, 1.0);
    out.color = inst.color;
    out.uv = corner;
    out.depth = depth;
    out.highlight_dim = highlight_dim;
    out.is_lite = uniforms.lite_mode;
    out.world_pos = base_pos;
    return out;
}

fragment float4 node_fragment(
    NodeVertexOut in [[stage_in]],
    constant Uniforms& uniforms [[buffer(1)]]
) {
    float dist = length(in.uv);

    if (in.highlight_dim < 0.001) discard_fragment();

    // ── Glow instances: soft radial gradient, no sphere shading ──
    // Detected by low alpha (glow alpha is 0.03–0.11, regular nodes are 0.5+).
    if (in.color.a < 0.15) {
        float glow = 1.0 - smoothstep(0.0, 1.0, dist);
        glow = glow * glow; // Quadratic falloff for soft edge
        // Pulsing aura: phase offset by world position so hubs pulse independently.
        if (in.is_lite < 0.5) {
            glow *= 1.0 + 0.25 * sin(uniforms.time * 2.0 + length(in.world_pos) * 0.01);
        }
        if (glow < 0.01) discard_fragment();
        return float4(in.color.rgb, in.color.a * glow * in.highlight_dim);
    }

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

    // Anime outline: dark ring near SDF boundary.
    float outline = smoothstep(0.73, 0.75, dist) * (1.0 - smoothstep(0.85, 0.87, dist));
    lit_color *= (1.0 - outline * 0.6);

    // Balanced: no depth-of-field fade (all nodes same opacity).
    // Cinematic: far nodes fade slightly for depth effect.
    float depth_fade = (in.is_lite < 0.5 && in.depth < -0.1) ? 0.65 : 1.0;
    float edge_softness = (in.is_lite < 0.5 && in.depth < -0.1) ? 0.75 : 0.85;
    float dof_alpha = 1.0 - smoothstep(edge_softness, 1.0, dist);
    float final_alpha = mix(dof_alpha, alpha, pixel_strength);

    float3 result_color = lit_color;

    // ── Pulse wave glow ──
    // Expanding ring from pulse_origin. Cinematic only (skip in balanced/perf).
    if (in.is_lite < 0.5 && uniforms.pulse_time >= 0.0) {
        float wave_speed = 800.0; // world units per second
        float wave_radius = uniforms.pulse_time * wave_speed;
        float d_to_pulse = length(in.world_pos - uniforms.pulse_origin);
        float ring_dist = abs(d_to_pulse - wave_radius);
        float ring_width = 60.0 + wave_radius * 0.15; // wider as it expands
        float ring_glow = 1.0 - smoothstep(0.0, ring_width, ring_dist);
        float fade = 1.0 - smoothstep(0.0, 2.0, uniforms.pulse_time); // fade over 2s
        ring_glow *= fade * 0.4; // subtle additive glow
        result_color += ring_glow * float3(0.5, 0.8, 1.0); // cool blue-white
    }

    // ── Chromatic aberration on impact (cinematic only) ──
    if (in.is_lite < 0.5 && uniforms.impact_intensity > 0.0) {
        float ca = uniforms.impact_intensity * 0.12;
        result_color.r += ca * in.uv.x;
        result_color.b -= ca * in.uv.x;
    }

    return float4(result_color, in.color.a * final_alpha * depth_fade * in.highlight_dim);
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

const DIALOGUE_SHADER_SOURCE: &str = r#"
#include <metal_stdlib>
using namespace metal;

struct DialogueVertexIn {
    float2 position [[attribute(0)]];
    float4 color    [[attribute(1)]];
};

struct DialogueVertexOut {
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

vertex DialogueVertexOut dialogue_vertex(
    const device DialogueVertexIn* vertices [[buffer(0)]],
    constant DialogueUniforms& u [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    DialogueVertexOut out;
    // Vertices are already in world coords — apply camera transform.
    float2 wp = vertices[vid].position;
    float2 sp = (wp - u.camera_offset) * u.camera_zoom;
    sp.x =  sp.x / (u.viewport_size.x * 0.5);
    sp.y = -sp.y / (u.viewport_size.y * 0.5);
    out.position = float4(sp, 0.0, 1.0);
    out.color = vertices[vid].color;
    return out;
}

fragment float4 dialogue_fragment(DialogueVertexOut in [[stage_in]]) {
    return in.color;
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
    pub use_aggregated_edges: bool,
    aggregated_edge_count: usize,
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
    // Reusable culled render lists for Classic mode.
    rendered_node_indices: Vec<usize>,
    candidate_entities: Vec<u32>,
    edge_candidate_indices: Vec<usize>,
    edge_candidate_marks: Vec<u32>,
    edge_candidate_generation: u32,
    edge_budget_scratch: Vec<u16>,
    density_clusters: FxHashMap<(i32, i32), DensityCluster>,
    classic_node_scratch: Vec<NodeInstance>,
    classic_edge_scratch: Vec<LineEdgeInstance>,
    classic_velocity_scratch: Vec<[f32; 2]>,
    // Background clear color (transparent for hologram overlay)
    pub clear_color: [f64; 4],
    pub light_mode: bool,
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
    // Physics link distance for edge tension calculation.
    pub link_distance: f32,
    // Laboratory visual toggles + knobs.
    pub enable_elastic_edges: bool,
    pub enable_tension_coloring: bool,
    /// 0.0 = stiff/straight, 1.0 = maximum rubber-band curvature.
    pub edge_elasticity: f32,
    // Pulse wave state (set on mouse_down, decays over time).
    pub pulse_origin: [f32; 2],
    /// Elapsed time when pulse started (0 = no active pulse).
    pub pulse_start: f32,
    /// Impact intensity: 1.0 on heavy collision, decays to 0.0 over ~0.33s.
    pub impact_intensity: f32,
    // Per-instance velocity buffer for squash & stretch (parallel to node instance buffer).
    node_velocity_buf: Option<Buffer>,
    node_velocity_capacity: usize,
    // Wind advection particles (200 CPU-driven dots).
    wind_particles: Vec<[f32; 4]>, // [x, y, vx, vy]
    wind_active: bool,
    wind_particle_count: usize, // number of particles in the glow section
    pub wind_x: f32,
    pub wind_y: f32,
    wind_rng_state: u32, // Simple LCG for particle randomness
    // Cached viewport size for particle bounds (set in draw()).
    last_viewport_width: f32,
    last_viewport_height: f32,
    // ── Theme state ────────────────────────────────────────────────
    pub visual_theme: VisualTheme,
    // ── Dialogue box state ───────────────────────────────────────
    pub(crate) dialogue: DialogueState,
    dialogue_pipeline: Option<RenderPipelineState>,
    dialogue_vertex_buf: Option<Buffer>,
    dialogue_vertex_scratch: Vec<DialogueVertex>,
    dialogue_uniform_buf: Option<Buffer>,
}

impl Renderer {
    #[inline]
    fn node_color(&self, node_type: &crate::types::NodeType) -> [f32; 4] {
        if self.light_mode { node_type.color_light() } else { node_type.color() }
    }

    #[inline]
    fn node_color_for_u8(&self, node_type: u8) -> [f32; 4] {
        self.node_color(&crate::types::NodeType::from_u8(node_type))
    }

    #[inline]
    fn edge_color(&self, edge_type: u8) -> [f32; 4] {
        if self.light_mode { edge_type_color_light(edge_type) } else { edge_type_color(edge_type) }
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
            use_aggregated_edges: false,
            aggregated_edge_count: 0,
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
            rendered_node_indices: Vec::new(),
            candidate_entities: Vec::new(),
            edge_candidate_indices: Vec::new(),
            edge_candidate_marks: Vec::new(),
            edge_candidate_generation: 0,
            edge_budget_scratch: Vec::new(),
            density_clusters: FxHashMap::default(),
            classic_node_scratch: Vec::new(),
            classic_edge_scratch: Vec::new(),
            classic_velocity_scratch: Vec::new(),
            light_mode: false,
            clear_color: [0.07, 0.07, 0.09, 1.0],
            quality_level: 0,  // Cinematic by default
            start_time: std::time::Instant::now(),
            prev_camera_zoom: 1.0,
            prev_camera_offset: [0.0, 0.0],
            link_distance: 243.0,
            enable_elastic_edges: true,
            enable_tension_coloring: true,
            edge_elasticity: 0.5,
            pulse_origin: [0.0, 0.0],
            pulse_start: 0.0,
            impact_intensity: 0.0,
            node_velocity_buf: None,
            node_velocity_capacity: 0,
            wind_particles: Vec::new(),
            wind_active: false,
            wind_particle_count: 0,
            wind_x: 0.0,
            wind_y: 0.0,
            wind_rng_state: 12345,
            last_viewport_width: 0.0,
            last_viewport_height: 0.0,
            visual_theme: VisualTheme::Dialogue,
            dialogue: DialogueState::default(),
            dialogue_pipeline: None,
            dialogue_vertex_buf: None,
            dialogue_vertex_scratch: Vec::new(),
            dialogue_uniform_buf: None,
        })
    }

    const CLASSIC_CULL_PADDING_PIXELS: f32 = 160.0;

    pub fn set_viewport_size(&mut self, viewport_width: u32, viewport_height: u32) -> bool {
        let width = viewport_width as f32;
        let height = viewport_height as f32;
        let changed = (self.last_viewport_width - width).abs() > f32::EPSILON
            || (self.last_viewport_height - height).abs() > f32::EPSILON;
        self.last_viewport_width = width;
        self.last_viewport_height = height;
        changed
    }

    fn current_view_bounds(&self, padding_pixels: f32) -> Option<ViewBounds> {
        if self.last_viewport_width <= 0.0 || self.last_viewport_height <= 0.0 {
            return None;
        }
        let padding = padding_pixels / self.camera_zoom.max(0.05);
        Some(viewport_bounds(
            self.camera_offset,
            self.camera_zoom,
            [self.last_viewport_width, self.last_viewport_height],
            padding,
        ))
    }

    #[inline]
    fn node_in_view(
        &self,
        bounds: Option<ViewBounds>,
        center: [f32; 2],
        radius: f32,
    ) -> bool {
        bounds.is_none_or(|view| bounds_intersects_circle(view, center, radius))
    }

    #[inline]
    fn segment_in_view(
        &self,
        bounds: Option<ViewBounds>,
        p0: [f32; 2],
        p1: [f32; 2],
    ) -> bool {
        bounds.is_none_or(|view| segment_intersects_bounds(view, p0, p1))
    }

    fn collect_visible_node_indices<F>(
        &mut self,
        world: &World,
        bounds: Option<ViewBounds>,
        radius_for: F,
    ) where
        F: Fn(&World, usize) -> f32,
    {
        self.rendered_node_indices.clear();

        if let Some(view) = bounds {
            world.spatial_grid.query_bounds_into(
                view.min_x,
                view.min_y,
                view.max_x,
                view.max_y,
                &mut self.candidate_entities,
            );
            for &entity in &self.candidate_entities {
                let Some(index) = world.index_of(entity) else {
                    continue;
                };
                if world.graph_node[index].visible == 0 {
                    continue;
                }

                let position = [world.transform[index].x, world.transform[index].y];
                if self.node_in_view(Some(view), position, radius_for(world, index)) {
                    self.rendered_node_indices.push(index);
                }
            }
            self.rendered_node_indices.sort_unstable();
            self.rendered_node_indices.dedup();
            return;
        }

        self.rendered_node_indices.extend(
            (0..world.len()).filter(|&index| world.graph_node[index].visible != 0),
        );
    }

    fn collect_candidate_edges(&mut self, world: &World) {
        self.edge_candidate_indices.clear();
        if world.edges.is_empty() || self.rendered_node_indices.is_empty() {
            return;
        }

        if self.edge_candidate_marks.len() < world.edges.len() {
            self.edge_candidate_marks.resize(world.edges.len(), 0);
        }

        self.edge_candidate_generation = self.edge_candidate_generation.wrapping_add(1);
        if self.edge_candidate_generation == 0 {
            self.edge_candidate_marks.fill(0);
            self.edge_candidate_generation = 1;
        }
        let generation = self.edge_candidate_generation;

        for &node_index in &self.rendered_node_indices {
            for &edge_index in world.edge_indices_for_index(node_index) {
                if self.edge_candidate_marks[edge_index] == generation {
                    continue;
                }
                self.edge_candidate_marks[edge_index] = generation;
                self.edge_candidate_indices.push(edge_index);
            }
        }
    }

    fn reset_edge_lod_budget(&mut self, world: &World, lod: LodProfile) {
        if lod.max_edges_per_node == u16::MAX {
            return;
        }
        if self.edge_budget_scratch.len() < world.len() {
            self.edge_budget_scratch.resize(world.len(), 0);
        }
        self.edge_budget_scratch[..world.len()].fill(0);
    }

    fn edge_allowed_by_lod(
        &mut self,
        world: &World,
        lod: LodProfile,
        src_index: usize,
        tgt_index: usize,
    ) -> bool {
        if lod.edge_degree_threshold != u32::MAX
            && world.hierarchy[src_index].link_count >= lod.edge_degree_threshold
            && world.hierarchy[tgt_index].link_count >= lod.edge_degree_threshold
        {
            return false;
        }

        if lod.max_edges_per_node == u16::MAX {
            return true;
        }

        if src_index == tgt_index {
            let budget = &mut self.edge_budget_scratch[src_index];
            if *budget >= lod.max_edges_per_node {
                return false;
            }
            *budget += 1;
            return true;
        }

        let (low, high) = if src_index < tgt_index {
            (src_index, tgt_index)
        } else {
            (tgt_index, src_index)
        };
        let (left, right) = self.edge_budget_scratch.split_at_mut(high);
        let low_budget = &mut left[low];
        let high_budget = &mut right[0];
        if *low_budget >= lod.max_edges_per_node || *high_budget >= lod.max_edges_per_node {
            return false;
        }
        *low_budget += 1;
        *high_budget += 1;
        true
    }

    #[inline]
    fn classic_node_instance(&self, world: &World, node_index: usize) -> NodeInstance {
        let graph_node = &world.graph_node[node_index];
        let co = world.render[node_index].color_override;
        let mut color = if co[3] > 0.0 {
            co
        } else {
            self.node_color_for_u8(world.hierarchy[node_index].node_type)
        };
        color[3] *= BASE_NODE_ALPHA;
        let z = if self.quality_level >= 2 {
            0.0
        } else {
            z_for_link_count(world.hierarchy[node_index].link_count)
        };
        NodeInstance {
            position: [world.transform[node_index].x, world.transform[node_index].y],
            radius: graph_node.radius,
            z,
            color,
        }
    }

    #[inline]
    fn classic_edge_instance_color(
        &self,
        world: &World,
        edge: &crate::ecs::EdgeComponent,
        src_index: usize,
        tgt_index: usize,
        p0: [f32; 2],
        p1: [f32; 2],
    ) -> [f32; 4] {
        let base_edge = self.edge_color(edge.edge_type);
        if self.highlight.active {
            let src_lit = self.highlight.highlighted_ids.contains(&world.graph_node[src_index].node_id);
            let tgt_lit = self.highlight.highlighted_ids.contains(&world.graph_node[tgt_index].node_id);
            if src_lit && tgt_lit {
                EDGE_HIGHLIGHT_COLOR
            } else {
                [base_edge[0], base_edge[1], base_edge[2], EDGE_DIM_ALPHA]
            }
        } else if self.enable_tension_coloring {
            let dx = p1[0] - p0[0];
            let dy = p1[1] - p0[1];
            let dist = (dx * dx + dy * dy).sqrt();
            let ideal = self.link_distance / edge.weight.max(0.01);
            let stress = (((dist - ideal) / ideal).max(0.0) / TENSION_K_YIELD).min(1.0);
            let mut color = [
                base_edge[0] + stress * (TENSION_COLOR[0] - base_edge[0]),
                base_edge[1] + stress * (TENSION_COLOR[1] - base_edge[1]),
                base_edge[2] + stress * (TENSION_COLOR[2] - base_edge[2]),
                base_edge[3] + stress * (TENSION_COLOR[3] - base_edge[3]),
            ];
            color[3] *= BASE_NODE_ALPHA;
            color
        } else {
            let mut color = base_edge;
            color[3] *= BASE_NODE_ALPHA;
            color
        }
    }

    fn rebuild_classic_buffers(&mut self, world: &World) {
        let view_bounds = self.current_view_bounds(Self::CLASSIC_CULL_PADDING_PIXELS);
        let lod = lod_profile_for_zoom(self.camera_zoom, self.quality_level);
        self.collect_visible_node_indices(world, view_bounds, |world, index| {
            world.graph_node[index].radius
        });

        self.classic_node_scratch.clear();
        self.classic_velocity_scratch.clear();
        self.classic_edge_scratch.clear();

        if lod.cluster_nodes && !self.highlight.active {
            self.density_clusters.clear();
            let cell_size = density_cell_size_world(self.camera_zoom);
            let inv_cell = 1.0 / cell_size;

            for &node_index in &self.rendered_node_indices {
                let graph_node = &world.graph_node[node_index];
                let co = world.render[node_index].color_override;
                let mut color = if co[3] > 0.0 {
                    co
                } else {
                    self.node_color_for_u8(world.hierarchy[node_index].node_type)
                };
                color[3] *= BASE_NODE_ALPHA;

                let position = [world.transform[node_index].x, world.transform[node_index].y];
                let key = (
                    (position[0] * inv_cell).floor() as i32,
                    (position[1] * inv_cell).floor() as i32,
                );
                let cluster = self.density_clusters.entry(key).or_default();
                cluster.sum_x += position[0];
                cluster.sum_y += position[1];
                cluster.sum_vx += world.velocity[node_index].vx;
                cluster.sum_vy += world.velocity[node_index].vy;
                for (sum, channel) in cluster.sum_color.iter_mut().zip(color) {
                    *sum += channel;
                }
                cluster.max_link_count = cluster.max_link_count.max(world.hierarchy[node_index].link_count);
                cluster.count += 1;
                debug_assert!(graph_node.visible != 0);
            }

            self.glow_count = 0;
            self.wind_particle_count = 0;

            for cluster in self.density_clusters.values() {
                let inv_count = 1.0 / cluster.count as f32;
                let proxy_radius = density_proxy_screen_radius(cluster.count) / self.camera_zoom.max(0.05);
                let mut color = [0.0; 4];
                for (channel, sum) in color.iter_mut().zip(cluster.sum_color) {
                    *channel = sum * inv_count;
                }
                color[3] = (0.42 + (cluster.count as f32).ln_1p() * 0.10).min(0.88);

                self.classic_node_scratch.push(NodeInstance {
                    position: [cluster.sum_x * inv_count, cluster.sum_y * inv_count],
                    radius: proxy_radius,
                    z: z_for_link_count(cluster.max_link_count),
                    color,
                });
                self.classic_velocity_scratch.push([
                    cluster.sum_vx * inv_count,
                    cluster.sum_vy * inv_count,
                ]);
            }

            self.node_count = self.classic_node_scratch.len();
        } else {
            if lod.draw_glow {
                for &node_index in &self.rendered_node_indices {
                    let pos = [world.transform[node_index].x, world.transform[node_index].y];
                    let z = z_for_link_count(world.hierarchy[node_index].link_count);
                    let color = self.classic_node_instance(world, node_index).color;
                    let radius = world.graph_node[node_index].radius;
                    let confidence = world.graph_node[node_index].confidence;

                    if world.hierarchy[node_index].link_count >= 9 {
                        self.classic_node_scratch.push(NodeInstance {
                            position: pos,
                            radius: radius * HUB_GLOW_RADIUS_FACTOR,
                            z: z + HUB_GLOW_Z_OFFSET,
                            color: [color[0], color[1], color[2], HUB_GLOW_ALPHA],
                        });
                        self.classic_velocity_scratch.push([0.0, 0.0]);
                    }

                    if confidence > 0.0 {
                        let conf = confidence.clamp(0.0, 1.0);
                        let glow_radius = radius * (CONF_GLOW_RADIUS_BASE + conf * CONF_GLOW_RADIUS_SCALE);
                        let glow_alpha = CONF_GLOW_ALPHA_BASE + conf * CONF_GLOW_ALPHA_SCALE;
                        self.classic_node_scratch.push(NodeInstance {
                            position: pos,
                            radius: glow_radius,
                            z: z + CONF_GLOW_Z_OFFSET,
                            color: [color[0], color[1], color[2], glow_alpha],
                        });
                        self.classic_velocity_scratch.push([0.0, 0.0]);
                    }
                }
            }

            if lod.draw_glow && self.last_viewport_width > 0.0 && self.last_viewport_height > 0.0 {
                self.update_wind_particles([self.last_viewport_width, self.last_viewport_height], self.camera_zoom);
            } else {
                self.wind_particle_count = 0;
            }

            if lod.draw_glow && self.wind_active {
                for particle in &self.wind_particles {
                    self.classic_node_scratch.push(NodeInstance {
                        position: [particle[0], particle[1]],
                        radius: 1.5,
                        z: -0.50,
                        color: [0.7, 0.85, 1.0, 0.08],
                    });
                    self.classic_velocity_scratch.push([0.0, 0.0]);
                }
                self.wind_particle_count = self.wind_particles.len();
            } else {
                self.wind_particle_count = 0;
            }

            self.glow_count = self.classic_node_scratch.len();

            for &node_index in &self.rendered_node_indices {
                self.classic_node_scratch.push(self.classic_node_instance(world, node_index));
                self.classic_velocity_scratch.push([world.velocity[node_index].vx, world.velocity[node_index].vy]);
            }

            self.node_count = self.rendered_node_indices.len();
        }

        if lod.cluster_nodes {
            self.glow_count = 0;
        }

        // Face geometry: Kirby-style eyes + mouth on dialogue-active node.
        if self.dialogue.active {
            if let Some(node_idx) = self.dialogue.node_index {
                if node_idx < world.transform.len() {
                    let nx = world.transform[node_idx].x;
                    let ny = world.transform[node_idx].y;
                    let r = world.graph_node[node_idx].radius;
                    let eye_r = r * 0.12;
                    let eye_spacing = r * 0.28;
                    let eye_y = ny - r * 0.15;
                    let mouth_y = ny + r * 0.25;

                    let time = self.start_time.elapsed().as_secs_f32();
                    let blink_cycle = (time * 0.33).fract();
                    let eyes_visible = blink_cycle < 0.92 || blink_cycle > 0.96;

                    if eyes_visible {
                        self.classic_node_scratch.push(NodeInstance {
                            position: [nx - eye_spacing, eye_y],
                            radius: eye_r,
                            z: 0.99,
                            color: [1.0, 1.0, 1.0, 1.0],
                        });
                        self.classic_velocity_scratch.push([0.0, 0.0]);

                        self.classic_node_scratch.push(NodeInstance {
                            position: [nx + eye_spacing, eye_y],
                            radius: eye_r,
                            z: 0.99,
                            color: [1.0, 1.0, 1.0, 1.0],
                        });
                        self.classic_velocity_scratch.push([0.0, 0.0]);
                    }

                    let mouth_r = if self.dialogue.is_streaming {
                        eye_r * (0.6 + 0.4 * (time * 8.0).sin().abs())
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

        let total_node_instances = self.classic_node_scratch.len();

        if total_node_instances == 0 {
            self.node_instance_buf = None;
            self.edge_instance_buf = None;
            self.glow_count = 0;
            self.node_count = 0;
            self.highlight_count = 0;
            self.edge_instance_count = 0;
            return;
        }

        if total_node_instances + 2 > self.node_instance_capacity || self.node_instance_buf.is_none() {
            let capacity = ((total_node_instances + 2) * 3 / 2).max(64);
            let buf_size = (capacity * std::mem::size_of::<NodeInstance>()) as u64;
            self.node_instance_buf = Some(
                self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.node_instance_capacity = capacity;
        }

        if let Some(buf) = &self.node_instance_buf {
            unsafe {
                std::ptr::copy_nonoverlapping(
                    self.classic_node_scratch.as_ptr(),
                    buf.contents() as *mut NodeInstance,
                    total_node_instances,
                );
            }
        }

        let velocity_count = total_node_instances + 2;
        if velocity_count > self.node_velocity_capacity || self.node_velocity_buf.is_none() {
            let capacity = (velocity_count * 3 / 2).max(64);
            let buf_size = (capacity * std::mem::size_of::<[f32; 2]>()) as u64;
            self.node_velocity_buf = Some(
                self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.node_velocity_capacity = capacity;
        }

        if let Some(buf) = &self.node_velocity_buf {
            unsafe {
                let ptr = buf.contents() as *mut [f32; 2];
                std::ptr::copy_nonoverlapping(
                    self.classic_velocity_scratch.as_ptr(),
                    ptr,
                    self.classic_velocity_scratch.len(),
                );
                for index in self.classic_velocity_scratch.len()..velocity_count.min(self.node_velocity_capacity) {
                    *ptr.add(index) = [0.0, 0.0];
                }
            }
        }

        if lod.draw_edges && !lod.cluster_nodes {
            self.collect_candidate_edges(world);
            self.reset_edge_lod_budget(world, lod);
            for candidate_index in 0..self.edge_candidate_indices.len() {
                let edge_index = self.edge_candidate_indices[candidate_index];
                let edge = &world.edges[edge_index];
                let (Some(src_index), Some(tgt_index)) = (
                    world.index_of(edge.source),
                    world.index_of(edge.target),
                ) else {
                    continue;
                };
                if world.graph_node[src_index].visible == 0 || world.graph_node[tgt_index].visible == 0 {
                    continue;
                }

                let p0 = [world.transform[src_index].x, world.transform[src_index].y];
                let p1 = [world.transform[tgt_index].x, world.transform[tgt_index].y];
                if (p0[0] == 0.0 && p0[1] == 0.0) || (p1[0] == 0.0 && p1[1] == 0.0) {
                    continue;
                }
                if !p0[0].is_finite() || !p0[1].is_finite() || !p1[0].is_finite() || !p1[1].is_finite() {
                    continue;
                }
                if !self.edge_allowed_by_lod(world, lod, src_index, tgt_index) {
                    continue;
                }

                let src_in_view = self.node_in_view(view_bounds, p0, world.graph_node[src_index].radius);
                let tgt_in_view = self.node_in_view(view_bounds, p1, world.graph_node[tgt_index].radius);
                if view_bounds.is_some() && !(src_in_view || tgt_in_view) {
                    continue;
                }
                if !self.segment_in_view(view_bounds, p0, p1) {
                    continue;
                }

                self.classic_edge_scratch.push(LineEdgeInstance {
                    p0,
                    p1,
                    color: self.classic_edge_instance_color(world, edge, src_index, tgt_index, p0, p1),
                });
            }
        }

        self.edge_instance_count = self.classic_edge_scratch.len();
        if self.edge_instance_count > 0 {
            if self.edge_instance_count > self.edge_instance_capacity || self.edge_instance_buf.is_none() {
                let capacity = (self.edge_instance_count * 3 / 2).max(64);
                let buf_size = (capacity * std::mem::size_of::<LineEdgeInstance>()) as u64;
                self.edge_instance_buf = Some(
                    self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
                );
                self.edge_instance_capacity = capacity;
            }

            if let Some(buf) = &self.edge_instance_buf {
                unsafe {
                    std::ptr::copy_nonoverlapping(
                        self.classic_edge_scratch.as_ptr(),
                        buf.contents() as *mut LineEdgeInstance,
                        self.edge_instance_count,
                    );
                }
            }
        } else {
            self.edge_instance_buf = None;
        }
    }

    pub fn upload_aggregated_edges(&mut self, edges: &[crate::edge_aggregation::AggregatedEdge]) {
        self.use_aggregated_edges = !edges.is_empty();
        self.aggregated_edge_count = edges.len();
        if edges.is_empty() {
            return;
        }

        if edges.len() > self.edge_instance_capacity || self.edge_instance_buf.is_none() {
            let capacity = (edges.len() * 3 / 2).max(64);
            let buf_size = (capacity * std::mem::size_of::<LineEdgeInstance>()) as u64;
            self.edge_instance_buf = Some(
                self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.edge_instance_capacity = capacity;
        }

        let base_rgb = if self.light_mode {
            [0.22, 0.25, 0.30]
        } else {
            [0.78, 0.82, 0.88]
        };

        if let Some(buf) = &self.edge_instance_buf {
            unsafe {
                let ptr = buf.contents() as *mut LineEdgeInstance;
                for (index, edge) in edges.iter().enumerate() {
                    *ptr.add(index) = LineEdgeInstance {
                        p0: edge.p0,
                        p1: edge.p1,
                        color: [base_rgb[0], base_rgb[1], base_rgb[2], edge.alpha],
                    };
                }
            }
        }
    }

    pub fn clear_aggregated_edges(&mut self) {
        self.use_aggregated_edges = false;
        self.aggregated_edge_count = 0;
    }

    /// Pre-allocate GPU buffers with headroom. Call once after commit.
    /// +2 for highlight rings, +hub_count for glow instances.
    pub fn allocate_buffers(&mut self, world: &World) {
        let hub_count = (0..world.len())
            .filter(|&index| world.graph_node[index].visible != 0 && world.hierarchy[index].link_count >= 9)
            .count();
        let confidence_glow_count = (0..world.len())
            .filter(|&index| world.graph_node[index].visible != 0 && world.graph_node[index].confidence > 0.0)
            .count();
        let node_count = world.len() + 2 + hub_count + confidence_glow_count;
        let edge_count = world.edges.len();

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

        self.upload_graph(world);
    }

    /// Simple LCG random: returns float in [-1, 1].
    fn rand_float(&mut self) -> f32 {
        self.wind_rng_state = self.wind_rng_state.wrapping_mul(1103515245).wrapping_add(12345);
        (self.wind_rng_state >> 16) as f32 / 32768.0 - 1.0
    }

    /// Update wind advection particles. Called each frame from update_positions.
    fn update_wind_particles(&mut self, viewport: [f32; 2], zoom: f32) {
        const PARTICLE_COUNT: usize = 200;

        if self.wind_x.abs() < 0.1 && self.wind_y.abs() < 0.1 {
            self.wind_active = false;
            return;
        }
        self.wind_active = true;

        // Initialize particles on first activation.
        if self.wind_particles.len() < PARTICLE_COUNT {
            self.wind_particles.clear();
            let half_w = viewport[0] / (2.0 * zoom.max(0.01));
            let half_h = viewport[1] / (2.0 * zoom.max(0.01));
            for _ in 0..PARTICLE_COUNT {
                let x = self.camera_offset[0] + self.rand_float() * half_w;
                let y = self.camera_offset[1] + self.rand_float() * half_h;
                self.wind_particles.push([x, y, 0.0, 0.0]);
            }
        }

        let dt = 1.0 / 60.0;
        let half_w = viewport[0] / (2.0 * zoom.max(0.01));
        let half_h = viewport[1] / (2.0 * zoom.max(0.01));
        let cx = self.camera_offset[0];
        let cy = self.camera_offset[1];

        for p in &mut self.wind_particles {
            p[2] += (self.wind_x * 0.8 - p[2]) * 0.1;
            p[3] += (self.wind_y * 0.8 - p[3]) * 0.1;
            p[0] += p[2] * dt;
            p[1] += p[3] * dt;
            if p[0] < cx - half_w * 1.3 || p[0] > cx + half_w * 1.3
            || p[1] < cy - half_h * 1.3 || p[1] > cy + half_h * 1.3 {
                // Respawn within viewport.
                // Use self.wind_rng_state for deterministic randomness.
                let state = &mut (p[0].to_bits() ^ p[1].to_bits() ^ 0xDEAD_BEEF);
                *state = state.wrapping_mul(1103515245).wrapping_add(12345);
                let rx = (*state >> 16) as f32 / 32768.0 - 1.0;
                *state = state.wrapping_mul(1103515245).wrapping_add(12345);
                let ry = (*state >> 16) as f32 / 32768.0 - 1.0;
                p[0] = cx + rx * half_w;
                p[1] = cy + ry * half_h;
            }
        }
    }

    /// Full upload of graph data to GPU buffers.
    pub fn upload_graph(&mut self, world: &World) {
        self.rebuild_classic_buffers(world);
    }

    /// Update positions in-place (called every frame after sync_positions).
    /// Buffer layout: [glow_count glows] [node_count nodes] [highlight rings].
    pub fn update_positions(&mut self, world: &World) {
        self.rebuild_classic_buffers(world);
    }

    /// Append highlight ring instances after glow + regular node instances.
    pub fn set_highlights(&mut self, selected: Option<u32>, hovered: Option<u32>, world: &World) {
        let Some(buf) = &self.node_instance_buf else { return };
        let ptr = buf.contents() as *mut NodeInstance;
        let mut idx = self.glow_count + self.node_count;
        let capacity = self.node_instance_capacity;

        if idx < capacity
            && let Some(sel_id) = selected
            && let Some(gi) = world.index_of_node_id(sel_id)
            && world.graph_node[gi].visible != 0
        {
            let color = self.node_color_for_u8(world.hierarchy[gi].node_type);
            unsafe {
                *ptr.add(idx) = NodeInstance {
                    position: [world.transform[gi].x, world.transform[gi].y],
                    radius: world.graph_node[gi].radius + 6.0,
                    z: z_for_link_count(world.hierarchy[gi].link_count),
                    color: [color[0], color[1], color[2], 0.6],
                };
            }
            idx += 1;
        }

        if idx < capacity
            && let Some(hov_id) = hovered
            && Some(hov_id) != selected
            && let Some(gi) = world.index_of_node_id(hov_id)
            && world.graph_node[gi].visible != 0
        {
            unsafe {
                *ptr.add(idx) = NodeInstance {
                    position: [world.transform[gi].x, world.transform[gi].y],
                    radius: world.graph_node[gi].radius + 2.0,
                    z: z_for_link_count(world.hierarchy[gi].link_count),
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
    pub fn rebuild_highlight_flags(&mut self, world: &World) {
        let total = self.glow_count + self.node_count + self.highlight_count;
        if total == 0 { return; }

        // Encode dim factor: 0 = normal (1.0), non-zero = dim (value/255).
        // DIM_ALPHA (0.04) → 10, glow dim (DIM_ALPHA * 0.4 ≈ 0.016) → 4.
        const NODE_DIM: u8 = 10;   // 0.04 * 255 ≈ 10
        const GLOW_DIM: u8 = 4;    // glow dim factor ≈ 0.016

        // Reuse pre-allocated scratch buffer (avoids heap allocation every frame).
        self.highlight_flag_scratch.clear();
        self.highlight_flag_scratch.reserve(total);

        if self.highlight.active {
            // Glow flags — must mirror update_positions exactly: cap at self.glow_count.
            // Without this cap, visibility/link_count changes would misalign the flag buffer
            // with the instance buffer, causing the wrong node to get highlighted.
            // Flag encoding: 0 = normal, 1 = highlighted (boosted), GLOW_DIM/NODE_DIM = dimmed.
            let mut glow_flags = 0usize;
            for &node_index in &self.rendered_node_indices {
                let graph_node = &world.graph_node[node_index];
                let lit = self.highlight.highlighted_ids.contains(&graph_node.node_id);
                if world.hierarchy[node_index].link_count >= 9 && glow_flags < self.glow_count {
                    self.highlight_flag_scratch.push(if lit { 1 } else { GLOW_DIM });
                    glow_flags += 1;
                }
                if graph_node.confidence > 0.0 && glow_flags < self.glow_count {
                    self.highlight_flag_scratch.push(if lit { 1 } else { GLOW_DIM });
                    glow_flags += 1;
                }
            }
            // Pad or truncate to exactly glow_count (safety net).
            self.highlight_flag_scratch.resize(self.glow_count, 0);

            // Regular node flags: 1 = highlighted (bright), NODE_DIM = dimmed
            for &node_index in &self.rendered_node_indices {
                let graph_node = &world.graph_node[node_index];
                let lit = self.highlight.highlighted_ids.contains(&graph_node.node_id);
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
    pub fn update_field_lines(&mut self, hovered: Option<u32>, world: &World, time: f32) {
        if hovered == self.field_line_hovered_id && hovered.is_some() {
            // Same node still hovered — just update positions with time animation.
            if hovered.is_none() { return; }
        }
        self.field_line_hovered_id = hovered;

        let Some(hov_id) = hovered else {
            self.field_line_count = 0;
            return;
        };

        let Some(hov_entity) = world.entity_of_node_id(hov_id) else {
            self.field_line_count = 0;
            return;
        };
        let Some(hov_idx) = world.index_of(hov_entity) else {
            self.field_line_count = 0;
            return;
        };
        if world.graph_node[hov_idx].visible == 0 {
            self.field_line_count = 0;
            return;
        }

        let hov_pos = [world.transform[hov_idx].x, world.transform[hov_idx].y];
        let hov_color = self.node_color_for_u8(world.hierarchy[hov_idx].node_type);
        let field_color = [hov_color[0], hov_color[1], hov_color[2], 0.12];

        // Reuse scratch buffer for field line segments.
        self.field_line_scratch.clear();
        const FIELD_LINES_PER_NEIGHBOR: usize = 3;
        const FIELD_SEGMENTS: usize = 6;

        // Find neighbors from ECS edge topology.
        for &edge_index in world.edge_indices_for_index(hov_idx) {
            let edge = &world.edges[edge_index];
            let neighbor_entity = if edge.source == hov_entity {
                edge.target
            } else if edge.target == hov_entity {
                edge.source
            } else {
                continue;
            };

            let Some(n_idx) = world.index_of(neighbor_entity) else { continue; };
            if world.graph_node[n_idx].visible == 0 { continue; }

            let n_pos = [world.transform[n_idx].x, world.transform[n_idx].y];
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

    // ── Dialogue Box Rendering ────────────────────────────────────────────────

    fn ensure_dialogue_pipeline(&mut self) {
        if self.dialogue_pipeline.is_some() {
            return;
        }
        let library = match self.device.new_library_with_source(
            DIALOGUE_SHADER_SOURCE,
            &CompileOptions::new(),
        ) {
            Ok(lib) => lib,
            Err(e) => {
                eprintln!("dialogue shader compile: {e}");
                return;
            }
        };
        let vert = match library.get_function("dialogue_vertex", None) {
            Ok(f) => f,
            Err(_) => return,
        };
        let frag = match library.get_function("dialogue_fragment", None) {
            Ok(f) => f,
            Err(_) => return,
        };

        let desc = RenderPipelineDescriptor::new();
        desc.set_vertex_function(Some(&vert));
        desc.set_fragment_function(Some(&frag));

        // Vertex descriptor: float2 position at offset 0, float4 color at offset 8, stride 24.
        let vd = VertexDescriptor::new();
        let attrs = vd.attributes();
        // position: float2 at offset 0
        if let Some(attr0) = attrs.object_at(0) {
            attr0.set_format(MTLVertexFormat::Float2);
            attr0.set_offset(0);
            attr0.set_buffer_index(0);
        }
        // color: float4 at offset 8
        if let Some(attr1) = attrs.object_at(1) {
            attr1.set_format(MTLVertexFormat::Float4);
            attr1.set_offset(8);
            attr1.set_buffer_index(0);
        }
        // layout
        let layouts = vd.layouts();
        if let Some(layout0) = layouts.object_at(0) {
            layout0.set_stride(std::mem::size_of::<DialogueVertex>() as u64);
            layout0.set_step_function(MTLVertexStepFunction::PerVertex);
            layout0.set_step_rate(1);
        }
        desc.set_vertex_descriptor(Some(&vd));

        // Alpha blending (same as classic pipelines).
        if let Some(color_attach) = desc.color_attachments().object_at(0) {
            color_attach.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
            color_attach.set_blending_enabled(true);
            color_attach.set_source_rgb_blend_factor(MTLBlendFactor::SourceAlpha);
            color_attach.set_destination_rgb_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
            color_attach.set_source_alpha_blend_factor(MTLBlendFactor::One);
            color_attach.set_destination_alpha_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
        }

        self.dialogue_pipeline = self.device.new_render_pipeline_state(&desc).ok();
    }

    fn compute_dialogue_box_position(&mut self, world: &World) {
        let Some(node_index) = self.dialogue.node_index else {
            return;
        };
        if node_index >= world.len() {
            return;
        }

        let node_x = world.transform[node_index].x;
        let node_y = world.transform[node_index].y;
        let node_radius = world.graph_node[node_index].radius;
        let zoom = self.camera_zoom.max(0.01);

        // Convert screen-space dimensions to world-space.
        let box_w_world = DIALOGUE_BOX_SCREEN_WIDTH / zoom;
        let box_h_world = DIALOGUE_BOX_SCREEN_HEIGHT / zoom;
        let tail_h_world = DIALOGUE_TAIL_SCREEN_HEIGHT / zoom;
        let gap_world = DIALOGUE_GAP_SCREEN / zoom;

        // Box is centered above the node.
        let box_center_x = node_x;
        let box_bottom_y = node_y - node_radius - gap_world - tail_h_world;
        let box_top_y = box_bottom_y - box_h_world;
        let box_left = box_center_x - box_w_world * 0.5;

        // Store world-space rect for vertex building (left, top, width, height).
        // We use node_screen_pos temporarily to cache the world-space tail tip.
        let vw = self.last_viewport_width;
        let vh = self.last_viewport_height;

        // World → screen: screen = (world - camera) * zoom + viewport/2
        let screen_box_x = (box_left - self.camera_offset[0]) * zoom + vw * 0.5;
        let screen_box_y = (box_top_y - self.camera_offset[1]) * zoom + vh * 0.5;
        let screen_box_w = box_w_world * zoom;
        let screen_box_h = box_h_world * zoom;

        self.dialogue.box_screen_rect = [screen_box_x, screen_box_y, screen_box_w, screen_box_h];
        let node_screen_x = (node_x - self.camera_offset[0]) * zoom + vw * 0.5;
        let node_screen_y = (node_y - self.camera_offset[1]) * zoom + vh * 0.5;
        self.dialogue.node_screen_pos = [node_screen_x, node_screen_y];
    }

    fn build_dialogue_vertices(&mut self, world: &World) {
        self.dialogue_vertex_scratch.clear();

        let Some(node_index) = self.dialogue.node_index else {
            return;
        };
        if node_index >= world.len() {
            return;
        }

        let node_x = world.transform[node_index].x;
        let node_y = world.transform[node_index].y;
        let node_radius = world.graph_node[node_index].radius;
        let zoom = self.camera_zoom.max(0.01);

        let box_w = DIALOGUE_BOX_SCREEN_WIDTH / zoom;
        let box_h = DIALOGUE_BOX_SCREEN_HEIGHT / zoom;
        let tail_h = DIALOGUE_TAIL_SCREEN_HEIGHT / zoom;
        let gap = DIALOGUE_GAP_SCREEN / zoom;
        let border_w = 2.0 / zoom;
        let nameplate_h = 24.0 / zoom;

        let cx = node_x;
        let box_bottom = node_y - node_radius - gap - tail_h;
        let box_top = box_bottom - box_h;
        let left = cx - box_w * 0.5;
        let right = cx + box_w * 0.5;

        // Colors: dark blue gradient.
        let color_top = [0.08_f32, 0.10, 0.22, 0.92];
        let color_bot = [0.04_f32, 0.06, 0.14, 0.92];

        // Background: 2 triangles forming a quad.
        // Tri 1: top-left, top-right, bottom-left
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [left, box_top], color: color_top });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [right, box_top], color: color_top });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [left, box_bottom], color: color_bot });
        // Tri 2: top-right, bottom-right, bottom-left
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [right, box_top], color: color_top });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [right, box_bottom], color: color_bot });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [left, box_bottom], color: color_bot });

        // Tail: triangle from box bottom-center to node.
        let tail_tip_y = node_y - node_radius - gap;
        let tail_half_w = 12.0 / zoom;
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [cx - tail_half_w, box_bottom], color: color_bot });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [cx + tail_half_w, box_bottom], color: color_bot });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [cx, tail_tip_y], color: color_bot });

        // Nameplate bar at top: 2 triangles, uses node type color.
        let np_color = self.node_color_for_u8(world.hierarchy[node_index].node_type);
        let np_bottom = box_top + nameplate_h;
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [left, box_top], color: np_color });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [right, box_top], color: np_color });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [left, np_bottom], color: np_color });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [right, box_top], color: np_color });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [right, np_bottom], color: np_color });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [left, np_bottom], color: np_color });

        // Border: 4 thin quads (top, bottom, left, right) — white.
        let border_color = [1.0_f32, 1.0, 1.0, 0.85];

        // Top border
        self.push_border_quad(left, box_top, right, box_top + border_w, border_color);
        // Bottom border
        self.push_border_quad(left, box_bottom - border_w, right, box_bottom, border_color);
        // Left border
        self.push_border_quad(left, box_top, left + border_w, box_bottom, border_color);
        // Right border
        self.push_border_quad(right - border_w, box_top, right, box_bottom, border_color);
    }

    fn push_border_quad(&mut self, x0: f32, y0: f32, x1: f32, y1: f32, color: [f32; 4]) {
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [x0, y0], color });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [x1, y0], color });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [x0, y1], color });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [x1, y0], color });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [x1, y1], color });
        self.dialogue_vertex_scratch.push(DialogueVertex { position: [x0, y1], color });
    }

    /// Prepare dialogue box GPU data. Call before the render pass.
    /// Builds vertices, uploads buffers, ensures pipeline is compiled.
    pub fn prepare_dialogue_box(&mut self, world: &World) {
        if !self.dialogue.active {
            return;
        }

        self.ensure_dialogue_pipeline();
        self.compute_dialogue_box_position(world);
        self.build_dialogue_vertices(world);

        let vertex_count = self.dialogue_vertex_scratch.len();
        if vertex_count == 0 {
            return;
        }

        // Upload vertices to GPU buffer.
        let needed_bytes = (vertex_count * std::mem::size_of::<DialogueVertex>()) as u64;
        if self.dialogue_vertex_buf.as_ref().is_none_or(|b| b.length() < needed_bytes) {
            let capacity_bytes = (needed_bytes * 3 / 2).max(1024);
            self.dialogue_vertex_buf = Some(
                self.device.new_buffer(capacity_bytes, MTLResourceOptions::StorageModeShared),
            );
        }
        if let Some(buf) = &self.dialogue_vertex_buf {
            // SAFETY: buf.contents() is valid for buf.length() bytes; we ensured capacity above.
            unsafe {
                std::ptr::copy_nonoverlapping(
                    self.dialogue_vertex_scratch.as_ptr(),
                    buf.contents() as *mut DialogueVertex,
                    vertex_count,
                );
            }
        }

        // Upload dialogue uniforms.
        let elapsed = self.start_time.elapsed().as_secs_f32();
        let du = DialogueUniforms {
            viewport_size: [self.last_viewport_width, self.last_viewport_height],
            camera_offset: self.camera_offset,
            camera_zoom: self.camera_zoom,
            time: elapsed,
            _pad: [0.0; 2],
        };
        if self.dialogue_uniform_buf.is_none() {
            self.dialogue_uniform_buf = Some(self.device.new_buffer(
                std::mem::size_of::<DialogueUniforms>() as u64,
                MTLResourceOptions::StorageModeShared,
            ));
        }
        if let Some(ubuf) = &self.dialogue_uniform_buf {
            // SAFETY: ubuf is large enough for DialogueUniforms (32 bytes).
            unsafe {
                let ptr = ubuf.contents() as *mut DialogueUniforms;
                *ptr = du;
            }
        }
    }

    /// Issue dialogue box draw commands into the encoder.
    /// Call after prepare_dialogue_box, inside the render pass.
    fn draw_dialogue_commands(&self, encoder: &RenderCommandEncoderRef) {
        if !self.dialogue.active {
            return;
        }
        let vertex_count = self.dialogue_vertex_scratch.len();
        if vertex_count == 0 {
            return;
        }
        let Some(pipeline) = &self.dialogue_pipeline else {
            return;
        };
        encoder.set_render_pipeline_state(pipeline);
        if let (Some(vbuf), Some(ubuf)) = (&self.dialogue_vertex_buf, &self.dialogue_uniform_buf) {
            encoder.set_vertex_buffer(0, Some(vbuf), 0);
            encoder.set_vertex_buffer(1, Some(ubuf), 0);
            encoder.draw_primitives(
                MTLPrimitiveType::Triangle,
                0,
                vertex_count as u64,
            );
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

    pub fn draw(&mut self, viewport_width: u32, viewport_height: u32, world: &World) {
        self.set_viewport_size(viewport_width, viewport_height);
        self.prepare_dialogue_box(world);
        autoreleasepool(|| {
            let drawable = match self.layer.next_drawable() {
                Some(d) => d,
                None => return,
            };

            let elapsed = self.start_time.elapsed().as_secs_f32();
            // Pulse time: seconds since pulse started (-1 = no active pulse).
            // Auto-expire after 2 seconds.
            let pulse_t = if self.pulse_start > 0.0 {
                let dt = elapsed - self.pulse_start;
                if dt > 2.0 { self.pulse_start = 0.0; -1.0 } else { dt }
            } else {
                -1.0
            };
            // Decay impact intensity each frame (~0.33s total fade).
            let dt = 1.0 / 60.0;
            if self.impact_intensity > 0.0 {
                self.impact_intensity = (self.impact_intensity - dt * 3.0).max(0.0);
            }
            let uniforms = Uniforms {
                viewport_size: [viewport_width as f32, viewport_height as f32],
                camera_offset: self.camera_offset,
                camera_zoom: self.camera_zoom,
                time: elapsed,
                pulse_origin: self.pulse_origin,
                pulse_time: pulse_t,
                focal_length: 2.0,
                camera_velocity: [0.0, 0.0],
                zoom_velocity: 0.0,
                lite_mode: self.quality_level as f32,
                impact_intensity: self.impact_intensity,
                _pad: 0.0,
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
            let effective_edge_count = if self.use_aggregated_edges {
                self.aggregated_edge_count
            } else {
                self.edge_instance_count
            };
            if effective_edge_count > 0
                && let Some(inst_buf) = &self.edge_instance_buf
            {
                // Clamp to buffer capacity to prevent Metal validation crash.
                let edge_draw = effective_edge_count.min(self.edge_instance_capacity);
                encoder.set_render_pipeline_state(&self.edge_pipeline);
                encoder.set_vertex_buffer(0, Some(inst_buf), 0);
                encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                encoder.draw_primitives_instanced(
                    MTLPrimitiveType::Triangle,
                    0,
                    6,
                    edge_draw as u64,
                );
            }

            // Draw magnetic field lines (hover interaction, between edges and nodes).
            if self.field_line_count > 0
                && let Some(fl_buf) = &self.field_line_buf
            {
                let fl_draw = self.field_line_count.min(self.field_line_capacity);
                encoder.set_render_pipeline_state(&self.edge_pipeline);
                encoder.set_vertex_buffer(0, Some(fl_buf), 0);
                encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                encoder.draw_primitives_instanced(
                    MTLPrimitiveType::Triangle,
                    0,
                    6,
                    fl_draw as u64,
                );
            }

            // Draw nodes: glow instances + regular nodes + highlight rings.
            let total_instances = self.glow_count + self.node_count + self.highlight_count;
            if total_instances > 0
                && let Some(inst_buf) = &self.node_instance_buf
            {
                // Safety: clamp draw count to actual buffer capacities.
                // Metal validates that shader reads don't exceed buffer length.
                let draw_count = total_instances
                    .min(self.node_instance_capacity);

                encoder.set_render_pipeline_state(&self.node_pipeline);
                encoder.set_vertex_buffer(0, Some(inst_buf), 0);
                encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                // Bind uniforms to fragment shader for pulse wave effect.
                encoder.set_fragment_buffer(1, Some(&self.uniform_buf), 0);

                // Bind highlight flag buffer (buffer(2)).
                // Ensure buffer exists AND is large enough for draw_count.
                if self.highlight_flag_buf.is_none() || self.highlight_flag_capacity < draw_count {
                    let cap = (draw_count * 3 / 2).max(64);
                    let buf = self.device.new_buffer(cap as u64, MTLResourceOptions::StorageModeShared);
                    self.highlight_flag_buf = Some(buf);
                    self.highlight_flag_capacity = cap;
                }
                if let Some(flag_buf) = &self.highlight_flag_buf {
                    encoder.set_vertex_buffer(2, Some(flag_buf), 0);
                }

                // Bind velocity buffer for squash & stretch (buffer 3).
                // Ensure buffer exists AND is large enough for draw_count.
                if self.node_velocity_buf.is_none() || self.node_velocity_capacity < draw_count {
                    let cap = (draw_count * 3 / 2).max(64);
                    let buf_size = (cap * std::mem::size_of::<[f32; 2]>()) as u64;
                    self.node_velocity_buf = Some(
                        self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
                    );
                    self.node_velocity_capacity = cap;
                }
                if let Some(vel_buf) = &self.node_velocity_buf {
                    encoder.set_vertex_buffer(3, Some(vel_buf), 0);
                }

                if draw_count > 0 {
                    encoder.draw_primitives_instanced(
                        MTLPrimitiveType::Triangle,
                        0,
                        6,
                        draw_count as u64,
                    );
                }
            }

            // Draw dialogue box overlay (after nodes, on top).
            self.draw_dialogue_commands(encoder);

            encoder.end_encoding();

            cmd_buf.present_drawable(drawable);
            cmd_buf.commit();
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;


    #[test]
    fn z_for_link_count_tiers() {
        assert!(z_for_link_count(0) < z_for_link_count(4));
        assert!(z_for_link_count(4) < z_for_link_count(7));
        assert!(z_for_link_count(7) < z_for_link_count(10));
    }

    #[test]
    fn tension_color_constants_valid() {
        for c in &TENSION_COLOR {
            assert!(*c >= 0.0 && *c <= 1.0, "Tension color component out of range: {}", c);
        }
        assert!(TENSION_K_YIELD > 0.0 && TENSION_K_YIELD <= 1.0);
    }

    #[test]
    fn uniforms_size_matches_metal() {
        // Uniforms must be consistent between Rust and Metal (16-byte aligned).
        // 15 data floats + 1 padding float = 16 floats = 64 bytes.
        assert_eq!(std::mem::size_of::<Uniforms>(), 64);
    }

    #[test]
    fn node_instance_size() {
        // position(8) + radius(4) + z(4) + color(16) = 32 bytes.
        assert_eq!(std::mem::size_of::<NodeInstance>(), 32);
    }

    #[test]
    fn line_edge_instance_size() {
        // p0(8) + p1(8) + color(16) = 32 bytes.
        assert_eq!(std::mem::size_of::<LineEdgeInstance>(), 32);
    }

    #[test]
    fn lod_profile_is_zoom_stable_in_cinematic_mode() {
        let near = lod_profile_for_zoom(1.0, 0);
        let far = lod_profile_for_zoom(0.05, 0);
        assert_eq!(near, far);
        assert!(near.draw_edges);
        assert!(near.draw_glow);
        assert!(!near.cluster_nodes);
    }

    #[test]
    fn density_cell_size_grows_when_zooming_out() {
        assert!(density_cell_size_world(0.05) > density_cell_size_world(0.20));
    }

    #[test]
    fn lod_profile_is_zoom_stable_in_performance_mode() {
        let near = lod_profile_for_zoom(1.0, 2);
        let far = lod_profile_for_zoom(0.05, 2);
        assert_eq!(near, far);
        assert!(near.draw_edges);
        assert!(!near.draw_glow);
        assert!(!near.cluster_nodes);
        assert_eq!(near.edge_degree_threshold, 36);
        assert_eq!(near.max_edges_per_node, 10);
    }

    #[test]
    fn segment_intersects_bounds_detects_crossing_line() {
        let bounds = ViewBounds {
            min_x: 0.0,
            min_y: 0.0,
            max_x: 100.0,
            max_y: 100.0,
        };
        assert!(segment_intersects_bounds(bounds, [-20.0, 50.0], [120.0, 50.0]));
    }

    #[test]
    fn bounds_intersects_circle_excludes_far_node() {
        let bounds = viewport_bounds([0.0, 0.0], 1.0, [200.0, 200.0], 0.0);
        assert!(bounds_intersects_circle(bounds, [90.0, 0.0], 12.0));
        assert!(!bounds_intersects_circle(bounds, [150.0, 0.0], 12.0));
    }

    #[test]
    fn dialogue_state_default_inactive() {
        let state = DialogueState::default();
        assert!(!state.active);
        assert!(state.node_index.is_none());
        assert!(!state.is_streaming);
        assert_eq!(state.box_screen_rect, [0.0; 4]);
        assert_eq!(state.node_screen_pos, [0.0; 2]);
    }

    #[test]
    fn dialogue_vertex_size() {
        // position(8) + color(16) = 24 bytes.
        assert_eq!(std::mem::size_of::<DialogueVertex>(), 24);
    }

    #[test]
    fn dialogue_uniforms_size() {
        // viewport_size(8) + camera_offset(8) + camera_zoom(4) + time(4) + _pad(8) = 32 bytes.
        assert_eq!(std::mem::size_of::<DialogueUniforms>(), 32);
    }

    #[test]
    fn dialogue_constants_positive() {
        assert!(DIALOGUE_BOX_SCREEN_WIDTH > 0.0);
        assert!(DIALOGUE_BOX_SCREEN_HEIGHT > 0.0);
        assert!(DIALOGUE_TAIL_SCREEN_HEIGHT > 0.0);
        assert!(DIALOGUE_GAP_SCREEN > 0.0);
    }
}
