//! # Graph Data Structures
//!
//! Core types for the LogSeq-style graph engine.
//! 7 node types (down from 13), explicit velocity model (d3-force style).

use rustc_hash::{FxHashMap, FxHashSet};

/// Node type enum — 7 semantic categories.
/// Idea merges BrainDump, Source merges Paper/Book/Thinker, Tag absorbs Concept.
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum NodeType {
    Note = 0,
    Chat = 1,
    Idea = 2,
    Source = 3,
    Folder = 4,
    Quote = 5,
    Tag = 6,
    Block = 7,
}

impl NodeType {
    pub fn from_u8(v: u8) -> Self {
        match v {
            0 => Self::Note,
            1 => Self::Chat,
            2 => Self::Idea,
            3 => Self::Source,
            4 => Self::Folder,
            5 => Self::Quote,
            6 => Self::Tag,
            7 => Self::Block,
            _ => Self::Note,
        }
    }

    /// RGBA color for this node type (dark mode — vibrant pastels on dark background).
    pub fn color(&self) -> [f32; 4] {
        match self {
            Self::Note => [0.39, 0.90, 0.85, 1.0],   // teal
            Self::Chat => [1.00, 0.62, 0.04, 1.0],   // orange
            Self::Idea => [1.00, 0.84, 0.04, 1.0],   // yellow
            Self::Source => [0.20, 0.78, 0.35, 1.0], // green
            Self::Folder => [0.64, 0.52, 0.37, 1.0], // brown
            Self::Quote => [0.69, 0.32, 0.87, 1.0],  // purple
            Self::Tag => [0.46, 0.46, 0.50, 1.0],    // gray
            Self::Block => [0.55, 0.78, 0.90, 1.0],  // sky blue
        }
    }

    /// RGBA color for this node type (light mode — strong contrast on light background).
    pub fn color_light(&self) -> [f32; 4] {
        match self {
            Self::Note => [0.05, 0.48, 0.44, 1.0],   // teal (darker)
            Self::Chat => [0.72, 0.36, 0.00, 1.0],   // orange (darker)
            Self::Idea => [0.65, 0.52, 0.00, 1.0],   // gold (darker)
            Self::Source => [0.05, 0.46, 0.16, 1.0], // green (darker)
            Self::Folder => [0.40, 0.28, 0.16, 1.0], // brown (darker)
            Self::Quote => [0.42, 0.12, 0.58, 1.0],  // purple (darker)
            Self::Tag => [0.25, 0.25, 0.30, 1.0],    // gray (darker)
            Self::Block => [0.15, 0.42, 0.60, 1.0],  // blue (darker)
        }
    }
}

/// Minimum node radius in world units.
const MIN_RADIUS: f32 = 4.0;
/// Maximum node radius in world units.
const MAX_RADIUS: f32 = 40.0;
/// Base radius multiplier for cbrt(link_count) scaling.
const BASE_RADIUS: f32 = 8.0;

/// Compute node radius from link count using LogSeq's formula:
/// `radius = cbrt(link_count) * 8.0`, clamped to [4, 40].
pub fn radius_for_link_count(link_count: u32) -> f32 {
    let count = link_count.max(1) as f32;
    (count.cbrt() * BASE_RADIUS).clamp(MIN_RADIUS, MAX_RADIUS)
}

/// RGBA color for an edge type (dark mode — subtle pastels on dark background).
/// 12 types: 0=reference, 1=contains, 2=tagged, 3=mentions, 4=cites,
/// 5=authored, 6=related, 7=quotes, 8=supports, 9=contradicts, 10=expands, 11=questions.
pub fn edge_type_color(edge_type: u8) -> [f32; 4] {
    match edge_type {
        0 => [0.55, 0.55, 0.60, 0.35],  // reference — light gray
        1 => [0.50, 0.40, 0.30, 0.35],  // contains — brown
        2 => [0.46, 0.46, 0.50, 0.30],  // tagged — gray
        3 => [0.40, 0.70, 0.90, 0.40],  // mentions — light blue
        4 => [0.20, 0.78, 0.35, 0.45],  // cites — green
        5 => [1.00, 0.62, 0.04, 0.40],  // authored — orange
        6 => [0.69, 0.32, 0.87, 0.40],  // related — purple
        7 => [1.00, 0.84, 0.04, 0.40],  // quotes — yellow
        8 => [0.30, 0.90, 0.40, 0.50],  // supports — bright green
        9 => [0.95, 0.25, 0.25, 0.50],  // contradicts — red
        10 => [0.30, 0.85, 0.85, 0.45], // expands — cyan
        11 => [0.95, 0.75, 0.10, 0.45], // questions — amber
        _ => [0.55, 0.55, 0.60, 0.30],  // default — gray
    }
}

