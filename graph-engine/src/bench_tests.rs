//! Performance benchmark tests for ECS + SpatialGrid at scale.
//!
//! These tests measure wall-clock time using `std::time::Instant`.
//! Run with `cargo test bench -- --nocapture` to see timing output.
//! No assertions on timing — just measure and print.

#[cfg(test)]
mod bench_tests {
    use crate::cluster::detect_communities;
    use crate::cluster_cache::ClusterCache;
    use crate::ecs::World;
    use crate::ecs::components::*;
    use crate::ecs::spatial_grid::SpatialGrid;
    use crate::ecs::systems;
    use crate::renderer::{bounds_intersects_circle, viewport_bounds};
    use crate::search::SearchIndex;
    use crate::simulation::Simulation;
    use crate::types::Graph;
    use std::hint::black_box;
    use std::time::Instant;

    const GRAPH_BENCHMARK_SIZES: [usize; 3] = [1_000, 5_000, 10_000];
    const VIEWPORT_SIZE: [f32; 2] = [1_440.0, 900.0];
    const VIEWPORT_CULL_PADDING_PIXELS: f32 = 160.0;
    const VIEWPORT_REFRESH_STEPS: usize = 120;
    const SEARCH_HIGHLIGHT_PASSES: usize = 80;

    struct GraphCommitMetrics {
        sim_load_us: u128,
        cluster_us: u128,
        world_build_us: u128,
        search_index_us: u128,
        total_us: u128,
    }

    fn make_graph(node_count: usize) -> Graph {
        let mut graph = Graph::new();
        let edge_hub_stride = (node_count / 11).max(9);
        let edge_long_stride = (node_count / 5).max(17);

        for i in 0..node_count {
            let angle = i as f32 * 0.173_205_08;
            let radius = 180.0 + (i as f32).sqrt() * 18.0;
            let link_count = if i % 23 == 0 {
                14
            } else if i % 7 == 0 {
                7
            } else {
                3
            };
            let label = format!("Alpha Cluster Node {i} Topic {} Source {}", i % 97, i % 31);
            graph.add_node(
                format!("node-{i}"),
                radius * angle.cos(),
                radius * angle.sin(),
                (i % 8) as u8,
                link_count,
                label,
            );
        }

        for i in 0..node_count {
            let next = (i + 1) % node_count;
            let hub = (i + edge_hub_stride) % node_count;
            let long = (i + edge_long_stride) % node_count;
            graph.add_edge(&format!("node-{i}"), &format!("node-{next}"), 1.0, 0);

            if i % 3 == 0 {
                graph.add_edge(&format!("node-{i}"), &format!("node-{hub}"), 0.75, 6);
            }
            if i % 11 == 0 {
                graph.add_edge(&format!("node-{i}"), &format!("node-{long}"), 0.55, 4);
            }
        }

        graph
    }

    fn steady_state_tick_count(node_count: usize) -> usize {
        match node_count {
            0..=500 => 120,
            501..=1_000 => 60,
            1_001..=3_000 => 40,
            _ => 30,
        }
    }

    fn measure_commit_core(graph: &Graph) -> (GraphCommitMetrics, World) {
        let total_start = Instant::now();

        let sim_start = Instant::now();
        let mut sim = Simulation::new();
        sim.load_from_graph(graph);
        let sim_load_us = sim_start.elapsed().as_micros();

        let cluster_start = Instant::now();
        let cluster_ids = detect_communities(sim.x.len(), &sim.edges);
        let mut cluster_cache = ClusterCache::new();
        cluster_cache.build(cluster_ids.clone(), &sim.edges, &sim.graph_indices);
        sim.cluster_ids = cluster_ids;
        let cluster_us = cluster_start.elapsed().as_micros();

        let world_start = Instant::now();
        let mut world = World::from_graph(graph);
        world.sync_clusters(&sim.cluster_ids, &sim.graph_indices);
        let world_build_us = world_start.elapsed().as_micros();

        let search_start = Instant::now();
        let mut search_index = SearchIndex::new();
        search_index.build(&graph.nodes);
        let search_index_us = search_start.elapsed().as_micros();

        black_box(search_index.search("cluster", 16));
        black_box(cluster_cache.cluster_count_for_zoom(0.3));

        (
            GraphCommitMetrics {
                sim_load_us,
                cluster_us,
                world_build_us,
                search_index_us,
                total_us: total_start.elapsed().as_micros(),
            },
            world,
        )
    }

    fn measure_steady_state_simulation(graph: &Graph) -> u128 {
        let mut sim = Simulation::new();
        sim.load_from_graph(graph);

        for _ in 0..120 {
            sim.tick();
        }

        let tick_count = steady_state_tick_count(graph.nodes.len());
        let start = Instant::now();
        for _ in 0..tick_count {
            sim.tick();
        }
        black_box((sim.is_settled, sim.x.len()));
        start.elapsed().as_micros()
    }

