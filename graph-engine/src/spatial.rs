// ── Spatial Quadtree for Hit Testing ────────────────────────────────────────
// Lightweight quadtree built from visible graph nodes each render frame.
//
// Lightweight quadtree built from visible graph nodes each render frame.
// Provides O(log n) point-in-radius queries for click and hover detection.
// Separate from the Barnes-Hut tree (which lives on the physics thread and
// stores mass/center-of-mass for force approximation).

const MAX_DEPTH: u32 = 16;

/// Axis-aligned bounding box.
#[derive(Clone, Copy)]
struct AABB {
    min_x: f32,
    min_y: f32,
    max_x: f32,
    max_y: f32,
}

impl AABB {
    fn size(&self) -> f32 {
        (self.max_x - self.min_x).max(self.max_y - self.min_y)
    }

    fn midpoint(&self) -> (f32, f32) {
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
        } else {
            if x < mx { 2 } else { 3 }
        }
    }

    /// Does this AABB intersect a circle centered at (cx, cy) with radius r?
    /// Used for early pruning: skip subtrees that can't contain a closer hit.
    fn intersects_circle(&self, cx: f32, cy: f32, r: f32) -> bool {
        let closest_x = cx.clamp(self.min_x, self.max_x);
        let closest_y = cy.clamp(self.min_y, self.max_y);
        let dx = cx - closest_x;
        let dy = cy - closest_y;
        dx * dx + dy * dy <= r * r
    }
}

/// A single entry in the spatial index.
struct SpatialEntry {
    node_id: u32,
    x: f32,
    y: f32,
    hit_radius: f32, // node.radius * HIT_PADDING
}

/// Quadtree node: either a leaf with one body, or an internal node with 4 children.
struct QTNode {
    bounds: AABB,
    body: Option<SpatialEntry>,
    children: Option<Box<[Option<QTNode>; 4]>>,
}

impl QTNode {
    fn new(bounds: AABB) -> Self {
        Self {
            bounds,
            body: None,
            children: None,
        }
    }

    fn insert(&mut self, entry: SpatialEntry, depth: u32) {
        if depth >= MAX_DEPTH {
            // At max depth: store if empty, otherwise accept collision (keep first-inserted).
            // This handles coincident points gracefully — one is clickable, which is fine.
            if self.body.is_none() {
                self.body = Some(entry);
            }
            return;
        }

        // Already subdivided — route to correct child
        if self.children.is_some() {
            let qi = self.bounds.quadrant_for(entry.x, entry.y);
            let children = self.children.as_mut().unwrap();
            if children[qi].is_none() {
                children[qi] = Some(QTNode::new(self.bounds.quadrant(qi)));
            }
            children[qi].as_mut().unwrap().insert(entry, depth + 1);
            return;
        }

        // Empty leaf — store body
        if self.body.is_none() {
            self.body = Some(entry);
            return;
        }

        // Leaf collision — subdivide, re-insert existing + new
        let old = self.body.take().unwrap();
        self.children = Some(Box::new([None, None, None, None]));

        let children = self.children.as_mut().unwrap();

        let qi_old = self.bounds.quadrant_for(old.x, old.y);
        if children[qi_old].is_none() {
            children[qi_old] = Some(QTNode::new(self.bounds.quadrant(qi_old)));
        }
        children[qi_old]
            .as_mut()
            .unwrap()
            .insert(old, depth + 1);

        let qi_new = self.bounds.quadrant_for(entry.x, entry.y);
        if children[qi_new].is_none() {
            children[qi_new] = Some(QTNode::new(self.bounds.quadrant(qi_new)));
        }
        children[qi_new]
            .as_mut()
            .unwrap()
            .insert(entry, depth + 1);
    }

    /// Find the closest node whose hit radius contains the query point.
    /// Uses AABB pruning to skip entire subtrees that can't improve on the
    /// current best distance.
    fn query_nearest(&self, qx: f32, qy: f32, best: &mut Option<(u32, f32)>) {
        // Prune: if we already have a candidate, skip subtrees that can't be closer
        if let Some((_, best_dist)) = best {
            if !self.bounds.intersects_circle(qx, qy, *best_dist) {
                return;
            }
        }

        // Check leaf body
        if let Some(body) = &self.body {
            let dx = qx - body.x;
            let dy = qy - body.y;
            let dist = (dx * dx + dy * dy).sqrt();
            if dist < body.hit_radius {
                if best.is_none() || dist < best.unwrap().1 {
                    *best = Some((body.node_id, dist));
                }
            }
        }

        // Recurse into children
        if let Some(children) = &self.children {
            for child in children.iter().flatten() {
                child.query_nearest(qx, qy, best);
            }
        }
    }
}

// ── Public API ──────────────────────────────────────────────────────────────

/// Touch-target padding multiplier. A node with radius 8px gets a 12px hit zone.
const HIT_PADDING: f32 = 1.5;

/// Spatial index for O(log n) point-in-radius queries on visible graph nodes.
/// Rebuilt each render frame after position sync.
pub struct SpatialIndex {
    root: Option<QTNode>,
    count: usize,
}

