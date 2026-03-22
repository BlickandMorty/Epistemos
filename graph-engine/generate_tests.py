import itertools

def generate_tests():
    node_counts = [2, 10, 50]
    topologies = ["chain", "star", "cycle", "full", "disconnected"]
    spreads = [("tiny", 0.1), ("normal", 10.0), ("massive", 5000.0)]
    center_modes = ["Off", "Attract", "Repel"]
    link_strengths = ["weak", "strong"]

    with open("src/comprehensive_simulation_tests.rs", "w") as f:
        f.write("//! Automatically generated comprehensive simulation tests.\n")
        f.write("#[cfg(test)]\n")
        f.write("mod tests {\n")
        f.write("    use crate::simulation::{Simulation, CenterMode};\n")
        f.write("    use crate::types::Graph;\n")
        f.write("\n")

        test_idx = 0
        for (nodes, topo, (spread_name, spread_val), center, link) in itertools.product(node_counts, topologies, spreads, center_modes, link_strengths):
            # We want around 200 tests.
            # 3 * 5 * 3 * 3 * 2 = 270 combinations. Perfect!

            f.write(f"    #[test]\n")
            f.write(f"    fn test_scenario_{test_idx}_n{nodes}_{topo}_{spread_name}_{center.lower()}_{link}() {{\n")
            f.write(f"        let mut g = Graph::new();\n")
            
            # Nodes
            f.write(f"        for i in 0..{nodes} {{\n")
            f.write(f"            let x = (i as f32 % 5.0) * {spread_val};\n")
            f.write(f"            let y = (i as f32 / 5.0) * {spread_val};\n")
            f.write(f"            g.add_node(format!(\"n{{}}\", i), x, y, 0, 1, format!(\"N{{}}\", i));\n")
            f.write(f"        }}\n")

            # Edges
            if topo == "chain":
                f.write(f"        for i in 0..({nodes} - 1) {{\n")
                f.write(f"            g.add_edge(&format!(\"n{{}}\", i), &format!(\"n{{}}\", i + 1), 1.0, 0);\n")
                f.write(f"        }}\n")
            elif topo == "star":
                f.write(f"        for i in 1..{nodes} {{\n")
                f.write(f"            g.add_edge(\"n0\", &format!(\"n{{}}\", i), 1.0, 0);\n")
                f.write(f"        }}\n")
            elif topo == "cycle":
                f.write(f"        if {nodes} > 2 {{\n")
                f.write(f"            for i in 0..{nodes} {{\n")
                f.write(f"                let next = (i + 1) % {nodes};\n")
                f.write(f"                g.add_edge(&format!(\"n{{}}\", i), &format!(\"n{{}}\", next), 1.0, 0);\n")
                f.write(f"            }}\n")
                f.write(f"        }}\n")
            elif topo == "full":
                f.write(f"        if {nodes} <= 20 {{ // Limit full graph edges to avoid massive tests\n")
                f.write(f"            for i in 0..{nodes} {{\n")
                f.write(f"                for j in (i + 1)..{nodes} {{\n")
                f.write(f"                    g.add_edge(&format!(\"n{{}}\", i), &format!(\"n{{}}\", j), 1.0, 0);\n")
                f.write(f"                }}\n")
                f.write(f"            }}\n")
                f.write(f"        }}\n")
            # disconnected adds no edges

            f.write(f"        let mut sim = Simulation::new();\n")
            f.write(f"        sim.load_from_graph(&g);\n")

            # Apply parameters
            f.write(f"        sim.params.center_mode = CenterMode::{center};\n")
            if link == "weak":
                f.write(f"        sim.params.link_strength = 0.05;\n")
            else:
                f.write(f"        sim.params.link_strength = 2.0;\n")

            # Run simulation
            f.write(f"        for _ in 0..100 {{\n")
            f.write(f"            sim.tick();\n")
            f.write(f"        }}\n")

            # Assertions
            f.write(f"        for i in 0..{nodes} {{\n")
            f.write(f"            assert!(sim.x[i].is_finite(), \"Node {{}} x is not finite\", i);\n")
            f.write(f"            assert!(sim.y[i].is_finite(), \"Node {{}} y is not finite\", i);\n")
            f.write(f"            assert!(sim.x[i].abs() < 1e7, \"Node {{}} x exploded to {{}}\", i, sim.x[i]);\n")
            f.write(f"            assert!(sim.y[i].abs() < 1e7, \"Node {{}} y exploded to {{}}\", i, sim.y[i]);\n")
            f.write(f"        }}\n")
            f.write(f"    }}\n\n")

            test_idx += 1

        f.write("}\n")

if __name__ == "__main__":
    generate_tests()
