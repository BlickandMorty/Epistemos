//! ECS physics systems — thin adapters that extract SoA slices from World
//! and pass them to the existing force functions in `crate::forces`.
//!
//! The force functions operate on flat `&[f32]` / `&mut [f32]` slices.
//! World stores physics hot-path arrays (`px`, `py`, `pvx`, `pvy`, `pfx`, `pfy`)
//! that serve as those slices directly, avoiding per-tick copy overhead.

use crate::forces;
use crate::quadtree;
use crate::simulation::ForceParams;
use super::World;

/// Sync transform + velocity components into physics hot-path arrays.
/// Call before running physics tick.
pub fn sync_transforms_to_physics(world: &mut World) {
    let n = world.entities.len();
    world.px.resize(n, 0.0);
    world.py.resize(n, 0.0);
    world.pvx.resize(n, 0.0);
    world.pvy.resize(n, 0.0);
    world.pfx.resize(n, None);
    world.pfy.resize(n, None);

    for i in 0..n {
        world.px[i] = world.transform[i].x;
        world.py[i] = world.transform[i].y;
        world.pvx[i] = world.velocity[i].vx;
        world.pvy[i] = world.velocity[i].vy;
    }
}

/// Sync physics hot-path arrays back into transform + velocity components.
/// Call after running physics tick.
pub fn sync_physics_to_transforms(world: &mut World) {
    let n = world.entities.len();
    for i in 0..n {
        world.transform[i].x = world.px[i];
        world.transform[i].y = world.py[i];
        world.velocity[i].vx = world.pvx[i];
        world.velocity[i].vy = world.pvy[i];
    }
}

