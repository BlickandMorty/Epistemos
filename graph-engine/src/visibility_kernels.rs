//! Phase B Week 7-8 compute-kernel reference: frustum culling +
//! visibility compaction.
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Phase B —
//! Metal compute (8 weeks)" → §"Week 7-8: Visibility compaction +
//! indirect draw". The plan calls for:
//!
//!   compact_visible.metal      — frustum cull, output visible-node + edge ID lists
//!   build_indirect_args.metal  — write MTLDrawPrimitivesIndirectArguments to a private buffer
//!
//! Plus the switch to `drawPrimitivesIndirect` on the render encoder.
//! The CPU reference here ships the *culling and compaction* halves;
//! the `MTLDrawPrimitivesIndirectArguments` writer is a fixed-shape
//! struct fill that the upcoming MSL kernel emits once + done.
//!
//! ## Pure-data contract
//!
//! Inputs are positions, edges, a `Frustum2D`. Outputs are compacted
//! index lists (visible nodes / visible edges) and a draw-arg record
//! that maps 1:1 onto `MTLDrawPrimitivesIndirectArguments`. No engine
//! dependencies; integrator reads outputs once per frame.
//!
//! ## Determinism contract
//!
//! Same inputs → bit-identical compaction output. Tested via
//! `frustum_cull_is_deterministic`.

/// Axis-aligned bounding box used as the camera frustum in 2D space.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Frustum2D {
    pub min_x: f32,
    pub min_y: f32,
    pub max_x: f32,
    pub max_y: f32,
}

impl Frustum2D {
    pub fn from_centre_and_half(centre_x: f32, centre_y: f32, half_w: f32, half_h: f32) -> Self {
        Self {
            min_x: centre_x - half_w,
            min_y: centre_y - half_h,
            max_x: centre_x + half_w,
            max_y: centre_y + half_h,
        }
    }

    /// Does the point + radius circle intersect this frustum?
    pub fn intersects_circle(&self, x: f32, y: f32, radius: f32) -> bool {
        // Distance from point to AABB on each axis, clamped to zero
        // when inside that axis. If the squared distance is within r²,
        // the circle clips the box.
        let dx = if x < self.min_x { self.min_x - x }
                 else if x > self.max_x { x - self.max_x }
                 else { 0.0 };
        let dy = if y < self.min_y { self.min_y - y }
                 else if y > self.max_y { y - self.max_y }
                 else { 0.0 };
        dx * dx + dy * dy <= radius * radius
    }
}

/// Mirror of `MTLDrawPrimitivesIndirectArguments`. Same field order so
/// `compute_indirect_args` can be a straight memcpy when the kernel
/// lands.
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DrawIndirectArgs {
    pub vertex_count: u32,
    pub instance_count: u32,
    pub vertex_start: u32,
    pub base_instance: u32,
}

/// Kernel 1: frustum-cull each node and emit a compact `Vec<u32>` of
/// visible node ids (sorted by original index for determinism).
///
/// `node_radii` is per-node visual radius — used by `intersects_circle`
/// to keep nodes that straddle the frustum boundary visible. Each
/// node's RENDERABLE flag must already be set for it to be considered.
///
/// Mirror of compact_visible.metal's node pass.
pub fn frustum_cull_nodes(
    pos_x: &[f32],
    pos_y: &[f32],
    node_radii: &[f32],
    flags: &[u32],
    frustum: &Frustum2D,
) -> Vec<u32> {
    let n = pos_x.len().min(pos_y.len()).min(node_radii.len()).min(flags.len());
    let mut visible: Vec<u32> = Vec::with_capacity(n / 4);
    for i in 0..n {
        // FLAG_RENDERABLE = 1 << 0
        if flags[i] & 1 == 0 { continue; }
        if frustum.intersects_circle(pos_x[i], pos_y[i], node_radii[i]) {
            visible.push(i as u32);
        }
    }
    visible
}

