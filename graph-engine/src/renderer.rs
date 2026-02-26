use std::ffi::c_void;

use glam::Vec2;
use metal::foreign_types::ForeignType;
use metal::*;
use objc::rc::autoreleasepool;

use crate::types::Graph;

// Direct Objective-C runtime call — avoids macro import issues with Rust 2024 edition.
unsafe extern "C" {
    fn objc_retain(obj: *mut c_void) -> *mut c_void;
}

// ── GPU data structs (must match Metal shader layouts) ──────────────────────

/// Per-instance data for node rendering. Matches shader's NodeInstance.
/// Note: MSL float4 requires 16-byte alignment, so _pad is needed between
/// radius (offset 8, 4 bytes) and color (must start at offset 16).
#[repr(C)]
#[derive(Clone, Copy)]
struct NodeInstance {
    position: [f32; 2], // offset 0, 8 bytes
    radius: f32,        // offset 8, 4 bytes
    _pad: f32,          // offset 12, 4 bytes (aligns color to 16)
    color: [f32; 4],    // offset 16, 16 bytes
}

/// Per-instance data for curved Bézier edge rendering.
/// The vertex shader builds a bounding quad from the 3 control points,
/// and the fragment shader computes the SDF distance to the quadratic
/// Bézier curve for anti-aliased stroke rendering.
/// NOTE: `_pad` aligns `color` to offset 32 so it matches MSL `float4` alignment (16 bytes).
#[repr(C)]
#[derive(Clone, Copy)]
struct BezierEdgeInstance {
    p0: [f32; 2],     // Source position   (offset 0, 8 bytes)
    p1: [f32; 2],     // Control point     (offset 8, 8 bytes)
    p2: [f32; 2],     // Target position   (offset 16, 8 bytes)
    _pad: [f32; 2],   // Padding           (offset 24, 8 bytes)
    color: [f32; 4],  // Edge color        (offset 32, 16-byte aligned)
}

/// Uniform data sent to all shaders (camera transform).
#[repr(C)]
#[derive(Clone, Copy)]
struct Uniforms {
    viewport_size: [f32; 2],
    camera_offset: [f32; 2],
    camera_zoom: f32,
    _padding: f32,
}

// ── Metal Shader Source ─────────────────────────────────────────────────────

const SHADER_SOURCE: &str = r#"
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float2 viewport_size;
    float2 camera_offset;
    float camera_zoom;
    float _padding;
};

// ── Node shaders (instanced circles) ────────────────────────────────────

struct NodeInstance {
    float2 position;  // offset 0
    float  radius;    // offset 8
    float  _pad;      // offset 12 (explicit padding for float4 alignment)
    float4 color;     // offset 16
};

struct NodeVertexOut {
    float4 position [[position]];
    float4 color;
    float2 uv;  // For circle SDF
};

vertex NodeVertexOut node_vertex(
    uint vertex_id [[vertex_id]],
    uint instance_id [[instance_id]],
    constant NodeInstance* instances [[buffer(0)]],
    constant Uniforms& uniforms [[buffer(1)]]
) {
    // Quad vertices: 6 vertices for 2 triangles
    float2 corners[6] = {
        float2(-1, -1), float2( 1, -1), float2(-1,  1),
        float2(-1,  1), float2( 1, -1), float2( 1,  1)
    };

    NodeInstance inst = instances[instance_id];
    float2 corner = corners[vertex_id];
    float2 world_pos = inst.position + corner * inst.radius;

    // Apply camera transform: (world - offset) * zoom, then to NDC
    float2 screen = (world_pos - uniforms.camera_offset) * uniforms.camera_zoom;
    float2 ndc = screen / (uniforms.viewport_size * 0.5) * float2(1, -1);

    NodeVertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.color = inst.color;
    out.uv = corner;
    return out;
}

fragment float4 node_fragment(NodeVertexOut in [[stage_in]]) {
    float dist = length(in.uv);
    // Smooth circle with anti-aliased edge
    float alpha = 1.0 - smoothstep(0.85, 1.0, dist);
    if (alpha < 0.01) discard_fragment();
    return float4(in.color.rgb, in.color.a * alpha);
}

// ── Curved edge shaders (quadratic Bézier SDF) ─────────────────────

