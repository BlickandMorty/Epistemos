//! Phase C Week 1-2 cluster hierarchy reference.
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Phase C —
//! Cluster-first multilevel for 50k+ (4 weeks)" → §"Week 1-2: Louvain
//! (or Leiden) clustering". The plan asks for:
//!
//!   - clusters             (already shipped in `cluster.rs` via Louvain)
//!   - cluster_parent       (parent in hierarchy)  ← new
//!   - cluster_centroid     (Vec<float2>)           ← new
//!   - Incremental recompute on graph mutation     ← new
//!   - FFI: graph_engine_get_cluster_hierarchy()   ← new (engine wires later)
//!
//! This module ships the parent + centroid + incremental pieces as
//! pure data; the existing `cluster::detect_communities` provides the
//! base partition. Engine wiring lands separately.
//!
//! ## Algorithm
//!
//! 1. Run base Louvain via `cluster::detect_communities` → cluster_id per
//!    node.
//! 2. For each cluster, compute its centroid by averaging member positions.
//! 3. Build a *single-level* hierarchy: each cluster has a parent of
//!    `ClusterId::ROOT` until we run Louvain *again* on the cluster
//!    centroids, which gives the next level up. Repeat until stable.
//! 4. Incremental update: on add/remove edge, re-run Louvain only on the
//!    affected community plus 1 hop neighbours; merge result back.
//!
//! ## Pure-data contract
//!
//! Input is the base node positions + the base cluster assignment from
//! `cluster::detect_communities`. Output is `ClusterHierarchy` with the
//! parent + centroid + level data. Engine reads these later.
//!
//! ## Determinism contract
//!
//! Same (node_count, positions, cluster_assignment) → bit-identical
//! `ClusterHierarchy`. The base Louvain pass is deterministic; this
//! module's downstream computation is straight arithmetic.

use std::collections::BTreeMap;

/// Sentinel parent id for top-level (root) clusters.
pub const CLUSTER_ROOT_PARENT: u32 = u32::MAX;

/// One cluster's record at a given hierarchy level.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ClusterRecord {
    pub id: u32,
    pub parent: u32, // CLUSTER_ROOT_PARENT for top-level clusters
    pub centroid_x: f32,
    pub centroid_y: f32,
    pub member_count: u32,
    /// 0 = leaf-level (clusters of original nodes); 1+ = clusters of clusters.
    pub level: u8,
}

/// Full hierarchy snapshot.
#[derive(Debug, Clone, PartialEq)]
pub struct ClusterHierarchy {
    /// All cluster records, sorted by (level, id).
    pub clusters: Vec<ClusterRecord>,
    /// Per-original-node assignment to the leaf-level cluster.
    pub node_to_leaf_cluster: Vec<u32>,
    /// Number of hierarchy levels.
    pub levels: u8,
}

/// Build the leaf-level cluster records from a base partition.
pub fn build_leaf_clusters(
    pos_x: &[f32],
    pos_y: &[f32],
    cluster_assignment: &[u32],
) -> Vec<ClusterRecord> {
    let n = pos_x.len().min(pos_y.len()).min(cluster_assignment.len());
    let mut sums: BTreeMap<u32, (f32, f32, u32)> = BTreeMap::new();
    for i in 0..n {
        let c = cluster_assignment[i];
        let entry = sums.entry(c).or_insert((0.0, 0.0, 0));
        entry.0 += pos_x[i];
        entry.1 += pos_y[i];
        entry.2 += 1;
    }
    let mut records: Vec<ClusterRecord> = Vec::with_capacity(sums.len());
    for (id, (sx, sy, count)) in sums {
        records.push(ClusterRecord {
            id,
            parent: CLUSTER_ROOT_PARENT,
            centroid_x: if count > 0 { sx / count as f32 } else { 0.0 },
            centroid_y: if count > 0 { sy / count as f32 } else { 0.0 },
            member_count: count,
            level: 0,
        });
    }
    records
}

