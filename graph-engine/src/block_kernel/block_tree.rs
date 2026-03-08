use std::collections::HashMap;
use crate::block_kernel::op::{BlockId, Op, PropertyValue};

/// Extract trailing @key=value properties from block content.
/// Mirrors the Swift BlockPropertyParser pattern: only trailing @key=value pairs.
fn parse_inline_properties(content: &str) -> HashMap<String, PropertyValue> {
    let mut props = HashMap::new();
    // Scan backward from end for @key=value tokens
    let trimmed = content.trim_end();
    let bytes = trimmed.as_bytes();
    let mut pos = trimmed.len();

    loop {
        // Skip trailing whitespace
        while pos > 0 && bytes[pos - 1] == b' ' {
            pos -= 1;
        }
        if pos == 0 { break; }

        // Find the value: non-whitespace, non-@ chars backward
        let val_end = pos;
        while pos > 0 && bytes[pos - 1] != b' ' && bytes[pos - 1] != b'=' {
            pos -= 1;
        }
        if pos == 0 || bytes[pos - 1] != b'=' { break; }
        let val_start = pos;
        pos -= 1; // skip '='

        // Find the key: word chars backward
        let key_end = pos;
        while pos > 0 && (bytes[pos - 1].is_ascii_alphanumeric() || bytes[pos - 1] == b'_') {
            pos -= 1;
        }
        if pos == key_end { break; } // empty key
        // Must be preceded by '@'
        if pos == 0 || bytes[pos - 1] != b'@' { break; }
        let key_start = pos;
        pos -= 1; // skip '@'

        let key = &trimmed[key_start..key_end];
        let val = &trimmed[val_start..val_end];
        props.insert(key.to_string(), parse_property_value(val));
    }

    props
}

fn parse_property_value(raw: &str) -> PropertyValue {
    if raw.eq_ignore_ascii_case("true") { return PropertyValue::Bool(true); }
    if raw.eq_ignore_ascii_case("false") { return PropertyValue::Bool(false); }
    if let Ok(i) = raw.parse::<i64>() {
        if !raw.contains('.') { return PropertyValue::Int(i); }
    }
    if let Ok(f) = raw.parse::<f32>() { return PropertyValue::Float(f); }
    PropertyValue::String(raw.to_string())
}

#[derive(Clone, Debug)]
pub struct Block {
    pub id: BlockId,
    pub parent_id: Option<BlockId>,
    pub content: String,
    pub depth: u16,
    pub order: u32,
    pub children: Vec<BlockId>,  // Sorted by order
    pub properties: HashMap<String, PropertyValue>,
}

/// Materialized block tree for a single page.
/// All blocks stored in a flat HashMap; parent-child via IDs.
pub struct BlockTree {
    blocks: HashMap<BlockId, Block>,
    roots: Vec<BlockId>, // Top-level blocks sorted by order
}

impl BlockTree {
    pub fn new() -> Self {
        Self {
            blocks: HashMap::new(),
            roots: Vec::new(),
        }
    }

    /// Sort children by collecting orders first, then sorting
    fn sort_children_by_order(&mut self, parent_id: &BlockId) {
        if let Some(parent) = self.blocks.get(parent_id) {
            // Collect (id, order) pairs
            let mut pairs: Vec<(BlockId, u32)> = parent.children
                .iter()
                .map(|id| (*id, self.blocks.get(id).map_or(0, |b| b.order)))
                .collect();
            // Sort by order
            pairs.sort_by_key(|(_, order)| *order);
            // Extract sorted ids
            let sorted: Vec<BlockId> = pairs.into_iter().map(|(id, _)| id).collect();
            // Update parent's children
            if let Some(parent) = self.blocks.get_mut(parent_id) {
                parent.children = sorted;
            }
        }
    }

