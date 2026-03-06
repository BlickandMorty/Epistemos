//! Multi-scale cluster cache for zoom-level-dependent edge aggregation.
//!
//! Caches Louvain cluster assignments at two granularity levels:
//! - Level 1 (neighborhood): standard Louvain output
//! - Level 2 (macro): Louvain on the meta-graph of Level 1 clusters
//!
//! Invalidation is based on the visible node ordering plus the simulation edge list.

use crate::cluster::detect_communities;
use rustc_hash::FxHashMap;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

/// Zoom tiers for cluster-based edge aggregation.
/// Detail (>= 0.5): no clustering, per-edge rendering.
/// Neighborhood (0.15–0.5): Level 1 standard Louvain.
/// Macro (< 0.15): Level 2 meta-graph Louvain.
const ZOOM_DETAIL: f32 = 0.5;
const ZOOM_MACRO: f32 = 0.15;

struct ClusterLevel {
    assignments: Vec<u32>,
    cluster_count: u32,
}

pub struct ClusterCache {
    level1: Option<ClusterLevel>,
    level2: Option<ClusterLevel>,
    /// Topology fingerprint for invalidation.
    topo_fingerprint: u64,
}

impl ClusterCache {
    pub fn new() -> Self {
        Self {
            level1: None,
            level2: None,
            topo_fingerprint: 0,
        }
    }

    pub fn topology_fingerprint(graph_indices: &[usize], edges: &[(usize, usize)]) -> u64 {
        let mut hasher = DefaultHasher::new();
        graph_indices.hash(&mut hasher);
        edges.hash(&mut hasher);
        hasher.finish()
    }

    /// Check if cache is valid for the given topology fingerprint.
    pub fn is_valid(&self, topology_fingerprint: u64) -> bool {
        self.level1.is_some() && self.topo_fingerprint == topology_fingerprint
    }

    pub fn level1_assignments(&self) -> Option<&[u32]> {
        self.level1
            .as_ref()
            .map(|level| level.assignments.as_slice())
    }

    /// Cheap O(n) fallback for large graphs: cluster by coarse position buckets.
    pub fn coarse_assignments(x: &[f32], y: &[f32]) -> Vec<u32> {
        if x.len() != y.len() || x.is_empty() {
            return Vec::new();
        }

        let mut min_x = f32::INFINITY;
        let mut max_x = f32::NEG_INFINITY;
        let mut min_y = f32::INFINITY;
        let mut max_y = f32::NEG_INFINITY;
        for (&px, &py) in x.iter().zip(y) {
            min_x = min_x.min(px);
            max_x = max_x.max(px);
            min_y = min_y.min(py);
            max_y = max_y.max(py);
        }

        let span_x = (max_x - min_x).max(1.0);
        let span_y = (max_y - min_y).max(1.0);
        let target_clusters = ((x.len() as f32).sqrt() / 2.0).round().clamp(4.0, 96.0) as usize;
        let grid_side = (target_clusters as f32).sqrt().ceil() as usize;
        let cell_w = span_x / grid_side as f32;
        let cell_h = span_y / grid_side as f32;

        let mut cell_to_cluster = FxHashMap::default();
        let mut next_cluster_id = 0u32;
        let mut assignments = Vec::with_capacity(x.len());
        for (&px, &py) in x.iter().zip(y) {
            let gx =
                (((px - min_x) / cell_w).floor() as usize).min(grid_side.saturating_sub(1)) as u32;
            let gy =
                (((py - min_y) / cell_h).floor() as usize).min(grid_side.saturating_sub(1)) as u32;
            let cell = (gx, gy);
            let cluster_id = *cell_to_cluster.entry(cell).or_insert_with(|| {
                let id = next_cluster_id;
                next_cluster_id += 1;
                id
            });
            assignments.push(cluster_id);
        }
        assignments
    }

