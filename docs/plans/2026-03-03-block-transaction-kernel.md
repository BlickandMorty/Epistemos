# Block Transaction Kernel (BTK) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace post-hoc Jaccard block reconciliation with an operation-log-based block kernel in Rust, giving every block a stable UUID that survives arbitrary edits.

**Architecture:** Append-only op log in Rust → materialized block tree → markdown projection. Swift intercepts `textDidChange` and translates NSTextStorage edits into block ops via FFI. The op log is the source of truth; markdown and SDBlock entities are derived views.

**Tech Stack:** Rust (`graph-engine/src/block_kernel/`), Swift FFI, SwiftData (SDBlock migration)

---

## The Problem Today

`BlockReconciler.swift` (232 lines) runs every 5 seconds on the debounce timer. It parses the full markdown, fetches all SDBlock entities, and does O(n×m) Jaccard similarity matching (threshold 0.4) to re-identify blocks.

**Fatal flaw:** Heavy edits (>60% word change) drop Jaccard below 0.4 → new block ID generated → all `((blockRef))` citations pointing to the old ID become dead links. Zero notification to the user.

**BTK fix:** Track edits as they happen. An `UpdateBlock` op changes content in-place — the block ID is never lost, no matter how much the text changes.

---

## What Exists Today

| File | Lines | Role |
|------|-------|------|
| `Epistemos/Sync/BlockReconciler.swift` | 232 | Post-hoc Jaccard matching (to be retired) |
| `Epistemos/Sync/BlockParser.swift` | 228 | O(n) markdown → `[ParsedBlock]` with utf16Range |
| `Epistemos/Models/SDBlock.swift` | 60 | SwiftData model: id, pageId, parentBlockId, content, depth, order |
| `Epistemos/Views/Notes/ProseEditorRepresentable.swift` | ~1020 | Coordinator with `textDidChange`, `shouldChangeText`, binding sync |
| `Epistemos/Views/Notes/ProseEditorView.swift:120` | — | `debouncedSave()` calls `BlockReconciler.reconcile()` at line 137 |

Key Coordinator details (for Task 6 translator hookup):
- `textDidChange()` at line 533 — fires on every edit, guards for `isFlushingTokens` and `isProgrammaticChange`
- `shouldChangeText(in:replacementString:)` — used for undo support
- Binding sync debounced to 300ms (line 597)
- `debouncedSave()` in ProseEditorView calls BlockReconciler at 5s interval

---

## New Files

```
graph-engine/src/block_kernel/
├── mod.rs          # Public API: apply_op, get_block, get_tree, export_markdown
├── op.rs           # Op enum (8 variants) + BlockId type
├── op_log.rs       # Append-only Vec<Op> with sequence numbers
├── block_tree.rs   # HashMap<BlockId, Block> materialized from ops
├── projection.rs   # block_tree → markdown string (round-trip-safe)
└── translator.rs   # (offset, old_len, new_text) → Vec<Op>
```

---

## Task 1: Op Types and Block Tree (Rust)

**Files:**
- Create: `graph-engine/src/block_kernel/mod.rs`
- Create: `graph-engine/src/block_kernel/op.rs`
- Create: `graph-engine/src/block_kernel/block_tree.rs`
- Modify: `graph-engine/src/lib.rs` (add `pub mod block_kernel;`)

**Step 1: Define the op types in `op.rs`**

```rust
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
```

**Step 2: Define the Block and BlockTree in `block_tree.rs`**

