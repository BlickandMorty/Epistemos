//! Cluster-based edge aggregation for LOD rendering.
//!
//! When zoomed out, collapses individual ECS edges into bundle edges between
//! cluster centroids. Drops edge count from O(E) to O(C²) where C = cluster count.

use rustc_hash::FxHashMap;

use crate::ecs::{GraphNodeComponent, TransformComponent, World};

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

fn compute_centroids(
    transforms: &[TransformComponent],
    graph_nodes: &[GraphNodeComponent],
) -> FxHashMap<u32, [f32; 2]> {
    let mut sums: FxHashMap<u32, (f32, f32, u32)> = FxHashMap::default();

    for (transform, graph_node) in transforms.iter().zip(graph_nodes.iter()) {
        if graph_node.visible == 0 || graph_node.cluster_id == u32::MAX {
            continue;
        }
        let entry = sums.entry(graph_node.cluster_id).or_insert((0.0, 0.0, 0));
        entry.0 += transform.x;
        entry.1 += transform.y;
        entry.2 += 1;
    }

    sums.into_iter()
        .map(|(cluster_id, (sum_x, sum_y, count))| {
            let inv = 1.0 / count as f32;
            (cluster_id, [sum_x * inv, sum_y * inv])
        })
        .collect()
}

/// Build aggregated edges from ECS topology + cluster assignments.
pub fn build_aggregated_edges(world: &World) -> Vec<AggregatedEdge> {
    if world.is_empty() || world.edges.is_empty() {
        return Vec::new();
    }

    let centroids = compute_centroids(&world.transform, &world.graph_node);
    if centroids.is_empty() {
        return Vec::new();
    }

    let mut counts: FxHashMap<(u32, u32), u32> =
        FxHashMap::with_capacity_and_hasher(centroids.len() * 2, Default::default());

    for edge in &world.edges {
        let (Some(src_index), Some(tgt_index)) =
            (world.index_of(edge.source), world.index_of(edge.target))
        else {
            continue;
        };

        let src_node = &world.graph_node[src_index];
        let tgt_node = &world.graph_node[tgt_index];
        if src_node.visible == 0 || tgt_node.visible == 0 {
            continue;
        }

        let src_cluster = src_node.cluster_id;
        let tgt_cluster = tgt_node.cluster_id;
        if src_cluster == u32::MAX || tgt_cluster == u32::MAX || src_cluster == tgt_cluster {
            continue;
        }

        let key = if src_cluster < tgt_cluster {
            (src_cluster, tgt_cluster)
        } else {
            (tgt_cluster, src_cluster)
        };
        *counts.entry(key).or_insert(0) += 1;
    }

    let mut result = Vec::with_capacity(counts.len());
    for ((src_cluster, tgt_cluster), count) in counts {
        let (Some(&p0), Some(&p1)) = (centroids.get(&src_cluster), centroids.get(&tgt_cluster))
        else {
            continue;
        };
        if !p0[0].is_finite() || !p0[1].is_finite() || !p1[0].is_finite() || !p1[1].is_finite() {
            continue;
        }
        result.push(AggregatedEdge {
            p0,
            p1,
            count,
            alpha: (count as f32).ln_1p().min(1.0) * 0.8,
        });
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ecs::World;
    use crate::types::Graph;

    fn setup_clustered_graph() -> World {
        let mut graph = Graph::new();
        graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        graph.add_node("b".into(), 10.0, 0.0, 0, 1, "B".into());
        graph.add_node("c".into(), 100.0, 100.0, 0, 1, "C".into());
        graph.add_node("d".into(), 110.0, 100.0, 0, 1, "D".into());

        graph.add_edge("a", "b", 1.0, 0);
        graph.add_edge("c", "d", 1.0, 0);
        graph.add_edge("a", "c", 1.0, 0);
        graph.add_edge("b", "d", 1.0, 0);
        graph.add_edge("a", "d", 1.0, 0);

        let mut world = World::from_graph(&graph);
        world.graph_node[0].cluster_id = 0;
        world.graph_node[1].cluster_id = 0;
        world.graph_node[2].cluster_id = 1;
        world.graph_node[3].cluster_id = 1;
        world
    }

    #[test]
    fn centroid_computation_uses_visible_cluster_members() {
        let world = setup_clustered_graph();
        let centroids = compute_centroids(&world.transform, &world.graph_node);

        assert_eq!(centroids.len(), 2);
        assert!((centroids[&0][0] - 5.0).abs() < 0.01);
        assert!((centroids[&0][1] - 0.0).abs() < 0.01);
        assert!((centroids[&1][0] - 105.0).abs() < 0.01);
        assert!((centroids[&1][1] - 100.0).abs() < 0.01);
    }

    #[test]
    fn aggregated_edges_collapse_inter_cluster_edges() {
        let world = setup_clustered_graph();
        let edges = build_aggregated_edges(&world);

        assert_eq!(edges.len(), 1);
        assert_eq!(edges[0].count, 3);
        assert!(edges[0].alpha > 0.0);
    }

    #[test]
    fn invisible_nodes_are_excluded() {
        let mut world = setup_clustered_graph();
        world.graph_node[3].visible = 0;
        let edges = build_aggregated_edges(&world);
        assert_eq!(edges.len(), 1);
        assert_eq!(edges[0].count, 1);
    }

    #[test]
    fn missing_clusters_skip_aggregation() {
        let mut world = setup_clustered_graph();
        world.graph_node[2].cluster_id = u32::MAX;
        let edges = build_aggregated_edges(&world);
        assert_eq!(edges.len(), 1);
        assert_eq!(edges[0].count, 2);
    }
}