    /// Build both cache levels from simulation data.
    /// `cluster_ids_l1`: Level 1 assignments from Louvain (indexed by sim index).
    /// `edges`: simulation edge list (sim index pairs).
    pub fn build(
        &mut self,
        cluster_ids_l1: Vec<u32>,
        edges: &[(usize, usize)],
        graph_indices: &[usize],
    ) {
        let n_clusters = cluster_ids_l1.iter().max().map(|&m| m + 1).unwrap_or(0) as usize;

        // Store Level 1
        self.level1 = Some(ClusterLevel {
            assignments: cluster_ids_l1.clone(),
            cluster_count: n_clusters as u32,
        });

        // Build Level 2: meta-graph where each L1 cluster is a node.
        // Inter-cluster edges become meta-edges.
        if n_clusters > 1 {
            let mut meta_edges_map: FxHashMap<(usize, usize), u32> = FxHashMap::default();
            for &(u, v) in edges {
                if u < cluster_ids_l1.len() && v < cluster_ids_l1.len() {
                    let ca = cluster_ids_l1[u] as usize;
                    let cb = cluster_ids_l1[v] as usize;
                    if ca != cb {
                        let key = if ca < cb { (ca, cb) } else { (cb, ca) };
                        *meta_edges_map.entry(key).or_insert(0) += 1;
                    }
                }
            }

            let meta_edges: Vec<(usize, usize)> = meta_edges_map.keys().copied().collect();
            let meta_clusters = detect_communities(n_clusters, &meta_edges);

            // Map Level 2 meta-cluster IDs back to original node indices.
            // node i → L1 cluster → meta-cluster
            let l2_assignments: Vec<u32> = cluster_ids_l1
                .iter()
                .map(|&c1| {
                    let c1_idx = c1 as usize;
                    if c1_idx < meta_clusters.len() {
                        meta_clusters[c1_idx]
                    } else {
                        u32::MAX
                    }
                })
                .collect();

            let l2_count = l2_assignments.iter().max().map(|&m| m + 1).unwrap_or(0);

            self.level2 = Some(ClusterLevel {
                assignments: l2_assignments,
                cluster_count: l2_count,
            });
        } else {
            self.level2 = None;
        }

        self.topo_fingerprint = Self::topology_fingerprint(graph_indices, edges);
    }

    /// Get cluster assignments for the given zoom level.
    /// Returns None for detail zoom (no clustering needed).
    pub fn assignments_for_zoom(&self, zoom: f32) -> Option<&[u32]> {
        if zoom >= ZOOM_DETAIL {
            return None; // Detail mode: no clustering
        }
        if zoom >= ZOOM_MACRO {
            // Neighborhood mode: Level 1
            self.level1.as_ref().map(|l| l.assignments.as_slice())
        } else {
            // Macro mode: Level 2 (fall back to Level 1 if no Level 2)
            self.level2
                .as_ref()
                .or(self.level1.as_ref())
                .map(|l| l.assignments.as_slice())
        }
    }