impl SpatialIndex {
    pub fn new() -> Self {
        Self {
            root: None,
            count: 0,
        }
    }

    /// Rebuild the spatial index from the current graph node positions.
    /// Only indexes visible nodes. O(n log n) build time.
    pub fn build(&mut self, nodes: &[crate::types::Node]) {
        self.root = None;
        self.count = 0;

        // Compute tight bounding box of visible nodes
        let mut min_x = f32::MAX;
        let mut min_y = f32::MAX;
        let mut max_x = f32::MIN;
        let mut max_y = f32::MIN;
        let mut any_visible = false;

        for n in nodes {
            if !n.visible {
                continue;
            }
            any_visible = true;
            min_x = min_x.min(n.pos.x);
            min_y = min_y.min(n.pos.y);
            max_x = max_x.max(n.pos.x);
            max_y = max_y.max(n.pos.y);
        }

        if !any_visible {
            return;
        }

        // Pad and square the bounds for clean quadrant subdivision
        let pad = 50.0;
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

        let mut root = QTNode::new(bounds);

        for n in nodes {
            if !n.visible {
                continue;
            }
            root.insert(
                SpatialEntry {
                    node_id: n.id,
                    x: n.pos.x,
                    y: n.pos.y,
                    hit_radius: n.radius * HIT_PADDING,
                },
                0,
            );
            self.count += 1;
        }

        self.root = Some(root);
    }

    /// Find the closest visible node within its hit radius to the query point.
    /// Returns the node ID if found. O(log n) average case.
    pub fn query_point(&self, world_x: f32, world_y: f32) -> Option<u32> {
        let root = self.root.as_ref()?;
        let mut best: Option<(u32, f32)> = None;
        root.query_nearest(world_x, world_y, &mut best);
        best.map(|(id, _)| id)
    }

    /// Number of nodes currently indexed.
    pub fn len(&self) -> usize {
        self.count
    }

    pub fn is_empty(&self) -> bool {
        self.count == 0
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{Node, NodeType};
    use glam::Vec2;

    fn make_node(id: u32, x: f32, y: f32, radius: f32) -> Node {
        Node {
            id,
            uuid: format!("node-{}", id),
            pos: Vec2::new(x, y),
            vel: Vec2::ZERO,
            node_type: NodeType::Note,
            weight: 1.0,
            label: format!("Node {}", id),
            radius,
            visible: true,
        }
    }

    #[test]
    fn empty_index_returns_none() {
        let idx = SpatialIndex::new();
        assert!(idx.query_point(0.0, 0.0).is_none());
    }

    #[test]
    fn single_node_hit() {
        let nodes = vec![make_node(1, 100.0, 100.0, 10.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 1);

        // Direct hit
        assert_eq!(idx.query_point(100.0, 100.0), Some(1));
        // Within hit radius (10 * 1.5 = 15)
        assert_eq!(idx.query_point(110.0, 100.0), Some(1));
        // Just outside hit radius
        assert!(idx.query_point(116.0, 100.0).is_none());
    }

    #[test]
    fn closest_node_wins() {
        let nodes = vec![
            make_node(1, 0.0, 0.0, 20.0),   // hit_radius = 30
            make_node(2, 25.0, 0.0, 20.0),   // hit_radius = 30
        ];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);

        // Click at x=10: both are within range, but node 1 is closer
        assert_eq!(idx.query_point(10.0, 0.0), Some(1));
        // Click at x=20: node 2 is closer (dist=5 vs dist=20)
        assert_eq!(idx.query_point(20.0, 0.0), Some(2));
    }

    #[test]
    fn invisible_nodes_excluded() {
        let mut nodes = vec![
            make_node(1, 100.0, 100.0, 10.0),
            make_node(2, 100.0, 100.0, 10.0),
        ];
        nodes[0].visible = false;

        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 1);

        // Should only find node 2
        assert_eq!(idx.query_point(100.0, 100.0), Some(2));
    }

    #[test]
    fn many_nodes_quadtree_correctness() {
        // Place nodes on a grid and verify all are findable
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            nodes.push(make_node(i as u32, x, y, 8.0));
        }

        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 100);

        // Each node should be hittable at its own position
        for n in &nodes {
            let result = idx.query_point(n.pos.x, n.pos.y);
            assert_eq!(result, Some(n.id), "Failed to find node {} at ({}, {})", n.id, n.pos.x, n.pos.y);
        }

        // Far away point should miss
        assert!(idx.query_point(-1000.0, -1000.0).is_none());
    }

    #[test]
    fn coincident_nodes_dont_stack_overflow() {
        // Two nodes at the exact same position — tests MAX_DEPTH guard.
        // The quadtree keeps the first-inserted node at max depth; the second is
        // silently dropped. This is acceptable for hit testing (clicking either
        // coincident node is equivalent).
        let nodes = vec![
            make_node(1, 50.0, 50.0, 8.0),
            make_node(2, 50.0, 50.0, 8.0),
        ];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 2); // Both counted, even though one isn't queryable

        // First-inserted node (id=1) survives at max depth
        let result = idx.query_point(50.0, 50.0);
        assert_eq!(result, Some(1));
    }
}
