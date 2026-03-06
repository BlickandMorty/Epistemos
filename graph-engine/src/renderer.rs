use std::ffi::c_void;

use metal::foreign_types::ForeignType;
use metal::*;
use objc::rc::autoreleasepool;

use crate::ecs::World;
use crate::types::{Graph, VisualTheme, VoxelPalette, edge_type_color, edge_type_color_light};

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
    pulse_origin: [f32; 2],  // world-space origin of click pulse wave
    pulse_time: f32,         // time of pulse start (0 = no active pulse)
    focal_length: f32,       // perspective focal distance (2.0 default)
    camera_velocity: [f32; 2], // camera offset delta (world units/frame)
    zoom_velocity: f32,        // zoom delta per frame (for motion blur)
    lite_mode: f32,            // 0.0 = cinematic, 1.0 = balanced, 2.0 = performance
    impact_intensity: f32,     // 1.0 on heavy collision → 0.0 (chromatic aberration)
    _pad: f32,                 // pad to 64 bytes (Metal 16-byte struct alignment)
}

// ── Pixel art GPU data structs (must match PIXEL_SHADER_SOURCE layouts) ──────

/// Per-instance data for pixel art node rendering (square block with optional glare).
#[repr(C)]
#[derive(Clone, Copy)]
struct PixelNodeInstance {
    position: [f32; 2],       // offset 0  — world position (snapped in shader)
    size: f32,                // offset 8  — block size in offscreen pixels
    _pad0: f32,               // offset 12 — align base_color to 16 bytes
    base_color: [f32; 4],     // offset 16
    highlight_color: [f32; 4],// offset 32 — glare highlight (top-left)
    shadow_color: [f32; 4],   // offset 48 — glare shadow (bottom-right)
    has_glare: u32,           // offset 64 — 0 or 1
    _pad1: [u32; 3],          // offset 68 — pad to 80 bytes (16-byte aligned)
}

/// Per-instance data for pixel art edge rendering (jagged line with jitter).
#[repr(C)]
#[derive(Clone, Copy)]
struct PixelEdgeInstance {
    p0: [f32; 2],             // offset 0
    p1: [f32; 2],             // offset 8
    color: [f32; 4],          // offset 16
    edge_id: u32,             // offset 32 — deterministic jitter seed
    _pad: [u32; 3],           // offset 36 — pad to 48 bytes (16-byte aligned)
}

