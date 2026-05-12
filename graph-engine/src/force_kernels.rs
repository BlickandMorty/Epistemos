//! Phase B compute-kernel reference implementations (Rust mirror of MSL).
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Phase B — Metal
//! compute (8 weeks)" → §"Week 1-2: Spring forces kernel + integration
//! kernel". The plan calls for two `.metal` files:
//!
//! - `Epistemos/Shaders/Graph/spring_forces.metal`: node-parallel CSR
//!   gather (no atomics)
//! - `Epistemos/Shaders/Graph/integrate.metal`: reads NodeState, applies
//!   forces, updates velocity + position; honors RENDERABLE / AWAKE /
//!   WARMING / SLEEPING flag semantics
//!
//! The Phase B exit gate requires "GPU spring kernel produces bit-
//! equivalent forces to CPU baseline (within 1e-5)". This module ships
//! the CPU baseline as a *node-parallel CSR* algorithm so the MSL kernel
//! can be a straight per-thread translation. The numerics are pinned to
//! match what the Metal kernel will compute byte-for-byte.
//!
//! ## Pure-data contract
//!
//! Inputs are slim `f32` arrays + an undirected CSR (head + neighbours).
//! Outputs are `f32` force arrays. No engine dependencies; the integrator
//! sequences `spring_forces_kernel` and `integrate_kernel` per frame.
//!
//! ## Why a separate module
//!
//! `forces.rs` already has d3-force's edge-parallel implementation
//! (`force_link`). That algorithm walks the edge array linearly and
//! writes to both endpoints — perfect for CPU, but every edge write is
//! a contention point on GPU. Node-parallel CSR walks every node's
//! adjacency list and sums forces locally — exactly mirrors the Metal
//! threadgroup pattern.
//!
//! ## Determinism contract
//!
//! Same input arrays + same alpha → bit-identical f32 output. Tested in
//! `spring_kernel_is_deterministic` and `mirror_of_edge_parallel_within_eps`.

/// Undirected CSR (compressed sparse row) view of the graph.
///
/// `head[i]` is the offset into `neighbours` where node `i`'s adjacency
/// list begins; the list extends through `head[i+1]`. `head.len()` is
/// `nodes + 1`. Each `(neighbour, edge_index)` tuple in `neighbours`
/// references back into the edge data arrays (rest_length, weight, etc.).
///
/// This is the canonical Phase B layout — both Metal kernels read from
/// this exact memory layout.
#[derive(Debug, Clone)]
pub struct UndirectedCsr<'a> {
    pub head: &'a [u32],
    pub neighbours: &'a [(u32, u32)],
}

impl<'a> UndirectedCsr<'a> {
    pub fn node_count(&self) -> usize {
        self.head.len().saturating_sub(1)
    }

    pub fn neighbours_of(&self, node: u32) -> &[(u32, u32)] {
        let i = node as usize;
        if i + 1 >= self.head.len() { return &[]; }
        let lo = self.head[i] as usize;
        let hi = self.head[i + 1] as usize;
        if lo > hi || hi > self.neighbours.len() { return &[]; }
        &self.neighbours[lo..hi]
    }

    pub fn degree(&self, node: u32) -> u32 {
        let i = node as usize;
        if i + 1 >= self.head.len() { return 0; }
        self.head[i + 1] - self.head[i]
    }
}

