//! GraphPOPE-lite warm-start (Phase A Week 3).
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Phase A — CPU
//! foundation + zero-copy" → §"Week 3: GraphPOPE-lite warm-start +
//! RevealController". This module owns the warm-start step that places nodes
//! before any physics runs, so the first frame after open is *already close*
//! to a stable layout instead of being a violent cloud-burst.
//!
//! ## Algorithm (drop 5/6 verbatim, lite variant)
//!
//! 1. Split the graph into connected components.
//! 2. For each component of size N, choose A anchors:
//!    - A = 8  if N <  5k
//!    - A = 16 if 5k ≤ N < 50k
//!    - A = 32 if N ≥ 50k
//! 3. Anchor selection:
//!    - 50% highest degree
//!    - 25% approximate-PageRank (push-based, ε=1e-4, residual budget)
//!    - 25% farthest-point sampling (BFS hop distance from picked set)
//! 4. Run BFS from each anchor → distance vector d_i[a].
//!    Build `z_i[a] = 1 / (1 + d(i, a))`.
//! 5. Standardize each column (subtract column mean, divide by stdev+ε).
//! 6. Project `Z ∈ R^{N×A}` to 2D via deterministic two-vector random
//!    projection (sums of sin/cos of column index seeded by the component's
//!    canonical hash). This is the "simplest" branch from the spec — no PCA
//!    yet; the "prettier" 2-pass power iteration is a later upgrade.
//! 7. Normalize each component's positions into a unit box, then place
//!    components on a relaxed grid in the world.
//!
//! ## Why pure data
//!
//! Engine integration is deferred — this module only consumes a slim
//! `WarmstartInput` (node ids + (u32, u32) edges) and returns positions.
//! That makes it trivially testable, deterministic, and isolated from the
//! engine's ECS / motion plant; the canonical plan flags this exact pattern
//! ("warm-start runs on the immutable topology snapshot, not the live
//! integrator").
//!
//! ## Determinism contract
//!
//! For a given `(input, seed)`, output is bit-for-bit identical across
//! runs and platforms. Tested in `warm_start_is_deterministic`. The whole
//! module avoids `HashMap` ordering — only `BTreeMap` / sorted `Vec`.

use std::collections::{BTreeMap, BTreeSet, VecDeque};

/// Input to the warm-start algorithm.
///
/// `node_ids` is the set of nodes to lay out. `edges` is an undirected
/// edge list expressed as `(u32, u32)` — duplicates and self-loops are
/// tolerated (they are silently ignored). Both slices must be small
/// enough to fit in memory comfortably (the algorithm is O(N·A·E)
/// dominated by the per-anchor BFS).
#[derive(Debug, Clone)]
pub struct WarmstartInput<'a> {
    pub node_ids: &'a [u32],
    pub edges: &'a [(u32, u32)],
    /// World-space half-extent (positions land in `[-world_half, +world_half]`).
    pub world_half: f32,
    /// Deterministic seed for the random-projection step. Distinct seeds
    /// produce visually different but equally valid layouts.
    pub seed: u64,
}

/// Output from the warm-start algorithm — a map from node id → 2D position.
#[derive(Debug, Clone, PartialEq)]
pub struct WarmstartOutput {
    /// Sorted by node id for deterministic iteration.
    pub positions: Vec<(u32, [f32; 2])>,
    /// Diagnostic — how many connected components were laid out.
    pub component_count: usize,
    /// Diagnostic — anchors used per component (sorted by component index).
    pub anchors_per_component: Vec<usize>,
}

/// Anchor-count schedule from the canonical plan §"Week 3" step 2.
fn anchor_count_for(n: usize) -> usize {
    if n < 5_000 { 8 } else if n < 50_000 { 16 } else { 32 }
}

/// Tunable epsilon for column standardisation to avoid div-by-zero.
const STD_EPS: f32 = 1e-6;

