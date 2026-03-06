//! ECS World — SoA (Struct of Arrays) storage for cache-friendly iteration.

pub mod bridge;
pub mod components;
pub mod spatial_grid;
pub mod systems;

pub use components::*;
pub use spatial_grid::SpatialGrid;

use rustc_hash::FxHashMap;

pub type Entity = u32;

pub struct World {
    pub entities: Vec<Entity>,
    pub entity_to_index: FxHashMap<u32, usize>,
    next_entity_id: u32,

    // SoA components
    pub transform: Vec<TransformComponent>,
    pub velocity: Vec<VelocityComponent>,
    pub hierarchy: Vec<HierarchyComponent>,
    pub render: Vec<RenderComponent>,
    pub graph_node: Vec<GraphNodeComponent>,
    pub ai: Vec<AIComponent>,
    pub edges: Vec<EdgeComponent>,
    pub edge_adjacency: Vec<Vec<usize>>,
    pub spatial_grid: SpatialGrid,

    /// Maps Graph node IDs to ECS entity IDs for FFI lookups during migration.
    pub node_id_to_entity: FxHashMap<u32, Entity>,
    /// Reverse map: entity ID → graph node ID, for cleanup on despawn.
    pub entity_to_node_id: FxHashMap<Entity, u32>,

    // Physics hot-path SoA arrays — flat f32 slices for force functions.
    // Duplicates transform.x/y and velocity.vx/vy to avoid struct-of-struct
    // indirection in the inner physics loop (forces take &[f32] / &mut [f32]).
    pub px: Vec<f32>,
    pub py: Vec<f32>,
    pub pvx: Vec<f32>,
    pub pvy: Vec<f32>,
    pub pfx: Vec<Option<f32>>,
    pub pfy: Vec<Option<f32>>,
}

impl Default for World {
    fn default() -> Self {
        Self::new()
    }
}

impl World {
    pub fn new() -> Self {
        Self {
            entities: Vec::new(),
            entity_to_index: FxHashMap::default(),
            next_entity_id: 0,
            transform: Vec::new(),
            velocity: Vec::new(),
            hierarchy: Vec::new(),
            render: Vec::new(),
            graph_node: Vec::new(),
            ai: Vec::new(),
            edges: Vec::new(),
            edge_adjacency: Vec::new(),
            spatial_grid: SpatialGrid::new(50.0),
            node_id_to_entity: FxHashMap::default(),
            entity_to_node_id: FxHashMap::default(),
            px: Vec::new(),
            py: Vec::new(),
            pvx: Vec::new(),
            pvy: Vec::new(),
            pfx: Vec::new(),
            pfy: Vec::new(),
        }
    }

    pub fn with_capacity(cap: usize) -> Self {
        Self {
            entities: Vec::with_capacity(cap),
            entity_to_index: FxHashMap::with_capacity_and_hasher(cap, Default::default()),
            next_entity_id: 0,
            transform: Vec::with_capacity(cap),
            velocity: Vec::with_capacity(cap),
            hierarchy: Vec::with_capacity(cap),
            render: Vec::with_capacity(cap),
            graph_node: Vec::with_capacity(cap),
            ai: Vec::with_capacity(cap),
            edges: Vec::with_capacity(cap.saturating_mul(2)),
            edge_adjacency: Vec::with_capacity(cap),
            spatial_grid: SpatialGrid::new(50.0),
            node_id_to_entity: FxHashMap::with_capacity_and_hasher(cap, Default::default()),
            entity_to_node_id: FxHashMap::with_capacity_and_hasher(cap, Default::default()),
            px: Vec::with_capacity(cap),
            py: Vec::with_capacity(cap),
            pvx: Vec::with_capacity(cap),
            pvy: Vec::with_capacity(cap),
            pfx: Vec::with_capacity(cap),
            pfy: Vec::with_capacity(cap),
        }
    }

