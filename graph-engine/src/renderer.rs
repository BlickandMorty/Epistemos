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
    face_type: f32, // offset 32 — 0=none, 1=note..8=block, -1=face feature, -2/-3=highlight rings
    _pad: [f32; 3], // offset 36 — alignment padding to 48 bytes (Metal float4 → 16-byte struct stride)
}

const FACE_FEATURE_TYPE: f32 = -1.0;
const SELECTED_HIGHLIGHT_RING_TYPE: f32 = -2.0;
const HOVER_HIGHLIGHT_RING_TYPE: f32 = -3.0;

/// Per-instance data for straight-line edge rendering.
#[repr(C)]
#[derive(Clone, Copy)]
struct LineEdgeInstance {
    p0: [f32; 2],      // offset 0
    p1: [f32; 2],      // offset 8
    color: [f32; 4],   // offset 16
    thickness_px: f32, // offset 32
    _pad: [f32; 3],    // offset 36
}

/// Per-instance data for cubic graph-edge rendering.
#[repr(C)]
#[derive(Clone, Copy)]
struct CurveEdgeInstance {
    p0: [f32; 2],
    c0: [f32; 2],
    c1: [f32; 2],
    p1: [f32; 2],
    color: [f32; 4],
    thickness_px: f32,
    _pad: [f32; 3],
}