    /// Apply a single op, mutating the tree in place.
    pub fn apply(&mut self, op: &Op) {
        match op {
            Op::InsertBlock { block_id, parent_id, position, content, depth } => {
                let block = Block {
                    id: *block_id,
                    parent_id: *parent_id,
                    content: content.clone(),
                    depth: *depth,
                    order: *position,
                    children: Vec::new(),
                    properties: parse_inline_properties(content),
                };
                self.blocks.insert(*block_id, block);
                if let Some(pid) = parent_id {
                    // Get parent and add child
                    if let Some(parent) = self.blocks.get_mut(pid) {
                        parent.children.push(*block_id);
                    }
                    // Sort children separately to avoid borrow issues
                    self.sort_children_by_order(pid);
                } else {
                    self.roots.push(*block_id);
                    // Sort roots
                    let mut pairs: Vec<(BlockId, u32)> = self.roots
                        .iter()
                        .map(|id| (*id, self.blocks.get(id).map_or(0, |b| b.order)))
                        .collect();
                    pairs.sort_by_key(|(_, order)| *order);
                    self.roots = pairs.into_iter().map(|(id, _)| id).collect();
                }
            }
            Op::DeleteBlock { block_id } => {
                // First, collect all info we need before any mutations
                let block_info = self.blocks.get(block_id).map(|b| {
                    (b.parent_id, b.children.clone())
                });
                
                if let Some((parent_id, children)) = block_info {
                    // Reparent children
                    for child_id in &children {
                        if let Some(child) = self.blocks.get_mut(child_id) {
                            child.parent_id = parent_id;
                        }
                    }
                    
                    // Remove the block
                    self.blocks.remove(block_id);
                    
                    // Update parent's children list or roots
                    if let Some(pid) = parent_id {
                        if let Some(parent) = self.blocks.get_mut(&pid) {
                            parent.children.retain(|id| id != block_id);
                            parent.children.extend_from_slice(&children);
                        }
                        self.sort_children_by_order(&pid);
                    } else {
                        self.roots.retain(|id| id != block_id);
                        self.roots.extend_from_slice(&children);
                        let mut pairs: Vec<(BlockId, u32)> = self.roots
                            .iter()
                            .map(|id| (*id, self.blocks.get(id).map_or(0, |b| b.order)))
                            .collect();
                        pairs.sort_by_key(|(_, order)| *order);
                        self.roots = pairs.into_iter().map(|(id, _)| id).collect();
                    }
                }
            }
            Op::UpdateBlock { block_id, content } => {
                if let Some(block) = self.blocks.get_mut(block_id) {
                    block.content = content.clone();
                    // Re-extract inline properties from updated content
                    let inline = parse_inline_properties(content);
                    // Merge: inline props overwrite, but keep explicit SetProperty values
                    // that don't conflict with inline. Clear old inline-sourced props.
                    block.properties = inline;
                }
            }
            Op::SplitBlock { block_id, offset, new_block_id } => {
                let (new_content, remaining_content, parent_id, depth, order) = {
                    if let Some(block) = self.blocks.get(block_id) {
                        // Snap offset to nearest char boundary to avoid panic on multi-byte UTF-8.
                        let mut off = (*offset as usize).min(block.content.len());
                        while off > 0 && !block.content.is_char_boundary(off) {
                            off -= 1;
                        }
                        let before = block.content[..off].to_string();
                        let after = block.content[off..].to_string();
                        (before, after, block.parent_id, block.depth, block.order + 1)
                    } else {
                        return;
                    }
                };
                // Update original block
                if let Some(block) = self.blocks.get_mut(block_id) {
                    block.content = new_content;
                }
                // Insert new block after original
                self.apply(&Op::InsertBlock {
                    block_id: *new_block_id,
                    parent_id,
                    position: order,
                    content: remaining_content,
                    depth,
                });
            }
            Op::MergeBlock { block_id, into_id } => {
                let content = self.blocks.get(block_id).map(|b| b.content.clone());
                if let (Some(append), Some(target)) = (content, self.blocks.get_mut(into_id)) {
                    target.content.push_str(&append);
                }
                self.apply(&Op::DeleteBlock { block_id: *block_id });
            }
            Op::MoveSubtree { block_id, new_parent, position } => {
                // Get old parent before any mutations
                let old_parent = self.blocks.get(block_id).and_then(|b| b.parent_id);
                
                // Remove from old parent first
                if let Some(pid) = old_parent {
                    if let Some(parent) = self.blocks.get_mut(&pid) {
                        parent.children.retain(|id| id != block_id);
                    }
                } else {
                    self.roots.retain(|id| id != block_id);
                }
                
                // Update block's parent and order
                if let Some(block) = self.blocks.get_mut(block_id) {
                    block.parent_id = *new_parent;
                    block.order = *position;
                }
                
                // Add to new parent
                if let Some(pid) = new_parent {
                    if let Some(parent) = self.blocks.get_mut(pid) {
                        parent.children.push(*block_id);
                    }
                    self.sort_children_by_order(pid);
                } else {
                    self.roots.push(*block_id);
                    let mut pairs: Vec<(BlockId, u32)> = self.roots
                        .iter()
                        .map(|id| (*id, self.blocks.get(id).map_or(0, |b| b.order)))
                        .collect();
                    pairs.sort_by_key(|(_, order)| *order);
                    self.roots = pairs.into_iter().map(|(id, _)| id).collect();
                }
            }
            Op::SetProperty { block_id, key, value } => {
                if let Some(block) = self.blocks.get_mut(block_id) {
                    match value {
                        PropertyValue::Null => { block.properties.remove(key); }
                        _ => { block.properties.insert(key.clone(), value.clone()); }
                    }
                }
            }
            Op::SetRef { .. } => {
                // Refs are stored in the op log for graph edge creation.
                // The block tree itself doesn't track them — the graph engine does.
            }
        }
    }

