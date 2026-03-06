//! Cluster-based edge aggregation for LOD rendering.
//!
//! When zoomed out, collapses individual edges into bundle edges between
//! cluster centroids. Drops edge count from O(E) to O(C²) where C = cluster count.

use rustc_hash::FxHashMap;

use crate::ecs::{HierarchyComponent, TransformComponent, World};
use crate::types::{Edge, Graph};

/// Zoom threshold below which edges are aggregated by cluster.
pub const AGGREGATION_THRESHOLD: f32 = 0.3;

/// A single aggregated edge between two cluster centroids.
#[derive(Debug, Clone)]
pub struct AggregatedEdge {
    pub p0: [f32; 2],
    pub p1: [f32; 2],
    pub count: u32,
    /// Alpha derived from edge count: ln(count).min(1.0) * 0.8
    pub alpha: f32,
}

/// Compute centroids for each cluster from visible nodes.
/// Returns a map of cluster_id → (centroid_x, centroid_y).
fn compute_centroids(
    transforms: &[TransformComponent],
    hierarchy: &[HierarchyComponent],
) -> FxHashMap<u32, [f32; 2]> {
    let mut sums: FxHashMap<u32, (f32, f32, u32)> = FxHashMap::default();

    for (t, h) in transforms.iter().zip(hierarchy.iter()) {
        if h.visible == 0 || h.cluster_id == u32::MAX {
            continue;
        }
        let entry = sums.entry(h.cluster_id).or_insert((0.0, 0.0, 0));
        entry.0 += t.x;
        entry.1 += t.y;
        entry.2 += 1;
    }

    sums.into_iter()
        .map(|(cid, (sx, sy, count))| {
            let n = count as f32;
            (cid, [sx / n, sy / n])
        })
        .collect()
}

