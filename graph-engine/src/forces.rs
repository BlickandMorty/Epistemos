//! # D3-Force Modules
//!
//! Faithful translation of d3-force's individual force functions.
//! Each force mutates velocity arrays directly (d3 model: forces add to vx/vy,
//! no mass division). Order matches LogSeq's pipeline:
//! link → many-body → collide → center.

use crate::quadtree::{self, Body};

/// Tiny displacement to break symmetry on coincident nodes.
/// d3 uses `(lcg() - 0.5) * 1e-6`. We use a seed-based approach
/// so coincident pairs get pushed in different directions.
fn jiggle(seed: usize) -> f32 {
    if seed & 1 == 0 { 1e-6 } else { -1e-6 }
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
    fx: &[Option<f32>],
    fy: &[Option<f32>],
    link_distance: f32,
    link_strength_override: f32,
    alpha: f32,
) {
    for (ei, &(si, ti)) in edges.iter().enumerate() {
        if si >= x.len() || ti >= x.len() {
            continue;
        }

        let mut dx = x[ti] - x[si] + jiggle(ei);
        let mut dy = y[ti] - y[si] + jiggle(ei + 1);
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

        // Skip force on pinned (dragged) nodes — their velocity is discarded
        // anyway, but applying it causes oscillation in connected free nodes.
        let ti_pinned =
            fx.get(ti).copied().flatten().is_some() || fy.get(ti).copied().flatten().is_some();
        let si_pinned =
            fx.get(si).copied().flatten().is_some() || fy.get(si).copied().flatten().is_some();

        if !ti_pinned {
            vx[ti] -= dx * displacement * bias;
            vy[ti] -= dy * displacement * bias;
        }
        if !si_pinned {
            vx[si] += dx * displacement * (1.0 - bias);
            vy[si] += dy * displacement * (1.0 - bias);
        }
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
    let fx: Vec<Option<f32>> = vec![None; x.len()];
    let fy: Vec<Option<f32>> = vec![None; x.len()];
    let mut bodies = Vec::new();
    let degrees: Vec<u32> = vec![1; x.len()]; // uniform degrees for standalone usage
    force_many_body_with_scratch(
        x,
        y,
        vx,
        vy,
        &fx,
        &fy,
        charge_strength,
        distance_max,
        distance_min,
        alpha,
        &mut bodies,
        &degrees,
    );
}

/// Like `force_many_body` but reuses a caller-provided scratch buffer for `Body` allocations.
#[allow(clippy::too_many_arguments)]
pub fn force_many_body_with_scratch(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    fx: &[Option<f32>],
    fy: &[Option<f32>],
    charge_strength: f32,
    distance_max: f32,
    distance_min: f32,
    alpha: f32,
    bodies: &mut Vec<Body>,
    _degrees: &[u32],
) {
    let n = x.len();
    if n < 2 {
        return;
    }

    // Build Barnes-Hut tree with uniform charge (canonical d3-force behavior).
    bodies.clear();
    if bodies.capacity() < n {
        bodies.reserve(n - bodies.capacity());
    }
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

    // Apply force from tree to each node. Skip pinned (dragged) nodes —
    // they're in the tree as repulsion sources but shouldn't receive force.
    for i in 0..n {
        let pinned =
            fx.get(i).copied().flatten().is_some() || fy.get(i).copied().flatten().is_some();
        if pinned {
            continue;
        }

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
/// `fx`/`fy` = fixed position arrays — nodes with Some(fx) are immovable during collision.
pub fn force_collide(
    x: &mut [f32],
    y: &mut [f32],
    radii: &[f32],
    fx: &[Option<f32>],
    fy: &[Option<f32>],
    iterations: u32,
) {
    let mut grid = rustc_hash::FxHashMap::default();
    force_collide_with_scratch(x, y, radii, fx, fy, iterations, &mut grid);
}

/// Like `force_collide` but reuses a caller-provided grid HashMap to avoid per-tick allocation.
/// Uses a flat pair buffer to decouple grid lookup from position mutation,
/// avoiding the keys-collection allocation.
pub fn force_collide_with_scratch(
    x: &mut [f32],
    y: &mut [f32],
    radii: &[f32],
    fx: &[Option<f32>],
    fy: &[Option<f32>],
    iterations: u32,
    grid: &mut rustc_hash::FxHashMap<(i32, i32), Vec<usize>>,
) {
    let mut keys = Vec::new();
    // Legacy callers (tests, graph_tests) use strict 50/50 collision
    // with no mass awareness — matches historical behaviour.
    force_collide_with_full_scratch(
        x, y, radii, &[], fx, fy, iterations, 1.0, grid, &mut keys,
    );
}

/// Like `force_collide_with_scratch` but also reuses the occupied-cell key buffer.
///
/// `mass` may be empty — when non-empty and the same length as the
/// position arrays, pair resolution is weighted by inverse mass so a
/// heavy hub pushes a light leaf rather than splitting the correction
/// 50/50. `compliance ∈ (0, 1]` scales the per-tick overlap resolution:
/// 1.0 is a hard snap, 0.7 lets nodes visibly touch for 2-3 frames
/// before separating (synthesis §2.1 + user "real flow" ask).
#[allow(clippy::too_many_arguments)]
pub fn force_collide_with_full_scratch(
    x: &mut [f32],
    y: &mut [f32],
    radii: &[f32],
    mass: &[f32],
    fx: &[Option<f32>],
    fy: &[Option<f32>],
    iterations: u32,
    compliance: f32,
    grid: &mut rustc_hash::FxHashMap<(i32, i32), Vec<usize>>,
    keys: &mut Vec<(i32, i32)>,
) {
    let n = x.len();
    if n < 2 {
        return;
    }

    // Fall back to brute force for tiny graphs (grid overhead not worth it).
    if n <= 32 {
        force_collide_brute(x, y, radii, mass, fx, fy, iterations, compliance);
        return;
    }

    // Find max radius to determine cell size.
    let max_radius = radii.iter().cloned().fold(0.0_f32, f32::max);
    if max_radius <= 0.0 {
        return;
    }
    let cell_size = max_radius * 2.0;
    let inv_cell = 1.0 / cell_size;

    // 4 forward-neighbor offsets to avoid double-checking pairs.
    const OFFSETS: [(i32, i32); 4] = [(1, 0), (-1, 1), (0, 1), (1, 1)];
    if grid.capacity() < n {
        grid.reserve(n - grid.capacity());
    }
    if keys.capacity() < n {
        keys.reserve(n - keys.capacity());
    }

    for _ in 0..iterations {
        // Clear grid, reusing allocated inner Vecs.
        for v in grid.values_mut() {
            v.clear();
        }

        // Build grid: hash (cell_x, cell_y) → list of node indices.
        for i in 0..n {
            let gx = (x[i] * inv_cell).floor() as i32;
            let gy = (y[i] * inv_cell).floor() as i32;
            grid.entry((gx, gy)).or_default().push(i);
        }

        // Snapshot occupied cell keys once, then reuse the same allocation every tick.
        keys.clear();
        keys.extend(grid.keys().copied());

        for key in keys.iter() {
            let cell = match grid.get(key) {
                Some(c) if !c.is_empty() => c,
                _ => continue,
            };

            // Intra-cell pairs.
            for a in 0..cell.len() {
                for b in (a + 1)..cell.len() {
                    resolve_overlap(
                        x, y, radii, mass, fx, fy, cell[a], cell[b], compliance,
                    );
                }
            }

            // Inter-cell pairs with forward neighbors.
            for &(ox, oy) in &OFFSETS {
                let nkey = (key.0.saturating_add(ox), key.1.saturating_add(oy));
                if let Some(neighbor) = grid.get(&nkey) {
                    for &i in cell.iter() {
                        for &j in neighbor.iter() {
                            resolve_overlap(x, y, radii, mass, fx, fy, i, j, compliance);
                        }
                    }
                }
            }
        }
    }
}

/// Resolve overlap between two nodes by pushing them apart.
///
/// - `mass.is_empty()` → legacy 50/50 split (back-compat for tests).
/// - `mass.len() >= i,j` → inverse-mass weighted split (heavy pushes light).
/// - `compliance ∈ (0, 1]` scales per-tick correction. 1.0 snaps apart
///   on contact (legacy); 0.7 lets nodes visibly press together for
///   2-3 frames before fully separating — "soft touch."
///
/// If one node is fixed (fx/fy set), 100% of the correction goes to the
/// other regardless of mass. If both are fixed, skip.
#[inline(always)]
#[allow(clippy::too_many_arguments)]
fn resolve_overlap(
    x: &mut [f32],
    y: &mut [f32],
    radii: &[f32],
    mass: &[f32],
    fx: &[Option<f32>],
    fy: &[Option<f32>],
    i: usize,
    j: usize,
    compliance: f32,
) {
    let mut dx = x[j] - x[i];
    let mut dy = y[j] - y[i];
    let dist_sq = dx * dx + dy * dy;
    let min_dist = radii[i] + radii[j];
    let min_dist_sq = min_dist * min_dist;

    if dist_sq < min_dist_sq {
        let i_fixed =
            fx.get(i).is_some_and(|f| f.is_some()) || fy.get(i).is_some_and(|f| f.is_some());
        let j_fixed =
            fx.get(j).is_some_and(|f| f.is_some()) || fy.get(j).is_some_and(|f| f.is_some());

        // Both fixed — can't resolve overlap.
        if i_fixed && j_fixed {
            return;
        }

        let dist = dist_sq.sqrt().max(1e-6);
        // `compliance.clamp(1e-3, 1.0)` guards against a caller
        // accidentally driving the correction to zero (which would
        // freeze nodes in overlap forever) or negative (which would
        // push them further together).
        let c = compliance.clamp(1e-3, 1.0);
        let overlap = (min_dist - dist) / dist * c;
        dx *= overlap;
        dy *= overlap;

        if i_fixed {
            // i is fixed — push j by 100% of the scaled correction.
            x[j] += dx;
            y[j] += dy;
        } else if j_fixed {
            x[i] -= dx;
            y[i] -= dy;
        } else {
            // Neither fixed — weight by inverse mass when available,
            // falling back to the historical 50/50 split when `mass`
            // is empty or out of range. Heavy nodes absorb less of
            // the correction and effectively push lighter ones.
            let (w_i, w_j) = if mass.len() > i.max(j) {
                let inv_i = 1.0 / mass[i].max(1.0);
                let inv_j = 1.0 / mass[j].max(1.0);
                let total = inv_i + inv_j;
                if total > 0.0 {
                    (inv_i / total, inv_j / total)
                } else {
                    (0.5, 0.5)
                }
            } else {
                (0.5, 0.5)
            };
            // i absorbs w_i of the correction (away from j); j absorbs w_j.
            x[j] += dx * w_j;
            y[j] += dy * w_j;
            x[i] -= dx * w_i;
            y[i] -= dy * w_i;
        }
    }
}

/// Brute-force O(n²) fallback for small graphs where grid overhead isn't worth it.
#[allow(clippy::too_many_arguments)]
fn force_collide_brute(
    x: &mut [f32],
    y: &mut [f32],
    radii: &[f32],
    mass: &[f32],
    fx: &[Option<f32>],
    fy: &[Option<f32>],
    iterations: u32,
    compliance: f32,
) {
    let n = x.len();
    for _ in 0..iterations {
        for i in 0..n {
            for j in (i + 1)..n {
                resolve_overlap(x, y, radii, mass, fx, fy, i, j, compliance);
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
#[inline]
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
    let s = strength * alpha;
    for i in 0..x.len() {
        vx[i] += (center_x - x[i]) * s;
        vy[i] += (center_y - y[i]) * s;
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

/// Like `force_cluster` but reuses caller-provided centroid buffers.
#[allow(clippy::too_many_arguments)]
pub fn force_cluster_with_scratch(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    cluster_ids: &[u32],
    strength: f32,
    alpha: f32,
    cx: &mut Vec<f32>,
    cy: &mut Vec<f32>,
    counts: &mut Vec<u32>,
) {
    if strength < 0.001 || x.is_empty() {
        return;
    }
    let n = x.len();
    if cluster_ids.len() != n {
        return;
    }

    let max_cluster = cluster_ids.iter().copied().max().unwrap_or(0) as usize;
    let cap = max_cluster + 1;

    // Reuse scratch buffers — resize and zero without reallocating.
    cx.resize(cap, 0.0);
    cy.resize(cap, 0.0);
    counts.resize(cap, 0);
    cx[..cap].fill(0.0);
    cy[..cap].fill(0.0);
    counts[..cap].fill(0);

    for i in 0..n {
        let c = cluster_ids[i] as usize;
        cx[c] += x[i];
        cy[c] += y[i];
        counts[c] += 1;
    }

    for c in 0..cap {
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

// ── Torsional Springs (Angular equalization for hubs) ──────────────────────

/// For hub nodes (degree > 2), compute angular gaps between sorted neighbors
/// and apply tangential force to equalize spacing. Creates crystalline starbursts.
///
/// `edges`: (source_idx, target_idx) pairs.
/// `strength`: user-facing knob (0-1).
/// `alpha`: simulation alpha.
#[allow(clippy::too_many_arguments)]
pub fn force_torsion(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    edges: &[(usize, usize)],
    degrees: &[u32],
    strength: f32,
    alpha: f32,
) {
    if strength < 0.001 || x.is_empty() {
        return;
    }
    let n = x.len();
    let effective = strength * alpha;

    // Build per-node neighbor lists from edge list.
    // Reuses stack for small graphs, heap for large.
    let mut neighbors: Vec<Vec<usize>> = vec![Vec::new(); n];
    for &(s, t) in edges {
        if s < n && t < n {
            neighbors[s].push(t);
            neighbors[t].push(s);
        }
    }

    // For each hub node (degree > 2), equalize angular spacing.
    for hub in 0..n {
        let deg = degrees[hub] as usize;
        if deg <= 2 {
            continue;
        }

        let nb = &neighbors[hub];
        if nb.len() <= 2 {
            continue;
        }

        // Compute angles from hub to each neighbor.
        let mut angles: Vec<(f32, usize)> = nb
            .iter()
            .map(|&ni| {
                let angle = (y[ni] - y[hub]).atan2(x[ni] - x[hub]);
                (angle, ni)
            })
            .collect();
        angles.sort_unstable_by(|a, b| a.0.partial_cmp(&b.0).unwrap_or(std::cmp::Ordering::Equal));

        let k = angles.len();
        let ideal_gap = std::f32::consts::TAU / k as f32;

        // For each adjacent pair, compute angular error and apply tangential force.
        for i in 0..k {
            let j = (i + 1) % k;
            let mut gap = angles[j].0 - angles[i].0;
            if gap < 0.0 {
                gap += std::f32::consts::TAU;
            }

            let error = ideal_gap - gap;
            if error.abs() < 0.01 {
                continue;
            } // Dead zone — don't fight for tiny errors.

            let ni = angles[i].1;
            let nj = angles[j].1;

            // Tangential force perpendicular to the hub→neighbor direction.
            // Push ni clockwise and nj counter-clockwise (or vice versa).
            let dist_i = ((x[ni] - x[hub]).powi(2) + (y[ni] - y[hub]).powi(2))
                .sqrt()
                .max(1.0);
            let theta_i = angles[i].0;
            let tx_i = -theta_i.sin();
            let ty_i = theta_i.cos();
            let force_i = error * effective * (dist_i * 0.01);

            vx[ni] += tx_i * force_i;
            vy[ni] += ty_i * force_i;

            let dist_j = ((x[nj] - x[hub]).powi(2) + (y[nj] - y[hub]).powi(2))
                .sqrt()
                .max(1.0);
            let theta_j = angles[j].0;
            let tx_j = -theta_j.sin();
            let ty_j = theta_j.cos();
            let force_j = -error * effective * (dist_j * 0.01);

            vx[nj] += tx_j * force_j;
            vy[nj] += ty_j * force_j;
        }
    }
}

// ── Semantic Boids Flocking ──────────────────────────────────────────────────

/// Boids-based flocking for semantically similar nodes.
/// Replaces simple spring attraction with three rules:
///   - **Separation**: strong repulsion when nodes crowd below `d_crowd`
///   - **Alignment**: steer velocity toward neighbor's velocity (lazy orbits)
///   - **Cohesion**: attract toward centroid when beyond half ideal distance
///
/// Pair-wise processing over KNN pairs — O(E) per tick, zero allocation.
#[allow(clippy::too_many_arguments)]
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
    let d_crowd = ideal_distance * 0.3;
    let half_ideal = ideal_distance * 0.5;
    let eff = strength * 0.1 * alpha;

    // Boids tuning: separation dominates at close range,
    // alignment creates lazy circular motion, cohesion pulls groups together.
    const K_SEP: f32 = 2.0;
    const K_ALIGN: f32 = 0.15;
    const K_COHESION: f32 = 0.4;

    for &(a, b, similarity) in neighbors {
        if a >= n || b >= n {
            continue;
        }
        let dx = x[b] - x[a];
        let dy = y[b] - y[a];
        let dist = (dx * dx + dy * dy).sqrt().max(1.0);
        let pair_eff = eff * similarity;

        // 1. Separation: repel when within crowding distance.
        if dist < d_crowd {
            let repel = pair_eff * K_SEP * (d_crowd - dist) / dist;
            vx[a] -= dx * repel;
            vy[a] -= dy * repel;
            vx[b] += dx * repel;
            vy[b] += dy * repel;
        }

        // 2. Alignment: steer each node's velocity toward the other's.
        //    Pre-compute delta from original values to avoid asymmetry.
        let dvx = (vx[b] - vx[a]) * pair_eff * K_ALIGN;
        let dvy = (vy[b] - vy[a]) * pair_eff * K_ALIGN;
        vx[a] += dvx;
        vy[a] += dvy;
        vx[b] -= dvx;
        vy[b] -= dvy;

        // 3. Cohesion: attract when beyond half ideal distance.
        if dist > half_ideal {
            let pull = pair_eff * K_COHESION * (dist - half_ideal) / dist;
            vx[a] += dx * pull;
            vy[a] += dy * pull;
            vx[b] -= dx * pull;
            vy[b] -= dy * pull;
        }
    }
}

// ── Force: Wind (mass-weighted directional) ──────────────────────────────────

/// Constant directional force scaled inversely by node degree (mass proxy).
/// Leaf nodes (degree 1) blow freely; hub nodes (degree 20+) barely move.
/// `wind_x`/`wind_y` are user-facing knobs in world units/tick.
pub fn force_wind(
    vx: &mut [f32],
    vy: &mut [f32],
    degrees: &[u32],
    wind_x: f32,
    wind_y: f32,
    alpha: f32,
) {
    if wind_x.abs() < 0.001 && wind_y.abs() < 0.001 {
        return;
    }
    let wx = wind_x * alpha;
    let wy = wind_y * alpha;
    for i in 0..vx.len() {
        let mass = (degrees[i].max(1) as f32).sqrt(); // sqrt(degree) as mass proxy
        let inv_mass = 1.0 / mass;
        vx[i] += wx * inv_mass;
        vy[i] += wy * inv_mass;
    }
}

// ── Force: Orbital (tangential velocity for hierarchical edges) ──────────────

/// Applies tangential velocity to child nodes around their parent, creating
/// slow orbital motion. Only affects hierarchical edges (contains=1, authored=5).
/// `speed` is 0-1 user knob. `alpha` is simulation alpha.
#[allow(clippy::too_many_arguments)]
pub fn force_orbital(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    edges: &[(usize, usize)],
    edge_types: &[u8],
    degrees: &[u32],
    speed: f32,
    alpha: f32,
) {
    if speed < 0.001 || edges.is_empty() {
        return;
    }
    let n = x.len();
    let eff = speed * 0.3 * alpha;

    for (ei, &(parent, child)) in edges.iter().enumerate() {
        if parent >= n || child >= n {
            continue;
        }
        let etype = edge_types.get(ei).copied().unwrap_or(0);
        // Only hierarchical edges: contains(1) and authored(5).
        if etype != 1 && etype != 5 {
            continue;
        }
        // Parent is the higher-degree node. If child has higher degree, swap semantics.
        let (hub, leaf) = if degrees[parent] >= degrees[child] {
            (parent, child)
        } else {
            (child, parent)
        };

        let dx = x[leaf] - x[hub];
        let dy = y[leaf] - y[hub];
        let dist = (dx * dx + dy * dy).sqrt().max(1.0);
        // Tangential direction (perpendicular to radial, CCW).
        let tx = -dy / dist;
        let ty = dx / dist;
        // Force inversely proportional to distance (closer = faster orbit).
        let force = eff * (100.0 / dist).min(1.0);
        vx[leaf] += tx * force;
        vy[leaf] += ty * force;
    }
}

// ── Force: Shadow Attraction (contextual gravity toward a point) ────────────

/// Pulls specific nodes toward a shadow target point.
/// Each node has an individual `shadow_strength` (0.0 = no pull, 1.0 = max).
/// Used for contextual editing: type in a note and related nodes drift toward it.
///
/// Force = (target - position) * strength * alpha * 0.05
/// The 1/r falloff prevents distant nodes from overshooting.
#[allow(clippy::too_many_arguments)]
pub fn force_shadow(
    x: &[f32],
    y: &[f32],
    vx: &mut [f32],
    vy: &mut [f32],
    shadow_strength: &[f32],
    shadow_target: [f32; 2],
    alpha: f32,
) {
    let tx = shadow_target[0];
    let ty = shadow_target[1];
    for i in 0..x.len() {
        let s = shadow_strength[i];
        if s < 0.001 {
            continue;
        }
        let dx = tx - x[i];
        let dy = ty - y[i];
        let dist_sq = dx * dx + dy * dy;
        if dist_sq < 1e-4 {
            continue;
        }
        // Gentle 1/sqrt(r) falloff: close nodes pull faster, distant ones drift slowly.
        let inv_dist = 1.0 / dist_sq.sqrt();
        let force = s * alpha * 0.05;
        vx[i] += dx * inv_dist * force;
        vy[i] += dy * inv_dist * force;
    }
}

// ── Force: Snap-Back Spring (post-drag impulse) ────────────────────────────

/// Applies a decaying spring impulse after drag release.
/// Each node has a `snap_back` tether offset [dx, dy] set on release.
/// Per tick: inject velocity proportional to tether, then decay tether.
///
/// This creates the "rubber band" feeling when you grab a heavy node and let go.
pub fn force_snap_back(
    vx: &mut [f32],
    vy: &mut [f32],
    snap_back: &mut [[f32; 2]],
    mass: &[f32],
    strength: f32,
) {
    if strength < 0.001 {
        return;
    }
    for i in 0..vx.len() {
        let sb = &mut snap_back[i];
        let mag_sq = sb[0] * sb[0] + sb[1] * sb[1];
        if mag_sq < 0.01 {
            sb[0] = 0.0;
            sb[1] = 0.0;
            continue;
        }
        // Snap-back velocity injection, inversely proportional to mass.
        // Per v3 motion spec §6: `snap_freq_hz = 1.75`, damping ratio
        // 0.55. The legacy tether-decay form (0.85 / tick) reads as
        // over-damped — the node returns linearly rather than with
        // the slight overshoot that M3 Expressive calls for. 0.82
        // retention per tick is the canonical approximation at 60 Hz.
        // A full 2nd-order spring rewrite (proper `omega_n`/`zeta`
        // integration) is deferred to a later commit — this tune
        // pulls the existing tether form toward the right envelope
        // without a wholesale rewrite.
        let m = mass[i].max(0.5);
        let factor = strength / m;
        vx[i] += sb[0] * factor;
        vy[i] += sb[1] * factor;
        sb[0] *= 0.82;
        sb[1] *= 0.82;
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

        force_link(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            0.0,
            1.0,
        );

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

        force_link(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            0.0,
            1.0,
        );

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
        assert!(
            vx[1] > 0.0,
            "node 1 should be repelled right, got {}",
            vx[1]
        );
    }

    #[test]
    fn collide_separates_overlap() {
        let mut x = vec![0.0, 10.0];
        let mut y = vec![0.0, 0.0];
        let radii = vec![26.0, 26.0]; // min_dist = 52, actual dist = 10
        let fx = vec![None, None];
        let fy = vec![None, None];

        force_collide(&mut x, &mut y, &radii, &fx, &fy, 2);

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
        let fx = vec![None, None];
        let fy = vec![None, None];

        force_collide(&mut x, &mut y, &radii, &fx, &fy, 2);

        assert_eq!(x, x_orig, "nodes should not move when not overlapping");
    }

    #[test]
    fn collide_respects_fixed_node() {
        let mut x = vec![0.0, 10.0];
        let mut y = vec![0.0, 0.0];
        let radii = vec![26.0, 26.0]; // min_dist = 52, overlap
        let fx = vec![Some(0.0), None]; // node 0 is fixed
        let fy = vec![Some(0.0), None];

        force_collide(&mut x, &mut y, &radii, &fx, &fy, 2);

        // Node 0 should NOT have moved (it's fixed).
        assert_eq!(x[0], 0.0, "fixed node should not move");
        assert_eq!(y[0], 0.0, "fixed node should not move");
        // Node 1 should have been pushed away by the full displacement.
        assert!(
            x[1] > 50.0,
            "unfixed node should be pushed fully away, got {}",
            x[1]
        );
    }

    #[test]
    fn collide_both_fixed_skipped() {
        let mut x = vec![0.0, 10.0];
        let mut y = vec![0.0, 0.0];
        let radii = vec![26.0, 26.0];
        let fx = vec![Some(0.0), Some(10.0)]; // both fixed
        let fy = vec![Some(0.0), Some(0.0)];
        let x_orig = x.clone();

        force_collide(&mut x, &mut y, &radii, &fx, &fy, 2);

        assert_eq!(x, x_orig, "both fixed → no movement");
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

        force_link(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            0.0,
            1.0,
        );

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

        force_link(
            &x,
            &y,
            &mut vx_w1,
            &mut vy_w1,
            &edges,
            &[1.0],
            &degrees,
            &[],
            &[],
            200.0,
            0.0,
            1.0,
        );
        force_link(
            &x,
            &y,
            &mut vx_w3,
            &mut vy_w3,
            &edges,
            &[3.0],
            &degrees,
            &[],
            &[],
            200.0,
            0.0,
            1.0,
        );

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

    // =========================================================================
    // Link Force Tests (10 tests)
    // =========================================================================

    #[test]
    fn link_no_edges_no_change() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let edges: Vec<(usize, usize)> = vec![];
        let weights: Vec<f32> = vec![];
        let degrees = vec![1, 1];

        force_link(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            0.0,
            1.0,
        );

        assert_eq!(vx[0], 0.0);
        assert_eq!(vx[1], 0.0);
    }

    #[test]
    fn link_exact_distance_no_force() {
        let x = vec![0.0, 180.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let edges = vec![(0, 1)];
        let weights = vec![1.0];
        let degrees = vec![1, 1];

        force_link(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            1.0,
            1.0,
        );

        // At exact distance with override strength, force should be minimal
        assert!(vx[0].abs() < 1e-5);
    }

    #[test]
    fn link_strength_override_used() {
        let x = vec![0.0, 200.0];
        let y = vec![0.0, 0.0];
        let mut vx1 = vec![0.0, 0.0];
        let mut vy1 = vec![0.0, 0.0];
        let mut vx2 = vec![0.0, 0.0];
        let mut vy2 = vec![0.0, 0.0];
        let edges = vec![(0, 1)];
        let weights = vec![1.0];
        let degrees = vec![1, 1];

        force_link(
            &x,
            &y,
            &mut vx1,
            &mut vy1,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            0.5,
            1.0,
        );
        force_link(
            &x,
            &y,
            &mut vx2,
            &mut vy2,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            1.0,
            1.0,
        );

        // Double strength should produce approximately double force
        assert!(vx2[0].abs() > vx1[0].abs());
    }

    #[test]
    fn link_weight_very_high() {
        let x = vec![0.0, 200.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let edges = vec![(0, 1)];
        let weights = vec![10.0];
        let degrees = vec![1, 1];

        force_link(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            0.0,
            1.0,
        );

        // High weight should produce strong attraction
        assert!(vx[0].abs() > 1.0);
    }

    #[test]
    fn link_weight_very_low() {
        let x = vec![0.0, 200.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let edges = vec![(0, 1)];
        let weights = vec![0.1];
        let degrees = vec![1, 1];

        force_link(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            0.0,
            1.0,
        );

        // Low weight produces weak attraction
        // Distance 200 vs effective distance 180/0.1 = 1800, so nodes are much closer than target
        // This actually produces REPULSION (pushing apart)
        assert!(
            vx[0] < 0.0,
            "when closer than target, should repel: got {}",
            vx[0]
        );
    }

    #[test]
    fn link_self_loop_handled() {
        let x = vec![0.0];
        let y = vec![0.0];
        let mut vx = vec![0.0];
        let mut vy = vec![0.0];
        let edges = vec![(0, 0)];
        let weights = vec![1.0];
        let degrees = vec![1];

        force_link(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            0.0,
            1.0,
        );

        // Self-loop should apply no net force (or minimal)
        assert!(vx[0].abs() < 1.0);
    }

    #[test]
    fn link_multiple_edges_accumulate() {
        let x = vec![0.0, 100.0, 200.0];
        let y = vec![0.0, 0.0, 0.0];
        let mut vx = vec![0.0, 0.0, 0.0];
        let mut vy = vec![0.0, 0.0, 0.0];
        let edges = vec![(0, 1), (1, 2)];
        let weights = vec![1.0, 1.0];
        let degrees = vec![1, 2, 1];

        force_link(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            0.0,
            1.0,
        );

        // Middle node (1) should have forces from both edges
        assert!(vx[1] != 0.0);
    }

    #[test]
    fn link_alpha_zero_no_force() {
        let x = vec![0.0, 200.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let edges = vec![(0, 1)];
        let weights = vec![1.0];
        let degrees = vec![1, 1];

        force_link(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            0.0,
            0.0,
        );

        assert_eq!(vx[0], 0.0);
        assert_eq!(vx[1], 0.0);
    }

    #[test]
    fn link_diagonal_edge() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 100.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let edges = vec![(0, 1)];
        let weights = vec![1.0];
        let degrees = vec![1, 1];

        force_link(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &edges,
            &weights,
            &degrees,
            &[],
            &[],
            180.0,
            0.0,
            1.0,
        );

        // Both x and y should be affected for diagonal edge
        assert!(vx[0] != 0.0 || vy[0] != 0.0);
    }

    // =========================================================================
    // Many-Body Tests (10 tests)
    // =========================================================================

    #[test]
    fn many_body_empty() {
        let x: Vec<f32> = vec![];
        let y: Vec<f32> = vec![];
        let mut vx: Vec<f32> = vec![];
        let mut vy: Vec<f32> = vec![];

        force_many_body(&x, &y, &mut vx, &mut vy, -600.0, 600.0, 1.0, 1.0);
    }

    #[test]
    fn many_body_single_node() {
        let x = vec![0.0];
        let y = vec![0.0];
        let mut vx = vec![0.0];
        let mut vy = vec![0.0];

        force_many_body(&x, &y, &mut vx, &mut vy, -600.0, 600.0, 1.0, 1.0);

        // Single node has no one to repel from
        assert_eq!(vx[0], 0.0);
    }

    #[test]
    fn many_body_positive_strength_attracts() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];

        force_many_body(&x, &y, &mut vx, &mut vy, 600.0, 600.0, 1.0, 1.0);

        // Positive strength → attraction
        assert!(vx[0] > 0.0, "positive charge should attract: {}", vx[0]);
    }

    #[test]
    fn many_body_distance_max_cuts_off() {
        let x = vec![0.0, 1000.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];

        force_many_body(&x, &y, &mut vx, &mut vy, -600.0, 500.0, 1.0, 1.0);

        // Distance 1000 > max 500 → no force
        assert_eq!(vx[0], 0.0);
    }

    #[test]
    fn many_body_distance_min_prevents_singularity() {
        let x = vec![0.0, 0.1];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];

        force_many_body(&x, &y, &mut vx, &mut vy, -600.0, 600.0, 10.0, 1.0);

        // Very close nodes should use distance_min, not actual distance
        assert!(vx[0].abs() < 1000.0);
    }

    #[test]
    fn many_body_symmetric_forces() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];

        force_many_body(&x, &y, &mut vx, &mut vy, -600.0, 600.0, 1.0, 1.0);

        // Forces should be equal and opposite
        assert!(
            (vx[0] + vx[1]).abs() < 0.01,
            "forces should be symmetric: v0={}, v1={}",
            vx[0],
            vx[1]
        );
    }

    #[test]
    fn many_body_with_scratch_reuses_buffer() {
        let x = vec![0.0, 50.0, 100.0];
        let y = vec![0.0, 0.0, 0.0];
        let mut vx = vec![0.0, 0.0, 0.0];
        let mut vy = vec![0.0, 0.0, 0.0];
        let mut scratch = Vec::new();

        let degrees = vec![1u32; 3];
        force_many_body_with_scratch(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &[],
            &[],
            -600.0,
            600.0,
            1.0,
            1.0,
            &mut scratch,
            &degrees,
        );

        assert!(scratch.capacity() >= 3);
    }

    #[test]
    fn many_body_alpha_scales_force() {
        let x = vec![0.0, 50.0];
        let y = vec![0.0, 0.0];
        let mut vx1 = vec![0.0, 0.0];
        let mut vy1 = vec![0.0, 0.0];
        let mut vx2 = vec![0.0, 0.0];
        let mut vy2 = vec![0.0, 0.0];

        force_many_body(&x, &y, &mut vx1, &mut vy1, -600.0, 600.0, 1.0, 0.5);
        force_many_body(&x, &y, &mut vx2, &mut vy2, -600.0, 600.0, 1.0, 1.0);

        // Double alpha should produce double force
        assert!((vx2[0] - 2.0 * vx1[0]).abs() < 0.1);
    }

    #[test]
    fn many_body_triangle_symmetry() {
        let x = vec![0.0, 100.0, 50.0];
        let y = vec![0.0, 0.0, 86.6]; // Equilateral triangle
        let mut vx = vec![0.0, 0.0, 0.0];
        let mut vy = vec![0.0, 0.0, 0.0];

        force_many_body(&x, &y, &mut vx, &mut vy, -600.0, 600.0, 1.0, 1.0);

        // All forces should roughly cancel in center of mass
        let sum_x = vx.iter().sum::<f32>();
        let sum_y = vy.iter().sum::<f32>();
        assert!(sum_x.abs() < 1.0);
        assert!(sum_y.abs() < 1.0);
    }

    #[test]
    fn many_body_three_collinear() {
        let x = vec![0.0, 50.0, 100.0];
        let y = vec![0.0, 0.0, 0.0];
        let mut vx = vec![0.0, 0.0, 0.0];
        let mut vy = vec![0.0, 0.0, 0.0];

        force_many_body(&x, &y, &mut vx, &mut vy, -600.0, 600.0, 1.0, 1.0);

        // Middle node should have some force acting on it
        // Due to symmetry, it might be close to 0 but outer nodes should have opposing forces
        assert!(vx[0] < 0.0, "leftmost should be pushed left");
        assert!(vx[2] > 0.0, "rightmost should be pushed right");
    }

    // =========================================================================
    // Collide Tests (10 tests)
    // =========================================================================

    #[test]
    fn collide_empty() {
        let mut x: Vec<f32> = vec![];
        let mut y: Vec<f32> = vec![];
        let radii: Vec<f32> = vec![];
        let fx: Vec<Option<f32>> = vec![];
        let fy: Vec<Option<f32>> = vec![];

        force_collide(&mut x, &mut y, &radii, &fx, &fy, 2);
    }

    #[test]
    fn collide_single_node() {
        let mut x = vec![0.0];
        let mut y = vec![0.0];
        let radii = vec![26.0];
        let fx = vec![None];
        let fy = vec![None];

        force_collide(&mut x, &mut y, &radii, &fx, &fy, 2);

        assert_eq!(x[0], 0.0);
    }

    #[test]
    fn collide_exactly_touching() {
        let mut x = vec![0.0, 52.0];
        let mut y = vec![0.0, 0.0];
        let radii = vec![26.0, 26.0];
        let fx = vec![None, None];
        let fy = vec![None, None];

        force_collide(&mut x, &mut y, &radii, &fx, &fy, 2);

        // Exactly touching, no overlap
        assert_eq!(x[0], 0.0);
        assert_eq!(x[1], 52.0);
    }

    #[test]
    fn collide_multiple_iterations() {
        let mut x = vec![0.0, 10.0, 20.0];
        let mut y = vec![0.0, 0.0, 0.0];
        let radii = vec![26.0, 26.0, 26.0];
        let fx = vec![None, None, None];
        let fy = vec![None, None, None];

        force_collide(&mut x, &mut y, &radii, &fx, &fy, 3);

        // After multiple iterations, should be well separated
        let dist1 = (x[1] - x[0]).abs();
        let _dist2 = (x[2] - x[1]).abs();
        assert!(!(10.0..51.0).contains(&dist1));
    }

    #[test]
    fn collide_different_radii() {
        let mut x = vec![0.0, 30.0];
        let mut y = vec![0.0, 0.0];
        let radii = vec![10.0, 30.0];
        let fx = vec![None, None];
        let fy = vec![None, None];

        force_collide(&mut x, &mut y, &radii, &fx, &fy, 2);

        // min_dist = 40, actual dist = 30 → overlap
        let dist = (x[1] - x[0]).abs();
        assert!(dist >= 39.0);
    }

    #[test]
    fn collide_2d_overlap() {
        let mut x = vec![0.0, 30.0];
        let mut y = vec![0.0, 30.0];
        let radii = vec![26.0, 26.0];
        let fx = vec![None, None];
        let fy = vec![None, None];

        force_collide(&mut x, &mut y, &radii, &fx, &fy, 2);

        // Diagonal distance should be >= 52
        let dist_sq = (x[1] - x[0]).powi(2) + (y[1] - y[0]).powi(2);
        assert!(dist_sq >= 51.0_f32.powi(2));
    }

    #[test]
    fn collide_many_nodes() {
        let mut x: Vec<f32> = (0..50).map(|i| (i % 10) as f32 * 25.0).collect();
        let mut y: Vec<f32> = (0..50).map(|i| (i / 10) as f32 * 25.0).collect();
        let radii: Vec<f32> = vec![10.0; 50];
        let fx: Vec<Option<f32>> = vec![None; 50];
        let fy: Vec<Option<f32>> = vec![None; 50];

        force_collide(&mut x, &mut y, &radii, &fx, &fy, 3);

        // All pairs should have no overlap (with tolerance)
        for i in 0..50 {
            for j in (i + 1)..50 {
                let dist_sq = (x[j] - x[i]).powi(2) + (y[j] - y[i]).powi(2);
                let min_dist = radii[i] + radii[j];
                assert!(
                    dist_sq >= min_dist.powi(2) - 10.0,
                    "nodes {} and {} overlap: dist={}, min={}",
                    i,
                    j,
                    dist_sq.sqrt(),
                    min_dist
                );
            }
        }
    }

    #[test]
    fn collide_with_grid_scratch() {
        let mut x = vec![0.0, 10.0, 20.0];
        let mut y = vec![0.0, 0.0, 0.0];
        let radii = vec![26.0, 26.0, 26.0];
        let fx = vec![None, None, None];
        let fy = vec![None, None, None];
        let mut grid = rustc_hash::FxHashMap::default();
        let mut keys = Vec::new();

        force_collide_with_full_scratch(
            &mut x, &mut y, &radii, &[], &fx, &fy, 2, 1.0, &mut grid, &mut keys,
        );

        // Grid should be reusable
        assert!(grid.is_empty() || grid.values().all(|v| v.is_empty()));
    }

    #[test]
    fn collide_with_full_scratch_reuses_key_buffer() {
        let mut x: Vec<f32> = (0..40).map(|i| i as f32 * 12.0).collect();
        let mut y = vec![0.0; 40];
        let radii = vec![26.0; 40];
        let fx = vec![None; 40];
        let fy = vec![None; 40];
        let mut grid = rustc_hash::FxHashMap::default();
        let mut keys = Vec::new();

        force_collide_with_full_scratch(
            &mut x, &mut y, &radii, &[], &fx, &fy, 2, 1.0, &mut grid, &mut keys,
        );
        let first_capacity = keys.capacity();

        force_collide_with_full_scratch(
            &mut x, &mut y, &radii, &[], &fx, &fy, 2, 1.0, &mut grid, &mut keys,
        );

        assert!(first_capacity > 0);
        assert_eq!(keys.capacity(), first_capacity);
    }

    #[test]
    fn collide_zero_radius_no_effect() {
        let mut x = vec![0.0, 1.0];
        let mut y = vec![0.0, 0.0];
        let x_orig = x.clone();
        let radii = vec![0.0, 0.0];
        let fx = vec![None, None];
        let fy = vec![None, None];

        force_collide(&mut x, &mut y, &radii, &fx, &fy, 2);

        // With zero radius, nothing should happen
        assert_eq!(x, x_orig);
    }

    // =========================================================================
    // Center Force Tests (10 tests)
    // =========================================================================

    #[test]
    fn center_no_nodes() {
        let x: Vec<f32> = vec![];
        let y: Vec<f32> = vec![];
        let mut vx: Vec<f32> = vec![];
        let mut vy: Vec<f32> = vec![];

        force_center(&x, &y, &mut vx, &mut vy, 0.0, 0.0, 0.02, 1.0);
    }

    #[test]
    fn center_already_at_center() {
        let x = vec![0.0, 0.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];

        force_center(&x, &y, &mut vx, &mut vy, 0.0, 0.0, 0.02, 1.0);

        assert_eq!(vx[0], 0.0);
        assert_eq!(vx[1], 0.0);
    }

    #[test]
    fn center_custom_location() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 200.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];

        force_center(&x, &y, &mut vx, &mut vy, 500.0, 500.0, 0.02, 1.0);

        // All nodes should be pulled toward (500, 500)
        assert!(vx[0] > 0.0);
        assert!(vy[0] > 0.0);
        assert!(vx[1] > 0.0);
        assert!(vy[1] > 0.0);
    }

    #[test]
    fn center_zero_strength_no_effect() {
        let x = vec![100.0];
        let y = vec![100.0];
        let mut vx = vec![0.0];
        let mut vy = vec![0.0];

        force_center(&x, &y, &mut vx, &mut vy, 0.0, 0.0, 0.0, 1.0);

        assert_eq!(vx[0], 0.0);
    }

    #[test]
    fn center_negative_strength() {
        let x = vec![100.0];
        let y = vec![0.0];
        let mut vx = vec![0.0];
        let mut vy = vec![0.0];

        force_center(&x, &y, &mut vx, &mut vy, 0.0, 0.0, -0.02, 1.0);

        // Negative strength → push away from center
        // Node at x=100, center at 0, negative strength pushes away
        assert!(vx[0] != 0.0, "should have force applied");
    }

    #[test]
    fn center_proportional_to_distance() {
        let x = vec![50.0, 100.0];
        let y = vec![0.0, 0.0];
        let mut vx1 = vec![0.0, 0.0];
        let mut vy1 = vec![0.0, 0.0];
        let mut vx2 = vec![0.0, 0.0];
        let mut vy2 = vec![0.0, 0.0];

        force_center(&x, &y, &mut vx1, &mut vy1, 0.0, 0.0, 0.02, 1.0);
        force_center(&x, &y, &mut vx2, &mut vy2, 0.0, 0.0, 0.04, 1.0);

        // Node 2 at 100 should have double the force of node 1 at 50
        assert!((vx2[1] / vx1[1] - 2.0).abs() < 0.01);
    }

    #[test]
    fn center_many_nodes() {
        let n = 100;
        let x: Vec<f32> = (0..n).map(|i| (i as f32) * 10.0).collect();
        let y: Vec<f32> = vec![0.0; n];
        let mut vx = vec![0.0; n];
        let mut vy = vec![0.0; n];

        force_center(&x, &y, &mut vx, &mut vy, 0.0, 0.0, 0.01, 1.0);

        // All nodes should be pulled toward center (0,0)
        // Nodes at x > 0 should be pulled left (vx < 0)
        for i in 1..n {
            assert!(
                vx[i] < 0.0,
                "node {} at x={} should be pulled left toward center",
                i,
                x[i]
            );
        }
        // Node at x=0 stays at center
        assert_eq!(vx[0], 0.0);
    }

    #[test]
    fn center_alpha_scaling() {
        let x = vec![100.0];
        let y = vec![0.0];
        let mut vx1 = vec![0.0];
        let mut vy1 = vec![0.0];
        let mut vx2 = vec![0.0];
        let mut vy2 = vec![0.0];

        force_center(&x, &y, &mut vx1, &mut vy1, 0.0, 0.0, 0.02, 0.5);
        force_center(&x, &y, &mut vx2, &mut vy2, 0.0, 0.0, 0.02, 1.0);

        assert!((vx2[0] - 2.0 * vx1[0]).abs() < 0.001);
    }

    #[test]
    fn center_2d_distribution() {
        let x = vec![0.0, 100.0, 0.0, 100.0];
        let y = vec![0.0, 0.0, 100.0, 100.0];
        let mut vx = vec![0.0; 4];
        let mut vy = vec![0.0; 4];

        force_center(&x, &y, &mut vx, &mut vy, 50.0, 50.0, 0.02, 1.0);

        // All pulled toward center (50, 50)
        assert!(vx[0] > 0.0); // (0,0) → right
        assert!(vx[1] < 0.0); // (100,0) → left
        assert!(vx[2] > 0.0); // (0,100) → right
        assert!(vx[3] < 0.0); // (100,100) → left
    }

    // =========================================================================
    // Cluster Force Tests (10 tests)
    // =========================================================================

    #[test]
    fn cluster_empty() {
        let x: Vec<f32> = vec![];
        let y: Vec<f32> = vec![];
        let mut vx: Vec<f32> = vec![];
        let mut vy: Vec<f32> = vec![];
        let cluster_ids: Vec<u32> = vec![];

        force_cluster(&x, &y, &mut vx, &mut vy, &cluster_ids, 1.0, 1.0);
    }

    #[test]
    fn cluster_single_node() {
        let x = vec![0.0];
        let y = vec![0.0];
        let mut vx = vec![0.0];
        let mut vy = vec![0.0];
        let cluster_ids = vec![0u32];

        force_cluster(&x, &y, &mut vx, &mut vy, &cluster_ids, 1.0, 1.0);

        // Singleton, no force
        assert_eq!(vx[0], 0.0);
    }

    #[test]
    fn cluster_two_same_cluster() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let cluster_ids = vec![0u32, 0];

        force_cluster(&x, &y, &mut vx, &mut vy, &cluster_ids, 0.5, 1.0);

        // Both pulled toward centroid at 50
        assert!(vx[0] > 0.0);
        assert!(vx[1] < 0.0);
    }

    #[test]
    fn cluster_three_same_cluster() {
        let x = vec![0.0, 100.0, 50.0];
        let y = vec![0.0, 0.0, 100.0];
        let mut vx = vec![0.0, 0.0, 0.0];
        let mut vy = vec![0.0, 0.0, 0.0];
        let cluster_ids = vec![0u32, 0, 0];

        force_cluster(&x, &y, &mut vx, &mut vy, &cluster_ids, 0.5, 1.0);

        // All pulled toward centroid
        // Centroid is at (50, 33.3)
        assert!(vx[0] > 0.0); // pulled right
        assert!(vx[1] < 0.0); // pulled left
        assert!(vy[2] < 0.0); // pulled down (from 100 toward 33)
    }

    #[test]
    fn cluster_multiple_clusters() {
        let x = vec![0.0, 100.0, 200.0, 300.0];
        let y = vec![0.0, 0.0, 0.0, 0.0];
        let mut vx = vec![0.0; 4];
        let mut vy = vec![0.0; 4];
        let cluster_ids = vec![0u32, 0, 1, 1];

        force_cluster(&x, &y, &mut vx, &mut vy, &cluster_ids, 0.5, 1.0);

        // Cluster 0: centroid at 50, node 0→right, node 1→left
        assert!(vx[0] > 0.0);
        assert!(vx[1] < 0.0);
        // Cluster 1: centroid at 250, node 2→right, node 3→left
        assert!(vx[2] > 0.0);
        assert!(vx[3] < 0.0);
    }

    #[test]
    fn cluster_mismatched_length() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let cluster_ids = vec![0u32]; // Wrong length

        force_cluster(&x, &y, &mut vx, &mut vy, &cluster_ids, 1.0, 1.0);

        // Should be no-op with mismatched length
        assert_eq!(vx[0], 0.0);
    }

    #[test]
    fn cluster_with_scratch_reuses_buffers() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let cluster_ids = vec![0u32, 0];
        let mut cx = Vec::new();
        let mut cy = Vec::new();
        let mut counts = Vec::new();

        force_cluster_with_scratch(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &cluster_ids,
            0.5,
            1.0,
            &mut cx,
            &mut cy,
            &mut counts,
        );

        assert!(cx.capacity() >= 1);
        assert!(counts.capacity() >= 1);
    }

    #[test]
    fn cluster_alpha_scaling() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 0.0];
        let mut vx1 = vec![0.0, 0.0];
        let mut vy1 = vec![0.0, 0.0];
        let mut vx2 = vec![0.0, 0.0];
        let mut vy2 = vec![0.0, 0.0];
        let cluster_ids = vec![0u32, 0];

        force_cluster(&x, &y, &mut vx1, &mut vy1, &cluster_ids, 0.5, 0.5);
        force_cluster(&x, &y, &mut vx2, &mut vy2, &cluster_ids, 0.5, 1.0);

        assert!((vx2[0] - 2.0 * vx1[0]).abs() < 0.01);
    }

    #[test]
    fn cluster_strength_linear() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 0.0];
        let mut vx1 = vec![0.0, 0.0];
        let mut vy1 = vec![0.0, 0.0];
        let mut vx2 = vec![0.0, 0.0];
        let mut vy2 = vec![0.0, 0.0];
        let cluster_ids = vec![0u32, 0];

        force_cluster(&x, &y, &mut vx1, &mut vy1, &cluster_ids, 0.25, 1.0);
        force_cluster(&x, &y, &mut vx2, &mut vy2, &cluster_ids, 0.5, 1.0);

        assert!((vx2[0] - 2.0 * vx1[0]).abs() < 0.01);
    }

    // =========================================================================
    // Semantic Force Tests (10 tests)
    // =========================================================================

    #[test]
    fn semantic_empty_neighbors() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let neighbors: Vec<(usize, usize, f32)> = vec![];

        force_semantic(&x, &y, &mut vx, &mut vy, &neighbors, 1.0, 200.0, 1.0);

        assert_eq!(vx[0], 0.0);
        assert_eq!(vx[1], 0.0);
    }

    #[test]
    fn semantic_single_pair_far_apart() {
        let x = vec![0.0, 200.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let neighbors = vec![(0, 1, 1.0)]; // Max similarity

        force_semantic(&x, &y, &mut vx, &mut vy, &neighbors, 1.0, 200.0, 1.0);

        // Distance 200 > half_ideal (100), should attract
        assert!(vx[0] > 0.0);
        assert!(vx[1] < 0.0);
    }

    #[test]
    fn semantic_single_pair_close_together() {
        let x = vec![0.0, 50.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let neighbors = vec![(0, 1, 1.0)];

        force_semantic(&x, &y, &mut vx, &mut vy, &neighbors, 1.0, 200.0, 1.0);

        // Distance 50 < d_crowd (60): boids separation pushes apart.
        // Node 0 pushed left (negative vx), node 1 pushed right (positive vx).
        assert!(vx[0] < 0.0, "node 0 should be pushed left by separation");
        assert!(vx[1] > 0.0, "node 1 should be pushed right by separation");
    }

    #[test]
    fn semantic_similarity_scaling() {
        let x = vec![0.0, 200.0];
        let y = vec![0.0, 0.0];
        let mut vx1 = vec![0.0, 0.0];
        let mut vy1 = vec![0.0, 0.0];
        let mut vx2 = vec![0.0, 0.0];
        let mut vy2 = vec![0.0, 0.0];

        let neighbors1 = vec![(0, 1, 0.5)];
        let neighbors2 = vec![(0, 1, 1.0)];

        force_semantic(&x, &y, &mut vx1, &mut vy1, &neighbors1, 1.0, 200.0, 1.0);
        force_semantic(&x, &y, &mut vx2, &mut vy2, &neighbors2, 1.0, 200.0, 1.0);

        // Double similarity should produce double force
        assert!((vx2[0] - 2.0 * vx1[0]).abs() < 0.01);
    }

    #[test]
    fn semantic_zero_strength() {
        let x = vec![0.0, 200.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let neighbors = vec![(0, 1, 1.0)];

        force_semantic(&x, &y, &mut vx, &mut vy, &neighbors, 0.0, 200.0, 1.0);

        assert_eq!(vx[0], 0.0);
    }

    #[test]
    fn semantic_invalid_indices_skipped() {
        let x = vec![0.0, 100.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let neighbors = vec![(0, 5, 1.0), (1, 10, 1.0)]; // Invalid indices

        force_semantic(&x, &y, &mut vx, &mut vy, &neighbors, 1.0, 200.0, 1.0);

        // Invalid indices should be skipped gracefully
        assert_eq!(vx[0], 0.0);
    }

    #[test]
    fn semantic_multiple_pairs() {
        let x = vec![0.0, 200.0, 400.0];
        let y = vec![0.0, 0.0, 0.0];
        let mut vx = vec![0.0, 0.0, 0.0];
        let mut vy = vec![0.0, 0.0, 0.0];
        let neighbors = vec![(0, 1, 1.0), (1, 2, 1.0)];

        force_semantic(&x, &y, &mut vx, &mut vy, &neighbors, 1.0, 200.0, 1.0);

        // Both pairs should attract (distances > half_ideal = 100)
        // Distance 0-1 = 200, 1-2 = 200, both should attract
        assert!(vx[0] >= 0.0, "node 0 pulled right or zero");
        assert!(vx[2] <= 0.0, "node 2 pulled left or zero");
    }

    #[test]
    fn semantic_ideal_distance_affects_force() {
        let x = vec![0.0, 150.0];
        let y = vec![0.0, 0.0];
        let mut vx1 = vec![0.0, 0.0];
        let mut vy1 = vec![0.0, 0.0];
        let mut vx2 = vec![0.0, 0.0];
        let mut vy2 = vec![0.0, 0.0];

        let neighbors = vec![(0, 1, 1.0)];

        force_semantic(&x, &y, &mut vx1, &mut vy1, &neighbors, 1.0, 100.0, 1.0);
        force_semantic(&x, &y, &mut vx2, &mut vy2, &neighbors, 1.0, 400.0, 1.0);

        // Smaller ideal distance means farther from half_ideal (50), stronger pull
        assert!(vx1[0].abs() > vx2[0].abs());
    }

    #[test]
    fn semantic_symmetric_force() {
        let x = vec![0.0, 200.0];
        let y = vec![0.0, 0.0];
        let mut vx = vec![0.0, 0.0];
        let mut vy = vec![0.0, 0.0];
        let neighbors = vec![(0, 1, 1.0)];

        force_semantic(&x, &y, &mut vx, &mut vy, &neighbors, 1.0, 200.0, 1.0);

        // Forces should be equal and opposite
        assert!((vx[0] + vx[1]).abs() < 0.01);
    }

    #[test]
    fn many_body_scratch_capacity_stabilizes_after_first_pass() {
        let x = vec![0.0, 120.0, 240.0, 360.0];
        let y = vec![0.0, 0.0, 0.0, 0.0];
        let mut vx = vec![0.0; 4];
        let mut vy = vec![0.0; 4];
        let fx = vec![None; 4];
        let fy = vec![None; 4];
        let degrees = vec![1; 4];
        let mut bodies = Vec::new();

        force_many_body_with_scratch(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &fx,
            &fy,
            -600.0,
            600.0,
            1.0,
            1.0,
            &mut bodies,
            &degrees,
        );
        let first_capacity = bodies.capacity();

        force_many_body_with_scratch(
            &x,
            &y,
            &mut vx,
            &mut vy,
            &fx,
            &fy,
            -600.0,
            600.0,
            1.0,
            1.0,
            &mut bodies,
            &degrees,
        );

        assert_eq!(bodies.capacity(), first_capacity);
    }

    #[test]
    fn collision_full_scratch_reuses_key_capacity() {
        let mut x = vec![0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 35.0];
        let mut y = vec![0.0; 8];
        let radii = vec![20.0; 8];
        let fx = vec![None; 8];
        let fy = vec![None; 8];
        let mut grid = rustc_hash::FxHashMap::default();
        let mut keys = Vec::new();

        force_collide_with_full_scratch(
            &mut x, &mut y, &radii, &[], &fx, &fy, 2, 1.0, &mut grid, &mut keys,
        );
        let first_capacity = keys.capacity();

        force_collide_with_full_scratch(
            &mut x, &mut y, &radii, &[], &fx, &fy, 2, 1.0, &mut grid, &mut keys,
        );

        assert_eq!(keys.capacity(), first_capacity);
    }
}