/// Build an undirected CSR from an `(u32, u32)` edge list. Self-loops and
/// duplicates are silently dropped. Returns `(head, neighbours)` owned
/// vectors — the caller can hand slim slices into `UndirectedCsr`.
pub fn build_undirected_csr(
    node_count: u32,
    edges: &[(u32, u32)],
) -> (Vec<u32>, Vec<(u32, u32)>) {
    // First pass: count valid neighbours per node, deduped.
    let n = node_count as usize;
    if n == 0 || edges.is_empty() {
        return (vec![0; n + 1], Vec::new());
    }
    let mut adj_set: Vec<std::collections::BTreeSet<u32>> =
        (0..n).map(|_| std::collections::BTreeSet::new()).collect();
    let mut edge_ix: std::collections::BTreeMap<(u32, u32), u32> = Default::default();
    for (ei, &(s, t)) in edges.iter().enumerate() {
        if s == t || s >= node_count || t >= node_count { continue; }
        adj_set[s as usize].insert(t);
        adj_set[t as usize].insert(s);
        let key = if s < t { (s, t) } else { (t, s) };
        edge_ix.entry(key).or_insert(ei as u32);
    }
    let mut head: Vec<u32> = Vec::with_capacity(n + 1);
    let mut neighbours: Vec<(u32, u32)> = Vec::new();
    let mut acc: u32 = 0;
    head.push(0);
    for (i, set) in adj_set.iter().enumerate() {
        for &nbr in set {
            let key = if i as u32 <= nbr { (i as u32, nbr) } else { (nbr, i as u32) };
            let eix = edge_ix.get(&key).copied().unwrap_or(0);
            neighbours.push((nbr, eix));
        }
        acc += set.len() as u32;
        head.push(acc);
    }
    (head, neighbours)
}

/// Phase B spring-forces kernel — node-parallel CSR gather, no atomics.
///
/// For each node `i`, walks its adjacency list and accumulates the spring
/// force from each incident edge into a local `(fx, fy)` accumulator,
/// then writes the result to `force_x[i]` / `force_y[i]`. This is the
/// exact GPU pattern: one thread per node, no cross-thread writes.
///
/// Output overwrites prior force values in `force_x` / `force_y`.
///
/// `link_distance` defaults to 30.0 in production; tests should pass
/// values that fit their fixture. `alpha` is the integrator alpha
/// (typically warm-start / reveal-controlled).
pub fn spring_forces_kernel(
    pos_x: &[f32],
    pos_y: &[f32],
    csr: &UndirectedCsr<'_>,
    edge_rest: &[f32],
    edge_weight: &[f32],
    force_x: &mut [f32],
    force_y: &mut [f32],
    alpha: f32,
    link_distance_default: f32,
) {
    let n = csr.node_count().min(pos_x.len()).min(pos_y.len());
    for i in 0..n {
        let mut fx = 0.0_f32;
        let mut fy = 0.0_f32;
        let ux = pos_x[i];
        let uy = pos_y[i];
        for &(nbr, eix) in csr.neighbours_of(i as u32) {
            let j = nbr as usize;
            if j >= pos_x.len() || j >= pos_y.len() { continue; }
            let vx = pos_x[j];
            let vy = pos_y[j];
            let dx = vx - ux;
            let dy = vy - uy;
            let dist_sq = dx * dx + dy * dy;
            // Floor distance at 1e-3 to avoid /0 when nodes coincide; matches
            // the d3-force jiggle but is deterministic across endpoints.
            let dist = dist_sq.sqrt().max(1e-3);
            let weight = edge_weight.get(eix as usize).copied().unwrap_or(1.0);
            let rest = edge_rest.get(eix as usize).copied().unwrap_or(link_distance_default);
            let strength = 1.0 / (csr.degree(i as u32).min(csr.degree(nbr)) as f32).max(1.0);
            // d3 model: f = strength * (rest - dist) * unit_direction * alpha
            // Sign: pull i toward j when dist > rest.
            let unit_x = dx / dist;
            let unit_y = dy / dist;
            let magnitude = strength * weight * (dist - rest) * alpha;
            fx += unit_x * magnitude;
            fy += unit_y * magnitude;
        }
        force_x[i] = fx;
        force_y[i] = fy;
    }
}