/// Build an adjacency map from a (u32, u32) edge list. Self-loops and
/// duplicates are deduplicated. The map is keyed by node id, value is a
/// sorted `Vec<u32>` of neighbour ids so BFS order is deterministic.
fn build_adjacency(
    node_ids: &[u32],
    edges: &[(u32, u32)],
) -> BTreeMap<u32, Vec<u32>> {
    let valid: BTreeSet<u32> = node_ids.iter().copied().collect();
    let mut adj: BTreeMap<u32, BTreeSet<u32>> = BTreeMap::new();
    for &id in node_ids {
        adj.insert(id, BTreeSet::new());
    }
    for &(s, t) in edges {
        if s == t { continue; }
        if !valid.contains(&s) || !valid.contains(&t) { continue; }
        adj.entry(s).or_default().insert(t);
        adj.entry(t).or_default().insert(s);
    }
    adj.into_iter()
        .map(|(k, v)| (k, v.into_iter().collect()))
        .collect()
}

/// Split into connected components via iterative BFS. Returned components
/// are sorted by their smallest node id so iteration is deterministic.
fn connected_components(adj: &BTreeMap<u32, Vec<u32>>) -> Vec<Vec<u32>> {
    let mut seen: BTreeSet<u32> = BTreeSet::new();
    let mut components: Vec<Vec<u32>> = Vec::new();
    for &start in adj.keys() {
        if seen.contains(&start) { continue; }
        let mut comp: Vec<u32> = Vec::new();
        let mut queue: VecDeque<u32> = VecDeque::new();
        queue.push_back(start);
        seen.insert(start);
        while let Some(node) = queue.pop_front() {
            comp.push(node);
            if let Some(neigh) = adj.get(&node) {
                for &n in neigh {
                    if !seen.contains(&n) {
                        seen.insert(n);
                        queue.push_back(n);
                    }
                }
            }
        }
        comp.sort_unstable();
        components.push(comp);
    }
    components.sort_unstable_by_key(|c| c.first().copied().unwrap_or(u32::MAX));
    components
}

/// BFS from `start`, return distance map.
fn bfs_distances(start: u32, adj: &BTreeMap<u32, Vec<u32>>) -> BTreeMap<u32, u32> {
    let mut dist: BTreeMap<u32, u32> = BTreeMap::new();
    let mut queue: VecDeque<u32> = VecDeque::new();
    dist.insert(start, 0);
    queue.push_back(start);
    while let Some(node) = queue.pop_front() {
        let d = dist[&node];
        if let Some(neigh) = adj.get(&node) {
            for &n in neigh {
                if !dist.contains_key(&n) {
                    dist.insert(n, d + 1);
                    queue.push_back(n);
                }
            }
        }
    }
    dist
}

/// Approximate-PageRank rank ordering, push-based with residual ε.
/// Result is component-node-ids sorted by descending score; ties broken
/// by lower node id for determinism.
fn pagerank_rank(
    component: &[u32],
    adj: &BTreeMap<u32, Vec<u32>>,
    iterations: usize,
    damping: f32,
) -> Vec<u32> {
    let n = component.len();
    if n == 0 { return Vec::new(); }
    let mut scores: BTreeMap<u32, f32> = BTreeMap::new();
    let base = 1.0 / n as f32;
    for &id in component { scores.insert(id, base); }
    for _ in 0..iterations {
        let mut next: BTreeMap<u32, f32> = BTreeMap::new();
        for &id in component { next.insert(id, (1.0 - damping) / n as f32); }
        for &id in component {
            let s = scores[&id];
            if let Some(neigh) = adj.get(&id) {
                if neigh.is_empty() {
                    // Sink: redistribute uniformly to avoid losing mass.
                    let share = damping * s / n as f32;
                    for &k in component { *next.get_mut(&k).unwrap() += share; }
                } else {
                    let share = damping * s / neigh.len() as f32;
                    for &nbr in neigh {
                        if let Some(slot) = next.get_mut(&nbr) {
                            *slot += share;
                        }
                    }
                }
            }
        }
        scores = next;
    }
    let mut ranked: Vec<(u32, f32)> = scores.into_iter().collect();
    ranked.sort_by(|a, b| {
        b.1.partial_cmp(&a.1)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then(a.0.cmp(&b.0))
    });
    ranked.into_iter().map(|(id, _)| id).collect()
}

