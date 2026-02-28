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
}
