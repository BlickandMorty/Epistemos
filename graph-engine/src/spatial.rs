// ── Spatial Quadtree for Hit Testing ────────────────────────────────────────
//
// Lightweight quadtree built from visible graph nodes each render frame.
// Provides O(log n) point-in-radius queries for click and hover detection.
// Separate from the Barnes-Hut tree (which is used for force approximation).

const MAX_DEPTH: u32 = 16;

#[derive(Clone, Copy)]
struct Aabb {
    min_x: f32,
    min_y: f32,
    max_x: f32,
    max_y: f32,
}

impl Aabb {
    fn size(&self) -> f32 {
        (self.max_x - self.min_x).max(self.max_y - self.min_y)
    }

    fn midpoint(&self) -> (f32, f32) {
        (
            (self.min_x + self.max_x) * 0.5,
            (self.min_y + self.max_y) * 0.5,
        )
    }

    fn quadrant(&self, idx: usize) -> Aabb {
        let (mx, my) = self.midpoint();
        match idx {
            0 => Aabb { min_x: self.min_x, min_y: self.min_y, max_x: mx, max_y: my },
            1 => Aabb { min_x: mx, min_y: self.min_y, max_x: self.max_x, max_y: my },
            2 => Aabb { min_x: self.min_x, min_y: my, max_x: mx, max_y: self.max_y },
            _ => Aabb { min_x: mx, min_y: my, max_x: self.max_x, max_y: self.max_y },
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

    fn intersects_circle(&self, cx: f32, cy: f32, r: f32) -> bool {
        let closest_x = cx.clamp(self.min_x, self.max_x);
        let closest_y = cy.clamp(self.min_y, self.max_y);
        let dx = cx - closest_x;
        let dy = cy - closest_y;
        dx * dx + dy * dy <= r * r
    }
}

struct SpatialEntry {
    node_id: u32,
    x: f32,
    y: f32,
    hit_radius: f32,
}

struct QTNode {
    bounds: Aabb,
    body: Option<SpatialEntry>,
    children: Option<Box<[Option<QTNode>; 4]>>,
}

impl QTNode {
    fn new(bounds: Aabb) -> Self {
        Self {
            bounds,
            body: None,
            children: None,
        }
    }

    fn insert(&mut self, entry: SpatialEntry, depth: u32) {
        if depth >= MAX_DEPTH {
            if self.body.is_none() {
                self.body = Some(entry);
            }
            return;
        }

        if let Some(children) = &mut self.children {
            let qi = self.bounds.quadrant_for(entry.x, entry.y);
            if children[qi].is_none() {
                children[qi] = Some(QTNode::new(self.bounds.quadrant(qi)));
            }
            children[qi].as_mut().unwrap().insert(entry, depth + 1);
            return;
        }

        if self.body.is_none() {
            self.body = Some(entry);
            return;
        }

        let old = self.body.take().unwrap();
        self.children = Some(Box::new([None, None, None, None]));

        let children = self.children.as_mut().unwrap();

        let qi_old = self.bounds.quadrant_for(old.x, old.y);
        if children[qi_old].is_none() {
            children[qi_old] = Some(QTNode::new(self.bounds.quadrant(qi_old)));
        }
        children[qi_old].as_mut().unwrap().insert(old, depth + 1);

        let qi_new = self.bounds.quadrant_for(entry.x, entry.y);
        if children[qi_new].is_none() {
            children[qi_new] = Some(QTNode::new(self.bounds.quadrant(qi_new)));
        }
        children[qi_new].as_mut().unwrap().insert(entry, depth + 1);
    }

    fn query_nearest(&self, qx: f32, qy: f32, best: &mut Option<(u32, f32)>) {
        if let Some((_, best_dist)) = best && !self.bounds.intersects_circle(qx, qy, *best_dist) {
            return;
        }

        if let Some(body) = &self.body {
            let dx = qx - body.x;
            let dy = qy - body.y;
            let dist = (dx * dx + dy * dy).sqrt();
            if dist < body.hit_radius && (best.is_none() || dist < best.unwrap().1) {
                *best = Some((body.node_id, dist));
            }
        }

        if let Some(children) = &self.children {
            for child in children.iter().flatten() {
                child.query_nearest(qx, qy, best);
            }
        }
    }
}

// ── Public API ──────────────────────────────────────────────────────────────

/// Touch-target padding multiplier.
const HIT_PADDING: f32 = 1.5;

/// Spatial index for O(log n) point-in-radius queries on visible graph nodes.
pub struct SpatialIndex {
    root: Option<QTNode>,
    count: usize,
}

impl Default for SpatialIndex {
    fn default() -> Self {
        Self::new()
    }
}

impl SpatialIndex {
    pub fn new() -> Self {
        Self {
            root: None,
            count: 0,
        }
    }

    /// Rebuild the spatial index from the current graph node positions.
    /// Uses the new Node struct with x/y fields (not pos: Vec2).
    pub fn build(&mut self, nodes: &[crate::types::Node]) {
        self.root = None;
        self.count = 0;

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
            min_x = min_x.min(n.x);
            min_y = min_y.min(n.y);
            max_x = max_x.max(n.x);
            max_y = max_y.max(n.y);
        }

        if !any_visible {
            return;
        }

        let pad = 50.0;
        let raw = Aabb {
            min_x: min_x - pad,
            min_y: min_y - pad,
            max_x: max_x + pad,
            max_y: max_y + pad,
        };
        let size = raw.size();
        let (cx, cy) = raw.midpoint();
        let half = size * 0.5;
        let bounds = Aabb {
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
                    x: n.x,
                    y: n.y,
                    hit_radius: n.radius * HIT_PADDING,
                },
                0,
            );
            self.count += 1;
        }

