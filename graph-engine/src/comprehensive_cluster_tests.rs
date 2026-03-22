//! Automatically generated comprehensive clustering tests.
#[cfg(test)]
mod tests {
    #![allow(clippy::manual_div_ceil)]

    use crate::cluster::detect_communities;

    #[test]
    fn test_cluster_0_n10_empty_ordered_unique() {
        let n = 10;
        let edges = Vec::new();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            10,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_1_n10_empty_ordered_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            10,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_2_n10_empty_reversed_unique() {
        let n = 10;
        let mut edges = Vec::new();
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            10,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_3_n10_empty_reversed_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            10,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_4_n10_complete_ordered_unique() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_5_n10_complete_ordered_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_6_n10_complete_reversed_unique() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_7_n10_complete_reversed_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_8_n10_chain_ordered_unique() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_9_n10_chain_ordered_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_10_n10_chain_reversed_unique() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_11_n10_chain_reversed_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_12_n10_star_ordered_unique() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_13_n10_star_ordered_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_14_n10_star_reversed_unique() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_15_n10_star_reversed_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_16_n10_ring_ordered_unique() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_17_n10_ring_ordered_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_18_n10_ring_reversed_unique() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_19_n10_ring_reversed_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_20_n10_two_cliques_ordered_unique() {
        let n = 10;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_21_n10_two_cliques_ordered_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_22_n10_two_cliques_reversed_unique() {
        let n = 10;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_23_n10_two_cliques_reversed_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_24_n10_bipartite_ordered_unique() {
        let n = 10;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_25_n10_bipartite_ordered_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_26_n10_bipartite_reversed_unique() {
        let n = 10;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_27_n10_bipartite_reversed_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_28_n10_disconnected_pairs_ordered_unique() {
        let n = 10;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (10 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_29_n10_disconnected_pairs_ordered_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (10 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_30_n10_disconnected_pairs_reversed_unique() {
        let n = 10;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (10 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_31_n10_disconnected_pairs_reversed_with_duplicates() {
        let n = 10;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 10, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 10, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (10 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_32_n50_empty_ordered_unique() {
        let n = 50;
        let edges = Vec::new();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            50,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_33_n50_empty_ordered_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            50,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_34_n50_empty_reversed_unique() {
        let n = 50;
        let mut edges = Vec::new();
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            50,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_35_n50_empty_reversed_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            50,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_36_n50_complete_ordered_unique() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_37_n50_complete_ordered_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_38_n50_complete_reversed_unique() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_39_n50_complete_reversed_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_40_n50_chain_ordered_unique() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_41_n50_chain_ordered_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_42_n50_chain_reversed_unique() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_43_n50_chain_reversed_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_44_n50_star_ordered_unique() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_45_n50_star_ordered_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_46_n50_star_reversed_unique() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_47_n50_star_reversed_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_48_n50_ring_ordered_unique() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_49_n50_ring_ordered_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_50_n50_ring_reversed_unique() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_51_n50_ring_reversed_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_52_n50_two_cliques_ordered_unique() {
        let n = 50;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.
        assert!(
            unique.len() >= 2,
            "Two distinct cliques with 1 bridge should not completely merge"
        );
    }

    #[test]
    fn test_cluster_53_n50_two_cliques_ordered_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.
        assert!(
            unique.len() >= 2,
            "Two distinct cliques with 1 bridge should not completely merge"
        );
    }

    #[test]
    fn test_cluster_54_n50_two_cliques_reversed_unique() {
        let n = 50;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.
        assert!(
            unique.len() >= 2,
            "Two distinct cliques with 1 bridge should not completely merge"
        );
    }

    #[test]
    fn test_cluster_55_n50_two_cliques_reversed_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.
        assert!(
            unique.len() >= 2,
            "Two distinct cliques with 1 bridge should not completely merge"
        );
    }

    #[test]
    fn test_cluster_56_n50_bipartite_ordered_unique() {
        let n = 50;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_57_n50_bipartite_ordered_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_58_n50_bipartite_reversed_unique() {
        let n = 50;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_59_n50_bipartite_reversed_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_60_n50_disconnected_pairs_ordered_unique() {
        let n = 50;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (50 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_61_n50_disconnected_pairs_ordered_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (50 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_62_n50_disconnected_pairs_reversed_unique() {
        let n = 50;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (50 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_63_n50_disconnected_pairs_reversed_with_duplicates() {
        let n = 50;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 50, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 50, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (50 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_64_n200_empty_ordered_unique() {
        let n = 200;
        let edges = Vec::new();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            200,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_65_n200_empty_ordered_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            200,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_66_n200_empty_reversed_unique() {
        let n = 200;
        let mut edges = Vec::new();
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            200,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_67_n200_empty_reversed_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            200,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_68_n200_complete_ordered_unique() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_69_n200_complete_ordered_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_70_n200_complete_reversed_unique() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_71_n200_complete_reversed_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_72_n200_chain_ordered_unique() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_73_n200_chain_ordered_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_74_n200_chain_reversed_unique() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_75_n200_chain_reversed_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_76_n200_star_ordered_unique() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_77_n200_star_ordered_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_78_n200_star_reversed_unique() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_79_n200_star_reversed_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_80_n200_ring_ordered_unique() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_81_n200_ring_ordered_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_82_n200_ring_reversed_unique() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_83_n200_ring_reversed_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_84_n200_two_cliques_ordered_unique() {
        let n = 200;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.
        assert!(
            unique.len() >= 2,
            "Two distinct cliques with 1 bridge should not completely merge"
        );
    }

    #[test]
    fn test_cluster_85_n200_two_cliques_ordered_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.
        assert!(
            unique.len() >= 2,
            "Two distinct cliques with 1 bridge should not completely merge"
        );
    }

    #[test]
    fn test_cluster_86_n200_two_cliques_reversed_unique() {
        let n = 200;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.
        assert!(
            unique.len() >= 2,
            "Two distinct cliques with 1 bridge should not completely merge"
        );
    }

    #[test]
    fn test_cluster_87_n200_two_cliques_reversed_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.
        assert!(
            unique.len() >= 2,
            "Two distinct cliques with 1 bridge should not completely merge"
        );
    }

    #[test]
    fn test_cluster_88_n200_bipartite_ordered_unique() {
        let n = 200;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_89_n200_bipartite_ordered_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_90_n200_bipartite_reversed_unique() {
        let n = 200;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_91_n200_bipartite_reversed_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_92_n200_disconnected_pairs_ordered_unique() {
        let n = 200;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (200 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_93_n200_disconnected_pairs_ordered_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (200 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_94_n200_disconnected_pairs_reversed_unique() {
        let n = 200;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (200 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_95_n200_disconnected_pairs_reversed_with_duplicates() {
        let n = 200;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 200, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 200, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (200 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_96_n1000_empty_ordered_unique() {
        let n = 1000;
        let edges = Vec::new();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            1000,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_97_n1000_empty_ordered_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            1000,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_98_n1000_empty_reversed_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            1000,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_99_n1000_empty_reversed_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        assert_eq!(
            unique.len(),
            1000,
            "Empty graph should have N distinct clusters"
        );
    }

    #[test]
    fn test_cluster_100_n1000_complete_ordered_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_101_n1000_complete_ordered_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_102_n1000_complete_reversed_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_103_n1000_complete_reversed_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 0..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_104_n1000_chain_ordered_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_105_n1000_chain_ordered_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_106_n1000_chain_reversed_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_107_n1000_chain_reversed_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 0..n - 1 {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_108_n1000_star_ordered_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_109_n1000_star_ordered_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_110_n1000_star_reversed_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_111_n1000_star_reversed_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 1..n {
            edges.push((0, i));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_112_n1000_ring_ordered_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_113_n1000_ring_ordered_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_114_n1000_ring_reversed_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_115_n1000_ring_reversed_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in 0..n {
            edges.push((i, (i + 1) % n));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_116_n1000_two_cliques_ordered_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.
        assert!(
            unique.len() >= 2,
            "Two distinct cliques with 1 bridge should not completely merge"
        );
    }

    #[test]
    fn test_cluster_117_n1000_two_cliques_ordered_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.
        assert!(
            unique.len() >= 2,
            "Two distinct cliques with 1 bridge should not completely merge"
        );
    }

    #[test]
    fn test_cluster_118_n1000_two_cliques_reversed_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.
        assert!(
            unique.len() >= 2,
            "Two distinct cliques with 1 bridge should not completely merge"
        );
    }

    #[test]
    fn test_cluster_119_n1000_two_cliques_reversed_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in (i + 1)..half {
                edges.push((i, j));
            }
        }
        for i in half..n {
            for j in (i + 1)..n {
                edges.push((i, j));
            }
        }
        edges.push((0, half)); // bridge
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        // Even if modularity joins some things, we shouldn't get N clusters or 1 cluster.
        assert!(
            unique.len() >= 2,
            "Two distinct cliques with 1 bridge should not completely merge"
        );
    }

    #[test]
    fn test_cluster_120_n1000_bipartite_ordered_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_121_n1000_bipartite_ordered_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_122_n1000_bipartite_reversed_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_123_n1000_bipartite_reversed_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        let half = n / 2;
        for i in 0..half {
            for j in half..n {
                edges.push((i, j));
            }
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
    }

    #[test]
    fn test_cluster_124_n1000_disconnected_pairs_ordered_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (1000 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_125_n1000_disconnected_pairs_ordered_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (1000 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_126_n1000_disconnected_pairs_reversed_unique() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (1000 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }

    #[test]
    fn test_cluster_127_n1000_disconnected_pairs_reversed_with_duplicates() {
        let n = 1000;
        let mut edges = Vec::new();
        for i in (0..(n - 1)).step_by(2) {
            edges.push((i, i + 1));
        }
        let mut extra = edges.clone();
        edges.append(&mut extra);
        edges.reverse();
        let result = detect_communities(n, &edges);
        assert_eq!(result.len(), 1000, "Output length should match node count");
        for &c in &result {
            assert!((c as usize) < 1000, "Cluster ID {} out of bounds", c);
        }
        let unique: std::collections::HashSet<u32> = result.iter().copied().collect();
        let expected_clusters = (1000 + 1) / 2;
        assert_eq!(
            unique.len(),
            expected_clusters,
            "Disconnected pairs should have N/2 clusters"
        );
    }
}