struct BezierEdgeInstance {
    float2 p0;       // Source position   (offset 0)
    float2 p1;       // Control point     (offset 8)
    float2 p2;       // Target position   (offset 16)
    float2 _pad;     // Padding           (offset 24)
    float4 color;    // Edge color        (offset 32)
};

struct BezierVertexOut {
    float4 position [[position]];
    float2 world_pos;
    float2 p0 [[flat]];
    float2 p1 [[flat]];
    float2 p2 [[flat]];
    float4 color [[flat]];
};

vertex BezierVertexOut bezier_edge_vertex(
    uint vertex_id [[vertex_id]],
    uint instance_id [[instance_id]],
    constant BezierEdgeInstance* instances [[buffer(0)]],
    constant Uniforms& u [[buffer(1)]]
) {
    BezierEdgeInstance inst = instances[instance_id];

    // Bounding box of the 3 control points + padding for stroke and AA
    float pad = 3.0 / u.camera_zoom;
    float2 bb_min = min(min(inst.p0, inst.p1), inst.p2) - pad;
    float2 bb_max = max(max(inst.p0, inst.p1), inst.p2) + pad;

    float2 corners[6] = {
        float2(bb_min.x, bb_min.y), float2(bb_max.x, bb_min.y), float2(bb_min.x, bb_max.y),
        float2(bb_min.x, bb_max.y), float2(bb_max.x, bb_min.y), float2(bb_max.x, bb_max.y)
    };

    float2 world_pos = corners[vertex_id];
    float2 screen = (world_pos - u.camera_offset) * u.camera_zoom;
    float2 ndc = screen / (u.viewport_size * 0.5) * float2(1, -1);

    BezierVertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.world_pos = world_pos;
    out.p0 = inst.p0;
    out.p1 = inst.p1;
    out.p2 = inst.p2;
    out.color = inst.color;
    return out;
}

// Signed distance to quadratic Bézier curve (Inigo Quilez)
float dot2_v(float2 v) { return dot(v, v); }

float sdBezier(float2 pos, float2 A, float2 B, float2 C) {
    float2 a = B - A;
    float2 b = A - 2.0*B + C;
    float2 c = a * 2.0;
    float2 d = A - pos;

    // Degenerate: nearly straight line (avoids division by zero)
    float bb = dot(b, b);
    if (bb < 0.0001) {
        float2 ab = C - A;
        float t = clamp(dot(pos - A, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
        return length(pos - A - ab * t);
    }

    float kk = 1.0 / bb;
    float kx = kk * dot(a, b);
    float ky = kk * (2.0 * dot(a, a) + dot(d, b)) / 3.0;
    float kz = kk * dot(d, a);

    float p = ky - kx * kx;
    float q = kx * (2.0 * kx * kx - 3.0 * ky) + kz;
    float p3 = p * p * p;
    float h = q * q + 4.0 * p3;

    float res;
    if (h >= 0.0) {
        h = sqrt(h);
        float2 x = (float2(h, -h) - q) / 2.0;
        float2 uv = sign(x) * pow(abs(x), float2(1.0/3.0));
        float t = clamp(uv.x + uv.y - kx, 0.0, 1.0);
        float2 qp = d + (c + b * t) * t;
        res = dot2_v(qp);
    } else {
        float z = sqrt(-p);
        float v = acos(clamp(q / (p * z * 2.0), -1.0, 1.0)) / 3.0;
        float m = cos(v);
        float n = sin(v) * 1.732050808;
        float3 t3 = clamp(float3(m + m, -n - m, n - m) * z - kx, 0.0, 1.0);
        float2 q1 = d + (c + b * t3.x) * t3.x;
        float2 q2 = d + (c + b * t3.y) * t3.y;
        res = min(dot2_v(q1), dot2_v(q2));
    }
    return sqrt(res);
}

fragment float4 bezier_edge_fragment(
    BezierVertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(1)]]
) {
    float dist = sdBezier(in.world_pos, in.p0, in.p1, in.p2);

    // Zoom-invariant stroke: 1.5px half-width in screen pixels
    float half_width = 1.5 / u.camera_zoom;
    float aa = fwidth(dist);
    float alpha = 1.0 - smoothstep(half_width - aa, half_width + aa, dist);

    if (alpha < 0.01) discard_fragment();
    return float4(in.color.rgb, in.color.a * alpha);
}
"#;

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Compute a quadratic Bézier control point for a curved edge.
/// The control point is offset perpendicular to the midpoint of the edge,
/// creating a gentle arc proportional to edge length (12% offset).
fn bezier_control_point(a: [f32; 2], b: [f32; 2]) -> [f32; 2] {
    let mid_x = (a[0] + b[0]) * 0.5;
    let mid_y = (a[1] + b[1]) * 0.5;
    let dx = b[0] - a[0];
    let dy = b[1] - a[1];
    let len = (dx * dx + dy * dy).sqrt();
    if len < 0.001 {
        return [mid_x, mid_y];
    }
    // Perpendicular: rotate direction 90° CCW, normalize, scale by 12% of length
    let perp_x = -dy / len;
    let perp_y = dx / len;
    let offset = len * 0.12;
    [mid_x + perp_x * offset, mid_y + perp_y * offset]
}

