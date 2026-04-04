//! Graph → World bridge for ECS migration.
//!
//! Converts the existing `Graph` (AoS node storage) into an ECS `World` (SoA component arrays).
//! Topology is mirrored into ECS so render and gameplay systems can avoid the legacy `Graph` path.

use rustc_hash::FxHashMap;

use super::{
    EdgeComponent, GraphNodeComponent, HierarchyComponent, RenderComponent, TransformComponent,
    VelocityComponent, World,
};
use crate::types::Graph;

impl World {
    /// Build an ECS `World` from an existing `Graph`.
    ///
    /// Pre-allocates all SoA arrays, spawns one entity per graph node,
    /// populates `node_id_to_entity` for FFI lookups, and rebuilds the spatial grid.
    pub fn from_graph(graph: &Graph) -> Self {
        let n = graph.nodes.len();
        let mut world = Self::with_capacity(n);
        let mut id_map = FxHashMap::with_capacity_and_hasher(n, Default::default());

        for node in &graph.nodes {
            let entity = world.spawn(TransformComponent {
                x: node.x,
                y: node.y,
                scale: 1.0,
            });

            let idx = world.index_of(entity).unwrap();

            world.velocity[idx] = VelocityComponent {
                vx: node.vx,
                vy: node.vy,
            };

            world.hierarchy[idx] = HierarchyComponent {
                depth: 0,
                parent: u32::MAX,
                node_type: node.node_type as u8,
                _pad: [0; 3],
                link_count: node.link_count,
            };

            world.render[idx] = RenderComponent {
                _pad: [0; 4],
                color_override: node.color_override,
            };

            world.graph_node[idx] = GraphNodeComponent {
                node_id: node.id,
                visible: u8::from(node.visible),
                _pad0: [0; 3],
                radius: node.radius,
                confidence: node.confidence,
                cluster_id: u32::MAX,
                _pad1: [0; 4],
                created_at: node.created_at,
                updated_at: node.updated_at,
            };

            id_map.insert(node.id, entity);
        }

        world.edges.reserve(graph.edges.len());
        for edge in &graph.edges {
            let (Some(&source), Some(&target)) =
                (id_map.get(&edge.source), id_map.get(&edge.target))
            else {
                continue;
            };
            world.edges.push(EdgeComponent {
                source,
                target,
                weight: edge.weight,
                edge_type: edge.edge_type,
                _pad0: [0; 3],
            });
        }

        world.rebuild_edge_adjacency();
        world
            .spatial_grid
            .rebuild(&world.entities, &world.transform);
        world.node_id_to_entity = id_map.clone();
        world.entity_to_node_id = id_map.into_iter().map(|(nid, eid)| (eid, nid)).collect();

        // Compute folder nesting depth from containment edges (edge_type=1).
        // BFS from root folders (those that are NOT contained by another folder).
        world.compute_folder_depth();

        world
    }

    /// Compute `hierarchy.depth` for folder nodes by BFS over containment edges.
    /// Root folders (not contained by any other folder) get depth 0.
    /// Each nested folder increments depth by 1.
    fn compute_folder_depth(&mut self) {
        const FOLDER_TYPE: u8 = 4; // NodeType::Folder
        const CONTAINS_EDGE: u8 = 1;

        let n = self.entities.len();
        if n == 0 {
            return;
        }

        // Build containment parent map: child_entity → parent_entity.
        // "contains" edge: source contains target → target's parent is source.
        let mut parent_of: FxHashMap<u32, u32> = FxHashMap::default();
        for edge in &self.edges {
            if edge.edge_type == CONTAINS_EDGE {
                parent_of.insert(edge.target, edge.source);
            }
        }

        // For each folder, walk up the containment chain to compute depth.
        for i in 0..n {
            if self.hierarchy[i].node_type != FOLDER_TYPE {
                continue;
            }

            let entity = self.entities[i];
            let mut depth = 0u32;
            let mut current = entity;

            // Walk up the containment chain (max 20 to prevent cycles).
            for _ in 0..20 {
                if let Some(&parent_entity) = parent_of.get(&current) {
                    // Only count parent if it's also a folder.
                    if let Some(&parent_idx) = self.entity_to_index.get(&parent_entity) {
                        if self.hierarchy[parent_idx].node_type == FOLDER_TYPE {
                            depth += 1;
                            current = parent_entity;
                            continue;
                        }
                    }
                }
                break;
            }

            self.hierarchy[i].depth = depth;
            if let Some(&parent_entity) = parent_of.get(&entity) {
                self.hierarchy[i].parent = parent_entity;
            }
        }
    }