/// Build aggregated edges from graph edges + world cluster assignments.
///
/// For each edge, looks up source/target cluster_ids. If different clusters,
/// accumulates into (cluster_a, cluster_b) → count map. Returns one
/// AggregatedEdge per unique cluster pair.
pub fn build_aggregated_edges(graph: &Graph, world: &World) -> Vec<AggregatedEdge> {
    if world.is_empty() || graph.edges.is_empty() {
        return Vec::new();
    }

    let centroids = compute_centroids(&world.transform, &world.hierarchy);
    if centroids.is_empty() {
        return Vec::new();
    }

    // Accumulate inter-cluster edge counts.
    // Key: (min(cluster_a, cluster_b), max(cluster_a, cluster_b))
    let mut counts: FxHashMap<(u32, u32), u32> =
        FxHashMap::with_capacity_and_hasher(centroids.len() * 2, Default::default());

    for edge in &graph.edges {
        let si = graph.id_to_index.get(&edge.source);
        let ti = graph.id_to_index.get(&edge.target);
        if let (Some(&si), Some(&ti)) = (si, ti) {
            // Graph node index == world entity index (from_graph iterates in order)
            if si >= world.hierarchy.len() || ti >= world.hierarchy.len() {
                continue;
            }
            let src_h = &world.hierarchy[si];
            let tgt_h = &world.hierarchy[ti];

            if src_h.visible == 0 || tgt_h.visible == 0 {
                continue;
            }
            let ca = src_h.cluster_id;
            let cb = tgt_h.cluster_id;
            if ca == u32::MAX || cb == u32::MAX || ca == cb {
                continue; // Skip intra-cluster or unassigned
            }

            let key = if ca < cb { (ca, cb) } else { (cb, ca) };
            *counts.entry(key).or_insert(0) += 1;
        }
    }

    // Build aggregated edge instances.
    let mut result = Vec::with_capacity(counts.len());
    for ((ca, cb), count) in &counts {
        if let (Some(&p0), Some(&p1)) = (centroids.get(ca), centroids.get(cb)) {
            // Skip degenerate positions
            if !p0[0].is_finite() || !p0[1].is_finite() || !p1[0].is_finite() || !p1[1].is_finite() {
                continue;
            }
            let alpha = ((*count as f32).ln_1p()).min(1.0) * 0.8;
            result.push(AggregatedEdge {
                p0,
                p1,
                count: *count,
                alpha,
            });
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ecs::World;
    use crate::types::Graph;

    /// Helper: build a graph + world with known clusters
    fn setup_clustered_graph() -> (Graph, World) {
        let mut graph = Graph::new();
        // Cluster 0: nodes a, b at (0,0) and (10,0)
        graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        graph.add_node("b".into(), 10.0, 0.0, 0, 1, "B".into());
        // Cluster 1: nodes c, d at (100,100) and (110,100)
        graph.add_node("c".into(), 100.0, 100.0, 0, 1, "C".into());
        graph.add_node("d".into(), 110.0, 100.0, 0, 1, "D".into());

        // Intra-cluster edges (should be skipped)
        graph.add_edge("a", "b", 1.0, 0);
        graph.add_edge("c", "d", 1.0, 0);
        // Inter-cluster edges (should be aggregated)
        graph.add_edge("a", "c", 1.0, 0);
        graph.add_edge("b", "d", 1.0, 0);
        graph.add_edge("a", "d", 1.0, 0);

        let mut world = World::from_graph(&graph);
        // Assign clusters
        world.hierarchy[0].cluster_id = 0; // a
        world.hierarchy[1].cluster_id = 0; // b
        world.hierarchy[2].cluster_id = 1; // c
        world.hierarchy[3].cluster_id = 1; // d

        (graph, world)
    }

    #[test]
    fn test_centroid_computation() {
        let (_, world) = setup_clustered_graph();
        let centroids = compute_centroids(&world.transform, &world.hierarchy);

        assert_eq!(centroids.len(), 2);
        // Cluster 0: mean of (0,0) and (10,0) = (5, 0)
        let c0 = centroids[&0];
        assert!((c0[0] - 5.0).abs() < 0.01);
        assert!((c0[1] - 0.0).abs() < 0.01);
        // Cluster 1: mean of (100,100) and (110,100) = (105, 100)
        let c1 = centroids[&1];
        assert!((c1[0] - 105.0).abs() < 0.01);
        assert!((c1[1] - 100.0).abs() < 0.01);
    }

    #[test]
    fn test_aggregated_edges() {
        let (graph, world) = setup_clustered_graph();
        let agg = build_aggregated_edges(&graph, &world);

        // 3 inter-cluster edges → 1 aggregated edge between cluster 0 and 1
        assert_eq!(agg.len(), 1);
        assert_eq!(agg[0].count, 3);
        assert!(agg[0].alpha > 0.0);
    }

    #[test]
    fn test_single_cluster_no_aggregated_edges() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        graph.add_node("b".into(), 10.0, 0.0, 0, 1, "B".into());
        graph.add_edge("a", "b", 1.0, 0);

        let mut world = World::from_graph(&graph);
        world.hierarchy[0].cluster_id = 0;
        world.hierarchy[1].cluster_id = 0;

        let agg = build_aggregated_edges(&graph, &world);
        assert!(agg.is_empty(), "intra-cluster edges should not produce aggregated edges");
    }

    #[test]
    fn test_unassigned_clusters_skipped() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        graph.add_node("b".into(), 10.0, 0.0, 0, 1, "B".into());
        graph.add_edge("a", "b", 1.0, 0);

        let world = World::from_graph(&graph);
        // cluster_id defaults to u32::MAX (unassigned)

        let agg = build_aggregated_edges(&graph, &world);
        assert!(agg.is_empty(), "unassigned cluster nodes should not produce aggregated edges");
    }

    #[test]
    fn test_empty_graph() {
        let graph = Graph::new();
        let world = World::from_graph(&graph);
        let agg = build_aggregated_edges(&graph, &world);
        assert!(agg.is_empty());
    }

    #[test]
    fn test_invisible_nodes_excluded() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        graph.add_node("b".into(), 100.0, 100.0, 0, 1, "B".into());
        graph.add_edge("a", "b", 1.0, 0);

        let mut world = World::from_graph(&graph);
        world.hierarchy[0].cluster_id = 0;
        world.hierarchy[1].cluster_id = 1;
        world.hierarchy[1].visible = 0; // b is invisible

        let agg = build_aggregated_edges(&graph, &world);
        assert!(agg.is_empty(), "edges to invisible nodes should be excluded");
    }

    #[test]
    fn test_all_unique_clusters() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        graph.add_node("b".into(), 10.0, 10.0, 0, 1, "B".into());
        graph.add_node("c".into(), 20.0, 20.0, 0, 1, "C".into());
        graph.add_edge("a", "b", 1.0, 0);
        graph.add_edge("b", "c", 1.0, 0);
        graph.add_edge("a", "c", 1.0, 0);

        let mut world = World::from_graph(&graph);
        world.hierarchy[0].cluster_id = 0;
        world.hierarchy[1].cluster_id = 1;
        world.hierarchy[2].cluster_id = 2;

        let agg = build_aggregated_edges(&graph, &world);
        // 3 edges between 3 different clusters = 3 aggregated edges
        assert_eq!(agg.len(), 3);
        for edge in &agg {
            assert_eq!(edge.count, 1);
        }
    }
}