/// Farthest-point sampling: greedy max-min hop distance from already-picked
/// anchors. Used to add coverage anchors that catch corners.
fn farthest_point_sample(
    component: &[u32],
    adj: &BTreeMap<u32, Vec<u32>>,
    already: &BTreeSet<u32>,
    count: usize,
) -> Vec<u32> {
    if count == 0 || component.is_empty() { return Vec::new(); }
    let mut picked: BTreeSet<u32> = already.clone();
    let mut picks: Vec<u32> = Vec::new();
    // If we have no anchors yet, seed with the component's lowest-id node so
    // FPS is deterministic.
    if picked.is_empty() {
        if let Some(&first) = component.first() {
            picked.insert(first);
            picks.push(first);
        }
    }
    while picks.len() < count {
        // Multi-source BFS from picked set.
        let mut dist: BTreeMap<u32, u32> = BTreeMap::new();
        let mut queue: VecDeque<u32> = VecDeque::new();
        for &p in &picked {
            dist.insert(p, 0);
            queue.push_back(p);
        }
        while let Some(node) = queue.pop_front() {
            let d = dist[&node];
            if let Some(neigh) = adj.get(&node) {
                for &n in neigh {
                    if !dist.contains_key(&n) {
                        dist.insert(n, d + 1);
                        queue.push_back(n);
                    }
                }
            }
        }
        // Pick the most-distant un-picked node; ties → lower id.
        let mut best: Option<(u32, u32)> = None;
        for &id in component {
            if picked.contains(&id) { continue; }
            let d = dist.get(&id).copied().unwrap_or(u32::MAX);
            best = match best {
                None => Some((id, d)),
                Some((bid, bd)) => {
                    if d > bd || (d == bd && id < bid) { Some((id, d)) } else { Some((bid, bd)) }
                }
            };
        }
        match best {
            Some((id, _)) => {
                picked.insert(id);
                picks.push(id);
            }
            None => break,
        }
    }
    picks
}

/// Select A anchors for one component using the 50/25/25 split from the
/// canonical plan.
fn select_anchors(
    component: &[u32],
    adj: &BTreeMap<u32, Vec<u32>>,
    a_count: usize,
) -> Vec<u32> {
    if a_count == 0 || component.is_empty() { return Vec::new(); }
    let half = a_count / 2;
    let quarter = (a_count - half) / 2;
    let last = a_count.saturating_sub(half + quarter);

    // 1) Top-degree: sort by descending degree, then by ascending id.
    let mut deg: Vec<(u32, u32)> = component.iter().map(|&id| {
        let d = adj.get(&id).map(|v| v.len() as u32).unwrap_or(0);
        (id, d)
    }).collect();
    deg.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
    let top_degree: Vec<u32> = deg.iter().take(half).map(|&(id, _)| id).collect();

    let mut picked: BTreeSet<u32> = top_degree.iter().copied().collect();

    // 2) PageRank picks that aren't already in `picked`.
    let pr_ranked = pagerank_rank(component, adj, 20, 0.85);
    let mut pr_picks: Vec<u32> = Vec::new();
    for id in pr_ranked {
        if pr_picks.len() >= quarter { break; }
        if !picked.contains(&id) {
            picked.insert(id);
            pr_picks.push(id);
        }
    }

    // 3) Farthest-point sampling for remaining anchors.
    let fps_picks = farthest_point_sample(component, adj, &picked, last);

    let mut all: Vec<u32> = Vec::with_capacity(a_count);
    all.extend(top_degree);
    all.extend(pr_picks);
    all.extend(fps_picks);
    // Final dedup pass — top-degree could overlap if the graph is tiny.
    let mut seen: BTreeSet<u32> = BTreeSet::new();
    all.retain(|id| seen.insert(*id));
    all
}

