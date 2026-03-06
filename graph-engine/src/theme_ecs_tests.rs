//! Comprehensive tests for theme system and ECS integration.
//!
//! Covers: theme switching, palette color overrides, ECS spawn at scale,
//! SpatialGrid correctness, World::from_graph bridge, and node_id_to_entity lookups.

#[cfg(test)]
mod theme_ecs_tests {
    use crate::ecs::components::*;
    use crate::ecs::spatial_grid::SpatialGrid;
    use crate::ecs::World;
    use crate::types::{Graph, NodeType, VisualTheme, VoxelPalette};

    // ── Theme Switching ──────────────────────────────────────────────────────

    #[test]
    fn theme_pixel_is_default() {
        let theme = VisualTheme::from_u8(0);
        assert_eq!(theme, VisualTheme::Pixel);
    }

    #[test]
    fn theme_switch_pixel_to_classic() {
        let mut theme = VisualTheme::Pixel;
        assert_eq!(theme, VisualTheme::Pixel);

        theme = VisualTheme::from_u8(1);
        assert_eq!(theme, VisualTheme::Classic);
    }

    #[test]
    fn theme_switch_classic_to_pixel() {
        let mut theme = VisualTheme::Classic;
        theme = VisualTheme::from_u8(0);
        assert_eq!(theme, VisualTheme::Pixel);
    }

    #[test]
    fn theme_paired_with_palette() {
        // Pixel theme uses VoxelPalette; Classic uses NodeType::color().
        // Verify both paths produce valid colors.
        let pixel_palette = VoxelPalette::dark();
        for block_type in 0..=4u8 {
            let color = pixel_palette.color_for_block(block_type);
            assert_eq!(color[3].is_finite(), true);
            assert!(color[3] > 0.0, "palette alpha should be positive");
        }

        for nt in 0..=7u8 {
            let color = NodeType::from_u8(nt).color();
            assert_eq!(color[3], 1.0, "classic mode node colors should be fully opaque");
        }
    }

    // ── Color Overrides ──────────────────────────────────────────────────────

    #[test]
    fn palette_custom_colors_persist() {
        let mut palette = VoxelPalette::light();
        let custom = [0.1, 0.2, 0.3, 0.9];
        palette.core = custom;
        assert_eq!(palette.core, custom);
        assert_eq!(palette.color_for_block(0), custom);
    }

    #[test]
    fn palette_overrides_reset_on_reinit() {
        // Document expected behavior: reinitializing palette resets overrides.
        let mut palette = VoxelPalette::dark();
        palette.core = [0.99, 0.88, 0.77, 0.66];
        assert_eq!(palette.core, [0.99, 0.88, 0.77, 0.66]);

        // Re-create palette — overrides are lost. This is expected.
        palette = VoxelPalette::dark();
        assert_ne!(palette.core, [0.99, 0.88, 0.77, 0.66]);
        assert_eq!(palette.core, [1.0, 0.25, 0.25, 1.0]); // default dark core
    }

    #[test]
    fn palette_toggle_light_dark_resets_overrides() {
        let mut palette = VoxelPalette::light();
        palette.primary = [0.5, 0.5, 0.5, 0.5];

        // Switch to dark — overrides are lost.
        palette = VoxelPalette::dark();
        assert_ne!(palette.primary, [0.5, 0.5, 0.5, 0.5]);
    }

