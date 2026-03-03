import itertools

def generate_cluster_tests():
    node_counts = [10, 50, 200, 1000]
    graph_types = [
        "empty", 
        "complete", 
        "chain", 
        "star", 
        "ring", 
        "two_cliques", 
        "bipartite", 
        "disconnected_pairs"
    ]
    shuffle_edges = ["ordered", "reversed"]
    duplicate_edges = ["unique", "with_duplicates"]
    
    with open("src/comprehensive_cluster_tests.rs", "w") as f:
        f.write("//! Automatically generated comprehensive clustering tests.\n")
        f.write("#[cfg(test)]\n")
        f.write("mod tests {\n")
        f.write("    use crate::cluster::detect_communities;\n")
        f.write("\n")
        
        test_idx = 0
        for (count, gtype, shuffle, dupes) in itertools.product(node_counts, graph_types, shuffle_edges, duplicate_edges):
            # 4 * 8 * 2 * 2 = 128 tests
            
            f.write(f"    #[test]\n")
            f.write(f"    fn test_cluster_{test_idx}_n{count}_{gtype}_{shuffle}_{dupes}() {{\n")
            f.write(f"        let n = {count};\n")
            f.write(f"        let mut edges = Vec::new();\n")
            
            if gtype == "empty":
                pass
            elif gtype == "complete":
                f.write(f"        for i in 0..n {{\n")
                f.write(f"            for j in (i+1)..n {{\n")
                f.write(f"                edges.push((i, j));\n")
                f.write(f"            }}\n")
                f.write(f"        }}\n")
            elif gtype == "chain":
                f.write(f"        for i in 0..n-1 {{\n")
                f.write(f"            edges.push((i, i+1));\n")
                f.write(f"        }}\n")
            elif gtype == "star":
                f.write(f"        for i in 1..n {{\n")
                f.write(f"            edges.push((0, i));\n")
                f.write(f"        }}\n")
            elif gtype == "ring":
                f.write(f"        for i in 0..n {{\n")
                f.write(f"            edges.push((i, (i+1)%n));\n")
                f.write(f"        }}\n")
            elif gtype == "two_cliques":
                f.write(f"        let half = n / 2;\n")
                f.write(f"        for i in 0..half {{\n")
                f.write(f"            for j in (i+1)..half {{\n")
                f.write(f"                edges.push((i, j));\n")
                f.write(f"            }}\n")
                f.write(f"        }}\n")
                f.write(f"        for i in half..n {{\n")
                f.write(f"            for j in (i+1)..n {{\n")
                f.write(f"                edges.push((i, j));\n")
                f.write(f"            }}\n")
                f.write(f"        }}\n")
                f.write(f"        edges.push((0, half)); // bridge\n")
            elif gtype == "bipartite":
                f.write(f"        let half = n / 2;\n")
                f.write(f"        for i in 0..half {{\n")
                f.write(f"            for j in half..n {{\n")
                f.write(f"                edges.push((i, j));\n")
                f.write(f"            }}\n")
                f.write(f"        }}\n")
            elif gtype == "disconnected_pairs":
                f.write(f"        for i in (0..(n - 1)).step_by(2) {{\n")
                f.write(f"            edges.push((i, i+1));\n")
                f.write(f"        }}\n")
                
            if dupes == "with_duplicates":
                f.write(f"        let mut extra = edges.clone();\n")
                f.write(f"        edges.append(&mut extra);\n")
                
            if shuffle == "reversed":
                f.write(f"        edges.reverse();\n")
                
            f.write(f"        let result = detect_communities(n, &edges);\n")
            
            f.write(f"        assert_eq!(result.len(), {count}, \"Output length should match node count\");\n")
            f.write(f"        for &c in &result {{\n")
            f.write(f"            assert!((c as usize) < {count}, \"Cluster ID {{}} out of bounds\", c);\n")
            f.write(f"        }}\n")
            
            # Additional semantic checks based on topology
            if gtype == "empty":
                f.write(f"        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();\n")
                f.write(f"        assert_eq!(unique.len(), {count}, \"Empty graph should have N distinct clusters\");\n")
            elif gtype == "disconnected_pairs":
                f.write(f"        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();\n")
                f.write(f"        let expected_clusters = ({count} + 1) / 2;\n")
                f.write(f"        assert_eq!(unique.len(), expected_clusters, \"Disconnected pairs should have N/2 clusters\");\n")
            elif gtype == "two_cliques" and count >= 50:
                f.write(f"        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();\n")
                f.write(f"        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.\n")
                f.write(f"        assert!(unique.len() >= 2, \"Two distinct cliques with 1 bridge should not completely merge\");\n")

            f.write(f"    }}\n\n")
            test_idx += 1

        f.write("}\n")

if __name__ == "__main__":
    generate_cluster_tests()