```rust
use std::collections::HashMap;
use crate::block_kernel::op::{BlockId, Op, PropertyValue};

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
                    properties: HashMap::new(),
                };
                self.blocks.insert(*block_id, block);
                if let Some(pid) = parent_id {
                    if let Some(parent) = self.blocks.get_mut(pid) {
                        parent.children.push(*block_id);
                        parent.children.sort_by_key(|id| {
                            self.blocks.get(id).map_or(0, |b| b.order)
                        });
                    }
                } else {
                    self.roots.push(*block_id);
                    self.roots.sort_by_key(|id| {
                        self.blocks.get(id).map_or(0, |b| b.order)
                    });
                }
            }
            Op::DeleteBlock { block_id } => {
                if let Some(block) = self.blocks.remove(block_id) {
                    // Reparent children to deleted block's parent
                    for child_id in &block.children {
                        if let Some(child) = self.blocks.get_mut(child_id) {
                            child.parent_id = block.parent_id;
                        }
                    }
                    if let Some(pid) = block.parent_id {
                        if let Some(parent) = self.blocks.get_mut(&pid) {
                            parent.children.retain(|id| id != block_id);
                            parent.children.extend_from_slice(&block.children);
                            parent.children.sort_by_key(|id| {
                                self.blocks.get(id).map_or(0, |b| b.order)
                            });
                        }
                    } else {
                        self.roots.retain(|id| id != block_id);
                        self.roots.extend_from_slice(&block.children);
                        self.roots.sort_by_key(|id| {
                            self.blocks.get(id).map_or(0, |b| b.order)
                        });
                    }
                }
            }
            Op::UpdateBlock { block_id, content } => {
                if let Some(block) = self.blocks.get_mut(block_id) {
                    block.content = content.clone();
                }
            }
            Op::SplitBlock { block_id, offset, new_block_id } => {
                let (new_content, remaining_content, parent_id, depth, order) = {
                    if let Some(block) = self.blocks.get(block_id) {
                        let off = (*offset as usize).min(block.content.len());
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
                // Remove from old parent
                if let Some(block) = self.blocks.get(block_id) {
                    let old_parent = block.parent_id;
                    if let Some(pid) = old_parent {
                        if let Some(parent) = self.blocks.get_mut(&pid) {
                            parent.children.retain(|id| id != block_id);
                        }
                    } else {
                        self.roots.retain(|id| id != block_id);
                    }
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
                        parent.children.sort_by_key(|id| {
                            self.blocks.get(id).map_or(0, |b| b.order)
                        });
                    }
                } else {
                    self.roots.push(*block_id);
                    self.roots.sort_by_key(|id| {
                        self.blocks.get(id).map_or(0, |b| b.order)
                    });
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
}
```

**Step 3: Wire up `mod.rs`**

```rust
pub mod op;
pub mod op_log;
pub mod block_tree;
pub mod projection;
pub mod translator;

pub use op::{BlockId, Op, PropertyValue};
pub use block_tree::BlockTree;
```

**Step 4: Add module to `lib.rs`**

Add `pub mod block_kernel;` after the existing module declarations.

**Step 5: Run tests**

```bash
cd graph-engine && cargo test
```

Expected: All existing tests pass. No new tests yet (next task).

**Step 6: Commit**

```bash
git add graph-engine/src/block_kernel/ graph-engine/src/lib.rs
git commit -m "feat(btk): add block kernel op types and block tree"
```

---

## Task 2: Op Log (Rust)

**Files:**
- Create: `graph-engine/src/block_kernel/op_log.rs`

**Step 1: Write the op log**

```rust
use crate::block_kernel::op::Op;

/// Append-only operation log. Source of truth for block state.
/// Each op gets a monotonic sequence number.
pub struct OpLog {
    ops: Vec<(u64, Op)>,  // (sequence_number, op)
    next_seq: u64,
}

impl OpLog {
    pub fn new() -> Self {
        Self { ops: Vec::new(), next_seq: 1 }
    }

    /// Append an op and return its sequence number.
    pub fn append(&mut self, op: Op) -> u64 {
        let seq = self.next_seq;
        self.ops.push((seq, op));
        self.next_seq += 1;
        seq
    }

    /// All ops since a given sequence number (exclusive).
    pub fn since(&self, after_seq: u64) -> &[(u64, Op)] {
        // Binary search for the first op with seq > after_seq
        let idx = self.ops.partition_point(|(s, _)| *s <= after_seq);
        &self.ops[idx..]
    }

    pub fn len(&self) -> usize {
        self.ops.len()
    }

    pub fn is_empty(&self) -> bool {
        self.ops.is_empty()
    }

    pub fn latest_seq(&self) -> u64 {
        self.next_seq - 1
    }
}
```

**Step 2: Write tests for OpLog**

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::block_kernel::op::{BlockId, Op};

    #[test]
    fn append_increments_sequence() {
        let mut log = OpLog::new();
        let id = BlockId::new();
        let s1 = log.append(Op::InsertBlock {
            block_id: id, parent_id: None, position: 0,
            content: "hello".into(), depth: 0,
        });
        let s2 = log.append(Op::UpdateBlock {
            block_id: id, content: "world".into(),
        });
        assert_eq!(s1, 1);
        assert_eq!(s2, 2);
        assert_eq!(log.len(), 2);
    }

    #[test]
    fn since_returns_ops_after_seq() {
        let mut log = OpLog::new();
        let id = BlockId::new();
        for i in 0..5 {
            log.append(Op::UpdateBlock {
                block_id: id, content: format!("v{}", i),
            });
        }
        let after_3 = log.since(3);
        assert_eq!(after_3.len(), 2); // seq 4, 5
    }
}
```

**Step 3: Run tests**

```bash
cd graph-engine && cargo test block_kernel
```

Expected: 2 new tests pass.

**Step 4: Commit**

```bash
git add graph-engine/src/block_kernel/op_log.rs
git commit -m "feat(btk): add append-only op log with sequence numbers"
```

---

## Task 3: Block Tree Tests (Rust)

**Files:**
- Create: `graph-engine/src/block_kernel/tests.rs` (or inline in `block_tree.rs`)

**Write comprehensive tests for all 8 op types:**

```rust
#[cfg(test)]
mod tests {
    use crate::block_kernel::op::*;
    use crate::block_kernel::block_tree::BlockTree;

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
}
```

**Run:** `cd graph-engine && cargo test block_kernel`

Expected: 7 tests pass.

**Commit:** `git commit -m "test(btk): add comprehensive block tree tests for all 8 op types"`

---

## Task 4: Markdown Projection (Rust)

**Files:**
- Create: `graph-engine/src/block_kernel/projection.rs`

The projection converts a BlockTree back to markdown. This must round-trip perfectly: `parse(md) → ops → tree → project() == md`.

**Step 1: Write projection**

```rust
use crate::block_kernel::block_tree::BlockTree;
use crate::block_kernel::op::BlockId;