/// RGBA color for an edge type (light mode — strong contrast on light background).
pub fn edge_type_color_light(edge_type: u8) -> [f32; 4] {
    match edge_type {
        0 => [0.08, 0.08, 0.10, 0.90],  // reference — near black
        1 => [0.14, 0.09, 0.04, 0.90],  // contains — dark umber
        2 => [0.10, 0.10, 0.12, 0.88],  // tagged — graphite
        3 => [0.04, 0.15, 0.32, 0.90],  // mentions — ink blue
        4 => [0.02, 0.22, 0.08, 0.90],  // cites — forest
        5 => [0.28, 0.14, 0.02, 0.90],  // authored — burnt amber
        6 => [0.19, 0.05, 0.30, 0.90],  // related — deep violet
        7 => [0.29, 0.23, 0.02, 0.90],  // quotes — antique gold
        8 => [0.03, 0.24, 0.08, 0.90],  // supports — deep green
        9 => [0.34, 0.05, 0.05, 0.90],  // contradicts — dark red
        10 => [0.03, 0.22, 0.22, 0.90], // expands — deep teal
        11 => [0.30, 0.18, 0.02, 0.90], // questions — dark amber
        _ => [0.08, 0.08, 0.10, 0.88],  // default — near black
    }
}

/// A node in the knowledge graph.
/// Uses d3-force's explicit velocity model (vx/vy stored directly).
#[derive(Clone)]
pub struct Node {
    pub id: u32,
    pub uuid: String,
    pub x: f32,
    pub y: f32,
    pub vx: f32,
    pub vy: f32,
    /// Fixed position for drag constraint (d3 style).
    /// When set, node snaps to this position and velocity is zeroed.
    pub fx: Option<f32>,
    pub fy: Option<f32>,
    pub node_type: NodeType,
    pub link_count: u32,
    pub radius: f32,
    pub label: String,
    pub visible: bool,
    /// Creation timestamp (Unix epoch seconds). 0.0 = not set (always visible in time filter).
    pub created_at: f64,
    /// Last update timestamp (Unix epoch seconds). 0.0 = not set.
    pub updated_at: f64,
    /// Confidence score (0.0–1.0) from enrichment pipeline. 0.0 = not set.
    pub confidence: f32,
    /// Per-node RGBA color override. alpha > 0 means active.
    pub color_override: [f32; 4],
}

#[derive(Clone)]
pub struct Edge {
    pub source: u32,
    pub target: u32,
    pub weight: f32,
    pub edge_type: u8,
}

#[derive(Clone)]
pub struct Graph {
    pub nodes: Vec<Node>,
    pub edges: Vec<Edge>,
    pub uuid_to_id: FxHashMap<String, u32>,
    pub id_to_index: FxHashMap<u32, usize>,
    next_id: u32,
}

impl Default for Graph {
    fn default() -> Self {
        Self::new()
    }
}

impl Graph {
    fn refresh_node_link_metrics(&mut self, node_id: u32) {
        let Some(&index) = self.id_to_index.get(&node_id) else {
            return;
        };

        let mut neighbors = FxHashSet::default();
        for edge in &self.edges {
            if edge.source == node_id {
                neighbors.insert(edge.target);
            }
            if edge.target == node_id {
                neighbors.insert(edge.source);
            }
        }

        let link_count = neighbors.len() as u32;
        let node = &mut self.nodes[index];
        node.link_count = link_count;
        node.radius = radius_for_link_count(link_count);
    }

    fn refresh_pair_link_metrics(&mut self, first_id: u32, second_id: u32) {
        self.refresh_node_link_metrics(first_id);
        if second_id != first_id {
            self.refresh_node_link_metrics(second_id);
        }
    }

    pub fn new() -> Self {
        Self {
            nodes: Vec::new(),
            edges: Vec::new(),
            uuid_to_id: FxHashMap::default(),
            id_to_index: FxHashMap::default(),
            next_id: 0,
        }
    }

    pub fn clear(&mut self) {
        self.nodes.clear();
        self.edges.clear();
        self.uuid_to_id.clear();
        self.id_to_index.clear();
        self.next_id = 0;
    }

    pub fn add_node(
        &mut self,
        uuid: String,
        x: f32,
        y: f32,
        node_type: u8,
        link_count: u32,
        label: String,
    ) {
        let id = self.next_id;
        self.next_id += 1;
        let radius = radius_for_link_count(link_count);
        let node = Node {
            id,
            uuid: uuid.clone(),
            x,
            y,
            vx: 0.0,
            vy: 0.0,
            fx: None,
            fy: None,
            node_type: NodeType::from_u8(node_type),
            link_count,
            radius,
            label,
            visible: true,
            created_at: 0.0,
            updated_at: 0.0,
            confidence: 0.0,
            color_override: [0.0; 4],
        };
        let index = self.nodes.len();
        self.uuid_to_id.insert(uuid, id);
        self.id_to_index.insert(id, index);
        self.nodes.push(node);
    }

