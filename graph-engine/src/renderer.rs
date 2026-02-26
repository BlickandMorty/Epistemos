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

/// Per-instance data for edge rendering. Matches shader's EdgeInstance.
#[repr(C)]
#[derive(Clone, Copy)]
struct EdgeVertex {
    position: [f32; 2],
    color: [f32; 4],
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

// ── Edge shaders (line segments) ────────────────────────────────────────

struct EdgeVertexOut {
    float4 position [[position]];
    float4 color;
};

vertex EdgeVertexOut edge_vertex(
    uint vertex_id [[vertex_id]],
    constant float2* positions [[buffer(0)]],
    constant float4* colors [[buffer(1)]],
    constant Uniforms& uniforms [[buffer(2)]]
) {
    float2 world_pos = positions[vertex_id];
    float2 screen = (world_pos - uniforms.camera_offset) * uniforms.camera_zoom;
    float2 ndc = screen / (uniforms.viewport_size * 0.5) * float2(1, -1);

    EdgeVertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.color = colors[vertex_id];
    return out;
}

fragment float4 edge_fragment(EdgeVertexOut in [[stage_in]]) {
    return in.color;
}
"#;

// ── Renderer ────────────────────────────────────────────────────────────────

pub struct Renderer {
    device: Device,
    command_queue: CommandQueue,
    layer: MetalLayer,
    node_pipeline: RenderPipelineState,
    edge_pipeline: RenderPipelineState,
    // Buffers (pre-allocated with headroom, reused across frames)
    node_instance_buf: Option<Buffer>,
    edge_position_buf: Option<Buffer>,
    edge_color_buf: Option<Buffer>,
    uniform_buf: Buffer,
    // Capacity tracking — buffers are only re-allocated when count exceeds capacity
    node_instance_capacity: usize,
    edge_capacity: usize,
    // Camera state
    pub camera_offset: Vec2,
    pub camera_zoom: f32,
    // Cached counts
    node_count: usize,
    edge_vertex_count: usize,
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
        let edge_vert = library.get_function("edge_vertex", None).unwrap();
        let edge_frag = library.get_function("edge_fragment", None).unwrap();

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
            edge_position_buf: None,
            edge_color_buf: None,
            uniform_buf,
            node_instance_capacity: 0,
            edge_capacity: 0,
            camera_offset: Vec2::ZERO,
            camera_zoom: 1.0,
            node_count: 0,
            edge_vertex_count: 0,
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
            self.edge_position_buf = None;
            self.edge_color_buf = None;
            self.edge_vertex_count = 0;
            return;
        }

        let node_buf_size = (self.node_count * std::mem::size_of::<NodeInstance>()) as u64;
        let node_buf = self.device.new_buffer_with_data(
            instances.as_ptr() as *const c_void,
            node_buf_size,
            MTLResourceOptions::StorageModeShared,
        );
        self.node_instance_buf = Some(node_buf);

        // ── Edge vertices (2 per edge for line segments, visible only) ──
        let mut edge_positions: Vec<[f32; 2]> = Vec::with_capacity(graph.edges.len() * 2);
        let mut edge_colors: Vec<[f32; 4]> = Vec::with_capacity(graph.edges.len() * 2);

        let edge_color: [f32; 4] = [0.35, 0.35, 0.40, 0.5]; // Subtle gray

        for edge in &graph.edges {
            let si = graph.id_to_index.get(&edge.source);
            let ti = graph.id_to_index.get(&edge.target);
            if let (Some(&si), Some(&ti)) = (si, ti) {
                let src = &graph.nodes[si];
                let tgt = &graph.nodes[ti];
                if !src.visible || !tgt.visible { continue; }
                edge_positions.push([src.pos.x, src.pos.y]);
                edge_positions.push([tgt.pos.x, tgt.pos.y]);
                edge_colors.push(edge_color);
                edge_colors.push(edge_color);
            }
        }

        self.edge_vertex_count = edge_positions.len();