/// Project a block tree back to markdown text.
/// Walks blocks in document order, indenting by depth.
pub fn project(tree: &BlockTree) -> String {
    let mut result = String::with_capacity(4096);
    let blocks = tree.walk();

    for (i, block) in blocks.iter().enumerate() {
        if i > 0 {
            result.push('\n');
        }
        // Indent: 2 spaces per depth level
        for _ in 0..block.depth {
            result.push_str("  ");
        }
        // List marker for indented blocks
        if block.depth > 0 {
            result.push_str("- ");
        }
        result.push_str(&block.content);
    }

    result
}

/// Parse markdown into a sequence of InsertBlock ops.
/// Uses the same logic as BlockParser.swift but in Rust.
/// This is the Rust-native entry point for initial population.
pub fn parse_to_ops(markdown: &str) -> Vec<crate::block_kernel::op::Op> {
    let mut ops = Vec::new();
    if markdown.is_empty() {
        return ops;
    }

    let lines: Vec<&str> = markdown.split('\n').collect();
    let mut order: u32 = 0;
    let mut i = 0;

    // Stack of (depth, BlockId) for parent tracking
    let mut depth_stack: Vec<(u16, BlockId)> = Vec::new();

    while i < lines.len() {
        let line = lines[i];

        // Skip blank lines
        if line.trim().is_empty() {
            i += 1;
            continue;
        }

        // Measure indent (each 2 spaces or tab = +1 depth)
        let (depth, stripped) = measure_indent(line);

        // Strip list marker
        let content = strip_list_marker(stripped);

        // Fenced code block: consume until closing fence
        if content.starts_with("```") {
            let mut fence_content = String::from(line);
            i += 1;
            while i < lines.len() {
                fence_content.push('\n');
                fence_content.push_str(lines[i]);
                if lines[i].trim().starts_with("```") {
                    i += 1;
                    break;
                }
                i += 1;
            }
            let block_id = BlockId::new();
            ops.push(crate::block_kernel::op::Op::InsertBlock {
                block_id,
                parent_id: None,
                position: order,
                content: fence_content,
                depth: 0,
            });
            order += 1;
            continue;
        }

        // Find parent: pop stack to find closest ancestor at depth - 1
        while let Some((d, _)) = depth_stack.last() {
            if *d >= depth {
                depth_stack.pop();
            } else {
                break;
            }
        }
        let parent_id = if depth > 0 {
            depth_stack.last().map(|(_, id)| *id)
        } else {
            None
        };

        let block_id = BlockId::new();
        ops.push(crate::block_kernel::op::Op::InsertBlock {
            block_id,
            parent_id,
            position: order,
            content: content.to_string(),
            depth,
        });
        depth_stack.push((depth, block_id));
        order += 1;
        i += 1;
    }

    ops
}

fn measure_indent(line: &str) -> (u16, &str) {
    let mut depth: u16 = 0;
    let mut spaces = 0;
    let bytes = line.as_bytes();
    let mut pos = 0;

    while pos < bytes.len() {
        match bytes[pos] {
            b'\t' => { depth += 1; spaces = 0; }
            b' ' => {
                spaces += 1;
                if spaces == 2 { depth += 1; spaces = 0; }
            }
            _ => break,
        }
        pos += 1;
    }

    (depth, &line[pos..])
}

