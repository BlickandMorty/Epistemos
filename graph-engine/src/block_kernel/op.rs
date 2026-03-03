use std::fmt;

/// Stable block identifier. 128-bit UUID as [u8; 16] for FFI compatibility.
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
#[repr(C)]
pub struct BlockId(pub [u8; 16]);

impl BlockId {
    pub fn new() -> Self {
        // Use simple counter + timestamp for uniqueness.
        // No external dependency needed.
        use std::sync::atomic::{AtomicU64, Ordering};
        use std::time::{SystemTime, UNIX_EPOCH};
        static COUNTER: AtomicU64 = AtomicU64::new(0);
        let ts = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos() as u64;
        let count = COUNTER.fetch_add(1, Ordering::Relaxed);
        let mut bytes = [0u8; 16];
        bytes[..8].copy_from_slice(&ts.to_le_bytes());
        bytes[8..].copy_from_slice(&count.to_le_bytes());
        Self(bytes)
    }

    pub fn from_uuid_string(s: &str) -> Option<Self> {
        // Parse "550e8400-e29b-41d4-a716-446655440000" format
        let hex: String = s.chars().filter(|c| c.is_ascii_hexdigit()).collect();
        if hex.len() != 32 { return None; }
        let mut bytes = [0u8; 16];
        for i in 0..16 {
            bytes[i] = u8::from_str_radix(&hex[i*2..i*2+2], 16).ok()?;
        }
        Some(Self(bytes))
    }

    pub fn to_uuid_string(&self) -> String {
        format!(
            "{:02x}{:02x}{:02x}{:02x}-{:02x}{:02x}-{:02x}{:02x}-{:02x}{:02x}-{:02x}{:02x}{:02x}{:02x}{:02x}{:02x}",
            self.0[0], self.0[1], self.0[2], self.0[3],
            self.0[4], self.0[5], self.0[6], self.0[7],
            self.0[8], self.0[9], self.0[10], self.0[11],
            self.0[12], self.0[13], self.0[14], self.0[15]
        )
    }
}

impl Default for BlockId {
    fn default() -> Self {
        Self::new()
    }
}

impl fmt::Debug for BlockId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "BlockId({})", &self.to_uuid_string()[..8])
    }
}

/// A single atomic operation on the block tree.
#[derive(Clone, Debug)]
pub enum Op {
    /// Insert a new block with given content.
    InsertBlock {
        block_id: BlockId,
        parent_id: Option<BlockId>,
        position: u32,  // Order among siblings
        content: String,
        depth: u16,
    },
    /// Delete a block. Children are reparented to the deleted block's parent.
    DeleteBlock {
        block_id: BlockId,
    },
    /// Update block content (any amount of change — ID is preserved).
    UpdateBlock {
        block_id: BlockId,
        content: String,
    },
    /// Split a block at a character offset, creating a new block after it.
    SplitBlock {
        block_id: BlockId,
        offset: u32,          // UTF-8 byte offset within content
        new_block_id: BlockId,
    },
    /// Merge a block into the preceding block (append content).
    MergeBlock {
        block_id: BlockId,
        into_id: BlockId,
    },
    /// Move a block (and its children) to a new parent/position.
    MoveSubtree {
        block_id: BlockId,
        new_parent: Option<BlockId>,
        position: u32,
    },
    /// Set a metadata property on a block (type, confidence, tag, etc.).
    SetProperty {
        block_id: BlockId,
        key: String,
        value: PropertyValue,
    },
    /// Create/update an edge relationship from this block to a target.
    SetRef {
        block_id: BlockId,
        target_id: BlockId,
        ref_type: u8, // Maps to GraphEdgeType
    },
}

#[derive(Clone, Debug, PartialEq)]
pub enum PropertyValue {
    String(String),
    Float(f32),
    Int(i64),
    Bool(bool),
    Null, // Remove property
}
