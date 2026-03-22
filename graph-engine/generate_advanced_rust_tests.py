import itertools
import os

def generate_rust_chaos_tests():
    # Advanced Property / Chaos tests for core simulation logic.
    chaos_configs = [
        {"desc": "extreme_distances", "coords": "[f32::MAX, f32::MAX, -f32::MAX, -f32::MAX]"},
        {"desc": "micro_distances", "coords": "[0.00000001, -0.00000001]"},
        {"desc": "nan_injection", "coords": "[f32::NAN]"},
        {"desc": "infinity_injection", "coords": "[f32::INFINITY, f32::NEG_INFINITY]"},
        {"desc": "zero_injection", "coords": "[0.0, -0.0]"},
    ]
    node_configs = [1, 10, 100]
    tick_overloads = [1, 100, 1000]

    with open("src/advanced_chaos_tests.rs", "w") as f:
        f.write("//! Automatically generated advanced chaos engineering tests.\n")
        f.write("#[cfg(test)]\n")
        f.write("mod tests {\n")
        f.write("    use crate::simulation::{Simulation, ForceParams, CenterMode};\n")
        f.write("    use crate::types::Graph;\n\n")

        test_idx = 0
        for config in chaos_configs:
            for count in node_configs:
                for ticks in tick_overloads:
                    f.write(f"    #[test]\n")
                    f.write(f"    fn test_chaos_sim_{test_idx}_{config['desc']}_n{count}_t{ticks}() {{\n")
                    f.write(f"        let mut graph = Graph::new();\n")
                    f.write(f"        let chaos_vals: Vec<f32> = vec!{config['coords']};\n")
                    f.write(f"        for i in 0..{count} {{\n")
                    f.write(f"            let val = chaos_vals[i % chaos_vals.len()];\n")
                    f.write(f"            graph.add_node(\n")
                    f.write(f"                format!(\"node-{{}}\", i),\n")
                    f.write(f"                val,\n")
                    f.write(f"                val,\n")
                    f.write(f"                0,\n")
                    f.write(f"                if val.is_nan() || !val.is_finite() {{ 1 }} else {{ (val.abs() as u32) % 100 }},\n")
                    f.write(f"                format!(\"N{{}}\", i),\n")
                    f.write(f"            );\n")
                    f.write(f"        }}\n")
                    f.write(f"        let mut sim = Simulation::new();\n")
                    f.write(f"        sim.load_from_graph(&graph);\n")
                    f.write(f"        sim.params.center_mode = CenterMode::Attract;\n")
                    f.write(f"        \n")
                    f.write(f"        // Trigger N ticks under chaos conditions\n")
                    f.write(f"        for _ in 0..{ticks} {{\n")
                    f.write(f"            sim.tick();\n")
                    f.write(f"        }}\n")
                    f.write(f"        \n")
                    f.write(f"        // Under severe chaos (NaNs / Inf), math will break down, \n")
                    f.write(f"        // but the core requirement is we don't hit a panic boundary!\n")
                    if config["desc"] not in ["nan_injection", "infinity_injection", "extreme_distances"]:
                        f.write(f"        for i in 0..sim.x.len() {{\n")
                        f.write(f"            assert!(sim.x[i].is_finite());\n")
                        f.write(f"        }}\n")
                    f.write(f"    }}\n\n")
                    test_idx += 1

        f.write("}\n")
        print(f"Generated {test_idx} Rust Chaos tests")

if __name__ == "__main__":
    generate_rust_chaos_tests()