    /// Copy simulation cluster assignments into the ECS graph-node metadata.
    ///
    /// `graph_indices[sim_idx]` maps simulation indices back to graph/world indices.
    pub fn sync_clusters(&mut self, cluster_ids: &[u32], graph_indices: &[usize]) {
        for graph_node in &mut self.graph_node {
            graph_node.cluster_id = u32::MAX;
        }

        for (sim_index, &graph_index) in graph_indices.iter().enumerate() {
            if sim_index >= cluster_ids.len() || graph_index >= self.graph_node.len() {
                continue;
            }
            self.graph_node[graph_index].cluster_id = cluster_ids[sim_index];
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{Graph, NodeType};

    #[test]
    fn test_from_graph_empty() {
        let graph = Graph::new();
        let world = World::from_graph(&graph);

        assert!(world.is_empty());
        assert!(world.node_id_to_entity.is_empty());
    }

    #[test]
    fn test_from_graph_basic() {
        let mut graph = Graph::new();
        graph.add_node("note-1".into(), 10.0, 20.0, 0, 5, "My Note".into());
        graph.add_node("folder-1".into(), 30.0, 40.0, 4, 12, "Folder".into());

        let world = World::from_graph(&graph);

        assert_eq!(world.len(), 2);
        assert_eq!(world.node_id_to_entity.len(), 2);

        // Verify the note entity
        let note_entity = world.node_id_to_entity[&0];
        let ni = world.index_of(note_entity).unwrap();
        assert_eq!(world.transform[ni].x, 10.0);
        assert_eq!(world.transform[ni].y, 20.0);
        assert_eq!(world.transform[ni].scale, 1.0);
        assert_eq!(world.hierarchy[ni].node_type, NodeType::Note as u8);
        assert_eq!(world.hierarchy[ni].link_count, 5);
        assert_eq!(world.graph_node[ni].node_id, 0);
        assert_eq!(world.graph_node[ni].visible, 1);
        assert_eq!(world.graph_node[ni].cluster_id, u32::MAX);

        // Verify the folder entity
        let folder_entity = world.node_id_to_entity[&1];
        let fi = world.index_of(folder_entity).unwrap();
        assert_eq!(world.transform[fi].x, 30.0);
        assert_eq!(world.transform[fi].y, 40.0);
        assert_eq!(world.hierarchy[fi].node_type, NodeType::Folder as u8);
        assert_eq!(world.hierarchy[fi].link_count, 12);
        assert_eq!(world.graph_node[fi].node_id, 1);
        assert_eq!(world.graph_node[fi].cluster_id, u32::MAX);
    }

    #[test]
    fn test_from_graph_preserves_positions() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), -50.5, 123.4, 0, 1, "A".into());
        graph.nodes[0].vx = 314.0_f32 / 100.0;
        graph.nodes[0].vy = -2.71;

        let world = World::from_graph(&graph);
        let entity = world.node_id_to_entity[&0];
        let idx = world.index_of(entity).unwrap();

        assert_eq!(world.transform[idx].x, -50.5);
        assert_eq!(world.transform[idx].y, 123.4);
        assert_eq!(world.velocity[idx].vx, 314.0_f32 / 100.0);
        assert_eq!(world.velocity[idx].vy, -2.71);
    }

    #[test]
    fn test_from_graph_preserves_edges() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        graph.add_node("b".into(), 10.0, 0.0, 0, 1, "B".into());
        graph.add_edge("a", "b", 2.5, 4);

        let world = World::from_graph(&graph);

        assert_eq!(world.edges.len(), 1);
        let edge = world.edges[0];
        assert_eq!(world.entity_to_node_id[&edge.source], 0);
        assert_eq!(world.entity_to_node_id[&edge.target], 1);
        assert_eq!(edge.weight, 2.5);
        assert_eq!(edge.edge_type, 4);
        let source_index = world.index_of(edge.source).unwrap();
        let target_index = world.index_of(edge.target).unwrap();
        assert_eq!(world.edge_indices_for_index(source_index), &[0]);
        assert_eq!(world.edge_indices_for_index(target_index), &[0]);
    }

    #[test]
    fn test_sync_clusters_marks_only_visible_sim_nodes() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        graph.add_node("b".into(), 10.0, 0.0, 0, 1, "B".into());
        graph.add_node("c".into(), 20.0, 0.0, 0, 1, "C".into());

        let mut world = World::from_graph(&graph);
        world.sync_clusters(&[4, 7], &[0, 2]);

        assert_eq!(world.graph_node[0].cluster_id, 4);
        assert_eq!(world.graph_node[1].cluster_id, u32::MAX);
        assert_eq!(world.graph_node[2].cluster_id, 7);
    }
}
