//! Comprehensive tests for theme system and ECS integration.
//!
//! Covers: theme switching, ECS spawn at scale,
//! SpatialGrid correctness, World::from_graph bridge, and node_id_to_entity lookups.

#[cfg(test)]
mod tests {
    use crate::ecs::World;
    use crate::ecs::components::*;
    use crate::ecs::spatial_grid::SpatialGrid;
    use crate::types::{Graph, NodeType, VisualTheme};

    // ── Theme Switching ──────────────────────────────────────────────────────

    #[test]
    fn theme_dialogue_is_default() {
        let theme = VisualTheme::from_u8(0);
        assert_eq!(theme, VisualTheme::Dialogue);
    }

    #[test]
    fn theme_switch_dialogue_to_classic() {
        let mut theme = VisualTheme::Dialogue;
        assert_eq!(theme, VisualTheme::Dialogue);

        theme = VisualTheme::from_u8(1);
        assert_eq!(theme, VisualTheme::Classic);
    }

    #[test]
    fn theme_switch_classic_to_dialogue() {
        let theme = VisualTheme::from_u8(0);
        assert_eq!(theme, VisualTheme::Dialogue);
    }

    #[test]
    fn theme_classic_colors_valid() {
        for nt in 0..=7u8 {
            let color = NodeType::from_u8(nt).color();
            assert_eq!(
                color[3], 1.0,
                "classic mode node colors should be fully opaque"
            );
        }
    }

    // ── ECS Spawn at Scale ───────────────────────────────────────────────────

    #[test]
    fn spawn_1000_verify_count() {
        let mut world = World::with_capacity(1000);
        for i in 0..1000u32 {
            world.spawn(TransformComponent {
                x: i as f32,
                y: -(i as f32),
                scale: 1.0,
            });
        }
        assert_eq!(world.len(), 1000);
    }

    #[test]
    fn spawn_1000_despawn_half_verify_count() {
        let mut world = World::with_capacity(1000);
        let mut entities = Vec::with_capacity(1000);
        for i in 0..1000u32 {
            entities.push(world.spawn(TransformComponent {
                x: i as f32,
                y: 0.0,
                scale: 1.0,
            }));
        }
        assert_eq!(world.len(), 1000);

        // Despawn first 500
        for entity in entities.iter().take(500) {
            world.despawn(*entity);
        }
        assert_eq!(world.len(), 500);

        // All remaining entities should still be findable
        for entity in entities.iter().take(1000).skip(500) {
            assert!(
                world.index_of(*entity).is_some(),
                "entity {} should still exist",
                entity
            );
        }
    }

    #[test]
    fn spawn_1000_verify_positions() {
        let mut world = World::with_capacity(1000);
        let mut entities = Vec::with_capacity(1000);
        for i in 0..1000u32 {
            entities.push(world.spawn(TransformComponent {
                x: i as f32 * 10.0,
                y: -(i as f32) * 5.0,
                scale: 1.0 + (i as f32) * 0.001,
            }));
        }

        for (i, &e) in entities.iter().enumerate() {
            let idx = world.index_of(e).unwrap();
            let expected_x = i as f32 * 10.0;
            let expected_y = -(i as f32) * 5.0;
            assert!((world.transform[idx].x - expected_x).abs() < 0.001);
            assert!((world.transform[idx].y - expected_y).abs() < 0.001);
        }
    }

    // ── SpatialGrid Correctness ──────────────────────────────────────────────

    #[test]
    fn spatial_grid_known_positions_exact_results() {
        let mut grid = SpatialGrid::new(100.0);

        // Place entities at known positions
        grid.insert(0, 0.0, 0.0);
        grid.insert(1, 50.0, 50.0);
        grid.insert(2, 200.0, 200.0);
        grid.insert(3, 300.0, 300.0);
        grid.insert(4, -100.0, -100.0);

        // Query at origin with radius 110 — should find entities in nearby cells
        let nearby = grid.query_candidates(0.0, 0.0, 110.0);
        assert!(nearby.contains(&0), "entity 0 at origin should be found");
        assert!(nearby.contains(&1), "entity 1 at (50,50) should be found");
        assert!(
            nearby.contains(&4),
            "entity 4 at (-100,-100) should be found"
        );
        // Entity 2 at (200,200) is too far
        assert!(!nearby.contains(&2), "entity 2 should be too far");
        assert!(!nearby.contains(&3), "entity 3 should be too far");
    }

