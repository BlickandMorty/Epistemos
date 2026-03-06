//! Edge case tests for ECS World, SpatialGrid, and VisualTheme.
//!
//! Covers: empty states, single-entity operations, boundary values,
//! rapid spawn/despawn cycles, invalid enum conversions.

#[cfg(test)]
mod edge_case_tests {
    use crate::ecs::components::*;
    use crate::ecs::spatial_grid::SpatialGrid;
    use crate::ecs::World;
    use crate::types::VisualTheme;

    // ── Empty World Operations ──────────────────────────────────────────────

    #[test]
    fn empty_world_len_and_is_empty() {
        let world = World::new();
        assert_eq!(world.len(), 0);
        assert!(world.is_empty());
    }

    #[test]
    fn despawn_from_empty_world() {
        let mut world = World::new();
        // Despawning a nonexistent entity from an empty world should not panic.
        world.despawn(0);
        world.despawn(u32::MAX);
        world.despawn(42);
        assert!(world.is_empty());
    }

    #[test]
    fn index_of_in_empty_world() {
        let world = World::new();
        assert_eq!(world.index_of(0), None);
        assert_eq!(world.index_of(u32::MAX), None);
    }

    // ── Single Entity ────────────────────────────────────────────────────────

    #[test]
    fn single_entity_spawn_and_despawn() {
        let mut world = World::new();
        let e = world.spawn(TransformComponent { x: 1.0, y: 2.0, scale: 3.0 });
        assert_eq!(world.len(), 1);
        assert!(!world.is_empty());
        assert_eq!(world.index_of(e), Some(0));

        world.despawn(e);
        assert_eq!(world.len(), 0);
        assert!(world.is_empty());
        assert_eq!(world.index_of(e), None);
    }

    #[test]
    fn single_entity_double_despawn() {
        let mut world = World::new();
        let e = world.spawn(TransformComponent { x: 0.0, y: 0.0, scale: 1.0 });
        world.despawn(e);
        // Second despawn of same entity should be a no-op.
        world.despawn(e);
        assert!(world.is_empty());
    }

    #[test]
    fn single_entity_components_correct() {
        let mut world = World::new();
        let e = world.spawn(TransformComponent { x: -999.0, y: 999.0, scale: 0.5 });
        let idx = world.index_of(e).unwrap();

        assert_eq!(world.transform[idx].x, -999.0);
        assert_eq!(world.transform[idx].y, 999.0);
        assert_eq!(world.transform[idx].scale, 0.5);
        // Default components
        assert_eq!(world.velocity[idx].vx, 0.0);
        assert_eq!(world.velocity[idx].vy, 0.0);
        assert_eq!(world.hierarchy[idx].depth, 0);
        assert_eq!(world.hierarchy[idx].parent, u32::MAX);
        assert_eq!(world.ai[idx].state, AIState::Idle as u8);
    }

    // ── Spatial Grid Edge Cases ──────────────────────────────────────────────

    #[test]
    fn spatial_grid_zero_entities() {
        let mut grid = SpatialGrid::new(50.0);
        let entities: Vec<u32> = vec![];
        let transforms: Vec<TransformComponent> = vec![];
        grid.rebuild(&entities, &transforms);

        let result = grid.query_candidates(0.0, 0.0, 1000.0);
        assert!(result.is_empty());

        let neighbors = grid.query_neighbors(0.0, 0.0);
        assert!(neighbors.is_empty());
    }