/// Kernel 2: visibility compaction for edges. Returns indices into the
/// edge array for edges where *either* endpoint is visible (per the
/// canonical plan — edges connecting offscreen to onscreen still need
/// to be drawn).
///
/// `visible_node_set` is the BTreeSet of visible node ids (from
/// `frustum_cull_nodes`); the caller pre-builds it once per frame.
pub fn frustum_cull_edges(
    edges: &[(u32, u32)],
    visible_node_set: &std::collections::BTreeSet<u32>,
) -> Vec<u32> {
    let mut out: Vec<u32> = Vec::with_capacity(edges.len() / 4);
    for (ei, &(s, t)) in edges.iter().enumerate() {
        if visible_node_set.contains(&s) || visible_node_set.contains(&t) {
            out.push(ei as u32);
        }
    }
    out
}

/// Kernel 3: build `DrawIndirectArgs` from the compacted lists. The
/// values flow straight into `MTLDrawPrimitivesIndirectArguments` so
/// the render encoder can call `drawPrimitivesIndirect` and skip the
/// CPU iteration entirely.
///
/// For nodes: typically 6 vertices per instanced quad sprite.
/// For edges: typically 6 vertices per instanced line quad.
///
/// `vertices_per_instance` is the geometry's vertex count.
pub fn build_indirect_args(
    visible_count: u32,
    vertices_per_instance: u32,
) -> DrawIndirectArgs {
    DrawIndirectArgs {
        vertex_count: vertices_per_instance,
        instance_count: visible_count,
        vertex_start: 0,
        base_instance: 0,
    }
}

/// Frame-level summary used by the renderer + telemetry.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct VisibilityStats {
    pub total_nodes: u32,
    pub visible_nodes: u32,
    pub total_edges: u32,
    pub visible_edges: u32,
    pub visible_node_fraction: f32,
}

