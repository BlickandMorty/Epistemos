import itertools

def generate_spatial_tests():
    node_counts = [0, 1, 10, 100, 500]
    layouts = ["clustered", "grid", "line", "origin"]
    radii = ["uniform_10", "uniform_100", "mixed_1_to_50"]
    visibilities = ["all_visible", "none_visible", "half_visible"]
    queries = ["exact_center", "padded_edge", "far_miss", "mass_queries"]

    with open("src/comprehensive_spatial_tests.rs", "w") as f:
        f.write("//! Automatically generated comprehensive spatial tests.\n")
        f.write("#[cfg(test)]\n")
        f.write("mod tests {\n")
        f.write("    use crate::spatial::SpatialIndex;\n")
        f.write("    use crate::types::{Node, NodeType};\n")
        f.write("\n")
        f.write("    fn make_test_node(id: u32, x: f32, y: f32, radius: f32, visible: bool) -> Node {\n")
        f.write("        Node {\n")
        f.write("            id,\n")
        f.write("            uuid: format!(\"uuid-{}\", id),\n")
        f.write("            x, y, vx: 0.0, vy: 0.0, fx: None, fy: None,\n")
        f.write("            node_type: NodeType::from_u8(0),\n")
        f.write("            link_count: 1,\n")
        f.write("            radius,\n")
        f.write("            label: format!(\"N{}\", id),\n")
        f.write("            visible,\n")
        f.write("            created_at: 0.0, updated_at: 0.0, confidence: 0.0,\n")
        f.write("        }\n")
        f.write("    }\n\n")

        test_idx = 0
        for (count, layout, radius, vis, query) in itertools.product(node_counts, layouts, radii, visibilities, queries):
            # 5 * 4 * 3 * 3 * 4 = 720 tests!
            f.write(f"    #[test]\n")
            f.write(f"    fn test_spatial_{test_idx}_n{count}_{layout}_{radius}_{vis}_{query}() {{\n")
            f.write(f"        let mut nodes = Vec::new();\n")
            f.write(f"        for i in 0..{count} {{\n")
            
            # Layout logic
            if layout == "grid":
                f.write(f"            let x = (i % 10) as f32 * 50.0;\n")
                f.write(f"            let y = (i / 10) as f32 * 50.0;\n")
            elif layout == "line":
                f.write(f"            let x = i as f32 * 10.0;\n")
                f.write(f"            let y = 0.0;\n")
            elif layout == "clustered":
                f.write(f"            let cluster_dx = (i % 3) as f32 * 2.0;\n")
                f.write(f"            let cluster_dy = (i / 3 % 3) as f32 * 2.0;\n")
                f.write(f"            let offset = (i / 9) as f32 * 1000.0;\n")
                f.write(f"            let x = offset + cluster_dx;\n")
                f.write(f"            let y = offset + cluster_dy;\n")
            elif layout == "origin":
                f.write(f"            let x = 0.0;\n")
                f.write(f"            let y = 0.0;\n")
                
            # Radius logic
            if radius == "uniform_10":
                f.write(f"            let r = 10.0;\n")
            elif radius == "uniform_100":
                f.write(f"            let r = 100.0;\n")
            elif radius == "mixed_1_to_50":
                f.write(f"            let r = 1.0 + (i % 50) as f32;\n")
                
            # Visibility logic
            if vis == "all_visible":
                f.write(f"            let v = true;\n")
            elif vis == "none_visible":
                f.write(f"            let v = false;\n")
            elif vis == "half_visible":
                f.write(f"            let v = i % 2 == 0;\n")

            f.write(f"            nodes.push(make_test_node(i as u32, x, y, r, v));\n")
            f.write(f"        }}\n")

            f.write(f"        let mut idx = SpatialIndex::new();\n")
            f.write(f"        idx.build(&nodes);\n")
            
            # Count expected visible
            if vis == "all_visible":
                f.write(f"        let expected_len = {count};\n")
            elif vis == "none_visible":
                f.write(f"        let expected_len = 0;\n")
            elif vis == "half_visible":
                f.write(f"        let expected_len = (0..{count}).filter(|i| i % 2 == 0).count();\n")
                
            f.write(f"        assert_eq!(idx.len(), expected_len, \"Index length mismatch\");\n")
            
            # Query logic
            if count > 0:
                f.write(f"        let target_node = &nodes[0];\n")
                f.write(f"        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs\n")
                
                if query == "exact_center":
                    f.write(f"        let res = idx.query_point(target_node.x, target_node.y);\n")
                    f.write(f"        if target_node.visible {{\n")
                    f.write(f"            assert!(res.is_some(), \"Should hit center of visible point\");\n")
                    f.write(f"        }} else {{\n")
                    f.write(f"            assert!(res.is_none() || {count} > 1, \"Should not hit invisible point unless coincident with a visible one\");\n")
                    f.write(f"        }}\n")
                elif query == "padded_edge":
                    f.write(f"        let qx = target_node.x + hit_pad - 0.1;\n")
                    f.write(f"        let qy = target_node.y;\n")
                    f.write(f"        let res = idx.query_point(qx, qy);\n")
                    f.write(f"        if target_node.visible {{\n")
                    f.write(f"            assert!(res.is_some(), \"Should hit padded edge\");\n")
                    f.write(f"        }}\n")
                elif query == "far_miss":
                    f.write(f"        let qx = target_node.x + hit_pad + 10.0;\n")
                    f.write(f"        let qy = target_node.y;\n")
                    f.write(f"        let res = idx.query_point(qx, qy);\n")
                    # It might hit ANOTHER node if they are clustered or origin.
                    if layout not in ["origin", "clustered", "line"] and vis == "all_visible" and radius == "uniform_10":
                         f.write(f"        assert!(res.is_none(), \"Should definitely miss isolated far point\");\n")
                elif query == "mass_queries":
                    f.write(f"        for j in 0..100 {{\n")
                    f.write(f"            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);\n")
                    f.write(f"        }}\n")

            f.write(f"    }}\n\n")
            test_idx += 1

        f.write("}\n")

if __name__ == "__main__":
    generate_spatial_tests()