        if self.edge_vertex_count > 0 {
            let pos_size = (self.edge_vertex_count * std::mem::size_of::<[f32; 2]>()) as u64;
            let col_size = (self.edge_vertex_count * std::mem::size_of::<[f32; 4]>()) as u64;

            self.edge_position_buf = Some(self.device.new_buffer_with_data(
                edge_positions.as_ptr() as *const c_void,
                pos_size,
                MTLResourceOptions::StorageModeShared,
            ));
            self.edge_color_buf = Some(self.device.new_buffer_with_data(
                edge_colors.as_ptr() as *const c_void,
                col_size,
                MTLResourceOptions::StorageModeShared,
            ));
        } else {
            self.edge_position_buf = None;
            self.edge_color_buf = None;
        }
    }

    /// Pre-allocate GPU buffers with 50% headroom, then perform an initial data upload.
    /// Only re-allocates if the graph has grown beyond current capacity (or buffers are None).
    /// Call this once after commit (graph topology change), NOT every frame.
    pub fn allocate_buffers(&mut self, graph: &Graph) {
        let node_count = graph.nodes.len();
        let edge_vertex_count = graph.edges.len() * 2; // 2 vertices per edge (line segment)

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

        // ── Edge buffers (positions + colors) ────────────────────────────
        if edge_vertex_count > self.edge_capacity || self.edge_position_buf.is_none() {
            let capacity = (edge_vertex_count * 3 / 2).max(64);
            let pos_size = (capacity * std::mem::size_of::<[f32; 2]>()) as u64;
            let col_size = (capacity * std::mem::size_of::<[f32; 4]>()) as u64;
            self.edge_position_buf = Some(
                self.device
                    .new_buffer(pos_size, MTLResourceOptions::StorageModeShared),
            );
            self.edge_color_buf = Some(
                self.device
                    .new_buffer(col_size, MTLResourceOptions::StorageModeShared),
            );
            self.edge_capacity = capacity;
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
            self.edge_vertex_count = 0;
            return;
        }

        // ── Update edge positions in-place (colors are static, visible only)
        if let Some(buf) = &self.edge_position_buf {
            let mut vertex_idx = 0usize;
            unsafe {
                let ptr = buf.contents() as *mut [f32; 2];
                for edge in &graph.edges {
                    let si = graph.id_to_index.get(&edge.source);
                    let ti = graph.id_to_index.get(&edge.target);
                    if let (Some(&si), Some(&ti)) = (si, ti) {
                        let src = &graph.nodes[si];
                        let tgt = &graph.nodes[ti];
                        if !src.visible || !tgt.visible { continue; }
                        *ptr.add(vertex_idx) = [src.pos.x, src.pos.y];
                        *ptr.add(vertex_idx + 1) = [tgt.pos.x, tgt.pos.y];
                        vertex_idx += 2;
                    }
                }
            }
            self.edge_vertex_count = vertex_idx;
        } else {
            self.edge_vertex_count = 0;
        }
    }

    /// Render one frame.
    pub fn draw(&mut self, viewport_width: u32, viewport_height: u32) {
        autoreleasepool(|| {
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

            // ── Draw edges first (behind nodes) ─────────────────────────
            if self.edge_vertex_count > 0 {
                if let (Some(pos_buf), Some(col_buf)) =
                    (&self.edge_position_buf, &self.edge_color_buf)
                {
                    encoder.set_render_pipeline_state(&self.edge_pipeline);
                    encoder.set_vertex_buffer(0, Some(pos_buf), 0);
                    encoder.set_vertex_buffer(1, Some(col_buf), 0);
                    encoder.set_vertex_buffer(2, Some(&self.uniform_buf), 0);
                    encoder.draw_primitives(
                        MTLPrimitiveType::Line,
                        0,
                        self.edge_vertex_count as u64,
                    );
                }
            }

            // ── Draw nodes (instanced quads with circle SDF) ────────────
            if self.node_count > 0 {
                if let Some(inst_buf) = &self.node_instance_buf {
                    encoder.set_render_pipeline_state(&self.node_pipeline);
                    encoder.set_vertex_buffer(0, Some(inst_buf), 0);
                    encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                    encoder.draw_primitives_instanced(
                        MTLPrimitiveType::Triangle,
                        0,
                        6,                          // 6 vertices per quad
                        self.node_count as u64,     // One instance per node
                    );
                }
            }

            encoder.end_encoding();
            cmd_buf.present_drawable(drawable);
            cmd_buf.commit();
        });
    }
}