    /// Get the cluster count for the current zoom level.
    pub fn cluster_count_for_zoom(&self, zoom: f32) -> u32 {
        if zoom >= ZOOM_DETAIL {
            return 0;
        }
        if zoom >= ZOOM_MACRO {
            self.level1.as_ref().map(|l| l.cluster_count).unwrap_or(0)
        } else {
            self.level2
                .as_ref()
                .or(self.level1.as_ref())
                .map(|l| l.cluster_count)
                .unwrap_or(0)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cache_invalidation() {
        let mut cache = ClusterCache::new();
        let fingerprint =
            ClusterCache::topology_fingerprint(&[0, 1, 2, 3], &[(0, 1), (2, 3), (0, 2)]);
        assert!(!cache.is_valid(fingerprint));

        cache.build(vec![0, 0, 1, 1], &[(0, 1), (2, 3), (0, 2)], &[0, 1, 2, 3]);
        assert!(cache.is_valid(fingerprint));

        let same_counts_new_edges =
            ClusterCache::topology_fingerprint(&[0, 1, 2, 3], &[(0, 3), (1, 2), (0, 2)]);
        assert_ne!(fingerprint, same_counts_new_edges);
        assert!(!cache.is_valid(same_counts_new_edges));

        let same_counts_new_visible_set =
            ClusterCache::topology_fingerprint(&[4, 5, 6, 7], &[(0, 1), (2, 3), (0, 2)]);
        assert_ne!(fingerprint, same_counts_new_visible_set);
        assert!(!cache.is_valid(same_counts_new_visible_set));
    }

    #[test]
    fn test_zoom_level_selection() {
        let mut cache = ClusterCache::new();
        cache.build(vec![0, 0, 1, 1], &[(0, 1), (2, 3), (0, 2)], &[0, 1, 2, 3]);

        // Detail zoom: no assignments
        assert!(cache.assignments_for_zoom(0.6).is_none());
        assert!(cache.assignments_for_zoom(1.0).is_none());

        // Neighborhood zoom: Level 1
        let l1 = cache.assignments_for_zoom(0.3);
        assert!(l1.is_some());
        assert_eq!(l1.unwrap().len(), 4);

        // Macro zoom: Level 2 (or fallback to Level 1)
        let l2 = cache.assignments_for_zoom(0.1);
        assert!(l2.is_some());
        assert_eq!(l2.unwrap().len(), 4);
    }

    #[test]
    fn test_level2_meta_clustering() {
        let mut cache = ClusterCache::new();
        // 4 L1 clusters: 0, 1, 2, 3
        // Edges: 0↔1 (many), 2↔3 (many), 0↔2 (few)
        // Expected L2: clusters {0,1} and {2,3} collapse further
        let assignments_l1 = vec![0, 0, 1, 1, 2, 2, 3, 3];
        let edges = vec![
            (0, 1),
            (0, 2),
            (0, 3),
            (1, 2),
            (1, 3), // L1 cluster 0↔1
            (4, 5),
            (4, 6),
            (4, 7),
            (5, 6),
            (5, 7), // L1 cluster 2↔3
            (2, 4), // L1 cluster 1↔2 (single bridge)
        ];

        cache.build(assignments_l1, &edges, &[0, 1, 2, 3, 4, 5, 6, 7]);

        assert!(cache.level1.is_some());
        assert!(cache.level2.is_some());

        let l2 = cache.level2.as_ref().unwrap();
        // L2 should have fewer clusters than L1
        assert!(l2.cluster_count <= 4);
        assert_eq!(l2.assignments.len(), 8);
    }

    #[test]
    fn test_single_cluster() {
        let mut cache = ClusterCache::new();
        cache.build(vec![0, 0, 0], &[(0, 1), (1, 2)], &[0, 1, 2]);

        assert!(cache.level1.is_some());
        // Single cluster → no meta-graph → no Level 2
        assert!(cache.level2.is_none());

        // Macro zoom falls back to Level 1
        let l = cache.assignments_for_zoom(0.1);
        assert!(l.is_some());
        assert_eq!(l.unwrap(), &[0, 0, 0]);
    }

    #[test]
    fn test_empty_graph() {
        let mut cache = ClusterCache::new();
        cache.build(vec![], &[], &[]);

        assert!(cache.is_valid(ClusterCache::topology_fingerprint(&[], &[])));
        assert!(cache.assignments_for_zoom(0.3).is_some());
        assert!(cache.assignments_for_zoom(0.3).unwrap().is_empty());
    }

    #[test]
    fn test_cluster_count() {
        let mut cache = ClusterCache::new();
        cache.build(vec![0, 0, 1, 1, 2], &[(0, 2), (2, 4)], &[0, 1, 2, 3, 4]);

        assert_eq!(cache.cluster_count_for_zoom(1.0), 0); // Detail
        assert_eq!(cache.cluster_count_for_zoom(0.3), 3); // Neighborhood: 3 L1 clusters
    }

    #[test]
    fn test_coarse_assignments_groups_spatial_regions() {
        let assignments = ClusterCache::coarse_assignments(
            &[0.0, 10.0, 1000.0, 1010.0],
            &[0.0, 10.0, 1000.0, 1010.0],
        );
        assert_eq!(assignments.len(), 4);
        assert_eq!(assignments[0], assignments[1]);
        assert_eq!(assignments[2], assignments[3]);
        assert_ne!(assignments[0], assignments[2]);
    }
}
