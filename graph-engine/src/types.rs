use glam::Vec2;
use rustc_hash::FxHashMap;

/// Node type enum — mirrors Swift GraphNodeType (13 types)
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum NodeType {
    Note = 0,
    Folder = 1,
    Idea = 2,
    BrainDump = 3,
    Chat = 4,
    Insight = 5,
    Thinker = 6,
    Paper = 7,
    Book = 8,
    Source = 9,
    Concept = 10,
    Tag = 11,
    Quote = 12,
}

impl NodeType {
    pub fn from_u8(v: u8) -> Self {
        match v {
            0 => Self::Note,
            1 => Self::Folder,
            2 => Self::Idea,
            3 => Self::BrainDump,
            4 => Self::Chat,
            5 => Self::Insight,
            6 => Self::Thinker,
            7 => Self::Paper,
            8 => Self::Book,
            9 => Self::Source,
            10 => Self::Concept,
            11 => Self::Tag,
            12 => Self::Quote,
            _ => Self::Note,
        }
    }

    /// RGBA color for this node type.
    pub fn color(&self) -> [f32; 4] {
        match self {
            Self::Note => [0.39, 0.90, 0.85, 1.0],
            Self::Folder => [0.64, 0.52, 0.37, 1.0],
            Self::Idea => [1.00, 0.84, 0.04, 1.0],
            Self::BrainDump => [0.35, 0.34, 0.84, 1.0],
            Self::Chat => [1.00, 0.62, 0.04, 1.0],
            Self::Insight => [0.69, 0.32, 0.87, 1.0],
            Self::Thinker => [1.00, 0.18, 0.33, 1.0],
            Self::Paper => [0.20, 0.78, 0.35, 1.0],
            Self::Book => [0.25, 0.78, 0.76, 1.0],
            Self::Source => [0.56, 0.56, 0.58, 1.0],
            Self::Concept => [0.39, 0.82, 1.00, 1.0],
            Self::Tag => [0.46, 0.46, 0.50, 1.0],
            Self::Quote => [1.00, 0.84, 0.04, 1.0],
        }
    }
}

#[derive(Clone)]
pub struct Node {
    pub id: u32,
    pub uuid: String,
    pub pos: Vec2,
    pub vel: Vec2,
    pub node_type: NodeType,
    pub weight: f32,
    pub label: String,
    pub radius: f32,
}

impl Node {
    pub fn radius_for_weight(weight: f32) -> f32 {
        if weight > 10.0 {
            22.0
        } else if weight > 3.0 {
            14.0
        } else {
            8.0
        }
    }
}

#[derive(Clone)]
pub struct Edge {
    pub source: u32,
    pub target: u32,
    pub edge_type: u8,
    pub weight: f32,
}

pub struct Graph {
    pub nodes: Vec<Node>,
    pub edges: Vec<Edge>,
    pub uuid_to_id: FxHashMap<String, u32>,
    pub id_to_index: FxHashMap<u32, usize>,
    next_id: u32,
}

impl Graph {
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
        weight: f32,
        label: String,
    ) {
        let id = self.next_id;
        self.next_id += 1;
        let radius = Node::radius_for_weight(weight);
        let node = Node {
            id,
            uuid: uuid.clone(),
            pos: Vec2::new(x, y),
            vel: Vec2::ZERO,
            node_type: NodeType::from_u8(node_type),
            weight,
            label,
            radius,
        };
        let index = self.nodes.len();
        self.uuid_to_id.insert(uuid, id);
        self.id_to_index.insert(id, index);
        self.nodes.push(node);
    }

    pub fn add_edge(&mut self, source_uuid: &str, target_uuid: &str, edge_type: u8, weight: f32) {
        if let (Some(&src), Some(&tgt)) = (
            self.uuid_to_id.get(source_uuid),
            self.uuid_to_id.get(target_uuid),
        ) {
            self.edges.push(Edge {
                source: src,
                target: tgt,
                edge_type,
                weight,
            });
        }
    }
}