/// Build the inverse-distance feature matrix `Z[i, a] = 1 / (1 + d(i, a))`,
/// returned in (sorted-node-id) × anchor-index order.
fn build_feature_matrix(
    component: &[u32],
    anchors: &[u32],
    adj: &BTreeMap<u32, Vec<u32>>,
) -> Vec<Vec<f32>> {
    let mut rows: Vec<Vec<f32>> = Vec::with_capacity(component.len());
    let mut anchor_dist: Vec<BTreeMap<u32, u32>> = Vec::with_capacity(anchors.len());
    for &a in anchors {
        anchor_dist.push(bfs_distances(a, adj));
    }
    for &id in component {
        let mut row = Vec::with_capacity(anchors.len());
        for col in 0..anchors.len() {
            let d = anchor_dist[col].get(&id).copied().unwrap_or(u32::MAX);
            let f = if d == u32::MAX { 0.0 } else { 1.0 / (1.0 + d as f32) };
            row.push(f);
        }
        rows.push(row);
    }
    rows
}

/// Standardize columns in place — subtract column mean, divide by stdev+ε.
fn standardize_columns(matrix: &mut [Vec<f32>]) {
    if matrix.is_empty() { return; }
    let cols = matrix[0].len();
    let rows = matrix.len() as f32;
    if rows < 1.0 { return; }
    for c in 0..cols {
        let mean: f32 = matrix.iter().map(|r| r[c]).sum::<f32>() / rows;
        let var: f32 = matrix.iter().map(|r| {
            let d = r[c] - mean; d * d
        }).sum::<f32>() / rows;
        let std = var.sqrt().max(STD_EPS);
        for r in matrix.iter_mut() {
            r[c] = (r[c] - mean) / std;
        }
    }
}

/// Deterministic two-vector random projection.
///
/// For each column index `a`, sample two coefficients seeded by `(seed, a)`
/// using a stripped-down xorshift; project each row to 2D via dot product.
/// This is the "simplest" branch from the canonical plan; the prettier
/// 2-pass power-iteration PCA can replace it later.
fn project_to_2d(matrix: &[Vec<f32>], seed: u64) -> Vec<[f32; 2]> {
    if matrix.is_empty() { return Vec::new(); }
    let cols = matrix[0].len();
    let mut weights: Vec<[f32; 2]> = Vec::with_capacity(cols);
    let mut state = seed.wrapping_mul(0x9E37_79B9_7F4A_7C15).wrapping_add(1);
    for _ in 0..cols {
        // Two independent draws via xorshift64.
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        let x = ((state >> 32) as i32 as f32) / (i32::MAX as f32);
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        let y = ((state >> 32) as i32 as f32) / (i32::MAX as f32);
        weights.push([x, y]);
    }
    matrix.iter().map(|row| {
        let mut x = 0.0_f32;
        let mut y = 0.0_f32;
        for (c, &v) in row.iter().enumerate() {
            x += v * weights[c][0];
            y += v * weights[c][1];
        }
        [x, y]
    }).collect()
}

/// Normalize a set of 2D positions into the box `[-half, +half]²`.
fn normalize_into_box(points: &mut [[f32; 2]], half: f32) {
    if points.is_empty() { return; }
    let mut min_x = f32::INFINITY;
    let mut min_y = f32::INFINITY;
    let mut max_x = f32::NEG_INFINITY;
    let mut max_y = f32::NEG_INFINITY;
    for p in points.iter() {
        if p[0] < min_x { min_x = p[0]; }
        if p[1] < min_y { min_y = p[1]; }
        if p[0] > max_x { max_x = p[0]; }
        if p[1] > max_y { max_y = p[1]; }
    }
    let span_x = (max_x - min_x).max(STD_EPS);
    let span_y = (max_y - min_y).max(STD_EPS);
    for p in points.iter_mut() {
        p[0] = ((p[0] - min_x) / span_x) * (2.0 * half) - half;
        p[1] = ((p[1] - min_y) / span_y) * (2.0 * half) - half;
    }
}

/// Place components on a relaxed grid so they don't overlap.
fn place_component_on_grid(
    component_index: usize,
    total_components: usize,
    world_half: f32,
) -> [f32; 2] {
    if total_components <= 1 { return [0.0, 0.0]; }
    let cells_per_row = ((total_components as f32).sqrt().ceil() as usize).max(1);
    let row = component_index / cells_per_row;
    let col = component_index % cells_per_row;
    let cell_size = (world_half * 2.0) / cells_per_row as f32;
    let origin = -world_half + cell_size * 0.5;
    [
        origin + col as f32 * cell_size,
        origin + row as f32 * cell_size,
    ]
}