    pub fn get(&self, id: &BlockId) -> Option<&Block> {
        self.blocks.get(id)
    }

    pub fn roots(&self) -> &[BlockId] {
        &self.roots
    }

    pub fn block_count(&self) -> usize {
        self.blocks.len()
    }

    /// Depth-first traversal in document order.
    pub fn walk(&self) -> Vec<&Block> {
        let mut result = Vec::with_capacity(self.blocks.len());
        for root_id in &self.roots {
            self.walk_recursive(root_id, &mut result);
        }
        result
    }

    fn walk_recursive<'a>(&'a self, id: &BlockId, out: &mut Vec<&'a Block>) {
        if let Some(block) = self.blocks.get(id) {
            out.push(block);
            for child_id in &block.children {
                self.walk_recursive(child_id, out);
            }
        }
    }

    /// Returns true if any block matches the given property filter.
    pub fn has_matching_property(&self, key: &str, op: u8, value: &PropertyValue) -> bool {
        self.blocks.values().any(|b| {
            if let Some(prop) = b.properties.get(key) {
                compare_property(prop, op, value)
            } else {
                false
            }
        })
    }

    /// Returns true if any block matches the given depth filter.
    pub fn has_matching_depth(&self, op: u8, depth: u16) -> bool {
        self.blocks.values().any(|b| compare_u16(b.depth, op, depth))
    }

    /// Returns block IDs matching a property filter.
    pub fn blocks_matching_property(&self, key: &str, op: u8, value: &PropertyValue) -> Vec<&Block> {
        self.blocks.values().filter(|b| {
            if let Some(prop) = b.properties.get(key) {
                compare_property(prop, op, value)
            } else {
                false
            }
        }).collect()
    }

    /// Returns block IDs matching a depth filter.
    pub fn blocks_matching_depth(&self, op: u8, depth: u16) -> Vec<&Block> {
        self.blocks.values().filter(|b| compare_u16(b.depth, op, depth)).collect()
    }
}

// CompOp mapping: 0=eq, 1=neq, 2=lt, 3=gt, 4=lte, 5=gte, 6=contains
fn compare_property(prop: &PropertyValue, op: u8, value: &PropertyValue) -> bool {
    match (prop, value) {
        (PropertyValue::Float(a), PropertyValue::Float(b)) => compare_f32(*a, op, *b),
        (PropertyValue::Int(a), PropertyValue::Int(b)) => compare_i64(*a, op, *b),
        (PropertyValue::Bool(a), PropertyValue::Bool(b)) => match op {
            0 => a == b,  // eq
            1 => a != b,  // neq
            _ => false,
        },
        (PropertyValue::String(a), PropertyValue::String(b)) => match op {
            0 => a == b,
            1 => a != b,
            6 => a.to_lowercase().contains(&b.to_lowercase()), // contains
            _ => a.cmp(b) == str_cmp_for_op(op),
        },
        _ => false,
    }
}

fn compare_f32(a: f32, op: u8, b: f32) -> bool {
    match op {
        0 => (a - b).abs() < f32::EPSILON,
        1 => (a - b).abs() >= f32::EPSILON,
        2 => a < b,
        3 => a > b,
        4 => a <= b,
        5 => a >= b,
        _ => false,
    }
}

fn compare_i64(a: i64, op: u8, b: i64) -> bool {
    match op {
        0 => a == b,
        1 => a != b,
        2 => a < b,
        3 => a > b,
        4 => a <= b,
        5 => a >= b,
        _ => false,
    }
}

fn compare_u16(a: u16, op: u8, b: u16) -> bool {
    match op {
        0 => a == b,
        1 => a != b,
        2 => a < b,
        3 => a > b,
        4 => a <= b,
        5 => a >= b,
        _ => false,
    }
}