    pub fn spawn(&mut self, transform: TransformComponent) -> Entity {
        debug_assert!(self.next_entity_id < u32::MAX, "entity ID space exhausted");
        let entity = self.next_entity_id;
        self.next_entity_id = self.next_entity_id.wrapping_add(1);

        let index = self.entities.len();
        self.entities.push(entity);
        self.entity_to_index.insert(entity, index);

        self.transform.push(transform);
        self.velocity.push(VelocityComponent::default());
        self.hierarchy.push(HierarchyComponent::default());
        self.render.push(RenderComponent::default());
        self.graph_node.push(GraphNodeComponent::default());
        self.ai.push(AIComponent::default());
        self.edge_adjacency.push(Vec::new());

        self.px.push(transform.x);
        self.py.push(transform.y);
        self.pvx.push(0.0);
        self.pvy.push(0.0);
        self.pfx.push(None);
        self.pfy.push(None);

        entity
    }

    pub fn despawn(&mut self, entity: Entity) {
        let Some(&index) = self.entity_to_index.get(&entity) else {
            return;
        };

        let Some(last) = self.entities.len().checked_sub(1) else {
            return;
        };

        if index != last {
            // Swap-remove: move last element into the vacated slot
            let moved_entity = self.entities[last];
            self.entities[index] = moved_entity;
            self.transform[index] = self.transform[last];
            self.velocity[index] = self.velocity[last];
            self.hierarchy[index] = self.hierarchy[last];
            self.render[index] = self.render[last];
            self.graph_node[index] = self.graph_node[last];
            self.ai[index] = self.ai[last];
            self.px[index] = self.px[last];
            self.py[index] = self.py[last];
            self.pvx[index] = self.pvx[last];
            self.pvy[index] = self.pvy[last];
            self.pfx[index] = self.pfx[last];
            self.pfy[index] = self.pfy[last];

            self.entity_to_index.insert(moved_entity, index);
        }

        self.entities.pop();
        self.transform.pop();
        self.velocity.pop();
        self.hierarchy.pop();
        self.render.pop();
        self.graph_node.pop();
        self.ai.pop();
        self.edge_adjacency.pop();
        self.px.pop();
        self.py.pop();
        self.pvx.pop();
        self.pvy.pop();
        self.pfx.pop();
        self.pfy.pop();

        self.entity_to_index.remove(&entity);

        // Clean up node_id_to_entity reverse mapping
        if let Some(node_id) = self.entity_to_node_id.remove(&entity) {
            self.node_id_to_entity.remove(&node_id);
        }

        self.edges.retain(|edge| edge.source != entity && edge.target != entity);
        self.rebuild_edge_adjacency();
    }

    pub fn len(&self) -> usize {
        self.entities.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entities.is_empty()
    }

    pub fn index_of(&self, entity: Entity) -> Option<usize> {
        self.entity_to_index.get(&entity).copied()
    }

    pub fn entity_of_node_id(&self, node_id: u32) -> Option<Entity> {
        self.node_id_to_entity.get(&node_id).copied()
    }

    pub fn index_of_node_id(&self, node_id: u32) -> Option<usize> {
        self.entity_of_node_id(node_id)
            .and_then(|entity| self.index_of(entity))
    }

    pub fn edge_indices_for_index(&self, index: usize) -> &[usize] {
        self.edge_adjacency
            .get(index)
            .map(Vec::as_slice)
            .unwrap_or(&[])
    }

