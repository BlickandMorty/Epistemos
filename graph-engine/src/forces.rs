//! # D3-Force Modules
//!
//! Faithful translation of d3-force's individual force functions.
//! Each force mutates velocity arrays directly (d3 model: forces add to vx/vy,
//! no mass division). Order matches LogSeq's pipeline:
//! link → many-body → collide → center.

use crate::quadtree::{self, Body};

/// Tiny random displacement to break symmetry on coincident nodes.
/// d3 uses `(lcg() - 0.5) * 1e-6`.
fn jiggle() -> f32 {
    // Simple deterministic jiggle — not truly random but breaks symmetry.
    // In practice, node positions are never exactly equal after initialization.
    1e-6
}

// ── Force: Link (Hooke's spring along edges) ────────────────────────────────

/// d3.forceLink() translation.
///
/// For each edge, applies a spring force proportional to the displacement
/// from the ideal `link_distance`. Strength defaults to `1 / min(degree(src), degree(tgt))`
/// which makes edges between high-degree hubs softer (d3 default behavior).
///
/// If `link_strength_override` > 0, it overrides the per-edge auto strength.
///
/// `edge_weights` (parallel to `edges`): higher weight → shorter link distance
/// and stronger spring. Weight 1.0 is neutral; weight 3.0 means 1/3 the distance.
#[allow(clippy::too_many_arguments)]
pub fn force_link(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    edges: &[(usize, usize)],
    edge_weights: &[f32],
    degrees: &[u32],
    link_distance: f32,
    link_strength_override: f32,
    alpha: f32,
) {
    for (ei, &(si, ti)) in edges.iter().enumerate() {
        if si >= x.len() || ti >= x.len() {
            continue;
        }

        let mut dx = x[ti] - x[si] + jiggle();
        let mut dy = y[ti] - y[si] + jiggle();
        let dist = (dx * dx + dy * dy).sqrt().max(1e-6);
        dx /= dist;
        dy /= dist;

        // Per-edge weight: higher weight = shorter distance, stronger spring.
        let w = edge_weights.get(ei).copied().unwrap_or(1.0).max(0.1);
        let edge_dist = link_distance / w;

        // Strength: 1 / min(degree(source), degree(target)), or override.
        // Scaled by weight so containment edges pull harder.
        let strength = if link_strength_override > 0.0 {
            link_strength_override * w
        } else {
            let min_deg = degrees[si].min(degrees[ti]).max(1) as f32;
            w / min_deg
        };

        let displacement = (dist - edge_dist) * alpha * strength;

        // Bias: distribute force proportional to degree (heavier nodes move less).
        let src_deg = degrees[si].max(1) as f32;
        let tgt_deg = degrees[ti].max(1) as f32;
        let bias = src_deg / (src_deg + tgt_deg);

        vx[ti] -= dx * displacement * bias;
        vy[ti] -= dy * displacement * bias;
        vx[si] += dx * displacement * (1.0 - bias);
        vy[si] += dy * displacement * (1.0 - bias);
    }
}

// ── Force: Many-Body (Barnes-Hut repulsion) ─────────────────────────────────

/// d3.forceManyBody() translation with Barnes-Hut O(n log n) approximation.
///
/// `charge_strength` is typically negative for repulsion (LogSeq: -600).
/// `distance_max` limits the force range (LogSeq: 600).
/// `distance_min` prevents singularities (d3 default: 1).
/// `theta` controls Barnes-Hut accuracy (d3/LogSeq default: 0.5).
#[allow(clippy::too_many_arguments)]
pub fn force_many_body(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    charge_strength: f32,
    distance_max: f32,
    distance_min: f32,
    alpha: f32,
) {
    let mut bodies = Vec::new();
    force_many_body_with_scratch(x, y, vx, vy, charge_strength, distance_max, distance_min, alpha, &mut bodies);
}

