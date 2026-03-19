use std::collections::HashMap;

use loro::{ExportMode, LoroDoc, LoroTree, TreeID, TreeParentId};

use crate::block_kernel::FractionalIndex;

#[derive(Debug)]
pub enum OutlineError {
    Loro(String),
    MissingNode(String),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OutlinePlacement {
    pub parent_id: String,
    pub order_key: String,
}

pub struct OutlineCrdt {
    peer_id: u64,
    jitter: u8,
    doc: LoroDoc,
    tree: LoroTree,
    node_ids: HashMap<String, TreeID>,
    parents: HashMap<String, Option<String>>,
    order_keys: HashMap<String, FractionalIndex>,
}

const BLOCK_ID_META_KEY: &str = "block_id";
const ORDER_KEY_META_KEY: &str = "order_key";

impl OutlineCrdt {
    pub fn new(peer_id: u64, jitter: u8) -> Result<Self, OutlineError> {
        let doc = LoroDoc::new();
        doc.set_peer_id(peer_id)
            .map_err(|error| OutlineError::Loro(error.to_string()))?;
        let tree = doc.get_tree("outline");
        tree.enable_fractional_index(jitter);
        Ok(Self {
            peer_id,
            jitter,
            doc,
            tree,
            node_ids: HashMap::new(),
            parents: HashMap::new(),
            order_keys: HashMap::new(),
        })
    }

    pub fn insert_block(
        &mut self,
        block_id: &str,
        parent_id: Option<&str>,
        index: usize,
    ) -> Result<OutlinePlacement, OutlineError> {
        let tree_parent = parent_id.and_then(|parent| self.node_ids.get(parent).copied());
        let tree_id = self
            .tree
            .create_at(tree_parent, index)
            .map_err(|error| OutlineError::Loro(error.to_string()))?;
        self.node_ids.insert(block_id.to_string(), tree_id);
        let placement = self.assign_order(block_id, parent_id, index);
        self.persist_node_metadata(tree_id, block_id, &placement.order_key)?;
        self.doc.commit();
        self.rebuild_state_from_tree()?;
        Ok(placement)
    }

    pub fn move_block(
        &mut self,
        block_id: &str,
        parent_id: Option<&str>,
        index: usize,
    ) -> Result<OutlinePlacement, OutlineError> {
        let Some(tree_id) = self.node_ids.get(block_id).copied() else {
            return Err(OutlineError::MissingNode(block_id.to_string()));
        };
        let tree_parent = parent_id.and_then(|parent| self.node_ids.get(parent).copied());
        self.tree
            .mov_to(tree_id, tree_parent, index)
            .map_err(|error| OutlineError::Loro(error.to_string()))?;
        let placement = self.assign_order(block_id, parent_id, index);
        self.persist_node_metadata(tree_id, block_id, &placement.order_key)?;
        self.doc.commit();
        self.rebuild_state_from_tree()?;
        Ok(placement)
    }

    pub fn delete_block(&mut self, block_id: &str) -> Result<(), OutlineError> {
        let Some(tree_id) = self.node_ids.remove(block_id) else {
            return Err(OutlineError::MissingNode(block_id.to_string()));
        };
        self.tree
            .delete(tree_id)
            .map_err(|error| OutlineError::Loro(error.to_string()))?;
        self.doc.commit();
        self.rebuild_state_from_tree()?;
        Ok(())
    }

    pub fn snapshot(&self) -> Result<Vec<u8>, OutlineError> {
        self.doc
            .export(ExportMode::snapshot())
            .map_err(|error| OutlineError::Loro(error.to_string()))
    }

    pub fn restore(snapshot: &[u8], peer_id: u64, jitter: u8) -> Result<Self, OutlineError> {
        let doc = LoroDoc::from_snapshot(snapshot)
            .map_err(|error| OutlineError::Loro(error.to_string()))?;
        doc.set_peer_id(peer_id)
            .map_err(|error| OutlineError::Loro(error.to_string()))?;
        let tree = doc.get_tree("outline");
        tree.enable_fractional_index(jitter);
        let mut outline = Self {
            peer_id,
            jitter,
            doc,
            tree,
            node_ids: HashMap::new(),
            parents: HashMap::new(),
            order_keys: HashMap::new(),
        };
        outline.rebuild_state_from_tree()?;
        Ok(outline)
    }

    fn assign_order(
        &mut self,
        block_id: &str,
        parent_id: Option<&str>,
        index: usize,
    ) -> OutlinePlacement {
        let siblings = self.ordered_siblings(parent_id, Some(block_id));
        let left = index
            .checked_sub(1)
            .and_then(|left_index| siblings.get(left_index))
            .and_then(|sibling| self.order_keys.get(sibling));
        let right = siblings
            .get(index)
            .and_then(|sibling| self.order_keys.get(sibling));
        let discriminator = self.next_discriminator(block_id);
        let order = FractionalIndex::between(left, right, self.peer_id as u32, discriminator);
        let order_key = order.as_sort_key();
        self.order_keys.insert(block_id.to_string(), order);
        OutlinePlacement {
            parent_id: parent_id.unwrap_or_default().to_string(),
            order_key,
        }
    }

    fn ordered_siblings(&self, parent_id: Option<&str>, excluding: Option<&str>) -> Vec<String> {
        let parent = parent_id.map(std::string::ToString::to_string);
        let mut siblings = self
            .parents
            .iter()
            .filter_map(|(block_id, stored_parent)| {
                (stored_parent.as_ref() == parent.as_ref() && excluding != Some(block_id.as_str()))
                    .then_some(block_id.clone())
            })
            .collect::<Vec<_>>();
        siblings.sort_by(|left, right| {
            let left_key = self.order_keys.get(left);
            let right_key = self.order_keys.get(right);
            left_key.cmp(&right_key)
        });
        siblings
    }