    #[test]
    fn palette_all_block_types_return_unique_colors() {
        let palette = VoxelPalette::light();
        let colors: Vec<[f32; 4]> = (0..=4u8)
            .map(|bt| palette.color_for_block(bt))
            .collect();

        // Each block type should have a distinct color
        for i in 0..colors.len() {
            for j in (i + 1)..colors.len() {
                assert_ne!(colors[i], colors[j],
                    "block types {i} and {j} should have distinct colors");
            }
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
        for i in 0..500 {
            world.despawn(entities[i]);
        }
        assert_eq!(world.len(), 500);

        // All remaining entities should still be findable
        for i in 500..1000 {
            assert!(world.index_of(entities[i]).is_some(),
                "entity {} should still exist", entities[i]);
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
        assert!(nearby.contains(&4), "entity 4 at (-100,-100) should be found");
        // Entity 2 at (200,200) is too far
        assert!(!nearby.contains(&2), "entity 2 should be too far");
        assert!(!nearby.contains(&3), "entity 3 should be too far");
    }

    #[test]
    fn spatial_grid_rebuild_from_transforms() {
        let entities: Vec<u32> = vec![0, 1, 2];
        let transforms = vec![
            TransformComponent { x: 0.0, y: 0.0, scale: 1.0 },
            TransformComponent { x: 10.0, y: 10.0, scale: 1.0 },
            TransformComponent { x: 500.0, y: 500.0, scale: 1.0 },
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
            let entity = world.node_id_to_entity[&(nt as u32)];
            let idx = world.index_of(entity).unwrap();
            assert_eq!(world.hierarchy[idx].node_type, nt);
        }
    }

    #[test]
    fn from_graph_block_type_mapping() {
        let mut graph = Graph::new();
        // Folder → Core
        graph.add_node("folder".into(), 0.0, 0.0, NodeType::Folder as u8, 1, "F".into());
        // Note → Primary
        graph.add_node("note".into(), 0.0, 0.0, NodeType::Note as u8, 1, "N".into());
        // Source → Secondary
        graph.add_node("source".into(), 0.0, 0.0, NodeType::Source as u8, 1, "S".into());
        // Chat → Tertiary
        graph.add_node("chat".into(), 0.0, 0.0, NodeType::Chat as u8, 1, "C".into());
        // Tag → Leaf
        graph.add_node("tag".into(), 0.0, 0.0, NodeType::Tag as u8, 1, "T".into());

        let world = World::from_graph(&graph);

        let check = |graph_id: u32, expected_bt: BlockType| {
            let entity = world.node_id_to_entity[&graph_id];
            let idx = world.index_of(entity).unwrap();
            assert_eq!(world.render[idx].block_type, expected_bt as u8,
                "graph node {graph_id} should map to {:?}", expected_bt);
        };

        check(0, BlockType::Core);     // Folder
        check(1, BlockType::Primary);  // Note
        check(2, BlockType::Secondary);// Source
        check(3, BlockType::Tertiary); // Chat
        check(4, BlockType::Leaf);     // Tag
    }

    #[test]
    fn from_graph_glare_assignment() {
        let mut graph = Graph::new();
        graph.add_node("folder".into(), 0.0, 0.0, NodeType::Folder as u8, 1, "F".into());
        graph.add_node("note".into(), 0.0, 0.0, NodeType::Note as u8, 1, "N".into());
        graph.add_node("tag".into(), 0.0, 0.0, NodeType::Tag as u8, 1, "T".into());
        graph.add_node("chat".into(), 0.0, 0.0, NodeType::Chat as u8, 1, "C".into());

        let world = World::from_graph(&graph);

        // Core and Primary get glare (1), others don't (0)
        let folder_e = world.node_id_to_entity[&0];
        let note_e = world.node_id_to_entity[&1];
        let tag_e = world.node_id_to_entity[&2];
        let chat_e = world.node_id_to_entity[&3];

        assert_eq!(world.render[world.index_of(folder_e).unwrap()].has_glare, 1);
        assert_eq!(world.render[world.index_of(note_e).unwrap()].has_glare, 1);
        assert_eq!(world.render[world.index_of(tag_e).unwrap()].has_glare, 0);
        assert_eq!(world.render[world.index_of(chat_e).unwrap()].has_glare, 0);
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
            assert!(entity.is_some(), "graph node id {i} should have a mapped entity");
            let idx = world.index_of(*entity.unwrap());
            assert!(idx.is_some(), "entity for graph node {i} should exist in world");
        }
    }

    #[test]
    fn node_id_to_entity_missing_id() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());

        let world = World::from_graph(&graph);
        assert!(world.node_id_to_entity.get(&999).is_none());
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

    // ── VoxelPalette Repr ────────────────────────────────────────────────────

    #[test]
    fn voxel_palette_is_repr_c() {
        // VoxelPalette is #[repr(C)] — verify size is predictable.
        // 7 fields * 4 components * 4 bytes = 112 bytes
        let size = std::mem::size_of::<VoxelPalette>();
        assert_eq!(size, 112, "VoxelPalette should be exactly 112 bytes (7 * [f32;4])");
    }

    #[test]
    fn visual_theme_is_repr_u8() {
        assert_eq!(std::mem::size_of::<VisualTheme>(), 1);
    }
}