    fn measure_viewport_refresh(world: &World) -> (u128, usize) {
        let mut candidate_entities = Vec::new();
        let mut visible_total = 0usize;
        let start = Instant::now();

        for step in 0..VIEWPORT_REFRESH_STEPS {
            let angle = step as f32 * 0.17;
            let zoom: f32 = match step % 4 {
                0 => 0.45,
                1 => 0.85,
                2 => 1.35,
                _ => 2.10,
            };
            let camera_offset = [angle.cos() * 620.0, angle.sin() * 460.0];
            let padding = VIEWPORT_CULL_PADDING_PIXELS / zoom.max(0.05);
            let bounds = viewport_bounds(camera_offset, zoom, VIEWPORT_SIZE, padding);

            world.spatial_grid.query_bounds_into(
                bounds.min_x,
                bounds.min_y,
                bounds.max_x,
                bounds.max_y,
                &mut candidate_entities,
            );

            for &entity in &candidate_entities {
                let Some(index) = world.index_of(entity) else {
                    continue;
                };
                if world.graph_node[index].visible == 0 {
                    continue;
                }

                let center = [world.transform[index].x, world.transform[index].y];
                if bounds_intersects_circle(bounds, center, world.graph_node[index].radius) {
                    visible_total += 1;
                }
            }
        }

        black_box(visible_total);
        (start.elapsed().as_micros(), visible_total)
    }

    fn measure_search_highlight(graph: &Graph) -> (u128, usize) {
        let queries = ["alpha", "cluster", "topic 12", "source 7", "missing"];
        let mut search_index = SearchIndex::new();
        search_index.build(&graph.nodes);
        let mut matches = Vec::new();
        let mut total_matches = 0usize;
        let start = Instant::now();

        for pass in 0..SEARCH_HIGHLIGHT_PASSES {
            search_index
                .collect_contains_match_node_ids(queries[pass % queries.len()], &mut matches);
            total_matches += matches.len();
        }

        black_box(total_matches);
        (start.elapsed().as_micros(), total_matches)
    }

    fn spawn_entities(world: &mut World, count: u32) {
        for i in 0..count {
            let angle = (i as f32) * 0.1;
            let r = (i as f32).sqrt() * 10.0;
            let entity = world.spawn(TransformComponent {
                x: r * angle.cos(),
                y: r * angle.sin(),
                scale: 1.0,
            });
            let idx = world.index_of(entity).unwrap();
            world.velocity[idx] = VelocityComponent {
                vx: angle.sin() * 0.5,
                vy: angle.cos() * 0.5,
            };
            world.hierarchy[idx] = HierarchyComponent {
                depth: (i % 5) as u32,
                parent: u32::MAX,
                node_type: (i % 8) as u8,
                _pad: [0; 3],
                link_count: (i % 20),
            };
            world.render[idx] = RenderComponent {
                _pad: [0; 4],
                color_override: [0.0; 4],
            };
        }
    }

    fn run_benchmark(count: u32) {
        // Spawn
        let t0 = Instant::now();
        let mut world = World::with_capacity(count as usize);
        spawn_entities(&mut world, count);
        let spawn_us = t0.elapsed().as_micros();
        assert_eq!(world.len(), count as usize);

        // Spatial grid rebuild
        let t1 = Instant::now();
        world
            .spatial_grid
            .rebuild(&world.entities, &world.transform);
        let grid_rebuild_us = t1.elapsed().as_micros();

        // Spatial grid query (100 queries at different positions)
        let t2 = Instant::now();
        for i in 0..100u32 {
            let x = (i as f32) * 3.14;
            let y = (i as f32) * 2.71;
            let _ = world.spatial_grid.query_candidates(x, y, 100.0);
        }
        let grid_query_us = t2.elapsed().as_micros();

        // Sync transforms → physics arrays
        let t3 = Instant::now();
        systems::sync_transforms_to_physics(&mut world);
        let sync_to_us = t3.elapsed().as_micros();

        // Sync physics arrays → transforms
        let t4 = Instant::now();
        systems::sync_physics_to_transforms(&mut world);
        let sync_from_us = t4.elapsed().as_micros();

        // Despawn half (swap-remove stress)
        let entities_to_despawn: Vec<u32> = world
            .entities
            .iter()
            .copied()
            .take(count as usize / 2)
            .collect();
        let t5 = Instant::now();
        for e in entities_to_despawn {
            world.despawn(e);
        }
        let despawn_us = t5.elapsed().as_micros();

        println!("=== ECS Benchmark: {count} entities ===");
        println!("  spawn:          {spawn_us:>8} us");
        println!("  grid rebuild:   {grid_rebuild_us:>8} us");
        println!("  grid 100x query:{grid_query_us:>8} us");
        println!("  sync to phys:   {sync_to_us:>8} us");
        println!("  sync from phys: {sync_from_us:>8} us");
        println!("  despawn half:   {despawn_us:>8} us");
        println!();
    }

