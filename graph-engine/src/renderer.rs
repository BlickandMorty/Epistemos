use std::ffi::c_void;

use glam::Vec2;
use metal::foreign_types::ForeignType;
use metal::*;
use objc::rc::autoreleasepool;

use crate::types::Graph;

// ── GPU data structs (must match Metal shader layouts) ──────────────────────

/// Per-instance data for node rendering. Matches shader's InstanceData.
#[repr(C)]
#[derive(Clone, Copy)]
struct NodeInstance {
    position: [f32; 2],
    radius: f32,
    color: [f32; 4],
}

/// Per-vertex data for edge quad-strip rendering. 6 vertices per edge.
#[repr(C)]
#[derive(Clone, Copy)]
struct EdgeQuadVertex {
    endpoint_a: [f32; 2],  // 8 bytes
    endpoint_b: [f32; 2],  // 8 bytes
    perp_sign: f32,        // 4 bytes: -1.0 or +1.0
    edge_coord: f32,       // 4 bytes: 0.0 at A, 1.0 at B
    color: [f32; 4],       // 16 bytes
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
    float2 position;
    float  radius;
    float4 color;
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

// ── Edge shaders (quad strips with SDF anti-aliasing) ─────────────────

struct EdgeQuadVertex {
    float2 endpoint_a;   // offset 0
    float2 endpoint_b;   // offset 8
    float  perp_sign;    // offset 16: -1.0 or +1.0
    float  edge_coord;   // offset 20: 0.0 at A, 1.0 at B
    float4 color;        // offset 24
};

struct EdgeVertexOut {
    float4 position [[position]];
    float4 color;
    float  edge_coord;   // For AA: -1 to +1 across line width
};

vertex EdgeVertexOut edge_vertex(
    uint vertex_id [[vertex_id]],
    constant EdgeQuadVertex* verts [[buffer(0)]],
    constant Uniforms& u [[buffer(1)]]
) {
    EdgeQuadVertex v = verts[vertex_id];

    // Transform both endpoints to clip space
    float2 a_screen = (v.endpoint_a - u.camera_offset) * u.camera_zoom;
    float2 b_screen = (v.endpoint_b - u.camera_offset) * u.camera_zoom;
    float2 a_ndc = a_screen / (u.viewport_size * 0.5) * float2(1, -1);
    float2 b_ndc = b_screen / (u.viewport_size * 0.5) * float2(1, -1);

    // Direction and perpendicular in NDC (clip-space expansion for zoom invariance)
    float2 dir = b_ndc - a_ndc;
    float len = length(dir);
    float2 norm_dir = len > 0.0001 ? dir / len : float2(0, 1);
    float2 perp = float2(-norm_dir.y, norm_dir.x);

    // Thickness in NDC: 1.5px equivalent
    float2 offset = perp * v.perp_sign * 1.5 / u.viewport_size;

    // Pick base position
    float2 base_ndc = mix(a_ndc, b_ndc, v.edge_coord);

    EdgeVertexOut out;
    out.position = float4(base_ndc + offset, 0.0, 1.0);
    out.color = v.color;
    out.edge_coord = v.perp_sign; // -1 to +1 across width
    return out;
}

fragment float4 edge_fragment(EdgeVertexOut in [[stage_in]]) {
    // SDF anti-aliasing: smooth falloff at edges
    float dist = abs(in.edge_coord);
    float aa_alpha = 1.0 - smoothstep(0.7, 1.0, dist);
    return float4(in.color.rgb, in.color.a * aa_alpha);
}
"#;

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Build 6 vertices (2 triangles) forming a quad strip for one edge.
fn build_edge_quad(a: [f32; 2], b: [f32; 2], color: [f32; 4]) -> [EdgeQuadVertex; 6] {
    [
        EdgeQuadVertex { endpoint_a: a, endpoint_b: b, perp_sign: -1.0, edge_coord: 0.0, color },
        EdgeQuadVertex { endpoint_a: a, endpoint_b: b, perp_sign:  1.0, edge_coord: 0.0, color },
        EdgeQuadVertex { endpoint_a: a, endpoint_b: b, perp_sign: -1.0, edge_coord: 1.0, color },
        EdgeQuadVertex { endpoint_a: a, endpoint_b: b, perp_sign: -1.0, edge_coord: 1.0, color },
        EdgeQuadVertex { endpoint_a: a, endpoint_b: b, perp_sign:  1.0, edge_coord: 0.0, color },
        EdgeQuadVertex { endpoint_a: a, endpoint_b: b, perp_sign:  1.0, edge_coord: 1.0, color },
    ]
}

// ── Renderer ────────────────────────────────────────────────────────────────

pub struct Renderer {
    device: Device,
    command_queue: CommandQueue,
    layer: MetalLayer,
    node_pipeline: RenderPipelineState,
    edge_pipeline: RenderPipelineState,
    // Buffers (recreated when graph size changes)
    node_instance_buf: Option<Buffer>,
    edge_quad_buf: Option<Buffer>,
    uniform_buf: Buffer,
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
        let device: Device = unsafe {
            let dev_ref: &DeviceRef = &*(device_ptr as *const DeviceRef);
            dev_ref.to_owned()
        };