/// Like `force_many_body` but reuses a caller-provided scratch buffer for `Body` allocations.
#[allow(clippy::too_many_arguments)]
pub fn force_many_body_with_scratch(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    charge_strength: f32,
    distance_max: f32,
    distance_min: f32,
    alpha: f32,
    bodies: &mut Vec<Body>,
) {
    let n = x.len();
    if n < 2 {
        return;
    }

    // Build Barnes-Hut tree with all nodes, reusing scratch buffer.
    bodies.clear();
    bodies.extend((0..n).map(|i| Body {
        index: i,
        x: x[i],
        y: y[i],
        strength: charge_strength,
    }));

    let tree = match quadtree::build_tree(bodies) {
        Some(t) => t,
        None => return,
    };

    let dist_min_sq = distance_min * distance_min;
    let dist_max_sq = distance_max * distance_max;

    // Apply force from tree to each node.
    for i in 0..n {
        let mut dvx = 0.0_f32;
        let mut dvy = 0.0_f32;
        tree.apply_force(
            x[i],
            y[i],
            i,
            alpha,
            dist_min_sq,
            dist_max_sq,
            &mut dvx,
            &mut dvy,
        );
        vx[i] += dvx;
        vy[i] += dvy;
    }
}

// ── Force: Collide (overlap prevention) ─────────────────────────────────────

/// d3.forceCollide() translation with grid-based broadphase acceleration.
///
/// Position-based (not velocity-based): directly separates overlapping nodes.
/// Uses a uniform grid to reduce pair checks from O(n²) to approximately O(n)
/// for uniformly distributed nodes. Each node is binned into a grid cell of
/// size `2 × max_radius`, then only checks the 3×3 neighborhood.
/// `iterations` = number of passes per tick (LogSeq: 2).
/// `radii` = per-node collision radius (LogSeq uses fixed 26px).
pub fn force_collide(
    x: &mut [f32],
    y: &mut [f32],
    radii: &[f32],
    iterations: u32,
) {
    let mut grid = std::collections::HashMap::new();
    force_collide_with_scratch(x, y, radii, iterations, &mut grid);
}

/// Like `force_collide` but reuses a caller-provided grid HashMap to avoid per-tick allocation.
pub fn force_collide_with_scratch(
    x: &mut [f32],
    y: &mut [f32],
    radii: &[f32],
    iterations: u32,
    grid: &mut std::collections::HashMap<(i32, i32), Vec<usize>>,
) {
    let n = x.len();
    if n < 2 {
        return;
    }

    // Fall back to brute force for tiny graphs (grid overhead not worth it).
    if n <= 32 {
        force_collide_brute(x, y, radii, iterations);
        return;
    }

    // Find max radius to determine cell size.
    let max_radius = radii.iter().cloned().fold(0.0_f32, f32::max);
    if max_radius <= 0.0 {
        return;
    }
    let cell_size = max_radius * 2.0;
    let inv_cell = 1.0 / cell_size;

    for _ in 0..iterations {
        // Clear grid, reusing allocated inner Vecs.
        for v in grid.values_mut() {
            v.clear();
        }

        // Build grid: hash (cell_x, cell_y) → list of node indices.
        for i in 0..n {
            let cx = (x[i] * inv_cell).floor() as i32;
            let cy = (y[i] * inv_cell).floor() as i32;
            grid.entry((cx, cy)).or_default().push(i);
        }

        // Collect keys for iteration (can't mutate x/y while iterating grid).
        let keys: Vec<(i32, i32)> = grid.keys().copied().collect();

        // 4 forward-neighbor offsets to avoid double-checking pairs.
        let offsets: [(i32, i32); 4] = [(1, 0), (-1, 1), (0, 1), (1, 1)];

        for key in &keys {
            let cell = &grid[key];
            if cell.is_empty() { continue; }

            // Intra-cell pairs.
            for a in 0..cell.len() {
                for b in (a + 1)..cell.len() {
                    resolve_overlap(x, y, radii, cell[a], cell[b]);
                }
            }

            // Inter-cell pairs with forward neighbors (O(1) lookup each).
            for &(ox, oy) in &offsets {
                let nkey = (key.0 + ox, key.1 + oy);
                if let Some(neighbor) = grid.get(&nkey) {
                    for &i in cell.iter() {
                        for &j in neighbor.iter() {
                            resolve_overlap(x, y, radii, i, j);
                        }
                    }
                }
            }
        }
    }
}

