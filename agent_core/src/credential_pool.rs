//! Credential Pool — Multi-Key Rotation for API Authentication Failures
//!
//! When an API key is rejected (401/403), automatically rotate to the next
//! key in the pool. Tracks exhausted keys per session and per provider.
//!
//! Reference: Hermes `agent/credential_manager.py`

use std::collections::HashMap;
use std::sync::Mutex;

/// A pool of API keys for a single provider, with rotation tracking.
#[derive(Debug, Clone)]
pub struct ProviderCredentialPool {
    provider: String,
    keys: Vec<String>,
    /// Index of the currently active key.
    current_index: usize,
    /// Indices of keys that have been exhausted (failed auth).
    exhausted: Vec<usize>,
    /// Maximum rotation attempts before giving up on this provider.
    max_rotations: usize,
}

impl ProviderCredentialPool {
    /// Create a new credential pool for a provider.
    /// If `keys` is empty, the pool will be in "passthrough" mode — no rotation possible.
    pub fn new(provider: impl Into<String>, keys: Vec<String>) -> Self {
        Self {
            provider: provider.into(),
            keys,
            current_index: 0,
            exhausted: Vec::new(),
            max_rotations: 3,
        }
    }

    /// Get the currently active API key.
    pub fn current_key(&self) -> Option<&str> {
        self.keys.get(self.current_index).map(|s| s.as_str())
    }

    /// Rotate to the next available key. Returns true if a new key is available,
    /// false if all keys are exhausted.
    pub fn rotate(&mut self) -> bool {
        if self.keys.is_empty() {
            return false;
        }

        // Mark current key as exhausted
        if !self.exhausted.contains(&self.current_index) {
            self.exhausted.push(self.current_index);
        }

        // Find next non-exhausted key
        for offset in 1..self.keys.len() {
            let next_index = (self.current_index + offset) % self.keys.len();
            if !self.exhausted.contains(&next_index) {
                self.current_index = next_index;
                tracing::info!(
                    provider = %self.provider,
                    from_index = self.exhausted.last().unwrap_or(&0),
                    to_index = next_index,
                    "Rotated to next API key"
                );
                return true;
            }
        }

        tracing::warn!(
            provider = %self.provider,
            exhausted_count = self.exhausted.len(),
            total_keys = self.keys.len(),
            "All API keys exhausted for provider"
        );
        false
    }

    /// Check if all keys are exhausted.
    pub fn all_exhausted(&self) -> bool {
        if self.keys.is_empty() {
            return true;
        }
        self.exhausted.len() >= self.keys.len().min(self.max_rotations)
    }

    /// Reset the pool (e.g., on session start).
    pub fn reset(&mut self) {
        self.current_index = 0;
        self.exhausted.clear();
    }

    /// Get the provider name.
    pub fn provider(&self) -> &str {
        &self.provider
    }

    /// Get number of keys in the pool.
    pub fn key_count(&self) -> usize {
        self.keys.len()
    }

    /// Get number of exhausted keys.
    pub fn exhausted_count(&self) -> usize {
        self.exhausted.len()
    }
}

/// Global credential manager — holds pools for all configured providers.
pub struct CredentialManager {
    pools: Mutex<HashMap<String, ProviderCredentialPool>>,
}

impl CredentialManager {
    pub fn new() -> Self {
        Self {
            pools: Mutex::new(HashMap::new()),
        }
    }

    /// Register a credential pool for a provider.
    pub fn register_pool(&self, provider: &str, keys: Vec<String>) {
        let mut pools = self.pools.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        pools.insert(provider.to_string(), ProviderCredentialPool::new(provider, keys));
    }

    /// Get the current key for a provider.
    pub fn current_key(&self, provider: &str) -> Option<String> {
        let pools = self.pools.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        pools.get(provider).and_then(|p| p.current_key().map(|s| s.to_string()))
    }

    /// Rotate credentials for a provider. Returns true if a new key is available.
    pub fn rotate(&self, provider: &str) -> bool {
        let mut pools = self.pools.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        pools.get_mut(provider).map_or(false, |p| p.rotate())
    }