/// Run the full warm-start pipeline.
pub fn warm_start(input: WarmstartInput<'_>) -> WarmstartOutput {
    let adj = build_adjacency(input.node_ids, input.edges);
    let components = connected_components(&adj);

    let mut all_positions: Vec<(u32, [f32; 2])> = Vec::with_capacity(input.node_ids.len());
    let mut anchors_per_component: Vec<usize> = Vec::with_capacity(components.len());

    let comp_count = components.len();
    let per_component_half = if comp_count > 1 {
        // Each cell gets a fraction of the world so components don't crash into each other.
        input.world_half / (comp_count as f32).sqrt().ceil().max(1.0)
    } else {
        input.world_half
    };

    for (i, comp) in components.iter().enumerate() {
        let a_count = anchor_count_for(comp.len()).min(comp.len().max(1));
        let anchors = select_anchors(comp, &adj, a_count);
        anchors_per_component.push(anchors.len());

        // Edge cases: lone node — just slot it on the grid.
        if comp.len() == 1 || anchors.is_empty() {
            let centre = place_component_on_grid(i, comp_count, input.world_half);
            for &id in comp {
                all_positions.push((id, centre));
            }
            continue;
        }

        let mut matrix = build_feature_matrix(comp, &anchors, &adj);
        standardize_columns(&mut matrix);
        let mut points = project_to_2d(&matrix, input.seed ^ (i as u64).wrapping_mul(0x517C_C1B7_2722_0A95));
        normalize_into_box(&mut points, per_component_half);
        let centre = place_component_on_grid(i, comp_count, input.world_half);
        for (idx, &id) in comp.iter().enumerate() {
            let p = points[idx];
            all_positions.push((id, [p[0] + centre[0], p[1] + centre[1]]));
        }
    }

    all_positions.sort_by_key(|&(id, _)| id);
    WarmstartOutput {
        positions: all_positions,
        component_count: comp_count,
        anchors_per_component,
    }
}