    #[test]
    fn benchmark_10k_ecs_operations() {
        run_benchmark(10_000);
    }

    #[test]
    fn benchmark_50k_ecs_operations() {
        run_benchmark(50_000);
    }

    #[test]
    fn benchmark_100k_ecs_operations() {
        run_benchmark(100_000);
    }

    #[test]
    fn benchmark_spatial_grid_rebuild_at_scale() {
        let entities: Vec<u32> = (0..100_000u32).collect();
        let transforms: Vec<TransformComponent> = (0..100_000u32)
            .map(|i| {
                let angle = (i as f32) * 0.1;
                let r = (i as f32).sqrt() * 10.0;
                TransformComponent {
                    x: r * angle.cos(),
                    y: r * angle.sin(),
                    scale: 1.0,
                }
            })
            .collect();

        let mut grid = SpatialGrid::new(50.0);

        // Cold rebuild
        let t0 = Instant::now();
        grid.rebuild(&entities, &transforms);
        let cold_us = t0.elapsed().as_micros();

        // Warm rebuild (reuses allocated Vecs)
        let t1 = Instant::now();
        grid.rebuild(&entities, &transforms);
        let warm_us = t1.elapsed().as_micros();

        println!("=== SpatialGrid Rebuild: 100K transforms ===");
        println!("  cold rebuild: {cold_us:>8} us");
        println!("  warm rebuild: {warm_us:>8} us");
        println!();
    }

    #[test]
    fn benchmark_spatial_grid_query_radius() {
        let entities: Vec<u32> = (0..50_000u32).collect();
        let transforms: Vec<TransformComponent> = (0..50_000u32)
            .map(|i| TransformComponent {
                x: (i % 500) as f32 * 2.0,
                y: (i / 500) as f32 * 2.0,
                scale: 1.0,
            })
            .collect();

        let mut grid = SpatialGrid::new(50.0);
        grid.rebuild(&entities, &transforms);

        // Small radius queries (few results)
        let t0 = Instant::now();
        for _ in 0..1000 {
            let _ = grid.query_candidates(250.0, 50.0, 25.0);
        }
        let small_us = t0.elapsed().as_micros();

        // Large radius queries (many results)
        let t1 = Instant::now();
        for _ in 0..100 {
            let _ = grid.query_candidates(250.0, 50.0, 200.0);
        }
        let large_us = t1.elapsed().as_micros();

        println!("=== SpatialGrid Query: 50K entities ===");
        println!("  1000x small radius (25): {small_us:>8} us");
        println!("  100x large radius (200): {large_us:>8} us");
        println!();
    }

    #[test]
    fn benchmark_graph_phase1_matrix() {
        println!("=== Graph Phase 1 Benchmark Matrix ===");
        println!(
            "sizes: {:?} nodes | commit core + 1s steady-state sim + viewport refresh + search highlight",
            GRAPH_BENCHMARK_SIZES
        );

        for size in GRAPH_BENCHMARK_SIZES {
            let graph = make_graph(size);
            let (commit, world) = measure_commit_core(&graph);
            let steady_state_us = measure_steady_state_simulation(&graph);
            let (viewport_refresh_us, visible_total) = measure_viewport_refresh(&world);
            let (search_highlight_us, total_matches) = measure_search_highlight(&graph);

            println!("--- {size:>5} nodes ---");
            println!(
                "  commit core total:        {total:>8} us  (sim {sim:>8} | cluster {cluster:>8} | world {world:>8} | search {search:>8})",
                total = commit.total_us,
                sim = commit.sim_load_us,
                cluster = commit.cluster_us,
                world = commit.world_build_us,
                search = commit.search_index_us,
            );
            println!(
                "  steady-state sim (1s):    {steady_state_us:>8} us  ({ticks:>3} ticks)",
                ticks = steady_state_tick_count(size),
            );
            println!(
                "  viewport refresh:         {viewport_refresh_us:>8} us  ({steps:>3} steps, {visible_total} visible checks)",
                steps = VIEWPORT_REFRESH_STEPS,
            );
            println!(
                "  search highlight:         {search_highlight_us:>8} us  ({passes:>3} passes, {total_matches} matches)",
                passes = SEARCH_HIGHLIGHT_PASSES,
            );
            println!();
        }
    }
}