        let layer: MetalLayer = unsafe {
            MetalLayer::from_ptr(layer_ptr as *mut _)
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
            edge_quad_buf: None,
            uniform_buf,
            camera_offset: Vec2::ZERO,
            camera_zoom: 1.0,
            node_count: 0,
            edge_vertex_count: 0,
        })
    }

    /// Upload graph data to GPU buffers.
    pub fn upload_graph(&mut self, graph: &Graph) {
        self.node_count = graph.nodes.len();
        if self.node_count == 0 {
            self.node_instance_buf = None;
            self.edge_quad_buf = None;
            self.edge_vertex_count = 0;
            return;
        }

        // ── Node instances ──────────────────────────────────────────────
        let mut instances: Vec<NodeInstance> = Vec::with_capacity(self.node_count);
        for node in &graph.nodes {
            instances.push(NodeInstance {
                position: [node.pos.x, node.pos.y],
                radius: node.radius,
                color: node.node_type.color(),
            });
        }

        let node_buf_size = (self.node_count * std::mem::size_of::<NodeInstance>()) as u64;
        let node_buf = self.device.new_buffer_with_data(
            instances.as_ptr() as *const c_void,
            node_buf_size,
            MTLResourceOptions::StorageModeShared,
        );
        self.node_instance_buf = Some(node_buf);

        // ── Edge quad-strip vertices (6 per edge) ───────────────────────
        let edge_count = graph.edges.len();
        if edge_count == 0 {
            self.edge_quad_buf = None;
            self.edge_vertex_count = 0;
            return;
        }

        let mut edge_verts: Vec<EdgeQuadVertex> = Vec::with_capacity(edge_count * 6);

        for edge in &graph.edges {
            let si = graph.id_to_index.get(&edge.source);
            let ti = graph.id_to_index.get(&edge.target);
            if let (Some(&si), Some(&ti)) = (si, ti) {
                let src = &graph.nodes[si];
                let tgt = &graph.nodes[ti];
                let a = [src.pos.x, src.pos.y];
                let b = [tgt.pos.x, tgt.pos.y];
                // Edge color: source node type color at 40% opacity
                let src_color = src.node_type.color();
                let color = [src_color[0], src_color[1], src_color[2], 0.4];
                let quad = build_edge_quad(a, b, color);
                edge_verts.extend_from_slice(&quad);
            }
        }

        self.edge_vertex_count = edge_verts.len();

        if self.edge_vertex_count > 0 {
            let buf_size = (self.edge_vertex_count * std::mem::size_of::<EdgeQuadVertex>()) as u64;
            self.edge_quad_buf = Some(self.device.new_buffer_with_data(
                edge_verts.as_ptr() as *const c_void,
                buf_size,
                MTLResourceOptions::StorageModeShared,
            ));
        }
    }

    /// Render one frame.
    pub fn draw(&mut self, viewport_width: u32, viewport_height: u32) {
        autoreleasepool(|| {
            let drawable = match self.layer.next_drawable() {
                Some(d) => d,
                None => return,
            };

            // Update uniforms
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
                if let Some(quad_buf) = &self.edge_quad_buf {
                    encoder.set_render_pipeline_state(&self.edge_pipeline);
                    encoder.set_vertex_buffer(0, Some(quad_buf), 0);
                    encoder.set_vertex_buffer(1, Some(&self.uniform_buf), 0);
                    encoder.draw_primitives(
                        MTLPrimitiveType::Triangle,
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
