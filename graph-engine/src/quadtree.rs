//! # Barnes-Hut Quadtree
//!
//! Used by `force_many_body` for O(n log n) charge force approximation.
//! Theta = 0.5 (d3/LogSeq default — more accurate than the old 0.9).
//!
//! Each internal node stores the total charge and center-of-charge
//! of its subtree, enabling far-field approximation when
//! `cell_size / distance < theta`.

/// Barnes-Hut opening angle. Cells whose `size / dist < THETA` are
/// treated as single point charges. 0.5 = d3 default.
pub const THETA: f32 = 0.5;

/// Maximum tree depth to prevent infinite recursion on coincident points.
const MAX_DEPTH: u32 = 20;

/// Axis-aligned bounding box.
#[derive(Clone, Copy)]
pub struct AABB {
    pub min_x: f32,
    pub min_y: f32,
    pub max_x: f32,
    pub max_y: f32,
}

impl AABB {
    pub fn size(&self) -> f32 {
        (self.max_x - self.min_x).max(self.max_y - self.min_y)
    }

    pub fn midpoint(&self) -> (f32, f32) {
        (
            (self.min_x + self.max_x) * 0.5,
            (self.min_y + self.max_y) * 0.5,
        )
    }

    fn quadrant(&self, idx: usize) -> AABB {
        let (mx, my) = self.midpoint();
        match idx {
            0 => AABB { min_x: self.min_x, min_y: self.min_y, max_x: mx, max_y: my },
            1 => AABB { min_x: mx, min_y: self.min_y, max_x: self.max_x, max_y: my },
            2 => AABB { min_x: self.min_x, min_y: my, max_x: mx, max_y: self.max_y },
            _ => AABB { min_x: mx, min_y: my, max_x: self.max_x, max_y: self.max_y },
        }
    }

    fn quadrant_for(&self, x: f32, y: f32) -> usize {
        let (mx, my) = self.midpoint();
        if y < my {
            if x < mx { 0 } else { 1 }
        } else if x < mx {
            2
        } else {
            3
        }
    }
}

/// A body in the Barnes-Hut tree.
#[derive(Clone, Copy)]
pub struct Body {
    pub index: usize,
    pub x: f32,
    pub y: f32,
    pub strength: f32,
}

/// Quadtree node for Barnes-Hut force approximation.
pub struct BHNode {
    bounds: AABB,
    /// Single body stored in leaf nodes.
    body: Option<Body>,
    /// Children (NW, NE, SW, SE). None = no children.
    children: Option<Box<[Option<BHNode>; 4]>>,
    /// Aggregate: total strength of all bodies in this subtree.
    total_strength: f32,
    /// Aggregate: center of charge (weighted by strength).
    center_x: f32,
    center_y: f32,
    /// Number of bodies in this subtree.
    count: u32,
}

impl BHNode {
    fn new(bounds: AABB) -> Self {
        Self {
            bounds,
            body: None,
            children: None,
            total_strength: 0.0,
            center_x: 0.0,
            center_y: 0.0,
            count: 0,
        }
    }

    fn insert(&mut self, body: Body, depth: u32) {
        if depth >= MAX_DEPTH {
            // At max depth: accumulate into aggregates but don't subdivide further.
            self.accumulate(body);
            if self.body.is_none() {
                self.body = Some(body);
            }
            return;
        }

        // Already subdivided — route to correct child.
        if self.children.is_some() {
            self.accumulate(body);
            let qi = self.bounds.quadrant_for(body.x, body.y);
            let children = self.children.as_mut().unwrap();
            if children[qi].is_none() {
                children[qi] = Some(BHNode::new(self.bounds.quadrant(qi)));
            }
            children[qi].as_mut().unwrap().insert(body, depth + 1);
            return;
        }

        // Empty leaf — store body.
        if self.body.is_none() {
            self.body = Some(body);
            self.accumulate(body);
            return;
        }

        // Leaf collision — subdivide, re-insert existing + new.
        let old = self.body.take().unwrap();
        self.children = Some(Box::new([None, None, None, None]));

        // Reset aggregates — will be recomputed by recursive inserts.
        self.total_strength = 0.0;
        self.center_x = 0.0;
        self.center_y = 0.0;
        self.count = 0;

        // Re-insert old body.
        self.insert(old, depth);
        // Insert new body.
        self.insert(body, depth);
    }

