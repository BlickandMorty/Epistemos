use rkyv::{Archive, Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Archive, Serialize, Deserialize)]
#[repr(u16)]
#[rkyv(derive(Debug))]
pub enum SubscriptionKind {
    Outline = 1,
    Tasks = 2,
    Properties = 3,
    Links = 4,
}

impl SubscriptionKind {
    pub const fn code(self) -> u16 {
        self as u16
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Archive, Serialize, Deserialize)]
#[rkyv(compare(PartialEq), derive(Debug))]
pub struct BlockRow {
    pub page_id: String,
    pub block_id: String,
    pub parent_id: String,
    pub order_key: String,
    pub depth: u16,
    pub content: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Archive, Serialize, Deserialize)]
#[rkyv(compare(PartialEq), derive(Debug))]
pub struct TaskRow {
    pub page_id: String,
    pub block_id: String,
    pub marker: String,
    pub done: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Archive, Serialize, Deserialize)]
#[rkyv(compare(PartialEq), derive(Debug))]
pub struct PropertyRow {
    pub page_id: String,
    pub block_id: String,
    pub key: String,
    pub value: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Archive, Serialize, Deserialize)]
#[rkyv(compare(PartialEq), derive(Debug))]
pub struct LinkRow {
    pub page_id: String,
    pub block_id: String,
    pub target_id: String,
    pub ref_type: u8,
}

#[derive(Clone, Debug, PartialEq, Eq, Archive, Serialize, Deserialize)]
#[rkyv(compare(PartialEq), derive(Debug))]
pub enum QueryRow {
    Block(BlockRow),
    Task(TaskRow),
    Property(PropertyRow),
    Link(LinkRow),
}

impl QueryRow {
    pub fn identity(&self) -> String {
        match self {
            Self::Block(row) => format!("block|{}|{}|{}", row.page_id, row.block_id, row.parent_id),
            Self::Task(row) => format!("task|{}|{}", row.page_id, row.block_id),
            Self::Property(row) => format!("prop|{}|{}|{}", row.page_id, row.block_id, row.key),
            Self::Link(row) => format!(
                "link|{}|{}|{}|{}",
                row.page_id, row.block_id, row.target_id, row.ref_type
            ),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Archive, Serialize, Deserialize)]
#[rkyv(derive(Debug))]
pub struct QueryDiffEnvelope {
    pub tx_id: u64,
    pub subscription_id: u64,
    pub kind: SubscriptionKind,
    pub added: Vec<QueryRow>,
    pub updated: Vec<QueryRow>,
    pub removed: Vec<QueryRow>,
}
