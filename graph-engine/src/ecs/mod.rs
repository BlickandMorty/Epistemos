//! ECS World — SoA (Struct of Arrays) storage for cache-friendly iteration.

pub mod components;

pub use components::*;

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
    pub ai: Vec<AIComponent>,
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
            ai: Vec::new(),
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
            ai: Vec::with_capacity(cap),
        }
    }

    pub fn spawn(&mut self, transform: TransformComponent) -> Entity {
        let entity = self.next_entity_id;
        self.next_entity_id += 1;

        let index = self.entities.len();
        self.entities.push(entity);
        self.entity_to_index.insert(entity, index);

        self.transform.push(transform);
        self.velocity.push(VelocityComponent::default());
        self.hierarchy.push(HierarchyComponent::default());
        self.render.push(RenderComponent::default());
        self.ai.push(AIComponent::default());

        entity
    }

    pub fn despawn(&mut self, entity: Entity) {
        let Some(&index) = self.entity_to_index.get(&entity) else {
            return;
        };

        let last = self.entities.len() - 1;

        if index != last {
            // Swap-remove: move last element into the vacated slot
            let moved_entity = self.entities[last];
            self.entities[index] = moved_entity;
            self.transform[index] = self.transform[last];
            self.velocity[index] = self.velocity[last];
            self.hierarchy[index] = self.hierarchy[last];
            self.render[index] = self.render[last];
            self.ai[index] = self.ai[last];

            self.entity_to_index.insert(moved_entity, index);
        }

        self.entities.pop();
        self.transform.pop();
        self.velocity.pop();
        self.hierarchy.pop();
        self.render.pop();
        self.ai.pop();

        self.entity_to_index.remove(&entity);
    }

    pub fn len(&self) -> usize {
        self.entities.len()
    }

    pub fn index_of(&self, entity: Entity) -> Option<usize> {
        self.entity_to_index.get(&entity).copied()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
        // e1 should have been swapped into index 0
        let idx = world.index_of(e1).unwrap();
        assert_eq!(idx, 0);
        assert_eq!(world.transform[0].x, 30.0);
        assert_eq!(world.transform[0].y, 40.0);
        assert!(world.index_of(e0).is_none());
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
    }

    #[test]
    fn test_despawn_last() {
        let mut world = World::new();
        let t0 = TransformComponent { x: 1.0, y: 2.0, scale: 1.0 };
        let t1 = TransformComponent { x: 3.0, y: 4.0, scale: 1.0 };
        let e0 = world.spawn(t0);
        let e1 = world.spawn(t1);

        // Despawn last — no swap needed
        world.despawn(e1);

        assert_eq!(world.len(), 1);
        assert!(world.index_of(e1).is_none());
        let idx = world.index_of(e0).unwrap();
        assert_eq!(idx, 0);
        assert_eq!(world.transform[0].x, 1.0);
    }

    #[test]
    fn test_despawn_nonexistent() {
        let mut world = World::new();
        let t = TransformComponent { x: 1.0, y: 2.0, scale: 1.0 };
        world.spawn(t);

        // Despawn entity that doesn't exist — should be no-op
        world.despawn(999);

        assert_eq!(world.len(), 1);
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

        // After despawning e0, e2 moves to index 0
        world.despawn(e0);

        assert_eq!(world.index_of(e0), None);
        assert_eq!(world.index_of(e1), Some(1));
        assert_eq!(world.index_of(e2), Some(0));
    }
}