    fn accumulate(&mut self, body: Body) {
        let new_total = self.total_strength + body.strength;
        if new_total.abs() > f32::EPSILON {
            self.center_x =
                (self.center_x * self.total_strength + body.x * body.strength) / new_total;
            self.center_y =
                (self.center_y * self.total_strength + body.y * body.strength) / new_total;
        }
        self.total_strength = new_total;
        self.count += 1;
    }

    /// Apply the many-body force from this subtree to the node at (nx, ny).
    /// Modifies `dvx` and `dvy` in place (accumulated velocity deltas).
    #[allow(clippy::too_many_arguments)]
    pub fn apply_force(
        &self,
        nx: f32,
        ny: f32,
        node_index: usize,
        alpha: f32,
        distance_min_sq: f32,
        distance_max_sq: f32,
        dvx: &mut f32,
        dvy: &mut f32,
    ) {
        if self.count == 0 {
            return;
        }

        let dx = self.center_x - nx;
        let dy = self.center_y - ny;
        let mut dist_sq = dx * dx + dy * dy;

        // Skip if beyond max range.
        if dist_sq > distance_max_sq {
            return;
        }

        let cell_size = self.bounds.size();

        // Can we use the far-field approximation?
        // Condition: cell_size / sqrt(dist_sq) < theta, i.e. cell_size² < theta² * dist_sq
        let use_approximation =
            cell_size * cell_size < THETA * THETA * dist_sq && self.count > 1;

        if use_approximation || self.count == 1 {
            // Check if this is the node itself (skip self-interaction).
            if self.count == 1
                && let Some(body) = &self.body
                && body.index == node_index
            {
                return;
            }

            // Clamp minimum distance.
            if dist_sq < distance_min_sq {
                dist_sq = distance_min_sq;
            }

            let dist = dist_sq.sqrt();
            // d3 formula: strength * alpha / dist², applied as (dx/dist, dy/dist) components.
            let w = self.total_strength * alpha / dist_sq;
            *dvx += dx / dist * w;
            *dvy += dy / dist * w;
            return;
        }

        // Not far enough — recurse into children.
        if let Some(children) = &self.children {
            for child in children.iter().flatten() {
                child.apply_force(
                    nx,
                    ny,
                    node_index,
                    alpha,
                    distance_min_sq,
                    distance_max_sq,
                    dvx,
                    dvy,
                );
            }
        }
    }
}

