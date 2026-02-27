//! Louvain community detection for cluster physics.
//! Detects densely connected subgraphs and assigns cluster IDs.

/// Detect communities using a simplified Louvain method.
/// Returns a Vec<u32> where result[i] = cluster_id for node i.
/// Only operates on the provided edge list (simulation indices).
pub fn detect_communities(
    n: usize,
    edges: &[(usize, usize)],
) -> Vec<u32> {
    if n == 0 { return Vec::new(); }
    if edges.is_empty() {
        return (0..n as u32).collect();
    }

    let mut community: Vec<u32> = (0..n as u32).collect();

    let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
    for &(u, v) in edges {
        if u < n && v < n {
            adj[u].push(v);
            adj[v].push(u);
        }
    }

    let mut improved = true;
    let mut iterations = 0;
    while improved && iterations < 10 {
        improved = false;
        iterations += 1;

        for i in 0..n {
            let current_comm = community[i];

            let mut comm_edges: std::collections::HashMap<u32, usize> = std::collections::HashMap::new();
            for &j in &adj[i] {
                *comm_edges.entry(community[j]).or_default() += 1;
            }

            let mut best_comm = current_comm;
            let mut best_count = comm_edges.get(&current_comm).copied().unwrap_or(0);

            for (&comm, &count) in &comm_edges {
                if count > best_count {
                    best_comm = comm;
                    best_count = count;
                }
            }

            if best_comm != current_comm {
                community[i] = best_comm;
                improved = true;
            }
        }
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