/// Resolve overlap between two nodes by pushing them apart equally.
#[inline(always)]
fn resolve_overlap(x: &mut [f32], y: &mut [f32], radii: &[f32], i: usize, j: usize) {
    let mut dx = x[j] - x[i];
    let mut dy = y[j] - y[i];
    let dist_sq = dx * dx + dy * dy;
    let min_dist = radii[i] + radii[j];
    let min_dist_sq = min_dist * min_dist;

    if dist_sq < min_dist_sq {
        let dist = dist_sq.sqrt().max(1e-6);
        let overlap = (min_dist - dist) / dist * 0.5;
        dx *= overlap;
        dy *= overlap;

        x[j] += dx;
        y[j] += dy;
        x[i] -= dx;
        y[i] -= dy;
    }
}

/// Brute-force O(n²) fallback for small graphs where grid overhead isn't worth it.
fn force_collide_brute(
    x: &mut [f32],
    y: &mut [f32],
    radii: &[f32],
    iterations: u32,
) {
    let n = x.len();
    for _ in 0..iterations {
        for i in 0..n {
            for j in (i + 1)..n {
                resolve_overlap(x, y, radii, i, j);
            }
        }
    }
}

// ── Force: Center (X + Y positioning) ──────────────────────────────────────

/// d3.forceX(0).strength(s) + d3.forceY(0).strength(s) combined.
///
/// Pulls every node toward `(center_x, center_y)` with a gentle spring.
/// LogSeq uses strength = 0.02, centered at origin (0, 0).
#[allow(clippy::too_many_arguments)]
pub fn force_center(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    center_x: f32,
    center_y: f32,
    strength: f32,
    alpha: f32,
) {
    for i in 0..x.len() {
        vx[i] += (center_x - x[i]) * strength * alpha;
        vy[i] += (center_y - y[i]) * strength * alpha;
    }
}

// ── Force: Cluster (cohesion toward cluster centroid) ────────────────────────

/// Cluster cohesion force: pulls nodes toward their cluster centroid.
///
/// Each node is assigned a `cluster_id`. For each cluster, compute the centroid
/// of all member nodes, then apply a spring force pulling each node toward its
/// cluster centroid. Singleton clusters (count <= 1) are skipped.
///
/// `strength` is 0-1 user-facing knob; `alpha` is the simulation alpha.
pub fn force_cluster(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    cluster_ids: &[u32],
    strength: f32,
    alpha: f32,
) {
    if strength < 0.001 || x.is_empty() {
        return;
    }
    let n = x.len();
    if cluster_ids.len() != n {
        return;
    }

    let max_cluster = cluster_ids.iter().copied().max().unwrap_or(0) as usize;
    let mut cx = vec![0.0f32; max_cluster + 1];
    let mut cy = vec![0.0f32; max_cluster + 1];
    let mut counts = vec![0u32; max_cluster + 1];

    for i in 0..n {
        let c = cluster_ids[i] as usize;
        cx[c] += x[i];
        cy[c] += y[i];
        counts[c] += 1;
    }

    for c in 0..=max_cluster {
        if counts[c] > 0 {
            cx[c] /= counts[c] as f32;
            cy[c] /= counts[c] as f32;
        }
    }

    let effective = strength * 0.05 * alpha;
    for i in 0..n {
        let c = cluster_ids[i] as usize;
        if counts[c] <= 1 {
            continue;
        }
        vx[i] += (cx[c] - x[i]) * effective;
        vy[i] += (cy[c] - y[i]) * effective;
    }
}

// ── Semantic Attraction ─────────────────────────────────────────────────────

