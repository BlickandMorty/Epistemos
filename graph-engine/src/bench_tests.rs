//! Performance benchmark tests for ECS + SpatialGrid at scale.
//!
//! These tests measure wall-clock time using `std::time::Instant`.
//! Run with `cargo test bench -- --nocapture` to see timing output.
//! No assertions on timing — just measure and print.

#[cfg(test)]
mod bench_tests {
    use crate::ecs::components::*;
    use crate::ecs::spatial_grid::SpatialGrid;
    use crate::ecs::systems;
    use crate::ecs::World;
    use std::time::Instant;

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
        world.spatial_grid.rebuild(&world.entities, &world.transform);
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
        let entities_to_despawn: Vec<u32> = world.entities.iter().copied()
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
}