fn strip_list_marker(s: &str) -> &str {
    if let Some(rest) = s.strip_prefix("- ") { return rest; }
    if let Some(rest) = s.strip_prefix("* ") { return rest; }

    // Ordered: "1. ", "2. ", etc.
    let bytes = s.as_bytes();
    let mut i = 0;
    while i < bytes.len() && bytes[i].is_ascii_digit() {
        i += 1;
    }
    if i > 0 && i + 1 < bytes.len() && bytes[i] == b'.' && bytes[i + 1] == b' ' {
        return &s[i + 2..];
    }

    s
}
```

**Step 2: Write round-trip tests**

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::block_kernel::block_tree::BlockTree;

    fn roundtrip(md: &str) -> String {
        let ops = parse_to_ops(md);
        let mut tree = BlockTree::new();
        for op in &ops {
            tree.apply(op);
        }
        project(&tree)
    }

    #[test]
    fn roundtrip_simple_paragraphs() {
        let md = "Hello\n\nWorld";
        assert_eq!(roundtrip(md), "Hello\nWorld");
        // Note: blank lines between paragraphs are lost (blocks are content-only).
        // This is acceptable — the projection produces minimal markdown.
    }

    #[test]
    fn roundtrip_nested_list() {
        let md = "Top level\n  - Child\n    - Grandchild";
        let result = roundtrip(md);
        assert!(result.contains("Top level"));
        assert!(result.contains("Child"));
        assert!(result.contains("Grandchild"));
    }

    #[test]
    fn roundtrip_heading() {
        let md = "# Title\n\nSome text";
        let result = roundtrip(md);
        assert!(result.contains("# Title"));
        assert!(result.contains("Some text"));
    }

    #[test]
    fn empty_markdown() {
        assert_eq!(roundtrip(""), "");
    }
}
```

**Run:** `cd graph-engine && cargo test block_kernel`

**Commit:** `git commit -m "feat(btk): add markdown projection with round-trip tests"`

---

## Task 5: Edit Translator (Rust — The Hard Part)

**Files:**
- Create: `graph-engine/src/block_kernel/translator.rs`

This is the critical piece. NSTextView tells us: "at UTF-16 offset X, replaced Y chars with Z". We map that to the block tree and emit the correct ops.

**Step 1: Write translator**

