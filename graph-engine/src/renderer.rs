use std::ffi::c_void;

use metal::foreign_types::ForeignType;
use metal::*;
use objc::rc::autoreleasepool;

use crate::msdf::{FontAtlas, GlyphInstance};
use crate::types::Graph;

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

/// Uniform data sent to all shaders (camera transform + animation + effects).
#[repr(C)]
#[derive(Clone, Copy)]
struct Uniforms {
    viewport_size: [f32; 2],
    camera_offset: [f32; 2],
    camera_zoom: f32,
    time: f32,           // elapsed seconds — drives subtle breathing animation
    ripple_origin: [f32; 2], // world position of last node grab (ripple center)
    ripple_time: f32,        // seconds since ripple started (negative = inactive)
    focal_length: f32,       // perspective focal distance (2.0 default)
    camera_velocity: [f32; 2], // camera offset delta (world units/frame)
    zoom_velocity: f32,        // zoom delta per frame (for motion blur)
    _pad2: f32,                // 16-byte alignment
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

/// Number of line segments to tessellate each bezier edge into.
const EDGE_SEGMENTS: usize = 8;
/// Default edge color: subtle gray at 30% opacity (LogSeq style).
const EDGE_COLOR: [f32; 4] = [0.55, 0.55, 0.60, 0.3];
/// Highlighted edge color: brighter accent.
const EDGE_HIGHLIGHT_COLOR: [f32; 4] = [0.65, 0.85, 1.00, 0.6];
/// Dimmed node alpha when highlight is active.
const DIM_ALPHA: f32 = 0.15;
/// Dimmed edge alpha when highlight is active.
const EDGE_DIM_ALPHA: f32 = 0.05;

/// Compute the quadratic bezier control point for a gravitational arc edge.
/// The curve bends toward the heavier node (more links = more mass).
fn gravitational_control_point(
    p0: [f32; 2], p1: [f32; 2],
    mass0: u32, mass1: u32,
) -> [f32; 2] {
    let mx = (p0[0] + p1[0]) * 0.5;
    let my = (p0[1] + p1[1]) * 0.5;
    let dx = p1[0] - p0[0];
    let dy = p1[1] - p0[1];
    let len = (dx * dx + dy * dy).sqrt().max(1.0);
    // Perpendicular direction.
    let px = -dy / len;
    let py = dx / len;
    // Mass ratio determines curvature magnitude and direction.
    // Positive = bend toward p1 (heavier), negative = toward p0.
    let m0 = (mass0.max(1) as f32).cbrt();
    let m1 = (mass1.max(1) as f32).cbrt();
    let bias = (m1 - m0) / (m0 + m1); // range [-1, 1]
    let curvature = len * 0.12 * bias;
    [mx + px * curvature, my + py * curvature]
}

/// Evaluate a quadratic bezier at parameter t ∈ [0, 1].
fn bezier_point(p0: [f32; 2], cp: [f32; 2], p1: [f32; 2], t: f32) -> [f32; 2] {
    let s = 1.0 - t;
    [
        s * s * p0[0] + 2.0 * s * t * cp[0] + t * t * p1[0],
        s * s * p0[1] + 2.0 * s * t * cp[1] + t * t * p1[1],
    ]
}

/// Tessellate a quadratic bezier into N line segments.
fn tessellate_bezier(
    p0: [f32; 2], cp: [f32; 2], p1: [f32; 2],
    color: [f32; 4],
    out: &mut Vec<LineEdgeInstance>,
) {
    let n = EDGE_SEGMENTS;
    let mut prev = p0;
    for i in 1..=n {
        let t = i as f32 / n as f32;
        let next = bezier_point(p0, cp, p1, t);
        out.push(LineEdgeInstance {
            p0: prev,
            p1: next,
            color,
        });
        prev = next;
    }
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
    float2 ripple_origin;
    float ripple_time;
    float focal_length;
    float2 camera_velocity;
    float zoom_velocity;
    float _pad2;
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
};

vertex NodeVertexOut node_vertex(
    uint vertex_id [[vertex_id]],
    uint instance_id [[instance_id]],
    constant NodeInstance* instances [[buffer(0)]],
    constant Uniforms& uniforms [[buffer(1)]]
) {
    float2 corners[6] = {
        float2(-1, -1), float2( 1, -1), float2(-1,  1),
        float2(-1,  1), float2( 1, -1), float2( 1,  1)
    };

    NodeInstance inst = instances[instance_id];
    float2 corner = corners[vertex_id];

    // Breathing animation — tier-based speed: background slowest (stars barely twinkle),
    // foreground fastest (bright stars pulse visibly). Cosmic observatory feel.
    float breath_speed = inst.z > 0.2 ? 0.7 : (inst.z > -0.1 ? 0.5 : 0.3);
    float breath = sin(uniforms.time * breath_speed + float(instance_id) * 2.39996) * 0.18;
    float depth = inst.z + breath;

    // Perspective division: focal/(focal-depth). Works for any depth range.
    // Positive depth = closer (larger), negative depth = farther (smaller).
    float perspective_scale = uniforms.focal_length / (uniforms.focal_length - depth);
    float effective_radius = inst.radius * perspective_scale;

    // Ripple effect: radial shockwave from node grab point.
    float2 base_pos = inst.position;
    if (uniforms.ripple_time >= 0.0) {
        float2 to_node = base_pos - uniforms.ripple_origin;
        float dist = length(to_node);
        float ripple_radius = uniforms.ripple_time * 400.0;  // wave speed
        float wave_dist = dist - ripple_radius;
        // Decaying sine wave centered on the expanding ring.
        float wave = sin(wave_dist * 0.08) * exp(-wave_dist * wave_dist * 0.0003);
        // Amplitude decays over time and with distance from origin.
        float amplitude = 18.0 * exp(-uniforms.ripple_time * 2.5) * exp(-dist * 0.003);
        float2 dir = dist > 0.1 ? normalize(to_node) : float2(0, 0);
        base_pos += dir * wave * amplitude;
    }

    float2 world_pos = base_pos + corner * effective_radius;

    float2 screen = (world_pos - uniforms.camera_offset) * uniforms.camera_zoom;
    float2 ndc = screen / (uniforms.viewport_size * 0.5) * float2(1, -1);

    // Depth-based NDC z for proper draw ordering (closer = smaller z = in front).
    float ndc_z = 0.5 - depth * 0.1;

    NodeVertexOut out;
    out.position = float4(ndc, ndc_z, 1.0);
    out.color = inst.color;
    out.uv = corner;
    out.depth = depth;
    return out;
}

fragment float4 node_fragment(NodeVertexOut in [[stage_in]]) {
    // ── Pixel art quantization ──
    // pixel_art_strength: 0.0 = fully smooth, 1.0 = fully pixelated.
    // Hardcoded at 0.6 for now (subtle but distinctive).
    float pixel_strength = 0.6;

    // Grid resolution: 12 cells per node diameter gives a tasteful retro look.
    float grid = 12.0;
    float2 quv = floor(in.uv * grid + 0.5) / grid;  // Snap UV to grid

    // Blend between smooth UV and quantized UV
    float2 final_uv = mix(in.uv, quv, pixel_strength);

    float dist = length(final_uv);

    // Hard pixel boundary instead of smoothstep (blended with smooth)
    float smooth_alpha = 1.0 - smoothstep(0.85, 1.0, length(in.uv));
    float pixel_alpha = dist < 0.92 ? 1.0 : 0.0;
    float alpha = mix(smooth_alpha, pixel_alpha, pixel_strength);
    if (alpha < 0.01) discard_fragment();

    // ── 3D sphere shading (on quantized coords) ──
    float r2 = dot(final_uv, final_uv);
    float nz = sqrt(max(1.0 - r2, 0.0));

    // Diffuse lighting
    float3 light_dir = normalize(float3(-0.35, -0.5, 0.8));
    float3 normal = float3(final_uv.x, final_uv.y, nz);
    float diffuse = max(dot(normal, light_dir), 0.0);
    float lighting = 0.45 + 0.55 * diffuse;

    // ── Stepped lighting (pixel art bands) ──
    float bands = 4.0;
    float stepped_lighting = floor(lighting * bands + 0.5) / bands;
    lighting = mix(lighting, stepped_lighting, pixel_strength);

    // Specular highlight
    float3 view_dir = float3(0, 0, 1);
    float3 half_vec = normalize(light_dir + view_dir);
    float spec = pow(max(dot(normal, half_vec), 0.0), 32.0);

    // ── Dithered specular (checkerboard pattern) ──
    float2 grid_pos = floor(in.uv * grid + 0.5);
    bool checker = fmod(grid_pos.x + grid_pos.y, 2.0) < 1.0;
    float pixel_spec = (spec > 0.3 && checker) ? 0.4 : 0.0;
    spec = mix(spec * 0.3, pixel_spec, pixel_strength);

    // Rim/Fresnel glow
    float rim = 1.0 - nz;
    float rim_glow = pow(rim, 3.0) * 0.35;

    // Combine
    float3 lit_color = in.color.rgb * lighting + spec + in.color.rgb * rim_glow;

    // Background depth fade
    float depth_fade = in.depth < -0.1 ? 0.65 : 1.0;
    float edge_softness = in.depth < -0.1 ? 0.75 : 0.85;
    float dof_alpha = 1.0 - smoothstep(edge_softness, 1.0, length(in.uv));

    // Final alpha blends pixel boundary with depth-of-field
    float final_alpha = mix(dof_alpha, alpha, pixel_strength);

    return float4(lit_color, in.color.a * final_alpha * depth_fade);
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

    // Transform endpoints to NDC first.
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

// ── MSDF text label shaders ─────────────────────────────────────────

struct GlyphInstance {
    float2 position;
    float2 glyph_offset;
    float2 glyph_size;
    float2 uv_origin;
    float2 uv_size;
    float  font_size;
    float  alpha;
    float4 color;
};

struct GlyphVertexOut {
    float4 position [[position]];
    float2 uv;
    float  alpha;
    float4 color;
    float  screen_px_range;
};

vertex GlyphVertexOut msdf_vertex(
    uint vertex_id [[vertex_id]],
    uint instance_id [[instance_id]],
    constant GlyphInstance* instances [[buffer(0)]],
    constant Uniforms& uniforms [[buffer(1)]]
) {
    float2 corners[6] = {
        float2(-1, -1), float2( 1, -1), float2(-1,  1),
        float2(-1,  1), float2( 1, -1), float2( 1,  1)
    };

    float2 uv_corners[6] = {
        float2(0, 1), float2(1, 1), float2(0, 0),
        float2(0, 0), float2(1, 1), float2(1, 0)
    };

    GlyphInstance inst = instances[instance_id];
    float2 corner = corners[vertex_id];

    float2 world_pos = inst.position + inst.glyph_offset + corner * inst.glyph_size;
    float2 screen = (world_pos - uniforms.camera_offset) * uniforms.camera_zoom;
    float2 ndc = screen / (uniforms.viewport_size * 0.5) * float2(1, -1);

    float2 uv_corner = uv_corners[vertex_id];
    float2 uv = inst.uv_origin + uv_corner * inst.uv_size;

    float screen_px_range = max(0.125 * inst.font_size * uniforms.camera_zoom, 1.0);

    GlyphVertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv = uv;
    out.alpha = inst.alpha;
    out.color = inst.color;
    out.screen_px_range = screen_px_range;
    return out;
}

float msdf_median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

fragment float4 msdf_fragment(
    GlyphVertexOut in [[stage_in]],
    texture2d<float> atlas [[texture(0)]]
) {
    constexpr sampler atlas_sampler(mag_filter::linear, min_filter::linear);
    float3 msd = atlas.sample(atlas_sampler, in.uv).rgb;
    float sd = msdf_median(msd.r, msd.g, msd.b);
    float screen_dist = in.screen_px_range * (sd - 0.5);
    float opacity = clamp(screen_dist + 0.5, 0.0, 1.0);
    if (opacity < 0.01) discard_fragment();
    return float4(in.color.rgb, in.color.a * in.alpha * opacity);
}

// ── Post-process motion blur ──────────────────────────────────────────

struct PostVertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex PostVertexOut post_vertex(uint vid [[vertex_id]],
                                 constant float2* verts [[buffer(0)]]) {
    PostVertexOut out;
    out.position = float4(verts[vid], 0.0, 1.0);
    out.uv = verts[vid] * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

fragment float4 post_blur(PostVertexOut in [[stage_in]],
                          texture2d<float> current [[texture(0)]],
                          texture2d<float> previous [[texture(1)]],
                          constant Uniforms& u [[buffer(0)]]) {
    constexpr sampler s(filter::linear);
    float4 color = current.sample(s, in.uv);

    // Camera velocity magnitude → blur intensity.
    float speed = length(u.camera_velocity) * u.camera_zoom + abs(u.zoom_velocity) * 500.0;
    float blur_strength = clamp(speed * 0.002, 0.0, 0.35);

    if (blur_strength > 0.01) {
        // Radial blur: sample along direction from center.
        float2 center = float2(0.5, 0.5);
        float2 dir = in.uv - center;
        float zoom_sign = sign(u.zoom_velocity);
        float radial_scale = blur_strength * zoom_sign;

        // 4 radial taps.
        float4 blur_accum = float4(0);
        for (int i = 1; i <= 4; i++) {
            float t = float(i) * 0.008 * radial_scale;
            blur_accum += current.sample(s, in.uv + dir * t);
        }
        blur_accum *= 0.25;

        // Pan blur: directional based on camera velocity.
        float2 pan_dir = u.camera_velocity * 0.0003;
        float4 pan_accum = float4(0);
        for (int i = 1; i <= 3; i++) {
            float t = float(i);
            pan_accum += current.sample(s, in.uv + pan_dir * t);
        }
        pan_accum /= 3.0;

        // Blend: current + radial/directional + temporal (previous frame).
        float radial_weight = abs(u.zoom_velocity) > 0.001 ? 0.5 : 0.2;
        float pan_weight = 1.0 - radial_weight;
        float4 blurred = blur_accum * radial_weight + pan_accum * pan_weight;
        color = mix(color, blurred, blur_strength * 0.6);
        float4 prev = previous.sample(s, in.uv);
        color = mix(color, prev, blur_strength * 0.4);
    }

    return color;
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
    msdf_pipeline: RenderPipelineState,
    msdf_atlas_texture: Texture,
    glyph_instance_buf: Option<Buffer>,
    glyph_instance_capacity: usize,
    glyph_count: usize,
    font_atlas: FontAtlas,
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
    // Magnetic field lines (hover interaction).
    field_line_buf: Option<Buffer>,
    field_line_count: usize,
    field_line_hovered_id: Option<u32>,
    // Background clear color (transparent for hologram overlay)
    pub clear_color: [f64; 4],
    // Light mode: uses darker node colors for light backgrounds.
    pub light_mode: bool,
    // Epoch for time uniform (drives breathing animation).
    pub start_time: std::time::Instant,
    // Ripple effect state (triggered on node grab).
    pub ripple_origin: [f32; 2],
    pub ripple_start: Option<std::time::Instant>,
    // Motion blur (two-pass rendering).
    post_pipeline: RenderPipelineState,
    post_vertex_buf: Buffer,
    offscreen_texture: Option<Texture>,
    prev_frame_texture: Option<Texture>,
    offscreen_width: u32,
    offscreen_height: u32,
    prev_camera_zoom: f32,
    prev_camera_offset: [f32; 2],
    // Label rendering settings (tunable from Swift)
    /// Screen radius below which labels are invisible (default 2).
    pub label_fade_start: f32,
    /// Screen radius above which labels are fully opaque (default 10).
    pub label_fade_end: f32,
    /// Base font size in world units (default 12).
    pub label_font_size: f32,
    /// Master toggle for label rendering (default true).
    pub labels_enabled: bool,
}

impl Renderer {
    /// Resolve node color based on light/dark mode.
    #[inline]
    fn node_color(&self, node_type: &crate::types::NodeType) -> [f32; 4] {
        if self.light_mode { node_type.color_light() } else { node_type.color() }
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
            .expect("Failed to compile Metal shaders");

        let node_vert = library.get_function("node_vertex", None).unwrap();
        let node_frag = library.get_function("node_fragment", None).unwrap();
        let edge_vert = library.get_function("line_edge_vertex", None).unwrap();
        let edge_frag = library.get_function("line_edge_fragment", None).unwrap();

        // Helper to create a pipeline with alpha blending
        let make_pipeline = |vert: &Function, frag: &Function| -> RenderPipelineState {
            let desc = RenderPipelineDescriptor::new();
            desc.set_vertex_function(Some(vert));
            desc.set_fragment_function(Some(frag));
            let color_attach = desc.color_attachments().object_at(0).unwrap();
            color_attach.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
            color_attach.set_blending_enabled(true);
            color_attach.set_source_rgb_blend_factor(MTLBlendFactor::SourceAlpha);
            color_attach.set_destination_rgb_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
            color_attach.set_source_alpha_blend_factor(MTLBlendFactor::One);
            color_attach.set_destination_alpha_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
            device.new_render_pipeline_state(&desc).expect("Failed to create pipeline")
        };

        let node_pipeline = make_pipeline(&node_vert, &node_frag);
        let edge_pipeline = make_pipeline(&edge_vert, &edge_frag);

        // MSDF pipeline
        let msdf_vert = library.get_function("msdf_vertex", None).unwrap();
        let msdf_frag = library.get_function("msdf_fragment", None).unwrap();
        let msdf_pipeline = make_pipeline(&msdf_vert, &msdf_frag);

        // Post-process motion blur pipeline (no blending — writes final color).
        let post_vert = library.get_function("post_vertex", None).unwrap();
        let post_frag = library.get_function("post_blur", None).unwrap();
        let post_desc = RenderPipelineDescriptor::new();
        post_desc.set_vertex_function(Some(&post_vert));
        post_desc.set_fragment_function(Some(&post_frag));
        let post_color = post_desc.color_attachments().object_at(0).unwrap();
        post_color.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
        post_color.set_blending_enabled(false);
        let post_pipeline = device
            .new_render_pipeline_state(&post_desc)
            .expect("Failed to create post-process pipeline");

        // Full-screen quad (2 triangles, NDC coordinates).
        let quad_verts: [f32; 12] = [
            -1.0, -1.0, 1.0, -1.0, -1.0, 1.0,
            -1.0, 1.0, 1.0, -1.0, 1.0, 1.0,
        ];
        let post_vertex_buf = device.new_buffer_with_data(
            quad_verts.as_ptr() as *const c_void,
            (quad_verts.len() * std::mem::size_of::<f32>()) as u64,
            MTLResourceOptions::StorageModeShared,
        );

        // Load font atlas texture
        let font_atlas = FontAtlas::load();

        let tex_desc = TextureDescriptor::new();
        tex_desc.set_texture_type(MTLTextureType::D2);
        tex_desc.set_pixel_format(MTLPixelFormat::RGBA8Unorm);
        tex_desc.set_width(font_atlas.atlas_width as u64);
        tex_desc.set_height(font_atlas.atlas_height as u64);
        tex_desc.set_storage_mode(MTLStorageMode::Shared);
        tex_desc.set_usage(MTLTextureUsage::ShaderRead);
        let msdf_atlas_texture = device.new_texture(&tex_desc);

        let region = MTLRegion::new_2d(
            0, 0,
            font_atlas.atlas_width as u64,
            font_atlas.atlas_height as u64,
        );
        msdf_atlas_texture.replace_region(
            region,
            0,
            font_atlas.rgba_data.as_ptr() as *const c_void,
            (font_atlas.atlas_width * 4) as u64,
        );

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
            msdf_pipeline,
            msdf_atlas_texture,
            glyph_instance_buf: None,
            glyph_instance_capacity: 0,
            glyph_count: 0,
            font_atlas,
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
            field_line_buf: None,
            field_line_count: 0,
            field_line_hovered_id: None,
            clear_color: [0.07, 0.07, 0.09, 1.0],
            light_mode: false,
            start_time: std::time::Instant::now(),
            ripple_origin: [0.0, 0.0],
            ripple_start: None,
            post_pipeline,
            post_vertex_buf,
            offscreen_texture: None,
            prev_frame_texture: None,
            offscreen_width: 0,
            offscreen_height: 0,
            prev_camera_zoom: 1.0,
            prev_camera_offset: [0.0, 0.0],
            label_fade_start: 2.0,
            label_fade_end: 10.0,
            label_font_size: 12.0,
            labels_enabled: true,
        })
    }

    /// Pre-allocate GPU buffers with headroom. Call once after commit.
    /// +2 for highlight rings, +hub_count for glow instances.
    pub fn allocate_buffers(&mut self, graph: &Graph, entrance: Option<&[crate::engine::EntranceNodeState]>) {
        let hub_count = graph.nodes.iter().filter(|n| n.visible && n.link_count >= 9).count();
        let node_count = graph.nodes.len() + 2 + hub_count;
        let edge_count = graph.edges.len();

        if node_count > self.node_instance_capacity || self.node_instance_buf.is_none() {
            let capacity = (node_count * 3 / 2).max(64);
            let buf_size = (capacity * std::mem::size_of::<NodeInstance>()) as u64;
            self.node_instance_buf = Some(
                self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.node_instance_capacity = capacity;
        }

        let edge_segment_count = edge_count * EDGE_SEGMENTS;
        if edge_segment_count > self.edge_instance_capacity || self.edge_instance_buf.is_none() {
            let capacity = (edge_segment_count * 3 / 2).max(64);
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
            // Apply dimming if highlight is active and this node isn't highlighted.
            if self.highlight.active && !self.highlight.highlighted_ids.contains(&node.id) {
                color[3] = DIM_ALPHA;
            }

            let mut z = z_for_link_count(node.link_count);
            let mut pos = [node.x, node.y];

            // Apply entrance animation offsets (z-depth, alpha, spiral displacement).
            if let Some(ent) = entrance {
                if let Some(state) = ent.get(gi) {
                    z += state.z_offset;
                    color[3] *= state.alpha;
                    pos[0] += state.dx;
                    pos[1] += state.dy;
                }
            }

            // Hub glow: foreground nodes (9+ links) get a faint radial glow behind them.
            if node.link_count >= 9 {
                let glow_alpha = if self.highlight.active
                    && !self.highlight.highlighted_ids.contains(&node.id)
                {
                    DIM_ALPHA * 0.3
                } else if self.light_mode {
                    0.15
                } else {
                    0.08
                };
                // Apply entrance alpha to glow too.
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
        if total_node_instances > self.node_instance_capacity || self.node_instance_buf.is_none() {
            let capacity = (total_node_instances * 3 / 2).max(64);
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

        // Gravitational arc edge instances (bezier tessellated into segments).
        // During entrance, edges only appear when both endpoints have mostly arrived.
        let mut edge_instances: Vec<LineEdgeInstance> =
            Vec::with_capacity(graph.edges.len() * EDGE_SEGMENTS);

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

                let mut color = if self.highlight.active {
                    let src_lit = self.highlight.highlighted_ids.contains(&src.id);
                    let tgt_lit = self.highlight.highlighted_ids.contains(&tgt.id);
                    if src_lit && tgt_lit {
                        EDGE_HIGHLIGHT_COLOR
                    } else {
                        [EDGE_COLOR[0], EDGE_COLOR[1], EDGE_COLOR[2], EDGE_DIM_ALPHA]
                    }
                } else {
                    EDGE_COLOR
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

                let cp = gravitational_control_point(p0, p1, src.link_count, tgt.link_count);
                tessellate_bezier(p0, cp, p1, color, &mut edge_instances);
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

                    // Update glow instance (if this node has one).
                    if node.link_count >= 9 && glow_idx < self.glow_count {
                        let glow = &mut *ptr.add(glow_idx);
                        glow.position = pos;
                        glow.z = z - 0.1;
                        glow.color[3] = if self.highlight.active
                            && !self.highlight.highlighted_ids.contains(&node.id)
                        { DIM_ALPHA * 0.3 } else { 0.08 } * ent_alpha;
                        glow_idx += 1;
                    }

                    // Update regular node instance (offset past glow instances).
                    let inst = &mut *ptr.add(self.glow_count + visible_count);
                    inst.position = pos;
                    inst.z = z;

                    // Update color for highlight + entrance alpha.
                    let mut color = self.node_color(&node.node_type);
                    if self.highlight.active && !self.highlight.highlighted_ids.contains(&node.id) {
                        color[3] = DIM_ALPHA;
                    }
                    color[3] *= ent_alpha;
                    inst.color = color;

                    visible_count += 1;
                }
            }
        }
        self.node_count = visible_count;

        if self.node_count == 0 {
            self.edge_instance_count = 0;
            return;
        }

        // Update gravitational arc edge positions (re-tessellate bezier curves).
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

                        // Light mode: darker edges for light backgrounds.
                        let base_edge = if self.light_mode {
                            [0.30, 0.30, 0.35, 0.45]
                        } else {
                            EDGE_COLOR
                        };
                        let hi_edge = if self.light_mode {
                            [0.10, 0.40, 0.70, 0.65]
                        } else {
                            EDGE_HIGHLIGHT_COLOR
                        };
                        let dim_edge_alpha = if self.light_mode { 0.10 } else { EDGE_DIM_ALPHA };

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

                        let cp = gravitational_control_point(p0, p1, src.link_count, tgt.link_count);

                        // Write tessellated segments in-place.
                        let mut prev = p0;
                        for seg in 1..=EDGE_SEGMENTS {
                            let t = seg as f32 / EDGE_SEGMENTS as f32;
                            let next = bezier_point(p0, cp, p1, t);
                            let inst = &mut *ptr.add(inst_idx);
                            inst.p0 = prev;
                            inst.p1 = next;
                            inst.color = color;
                            prev = next;
                            inst_idx += 1;
                        }
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

        if let Some(sel_id) = selected
            && let Some(node) = graph.nodes.iter().find(|n| n.id == sel_id && n.visible)
        {
            let color = self.node_color(&node.node_type);
            unsafe {
                *ptr.add(idx) = NodeInstance {
                    position: [node.x, node.y],
                    radius: node.radius + 4.0,
                    z: z_for_link_count(node.link_count),
                    color: [color[0], color[1], color[2], 0.4],
                };
            }
            idx += 1;
        }

        if let Some(hov_id) = hovered
            && Some(hov_id) != selected
            && let Some(node) = graph.nodes.iter().find(|n| n.id == hov_id && n.visible)
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
            self.field_line_buf = None;
            return;
        };

        let Some(hov_node) = graph.nodes.iter().find(|n| n.id == hov_id && n.visible) else {
            self.field_line_count = 0;
            self.field_line_buf = None;
            return;
        };

        let hov_pos = [hov_node.x, hov_node.y];
        let hov_color = self.node_color(&hov_node.node_type);
        let field_color = [hov_color[0], hov_color[1], hov_color[2], 0.12];

        let mut segments: Vec<LineEdgeInstance> = Vec::new();
        const FIELD_LINES_PER_NEIGHBOR: usize = 3;
        const FIELD_SEGMENTS: usize = 6;

        // Find neighbors.
        for edge in &graph.edges {
            let neighbor_id = if edge.source == hov_id {
                edge.target
            } else if edge.target == hov_id {
                edge.source
            } else {
                continue;
            };

            let Some(neighbor) = graph.nodes.iter().find(|n| n.id == neighbor_id && n.visible) else {
                continue;
            };

            let n_pos = [neighbor.x, neighbor.y];
            let dx = n_pos[0] - hov_pos[0];
            let dy = n_pos[1] - hov_pos[1];
            let dist = (dx * dx + dy * dy).sqrt().max(1.0);
            let px = -dy / dist;
            let py = dx / dist;

            // Generate multiple field lines with different offsets.
            for line_i in 0..FIELD_LINES_PER_NEIGHBOR {
                let offset_t = (line_i as f32 - 1.0) * dist * 0.15;
                // Animate with time for shimmering.
                let shimmer = (time * 0.8 + line_i as f32 * 1.5).sin() * dist * 0.04;
                let cp_offset = offset_t + shimmer;

                let cp = [
                    (hov_pos[0] + n_pos[0]) * 0.5 + px * cp_offset,
                    (hov_pos[1] + n_pos[1]) * 0.5 + py * cp_offset,
                ];

                // Tessellate this field line.
                let mut prev = hov_pos;
                for seg in 1..=FIELD_SEGMENTS {
                    let t = seg as f32 / FIELD_SEGMENTS as f32;
                    let next = bezier_point(hov_pos, cp, n_pos, t);
                    segments.push(LineEdgeInstance {
                        p0: prev,
                        p1: next,
                        color: field_color,
                    });
                    prev = next;
                }
            }
        }

        self.field_line_count = segments.len();
        if self.field_line_count > 0 {
            let buf_size = (self.field_line_count * std::mem::size_of::<LineEdgeInstance>()) as u64;
            self.field_line_buf = Some(self.device.new_buffer_with_data(
                segments.as_ptr() as *const c_void,
                buf_size,
                MTLResourceOptions::StorageModeShared,
            ));
        } else {
            self.field_line_buf = None;
        }
    }

    const CAMERA_LAMBDA: f32 = 8.0;

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

    pub fn upload_labels(&mut self, graph: &Graph) {
        const LABEL_GAP: f32 = 4.0;

        if !self.labels_enabled {
            self.glyph_count = 0;
            self.glyph_instance_buf = None;
            return;
        }

        let zoom = self.camera_zoom;
        let fade_start = self.label_fade_start;
        let fade_end = self.label_fade_end;
        let font_size = self.label_font_size;
        let mut all_instances: Vec<GlyphInstance> = Vec::new();

        for node in &graph.nodes {
            if !node.visible { continue; }
            let screen_radius = node.radius * zoom;
            if screen_radius < fade_start { continue; }

            let size_alpha =
                ((screen_radius - fade_start) / (fade_end - fade_start)).clamp(0.0, 1.0);
            let weight_boost = if node.link_count > 5 { 1.0 } else { 0.7 };
            let mut alpha = size_alpha * weight_boost;

            // Dim labels for non-highlighted nodes.
            if self.highlight.active && !self.highlight.highlighted_ids.contains(&node.id) {
                alpha *= DIM_ALPHA;
            }
            if alpha < 0.01 { continue; }

            let anchor = [node.x, node.y + node.radius + LABEL_GAP];
            let color = if self.light_mode {
                [0.08f32, 0.08, 0.10, 1.0]
            } else {
                [1.0f32, 1.0, 1.0, 1.0]
            };

            let glyphs = self.font_atlas.layout_label(&node.label, anchor, font_size, alpha, color);
            all_instances.extend_from_slice(&glyphs);
        }

        self.glyph_count = all_instances.len();

        if self.glyph_count == 0 {
            self.glyph_instance_buf = None;
            return;
        }

        if self.glyph_count > self.glyph_instance_capacity || self.glyph_instance_buf.is_none() {
            // Need a bigger buffer — allocate with headroom.
            self.glyph_instance_capacity = (self.glyph_count * 3 / 2).max(256);
            let buf_size = (self.glyph_instance_capacity * std::mem::size_of::<GlyphInstance>()) as u64;
            self.glyph_instance_buf = Some(
                self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
        }

        // Write glyph data into the existing (or newly allocated) buffer in-place.
        if let Some(buf) = &self.glyph_instance_buf {
            unsafe {
                std::ptr::copy_nonoverlapping(
                    all_instances.as_ptr(),
                    buf.contents() as *mut GlyphInstance,
                    self.glyph_count,
                );
            }
        }
    }

    /// Ensure offscreen textures exist and match viewport size.
    fn ensure_offscreen_textures(&mut self, w: u32, h: u32) {
        if self.offscreen_width == w && self.offscreen_height == h
            && self.offscreen_texture.is_some()
        {
            return;
        }
        let desc = TextureDescriptor::new();
        desc.set_texture_type(MTLTextureType::D2);
        desc.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
        desc.set_width(w as u64);
        desc.set_height(h as u64);
        desc.set_storage_mode(MTLStorageMode::Private);
        desc.set_usage(MTLTextureUsage::RenderTarget | MTLTextureUsage::ShaderRead);
        self.offscreen_texture = Some(self.device.new_texture(&desc));
        self.prev_frame_texture = Some(self.device.new_texture(&desc));
        self.offscreen_width = w;
        self.offscreen_height = h;
    }

    pub fn draw(&mut self, viewport_width: u32, viewport_height: u32) {
        // Pre-compute state before entering autoreleasepool (avoids borrow conflicts).
        let cam_vel = [
            self.camera_offset[0] - self.prev_camera_offset[0],
            self.camera_offset[1] - self.prev_camera_offset[1],
        ];
        let zoom_vel = self.camera_zoom - self.prev_camera_zoom;
        self.prev_camera_offset = self.camera_offset;
        self.prev_camera_zoom = self.camera_zoom;

        // Ensure offscreen textures before getting drawable (avoids &self / &mut self conflict).
        self.ensure_offscreen_textures(viewport_width, viewport_height);

        let has_motion = cam_vel[0].abs() > 0.01
            || cam_vel[1].abs() > 0.01
            || zoom_vel.abs() > 0.0005;

        autoreleasepool(|| {
            let drawable = match self.layer.next_drawable() {
                Some(d) => d,
                None => return,
            };

            let ripple_time = self.ripple_start
                .map(|s| s.elapsed().as_secs_f32())
                .unwrap_or(-1.0);

            let uniforms = Uniforms {
                viewport_size: [viewport_width as f32, viewport_height as f32],
                camera_offset: self.camera_offset,
                camera_zoom: self.camera_zoom,
                time: self.start_time.elapsed().as_secs_f32(),
                ripple_origin: self.ripple_origin,
                ripple_time,
                focal_length: 2.0,
                camera_velocity: cam_vel,
                zoom_velocity: zoom_vel,
                _pad2: 0.0,
            };
            unsafe {
                let ptr = self.uniform_buf.contents() as *mut Uniforms;
                *ptr = uniforms;
            }

            // Determine scene render target: offscreen if motion blur active, drawable otherwise.
            let scene_texture = if has_motion {
                if let Some(ref tex) = self.offscreen_texture { tex } else { drawable.texture() }
            } else {
                drawable.texture()
            };

            // ── Pass 1: Scene render ──
            let render_desc = RenderPassDescriptor::new();
            let color = render_desc.color_attachments().object_at(0).unwrap();
            color.set_texture(Some(scene_texture));
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
                encoder.draw_primitives_instanced(
                    MTLPrimitiveType::Triangle,
                    0,
                    6,
                    total_instances as u64,
                );
            }

            // Draw MSDF text labels (on top)
            if self.glyph_count > 0
                && let Some(glyph_buf) = &self.glyph_instance_buf
            {
                encoder.set_render_pipeline_state(&self.msdf_pipeline);
                encoder.set_vertex_buffer(0, Some(glyph_buf), 0);
                encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                encoder.set_fragment_texture(0, Some(&self.msdf_atlas_texture));
                encoder.draw_primitives_instanced(
                    MTLPrimitiveType::Triangle,
                    0,
                    6,
                    self.glyph_count as u64,
                );
            }

            encoder.end_encoding();

            // ── Pass 2: Motion blur composite (only when camera is moving) ──
            if has_motion {
                if let (Some(offscreen), Some(prev)) =
                    (&self.offscreen_texture, &self.prev_frame_texture)
                {
                    let blur_desc = RenderPassDescriptor::new();
                    let blur_color = blur_desc.color_attachments().object_at(0).unwrap();
                    blur_color.set_texture(Some(drawable.texture()));
                    blur_color.set_load_action(MTLLoadAction::DontCare);
                    blur_color.set_store_action(MTLStoreAction::Store);

                    let blur_enc = cmd_buf.new_render_command_encoder(blur_desc);
                    blur_enc.set_render_pipeline_state(&self.post_pipeline);
                    blur_enc.set_vertex_buffer(0, Some(&self.post_vertex_buf), 0);
                    blur_enc.set_fragment_buffer(0, Some(&self.uniform_buf), 0);
                    blur_enc.set_fragment_texture(0, Some(offscreen));
                    blur_enc.set_fragment_texture(1, Some(prev));
                    blur_enc.draw_primitives(MTLPrimitiveType::Triangle, 0, 6);
                    blur_enc.end_encoding();
                }

                // Copy current offscreen to prev_frame for next frame's temporal blend.
                if let (Some(offscreen), Some(prev)) =
                    (&self.offscreen_texture, &self.prev_frame_texture)
                {
                    let blit = cmd_buf.new_blit_command_encoder();
                    blit.copy_from_texture(
                        offscreen,
                        0, 0,
                        MTLOrigin { x: 0, y: 0, z: 0 },
                        MTLSize { width: viewport_width as u64, height: viewport_height as u64, depth: 1 },
                        prev,
                        0, 0,
                        MTLOrigin { x: 0, y: 0, z: 0 },
                    );
                    blit.end_encoding();
                }
            }

            cmd_buf.present_drawable(drawable);
            cmd_buf.commit();
        });
    }
}
