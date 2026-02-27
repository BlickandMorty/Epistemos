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
}