/// Run one full physics tick on the World's data using existing force functions.
///
/// Mirrors the core of `Simulation::tick()`:
/// 1. Alpha decay
/// 2. Settled detection (alpha < floor && no fixed nodes)
/// 3. Link, many-body, collide, center forces
/// 4. Velocity Verlet integration with decay + MAX_VELOCITY clamp
/// 5. NaN/Inf safety reset
/// 6. Sync back to transform components
/// 7. Rebuild spatial grid
///
/// Extended features (cluster, semantic, fluid, torsion, orbital, haptic)
/// are intentionally omitted — they can be layered on later.
pub fn tick(
    world: &mut World,
    params: &mut ForceParams,
    edges: &[(usize, usize)],
    edge_weights: &[f32],
    degrees: &[u32],
    collision_radii: &[f32],
    bodies_scratch: &mut Vec<quadtree::Body>,
    collision_grid: &mut rustc_hash::FxHashMap<(i32, i32), Vec<usize>>,
) {
    let n = world.entities.len();
    if n == 0 {
        return;
    }

    // 1. Alpha decay — converges toward alpha_target.
    params.alpha += (params.alpha_target - params.alpha) * params.alpha_decay;

    const ALPHA_FLOOR: f32 = 0.0001;
    let at_floor = params.alpha < ALPHA_FLOOR;
    if at_floor {
        params.alpha = ALPHA_FLOOR;
    }

    // 2. Settled = alpha at floor and no nodes being dragged.
    let any_fixed = world.pfx.iter().any(|f| f.is_some());
    let settled = at_floor && !any_fixed;

    if settled {
        for i in 0..n {
            world.pvx[i] = 0.0;
            world.pvy[i] = 0.0;
        }
        sync_physics_to_transforms(world);
        return;
    }

    let alpha = params.alpha;

    // 3. Apply forces in d3/LogSeq order: link -> many-body -> collide -> center

    // Link force
    forces::force_link(
        &world.px,
        &world.py,
        &mut world.pvx,
        &mut world.pvy,
        edges,
        edge_weights,
        degrees,
        &world.pfx,
        &world.pfy,
        params.link_distance,
        params.link_strength,
        alpha,
    );

    if !at_floor {
        // Many-body force (Barnes-Hut repulsion)
        bodies_scratch.clear();
        forces::force_many_body_with_scratch(
            &world.px,
            &world.py,
            &mut world.pvx,
            &mut world.pvy,
            &world.pfx,
            &world.pfy,
            params.charge_strength,
            params.charge_range,
            1.0, // distance_min (d3 default)
            alpha,
            bodies_scratch,
            degrees,
        );

        // Collision force (position-based overlap prevention)
        forces::force_collide_with_scratch(
            &mut world.px,
            &mut world.py,
            collision_radii,
            &world.pfx,
            &world.pfy,
            params.collision_iterations,
            collision_grid,
        );
    }

    // Center force — always active
    let center_str = match params.center_mode {
        crate::simulation::CenterMode::Attract => params.center_strength,
        crate::simulation::CenterMode::Off => 0.0,
        crate::simulation::CenterMode::Repel => -params.center_strength,
    };
    if center_str.abs() > 0.0001 {
        forces::force_center(
            &world.px,
            &world.py,
            &mut world.pvx,
            &mut world.pvy,
            0.0,
            0.0,
            center_str,
            alpha,
        );
    }

    // 4. Velocity Verlet integration with uniform decay.
    const MAX_VELOCITY: f32 = 500.0;
    let decay = params.velocity_decay;
    for i in 0..n {
        if let Some(fx_val) = world.pfx[i] {
            world.pvx[i] = fx_val - world.px[i];
            world.px[i] = fx_val;
        } else {
            world.pvx[i] *= decay;
            world.pvx[i] = world.pvx[i].clamp(-MAX_VELOCITY, MAX_VELOCITY);
            world.px[i] += world.pvx[i];
        }
        if let Some(fy_val) = world.pfy[i] {
            world.pvy[i] = fy_val - world.py[i];
            world.py[i] = fy_val;
        } else {
            world.pvy[i] *= decay;
            world.pvy[i] = world.pvy[i].clamp(-MAX_VELOCITY, MAX_VELOCITY);
            world.py[i] += world.pvy[i];
        }

        // Safety: reset NaN/Inf positions to origin.
        if !world.px[i].is_finite() { world.px[i] = 0.0; world.pvx[i] = 0.0; }
        if !world.py[i].is_finite() { world.py[i] = 0.0; world.pvy[i] = 0.0; }
    }

    // 5. Sync back to transform + velocity components.
    sync_physics_to_transforms(world);

    // 6. Rebuild spatial grid from updated positions.
    world.spatial_grid.rebuild(&world.entities, &world.transform);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ecs::TransformComponent;

    fn make_params() -> ForceParams {
        ForceParams::default()
    }

    #[test]
    fn test_tick_moves_nodes_apart() {
        let mut world = World::new();
        // Two nodes slightly overlapping — repulsion + collision should push them apart.
        // Not exactly coincident (coincident nodes have zero displacement vector,
        // so forces have no direction to push in — same behavior as d3-force).
        world.spawn(TransformComponent { x: -1.0, y: 0.0, scale: 1.0 });
        world.spawn(TransformComponent { x: 1.0, y: 0.0, scale: 1.0 });
        sync_transforms_to_physics(&mut world);

        let mut params = make_params();
        let edges: Vec<(usize, usize)> = vec![];
        let edge_weights: Vec<f32> = vec![];
        let degrees: Vec<u32> = vec![1, 1];
        let collision_radii: Vec<f32> = vec![26.0, 26.0];
        let mut bodies = Vec::new();
        let mut grid = rustc_hash::FxHashMap::default();

        let dist_before = (world.transform[1].x - world.transform[0].x).abs();

        tick(&mut world, &mut params, &edges, &edge_weights, &degrees,
             &collision_radii, &mut bodies, &mut grid);

        // After one tick, nodes should be pushed further apart by repulsion + collision.
        let dist_after = (world.transform[1].x - world.transform[0].x).abs();
        assert!(dist_after > dist_before,
            "overlapping nodes should separate: before={dist_before}, after={dist_after}");
    }

    #[test]
    fn test_tick_link_attraction() {
        let mut world = World::new();
        // Two linked nodes far apart — spring should pull them closer.
        world.spawn(TransformComponent { x: -500.0, y: 0.0, scale: 1.0 });
        world.spawn(TransformComponent { x: 500.0, y: 0.0, scale: 1.0 });
        sync_transforms_to_physics(&mut world);

        let mut params = make_params();
        let edges = vec![(0usize, 1usize)];
        let edge_weights = vec![1.0];
        let degrees = vec![1u32, 1];
        let collision_radii = vec![26.0, 26.0];
        let mut bodies = Vec::new();
        let mut grid = rustc_hash::FxHashMap::default();

        let x0_before = world.transform[0].x;
        let x1_before = world.transform[1].x;

        for _ in 0..5 {
            sync_transforms_to_physics(&mut world);
            tick(&mut world, &mut params, &edges, &edge_weights, &degrees,
                 &collision_radii, &mut bodies, &mut grid);
        }

        let dist_before = (x1_before - x0_before).abs();
        let dist_after = (world.transform[1].x - world.transform[0].x).abs();
        assert!(dist_after < dist_before,
            "linked nodes should move closer: before={dist_before}, after={dist_after}");
    }

    #[test]
    fn test_tick_settled() {
        let mut world = World::new();
        world.spawn(TransformComponent { x: 10.0, y: 10.0, scale: 1.0 });
        world.spawn(TransformComponent { x: -10.0, y: -10.0, scale: 1.0 });
        sync_transforms_to_physics(&mut world);

        let mut params = make_params();
        let edges: Vec<(usize, usize)> = vec![];
        let edge_weights: Vec<f32> = vec![];
        let degrees = vec![1u32, 1];
        let collision_radii = vec![26.0, 26.0];
        let mut bodies = Vec::new();
        let mut grid = rustc_hash::FxHashMap::default();

        // Run many ticks — alpha should decay below floor and velocities zero out.
        for _ in 0..500 {
            sync_transforms_to_physics(&mut world);
            tick(&mut world, &mut params, &edges, &edge_weights, &degrees,
                 &collision_radii, &mut bodies, &mut grid);
        }

        assert!(params.alpha <= 0.001,
            "alpha should have decayed to floor: {}", params.alpha);
        let total_v: f32 = world.velocity.iter()
            .map(|v| v.vx.abs() + v.vy.abs())
            .sum();
        assert!(total_v < 0.01,
            "velocities should be near zero when settled: {total_v}");
    }

    #[test]
    fn test_sync_round_trip() {
        let mut world = World::new();
        world.spawn(TransformComponent { x: 42.0, y: -17.0, scale: 1.0 });
        world.spawn(TransformComponent { x: 100.0, y: 200.0, scale: 1.0 });

        sync_transforms_to_physics(&mut world);

        // Verify physics arrays match components.
        assert_eq!(world.px[0], 42.0);
        assert_eq!(world.py[0], -17.0);
        assert_eq!(world.px[1], 100.0);
        assert_eq!(world.py[1], 200.0);

        // Modify physics arrays (simulating force application).
        world.px[0] = 99.0;
        world.py[0] = -99.0;
        world.pvx[0] = 5.0;
        world.pvy[0] = -3.0;

        sync_physics_to_transforms(&mut world);

        // Verify components reflect physics changes.
        assert_eq!(world.transform[0].x, 99.0);
        assert_eq!(world.transform[0].y, -99.0);
        assert_eq!(world.velocity[0].vx, 5.0);
        assert_eq!(world.velocity[0].vy, -3.0);

        // Node 1 unchanged.
        assert_eq!(world.transform[1].x, 100.0);
        assert_eq!(world.transform[1].y, 200.0);
    }
}