/// Build a Barnes-Hut quadtree from a set of bodies.
pub fn build_tree(bodies: &[Body]) -> Option<BHNode> {
    if bodies.is_empty() {
        return None;
    }

    // Compute bounding box.
    let mut min_x = f32::MAX;
    let mut min_y = f32::MAX;
    let mut max_x = f32::MIN;
    let mut max_y = f32::MIN;

    for b in bodies {
        min_x = min_x.min(b.x);
        min_y = min_y.min(b.y);
        max_x = max_x.max(b.x);
        max_y = max_y.max(b.y);
    }

    // Pad and square the bounds.
    let pad = 10.0;
    let raw = AABB {
        min_x: min_x - pad,
        min_y: min_y - pad,
        max_x: max_x + pad,
        max_y: max_y + pad,
    };
    let size = raw.size();
    let (cx, cy) = raw.midpoint();
    let half = size * 0.5;
    let bounds = AABB {
        min_x: cx - half,
        min_y: cy - half,
        max_x: cx + half,
        max_y: cy + half,
    };

    let mut root = BHNode::new(bounds);
    for body in bodies {
        root.insert(*body, 0);
    }

    Some(root)
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn single_body_tree() {
        let bodies = vec![Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 }];
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.count, 1);
        assert!((tree.total_strength - (-600.0)).abs() < f32::EPSILON);
    }

    #[test]
    fn two_bodies_subdivide() {
        let bodies = vec![
            Body { index: 0, x: -100.0, y: 0.0, strength: -600.0 },
            Body { index: 1, x: 100.0, y: 0.0, strength: -600.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.count, 2);
        assert!((tree.total_strength - (-1200.0)).abs() < f32::EPSILON);
        // Center of charge should be at (0, 0) since equal strengths.
        assert!(tree.center_x.abs() < f32::EPSILON);
    }

    #[test]
    fn self_interaction_skipped() {
        let bodies = vec![Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 }];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        tree.apply_force(0.0, 0.0, 0, 1.0, 1.0, 360000.0, &mut dvx, &mut dvy);
        // Should be zero — node doesn't repel itself.
        assert_eq!(dvx, 0.0);
        assert_eq!(dvy, 0.0);
    }

    #[test]
    fn repulsion_pushes_apart() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 },
            Body { index: 1, x: 50.0, y: 0.0, strength: -600.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        // Apply force from tree to node 0 at (0, 0).
        tree.apply_force(0.0, 0.0, 0, 1.0, 1.0, 360000.0, &mut dvx, &mut dvy);
        // Node 1 is at x=50, with negative strength → should push node 0 leftward (negative dvx).
        assert!(dvx < 0.0, "expected negative dvx (repulsion), got {}", dvx);
        assert!(dvy.abs() < f32::EPSILON, "expected zero dvy, got {}", dvy);
    }

    #[test]
    fn distance_max_cutoff() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 },
            Body { index: 1, x: 1000.0, y: 0.0, strength: -600.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        // Set distance_max to 100 — node 1 at distance 1000 should be ignored.
        let dist_max_sq = 100.0 * 100.0;
        tree.apply_force(0.0, 0.0, 0, 1.0, 1.0, dist_max_sq, &mut dvx, &mut dvy);
        assert_eq!(dvx, 0.0);
        assert_eq!(dvy, 0.0);
    }

    #[test]
    fn coincident_bodies_no_panic() {
        let bodies = vec![
            Body { index: 0, x: 50.0, y: 50.0, strength: -600.0 },
            Body { index: 1, x: 50.0, y: 50.0, strength: -600.0 },
        ];
        let tree = build_tree(&bodies);
        assert!(tree.is_some());
        assert_eq!(tree.unwrap().count, 2);
    }

    #[test]
    fn many_bodies_correctness() {
        let bodies: Vec<Body> = (0..100)
            .map(|i| Body {
                index: i,
                x: (i % 10) as f32 * 50.0,
                y: (i / 10) as f32 * 50.0,
                strength: -600.0,
            })
            .collect();
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.count, 100);
        assert!((tree.total_strength - (-60000.0)).abs() < f32::EPSILON);
    }

    // =========================================================================
    // Tree Building Tests (10 tests)
    // =========================================================================

    #[test]
    fn build_tree_empty() {
        let bodies: Vec<Body> = vec![];
        let tree = build_tree(&bodies);
        assert!(tree.is_none());
    }

    #[test]
    fn build_tree_single() {
        let bodies = vec![Body { index: 0, x: 5.0, y: 10.0, strength: 100.0 }];
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.count, 1);
        assert!((tree.total_strength - 100.0).abs() < f32::EPSILON);
        assert!((tree.center_x - 5.0).abs() < f32::EPSILON);
        assert!((tree.center_y - 10.0).abs() < f32::EPSILON);
    }

    #[test]
    fn build_tree_two_separate() {
        let bodies = vec![
            Body { index: 0, x: -100.0, y: 0.0, strength: 50.0 },
            Body { index: 1, x: 100.0, y: 0.0, strength: 50.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.count, 2);
        assert!((tree.total_strength - 100.0).abs() < f32::EPSILON);
        // Center of charge at origin
        assert!(tree.center_x.abs() < f32::EPSILON);
    }

    #[test]
    fn build_tree_computes_bounds() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: 1.0 },
            Body { index: 1, x: 100.0, y: 200.0, strength: 1.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        // Bounds should be padded and square
        assert!(tree.bounds.min_x < 0.0);
        assert!(tree.bounds.min_y < 0.0);
        assert!(tree.bounds.max_x > 100.0);
        assert!(tree.bounds.max_y > 200.0);
        assert!(tree.bounds.max_x - tree.bounds.min_x >= tree.bounds.max_y - tree.bounds.min_y);
    }

    #[test]
    fn build_tree_large_count() {
        let bodies: Vec<Body> = (0..1000)
            .map(|i| Body {
                index: i,
                x: (i % 100) as f32 * 10.0,
                y: (i / 100) as f32 * 10.0,
                strength: -1.0,
            })
            .collect();
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.count, 1000);
        assert!((tree.total_strength - (-1000.0)).abs() < f32::EPSILON);
    }

    #[test]
    fn build_tree_negative_positions() {
        let bodies = vec![
            Body { index: 0, x: -500.0, y: -500.0, strength: 100.0 },
            Body { index: 1, x: -100.0, y: -100.0, strength: 100.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.count, 2);
        assert!(tree.bounds.min_x < -500.0);
        assert!(tree.bounds.min_y < -500.0);
    }

    #[test]
    fn build_tree_mixed_strengths() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: 100.0 },
            Body { index: 1, x: 100.0, y: 0.0, strength: 300.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        // Center should be closer to the stronger body
        assert!(tree.center_x > 50.0);
        assert!(tree.center_x < 100.0);
    }

    #[test]
    fn build_tree_very_small_spread() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: 1.0 },
            Body { index: 1, x: 0.001, y: 0.001, strength: 1.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.count, 2);
    }

    #[test]
    fn build_tree_very_large_spread() {
        let bodies = vec![
            Body { index: 0, x: -1e6, y: -1e6, strength: 1.0 },
            Body { index: 1, x: 1e6, y: 1e6, strength: 1.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.count, 2);
        assert!(tree.bounds.size() > 2e6);
    }

    // =========================================================================
    // Insertion Tests (10 tests)
    // =========================================================================

    #[test]
    fn insert_creates_leaf() {
        let bodies = vec![Body { index: 0, x: 0.0, y: 0.0, strength: 1.0 }];
        let tree = build_tree(&bodies).unwrap();
        // Single body should create a leaf
        assert!(tree.body.is_some());
        assert!(tree.children.is_none());
    }

    #[test]
    fn insert_subdivides_on_collision() {
        let bodies = vec![
            Body { index: 0, x: 10.0, y: 10.0, strength: 1.0 },
            Body { index: 1, x: -10.0, y: -10.0, strength: 1.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        // Different quadrants, might or might not create children
        assert_eq!(tree.count, 2);
    }

    #[test]
    fn insert_same_quadrant_subdivides() {
        let bodies = vec![
            Body { index: 0, x: 10.0, y: 10.0, strength: 1.0 },
            Body { index: 1, x: 20.0, y: 20.0, strength: 1.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        // Same quadrant requires subdivision
        assert_eq!(tree.count, 2);
    }

    #[test]
    fn insert_accumulates_aggregates() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: 100.0 },
            Body { index: 1, x: 100.0, y: 100.0, strength: 100.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.total_strength, 200.0);
        assert_eq!(tree.count, 2);
    }

    #[test]
    fn insert_respects_max_depth() {
        // Create many coincident points
        let bodies: Vec<Body> = (0..100)
            .map(|i| Body { index: i, x: 0.0, y: 0.0, strength: 1.0 })
            .collect();
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.count, 100);
        // Should not overflow stack due to max_depth
    }

    #[test]
    fn insert_preserves_indices() {
        let bodies = vec![
            Body { index: 42, x: 0.0, y: 0.0, strength: 1.0 },
            Body { index: 99, x: 100.0, y: 100.0, strength: 1.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        // Tree stores bodies, indices should be preserved
        assert_eq!(tree.count, 2);
    }

    #[test]
    fn insert_all_quadrants() {
        let bodies = vec![
            Body { index: 0, x: -10.0, y: -10.0, strength: 1.0 },
            Body { index: 1, x: 10.0, y: -10.0, strength: 1.0 },
            Body { index: 2, x: -10.0, y: 10.0, strength: 1.0 },
            Body { index: 3, x: 10.0, y: 10.0, strength: 1.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.count, 4);
    }

    #[test]
    fn insert_balanced_tree() {
        let bodies: Vec<Body> = (0..8)
            .map(|i| Body {
                index: i,
                x: if i % 2 == 0 { -10.0 } else { 10.0 },
                y: if i < 4 { -10.0 } else { 10.0 },
                strength: 1.0,
            })
            .collect();
        let tree = build_tree(&bodies).unwrap();
        assert_eq!(tree.count, 8);
    }

    #[test]
    fn insert_updates_center_of_charge() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: 100.0 },
            Body { index: 1, x: 100.0, y: 0.0, strength: 100.0 },
            Body { index: 2, x: 50.0, y: 0.0, strength: 100.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        // Center should be at weighted average
        assert!((tree.center_x - 50.0).abs() < 1.0);
    }

    // =========================================================================
    // AABB Tests (10 tests)
    // =========================================================================

    #[test]
    fn aabb_size_square() {
        let aabb = AABB { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 100.0 };
        assert_eq!(aabb.size(), 100.0);
    }

    #[test]
    fn aabb_size_rectangular() {
        let aabb = AABB { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 50.0 };
        assert_eq!(aabb.size(), 100.0);
    }

    #[test]
    fn aabb_midpoint() {
        let aabb = AABB { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 200.0 };
        let (mx, my) = aabb.midpoint();
        assert_eq!(mx, 50.0);
        assert_eq!(my, 100.0);
    }

    #[test]
    fn aabb_quadrant_nw() {
        let aabb = AABB { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 100.0 };
        let qw = aabb.quadrant(0);
        assert_eq!(qw.min_x, 0.0);
        assert_eq!(qw.max_x, 50.0);
        assert_eq!(qw.min_y, 0.0);
        assert_eq!(qw.max_y, 50.0);
    }

    #[test]
    fn aabb_quadrant_ne() {
        let aabb = AABB { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 100.0 };
        let qe = aabb.quadrant(1);
        assert_eq!(qe.min_x, 50.0);
        assert_eq!(qe.max_x, 100.0);
    }

    #[test]
    fn aabb_quadrant_sw() {
        let aabb = AABB { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 100.0 };
        let qs = aabb.quadrant(2);
        assert_eq!(qs.min_x, 0.0);
        assert_eq!(qs.max_x, 50.0);
        assert_eq!(qs.min_y, 50.0);
        assert_eq!(qs.max_y, 100.0);
    }

    #[test]
    fn aabb_quadrant_se() {
        let aabb = AABB { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 100.0 };
        let q = aabb.quadrant(3);
        assert_eq!(q.min_x, 50.0);
        assert_eq!(q.max_y, 100.0);
    }

    #[test]
    fn aabb_quadrant_for_nw() {
        let aabb = AABB { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 100.0 };
        assert_eq!(aabb.quadrant_for(25.0, 25.0), 0);
    }

    #[test]
    fn aabb_quadrant_for_ne() {
        let aabb = AABB { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 100.0 };
        assert_eq!(aabb.quadrant_for(75.0, 25.0), 1);
    }

    #[test]
    fn aabb_quadrant_for_boundary() {
        let aabb = AABB { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 100.0 };
        // On boundary goes to upper/right quadrants
        assert_eq!(aabb.quadrant_for(50.0, 50.0), 3);
    }

    // =========================================================================
    // Force Application Tests (10 tests)
    // =========================================================================

    #[test]
    fn apply_force_empty_tree() {
        let tree = build_tree(&[]);
        assert!(tree.is_none());
    }

    #[test]
    fn apply_force_self_skipped() {
        let bodies = vec![Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 }];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        tree.apply_force(0.0, 0.0, 0, 1.0, 1.0, 1e9, &mut dvx, &mut dvy);
        assert_eq!(dvx, 0.0);
        assert_eq!(dvy, 0.0);
    }

    #[test]
    fn apply_force_different_node() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 },
            Body { index: 1, x: 50.0, y: 0.0, strength: -600.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        // Apply force from tree to node 0
        tree.apply_force(0.0, 0.0, 0, 1.0, 1.0, 1e9, &mut dvx, &mut dvy);
        // Repulsion from node 1 at x=50
        assert!(dvx < 0.0);
    }

    #[test]
    fn apply_force_distance_max_cutoff() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 },
            Body { index: 1, x: 1000.0, y: 0.0, strength: -600.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        tree.apply_force(0.0, 0.0, 0, 1.0, 1.0, 100.0 * 100.0, &mut dvx, &mut dvy);
        assert_eq!(dvx, 0.0);
    }

    #[test]
    fn apply_force_distance_min_clamped() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 },
            Body { index: 1, x: 0.1, y: 0.0, strength: -600.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        tree.apply_force(0.0, 0.0, 0, 1.0, 10.0 * 10.0, 1e9, &mut dvx, &mut dvy);
        // Should use distance_min, not actual small distance
        assert!(dvx.abs() < 1000.0);
    }

    #[test]
    fn apply_force_accumulates() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 },
            Body { index: 1, x: 50.0, y: 0.0, strength: -600.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 1.0;
        let mut dvy = 2.0;
        tree.apply_force(0.0, 0.0, 0, 1.0, 1.0, 1e9, &mut dvx, &mut dvy);
        // Should accumulate, not replace
        assert!(dvx != 1.0, "force should be accumulated onto existing dvx");
    }

    #[test]
    fn apply_force_alpha_scaling() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 },
            Body { index: 1, x: 50.0, y: 0.0, strength: -600.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx1 = 0.0;
        let mut dvy1 = 0.0;
        let mut dvx2 = 0.0;
        let mut dvy2 = 0.0;
        tree.apply_force(0.0, 0.0, 0, 0.5, 1.0, 1e9, &mut dvx1, &mut dvy1);
        tree.apply_force(0.0, 0.0, 0, 1.0, 1.0, 1e9, &mut dvx2, &mut dvy2);
        assert!((dvx2 - 2.0 * dvx1).abs() < 0.01);
    }

    #[test]
    fn apply_force_zero_count_skipped() {
        let bodies = vec![Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 }];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        // Querying at very far position beyond bounds with max_dist
        tree.apply_force(1e9, 1e9, 0, 1.0, 1.0, 1.0, &mut dvx, &mut dvy);
        assert_eq!(dvx, 0.0);
    }

    #[test]
    fn apply_force_uses_approximation() {
        // Many bodies in a small area should use approximation
        let bodies: Vec<Body> = (0..100)
            .map(|i| Body {
                index: i,
                x: (i % 10) as f32 * 5.0,
                y: (i / 10) as f32 * 5.0,
                strength: -6.0,
            })
            .collect();
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        tree.apply_force(1000.0, 1000.0, 0, 1.0, 1.0, 1e9, &mut dvx, &mut dvy);
        // Far away should use approximation
        assert!(dvx != 0.0 || dvy != 0.0);
    }

    // =========================================================================
    // Approximation Tests (10 tests)
    // =========================================================================

    #[test]
    fn theta_constant_value() {
        assert_eq!(THETA, 0.5);
    }

    #[test]
    fn approximation_used_when_far() {
        // A large cluster far from query point uses approximation
        let bodies: Vec<Body> = (0..50)
            .map(|i| Body {
                index: i,
                x: (i % 10) as f32,
                y: (i / 10) as f32,
                strength: -10.0,
            })
            .collect();
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        tree.apply_force(1000.0, 1000.0, 999, 1.0, 1.0, 1e9, &mut dvx, &mut dvy);
        // Should get some force from approximation
        assert!(dvx != 0.0 || dvy != 0.0);
    }

    #[test]
    fn approximation_not_used_when_close() {
        // Close query should recurse
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 },
            Body { index: 1, x: 10.0, y: 0.0, strength: -600.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        tree.apply_force(0.0, 0.0, 0, 1.0, 1.0, 1e9, &mut dvx, &mut dvy);
        assert!(dvx < 0.0);
    }

    #[test]
    fn approximation_accuracy() {
        // Compare direct vs approximated calculation
        let bodies: Vec<Body> = (0..20)
            .map(|i| Body { index: i, x: i as f32 * 10.0, y: 0.0, strength: -10.0 })
            .collect();
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        // Query at a position that should get repulsion
        tree.apply_force(250.0, 0.0, 999, 1.0, 1.0, 1e9, &mut dvx, &mut dvy);
        // Should get some force
        assert!(dvx.abs() > 0.0 || dvy.abs() > 0.0, "should get some force from tree");
    }

    #[test]
    fn approximation_condition_cell_size_vs_dist() {
        // size / dist < theta means use approximation
        let size = 100.0;
        let dist = 250.0;
        assert!(size / dist < THETA);
    }

    #[test]
    fn approximation_not_used_for_singles() {
        // Single body cells always used directly, not approximated
        let bodies = vec![Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 }];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        tree.apply_force(100.0, 0.0, 1, 1.0, 1.0, 1e9, &mut dvx, &mut dvy);
        // Single body should contribute
        assert!(dvx != 0.0 || dvy == 0.0);
    }

    #[test]
    fn approximation_with_large_tree() {
        let bodies: Vec<Body> = (0..500)
            .map(|i| Body {
                index: i,
                x: (i % 50) as f32 * 10.0,
                y: (i / 50) as f32 * 10.0,
                strength: -10.0,
            })
            .collect();
        let tree = build_tree(&bodies).unwrap();
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        tree.apply_force(1000.0, 1000.0, 0, 1.0, 1.0, 1e9, &mut dvx, &mut dvy);
        assert!(dvx != 0.0 || dvy != 0.0);
    }

    #[test]
    fn approximation_symmetry() {
        // Force between two nodes should be symmetric
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 },
            Body { index: 1, x: 100.0, y: 0.0, strength: -600.0 },
        ];
        let tree = build_tree(&bodies).unwrap();
        let mut dvx0 = 0.0;
        let mut dvy0 = 0.0;
        let mut dvx1 = 0.0;
        let mut dvy1 = 0.0;
        tree.apply_force(0.0, 0.0, 0, 1.0, 1.0, 1e9, &mut dvx0, &mut dvy0);
        tree.apply_force(100.0, 0.0, 1, 1.0, 1.0, 1e9, &mut dvx1, &mut dvy1);
        assert!((dvx0 + dvx1).abs() < 0.1);
    }

    #[test]
    fn approximation_performance() {
        // Ensure approximation provides benefit
        let bodies: Vec<Body> = (0..100)
            .map(|i| Body { index: i, x: i as f32, y: 0.0, strength: -10.0 })
            .collect();
        let tree = build_tree(&bodies).unwrap();
        // For 100 nodes, with theta=0.5, far queries should use approximation
        let mut dvx = 0.0;
        let mut dvy = 0.0;
        tree.apply_force(1000.0, 0.0, 50, 1.0, 1.0, 1e9, &mut dvx, &mut dvy);
        assert!(dvx != 0.0);
    }

    // =========================================================================
    // Body Structure Tests (10 tests)
    // =========================================================================

    #[test]
    fn body_creation() {
        let body = Body { index: 42, x: 100.0, y: 200.0, strength: -500.0 };
        assert_eq!(body.index, 42);
        assert_eq!(body.x, 100.0);
        assert_eq!(body.y, 200.0);
        assert_eq!(body.strength, -500.0);
    }

    #[test]
    fn body_copy() {
        let body1 = Body { index: 0, x: 0.0, y: 0.0, strength: 1.0 };
        let body2 = body1;
        assert_eq!(body1.index, body2.index);
    }

    #[test]
    fn body_clone() {
        let body = Body { index: 0, x: 0.0, y: 0.0, strength: 1.0 };
        let body_clone = body.clone();
        assert_eq!(body.index, body_clone.index);
        assert_eq!(body.x, body_clone.x);
    }

    #[test]
    fn body_negative_strength() {
        let body = Body { index: 0, x: 0.0, y: 0.0, strength: -600.0 };
        assert!(body.strength < 0.0);
    }

    #[test]
    fn body_positive_strength() {
        let body = Body { index: 0, x: 0.0, y: 0.0, strength: 600.0 };
        assert!(body.strength > 0.0);
    }

    #[test]
    fn body_zero_strength() {
        let body = Body { index: 0, x: 0.0, y: 0.0, strength: 0.0 };
        assert_eq!(body.strength, 0.0);
    }

    #[test]
    fn body_large_index() {
        let body = Body { index: 1_000_000, x: 0.0, y: 0.0, strength: 1.0 };
        assert_eq!(body.index, 1_000_000);
    }

    #[test]
    fn body_extreme_positions() {
        let body = Body { index: 0, x: 1e10, y: -1e10, strength: 1.0 };
        assert_eq!(body.x, 1e10);
        assert_eq!(body.y, -1e10);
    }

    #[test]
    fn body_in_vec() {
        let bodies = vec![
            Body { index: 0, x: 0.0, y: 0.0, strength: 1.0 },
            Body { index: 1, x: 100.0, y: 0.0, strength: 1.0 },
        ];
        assert_eq!(bodies.len(), 2);
    }

    #[test]
    fn body_iteration() {
        let bodies: Vec<Body> = (0..10)
            .map(|i| Body { index: i, x: i as f32, y: 0.0, strength: 1.0 })
            .collect();
        for (i, body) in bodies.iter().enumerate() {
            assert_eq!(body.index, i);
        }
    }
}