// ── Renderer ────────────────────────────────────────────────────────────────

pub struct Renderer {
    device: Device,
    command_queue: CommandQueue,
    layer: MetalLayer,
    node_pipeline: RenderPipelineState,
    edge_pipeline: RenderPipelineState,
    // Buffers (pre-allocated with headroom, reused across frames)
    node_instance_buf: Option<Buffer>,
    edge_instance_buf: Option<Buffer>,
    uniform_buf: Buffer,
    // Capacity tracking — buffers are only re-allocated when count exceeds capacity
    node_instance_capacity: usize,
    edge_instance_capacity: usize, // BezierEdgeInstance count (1 per edge)
    // Camera state
    pub camera_offset: Vec2,
    pub camera_zoom: f32,
    // Camera animation (frame-rate independent)
    pub target_offset: Vec2,
    pub target_zoom: f32,
    pub is_animating: bool,
    last_frame_time: std::time::Instant,
    // Cached counts
    node_count: usize,
    edge_instance_count: usize,
    highlight_count: usize,
}

impl Renderer {
    pub fn new(device_ptr: *mut c_void, layer_ptr: *mut c_void) -> Option<Self> {
        if device_ptr.is_null() || layer_ptr.is_null() {
            return None;
        }

        // Safety: pointers come from Swift's Unmanaged.passUnretained — we borrow, not own.
        // Device: borrow the reference and call to_owned() which bumps the retain count.
        let device: Device = unsafe {
            let dev_ref: &DeviceRef = &*(device_ptr as *const DeviceRef);
            dev_ref.to_owned()
        };

        // Layer: from_ptr takes ownership, so we must retain to balance Swift's ARC.
        // Without this, Rust's Drop would over-release the layer (double-free).
        let layer: MetalLayer = unsafe {
            let l = MetalLayer::from_ptr(layer_ptr as *mut _);
            objc_retain(layer_ptr);
            l
        };

        layer.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
        layer.set_device(&device);

        let command_queue = device.new_command_queue();

        // Compile shaders
        let library = device
            .new_library_with_source(SHADER_SOURCE, &CompileOptions::new())
            .expect("Failed to compile Metal shaders");

        let node_vert = library.get_function("node_vertex", None).unwrap();
        let node_frag = library.get_function("node_fragment", None).unwrap();
        let edge_vert = library.get_function("bezier_edge_vertex", None).unwrap();
        let edge_frag = library.get_function("bezier_edge_fragment", None).unwrap();

        // Node pipeline (with alpha blending for smooth circles)
        let node_desc = RenderPipelineDescriptor::new();
        node_desc.set_vertex_function(Some(&node_vert));
        node_desc.set_fragment_function(Some(&node_frag));
        let color_attach = node_desc.color_attachments().object_at(0).unwrap();
        color_attach.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
        color_attach.set_blending_enabled(true);
        color_attach.set_source_rgb_blend_factor(MTLBlendFactor::SourceAlpha);
        color_attach.set_destination_rgb_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
        color_attach.set_source_alpha_blend_factor(MTLBlendFactor::One);
        color_attach.set_destination_alpha_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);

        let node_pipeline = device
            .new_render_pipeline_state(&node_desc)
            .expect("Failed to create node pipeline");