/// Uniform data for pixel art shaders (simpler than classic: no perspective, no animation).
#[repr(C)]
#[derive(Clone, Copy)]
struct PixelUniforms {
    viewport_size: [f32; 2],  // offscreen texture size (low-res)
    camera_offset: [f32; 2],
    camera_zoom: f32,
    frame_count: u32,         // for edge jitter
    _pad0: f32,
    _pad1: f32,
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

// ── Pixel Art Metal Shader Source ──────────────────────────────────────────

const PIXEL_SHADER_SOURCE: &str = r#"
#include <metal_stdlib>
using namespace metal;

// Pixel art uniforms — simpler than classic (no perspective, no animation)
struct PixelUniforms {
    float2 viewport_size;    // offscreen texture size (low-res)
    float2 camera_offset;
    float camera_zoom;
    uint frame_count;        // for edge jitter
    float _pad0;
    float _pad1;
};

// ── Pixel Node (square block with optional glare) ──

struct PixelNodeInstance {
    float2 position;        // world position (will be snapped to integer in shader)
    float  size;            // block size in offscreen pixels
    float  _pad0;
    float4 base_color;
    float4 highlight_color; // glare highlight (top-left)
    float4 shadow_color;    // glare shadow (bottom-right)
    uint   has_glare;       // 0 or 1
    uint3  _pad1;
};

struct PixelNodeOut {
    float4 position [[position]];
    float2 uv;             // 0..1 across the block
    uint   has_glare;
    float4 base_color;
    float4 highlight_color;
    float4 shadow_color;
};

vertex PixelNodeOut pixel_node_vertex(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    constant PixelNodeInstance* nodes [[buffer(0)]],
    constant PixelUniforms& u [[buffer(1)]]
) {
    // 6-vertex quad (two triangles)
    float2 corners[6] = {
        float2(-0.5, -0.5), float2(0.5, -0.5), float2(-0.5, 0.5),
        float2(-0.5, 0.5), float2(0.5, -0.5), float2(0.5, 0.5)
    };

    PixelNodeInstance node = nodes[iid];
    float2 corner = corners[vid];

    // Snap world position to integer pixel grid
    float2 world_pos = round(node.position);

    // Camera transform to screen space
    float2 screen = (world_pos - u.camera_offset) * u.camera_zoom + corner * node.size;

    // Snap screen position to integer pixel in offscreen texture
    screen = round(screen);

    // NDC transform
    float2 ndc = screen / (u.viewport_size * 0.5);
    ndc.y = -ndc.y;

    PixelNodeOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv = corner + 0.5;  // 0..1
    out.has_glare = node.has_glare;
    out.base_color = node.base_color;
    out.highlight_color = node.highlight_color;
    out.shadow_color = node.shadow_color;
    return out;
}

fragment float4 pixel_node_fragment(PixelNodeOut in [[stage_in]]) {
    float4 color = in.base_color;

    if (in.has_glare != 0) {
        // 3-tone pixel glare: top-left highlight, center base, bottom-right shadow
        float2 uv = in.uv;

        if (uv.x < 0.3 && uv.y < 0.3) {
            color = in.highlight_color;
        } else if (uv.x > 0.7 && uv.y > 0.7) {
            color = in.shadow_color;
        }
    }

    return color;
}

// ── Pixel Edge (jagged line with hard cutoff) ──

struct PixelEdgeInstance {
    float2 p0;
    float2 p1;
    float4 color;
    uint   edge_id;   // for deterministic jitter
    uint3  _pad;
};

struct PixelEdgeOut {
    float4 position [[position]];
    float2 frag_coord;  // position on the quad in offscreen pixels
    float2 line_p0;
    float2 line_p1;
    float4 color;
    float  thickness;
};

vertex PixelEdgeOut pixel_edge_vertex(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    constant PixelEdgeInstance* edges [[buffer(0)]],
    constant PixelUniforms& u [[buffer(1)]]
) {
    PixelEdgeInstance edge = edges[iid];

    // Transform endpoints to screen space and snap
    float2 sp0 = round((edge.p0 - u.camera_offset) * u.camera_zoom);
    float2 sp1 = round((edge.p1 - u.camera_offset) * u.camera_zoom);

    // Deterministic jitter: subtle per-frame stair-step variance
    uint seed = edge.edge_id * 2654435761u + u.frame_count * 1013904223u;
    float jx = (float(seed & 0xFFu) / 255.0 - 0.5) * 1.5;
    float jy = (float((seed >> 8) & 0xFFu) / 255.0 - 0.5) * 1.5;
    sp0 += float2(jx, jy) * 0.3;
    sp1 += float2(jx, jy) * 0.3;
    // Re-snap after jitter
    sp0 = round(sp0);
    sp1 = round(sp1);

    // Build quad around the line segment with padding
    float2 dir = sp1 - sp0;
    float len = length(dir);
    if (len < 0.001) { len = 1.0; dir = float2(1, 0); }
    float2 norm = normalize(dir);
    float2 perp = float2(-norm.y, norm.x);
    float thickness = 1.0;  // 1 virtual pixel thick
    float pad = thickness + 1.0;

    // 6-vertex quad
    float2 offsets[6] = {
        float2(-pad, -pad), float2(len + pad, -pad), float2(-pad, pad),
        float2(-pad, pad), float2(len + pad, -pad), float2(len + pad, pad)
    };
    float2 offset = offsets[vid];
    float2 world = sp0 + norm * offset.x + perp * offset.y;

    float2 ndc = world / (u.viewport_size * 0.5);
    ndc.y = -ndc.y;

    PixelEdgeOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.frag_coord = world;
    out.line_p0 = sp0;
    out.line_p1 = sp1;
    out.color = edge.color;
    out.thickness = thickness;
    return out;
}

fragment float4 pixel_edge_fragment(PixelEdgeOut in [[stage_in]]) {
    // SDF distance to line segment — hard boolean cutoff
    float2 pa = in.frag_coord - in.line_p0;
    float2 ba = in.line_p1 - in.line_p0;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float dist = length(pa - ba * h);

    // Angle compensation for uniform perceived thickness
    float2 dir = normalize(ba);
    float angle_factor = abs(dot(dir, float2(1, 0)));
    float threshold = (in.thickness - 1.0 + angle_factor) * 0.5 + 0.5;

    // HARD binary cutoff — pixel ON or OFF. No smoothstep.
    if (dist > threshold) discard_fragment();

    return in.color;
}

// ── Upscale Pass (nearest-neighbor full-screen quad) ──

struct UpscaleOut {
    float4 position [[position]];
    float2 uv;
};

vertex UpscaleOut upscale_vertex(uint vid [[vertex_id]]) {
    // Full-screen quad from 6 vertices
    float2 positions[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1), float2(1, -1), float2(1, 1)
    };
    float2 uvs[6] = {
        float2(0, 1), float2(1, 1), float2(0, 0),
        float2(0, 0), float2(1, 1), float2(1, 0)
    };

    UpscaleOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = uvs[vid];
    return out;
}

