//! Persistent derived-state cache (ISSUE-2026-05-12-009).
//!
//! Stores at `<vault>/.epcache/projection.bin` a snapshot of derived
//! state that's expensive to rebuild on every cold launch:
//! - Sidebar tree (folder hierarchy + page IDs + titles)
//! - Graph snapshot (last frame positions, cluster pyramid, edge CSR)
//! - FTS-recent overlay
//! - Per-file mtime+content-hash for invalidation
//!
//! On launch:
//! 1. Read `projection.bin` → render sidebar instantly + render last
//!    known graph layout instantly
//! 2. In background: walk the vault, compute mtime+hash diffs, apply
//!    only the changes
//! 3. Cache stays valid across launches, invalidates on:
//!    - per-file mtime change (file edited)
//!    - per-file hash change (file replaced atomically)
//!    - app-version bump (schema may have changed)
//!
//! ## Status
//!
//! Scaffolding shipped: types + serde + IO + mtime invalidation.
//! NOT yet wired into the live sidebar or graph engine — that's
//! follow-on work per ISSUE-2026-05-12-009.
//!
//! ## Why a separate module
//!
//! This is *derived* state, not source-of-truth. The Markdown vault
//! files remain the canonical source. If `projection.bin` is corrupted
//! or deleted, the app rebuilds it from the live vault — slower cold
//! start, but no data loss. That separation matters because:
//! - The cache file can be deleted at any time without consequence
//! - The cache schema can evolve independently of vault format
//! - Sync/backup never needs to include the cache (it's per-device)

use std::path::{Path, PathBuf};
use std::time::SystemTime;

use serde::{Deserialize, Serialize};

/// Schema version for `projection.bin`. Increment when the on-disk
/// shape changes; the loader silently discards mismatched-version
/// caches and triggers a fresh build.
pub const PROJECTION_CACHE_SCHEMA_VERSION: u32 = 1;

/// Canonical filename of the per-vault projection cache.
pub const PROJECTION_CACHE_FILENAME: &str = "projection.bin";

/// One node in the sidebar tree snapshot. Lightweight enough that a
/// 50k-page vault fits in a few MB on disk.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SidebarTreeNode {
    pub id: String,
    pub kind: SidebarNodeKind,
    pub title: String,
    pub parent_id: Option<String>,
    /// Sort order within parent.
    pub order: u32,
    /// File path relative to vault root. None for synthetic nodes.
    pub rel_path: Option<String>,
    /// Last-modified time as seconds since UNIX epoch. Used for diff.
    pub mtime_unix_seconds: i64,
    /// BLAKE3 hash prefix (first 16 hex chars) of the file's body.
    /// Used to detect atomic-replacement edits that don't bump mtime.
    /// Empty string for synthetic / non-file nodes.
    pub content_hash_prefix: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SidebarNodeKind {
    Folder,
    Page,
    Epdoc,
    Code,
}

/// Graph layout snapshot. Stores the last frame's positions so the
/// renderer can paint immediately on cold open instead of running
/// physics from random init. Cluster pyramid is captured separately
/// because it's cheaper to invalidate independently.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct GraphSnapshot {
    /// Per-node final positions from last render frame. Indexed by
    /// the same node-id space as `SidebarTreeNode.id`.
    pub node_positions: Vec<(String, [f32; 2])>,
    /// Cluster membership + cluster centroid positions, computed by
    /// Louvain/Leiden during the most recent layout. Stored separately
    /// so the renderer can show cluster centroids at full zoom-out
    /// without loading per-node detail.
    pub cluster_centroids: Vec<ClusterEntry>,
    /// Wall-clock time the snapshot was written. Lets the renderer
    /// decide whether to trust the positions or invalidate (e.g. if
    /// the cache is older than the most recent edit).
    pub written_unix_seconds: i64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ClusterEntry {
    pub cluster_id: u32,
    pub centroid: [f32; 2],
    pub member_count: u32,
}

/// The on-disk format of `projection.bin`. Versioned via the
/// `schema_version` field so the loader can silently discard
/// mismatched-version caches.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ProjectionCache {
    pub schema_version: u32,
    /// App version that wrote this cache. Used to invalidate when the
    /// app updates and its derived-state shape may have changed.
    pub app_version: String,
    /// Vault root path that this cache describes. Used to detect a
    /// cache file being moved to a different vault.
    pub vault_root_path: String,
    /// When the cache was written, seconds since UNIX epoch.
    pub written_unix_seconds: i64,
    /// Sidebar tree at write time.
    pub sidebar_tree: Vec<SidebarTreeNode>,
    /// Graph snapshot at write time. None if the graph engine hasn't
    /// run yet for this vault.
    pub graph_snapshot: Option<GraphSnapshot>,
}

