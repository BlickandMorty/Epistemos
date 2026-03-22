import itertools

def generate_search_tests():
    dataset_types = [
        ("simple", '["apple", "banana", "cherry", "date"]'),
        ("tech", '["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"]'),
        ("similar", '["test", "testing", "tester", "tested", "testament"]'),
        ("mixed_case", '["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"]'),
        ("special_chars", '["C++", "C#", "F#", "Objective-C", "HTML5"]'),
    ]
    
    visibility_states = [
        ("all_visible", "true"),
        ("mixed_visible", "i % 2 == 0"),
        ("none_visible", "false"),
    ]
    
    queries = [
        ("exact", "exact_match"),
        ("prefix", "prefix_match"),
        ("contains", "contains_match"),
        ("subsequence", "subseq_match"),
        ("typo1", "typo1_match"),
        ("typo2", "typo2_match"),
        ("empty", "empty"),
        ("miss", "miss"),
    ]
    
    limits = [1, 5, 50]

    with open("src/comprehensive_search_tests.rs", "w") as f:
        f.write("//! Automatically generated comprehensive search tests.\n")
        f.write("#[cfg(test)]\n")
        f.write("mod tests {\n")
        f.write("    use crate::search::SearchIndex;\n")
        f.write("    use crate::types::{Node, NodeType};\n")
        f.write("\n")
        
        f.write("    fn make_test_node(id: usize, label: &str, visible: bool) -> Node {\n")
        f.write("        Node {\n")
        f.write("            id: 0,\n")
        f.write("            uuid: format!(\"uuid-{}\", id),\n")
        f.write("            x: 0.0, y: 0.0, vx: 0.0, vy: 0.0, fx: None, fy: None,\n")
        f.write("            node_type: NodeType::from_u8(0),\n")
        f.write("            link_count: 1,\n")
        f.write("            radius: 8.0,\n")
        f.write("            label: label.to_string(),\n")
        f.write("            visible,\n")
        f.write("            created_at: 0.0, updated_at: 0.0, confidence: 0.0,\n")
        f.write("        }\n")
        f.write("    }\n\n")

        test_idx = 0
        for ((ds_name, ds_vals), (vis_name, vis_expr), (query_type, query_logic), limit) in itertools.product(dataset_types, visibility_states, queries, limits):
            # 5 * 3 * 8 * 3 = 360 tests. A beautiful massive suite!
            
            f.write(f"    #[test]\n")
            f.write(f"    fn test_search_{test_idx}_{ds_name}_{vis_name}_{query_type}_limit{limit}() {{\n")
            f.write(f"        let labels = {ds_vals};\n")
            f.write(f"        let mut nodes = Vec::new();\n")
            f.write(f"        for (i, &l) in labels.iter().enumerate() {{\n")
            f.write(f"            let visible = {vis_expr};\n")
            f.write(f"            nodes.push(make_test_node(i, l, visible));\n")
            f.write(f"        }}\n")
            f.write(f"        let mut idx = SearchIndex::new();\n")
            f.write(f"        idx.build(&nodes);\n")
            
            # Determine query string based on dataset and query type
            # We'll just hardcode some logic in rust to pick a good query string dynamically 
            # based on the first item in the dataset.
            f.write(f"        let target = labels[0];\n")
            f.write(f"        let query = match \"{query_type}\" {{\n")
            f.write(f"            \"exact\" => target.to_string(),\n")
            f.write(f"            \"prefix\" => target.chars().take(3).collect(),\n")
            f.write(f"            \"contains\" => if target.len() > 3 {{ target.chars().skip(1).take(3).collect() }} else {{ target.to_string() }},\n")
            f.write(f"            \"subsequence\" => target.chars().step_by(2).collect(),\n")
            f.write(f"            \"typo1\" => {{ let mut q = target.to_string(); if !q.is_empty() {{ q.replace_range(0..1, \"z\"); }} q }},\n")
            f.write(f"            \"typo2\" => {{ let mut q = target.to_string(); if q.len() > 1 {{ q.replace_range(0..2, \"zz\"); }} q }},\n")
            f.write(f"            \"empty\" => String::new(),\n")
            f.write(f"            \"miss\" => \"xyz_unlikely_match_123\".to_string(),\n")
            f.write(f"            _ => String::new(),\n")
            f.write(f"        }};\n")
            
            f.write(f"        let results = idx.search(&query, {limit});\n")
            
            f.write(f"        assert!(results.len() <= {limit}, \"Results exceeded limit\");\n")
            f.write(f"        if \"{vis_name}\" == \"none_visible\" {{\n")
            f.write(f"            assert!(results.is_empty(), \"Hidden nodes should not be found\");\n")
            f.write(f"        }}\n")
            f.write(f"        if \"{query_type}\" == \"empty\" {{\n")
            f.write(f"            assert!(results.is_empty(), \"Empty query should return nothing\");\n")
            f.write(f"        }}\n")
            f.write(f"        if \"{query_type}\" == \"miss\" {{\n")
            f.write(f"            assert!(results.is_empty(), \"Unlikely query should return nothing\");\n")
            f.write(f"        }}\n")
            
            f.write(f"    }}\n\n")
            
            test_idx += 1

        f.write("}\n")

if __name__ == "__main__":
    generate_search_tests()