/// Pulls semantically similar nodes toward each other.
/// Operates on pre-computed KNN pairs (not computed per-tick).
/// Uses a spring model: attracts only when nodes are farther than 50% of ideal_distance.
pub fn force_semantic(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    neighbors: &[(usize, usize, f32)], // (sim_idx_a, sim_idx_b, similarity)
    strength: f32,
    ideal_distance: f32,
    alpha: f32,
) {
    if strength < 0.001 || neighbors.is_empty() {
        return;
    }
    let n = x.len();
    let half_ideal = ideal_distance * 0.5;
    let effective = strength * 0.1 * alpha;

    for &(a, b, similarity) in neighbors {
        if a >= n || b >= n {
            continue;
        }
        let dx = x[b] - x[a];
        let dy = y[b] - y[a];
        let dist = (dx * dx + dy * dy).sqrt().max(1.0);

        // Only attract when beyond half of ideal distance (prevents piling)
        if dist <= half_ideal {
            continue;
        }

        // Force proportional to similarity and excess distance
        let pull = effective * similarity * (dist - half_ideal) / dist;
        vx[a] += dx * pull;
        vy[a] += dy * pull;
        vx[b] -= dx * pull;
        vy[b] -= dy * pull;
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn link_attracts_distant_nodes() {
        let x = vec![0.0, 200.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let edges = vec![(0, 1)];
        let weights = vec![1.0];
        let degrees = vec![1, 1];

        force_link(&x, &y, &mut vx, &mut vy, &edges, &weights, &degrees, 180.0, 0.0, 1.0);

        // Nodes at distance 200 with link_distance 180 → should attract slightly.
        // Node 0 should move rightward (positive vx), node 1 leftward (negative vx).
        assert!(vx[0] > 0.0, "node 0 should move right, got {}", vx[0]);
        assert!(vx[1] < 0.0, "node 1 should move left, got {}", vx[1]);
    }

    #[test]
    fn link_repels_close_nodes() {
        let x = vec![0.0, 50.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let edges = vec![(0, 1)];
        let weights = vec![1.0];
        let degrees = vec![1, 1];

        force_link(&x, &y, &mut vx, &mut vy, &edges, &weights, &degrees, 180.0, 0.0, 1.0);

        // Nodes at distance 50 with link_distance 180 → should push apart.
        assert!(vx[0] < 0.0, "node 0 should move left, got {}", vx[0]);
        assert!(vx[1] > 0.0, "node 1 should move right, got {}", vx[1]);
    }

    #[test]
    fn many_body_repels() {
        let x = vec![0.0, 50.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];

        force_many_body(&x, &y, &mut vx, &mut vy, -600.0, 600.0, 1.0, 1.0);

        // Negative strength → repulsion. Node 0 should be pushed left, node 1 right.
        assert!(vx[0] < 0.0, "node 0 should be repelled left, got {}", vx[0]);
        assert!(vx[1] > 0.0, "node 1 should be repelled right, got {}", vx[1]);
    }

    #[test]
    fn collide_separates_overlap() {
        let mut x = vec![0.0, 10.0];
        let mut y = vec![0.0, 0.0];
        let radii = vec![26.0, 26.0]; // min_dist = 52, actual dist = 10

        force_collide(&mut x, &mut y, &radii, 2);

        // After collision, nodes should be at least 52 apart.
        let dist = ((x[1] - x[0]).powi(2) + (y[1] - y[0]).powi(2)).sqrt();
        assert!(
            dist >= 51.0, // Allow small floating point tolerance
            "nodes should be separated to ~52, got dist {}",
            dist
        );
    }

    #[test]
    fn collide_no_effect_when_far() {
        let mut x = vec![0.0, 100.0];
        let mut y = vec![0.0, 0.0];
        let radii = vec![26.0, 26.0]; // min_dist = 52, actual dist = 100
        let x_orig = x.clone();

        force_collide(&mut x, &mut y, &radii, 2);

        assert_eq!(x, x_orig, "nodes should not move when not overlapping");
    }

    #[test]
    fn center_pulls_toward_origin() {
        let x = vec![100.0, -50.0];
        let y = vec![200.0, -100.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];

        force_center(&x, &y, &mut vx, &mut vy, 0.0, 0.0, 0.02, 1.0);

        // Node 0 at (100, 200) should be pulled toward (0, 0).
        assert!(vx[0] < 0.0, "node 0 should be pulled left");
        assert!(vy[0] < 0.0, "node 0 should be pulled up");
        // Node 1 at (-50, -100) should be pulled toward (0, 0).
        assert!(vx[1] > 0.0, "node 1 should be pulled right");
        assert!(vy[1] > 0.0, "node 1 should be pulled down");
    }

    #[test]
    fn center_strength_scales() {
        let x = vec![100.0];
        let y = vec![0.0];
        let mut vx1 = vec![0.0];
        let mut vy1 = vec![0.0];
        let mut vx2 = vec![0.0];
        let mut vy2 = vec![0.0];

        force_center(&x, &y, &mut vx1, &mut vy1, 0.0, 0.0, 0.02, 1.0);
        force_center(&x, &y, &mut vx2, &mut vy2, 0.0, 0.0, 0.04, 1.0);

        // Double strength → double velocity change.
        assert!((vx2[0] - vx1[0] * 2.0).abs() < f32::EPSILON);
    }

    #[test]
    fn link_bias_respects_degree() {
        let x = vec![0.0, 200.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let edges = vec![(0, 1)];
        let weights = vec![1.0];
        let degrees = vec![10, 1]; // node 0 is a hub

        force_link(&x, &y, &mut vx, &mut vy, &edges, &weights, &degrees, 180.0, 0.0, 1.0);

        // Hub (degree 10) should move less than leaf (degree 1).
        assert!(
            vx[0].abs() < vx[1].abs(),
            "hub should move less: hub={}, leaf={}",
            vx[0].abs(),
            vx[1].abs()
        );
    }

    #[test]
    fn link_weight_shortens_distance() {
        // Two nodes at distance 200. Weight=1 with link_distance=200 → equilibrium.
        // Weight=3 → effective distance = 200/3 ≈ 67 → should attract strongly.
        let x = vec![0.0, 200.0];
        let y = vec![0.0, 0.0];
        let mut vx_w1 = vec![0.0, 0.0];
        let mut vy_w1 = vec![0.0, 0.0];
        let mut vx_w3 = vec![0.0, 0.0];
        let mut vy_w3 = vec![0.0, 0.0];
        let edges = vec![(0, 1)];
        let degrees = vec![1, 1];

        force_link(&x, &y, &mut vx_w1, &mut vy_w1, &edges, &[1.0], &degrees, 200.0, 0.0, 1.0);
        force_link(&x, &y, &mut vx_w3, &mut vy_w3, &edges, &[3.0], &degrees, 200.0, 0.0, 1.0);

        // Weight=1 at exact distance → near zero force. Weight=3 → strong attraction.
        assert!(
            vx_w3[0].abs() > vx_w1[0].abs(),
            "higher weight should produce stronger force: w1={}, w3={}",
            vx_w1[0].abs(),
            vx_w3[0].abs()
        );
    }

    #[test]
    fn cluster_force_pulls_toward_centroid() {
        // Two clusters: {0,1} centered around (-90, 10), {2,3} centered around (90, 10).
        let x = vec![-100.0, -80.0, 80.0, 100.0];
        let y = vec![0.0, 20.0, 0.0, 20.0];
        let mut vx = vec![0.0; 4];
        let mut vy = vec![0.0; 4];
        let cluster_ids = vec![0u32, 0, 1, 1];

        force_cluster(&x, &y, &mut vx, &mut vy, &cluster_ids, 0.5, 1.0);

        // Node 0 at (-100, 0), centroid of cluster 0 is (-90, 10).
        // Should be pulled right (toward -90) and down (toward 10).
        assert!(vx[0] > 0.0, "node 0 should move right toward centroid");
        assert!(vy[0] > 0.0, "node 0 should move down toward centroid");
    }

    #[test]
    fn cluster_force_skips_singletons() {
        let x = vec![100.0, -100.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0; 2];
        let mut vy = vec![0.0; 2];
        // Each node in its own cluster → singleton → no force applied.
        let cluster_ids = vec![0u32, 1];

        force_cluster(&x, &y, &mut vx, &mut vy, &cluster_ids, 1.0, 1.0);

        assert_eq!(vx[0], 0.0, "singleton cluster should not produce force");
        assert_eq!(vx[1], 0.0, "singleton cluster should not produce force");
    }

    #[test]
    fn cluster_force_zero_strength_noop() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0; 2];
        let mut vy = vec![0.0; 2];
        let cluster_ids = vec![0u32, 0];

        force_cluster(&x, &y, &mut vx, &mut vy, &cluster_ids, 0.0, 1.0);

        assert_eq!(vx[0], 0.0, "zero strength should be a no-op");
        assert_eq!(vx[1], 0.0, "zero strength should be a no-op");
    }

}
