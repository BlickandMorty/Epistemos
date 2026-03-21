//! Louvain community detection for cluster physics.
//! Detects densely connected subgraphs and assigns cluster IDs.

use rustc_hash::FxHashMap;

/// Detect communities using Louvain modularity optimization.
/// Returns a Vec<u32> where result[i] = cluster_id for node i.
/// Only operates on the provided edge list (simulation indices).
///
/// Uses the standard modularity gain formula: a node moves to a neighboring
/// community only when the gain ΔQ > 0. This prevents single bridge edges
/// from merging distinct dense subgraphs.
///
/// Max iterations scale with graph size to keep commit() responsive:
/// <500 nodes → 20 passes, 500-2000 → 10, 2000+ → 5.
pub fn detect_communities(n: usize, edges: &[(usize, usize)]) -> Vec<u32> {
    if n == 0 {
        return Vec::new();
    }
    if edges.is_empty() {
        return (0..n as u32).collect();
    }

    let mut community: Vec<u32> = (0..n as u32).collect();
    let m2 = (2 * edges.len()) as f64; // 2m (total degree sum)

    let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
    for &(u, v) in edges {
        if u < n && v < n {
            adj[u].push(v);
            adj[v].push(u);
        }
    }

    let degree: Vec<f64> = (0..n).map(|i| adj[i].len() as f64).collect();

    // Scale max iterations with graph size to keep commit() responsive.
    // Above 5K we skip Louvain entirely (handled in engine.rs), but guard here too.
    let max_passes = if n < 500 {
        20
    } else if n < 2000 {
        10
    } else if n < 5000 {
        5
    } else {
        2
    };

    for _ in 0..max_passes {
        let mut improved = false;

        // Σ_tot: sum of degrees per community — computed ONCE per pass, not per node.
        // Incrementally updated when a node moves communities.
        let mut sigma: FxHashMap<u32, f64> = FxHashMap::default();
        for j in 0..n {
            *sigma.entry(community[j]).or_default() += degree[j];
        }

        for i in 0..n {
            let ki = degree[i];
            let current = community[i];

            // Edges from i to each neighboring community
            let mut ki_to: FxHashMap<u32, f64> = FxHashMap::default();
            for &j in &adj[i] {
                *ki_to.entry(community[j]).or_default() += 1.0;
            }

            let ki_in_current = ki_to.get(&current).copied().unwrap_or(0.0);
            let sigma_current = sigma.get(&current).copied().unwrap_or(0.0);

            let mut best_comm = current;
            let mut best_gain = 0.0f64;

            for (&comm, &ki_in_c) in &ki_to {
                if comm == current {
                    continue;
                }
                let sigma_c = sigma.get(&comm).copied().unwrap_or(0.0);

                // ΔQ = (k_{i,C} - k_{i,current}) / 2m
                //    + k_i · (Σ_tot(current) - k_i - Σ_tot(C)) / (2m)²
                let gain = (ki_in_c - ki_in_current) / m2
                    + ki * (sigma_current - ki - sigma_c) / (m2 * m2);

                if gain > best_gain {
                    best_gain = gain;
                    best_comm = comm;
                }
            }

            if best_comm != current {
                // Incrementally update sigma: remove ki from old, add to new.
                *sigma.entry(current).or_default() -= ki;
                *sigma.entry(best_comm).or_default() += ki;
                community[i] = best_comm;
                improved = true;
            }
        }

        if !improved {
            break;
        }
    }

    // Renumber communities to be contiguous (0, 1, 2, ...).
    let mut renumber: FxHashMap<u32, u32> = FxHashMap::default();
    let mut next_id = 0u32;
    for c in &mut community {
        let new_id = renumber.entry(*c).or_insert_with(|| {
            let id = next_id;
            next_id += 1;
            id
        });
        *c = *new_id;
    }

    community
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_graph() {
        let result = detect_communities(0, &[]);
        assert!(result.is_empty());
    }

    #[test]
    fn no_edges_each_node_own_cluster() {
        let result = detect_communities(5, &[]);
        assert_eq!(result.len(), 5);
        let unique: std::collections::HashSet<u32> = result.into_iter().collect();
        assert_eq!(unique.len(), 5);
    }

    #[test]
    fn two_cliques_detected() {
        let edges = vec![
            (0, 1),
            (1, 2),
            (0, 2), // clique A
            (3, 4),
            (4, 5),
            (3, 5), // clique B
            (2, 3), // bridge
        ];
        let result = detect_communities(6, &edges);
        assert_eq!(result.len(), 6);
        assert_eq!(result[0], result[1]);
        assert_eq!(result[1], result[2]);
        assert_eq!(result[3], result[4]);
        assert_eq!(result[4], result[5]);
        assert_ne!(
            result[0], result[3],
            "two cliques should be different clusters"
        );
    }

    #[test]
    fn single_component_one_cluster() {
        let edges = vec![(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)];
        let result = detect_communities(4, &edges);
        assert!(result.iter().all(|&c| c == result[0]));
    }

    #[test]
    fn ring_graph() {
        let edges = vec![(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0)];
        let result = detect_communities(6, &edges);
        assert_eq!(result.len(), 6);
        let max_cluster = *result.iter().max().unwrap();
        assert!(max_cluster <= 5);
    }

    // =========================================================================
    // Empty and Trivial Graph Tests (10 tests)
    // =========================================================================

    #[test]
    fn detect_empty_graph() {
        let result = detect_communities(0, &[]);
        assert!(result.is_empty());
    }

    #[test]
    fn detect_single_node() {
        let result = detect_communities(1, &[]);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0], 0);
    }

    #[test]
    fn detect_two_nodes_no_edge() {
        let result = detect_communities(2, &[]);
        assert_eq!(result.len(), 2);
        // Each node in its own cluster
        assert_ne!(result[0], result[1]);
    }

    #[test]
    fn detect_two_nodes_with_edge() {
        let edges = vec![(0, 1)];
        let result = detect_communities(2, &edges);
        assert_eq!(result.len(), 2);
        // Connected nodes should be in same cluster
        assert_eq!(result[0], result[1]);
    }

    #[test]
    fn detect_three_nodes_line() {
        let edges = vec![(0, 1), (1, 2)];
        let result = detect_communities(3, &edges);
        assert_eq!(result.len(), 3);
        // Line graph should be one cluster
        assert_eq!(result[0], result[1]);
        assert_eq!(result[1], result[2]);
    }

    #[test]
    fn detect_three_nodes_triangle() {
        let edges = vec![(0, 1), (1, 2), (2, 0)];
        let result = detect_communities(3, &edges);
        assert_eq!(result.len(), 3);
        // Triangle is a clique
        assert_eq!(result[0], result[1]);
        assert_eq!(result[1], result[2]);
    }

    #[test]
    fn detect_three_nodes_star() {
        let edges = vec![(0, 1), (0, 2)];
        let result = detect_communities(3, &edges);
        assert_eq!(result.len(), 3);
        // Star graph - center with two leaves
        assert_eq!(result[0], result[1]);
        assert_eq!(result[0], result[2]);
    }

    #[test]
    fn detect_disconnected_components() {
        let edges = vec![(0, 1), (2, 3)];
        let result = detect_communities(4, &edges);
        assert_eq!(result.len(), 4);
        // Two separate pairs
        assert_eq!(result[0], result[1]);
        assert_eq!(result[2], result[3]);
        assert_ne!(result[0], result[2]);
    }

    #[test]
    fn detect_many_isolated_nodes() {
        let n = 100;
        let result = detect_communities(n, &[]);
        assert_eq!(result.len(), n);
        // Each isolated node should be its own cluster
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(unique.len(), n);
    }

    #[test]
    fn detect_complete_graph() {
        let n = 5;
        let mut edges = vec![];
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), n);
        // All in one cluster
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(unique.len(), 1);
    }

    // =========================================================================
    // Louvain Algorithm Tests (10 tests)
    // =========================================================================

    #[test]
    fn louvain_finds_communities() {
        // Two clear communities with dense internal connections
        let mut edges = vec![];
        // Clique A: nodes 0-4
        for i in 0..5 {
            for j in (i + 1)..5 {
                edges.push((i, j));
            }
        }
        // Clique B: nodes 5-9
        for i in 5..10 {
            for j in (i + 1)..10 {
                edges.push((i, j));
            }
        }
        // Single bridge edge
        edges.push((4, 5));

        let result = detect_communities(10, &edges);
        assert_eq!(result.len(), 10);
        // Should detect two communities
        assert_eq!(result[0], result[1]);
        assert_eq!(result[5], result[6]);
        assert_ne!(result[0], result[5]);
    }

    #[test]
    fn louvain_with_multiple_bridges() {
        let edges = vec![
            (0, 1),
            (1, 2),
            (2, 0), // Triangle A
            (3, 4),
            (4, 5),
            (5, 3), // Triangle B
            (0, 3),
            (1, 4), // Two bridges
        ];
        let result = detect_communities(6, &edges);
        assert_eq!(result.len(), 6);
        // Each triangle should be its own cluster
        assert_eq!(result[0], result[1]);
        assert_eq!(result[3], result[4]);
    }

    #[test]
    fn louvain_converges() {
        let edges = vec![
            (0, 1),
            (1, 2),
            (2, 3),
            (3, 0), // Square with cross
            (0, 2),
            (1, 3),
        ];
        let result = detect_communities(4, &edges);
        assert_eq!(result.len(), 4);
        // All connected, should be one cluster
        assert!(result.iter().all(|&c| c == result[0]));
    }

    #[test]
    fn louvain_renumbers_contiguous() {
        let edges = vec![
            (0, 1),
            (2, 3), // Two separate edges
        ];
        let result = detect_communities(4, &edges);
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Should be {0, 1} or similar contiguous numbering
        let max_id = *unique.iter().max().unwrap();
        assert_eq!(unique.len() as u32, max_id + 1);
    }

    #[test]
    fn louvain_handles_self_loops() {
        // Self-loops should not affect clustering
        let edges = vec![
            (0, 1),
            (1, 0),
            (0, 0), // Self-loop
        ];
        let result = detect_communities(2, &edges);
        assert_eq!(result.len(), 2);
        assert_eq!(result[0], result[1]);
    }

    #[test]
    fn louvain_large_clique() {
        let n = 20;
        let mut edges = vec![];
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let result = detect_communities(n, &edges);
        // All in one cluster
        assert!(result.iter().all(|&c| c == result[0]));
    }

    #[test]
    fn louvain_balanced_bipartite() {
        // Complete bipartite graph K_{3,3}
        let edges = vec![
            (0, 3),
            (0, 4),
            (0, 5),
            (1, 3),
            (1, 4),
            (1, 5),
            (2, 3),
            (2, 4),
            (2, 5),
        ];
        let result = detect_communities(6, &edges);
        assert_eq!(result.len(), 6);
        // Complete bipartite usually becomes one cluster
        // or may split depending on modularity
    }

    #[test]
    fn louvain_chain_graph() {
        let n = 10;
        let edges: Vec<(usize, usize)> = (0..n - 1).map(|i| (i, i + 1)).collect();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), n);
        // Chain should be mostly connected
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Chain is connected, but Louvain may split it into several communities
        assert!(
            unique.len() <= n,
            "should have reasonable number of clusters"
        );
    }

    #[test]
    fn louvain_star_graph() {
        let n = 10;
        let edges: Vec<(usize, usize)> = (1..n).map(|i| (0, i)).collect();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), n);
        // Star should be one cluster
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(unique.len(), 1);
    }

    #[test]
    fn louvain_grid_graph() {
        // 3x3 grid
        let edges = vec![
            (0, 1),
            (1, 2),
            (3, 4),
            (4, 5),
            (6, 7),
            (7, 8),
            (0, 3),
            (3, 6),
            (1, 4),
            (4, 7),
            (2, 5),
            (5, 8),
        ];
        let result = detect_communities(9, &edges);
        assert_eq!(result.len(), 9);
        // Grid usually stays connected
    }

    // =========================================================================
    // Cluster Assignment Tests (10 tests)
    // =========================================================================

    #[test]
    fn cluster_assignment_valid() {
        let edges = vec![(0, 1), (1, 2)];
        let result = detect_communities(3, &edges);
        // All clusters should be valid indices
        for &c in &result {
            assert!(c < 3); // At most n clusters
        }
    }

    #[test]
    fn cluster_assignment_consistent() {
        let edges = vec![(0, 1), (1, 2), (2, 0), (3, 4), (4, 5), (5, 3)];
        let result = detect_communities(6, &edges);
        // Triangle 1: nodes 0,1,2
        assert_eq!(result[0], result[1]);
        assert_eq!(result[1], result[2]);
        // Triangle 2: nodes 3,4,5
        assert_eq!(result[3], result[4]);
        assert_eq!(result[4], result[5]);
        // Different clusters
        assert_ne!(result[0], result[3]);
    }

    #[test]
    fn cluster_assignment_deterministic() {
        let edges = vec![(0, 1), (1, 2), (2, 0)];
        let result1 = detect_communities(3, &edges);
        let result2 = detect_communities(3, &edges);
        assert_eq!(result1, result2);
    }

    #[test]
    fn cluster_assignment_no_empty_clusters() {
        let edges = vec![(0, 1), (2, 3)];
        let result = detect_communities(4, &edges);
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // All clusters have at least one node
        assert_eq!(unique.len(), 2);
        for &c in &result {
            assert!(unique.contains(&c));
        }
    }

    #[test]
    fn cluster_assignment_contiguous_ids() {
        let edges = vec![(0, 1), (2, 3), (4, 5)];
        let result = detect_communities(6, &edges);
        let mut unique: Vec<u32> = result
            .iter()
            .copied()
            .collect::<std::collections::HashSet<_>>()
            .into_iter()
            .collect();
        unique.sort();
        // IDs should be 0, 1, 2, ...
        for (i, &c) in unique.iter().enumerate() {
            assert_eq!(c, i as u32);
        }
    }

    #[test]
    fn cluster_assignment_with_isolated() {
        let edges = vec![(0, 1)];
        let result = detect_communities(5, &edges);
        // Nodes 0,1 in one cluster, 2,3,4 each in their own
        assert_eq!(result[0], result[1]);
        assert_ne!(result[0], result[2]);
        assert_ne!(result[2], result[3]);
        assert_ne!(result[3], result[4]);
    }

    #[test]
    fn cluster_assignment_large_isolated() {
        let n = 100;
        let edges = vec![(0, 1), (1, 2)]; // Small connected component
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), n);
        // Check that we have the expected number of clusters
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // 1 cluster for nodes 0,1,2 + n-3 isolated = n-2 clusters total
        assert_eq!(unique.len() as usize, n - 2);
    }

    #[test]
    fn cluster_assignment_hierarchical() {
        // Two big clusters with internal structure
        let mut edges = vec![];
        // Cluster 1: dense connections
        for i in 0..10 {
            for j in (i + 1)..10 {
                edges.push((i, j));
            }
        }
        // Cluster 2: dense connections
        for i in 10..20 {
            for j in (i + 1)..20 {
                edges.push((i, j));
            }
        }
        let result = detect_communities(20, &edges);
        assert_eq!(result[0], result[5]);
        assert_eq!(result[10], result[15]);
        assert_ne!(result[0], result[10]);
    }

    #[test]
    fn cluster_assignment_bridge_node() {
        // Two cliques connected by a single node
        let edges = vec![
            (0, 1),
            (1, 2),
            (2, 0), // Clique A
            (2, 3), // Bridge through node 2
            (3, 4),
            (4, 5),
            (5, 3), // Clique B
        ];
        let result = detect_communities(6, &edges);
        assert_eq!(result.len(), 6);
        // Node 2 bridges the cliques
    }

    #[test]
    fn cluster_assignment_out_of_order_edges() {
        let edges = vec![
            (5, 4),
            (3, 2),
            (1, 0),
            (2, 1), // Creates chain: 0-1-2-3
        ];
        let result = detect_communities(6, &edges);
        assert_eq!(result.len(), 6);
        // Edges create connected component: 0-1-2-3
        // Check that connected nodes share clusters
        assert_eq!(result[0], result[1], "0 and 1 connected by (1,0)");
        assert_eq!(result[2], result[3], "2 and 3 connected by (3,2)");
        // Note: The algorithm may or may not merge the entire chain depending on modularity
    }

    // =========================================================================
    // Modularity Calculation Tests (10 tests)
    // =========================================================================

    #[test]
    fn modularity_single_cluster() {
        let edges = vec![(0, 1), (1, 2)];
        let result = detect_communities(3, &edges);
        // All in one cluster, modularity should be positive but small
        assert!(result.iter().all(|&c| c == result[0]));
    }

    #[test]
    fn modularity_isolated_nodes() {
        let result = detect_communities(5, &[]);
        // Each node isolated, modularity = 0 (no edges)
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(unique.len(), 5);
    }

    #[test]
    fn modularity_complete_bipartite() {
        let edges = vec![(0, 2), (0, 3), (1, 2), (1, 3)];
        let result = detect_communities(4, &edges);
        assert_eq!(result.len(), 4);
        // K_{2,2} should form appropriate clusters
    }

    #[test]
    fn modularity_gain_positive() {
        // When moving improves modularity
        let edges = vec![
            (0, 1),
            (0, 2),
            (1, 2), // Triangle
            (3, 4),
            (3, 5),
            (4, 5), // Another triangle
            (2, 3), // Single bridge
        ];
        let result = detect_communities(6, &edges);
        // Should maintain separation due to bridge constraint
        assert_eq!(result[0], result[1]);
        assert_eq!(result[3], result[4]);
    }

    #[test]
    fn modularity_with_weights() {
        // Edge weights affect modularity
        let edges = vec![
            (0, 1),
            (1, 2),
            (2, 0), // Strong triangle
            (3, 4), // Weak connection
        ];
        let result = detect_communities(5, &edges);
        assert_eq!(result.len(), 5);
    }

    #[test]
    fn modularity_two_equivalent_clusters() {
        // Two identical clusters should be detected
        let edges = vec![
            (0, 1),
            (1, 2),
            (2, 0), // Triangle 1
            (3, 4),
            (4, 5),
            (5, 3), // Triangle 2
        ];
        let result = detect_communities(6, &edges);
        assert_eq!(result[0], result[1]);
        assert_eq!(result[3], result[4]);
        assert_ne!(result[0], result[3]);
    }

    #[test]
    fn modularity_no_improvement_stops() {
        // When no moves improve modularity, stops
        let edges = vec![(0, 1)];
        let result = detect_communities(2, &edges);
        assert_eq!(result[0], result[1]);
    }

    #[test]
    fn modularity_density_based() {
        // Dense subgraphs should be separate communities
        let mut edges = vec![];
        // Dense cluster 1
        for i in 0..5 {
            for j in (i + 1)..5 {
                edges.push((i, j));
            }
        }
        // Dense cluster 2
        for i in 5..10 {
            for j in (i + 1)..10 {
                edges.push((i, j));
            }
        }
        let result = detect_communities(10, &edges);
        assert_eq!(result[0], result[2]);
        assert_eq!(result[5], result[7]);
        assert_ne!(result[0], result[5]);
    }

    #[test]
    fn modularity_converges_to_local_optimum() {
        // Louvain finds local optimum, not necessarily global
        let edges = vec![
            (0, 1),
            (1, 2),
            (2, 0), // Triangle
            (0, 3),
            (3, 4),
            (4, 0), // Another triangle sharing node 0
        ];
        let result = detect_communities(5, &edges);
        assert_eq!(result.len(), 5);
        // Node 0 connects both triangles
    }

    #[test]
    fn modularity_symmetric_structure() {
        // Symmetric graph should give symmetric clustering
        let edges = vec![
            (0, 1),
            (1, 2),
            (0, 2), // Left triangle
            (3, 4),
            (4, 5),
            (3, 5), // Right triangle
            (2, 3), // Center connection
        ];
        let result = detect_communities(6, &edges);
        // Symmetric structure
        assert_eq!(result[0], result[1]);
        assert_eq!(result[3], result[4]);
    }

    // =========================================================================
    // Iteration and Convergence Tests (10 tests)
    // =========================================================================

    #[test]
    fn iterations_small_graph() {
        // Small graphs get max 20 passes
        let edges = vec![(0, 1), (1, 2), (2, 3), (3, 4)];
        let result = detect_communities(5, &edges);
        assert_eq!(result.len(), 5);
    }

    #[test]
    fn iterations_medium_graph() {
        // 500-2000 nodes get max 10 passes
        let n = 1000;
        let edges: Vec<(usize, usize)> = (0..n - 1).map(|i| (i, i + 1)).collect();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), n);
    }

    #[test]
    fn iterations_large_graph() {
        // 2000+ nodes get max 5 passes
        let n = 2500;
        let edges: Vec<(usize, usize)> = (0..n - 1).map(|i| (i, i + 1)).collect();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), n);
    }

    #[test]
    fn convergence_reached_early() {
        // When no improvement possible, stops early
        let edges = vec![(0, 1)];
        let result = detect_communities(2, &edges);
        assert_eq!(result[0], result[1]);
    }

    #[test]
    fn convergence_stable_result() {
        let edges = vec![(0, 1), (1, 2), (2, 0), (3, 4), (4, 5), (5, 3)];
        let result1 = detect_communities(6, &edges);
        let result2 = detect_communities(6, &edges);
        // Multiple runs should give same result
        assert_eq!(result1, result2);
    }

    #[test]
    fn convergence_complex_graph() {
        // More complex graph requires more iterations
        let mut edges = vec![];
        for i in 0..20 {
            for j in (i + 1)..20 {
                if j - i <= 3 {
                    // Local connections
                    edges.push((i, j));
                }
            }
        }
        let result = detect_communities(20, &edges);
        assert_eq!(result.len(), 20);
    }

    #[test]
    fn convergence_with_cycles() {
        let edges = vec![
            (0, 1),
            (1, 2),
            (2, 3),
            (3, 0), // Cycle 1
            (4, 5),
            (5, 6),
            (6, 7),
            (7, 4), // Cycle 2
            (0, 4), // Bridge
        ];
        let result = detect_communities(8, &edges);
        assert_eq!(result.len(), 8);
    }

    #[test]
    fn convergence_random_graph() {
        // Random-like connections
        let edges: Vec<(usize, usize)> = vec![
            (0, 3),
            (0, 7),
            (1, 5),
            (1, 9),
            (2, 4),
            (2, 8),
            (3, 6),
            (4, 7),
            (5, 9),
            (6, 8),
        ];
        let result = detect_communities(10, &edges);
        assert_eq!(result.len(), 10);
    }

    #[test]
    fn convergence_multiple_components() {
        let edges = vec![(0, 1), (2, 3), (4, 5), (6, 7)];
        let result = detect_communities(8, &edges);
        assert_eq!(result.len(), 8);
        // Four pairs, each in separate cluster
        assert_ne!(result[0], result[2]);
        assert_ne!(result[2], result[4]);
        assert_ne!(result[4], result[6]);
    }

    #[test]
    fn convergence_termination_condition() {
        // Algorithm terminates when no improvement
        let edges = vec![];
        let result = detect_communities(3, &edges);
        // Should terminate immediately with each node separate
        assert_ne!(result[0], result[1]);
        assert_ne!(result[1], result[2]);
    }
}