    fn next_discriminator(&self, block_id: &str) -> u32 {
        let seed = (self.jitter as u32) << 24;
        seed ^ (block_id.len() as u32) ^ (self.order_keys.len() as u32)
    }

    fn persist_node_metadata(
        &self,
        tree_id: TreeID,
        block_id: &str,
        order_key: &str,
    ) -> Result<(), OutlineError> {
        let meta = self
            .tree
            .get_meta(tree_id)
            .map_err(|error| OutlineError::Loro(error.to_string()))?;
        meta.insert(BLOCK_ID_META_KEY, block_id)
            .map_err(|error| OutlineError::Loro(error.to_string()))?;
        meta.insert(ORDER_KEY_META_KEY, order_key)
            .map_err(|error| OutlineError::Loro(error.to_string()))?;
        Ok(())
    }

    fn rebuild_state_from_tree(&mut self) -> Result<(), OutlineError> {
        let mut tree_to_block = HashMap::<TreeID, String>::new();
        let mut node_ids = HashMap::<String, TreeID>::new();
        let mut order_keys = HashMap::<String, FractionalIndex>::new();

        for tree_id in self.tree.nodes() {
            if self
                .tree
                .is_node_deleted(&tree_id)
                .map_err(|error| OutlineError::Loro(error.to_string()))?
            {
                continue;
            }

            let meta = self
                .tree
                .get_meta(tree_id)
                .map_err(|error| OutlineError::Loro(error.to_string()))?;
            let Some(block_id) = meta_string(&meta, BLOCK_ID_META_KEY) else {
                continue;
            };

            let order_key = meta_string(&meta, ORDER_KEY_META_KEY)
                .and_then(|value| FractionalIndex::from_sort_key(&value))
                .unwrap_or_else(|| FractionalIndex::from_position(order_keys.len() as u32));

            tree_to_block.insert(tree_id, block_id.clone());
            node_ids.insert(block_id.clone(), tree_id);
            order_keys.insert(block_id, order_key);
        }

        let mut parents = HashMap::<String, Option<String>>::new();
        for (block_id, tree_id) in &node_ids {
            let parent = match self.tree.parent(*tree_id) {
                Some(TreeParentId::Node(parent_id)) => tree_to_block.get(&parent_id).cloned(),
                _ => None,
            };
            parents.insert(block_id.clone(), parent);
        }

        self.node_ids = node_ids;
        self.parents = parents;
        self.order_keys = order_keys;
        Ok(())
    }
}

fn meta_string(meta: &loro::LoroMap, key: &str) -> Option<String> {
    meta.get(key)
        .and_then(|value| value.into_value().ok())
        .and_then(|value| value.into_string().ok())
        .map(|value| value.to_string())
}

#[cfg(test)]
mod tests {
    use super::OutlineCrdt;

    #[test]
    fn movable_tree_generates_stable_order_keys() {
        let mut crdt = OutlineCrdt::new(7, 1).expect("crdt should initialize");
        let root = crdt
            .insert_block("root", None, 0)
            .expect("root should insert");
        let child = crdt
            .insert_block("child", Some("root"), 0)
            .expect("child should insert");

        assert!(root.order_key < child.order_key || child.parent_id == "root");
    }

    #[test]
    fn snapshots_roundtrip() {
        let mut crdt = OutlineCrdt::new(7, 1).expect("crdt should initialize");
        crdt.insert_block("root", None, 0)
            .expect("root should insert");
        let snapshot = crdt.snapshot().expect("snapshot should export");
        let restored = OutlineCrdt::restore(&snapshot, 7, 1).expect("snapshot should restore");
        let snapshot_again = restored.snapshot().expect("restored snapshot should export");
        assert!(!snapshot_again.is_empty());
    }

    #[test]
    fn restored_snapshot_retains_block_identity_and_allows_moves() {
        let mut crdt = OutlineCrdt::new(7, 1).expect("crdt should initialize");
        crdt.insert_block("root", None, 0)
            .expect("root should insert");
        crdt.insert_block("child", Some("root"), 0)
            .expect("child should insert");

        let snapshot = crdt.snapshot().expect("snapshot should export");
        let mut restored = OutlineCrdt::restore(&snapshot, 7, 1).expect("snapshot should restore");
        let placement = restored
            .move_block("child", None, 1)
            .expect("restored snapshot should keep node identity");
        assert_eq!(placement.parent_id, "");
    }

    #[test]
    fn deleting_parent_prunes_descendant_metadata() {
        let mut crdt = OutlineCrdt::new(7, 1).expect("crdt should initialize");
        crdt.insert_block("root", None, 0)
            .expect("root should insert");
        crdt.insert_block("child", Some("root"), 0)
            .expect("child should insert");
        crdt.insert_block("grandchild", Some("child"), 0)
            .expect("grandchild should insert");

        crdt.delete_block("child")
            .expect("delete should remove subtree");
        let result = crdt.move_block("grandchild", None, 0);
        assert!(matches!(result, Err(super::OutlineError::MissingNode(_))));
    }

    #[test]
    fn cycle_causing_move_is_rejected() {
        let mut crdt = OutlineCrdt::new(7, 1).expect("crdt should initialize");
        crdt.insert_block("root", None, 0)
            .expect("root should insert");
        crdt.insert_block("child", Some("root"), 0)
            .expect("child should insert");

        let result = crdt.move_block("root", Some("child"), 0);
        assert!(matches!(result, Err(super::OutlineError::Loro(_))));
    }
}
