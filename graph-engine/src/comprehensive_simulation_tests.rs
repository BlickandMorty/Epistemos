//! Automatically generated comprehensive simulation tests.
#[cfg(test)]
mod tests {
    use crate::simulation::{Simulation, CenterMode};
    use crate::types::Graph;

    #[test]
    fn test_scenario_0_n2_chain_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_1_n2_chain_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_2_n2_chain_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_3_n2_chain_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_4_n2_chain_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_5_n2_chain_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_6_n2_chain_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_7_n2_chain_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_8_n2_chain_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_9_n2_chain_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_10_n2_chain_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_11_n2_chain_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_12_n2_chain_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_13_n2_chain_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_14_n2_chain_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_15_n2_chain_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_16_n2_chain_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_17_n2_chain_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(2 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_18_n2_star_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_19_n2_star_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_20_n2_star_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_21_n2_star_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_22_n2_star_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_23_n2_star_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_24_n2_star_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_25_n2_star_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_26_n2_star_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_27_n2_star_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_28_n2_star_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_29_n2_star_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_30_n2_star_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_31_n2_star_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_32_n2_star_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_33_n2_star_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_34_n2_star_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_35_n2_star_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..2 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_36_n2_cycle_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_37_n2_cycle_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_38_n2_cycle_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_39_n2_cycle_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_40_n2_cycle_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_41_n2_cycle_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_42_n2_cycle_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_43_n2_cycle_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_44_n2_cycle_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_45_n2_cycle_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_46_n2_cycle_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_47_n2_cycle_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_48_n2_cycle_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_49_n2_cycle_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_50_n2_cycle_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_51_n2_cycle_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_52_n2_cycle_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_53_n2_cycle_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 > 2 {
            for i in 0..2 {
                let next = (i + 1) % 2;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_54_n2_full_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_55_n2_full_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_56_n2_full_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_57_n2_full_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_58_n2_full_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_59_n2_full_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_60_n2_full_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_61_n2_full_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_62_n2_full_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_63_n2_full_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_64_n2_full_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_65_n2_full_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_66_n2_full_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_67_n2_full_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_68_n2_full_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_69_n2_full_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_70_n2_full_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_71_n2_full_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 2 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..2 {
                for j in (i + 1)..2 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_72_n2_disconnected_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_73_n2_disconnected_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_74_n2_disconnected_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_75_n2_disconnected_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_76_n2_disconnected_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_77_n2_disconnected_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_78_n2_disconnected_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_79_n2_disconnected_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_80_n2_disconnected_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_81_n2_disconnected_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_82_n2_disconnected_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_83_n2_disconnected_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_84_n2_disconnected_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_85_n2_disconnected_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_86_n2_disconnected_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_87_n2_disconnected_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_88_n2_disconnected_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_89_n2_disconnected_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..2 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..2 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_90_n10_chain_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_91_n10_chain_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_92_n10_chain_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_93_n10_chain_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_94_n10_chain_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_95_n10_chain_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_96_n10_chain_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_97_n10_chain_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_98_n10_chain_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_99_n10_chain_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_100_n10_chain_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_101_n10_chain_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_102_n10_chain_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_103_n10_chain_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_104_n10_chain_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_105_n10_chain_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_106_n10_chain_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_107_n10_chain_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(10 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_108_n10_star_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_109_n10_star_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_110_n10_star_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_111_n10_star_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_112_n10_star_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_113_n10_star_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_114_n10_star_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_115_n10_star_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_116_n10_star_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_117_n10_star_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_118_n10_star_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_119_n10_star_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_120_n10_star_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_121_n10_star_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_122_n10_star_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_123_n10_star_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_124_n10_star_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_125_n10_star_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..10 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_126_n10_cycle_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_127_n10_cycle_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_128_n10_cycle_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_129_n10_cycle_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_130_n10_cycle_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_131_n10_cycle_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_132_n10_cycle_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_133_n10_cycle_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_134_n10_cycle_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_135_n10_cycle_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_136_n10_cycle_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_137_n10_cycle_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_138_n10_cycle_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_139_n10_cycle_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_140_n10_cycle_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_141_n10_cycle_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_142_n10_cycle_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_143_n10_cycle_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 > 2 {
            for i in 0..10 {
                let next = (i + 1) % 10;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_144_n10_full_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_145_n10_full_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_146_n10_full_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_147_n10_full_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_148_n10_full_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_149_n10_full_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_150_n10_full_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_151_n10_full_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_152_n10_full_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_153_n10_full_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_154_n10_full_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_155_n10_full_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_156_n10_full_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_157_n10_full_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_158_n10_full_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_159_n10_full_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_160_n10_full_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_161_n10_full_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 10 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..10 {
                for j in (i + 1)..10 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_162_n10_disconnected_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_163_n10_disconnected_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_164_n10_disconnected_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_165_n10_disconnected_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_166_n10_disconnected_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_167_n10_disconnected_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_168_n10_disconnected_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_169_n10_disconnected_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_170_n10_disconnected_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_171_n10_disconnected_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_172_n10_disconnected_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_173_n10_disconnected_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_174_n10_disconnected_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_175_n10_disconnected_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_176_n10_disconnected_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_177_n10_disconnected_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_178_n10_disconnected_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_179_n10_disconnected_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..10 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..10 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_180_n50_chain_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_181_n50_chain_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_182_n50_chain_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_183_n50_chain_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_184_n50_chain_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_185_n50_chain_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_186_n50_chain_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_187_n50_chain_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_188_n50_chain_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_189_n50_chain_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_190_n50_chain_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_191_n50_chain_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_192_n50_chain_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_193_n50_chain_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_194_n50_chain_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_195_n50_chain_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_196_n50_chain_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_197_n50_chain_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 0..(50 - 1) {
            g.add_edge(&format!("n{}", i), &format!("n{}", i + 1), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_198_n50_star_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_199_n50_star_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_200_n50_star_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_201_n50_star_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_202_n50_star_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_203_n50_star_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_204_n50_star_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_205_n50_star_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_206_n50_star_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_207_n50_star_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_208_n50_star_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_209_n50_star_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_210_n50_star_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_211_n50_star_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_212_n50_star_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_213_n50_star_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_214_n50_star_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_215_n50_star_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        for i in 1..50 {
            g.add_edge("n0", &format!("n{}", i), 1.0, 0);
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_216_n50_cycle_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_217_n50_cycle_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_218_n50_cycle_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_219_n50_cycle_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_220_n50_cycle_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_221_n50_cycle_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_222_n50_cycle_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_223_n50_cycle_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_224_n50_cycle_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_225_n50_cycle_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_226_n50_cycle_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_227_n50_cycle_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_228_n50_cycle_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_229_n50_cycle_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_230_n50_cycle_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_231_n50_cycle_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_232_n50_cycle_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_233_n50_cycle_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 > 2 {
            for i in 0..50 {
                let next = (i + 1) % 50;
                g.add_edge(&format!("n{}", i), &format!("n{}", next), 1.0, 0);
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_234_n50_full_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_235_n50_full_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_236_n50_full_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_237_n50_full_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_238_n50_full_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_239_n50_full_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_240_n50_full_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_241_n50_full_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_242_n50_full_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_243_n50_full_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_244_n50_full_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_245_n50_full_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_246_n50_full_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_247_n50_full_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_248_n50_full_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_249_n50_full_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_250_n50_full_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_251_n50_full_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        if 50 <= 20 { // Limit full graph edges to avoid massive tests
            for i in 0..50 {
                for j in (i + 1)..50 {
                    g.add_edge(&format!("n{}", i), &format!("n{}", j), 1.0, 0);
                }
            }
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_252_n50_disconnected_tiny_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_253_n50_disconnected_tiny_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_254_n50_disconnected_tiny_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_255_n50_disconnected_tiny_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_256_n50_disconnected_tiny_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_257_n50_disconnected_tiny_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 0.1;
            let y = (i as f32 / 5.0) * 0.1;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_258_n50_disconnected_normal_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_259_n50_disconnected_normal_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_260_n50_disconnected_normal_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_261_n50_disconnected_normal_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_262_n50_disconnected_normal_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_263_n50_disconnected_normal_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 10.0;
            let y = (i as f32 / 5.0) * 10.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_264_n50_disconnected_massive_off_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_265_n50_disconnected_massive_off_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Off;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_266_n50_disconnected_massive_attract_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_267_n50_disconnected_massive_attract_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Attract;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_268_n50_disconnected_massive_repel_weak() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 0.05;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

    #[test]
    fn test_scenario_269_n50_disconnected_massive_repel_strong() {
        let mut g = Graph::new();
        for i in 0..50 {
            let x = (i as f32 % 5.0) * 5000.0;
            let y = (i as f32 / 5.0) * 5000.0;
            g.add_node(format!("n{}", i), x, y, 0, 1, format!("N{}", i));
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&g);
        sim.params.center_mode = CenterMode::Repel;
        sim.params.link_strength = 2.0;
        for _ in 0..100 {
            sim.tick();
        }
        for i in 0..50 {
            assert!(sim.x[i].is_finite(), "Node {} x is not finite", i);
            assert!(sim.y[i].is_finite(), "Node {} y is not finite", i);
            assert!(sim.x[i].abs() < 1e7, "Node {} x exploded to {}", i, sim.x[i]);
            assert!(sim.y[i].abs() < 1e7, "Node {} y exploded to {}", i, sim.y[i]);
        }
    }

}