/// Phase B integrate kernel — reads positions/velocities/forces, advances
/// state, honours flag semantics.
///
/// Per drop 5's warm-zone formula, an integrator that's run on a Warming
/// node should apply a fraction of `dt` (caller computes via
/// `atmosphere::warm_zone_scaling`). The kernel only sees `dt_factor`
/// and `force_factor` here.
///
/// Flag bits (matching `node_state::FLAG_*`):
/// - bit 0: RENDERABLE (renderer-only; kernel ignores)
/// - bit 1: AWAKE
/// - bit 2: WARMING
/// - bit 3: SLEEPING
/// - bit 4: PINNED
///
/// Sleeping nodes skip integration. Pinned nodes skip integration (their
/// position is set externally). RENDERABLE is orthogonal — both sleeping
/// and pinned nodes still render.
#[allow(clippy::too_many_arguments)]
pub fn integrate_kernel(
    pos_x: &mut [f32],
    pos_y: &mut [f32],
    vel_x: &mut [f32],
    vel_y: &mut [f32],
    force_x: &[f32],
    force_y: &[f32],
    flags: &[u32],
    dt: f32,
    dt_factors: &[f32],
    force_factors: &[f32],
    velocity_decay: f32,
) {
    let n = pos_x.len()
        .min(pos_y.len()).min(vel_x.len()).min(vel_y.len())
        .min(force_x.len()).min(force_y.len()).min(flags.len());
    for i in 0..n {
        let f = flags[i];
        let sleeping = f & (1 << 3) != 0;
        let pinned = f & (1 << 4) != 0;
        if sleeping || pinned {
            continue;
        }
        let dt_eff = dt * dt_factors.get(i).copied().unwrap_or(1.0);
        let force_scale = force_factors.get(i).copied().unwrap_or(1.0);
        let fx = force_x[i] * force_scale;
        let fy = force_y[i] * force_scale;
        // Symplectic Euler: v += a*dt, then x += v*dt.
        vel_x[i] += fx * dt_eff;
        vel_y[i] += fy * dt_eff;
        vel_x[i] *= velocity_decay;
        vel_y[i] *= velocity_decay;
        pos_x[i] += vel_x[i] * dt_eff;
        pos_y[i] += vel_y[i] * dt_eff;
    }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn small_chain_csr() -> (Vec<u32>, Vec<(u32, u32)>) {
        // Nodes 0-1-2-3 in a chain
        build_undirected_csr(4, &[(0, 1), (1, 2), (2, 3)])
    }

    #[test]
    fn csr_degree_correct() {
        let (head, neighbours) = small_chain_csr();
        let csr = UndirectedCsr { head: &head, neighbours: &neighbours };
        assert_eq!(csr.degree(0), 1);
        assert_eq!(csr.degree(1), 2);
        assert_eq!(csr.degree(2), 2);
        assert_eq!(csr.degree(3), 1);
    }

    #[test]
    fn csr_neighbours_of_returns_sorted_list() {
        let (head, neighbours) = build_undirected_csr(3, &[(0, 1), (0, 2), (1, 2)]);
        let csr = UndirectedCsr { head: &head, neighbours: &neighbours };
        let n0: Vec<u32> = csr.neighbours_of(0).iter().map(|&(n, _)| n).collect();
        assert_eq!(n0, vec![1, 2]);
        let n1: Vec<u32> = csr.neighbours_of(1).iter().map(|&(n, _)| n).collect();
        assert_eq!(n1, vec![0, 2]);
    }

    #[test]
    fn csr_drops_duplicates_and_self_loops() {
        let (head, neighbours) =
            build_undirected_csr(2, &[(0, 1), (0, 0), (1, 0), (0, 1)]);
        let csr = UndirectedCsr { head: &head, neighbours: &neighbours };
        assert_eq!(csr.degree(0), 1);
        assert_eq!(csr.degree(1), 1);
        assert_eq!(neighbours.len(), 2);
    }

    #[test]
    fn csr_empty_input_safe() {
        let (head, neighbours) = build_undirected_csr(0, &[]);
        let csr = UndirectedCsr { head: &head, neighbours: &neighbours };
        assert_eq!(csr.node_count(), 0);
        assert_eq!(csr.neighbours_of(0).len(), 0);
    }

    #[test]
    fn spring_kernel_pulls_apart_overlapping_nodes() {
        let pos_x = vec![0.0_f32, 0.0];
        let pos_y = vec![0.0_f32, 0.0];
        let (head, neighbours) = build_undirected_csr(2, &[(0, 1)]);
        let csr = UndirectedCsr { head: &head, neighbours: &neighbours };
        let mut fx = vec![0.0_f32; 2];
        let mut fy = vec![0.0_f32; 2];
        spring_forces_kernel(
            &pos_x, &pos_y, &csr,
            &[30.0], &[1.0],
            &mut fx, &mut fy,
            1.0, 30.0,
        );
        // The rest length is 30; nodes are coincident so the rest force pulls
        // them apart — but coincident → jiggle floors distance so the force
        // is well-defined. Both nodes get equal-and-opposite forces.
        assert!((fx[0] + fx[1]).abs() < 1e-3, "Newton's third law on overlapping pair");
        assert!((fy[0] + fy[1]).abs() < 1e-3);
    }

    #[test]
    fn spring_kernel_attracts_separated_nodes_to_rest_length() {
        let pos_x = vec![0.0_f32, 100.0];
        let pos_y = vec![0.0_f32, 0.0];
        let (head, neighbours) = build_undirected_csr(2, &[(0, 1)]);
        let csr = UndirectedCsr { head: &head, neighbours: &neighbours };
        let mut fx = vec![0.0_f32; 2];
        let mut fy = vec![0.0_f32; 2];
        spring_forces_kernel(
            &pos_x, &pos_y, &csr,
            &[30.0], &[1.0],
            &mut fx, &mut fy,
            1.0, 30.0,
        );
        // dist > rest → force pulls them together. Node 0 should get +fx,
        // node 1 should get -fx.
        assert!(fx[0] > 0.0, "node 0 pulled toward node 1");
        assert!(fx[1] < 0.0, "node 1 pulled toward node 0");
        assert!((fx[0] + fx[1]).abs() < 1e-3, "Newton's third law");
    }

    #[test]
    fn spring_kernel_zero_alpha_zero_force() {
        let pos_x = vec![0.0_f32, 100.0];
        let pos_y = vec![0.0_f32, 0.0];
        let (head, neighbours) = build_undirected_csr(2, &[(0, 1)]);
        let csr = UndirectedCsr { head: &head, neighbours: &neighbours };
        let mut fx = vec![0.0_f32; 2];
        let mut fy = vec![0.0_f32; 2];
        spring_forces_kernel(
            &pos_x, &pos_y, &csr,
            &[30.0], &[1.0],
            &mut fx, &mut fy,
            0.0, 30.0,
        );
        assert_eq!(fx, vec![0.0, 0.0]);
        assert_eq!(fy, vec![0.0, 0.0]);
    }

    #[test]
    fn spring_kernel_is_deterministic() {
        let pos_x = vec![0.0_f32, 10.0, 20.0, 30.0];
        let pos_y = vec![1.0_f32, 2.0, 3.0, 4.0];
        let (head, neighbours) = small_chain_csr();
        let csr = UndirectedCsr { head: &head, neighbours: &neighbours };
        let mut fx_a = vec![0.0_f32; 4];
        let mut fy_a = vec![0.0_f32; 4];
        let mut fx_b = vec![0.0_f32; 4];
        let mut fy_b = vec![0.0_f32; 4];
        let rest = vec![30.0_f32; 3];
        let weight = vec![1.0_f32; 3];
        spring_forces_kernel(&pos_x, &pos_y, &csr, &rest, &weight, &mut fx_a, &mut fy_a, 0.8, 30.0);
        spring_forces_kernel(&pos_x, &pos_y, &csr, &rest, &weight, &mut fx_b, &mut fy_b, 0.8, 30.0);
        assert_eq!(fx_a, fx_b);
        assert_eq!(fy_a, fy_b);
    }

    #[test]
    fn integrate_kernel_advances_position_under_force() {
        let mut x = vec![0.0_f32];
        let mut y = vec![0.0_f32];
        let mut vx = vec![0.0_f32];
        let mut vy = vec![0.0_f32];
        let fx = vec![10.0_f32];
        let fy = vec![0.0_f32];
        let flags = vec![1u32 << 1]; // AWAKE
        integrate_kernel(
            &mut x, &mut y, &mut vx, &mut vy,
            &fx, &fy, &flags,
            0.1, &[1.0], &[1.0], 1.0,
        );
        // v += f*dt = 1.0 ; x += v*dt = 0.1
        assert!((vx[0] - 1.0).abs() < 1e-6);
        assert!((x[0] - 0.1).abs() < 1e-6);
    }

    #[test]
    fn integrate_kernel_skips_sleeping() {
        let mut x = vec![0.0_f32];
        let mut y = vec![0.0_f32];
        let mut vx = vec![0.0_f32];
        let mut vy = vec![0.0_f32];
        let fx = vec![10.0_f32];
        let fy = vec![0.0_f32];
        let flags = vec![1u32 << 3]; // SLEEPING
        integrate_kernel(
            &mut x, &mut y, &mut vx, &mut vy,
            &fx, &fy, &flags,
            0.1, &[1.0], &[1.0], 1.0,
        );
        assert_eq!(x, vec![0.0]);
        assert_eq!(vx, vec![0.0]);
    }

    #[test]
    fn integrate_kernel_skips_pinned() {
        let mut x = vec![5.0_f32];
        let mut y = vec![5.0_f32];
        let mut vx = vec![0.0_f32];
        let mut vy = vec![0.0_f32];
        let fx = vec![10.0_f32];
        let fy = vec![10.0_f32];
        let flags = vec![1u32 << 4]; // PINNED
        integrate_kernel(
            &mut x, &mut y, &mut vx, &mut vy,
            &fx, &fy, &flags,
            0.1, &[1.0], &[1.0], 1.0,
        );
        // Pinned nodes don't move.
        assert_eq!(x, vec![5.0]);
        assert_eq!(y, vec![5.0]);
    }

    #[test]
    fn integrate_kernel_applies_dt_factor() {
        let mut x = vec![0.0_f32];
        let mut y = vec![0.0_f32];
        let mut vx = vec![0.0_f32];
        let mut vy = vec![0.0_f32];
        let fx = vec![10.0_f32];
        let fy = vec![0.0_f32];
        let flags = vec![1u32 << 2]; // WARMING
        // dt_factor 0.5 → half dt → half acceleration this frame.
        integrate_kernel(
            &mut x, &mut y, &mut vx, &mut vy,
            &fx, &fy, &flags,
            0.1, &[0.5], &[1.0], 1.0,
        );
        // v += f * (dt*0.5) = 0.5 ; x += v * (dt*0.5) = 0.025
        assert!((vx[0] - 0.5).abs() < 1e-6);
        assert!((x[0] - 0.025).abs() < 1e-6);
    }

    #[test]
    fn integrate_kernel_applies_force_factor() {
        let mut x = vec![0.0_f32];
        let mut y = vec![0.0_f32];
        let mut vx = vec![0.0_f32];
        let mut vy = vec![0.0_f32];
        let fx = vec![10.0_f32];
        let fy = vec![0.0_f32];
        let flags = vec![1u32 << 1]; // AWAKE
        integrate_kernel(
            &mut x, &mut y, &mut vx, &mut vy,
            &fx, &fy, &flags,
            0.1, &[1.0], &[0.25], 1.0,
        );
        // force_factor 0.25 → fx_eff = 2.5 → v = 0.25 ; x = 0.025
        assert!((vx[0] - 0.25).abs() < 1e-6);
        assert!((x[0] - 0.025).abs() < 1e-6);
    }

    #[test]
    fn integrate_kernel_applies_velocity_decay() {
        let mut x = vec![0.0_f32];
        let mut y = vec![0.0_f32];
        let mut vx = vec![10.0_f32]; // start with momentum
        let mut vy = vec![0.0_f32];
        let fx = vec![0.0_f32];
        let fy = vec![0.0_f32];
        let flags = vec![1u32 << 1]; // AWAKE
        integrate_kernel(
            &mut x, &mut y, &mut vx, &mut vy,
            &fx, &fy, &flags,
            0.1, &[1.0], &[1.0], 0.6, // heavy damping
        );
        // No force; v *= decay then x += v*dt
        assert!((vx[0] - 6.0).abs() < 1e-6);
        assert!((x[0] - 0.6).abs() < 1e-6);
    }

    #[test]
    fn integrate_kernel_renderable_orthogonal_to_sleep() {
        // Per locked decision #4: RENDERABLE is independent of sleep state.
        // A node with FLAG_RENDERABLE | FLAG_SLEEPING set must skip integration
        // (sleeping) but the integrator MUST NOT touch the renderable bit.
        let mut x = vec![0.0_f32];
        let mut y = vec![0.0_f32];
        let mut vx = vec![0.0_f32];
        let mut vy = vec![0.0_f32];
        let fx = vec![10.0_f32];
        let fy = vec![0.0_f32];
        let flags = vec![(1u32 << 0) | (1u32 << 3)]; // RENDERABLE + SLEEPING
        integrate_kernel(
            &mut x, &mut y, &mut vx, &mut vy,
            &fx, &fy, &flags,
            0.1, &[1.0], &[1.0], 1.0,
        );
        // Sleeping → skip motion. RENDERABLE bit doesn't override sleep.
        assert_eq!(x, vec![0.0]);
        // Integrator doesn't write flags — they're caller's responsibility.
        assert_eq!(flags, vec![(1u32 << 0) | (1u32 << 3)]);
    }

    #[test]
    fn spring_kernel_mirror_of_edge_parallel_within_eps() {
        // Compare node-parallel CSR result against a simple edge-parallel
        // accumulation. Both must agree within float epsilon on a small graph.
        let pos_x = vec![0.0_f32, 50.0, 25.0, 100.0];
        let pos_y = vec![0.0_f32, 0.0, 30.0, 0.0];
        let edges_pairs: Vec<(u32, u32)> = vec![(0, 1), (1, 2), (2, 3), (0, 3)];
        let (head, neighbours) = build_undirected_csr(4, &edges_pairs);
        let csr = UndirectedCsr { head: &head, neighbours: &neighbours };
        let rest = vec![30.0_f32; 4];
        let weight = vec![1.0_f32; 4];

        // Node-parallel CSR result.
        let mut fx_node = vec![0.0_f32; 4];
        let mut fy_node = vec![0.0_f32; 4];
        spring_forces_kernel(
            &pos_x, &pos_y, &csr,
            &rest, &weight,
            &mut fx_node, &mut fy_node,
            1.0, 30.0,
        );

        // Reference: edge-parallel accumulation matching the kernel's math
        // (strength = 1/min_degree, force = strength * (dist-rest) * unit_dir).
        let mut fx_ref = vec![0.0_f32; 4];
        let mut fy_ref = vec![0.0_f32; 4];
        let degrees: Vec<u32> = (0..4).map(|i| csr.degree(i)).collect();
        for (ei, &(s, t)) in edges_pairs.iter().enumerate() {
            let si = s as usize;
            let ti = t as usize;
            let dx = pos_x[ti] - pos_x[si];
            let dy = pos_y[ti] - pos_y[si];
            let dist = (dx * dx + dy * dy).sqrt().max(1e-3);
            let unit_x = dx / dist;
            let unit_y = dy / dist;
            let strength = 1.0 / degrees[si].min(degrees[ti]) as f32;
            let weight_e = weight[ei];
            let rest_e = rest[ei];
            let mag = strength * weight_e * (dist - rest_e);
            fx_ref[si] += unit_x * mag;
            fy_ref[si] += unit_y * mag;
            fx_ref[ti] -= unit_x * mag;
            fy_ref[ti] -= unit_y * mag;
        }
        for i in 0..4 {
            assert!((fx_node[i] - fx_ref[i]).abs() < 1e-5,
                "spring kernel diverges from edge-parallel at node {i}: node={} ref={}",
                fx_node[i], fx_ref[i]);
            assert!((fy_node[i] - fy_ref[i]).abs() < 1e-5);
        }
    }
}