fragment float4 upscale_fragment(
    UpscaleOut in [[stage_in]],
    texture2d<float> scene [[texture(0)]],
    sampler nearest [[sampler(0)]]
) {
    return scene.sample(nearest, in.uv);
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
    // ── Pixel art theme state ───────────────────────────────────────
    pub visual_theme: VisualTheme,
    pub pixel_scale: u8,
    pub pixel_palette: VoxelPalette,
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
    pixel_uniform_buf: Option<Buffer>,
    pixel_frame_count: u32,
    // ── Edge aggregation (cluster LOD) ────────────────────────────
    /// When true, use aggregated cluster edges instead of individual edges.
    pub use_aggregated_edges: bool,
    /// Cached aggregated edge count for the current frame.
    aggregated_edge_count: usize,
}

impl Renderer {
    #[inline]
    fn node_color(&self, node_type: &crate::types::NodeType) -> [f32; 4] {
        if self.light_mode { node_type.color_light() } else { node_type.color() }
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
            last_viewport_width: 1920.0,
            last_viewport_height: 1080.0,
            visual_theme: VisualTheme::Pixel,
            pixel_scale: 8,
            pixel_palette: VoxelPalette::dark(),
            pixel_offscreen_texture: None,
            pixel_offscreen_width: 0,
            pixel_offscreen_height: 0,
            pixel_nearest_sampler: None,
            pixel_node_pipeline: None,
            pixel_edge_pipeline: None,
            pixel_upscale_pipeline: None,
            pixel_node_buf: None,
            pixel_node_capacity: 0,
            pixel_edge_buf: None,
            pixel_edge_capacity: 0,
            pixel_uniform_buf: None,
            pixel_frame_count: 0,
            use_aggregated_edges: false,
            aggregated_edge_count: 0,
        })
    }

    /// Pre-allocate GPU buffers with headroom. Call once after commit.
    /// +2 for highlight rings, +hub_count for glow instances.
    pub fn allocate_buffers(&mut self, graph: &Graph) {
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

        self.upload_graph(graph);
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
    pub fn upload_graph(&mut self, graph: &Graph) {
        // Hub glow instances go first (rendered behind regular nodes via NDC z).
        let mut glow_instances: Vec<NodeInstance> = Vec::new();
        let mut instances: Vec<NodeInstance> = Vec::with_capacity(graph.nodes.len());

        for (_gi, node) in graph.nodes.iter().enumerate() {
            if !node.visible { continue; }
            let co = node.color_override;
            let color = if co[3] > 0.0 { co } else { self.node_color(&node.node_type) };

            let is_performance = self.quality_level >= 2;
            let is_cinematic = self.quality_level == 0;
            let z = if is_performance { 0.0 } else { z_for_link_count(node.link_count) };
            let pos = [node.x, node.y];

            // Glow effects: only in Cinematic mode (not Balanced or Performance).
            if is_cinematic {
                if node.link_count >= 9 {
                    glow_instances.push(NodeInstance {
                        position: pos,
                        radius: node.radius * HUB_GLOW_RADIUS_FACTOR,
                        z: z + HUB_GLOW_Z_OFFSET,
                        color: [color[0], color[1], color[2], HUB_GLOW_ALPHA],
                    });
                }

                if node.confidence > 0.0 {
                    let conf = node.confidence.clamp(0.0, 1.0);
                    let glow_radius = node.radius * (CONF_GLOW_RADIUS_BASE + conf * CONF_GLOW_RADIUS_SCALE);
                    let glow_alpha = CONF_GLOW_ALPHA_BASE + conf * CONF_GLOW_ALPHA_SCALE;
                    glow_instances.push(NodeInstance {
                        position: pos,
                        radius: glow_radius,
                        z: z + CONF_GLOW_Z_OFFSET,
                        color: [color[0], color[1], color[2], glow_alpha],
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

        // Append wind advection particles to glow section (low alpha = glow fragment path).
        if self.wind_active {
            for p in &self.wind_particles {
                glow_instances.push(NodeInstance {
                    position: [p[0], p[1]],
                    radius: 1.5,
                    z: -0.50,
                    color: [0.7, 0.85, 1.0, 0.08],
                });
            }
            self.wind_particle_count = self.wind_particles.len();
        } else {
            self.wind_particle_count = 0;
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

        // Build velocity buffer parallel to instance buffer (for squash & stretch).
        {
            let vel_count = total_node_instances + 2; // +2 for highlight rings
            if vel_count > self.node_velocity_capacity || self.node_velocity_buf.is_none() {
                let capacity = (vel_count * 3 / 2).max(64);
                let buf_size = (capacity * std::mem::size_of::<[f32; 2]>()) as u64;
                self.node_velocity_buf = Some(
                    self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
                );
                self.node_velocity_capacity = capacity;
            }
            if let Some(buf) = &self.node_velocity_buf {
                unsafe {
                    let ptr = buf.contents() as *mut [f32; 2];
                    let mut idx = 0;
                    // Glows: zero velocity
                    for _ in 0..self.glow_count {
                        *ptr.add(idx) = [0.0, 0.0];
                        idx += 1;
                    }
                    // Nodes: actual velocity
                    for node in graph.nodes.iter().filter(|n| n.visible) {
                        if idx < vel_count {
                            *ptr.add(idx) = [node.vx, node.vy];
                            idx += 1;
                        }
                    }
                    // Zero-fill remaining (highlight rings + padding)
                    while idx < vel_count {
                        *ptr.add(idx) = [0.0, 0.0];
                        idx += 1;
                    }
                }
            }
        }

        // Straight edge instances (one line segment per edge).
        let mut edge_instances: Vec<LineEdgeInstance> =
            Vec::with_capacity(graph.edges.len());

        for edge in &graph.edges {
            let si = graph.id_to_index.get(&edge.source);
            let ti = graph.id_to_index.get(&edge.target);
            if let (Some(&si), Some(&ti)) = (si, ti) {
                let src = &graph.nodes[si];
                let tgt = &graph.nodes[ti];
                if !src.visible || !tgt.visible { continue; }

                let p0 = [src.x, src.y];
                let p1 = [tgt.x, tgt.y];

                // Skip edges with uninitialized or degenerate positions.
                if (p0[0] == 0.0 && p0[1] == 0.0) || (p1[0] == 0.0 && p1[1] == 0.0) {
                    continue;
                }
                if !p0[0].is_finite() || !p0[1].is_finite() || !p1[0].is_finite() || !p1[1].is_finite() {
                    continue;
                }

                let base_edge = self.edge_color(edge.edge_type);
                let color = if self.highlight.active {
                    let src_lit = self.highlight.highlighted_ids.contains(&src.id);
                    let tgt_lit = self.highlight.highlighted_ids.contains(&tgt.id);
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
                    [
                        base_edge[0] + stress * (TENSION_COLOR[0] - base_edge[0]),
                        base_edge[1] + stress * (TENSION_COLOR[1] - base_edge[1]),
                        base_edge[2] + stress * (TENSION_COLOR[2] - base_edge[2]),
                        base_edge[3] + stress * (TENSION_COLOR[3] - base_edge[3]),
                    ]
                } else {
                    base_edge
                };

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

    /// Upload aggregated cluster edges to the edge instance buffer.
    /// Called by engine when zoom < AGGREGATION_THRESHOLD.
    pub fn upload_aggregated_edges(&mut self, edges: &[crate::edge_aggregation::AggregatedEdge]) {
        self.use_aggregated_edges = !edges.is_empty();
        if edges.is_empty() {
            self.aggregated_edge_count = 0;
            return;
        }

        let count = edges.len();
        // Ensure buffer capacity
        if count > self.edge_instance_capacity || self.edge_instance_buf.is_none() {
            let capacity = (count * 3 / 2).max(64);
            let buf_size = (capacity * std::mem::size_of::<LineEdgeInstance>()) as u64;
            self.edge_instance_buf = Some(
                self.device.new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.edge_instance_capacity = capacity;
        }

        if let Some(buf) = &self.edge_instance_buf {
            // SAFETY: count <= edge_instance_capacity, buffer allocated above.
            unsafe {
                let ptr = buf.contents() as *mut LineEdgeInstance;
                for (i, agg) in edges.iter().enumerate() {
                    // Neutral aggregate color: gray with computed alpha
                    let base = if self.light_mode {
                        [0.35, 0.35, 0.40]
                    } else {
                        [0.55, 0.55, 0.60]
                    };
                    *ptr.add(i) = LineEdgeInstance {
                        p0: agg.p0,
                        p1: agg.p1,
                        color: [base[0], base[1], base[2], agg.alpha],
                    };
                }
            }
        }
        self.aggregated_edge_count = count;
    }

    /// Clear aggregated edge mode (return to individual edges).
    pub fn clear_aggregated_edges(&mut self) {
        self.use_aggregated_edges = false;
        self.aggregated_edge_count = 0;
    }

    /// Update positions in-place (called every frame after sync_positions).
    /// Buffer layout: [glow_count glows] [node_count nodes] [highlight rings].
    pub fn update_positions(&mut self, graph: &Graph) {
        let mut visible_count = 0usize;
        let mut glow_idx = 0usize;
        if let Some(buf) = &self.node_instance_buf {
            unsafe {
                let ptr = buf.contents() as *mut NodeInstance;
                for (_gi, node) in graph.nodes.iter().enumerate() {
                    if !node.visible { continue; }

                    let pos = [node.x, node.y];
                    let z = z_for_link_count(node.link_count);

                    // Update glow instances (Cinematic only — matches upload_graph gate).
                    let is_cinematic = self.quality_level == 0;
                    if is_cinematic {
                        if node.link_count >= 9 && glow_idx < self.glow_count {
                            let glow = &mut *ptr.add(glow_idx);
                            glow.position = pos;
                            glow.z = z + HUB_GLOW_Z_OFFSET;
                            glow.color[3] = HUB_GLOW_ALPHA;
                            glow_idx += 1;
                        }
                        if node.confidence > 0.0 && glow_idx < self.glow_count {
                            let conf = node.confidence.clamp(0.0, 1.0);
                            let glow = &mut *ptr.add(glow_idx);
                            glow.position = pos;
                            glow.z = z + CONF_GLOW_Z_OFFSET;
                            glow.color[3] = CONF_GLOW_ALPHA_BASE + conf * CONF_GLOW_ALPHA_SCALE;
                            glow_idx += 1;
                        }
                    }

                    // Update regular node instance (offset past glow instances).
                    let inst = &mut *ptr.add(self.glow_count + visible_count);
                    inst.position = pos;
                    inst.z = z;

                    let co = node.color_override;
                    let mut color = if co[3] > 0.0 { co } else { self.node_color(&node.node_type) };
                    color[3] *= BASE_NODE_ALPHA;
                    inst.color = color;

                    visible_count += 1;
                }
            }
        }
        // Update wind particle physics (positions computed CPU-side).
        let vp = [self.last_viewport_width, self.last_viewport_height];
        let zm = self.camera_zoom;
        self.update_wind_particles(vp, zm);
        // Update existing particle positions in the glow section of the buffer.
        // Particles are only present if upload_graph() included them (wind_particle_count > 0).
        // The buffer layout from upload_graph: [real_glows][wind_particles][nodes][highlights].
        // Real glows end at glow_idx, particles start there.
        if self.wind_particle_count > 0 {
            if let Some(buf) = &self.node_instance_buf {
                unsafe {
                    let ptr = buf.contents() as *mut NodeInstance;
                    for (i, p) in self.wind_particles.iter().enumerate() {
                        if glow_idx + i < self.node_instance_capacity {
                            let inst = &mut *ptr.add(glow_idx + i);
                            inst.position = [p[0], p[1]];
                        }
                    }
                }
            }
        }
        // glow_count includes wind particles (set by upload_graph).
        self.glow_count = glow_idx + self.wind_particle_count;
        self.node_count = visible_count;

        // Update velocity buffer in-place (parallel to instance buffer).
        if let Some(buf) = &self.node_velocity_buf {
            unsafe {
                let ptr = buf.contents() as *mut [f32; 2];
                let mut vi = 0;
                // Glows: zero velocity
                for _ in 0..self.glow_count {
                    if vi < self.node_velocity_capacity {
                        *ptr.add(vi) = [0.0, 0.0];
                        vi += 1;
                    }
                }
                // Nodes: actual velocity
                for node in graph.nodes.iter().filter(|n| n.visible) {
                    if vi < self.node_velocity_capacity {
                        *ptr.add(vi) = [node.vx, node.vy];
                        vi += 1;
                    }
                }
            }
        }

        if self.node_count == 0 {
            self.edge_instance_count = 0;
            return;
        }

        // Update curved edge positions in-place.
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

                        let p0 = [src.x, src.y];
                        let p1 = [tgt.x, tgt.y];

                        // Skip uninitialized/degenerate positions (prevents streaks).
                        if (p0[0] == 0.0 && p0[1] == 0.0) || (p1[0] == 0.0 && p1[1] == 0.0) {
                            continue;
                        }
                        if !p0[0].is_finite() || !p0[1].is_finite() || !p1[0].is_finite() || !p1[1].is_finite() {
                            continue;
                        }

                        let base_edge = self.edge_color(edge.edge_type);
                        let color = if self.highlight.active {
                            let src_lit = self.highlight.highlighted_ids.contains(&src.id);
                            let tgt_lit = self.highlight.highlighted_ids.contains(&tgt.id);
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
                            let mut e = [
                                base_edge[0] + stress * (TENSION_COLOR[0] - base_edge[0]),
                                base_edge[1] + stress * (TENSION_COLOR[1] - base_edge[1]),
                                base_edge[2] + stress * (TENSION_COLOR[2] - base_edge[2]),
                                base_edge[3] + stress * (TENSION_COLOR[3] - base_edge[3]),
                            ];
                            e[3] *= BASE_NODE_ALPHA;
                            e
                        } else {
                            let mut e = base_edge;
                            e[3] *= BASE_NODE_ALPHA;
                            e
                        };

                        if inst_idx < self.edge_instance_capacity {
                            let inst = &mut *ptr.add(inst_idx);
                            inst.p0 = p0;
                            inst.p1 = p1;
                            inst.color = color;
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

    // ── Pixel Art Pipeline ────────────────────────────────────────────

    /// Compile PIXEL_SHADER_SOURCE and create pipelines for node, edge, and upscale passes.
    fn create_pixel_pipelines(&mut self) {
        let library = match self.device.new_library_with_source(PIXEL_SHADER_SOURCE, &CompileOptions::new()) {
            Ok(lib) => lib,
            Err(e) => {
                eprintln!("pixel shader compile error: {e}");
                return;
            }
        };

        let make_pipeline = |vert_name: &str, frag_name: &str, blend: bool| -> Option<RenderPipelineState> {
            let vert = library.get_function(vert_name, None).ok()?;
            let frag = library.get_function(frag_name, None).ok()?;
            let desc = RenderPipelineDescriptor::new();
            desc.set_vertex_function(Some(&vert));
            desc.set_fragment_function(Some(&frag));
            let color_attach = desc.color_attachments().object_at(0)?;
            color_attach.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
            if blend {
                color_attach.set_blending_enabled(true);
                color_attach.set_source_rgb_blend_factor(MTLBlendFactor::SourceAlpha);
                color_attach.set_destination_rgb_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
                color_attach.set_source_alpha_blend_factor(MTLBlendFactor::One);
                color_attach.set_destination_alpha_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
            }
            self.device.new_render_pipeline_state(&desc).ok()
        };

        self.pixel_node_pipeline = make_pipeline("pixel_node_vertex", "pixel_node_fragment", true);
        self.pixel_edge_pipeline = make_pipeline("pixel_edge_vertex", "pixel_edge_fragment", true);
        self.pixel_upscale_pipeline = make_pipeline("upscale_vertex", "upscale_fragment", false);
    }

    /// Create or resize the offscreen texture for the low-res pixel art pass.
    fn ensure_pixel_offscreen(&mut self, w: u32, h: u32) {
        if self.pixel_offscreen_width == w && self.pixel_offscreen_height == h && self.pixel_offscreen_texture.is_some() {
            return;
        }
        let desc = TextureDescriptor::new();
        desc.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
        desc.set_width(w as u64);
        desc.set_height(h as u64);
        desc.set_storage_mode(MTLStorageMode::Private);
        desc.set_usage(MTLTextureUsage::RenderTarget | MTLTextureUsage::ShaderRead);
        self.pixel_offscreen_texture = Some(self.device.new_texture(&desc));
        self.pixel_offscreen_width = w;
        self.pixel_offscreen_height = h;
    }

    /// Create a nearest-neighbor sampler for the upscale pass.
    fn create_pixel_sampler(&mut self) {
        let desc = SamplerDescriptor::new();
        desc.set_min_filter(MTLSamplerMinMagFilter::Nearest);
        desc.set_mag_filter(MTLSamplerMinMagFilter::Nearest);
        desc.set_mip_filter(MTLSamplerMipFilter::NotMipmapped);
        desc.set_address_mode_s(MTLSamplerAddressMode::ClampToEdge);
        desc.set_address_mode_t(MTLSamplerAddressMode::ClampToEdge);
        self.pixel_nearest_sampler = Some(self.device.new_sampler(&desc));
    }

    /// Build the pixel art node instance buffer from ECS World data.
    /// Returns the number of instances written.
    fn build_pixel_node_instances(&mut self, world: &World, palette: &VoxelPalette) -> usize {
        let n = world.len();
        if n == 0 { return 0; }

        if n > self.pixel_node_capacity {
            let cap = (n * 3 / 2).max(64);
            let size = (cap * std::mem::size_of::<PixelNodeInstance>()) as u64;
            self.pixel_node_buf = Some(self.device.new_buffer(size, MTLResourceOptions::StorageModeShared));
            self.pixel_node_capacity = cap;
        }

        let buf = self.pixel_node_buf.as_ref().unwrap();
        let ptr = buf.contents() as *mut PixelNodeInstance;

        for i in 0..n {
            let block_type = world.render[i].block_type;
            let co = world.render[i].color_override;
            let base = if co[3] > 0.0 { co } else { palette.color_for_block(block_type) };

            // Size from block type: Core=16, Primary=12, Secondary=10, Tertiary=8, Leaf=6
            let size = match block_type {
                0 => 16.0_f32, 1 => 12.0, 2 => 10.0, 3 => 8.0, 4 => 6.0, _ => 8.0,
            };

            let highlight = [
                (base[0] + 0.3).min(1.0),
                (base[1] + 0.3).min(1.0),
                (base[2] + 0.3).min(1.0),
                base[3],
            ];
            let shadow = [
                (base[0] - 0.3).max(0.0),
                (base[1] - 0.3).max(0.0),
                (base[2] - 0.3).max(0.0),
                base[3],
            ];

            // SAFETY: i < n <= pixel_node_capacity, buffer was allocated above.
            unsafe {
                *ptr.add(i) = PixelNodeInstance {
                    position: [world.transform[i].x, world.transform[i].y],
                    size,
                    _pad0: 0.0,
                    base_color: base,
                    highlight_color: highlight,
                    shadow_color: shadow,
                    has_glare: world.render[i].has_glare as u32,
                    _pad1: [0; 3],
                };
            }
        }
        n
    }

    /// Build the pixel art edge instance buffer from Graph data.
    /// Returns the number of instances written.
    fn build_pixel_edge_instances(&mut self, graph: &Graph, palette: &VoxelPalette) -> usize {
        let edge_count = graph.edges.len();
        if edge_count == 0 { return 0; }

        if edge_count > self.pixel_edge_capacity {
            let cap = (edge_count * 3 / 2).max(64);
            let size = (cap * std::mem::size_of::<PixelEdgeInstance>()) as u64;
            self.pixel_edge_buf = Some(self.device.new_buffer(size, MTLResourceOptions::StorageModeShared));
            self.pixel_edge_capacity = cap;
        }

        let buf = self.pixel_edge_buf.as_ref().unwrap();
        let ptr = buf.contents() as *mut PixelEdgeInstance;
        let mut count = 0usize;

        for (ei, edge) in graph.edges.iter().enumerate() {
            let si = graph.id_to_index.get(&edge.source);
            let ti = graph.id_to_index.get(&edge.target);
            if let (Some(&si), Some(&ti)) = (si, ti) {
                let src = &graph.nodes[si];
                let tgt = &graph.nodes[ti];
                if !src.visible || !tgt.visible { continue; }

                let p0 = [src.x, src.y];
                let p1 = [tgt.x, tgt.y];

                if (p0[0] == 0.0 && p0[1] == 0.0) || (p1[0] == 0.0 && p1[1] == 0.0) { continue; }
                if !p0[0].is_finite() || !p0[1].is_finite() || !p1[0].is_finite() || !p1[1].is_finite() { continue; }

                if count < self.pixel_edge_capacity {
                    // SAFETY: count < pixel_edge_capacity, buffer was allocated above.
                    unsafe {
                        *ptr.add(count) = PixelEdgeInstance {
                            p0,
                            p1,
                            color: palette.edge,
                            edge_id: ei as u32,
                            _pad: [0; 3],
                        };
                    }
                    count += 1;
                }
            }
        }
        count
    }

    /// Two-pass pixel art render: low-res offscreen then nearest-neighbor upscale.
    pub fn draw_pixel(&mut self, viewport_w: u32, viewport_h: u32, world: &World, graph: &Graph) {
        self.last_viewport_width = viewport_w as f32;
        self.last_viewport_height = viewport_h as f32;

        let scale = self.pixel_scale as u32;
        let vw = (viewport_w / scale).max(1);
        let vh = (viewport_h / scale).max(1);

        // Lazy-init pipelines and sampler
        if self.pixel_node_pipeline.is_none() { self.create_pixel_pipelines(); }
        if self.pixel_nearest_sampler.is_none() { self.create_pixel_sampler(); }

        // Bail if pipelines failed to compile — clone handles immediately to release borrows.
        let node_pipeline = match &self.pixel_node_pipeline { Some(p) => p.clone(), None => return };
        let edge_pipeline = match &self.pixel_edge_pipeline { Some(p) => p.clone(), None => return };
        let upscale_pipeline = match &self.pixel_upscale_pipeline { Some(p) => p.clone(), None => return };
        let sampler = match &self.pixel_nearest_sampler { Some(s) => s.clone(), None => return };

        // Ensure offscreen texture at correct size
        self.ensure_pixel_offscreen(vw, vh);
        let offscreen_tex = match &self.pixel_offscreen_texture { Some(t) => t.clone(), None => return };

        let palette = self.pixel_palette; // Copy — avoids &self borrow conflict with &mut self methods

        // Build instance buffers
        let node_count = self.build_pixel_node_instances(world, &palette);
        let edge_count = self.build_pixel_edge_instances(graph, &palette);

        // Ensure uniform buffer exists
        if self.pixel_uniform_buf.is_none() {
            self.pixel_uniform_buf = Some(self.device.new_buffer(
                std::mem::size_of::<PixelUniforms>() as u64,
                MTLResourceOptions::StorageModeShared,
            ));
        }

        // Write uniforms
        let uniforms = PixelUniforms {
            viewport_size: [vw as f32, vh as f32],
            camera_offset: self.camera_offset,
            camera_zoom: self.camera_zoom / scale as f32,
            frame_count: self.pixel_frame_count,
            _pad0: 0.0,
            _pad1: 0.0,
        };
        if let Some(ubuf) = &self.pixel_uniform_buf {
            // SAFETY: buffer is sized for PixelUniforms, single writer.
            unsafe {
                let ptr = ubuf.contents() as *mut PixelUniforms;
                *ptr = uniforms;
            }
        }
        self.pixel_frame_count = self.pixel_frame_count.wrapping_add(1);

        let bg = palette.background;

        autoreleasepool(|| {
            let drawable = match self.layer.next_drawable() {
                Some(d) => d,
                None => return,
            };

            let cmd_buf = self.command_queue.new_command_buffer();

            // ── PASS 1: Render to low-res offscreen ──────────────────
            {
                let pass_desc = RenderPassDescriptor::new();
                let Some(color) = pass_desc.color_attachments().object_at(0) else { return; };
                color.set_texture(Some(&offscreen_tex));
                color.set_load_action(MTLLoadAction::Clear);
                color.set_clear_color(MTLClearColor::new(
                    bg[0] as f64, bg[1] as f64, bg[2] as f64, bg[3] as f64,
                ));
                color.set_store_action(MTLStoreAction::Store);

                let enc = cmd_buf.new_render_command_encoder(pass_desc);

                // Draw edges first (behind nodes)
                if edge_count > 0 {
                    if let (Some(ebuf), Some(ubuf)) = (&self.pixel_edge_buf, &self.pixel_uniform_buf) {
                        enc.set_render_pipeline_state(&edge_pipeline);
                        enc.set_vertex_buffer(0, Some(ebuf), 0);
                        enc.set_vertex_buffer(1, Some(ubuf), 0);
                        enc.draw_primitives_instanced(
                            MTLPrimitiveType::Triangle, 0, 6, edge_count as u64,
                        );
                    }
                }

                // Draw nodes
                if node_count > 0 {
                    if let (Some(nbuf), Some(ubuf)) = (&self.pixel_node_buf, &self.pixel_uniform_buf) {
                        enc.set_render_pipeline_state(&node_pipeline);
                        enc.set_vertex_buffer(0, Some(nbuf), 0);
                        enc.set_vertex_buffer(1, Some(ubuf), 0);
                        enc.draw_primitives_instanced(
                            MTLPrimitiveType::Triangle, 0, 6, node_count as u64,
                        );
                    }
                }

                enc.end_encoding();
            }

            // ── PASS 2: Upscale to drawable ──────────────────────────
            {
                let pass_desc = RenderPassDescriptor::new();
                let Some(color) = pass_desc.color_attachments().object_at(0) else { return; };
                color.set_texture(Some(drawable.texture()));
                color.set_load_action(MTLLoadAction::DontCare);
                color.set_store_action(MTLStoreAction::Store);

                let enc = cmd_buf.new_render_command_encoder(pass_desc);
                enc.set_render_pipeline_state(&upscale_pipeline);
                enc.set_fragment_texture(0, Some(&offscreen_tex));
                enc.set_fragment_sampler_state(0, Some(&sampler));
                enc.draw_primitives(MTLPrimitiveType::Triangle, 0, 6);
                enc.end_encoding();
            }

            cmd_buf.present_drawable(drawable);
            cmd_buf.commit();
        });
    }

    pub fn draw(&mut self, viewport_width: u32, viewport_height: u32, _world: &World, _graph: &Graph) {
        self.last_viewport_width = viewport_width as f32;
        self.last_viewport_height = viewport_height as f32;
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

    // ── Pixel art struct layout tests ────────────────────────────────

    #[test]
    fn pixel_node_instance_size() {
        // position(8) + size(4) + _pad0(4) + base_color(16) + highlight_color(16)
        // + shadow_color(16) + has_glare(4) + _pad1(12) = 80 bytes.
        assert_eq!(std::mem::size_of::<PixelNodeInstance>(), 80);
    }

    #[test]
    fn pixel_node_instance_alignment() {
        // Must be 4-byte aligned at minimum for Metal buffer binding.
        assert!(std::mem::align_of::<PixelNodeInstance>() >= 4);
    }

    #[test]
    fn pixel_edge_instance_size() {
        // p0(8) + p1(8) + color(16) + edge_id(4) + _pad(12) = 48 bytes.
        assert_eq!(std::mem::size_of::<PixelEdgeInstance>(), 48);
    }

    #[test]
    fn pixel_edge_instance_alignment() {
        assert!(std::mem::align_of::<PixelEdgeInstance>() >= 4);
    }

    #[test]
    fn pixel_uniforms_size() {
        // viewport_size(8) + camera_offset(8) + camera_zoom(4) + frame_count(4)
        // + _pad0(4) + _pad1(4) = 32 bytes.
        assert_eq!(std::mem::size_of::<PixelUniforms>(), 32);
    }

    #[test]
    fn pixel_uniforms_alignment() {
        assert!(std::mem::align_of::<PixelUniforms>() >= 4);
    }

    #[test]
    fn pixel_node_instance_16_byte_aligned_size() {
        // Metal requires buffer contents to be 16-byte aligned for structs.
        assert_eq!(std::mem::size_of::<PixelNodeInstance>() % 16, 0);
    }

    #[test]
    fn pixel_edge_instance_16_byte_aligned_size() {
        assert_eq!(std::mem::size_of::<PixelEdgeInstance>() % 16, 0);
    }

    #[test]
    fn pixel_uniforms_16_byte_aligned_size() {
        assert_eq!(std::mem::size_of::<PixelUniforms>() % 16, 0);
    }
}
