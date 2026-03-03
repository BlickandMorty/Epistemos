//! Automatically generated advanced chaos engineering tests.
#[cfg(test)]
mod tests {
    use crate::simulation::{Simulation, ForceParams, CenterMode};
    use crate::types::Graph;

    #[test]
    fn test_chaos_sim_0_extreme_distances_n1_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::MAX, f32::MAX, -f32::MAX, -f32::MAX];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_1_extreme_distances_n1_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::MAX, f32::MAX, -f32::MAX, -f32::MAX];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_2_extreme_distances_n1_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::MAX, f32::MAX, -f32::MAX, -f32::MAX];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_3_extreme_distances_n10_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::MAX, f32::MAX, -f32::MAX, -f32::MAX];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_4_extreme_distances_n10_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::MAX, f32::MAX, -f32::MAX, -f32::MAX];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_5_extreme_distances_n10_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::MAX, f32::MAX, -f32::MAX, -f32::MAX];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_6_extreme_distances_n100_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::MAX, f32::MAX, -f32::MAX, -f32::MAX];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_7_extreme_distances_n100_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::MAX, f32::MAX, -f32::MAX, -f32::MAX];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_8_extreme_distances_n100_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::MAX, f32::MAX, -f32::MAX, -f32::MAX];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_9_micro_distances_n1_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.00000001, -0.00000001];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_10_micro_distances_n1_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.00000001, -0.00000001];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_11_micro_distances_n1_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.00000001, -0.00000001];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_12_micro_distances_n10_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.00000001, -0.00000001];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_13_micro_distances_n10_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.00000001, -0.00000001];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_14_micro_distances_n10_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.00000001, -0.00000001];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_15_micro_distances_n100_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.00000001, -0.00000001];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_16_micro_distances_n100_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.00000001, -0.00000001];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_17_micro_distances_n100_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.00000001, -0.00000001];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_18_nan_injection_n1_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::NAN];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_19_nan_injection_n1_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::NAN];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_20_nan_injection_n1_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::NAN];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_21_nan_injection_n10_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::NAN];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_22_nan_injection_n10_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::NAN];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_23_nan_injection_n10_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::NAN];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_24_nan_injection_n100_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::NAN];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_25_nan_injection_n100_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::NAN];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_26_nan_injection_n100_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::NAN];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_27_infinity_injection_n1_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::INFINITY, f32::NEG_INFINITY];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_28_infinity_injection_n1_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::INFINITY, f32::NEG_INFINITY];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_29_infinity_injection_n1_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::INFINITY, f32::NEG_INFINITY];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_30_infinity_injection_n10_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::INFINITY, f32::NEG_INFINITY];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_31_infinity_injection_n10_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::INFINITY, f32::NEG_INFINITY];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_32_infinity_injection_n10_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::INFINITY, f32::NEG_INFINITY];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_33_infinity_injection_n100_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::INFINITY, f32::NEG_INFINITY];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_34_infinity_injection_n100_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::INFINITY, f32::NEG_INFINITY];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_35_infinity_injection_n100_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![f32::INFINITY, f32::NEG_INFINITY];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
    }

    #[test]
    fn test_chaos_sim_36_zero_injection_n1_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.0, -0.0];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_37_zero_injection_n1_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.0, -0.0];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_38_zero_injection_n1_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.0, -0.0];
        for i in 0..1 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_39_zero_injection_n10_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.0, -0.0];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_40_zero_injection_n10_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.0, -0.0];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_41_zero_injection_n10_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.0, -0.0];
        for i in 0..10 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_42_zero_injection_n100_t1() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.0, -0.0];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_43_zero_injection_n100_t100() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.0, -0.0];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..100 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

    #[test]
    fn test_chaos_sim_44_zero_injection_n100_t1000() {
        let mut graph = Graph::new();
        let chaos_vals: Vec<f32> = vec![0.0, -0.0];
        for i in 0..100 {
            let val = chaos_vals[i % chaos_vals.len()];
            graph.add_node(
                format!("node-{}", i),
                val,
                val,
                0,
                if val.is_nan() || !val.is_finite() { 1 } else { (val.abs() as u32) % 100 },
                format!("N{}", i),
            );
        }
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.params.center_mode = CenterMode::Attract;
        
        // Trigger N ticks under chaos conditions
        for _ in 0..1000 {
            sim.tick();
        }
        
        // Under severe chaos (NaNs / Inf), math will break down, 
        // but the core requirement is we don't hit a panic boundary!
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite());
        }
    }

}