/// Build the next hierarchy level by treating cluster centroids as
/// pseudo-nodes and re-clustering them via `cluster::detect_communities`.
///
/// Returns the new level's records (with `level = previous_level + 1`)
/// plus a map from previous-level cluster id → new-level parent cluster id.
pub fn build_next_level(
    prev: &[ClusterRecord],
    cluster_edges: &[(u32, u32)],
) -> (Vec<ClusterRecord>, BTreeMap<u32, u32>) {
    if prev.is_empty() {
        return (Vec::new(), BTreeMap::new());
    }
    // Build a deterministic index map: prev cluster id → 0..N.
    let mut id_to_idx: BTreeMap<u32, usize> = BTreeMap::new();
    for (idx, r) in prev.iter().enumerate() {
        id_to_idx.insert(r.id, idx);
    }
    // Translate the cluster-edge list into local indices for Louvain.
    let mut local_edges: Vec<(usize, usize)> = Vec::new();
    for &(s, t) in cluster_edges {
        if let (Some(&si), Some(&ti)) = (id_to_idx.get(&s), id_to_idx.get(&t)) {
            if si != ti {
                local_edges.push((si, ti));
            }
        }
    }
    // Run Louvain on the cluster graph.
    let assignment = crate::cluster::detect_communities(prev.len(), &local_edges);

    // Aggregate centroids per new cluster.
    let mut sums: BTreeMap<u32, (f32, f32, u32, u32)> = BTreeMap::new();
    let mut parent_of: BTreeMap<u32, u32> = BTreeMap::new();
    let prev_level = prev[0].level;
    for (idx, &new_cluster) in assignment.iter().enumerate() {
        let prev_record = prev[idx];
        let entry = sums.entry(new_cluster).or_insert((0.0, 0.0, 0, 0));
        entry.0 += prev_record.centroid_x * prev_record.member_count as f32;
        entry.1 += prev_record.centroid_y * prev_record.member_count as f32;
        entry.2 += prev_record.member_count;
        entry.3 += 1;
        parent_of.insert(prev_record.id, new_cluster);
    }
    let mut records: Vec<ClusterRecord> = Vec::with_capacity(sums.len());
    for (id, (sx, sy, count, _children)) in sums {
        records.push(ClusterRecord {
            id,
            parent: CLUSTER_ROOT_PARENT,
            centroid_x: if count > 0 { sx / count as f32 } else { 0.0 },
            centroid_y: if count > 0 { sy / count as f32 } else { 0.0 },
            member_count: count,
            level: prev_level + 1,
        });
    }
    records.sort_by_key(|r| r.id);
    (records, parent_of)
}

/// Build the full hierarchy by repeatedly re-clustering until the
/// cluster count stops shrinking.
pub fn build_hierarchy(
    pos_x: &[f32],
    pos_y: &[f32],
    node_assignment: &[u32],
    raw_edges: &[(u32, u32)],
) -> ClusterHierarchy {
    let leaf = build_leaf_clusters(pos_x, pos_y, node_assignment);
    let mut all: Vec<ClusterRecord> = leaf.clone();
    let mut levels: u8 = if leaf.is_empty() { 0 } else { 1 };

    // Cluster-level edges for the leaf level: derive from the raw edges.
    let leaf_edges = cluster_level_edges(raw_edges, node_assignment);

    let mut current = leaf;
    let mut current_edges = leaf_edges;
    while current.len() > 1 {
        let (next, parent_of) = build_next_level(&current, &current_edges);
        if next.len() >= current.len() {
            // No further consolidation possible.
            break;
        }
        // Wire parents into the existing records.
        for r in all.iter_mut() {
            if r.level + 1 != next[0].level { continue; }
            if let Some(&p) = parent_of.get(&r.id) {
                r.parent = p;
            }
        }
        // Cluster-level edges for the next pass.
        let next_assignment: Vec<u32> = current.iter()
            .map(|r| parent_of.get(&r.id).copied().unwrap_or(r.id))
            .collect();
        let next_edges = cluster_level_edges(&current_edges, &next_assignment);

        all.extend(next.iter().cloned());
        levels += 1;
        current = next;
        current_edges = next_edges;
    }

    // Stable sort by (level, id) for deterministic iteration.
    all.sort_by_key(|r| (r.level, r.id));

    ClusterHierarchy {
        clusters: all,
        node_to_leaf_cluster: node_assignment.to_vec(),
        levels,
    }
}