/// Reveal placement for a node that arrives after the warm-start pass.
///
/// Per the canonical plan §"Week 3" deliverable: "new node = weighted
/// centroid of visible neighbors + jitter; fallback to warm-start if no
/// visible neighbors". The fallback is the caller's job — if the returned
/// `Option` is `None`, the caller should re-run a single-component warm-
/// start for the new node or just drop it at the cursor / world centre.
pub fn reveal_position_from_neighbors(
    neighbor_positions: &[[f32; 2]],
    weights: &[f32],
    seed: u64,
) -> Option<[f32; 2]> {
    if neighbor_positions.is_empty() { return None; }
    let w_sum: f32 = weights.iter().copied().sum();
    let (mut cx, mut cy) = (0.0_f32, 0.0_f32);
    if w_sum.abs() < STD_EPS {
        // Unweighted fallback: arithmetic mean.
        for p in neighbor_positions {
            cx += p[0];
            cy += p[1];
        }
        let n = neighbor_positions.len() as f32;
        cx /= n;
        cy /= n;
    } else {
        for (p, &w) in neighbor_positions.iter().zip(weights.iter()) {
            cx += p[0] * w;
            cy += p[1] * w;
        }
        cx /= w_sum;
        cy /= w_sum;
    }
    // Deterministic per-node jitter — radius ≈ 0.5% of world span will be
    // applied by the caller; here we just return the centroid plus a small
    // xorshift-seeded offset to break exact-coincidence ties.
    let mut s = seed.wrapping_mul(0x517C_C1B7_2722_0A95).wrapping_add(0xD2B7_4407_B1CE_6E93);
    s ^= s << 13; s ^= s >> 7; s ^= s << 17;
    let jx = ((s >> 32) as i32 as f32) / (i32::MAX as f32);
    s ^= s << 13; s ^= s >> 7; s ^= s << 17;
    let jy = ((s >> 32) as i32 as f32) / (i32::MAX as f32);
    Some([cx + jx * 0.001, cy + jy * 0.001])
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn linear_chain(n: u32) -> (Vec<u32>, Vec<(u32, u32)>) {
        let nodes: Vec<u32> = (0..n).collect();
        let edges: Vec<(u32, u32)> = (0..n - 1).map(|i| (i, i + 1)).collect();
        (nodes, edges)
    }

    fn small_star(branch_count: u32) -> (Vec<u32>, Vec<(u32, u32)>) {
        // Node 0 is the hub.
        let nodes: Vec<u32> = (0..=branch_count).collect();
        let edges: Vec<(u32, u32)> = (1..=branch_count).map(|i| (0, i)).collect();
        (nodes, edges)
    }

    #[test]
    fn anchor_count_bands_match_plan() {
        assert_eq!(anchor_count_for(0), 8);
        assert_eq!(anchor_count_for(100), 8);
        assert_eq!(anchor_count_for(4_999), 8);
        assert_eq!(anchor_count_for(5_000), 16);
        assert_eq!(anchor_count_for(49_999), 16);
        assert_eq!(anchor_count_for(50_000), 32);
        assert_eq!(anchor_count_for(1_000_000), 32);
    }

    #[test]
    fn empty_input_yields_empty_output() {
        let out = warm_start(WarmstartInput {
            node_ids: &[],
            edges: &[],
            world_half: 100.0,
            seed: 42,
        });
        assert!(out.positions.is_empty());
        assert_eq!(out.component_count, 0);
    }

    #[test]
    fn single_node_lands_at_grid_centre() {
        let out = warm_start(WarmstartInput {
            node_ids: &[7],
            edges: &[],
            world_half: 100.0,
            seed: 42,
        });
        assert_eq!(out.positions.len(), 1);
        assert_eq!(out.positions[0].0, 7);
        assert_eq!(out.positions[0].1, [0.0, 0.0]);
        assert_eq!(out.component_count, 1);
    }

    #[test]
    fn isolated_nodes_form_separate_components() {
        let out = warm_start(WarmstartInput {
            node_ids: &[1, 2, 3, 4],
            edges: &[],
            world_half: 100.0,
            seed: 42,
        });
        assert_eq!(out.positions.len(), 4);
        assert_eq!(out.component_count, 4);
        // Grid placement → at least two distinct positions.
        let distinct: BTreeSet<(i32, i32)> = out.positions.iter()
            .map(|(_, p)| (p[0] as i32, p[1] as i32)).collect();
        assert!(distinct.len() >= 2, "isolated components must land on different grid cells");
    }

    #[test]
    fn warm_start_is_deterministic() {
        let (nodes, edges) = linear_chain(50);
        let a = warm_start(WarmstartInput {
            node_ids: &nodes,
            edges: &edges,
            world_half: 100.0,
            seed: 1234,
        });
        let b = warm_start(WarmstartInput {
            node_ids: &nodes,
            edges: &edges,
            world_half: 100.0,
            seed: 1234,
        });
        assert_eq!(a, b, "same input + seed must give bit-identical output");
    }

    #[test]
    fn different_seeds_give_different_layouts() {
        let (nodes, edges) = linear_chain(30);
        let a = warm_start(WarmstartInput {
            node_ids: &nodes,
            edges: &edges,
            world_half: 100.0,
            seed: 1,
        });
        let b = warm_start(WarmstartInput {
            node_ids: &nodes,
            edges: &edges,
            world_half: 100.0,
            seed: 2,
        });
        // Trivially the positions differ for any non-degenerate seed change.
        assert_ne!(a.positions, b.positions);
    }

    #[test]
    fn positions_land_inside_world_box() {
        let (nodes, edges) = linear_chain(100);
        let world_half = 50.0;
        let out = warm_start(WarmstartInput {
            node_ids: &nodes,
            edges: &edges,
            world_half,
            seed: 42,
        });
        for (id, p) in &out.positions {
            // Allow a small slack for floating-point in the grid offset.
            assert!(p[0].abs() <= world_half + 1.0, "node {id} x={} out of box", p[0]);
            assert!(p[1].abs() <= world_half + 1.0, "node {id} y={} out of box", p[1]);
        }
    }

    #[test]
    fn star_anchors_include_the_hub() {
        let (nodes, edges) = small_star(20);
        let adj = build_adjacency(&nodes, &edges);
        let comps = connected_components(&adj);
        assert_eq!(comps.len(), 1);
        let anchors = select_anchors(&comps[0], &adj, anchor_count_for(nodes.len()));
        assert!(anchors.contains(&0), "hub (degree-20) should be in the anchor set");
    }

    #[test]
    fn duplicate_edges_are_idempotent() {
        let nodes = vec![1u32, 2, 3];
        let edges_a = vec![(1u32, 2), (2, 3)];
        let edges_b = vec![(1u32, 2), (2, 3), (1, 2), (2, 1), (2, 3)];
        let a = warm_start(WarmstartInput {
            node_ids: &nodes,
            edges: &edges_a,
            world_half: 100.0,
            seed: 11,
        });
        let b = warm_start(WarmstartInput {
            node_ids: &nodes,
            edges: &edges_b,
            world_half: 100.0,
            seed: 11,
        });
        assert_eq!(a, b, "duplicate / reverse edges must not perturb output");
    }

    #[test]
    fn self_loops_are_ignored() {
        let nodes = vec![1u32, 2, 3];
        let with_loops = vec![(1u32, 1), (1, 2), (2, 3), (3, 3)];
        let without = vec![(1u32, 2), (2, 3)];
        let a = warm_start(WarmstartInput {
            node_ids: &nodes,
            edges: &with_loops,
            world_half: 100.0,
            seed: 1,
        });
        let b = warm_start(WarmstartInput {
            node_ids: &nodes,
            edges: &without,
            world_half: 100.0,
            seed: 1,
        });
        assert_eq!(a, b, "self-loops must be silently dropped");
    }

    #[test]
    fn reveal_centroid_no_neighbors_returns_none() {
        assert!(reveal_position_from_neighbors(&[], &[], 1).is_none());
    }

    #[test]
    fn reveal_centroid_single_neighbor_returns_near_it() {
        let p = reveal_position_from_neighbors(&[[10.0, 5.0]], &[1.0], 99)
            .expect("single neighbour must produce a centroid");
        // Within the jitter ball of 0.001.
        assert!((p[0] - 10.0).abs() < 0.01);
        assert!((p[1] - 5.0).abs() < 0.01);
    }

    #[test]
    fn reveal_centroid_weighted_average() {
        // Two neighbours, weights 1 and 3 → centroid heavily pulled toward second.
        let p = reveal_position_from_neighbors(
            &[[0.0, 0.0], [4.0, 0.0]],
            &[1.0, 3.0],
            7,
        ).expect("must succeed");
        // Expected x = (0*1 + 4*3) / 4 = 3.0, ± jitter.
        assert!((p[0] - 3.0).abs() < 0.01);
        assert!(p[1].abs() < 0.01);
    }

    #[test]
    fn feature_matrix_anchor_self_distance_is_one_over_one() {
        let (nodes, edges) = linear_chain(5);
        let adj = build_adjacency(&nodes, &edges);
        let comps = connected_components(&adj);
        let anchors = vec![0u32, 4];
        let matrix = build_feature_matrix(&comps[0], &anchors, &adj);
        // First row is node 0: distance to itself = 0 → 1/(1+0) = 1; distance to node 4 = 4 → 1/5 = 0.2.
        assert!((matrix[0][0] - 1.0).abs() < 1e-6);
        assert!((matrix[0][1] - 0.2).abs() < 1e-6);
        // Last row: distance to node 0 = 4, to node 4 = 0.
        assert!((matrix[4][0] - 0.2).abs() < 1e-6);
        assert!((matrix[4][1] - 1.0).abs() < 1e-6);
    }

    #[test]
    fn standardize_zero_mean_unit_var() {
        let mut m = vec![
            vec![1.0, 5.0],
            vec![2.0, 5.0],
            vec![3.0, 5.0],
        ];
        standardize_columns(&mut m);
        // Column 0: mean 2, stdev ≈ sqrt(2/3); column 1: constant → ε-divided.
        let col0_sum: f32 = m.iter().map(|r| r[0]).sum();
        assert!(col0_sum.abs() < 1e-4);
        // Constant column maps to (0, 0, 0) — value−mean = 0.
        for row in &m {
            assert!(row[1].abs() < 1e-4);
        }
    }
}