    #[test]
    fn spatial_grid_rebuild_from_transforms() {
        let entities: Vec<u32> = vec![0, 1, 2];
        let transforms = vec![
            TransformComponent {
                x: 0.0,
                y: 0.0,
                scale: 1.0,
            },
            TransformComponent {
                x: 10.0,
                y: 10.0,
                scale: 1.0,
            },
            TransformComponent {
                x: 500.0,
                y: 500.0,
                scale: 1.0,
            },
        ];

        let mut grid = SpatialGrid::new(50.0);
        grid.rebuild(&entities, &transforms);

        // Entities 0 and 1 are in same cell (0,0), entity 2 is far away
        let neighbors = grid.query_neighbors(5.0, 5.0);
        assert!(neighbors.contains(&0));
        assert!(neighbors.contains(&1));
        assert!(!neighbors.contains(&2));
    }

    #[test]
    fn spatial_grid_cell_boundary() {
        let mut grid = SpatialGrid::new(100.0);

        // Place entity exactly at cell boundary
        grid.insert(0, 100.0, 100.0); // cell (1, 1)
        grid.insert(1, 99.99, 99.99); // cell (0, 0) — just below boundary

        // Query_neighbors from (99,99) checks cells (-1,-1) to (1,1) — should find both
        let neighbors = grid.query_neighbors(99.0, 99.0);
        assert!(neighbors.contains(&0));
        assert!(neighbors.contains(&1));
    }

    // ── World::from_graph Bridge ─────────────────────────────────────────────

    #[test]
    fn from_graph_empty_produces_empty_world() {
        let graph = Graph::new();
        let world = World::from_graph(&graph);
        assert!(world.is_empty());
        assert!(world.node_id_to_entity.is_empty());
    }

    #[test]
    fn from_graph_preserves_all_node_types() {
        let mut graph = Graph::new();
        for nt in 0..=7u8 {
            graph.add_node(
                format!("node-{nt}"),
                nt as f32 * 100.0,
                0.0,
                nt,
                1,
                format!("Node {nt}"),
            );
        }

        let world = World::from_graph(&graph);
        assert_eq!(world.len(), 8);

        for nt in 0..=7u8 {
            let entity = world.node_id_to_entity[&u32::from(nt)];
            let idx = world.index_of(entity).unwrap();
            assert_eq!(world.hierarchy[idx].node_type, nt);
        }
    }

    // ── node_id_to_entity Lookup ─────────────────────────────────────────────

    #[test]
    fn node_id_to_entity_lookup_all_nodes() {
        let mut graph = Graph::new();
        for i in 0..50 {
            graph.add_node(
                format!("uuid-{i}"),
                i as f32,
                i as f32,
                (i % 8) as u8,
                i,
                format!("Node {i}"),
            );
        }

        let world = World::from_graph(&graph);
        assert_eq!(world.node_id_to_entity.len(), 50);

        for i in 0..50u32 {
            let entity = world.node_id_to_entity.get(&i);
            assert!(
                entity.is_some(),
                "graph node id {i} should have a mapped entity"
            );
            let idx = world.index_of(*entity.unwrap());
            assert!(
                idx.is_some(),
                "entity for graph node {i} should exist in world"
            );
        }
    }

    #[test]
    fn node_id_to_entity_missing_id() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());

        let world = World::from_graph(&graph);
        assert!(!world.node_id_to_entity.contains_key(&999));
    }

    // ── from_graph + Spatial Grid ────────────────────────────────────────────

    #[test]
    fn from_graph_rebuilds_spatial_grid() {
        let mut graph = Graph::new();
        graph.add_node("near".into(), 10.0, 10.0, 0, 1, "Near".into());
        graph.add_node("also-near".into(), 20.0, 20.0, 0, 1, "Also Near".into());
        graph.add_node("far".into(), 1000.0, 1000.0, 0, 1, "Far".into());

        let world = World::from_graph(&graph);

        // Spatial grid should have been rebuilt — query near origin
        let neighbors = world.spatial_grid.query_neighbors(15.0, 15.0);
        assert!(neighbors.contains(&0), "near entity should be found");
        assert!(neighbors.contains(&1), "also-near entity should be found");
        assert!(!neighbors.contains(&2), "far entity should not be found");
    }

    #[test]
    fn visual_theme_is_repr_u8() {
        assert_eq!(std::mem::size_of::<VisualTheme>(), 1);
    }
}