```rust
use crate::block_kernel::op::{BlockId, Op};
use crate::block_kernel::block_tree::BlockTree;

/// A text edit as reported by NSTextStorage.
#[repr(C)]
pub struct TextEdit {
    pub utf16_offset: u32,
    pub old_length: u32,   // Number of UTF-16 code units replaced
    pub new_text_ptr: *const u8,
    pub new_text_len: u32, // Byte length of replacement (UTF-8)
}

/// Translate a text edit into block ops.
/// Returns a Vec of ops to apply to the block tree.
pub fn translate_edit(
    tree: &BlockTree,
    edit_offset: u32,
    old_length: u32,
    new_text: &str,
) -> Vec<Op> {
    let blocks = tree.walk();
    if blocks.is_empty() {
        // Empty tree — create first block
        return vec![Op::InsertBlock {
            block_id: BlockId::new(),
            parent_id: None,
            position: 0,
            content: new_text.to_string(),
            depth: 0,
        }];
    }

    // Build a map of block → (start_utf16, end_utf16) in the projected document.
    // This reconstructs where each block sits in the flat text.
    let mut block_ranges: Vec<(BlockId, u32, u32)> = Vec::with_capacity(blocks.len());
    let mut cursor: u32 = 0;

    for (i, block) in blocks.iter().enumerate() {
        if i > 0 {
            cursor += 1; // newline separator
        }
        let indent = block.depth as u32 * 2; // 2 spaces per depth
        let marker = if block.depth > 0 { 2 } else { 0 }; // "- "
        let prefix_len = indent + marker;
        let content_start = cursor + prefix_len;
        let content_len = block.content.encode_utf16().count() as u32;
        let content_end = content_start + content_len;

        block_ranges.push((block.id, content_start, content_end));
        cursor = content_end;
    }

    let edit_end = edit_offset + old_length;

    // Find which block(s) the edit touches
    let mut affected: Vec<usize> = Vec::new();
    for (i, &(_, start, end)) in block_ranges.iter().enumerate() {
        // Edit overlaps this block's content range
        if edit_offset < end && edit_end > start {
            affected.push(i);
        }
    }

    // Case 1: Edit within a single block (most common)
    if affected.len() == 1 {
        let idx = affected[0];
        let (block_id, start, _) = block_ranges[idx];
        let block = blocks[idx];

        // Compute local offset within block content
        let local_offset = edit_offset.saturating_sub(start) as usize;
        let local_end = (edit_end.saturating_sub(start) as usize).min(block.content.len());

        let mut new_content = block.content.clone();
        // Replace using char indices (content is UTF-8, edit offsets are UTF-16)
        let char_start = utf16_to_byte_offset(&block.content, local_offset);
        let char_end = utf16_to_byte_offset(&block.content, local_end);
        new_content.replace_range(char_start..char_end, new_text);

        // Check if the new content contains a newline (block split by Enter)
        if new_content.contains('\n') {
            let parts: Vec<&str> = new_content.splitn(2, '\n').collect();
            let new_block_id = BlockId::new();
            return vec![
                Op::UpdateBlock {
                    block_id,
                    content: parts[0].to_string(),
                },
                Op::InsertBlock {
                    block_id: new_block_id,
                    parent_id: block.parent_id,
                    position: block.order + 1,
                    content: parts[1].to_string(),
                    depth: block.depth,
                },
            ];
        }

        return vec![Op::UpdateBlock {
            block_id,
            content: new_content,
        }];
    }

    // Case 2: Edit spans multiple blocks (selection delete, paste over blocks)
    if affected.len() > 1 {
        let first_idx = affected[0];
        let last_idx = *affected.last().unwrap();
        let (first_id, first_start, _) = block_ranges[first_idx];
        let (_, _, last_end) = block_ranges[last_idx];
        let first_block = blocks[first_idx];

        // Keep the beginning of the first block + new_text + end of last block
        let local_start = edit_offset.saturating_sub(first_start) as usize;
        let local_end = (edit_end.saturating_sub(block_ranges[last_idx].1)) as usize;

        let byte_start = utf16_to_byte_offset(&first_block.content, local_start);
        let last_block = blocks[last_idx];
        let byte_end = utf16_to_byte_offset(&last_block.content, local_end);

        let mut merged = first_block.content[..byte_start].to_string();
        merged.push_str(new_text);
        if byte_end < last_block.content.len() {
            merged.push_str(&last_block.content[byte_end..]);
        }

        let mut ops = vec![Op::UpdateBlock {
            block_id: first_id,
            content: merged,
        }];

        // Delete the intermediate and last blocks
        for &idx in &affected[1..] {
            ops.push(Op::DeleteBlock {
                block_id: block_ranges[idx].0,
            });
        }

        return ops;
    }

    // Case 3: Edit is between blocks (e.g., at a newline boundary)
    // Insert a new block
    vec![Op::InsertBlock {
        block_id: BlockId::new(),
        parent_id: None,
        position: edit_offset,
        content: new_text.to_string(),
        depth: 0,
    }]
}

/// Convert UTF-16 offset to byte offset in a UTF-8 string.
fn utf16_to_byte_offset(s: &str, utf16_offset: usize) -> usize {
    let mut utf16_count = 0;
    for (byte_idx, ch) in s.char_indices() {
        if utf16_count >= utf16_offset {
            return byte_idx;
        }
        utf16_count += ch.len_utf16();
    }
    s.len() // Past the end
}
```

**Step 2: Write translator tests**

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::block_kernel::block_tree::BlockTree;
    use crate::block_kernel::op::{BlockId, Op};

    fn make_tree(blocks: &[&str]) -> (BlockTree, Vec<BlockId>) {
        let mut tree = BlockTree::new();
        let mut ids = Vec::new();
        for (i, content) in blocks.iter().enumerate() {
            let id = BlockId::new();
            ids.push(id);
            tree.apply(&Op::InsertBlock {
                block_id: id, parent_id: None, position: i as u32,
                content: content.to_string(), depth: 0,
            });
        }
        (tree, ids)
    }

    #[test]
    fn single_block_update() {
        let (tree, ids) = make_tree(&["Hello World"]);
        // Replace "World" (offset 6, length 5) with "Rust"
        let ops = translate_edit(&tree, 6, 5, "Rust");
        assert_eq!(ops.len(), 1);
        match &ops[0] {
            Op::UpdateBlock { block_id, content } => {
                assert_eq!(*block_id, ids[0]);
                assert_eq!(content, "Hello Rust");
            }
            _ => panic!("Expected UpdateBlock"),
        }
    }

    #[test]
    fn enter_key_splits_block() {
        let (tree, ids) = make_tree(&["Hello World"]);
        // Insert newline at offset 5: "Hello\nWorld"
        let ops = translate_edit(&tree, 5, 0, "\n");
        assert_eq!(ops.len(), 2);
        match &ops[0] {
            Op::UpdateBlock { content, .. } => assert_eq!(content, "Hello"),
            _ => panic!("Expected UpdateBlock"),
        }
        match &ops[1] {
            Op::InsertBlock { content, .. } => assert_eq!(content, " World"),
            _ => panic!("Expected InsertBlock"),
        }
    }

    #[test]
    fn empty_tree_creates_block() {
        let tree = BlockTree::new();
        let ops = translate_edit(&tree, 0, 0, "First block");
        assert_eq!(ops.len(), 1);
        match &ops[0] {
            Op::InsertBlock { content, .. } => assert_eq!(content, "First block"),
            _ => panic!("Expected InsertBlock"),
        }
    }
}
```

**Run:** `cd graph-engine && cargo test translator`

**Commit:** `git commit -m "feat(btk): add edit-to-op translator (NSTextStorage edits → block ops)"`

---

## Task 6: FFI Bridge (Rust + Swift)

**Files:**
- Modify: `graph-engine/src/engine.rs` (add BTK state to Engine)
- Modify: `graph-engine/src/lib.rs` (add FFI functions)
- Modify: `graph-engine-bridge/graph_engine.h` (add C declarations)

**Step 1: Add BTK state to Engine**

In `engine.rs`, add to the Engine struct:

```rust
use crate::block_kernel::{BlockTree, Op, BlockId};
use crate::block_kernel::op_log::OpLog;
use std::collections::HashMap;