pub fn visibility_stats(
    total_nodes: u32,
    total_edges: u32,
    visible_nodes: u32,
    visible_edges: u32,
) -> VisibilityStats {
    let fraction = if total_nodes == 0 { 0.0 }
                   else { visible_nodes as f32 / total_nodes as f32 };
    VisibilityStats {
        total_nodes,
        visible_nodes,
        total_edges,
        visible_edges,
        visible_node_fraction: fraction,
    }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeSet;

    fn make_flags(n: usize, renderable: bool) -> Vec<u32> {
        let bit = if renderable { 1u32 } else { 0u32 };
        vec![bit; n]
    }

    #[test]
    fn frustum_intersects_inside_point() {
        let f = Frustum2D::from_centre_and_half(0.0, 0.0, 10.0, 10.0);
        assert!(f.intersects_circle(0.0, 0.0, 0.0));
        assert!(f.intersects_circle(5.0, 5.0, 0.0));
        assert!(f.intersects_circle(-9.9, -9.9, 0.0));
    }

    #[test]
    fn frustum_intersects_boundary_clip() {
        let f = Frustum2D::from_centre_and_half(0.0, 0.0, 10.0, 10.0);
        // Centre outside but circle clips boundary.
        assert!(f.intersects_circle(11.0, 0.0, 2.0));
        // Centre outside, circle too small.
        assert!(!f.intersects_circle(20.0, 0.0, 1.0));
    }

    #[test]
    fn frustum_excludes_far_points() {
        let f = Frustum2D::from_centre_and_half(0.0, 0.0, 5.0, 5.0);
        assert!(!f.intersects_circle(100.0, 0.0, 0.0));
        assert!(!f.intersects_circle(0.0, 100.0, 0.0));
    }

    #[test]
    fn frustum_cull_nodes_keeps_inside_drops_outside() {
        let pos_x = vec![0.0_f32, 5.0, 100.0, -100.0];
        let pos_y = vec![0.0_f32, 5.0, 0.0, 0.0];
        let radii = vec![1.0_f32; 4];
        let flags = make_flags(4, true);
        let f = Frustum2D::from_centre_and_half(0.0, 0.0, 10.0, 10.0);
        let visible = frustum_cull_nodes(&pos_x, &pos_y, &radii, &flags, &f);
        assert_eq!(visible, vec![0, 1]);
    }

    #[test]
    fn frustum_cull_nodes_skips_non_renderable() {
        let pos_x = vec![0.0_f32, 5.0];
        let pos_y = vec![0.0_f32, 5.0];
        let radii = vec![1.0_f32; 2];
        let flags = vec![0u32, 1u32]; // node 0 not renderable, node 1 is
        let f = Frustum2D::from_centre_and_half(0.0, 0.0, 10.0, 10.0);
        let visible = frustum_cull_nodes(&pos_x, &pos_y, &radii, &flags, &f);
        assert_eq!(visible, vec![1], "filter-hidden node must be culled");
    }

    #[test]
    fn frustum_cull_nodes_respects_radius_clip() {
        // Node centre is outside the frustum but its radius reaches in.
        let pos_x = vec![15.0_f32];
        let pos_y = vec![0.0_f32];
        let radii = vec![7.0_f32];
        let flags = vec![1u32];
        let f = Frustum2D::from_centre_and_half(0.0, 0.0, 10.0, 10.0);
        let visible = frustum_cull_nodes(&pos_x, &pos_y, &radii, &flags, &f);
        assert_eq!(visible, vec![0], "radius reaches into frustum → keep");
    }

    #[test]
    fn frustum_cull_edges_keeps_partial_visibility() {
        let edges = vec![(0u32, 1), (1u32, 2), (2u32, 3)];
        let mut visible_nodes: BTreeSet<u32> = BTreeSet::new();
        visible_nodes.insert(1);
        let visible = frustum_cull_edges(&edges, &visible_nodes);
        // Edges (0,1) and (1,2) touch node 1; (2,3) does not.
        assert_eq!(visible, vec![0, 1]);
    }

    #[test]
    fn frustum_cull_edges_no_visible_nodes_no_visible_edges() {
        let edges = vec![(0u32, 1), (1u32, 2)];
        let visible_nodes: BTreeSet<u32> = BTreeSet::new();
        let visible = frustum_cull_edges(&edges, &visible_nodes);
        assert_eq!(visible.len(), 0);
    }

    #[test]
    fn build_indirect_args_returns_canonical_struct() {
        let args = build_indirect_args(42, 6);
        assert_eq!(args.vertex_count, 6);
        assert_eq!(args.instance_count, 42);
        assert_eq!(args.vertex_start, 0);
        assert_eq!(args.base_instance, 0);
    }

    #[test]
    fn build_indirect_args_zero_visible_zero_instance_count() {
        let args = build_indirect_args(0, 6);
        assert_eq!(args.instance_count, 0);
    }

    #[test]
    fn visibility_stats_zero_nodes_zero_fraction() {
        let s = visibility_stats(0, 0, 0, 0);
        assert_eq!(s.visible_node_fraction, 0.0);
    }

    #[test]
    fn visibility_stats_half_visible() {
        let s = visibility_stats(10, 20, 5, 8);
        assert!((s.visible_node_fraction - 0.5).abs() < 1e-6);
        assert_eq!(s.visible_nodes, 5);
        assert_eq!(s.visible_edges, 8);
    }

    #[test]
    fn frustum_cull_is_deterministic() {
        let pos_x: Vec<f32> = (0..100).map(|i| (i as f32) * 0.3 - 15.0).collect();
        let pos_y: Vec<f32> = (0..100).map(|i| (i as f32) * 0.1 - 5.0).collect();
        let radii = vec![1.0_f32; 100];
        let flags = make_flags(100, true);
        let f = Frustum2D::from_centre_and_half(0.0, 0.0, 10.0, 10.0);
        let a = frustum_cull_nodes(&pos_x, &pos_y, &radii, &flags, &f);
        let b = frustum_cull_nodes(&pos_x, &pos_y, &radii, &flags, &f);
        assert_eq!(a, b);
    }

    #[test]
    fn renderable_flag_is_canonical_bit_0() {
        // Sanity guard: this module assumes FLAG_RENDERABLE = 1 << 0.
        // The graph-engine source of truth is `node_state::FLAG_RENDERABLE`.
        assert_eq!(crate::node_state::FLAG_RENDERABLE, 1u32);
    }
}
