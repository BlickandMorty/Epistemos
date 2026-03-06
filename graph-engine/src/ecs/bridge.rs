//! Graph → World bridge for ECS migration.
//!
//! Converts the existing `Graph` (AoS node storage) into an ECS `World` (SoA component arrays).
//! Edges are NOT migrated — the renderer reads them directly from `Graph`.

use rustc_hash::FxHashMap;

use super::{
    BlockType, HierarchyComponent, RenderComponent, TransformComponent, VelocityComponent, World,
};
use crate::types::{radius_for_link_count, Graph, NodeType};

/// Maps `NodeType` → `BlockType` for the pixel art renderer.
fn block_type_for_node(node_type: NodeType) -> BlockType {
    match node_type {
        NodeType::Folder => BlockType::Core,
        NodeType::Note => BlockType::Primary,
        NodeType::Source | NodeType::Idea => BlockType::Secondary,
        NodeType::Chat | NodeType::Quote => BlockType::Tertiary,
        NodeType::Tag | NodeType::Block => BlockType::Leaf,
    }
}

/// Returns 1 if this block type gets a glare highlight, 0 otherwise.
fn has_glare_for_block(bt: BlockType) -> u8 {
    match bt {
        BlockType::Core | BlockType::Primary => 1,
        _ => 0,
    }
}

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
                visible: node.visible as u8,
                _pad: [0; 2],
                link_count: node.link_count,
                radius: radius_for_link_count(node.link_count),
                cluster_id: u32::MAX,
            };

            let bt = block_type_for_node(node.node_type);
            world.render[idx] = RenderComponent {
                block_type: bt as u8,
                has_glare: has_glare_for_block(bt),
                _pad: [0; 2],
                color_override: [0.0; 4],
            };

            id_map.insert(node.id, entity);
        }

        world.spatial_grid.rebuild(&world.entities, &world.transform);
        world.node_id_to_entity = id_map.clone();
        world.entity_to_node_id = id_map.into_iter().map(|(nid, eid)| (eid, nid)).collect();
        world
    }

    /// Copy Louvain cluster assignments from simulation to ECS hierarchy.
    ///
    /// `graph_indices[sim_idx]` maps simulation index → graph node index.
    /// Graph node index == world entity index (since `from_graph` iterates in order).
    pub fn sync_clusters(&mut self, cluster_ids: &[u32], graph_indices: &[usize]) {
        // Reset all to unassigned
        for h in &mut self.hierarchy {
            h.cluster_id = u32::MAX;
        }
        // Map sim_index → graph_index → world array index
        for (si, &gi) in graph_indices.iter().enumerate() {
            if si < cluster_ids.len() && gi < self.hierarchy.len() {
                self.hierarchy[gi].cluster_id = cluster_ids[si];
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::Graph;

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
        assert_eq!(world.hierarchy[ni].visible, 1);
        assert!(world.hierarchy[ni].radius > 0.0);
        assert_eq!(world.hierarchy[ni].cluster_id, u32::MAX);
        assert_eq!(world.render[ni].block_type, BlockType::Primary as u8);
        assert_eq!(world.render[ni].has_glare, 1);

        // Verify the folder entity
        let folder_entity = world.node_id_to_entity[&1];
        let fi = world.index_of(folder_entity).unwrap();
        assert_eq!(world.transform[fi].x, 30.0);
        assert_eq!(world.transform[fi].y, 40.0);
        assert_eq!(world.hierarchy[fi].node_type, NodeType::Folder as u8);
        assert_eq!(world.hierarchy[fi].link_count, 12);
        assert_eq!(world.hierarchy[fi].visible, 1);
        assert!(world.hierarchy[fi].radius > world.hierarchy[ni].radius); // 12 links > 5 links
        assert_eq!(world.render[fi].block_type, BlockType::Core as u8);
        assert_eq!(world.render[fi].has_glare, 1);
    }

    #[test]
    fn test_node_type_to_block_type() {
        assert_eq!(block_type_for_node(NodeType::Folder), BlockType::Core);
        assert_eq!(block_type_for_node(NodeType::Note), BlockType::Primary);
        assert_eq!(block_type_for_node(NodeType::Source), BlockType::Secondary);
        assert_eq!(block_type_for_node(NodeType::Idea), BlockType::Secondary);
        assert_eq!(block_type_for_node(NodeType::Chat), BlockType::Tertiary);
        assert_eq!(block_type_for_node(NodeType::Quote), BlockType::Tertiary);
        assert_eq!(block_type_for_node(NodeType::Tag), BlockType::Leaf);
        assert_eq!(block_type_for_node(NodeType::Block), BlockType::Leaf);
    }

    #[test]
    fn test_from_graph_hidden_node() {
        let mut graph = Graph::new();
        graph.add_node("hidden".into(), 0.0, 0.0, 0, 1, "Hidden".into());
        graph.nodes[0].visible = false;

        let world = World::from_graph(&graph);
        let entity = world.node_id_to_entity[&0];
        let idx = world.index_of(entity).unwrap();
        assert_eq!(world.hierarchy[idx].visible, 0);
    }

    #[test]
    fn test_sync_clusters() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        graph.add_node("b".into(), 10.0, 10.0, 0, 1, "B".into());
        graph.add_node("c".into(), 20.0, 20.0, 0, 1, "C".into());

        let mut world = World::from_graph(&graph);

        // Simulate: only nodes 0 and 2 are in the simulation (indices 0 and 1)
        let cluster_ids = vec![5, 5]; // both in cluster 5
        let graph_indices = vec![0, 2]; // sim idx 0 → graph idx 0, sim idx 1 → graph idx 2

        world.sync_clusters(&cluster_ids, &graph_indices);

        assert_eq!(world.hierarchy[0].cluster_id, 5);
        assert_eq!(world.hierarchy[1].cluster_id, u32::MAX); // node 1 not in sim
        assert_eq!(world.hierarchy[2].cluster_id, 5);
    }

    #[test]
    fn test_sync_clusters_empty() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());

        let mut world = World::from_graph(&graph);
        world.sync_clusters(&[], &[]);

        assert_eq!(world.hierarchy[0].cluster_id, u32::MAX);
    }

    #[test]
    fn test_hierarchy_component_size() {
        assert_eq!(std::mem::size_of::<HierarchyComponent>(), 24);
    }

    #[test]
    fn test_from_graph_preserves_positions() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), -50.5, 123.4, 0, 1, "A".into());
        graph.nodes[0].vx = 3.14;
        graph.nodes[0].vy = -2.71;

        let world = World::from_graph(&graph);
        let entity = world.node_id_to_entity[&0];
        let idx = world.index_of(entity).unwrap();

        assert_eq!(world.transform[idx].x, -50.5);
        assert_eq!(world.transform[idx].y, 123.4);
        assert_eq!(world.velocity[idx].vx, 3.14);
        assert_eq!(world.velocity[idx].vy, -2.71);
    }
}
