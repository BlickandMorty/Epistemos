//! Phase B Week 3-4 compute-kernel reference: uniform grid broadphase
//! + cell-aggregate repulsion.
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Phase B —
//! Metal compute (8 weeks)" → §"Week 3-4: Uniform grid broadphase +
//! repulsion". The plan calls for five `.metal` files:
//!
//!   grid_build.metal     — hash positions into cell ids
//!   grid_scan.metal      — exclusive prefix sum over cell counts
//!   grid_scatter.metal   — scatter node indices into contiguous lists
//!   cell_reduce.metal    — per-cell mass + center-of-mass
//!   repulsion.metal      — near-field exact 3×3, far-field cell aggregate
//!
//! This module ships the CPU reference for all five so the MSL pass is
//! a translation rather than a fresh design. The Phase B exit gate
//! reads "GPU repulsion produces visually-equivalent output to CPU
//! Barnes-Hut on 5k / 10k / 50k synthetic vaults"; the existing
//! `quadtree.rs` Barnes-Hut is the BH reference, this module is the
//! uniform-grid candidate that ships *alongside* it.
//!
//! ## Pure-data contract
//!
//! Inputs are slim `f32` arrays. Outputs are force arrays + the grid
//! intermediates (cell counts, scan, scatter table, aggregates). No
//! engine dependencies; the integrator sequences these per frame.
//!
//! ## Why uniform grid, not Barnes-Hut, on GPU
//!
//! Per locked decision #5 in the canonical plan: "Uniform grid +
//! cell aggregation, not Barnes-Hut for GPU compute" — quadtree is
//! pointer-chasing and not GPU-friendly; uniform grid is one
//! atomic-add per node into a known bucket, plus a parallel scan.
//!
//! ## Determinism contract
//!
//! Same input arrays → bit-identical output. Tested in `*_is_deterministic`
//! across grid_build / grid_scatter / repulsion.

/// Static configuration for the uniform grid.
#[derive(Debug, Clone, Copy)]
pub struct UniformGridConfig {
    /// World half-extent — grid covers `[-world_half, +world_half]²`.
    pub world_half: f32,
    /// Number of cells per axis. Total cells = `cells_per_axis²`.
    pub cells_per_axis: u32,
}

impl UniformGridConfig {
    /// Plan §"Week 3-4" cell-size formula:
    ///   cell_size = 2 * median(atmosphere_radius), capped at world_size / 32
    pub fn from_median_atmosphere(world_half: f32, median_atmosphere_radius: f32) -> Self {
        let raw_cell_size = (2.0 * median_atmosphere_radius)
            .min(world_half * 2.0 / 32.0)
            .max(1e-3);
        let cells_per_axis = ((world_half * 2.0) / raw_cell_size).ceil().max(1.0) as u32;
        Self { world_half, cells_per_axis }
    }

    pub fn total_cells(&self) -> u32 {
        self.cells_per_axis * self.cells_per_axis
    }

    pub fn cell_size(&self) -> f32 {
        (self.world_half * 2.0) / self.cells_per_axis as f32
    }

    /// Map a world-space `(x, y)` to a cell id. Returns `None` if the
    /// point is outside the grid (caller decides whether to clamp).
    pub fn cell_of(&self, x: f32, y: f32) -> Option<u32> {
        let n = self.cells_per_axis as i32;
        let cs = self.cell_size();
        let ix = ((x + self.world_half) / cs).floor() as i32;
        let iy = ((y + self.world_half) / cs).floor() as i32;
        if ix < 0 || iy < 0 || ix >= n || iy >= n { return None; }
        Some((iy as u32) * self.cells_per_axis + ix as u32)
    }

    /// Map a cell id to its `(ix, iy)` coordinates. Returns `None` if
    /// the cell id is out of range.
    pub fn cell_coord(&self, cell_id: u32) -> Option<(u32, u32)> {
        if cell_id >= self.total_cells() { return None; }
        Some((cell_id % self.cells_per_axis, cell_id / self.cells_per_axis))
    }
}