/// State for the FFT-style dialogue box overlay.
#[derive(Clone)]
pub(crate) struct DialogueState {
    pub active: bool,
    pub node_index: Option<usize>,
    pub is_streaming: bool,
    pub look_target_world: [f32; 2],
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
            look_target_world: [0.0; 2],
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

#[derive(Clone, Copy)]
struct DialogueBoxGeometry {
    left: f32,
    right: f32,
    top: f32,
    bottom: f32,
    screen_rect: [f32; 4],
    node_screen_pos: [f32; 2],
}

const DIALOGUE_VIEWPORT_MARGIN_SCREEN: f32 = 18.0;

#[derive(Clone, Copy, Debug, PartialEq)]
struct DialogueLayoutMetrics {
    box_screen_width: f32,
    box_screen_height: f32,
    tail_screen_height: f32,
    gap_screen: f32,
    side_gap_screen: f32,
    compact: bool,
}

fn dialogue_layout_metrics(zoom: f32) -> DialogueLayoutMetrics {
    if zoom < 0.38 {
        DialogueLayoutMetrics {
            box_screen_width: 620.0,
            box_screen_height: 340.0,
            tail_screen_height: 22.0,
            gap_screen: 28.0,
            side_gap_screen: 80.0,
            compact: true,
        }
    } else if zoom < 0.82 {
        DialogueLayoutMetrics {
            box_screen_width: 820.0,
            box_screen_height: 480.0,
            tail_screen_height: 30.0,
            gap_screen: 34.0,
            side_gap_screen: 90.0,
            compact: false,
        }
    } else {
        DialogueLayoutMetrics {
            box_screen_width: 960.0,
            box_screen_height: 560.0,
            tail_screen_height: 36.0,
            gap_screen: 38.0,
            side_gap_screen: 100.0,
            compact: false,
        }
    }
}

/// Uniform data sent to all shaders (camera transform + animation).
#[repr(C)]
#[derive(Clone, Copy)]
struct Uniforms {
    viewport_size: [f32; 2],
    camera_offset: [f32; 2],
    camera_zoom: f32,
    time: f32,                 // elapsed seconds — drives breathing animation
    pulse_origin: [f32; 2],    // world-space origin of click pulse wave
    pulse_time: f32,           // time of pulse start (0 = no active pulse)
    focal_length: f32,         // perspective focal distance (2.0 default)
    camera_velocity: [f32; 2], // camera offset delta (world units/frame)
    zoom_velocity: f32,        // zoom delta per frame (for motion blur)
    lite_mode: f32,            // 0.0 = cinematic, 1.0 = balanced, 2.0 = performance
    impact_intensity: f32,     // 1.0 on heavy collision → 0.0 (chromatic aberration)
    dialogue_theme: f32,       // 1.0 = dialogue mode, 0.0 = classic
    vignette_strength: f32,    // 0.0 = off, 1.0 = heavy edge darkening (radial focus field)
    light_mode: f32,           // 0.0 = dark background, 1.0 = light background
    water_style: f32,          // 0.0 = retro pixel, 1.0 = water-bead shading
    water_wobble: f32,         // 0.0 = still, 1.0 = breathing radius
    edge_style: f32,           // 0.0 = smooth, 1.0 = pixel-art hard edge
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct ViewBounds {
    pub(crate) min_x: f32,
    pub(crate) min_y: f32,
    pub(crate) max_x: f32,
    pub(crate) max_y: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct LodProfile {
    draw_edges: bool,
    draw_glow: bool,
    cluster_nodes: bool,
    edge_degree_threshold: u32,
    max_edges_per_node: u16,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum EdgeGeometryKind {
    Curve,
    Straight,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum EdgeStyle {
    Smooth,
    PixelArt,
}

impl EdgeStyle {
    pub(crate) fn from_u8(value: u8) -> Self {
        if value == 1 {
            Self::PixelArt
        } else {
            Self::Smooth
        }
    }

    fn as_uniform(self) -> f32 {
        match self {
            Self::Smooth => 0.0,
            Self::PixelArt => 1.0,
        }
    }
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

#[cfg(any(test, debug_assertions))]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
struct RenderDebugCounters {
    upload_graph_calls: usize,
    update_positions_calls: usize,
    classic_buffer_rebuilds: usize,
    node_highlight_uploads: usize,
    edge_highlight_uploads: usize,
    field_line_buffer_allocations: usize,
    field_line_buffer_reuses: usize,
    last_total_nodes: usize,
    last_visible_nodes: usize,
    last_total_edges: usize,
    last_candidate_edges: usize,
    last_visible_edges: usize,
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

#[inline]
fn sort_and_dedup_indices(indices: &mut Vec<usize>) {
    indices.sort_unstable();
    indices.dedup();
}

#[inline]
fn aggregated_edge_base_rgb(light_mode: bool) -> [f32; 3] {
    if light_mode {
        [0.08, 0.09, 0.11]
    } else {
        [0.78, 0.82, 0.88]
    }
}

fn clamp_dialogue_box_left(
    preferred_left: f32,
    camera_offset_x: f32,
    zoom: f32,
    viewport_width: f32,
    box_width_world: f32,
) -> f32 {
    let view_half_w = viewport_width * 0.5 / zoom;
    let margin_world = DIALOGUE_VIEWPORT_MARGIN_SCREEN / zoom;
    let min_left = camera_offset_x - view_half_w + margin_world;
    let max_left = camera_offset_x + view_half_w - margin_world - box_width_world;
    if min_left <= max_left {
        preferred_left.clamp(min_left, max_left)
    } else {
        preferred_left
    }
}

fn clamp_dialogue_box_top(
    preferred_top: f32,
    camera_offset_y: f32,
    zoom: f32,
    viewport_height: f32,
    box_height_world: f32,
    max_top_before_overlap: f32,
) -> f32 {
    let view_half_h = viewport_height * 0.5 / zoom;
    let margin_world = DIALOGUE_VIEWPORT_MARGIN_SCREEN / zoom;
    let min_top = camera_offset_y - view_half_h + margin_world;
    let max_top = (camera_offset_y + view_half_h - margin_world - box_height_world)
        .min(max_top_before_overlap);
    if min_top <= max_top {
        preferred_top.clamp(min_top, max_top)
    } else {
        preferred_top.min(max_top_before_overlap)
    }
}

fn face_blink_openness(time: f32, node_seed: f32, streaming: bool) -> f32 {
    let speed = if streaming { 0.42 } else { 0.28 };
    let phase = (time * speed + node_seed).fract();
    let blink = if (0.82..=0.96).contains(&phase) {
        let distance = ((phase - 0.89) / 0.07).abs().min(1.0);
        1.0 - distance
    } else {
        0.0
    };
    (1.0 - blink * 0.78).clamp(0.22, 1.0)
}

fn face_pupil_offset(node_center: [f32; 2], look_target: [f32; 2], max_offset: f32) -> [f32; 2] {
    let dx = look_target[0] - node_center[0];
    let dy = look_target[1] - node_center[1];
    let dist = (dx * dx + dy * dy).sqrt();
    if dist <= f32::EPSILON || max_offset <= f32::EPSILON {
        return [0.0, 0.0];
    }

    let scale = dist.min(max_offset) / dist;
    let mut offset = [dx * scale, dy * scale];
    let offset_len = (offset[0] * offset[0] + offset[1] * offset[1]).sqrt();
    if offset_len > max_offset {
        let correction = max_offset / offset_len;
        offset[0] *= correction;
        offset[1] *= correction;
    }
    offset
}

fn dialogue_box_vertical_layout(node_y: f32, node_radius: f32, zoom: f32) -> (f32, f32) {
    let layout = dialogue_layout_metrics(zoom);
    let tail_h_world = layout.tail_screen_height / zoom;
    let base_gap_world = layout.gap_screen / zoom;
    let face_clearance_world =
        (node_radius * 1.12).max(if layout.compact { 58.0 } else { 76.0 } / zoom);
    let tail_tip_y = node_y - node_radius - base_gap_world - face_clearance_world;
    let box_bottom_y = tail_tip_y - tail_h_world;
    (box_bottom_y, tail_tip_y)
}

fn dialogue_node_radius(
    visual_theme: VisualTheme,
    base_radius: f32,
    _node_type: u8,
    _link_count: u32,
    _encoded_alpha: f32,
) -> f32 {
    if visual_theme != VisualTheme::Dialogue {
        return base_radius;
    }
    // No radius inflation — depth palette colors provide the dialogue styling.
    base_radius
}

fn string_edge_control_points(
    p0: [f32; 2],
    p1: [f32; 2],
    v0: [f32; 2],
    v1: [f32; 2],
    ideal_length: f32,
    curvature: f32,
) -> ([f32; 2], [f32; 2]) {
    let dx = p1[0] - p0[0];
    let dy = p1[1] - p0[1];
    let length = (dx * dx + dy * dy).sqrt();
    if length <= f32::EPSILON || curvature <= 0.0 {
        let handle = length * 0.25;
        return ([p0[0] + handle, p0[1]], [p1[0] - handle, p1[1]]);
    }

    let direction = [dx / length, dy / length];
    let normal = [-direction[1], direction[0]];
    let ideal = ideal_length.max(1.0);
    let slack = ((ideal - length) / ideal).clamp(0.0, 0.75);
    let tension = ((length - ideal) / ideal).clamp(0.0, 1.25);
    let relative_velocity = [v1[0] - v0[0], v1[1] - v0[1]];
    let normal_motion = (relative_velocity[0] * normal[0] + relative_velocity[1] * normal[1])
        .clamp(-180.0, 180.0)
        / 180.0;

    let handle = length * (0.20 + curvature * 0.26 + slack * 0.12);
    let velocity_gain = (0.08 + slack * 0.14) * (1.0 - tension * 0.45).max(0.35);
    let sag = (length * curvature * (0.18 + slack * 0.70) * (1.0 - tension * 0.7).max(0.14)
        + normal_motion * length * 0.08)
        .clamp(-length * 0.28, length * 0.28);

    let c0 = [
        p0[0] + direction[0] * handle + normal[0] * sag + v0[0] * velocity_gain,
        p0[1] + direction[1] * handle + normal[1] * sag + v0[1] * velocity_gain,
    ];
    let c1 = [
        p1[0] - direction[0] * handle + normal[0] * sag - v1[0] * velocity_gain,
        p1[1] - direction[1] * handle + normal[1] * sag - v1[1] * velocity_gain,
    ];
    (c0, c1)
}

#[cfg(test)]
fn cubic_bezier_point(p0: [f32; 2], c0: [f32; 2], c1: [f32; 2], p1: [f32; 2], t: f32) -> [f32; 2] {
    let one_minus_t = 1.0 - t;
    let a = one_minus_t * one_minus_t * one_minus_t;
    let b = 3.0 * one_minus_t * one_minus_t * t;
    let c = 3.0 * one_minus_t * t * t;
    let d = t * t * t;
    [
        a * p0[0] + b * c0[0] + c * c1[0] + d * p1[0],
        a * p0[1] + b * c0[1] + c * c1[1] + d * p1[1],
    ]
}

fn curve_intersects_bounds(
    bounds: ViewBounds,
    p0: [f32; 2],
    c0: [f32; 2],
    c1: [f32; 2],
    p1: [f32; 2],
) -> bool {
    let min_x = p0[0].min(c0[0]).min(c1[0]).min(p1[0]);
    let max_x = p0[0].max(c0[0]).max(c1[0]).max(p1[0]);
    let min_y = p0[1].min(c0[1]).min(c1[1]).min(p1[1]);
    let max_y = p0[1].max(c0[1]).max(c1[1]).max(p1[1]);
    max_x >= bounds.min_x && min_x <= bounds.max_x && max_y >= bounds.min_y && min_y <= bounds.max_y
}

pub(crate) fn lod_profile_for_zoom(_zoom: f32, quality_level: u8) -> LodProfile {
    match quality_level {
        0 => LodProfile {
            draw_edges: true,
            draw_glow: false,
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
            edge_degree_threshold: u32::MAX,
            max_edges_per_node: u16::MAX,
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

#[inline]
fn edge_intersects_view(
    bounds: Option<ViewBounds>,
    p0: [f32; 2],
    p1: [f32; 2],
    c0: [f32; 2],
    c1: [f32; 2],
) -> bool {
    bounds.is_none_or(|view| {
        segment_intersects_bounds(view, p0, p1) || curve_intersects_bounds(view, p0, c0, c1, p1)
    })
}

#[inline]
fn display_velocity(vx: f32, vy: f32) -> [f32; 2] {
    const MIN_SPEED_SQ: f32 = 36.0;
    const MAX_DISPLAY_SPEED: f32 = 72.0;
    const DISPLAY_SCALE: f32 = 0.25;

    let speed_sq = vx * vx + vy * vy;
    if speed_sq <= MIN_SPEED_SQ {
        return [0.0, 0.0];
    }

    let speed = speed_sq.sqrt();
    let scale = DISPLAY_SCALE * (MAX_DISPLAY_SPEED / speed).min(1.0);
    [vx * scale, vy * scale]
}

#[inline]
fn render_velocity(vx: f32, vy: f32, suppress_motion: bool) -> [f32; 2] {
    if suppress_motion {
        [0.0, 0.0]
    } else {
        display_velocity(vx, vy)
    }
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
        0..=2 => -0.40, // Background: leaf nodes recede deeper
        3..=5 => -0.10, // Lower-mid: slightly behind
        6..=8 => 0.12,  // Upper-mid: slightly forward
        _ => 0.50,      // Foreground: hub nodes closest to viewer
    }
}

/// Base alpha multiplier for all nodes — subtler ambient presence.
const BASE_NODE_ALPHA: f32 = 1.0;
const MIN_EDGE_WIDTH_PX: f32 = 0.70;
const MAX_EDGE_WIDTH_PX: f32 = 4.00;
/// Dimmed node alpha when highlight is active — near-ghost for unfocused nodes.
#[allow(dead_code)]
const DIM_ALPHA: f32 = 0.04;

fn edge_width_px_for_weight(weight: f32, p0_radius: f32, p1_radius: f32) -> f32 {
    let t = weight.clamp(0.0, 1.0);
    let weighted = MIN_EDGE_WIDTH_PX + (MAX_EDGE_WIDTH_PX - MIN_EDGE_WIDTH_PX) * t.powf(0.6);
    let min_endpoint_radius = p0_radius.min(p1_radius).max(0.0);
    let endpoint_limit = min_endpoint_radius * 0.6 * 2.0;
    if endpoint_limit > MIN_EDGE_WIDTH_PX {
        weighted.min(endpoint_limit)
    } else {
        MIN_EDGE_WIDTH_PX
    }
}

fn edge_color_with_endpoint_palette(
    base: [f32; 4],
    source_override: [f32; 4],
    target_override: [f32; 4],
) -> [f32; 4] {
    let source_has_color = source_override[3] > 0.0;
    let target_has_color = target_override[3] > 0.0;
    if !source_has_color && !target_has_color {
        return base;
    }

    let tint = match (source_has_color, target_has_color) {
        (true, true) => [
            (source_override[0] + target_override[0]) * 0.5,
            (source_override[1] + target_override[1]) * 0.5,
            (source_override[2] + target_override[2]) * 0.5,
            1.0,
        ],
        (true, false) => source_override,
        (false, true) => target_override,
        (false, false) => base,
    };

    [
        base[0] * 0.30 + tint[0] * 0.70,
        base[1] * 0.30 + tint[1] * 0.70,
        base[2] * 0.30 + tint[2] * 0.70,
        base[3],
    ]
}

#[inline]
fn monochrome_graph_node_color(light_mode: bool, node_type: u8, depth: u32) -> [f32; 4] {
    let _ = depth;
    let node_type = crate::types::NodeType::from_u8(node_type);
    match node_type {
        crate::types::NodeType::Folder => {
            if light_mode {
                [0.0, 0.0, 0.0, 1.0]
            } else {
                [1.0, 1.0, 1.0, 1.0]
            }
        }
        _ if light_mode => node_type.color_light(),
        _ => node_type.color(),
    }
}

// ── Glow constants (shared between upload_graph and update_positions) ─────
const HUB_GLOW_Z_OFFSET: f32 = -0.12;
const HUB_GLOW_ALPHA: f32 = 0.06; // lowered from 0.08 to reduce overdraw saturation
const HUB_GLOW_RADIUS_FACTOR: f32 = 2.2; // tightened from 2.5 to reduce overlap area
/// Max glow instances to prevent overdraw saturation in dense graphs.
/// With 1131 nodes, ~50 may qualify as hubs — rendering all of them at
/// 2.2x radius creates massive overlapping translucent quads. Cap to 24
/// for a good visual effect without GPU fill-rate thrashing.
const MAX_GLOW_INSTANCES: usize = 24;
const CONF_GLOW_Z_OFFSET: f32 = -0.06;
const CONF_GLOW_RADIUS_BASE: f32 = 1.5;
const CONF_GLOW_RADIUS_SCALE: f32 = 1.0;
const CONF_GLOW_ALPHA_BASE: f32 = 0.03;
const CONF_GLOW_ALPHA_SCALE: f32 = 0.08;
#[cfg(test)]
const GLOW_INSTANCE_ALPHA_CUTOFF: f32 = 0.15;
const CURVE_EDGE_STRIP_SEGMENTS: usize = 20;

fn attach_command_buffer_logging(cmd_buf: &CommandBufferRef, label: &'static str) {
    let block = block::ConcreteBlock::new(move |buffer: &CommandBufferRef| {
        if buffer.status() == MTLCommandBufferStatus::Error {
            eprintln!("[graph-engine] GPU command buffer failed in {label}");
        }
    })
    .copy();
    cmd_buf.add_completed_handler(&block);
}

/// Convert an sRGB perceptual color to linear space (Rust side).
/// Alpha channel is left unchanged (alpha is always linear).
#[inline]
fn srgb_to_linear_rgba(c: [f32; 4]) -> [f32; 4] {
    [c[0].powf(2.2), c[1].powf(2.2), c[2].powf(2.2), c[3]]
}

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

// Convert a perceptual sRGB color to linear space for correct blending.
// With BGRA8Unorm_sRGB framebuffer, the hardware does linear→sRGB on write,
// so all shader math must be in linear space. Constants authored as perceptual
// values need this conversion.
float3 srgb_to_linear(float3 c) {
    // Simplified gamma approximation: pow(c, 2.2).
    // Full sRGB transfer uses a piecewise function, but pow(2.2) is within
    // 0.3% for values > 0.04 — sufficient for visual color constants.
    return pow(c, float3(2.2));
}

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
    float dialogue_theme;   // 1.0 = dialogue mode, 0.0 = classic
    float vignette_strength; // 0.0 = off, 1.0 = heavy edge darkening
    float light_mode;        // 0.0 = dark bg, 1.0 = light bg
    float water_style;       // 0.0 = retro pixel, 1.0 = water-bead
    float water_wobble;      // 0.0 = still, 1.0 = breathing radius
    float edge_style;        // 0.0 = smooth, 1.0 = pixel-art hard edge
};

constant float GLOW_INSTANCE_ALPHA_CUTOFF = 0.15;

// ── Node shaders (instanced circles with depth perspective) ──────────

struct NodeInstance {
    float2 position;
    float  radius;
    float  z;
    float4 color;
    float  face_type;   // 0=none, 1=note..8=block, -1=face feature, -2/-3=highlight rings
    float  _pad[3];     // alignment padding to 48 bytes (float4 → 16-byte struct stride)
};

struct NodeVertexOut {
    float4 position [[position]];
    float4 color;
    float2 uv;
    float  face_type;
    float  depth;
    float  highlight_dim;  // 1.0 = normal, <1.0 = dimmed
    float  desaturate;     // 0.0 = full color, 1.0 = grayscale
    float  is_lite;        // 1.0 = lite mode, 0.0 = full mode
    float2 world_pos;      // world-space base position for pulse wave
    float  node_radius_world;
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
    bool dialogue_theme = uniforms.dialogue_theme > 0.5;

    // Performance keeps the old motion deformation. Cinematic v1 is the hard
    // pixel graph identity, so node silhouettes stay stable instead of wobbling
    // like water beads.
    float2 vel = velocities[instance_id];
    float speed = length(vel);
    if (uniforms.lite_mode > 1.5 && speed > 1.0) {
        float stretch_amount = min(speed * 0.002, 0.25);
        float2 dir = vel / speed;
        float2 perp = float2(-dir.y, dir.x);
        float stretch = 1.0 + stretch_amount;
        float compress = 1.0 / stretch;
        corner = dir * dot(corner, dir) * stretch + perp * dot(corner, perp) * compress;
    }

    float depth;
    float effective_radius;
    if (uniforms.lite_mode > 0.5) {
        // Balanced + Performance: keep static depth tiers but skip animated parallax.
        depth = inst.z;
        effective_radius = inst.radius;
    } else {
        // Keep classic nodes visually stable at rest instead of continuously pulsing.
        depth = dialogue_theme ? inst.z * 0.35 : inst.z;
        float perspective_scale = uniforms.focal_length / (uniforms.focal_length - depth);
        effective_radius = inst.radius * perspective_scale;
    }

    // Water wobble
    if (uniforms.water_wobble > 0.001) {
        float seed = fract(sin(dot(inst.position, float2(12.9898, 78.233))) * 43758.5453);
        float phase = seed * 6.2831853;
        float t = uniforms.time;
        float wobble = sin(t * 1.35 + phase) * 0.6 + sin(t * 2.1 + phase * 1.7) * 0.4;
        effective_radius *= 1.0 + wobble * 0.04 * uniforms.water_wobble;
    }

    if (uniforms.lite_mode < 0.5) {
        const float cinematic_world_scale = 1.18;
        const float cinematic_min_world_radius = 13.0;
        effective_radius = max(
            effective_radius * cinematic_world_scale,
            cinematic_min_world_radius
        );
    }

    float2 base_pos = inst.position;
    float2 world_pos = base_pos + corner * effective_radius;

    float2 screen = (world_pos - uniforms.camera_offset) * uniforms.camera_zoom;
    float2 ndc = screen / (uniforms.viewport_size * 0.5) * float2(1, -1);
    float ndc_z = 0.5 - depth * 0.1;

    // Highlight flags: 0=normal, 1=highlighted (selected+neighbors), 2=dim-dark,
    // 3=dim-light, 5=glow-dim.
    uchar flag = highlight_flags[instance_id];
    float highlight_dim = flag == 0 ? 1.0
                        : (flag == 1 ? 1.0    // highlighted: stays natural in both modes
                        : (flag == 2 ? 0.10   // dark mode: strong dim for unselected
                        : (flag == 3 ? 0.50   // light mode: pure color, low alpha = faded/transparent
                        : (float(flag) / 255.0))));
    // Desaturation only for dark mode dim. Light mode handles dim by darkening
    // the color (below), not by graying it — grayscale on white bg = white.
    float desaturate = (flag == 2) ? 1.0 : 0.0;

    NodeVertexOut out;
    out.position = float4(ndc, ndc_z, 1.0);
    out.color = inst.color;
    out.uv = corner;
    out.depth = depth;
    out.highlight_dim = highlight_dim;
    out.desaturate = desaturate;
    out.is_lite = uniforms.lite_mode;
    out.world_pos = base_pos;
    out.node_radius_world = effective_radius;
    out.face_type = inst.face_type;
    return out;
}

fragment float4 node_fragment(
    NodeVertexOut in [[stage_in]],
    constant Uniforms& uniforms [[buffer(1)]]
) {
    bool dialogue_theme = uniforms.dialogue_theme > 0.5;
    float dist = length(in.uv);
    if (in.highlight_dim < 0.001) discard_fragment();

    if (in.face_type <= -2.0) {
        bool selected_ring = in.face_type > -2.5;
        float inner = selected_ring ? 0.76 : 0.84;
        float outer = selected_ring ? 0.98 : 0.97;
        float feather = selected_ring ? 0.06 : 0.05;
        float ring = smoothstep(inner, inner + feather, dist)
            * (1.0 - smoothstep(outer - feather, outer, dist));
        float halo = (1.0 - smoothstep(outer - 0.03, 1.0, dist))
            * (selected_ring ? 0.32 : 0.18);
        float alpha = in.color.a * max(ring, halo);
        if (alpha < 0.01) discard_fragment();

        float3 ring_color = in.color.rgb + halo * srgb_to_linear(float3(0.18, 0.24, 0.30));
        return float4(ring_color, alpha);
    }

    // ── Glow instances: soft radial gradient, no sphere shading ──
    // Detected by low alpha (glow alpha is 0.03–0.11, regular nodes are 0.5+).
    if (in.color.a < GLOW_INSTANCE_ALPHA_CUTOFF) {
        float glow = 1.0 - smoothstep(0.0, 1.0, dist);
        glow = glow * glow; // Quadratic falloff for soft edge
        // Pulsing aura: phase offset by world position so hubs pulse independently.
        if (in.is_lite < 0.5 && dialogue_theme) {
            glow *= 1.0 + 0.25 * sin(uniforms.time * 2.0 + length(in.world_pos) * 0.01);
        }
        if (glow < 0.01) discard_fragment();
        float3 glow_rgb = in.color.rgb;
        if (in.desaturate > 0.5) {
            float lum = dot(glow_rgb, float3(0.299, 0.587, 0.114));
            glow_rgb = mix(glow_rgb, float3(lum), 0.85);
        }
        return float4(glow_rgb, in.color.a * glow * in.highlight_dim);
    }

    // ── Cinematic: hard stepped pixel-circle nodes ──
    // This is the v1 graph identity. It stays inside the same instanced
    // world/camera renderer as the fast path, so zooming is real camera zoom
    // rather than a screen-space SVG overlay scaling up.
    bool performance_mode = in.is_lite > 1.5;
    bool cinematic_mode = in.is_lite < 0.5;
    bool light = uniforms.light_mode > 0.5;
    bool folder_node = in.face_type > 3.5 && in.face_type < 4.5;
    bool large_folder_node = folder_node && in.depth >= 0.45;
    if (cinematic_mode) {
        const float pixel_grid = 9.0;
        float2 pixel_cell = floor((in.uv * 0.5 + 0.5) * pixel_grid);
        float2 pixel_uv = ((pixel_cell + 0.5) / pixel_grid) * 2.0 - 1.0;
        float pixel_dist = length(pixel_uv);
        if (pixel_dist > 0.96) discard_fragment();

        float3 pixel_color = in.color.rgb;
        if (large_folder_node) {
            float2 folder_light_dir = normalize(float2(-0.62, -0.78));
            float folder_light_band = dot(pixel_uv, folder_light_dir);
            float folder_pixel_glare = smoothstep(0.34, 0.78, folder_light_band)
                * (1.0 - smoothstep(0.06, 0.82, pixel_dist));
            float folder_pixel_shadow = smoothstep(0.36, 0.90, -folder_light_band)
                * smoothstep(0.28, 0.94, pixel_dist);
            float3 folder_glare_color = light
                ? srgb_to_linear(float3(0.16, 0.16, 0.16))
                : srgb_to_linear(float3(1.00, 1.00, 1.00));
            float3 folder_shadow_color = light
                ? srgb_to_linear(float3(0.00, 0.00, 0.00))
                : srgb_to_linear(float3(0.72, 0.72, 0.72));
            pixel_color = mix(pixel_color, folder_glare_color, folder_pixel_glare * 0.24);
            pixel_color = mix(pixel_color, folder_shadow_color, folder_pixel_shadow * 0.06);
        }
        if (uniforms.pulse_time >= 0.0) {
            float d_to_pulse = length(in.world_pos - uniforms.pulse_origin);
            float wave_radius = uniforms.pulse_time * 800.0;
            float ring_dist = abs(d_to_pulse - wave_radius);
            float ring_width = 58.0 + wave_radius * 0.14;
            float cinematic_click_wave = 1.0 - smoothstep(0.0, ring_width, ring_dist);
            float pulse_fade = 1.0 - smoothstep(0.0, 1.85, uniforms.pulse_time);
            cinematic_click_wave = floor(cinematic_click_wave * 4.0) / 4.0;
            float3 pulse_color = light
                ? srgb_to_linear(float3(0.82, 0.82, 0.82))
                : srgb_to_linear(float3(0.12, 0.12, 0.12));
            pixel_color = mix(pixel_color, pulse_color, cinematic_click_wave * pulse_fade * 0.45);
        }

        bool cinematic_dimmed = in.highlight_dim < 0.99 && in.highlight_dim > 0.001;
        if (cinematic_dimmed) {
            float3 selection_dim_target = light
                ? srgb_to_linear(float3(0.12, 0.12, 0.12))
                : srgb_to_linear(float3(0.06, 0.06, 0.06));
            pixel_color = mix(pixel_color, selection_dim_target, light ? 0.56 : 0.58);
            if (in.desaturate > 0.5) {
                float lum = dot(pixel_color, float3(0.299, 0.587, 0.114));
                pixel_color = mix(pixel_color, float3(lum), 0.45);
            }
        }

        return float4(pixel_color, max(in.color.a, 0.95));
    }

    // ── Balanced + Performance: shared node shading ──
    // Performance keeps a lighter static version of the default shading so the
    // graph reads similarly while still skipping the cinematic extras.
    bool water = uniforms.water_style > 0.5;
    float base_pixel_strength = performance_mode ? 0.45 : (light ? 0.35 : 0.6);
    float pixel_strength = water ? 0.0 : base_pixel_strength;
    float grid = performance_mode ? 10.0 : 12.0;
    // Large hub detection (for retro shine effect only — grid/strength unchanged).
    bool is_large_hub = in.depth >= 0.45;
    float2 quv = floor(in.uv * grid + 0.5) / grid;
    float2 final_uv = mix(in.uv, quv, pixel_strength);
    float qdist = length(final_uv);
    float smooth_alpha = 1.0 - smoothstep(0.85, 1.0, dist);
    float pixel_alpha = qdist < 0.92 ? 1.0 : 0.0;
    float alpha = mix(smooth_alpha, pixel_alpha, pixel_strength);
    if (alpha < 0.01) discard_fragment();

    if (folder_node || !water) {
        float3 result_color = in.color.rgb;
        if (large_folder_node) {
            float2 folder_light_dir = normalize(float2(-0.62, -0.78));
            float folder_light_band = dot(final_uv, folder_light_dir);
            float folder_pixel_glare = smoothstep(0.34, 0.78, folder_light_band)
                * (1.0 - smoothstep(0.06, 0.82, qdist));
            float folder_pixel_shadow = smoothstep(0.36, 0.90, -folder_light_band)
                * smoothstep(0.28, 0.94, qdist);
            float3 folder_glare_color = light
                ? srgb_to_linear(float3(0.16, 0.16, 0.16))
                : srgb_to_linear(float3(1.00, 1.00, 1.00));
            float3 folder_shadow_color = light
                ? srgb_to_linear(float3(0.00, 0.00, 0.00))
                : srgb_to_linear(float3(0.72, 0.72, 0.72));
            result_color = mix(result_color, folder_glare_color, folder_pixel_glare * 0.20);
            result_color = mix(result_color, folder_shadow_color, folder_pixel_shadow * 0.05);
        }

        bool is_dimmed = in.highlight_dim < 0.99 && in.highlight_dim > 0.001;
        if (is_dimmed) {
            float3 selection_dim_target = light
                ? srgb_to_linear(float3(0.12, 0.12, 0.12))
                : srgb_to_linear(float3(0.06, 0.06, 0.06));
            result_color = mix(result_color, selection_dim_target, folder_node ? 0.52 : 0.40);
        }
        if (in.desaturate > 0.5 && !folder_node) {
            float lum = dot(result_color, float3(0.299, 0.587, 0.114));
            result_color = mix(result_color, float3(lum), 0.85);
        }
        float dim_alpha_floor = is_dimmed ? 0.95 : 0.85;
        return float4(result_color, max(in.color.a * alpha, dim_alpha_floor));
    }

    float r2 = dot(final_uv, final_uv);
    float nz = sqrt(max(1.0 - r2, 0.0));

    float3 light_dir = normalize(float3(-0.35, -0.5, 0.8));
    float3 normal = float3(final_uv.x, final_uv.y, nz);
    float diffuse = max(dot(normal, light_dir), 0.0);
    float lighting;
    if (performance_mode) { lighting = 0.58 + 0.42 * diffuse; }
    else if (light) { lighting = 0.68 + 0.32 * diffuse; }
    else { lighting = 0.45 + 0.55 * diffuse; }

    float bands = performance_mode ? 3.0 : 4.0;
    float stepped_lighting = floor(lighting * bands + 0.5) / bands;
    lighting = mix(lighting, stepped_lighting, pixel_strength);

    float3 view_dir = float3(0, 0, 1);
    float3 half_vec = normalize(light_dir + view_dir);
    float2 grid_pos = floor(in.uv * grid + 0.5);
    float spec;
    if (water) { spec = pow(max(dot(normal, half_vec), 0.0), 96.0) * 0.85; } else
    if (performance_mode) {
        float soft_spec = max(dot(normal, half_vec), 0.0);
        spec = soft_spec * soft_spec * 0.08;
    } else {
        spec = pow(max(dot(normal, half_vec), 0.0), 32.0);
        bool checker = fmod(grid_pos.x + grid_pos.y, 2.0) < 1.0;
        float pixel_spec = (spec > 0.3 && checker) ? 0.4 : 0.0;
        spec = mix(spec * 0.3, pixel_spec, pixel_strength);
    }

    float rim = 1.0 - nz;
    float rim_glow;
    if (water) { rim_glow = pow(rim, 2.4) * 0.55; }
    else { rim_glow = pow(rim, performance_mode ? 2.2 : 3.0) * (performance_mode ? 0.16 : 0.35); }
    float spec_scale = 1.0;
    float3 lit_color;
    if (water) {
        float bottom_shadow = smoothstep(0.25, 0.95, final_uv.y) * 0.18;
        float3 base = in.color.rgb * (0.62 + 0.38 * diffuse - bottom_shadow);
        float3 rim_tint = srgb_to_linear(float3(0.88, 0.94, 1.0));
        lit_color = base + spec * spec_scale * srgb_to_linear(float3(0.98, 0.99, 1.0)) + rim_tint * rim_glow * spec_scale;
    } else {
        float rim_mult = light ? 0.0 : 1.0;
        lit_color = in.color.rgb * lighting + spec * spec_scale + in.color.rgb * rim_glow * rim_mult;
    }

    // ── Retro vector shine for large hub nodes ──
    // 8-bit game sprite style: discrete brightness tiers (white → light grey → dark grey)
    // on the upper-left quadrant simulating a 2D point light. Quantized to 4 steps.
    if (is_large_hub && !performance_mode && !water) {
        // Angular position from upper-left (0,0 = top-left corner, light source origin).
        // shine_coord in [0,1]: 0 = directly under light, 1 = opposite side.
        float2 shine_dir = normalize(float2(-0.6, -0.8));
        float shine_coord = 0.5 + 0.5 * dot(final_uv, shine_dir);
        // Only apply inside the node (dist < 0.9) and away from the outline.
        float shine_mask = (1.0 - smoothstep(0.0, 0.85, dist)) * (1.0 - smoothstep(0.70, 0.85, dist));
        // Quantize to 4 retro tiers: white highlight → light grey → mid grey → skip.
        float shine_raw = clamp((1.0 - shine_coord) * 1.4, 0.0, 1.0);
        float shine_stepped = floor(shine_raw * 4.0) / 4.0; // 0, 0.25, 0.5, 0.75
        // Map tiers to brightness additions (linear space):
        //   tier 3 (shine_stepped=0.75): bright white highlight
        //   tier 2 (0.50): light grey
        //   tier 1 (0.25): dark grey (subtle)
        //   tier 0 (0.00): no shine
        float3 shine_rgb = float3(0.0);
        if (shine_stepped > 0.6) {
            shine_rgb = srgb_to_linear(float3(0.95, 0.95, 0.95)) * 0.25; // white
        } else if (shine_stepped > 0.35) {
            shine_rgb = srgb_to_linear(float3(0.75, 0.75, 0.75)) * 0.16; // light grey
        } else if (shine_stepped > 0.15) {
            shine_rgb = srgb_to_linear(float3(0.45, 0.45, 0.45)) * 0.08; // dark grey
        }
        lit_color += shine_rgb * shine_mask;
    }

    // Anime outline: dark ring near SDF boundary.
    if (!water) {
        float outline = smoothstep(0.73, 0.75, dist) * (1.0 - smoothstep(0.85, 0.87, dist));
        float outline_strength;
        if (performance_mode) { outline_strength = 0.26; }
        else if (light) { outline_strength = 0.18; }
        else { outline_strength = 0.6; }
        lit_color *= (1.0 - outline * outline_strength);
    }


    // Depth-of-field: far nodes fade slightly. Dimmed nodes (selection active) blur.
    float depth_fade = (in.is_lite < 0.5 && in.depth < -0.1) ? 0.65 : 1.0;
    float edge_softness = (in.is_lite < 0.5 && in.depth < -0.1) ? 0.75 : 0.85;

    bool is_dimmed = in.highlight_dim < 0.99 && in.highlight_dim > 0.001;
    // Distinguish light vs dark mode dim: dark dim = 0.20, light dim = 0.70.
    // Use 0.40 as the midpoint threshold.
    bool is_light_mode_dim = is_dimmed && in.highlight_dim >= 0.40;

    // Selection dim: dark mode softens the SDF edge (blur look); light mode
    // just darkens + drops opacity so the focused node reads clearly without
    // fighting the white background.
    if (is_dimmed && !is_light_mode_dim) {
        edge_softness = 0.45;
        depth_fade *= 0.85;
    }
    float effective_pixel_strength = pixel_strength;
    float dof_alpha = 1.0 - smoothstep(edge_softness, 1.0, dist);
    float final_alpha = mix(dof_alpha, alpha, effective_pixel_strength);

    // Dimmed color treatment:
    // Dark mode: mix 35% toward grayscale (defocused look).
    // Light mode: keep pure original color, just drop opacity further.
    float3 result_color = lit_color;
    if (is_dimmed) {
        float3 selection_dim_target = light
            ? srgb_to_linear(float3(0.12, 0.12, 0.12))
            : srgb_to_linear(float3(0.06, 0.06, 0.06));
        result_color = mix(lit_color, selection_dim_target, is_light_mode_dim ? 0.40 : 0.48);
    }

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
        result_color += ring_glow * srgb_to_linear(float3(0.5, 0.8, 1.0)); // cool blue-white
    }

    // ── Chromatic aberration on impact (cinematic only) ──
    if (in.is_lite < 0.5 && uniforms.impact_intensity > 0.0) {
        float ca = uniforms.impact_intensity * 0.12;
        result_color.r += ca * in.uv.x;
        result_color.b -= ca * in.uv.x;
    }

    // ── Grayscale desaturation for non-highlighted nodes ──
    if (in.desaturate > 0.5) {
        float lum = dot(result_color, float3(0.299, 0.587, 0.114));
        result_color = mix(result_color, float3(lum), 0.85);
    }

    float dim_alpha_floor = is_dimmed ? 0.95 : 0.85;
    return float4(result_color, max(in.color.a * final_alpha * depth_fade * in.highlight_dim, dim_alpha_floor));
}

// ── Edge shaders ───────────────────────────────────────────────────

constant uint CURVE_EDGE_SEGMENTS = 20;
constant float EDGE_DIM_ALPHA_SCALE = 0.15;
constant float EDGE_DIM_ALPHA_SCALE_LIGHT = 0.42;
constant float MIN_EDGE_WIDTH_PX = 0.70;
constant float MAX_EDGE_WIDTH_PX = 4.00;

struct CurveEdgeInstance {
    float2 p0;
    float2 c0;
    float2 c1;
    float2 p1;
    float4 color;
    float thickness_px;
    float3 _pad;
};

struct LineEdgeInstance {
    float2 p0;
    float2 p1;
    float4 color;
    float thickness_px;
    float3 _pad;
};

struct LineVertexOut {
    float4 position [[position]];
    float4 color [[flat]];
    float  dist_from_center;
    float  pixel_edge_style [[flat]];
};

float2 cubic_bezier_curve_point(float2 p0, float2 c0, float2 c1, float2 p1, float t) {
    float one_minus_t = 1.0 - t;
    float a = one_minus_t * one_minus_t * one_minus_t;
    float b = 3.0 * one_minus_t * one_minus_t * t;
    float c = 3.0 * one_minus_t * t * t;
    float d = t * t * t;
    return a * p0 + b * c0 + c * c1 + d * p1;
}

vertex LineVertexOut curve_edge_vertex(
    uint vertex_id [[vertex_id]],
    uint instance_id [[instance_id]],
    constant CurveEdgeInstance* instances [[buffer(0)]],
    constant Uniforms& u [[buffer(1)]],
    constant uchar* edge_flags [[buffer(2)]]
) {
    CurveEdgeInstance inst = instances[instance_id];
    uint segment = vertex_id / 6;
    uint corner = vertex_id % 6;
    float t0 = float(segment) / float(CURVE_EDGE_SEGMENTS);
    float t1 = float(segment + 1) / float(CURVE_EDGE_SEGMENTS);
    float2 p0 = cubic_bezier_curve_point(inst.p0, inst.c0, inst.c1, inst.p1, t0);
    float2 p1 = cubic_bezier_curve_point(inst.p0, inst.c0, inst.c1, inst.p1, t1);

    float2 screen0 = (p0 - u.camera_offset) * u.camera_zoom;
    float2 ndc0 = screen0 / (u.viewport_size * 0.5) * float2(1, -1);
    float2 screen1 = (p1 - u.camera_offset) * u.camera_zoom;
    float2 ndc1 = screen1 / (u.viewport_size * 0.5) * float2(1, -1);

    float2 dir = ndc1 - ndc0;
    float len = length(dir);
    if (len < 0.00001) dir = float2(1, 0);
    else dir /= len;

    float2 perp = float2(-dir.y, dir.x);
    float2 pixel_to_ndc = 2.0 / u.viewport_size;
    float half_width_px = clamp(inst.thickness_px, MIN_EDGE_WIDTH_PX, MAX_EDGE_WIDTH_PX) * 0.5;
    float2 offset = perp * half_width_px * pixel_to_ndc;

    float2 base_ndc[6] = {
        ndc0 - offset, ndc0 + offset,
        ndc1 - offset, ndc1 - offset,
        ndc0 + offset, ndc1 + offset,
    };

    float dist_vals[6] = { -1, 1, -1, -1, 1, 1 };

    LineVertexOut out;
    out.position = float4(base_ndc[corner], 0.0, 1.0);
    uchar flag = edge_flags[instance_id];
    if (flag == 1) {
        out.color = float4(srgb_to_linear(float3(0.70, 0.90, 1.00)), 0.75);
    } else if (flag == 2) {
        float lum = dot(inst.color.rgb, float3(0.299, 0.587, 0.114));
        out.color = float4(float3(lum), inst.color.a * EDGE_DIM_ALPHA_SCALE);
    } else if (flag == 3) {
        float3 focus_rgb = mix(inst.color.rgb, float3(0.02, 0.025, 0.035), 0.32);
        out.color = float4(focus_rgb, max(inst.color.a, 0.94));
    } else if (flag == 4) {
        float lum = dot(inst.color.rgb, float3(0.299, 0.587, 0.114));
        float3 dim_rgb = mix(inst.color.rgb, float3(lum), 0.70);
        out.color = float4(dim_rgb, inst.color.a * EDGE_DIM_ALPHA_SCALE_LIGHT);
    } else {
        out.color = inst.color;
    }
    out.dist_from_center = dist_vals[corner];
    out.pixel_edge_style = u.edge_style;
    return out;
}

vertex LineVertexOut line_edge_vertex(
    uint vertex_id [[vertex_id]],
    uint instance_id [[instance_id]],
    constant LineEdgeInstance* instances [[buffer(0)]],
    constant Uniforms& u [[buffer(1)]],
    constant uchar* edge_flags [[buffer(2)]]
) {
    LineEdgeInstance inst = instances[instance_id];

    float2 screen0 = (inst.p0 - u.camera_offset) * u.camera_zoom;
    float2 screen1 = (inst.p1 - u.camera_offset) * u.camera_zoom;

    if (u.edge_style > 0.5) {
        screen0 = round(screen0);
        screen1 = round(screen1);
    }

    float2 ndc0 = screen0 / (u.viewport_size * 0.5) * float2(1, -1);
    float2 ndc1 = screen1 / (u.viewport_size * 0.5) * float2(1, -1);

    // Direction and perpendicular in NDC space — constant screen-pixel width.
    float2 dir = ndc1 - ndc0;
    float len = length(dir);
    if (len < 0.00001) dir = float2(1, 0);
    else dir /= len;

    float2 perp = float2(-dir.y, dir.x);

    float2 pixel_to_ndc = 2.0 / u.viewport_size;
    float half_width_px = clamp(inst.thickness_px, MIN_EDGE_WIDTH_PX, MAX_EDGE_WIDTH_PX) * 0.5;
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
    uchar flag = edge_flags[instance_id];
    if (flag == 1) {
        out.color = float4(srgb_to_linear(float3(0.70, 0.90, 1.00)), 0.75);
    } else if (flag == 2) {
        float lum = dot(inst.color.rgb, float3(0.299, 0.587, 0.114));
        out.color = float4(float3(lum), inst.color.a * EDGE_DIM_ALPHA_SCALE);
    } else if (flag == 3) {
        float3 focus_rgb = mix(inst.color.rgb, float3(0.02, 0.025, 0.035), 0.32);
        out.color = float4(focus_rgb, max(inst.color.a, 0.94));
    } else if (flag == 4) {
        float lum = dot(inst.color.rgb, float3(0.299, 0.587, 0.114));
        float3 dim_rgb = mix(inst.color.rgb, float3(lum), 0.70);
        out.color = float4(dim_rgb, inst.color.a * EDGE_DIM_ALPHA_SCALE_LIGHT);
    } else {
        out.color = inst.color;
    }
    out.dist_from_center = dist_vals[vertex_id];
    out.pixel_edge_style = u.edge_style;
    return out;
}

fragment float4 line_edge_fragment(LineVertexOut in [[stage_in]]) {
    if (in.pixel_edge_style > 0.5) {
        if (abs(in.dist_from_center) > 0.94) discard_fragment();
        return in.color;
    }

    float alpha = 1.0 - smoothstep(0.6, 1.0, abs(in.dist_from_center));
    if (alpha < 0.01) discard_fragment();
    return float4(in.color.rgb, in.color.a * alpha);
}

"#;

// ── Metal Compute Shader (GPU N-body repulsion) ──────────────────────────────

const COMPUTE_SHADER_SOURCE: &str = r#"
#include <metal_stdlib>
using namespace metal;

kernel void nbody_repulsion(
    device const float2* positions [[buffer(0)]],
    device float2* forces [[buffer(1)]],
    constant uint& node_count [[buffer(2)]],
    constant float& charge_strength [[buffer(3)]],
    constant float& alpha [[buffer(4)]],
    constant float& distance_max_sq [[buffer(5)]],
    constant float& distance_min_sq [[buffer(6)]],
    uint tid [[thread_position_in_grid]])
{
    if (tid >= node_count) return;

    float2 pos = positions[tid];
    float2 force = float2(0.0);

    for (uint j = 0; j < node_count; j++) {
        if (j == tid) continue;
        float2 d = positions[j] - pos;
        float dist_sq = dot(d, d);
        if (dist_sq > distance_max_sq) continue;
        if (dist_sq < distance_min_sq) dist_sq = distance_min_sq;
        float dist = sqrt(dist_sq);
        float w = charge_strength * alpha / dist_sq;
        force += (d / dist) * w;
    }

    forces[tid] = force;
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

// ── SDF Label Shader (MTSDF atlas, radial blur-reveal) ────────────────────────

const LABEL_SHADER_SOURCE: &str = r#"
#include <metal_stdlib>
using namespace metal;

// Per-glyph instance: one quad per character in a label string.
struct LabelInstance {
    float2 position;    // world-space center of the glyph quad
    float2 size;        // quad half-extents in world units
    float4 uv_rect;     // atlas UV rect (x, y, w, h) — from JSON glyph metrics
    float4 color;       // text color (linear RGB, alpha)
    float  node_dist;   // precomputed: distance from this node to camera focus
};

struct LabelUniforms {
    float2 viewport_size;
    float2 camera_offset;
    float  camera_zoom;
    float  focus_radius;   // world-space radius of full-crisp zone
    float  blur_radius;    // world-space radius of full-invisible zone
    float  px_range;       // SDF pixel range (matches atlas gen: 6.0)
    float  atlas_height;
    float  _pad;
};

struct LabelVertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float  blur;           // 0.0 = crisp, 1.0 = fully blurred/invisible
    float  screen_px_range; // px_range scaled to screen pixels for this glyph
};

vertex LabelVertexOut label_vertex(
    uint vertex_id [[vertex_id]],
    uint instance_id [[instance_id]],
    constant LabelInstance* instances [[buffer(0)]],
    constant LabelUniforms& u [[buffer(1)]]
) {
    float2 corners[6] = {
        float2(-1, -1), float2( 1, -1), float2(-1,  1),
        float2(-1,  1), float2( 1, -1), float2( 1,  1)
    };
    float2 uvs[6] = {
        float2(0, 1), float2(1, 1), float2(0, 0),
        float2(0, 0), float2(1, 1), float2(1, 0)
    };

    LabelInstance inst = instances[instance_id];
    float2 corner = corners[vertex_id];

    // Radial focus fade: keep visible labels sharp. The old implementation
    // shrank glyph quads and widened the SDF edge enough that graph labels read
    // blurry even when they were meant to be visible.
    float blur = smoothstep(u.focus_radius, u.blur_radius, inst.node_dist);

    // Early out is still handled in the fragment shader; keep glyph geometry at
    // stable size so fade distance does not distort font sharpness.
    float2 world_pos = inst.position + corner * inst.size;

    float2 screen = (world_pos - u.camera_offset) * u.camera_zoom;
    float2 ndc = screen / (u.viewport_size * 0.5) * float2(1, -1);

    // Map UV to atlas rect.
    float2 base_uv = uvs[vertex_id];
    float2 atlas_uv = inst.uv_rect.xy + base_uv * inst.uv_rect.zw;

    // Compute screen-space pixel range for proper SDF anti-aliasing.
    float screen_glyph_size = inst.size.y * 2.0 * u.camera_zoom;
    float atlas_glyph_px = inst.uv_rect.w * u.atlas_height;
    float screen_px_range = max(screen_glyph_size / atlas_glyph_px * u.px_range, 1.0);

    LabelVertexOut out;
    out.position = float4(ndc, 0.1, 1.0); // z=0.1: in front of nodes (z≈0.5)
    out.uv = atlas_uv;
    out.color = inst.color;
    out.blur = blur;
    out.screen_px_range = screen_px_range;
    return out;
}

// MTSDF median-of-three: the standard msdf-atlas-gen decoding.
float mtsdf_median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

fragment float4 label_fragment(
    LabelVertexOut in [[stage_in]],
    texture2d<float> atlas [[texture(0)]]
) {
    // Early exit when fully invisible (zero cost for off-focus labels).
    if (in.blur > 0.99) discard_fragment();

    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 sample = atlas.sample(s, in.uv);

    // MTSDF decode: use median of RGB channels as the distance.
    float sd = mtsdf_median(sample.r, sample.g, sample.b);

    // Adaptive smoothstep width based on screen-space pixel range.
    float edge = 0.5;
    float half_width = 0.5 / in.screen_px_range;

    // Focus fade should not make readable labels look out of focus. Widen only
    // a little near the end of the fade, then let alpha do the disappearing.
    float blur_widen = in.blur * 0.08;
    float edge_min = edge - half_width - blur_widen;
    float edge_max = edge + half_width + blur_widen;

    float alpha = smoothstep(edge_min, edge_max, sd);

    // Fade alpha further as blur increases (labels dissolve into nothing).
    alpha *= 1.0 - in.blur;

    if (alpha < 0.01) discard_fragment();

    return float4(in.color.rgb * alpha, in.color.a * alpha); // premultiplied alpha
}
"#;

// ── SDF Label GPU data structs ────────────────────────────────────────────────

/// Per-glyph instance for SDF label rendering (matches Metal LabelInstance).
/// Staged infrastructure: constructed from Swift once label atlas is loaded.
#[allow(dead_code)]
#[repr(C)]
#[derive(Clone, Copy)]
pub(crate) struct LabelInstance {
    pub position: [f32; 2], // world-space glyph center
    pub size: [f32; 2],     // half-extents (world units)
    pub uv_rect: [f32; 4],  // atlas UV rect [x, y, w, h]
    pub color: [f32; 4],    // linear RGBA
    pub node_dist: f32,     // distance from node to camera focus
    pub _pad: [f32; 3],     // align to 64 bytes
}

/// Uniform data for the label render pass.
#[repr(C)]
#[derive(Clone, Copy)]
pub(crate) struct LabelUniforms {
    pub viewport_size: [f32; 2],
    pub camera_offset: [f32; 2],
    pub camera_zoom: f32,
    pub focus_radius: f32,
    pub blur_radius: f32,
    pub px_range: f32,
    pub atlas_height: f32,
    pub _pad: f32,
}

// ── Highlight State ─────────────────────────────────────────────────────────

/// Neighbor highlight state for shift+click.
pub struct HighlightState {
    /// Set of node IDs that should be highlighted (root + neighbors).
    pub highlighted_ids: rustc_hash::FxHashSet<u32>,
    /// The selected root node ID (the one that gets the ripple animation).
    /// Distinct from neighbors which are in `highlighted_ids` but not the root.
    pub root_id: Option<u32>,
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
            root_id: None,
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
    straight_edge_pipeline: RenderPipelineState,
    field_line_pipeline: RenderPipelineState,
    node_instance_buf: Option<Buffer>,
    edge_instance_buf: Option<Buffer>,
    uniform_buf: Buffer,
    node_instance_capacity: usize,
    edge_instance_capacity: usize,
    edge_instance_stride: usize,
    // Camera state
    pub camera_offset: [f32; 2],
    pub camera_zoom: f32,
    pub target_offset: [f32; 2],
    pub target_zoom: f32,
    pub is_animating: bool,
    /// Set by the engine each frame so the renderer can skip viewport
    /// culling while physics is moving nodes (prevents edge flicker).
    pub sim_active: bool,
    last_frame_time: std::time::Instant,
    // Counts (buffer layout: [glow_count glows] [node_count nodes] [highlight_count rings])
    glow_count: usize,
    node_count: usize,
    face_feature_count: usize,
    edge_instance_count: usize,
    edge_geometry_kind: EdgeGeometryKind,
    edge_highlight_flag_buf: Option<Buffer>,
    edge_highlight_flag_capacity: usize,
    pub use_aggregated_edges: bool,
    aggregated_edge_count: usize,
    /// When true, edges are hidden unless `edge_filter_node` is set.
    pub edges_hidden: bool,
    /// When set, only edges connected to this node are drawn.
    pub edge_filter_node: Option<u32>,
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
    edge_highlight_flag_scratch: Vec<u8>,
    edge_highlight_pairs: Vec<[u32; 2]>,
    // Reusable culled render lists for Classic mode.
    rendered_node_indices: Vec<usize>,
    candidate_entities: Vec<u32>,
    edge_candidate_indices: Vec<usize>,
    edge_candidate_marks: Vec<u32>,
    edge_candidate_generation: u32,
    edge_budget_scratch: Vec<u16>,
    density_clusters: FxHashMap<(i32, i32), DensityCluster>,
    classic_node_scratch: Vec<NodeInstance>,
    classic_edge_scratch: Vec<CurveEdgeInstance>,
    straight_edge_scratch: Vec<LineEdgeInstance>,
    classic_velocity_scratch: Vec<[f32; 2]>,
    // Background clear color (transparent for hologram overlay)
    pub clear_color: [f64; 4],
    pub light_mode: bool,
    // Quality level: 0 = Cinematic (full effects), 1 = Balanced (static depth, no glow),
    // 2 = Performance (straight edges, lighter static shading, no glow).
    pub quality_level: u8,
    pub(crate) edge_style: EdgeStyle,
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
    // ── SDF label pipeline ────────────────────────────────────────────
    label_pipeline: Option<RenderPipelineState>,
    label_instance_buf: Option<Buffer>,
    label_instance_capacity: usize,
    label_instance_count: usize,
    label_uniform_buf: Option<Buffer>,
    label_atlas_texture: Option<Texture>,
    pub label_atlas_height: f32,
    /// Camera focus point for radial blur-reveal (world coords).
    pub label_focus: [f32; 2],
    /// Inner radius: labels within this distance are fully crisp.
    pub label_focus_radius: f32,
    /// Outer radius: labels beyond this distance are invisible.
    pub label_blur_radius: f32,
    /// Whether labels are enabled (disabled in performance mode).
    pub labels_enabled: bool,
    /// Water-effect style blend (0.0 = off, 1.0 = full).
    pub vignette_strength: f32,
    pub water_style: f32,
    /// Water-effect wobble intensity (0.0 = off, 1.0 = full).
    pub water_wobble: f32,
    // ── GPU N-body compute pipeline (double-buffered) ──────────────────
    pub compute_pipeline: Option<ComputePipelineState>,
    compute_position_buf: Option<Buffer>,
    /// Front force buffer: the one being read back (previous frame's results).
    compute_force_buf_front: Option<Buffer>,
    /// Back force buffer: the one being written to (current frame's dispatch).
    compute_force_buf_back: Option<Buffer>,
    compute_position_capacity: usize,
    compute_force_capacity: usize,
    /// Number of nodes in the most recent completed GPU dispatch.
    compute_last_n: usize,
    /// Whether a GPU compute dispatch is currently in-flight on the back buffer.
    compute_in_flight: bool,
    #[cfg(any(test, debug_assertions))]
    debug_counters: RenderDebugCounters,
}

impl Renderer {
    #[cfg(test)]
    pub(crate) fn classic_buffer_rebuild_count(&self) -> usize {
        self.debug_counters.classic_buffer_rebuilds
    }

    #[inline]
    fn push_face_node(&mut self, position: [f32; 2], radius: f32, color: [f32; 4]) {
        self.classic_node_scratch.push(NodeInstance {
            position,
            radius,
            z: 0.99,
            color,
            face_type: FACE_FEATURE_TYPE, // face feature circle, not a node
            _pad: [0.0; 3],
        });
        self.classic_velocity_scratch.push([0.0, 0.0]);
    }

    #[inline]
    fn node_color(&self, node_type: &crate::types::NodeType) -> [f32; 4] {
        if self.light_mode {
            node_type.color_light()
        } else {
            node_type.color()
        }
    }

    #[inline]
    fn node_color_for_u8(&self, node_type: u8) -> [f32; 4] {
        self.node_color(&crate::types::NodeType::from_u8(node_type))
    }

    #[inline]
    fn monochrome_graph_node_color(&self, node_type: u8, depth: u32) -> [f32; 4] {
        monochrome_graph_node_color(self.light_mode, node_type, depth)
    }

    #[inline]
    fn edge_color(&self, edge_type: u8) -> [f32; 4] {
        if self.light_mode {
            edge_type_color_light(edge_type)
        } else {
            edge_type_color(edge_type)
        }
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

        // sRGB framebuffer: hardware-automatic gamma conversion on write.
        // Shaders work in linear space, blending is correct (no dark fringe on glow).
        layer.set_pixel_format(MTLPixelFormat::BGRA8Unorm_sRGB);
        layer.set_device(&device);

        let command_queue = device.new_command_queue();

        let library = device
            .new_library_with_source(SHADER_SOURCE, &CompileOptions::new())
            .ok()?;

        let node_vert = library.get_function("node_vertex", None).ok()?;
        let node_frag = library.get_function("node_fragment", None).ok()?;
        let edge_vert = library.get_function("curve_edge_vertex", None).ok()?;
        let edge_frag = library.get_function("line_edge_fragment", None).ok()?;
        let straight_edge_vert = library.get_function("line_edge_vertex", None).ok()?;
        let field_line_vert = library.get_function("line_edge_vertex", None).ok()?;
        let field_line_frag = library.get_function("line_edge_fragment", None).ok()?;

        // Helper to create a pipeline with alpha blending.
        // Returns None if pipeline creation fails (e.g. incompatible GPU).
        let make_pipeline = |vert: &Function, frag: &Function| -> Option<RenderPipelineState> {
            let desc = RenderPipelineDescriptor::new();
            desc.set_vertex_function(Some(vert));
            desc.set_fragment_function(Some(frag));
            let color_attach = desc.color_attachments().object_at(0)?;
            color_attach.set_pixel_format(MTLPixelFormat::BGRA8Unorm_sRGB);
            color_attach.set_blending_enabled(true);
            color_attach.set_source_rgb_blend_factor(MTLBlendFactor::SourceAlpha);
            color_attach.set_destination_rgb_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
            color_attach.set_source_alpha_blend_factor(MTLBlendFactor::One);
            color_attach.set_destination_alpha_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
            device.new_render_pipeline_state(&desc).ok()
        };

        let node_pipeline = make_pipeline(&node_vert, &node_frag)?;
        let edge_pipeline = make_pipeline(&edge_vert, &edge_frag)?;
        let straight_edge_pipeline = make_pipeline(&straight_edge_vert, &edge_frag)?;
        let field_line_pipeline = make_pipeline(&field_line_vert, &field_line_frag)?;

        let uniform_buf = device.new_buffer(
            std::mem::size_of::<Uniforms>() as u64,
            MTLResourceOptions::StorageModeShared,
        );

        let compute_pipeline = Self::create_compute_pipeline(&device);

        Some(Self {
            device,
            command_queue,
            layer,
            node_pipeline,
            edge_pipeline,
            straight_edge_pipeline,
            field_line_pipeline,
            node_instance_buf: None,
            edge_instance_buf: None,
            uniform_buf,
            node_instance_capacity: 0,
            edge_instance_capacity: 0,
            edge_instance_stride: 0,
            camera_offset: [0.0, 0.0],
            camera_zoom: 1.0,
            target_offset: [0.0, 0.0],
            target_zoom: 1.0,
            is_animating: false,
            sim_active: false,
            last_frame_time: std::time::Instant::now(),
            glow_count: 0,
            node_count: 0,
            face_feature_count: 0,
            edge_instance_count: 0,
            edge_geometry_kind: EdgeGeometryKind::Curve,
            edge_highlight_flag_buf: None,
            edge_highlight_flag_capacity: 0,
            use_aggregated_edges: false,
            aggregated_edge_count: 0,
            edges_hidden: false,
            edge_filter_node: None,
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
            straight_edge_scratch: Vec::new(),
            classic_velocity_scratch: Vec::new(),
            edge_highlight_flag_scratch: Vec::new(),
            edge_highlight_pairs: Vec::new(),
            light_mode: false,
            clear_color: [0.07, 0.07, 0.09, 1.0],
            quality_level: 0, // Cinematic by default
            edge_style: EdgeStyle::Smooth,
            start_time: std::time::Instant::now(),
            prev_camera_zoom: 1.0,
            prev_camera_offset: [0.0, 0.0],
            link_distance: 243.0,
            enable_elastic_edges: true,
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
            // SDF labels: pipeline created lazily when atlas is loaded.
            label_pipeline: None,
            label_instance_buf: None,
            label_instance_capacity: 0,
            label_instance_count: 0,
            label_uniform_buf: None,
            label_atlas_texture: None,
            label_atlas_height: 1024.0,
            label_focus: [0.0, 0.0],
            label_focus_radius: 200.0, // labels crisp within 200 world units of focus
            label_blur_radius: 600.0,  // labels invisible beyond 600 world units
            labels_enabled: true,
            vignette_strength: 0.18,
            water_style: 0.0,
            water_wobble: 0.0,
            compute_pipeline,
            compute_position_buf: None,
            compute_force_buf_front: None,
            compute_force_buf_back: None,
            compute_position_capacity: 0,
            compute_force_capacity: 0,
            compute_last_n: 0,
            compute_in_flight: false,
            #[cfg(any(test, debug_assertions))]
            debug_counters: RenderDebugCounters::default(),
        })
    }

    fn create_compute_pipeline(device: &Device) -> Option<ComputePipelineState> {
        let library = device
            .new_library_with_source(COMPUTE_SHADER_SOURCE, &CompileOptions::new())
            .map_err(|e| eprintln!("compute shader compile: {e}"))
            .ok()?;
        let func = library
            .get_function("nbody_repulsion", None)
            .map_err(|e| eprintln!("compute function lookup: {e}"))
            .ok()?;
        device
            .new_compute_pipeline_state_with_function(&func)
            .map_err(|e| eprintln!("compute pipeline: {e}"))
            .ok()
    }

    /// Load an MTSDF atlas texture from raw RGBA pixel data.
    /// Call this once at startup from Swift after loading the atlas PNG.
    /// `width`/`height` in pixels, `data` is RGBA8 (4 bytes per pixel).
    pub fn load_label_atlas(&mut self, width: u32, height: u32, data: &[u8]) -> bool {
        let desc = TextureDescriptor::new();
        desc.set_pixel_format(MTLPixelFormat::RGBA8Unorm);
        desc.set_width(width as u64);
        desc.set_height(height as u64);
        desc.set_storage_mode(MTLStorageMode::Shared);
        desc.set_usage(MTLTextureUsage::ShaderRead);

        let texture = self.device.new_texture(&desc);
        let region = MTLRegion::new_2d(0, 0, width as u64, height as u64);
        texture.replace_region(region, 0, data.as_ptr() as *const _, (width * 4) as u64);

        // Create label pipeline lazily on first atlas load.
        if self.label_pipeline.is_none() {
            if let Some(pipeline) = Self::create_label_pipeline(&self.device) {
                self.label_pipeline = Some(pipeline);
            } else {
                eprintln!("label pipeline creation failed");
                return false;
            }
        }

        // Allocate uniform buffer.
        if self.label_uniform_buf.is_none() {
            self.label_uniform_buf = Some(self.device.new_buffer(
                std::mem::size_of::<LabelUniforms>() as u64,
                MTLResourceOptions::StorageModeShared,
            ));
        }

        self.label_atlas_height = height as f32;
        self.label_atlas_texture = Some(texture);
        true
    }

    fn create_label_pipeline(device: &Device) -> Option<RenderPipelineState> {
        let library = device
            .new_library_with_source(LABEL_SHADER_SOURCE, &CompileOptions::new())
            .map_err(|e| eprintln!("label shader compile: {e}"))
            .ok()?;
        let vert = library
            .get_function("label_vertex", None)
            .map_err(|e| eprintln!("label vertex lookup: {e}"))
            .ok()?;
        let frag = library
            .get_function("label_fragment", None)
            .map_err(|e| eprintln!("label fragment lookup: {e}"))
            .ok()?;

        let desc = RenderPipelineDescriptor::new();
        desc.set_vertex_function(Some(&vert));
        desc.set_fragment_function(Some(&frag));
        let color_attach = desc.color_attachments().object_at(0)?;
        color_attach.set_pixel_format(MTLPixelFormat::BGRA8Unorm_sRGB);
        // Premultiplied alpha blending (labels over graph).
        color_attach.set_blending_enabled(true);
        color_attach.set_source_rgb_blend_factor(MTLBlendFactor::One); // premultiplied
        color_attach.set_destination_rgb_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
        color_attach.set_source_alpha_blend_factor(MTLBlendFactor::One);
        color_attach.set_destination_alpha_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
        device
            .new_render_pipeline_state(&desc)
            .map_err(|e| eprintln!("label pipeline: {e}"))
            .ok()
    }

    /// Upload label instances for this frame. Called from the engine before draw().
    /// `instances` is a slice of LabelInstance built from the visible node labels.
    /// Staged: wired up by Swift once label atlas is loaded via graph_engine_load_label_atlas.
    #[allow(dead_code)]
    pub(crate) fn set_label_instances(&mut self, instances: &[LabelInstance]) {
        self.label_instance_count = instances.len();
        if instances.is_empty() {
            return;
        }

        let byte_len = std::mem::size_of_val(instances) as u64;
        if self.label_instance_buf.is_none() || self.label_instance_capacity < instances.len() {
            let cap = (instances.len() * 3 / 2).max(256);
            self.label_instance_buf = Some(self.device.new_buffer(
                (cap * std::mem::size_of::<LabelInstance>()) as u64,
                MTLResourceOptions::StorageModeShared,
            ));
            self.label_instance_capacity = cap;
        }

        if let Some(buf) = &self.label_instance_buf {
            // SAFETY: buffer is StorageModeShared and we just ensured capacity.
            unsafe {
                std::ptr::copy_nonoverlapping(
                    instances.as_ptr() as *const u8,
                    buf.contents() as *mut u8,
                    byte_len as usize,
                );
            }
        }
    }

    fn labels_pass_primary_draw_gate(&self) -> bool {
        self.labels_enabled
    }

    /// Encode label draw commands into the current render encoder.
    /// Called from draw() after nodes and before dialogue overlay.
    fn draw_label_commands(&self, encoder: &RenderCommandEncoderRef) {
        // Guard: labels disabled, no atlas, no pipeline, or nothing to draw.
        if !self.labels_pass_primary_draw_gate() {
            return;
        }
        let pipeline = match &self.label_pipeline {
            Some(p) => p,
            None => return,
        };
        let atlas = match &self.label_atlas_texture {
            Some(t) => t,
            None => return,
        };
        if self.label_instance_count == 0 {
            return;
        }
        let inst_buf = match &self.label_instance_buf {
            Some(b) => b,
            None => return,
        };
        let uniform_buf = match &self.label_uniform_buf {
            Some(b) => b,
            None => return,
        };

        // Update label uniforms.
        let uniforms = LabelUniforms {
            viewport_size: [self.last_viewport_width, self.last_viewport_height],
            camera_offset: self.camera_offset,
            camera_zoom: self.camera_zoom,
            focus_radius: self.label_focus_radius,
            blur_radius: self.label_blur_radius,
            px_range: 6.0, // must match atlas gen -pxrange flag
            atlas_height: self.label_atlas_height,
            _pad: 0.0,
        };
        // SAFETY: buffer is StorageModeShared and matches LabelUniforms layout.
        unsafe {
            let ptr = uniform_buf.contents() as *mut LabelUniforms;
            *ptr = uniforms;
        }

        encoder.set_render_pipeline_state(pipeline);
        encoder.set_vertex_buffer(0, Some(inst_buf), 0);
        encoder.set_vertex_buffer(1, Some(uniform_buf), 0);
        encoder.set_fragment_texture(0, Some(atlas));

        let draw_count = self.label_instance_count.min(self.label_instance_capacity);
        encoder.draw_primitives_instanced(
            MTLPrimitiveType::Triangle,
            0,
            6, // 2 triangles = 1 quad per glyph
            draw_count as u64,
        );
    }

    /// Dispatch brute-force O(N^2) N-body repulsion on GPU (double-buffered).
    ///
    /// Uses two force buffers: while the GPU writes to the "back" buffer for
    /// this frame, we read completed results from the "front" buffer (previous
    /// frame). Returns the previous frame's forces (one-frame latency — standard
    /// for physics engines) and fires the new dispatch asynchronously.
    ///
    /// On the very first call, dispatches synchronously so there's no empty frame.
    /// Returns None if compute pipeline is unavailable or the previous dispatch
    /// hasn't completed yet (physics falls back to CPU Barnes-Hut).
    pub fn dispatch_gpu_nbody(
        &mut self,
        positions: &[[f32; 2]],
        charge_strength: f32,
        alpha: f32,
        distance_max: f32,
        distance_min: f32,
    ) -> Option<Vec<[f32; 2]>> {
        let pipeline = self.compute_pipeline.as_ref()?;
        let n = positions.len();
        if n == 0 {
            return Some(Vec::new());
        }

        let pos_bytes = std::mem::size_of_val(positions);

        // Grow position buffer if needed.
        if n > self.compute_position_capacity || self.compute_position_buf.is_none() {
            let cap = (n * 3 / 2).max(64);
            self.compute_position_buf = Some(self.device.new_buffer(
                (cap * std::mem::size_of::<[f32; 2]>()) as u64,
                MTLResourceOptions::StorageModeShared,
            ));
            self.compute_position_capacity = cap;
        }

        // Grow front force buffer if needed.
        if n > self.compute_force_capacity || self.compute_force_buf_front.is_none() {
            let cap = (n * 3 / 2).max(64);
            self.compute_force_buf_front = Some(self.device.new_buffer(
                (cap * std::mem::size_of::<[f32; 2]>()) as u64,
                MTLResourceOptions::StorageModeShared,
            ));
            // Also grow back buffer to match.
            self.compute_force_buf_back = Some(self.device.new_buffer(
                (cap * std::mem::size_of::<[f32; 2]>()) as u64,
                MTLResourceOptions::StorageModeShared,
            ));
            self.compute_force_capacity = cap;
            // Buffers reallocated — previous in-flight dispatch targets stale memory.
            self.compute_in_flight = false;
        }

        // ── Read back previous frame's completed forces from front buffer ──
        let previous_forces = if self.compute_in_flight {
            // Previous dispatch was async — it should be done by now (GPU kernel
            // completes in <1ms on Apple Silicon; we're called at ~8-16ms intervals).
            // The completed handler already ran. Read from the front buffer.
            let prev_n = self.compute_last_n;
            let front = self.compute_force_buf_front.as_ref()?;
            let mut forces = Vec::with_capacity(prev_n);
            // SAFETY: front buffer is StorageModeShared, previous dispatch targeted
            // the back buffer (now swapped to front), GPU work is complete, buffer
            // has prev_n entries from the last dispatch.
            unsafe {
                let ptr = front.contents() as *const [f32; 2];
                forces.extend_from_slice(std::slice::from_raw_parts(ptr, prev_n));
            }
            Some(forces)
        } else {
            // First frame or after buffer reallocation — no previous results yet.
            None
        };

        // ── Swap front/back: this frame's dispatch writes to the old front ──
        std::mem::swap(
            &mut self.compute_force_buf_front,
            &mut self.compute_force_buf_back,
        );

        let pos_buf = self.compute_position_buf.as_ref()?;
        let back_buf = self.compute_force_buf_back.as_ref()?;

        // Copy positions into GPU buffer.
        // SAFETY: pos_buf is StorageModeShared with sufficient capacity, positions is valid.
        unsafe {
            std::ptr::copy_nonoverlapping(
                positions.as_ptr() as *const u8,
                pos_buf.contents() as *mut u8,
                pos_bytes,
            );
        }

        let cmd_buf = self.command_queue.new_command_buffer();
        attach_command_buffer_logging(cmd_buf, "gpu_nbody_forces");
        let encoder = cmd_buf.new_compute_command_encoder();
        encoder.set_compute_pipeline_state(pipeline);
        encoder.set_buffer(0, Some(pos_buf), 0);
        encoder.set_buffer(1, Some(back_buf), 0);

        let node_count = n as u32;
        let distance_max_sq = distance_max * distance_max;
        let distance_min_sq = distance_min * distance_min;

        encoder.set_bytes(
            2,
            std::mem::size_of::<u32>() as u64,
            &node_count as *const u32 as *const c_void,
        );
        encoder.set_bytes(
            3,
            std::mem::size_of::<f32>() as u64,
            &charge_strength as *const f32 as *const c_void,
        );
        encoder.set_bytes(
            4,
            std::mem::size_of::<f32>() as u64,
            &alpha as *const f32 as *const c_void,
        );
        encoder.set_bytes(
            5,
            std::mem::size_of::<f32>() as u64,
            &distance_max_sq as *const f32 as *const c_void,
        );
        encoder.set_bytes(
            6,
            std::mem::size_of::<f32>() as u64,
            &distance_min_sq as *const f32 as *const c_void,
        );

        let threads_per_group = 256;
        let thread_groups = n.div_ceil(threads_per_group);
        encoder.dispatch_thread_groups(
            MTLSize::new(thread_groups as u64, 1, 1),
            MTLSize::new(threads_per_group as u64, 1, 1),
        );
        encoder.end_encoding();
        cmd_buf.commit();

        if previous_forces.is_some() {
            // Steady state: dispatch is fire-and-forget. GPU kernel runs async while
            // the render thread continues with the previous frame's force results.
            // The back buffer will be read on the NEXT call after swap.
            self.compute_in_flight = true;
            self.compute_last_n = n;
            previous_forces
        } else {
            // First frame: wait synchronously so physics gets forces immediately
            // instead of falling back to CPU Barnes-Hut for the first tick.
            cmd_buf.wait_until_completed();
            self.compute_in_flight = true;
            self.compute_last_n = n;

            let mut forces = Vec::with_capacity(n);
            // SAFETY: back_buf is StorageModeShared, GPU work is complete, buffer has n entries.
            unsafe {
                let ptr = back_buf.contents() as *const [f32; 2];
                forces.extend_from_slice(std::slice::from_raw_parts(ptr, n));
            }
            Some(forces)
        }
    }

    // Generous padding so nodes at the viewport edge don't pop in/out as
    // physics nudges them across the cull boundary. 400px covers the
    // largest node radius (55) at any realistic zoom level.
    const CLASSIC_CULL_PADDING_PIXELS: f32 = 400.0;

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
        if self.is_camera_motion_active() {
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
    fn is_camera_motion_active(&self) -> bool {
        // Disable culling when physics is running — nodes shift under
        // simulation and cross the cull boundary, causing pop-in flicker.
        if self.sim_active {
            return true;
        }
        let zoom_delta = (self.camera_zoom - self.prev_camera_zoom).abs();
        let dx = self.camera_offset[0] - self.prev_camera_offset[0];
        let dy = self.camera_offset[1] - self.prev_camera_offset[1];
        let offset_delta_sq = dx * dx + dy * dy;
        self.is_animating || zoom_delta > 0.0005 || offset_delta_sq > 1.0
    }

    #[inline]
    fn node_in_view(&self, bounds: Option<ViewBounds>, center: [f32; 2], radius: f32) -> bool {
        bounds.is_none_or(|view| bounds_intersects_circle(view, center, radius))
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
            sort_and_dedup_indices(&mut self.rendered_node_indices);
            return;
        }

        self.rendered_node_indices
            .extend((0..world.len()).filter(|&index| world.graph_node[index].visible != 0));
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

    /// Collect only edges connected to a single node — O(degree) instead of O(E).
    fn collect_edges_for_node(&mut self, world: &World, node_id: u32) {
        self.edge_candidate_indices.clear();
        if let Some(node_index) = world.index_of_node_id(node_id) {
            for &edge_index in world.edge_indices_for_index(node_index) {
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

    fn edge_curvature(&self) -> f32 {
        let dialogue_bias = if self.visual_theme == VisualTheme::Dialogue {
            0.20
        } else {
            0.12
        };
        let elastic_bias = if self.enable_elastic_edges {
            0.06 + self.edge_elasticity.clamp(0.0, 1.0) * 0.20
        } else {
            0.0
        };
        dialogue_bias + elastic_bias
    }

    #[inline]
    fn classic_node_radius(&self, world: &World, node_index: usize) -> f32 {
        dialogue_node_radius(
            self.visual_theme,
            world.graph_node[node_index].radius,
            world.hierarchy[node_index].node_type,
            world.hierarchy[node_index].link_count,
            world.render[node_index].color_override[3],
        )
    }

    #[inline]
    fn classic_node_instance(&self, world: &World, node_index: usize) -> NodeInstance {
        let co = world.render[node_index].color_override;
        let hierarchy = &world.hierarchy[node_index];
        let mut color = if co[3] > 0.0 {
            // Depth palette encodes style signal in alpha > 1.0 — clamp for rendering.
            [co[0], co[1], co[2], co[3].min(1.0)]
        } else {
            self.monochrome_graph_node_color(hierarchy.node_type, hierarchy.depth)
        };
        let z = z_for_link_count(hierarchy.link_count);
        color[3] = color[3].min(1.0) * BASE_NODE_ALPHA;
        let face_type = (world.hierarchy[node_index].node_type as f32) + 1.0;
        NodeInstance {
            position: [world.transform[node_index].x, world.transform[node_index].y],
            radius: self.classic_node_radius(world, node_index),
            z,
            color,
            face_type,
            _pad: [0.0; 3],
        }
    }

    #[inline]
    fn classic_edge_instance_color(
        &self,
        world: &World,
        edge: &crate::ecs::EdgeComponent,
        src_index: usize,
        tgt_index: usize,
    ) -> [f32; 4] {
        let mut color = self.edge_color(edge.edge_type);
        color[3] *= BASE_NODE_ALPHA;
        edge_color_with_endpoint_palette(
            color,
            world.render[src_index].color_override,
            world.render[tgt_index].color_override,
        )
    }

    #[inline]
    fn preferred_edge_geometry_kind(&self) -> EdgeGeometryKind {
        if self.edge_style == EdgeStyle::PixelArt {
            return EdgeGeometryKind::Straight;
        }
        if self.quality_level >= 2 {
            EdgeGeometryKind::Straight
        } else {
            EdgeGeometryKind::Curve
        }
    }

    #[inline]
    fn edge_instance_stride_for(kind: EdgeGeometryKind) -> usize {
        match kind {
            EdgeGeometryKind::Curve => std::mem::size_of::<CurveEdgeInstance>(),
            EdgeGeometryKind::Straight => std::mem::size_of::<LineEdgeInstance>(),
        }
    }

    #[inline]
    fn edge_vertices_per_instance(&self) -> u64 {
        match self.edge_geometry_kind {
            EdgeGeometryKind::Curve => (CURVE_EDGE_STRIP_SEGMENTS * 6) as u64,
            EdgeGeometryKind::Straight => 6,
        }
    }

    #[inline]
    fn uniforms_for_draw(
        &self,
        viewport_width: f32,
        viewport_height: f32,
        elapsed: f32,
        pulse_t: f32,
    ) -> Uniforms {
        Uniforms {
            viewport_size: [viewport_width, viewport_height],
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
            dialogue_theme: if self.visual_theme == VisualTheme::Dialogue {
                1.0
            } else {
                0.0
            },
            vignette_strength: self.vignette_strength,
            light_mode: if self.light_mode { 1.0 } else { 0.0 },
            water_style: self.water_style,
            water_wobble: self.water_wobble,
            edge_style: self.edge_style.as_uniform(),
        }
    }

    fn rebuild_classic_buffers(&mut self, world: &World) {
        #[cfg(any(test, debug_assertions))]
        {
            self.debug_counters.classic_buffer_rebuilds += 1;
            self.debug_counters.last_total_nodes = world.len();
            self.debug_counters.last_total_edges = world.edges.len();
            self.debug_counters.last_candidate_edges = 0;
            self.debug_counters.last_visible_edges = 0;
        }
        let view_bounds = self.current_view_bounds(Self::CLASSIC_CULL_PADDING_PIXELS);
        let lod = lod_profile_for_zoom(self.camera_zoom, self.quality_level);
        let visual_theme = self.visual_theme;
        let suppress_motion = self.is_animating;
        let suppress_node_motion = suppress_motion || self.quality_level >= 1;
        self.collect_visible_node_indices(world, view_bounds, |world, index| {
            dialogue_node_radius(
                visual_theme,
                world.graph_node[index].radius,
                world.hierarchy[index].node_type,
                world.hierarchy[index].link_count,
                world.render[index].color_override[3],
            )
        });
        #[cfg(any(test, debug_assertions))]
        {
            self.debug_counters.last_visible_nodes = self.rendered_node_indices.len();
        }

        // Stable draw order: sort by z-tier (background first → foreground last)
        // so the painter's algorithm renders foreground nodes on top.
        // Tie-break by index for frame-to-frame consistency.
        self.rendered_node_indices.sort_unstable_by(|&a, &b| {
            let za = z_for_link_count(world.hierarchy[a].link_count);
            let zb = z_for_link_count(world.hierarchy[b].link_count);
            za.partial_cmp(&zb)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then(a.cmp(&b))
        });

        self.classic_node_scratch.clear();
        self.classic_velocity_scratch.clear();
        self.classic_edge_scratch.clear();
        self.straight_edge_scratch.clear();
        self.edge_highlight_pairs.clear();

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
                    self.monochrome_graph_node_color(
                        world.hierarchy[node_index].node_type,
                        world.hierarchy[node_index].depth,
                    )
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
                cluster.max_link_count = cluster
                    .max_link_count
                    .max(world.hierarchy[node_index].link_count);
                cluster.count += 1;
                debug_assert!(graph_node.visible != 0);
            }

            self.glow_count = 0;
            self.wind_particle_count = 0;

            for cluster in self.density_clusters.values() {
                let inv_count = 1.0 / cluster.count as f32;
                let proxy_radius =
                    density_proxy_screen_radius(cluster.count) / self.camera_zoom.max(0.05);
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
                    face_type: 0.0,
                    _pad: [0.0; 3],
                });
                self.classic_velocity_scratch.push(render_velocity(
                    cluster.sum_vx * inv_count,
                    cluster.sum_vy * inv_count,
                    suppress_node_motion,
                ));
            }

            self.node_count = self.classic_node_scratch.len();
        } else {
            // Light mode: skip the bloom/glow halos entirely — they read as
            // washed-out blobs against the white background.
            let draw_glow =
                lod.draw_glow && self.visual_theme != VisualTheme::Dialogue && !self.light_mode;
            // Glow only for highlighted nodes (selected + neighbors). At
            // rest no glows render — clean, calm graph. When a node is
            // selected, its neighborhood lights up with the glow aura.
            // User 2026-04-06: "only selected node and its connected nodes glow"
            let draw_selection_glow = draw_glow && self.highlight.active;
            if draw_selection_glow {
                let mut glow_emitted = 0usize;
                for &node_index in &self.rendered_node_indices {
                    if glow_emitted >= MAX_GLOW_INSTANCES {
                        break;
                    }
                    // Only glow for highlighted (selected + neighbor) nodes
                    let node_id = world.graph_node[node_index].node_id;
                    if !self.highlight.highlighted_ids.contains(&node_id) {
                        continue;
                    }
                    let pos = [world.transform[node_index].x, world.transform[node_index].y];
                    let node_instance = self.classic_node_instance(world, node_index);
                    let z = node_instance.z;
                    let color = node_instance.color;
                    let radius = node_instance.radius;
                    let confidence = world.graph_node[node_index].confidence;
                    let link_count = world.hierarchy[node_index].link_count;
                    let _node_type = world.hierarchy[node_index].node_type;
                    let is_root = self.highlight.root_id == Some(node_id);
                    // Glow for hubs in the neighborhood OR the selected root node
                    if link_count >= 9 || is_root {
                        self.classic_node_scratch.push(NodeInstance {
                            position: pos,
                            radius: radius * HUB_GLOW_RADIUS_FACTOR,
                            z: z + HUB_GLOW_Z_OFFSET,
                            color: [color[0], color[1], color[2], HUB_GLOW_ALPHA],
                            face_type: 0.0,
                            _pad: [0.0; 3],
                        });
                        self.classic_velocity_scratch.push([0.0, 0.0]);
                        glow_emitted += 1;
                    }

                    if confidence > 0.0 && glow_emitted < MAX_GLOW_INSTANCES {
                        let conf = confidence.clamp(0.0, 1.0);
                        let glow_radius =
                            radius * (CONF_GLOW_RADIUS_BASE + conf * CONF_GLOW_RADIUS_SCALE);
                        let glow_alpha = CONF_GLOW_ALPHA_BASE + conf * CONF_GLOW_ALPHA_SCALE;
                        self.classic_node_scratch.push(NodeInstance {
                            position: pos,
                            radius: glow_radius,
                            z: z + CONF_GLOW_Z_OFFSET,
                            color: [color[0], color[1], color[2], glow_alpha],
                            face_type: 0.0,
                            _pad: [0.0; 3],
                        });
                        self.classic_velocity_scratch.push([0.0, 0.0]);
                        glow_emitted += 1;
                    }
                }
            }

            if draw_glow && self.last_viewport_width > 0.0 && self.last_viewport_height > 0.0 {
                self.update_wind_particles(
                    [self.last_viewport_width, self.last_viewport_height],
                    self.camera_zoom,
                );
            } else {
                self.wind_particle_count = 0;
            }

            if draw_glow && self.wind_active {
                for particle in &self.wind_particles {
                    self.classic_node_scratch.push(NodeInstance {
                        position: [particle[0], particle[1]],
                        radius: 1.5,
                        z: -0.50,
                        color: [0.7, 0.85, 1.0, 0.08],
                        face_type: 0.0,
                        _pad: [0.0; 3],
                    });
                    self.classic_velocity_scratch.push([0.0, 0.0]);
                }
                self.wind_particle_count = self.wind_particles.len();
            } else {
                self.wind_particle_count = 0;
            }

            self.glow_count = self.classic_node_scratch.len();

            for &node_index in &self.rendered_node_indices {
                self.classic_node_scratch
                    .push(self.classic_node_instance(world, node_index));
                self.classic_velocity_scratch.push(render_velocity(
                    world.velocity[node_index].vx,
                    world.velocity[node_index].vy,
                    suppress_node_motion,
                ));
            }

            self.node_count = self.rendered_node_indices.len();
        }

        if lod.cluster_nodes {
            self.glow_count = 0;
        }

        // Face geometry for the active dialogue node.
        if self.visual_theme == VisualTheme::Dialogue
            && self.dialogue.active
            && let Some(node_idx) = self.dialogue.node_index
            && node_idx < world.transform.len()
        {
            let nx = world.transform[node_idx].x;
            let ny = world.transform[node_idx].y;
            let r = self.classic_node_radius(world, node_idx);
            let time = self.start_time.elapsed().as_secs_f32();
            let node_seed = world.graph_node[node_idx].node_id as f32 * 0.173;
            let bob_y = (time
                * (if self.dialogue.is_streaming {
                    2.8
                } else {
                    1.45
                })
                + node_seed)
                .sin()
                * r
                * 0.018;
            let eye_white_r = r * 0.15;
            let eye_lid_r = eye_white_r * 0.34;
            let pupil_r = eye_white_r * 0.30;
            let eye_spacing = r * 0.28;
            let eye_y = ny - r * 0.10 + bob_y;
            let brow_y = eye_y - r * 0.12;
            let mouth_y = ny + r * 0.24 + bob_y * 0.32;
            let blink_open = face_blink_openness(time, node_seed, self.dialogue.is_streaming);
            let pupil_offset = face_pupil_offset(
                [nx, ny],
                self.dialogue.look_target_world,
                eye_white_r * 0.22,
            );

            self.push_face_node(
                [nx - eye_spacing, brow_y],
                eye_white_r * 0.34,
                [0.14, 0.18, 0.26, 0.82],
            );
            self.push_face_node(
                [nx + eye_spacing, brow_y],
                eye_white_r * 0.34,
                [0.14, 0.18, 0.26, 0.82],
            );

            if blink_open > 0.4 {
                let eye_color = srgb_to_linear_rgba([0.96, 0.97, 0.98, 0.98]);
                let pupil_color = srgb_to_linear_rgba([0.10, 0.12, 0.18, 0.98]);
                let left_eye = [nx - eye_spacing, eye_y];
                let right_eye = [nx + eye_spacing, eye_y];
                let left_pupil = [left_eye[0] + pupil_offset[0], left_eye[1] + pupil_offset[1]];
                let right_pupil = [
                    right_eye[0] + pupil_offset[0],
                    right_eye[1] + pupil_offset[1],
                ];

                self.push_face_node(left_eye, eye_white_r * blink_open, eye_color);
                self.push_face_node(right_eye, eye_white_r * blink_open, eye_color);
                self.push_face_node(left_pupil, pupil_r * blink_open, pupil_color);
                self.push_face_node(right_pupil, pupil_r * blink_open, pupil_color);
            } else {
                let lid_color = srgb_to_linear_rgba([0.12, 0.15, 0.22, 0.88]);
                self.push_face_node([nx - eye_spacing, eye_y], eye_lid_r, lid_color);
                self.push_face_node([nx + eye_spacing, eye_y], eye_lid_r, lid_color);
            }

            if self.dialogue.is_streaming {
                let chatter = 0.04 + 0.12 * (time * 10.0 + node_seed).sin().abs();
                let mouth_w = eye_white_r * 0.64;
                let mouth_h = eye_white_r * (0.24 + chatter);
                self.push_face_node([nx - mouth_w, mouth_y], mouth_h, [0.15, 0.18, 0.25, 0.92]);
                self.push_face_node([nx, mouth_y], mouth_h * 1.18, [0.15, 0.18, 0.25, 0.96]);
                self.push_face_node([nx + mouth_w, mouth_y], mouth_h, [0.15, 0.18, 0.25, 0.92]);
                self.push_face_node(
                    [nx, mouth_y + mouth_h * 0.18],
                    mouth_h * 0.42,
                    [0.90, 0.56, 0.58, 0.28],
                );
            } else {
                let smile_color = srgb_to_linear_rgba([0.15, 0.18, 0.25, 0.90]);
                let smile_r = eye_white_r * 0.18;
                self.push_face_node([nx - eye_spacing * 0.34, mouth_y], smile_r, smile_color);
                self.push_face_node([nx, mouth_y + smile_r * 0.22], smile_r, smile_color);
                self.push_face_node([nx + eye_spacing * 0.34, mouth_y], smile_r, smile_color);
            }
        }

        self.face_feature_count = self
            .classic_node_scratch
            .len()
            .saturating_sub(self.glow_count + self.node_count);
        let total_node_instances = self.classic_node_scratch.len();

        if total_node_instances == 0 {
            self.node_instance_buf = None;
            self.edge_instance_buf = None;
            self.glow_count = 0;
            self.node_count = 0;
            self.face_feature_count = 0;
            self.highlight_count = 0;
            self.edge_instance_count = 0;
            return;
        }

        if total_node_instances + 2 > self.node_instance_capacity
            || self.node_instance_buf.is_none()
        {
            let capacity = ((total_node_instances + 2) * 3 / 2).max(64);
            let buf_size = (capacity * std::mem::size_of::<NodeInstance>()) as u64;
            self.node_instance_buf = Some(
                self.device
                    .new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
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
                self.device
                    .new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
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
                for index in self.classic_velocity_scratch.len()
                    ..velocity_count.min(self.node_velocity_capacity)
                {
                    *ptr.add(index) = [0.0, 0.0];
                }
            }
        }

        let should_draw_edges = lod.draw_edges
            && !lod.cluster_nodes
            && !(self.edges_hidden && self.edge_filter_node.is_none());
        let edge_geometry_kind = self.preferred_edge_geometry_kind();
        self.edge_geometry_kind = edge_geometry_kind;
        self.clear_aggregated_edges();
        if should_draw_edges {
            // When filtering to a single node, only collect that node's edges (O(degree) not O(E)).
            if let Some(filter_id) = self.edge_filter_node {
                self.collect_edges_for_node(world, filter_id);
            } else {
                self.collect_candidate_edges(world);
            }
            #[cfg(any(test, debug_assertions))]
            {
                self.debug_counters.last_candidate_edges = self.edge_candidate_indices.len();
            }
            self.reset_edge_lod_budget(world, lod);
            let curvature = self.edge_curvature();
            for candidate_index in 0..self.edge_candidate_indices.len() {
                let edge_index = self.edge_candidate_indices[candidate_index];
                let edge = &world.edges[edge_index];
                let (Some(src_index), Some(tgt_index)) =
                    (world.index_of(edge.source), world.index_of(edge.target))
                else {
                    continue;
                };
                if world.graph_node[src_index].visible == 0
                    || world.graph_node[tgt_index].visible == 0
                {
                    continue;
                }

                let p0 = [world.transform[src_index].x, world.transform[src_index].y];
                let p1 = [world.transform[tgt_index].x, world.transform[tgt_index].y];
                if (p0[0] == 0.0 && p0[1] == 0.0) || (p1[0] == 0.0 && p1[1] == 0.0) {
                    continue;
                }
                if !p0[0].is_finite()
                    || !p0[1].is_finite()
                    || !p1[0].is_finite()
                    || !p1[1].is_finite()
                {
                    continue;
                }
                if !self.edge_allowed_by_lod(world, lod, src_index, tgt_index) {
                    continue;
                }

                // Recoup node radii so edges terminate at the disc
                // boundary plus a small gap instead of stabbing into the
                // node centre (v3 motion-overlay spec, task 1).
                let r0 = world.graph_node[src_index].radius;
                let r1 = world.graph_node[tgt_index].radius;
                let thickness_px = edge_width_px_for_weight(edge.weight, r0, r1);

                let color = self.classic_edge_instance_color(world, edge, src_index, tgt_index);
                match edge_geometry_kind {
                    EdgeGeometryKind::Curve => {
                        let ideal_length = self.link_distance / edge.weight.max(0.01);
                        let (c0, c1) = string_edge_control_points(
                            p0,
                            p1,
                            [0.0, 0.0],
                            [0.0, 0.0],
                            ideal_length,
                            curvature,
                        );
                        if !edge_intersects_view(view_bounds, p0, p1, c0, c1) {
                            continue;
                        }
                        let Some((p0t, c0t, c1t, p1t)) = crate::edge_trim::trim_curve_endpoints(
                            p0,
                            c0,
                            c1,
                            p1,
                            r0,
                            r1,
                            crate::edge_trim::DEFAULT_EDGE_GAP_PX,
                        ) else {
                            continue;
                        };
                        self.classic_edge_scratch.push(CurveEdgeInstance {
                            p0: p0t,
                            c0: c0t,
                            c1: c1t,
                            p1: p1t,
                            color,
                            thickness_px,
                            _pad: [0.0; 3],
                        });
                    }
                    EdgeGeometryKind::Straight => {
                        if !view_bounds.is_none_or(|view| segment_intersects_bounds(view, p0, p1)) {
                            continue;
                        }
                        let Some((p0t, p1t)) = crate::edge_trim::trim_line_endpoints(
                            p0,
                            p1,
                            r0,
                            r1,
                            crate::edge_trim::DEFAULT_EDGE_GAP_PX,
                        ) else {
                            continue;
                        };
                        self.straight_edge_scratch.push(LineEdgeInstance {
                            p0: p0t,
                            p1: p1t,
                            color,
                            thickness_px,
                            _pad: [0.0; 3],
                        });
                    }
                }
                self.edge_highlight_pairs.push([
                    world.graph_node[src_index].node_id,
                    world.graph_node[tgt_index].node_id,
                ]);
            }
        }

        self.edge_instance_count = match edge_geometry_kind {
            EdgeGeometryKind::Curve => self.classic_edge_scratch.len(),
            EdgeGeometryKind::Straight => self.straight_edge_scratch.len(),
        };
        #[cfg(any(test, debug_assertions))]
        {
            self.debug_counters.last_visible_edges = self.edge_instance_count;
        }
        if self.edge_instance_count > 0 {
            let required_stride = Self::edge_instance_stride_for(edge_geometry_kind);
            if self.edge_instance_count > self.edge_instance_capacity
                || self.edge_instance_buf.is_none()
                || self.edge_instance_stride != required_stride
            {
                let capacity = (self.edge_instance_count * 3 / 2).max(64);
                let buf_size = (capacity * required_stride) as u64;
                self.edge_instance_buf = Some(
                    self.device
                        .new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
                );
                self.edge_instance_capacity = capacity;
                self.edge_instance_stride = required_stride;
            }

            if let Some(buf) = &self.edge_instance_buf {
                unsafe {
                    match edge_geometry_kind {
                        EdgeGeometryKind::Curve => {
                            std::ptr::copy_nonoverlapping(
                                self.classic_edge_scratch.as_ptr(),
                                buf.contents() as *mut CurveEdgeInstance,
                                self.edge_instance_count,
                            );
                        }
                        EdgeGeometryKind::Straight => {
                            std::ptr::copy_nonoverlapping(
                                self.straight_edge_scratch.as_ptr(),
                                buf.contents() as *mut LineEdgeInstance,
                                self.edge_instance_count,
                            );
                        }
                    }
                }
            }
        } else {
            self.edge_instance_buf = None;
        }
    }

    pub fn upload_aggregated_edges(&mut self, edges: &[crate::edge_aggregation::AggregatedEdge]) {
        self.use_aggregated_edges = !edges.is_empty();
        if edges.is_empty() {
            self.aggregated_edge_count = 0;
            return;
        }

        let base_rgb = aggregated_edge_base_rgb(self.light_mode);

        self.classic_edge_scratch.clear();
        self.straight_edge_scratch.clear();
        self.edge_geometry_kind = self.preferred_edge_geometry_kind();
        let curvature = (self.edge_curvature() * 0.8).max(0.10);
        for edge in edges {
            let color = [base_rgb[0], base_rgb[1], base_rgb[2], edge.alpha];
            let thickness_px = edge_width_px_for_weight(edge.alpha, 20.0, 20.0);
            match self.edge_geometry_kind {
                EdgeGeometryKind::Curve => {
                    let (c0, c1) = string_edge_control_points(
                        edge.p0,
                        edge.p1,
                        [0.0, 0.0],
                        [0.0, 0.0],
                        ((edge.p1[0] - edge.p0[0]).powi(2) + (edge.p1[1] - edge.p0[1]).powi(2))
                            .sqrt(),
                        curvature,
                    );
                    self.classic_edge_scratch.push(CurveEdgeInstance {
                        p0: edge.p0,
                        c0,
                        c1,
                        p1: edge.p1,
                        color,
                        thickness_px,
                        _pad: [0.0; 3],
                    });
                }
                EdgeGeometryKind::Straight => {
                    self.straight_edge_scratch.push(LineEdgeInstance {
                        p0: edge.p0,
                        p1: edge.p1,
                        color,
                        thickness_px,
                        _pad: [0.0; 3],
                    });
                }
            }
            self.edge_highlight_pairs.push([u32::MAX, u32::MAX]);
        }
        self.aggregated_edge_count = match self.edge_geometry_kind {
            EdgeGeometryKind::Curve => self.classic_edge_scratch.len(),
            EdgeGeometryKind::Straight => self.straight_edge_scratch.len(),
        };

        let required_stride = Self::edge_instance_stride_for(self.edge_geometry_kind);
        if self.aggregated_edge_count > self.edge_instance_capacity
            || self.edge_instance_buf.is_none()
            || self.edge_instance_stride != required_stride
        {
            let capacity = (self.aggregated_edge_count * 3 / 2).max(64);
            let buf_size = (capacity * required_stride) as u64;
            self.edge_instance_buf = Some(
                self.device
                    .new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.edge_instance_capacity = capacity;
            self.edge_instance_stride = required_stride;
        }

        if let Some(buf) = &self.edge_instance_buf {
            unsafe {
                match self.edge_geometry_kind {
                    EdgeGeometryKind::Curve => {
                        let ptr = buf.contents() as *mut CurveEdgeInstance;
                        std::ptr::copy_nonoverlapping(
                            self.classic_edge_scratch.as_ptr(),
                            ptr,
                            self.aggregated_edge_count,
                        );
                    }
                    EdgeGeometryKind::Straight => {
                        let ptr = buf.contents() as *mut LineEdgeInstance;
                        std::ptr::copy_nonoverlapping(
                            self.straight_edge_scratch.as_ptr(),
                            ptr,
                            self.aggregated_edge_count,
                        );
                    }
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
            .filter(|&index| {
                world.graph_node[index].visible != 0 && world.hierarchy[index].link_count >= 9
            })
            .count();
        let confidence_glow_count = (0..world.len())
            .filter(|&index| {
                world.graph_node[index].visible != 0 && world.graph_node[index].confidence > 0.0
            })
            .count();
        let node_count = world.len() + 2 + hub_count + confidence_glow_count;
        let edge_count = world.edges.len();

        if node_count > self.node_instance_capacity || self.node_instance_buf.is_none() {
            let capacity = (node_count * 3 / 2).max(64);
            let buf_size = (capacity * std::mem::size_of::<NodeInstance>()) as u64;
            self.node_instance_buf = Some(
                self.device
                    .new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.node_instance_capacity = capacity;
        }

        let required_stride = Self::edge_instance_stride_for(self.preferred_edge_geometry_kind());
        if edge_count > self.edge_instance_capacity
            || self.edge_instance_buf.is_none()
            || self.edge_instance_stride != required_stride
        {
            let capacity = (edge_count * 3 / 2).max(64);
            let buf_size = (capacity * required_stride) as u64;
            self.edge_instance_buf = Some(
                self.device
                    .new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.edge_instance_capacity = capacity;
            self.edge_instance_stride = required_stride;
        }

        self.upload_graph(world);
    }

    /// Simple LCG random: returns float in [-1, 1].
    fn rand_float(&mut self) -> f32 {
        self.wind_rng_state = self
            .wind_rng_state
            .wrapping_mul(1103515245)
            .wrapping_add(12345);
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
            if p[0] < cx - half_w * 1.3
                || p[0] > cx + half_w * 1.3
                || p[1] < cy - half_h * 1.3
                || p[1] > cy + half_h * 1.3
            {
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
        #[cfg(any(test, debug_assertions))]
        {
            self.debug_counters.upload_graph_calls += 1;
        }
        self.rebuild_classic_buffers(world);
    }

    /// Update positions in-place (called every frame after sync_positions).
    /// Buffer layout: [glow_count glows] [node_count nodes] [highlight rings].
    pub fn update_positions(&mut self, world: &World) {
        #[cfg(any(test, debug_assertions))]
        {
            self.debug_counters.update_positions_calls += 1;
        }
        self.rebuild_classic_buffers(world);
    }

    /// Append highlight ring instances after glow + regular node instances.
    pub fn set_highlights(&mut self, selected: Option<u32>, hovered: Option<u32>, world: &World) {
        let Some(buf) = &self.node_instance_buf else {
            return;
        };
        let ptr = buf.contents() as *mut NodeInstance;
        let mut idx = self.glow_count + self.node_count + self.face_feature_count;
        let capacity = self.node_instance_capacity;

        if idx < capacity
            && let Some(sel_id) = selected
            && let Some(gi) = world.index_of_node_id(sel_id)
            && world.graph_node[gi].visible != 0
        {
            let color = self.node_color_for_u8(world.hierarchy[gi].node_type);
            let r = self.classic_node_radius(world, gi);
            unsafe {
                *ptr.add(idx) = NodeInstance {
                    position: [world.transform[gi].x, world.transform[gi].y],
                    radius: r + 8.0,
                    z: z_for_link_count(world.hierarchy[gi].link_count),
                    color: [color[0], color[1], color[2], 0.58],
                    face_type: SELECTED_HIGHLIGHT_RING_TYPE,
                    _pad: [0.0; 3],
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
            let r = self.classic_node_radius(world, gi);
            unsafe {
                *ptr.add(idx) = NodeInstance {
                    position: [world.transform[gi].x, world.transform[gi].y],
                    radius: r + 4.0,
                    z: z_for_link_count(world.hierarchy[gi].link_count),
                    color: [1.0, 1.0, 1.0, 0.32],
                    face_type: HOVER_HIGHLIGHT_RING_TYPE,
                    _pad: [0.0; 3],
                };
            }
            idx += 1;
        }

        self.highlight_count = idx - self.glow_count - self.node_count - self.face_feature_count;
    }

    /// Rebuild the per-instance highlight flag buffer.
    /// Called every frame — cheap (N bytes) and ensures highlight changes are always visible,
    /// even when physics is settled and update_positions isn't running.
    pub fn rebuild_highlight_flags(&mut self, world: &World) {
        let total =
            self.glow_count + self.node_count + self.face_feature_count + self.highlight_count;
        if total == 0 {
            return;
        }

        // Flag encoding: 0=normal, 1=highlighted, 2=dim-dark, 3=dim-light, 5=glow-dim.
        const NODE_DIM_DARK: u8 = 2; // dark mode: strong dim + desaturate
        const NODE_DIM_LIGHT: u8 = 3; // light mode: gentle fade + desaturate
        const GLOW_DIM: u8 = 5; // glow dim factor ≈ 0.020

        let node_dim = if self.light_mode {
            NODE_DIM_LIGHT
        } else {
            NODE_DIM_DARK
        };

        // Reuse pre-allocated scratch buffer (avoids heap allocation every frame).
        self.highlight_flag_scratch.clear();
        self.highlight_flag_scratch.reserve(total);

        if self.highlight.active {
            // Glow flags — must mirror update_positions exactly: cap at self.glow_count.
            let mut glow_flags = 0usize;
            for &node_index in &self.rendered_node_indices {
                let graph_node = &world.graph_node[node_index];
                let lit = self.highlight.highlighted_ids.contains(&graph_node.node_id);
                if world.hierarchy[node_index].link_count >= 9 && glow_flags < self.glow_count {
                    self.highlight_flag_scratch
                        .push(if lit { 1 } else { GLOW_DIM });
                    glow_flags += 1;
                }
                if graph_node.confidence > 0.0 && glow_flags < self.glow_count {
                    self.highlight_flag_scratch
                        .push(if lit { 1 } else { GLOW_DIM });
                    glow_flags += 1;
                }
            }
            // Pad or truncate to exactly glow_count (safety net).
            self.highlight_flag_scratch.resize(self.glow_count, 0);

            // Regular node flags: 1 = highlighted (bright), node_dim = dimmed
            for &node_index in &self.rendered_node_indices {
                let graph_node = &world.graph_node[node_index];
                let lit = self.highlight.highlighted_ids.contains(&graph_node.node_id);
                self.highlight_flag_scratch
                    .push(if lit { 1 } else { node_dim });
            }
            self.highlight_flag_scratch.resize(
                self.glow_count + self.node_count + self.face_feature_count,
                0,
            );
        } else {
            // No highlight — all normal
            self.highlight_flag_scratch.resize(
                self.glow_count + self.node_count + self.face_feature_count,
                0,
            );
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
                self.device
                    .new_buffer(capacity as u64, MTLResourceOptions::StorageModeShared),
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
        #[cfg(any(test, debug_assertions))]
        {
            self.debug_counters.node_highlight_uploads += 1;
        }
    }

    pub fn rebuild_edge_highlight_flags(&mut self) {
        const EDGE_HIGHLIGHT_DARK: u8 = 1;
        const EDGE_DIM_DARK: u8 = 2;
        const EDGE_HIGHLIGHT_LIGHT: u8 = 3;
        const EDGE_DIM_LIGHT: u8 = 4;

        if self.edge_instance_count == 0 {
            self.edge_highlight_flag_scratch.clear();
            return;
        }

        self.edge_highlight_flag_scratch.clear();
        self.edge_highlight_flag_scratch
            .reserve(self.edge_instance_count);

        if self.highlight.active {
            for pair in &self.edge_highlight_pairs {
                if pair[0] == u32::MAX || pair[1] == u32::MAX {
                    self.edge_highlight_flag_scratch.push(0);
                    continue;
                }
                let src_lit = self.highlight.highlighted_ids.contains(&pair[0]);
                let tgt_lit = self.highlight.highlighted_ids.contains(&pair[1]);
                let flag = if self.light_mode {
                    if src_lit && tgt_lit {
                        EDGE_HIGHLIGHT_LIGHT
                    } else {
                        EDGE_DIM_LIGHT
                    }
                } else if src_lit && tgt_lit {
                    EDGE_HIGHLIGHT_DARK
                } else {
                    EDGE_DIM_DARK
                };
                self.edge_highlight_flag_scratch.push(flag);
            }
        } else {
            self.edge_highlight_flag_scratch
                .resize(self.edge_instance_count, 0);
        }

        let needed = self.edge_highlight_flag_scratch.len();
        if needed > self.edge_highlight_flag_capacity || self.edge_highlight_flag_buf.is_none() {
            let capacity = (needed * 3 / 2).max(64);
            self.edge_highlight_flag_buf = Some(
                self.device
                    .new_buffer(capacity as u64, MTLResourceOptions::StorageModeShared),
            );
            self.edge_highlight_flag_capacity = capacity;
        }
        if let Some(buf) = &self.edge_highlight_flag_buf {
            unsafe {
                std::ptr::copy_nonoverlapping(
                    self.edge_highlight_flag_scratch.as_ptr(),
                    buf.contents() as *mut u8,
                    needed,
                );
            }
        }
        #[cfg(any(test, debug_assertions))]
        {
            self.debug_counters.edge_highlight_uploads += 1;
        }
    }

    /// Generate magnetic field lines for a hovered node.
    /// Creates 2-3 bezier curves per neighbor, slightly offset, for a field-line fan effect.
    /// Lines are rendered using the existing edge shader.
    pub fn update_field_lines(&mut self, hovered: Option<u32>, world: &World, time: f32) {
        if hovered == self.field_line_hovered_id && hovered.is_some() {
            // Same node still hovered — just update positions with time animation.
            if hovered.is_none() {
                return;
            }
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

            let Some(n_idx) = world.index_of(neighbor_entity) else {
                continue;
            };
            if world.graph_node[n_idx].visible == 0 {
                continue;
            }

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
                        thickness_px: 1.2,
                        _pad: [0.0; 3],
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
                    self.device
                        .new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
                );
                self.field_line_capacity = capacity;
                #[cfg(any(test, debug_assertions))]
                {
                    self.debug_counters.field_line_buffer_allocations += 1;
                }
            } else {
                #[cfg(any(test, debug_assertions))]
                {
                    self.debug_counters.field_line_buffer_reuses += 1;
                }
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
        let library = match self
            .device
            .new_library_with_source(DIALOGUE_SHADER_SOURCE, &CompileOptions::new())
        {
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
        desc.set_vertex_descriptor(Some(vd));

        // Alpha blending (same as classic pipelines).
        if let Some(color_attach) = desc.color_attachments().object_at(0) {
            color_attach.set_pixel_format(MTLPixelFormat::BGRA8Unorm_sRGB);
            color_attach.set_blending_enabled(true);
            color_attach.set_source_rgb_blend_factor(MTLBlendFactor::SourceAlpha);
            color_attach.set_destination_rgb_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
            color_attach.set_source_alpha_blend_factor(MTLBlendFactor::One);
            color_attach.set_destination_alpha_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
        }

        self.dialogue_pipeline = self.device.new_render_pipeline_state(&desc).ok();
    }

    fn dialogue_box_geometry(&self, world: &World) -> Option<DialogueBoxGeometry> {
        let node_index = self.dialogue.node_index?;
        if node_index >= world.len()
            || self.last_viewport_width <= 0.0
            || self.last_viewport_height <= 0.0
        {
            return None;
        }

        let node_x = world.transform[node_index].x;
        let node_y = world.transform[node_index].y;
        let node_radius = world.graph_node[node_index].radius;
        let zoom = self.camera_zoom.max(0.01);
        let layout = dialogue_layout_metrics(zoom);

        // Convert screen-space dimensions to world-space.
        let box_w_world = layout.box_screen_width / zoom;
        let box_h_world = layout.box_screen_height / zoom;
        let side_gap_world = node_radius + layout.side_gap_screen / zoom;
        let preferred_left = if node_x <= self.camera_offset[0] {
            node_x + side_gap_world
        } else {
            node_x - box_w_world - side_gap_world
        };
        let box_left = clamp_dialogue_box_left(
            preferred_left,
            self.camera_offset[0],
            zoom,
            self.last_viewport_width,
            box_w_world,
        );
        let vw = self.last_viewport_width;
        let vh = self.last_viewport_height;
        let (preferred_box_bottom_y, tail_tip_y) =
            dialogue_box_vertical_layout(node_y, node_radius, zoom);
        let preferred_box_top_y = preferred_box_bottom_y - box_h_world;
        let max_box_top_y = tail_tip_y - layout.tail_screen_height / zoom - box_h_world;
        let box_top_y = clamp_dialogue_box_top(
            preferred_box_top_y,
            self.camera_offset[1],
            zoom,
            vh,
            box_h_world,
            max_box_top_y,
        );
        let box_bottom_y = box_top_y + box_h_world;

        let screen_box_x = (box_left - self.camera_offset[0]) * zoom + vw * 0.5;
        let screen_box_y = (box_top_y - self.camera_offset[1]) * zoom + vh * 0.5;
        let screen_box_w = box_w_world * zoom;
        let screen_box_h = box_h_world * zoom;
        let node_screen_x = (node_x - self.camera_offset[0]) * zoom + vw * 0.5;
        let node_screen_y = (node_y - self.camera_offset[1]) * zoom + vh * 0.5;

        Some(DialogueBoxGeometry {
            left: box_left,
            right: box_left + box_w_world,
            top: box_top_y,
            bottom: box_bottom_y,
            screen_rect: [screen_box_x, screen_box_y, screen_box_w, screen_box_h],
            node_screen_pos: [node_screen_x, node_screen_y],
        })
    }

    fn compute_dialogue_box_position(&mut self, world: &World) {
        let Some(geometry) = self.dialogue_box_geometry(world) else {
            return;
        };
        self.dialogue.box_screen_rect = geometry.screen_rect;
        self.dialogue.node_screen_pos = geometry.node_screen_pos;
    }

    fn build_dialogue_vertices(&mut self, world: &World) {
        self.dialogue_vertex_scratch.clear();

        let Some(node_index) = self.dialogue.node_index else {
            return;
        };
        if node_index >= world.len() {
            return;
        }
        let Some(geometry) = self.dialogue_box_geometry(world) else {
            return;
        };

        let zoom = self.camera_zoom.max(0.01);
        let layout = dialogue_layout_metrics(zoom);
        let border_w = 1.0 / zoom;
        let nameplate_h = if layout.compact { 24.0 } else { 34.0 } / zoom;
        let left = geometry.left;
        let right = geometry.right;
        let box_top = geometry.top;
        let box_bottom = geometry.bottom;

        // No Metal-drawn box — the SwiftUI overlay (DialogueOverlayView) handles all visuals.
        // Geometry is still computed above for box_screen_rect positioning.
        let _ = (left, right, box_top, box_bottom, border_w, nameplate_h);
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
        if self
            .dialogue_vertex_buf
            .as_ref()
            .is_none_or(|b| b.length() < needed_bytes)
        {
            let capacity_bytes = (needed_bytes * 3 / 2).max(1024);
            self.dialogue_vertex_buf = Some(
                self.device
                    .new_buffer(capacity_bytes, MTLResourceOptions::StorageModeShared),
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
            encoder.draw_primitives(MTLPrimitiveType::Triangle, 0, vertex_count as u64);
        }
    }

    /// Camera smoothing factor. Higher = faster. 6.5 = snappy response
    /// that still reads as smooth. Was 3.0 (too slow per user 2026-04-04).
    const CAMERA_LAMBDA: f32 = 6.5;

    pub fn set_camera_immediately(&mut self, offset: [f32; 2], zoom: f32) {
        self.camera_offset = offset;
        self.target_offset = offset;
        self.camera_zoom = zoom;
        self.target_zoom = zoom;
        self.prev_camera_offset = offset;
        self.prev_camera_zoom = zoom;
        self.is_animating = false;
        self.last_frame_time = std::time::Instant::now();
    }

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

    /// Canonical graph pass order: edges first, field lines second, nodes third,
    /// SDF labels fourth, and dialogue overlay last. Nodes must remain above
    /// edges so solid node bodies occlude edge geometry at crossings/endpoints.
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
                if dt > 2.0 {
                    self.pulse_start = 0.0;
                    -1.0
                } else {
                    dt
                }
            } else {
                -1.0
            };
            // Decay impact intensity each frame (~0.33s total fade).
            let dt = 1.0 / 60.0;
            if self.impact_intensity > 0.0 {
                self.impact_intensity = (self.impact_intensity - dt * 3.0).max(0.0);
            }
            let uniforms = self.uniforms_for_draw(
                viewport_width as f32,
                viewport_height as f32,
                elapsed,
                pulse_t,
            );
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
            attach_command_buffer_logging(cmd_buf, "renderer_draw");
            let encoder = cmd_buf.new_render_command_encoder(render_desc);

            // Draw edges first (behind nodes)
            let effective_edge_count = self.edge_instance_count;
            if effective_edge_count > 0
                && let Some(inst_buf) = &self.edge_instance_buf
            {
                // Clamp to buffer capacity to prevent Metal validation crash.
                let edge_draw = effective_edge_count.min(self.edge_instance_capacity);
                match self.edge_geometry_kind {
                    EdgeGeometryKind::Curve => {
                        encoder.set_render_pipeline_state(&self.edge_pipeline);
                    }
                    EdgeGeometryKind::Straight => {
                        encoder.set_render_pipeline_state(&self.straight_edge_pipeline);
                    }
                }
                encoder.set_vertex_buffer(0, Some(inst_buf), 0);
                encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                if self.edge_highlight_flag_buf.is_none()
                    || self.edge_highlight_flag_capacity < edge_draw
                {
                    let cap = (edge_draw * 3 / 2).max(64);
                    self.edge_highlight_flag_buf = Some(
                        self.device
                            .new_buffer(cap as u64, MTLResourceOptions::StorageModeShared),
                    );
                    self.edge_highlight_flag_capacity = cap;
                    if let Some(flag_buf) = &self.edge_highlight_flag_buf {
                        unsafe {
                            std::ptr::write_bytes(flag_buf.contents() as *mut u8, 0, cap);
                        }
                    }
                }
                if let Some(flag_buf) = &self.edge_highlight_flag_buf {
                    encoder.set_vertex_buffer(2, Some(flag_buf), 0);
                }
                encoder.draw_primitives_instanced(
                    MTLPrimitiveType::Triangle,
                    0,
                    self.edge_vertices_per_instance(),
                    edge_draw as u64,
                );
            }

            // Draw magnetic field lines (hover interaction, between edges and nodes).
            if self.field_line_count > 0
                && let Some(fl_buf) = &self.field_line_buf
            {
                let fl_draw = self.field_line_count.min(self.field_line_capacity);
                encoder.set_render_pipeline_state(&self.field_line_pipeline);
                encoder.set_vertex_buffer(0, Some(fl_buf), 0);
                encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                encoder.draw_primitives_instanced(MTLPrimitiveType::Triangle, 0, 6, fl_draw as u64);
            }

            // Draw nodes: glow instances + regular nodes + highlight rings.
            let total_instances =
                self.glow_count + self.node_count + self.face_feature_count + self.highlight_count;
            if total_instances > 0
                && let Some(inst_buf) = &self.node_instance_buf
            {
                // Safety: clamp draw count to actual buffer capacities.
                // Metal validates that shader reads don't exceed buffer length.
                let draw_count = total_instances.min(self.node_instance_capacity);

                encoder.set_render_pipeline_state(&self.node_pipeline);
                encoder.set_vertex_buffer(0, Some(inst_buf), 0);
                encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                // Bind uniforms to fragment shader for pulse wave effect.
                encoder.set_fragment_buffer(1, Some(&self.uniform_buf), 0);

                // Bind highlight flag buffer (buffer(2)).
                // Ensure buffer exists AND is large enough for draw_count.
                if self.highlight_flag_buf.is_none() || self.highlight_flag_capacity < draw_count {
                    let cap = (draw_count * 3 / 2).max(64);
                    let buf = self
                        .device
                        .new_buffer(cap as u64, MTLResourceOptions::StorageModeShared);
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
                        self.device
                            .new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
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

            // Draw SDF text labels (after nodes, before dialogue overlay).
            self.draw_label_commands(encoder);

            // Draw dialogue box overlay (after labels, on top).
            self.draw_dialogue_commands(encoder);

            encoder.end_encoding();

            cmd_buf.present_drawable(drawable);
            cmd_buf.commit();
        });

        self.prev_camera_zoom = self.camera_zoom;
        self.prev_camera_offset = self.camera_offset;
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
    fn render_order_keeps_edges_under_nodes_and_labels() {
        let source = std::fs::read_to_string(file!()).expect("renderer source should be readable");
        let edge_pipeline = source
            .find("encoder.set_render_pipeline_state(&self.edge_pipeline)")
            .expect("edge pipeline draw call should exist");
        let straight_edge_pipeline = source
            .find("encoder.set_render_pipeline_state(&self.straight_edge_pipeline)")
            .expect("straight edge pipeline draw call should exist");
        let field_line_pipeline = source
            .find("encoder.set_render_pipeline_state(&self.field_line_pipeline)")
            .expect("field line pipeline draw call should exist");
        let node_pipeline = source
            .find("encoder.set_render_pipeline_state(&self.node_pipeline)")
            .expect("node pipeline draw call should exist");
        let label_pass = source
            .find("self.draw_label_commands(encoder)")
            .expect("label draw call should exist");
        let dialogue_pass = source
            .find("self.draw_dialogue_commands(encoder)")
            .expect("dialogue draw call should exist");

        assert!(edge_pipeline < field_line_pipeline);
        assert!(straight_edge_pipeline < field_line_pipeline);
        assert!(field_line_pipeline < node_pipeline);
        assert!(node_pipeline < label_pass);
        assert!(label_pass < dialogue_pass);
    }

    #[test]
    fn edge_weight_maps_to_clamped_screen_thickness() {
        let thin = edge_width_px_for_weight(0.0, 20.0, 20.0);
        let medium = edge_width_px_for_weight(0.5, 20.0, 20.0);
        let thick = edge_width_px_for_weight(1.0, 20.0, 20.0);
        let small_endpoint = edge_width_px_for_weight(1.0, 2.0, 40.0);

        assert!(thin >= MIN_EDGE_WIDTH_PX);
        assert!(medium > thin);
        assert!(thick > medium);
        assert!(thick <= MAX_EDGE_WIDTH_PX);
        assert!(small_endpoint <= 2.0 * 0.6 * 2.0);
    }

    #[test]
    fn edge_color_blends_endpoint_palette_when_available() {
        let base = [0.20, 0.20, 0.20, 0.48];
        let red = [0.94, 0.08, 0.07, 1.0];
        let yellow = [1.0, 0.84, 0.04, 1.0];
        let blended = edge_color_with_endpoint_palette(base, red, yellow);

        assert!(blended[0] > base[0]);
        assert!(blended[1] > base[1]);
        assert!(blended[2] < base[2]);
        assert_eq!(blended[3], base[3]);

        let fallback = edge_color_with_endpoint_palette(base, [0.0; 4], [0.0; 4]);
        assert_eq!(fallback, base);
    }

    #[test]
    fn cinematic_pixel_nodes_apply_selection_dim_without_transparency() {
        let source = include_str!("renderer.rs");
        let production_source = source
            .split("mod tests")
            .next()
            .expect("renderer source should contain production section");

        assert!(production_source.contains("float3 selection_dim_target = light"));
        assert!(production_source.contains(": srgb_to_linear(float3(0.06, 0.06, 0.06));"));
        assert!(production_source.contains("pixel_color = mix(pixel_color, selection_dim_target"));
        assert!(production_source.contains("float dim_alpha_floor = is_dimmed ? 0.95 : 0.85;"));
        assert!(production_source.contains("return float4(pixel_color, max(in.color.a, 0.95));"));
    }

    #[test]
    fn uniforms_size_matches_metal() {
        // Uniforms must be consistent between Rust and Metal (16-byte aligned).
        // 17 data floats = 68 bytes, padded to 80 (next 16-byte boundary for
        // float2-aligned struct in MSL). repr(C) with [f32;2] as largest member
        // → 8-byte aligned → 72 (next multiple of 8). Let the test verify.
        let size = std::mem::size_of::<Uniforms>();
        assert!(size >= 68, "Uniforms too small: {size}");
        assert_eq!(size % 4, 0, "Uniforms not 4-byte aligned: {size}");
    }

    #[test]
    fn node_instance_size() {
        // position(8) + radius(4) + z(4) + color(16) + face_type(4) + _pad(12) = 48 bytes.
        // Must be a multiple of 16 to match Metal's float4 alignment stride.
        assert_eq!(std::mem::size_of::<NodeInstance>(), 48);
    }

    #[test]
    fn line_edge_instance_size() {
        // p0(8) + p1(8) + color(16) + thickness(4) + pad(12) = 48 bytes.
        assert_eq!(std::mem::size_of::<LineEdgeInstance>(), 48);
    }

    #[test]
    fn curve_edge_instance_size() {
        // p0(8) + c0(8) + c1(8) + p1(8) + color(16) + thickness(4) + pad(12) = 64 bytes.
        assert_eq!(std::mem::size_of::<CurveEdgeInstance>(), 64);
    }

    #[test]
    fn lod_profile_is_zoom_stable_in_cinematic_mode() {
        let near = lod_profile_for_zoom(1.0, 0);
        let far = lod_profile_for_zoom(0.05, 0);
        assert_eq!(near, far);
        assert!(near.draw_edges);
        assert!(!near.draw_glow);
        assert!(!near.cluster_nodes);
    }

    #[test]
    fn density_cell_size_grows_when_zooming_out() {
        assert!(density_cell_size_world(0.05) > density_cell_size_world(0.20));
    }

    #[test]
    fn camera_motion_disables_view_culling() {
        let mut renderer = make_test_renderer();
        renderer.set_viewport_size(640, 360);
        renderer.camera_offset = [0.0, 0.0];
        renderer.camera_zoom = 1.0;
        renderer.prev_camera_offset = [0.0, 0.0];
        renderer.prev_camera_zoom = 1.0;

        let stable = renderer
            .current_view_bounds(Renderer::CLASSIC_CULL_PADDING_PIXELS)
            .expect("viewport bounds should exist");

        renderer.prev_camera_offset = [-48.0, 24.0];
        renderer.prev_camera_zoom = 0.88;
        assert!(
            renderer
                .current_view_bounds(Renderer::CLASSIC_CULL_PADDING_PIXELS)
                .is_none()
        );

        renderer.prev_camera_offset = renderer.camera_offset;
        renderer.prev_camera_zoom = renderer.camera_zoom;

        let restored = renderer
            .current_view_bounds(Renderer::CLASSIC_CULL_PADDING_PIXELS)
            .expect("viewport bounds should restore once motion stops");

        assert_eq!(restored, stable);
    }

    #[test]
    fn lod_profile_is_zoom_stable_in_performance_mode() {
        let near = lod_profile_for_zoom(1.0, 2);
        let far = lod_profile_for_zoom(0.05, 2);
        assert_eq!(near, far);
        assert!(near.draw_edges);
        assert!(!near.draw_glow);
        assert!(!near.cluster_nodes);
        assert_eq!(near.edge_degree_threshold, u32::MAX);
        assert_eq!(near.max_edges_per_node, u16::MAX);
    }

    #[test]
    fn segment_intersects_bounds_detects_crossing_line() {
        let bounds = ViewBounds {
            min_x: 0.0,
            min_y: 0.0,
            max_x: 100.0,
            max_y: 100.0,
        };
        assert!(segment_intersects_bounds(
            bounds,
            [-20.0, 50.0],
            [120.0, 50.0]
        ));
    }

    #[test]
    fn bounds_intersects_circle_excludes_far_node() {
        let bounds = viewport_bounds([0.0, 0.0], 1.0, [200.0, 200.0], 0.0);
        assert!(bounds_intersects_circle(bounds, [90.0, 0.0], 12.0));
        assert!(!bounds_intersects_circle(bounds, [150.0, 0.0], 12.0));
    }

    #[test]
    fn sort_and_dedup_indices_collapses_duplicate_candidates() {
        let mut indices = vec![4, 1, 4, 2, 1, 3];
        sort_and_dedup_indices(&mut indices);
        assert_eq!(indices, vec![1, 2, 3, 4]);
    }

    #[test]
    fn label_draw_gate_stays_open_in_performance_mode() {
        let mut renderer = make_test_renderer();
        renderer.labels_enabled = true;
        renderer.quality_level = 2;

        assert!(renderer.labels_pass_primary_draw_gate());
    }

    #[test]
    fn label_draw_gate_still_respects_global_disable_toggle() {
        let mut renderer = make_test_renderer();
        renderer.labels_enabled = false;
        renderer.quality_level = 0;

        assert!(!renderer.labels_pass_primary_draw_gate());
    }

    #[test]
    fn edge_visibility_keeps_curve_crossing_view_even_if_endpoints_are_outside() {
        let bounds = viewport_bounds([0.0, 0.0], 1.0, [200.0, 200.0], 0.0);
        let p0 = [-160.0, 0.0];
        let p1 = [160.0, 0.0];
        let c0 = [-40.0, 90.0];
        let c1 = [40.0, 90.0];

        assert!(edge_intersects_view(Some(bounds), p0, p1, c0, c1));
    }

    #[test]
    fn display_velocity_suppresses_minor_motion_artifacts() {
        assert_eq!(display_velocity(2.0, 1.0), [0.0, 0.0]);
    }

    #[test]
    fn display_velocity_caps_large_motion_stretch() {
        let velocity = display_velocity(240.0, 0.0);
        assert!(velocity[0] <= 18.0);
        assert_eq!(velocity[1], 0.0);
    }

    #[test]
    fn render_velocity_suppresses_motion_while_camera_animates() {
        assert_eq!(render_velocity(120.0, 40.0, true), [0.0, 0.0]);
        assert_ne!(render_velocity(120.0, 40.0, false), [0.0, 0.0]);
    }

    #[test]
    fn dialogue_state_default_inactive() {
        let state = DialogueState::default();
        assert!(!state.active);
        assert!(state.node_index.is_none());
        assert!(!state.is_streaming);
        assert_eq!(state.look_target_world, [0.0; 2]);
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
        let compact = dialogue_layout_metrics(0.35);
        let medium = dialogue_layout_metrics(0.7);
        let full = dialogue_layout_metrics(1.0);
        assert!(compact.box_screen_width > 0.0);
        assert!(compact.box_screen_height > 0.0);
        assert!(compact.tail_screen_height > 0.0);
        assert!(compact.gap_screen > 0.0);
        assert!(medium.box_screen_width > compact.box_screen_width);
        assert!(full.box_screen_width > medium.box_screen_width);
    }

    #[test]
    fn dialogue_box_dimensions_are_roomy_enough_for_overlay_ui() {
        let full = dialogue_layout_metrics(1.0);
        assert!(full.box_screen_width >= 640.0);
        assert!(full.box_screen_height >= 320.0);
    }

    #[test]
    fn dialogue_box_collapses_to_compact_teaser_at_far_zoom() {
        let compact = dialogue_layout_metrics(0.35);
        let full = dialogue_layout_metrics(1.0);
        assert!(compact.compact);
        assert!(compact.box_screen_width < full.box_screen_width);
        assert!(compact.box_screen_height < full.box_screen_height);
    }

    #[test]
    fn dialogue_box_sits_above_large_node_face() {
        let node_y = 240.0;
        let node_radius = 64.0;
        let (box_bottom_y, tail_tip_y) = dialogue_box_vertical_layout(node_y, node_radius, 1.0);
        assert!(tail_tip_y < node_y - node_radius - 20.0);
        assert!(box_bottom_y < tail_tip_y);
    }

    #[test]
    fn string_edge_control_points_bend_off_center_line() {
        let (c0, c1) = string_edge_control_points(
            [0.0, 0.0],
            [100.0, 0.0],
            [8.0, 0.0],
            [-8.0, 0.0],
            140.0,
            0.22,
        );
        assert!(c0[0] > 0.0 && c0[0] < 60.0);
        assert!(c1[0] > 40.0 && c1[0] < 100.0);
        assert!(c0[1].abs().max(c1[1].abs()) >= 8.0);
    }

    #[test]
    fn cubic_bezier_preserves_segment_endpoints() {
        let p0 = [0.0, 0.0];
        let c0 = [30.0, 22.0];
        let c1 = [70.0, 22.0];
        let p1 = [100.0, 0.0];
        assert_eq!(cubic_bezier_point(p0, c0, c1, p1, 0.0), p0);
        assert_eq!(cubic_bezier_point(p0, c0, c1, p1, 1.0), p1);
    }

    #[test]
    fn string_edge_control_points_reduce_sag_under_high_tension() {
        let relaxed = string_edge_control_points(
            [0.0, 0.0],
            [160.0, 0.0],
            [0.0, 0.0],
            [0.0, 0.0],
            260.0,
            1.0,
        );
        let taut = string_edge_control_points(
            [0.0, 0.0],
            [280.0, 0.0],
            [0.0, 0.0],
            [0.0, 0.0],
            180.0,
            1.0,
        );
        let relaxed_sag = relaxed.0[1].abs().max(relaxed.1[1].abs());
        let taut_sag = taut.0[1].abs().max(taut.1[1].abs());
        assert!(relaxed_sag > taut_sag);
    }

    #[allow(clippy::assertions_on_constants)]
    #[test]
    fn glow_instance_cutoff_stays_between_nodes_and_glows() {
        // Glow alphas (0.03–0.11) must be below this cutoff,
        // and regular nodes (BASE_NODE_ALPHA) must be above.
        assert!(GLOW_INSTANCE_ALPHA_CUTOFF > CONF_GLOW_ALPHA_BASE + CONF_GLOW_ALPHA_SCALE);
        assert!(GLOW_INSTANCE_ALPHA_CUTOFF < BASE_NODE_ALPHA);
    }

    #[test]
    fn shader_source_defines_runtime_glow_cutoff_constant() {
        assert!(SHADER_SOURCE.contains(&format!(
            "constant float GLOW_INSTANCE_ALPHA_CUTOFF = {:.2};",
            GLOW_INSTANCE_ALPHA_CUTOFF
        )));
    }

    #[test]
    fn aggregated_edge_light_palette_stays_dark() {
        let light = aggregated_edge_base_rgb(true);
        let dark = aggregated_edge_base_rgb(false);

        assert!(light[0].max(light[1]).max(light[2]) <= 0.11);
        assert!(dark[0] > light[0]);
        assert!(dark[1] > light[1]);
        assert!(dark[2] > light[2]);
    }

    #[test]
    fn clamp_dialogue_box_left_keeps_box_inside_viewport() {
        let zoom = 1.0;
        let box_width_world = dialogue_layout_metrics(zoom).box_screen_width / zoom;
        let left = clamp_dialogue_box_left(520.0, 0.0, zoom, 1800.0, box_width_world);
        let margin = DIALOGUE_VIEWPORT_MARGIN_SCREEN / zoom;
        let max_left = 900.0 - margin - box_width_world;
        assert!((left - max_left).abs() < f32::EPSILON);
    }

    #[test]
    fn clamp_dialogue_box_top_keeps_box_inside_viewport_when_room_exists() {
        let zoom = 1.0;
        let box_height_world = dialogue_layout_metrics(zoom).box_screen_height / zoom;
        let top = clamp_dialogue_box_top(-360.0, 0.0, zoom, 900.0, box_height_world, -40.0);
        let min_top = -450.0 + DIALOGUE_VIEWPORT_MARGIN_SCREEN / zoom;
        let max_top = -40.0;
        assert!((min_top..=max_top).contains(&top));
    }

    fn make_test_renderer() -> Renderer {
        let device = Device::system_default().expect("Metal device should exist in renderer tests");
        let layer = MetalLayer::new();
        Renderer::new(
            device.as_ptr() as *mut std::ffi::c_void,
            layer.as_ptr() as *mut std::ffi::c_void,
        )
        .expect("renderer should initialize")
    }

    fn make_test_world(node_count: usize, spacing: f32) -> World {
        let mut graph = crate::types::Graph::new();
        for index in 0..node_count {
            graph.add_node(
                format!("node-{index}"),
                100.0 + index as f32 * spacing,
                0.0,
                0,
                2,
                format!("Node {index}"),
            );
        }
        for index in 0..node_count.saturating_sub(1) {
            graph.add_edge(
                &format!("node-{index}"),
                &format!("node-{}", index + 1),
                1.0,
                0,
            );
        }
        World::from_graph(&graph)
    }

    fn make_star_world(leaf_count: usize, radius: f32) -> World {
        let mut graph = crate::types::Graph::new();
        let center_x = 160.0;
        let center_y = 120.0;
        graph.add_node(
            "hub".to_string(),
            center_x,
            center_y,
            0,
            6,
            "Hub".to_string(),
        );
        for index in 0..leaf_count {
            let angle = std::f32::consts::TAU * index as f32 / leaf_count as f32;
            let x = center_x + radius * angle.cos();
            let y = center_y + radius * angle.sin();
            let leaf_id = format!("leaf-{index}");
            graph.add_node(leaf_id.clone(), x, y, 0, 2, format!("Leaf {index}"));
            graph.add_edge("hub", &leaf_id, 1.0, 0);
        }
        World::from_graph(&graph)
    }

    #[test]
    fn highlight_rebuild_updates_only_flag_buffers() {
        let world = make_test_world(3, 120.0);
        let mut renderer = make_test_renderer();
        renderer.set_viewport_size(1280, 720);
        renderer.allocate_buffers(&world);

        let baseline_rebuilds = renderer.debug_counters.classic_buffer_rebuilds;
        let baseline_uploads = renderer.debug_counters.upload_graph_calls;

        renderer.highlight.active = true;
        renderer
            .highlight
            .highlighted_ids
            .insert(world.graph_node[0].node_id);
        renderer
            .highlight
            .highlighted_ids
            .insert(world.graph_node[1].node_id);
        renderer.rebuild_highlight_flags(&world);
        renderer.rebuild_edge_highlight_flags();

        assert_eq!(
            renderer.debug_counters.classic_buffer_rebuilds,
            baseline_rebuilds
        );
        assert_eq!(renderer.debug_counters.upload_graph_calls, baseline_uploads);
        assert_eq!(renderer.debug_counters.node_highlight_uploads, 1);
        assert_eq!(renderer.debug_counters.edge_highlight_uploads, 1);
        assert_eq!(renderer.edge_highlight_flag_scratch, vec![1, 2]);
    }

    #[test]
    fn light_and_dark_node_highlight_flags_dim_non_neighbors() {
        if Device::system_default().is_none() {
            return;
        }
        let world = make_test_world(3, 120.0);
        let mut renderer = make_test_renderer();
        renderer.set_viewport_size(1280, 720);
        renderer.allocate_buffers(&world);

        renderer.highlight.active = true;
        renderer
            .highlight
            .highlighted_ids
            .insert(world.graph_node[0].node_id);
        renderer
            .highlight
            .highlighted_ids
            .insert(world.graph_node[1].node_id);
        renderer.rebuild_highlight_flags(&world);
        assert_eq!(renderer.highlight_flag_scratch, vec![1, 1, 2]);

        renderer.light_mode = true;
        renderer.rebuild_highlight_flags(&world);
        assert_eq!(renderer.highlight_flag_scratch, vec![1, 1, 3]);
    }

    #[test]
    fn light_mode_edge_highlights_use_separate_flags() {
        let world = make_test_world(3, 120.0);
        let mut renderer = make_test_renderer();
        renderer.light_mode = true;
        renderer.set_viewport_size(1280, 720);
        renderer.allocate_buffers(&world);

        renderer.highlight.active = true;
        renderer
            .highlight
            .highlighted_ids
            .insert(world.graph_node[0].node_id);
        renderer
            .highlight
            .highlighted_ids
            .insert(world.graph_node[1].node_id);
        renderer.rebuild_edge_highlight_flags();

        assert_eq!(renderer.edge_highlight_flag_scratch, vec![3, 4]);
    }

    #[test]
    fn field_line_buffer_reuses_capacity_for_same_hovered_node() {
        let world = make_test_world(3, 120.0);
        let mut renderer = make_test_renderer();
        renderer.set_viewport_size(1280, 720);

        let hovered_id = world.graph_node[1].node_id;
        renderer.update_field_lines(Some(hovered_id), &world, 0.0);
        let first_allocations = renderer.debug_counters.field_line_buffer_allocations;
        let first_count = renderer.field_line_count;

        renderer.update_field_lines(Some(hovered_id), &world, 0.5);

        assert!(first_count > 0);
        assert_eq!(
            renderer.debug_counters.field_line_buffer_allocations,
            first_allocations
        );
        assert!(renderer.debug_counters.field_line_buffer_reuses >= 1);
    }

    #[test]
    fn cinematic_quality_keeps_curved_edge_geometry() {
        let world = make_test_world(3, 120.0);
        let mut renderer = make_test_renderer();
        renderer.quality_level = 0;
        renderer.set_viewport_size(1280, 720);
        renderer.update_positions(&world);

        assert_eq!(renderer.edge_geometry_kind, EdgeGeometryKind::Curve);
        assert!(!renderer.classic_edge_scratch.is_empty());
        assert!(renderer.straight_edge_scratch.is_empty());
    }

    #[test]
    fn cinematic_quality_preserves_cinematic_uniforms_and_depth() {
        let world = make_test_world(3, 120.0);
        let mut renderer = make_test_renderer();
        renderer.quality_level = 0;

        let node = renderer.classic_node_instance(&world, 0);
        let uniforms = renderer.uniforms_for_draw(1280.0, 720.0, 1.0, 0.0);

        assert_ne!(node.z, 0.0);
        assert_eq!(uniforms.lite_mode, 0.0);
    }

    #[test]
    fn performance_quality_switches_to_straight_edge_geometry() {
        let world = make_test_world(3, 120.0);
        let mut renderer = make_test_renderer();
        renderer.quality_level = 2;
        renderer.set_viewport_size(1280, 720);
        renderer.update_positions(&world);

        assert_eq!(renderer.edge_geometry_kind, EdgeGeometryKind::Straight);
        assert!(!renderer.straight_edge_scratch.is_empty());
        assert!(renderer.classic_edge_scratch.is_empty());
    }

    #[test]
    fn pixel_edge_style_forces_straight_pixel_uniforms_without_quality_downgrade() {
        let world = make_test_world(3, 120.0);
        let mut renderer = make_test_renderer();
        renderer.quality_level = 0;
        renderer.edge_style = EdgeStyle::PixelArt;
        renderer.set_viewport_size(1280, 720);
        renderer.update_positions(&world);

        let uniforms = renderer.uniforms_for_draw(1280.0, 720.0, 1.0, 0.0);

        assert_eq!(renderer.quality_level, 0);
        assert_eq!(renderer.edge_geometry_kind, EdgeGeometryKind::Straight);
        assert!(!renderer.straight_edge_scratch.is_empty());
        assert!(renderer.classic_edge_scratch.is_empty());
        assert_eq!(uniforms.edge_style, 1.0);
    }

    #[test]
    fn performance_quality_preserves_static_depth_and_emits_performance_uniforms() {
        let world = make_test_world(3, 120.0);
        let mut renderer = make_test_renderer();
        renderer.quality_level = 2;

        let node = renderer.classic_node_instance(&world, 0);
        let uniforms = renderer.uniforms_for_draw(1280.0, 720.0, 1.0, 0.0);

        assert_ne!(node.z, 0.0);
        assert_eq!(uniforms.lite_mode, 2.0);
    }

    #[test]
    fn performance_quality_zeroes_velocity_uploads() {
        let mut world = make_test_world(3, 120.0);
        world.velocity[0].vx = 240.0;
        world.velocity[1].vy = -180.0;

        let mut renderer = make_test_renderer();
        renderer.quality_level = 2;
        renderer.set_viewport_size(1280, 720);
        renderer.update_positions(&world);

        assert!(
            renderer
                .classic_velocity_scratch
                .iter()
                .all(|velocity| *velocity == [0.0, 0.0])
        );
    }

    #[test]
    fn classic_theme_keeps_pixel_face_overlay_instances() {
        let world = make_test_world(1, 120.0);
        let mut renderer = make_test_renderer();
        renderer.visual_theme = VisualTheme::Classic;

        let node = renderer.classic_node_instance(&world, 0);

        assert_eq!(node.face_type, 1.0);
    }

    #[test]
    fn dark_mode_note_nodes_use_semantic_teal_fill() {
        let color = monochrome_graph_node_color(false, crate::types::NodeType::Note as u8, 0);

        assert_eq!(color, crate::types::NodeType::Note.color());
    }

    #[test]
    fn light_mode_note_nodes_use_semantic_teal_fill() {
        let color = monochrome_graph_node_color(true, crate::types::NodeType::Note as u8, 0);

        assert_eq!(color, crate::types::NodeType::Note.color_light());
    }

    #[test]
    fn light_and_dark_graph_nodes_are_solid_not_translucent() {
        for node_type in [
            crate::types::NodeType::Note,
            crate::types::NodeType::Folder,
            crate::types::NodeType::Idea,
            crate::types::NodeType::Chat,
            crate::types::NodeType::Source,
            crate::types::NodeType::Quote,
            crate::types::NodeType::Tag,
            crate::types::NodeType::Block,
        ] {
            let dark = monochrome_graph_node_color(false, node_type as u8, 0);
            let light = monochrome_graph_node_color(true, node_type as u8, 0);

            assert_eq!(dark[3], 1.0);
            assert_eq!(light[3], 1.0);
        }
    }

    #[test]
    fn dark_mode_folder_nodes_use_pitch_white_fill() {
        let root = monochrome_graph_node_color(false, crate::types::NodeType::Folder as u8, 0);
        let nested = monochrome_graph_node_color(false, crate::types::NodeType::Folder as u8, 3);

        assert_eq!(root, [1.0, 1.0, 1.0, 1.0]);
        assert_eq!(nested, root);
    }

    #[test]
    fn light_mode_folder_nodes_use_plain_oled_black_fill() {
        let root = monochrome_graph_node_color(true, crate::types::NodeType::Folder as u8, 0);
        let nested = monochrome_graph_node_color(true, crate::types::NodeType::Folder as u8, 3);

        assert_eq!(root, [0.0, 0.0, 0.0, 1.0]);
        assert_eq!(nested, root);
    }

    #[test]
    fn dark_mode_idea_nodes_keep_semantic_yellow_fill() {
        let color = monochrome_graph_node_color(false, crate::types::NodeType::Idea as u8, 0);

        assert_eq!(color, crate::types::NodeType::Idea.color());
    }

    #[test]
    fn light_mode_idea_nodes_keep_semantic_yellow_fill() {
        let color = monochrome_graph_node_color(true, crate::types::NodeType::Idea as u8, 0);

        assert_eq!(color, crate::types::NodeType::Idea.color_light());
    }

    #[test]
    fn classic_theme_skips_dialogue_face_geometry() {
        let world = make_test_world(1, 120.0);
        let mut renderer = make_test_renderer();
        renderer.visual_theme = VisualTheme::Classic;
        renderer.dialogue.active = true;
        renderer.dialogue.node_index = Some(0);
        renderer.set_viewport_size(1280, 720);

        renderer.update_positions(&world);

        assert_eq!(renderer.face_feature_count, 0);
    }

    #[test]
    fn highlight_instances_use_ring_overlay_sentinels() {
        let world = make_test_world(2, 120.0);
        let mut renderer = make_test_renderer();
        renderer.set_viewport_size(1280, 720);
        renderer.update_positions(&world);

        renderer.set_highlights(
            Some(world.graph_node[0].node_id),
            Some(world.graph_node[1].node_id),
            &world,
        );

        let highlight_start =
            renderer.glow_count + renderer.node_count + renderer.face_feature_count;
        let ptr = renderer
            .node_instance_buf
            .as_ref()
            .expect("highlight buffer should exist")
            .contents() as *const NodeInstance;
        let selected = unsafe { *ptr.add(highlight_start) };
        let hovered = unsafe { *ptr.add(highlight_start + 1) };

        assert_eq!(renderer.highlight_count, 2);
        assert_eq!(selected.face_type, SELECTED_HIGHLIGHT_RING_TYPE);
        assert_eq!(hovered.face_type, HOVER_HIGHLIGHT_RING_TYPE);
    }

    #[test]
    fn performance_quality_keeps_dense_hub_edges_connected() {
        let world = make_star_world(24, 180.0);
        let mut renderer = make_test_renderer();
        renderer.quality_level = 2;
        renderer.camera_offset = [0.0, 0.0];
        renderer.camera_zoom = 1.0;
        renderer.set_viewport_size(4096, 4096);

        renderer.update_positions(&world);

        assert_eq!(renderer.edge_geometry_kind, EdgeGeometryKind::Straight);
        assert_eq!(renderer.edge_instance_count, 24);
    }

    #[test]
    fn culling_padding_keeps_near_boundary_nodes_visible() {
        let world = make_test_world(2, 320.0);
        let mut renderer = make_test_renderer();
        renderer.camera_offset = [0.0, 0.0];
        renderer.camera_zoom = 1.0;
        renderer.set_viewport_size(640, 360);
        renderer.update_positions(&world);

        assert_eq!(renderer.rendered_node_indices.len(), 2);
    }

    #[test]
    fn update_positions_records_visible_workload_below_total_scene_size() {
        let world = make_test_world(8, 2_000.0);
        let mut renderer = make_test_renderer();
        renderer.camera_offset = [0.0, 0.0];
        renderer.camera_zoom = 1.0;
        renderer.set_viewport_size(640, 360);
        renderer.update_positions(&world);

        assert_eq!(renderer.debug_counters.last_total_nodes, 8);
        assert!(renderer.debug_counters.last_visible_nodes < 8);
        assert!(
            renderer.debug_counters.last_visible_edges < renderer.debug_counters.last_total_edges
        );
    }
}