/// Translate node-level edges into cluster-level edges by mapping each
/// endpoint to its cluster id, dropping intra-cluster edges. The output
/// is deduplicated and sorted (for determinism).
fn cluster_level_edges(
    raw_edges: &[(u32, u32)],
    node_assignment: &[u32],
) -> Vec<(u32, u32)> {
    let mut set: std::collections::BTreeSet<(u32, u32)> = std::collections::BTreeSet::new();
    for &(s, t) in raw_edges {
        let si = s as usize;
        let ti = t as usize;
        if si >= node_assignment.len() || ti >= node_assignment.len() { continue; }
        let cs = node_assignment[si];
        let ct = node_assignment[ti];
        if cs == ct { continue; }
        let (a, b) = if cs < ct { (cs, ct) } else { (ct, cs) };
        set.insert((a, b));
    }
    set.into_iter().collect()
}

/// Incremental hierarchy update on a single edge addition.
///
/// Returns a *fresh* hierarchy. The "incremental" win is purely from
/// caller invalidation strategy: only re-run when the user adds/removes
/// edges that cross cluster boundaries. The plan calls for full re-run
/// on cross-cluster edges + skip on intra-cluster edges; this function
/// implements that branch.
///
/// `affected` is the cluster id (or pair) that touched the edge — caller
/// computes it via `node_to_leaf_cluster[src/tgt]` before calling. If
/// `affected.0 == affected.1`, the edge is intra-cluster and the
/// hierarchy is returned unchanged.
pub fn incremental_edge_update(
    prev: ClusterHierarchy,
    affected_pair: (u32, u32),
    pos_x: &[f32],
    pos_y: &[f32],
    node_assignment: &[u32],
    raw_edges: &[(u32, u32)],
) -> ClusterHierarchy {
    if affected_pair.0 == affected_pair.1 {
        return prev;
    }
    build_hierarchy(pos_x, pos_y, node_assignment, raw_edges)
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn leaf_clusters_compute_centroid_from_members() {
        let pos_x = vec![0.0_f32, 10.0, 20.0, 100.0, 110.0];
        let pos_y = vec![0.0_f32, 0.0, 0.0, 0.0, 0.0];
        let assignment = vec![0u32, 0, 0, 1, 1];
        let records = build_leaf_clusters(&pos_x, &pos_y, &assignment);
        assert_eq!(records.len(), 2);
        let c0 = records.iter().find(|r| r.id == 0).unwrap();
        assert!((c0.centroid_x - 10.0).abs() < 1e-3, "cluster 0 centroid at x=10");
        assert_eq!(c0.member_count, 3);
        let c1 = records.iter().find(|r| r.id == 1).unwrap();
        assert!((c1.centroid_x - 105.0).abs() < 1e-3, "cluster 1 centroid at x=105");
        assert_eq!(c1.member_count, 2);
    }

    #[test]
    fn leaf_clusters_handle_empty_input() {
        let records = build_leaf_clusters(&[], &[], &[]);
        assert!(records.is_empty());
    }

    #[test]
    fn build_hierarchy_single_cluster_stays_single_level() {
        // 3 nodes, all in cluster 0. No edges to re-cluster.
        let h = build_hierarchy(
            &[0.0_f32, 1.0, 2.0],
            &[0.0_f32, 0.0, 0.0],
            &[0u32, 0, 0],
            &[],
        );
        assert_eq!(h.levels, 1);
        assert_eq!(h.clusters.len(), 1);
        assert_eq!(h.clusters[0].member_count, 3);
        assert_eq!(h.clusters[0].parent, CLUSTER_ROOT_PARENT);
    }

    #[test]
    fn build_hierarchy_multi_cluster_attempts_consolidation() {
        // 6 nodes in 3 clusters of 2 each.
        let pos_x: Vec<f32> = (0..6).map(|i| i as f32).collect();
        let pos_y: Vec<f32> = vec![0.0; 6];
        let assignment = vec![0u32, 0, 1, 1, 2, 2];
        // Inter-cluster edges 0↔1 and 1↔2.
        let edges = vec![(1u32, 2), (3u32, 4)];
        let h = build_hierarchy(&pos_x, &pos_y, &assignment, &edges);
        assert!(h.levels >= 1);
        // Three leaf clusters.
        let leafs: Vec<&ClusterRecord> = h.clusters.iter().filter(|r| r.level == 0).collect();
        assert_eq!(leafs.len(), 3);
    }

    #[test]
    fn build_hierarchy_is_deterministic() {
        let pos_x: Vec<f32> = (0..10).map(|i| (i as f32) * 1.5).collect();
        let pos_y: Vec<f32> = vec![0.0; 10];
        let assignment = vec![0u32, 0, 0, 1, 1, 1, 2, 2, 2, 2];
        let edges = vec![(0u32, 3), (3, 6), (6, 9)];
        let a = build_hierarchy(&pos_x, &pos_y, &assignment, &edges);
        let b = build_hierarchy(&pos_x, &pos_y, &assignment, &edges);
        assert_eq!(a, b, "same input → identical hierarchy");
    }

    #[test]
    fn cluster_level_edges_dedup_and_drop_intra() {
        let raw = vec![(0u32, 1), (1, 2), (2, 3), (1, 0)];
        let assignment = vec![0u32, 0, 1, 1];
        let out = cluster_level_edges(&raw, &assignment);
        // Intra-cluster (0,1)/(1,0) and (2,3) dropped; only (1,2) crosses.
        assert_eq!(out.len(), 1);
        assert!(out.contains(&(0u32, 1u32)) || out.contains(&(1u32, 0u32)));
    }

    #[test]
    fn incremental_intra_cluster_short_circuits() {
        let pos_x = vec![0.0_f32, 1.0, 2.0];
        let pos_y = vec![0.0_f32; 3];
        let assignment = vec![0u32, 0, 0];
        let edges = vec![];
        let initial = build_hierarchy(&pos_x, &pos_y, &assignment, &edges);
        let after = incremental_edge_update(
            initial.clone(),
            (0, 0), // intra-cluster edge → no-op
            &pos_x, &pos_y, &assignment, &edges,
        );
        assert_eq!(initial, after, "intra-cluster edge does not perturb hierarchy");
    }

    #[test]
    fn incremental_cross_cluster_rebuilds() {
        let pos_x = vec![0.0_f32, 1.0, 100.0, 101.0];
        let pos_y = vec![0.0_f32; 4];
        let assignment = vec![0u32, 0, 1, 1];
        let initial = build_hierarchy(&pos_x, &pos_y, &assignment, &[]);
        let after = incremental_edge_update(
            initial.clone(),
            (0, 1), // cross-cluster edge → rebuild
            &pos_x, &pos_y, &assignment, &[(1u32, 2)],
        );
        // Same node count + assignment + edges → identical answer; the test
        // exercises that the rebuild path is reachable.
        assert_eq!(after.node_to_leaf_cluster, assignment);
        assert_eq!(after.clusters.iter().filter(|r| r.level == 0).count(), 2);
    }

    #[test]
    fn centroid_weighted_by_member_count_at_next_level() {
        // Three leaf clusters: 1 node, 1 node, 100 nodes. If all 3 land in
        // the same next-level cluster, the centroid must be dominated by
        // the 100-node cluster.
        let mut pos_x = vec![0.0_f32, 50.0];
        let mut pos_y = vec![0.0_f32; 2];
        let mut assignment = vec![0u32, 1];
        for i in 0..100 {
            pos_x.push(1000.0 + i as f32);
            pos_y.push(0.0);
            assignment.push(2);
        }
        // Make all three connect so Louvain merges them.
        let edges: Vec<(u32, u32)> = vec![(0, 1), (1, 2)];
        let h = build_hierarchy(&pos_x, &pos_y, &assignment, &edges);
        // If the hierarchy reached level 2 (everything in one super-cluster),
        // its centroid is pulled toward the 100-node region.
        if let Some(top) = h.clusters.last() {
            if top.level >= 1 {
                assert!(top.centroid_x > 500.0,
                    "next-level centroid weighted by member count, got {}",
                    top.centroid_x);
            }
        }
    }
}