/// Kernel 1: hash positions into cell ids. Returns `cell_id_of_node[i]`
/// + `per_cell_count[cell_id]`. Mirror of `grid_build.metal`.
pub fn grid_build_kernel(
    pos_x: &[f32],
    pos_y: &[f32],
    cfg: &UniformGridConfig,
) -> (Vec<u32>, Vec<u32>) {
    let n = pos_x.len().min(pos_y.len());
    let total_cells = cfg.total_cells() as usize;
    let mut cell_of_node: Vec<u32> = vec![u32::MAX; n];
    let mut counts: Vec<u32> = vec![0; total_cells];
    for i in 0..n {
        if let Some(cell) = cfg.cell_of(pos_x[i], pos_y[i]) {
            cell_of_node[i] = cell;
            counts[cell as usize] += 1;
        }
    }
    (cell_of_node, counts)
}

/// Kernel 2: exclusive prefix sum over per-cell counts. Mirror of
/// `grid_scan.metal` (which would do a work-efficient parallel scan;
/// the CPU mirror is a serial pass).
pub fn grid_scan_kernel(counts: &[u32]) -> Vec<u32> {
    let mut scan: Vec<u32> = Vec::with_capacity(counts.len() + 1);
    scan.push(0);
    let mut acc: u32 = 0;
    for &c in counts {
        acc += c;
        scan.push(acc);
    }
    scan
}

/// Kernel 3: scatter node indices into contiguous per-cell lists.
/// Returns `scatter[idx_in_cell_list] = node_index`. Mirror of
/// `grid_scatter.metal`.
pub fn grid_scatter_kernel(
    cell_of_node: &[u32],
    scan: &[u32],
) -> Vec<u32> {
    let total_nodes_in_cells = *scan.last().unwrap_or(&0) as usize;
    let mut scatter: Vec<u32> = vec![u32::MAX; total_nodes_in_cells];
    // Per-cell cursor — where to write the next node into this cell's list.
    let mut cursor: Vec<u32> = scan[..scan.len() - 1].to_vec();
    for (node_idx, &cell) in cell_of_node.iter().enumerate() {
        if cell == u32::MAX { continue; }
        let c = cell as usize;
        let dest = cursor[c] as usize;
        if dest < scatter.len() {
            scatter[dest] = node_idx as u32;
            cursor[c] += 1;
        }
    }
    scatter
}

/// Per-cell aggregate: total "mass" (count by default) + centre-of-mass
/// position. The Phase B `repulsion.metal` far-field reads this for cells
/// it doesn't visit exactly.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CellAggregate {
    pub mass: u32,
    pub centre_x: f32,
    pub centre_y: f32,
}

/// Kernel 4: per-cell mass + centre-of-mass. Mirror of `cell_reduce.metal`.
///
/// Per canonical-plan §"Crash hardening" → "NaN / Inf propagation":
/// individual non-finite member positions are skipped from the sum
/// (their mass still counts) so a single corrupt position doesn't poison
/// the centroid of an otherwise-healthy cell. If the final centroid is
/// somehow still non-finite, it's clamped to zero before writing out.
pub fn cell_reduce_kernel(
    pos_x: &[f32],
    pos_y: &[f32],
    scatter: &[u32],
    scan: &[u32],
) -> Vec<CellAggregate> {
    let total_cells = scan.len().saturating_sub(1);
    let mut aggregates: Vec<CellAggregate> = Vec::with_capacity(total_cells);
    for cell_id in 0..total_cells {
        let lo = scan[cell_id] as usize;
        let hi = scan[cell_id + 1] as usize;
        let mut sum_x = 0.0_f32;
        let mut sum_y = 0.0_f32;
        let mass = (hi - lo) as u32;
        for &node in &scatter[lo..hi.min(scatter.len())] {
            let i = node as usize;
            if i < pos_x.len() && i < pos_y.len() {
                let px = pos_x[i];
                let py = pos_y[i];
                if px.is_finite() && py.is_finite() {
                    sum_x += px;
                    sum_y += py;
                }
            }
        }
        let mut centre_x = if mass > 0 { sum_x / mass as f32 } else { 0.0 };
        let mut centre_y = if mass > 0 { sum_y / mass as f32 } else { 0.0 };
        if !centre_x.is_finite() { centre_x = 0.0; }
        if !centre_y.is_finite() { centre_y = 0.0; }
        aggregates.push(CellAggregate { mass, centre_x, centre_y });
    }
    aggregates
}