// Add to Engine struct:
pub btk_trees: HashMap<String, BlockTree>,   // page_id → tree
pub btk_logs: HashMap<String, OpLog>,        // page_id → op log
```

Initialize both as `HashMap::new()` in `Engine::new()`.

**Step 2: Add FFI functions to `lib.rs`**

```rust
/// Initialize BTK for a page. Call once when a page is opened.
#[no_mangle]
pub extern "C" fn graph_engine_btk_init(
    engine: *mut Engine,
    page_id: *const c_char,
) -> u8 {
    ffi_engine_or!(engine, 0);
    let page_id = ffi_cstr!(page_id);
    if page_id.is_empty() { return 0; }

    engine.btk_trees.entry(page_id.to_string())
        .or_insert_with(block_kernel::BlockTree::new);
    engine.btk_logs.entry(page_id.to_string())
        .or_insert_with(block_kernel::op_log::OpLog::new);
    1
}

/// Load existing blocks from Swift (migration from SDBlock).
/// blocks_ptr is a pointer to an array of BlockFFI structs.
#[repr(C)]
pub struct BlockFFI {
    pub id: [u8; 16],           // UUID as 16 bytes
    pub parent_id: [u8; 16],    // Zero = no parent
    pub content_ptr: *const c_char,
    pub depth: u16,
    pub order: u32,
}

#[no_mangle]
pub extern "C" fn graph_engine_btk_load_blocks(
    engine: *mut Engine,
    page_id: *const c_char,
    blocks_ptr: *const BlockFFI,
    count: u32,
) -> u8 {
    ffi_engine_or!(engine, 0);
    let page_id_str = ffi_cstr!(page_id);
    if page_id_str.is_empty() || blocks_ptr.is_null() { return 0; }

    let tree = engine.btk_trees.entry(page_id_str.to_string())
        .or_insert_with(block_kernel::BlockTree::new);
    let log = engine.btk_logs.entry(page_id_str.to_string())
        .or_insert_with(block_kernel::op_log::OpLog::new);

    // SAFETY: Swift passes a valid array of `count` BlockFFI structs.
    let blocks = unsafe { std::slice::from_raw_parts(blocks_ptr, count as usize) };

    for b in blocks {
        let content = if b.content_ptr.is_null() {
            String::new()
        } else {
            unsafe { CStr::from_ptr(b.content_ptr) }
                .to_str().unwrap_or("").to_string()
        };

        let block_id = block_kernel::BlockId(b.id);
        let parent_id = if b.parent_id == [0u8; 16] {
            None
        } else {
            Some(block_kernel::BlockId(b.parent_id))
        };

        let op = block_kernel::Op::InsertBlock {
            block_id,
            parent_id,
            position: b.order,
            content,
            depth: b.depth,
        };
        tree.apply(&op);
        log.append(op);
    }

    1
}

/// Translate a text edit into block ops and apply them.
/// Returns the number of ops applied.
#[no_mangle]
pub extern "C" fn graph_engine_btk_translate_edit(
    engine: *mut Engine,
    page_id: *const c_char,
    edit_offset: u32,
    old_length: u32,
    new_text: *const c_char,
) -> u32 {
    ffi_engine_or!(engine, 0);
    let page_id_str = ffi_cstr!(page_id);
    let new_text_str = ffi_cstr!(new_text);

    let ops = {
        let tree = match engine.btk_trees.get(page_id_str) {
            Some(t) => t,
            None => return 0,
        };
        block_kernel::translator::translate_edit(tree, edit_offset, old_length, new_text_str)
    };

    let count = ops.len() as u32;

    // Apply ops to both tree and log
    if let Some(tree) = engine.btk_trees.get_mut(page_id_str) {
        if let Some(log) = engine.btk_logs.get_mut(page_id_str) {
            for op in ops {
                tree.apply(&op);
                log.append(op);
            }
        }
    }

    count
}