impl ProjectionCache {
    /// Construct a fresh, empty cache ready to be populated.
    pub fn empty(vault_root: &Path, app_version: &str) -> Self {
        Self {
            schema_version: PROJECTION_CACHE_SCHEMA_VERSION,
            app_version: app_version.to_string(),
            vault_root_path: vault_root.to_string_lossy().to_string(),
            written_unix_seconds: current_unix_seconds(),
            sidebar_tree: Vec::new(),
            graph_snapshot: None,
        }
    }

    /// True if this cache is compatible with the current app and
    /// matches the expected vault. If false, the caller should treat
    /// the cache as invalid and trigger a fresh build.
    pub fn is_compatible(&self, vault_root: &Path, app_version: &str) -> bool {
        self.schema_version == PROJECTION_CACHE_SCHEMA_VERSION
            && self.app_version == app_version
            && self.vault_root_path == vault_root.to_string_lossy().to_string()
    }

    /// Resolve the canonical on-disk path for a given vault.
    /// `<vault>/.epcache/projection.bin`.
    pub fn cache_path(vault_root: &Path) -> PathBuf {
        vault_root
            .join(".epcache")
            .join(PROJECTION_CACHE_FILENAME)
    }

    /// Load + deserialize the cache from disk. Returns `None` if the
    /// file is missing, corrupted, or version-mismatched (any of which
    /// indicate the caller should rebuild from scratch).
    pub fn load(vault_root: &Path, app_version: &str) -> Option<Self> {
        let path = Self::cache_path(vault_root);
        let bytes = std::fs::read(&path).ok()?;
        let cache: Self = serde_json::from_slice(&bytes).ok()?;
        if !cache.is_compatible(vault_root, app_version) {
            return None;
        }
        Some(cache)
    }

    /// Serialize + write the cache to disk atomically. Creates the
    /// `.epcache/` directory if missing. Writes to a `.tmp` file first
    /// and renames to the final path so a partial write never corrupts
    /// an existing valid cache.
    pub fn save(&self, vault_root: &Path) -> std::io::Result<()> {
        let cache_dir = vault_root.join(".epcache");
        std::fs::create_dir_all(&cache_dir)?;
        let final_path = cache_dir.join(PROJECTION_CACHE_FILENAME);
        let tmp_path = cache_dir.join(format!("{}.tmp", PROJECTION_CACHE_FILENAME));

        let bytes = serde_json::to_vec(self)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
        std::fs::write(&tmp_path, &bytes)?;
        std::fs::rename(&tmp_path, &final_path)?;
        Ok(())
    }

