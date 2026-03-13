use std::collections::HashMap;

use crate::block_kernel::fractional_index::FractionalIndex;
use crate::block_kernel::op::{BlockId, Op};

#[derive(Clone, Debug)]
struct NodeState {
    parent: Option<BlockId>,
    order: FractionalIndex,
    last_seq: u64,
    last_peer_id: u32,
}

/// Minimal movable-tree CRDT index for sibling ordering and cycle rejection.
/// This does not replace the existing BlockTree yet; it hardens ordering semantics
/// for subscription/query use and cross-device merge tests.
#[derive(Default)]
pub struct MovableTreeIndex {
    nodes: HashMap<BlockId, NodeState>,
}

impl MovableTreeIndex {
    /// Apply a BTK tree mutation into the movable-tree index.
    ///
    /// Returns `true` when the operation changed the index and `false` when it was rejected
    /// because it was stale, invalid, or unrelated to tree structure.
    pub fn apply(&mut self, seq: u64, peer_id: u32, op: &Op) -> bool {
        match op {
            Op::InsertBlock {
                block_id,
                parent_id,
                position,
                ..
            } => {
                let order = self.order_for(*parent_id, *position as usize, *block_id, peer_id, seq);
                self.nodes.insert(
                    *block_id,
                    NodeState {
                        parent: *parent_id,
                        order,
                        last_seq: seq,
                        last_peer_id: peer_id,
                    },
                );
                true
            }
            Op::MoveSubtree {
                block_id,
                new_parent,
                position,
            } => {
                let Some(existing) = self.nodes.get(block_id).cloned() else {
                    return false;
                };
                if seq < existing.last_seq
                    || (seq == existing.last_seq && peer_id <= existing.last_peer_id)
                {
                    return false;
                }
                if self.would_cycle(*block_id, *new_parent) {
                    return false;
                }
                let order = self.order_for(*new_parent, *position as usize, *block_id, peer_id, seq);
                self.nodes.insert(
                    *block_id,
                    NodeState {
                        parent: *new_parent,
                        order,
                        last_seq: seq,
                        last_peer_id: peer_id,
                    },
                );
                true
            }
            Op::DeleteBlock { block_id } => {
                let Some(removed) = self.nodes.remove(block_id) else {
                    return false;
                };
                for child in self
                    .nodes
                    .iter_mut()
                    .filter_map(|(id, node)| (node.parent == Some(*block_id)).then_some((*id, node)))
                {
                    child.1.parent = removed.parent;
                }
                true
            }
            _ => false,
        }
    }

    /// Return the current parent for a block if it exists in the index.
    pub fn parent_of(&self, block_id: BlockId) -> Option<BlockId> {
        self.nodes.get(&block_id).and_then(|node| node.parent)
    }

    /// Return children for `parent` in fractional-index order.
    pub fn ordered_children(&self, parent: Option<BlockId>) -> Vec<BlockId> {
        let mut children: Vec<(BlockId, &FractionalIndex)> = self
            .nodes
            .iter()
            .filter_map(|(id, node)| (node.parent == parent).then_some((*id, &node.order)))
            .collect();
        children.sort_by(|left, right| left.1.cmp(right.1));
        children.into_iter().map(|(id, _)| id).collect()
    }

    fn order_for(
        &self,
        parent: Option<BlockId>,
        requested_position: usize,
        block_id: BlockId,
        peer_id: u32,
        seq: u64,
    ) -> FractionalIndex {
        let mut siblings: Vec<(BlockId, &NodeState)> = self
            .nodes
            .iter()
            .filter_map(|(id, node)| {
                (node.parent == parent && *id != block_id).then_some((*id, node))
            })
            .collect();
        siblings.sort_by(|left, right| left.1.order.cmp(&right.1.order));

        let position = requested_position.min(siblings.len());
        let left = position
            .checked_sub(1)
            .and_then(|index| siblings.get(index).map(|(_, node)| &node.order));
        let right = siblings.get(position).map(|(_, node)| &node.order);
        FractionalIndex::between(left, right, peer_id, seq as u32)
    }

    fn would_cycle(&self, block_id: BlockId, new_parent: Option<BlockId>) -> bool {
        let mut cursor = new_parent;
        while let Some(parent) = cursor {
            if parent == block_id {
                return true;
            }
            cursor = self.nodes.get(&parent).and_then(|node| node.parent);
        }
        false
    }
}

#[cfg(test)]
mod tests {
    use super::MovableTreeIndex;
    use crate::block_kernel::op::{BlockId, Op};

    #[test]
    fn rejects_cycle_moves() {
        let root = BlockId::new();
        let child = BlockId::new();
        let grandchild = BlockId::new();

        let mut index = MovableTreeIndex::default();
        index.apply(
            1,
            1,
            &Op::InsertBlock {
                block_id: root,
                parent_id: None,
                position: 0,
                content: String::new(),
                depth: 0,
            },
        );
        index.apply(
            2,
            1,
            &Op::InsertBlock {
                block_id: child,
                parent_id: Some(root),
                position: 0,
                content: String::new(),
                depth: 1,
            },
        );
        index.apply(
            3,
            1,
            &Op::InsertBlock {
                block_id: grandchild,
                parent_id: Some(child),
                position: 0,
                content: String::new(),
                depth: 2,
            },
        );

        let applied = index.apply(
            4,
            1,
            &Op::MoveSubtree {
                block_id: root,
                new_parent: Some(grandchild),
                position: 0,
            },
        );

        assert!(!applied);
        assert_eq!(index.parent_of(root), None);
    }

    #[test]
    fn ignores_older_conflicting_moves() {
        let root = BlockId::new();
        let child = BlockId::new();
        let parent_b = BlockId::new();

        let mut index = MovableTreeIndex::default();
        for (seq, block_id, parent) in [
            (1, root, None),
            (2, child, Some(root)),
            (3, parent_b, None),
        ] {
            index.apply(
                seq,
                1,
                &Op::InsertBlock {
                    block_id,
                    parent_id: parent,
                    position: 0,
                    content: String::new(),
                    depth: 0,
                },
            );
        }

        assert!(index.apply(
            10,
            2,
            &Op::MoveSubtree {
                block_id: child,
                new_parent: Some(parent_b),
                position: 0,
            },
        ));
        assert!(!index.apply(
            9,
            1,
            &Op::MoveSubtree {
                block_id: child,
                new_parent: Some(root),
                position: 0,
            },
        ));

        assert_eq!(index.parent_of(child), Some(parent_b));
    }

    #[test]
    fn siblings_keep_fractional_order_after_insert_collisions() {
        let parent = BlockId::new();
        let mut index = MovableTreeIndex::default();
        index.apply(
            1,
            1,
            &Op::InsertBlock {
                block_id: parent,
                parent_id: None,
                position: 0,
                content: String::new(),
                depth: 0,
            },
        );

        let a = BlockId::new();
        let b = BlockId::new();
        let c = BlockId::new();

        for (seq, peer, block_id) in [(2, 1, a), (3, 2, b), (4, 3, c)] {
            assert!(index.apply(
                seq,
                peer,
                &Op::InsertBlock {
                    block_id,
                    parent_id: Some(parent),
                    position: 0,
                    content: String::new(),
                    depth: 1,
                },
            ));
        }

        let ordered = index.ordered_children(Some(parent));
        assert_eq!(ordered.len(), 3);
        assert!(ordered.windows(2).all(|pair| pair[0] != pair[1]));
    }
}