/// Kernel 5: cell-aggregate repulsion.
///
/// For each node:
/// - Near field: walk neighbour cells (3×3 around the node's cell, exact pairwise repulsion)
/// - Far field: walk distant cell aggregates (centre-of-mass approximation)
///
/// `near_radius_cells` is how many cell-radii to treat as "near field"
/// (default 1 → 3×3; the plan also allows 5×5 with `near_radius_cells = 2`).
///
/// Output overwrites `force_x` / `force_y` with the repulsion contribution.
#[allow(clippy::too_many_arguments)]
pub fn repulsion_kernel(
    pos_x: &[f32],
    pos_y: &[f32],
    cell_of_node: &[u32],
    scatter: &[u32],
    scan: &[u32],
    aggregates: &[CellAggregate],
    cfg: &UniformGridConfig,
    force_x: &mut [f32],
    force_y: &mut [f32],
    repulsion_strength: f32,
    near_radius_cells: i32,
) {
    let n = pos_x.len().min(pos_y.len()).min(cell_of_node.len());
    let total_cells = aggregates.len() as u32;
    let cpa = cfg.cells_per_axis as i32;

    for i in 0..n {
        let cell = cell_of_node[i];
        if cell == u32::MAX { continue; }
        let (cx, cy) = match cfg.cell_coord(cell) {
            Some(c) => c,
            None => continue,
        };

        let mut fx = 0.0_f32;
        let mut fy = 0.0_f32;
        let ux = pos_x[i];
        let uy = pos_y[i];

        // Near field: walk (2*near+1)² cells of exact node-node repulsion.
        let cxi = cx as i32;
        let cyi = cy as i32;
        let mut visited: std::collections::BTreeSet<u32> = std::collections::BTreeSet::new();
        for dy in -near_radius_cells..=near_radius_cells {
            for dx in -near_radius_cells..=near_radius_cells {
                let ax = cxi + dx;
                let ay = cyi + dy;
                if ax < 0 || ay < 0 || ax >= cpa || ay >= cpa { continue; }
                let cell_id = (ay as u32) * cfg.cells_per_axis + ax as u32;
                if cell_id >= total_cells { continue; }
                visited.insert(cell_id);
                let lo = scan[cell_id as usize] as usize;
                let hi = scan[cell_id as usize + 1] as usize;
                for &node in &scatter[lo..hi.min(scatter.len())] {
                    let j = node as usize;
                    if j == i || j >= pos_x.len() { continue; }
                    let dx_p = ux - pos_x[j];
                    let dy_p = uy - pos_y[j];
                    let dist_sq = (dx_p * dx_p + dy_p * dy_p).max(1e-6);
                    let dist = dist_sq.sqrt();
                    let magnitude = repulsion_strength / dist_sq;
                    let contrib_x = (dx_p / dist) * magnitude;
                    let contrib_y = (dy_p / dist) * magnitude;
                    // Per-neighbour isfinite guard per canonical-plan
                    // §"Crash hardening" → "NaN / Inf propagation".
                    if contrib_x.is_finite() && contrib_y.is_finite() {
                        fx += contrib_x;
                        fy += contrib_y;
                    }
                }
            }
        }

        // Far field: walk all OTHER cells via centre-of-mass aggregates.
        for cell_id in 0..total_cells {
            if visited.contains(&cell_id) { continue; }
            let agg = aggregates[cell_id as usize];
            if agg.mass == 0 { continue; }
            let dx_a = ux - agg.centre_x;
            let dy_a = uy - agg.centre_y;
            let dist_sq = (dx_a * dx_a + dy_a * dy_a).max(1e-6);
            let dist = dist_sq.sqrt();
            let magnitude = (agg.mass as f32) * repulsion_strength / dist_sq;
            let contrib_x = (dx_a / dist) * magnitude;
            let contrib_y = (dy_a / dist) * magnitude;
            if contrib_x.is_finite() && contrib_y.is_finite() {
                fx += contrib_x;
                fy += contrib_y;
            }
        }

        // Final-pass guard mirrors spring_forces_kernel — clamp non-
        // finite totals to zero before writing out.
        force_x[i] = if fx.is_finite() { fx } else { 0.0 };
        force_y[i] = if fy.is_finite() { fy } else { 0.0 };
    }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cell_size_formula_caps_at_world_over_32() {
        let cfg = UniformGridConfig::from_median_atmosphere(100.0, 100.0);
        // 2 * 100 = 200, but world_size/32 = 200/32 = 6.25 → cell_size = 6.25.
        assert!((cfg.cell_size() - 6.25).abs() < 0.1);
    }

    #[test]
    fn cell_size_formula_uses_atmosphere_when_smaller() {
        let cfg = UniformGridConfig::from_median_atmosphere(100.0, 1.0);
        // 2 * 1 = 2 < 6.25 → cell_size = 2.0.
        assert!((cfg.cell_size() - 2.0).abs() < 0.2);
    }

    #[test]
    fn cell_of_round_trips_position() {
        let cfg = UniformGridConfig { world_half: 10.0, cells_per_axis: 4 };
        // Centre of cell (0, 0) is roughly (-7.5, -7.5).
        let cell = cfg.cell_of(-7.5, -7.5);
        assert_eq!(cell, Some(0));
        // Centre of cell (3, 3) is roughly (7.5, 7.5).
        let cell = cfg.cell_of(7.5, 7.5);
        assert_eq!(cell, Some(15));
    }

    #[test]
    fn cell_of_returns_none_for_out_of_box() {
        let cfg = UniformGridConfig { world_half: 10.0, cells_per_axis: 4 };
        assert_eq!(cfg.cell_of(-100.0, 0.0), None);
        assert_eq!(cfg.cell_of(100.0, 0.0), None);
        assert_eq!(cfg.cell_of(0.0, -100.0), None);
        assert_eq!(cfg.cell_of(0.0, 100.0), None);
    }

    #[test]
    fn grid_build_counts_match_node_distribution() {
        let cfg = UniformGridConfig { world_half: 10.0, cells_per_axis: 2 };
        // 4 cells: 0=BL, 1=BR, 2=TL, 3=TR
        let pos_x = vec![-5.0_f32, -5.0, 5.0, 5.0, 0.0];
        let pos_y = vec![-5.0_f32, -5.0, -5.0, 5.0, 0.0];
        let (cells, counts) = grid_build_kernel(&pos_x, &pos_y, &cfg);
        assert_eq!(cells.len(), 5);
        assert_eq!(counts.iter().sum::<u32>(), 5);
    }

    #[test]
    fn grid_scan_is_exclusive_prefix_sum() {
        let counts = vec![2u32, 3, 0, 5];
        let scan = grid_scan_kernel(&counts);
        assert_eq!(scan, vec![0, 2, 5, 5, 10]);
    }

    #[test]
    fn grid_scatter_lists_nodes_per_cell() {
        let cell_of_node = vec![0u32, 1, 0, 2, 1];
        let counts = vec![2u32, 2, 1];
        let scan = grid_scan_kernel(&counts);
        let scatter = grid_scatter_kernel(&cell_of_node, &scan);
        assert_eq!(scatter.len(), 5);
        // First 2 entries are cell 0's nodes (0, 2 in some order).
        let cell_0: std::collections::BTreeSet<u32> = scatter[0..2].iter().copied().collect();
        assert_eq!(cell_0, [0, 2].iter().copied().collect());
        // Next 2 entries are cell 1's (1, 4).
        let cell_1: std::collections::BTreeSet<u32> = scatter[2..4].iter().copied().collect();
        assert_eq!(cell_1, [1, 4].iter().copied().collect());
        // Last 1 entry is cell 2 (node 3).
        assert_eq!(scatter[4], 3);
    }

    #[test]
    fn grid_scatter_handles_unmapped_nodes() {
        let cell_of_node = vec![0u32, u32::MAX, 0];
        let counts = vec![2u32];
        let scan = grid_scan_kernel(&counts);
        let scatter = grid_scatter_kernel(&cell_of_node, &scan);
        assert_eq!(scatter.len(), 2);
        let set: std::collections::BTreeSet<u32> = scatter.iter().copied().collect();
        assert_eq!(set, [0, 2].iter().copied().collect());
    }

    #[test]
    fn cell_reduce_computes_centre_of_mass() {
        let cfg = UniformGridConfig { world_half: 10.0, cells_per_axis: 2 };
        // Two nodes in cell 0 at (-7, -7) and (-3, -3)  → COM = (-5, -5).
        let pos_x = vec![-7.0_f32, -3.0];
        let pos_y = vec![-7.0_f32, -3.0];
        let (cell_of_node, counts) = grid_build_kernel(&pos_x, &pos_y, &cfg);
        let scan = grid_scan_kernel(&counts);
        let scatter = grid_scatter_kernel(&cell_of_node, &scan);
        let aggregates = cell_reduce_kernel(&pos_x, &pos_y, &scatter, &scan);
        // Cell 0 carries both nodes.
        assert_eq!(aggregates[0].mass, 2);
        assert!((aggregates[0].centre_x + 5.0).abs() < 1e-3);
        assert!((aggregates[0].centre_y + 5.0).abs() < 1e-3);
    }

    #[test]
    fn cell_reduce_zero_mass_centre_is_zero() {
        let cfg = UniformGridConfig { world_half: 10.0, cells_per_axis: 2 };
        let pos_x: Vec<f32> = vec![];
        let pos_y: Vec<f32> = vec![];
        let counts = vec![0u32; (cfg.total_cells()) as usize];
        let scan = grid_scan_kernel(&counts);
        let aggregates = cell_reduce_kernel(&pos_x, &pos_y, &[], &scan);
        for a in &aggregates {
            assert_eq!(a.mass, 0);
            assert_eq!(a.centre_x, 0.0);
            assert_eq!(a.centre_y, 0.0);
        }
    }

    #[test]
    fn repulsion_pushes_overlapping_nodes_apart() {
        let cfg = UniformGridConfig { world_half: 10.0, cells_per_axis: 4 };
        let pos_x = vec![0.0_f32, 0.1];
        let pos_y = vec![0.0_f32, 0.0];
        let (cell_of_node, counts) = grid_build_kernel(&pos_x, &pos_y, &cfg);
        let scan = grid_scan_kernel(&counts);
        let scatter = grid_scatter_kernel(&cell_of_node, &scan);
        let aggregates = cell_reduce_kernel(&pos_x, &pos_y, &scatter, &scan);
        let mut fx = vec![0.0_f32; 2];
        let mut fy = vec![0.0_f32; 2];
        repulsion_kernel(
            &pos_x, &pos_y, &cell_of_node, &scatter, &scan, &aggregates,
            &cfg, &mut fx, &mut fy, 100.0, 1,
        );
        // Node 0 is at the smaller-x side → fx[0] should be negative (pushed left).
        // Node 1 is at the larger-x side  → fx[1] should be positive (pushed right).
        assert!(fx[0] < 0.0, "leftmost node pushed left, got fx[0]={}", fx[0]);
        assert!(fx[1] > 0.0, "rightmost node pushed right, got fx[1]={}", fx[1]);
    }

    #[test]
    fn repulsion_is_deterministic() {
        let cfg = UniformGridConfig { world_half: 10.0, cells_per_axis: 4 };
        let pos_x = vec![1.0_f32, 2.0, 3.0, 4.0];
        let pos_y = vec![1.0_f32, 2.0, 3.0, 4.0];
        let (cell_of_node, counts) = grid_build_kernel(&pos_x, &pos_y, &cfg);
        let scan = grid_scan_kernel(&counts);
        let scatter = grid_scatter_kernel(&cell_of_node, &scan);
        let aggregates = cell_reduce_kernel(&pos_x, &pos_y, &scatter, &scan);
        let mut fx_a = vec![0.0_f32; 4];
        let mut fy_a = vec![0.0_f32; 4];
        let mut fx_b = vec![0.0_f32; 4];
        let mut fy_b = vec![0.0_f32; 4];
        repulsion_kernel(&pos_x, &pos_y, &cell_of_node, &scatter, &scan, &aggregates,
            &cfg, &mut fx_a, &mut fy_a, 50.0, 1);
        repulsion_kernel(&pos_x, &pos_y, &cell_of_node, &scatter, &scan, &aggregates,
            &cfg, &mut fx_b, &mut fy_b, 50.0, 1);
        assert_eq!(fx_a, fx_b);
        assert_eq!(fy_a, fy_b);
    }

    #[test]
    fn repulsion_zero_strength_zero_force() {
        let cfg = UniformGridConfig { world_half: 10.0, cells_per_axis: 4 };
        let pos_x = vec![0.0_f32, 5.0];
        let pos_y = vec![0.0_f32, 5.0];
        let (cell_of_node, counts) = grid_build_kernel(&pos_x, &pos_y, &cfg);
        let scan = grid_scan_kernel(&counts);
        let scatter = grid_scatter_kernel(&cell_of_node, &scan);
        let aggregates = cell_reduce_kernel(&pos_x, &pos_y, &scatter, &scan);
        let mut fx = vec![0.0_f32; 2];
        let mut fy = vec![0.0_f32; 2];
        repulsion_kernel(&pos_x, &pos_y, &cell_of_node, &scatter, &scan, &aggregates,
            &cfg, &mut fx, &mut fy, 0.0, 1);
        for f in fx.iter().chain(fy.iter()) {
            assert_eq!(*f, 0.0);
        }
    }

    #[test]
    fn repulsion_kernel_quarantines_nan_position_inputs() {
        // A node whose position is NaN must not poison its neighbour's force
        // accumulation. The kernel skips NaN-producing contributions and
        // writes a finite output regardless.
        let cfg = UniformGridConfig { world_half: 10.0, cells_per_axis: 4 };
        let pos_x = vec![0.0_f32, f32::NAN];
        let pos_y = vec![0.0_f32, 0.0];
        let (cell_of_node, counts) = grid_build_kernel(&pos_x, &pos_y, &cfg);
        let scan = grid_scan_kernel(&counts);
        let scatter = grid_scatter_kernel(&cell_of_node, &scan);
        let aggregates = cell_reduce_kernel(&pos_x, &pos_y, &scatter, &scan);
        let mut fx = vec![0.0_f32; 2];
        let mut fy = vec![0.0_f32; 2];
        repulsion_kernel(
            &pos_x, &pos_y, &cell_of_node, &scatter, &scan, &aggregates,
            &cfg, &mut fx, &mut fy, 100.0, 1,
        );
        // All outputs are finite.
        for f in fx.iter().chain(fy.iter()) {
            assert!(f.is_finite(), "repulsion output must be finite even with NaN inputs, got {}", f);
        }
    }

    #[test]
    fn cell_reduce_quarantines_nan_position_inputs() {
        // Two nodes in cell 0, one with NaN position. The finite one wins;
        // the NaN one contributes 0 to the sum but still counts as mass.
        let cfg = UniformGridConfig { world_half: 10.0, cells_per_axis: 2 };
        // Note: NaN won't map to any cell via `cell_of`, so grid_build will
        // skip it. Use a real position for both nodes but mock the scatter
        // / scan to put both in the same cell with one having a NaN position.
        let pos_x = vec![-5.0_f32, f32::NAN];
        let pos_y = vec![-5.0_f32, f32::NAN];
        // Manually construct scan + scatter putting both nodes into cell 0.
        let scan = vec![0u32, 2, 2, 2, 2];
        let scatter = vec![0u32, 1];
        let aggregates = cell_reduce_kernel(&pos_x, &pos_y, &scatter, &scan);
        // Cell 0 has mass=2 (both nodes counted); centre is from finite
        // contribution only (-5, -5) divided by 2 = (-2.5, -2.5).
        assert_eq!(aggregates[0].mass, 2);
        assert!(aggregates[0].centre_x.is_finite());
        assert!(aggregates[0].centre_y.is_finite());
        // (-5 + 0) / 2 = -2.5 (NaN contribution skipped)
        assert!((aggregates[0].centre_x + 2.5).abs() < 1e-3,
            "centroid uses only finite contributions, got {}",
            aggregates[0].centre_x);
    }

    #[test]
    fn full_grid_pipeline_round_trips_node_count() {
        let cfg = UniformGridConfig { world_half: 50.0, cells_per_axis: 8 };
        let pos_x: Vec<f32> = (0..100).map(|i| (i as f32 * 0.7) - 35.0).collect();
        let pos_y: Vec<f32> = (0..100).map(|i| ((i * 31) % 70) as f32 - 35.0).collect();
        let (cell_of_node, counts) = grid_build_kernel(&pos_x, &pos_y, &cfg);
        let scan = grid_scan_kernel(&counts);
        let scatter = grid_scatter_kernel(&cell_of_node, &scan);
        assert_eq!(scatter.len() as u32, counts.iter().sum::<u32>());
        let mapped = cell_of_node.iter().filter(|&&c| c != u32::MAX).count();
        assert_eq!(mapped as u32, counts.iter().sum::<u32>());
    }
}