    /// Check if all keys are exhausted for a provider.
    pub fn all_exhausted(&self, provider: &str) -> bool {
        let pools = self.pools.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        pools.get(provider).map_or(true, |p| p.all_exhausted())
    }

    /// Reset all pools (e.g., on new session).
    pub fn reset_all(&self) {
        let mut pools = self.pools.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        for pool in pools.values_mut() {
            pool.reset();
        }
    }

    /// Get a snapshot of all pool states (for diagnostics/FFI).
    pub fn snapshot(&self) -> HashMap<String, (usize, usize)> {
        let pools = self.pools.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        pools
            .iter()
            .map(|(k, v)| (k.clone(), (v.key_count(), v.exhausted_count())))
            .collect()
    }
}

impl Default for CredentialManager {
    fn default() -> Self {
        Self::new()
    }
}

/// Convenience: build a credential manager from a simple key map.
/// `keys_by_provider` maps provider name → list of API keys.
pub fn build_credential_manager(keys_by_provider: HashMap<String, Vec<String>>) -> CredentialManager {
    let manager = CredentialManager::new();
    for (provider, keys) in keys_by_provider {
        manager.register_pool(&provider, keys);
    }
    manager
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rotates_through_keys() {
        let mut pool = ProviderCredentialPool::new("claude", vec![
            "key_1".to_string(),
            "key_2".to_string(),
            "key_3".to_string(),
        ]);

        assert_eq!(pool.current_key(), Some("key_1"));
        assert!(pool.rotate());
        assert_eq!(pool.current_key(), Some("key_2"));
        assert!(pool.rotate());
        assert_eq!(pool.current_key(), Some("key_3"));
        // All keys exhausted
        assert!(!pool.rotate());
        assert!(pool.all_exhausted());
    }

    #[test]
    fn empty_pool_is_always_exhausted() {
        let mut pool = ProviderCredentialPool::new("claude", vec![]);
        assert_eq!(pool.current_key(), None);
        assert!(pool.all_exhausted());
        assert!(!pool.rotate());
    }

    #[test]
    fn single_key_pool() {
        let mut pool = ProviderCredentialPool::new("claude", vec!["only_key".to_string()]);
        assert_eq!(pool.current_key(), Some("only_key"));
        assert!(!pool.rotate());
        assert!(pool.all_exhausted());
    }

    #[test]
    fn reset_clears_exhausted() {
        let mut pool = ProviderCredentialPool::new("claude", vec![
            "key_1".to_string(),
            "key_2".to_string(),
        ]);
        pool.rotate();
        assert_eq!(pool.exhausted_count(), 1);
        pool.reset();
        assert_eq!(pool.exhausted_count(), 0);
        assert_eq!(pool.current_key(), Some("key_1"));
    }

    #[test]
    fn manager_rotate_across_providers() {
        let manager = CredentialManager::new();
        manager.register_pool("claude", vec!["c1".to_string(), "c2".to_string()]);
        manager.register_pool("openai", vec!["o1".to_string()]);

        assert_eq!(manager.current_key("claude"), Some("c1".to_string()));
        assert!(manager.rotate("claude"));
        assert_eq!(manager.current_key("claude"), Some("c2".to_string()));
        assert!(!manager.rotate("claude"));
        assert!(manager.all_exhausted("claude"));

        // OpenAI has only one key
        assert!(!manager.rotate("openai"));
        assert!(manager.all_exhausted("openai"));
    }

    #[test]
    fn manager_reset_all() {
        let manager = CredentialManager::new();
        manager.register_pool("claude", vec!["c1".to_string(), "c2".to_string()]);
        // Rotate once: c1 exhausted, now on c2
        manager.rotate("claude");
        assert_eq!(manager.current_key("claude"), Some("c2".to_string()));
        // Not all exhausted yet — c2 still available
        assert!(!manager.all_exhausted("claude"));

        // Rotate again: all exhausted
        manager.rotate("claude");
        assert!(manager.all_exhausted("claude"));

        manager.reset_all();
        assert!(!manager.all_exhausted("claude"));
        assert_eq!(manager.current_key("claude"), Some("c1".to_string()));
    }
}