    pub fn rebuild_edge_adjacency(&mut self) {
        if self.edge_adjacency.len() < self.len() {
            self.edge_adjacency.resize_with(self.len(), Vec::new);
        }
        for neighbors in &mut self.edge_adjacency {
            neighbors.clear();
        }

        for (edge_index, edge) in self.edges.iter().enumerate() {
            if let Some(src_index) = self.index_of(edge.source) {
                self.edge_adjacency[src_index].push(edge_index);
            }
            if let Some(tgt_index) = self.index_of(edge.target) {
                self.edge_adjacency[tgt_index].push(edge_index);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn assert_world_invariants(world: &World) {
        let n = world.entities.len();
        assert_eq!(world.transform.len(), n);
        assert_eq!(world.velocity.len(), n);
        assert_eq!(world.hierarchy.len(), n);
        assert_eq!(world.render.len(), n);
        assert_eq!(world.graph_node.len(), n);
        assert_eq!(world.ai.len(), n);
        assert_eq!(world.edge_adjacency.len(), n);
        assert_eq!(world.entity_to_index.len(), n);
        assert_eq!(world.px.len(), n);
        assert_eq!(world.py.len(), n);
        assert_eq!(world.pvx.len(), n);
        assert_eq!(world.pvy.len(), n);
        assert_eq!(world.pfx.len(), n);
        assert_eq!(world.pfy.len(), n);
    }

    #[test]
    fn test_world_add_entity() {
        let mut world = World::new();
        let t = TransformComponent { x: 1.0, y: 2.0, scale: 3.0 };
        let e = world.spawn(t);

        assert_eq!(world.len(), 1);
        let idx = world.index_of(e).unwrap();
        assert_eq!(world.transform[idx].x, 1.0);
        assert_eq!(world.transform[idx].y, 2.0);
        assert_eq!(world.transform[idx].scale, 3.0);
        assert_world_invariants(&world);
    }

    #[test]
    fn test_world_remove_entity() {
        let mut world = World::new();
        let t0 = TransformComponent { x: 10.0, y: 20.0, scale: 1.0 };
        let t1 = TransformComponent { x: 30.0, y: 40.0, scale: 2.0 };
        let e0 = world.spawn(t0);
        let e1 = world.spawn(t1);

        world.despawn(e0);

        assert_eq!(world.len(), 1);
        let idx = world.index_of(e1).unwrap();
        assert_eq!(idx, 0);
        assert_eq!(world.transform[0].x, 30.0);
        assert_eq!(world.transform[0].y, 40.0);
        assert!(world.index_of(e0).is_none());
        assert_world_invariants(&world);
    }

    #[test]
    fn test_world_with_capacity() {
        let world = World::with_capacity(1024);

        assert_eq!(world.len(), 0);
        assert!(world.transform.capacity() >= 1024);
        assert!(world.velocity.capacity() >= 1024);
        assert!(world.hierarchy.capacity() >= 1024);
        assert!(world.render.capacity() >= 1024);
        assert!(world.ai.capacity() >= 1024);
        assert!(world.entities.capacity() >= 1024);
        assert!(world.px.capacity() >= 1024);
        assert!(world.py.capacity() >= 1024);
        assert!(world.pvx.capacity() >= 1024);
        assert!(world.pvy.capacity() >= 1024);
        assert!(world.pfx.capacity() >= 1024);
        assert!(world.pfy.capacity() >= 1024);
        assert_world_invariants(&world);
    }

    #[test]
    fn test_spawn_multiple() {
        let mut world = World::new();
        let mut ids = Vec::with_capacity(100);

        for i in 0..100u32 {
            let t = TransformComponent { x: i as f32, y: 0.0, scale: 1.0 };
            ids.push(world.spawn(t));
        }

        assert_eq!(world.len(), 100);
        for (i, &e) in ids.iter().enumerate() {
            let idx = world.index_of(e).unwrap();
            assert_eq!(world.transform[idx].x, i as f32);
        }
        assert_world_invariants(&world);
    }

    #[test]
    fn test_despawn_last() {
        let mut world = World::new();
        let t0 = TransformComponent { x: 1.0, y: 2.0, scale: 1.0 };
        let t1 = TransformComponent { x: 3.0, y: 4.0, scale: 1.0 };
        let e0 = world.spawn(t0);
        let e1 = world.spawn(t1);

        world.despawn(e1);

        assert_eq!(world.len(), 1);
        assert!(world.index_of(e1).is_none());
        let idx = world.index_of(e0).unwrap();
        assert_eq!(idx, 0);
        assert_eq!(world.transform[0].x, 1.0);
        assert_world_invariants(&world);
    }

    #[test]
    fn test_despawn_nonexistent() {
        let mut world = World::new();
        let t = TransformComponent { x: 1.0, y: 2.0, scale: 1.0 };
        world.spawn(t);

        world.despawn(999);

        assert_eq!(world.len(), 1);
        assert_world_invariants(&world);
    }

    #[test]
    fn test_index_of() {
        let mut world = World::new();
        let t0 = TransformComponent { x: 0.0, y: 0.0, scale: 1.0 };
        let t1 = TransformComponent { x: 1.0, y: 1.0, scale: 1.0 };
        let t2 = TransformComponent { x: 2.0, y: 2.0, scale: 1.0 };
        let e0 = world.spawn(t0);
        let e1 = world.spawn(t1);
        let e2 = world.spawn(t2);

        assert_eq!(world.index_of(e0), Some(0));
        assert_eq!(world.index_of(e1), Some(1));
        assert_eq!(world.index_of(e2), Some(2));

        world.despawn(e0);

        assert_eq!(world.index_of(e0), None);
        assert_eq!(world.index_of(e1), Some(1));
        assert_eq!(world.index_of(e2), Some(0));
        assert_world_invariants(&world);
    }

    #[test]
    fn test_full_cycle_consistency() {
        let mut world = World::with_capacity(4);
        let e0 = world.spawn(TransformComponent { x: 0.0, y: 0.0, scale: 1.0 });
        let e1 = world.spawn(TransformComponent { x: 1.0, y: 1.0, scale: 1.0 });
        let e2 = world.spawn(TransformComponent { x: 2.0, y: 2.0, scale: 1.0 });

        world.despawn(e1); // middle swap — e2 moves to index 1
        assert_world_invariants(&world);

        world.despawn(e0); // e2 (now at index 0 after swap) stays, e0 removed
        assert_world_invariants(&world);

        assert_eq!(world.len(), 1);
        let idx = world.index_of(e2).unwrap();
        assert_eq!(world.transform[idx].x, 2.0);

        // Re-spawn after full cycle — new IDs, no collision
        let e3 = world.spawn(TransformComponent { x: 3.0, y: 3.0, scale: 1.0 });
        assert_eq!(world.len(), 2);
        assert!(world.index_of(e0).is_none());
        assert!(world.index_of(e1).is_none());
        assert!(world.index_of(e3).is_some());
        assert_world_invariants(&world);
    }

    #[test]
    fn test_despawn_removes_incident_edges() {
        let mut world = World::new();
        let e0 = world.spawn(TransformComponent { x: 0.0, y: 0.0, scale: 1.0 });
        let e1 = world.spawn(TransformComponent { x: 1.0, y: 1.0, scale: 1.0 });
        let e2 = world.spawn(TransformComponent { x: 2.0, y: 2.0, scale: 1.0 });
        world.edges.push(EdgeComponent { source: e0, target: e1, weight: 1.0, edge_type: 0, _pad0: [0; 3] });
        world.edges.push(EdgeComponent { source: e1, target: e2, weight: 1.0, edge_type: 0, _pad0: [0; 3] });
        world.edges.push(EdgeComponent { source: e0, target: e2, weight: 1.0, edge_type: 0, _pad0: [0; 3] });
        world.rebuild_edge_adjacency();

        world.despawn(e1);

        assert_eq!(world.edges.len(), 1);
        assert_eq!(world.edges[0].source, e0);
        assert_eq!(world.edges[0].target, e2);
        let e0_index = world.index_of(e0).unwrap();
        let e2_index = world.index_of(e2).unwrap();
        assert_eq!(world.edge_indices_for_index(e0_index), &[0]);
        assert_eq!(world.edge_indices_for_index(e2_index), &[0]);
    }

    #[test]
    fn test_rebuild_edge_adjacency_tracks_incident_edges() {
        let mut world = World::new();
        let e0 = world.spawn(TransformComponent { x: 0.0, y: 0.0, scale: 1.0 });
        let e1 = world.spawn(TransformComponent { x: 1.0, y: 0.0, scale: 1.0 });
        let e2 = world.spawn(TransformComponent { x: 2.0, y: 0.0, scale: 1.0 });

        world.edges.push(EdgeComponent { source: e0, target: e1, weight: 1.0, edge_type: 0, _pad0: [0; 3] });
        world.edges.push(EdgeComponent { source: e1, target: e2, weight: 1.0, edge_type: 0, _pad0: [0; 3] });
        world.rebuild_edge_adjacency();

        let i0 = world.index_of(e0).unwrap();
        let i1 = world.index_of(e1).unwrap();
        let i2 = world.index_of(e2).unwrap();
        assert_eq!(world.edge_indices_for_index(i0), &[0]);
        assert_eq!(world.edge_indices_for_index(i1), &[0, 1]);
        assert_eq!(world.edge_indices_for_index(i2), &[1]);
    }

    #[test]
    fn test_is_empty() {
        let mut world = World::new();
        assert!(world.is_empty());

        let e = world.spawn(TransformComponent { x: 0.0, y: 0.0, scale: 1.0 });
        assert!(!world.is_empty());

        world.despawn(e);
        assert!(world.is_empty());
        assert_world_invariants(&world);
    }
}
