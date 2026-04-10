//! Skills Registry — Persistent skill usage tracking and discovery.
//!
//! Maintains `skills_registry.yaml` inside the vault's `skills/` directory.
//! Tracks usage counts, success rates, and timestamps for each registered skill.
//! Supports relevance-based listing via the existing SkillRouter.

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::storage::vault::VaultError;

// ---------------------------------------------------------------------------
// Registry Entry
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkillRegistryEntry {
    pub name: String,
    pub description: String,
    #[serde(default = "default_version")]
    pub version: String,
    #[serde(default)]
    pub triggers: Vec<String>,
    #[serde(default)]
    pub license: String,
    #[serde(default)]
    pub last_used: Option<DateTime<Utc>>,
    #[serde(default)]
    pub use_count: u32,
    #[serde(default)]
    pub success_count: u32,
    #[serde(default)]
    pub failure_count: u32,
}

fn default_version() -> String {
    "v1".to_string()
}

impl SkillRegistryEntry {
    pub fn avg_success_rate(&self) -> f64 {
        let total = self.success_count + self.failure_count;
        if total == 0 {
            return 1.0; // Assume success for unused skills
        }
        self.success_count as f64 / total as f64
    }
}

// ---------------------------------------------------------------------------
// Registry Store
// ---------------------------------------------------------------------------

/// Persistent registry backed by `skills/skills_registry.yaml`.
pub struct SkillsRegistryStore {
    registry_path: PathBuf,
    entries: HashMap<String, SkillRegistryEntry>,
}

impl SkillsRegistryStore {
    /// Load (or create) the registry from a vault's skills directory.
    pub fn load(vault_root: &Path) -> Self {
        let registry_path = vault_root.join("skills").join("skills_registry.yaml");
        let entries = if registry_path.exists() {
            match fs::read_to_string(&registry_path) {
                Ok(content) => {
                    let list: Vec<SkillRegistryEntry> = serde_yaml::from_str(&content)
                        .unwrap_or_default();
                    list.into_iter()
                        .map(|entry| (entry.name.clone(), entry))
                        .collect()
                }
                Err(_) => HashMap::new(),
            }
        } else {
            HashMap::new()
        };

        Self {
            registry_path,
            entries,
        }
    }

    /// Save the registry to disk.
    pub fn save(&self) -> Result<(), VaultError> {
        if let Some(parent) = self.registry_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let list: Vec<&SkillRegistryEntry> = self.entries.values().collect();
        let yaml = serde_yaml::to_string(&list)
            .map_err(|e| VaultError::DatabaseError(format!("yaml serialize: {e}")))?;
        fs::write(&self.registry_path, yaml)?;
        Ok(())
    }

    /// Register or update a skill entry.
    pub fn register_skill(&mut self, entry: SkillRegistryEntry) {
        self.entries.insert(entry.name.clone(), entry);
    }

    /// Record a usage event for a skill.
    pub fn record_usage(&mut self, name: &str, success: bool) {
        if let Some(entry) = self.entries.get_mut(name) {
            entry.use_count += 1;
            entry.last_used = Some(Utc::now());
            if success {
                entry.success_count += 1;
            } else {
                entry.failure_count += 1;
            }
        }
    }

    /// List all entries sorted by usage count (most used first).
    pub fn list_all(&self) -> Vec<&SkillRegistryEntry> {
        let mut entries: Vec<&SkillRegistryEntry> = self.entries.values().collect();
        entries.sort_by(|a, b| b.use_count.cmp(&a.use_count));
        entries
    }

    /// Get an entry by name.
    pub fn get(&self, name: &str) -> Option<&SkillRegistryEntry> {
        self.entries.get(name)
    }

    /// Number of registered skills.
    pub fn len(&self) -> usize {
        self.entries.len()
    }

    /// Check if registry is empty.
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn make_entry(name: &str) -> SkillRegistryEntry {
        SkillRegistryEntry {
            name: name.to_string(),
            description: format!("{name} skill"),
            version: "v1".to_string(),
            triggers: vec![name.to_string()],
            license: "MIT".to_string(),
            last_used: None,
            use_count: 0,
            success_count: 0,
            failure_count: 0,
        }
    }

    #[test]
    fn register_and_list() {
        let tmp = TempDir::new().unwrap();
        let mut store = SkillsRegistryStore::load(tmp.path());

        store.register_skill(make_entry("vault-search"));
        store.register_skill(make_entry("vault-init"));

        assert_eq!(store.len(), 2);
        assert!(store.get("vault-search").is_some());
    }

    #[test]
    fn record_usage_updates_stats() {
        let tmp = TempDir::new().unwrap();
        let mut store = SkillsRegistryStore::load(tmp.path());

        store.register_skill(make_entry("vault-search"));
        store.record_usage("vault-search", true);
        store.record_usage("vault-search", true);
        store.record_usage("vault-search", false);

        let entry = store.get("vault-search").unwrap();
        assert_eq!(entry.use_count, 3);
        assert_eq!(entry.success_count, 2);
        assert_eq!(entry.failure_count, 1);
        assert!((entry.avg_success_rate() - 0.6667).abs() < 0.01);
    }

    #[test]
    fn save_and_reload() {
        let tmp = TempDir::new().unwrap();
        {
            let mut store = SkillsRegistryStore::load(tmp.path());
            store.register_skill(make_entry("vault-search"));
            store.record_usage("vault-search", true);
            store.save().unwrap();
        }

        let store2 = SkillsRegistryStore::load(tmp.path());
        assert_eq!(store2.len(), 1);
        let entry = store2.get("vault-search").unwrap();
        assert_eq!(entry.use_count, 1);
    }

    #[test]
    fn empty_registry() {
        let tmp = TempDir::new().unwrap();
        let store = SkillsRegistryStore::load(tmp.path());
        assert!(store.is_empty());
        assert_eq!(store.len(), 0);
    }

    #[test]
    fn unused_skill_has_100_success_rate() {
        let entry = make_entry("test");
        assert_eq!(entry.avg_success_rate(), 1.0);
    }
}