    pub fn add_edge(&mut self, source_uuid: &str, target_uuid: &str, weight: f32, edge_type: u8) {
        if let (Some(&src), Some(&tgt)) = (
            self.uuid_to_id.get(source_uuid),
            self.uuid_to_id.get(target_uuid),
        ) {
            self.edges.push(Edge {
                source: src,
                target: tgt,
                weight,
                edge_type,
            });
            self.refresh_pair_link_metrics(src, tgt);
        }
    }

    /// Remove a node by UUID. Also removes all edges touching it.
    /// Uses swap-remove for O(1) Vec removal, fixes id_to_index for the swapped element.
    /// `next_id` is NOT reset — IDs are monotonically increasing to avoid collisions.
    pub fn remove_node(&mut self, uuid: &str) -> bool {
        let Some(&id) = self.uuid_to_id.get(uuid) else {
            return false;
        };
        let Some(&idx) = self.id_to_index.get(&id) else {
            return false;
        };

        let mut affected_neighbors = FxHashSet::default();
        for edge in &self.edges {
            if edge.source == id {
                affected_neighbors.insert(edge.target);
            }
            if edge.target == id {
                affected_neighbors.insert(edge.source);
            }
        }

        // Remove all edges touching this node.
        self.edges.retain(|e| e.source != id && e.target != id);

        // Swap-remove: if not the last element, fix the swapped node's index.
        let last_idx = self.nodes.len() - 1;
        if idx != last_idx {
            let swapped_id = self.nodes[last_idx].id;
            self.id_to_index.insert(swapped_id, idx);
        }
        self.nodes.swap_remove(idx);

        self.uuid_to_id.remove(uuid);
        self.id_to_index.remove(&id);

        for neighbor_id in affected_neighbors {
            self.refresh_node_link_metrics(neighbor_id);
        }
        true
    }

    /// Remove edges between two nodes (both directions).
    /// Returns the number of edges removed.
    pub fn remove_edges(&mut self, source_uuid: &str, target_uuid: &str) -> usize {
        let src_id = self.uuid_to_id.get(source_uuid).copied();
        let tgt_id = self.uuid_to_id.get(target_uuid).copied();
        let (Some(src), Some(tgt)) = (src_id, tgt_id) else {
            return 0;
        };

        let before = self.edges.len();
        self.edges.retain(|e| {
            !((e.source == src && e.target == tgt) || (e.source == tgt && e.target == src))
        });
        let removed = before - self.edges.len();
        if removed > 0 {
            self.refresh_pair_link_metrics(src, tgt);
        }
        removed
    }
}

// ── Theme Types ─────────────────────────────────────────────────────────────

/// Graph visual theme — selects rendering style.
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VisualTheme {
    Dialogue = 0, // FFT-style dialogue box on node selection
    Classic = 1,  // Original SDF circles + smooth lines
}

impl VisualTheme {
    pub fn from_u8(v: u8) -> Self {
        match v {
            1 => Self::Classic,
            _ => Self::Dialogue,
        }
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // =========================================================================
    // Node Type Tests (10 tests)
    // =========================================================================

    #[test]
    fn node_type_roundtrip() {
        for v in 0..=7u8 {
            let nt = NodeType::from_u8(v);
            assert_eq!(nt as u8, v);
        }
    }

    #[test]
    fn node_type_invalid_defaults_to_note() {
        // Out-of-range values default to Note
        assert_eq!(NodeType::from_u8(255), NodeType::Note);
        assert_eq!(NodeType::from_u8(8), NodeType::Note);
        assert_eq!(NodeType::from_u8(100), NodeType::Note);
    }

    #[test]
    fn node_type_block_variant() {
        assert_eq!(NodeType::from_u8(7), NodeType::Block);
        assert_eq!(NodeType::Block as u8, 7);
    }

    #[test]
    fn node_type_all_variants_distinct() {
        let types: Vec<NodeType> = (0..=7u8).map(NodeType::from_u8).collect();
        for i in 0..types.len() {
            for j in (i + 1)..types.len() {
                assert_ne!(types[i], types[j], "Node types should be distinct");
            }
        }
    }

    #[test]
    fn node_type_note_properties() {
        let nt = NodeType::Note;
        assert_eq!(nt as u8, 0);
        let color = nt.color();
        assert_eq!(color[3], 1.0); // Alpha is 1.0
    }

    #[test]
    fn node_type_chat_properties() {
        let nt = NodeType::Chat;
        assert_eq!(nt as u8, 1);
        assert_eq!(nt.color()[3], 1.0);
    }

    #[test]
    fn node_type_idea_properties() {
        let nt = NodeType::Idea;
        assert_eq!(nt as u8, 2);
        assert_eq!(nt.color()[3], 1.0);
    }

    #[test]
    fn node_type_source_properties() {
        let nt = NodeType::Source;
        assert_eq!(nt as u8, 3);
        assert_eq!(nt.color()[3], 1.0);
    }

    #[test]
    fn node_type_folder_properties() {
        let nt = NodeType::Folder;
        assert_eq!(nt as u8, 4);
        assert_eq!(nt.color()[3], 1.0);
    }

    #[test]
    fn node_type_quote_properties() {
        let nt = NodeType::Quote;
        assert_eq!(nt as u8, 5);
        assert_eq!(nt.color()[3], 1.0);
    }

    #[test]
    fn node_type_tag_properties() {
        let nt = NodeType::Tag;
        assert_eq!(nt as u8, 6);
        assert_eq!(nt.color()[3], 1.0);
    }

    // =========================================================================
    // Node Construction Tests (10 tests)
    // =========================================================================

    #[test]
    fn node_default_values() {
        let mut g = Graph::new();
        g.add_node("test-uuid".into(), 10.0, 20.0, 0, 5, "Test".into());

        let node = &g.nodes[0];
        assert_eq!(node.id, 0);
        assert_eq!(node.uuid, "test-uuid");
        assert_eq!(node.x, 10.0);
        assert_eq!(node.y, 20.0);
        assert_eq!(node.vx, 0.0);
        assert_eq!(node.vy, 0.0);
        assert_eq!(node.fx, None);
        assert_eq!(node.fy, None);
        assert!(node.visible);
        assert_eq!(node.created_at, 0.0);
        assert_eq!(node.updated_at, 0.0);
        assert_eq!(node.confidence, 0.0);
    }

    #[test]
    fn node_velocity_model_explicit() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());