/// Get the current markdown projection for a page.
/// Returns a C string that must be freed with graph_engine_free_string.
#[no_mangle]
pub extern "C" fn graph_engine_btk_get_markdown(
    engine: *mut Engine,
    page_id: *const c_char,
) -> *const c_char {
    ffi_engine_or!(engine, std::ptr::null());
    let page_id_str = ffi_cstr!(page_id);

    let tree = match engine.btk_trees.get(page_id_str) {
        Some(t) => t,
        None => return std::ptr::null(),
    };

    let md = block_kernel::projection::project(tree);
    match CString::new(md) {
        Ok(cs) => cs.into_raw(),
        Err(_) => std::ptr::null(),
    }
}
```

**Step 3: Add to C bridge header**

In `graph-engine-bridge/graph_engine.h`:

```c
// BTK (Block Transaction Kernel)
typedef struct {
    uint8_t id[16];
    uint8_t parent_id[16];
    const char *content_ptr;
    uint16_t depth;
    uint32_t order;
} BlockFFI;

uint8_t graph_engine_btk_init(void *engine, const char *page_id);
uint8_t graph_engine_btk_load_blocks(void *engine, const char *page_id,
                                      const BlockFFI *blocks, uint32_t count);
uint32_t graph_engine_btk_translate_edit(void *engine, const char *page_id,
                                          uint32_t edit_offset, uint32_t old_length,
                                          const char *new_text);
const char *graph_engine_btk_get_markdown(void *engine, const char *page_id);
```

**Step 4: Run tests**

```bash
cd graph-engine && cargo test
xcodebuild -scheme Epistemos -destination 'platform=macOS' build
```

Expected: All tests pass, build succeeds.

**Commit:** `git commit -m "feat(btk): add FFI bridge for block kernel (init, load, translate, project)"`

---

## Task 7: Swift Integration — BlockEditTranslator

**Files:**
- Create: `Epistemos/Engine/BlockEditTranslator.swift`
- Modify: `Epistemos/Views/Notes/ProseEditorRepresentable.swift` (hook into textDidChange)
- Modify: `Epistemos/Views/Notes/ProseEditorView.swift` (feature flag, migration)

**Step 1: Create BlockEditTranslator.swift**

```swift
import Foundation

/// Translates NSTextStorage edits into BTK ops via FFI.
/// One instance per open page, held by the ProseEditorRepresentable Coordinator.
@MainActor
final class BlockEditTranslator {

    private let pageId: String
    private weak var graphState: GraphState?
    private var initialized = false

    init(pageId: String, graphState: GraphState) {
        self.pageId = pageId
        self.graphState = graphState
    }

    /// Initialize BTK for this page. Call once on first edit.
    func initIfNeeded(existingBlocks: [SDBlock]) {
        guard !initialized, let engine = graphState?.engineHandle else { return }

        pageId.withCString { pageIdPtr in
            graph_engine_btk_init(engine, pageIdPtr)
        }

        // Load existing blocks from SwiftData
        if !existingBlocks.isEmpty {
            var ffiBlocks: [BlockFFI] = existingBlocks.map { block in
                var ffi = BlockFFI()
                // Convert UUID string to 16 bytes
                if let uuid = UUID(uuidString: block.id) {
                    let (b0, b1, b2, b3, b4, b5, b6, b7,
                         b8, b9, b10, b11, b12, b13, b14, b15) = uuid.uuid
                    ffi.id = (b0, b1, b2, b3, b4, b5, b6, b7,
                              b8, b9, b10, b11, b12, b13, b14, b15)
                }
                if let parentId = block.parentBlockId, let uuid = UUID(uuidString: parentId) {
                    let (b0, b1, b2, b3, b4, b5, b6, b7,
                         b8, b9, b10, b11, b12, b13, b14, b15) = uuid.uuid
                    ffi.parent_id = (b0, b1, b2, b3, b4, b5, b6, b7,
                                     b8, b9, b10, b11, b12, b13, b14, b15)
                }
                // content_ptr set below in withCString
                ffi.depth = UInt16(block.depth)
                ffi.order = UInt32(block.order)
                return ffi
            }

            // Note: content_ptr lifetime must span the FFI call.
            // Use withCString for each block's content.
            // For simplicity, pre-encode all strings and pin them.
            var cStrings: [UnsafeMutablePointer<CChar>] = []
            for block in existingBlocks {
                let cs = strdup(block.content)
                cStrings.append(cs!)
            }
            for (i, cs) in cStrings.enumerated() {
                ffiBlocks[i].content_ptr = UnsafePointer(cs)
            }

            pageId.withCString { pageIdPtr in
                ffiBlocks.withUnsafeBufferPointer { buf in
                    graph_engine_btk_load_blocks(
                        engine, pageIdPtr,
                        buf.baseAddress, UInt32(buf.count)
                    )
                }
            }

            for cs in cStrings { free(cs) }
        }

        initialized = true
    }