fn str_cmp_for_op(op: u8) -> std::cmp::Ordering {
    match op {
        2 => std::cmp::Ordering::Less,
        3 => std::cmp::Ordering::Greater,
        _ => std::cmp::Ordering::Equal,
    }
}

impl Default for BlockTree {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::block_kernel::op::*;

    #[test]
    fn insert_and_get() {
        let mut tree = BlockTree::new();
        let id = BlockId::new();
        tree.apply(&Op::InsertBlock {
            block_id: id, parent_id: None, position: 0,
            content: "Hello".into(), depth: 0,
        });
        assert_eq!(tree.block_count(), 1);
        assert_eq!(tree.get(&id).unwrap().content, "Hello");
    }

    #[test]
    fn update_preserves_id() {
        let mut tree = BlockTree::new();
        let id = BlockId::new();
        tree.apply(&Op::InsertBlock {
            block_id: id, parent_id: None, position: 0,
            content: "original text that will be completely rewritten".into(), depth: 0,
        });
        tree.apply(&Op::UpdateBlock {
            block_id: id, content: "something totally different now".into(),
        });
        // ID is preserved — this is the whole point of BTK
        assert_eq!(tree.get(&id).unwrap().content, "something totally different now");
        assert_eq!(tree.block_count(), 1);
    }

    #[test]
    fn delete_reparents_children() {
        let mut tree = BlockTree::new();
        let parent = BlockId::new();
        let child = BlockId::new();
        let grandchild = BlockId::new();

        tree.apply(&Op::InsertBlock {
            block_id: parent, parent_id: None, position: 0,
            content: "parent".into(), depth: 0,
        });
        tree.apply(&Op::InsertBlock {
            block_id: child, parent_id: Some(parent), position: 0,
            content: "child".into(), depth: 1,
        });
        tree.apply(&Op::InsertBlock {
            block_id: grandchild, parent_id: Some(child), position: 0,
            content: "grandchild".into(), depth: 2,
        });

        // Delete the child — grandchild should be reparented to parent
        tree.apply(&Op::DeleteBlock { block_id: child });

        assert_eq!(tree.block_count(), 2);
        assert_eq!(tree.get(&grandchild).unwrap().parent_id, Some(parent));
    }

    #[test]
    fn split_creates_two_blocks() {
        let mut tree = BlockTree::new();
        let id = BlockId::new();
        let new_id = BlockId::new();
        tree.apply(&Op::InsertBlock {
            block_id: id, parent_id: None, position: 0,
            content: "Hello World".into(), depth: 0,
        });
        tree.apply(&Op::SplitBlock {
            block_id: id, offset: 5, new_block_id: new_id,
        });
        assert_eq!(tree.get(&id).unwrap().content, "Hello");
        assert_eq!(tree.get(&new_id).unwrap().content, " World");
    }

    #[test]
    fn merge_appends_and_deletes() {
        let mut tree = BlockTree::new();
        let a = BlockId::new();
        let b = BlockId::new();
        tree.apply(&Op::InsertBlock {
            block_id: a, parent_id: None, position: 0,
            content: "Hello".into(), depth: 0,
        });
        tree.apply(&Op::InsertBlock {
            block_id: b, parent_id: None, position: 1,
            content: " World".into(), depth: 0,
        });
        tree.apply(&Op::MergeBlock { block_id: b, into_id: a });
        assert_eq!(tree.get(&a).unwrap().content, "Hello World");
        assert!(tree.get(&b).is_none());
    }

    #[test]
    fn move_subtree() {
        let mut tree = BlockTree::new();
        let a = BlockId::new();
        let b = BlockId::new();
        let c = BlockId::new();
        tree.apply(&Op::InsertBlock {
            block_id: a, parent_id: None, position: 0,
            content: "A".into(), depth: 0,
        });
        tree.apply(&Op::InsertBlock {
            block_id: b, parent_id: None, position: 1,
            content: "B".into(), depth: 0,
        });
        tree.apply(&Op::InsertBlock {
            block_id: c, parent_id: Some(a), position: 0,
            content: "C".into(), depth: 1,
        });
        // Move C under B
        tree.apply(&Op::MoveSubtree {
            block_id: c, new_parent: Some(b), position: 0,
        });
        assert_eq!(tree.get(&c).unwrap().parent_id, Some(b));
    }