        // Edge pipeline (also with alpha blending)
        let edge_desc = RenderPipelineDescriptor::new();
        edge_desc.set_vertex_function(Some(&edge_vert));
        edge_desc.set_fragment_function(Some(&edge_frag));
        let edge_color_attach = edge_desc.color_attachments().object_at(0).unwrap();
        edge_color_attach.set_pixel_format(MTLPixelFormat::BGRA8Unorm);
        edge_color_attach.set_blending_enabled(true);
        edge_color_attach.set_source_rgb_blend_factor(MTLBlendFactor::SourceAlpha);
        edge_color_attach.set_destination_rgb_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);
        edge_color_attach.set_source_alpha_blend_factor(MTLBlendFactor::One);
        edge_color_attach.set_destination_alpha_blend_factor(MTLBlendFactor::OneMinusSourceAlpha);

        let edge_pipeline = device
            .new_render_pipeline_state(&edge_desc)
            .expect("Failed to create edge pipeline");

        // Uniform buffer (small, persistent)
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
            camera_offset: Vec2::ZERO,
            camera_zoom: 1.0,
            target_offset: Vec2::ZERO,
            target_zoom: 1.0,
            is_animating: false,
            last_frame_time: std::time::Instant::now(),
            node_count: 0,
            edge_instance_count: 0,
            highlight_count: 0,
        })
    }

    /// Upload graph data to GPU buffers. Skips invisible nodes and edges
    /// where either endpoint is invisible.
    pub fn upload_graph(&mut self, graph: &Graph) {
        // ── Node instances (visible only) ───────────────────────────────
        let mut instances: Vec<NodeInstance> = Vec::with_capacity(graph.nodes.len());
        for node in &graph.nodes {
            if !node.visible { continue; }
            instances.push(NodeInstance {
                position: [node.pos.x, node.pos.y],
                radius: node.radius,
                _pad: 0.0,
                color: node.node_type.color(),
            });
        }

        self.node_count = instances.len();
        if self.node_count == 0 {
            self.node_instance_buf = None;
            self.edge_instance_buf = None;
            self.edge_instance_count = 0;
            return;
        }

        let node_buf_size = (self.node_count * std::mem::size_of::<NodeInstance>()) as u64;
        let node_buf = self.device.new_buffer_with_data(
            instances.as_ptr() as *const c_void,
            node_buf_size,
            MTLResourceOptions::StorageModeShared,
        );
        self.node_instance_buf = Some(node_buf);

        // ── Bézier edge instances (1 per edge, visible only) ────────────
        let mut edge_instances: Vec<BezierEdgeInstance> = Vec::with_capacity(graph.edges.len());

        for edge in &graph.edges {
            let si = graph.id_to_index.get(&edge.source);
            let ti = graph.id_to_index.get(&edge.target);
            if let (Some(&si), Some(&ti)) = (si, ti) {
                let src = &graph.nodes[si];
                let tgt = &graph.nodes[ti];
                if !src.visible || !tgt.visible { continue; }
                let a = [src.pos.x, src.pos.y];
                let b = [tgt.pos.x, tgt.pos.y];
                let ctrl = bezier_control_point(a, b);
                let src_color = src.node_type.color();
                let color = [src_color[0], src_color[1], src_color[2], 0.4];
                edge_instances.push(BezierEdgeInstance {
                    p0: a,
                    p1: ctrl,
                    p2: b,
                    _pad: [0.0; 2],
                    color,
                });
            }
        }

        self.edge_instance_count = edge_instances.len();

        if self.edge_instance_count > 0 {
            let buf_size = (self.edge_instance_count * std::mem::size_of::<BezierEdgeInstance>()) as u64;
            self.edge_instance_buf = Some(self.device.new_buffer_with_data(
                edge_instances.as_ptr() as *const c_void,
                buf_size,
                MTLResourceOptions::StorageModeShared,
            ));
        } else {
            self.edge_instance_buf = None;
        }
    }

    /// Pre-allocate GPU buffers with 50% headroom, then perform an initial data upload.
    /// Only re-allocates if the graph has grown beyond current capacity (or buffers are None).
    /// Call this once after commit (graph topology change), NOT every frame.
    pub fn allocate_buffers(&mut self, graph: &Graph) {
        let node_count = graph.nodes.len() + 2; // +2 for potential selected/hovered highlights
        let edge_count = graph.edges.len(); // 1 instance per edge (Bézier SDF)

        // ── Node instance buffer ─────────────────────────────────────────
        if node_count > self.node_instance_capacity || self.node_instance_buf.is_none() {
            let capacity = (node_count * 3 / 2).max(64);
            let buf_size = (capacity * std::mem::size_of::<NodeInstance>()) as u64;
            self.node_instance_buf = Some(
                self.device
                    .new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.node_instance_capacity = capacity;
        }

        // ── Edge instance buffer (1 BezierEdgeInstance per edge) ─────────
        if edge_count > self.edge_instance_capacity || self.edge_instance_buf.is_none() {
            let capacity = (edge_count * 3 / 2).max(64);
            let buf_size = (capacity * std::mem::size_of::<BezierEdgeInstance>()) as u64;
            self.edge_instance_buf = Some(
                self.device
                    .new_buffer(buf_size, MTLResourceOptions::StorageModeShared),
            );
            self.edge_instance_capacity = capacity;
        }

        // Perform initial full data write into the freshly-allocated buffers
        self.upload_graph(graph);
    }

    /// Write ONLY position data into existing pre-allocated buffers via pointer writes.
    /// Does NOT create new buffers. Call this every frame after sync_positions().
    /// Skips invisible nodes and edges where either endpoint is invisible.
    pub fn update_positions(&mut self, graph: &Graph) {
        // ── Update node positions in-place (visible only) ────────────────
        let mut visible_count = 0usize;
        if let Some(buf) = &self.node_instance_buf {
            unsafe {
                let ptr = buf.contents() as *mut NodeInstance;
                for node in &graph.nodes {
                    if !node.visible { continue; }
                    let inst = &mut *ptr.add(visible_count);
                    inst.position = [node.pos.x, node.pos.y];
                    visible_count += 1;
                }
            }
        }
        self.node_count = visible_count;

        if self.node_count == 0 {
            self.edge_instance_count = 0;
            return;
        }

        // ── Update Bézier edge instances in-place (visible only) ─────────
        if let Some(buf) = &self.edge_instance_buf {
            let mut inst_idx = 0usize;
            unsafe {
                let ptr = buf.contents() as *mut BezierEdgeInstance;
                for edge in &graph.edges {
                    let si = graph.id_to_index.get(&edge.source);
                    let ti = graph.id_to_index.get(&edge.target);
                    if let (Some(&si), Some(&ti)) = (si, ti) {
                        let src = &graph.nodes[si];
                        let tgt = &graph.nodes[ti];
                        if !src.visible || !tgt.visible { continue; }
                        let a = [src.pos.x, src.pos.y];
                        let b = [tgt.pos.x, tgt.pos.y];
                        let ctrl = bezier_control_point(a, b);
                        let src_color = src.node_type.color();
                        let color = [src_color[0], src_color[1], src_color[2], 0.4];
                        let inst = &mut *ptr.add(inst_idx);
                        inst.p0 = a;
                        inst.p1 = ctrl;
                        inst.p2 = b;
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

    /// Append highlight ring instances after the regular nodes.
    /// These use the same circle SDF shader but with larger radius and different alpha.
    pub fn set_highlights(&mut self, selected: Option<u32>, hovered: Option<u32>, graph: &Graph) {
        let Some(buf) = &self.node_instance_buf else { return };
        let ptr = buf.contents() as *mut NodeInstance;
        let mut idx = self.node_count;

        // Selected ring: node-type color, +4px radius, 40% alpha
        if let Some(sel_id) = selected {
            if let Some(node) = graph.nodes.iter().find(|n| n.id == sel_id && n.visible) {
                let color = node.node_type.color();
                unsafe {
                    *ptr.add(idx) = NodeInstance {
                        position: [node.pos.x, node.pos.y],
                        radius: node.radius + 4.0,
                        _pad: 0.0,
                        color: [color[0], color[1], color[2], 0.4],
                    };
                }
                idx += 1;
            }
        }

        // Hovered ring: white glow, +2px radius, 20% alpha (only if different from selected)
        if let Some(hov_id) = hovered {
            if Some(hov_id) != selected {
                if let Some(node) = graph.nodes.iter().find(|n| n.id == hov_id && n.visible) {
                    unsafe {
                        *ptr.add(idx) = NodeInstance {
                            position: [node.pos.x, node.pos.y],
                            radius: node.radius + 2.0,
                            _pad: 0.0,
                            color: [1.0, 1.0, 1.0, 0.2],
                        };
                    }
                    idx += 1;
                }
            }
        }

        self.highlight_count = idx - self.node_count;
    }

    const CAMERA_LAMBDA: f32 = 8.0;

    /// Smooth the camera toward its target using exponential damping.
    /// Formula: t = 1 - exp(-lambda * dt). Gives identical results at 60Hz and 120Hz.
    pub fn update_camera(&mut self) {
        let now = std::time::Instant::now();
        let dt = (now - self.last_frame_time).as_secs_f32().min(0.1);
        self.last_frame_time = now;

        if !self.is_animating { return; }

        let t = 1.0 - (-Self::CAMERA_LAMBDA * dt).exp();

        self.camera_offset = self.camera_offset.lerp(self.target_offset, t);
        self.camera_zoom = self.camera_zoom + (self.target_zoom - self.camera_zoom) * t;

        let offset_diff = (self.target_offset - self.camera_offset).length();
        let zoom_diff = (self.target_zoom - self.camera_zoom).abs();
        if offset_diff < 0.1 && zoom_diff < 0.001 {
            self.camera_offset = self.target_offset;
            self.camera_zoom = self.target_zoom;
            self.is_animating = false;
        }
    }

    /// Render one frame. Camera must be updated via update_camera() before calling draw().
    pub fn draw(&mut self, viewport_width: u32, viewport_height: u32) {
        autoreleasepool(|| {
            // Camera already advanced in Engine::render() before fire_labels_updated(),
            // ensuring labels and Metal rendering share the same camera state.

            let drawable = match self.layer.next_drawable() {
                Some(d) => d,
                None => return,
            };

            // Update uniforms.
            // Note: Writing to a StorageModeShared buffer while the GPU may still be reading
            // the previous frame is technically a data race. On Apple Silicon unified memory
            // this is safe in practice for small writes (24 bytes), but for correctness under
            // Metal validation, production code should use triple-buffered uniforms with a
            // dispatch semaphore. TODO: upgrade to triple-buffering for Metal validation compliance.
            let uniforms = Uniforms {
                viewport_size: [viewport_width as f32, viewport_height as f32],
                camera_offset: [self.camera_offset.x, self.camera_offset.y],
                camera_zoom: self.camera_zoom,
                _padding: 0.0,
            };
            unsafe {
                let ptr = self.uniform_buf.contents() as *mut Uniforms;
                *ptr = uniforms;
            }

            let render_desc = RenderPassDescriptor::new();
            let color = render_desc.color_attachments().object_at(0).unwrap();
            color.set_texture(Some(drawable.texture()));
            color.set_load_action(MTLLoadAction::Clear);
            color.set_clear_color(MTLClearColor::new(0.07, 0.07, 0.09, 1.0));
            color.set_store_action(MTLStoreAction::Store);

            let cmd_buf = self.command_queue.new_command_buffer();
            let encoder = cmd_buf.new_render_command_encoder(render_desc);

            // ── Draw curved edges first (behind nodes) ─────────────────
            if self.edge_instance_count > 0 {
                if let Some(inst_buf) = &self.edge_instance_buf {
                    encoder.set_render_pipeline_state(&self.edge_pipeline);
                    encoder.set_vertex_buffer(0, Some(inst_buf), 0);
                    encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                    encoder.set_fragment_buffer(1, Some(&self.uniform_buf), 0);
                    encoder.draw_primitives_instanced(
                        MTLPrimitiveType::Triangle,
                        0,
                        6, // 6 vertices per bounding quad
                        self.edge_instance_count as u64,
                    );
                }
            }

            // ── Draw nodes + highlight rings (instanced quads with circle SDF) ──
            let total_instances = self.node_count + self.highlight_count;
            if total_instances > 0 {
                if let Some(inst_buf) = &self.node_instance_buf {
                    encoder.set_render_pipeline_state(&self.node_pipeline);
                    encoder.set_vertex_buffer(0, Some(inst_buf), 0);
                    encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                    encoder.draw_primitives_instanced(
                        MTLPrimitiveType::Triangle,
                        0,
                        6,                              // 6 vertices per quad
                        total_instances as u64,         // Nodes + highlight rings
                    );
                }
            }

            encoder.end_encoding();
            cmd_buf.present_drawable(drawable);
            cmd_buf.commit();
        });
    }
}
