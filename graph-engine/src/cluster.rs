//! Louvain community detection for cluster physics.
//! Detects densely connected subgraphs and assigns cluster IDs.

/// Detect communities using Louvain modularity optimization.
/// Returns a Vec<u32> where result[i] = cluster_id for node i.
/// Only operates on the provided edge list (simulation indices).
///
/// Uses the standard modularity gain formula: a node moves to a neighboring
/// community only when the gain ΔQ > 0. This prevents single bridge edges
/// from merging distinct dense subgraphs.
pub fn detect_communities(
    n: usize,
    edges: &[(usize, usize)],
) -> Vec<u32> {
    if n == 0 { return Vec::new(); }
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

    for _ in 0..20 {
        let mut improved = false;

        for i in 0..n {
            let ki = degree[i];
            let current = community[i];

            // Edges from i to each neighboring community
            let mut ki_to: std::collections::HashMap<u32, f64> = std::collections::HashMap::new();
            for &j in &adj[i] {
                *ki_to.entry(community[j]).or_default() += 1.0;
            }

            // Σ_tot: sum of degrees per community
            let mut sigma: std::collections::HashMap<u32, f64> = std::collections::HashMap::new();
            for j in 0..n {
                *sigma.entry(community[j]).or_default() += degree[j];
            }

            let ki_in_current = ki_to.get(&current).copied().unwrap_or(0.0);
            let sigma_current = sigma.get(&current).copied().unwrap_or(0.0);

            let mut best_comm = current;
            let mut best_gain = 0.0f64;

            for (&comm, &ki_in_c) in &ki_to {
                if comm == current { continue; }
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
                community[i] = best_comm;
                improved = true;
            }
        }

        if !improved { break; }
    }

    // Renumber communities to be contiguous (0, 1, 2, ...).
    let mut renumber: std::collections::HashMap<u32, u32> = std::collections::HashMap::new();
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
            (0, 1), (1, 2), (0, 2),  // clique A
            (3, 4), (4, 5), (3, 5),  // clique B
            (2, 3),                    // bridge
        ];
        let result = detect_communities(6, &edges);
        assert_eq!(result.len(), 6);
        assert_eq!(result[0], result[1]);
        assert_eq!(result[1], result[2]);
        assert_eq!(result[3], result[4]);
        assert_eq!(result[4], result[5]);
        assert_ne!(result[0], result[3], "two cliques should be different clusters");
    }

    #[test]
    fn single_component_one_cluster() {
        let edges = vec![(0,1),(0,2),(0,3),(1,2),(1,3),(2,3)];
        let result = detect_communities(4, &edges);
        assert!(result.iter().all(|&c| c == result[0]));
    }

    #[test]
    fn ring_graph() {
        let edges = vec![(0,1),(1,2),(2,3),(3,4),(4,5),(5,0)];
        let result = detect_communities(6, &edges);
        assert_eq!(result.len(), 6);
        let max_cluster = *result.iter().max().unwrap();
        assert!(max_cluster <= 5);
    }
}