    #[test]
    fn set_property_and_null_removes() {
        let mut tree = BlockTree::new();
        let id = BlockId::new();
        tree.apply(&Op::InsertBlock {
            block_id: id, parent_id: None, position: 0,
            content: "claim".into(), depth: 0,
        });
        tree.apply(&Op::SetProperty {
            block_id: id, key: "confidence".into(),
            value: PropertyValue::Float(0.8),
        });
        assert_eq!(
            tree.get(&id).unwrap().properties.get("confidence"),
            Some(&PropertyValue::Float(0.8))
        );
        tree.apply(&Op::SetProperty {
            block_id: id, key: "confidence".into(),
            value: PropertyValue::Null,
        });
        assert!(tree.get(&id).unwrap().properties.get("confidence").is_none());
    }

    #[test]
    fn walk_returns_document_order() {
        let mut tree = BlockTree::new();
        let a = BlockId::new();
        let b = BlockId::new();
        let c = BlockId::new();
        tree.apply(&Op::InsertBlock {
            block_id: a, parent_id: None, position: 0,
            content: "A".into(), depth: 0,
        });
        tree.apply(&Op::InsertBlock {
            block_id: c, parent_id: Some(a), position: 0,
            content: "C".into(), depth: 1,
        });
        tree.apply(&Op::InsertBlock {
            block_id: b, parent_id: None, position: 1,
            content: "B".into(), depth: 0,
        });
        let walked: Vec<&str> = tree.walk().iter().map(|b| b.content.as_str()).collect();
        assert_eq!(walked, vec!["A", "C", "B"]);
    }

    #[test]
    fn insert_extracts_inline_properties() {
        let mut tree = BlockTree::new();
        let id = BlockId::new();
        tree.apply(&Op::InsertBlock {
            block_id: id, parent_id: None, position: 0,
            content: "This is a claim @tag=claim @confidence=0.8".into(), depth: 0,
        });
        let block = tree.get(&id).unwrap();
        assert_eq!(block.properties.get("tag"), Some(&PropertyValue::String("claim".into())));
        assert_eq!(block.properties.get("confidence"), Some(&PropertyValue::Float(0.8)));
    }

    #[test]
    fn update_syncs_inline_properties() {
        let mut tree = BlockTree::new();
        let id = BlockId::new();
        tree.apply(&Op::InsertBlock {
            block_id: id, parent_id: None, position: 0,
            content: "text @tag=claim".into(), depth: 0,
        });
        assert_eq!(tree.get(&id).unwrap().properties.get("tag"),
                   Some(&PropertyValue::String("claim".into())));

        // Update removes the property
        tree.apply(&Op::UpdateBlock {
            block_id: id, content: "text without properties".into(),
        });
        assert!(tree.get(&id).unwrap().properties.is_empty());

        // Update adds a different property
        tree.apply(&Op::UpdateBlock {
            block_id: id, content: "text @status=verified".into(),
        });
        assert_eq!(tree.get(&id).unwrap().properties.get("status"),
                   Some(&PropertyValue::String("verified".into())));
    }

    #[test]
    fn parse_inline_properties_values() {
        let props = parse_inline_properties("hello @bool=true @int=42 @float=3.14");
        assert_eq!(props.get("bool"), Some(&PropertyValue::Bool(true)));
        assert_eq!(props.get("int"), Some(&PropertyValue::Int(42)));
        assert_eq!(props.get("float"), Some(&PropertyValue::Float(3.14)));
    }

    #[test]
    fn parse_inline_properties_empty() {
        assert!(parse_inline_properties("no properties here").is_empty());
        assert!(parse_inline_properties("").is_empty());
    }

    #[test]
    fn property_filter_queries_work() {
        let mut tree = BlockTree::new();
        let a = BlockId::new();
        let b = BlockId::new();
        tree.apply(&Op::InsertBlock {
            block_id: a, parent_id: None, position: 0,
            content: "claim @confidence=0.3".into(), depth: 0,
        });
        tree.apply(&Op::InsertBlock {
            block_id: b, parent_id: None, position: 1,
            content: "fact @confidence=0.9".into(), depth: 0,
        });
        // confidence < 0.5 should match only block a
        assert!(tree.has_matching_property("confidence", 2, &PropertyValue::Float(0.5))); // lt
        let matches = tree.blocks_matching_property("confidence", 2, &PropertyValue::Float(0.5));
        assert_eq!(matches.len(), 1);
        assert_eq!(matches[0].content, "claim @confidence=0.3");
    }
}
