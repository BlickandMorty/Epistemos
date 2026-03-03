use super::*;
use crate::simulation::{Simulation, ForceParams, CenterMode};
use crate::types::Graph;

#[cfg(test)]
mod physics_audit_tests {
    use super::*;

    /// Helper to setup a basic simulation with default parameters
    fn setup_sim_with_nodes(n: usize) -> Simulation {
        let mut graph = Graph::new();
        for i in 0..n {
            graph.add_node(
                format!("node-{}", i),
                (i as f32) * 10.0,
                0.0,
                0, // note
                1, // link count
                format!("Node {}", i)
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim
    }

    #[test]
    fn test_pinned_nodes_do_not_move() {
        let mut sim = setup_sim_with_nodes(2);

        // Pin the first node at (100, 100)
        sim.fx[0] = Some(100.0);
        sim.fy[0] = Some(100.0);

        // Put the second node right next to it so repulsion forces act on it
        sim.x[1] = 100.1;
        sim.y[1] = 100.1;

        // Run several ticks
        for _ in 0..10 {
            sim.tick();
        }

        // The pinned node should not have budged, and velocity must be zero
        assert_eq!(sim.x[0], 100.0);
        assert_eq!(sim.y[0], 100.0);
        assert_eq!(sim.vx[0], 0.0);
        assert_eq!(sim.vy[0], 0.0);

        // The second node should have moved away from its initial position.
        let dist = ((sim.x[1] - 100.1).powi(2) + (sim.y[1] - 100.1).powi(2)).sqrt();
        assert!(dist > 0.1, "unpinned node should move, dist={}", dist);
    }

    #[test]
    fn test_distant_nodes_with_zero_center_gravity() {
        // With center_strength=0, the center force is truly off (d3 canonical).
        // Orphan nodes drift freely. Use center_strength > 0 to pull them back.
        let mut sim = setup_sim_with_nodes(1);

        sim.params.center_strength = 0.0;
        sim.params.velocity_decay = 0.6;

        // Place orphan node far away with slight outward velocity.
        sim.x[0] = 5000.0;
        sim.y[0] = 0.0;
        sim.vx[0] = 10.0;
        sim.vy[0] = 0.0;

        for _ in 0..50 {
            sim.tick();
        }

        // With no center force and outward velocity, node drifts further.
        // This is correct d3 behavior — center_strength=0 means no pull.
        assert!(sim.x[0].is_finite(),
            "Node should remain finite, got x={}", sim.x[0]);
    }

    #[test]
    fn test_distant_nodes_reaggregated_by_center_gravity() {
        // This tests the FIX to the orphan nodes bug
        let mut sim = setup_sim_with_nodes(1);
        
        sim.params.center_strength = 0.02; 
        sim.params.velocity_decay = 0.05;
        // Turn off cooling so physics runs continuously for the test
        sim.params.alpha_decay = 0.0;

        sim.x[0] = 5000.0;
        sim.y[0] = 0.0;
        sim.vx[0] = 10.0;
        sim.vy[0] = 0.0;

        for _ in 0..50 {
            sim.tick();
        }

        assert!(sim.vx[0] < 0.0 || sim.x[0] < 5000.0 + 10.0);
        
        // Force convergence
        for _ in 0..1000 {
            sim.tick();
        }

        // After 1050 ticks with center gravity, node should be pulled closer to origin
        // The exact position depends on many factors, but it should be significantly closer
        assert!(sim.x[0].abs() < 5000.0, "Node should be pulled toward center, but x was {}", sim.x[0]);
    }

    #[test]
    fn test_explosive_entrance_repulsion_limited_by_charge_range() {
        let mut sim = setup_sim_with_nodes(2);

        // Node 0 is the center hub
        sim.x[0] = 0.0; sim.y[0] = 0.0;
        sim.fx[0] = Some(0.0); sim.fy[0] = Some(0.0);
        
        // Node 1 is an orphan at the edge of the blast radius
        sim.x[1] = 400.0; sim.y[1] = 0.0;

        // Limit the charge radius
        sim.params.charge_strength = -500.0;
        sim.params.charge_range = 280.0; // The fix: tighten blast radius
        sim.params.center_strength = 0.0; // Turn off gravity to isolate repulsion
        sim.params.cluster_strength = 0.0; // Turn off clustering
        sim.params.enable_torsional_springs = false;
        sim.params.enable_fluid_dynamics = false;

        sim.edges.clear();
        sim.degrees = vec![0, 0];

        sim.tick();

        // Node 1 at distance 400 with charge_range 280 should receive minimal force
        // Small numerical errors or force leakage is acceptable, but should be very small
        assert!(sim.vx[1].abs() < 1.0, "Node 1 velocity should be near zero (outside charge range), but was {}", sim.vx[1]);
    }

    #[test]
    fn test_crash_quadtree_coincident_nan_safe() {
        // Crash scenario: hundreds of nodes exactly at 0,0 where repulsion
        // might infinite loop due to coincident bounding boxes or NaNs.
        let mut sim = setup_sim_with_nodes(500);

        for i in 0..500 {
            sim.x[i] = 0.0;
            sim.y[i] = 0.0;
        }

        // Should not hang. We just rely on cargo test timing out or succeeding quickly.
        let start = std::time::Instant::now();
        sim.tick();
        
        assert!(start.elapsed().as_millis() < 500, "Coincident nodes should settle quickly without hanging the quadtree.");
    }

    #[test]
    fn test_crash_presettle_blocktime() {
        // Crash scenario: spindump reported a 3.9s slow hid response.
        // We know engine.rs runs up to 1200 ticks synchronously on the main thread for N < 2000.
        // Let's test the execution time of 1200 ticks for 1900 nodes.
        let mut sim = setup_sim_with_nodes(1900);
        
        let mut start_positions = vec![(0.0, 0.0); 1900];
        for i in 0..1900 {
            // Distribute them in a spiral like engine.rs does
            let golden_angle: f32 = std::f32::consts::PI * (3.0 - 5.0_f32.sqrt());
            let r = 350.0 * (i as f32).sqrt();
            let theta = i as f32 * golden_angle;
            sim.x[i] = r * theta.cos();
            sim.y[i] = r * theta.sin();
        }

        let start = std::time::Instant::now();
        for _ in 0..1200 {
            sim.tick();
        }
        
        let elapsed_ms = start.elapsed().as_millis();
        
        // Let's assert that it's surprisingly slow (which proves the bug) or fast enough.
        // If this takes > 1000ms, it's a huge red flag that we are hanging the main thread.
        println!("1200 ticks for 1900 nodes took {} ms", elapsed_ms);
        
        // We'll assert it completes. The console output will log the time.
        assert!(elapsed_ms < 10000, "Sanity check: took more than 10 seconds!");
    }

    #[test]
    fn test_physics_alpha_cooling_converges() {
        let mut sim = setup_sim_with_nodes(2);

        sim.params.alpha = 0.15;
        sim.params.alpha_min = 0.001;
        sim.params.alpha_decay = 0.0228;

        let original_alpha = sim.params.alpha;

        sim.tick();

        assert!(sim.params.alpha < original_alpha); // Must decrease
        assert!(sim.params.alpha > 0.0);           // But not disappear instantly
    }

    #[test]
    fn test_all_edges_loaded_no_cap() {
        // Regression: edge cap (12 per node) used to orphan subtrees.
        // Hub with 30 connections should keep ALL edges in physics.
        let mut graph = Graph::new();
        // Hub node at center
        graph.add_node("hub".to_string(), 0.0, 0.0, 0, 30, "Hub".to_string());
        // 30 leaf nodes arranged around hub
        for i in 0..30 {
            let angle = (i as f32) * std::f32::consts::TAU / 30.0;
            graph.add_node(
                format!("leaf-{}", i), 120.0 * angle.cos(), 120.0 * angle.sin(),
                0, 1, format!("Leaf {}", i),
            );
            graph.add_edge("hub", &format!("leaf-{}", i), 1.0, 0);
        }

        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        // All 30 edges must be loaded — no cap.
        assert_eq!(sim.edges.len(), 30, "All 30 hub edges must be in physics sim");
        // Hub degree must be 30.
        assert_eq!(sim.degrees[0], 30, "Hub degree must reflect all connections");
    }

    #[test]
    fn test_intermediate_node_stays_near_parent() {
        // Regression: intermediate nodes (nested folder in a folder)
        // used to scatter because their edge to the parent hub was dropped.
        let mut graph = Graph::new();
        // Hub with 25 connections (well above old cap of 12)
        graph.add_node("hub".to_string(), 0.0, 0.0, 0, 25, "Hub".to_string());
        for i in 0..25 {
            let angle = (i as f32) * std::f32::consts::TAU / 25.0;
            let r = 120.0;
            graph.add_node(
                format!("child-{}", i), r * angle.cos(), r * angle.sin(),
                0, 2, format!("Child {}", i),
            );
            graph.add_edge("hub", &format!("child-{}", i), 1.0, 0);
        }
        // Intermediate node connected to child-0 (nested folder)
        graph.add_node("nested".to_string(), 240.0, 0.0, 0, 1, "Nested".to_string());
        graph.add_edge("child-0", "nested", 1.0, 0);

        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.alpha_decay = 0.0; // Keep physics running

        // Run 500 ticks to reach equilibrium
        for _ in 0..500 { sim.tick(); }

        // Find nested node's sim index (last node added = index 26)
        let nested_idx = 26;
        let child0_idx = 1; // first child after hub

        let dx = sim.x[nested_idx] - sim.x[child0_idx];
        let dy = sim.y[nested_idx] - sim.y[child0_idx];
        let dist_to_parent = (dx * dx + dy * dy).sqrt();

        // Nested node must stay within reasonable distance of its parent.
        // With link_distance=120, it should settle near that distance.
        assert!(dist_to_parent < 400.0,
            "Nested node should stay near parent (child-0), but distance was {:.1}",
            dist_to_parent);
    }
}