    #[test]
    fn spatial_grid_single_entity() {
        let mut grid = SpatialGrid::new(50.0);
        grid.insert(0, 25.0, 25.0);

        let result = grid.query_candidates(25.0, 25.0, 10.0);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0], 0);

        let neighbors = grid.query_neighbors(25.0, 25.0);
        assert_eq!(neighbors.len(), 1);
        assert_eq!(neighbors[0], 0);
    }

    #[test]
    fn spatial_grid_single_entity_far_query() {
        let mut grid = SpatialGrid::new(50.0);
        grid.insert(0, 0.0, 0.0);

        // Query very far away — should not find the entity
        let result = grid.query_candidates(10000.0, 10000.0, 10.0);
        assert!(result.is_empty());
    }

    #[test]
    fn spatial_grid_negative_coordinates() {
        let mut grid = SpatialGrid::new(50.0);
        grid.insert(0, -100.0, -200.0);
        grid.insert(1, -110.0, -210.0);

        let result = grid.query_candidates(-105.0, -205.0, 60.0);
        assert!(result.contains(&0));
        assert!(result.contains(&1));
    }

    #[test]
    fn spatial_grid_clear_then_query() {
        let mut grid = SpatialGrid::new(50.0);
        grid.insert(0, 10.0, 10.0);
        grid.insert(1, 20.0, 20.0);
        grid.clear();

        assert!(grid.query_candidates(10.0, 10.0, 100.0).is_empty());
        assert!(grid.query_neighbors(10.0, 10.0).is_empty());
    }

    #[test]
    fn spatial_grid_rebuild_replaces_old_data() {
        let mut grid = SpatialGrid::new(50.0);
        grid.insert(99, 500.0, 500.0);

        let entities = vec![0u32];
        let transforms = vec![
            TransformComponent { x: 0.0, y: 0.0, scale: 1.0 },
        ];
        grid.rebuild(&entities, &transforms);

        // Old entity 99 at (500,500) should be gone
        let far = grid.query_candidates(500.0, 500.0, 10.0);
        assert!(!far.contains(&99));

        // New entity 0 at (0,0) should be present
        let near = grid.query_candidates(0.0, 0.0, 10.0);
        assert!(near.contains(&0));
    }

    // ── Rapid Spawn/Despawn Cycles ───────────────────────────────────────────

    #[test]
    fn rapid_spawn_despawn_interleaved() {
        let mut world = World::new();
        let mut entities = Vec::with_capacity(100);

        // Spawn 100
        for i in 0..100u32 {
            let e = world.spawn(TransformComponent {
                x: i as f32,
                y: -(i as f32),
                scale: 1.0,
            });
            entities.push(e);
        }
        assert_eq!(world.len(), 100);

        // Despawn every other one
        for i in (0..100).step_by(2) {
            world.despawn(entities[i]);
        }
        assert_eq!(world.len(), 50);

        // Spawn 50 more
        for i in 0..50u32 {
            world.spawn(TransformComponent {
                x: 1000.0 + i as f32,
                y: 0.0,
                scale: 1.0,
            });
        }
        assert_eq!(world.len(), 100);

        // Despawn all remaining
        let all: Vec<u32> = world.entities.clone();
        for e in all {
            world.despawn(e);
        }
        assert!(world.is_empty());
    }

    #[test]
    fn rapid_spawn_despawn_same_entity_repeatedly() {
        let mut world = World::new();

        for _ in 0..500 {
            let e = world.spawn(TransformComponent { x: 0.0, y: 0.0, scale: 1.0 });
            assert_eq!(world.len(), 1);
            world.despawn(e);
            assert!(world.is_empty());
        }

        // Entity IDs should have incremented, not reused
        let e = world.spawn(TransformComponent { x: 0.0, y: 0.0, scale: 1.0 });
        assert_eq!(e, 500);
    }

    #[test]
    fn swap_remove_preserves_all_arrays() {
        let mut world = World::new();

        let e0 = world.spawn(TransformComponent { x: 10.0, y: 20.0, scale: 1.0 });
        let e1 = world.spawn(TransformComponent { x: 30.0, y: 40.0, scale: 2.0 });
        let e2 = world.spawn(TransformComponent { x: 50.0, y: 60.0, scale: 3.0 });

        // Set velocity on e2
        let idx2 = world.index_of(e2).unwrap();
        world.velocity[idx2] = VelocityComponent { vx: 7.0, vy: 8.0 };

        // Despawn e0 — e2 should swap into index 0
        world.despawn(e0);
        assert_eq!(world.len(), 2);

        let new_idx2 = world.index_of(e2).unwrap();
        assert_eq!(new_idx2, 0); // e2 moved to index 0
        assert_eq!(world.transform[new_idx2].x, 50.0);
        assert_eq!(world.transform[new_idx2].y, 60.0);
        assert_eq!(world.transform[new_idx2].scale, 3.0);
        assert_eq!(world.velocity[new_idx2].vx, 7.0);
        assert_eq!(world.velocity[new_idx2].vy, 8.0);

        // e1 should still be at index 1
        let idx1 = world.index_of(e1).unwrap();
        assert_eq!(idx1, 1);
        assert_eq!(world.transform[idx1].x, 30.0);
    }

    // ── VisualTheme Edge Cases ───────────────────────────────────────────────

    #[test]
    fn visual_theme_from_u8_valid_values() {
        assert_eq!(VisualTheme::from_u8(0), VisualTheme::Dialogue);
        assert_eq!(VisualTheme::from_u8(1), VisualTheme::Classic);
    }

    #[test]
    fn visual_theme_from_u8_invalid_defaults_to_dialogue() {
        assert_eq!(VisualTheme::from_u8(2), VisualTheme::Dialogue);
        assert_eq!(VisualTheme::from_u8(128), VisualTheme::Dialogue);
        assert_eq!(VisualTheme::from_u8(255), VisualTheme::Dialogue);
        assert_eq!(VisualTheme::from_u8(42), VisualTheme::Dialogue);
    }

    #[test]
    fn visual_theme_repr_values() {
        assert_eq!(VisualTheme::Dialogue as u8, 0);
        assert_eq!(VisualTheme::Classic as u8, 1);
    }

    #[test]
    fn visual_theme_equality() {
        let a = VisualTheme::from_u8(0);
        let b = VisualTheme::from_u8(0);
        assert_eq!(a, b);

        let c = VisualTheme::from_u8(1);
        assert_ne!(a, c);
    }

    // ── AIState Edge Cases ─────────────────────────────────────────────────────

    #[test]
    fn ai_state_all_variants() {
        assert_eq!(AIState::Idle as u8, 0);
        assert_eq!(AIState::Swimming as u8, 1);
        assert_eq!(AIState::AvoidingCursor as u8, 2);
        assert_eq!(AIState::TrailingParent as u8, 3);
        assert_eq!(AIState::Excited as u8, 4);
        assert_eq!(AIState::Sleeping as u8, 5);
    }

    // ── World Physics Array Consistency ──────────────────────────────────────

    #[test]
    fn physics_arrays_grow_with_spawn() {
        let mut world = World::new();
        for _ in 0..10 {
            world.spawn(TransformComponent { x: 0.0, y: 0.0, scale: 1.0 });
        }
        assert_eq!(world.px.len(), 10);
        assert_eq!(world.py.len(), 10);
        assert_eq!(world.pvx.len(), 10);
        assert_eq!(world.pvy.len(), 10);
        assert_eq!(world.pfx.len(), 10);
        assert_eq!(world.pfy.len(), 10);
    }

    #[test]
    fn physics_arrays_shrink_with_despawn() {
        let mut world = World::new();
        let mut entities = Vec::with_capacity(10);
        for _ in 0..10 {
            entities.push(world.spawn(TransformComponent { x: 0.0, y: 0.0, scale: 1.0 }));
        }
        for e in entities {
            world.despawn(e);
        }
        assert_eq!(world.px.len(), 0);
        assert_eq!(world.py.len(), 0);
        assert_eq!(world.pvx.len(), 0);
        assert_eq!(world.pvy.len(), 0);
        assert_eq!(world.pfx.len(), 0);
        assert_eq!(world.pfy.len(), 0);
    }

    #[test]
    fn physics_arrays_spawn_stores_position() {
        let mut world = World::new();
        world.spawn(TransformComponent { x: 42.0, y: -17.5, scale: 1.0 });
        assert_eq!(world.px[0], 42.0);
        assert_eq!(world.py[0], -17.5);
        assert_eq!(world.pvx[0], 0.0);
        assert_eq!(world.pvy[0], 0.0);
        assert_eq!(world.pfx[0], None);
        assert_eq!(world.pfy[0], None);
    }

    // ── Regression: despawn cleans node_id_to_entity ────────────────────────

    #[test]
    fn despawn_cleans_node_id_to_entity() {
        let mut world = World::new();
        let e0 = world.spawn(TransformComponent { x: 0.0, y: 0.0, scale: 1.0 });
        let e1 = world.spawn(TransformComponent { x: 1.0, y: 1.0, scale: 1.0 });

        // Simulate bridge population
        world.node_id_to_entity.insert(100, e0);
        world.entity_to_node_id.insert(e0, 100);
        world.node_id_to_entity.insert(101, e1);
        world.entity_to_node_id.insert(e1, 101);

        world.despawn(e0);

        // node_id 100 should be cleaned up
        assert!(!world.node_id_to_entity.contains_key(&100));
        assert!(!world.entity_to_node_id.contains_key(&e0));
        // node_id 101 should still exist
        assert_eq!(world.node_id_to_entity[&101], e1);
    }

    // ── Regression: grid rebuild uses entity IDs, not array indices ─────────

    #[test]
    fn grid_rebuild_uses_entity_ids_after_swap_remove() {
        let mut world = World::new();
        let e0 = world.spawn(TransformComponent { x: 0.0, y: 0.0, scale: 1.0 });
        let _e1 = world.spawn(TransformComponent { x: 100.0, y: 100.0, scale: 1.0 });
        let e2 = world.spawn(TransformComponent { x: 200.0, y: 200.0, scale: 1.0 });

        // After despawning e0, e2 swaps into index 0.
        // entities = [e2, e1], transforms = [(200,200), (100,100)]
        world.despawn(e0);

        world.spatial_grid.rebuild(&world.entities, &world.transform);

        // Grid should contain e2 (not 0) near (200,200)
        let near_200 = world.spatial_grid.query_candidates(200.0, 200.0, 10.0);
        assert!(near_200.contains(&e2), "grid should store entity ID {e2}, not array index 0");
        assert!(!near_200.contains(&e0), "despawned entity should not be in grid");
    }
}
