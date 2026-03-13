//! # Version Chain
//!
//! Merkle-like hash-linked version chain per node.
//! Each version has a hash and parent_hash, forming a linked list from HEAD backward.
//! Pure data structure — no rendering or physics cost.
//!
//! Enables:
//! - O(1) version count queries
//! - O(n) full history traversal
//! - Future: content-addressable integrity verification

use rustc_hash::FxHashMap;

/// A single version entry in the chain.
#[derive(Clone, Debug)]
pub struct Version {
    /// Content hash (e.g., SHA-256 truncated to 64 bits for compactness).
    pub hash: u64,
    /// Parent version hash (0 = root / first version).
    pub parent_hash: u64,
    /// Unix epoch seconds when this version was created.
    pub timestamp: f64,
}

/// A chain of versions for a single node, ordered newest-first.
#[derive(Clone, Debug, Default)]
pub struct VersionChain {
    versions: Vec<Version>,
    /// Hash → index for O(1) lookup.
    hash_index: FxHashMap<u64, usize>,
}

impl VersionChain {
    pub fn new() -> Self {
        Self::default()
    }

    /// Add a version to the chain.
    /// Returns false if parent_hash != 0 and doesn't exist in the chain (orphan rejection).
    pub fn add(&mut self, hash: u64, parent_hash: u64, timestamp: f64) -> bool {
        // Reject orphans: parent must exist (or be 0 for root).
        if parent_hash != 0 && !self.hash_index.contains_key(&parent_hash) {
            return false;
        }
        // Reject duplicates.
        if self.hash_index.contains_key(&hash) {
            return false;
        }
        let idx = self.versions.len();
        self.versions.push(Version {
            hash,
            parent_hash,
            timestamp,
        });
        self.hash_index.insert(hash, idx);
        true
    }

    /// Number of versions in the chain.
    pub fn count(&self) -> u32 {
        self.versions.len() as u32
    }

    /// Get the most recent version (last added).
    pub fn head(&self) -> Option<&Version> {
        self.versions.last()
    }

    /// Walk the chain from a starting hash backward to root.
    /// Returns versions in newest-first order.
    pub fn history_from(&self, start_hash: u64) -> Vec<&Version> {
        let mut result = Vec::new();
        let mut current_hash = start_hash;

        // Safety bound: prevent infinite loops in case of corruption.
        let max_steps = self.versions.len();
        let mut steps = 0;

        while let Some(&idx) = self.hash_index.get(&current_hash) {
            let version = &self.versions[idx];
            result.push(version);
            if version.parent_hash == 0 {
                break; // Reached root.
            }
            current_hash = version.parent_hash;
            steps += 1;
            if steps > max_steps {
                break; // Cycle protection.
            }
        }
        result
    }

    /// Walk from HEAD backward to root.
    pub fn history(&self) -> Vec<&Version> {
        match self.head() {
            Some(head) => self.history_from(head.hash),
            None => Vec::new(),
        }
    }
}

/// Store for all version chains, keyed by node UUID.
#[derive(Clone, Debug, Default)]
pub struct VersionStore {
    chains: FxHashMap<String, VersionChain>,
}

impl VersionStore {
    pub fn new() -> Self {
        Self::default()
    }

    /// Add a version to a node's chain. Creates the chain if it doesn't exist.
    pub fn add_version(
        &mut self,
        node_uuid: &str,
        hash: u64,
        parent_hash: u64,
        timestamp: f64,
    ) -> bool {
        self.chains
            .entry(node_uuid.to_string())
            .or_default()
            .add(hash, parent_hash, timestamp)
    }

    /// Get the version count for a node.
    pub fn version_count(&self, node_uuid: &str) -> u32 {
        self.chains.get(node_uuid).map_or(0, |chain| chain.count())
    }

    /// Get the version chain for a node (if any).
    pub fn chain(&self, node_uuid: &str) -> Option<&VersionChain> {
        self.chains.get(node_uuid)
    }

    /// Clear all version data.
    pub fn clear(&mut self) {
        self.chains.clear();
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_chain_linear() {
        let mut chain = VersionChain::new();
        assert!(chain.add(100, 0, 1000.0)); // root
        assert!(chain.add(200, 100, 2000.0)); // child of root
        assert!(chain.add(300, 200, 3000.0)); // child of 200

        assert_eq!(chain.count(), 3);
        let history = chain.history();
        assert_eq!(history.len(), 3);
        assert_eq!(history[0].hash, 300); // HEAD first
        assert_eq!(history[1].hash, 200);
        assert_eq!(history[2].hash, 100); // root last
    }

    #[test]
    fn version_chain_orphan_rejected() {
        let mut chain = VersionChain::new();
        assert!(chain.add(100, 0, 1000.0));
        // Parent 999 doesn't exist — should be rejected.
        assert!(!chain.add(200, 999, 2000.0));
        assert_eq!(chain.count(), 1);
    }

    #[test]
    fn version_chain_duplicate_rejected() {
        let mut chain = VersionChain::new();
        assert!(chain.add(100, 0, 1000.0));
        assert!(!chain.add(100, 0, 2000.0)); // duplicate hash
        assert_eq!(chain.count(), 1);
    }

    #[test]
    fn version_chain_empty_history() {
        let chain = VersionChain::new();
        assert!(chain.history().is_empty());
        assert!(chain.head().is_none());
    }

    #[test]
    fn version_store_multi_node() {
        let mut store = VersionStore::new();
        store.add_version("node-a", 100, 0, 1000.0);
        store.add_version("node-a", 200, 100, 2000.0);
        store.add_version("node-b", 300, 0, 1500.0);

        assert_eq!(store.version_count("node-a"), 2);
        assert_eq!(store.version_count("node-b"), 1);
        assert_eq!(store.version_count("node-c"), 0);
    }

    #[test]
    fn version_store_clear() {
        let mut store = VersionStore::new();
        store.add_version("node-a", 100, 0, 1000.0);
        store.clear();
        assert_eq!(store.version_count("node-a"), 0);
    }

    #[test]
    fn version_history_from_mid_chain() {
        let mut chain = VersionChain::new();
        chain.add(100, 0, 1000.0);
        chain.add(200, 100, 2000.0);
        chain.add(300, 200, 3000.0);

        // Walk from version 200 (not HEAD)
        let history = chain.history_from(200);
        assert_eq!(history.len(), 2);
        assert_eq!(history[0].hash, 200);
        assert_eq!(history[1].hash, 100);
    }
}