        // Velocity should be explicitly stored (d3-force style)
        g.nodes[0].vx = 5.0;
        g.nodes[0].vy = -3.0;

        assert_eq!(g.nodes[0].vx, 5.0);
        assert_eq!(g.nodes[0].vy, -3.0);
    }

    #[test]
    fn node_fixed_position() {
        let mut g = Graph::new();
        g.add_node("a".into(), 10.0, 20.0, 0, 1, "A".into());

        // Test fixed position (drag constraint)
        g.nodes[0].fx = Some(100.0);
        g.nodes[0].fy = Some(200.0);

        assert_eq!(g.nodes[0].fx, Some(100.0));
        assert_eq!(g.nodes[0].fy, Some(200.0));
    }

    #[test]
    fn node_partial_fixed_position() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());

        // Only fix x, leave y free
        g.nodes[0].fx = Some(50.0);
        g.nodes[0].fy = None;

        assert_eq!(g.nodes[0].fx, Some(50.0));
        assert_eq!(g.nodes[0].fy, None);
    }

    #[test]
    fn node_type_assignment() {
        let mut g = Graph::new();
        for t in 0..=6u8 {
            g.add_node(format!("node-{}", t), 0.0, 0.0, t, 1, format!("Node {}", t));
        }

        for t in 0..=6u8 {
            assert_eq!(g.nodes[t as usize].node_type as u8, t);
        }
    }

    #[test]
    fn node_visibility_toggle() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());

        assert!(g.nodes[0].visible);

        g.nodes[0].visible = false;
        assert!(!g.nodes[0].visible);

        g.nodes[0].visible = true;
        assert!(g.nodes[0].visible);
    }

    #[test]
    fn node_label_storage() {
        let mut g = Graph::new();
        let long_label = "a".repeat(1000);
        g.add_node("a".into(), 0.0, 0.0, 0, 1, long_label.clone());

        assert_eq!(g.nodes[0].label, long_label);
    }

    #[test]
    fn node_uuid_uniqueness() {
        let mut g = Graph::new();
        g.add_node("uuid-1".into(), 0.0, 0.0, 0, 1, "A".into());
        g.add_node("uuid-2".into(), 0.0, 0.0, 0, 1, "B".into());

        assert_ne!(g.nodes[0].id, g.nodes[1].id);
        assert_ne!(g.nodes[0].uuid, g.nodes[1].uuid);
    }

    #[test]
    fn node_timestamps_default_zero() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());

        assert_eq!(g.nodes[0].created_at, 0.0);
        assert_eq!(g.nodes[0].updated_at, 0.0);
    }

    #[test]
    fn node_timestamps_settable() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());

        g.nodes[0].created_at = 1700000000.0;
        g.nodes[0].updated_at = 1700001000.0;

        assert_eq!(g.nodes[0].created_at, 1700000000.0);
        assert_eq!(g.nodes[0].updated_at, 1700001000.0);
    }

    // =========================================================================
    // Edge Construction Tests (10 tests)
    // =========================================================================

    #[test]
    fn edge_basic_construction() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        g.add_node("b".into(), 10.0, 0.0, 1, 2, "B".into());
        g.add_edge("a", "b", 1.0, 0);

        assert_eq!(g.edges.len(), 1);
        assert_eq!(g.edges[0].source, 0);
        assert_eq!(g.edges[0].target, 1);
        assert_eq!(g.edges[0].weight, 1.0);
        assert_eq!(g.edges[0].edge_type, 0);
    }

    #[test]
    fn edge_with_type() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        g.add_node("b".into(), 0.0, 0.0, 0, 1, "B".into());

        for t in 0..=11u8 {
            g.add_edge("a", "b", 1.0, t);
        }

        for (i, t) in (0..=11u8).enumerate() {
            assert_eq!(g.edges[i].edge_type, t);
        }
    }

    #[test]
    fn edge_weight_variation() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        g.add_node("b".into(), 0.0, 0.0, 0, 1, "B".into());

        g.add_edge("a", "b", 0.5, 0);
        g.add_edge("a", "b", 2.0, 0);
        g.add_edge("a", "b", 10.0, 0);

        assert_eq!(g.edges[0].weight, 0.5);
        assert_eq!(g.edges[1].weight, 2.0);
        assert_eq!(g.edges[2].weight, 10.0);
    }

    #[test]
    fn edge_unknown_uuid_skipped() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());

        g.add_edge("a", "nonexistent", 1.0, 0);
        assert_eq!(g.edges.len(), 0);

        g.add_edge("nonexistent", "a", 1.0, 0);
        assert_eq!(g.edges.len(), 0);

        g.add_edge("nonexistent1", "nonexistent2", 1.0, 0);
        assert_eq!(g.edges.len(), 0);
    }

    #[test]
    fn edge_multiple_from_same_source() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        g.add_node("b".into(), 0.0, 0.0, 0, 1, "B".into());
        g.add_node("c".into(), 0.0, 0.0, 0, 1, "C".into());

        g.add_edge("a", "b", 1.0, 0);
        g.add_edge("a", "c", 1.0, 0);

        assert_eq!(g.edges.len(), 2);
        assert_eq!(g.edges[0].source, 0);
        assert_eq!(g.edges[1].source, 0);
    }

    #[test]
    fn edge_bidirectional() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        g.add_node("b".into(), 0.0, 0.0, 0, 1, "B".into());

        g.add_edge("a", "b", 1.0, 0);
        g.add_edge("b", "a", 1.0, 0);

        assert_eq!(g.edges.len(), 2);
        assert_eq!(g.edges[0].source, 0);
        assert_eq!(g.edges[0].target, 1);
        assert_eq!(g.edges[1].source, 1);
        assert_eq!(g.edges[1].target, 0);
    }

    #[test]
    fn parallel_edges_do_not_inflate_unique_link_count() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 0, "A".into());
        g.add_node("b".into(), 0.0, 0.0, 0, 0, "B".into());

        g.add_edge("a", "b", 1.0, 0);
        g.add_edge("b", "a", 0.5, 1);

        assert_eq!(g.nodes[0].link_count, 1);
        assert_eq!(g.nodes[1].link_count, 1);
        assert_eq!(g.nodes[0].radius, radius_for_link_count(1));
        assert_eq!(g.nodes[1].radius, radius_for_link_count(1));
    }

    #[test]
    fn edge_add_refreshes_neighbor_link_counts() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 0, "A".into());
        g.add_node("b".into(), 0.0, 0.0, 0, 0, "B".into());
        g.add_node("c".into(), 0.0, 0.0, 0, 0, "C".into());

        g.add_edge("a", "b", 1.0, 0);
        g.add_edge("b", "c", 1.0, 0);

        assert_eq!(g.nodes[0].link_count, 1);
        assert_eq!(g.nodes[1].link_count, 2);
        assert_eq!(g.nodes[2].link_count, 1);
        assert_eq!(g.nodes[1].radius, radius_for_link_count(2));
    }

    #[test]
    fn edge_self_loop() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());

        g.add_edge("a", "a", 1.0, 0);

        assert_eq!(g.edges.len(), 1);
        assert_eq!(g.edges[0].source, 0);
        assert_eq!(g.edges[0].target, 0);
    }

    #[test]
    fn edge_source_target_distinct() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        g.add_node("b".into(), 0.0, 0.0, 0, 1, "B".into());

        g.add_edge("a", "b", 1.0, 0);

        // Edge source and target are distinct
        assert_ne!(g.edges[0].source, g.edges[0].target);
    }

    // =========================================================================
    // Graph Construction Tests (10 tests)
    // =========================================================================

    #[test]
    fn graph_empty_new() {
        let g = Graph::new();
        assert!(g.nodes.is_empty());
        assert!(g.edges.is_empty());
        assert!(g.uuid_to_id.is_empty());
        assert!(g.id_to_index.is_empty());
    }

    #[test]
    fn graph_default_same_as_new() {
        let g_default = Graph::default();
        let g_new = Graph::new();

        assert_eq!(g_default.nodes.len(), g_new.nodes.len());
        assert_eq!(g_default.edges.len(), g_new.edges.len());
    }

    #[test]
    fn graph_add_node_increments_id() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        g.add_node("b".into(), 0.0, 0.0, 0, 1, "B".into());
        g.add_node("c".into(), 0.0, 0.0, 0, 1, "C".into());

        assert_eq!(g.nodes[0].id, 0);
        assert_eq!(g.nodes[1].id, 1);
        assert_eq!(g.nodes[2].id, 2);
    }

    #[test]
    fn graph_uuid_to_id_mapping() {
        let mut g = Graph::new();
        g.add_node("uuid-a".into(), 0.0, 0.0, 0, 1, "A".into());
        g.add_node("uuid-b".into(), 0.0, 0.0, 0, 1, "B".into());

        assert_eq!(g.uuid_to_id.get("uuid-a"), Some(&0));
        assert_eq!(g.uuid_to_id.get("uuid-b"), Some(&1));
    }

    #[test]
    fn graph_id_to_index_mapping() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        g.add_node("b".into(), 0.0, 0.0, 0, 1, "B".into());

        assert_eq!(g.id_to_index.get(&0), Some(&0));
        assert_eq!(g.id_to_index.get(&1), Some(&1));
    }

    #[test]
    fn graph_clear_resets_all() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        g.add_node("b".into(), 0.0, 0.0, 0, 1, "B".into());
        g.add_edge("a", "b", 1.0, 0);

        g.clear();

        assert!(g.nodes.is_empty());
        assert!(g.edges.is_empty());
        assert!(g.uuid_to_id.is_empty());
        assert!(g.id_to_index.is_empty());
        assert_eq!(g.next_id, 0);
    }

    #[test]
    fn graph_multiple_nodes() {
        let mut g = Graph::new();
        for i in 0..100 {
            g.add_node(
                format!("node-{}", i),
                i as f32,
                i as f32,
                0,
                1,
                format!("Node {}", i),
            );
        }

        assert_eq!(g.nodes.len(), 100);
        assert_eq!(g.uuid_to_id.len(), 100);
    }

    #[test]
    fn graph_multiple_edges() {
        let mut g = Graph::new();
        for i in 0..10 {
            g.add_node(format!("node-{}", i), 0.0, 0.0, 0, 1, format!("Node {}", i));
        }

        for i in 0..9 {
            g.add_edge(&format!("node-{}", i), &format!("node-{}", i + 1), 1.0, 0);
        }

        assert_eq!(g.edges.len(), 9);
    }

    #[test]
    fn graph_next_id_preserved_across_clear() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
        assert_eq!(g.next_id, 1);

        g.clear();
        assert_eq!(g.next_id, 0); // Reset after clear

        g.add_node("b".into(), 0.0, 0.0, 0, 1, "B".into());
        assert_eq!(g.next_id, 1);
        assert_eq!(g.nodes[0].id, 0);
    }

    // =========================================================================
    // Radius Calculation Tests (10 tests)
    // =========================================================================

    #[test]
    fn radius_zero_treated_as_one() {
        assert_eq!(radius_for_link_count(0), BASE_RADIUS);
    }

    #[test]
    fn radius_one() {
        assert_eq!(radius_for_link_count(1), BASE_RADIUS);
    }

    #[test]
    fn radius_eight() {
        // cbrt(8) * 8 = 2 * 8 = 16
        let r = radius_for_link_count(8);
        assert!((r - 16.0).abs() < 0.01, "Expected 16.0, got {}", r);
    }

    #[test]
    fn radius_twenty_seven() {
        // cbrt(27) * 8 = 3 * 8 = 24
        let r = radius_for_link_count(27);
        assert!((r - 24.0).abs() < 0.01, "Expected 24.0, got {}", r);
    }

    #[test]
    fn radius_sixty_four() {
        // cbrt(64) * 8 = 4 * 8 = 32
        let r = radius_for_link_count(64);
        assert!((r - 32.0).abs() < 0.01, "Expected 32.0, got {}", r);
    }

    #[test]
    fn radius_clamps_to_max() {
        // Very large values should clamp to MAX_RADIUS
        assert_eq!(radius_for_link_count(1000), MAX_RADIUS);
        assert_eq!(radius_for_link_count(10000), MAX_RADIUS);
        assert_eq!(radius_for_link_count(100000), MAX_RADIUS);
    }

    #[test]
    fn radius_clamps_to_min() {
        // Zero is treated as 1, which gives BASE_RADIUS > MIN_RADIUS
        // So we just verify MIN_RADIUS is respected at the lower bound
        assert!(radius_for_link_count(0) >= MIN_RADIUS);
        assert!(radius_for_link_count(1) >= MIN_RADIUS);
    }

    #[test]
    fn radius_monotonic_with_link_count() {
        // Radius should generally increase with link count (though clamped)
        let r1 = radius_for_link_count(1);
        let r8 = radius_for_link_count(8);
        let r27 = radius_for_link_count(27);
        let r64 = radius_for_link_count(64);

        assert!(r1 < r8);
        assert!(r8 < r27);
        assert!(r27 < r64);
    }

    #[test]
    fn radius_in_node_construction() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 8, "A".into());
        g.add_node("b".into(), 0.0, 0.0, 0, 27, "B".into());

        // Radius is computed from link_count
        assert!((g.nodes[0].radius - 16.0).abs() < 0.1);
        assert!((g.nodes[1].radius - 24.0).abs() < 0.1);
    }

    #[test]
    fn radius_values_in_valid_range() {
        for i in 0..=1000 {
            let r = radius_for_link_count(i);
            assert!(
                r >= MIN_RADIUS && r <= MAX_RADIUS,
                "Radius {} for link count {} out of range [{}, {}]",
                r,
                i,
                MIN_RADIUS,
                MAX_RADIUS
            );
        }
    }

    // =========================================================================
    // Edge Color Tests (10 tests)
    // =========================================================================

    #[test]
    fn edge_type_colors_all_valid() {
        // All 12 types should return non-zero alpha
        for t in 0..=11u8 {
            let c = edge_type_color(t);
            assert!(c[3] > 0.0, "alpha should be > 0 for type {}", t);
        }
    }

    #[test]
    fn edge_type_color_default_for_invalid() {
        // Unknown type should return default gray
        let def = edge_type_color(255);
        assert!(def[3] > 0.0);
        assert_eq!(def, [0.55, 0.55, 0.60, 0.30]);
    }

    #[test]
    fn edge_type_colors_opaque_enough() {
        // All valid types should have reasonable opacity
        for t in 0..=11u8 {
            let c = edge_type_color(t);
            assert!(
                c[3] >= 0.3 && c[3] <= 0.55,
                "Dark mode alpha out of range for type {}",
                t
            );
        }
    }

    #[test]
    fn edge_type_colors_rgba_in_range() {
        for t in 0..=11u8 {
            let c = edge_type_color(t);
            for i in 0..4 {
                assert!(
                    c[i] >= 0.0 && c[i] <= 1.0,
                    "Color component out of [0,1] range"
                );
            }
        }
    }

    #[test]
    fn edge_type_colors_distinct() {
        // Some edge types should have distinct colors
        let c0 = edge_type_color(0);
        let c4 = edge_type_color(4);
        let c9 = edge_type_color(9);

        assert_ne!(c0, c4);
        assert_ne!(c4, c9);
        assert_ne!(c0, c9);
    }

    #[test]
    fn edge_type_color_reference() {
        let c = edge_type_color(0);
        assert_eq!(c, [0.55, 0.55, 0.60, 0.35]);
    }

    #[test]
    fn edge_type_color_contradicts() {
        let c = edge_type_color(9);
        assert_eq!(c, [0.95, 0.25, 0.25, 0.50]);
    }

    #[test]
    fn edge_type_color_supports() {
        let c = edge_type_color(8);
        assert_eq!(c, [0.30, 0.90, 0.40, 0.50]);
    }

    #[test]
    fn light_mode_edge_colors_stay_dark_on_bright_canvas() {
        for t in 0..=11u8 {
            let c = edge_type_color_light(t);
            let max_channel = c[0].max(c[1]).max(c[2]);
            assert!(
                max_channel <= 0.34,
                "Light mode edge color for type {} is still too bright: {:?}",
                t,
                c
            );
            assert!(
                c[3] >= 0.82,
                "Light mode alpha should stay high for type {}",
                t
            );
        }
    }

    // =========================================================================
    // Memory Layout Tests (5 tests)
    // =========================================================================

    #[test]
    fn node_size_reasonable() {
        // Ensure Node isn't unexpectedly large
        let size = std::mem::size_of::<Node>();
        // Node contains a String (3 words) plus fields, should be < 200 bytes
        assert!(size < 200, "Node size {} seems too large", size);
    }

    #[test]
    fn edge_size_reasonable() {
        let size = std::mem::size_of::<Edge>();
        // Edge should be small (u32, u32, f32, u8 + padding)
        assert!(size <= 24, "Edge size {} seems too large", size);
    }

    #[test]
    fn graph_size_reasonable() {
        let size = std::mem::size_of::<Graph>();
        // Graph contains vectors and hashmaps
        assert!(size < 500, "Graph size {} seems too large", size);
    }

    #[test]
    fn node_type_size_is_u8() {
        assert_eq!(std::mem::size_of::<NodeType>(), 1);
    }

    #[test]
    fn node_alignment() {
        let align = std::mem::align_of::<Node>();
        assert!(align <= 8, "Node alignment {} seems too large", align);
    }

    // =========================================================================
    // VisualTheme Tests (3 tests)
    // =========================================================================

    #[test]
    fn test_visual_theme_from_u8() {
        assert_eq!(VisualTheme::from_u8(0), VisualTheme::Dialogue);
        assert_eq!(VisualTheme::from_u8(1), VisualTheme::Classic);
        assert_eq!(VisualTheme::from_u8(255), VisualTheme::Dialogue); // default
    }

    // =========================================================================
    // Graph Remove Tests (8 tests)
    // =========================================================================

    #[test]
    fn remove_node_basic() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 0, "A".into());
        g.add_node("b".into(), 1.0, 0.0, 0, 0, "B".into());
        g.add_node("c".into(), 2.0, 0.0, 0, 0, "C".into());
        assert!(g.remove_node("b"));
        assert_eq!(g.nodes.len(), 2);
        assert!(g.uuid_to_id.get("b").is_none());
        // a and c should still be reachable
        assert!(g.uuid_to_id.contains_key("a"));
        assert!(g.uuid_to_id.contains_key("c"));
    }

    #[test]
    fn remove_node_cleans_edges() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 0, "A".into());
        g.add_node("b".into(), 1.0, 0.0, 0, 0, "B".into());
        g.add_node("c".into(), 2.0, 0.0, 0, 0, "C".into());
        g.add_edge("a", "b", 1.0, 0);
        g.add_edge("b", "c", 1.0, 0);
        assert_eq!(g.edges.len(), 2);
        g.remove_node("b");
        assert_eq!(g.edges.len(), 0); // both edges touched b
    }

    #[test]
    fn remove_node_refreshes_neighbor_link_counts() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 0, "A".into());
        g.add_node("b".into(), 1.0, 0.0, 0, 0, "B".into());
        g.add_node("c".into(), 2.0, 0.0, 0, 0, "C".into());
        g.add_edge("a", "b", 1.0, 0);
        g.add_edge("b", "c", 1.0, 0);

        assert!(g.remove_node("b"));

        assert_eq!(g.nodes.len(), 2);
        assert_eq!(g.nodes[0].link_count, 0);
        assert_eq!(g.nodes[1].link_count, 0);
        assert_eq!(g.nodes[0].radius, radius_for_link_count(0));
        assert_eq!(g.nodes[1].radius, radius_for_link_count(0));
    }

    #[test]
    fn remove_node_swap_fixup() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 0, "A".into());
        g.add_node("b".into(), 1.0, 0.0, 0, 0, "B".into());
        g.add_node("c".into(), 2.0, 0.0, 0, 0, "C".into());
        let c_id = *g.uuid_to_id.get("c").unwrap();
        // Remove a (index 0) → c swaps into index 0
        g.remove_node("a");
        assert_eq!(*g.id_to_index.get(&c_id).unwrap(), 0);
        assert_eq!(g.nodes[0].uuid, "c");
    }

    #[test]
    fn remove_node_nonexistent() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 0, "A".into());
        assert!(!g.remove_node("zzz"));
        assert_eq!(g.nodes.len(), 1);
    }

    #[test]
    fn remove_node_last_element() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 0, "A".into());
        g.add_node("b".into(), 1.0, 0.0, 0, 0, "B".into());
        // Remove last element — no swap needed
        assert!(g.remove_node("b"));
        assert_eq!(g.nodes.len(), 1);
        assert_eq!(g.nodes[0].uuid, "a");
    }

    #[test]
    fn remove_edges_basic() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 0, "A".into());
        g.add_node("b".into(), 1.0, 0.0, 0, 0, "B".into());
        g.add_edge("a", "b", 1.0, 0);
        assert_eq!(g.remove_edges("a", "b"), 1);
        assert!(g.edges.is_empty());
    }

    #[test]
    fn remove_edges_bidirectional() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 0, "A".into());
        g.add_node("b".into(), 1.0, 0.0, 0, 0, "B".into());
        g.add_edge("a", "b", 1.0, 0);
        g.add_edge("b", "a", 0.5, 1);
        assert_eq!(g.remove_edges("a", "b"), 2);
        assert!(g.edges.is_empty());
    }

    #[test]
    fn remove_edges_refreshes_link_counts_after_pair_removal() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 0, "A".into());
        g.add_node("b".into(), 1.0, 0.0, 0, 0, "B".into());
        g.add_node("c".into(), 2.0, 0.0, 0, 0, "C".into());
        g.add_edge("a", "b", 1.0, 0);
        g.add_edge("b", "a", 0.5, 1);
        g.add_edge("b", "c", 1.0, 0);

        assert_eq!(g.remove_edges("a", "b"), 2);

        assert_eq!(g.nodes[0].link_count, 0);
        assert_eq!(g.nodes[1].link_count, 1);
        assert_eq!(g.nodes[2].link_count, 1);
        assert_eq!(g.nodes[1].radius, radius_for_link_count(1));
    }

    #[test]
    fn remove_edges_no_match() {
        let mut g = Graph::new();
        g.add_node("a".into(), 0.0, 0.0, 0, 0, "A".into());
        g.add_node("b".into(), 1.0, 0.0, 0, 0, "B".into());
        assert_eq!(g.remove_edges("a", "b"), 0);
        // Non-existent nodes
        assert_eq!(g.remove_edges("x", "y"), 0);
    }
}