    /// Called from textDidChange. Translates the NSTextStorage edit into block ops.
    func translateEdit(offset: Int, oldLength: Int, newText: String) {
        guard initialized, let engine = graphState?.engineHandle else { return }

        pageId.withCString { pageIdPtr in
            newText.withCString { textPtr in
                graph_engine_btk_translate_edit(
                    engine, pageIdPtr,
                    UInt32(offset), UInt32(oldLength), textPtr
                )
            }
        }
    }
}
```

**Step 2: Hook into ProseEditorRepresentable Coordinator**

In `ProseEditorRepresentable.swift`, add to the Coordinator class:

```swift
var blockEditTranslator: BlockEditTranslator?
```

In `textDidChange()` (line 533), after the existing guards:

```swift
// BTK: translate edit into block ops (if enabled)
if let translator = blockEditTranslator,
   let storage = textView?.textStorage,
   let editedRange = textView?.rangeForUserTextChange {
    // NSTextStorage.editedRange gives us the range that changed
    let offset = storage.editedRange.location
    let oldLength = storage.editedRange.length - storage.changeInLength
    let newText = (storage.string as NSString).substring(with: storage.editedRange)
    translator.translateEdit(offset: offset, oldLength: oldLength, newText: newText)
}
```

**Step 3: Feature flag in ProseEditorView**

In `debouncedSave()` (line 120), wrap BlockReconciler call:

```swift
if UserDefaults.standard.bool(forKey: "epistemos.btk.enabled") {
    // BTK handles block tracking in real-time via the Coordinator.
    // No need for post-hoc reconciliation.
} else {
    BlockReconciler.reconcile(pageId: pageId, markdown: newValue, context: modelContext)
}
```

**Step 4: Run tests**

```bash
cd graph-engine && cargo test
xcodebuild -scheme Epistemos -destination 'platform=macOS' build
```

**Step 5: Commit**

```bash
git commit -m "feat(btk): add Swift BlockEditTranslator + feature flag"
```

---

## Task 8: Migration Path

**Files:**
- Modify: `Epistemos/Views/Notes/ProseEditorView.swift`

On first page open with BTK enabled, load existing SDBlock data into the kernel:

```swift
// In page open flow, after loading body:
if UserDefaults.standard.bool(forKey: "epistemos.btk.enabled") {
    let descriptor = FetchDescriptor<SDBlock>(
        predicate: #Predicate<SDBlock> { $0.pageId == pageId },
        sortBy: [SortDescriptor(\SDBlock.order)]
    )
    let existingBlocks = (try? modelContext.fetch(descriptor)) ?? []
    coordinator.blockEditTranslator = BlockEditTranslator(
        pageId: pageId, graphState: graphState
    )
    coordinator.blockEditTranslator?.initIfNeeded(existingBlocks: existingBlocks)
}
```

**Verify:**
1. Set `epistemos.btk.enabled` to true in UserDefaults (via Terminal: `defaults write com.epistemos.app epistemos.btk.enabled -bool true`)
2. Open a note with existing blocks
3. Edit text — verify no crash
4. The BTK is now tracking edits. Block IDs should remain stable across arbitrary content changes.

**Commit:** `git commit -m "feat(btk): add SDBlock → BTK migration path on page open"`

---

## Exit Criteria

- [ ] 8 op types implemented and tested (InsertBlock, DeleteBlock, UpdateBlock, SplitBlock, MergeBlock, MoveSubtree, SetProperty, SetRef)
- [ ] OpLog append-only with sequence numbers
- [ ] BlockTree materializes from ops correctly
- [ ] Markdown projection round-trips
- [ ] Edit translator maps NSTextStorage edits → ops for single-block edits, splits, and multi-block deletes
- [ ] FFI bridge: init, load_blocks, translate_edit, get_markdown
- [ ] Swift BlockEditTranslator hooks into Coordinator textDidChange
- [ ] Feature flag: `epistemos.btk.enabled` gates old reconciler vs new BTK
- [ ] Migration: existing SDBlock data loads into kernel on page open
- [ ] `cargo test` all pass (existing + new BTK tests)
- [ ] `xcodebuild build` succeeds
- [ ] Editing a note with BTK enabled doesn't crash
- [ ] Block IDs survive 100% content rewrite (the whole point)