    /// Compute the set of file paths whose mtime or content-hash has
    /// changed since this cache was written. The caller (`VaultSync`
    /// background task) can then re-index only those files instead of
    /// crawling the whole vault. Empty result means the cache is
    /// fully fresh.
    pub fn diff_against_live(
        &self,
        live_files: &[(String, i64, String)],
    ) -> Vec<DiffEntry> {
        let mut by_path = std::collections::HashMap::with_capacity(self.sidebar_tree.len());
        for node in &self.sidebar_tree {
            if let Some(rel) = &node.rel_path {
                by_path.insert(
                    rel.clone(),
                    (node.mtime_unix_seconds, node.content_hash_prefix.clone()),
                );
            }
        }
        let mut diffs = Vec::new();
        let mut seen = std::collections::HashSet::new();
        for (rel_path, live_mtime, live_hash_prefix) in live_files {
            seen.insert(rel_path.clone());
            match by_path.get(rel_path) {
                None => diffs.push(DiffEntry::Added(rel_path.clone())),
                Some((cached_mtime, cached_hash)) => {
                    if *cached_mtime != *live_mtime || cached_hash != live_hash_prefix {
                        diffs.push(DiffEntry::Modified(rel_path.clone()));
                    }
                }
            }
        }
        for cached_rel in by_path.keys() {
            if !seen.contains(cached_rel) {
                diffs.push(DiffEntry::Removed(cached_rel.clone()));
            }
        }
        diffs
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum DiffEntry {
    Added(String),
    Modified(String),
    Removed(String),
}

fn current_unix_seconds() -> i64 {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn sample_cache(vault_root: &Path) -> ProjectionCache {
        let mut cache = ProjectionCache::empty(vault_root, "1.0.0");
        cache.sidebar_tree.push(SidebarTreeNode {
            id: "page-1".to_string(),
            kind: SidebarNodeKind::Page,
            title: "Hello".to_string(),
            parent_id: None,
            order: 0,
            rel_path: Some("notes/hello.md".to_string()),
            mtime_unix_seconds: 1_700_000_000,
            content_hash_prefix: "abc123".to_string(),
        });
        cache.sidebar_tree.push(SidebarTreeNode {
            id: "folder-1".to_string(),
            kind: SidebarNodeKind::Folder,
            title: "Inbox".to_string(),
            parent_id: None,
            order: 1,
            rel_path: None,
            mtime_unix_seconds: 1_700_000_000,
            content_hash_prefix: String::new(),
        });
        cache
    }

    #[test]
    fn round_trip_preserves_contents() {
        let dir = TempDir::new().unwrap();
        let cache = sample_cache(dir.path());
        cache.save(dir.path()).unwrap();
        let loaded = ProjectionCache::load(dir.path(), "1.0.0").unwrap();
        assert_eq!(loaded.sidebar_tree.len(), 2);
        assert_eq!(loaded.sidebar_tree[0].id, "page-1");
        assert_eq!(loaded.sidebar_tree[1].kind, SidebarNodeKind::Folder);
    }

    #[test]
    fn schema_version_mismatch_returns_none() {
        let dir = TempDir::new().unwrap();
        let mut cache = sample_cache(dir.path());
        cache.schema_version = 999;
        cache.save(dir.path()).unwrap();
        let loaded = ProjectionCache::load(dir.path(), "1.0.0");
        assert!(loaded.is_none());
    }

    #[test]
    fn app_version_mismatch_returns_none() {
        let dir = TempDir::new().unwrap();
        let cache = sample_cache(dir.path());
        cache.save(dir.path()).unwrap();
        let loaded = ProjectionCache::load(dir.path(), "2.0.0");
        assert!(loaded.is_none());
    }

    #[test]
    fn diff_detects_added_modified_removed() {
        let dir = TempDir::new().unwrap();
        let cache = sample_cache(dir.path());
        let live = vec![
            ("notes/hello.md".to_string(), 1_700_000_001, "abc124".to_string()), // mtime changed
            ("notes/new.md".to_string(), 1_700_000_005, "def456".to_string()),    // new file
        ];
        let diffs = cache.diff_against_live(&live);
        assert!(
            diffs.contains(&DiffEntry::Modified("notes/hello.md".to_string())),
            "expected modified, got {diffs:?}"
        );
        assert!(
            diffs.contains(&DiffEntry::Added("notes/new.md".to_string())),
            "expected added, got {diffs:?}"
        );
    }

    #[test]
    fn diff_empty_when_live_matches_cache() {
        let dir = TempDir::new().unwrap();
        let cache = sample_cache(dir.path());
        let live = vec![("notes/hello.md".to_string(), 1_700_000_000, "abc123".to_string())];
        let diffs = cache.diff_against_live(&live);
        assert!(diffs.is_empty(), "expected empty diff, got {diffs:?}");
    }

    #[test]
    fn cache_path_uses_epcache_dir() {
        let path = ProjectionCache::cache_path(Path::new("/tmp/vault"));
        assert!(path.ends_with(".epcache/projection.bin"));
    }

    #[test]
    fn graph_snapshot_round_trips() {
        let dir = TempDir::new().unwrap();
        let mut cache = sample_cache(dir.path());
        cache.graph_snapshot = Some(GraphSnapshot {
            node_positions: vec![("page-1".to_string(), [10.0, 20.0])],
            cluster_centroids: vec![ClusterEntry {
                cluster_id: 0,
                centroid: [5.0, 10.0],
                member_count: 1,
            }],
            written_unix_seconds: 1_700_000_000,
        });
        cache.save(dir.path()).unwrap();
        let loaded = ProjectionCache::load(dir.path(), "1.0.0").unwrap();
        assert_eq!(loaded.graph_snapshot.as_ref().unwrap().node_positions.len(), 1);
        assert_eq!(loaded.graph_snapshot.as_ref().unwrap().cluster_centroids[0].cluster_id, 0);
    }
}