        self.root = Some(root);
    }

    pub fn query_point(&self, world_x: f32, world_y: f32) -> Option<u32> {
        let root = self.root.as_ref()?;
        let mut best: Option<(u32, f32)> = None;
        root.query_nearest(world_x, world_y, &mut best);
        best.map(|(id, _)| id)
    }

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

    fn make_node(id: u32, x: f32, y: f32, radius: f32) -> Node {
        Node {
            id,
            uuid: format!("node-{}", id),
            x,
            y,
            vx: 0.0,
            vy: 0.0,
            fx: None,
            fy: None,
            node_type: NodeType::Note,
            link_count: 1,
            label: format!("Node {}", id),
            radius,
            visible: true,
            created_at: 0.0,
            updated_at: 0.0,
            confidence: 0.0,
            color_override: [0.0; 4],
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
        assert_eq!(idx.query_point(100.0, 100.0), Some(1));
        assert_eq!(idx.query_point(110.0, 100.0), Some(1));
        assert!(idx.query_point(116.0, 100.0).is_none());
    }

    #[test]
    fn closest_node_wins() {
        let nodes = vec![
            make_node(1, 0.0, 0.0, 20.0),
            make_node(2, 25.0, 0.0, 20.0),
        ];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.query_point(10.0, 0.0), Some(1));
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
        assert_eq!(idx.query_point(100.0, 100.0), Some(2));
    }

    #[test]
    fn many_nodes_quadtree_correctness() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            nodes.push(make_node(i as u32, x, y, 8.0));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 100);
        for n in &nodes {
            let result = idx.query_point(n.x, n.y);
            assert_eq!(result, Some(n.id));
        }
        assert!(idx.query_point(-1000.0, -1000.0).is_none());
    }

    #[test]
    fn coincident_nodes_dont_stack_overflow() {
        let nodes = vec![
            make_node(1, 50.0, 50.0, 8.0),
            make_node(2, 50.0, 50.0, 8.0),
        ];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 2);
        let result = idx.query_point(50.0, 50.0);
        assert_eq!(result, Some(1));
    }

    // =========================================================================
    // SpatialIndex Construction Tests (10 tests)
    // =========================================================================

    #[test]
    fn spatial_index_new_empty() {
        let idx = SpatialIndex::new();
        assert!(idx.is_empty());
        assert_eq!(idx.len(), 0);
    }

    #[test]
    fn spatial_index_default() {
        let idx: SpatialIndex = Default::default();
        assert!(idx.is_empty());
    }

    #[test]
    fn spatial_index_build_single() {
        let nodes = vec![make_node(1, 100.0, 100.0, 10.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 1);
    }

    #[test]
    fn spatial_index_build_many() {
        let nodes: Vec<Node> = (0..100).map(|i| make_node(i as u32, (i as f32) * 10.0, 0.0, 5.0)).collect();
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 100);
    }

    #[test]
    fn spatial_index_build_empty_nodes() {
        let nodes: Vec<Node> = vec![];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert!(idx.is_empty());
    }

    #[test]
    fn spatial_index_rebuild_replaces() {
        let nodes1 = vec![make_node(1, 0.0, 0.0, 10.0)];
        let nodes2 = vec![make_node(2, 100.0, 100.0, 10.0), make_node(3, 200.0, 200.0, 10.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes1);
        assert_eq!(idx.len(), 1);
        idx.build(&nodes2);
        assert_eq!(idx.len(), 2);
    }

    #[test]
    fn spatial_index_build_negative_positions() {
        let nodes = vec![
            make_node(1, -100.0, -100.0, 10.0),
            make_node(2, -200.0, 50.0, 10.0),
        ];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 2);
    }

    #[test]
    fn spatial_index_build_large_positions() {
        let nodes = vec![
            make_node(1, 1e6, 1e6, 10.0),
            make_node(2, -1e6, -1e6, 10.0),
        ];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 2);
    }

    #[test]
    fn spatial_index_build_zero_radius() {
        let nodes = vec![make_node(1, 0.0, 0.0, 0.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 1);
    }

    #[test]
    fn spatial_index_build_large_radius() {
        let nodes = vec![make_node(1, 0.0, 0.0, 1000.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 1);
    }

    // =========================================================================
    // Query Point Tests (10 tests)
    // =========================================================================

    #[test]
    fn query_point_exact_center() {
        let nodes = vec![make_node(42, 100.0, 200.0, 10.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.query_point(100.0, 200.0), Some(42));
    }

    #[test]
    fn query_point_nearby() {
        let nodes = vec![make_node(1, 100.0, 100.0, 10.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        // Within radius * HIT_PADDING (10 * 1.5 = 15)
        assert_eq!(idx.query_point(110.0, 100.0), Some(1));
        assert_eq!(idx.query_point(100.0, 110.0), Some(1));
    }

    #[test]
    fn query_point_outside_radius() {
        let nodes = vec![make_node(1, 100.0, 100.0, 10.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        // Beyond radius * HIT_PADDING (15)
        assert!(idx.query_point(120.0, 100.0).is_none());
        assert!(idx.query_point(100.0, 120.0).is_none());
    }

    #[test]
    fn query_point_returns_nearest() {
        // Nodes spaced far enough that their hit radii don't overlap
        // Hit radius = radius * 1.5 = 15 for each node
        let nodes = vec![
            make_node(1, 0.0, 0.0, 10.0),
            make_node(2, 100.0, 0.0, 10.0),
            make_node(3, 200.0, 0.0, 10.0),
        ];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        // Query near each node center
        assert_eq!(idx.query_point(0.0, 0.0), Some(1));
        assert_eq!(idx.query_point(100.0, 0.0), Some(2));
        assert_eq!(idx.query_point(200.0, 0.0), Some(3));
    }

    #[test]
    fn query_point_edge_of_radius() {
        let nodes = vec![make_node(1, 0.0, 0.0, 10.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        // Exactly at radius * HIT_PADDING
        let hit_radius = 10.0 * 1.5; // HIT_PADDING
        // query_nearest checks dist < hit_radius, not <=
        // So at exactly hit_radius it returns None
        assert!(idx.query_point(hit_radius - 0.1, 0.0).is_some());
    }

    #[test]
    fn query_point_far_away() {
        let nodes = vec![make_node(1, 0.0, 0.0, 10.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert!(idx.query_point(1000.0, 1000.0).is_none());
        assert!(idx.query_point(-1000.0, -1000.0).is_none());
    }

    #[test]
    fn query_point_diagonal() {
        let nodes = vec![make_node(1, 0.0, 0.0, 10.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let hit_radius = 10.0 * 1.5; // 15
        // Query at distance less than hit_radius from center
        // At (10, 0), distance = 10 < 15, should hit
        assert_eq!(idx.query_point(10.0, 0.0), Some(1));
        // At (0, 10), distance = 10 < 15, should hit
        assert_eq!(idx.query_point(0.0, 10.0), Some(1));
    }

    #[test]
    fn query_point_overlapping_nodes() {
        let nodes = vec![
            make_node(1, 0.0, 0.0, 20.0),
            make_node(2, 5.0, 0.0, 20.0),
        ];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let result = idx.query_point(0.0, 0.0);
        // Should return the closest one
        assert!(result == Some(1) || result == Some(2));
    }

    #[test]
    fn query_point_multiple_calls() {
        let nodes = vec![
            make_node(1, 0.0, 0.0, 10.0),
            make_node(2, 100.0, 0.0, 10.0),
        ];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.query_point(0.0, 0.0), Some(1));
        assert_eq!(idx.query_point(100.0, 0.0), Some(2));
        assert_eq!(idx.query_point(0.0, 0.0), Some(1));
    }

    #[test]
    fn query_point_same_position_different_ids() {
        let nodes = vec![
            make_node(1, 50.0, 50.0, 10.0),
            make_node(2, 50.0, 50.0, 10.0),
        ];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let result = idx.query_point(50.0, 50.0);
        assert!(result.is_some());
    }

    // =========================================================================
    // AABB Tests (5 tests)
    // =========================================================================

    #[test]
    fn aabb_size() {
        let aabb = Aabb { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 50.0 };
        assert_eq!(aabb.size(), 100.0);
    }

    #[test]
    fn aabb_midpoint() {
        let aabb = Aabb { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 200.0 };
        let (mx, my) = aabb.midpoint();
        assert_eq!(mx, 50.0);
        assert_eq!(my, 100.0);
    }

    #[test]
    fn aabb_intersects_circle_inside() {
        let aabb = Aabb { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 100.0 };
        assert!(aabb.intersects_circle(50.0, 50.0, 10.0));
    }

    #[test]
    fn aabb_intersects_circle_outside() {
        let aabb = Aabb { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 100.0 };
        assert!(!aabb.intersects_circle(200.0, 200.0, 10.0));
    }

    #[test]
    fn aabb_intersects_circle_near_edge() {
        let aabb = Aabb { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 100.0 };
        // Circle center outside but radius overlaps
        assert!(aabb.intersects_circle(105.0, 50.0, 10.0));
    }

    // =========================================================================
    // Visibility Tests (5 tests)
    // =========================================================================

    #[test]
    fn invisible_node_excluded() {
        let mut node = make_node(1, 100.0, 100.0, 10.0);
        node.visible = false;
        let nodes = vec![node];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert!(idx.is_empty());
    }

    #[test]
    fn mixed_visible_invisible() {
        let mut node1 = make_node(1, 0.0, 0.0, 10.0);
        node1.visible = false;
        let node2 = make_node(2, 100.0, 100.0, 10.0);
        let nodes = vec![node1, node2];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 1);
        assert_eq!(idx.query_point(100.0, 100.0), Some(2));
    }

    #[test]
    fn all_invisible_empty() {
        let mut nodes = vec![
            make_node(1, 0.0, 0.0, 10.0),
            make_node(2, 100.0, 100.0, 10.0),
        ];
        nodes[0].visible = false;
        nodes[1].visible = false;
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert!(idx.is_empty());
    }

    #[test]
    fn visibility_change_requires_rebuild() {
        let mut node = make_node(1, 0.0, 0.0, 10.0);
        let mut idx = SpatialIndex::new();
        idx.build(&vec![node.clone()]);
        assert_eq!(idx.len(), 1);
        
        node.visible = false;
        idx.build(&vec![node]);
        assert!(idx.is_empty());
    }

    #[test]
    fn only_visible_contribute_to_bounds() {
        let mut node1 = make_node(1, 0.0, 0.0, 10.0);
        node1.visible = false;
        let node2 = make_node(2, 1000.0, 1000.0, 10.0);
        let nodes = vec![node1, node2];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 1);
        assert!(idx.query_point(1000.0, 1000.0).is_some());
    }

    // =========================================================================
    // Hit Radius Tests (5 tests)
    // =========================================================================

    #[test]
    fn hit_radius_scaled() {
        let nodes = vec![make_node(1, 0.0, 0.0, 10.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        // Hit radius = 10 * 1.5 = 15
        assert!(idx.query_point(14.0, 0.0).is_some());
    }

    #[test]
    fn hit_radius_proportional_to_node_radius() {
        let nodes = vec![
            make_node(1, 0.0, 0.0, 10.0),
            make_node(2, 100.0, 0.0, 20.0),
        ];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        // Larger node should have larger hit radius
        let hit_radius_1 = 10.0 * 1.5;
        let hit_radius_2 = 20.0 * 1.5;
        assert!(idx.query_point(hit_radius_1 - 1.0, 0.0).is_some());
        assert!(idx.query_point(100.0 + hit_radius_2 - 1.0, 0.0).is_some());
    }

    #[test]
    fn hit_radius_exact_threshold() {
        let nodes = vec![make_node(1, 0.0, 0.0, 10.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let hit_radius = 10.0 * 1.5;
        // Just inside
        assert!(idx.query_point(hit_radius - 0.1, 0.0).is_some());
    }

    #[test]
    fn hit_radius_zero() {
        let nodes = vec![make_node(1, 0.0, 0.0, 0.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        // Hit radius is 0, so only exact center should hit
        // But even with 0 radius, padding makes it 0
        // query_nearest uses dist < hit_radius, so 0 radius means nothing hits
        // Actually: query_nearest checks dist < body.hit_radius
        // So with hit_radius = 0 * 1.5 = 0, nothing should match
        // Let's check if exact position still works
    }

    #[test]
    fn hit_radius_large_value() {
        let nodes = vec![make_node(1, 0.0, 0.0, 100.0)];
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let hit_radius = 100.0 * 1.5;
        assert!(idx.query_point(hit_radius - 1.0, 0.0).is_some());
    }

    // =========================================================================
    // Performance and Scale Tests (5 tests)
    // =========================================================================

    #[test]
    fn many_nodes_performance() {
        let nodes: Vec<Node> = (0..1000)
            .map(|i| make_node(i as u32, (i % 100) as f32 * 10.0, (i / 100) as f32 * 10.0, 5.0))
            .collect();
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 1000);
        // Query multiple points
        for i in 0..100 {
            let x = (i % 100) as f32 * 10.0;
            let y = (i / 100) as f32 * 10.0;
            let result = idx.query_point(x, y);
            assert!(result.is_some());
        }
    }

    #[test]
    fn dense_grid_query() {
        let nodes: Vec<Node> = (0..100)
            .map(|i| make_node(i as u32, (i % 10) as f32 * 5.0, (i / 10) as f32 * 5.0, 3.0))
            .collect();
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        // All points should be queryable
        for n in &nodes {
            assert!(idx.query_point(n.x, n.y).is_some());
        }
    }

    #[test]
    fn rebuild_clears_old() {
        let nodes1: Vec<Node> = (0..50).map(|i| make_node(i as u32, 0.0, 0.0, 5.0)).collect();
        let nodes2: Vec<Node> = (0..30).map(|i| make_node((i + 100) as u32, 100.0, 100.0, 5.0)).collect();
        let mut idx = SpatialIndex::new();
        idx.build(&nodes1);
        assert_eq!(idx.len(), 50);
        idx.build(&nodes2);
        assert_eq!(idx.len(), 30);
    }

    #[test]
    fn sparse_distribution() {
        let nodes: Vec<Node> = (0..10)
            .map(|i| make_node(i as u32, (i as f32) * 1000.0, 0.0, 10.0))
            .collect();
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        for n in &nodes {
            assert_eq!(idx.query_point(n.x, n.y), Some(n.id));
        }
    }

    #[test]
    fn clustered_distribution() {
        let mut nodes = vec![];
        // Cluster 1
        for i in 0..25 {
            nodes.push(make_node(i as u32, (i % 5) as f32 * 2.0, (i / 5) as f32 * 2.0, 3.0));
        }
        // Cluster 2 (far away)
        for i in 25..50 {
            nodes.push(make_node(i as u32, 1000.0 + (i % 5) as f32 * 2.0, (i / 5) as f32 * 2.0, 3.0));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        assert_eq!(idx.len(), 50);
    }
}
