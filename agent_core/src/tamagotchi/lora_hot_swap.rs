//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.3 G5 — LoRA hot-swap research spike (50 × 50 MB LoRA
//!   per companion).
//! - `COGNITIVE_DAG_DOCTRINE §6 cost` — per-companion LoRA ceiling
//!   doctrine.
//! - Companion to [`super::sprite_atlas::CharacterDna`] (5 DNAs;
//!   each can carry up to 50 swappable LoRAs).
//!
//! # Phase B.3 G5 — LoRA hot-swap substrate (completes Wave G)
//!
//! Per-companion ceiling: 50 × 50 MB = 2.5 GB. On M2 Pro 16 GB this
//! fits comfortably for one or two simultaneously-active companions;
//! more requires LRU eviction. Substrate floor owns the manager +
//! LRU policy + per-LoRA descriptor.
//!
//! ## HARDWARE-BUDGET
//!
//! M2 Pro 16 GB: ~10 GB usable for model + KV + LoRA pool after OS
//! reserves. Active model (Qwen3-8B Q4) = 5 GB; KV at 32k = 1-2 GB;
//! leaves ~3 GB for LoRA pool. With 50 MB per LoRA, that's ~60 LoRAs
//! resident across all companions — eviction is necessary when more
//! companions need their LoRA stack simultaneously.

use serde::{Deserialize, Serialize};

pub const LORA_BYTES_PER_ADAPTER: u64 = 50 * 1024 * 1024;
pub const MAX_LORAS_PER_COMPANION: u32 = 50;
pub const PER_COMPANION_CEILING_BYTES: u64 =
    LORA_BYTES_PER_ADAPTER * (MAX_LORAS_PER_COMPANION as u64);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct LoraDescriptor {
    pub id: String,
    pub byte_size: u64,
    pub companion_id: String,
    pub last_used_unix_ms: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LoraHotSwapManager {
    pub pool_capacity_bytes: u64,
    pub loaded: Vec<LoraDescriptor>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum LoraSwapError {
    ZeroCapacity,
    LoraTooLarge { id_byte_size: u64, capacity: u64 },
    PerCompanionCeilingExceeded { companion_id_size: u64, ceiling: u64 },
    AdapterNotFound,
}

impl LoraHotSwapManager {
    pub fn new(pool_capacity_bytes: u64) -> Result<Self, LoraSwapError> {
        if pool_capacity_bytes == 0 {
            return Err(LoraSwapError::ZeroCapacity);
        }
        Ok(Self { pool_capacity_bytes, loaded: Vec::new() })
    }

    pub fn current_bytes(&self) -> u64 {
        self.loaded.iter().map(|d| d.byte_size).sum()
    }

    pub fn free_bytes(&self) -> u64 {
        self.pool_capacity_bytes.saturating_sub(self.current_bytes())
    }

    pub fn bytes_for_companion(&self, companion_id: &str) -> u64 {
        self.loaded
            .iter()
            .filter(|d| d.companion_id == companion_id)
            .map(|d| d.byte_size)
            .sum()
    }

    pub fn count_for_companion(&self, companion_id: &str) -> u32 {
        self.loaded
            .iter()
            .filter(|d| d.companion_id == companion_id)
            .count() as u32
    }

    /// Swap in a LoRA, evicting the least-recently-used adapters as
    /// needed to make room. Enforces per-companion ceiling.
    pub fn swap_in(&mut self, descriptor: LoraDescriptor) -> Result<(), LoraSwapError> {
        if descriptor.byte_size > self.pool_capacity_bytes {
            return Err(LoraSwapError::LoraTooLarge {
                id_byte_size: descriptor.byte_size,
                capacity: self.pool_capacity_bytes,
            });
        }
        let companion_after =
            self.bytes_for_companion(&descriptor.companion_id) + descriptor.byte_size;
        if companion_after > PER_COMPANION_CEILING_BYTES {
            return Err(LoraSwapError::PerCompanionCeilingExceeded {
                companion_id_size: companion_after,
                ceiling: PER_COMPANION_CEILING_BYTES,
            });
        }
        while self.free_bytes() < descriptor.byte_size {
            if self.loaded.is_empty() {
                return Err(LoraSwapError::LoraTooLarge {
                    id_byte_size: descriptor.byte_size,
                    capacity: self.pool_capacity_bytes,
                });
            }
            let lru_idx = self
                .loaded
                .iter()
                .enumerate()
                .min_by_key(|(_, d)| d.last_used_unix_ms)
                .map(|(i, _)| i)
                .unwrap();
            self.loaded.remove(lru_idx);
        }
        self.loaded.push(descriptor);
        Ok(())
    }

    /// Swap out (evict) a LoRA by id. Errors if not loaded.
    pub fn swap_out(&mut self, id: &str) -> Result<(), LoraSwapError> {
        let idx = self
            .loaded
            .iter()
            .position(|d| d.id == id)
            .ok_or(LoraSwapError::AdapterNotFound)?;
        self.loaded.remove(idx);
        Ok(())
    }

    pub fn touch(&mut self, id: &str, now_unix_ms: u64) -> Result<(), LoraSwapError> {
        let d = self
            .loaded
            .iter_mut()
            .find(|d| d.id == id)
            .ok_or(LoraSwapError::AdapterNotFound)?;
        d.last_used_unix_ms = now_unix_ms;
        Ok(())
    }

    /// Number of adapters currently resident in the pool.
    pub fn loaded_count(&self) -> usize {
        self.loaded.len()
    }

    /// Predicate: nothing is currently loaded.
    pub fn is_empty(&self) -> bool {
        self.loaded.is_empty()
    }

    /// Predicate: an adapter with this id is currently resident.
    /// Cross-surface invariant: `contains(id)` iff `touch(id, _)`
    /// would return `Ok(())`.
    pub fn contains(&self, id: &str) -> bool {
        self.loaded.iter().any(|d| d.id == id)
    }

    /// Pool utilization in `[0.0, 1.0]`: `current_bytes /
    /// pool_capacity_bytes`. Returns `None` only if the pool has
    /// zero capacity (which the constructor rejects, but defensive
    /// against post-construction mutation).
    pub fn utilization(&self) -> Option<f64> {
        if self.pool_capacity_bytes == 0 {
            return None;
        }
        Some(self.current_bytes() as f64 / self.pool_capacity_bytes as f64)
    }

    /// Id of the least-recently-used (lowest `last_used_unix_ms`)
    /// resident adapter, or `None` if the pool is empty. The next
    /// candidate the LRU policy would evict.
    pub fn lru_id(&self) -> Option<&str> {
        self.loaded
            .iter()
            .min_by_key(|d| d.last_used_unix_ms)
            .map(|d| d.id.as_str())
    }

    /// Id of the most-recently-used resident adapter, or `None` if
    /// the pool is empty. Companion to [`Self::lru_id`].
    pub fn mru_id(&self) -> Option<&str> {
        self.loaded
            .iter()
            .max_by_key(|d| d.last_used_unix_ms)
            .map(|d| d.id.as_str())
    }
}

impl LoraSwapError {
    /// Predicate: this error stems from capacity / size limits
    /// (ZeroCapacity / LoraTooLarge / PerCompanionCeilingExceeded).
    pub const fn is_capacity_error(&self) -> bool {
        matches!(
            self,
            LoraSwapError::ZeroCapacity
                | LoraSwapError::LoraTooLarge { .. }
                | LoraSwapError::PerCompanionCeilingExceeded { .. }
        )
    }

    /// Predicate: this error stems from a lookup failure
    /// (AdapterNotFound). Cross-surface invariant: every variant
    /// satisfies exactly one of `is_capacity_error` / `is_lookup_error`.
    pub const fn is_lookup_error(&self) -> bool {
        matches!(self, LoraSwapError::AdapterNotFound)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lora(id: &str, byte_size: u64, companion: &str, last_used: u64) -> LoraDescriptor {
        LoraDescriptor {
            id: id.to_string(),
            byte_size,
            companion_id: companion.to_string(),
            last_used_unix_ms: last_used,
        }
    }

    #[test]
    fn constants_match_doctrine() {
        assert_eq!(LORA_BYTES_PER_ADAPTER, 50 * 1024 * 1024);
        assert_eq!(MAX_LORAS_PER_COMPANION, 50);
        assert_eq!(PER_COMPANION_CEILING_BYTES, 50 * 50 * 1024 * 1024);
    }

    #[test]
    fn zero_capacity_rejected() {
        let err = LoraHotSwapManager::new(0).unwrap_err();
        assert_eq!(err, LoraSwapError::ZeroCapacity);
    }

    #[test]
    fn fresh_manager_has_zero_bytes_loaded() {
        let m = LoraHotSwapManager::new(1024 * 1024 * 1024).unwrap();
        assert_eq!(m.current_bytes(), 0);
        assert_eq!(m.free_bytes(), 1024 * 1024 * 1024);
    }

    #[test]
    fn swap_in_within_capacity_loads() {
        let mut m = LoraHotSwapManager::new(200 * 1024 * 1024).unwrap();
        m.swap_in(lora("a", 50 * 1024 * 1024, "c1", 0)).unwrap();
        m.swap_in(lora("b", 50 * 1024 * 1024, "c1", 1)).unwrap();
        assert_eq!(m.current_bytes(), 100 * 1024 * 1024);
    }

    #[test]
    fn lora_larger_than_pool_rejected() {
        let mut m = LoraHotSwapManager::new(10 * 1024 * 1024).unwrap();
        let err = m
            .swap_in(lora("big", 100 * 1024 * 1024, "c1", 0))
            .unwrap_err();
        assert!(matches!(err, LoraSwapError::LoraTooLarge { .. }));
    }

    #[test]
    fn per_companion_ceiling_enforced() {
        let mut m =
            LoraHotSwapManager::new(PER_COMPANION_CEILING_BYTES + LORA_BYTES_PER_ADAPTER).unwrap();
        for i in 0..50 {
            m.swap_in(lora(&format!("a{}", i), LORA_BYTES_PER_ADAPTER, "c1", i)).unwrap();
        }
        let err = m
            .swap_in(lora("overflow", LORA_BYTES_PER_ADAPTER, "c1", 50))
            .unwrap_err();
        assert!(matches!(err, LoraSwapError::PerCompanionCeilingExceeded { .. }));
    }

    #[test]
    fn lru_eviction_makes_room() {
        let mut m = LoraHotSwapManager::new(150 * 1024 * 1024).unwrap();
        m.swap_in(lora("oldest", 50 * 1024 * 1024, "c1", 100)).unwrap();
        m.swap_in(lora("middle", 50 * 1024 * 1024, "c2", 200)).unwrap();
        m.swap_in(lora("newest", 50 * 1024 * 1024, "c3", 300)).unwrap();
        assert_eq!(m.loaded.len(), 3);
        m.swap_in(lora("incoming", 50 * 1024 * 1024, "c4", 400)).unwrap();
        assert_eq!(m.loaded.len(), 3);
        assert!(m.loaded.iter().all(|d| d.id != "oldest"));
    }

    #[test]
    fn swap_out_removes_adapter() {
        let mut m = LoraHotSwapManager::new(100 * 1024 * 1024).unwrap();
        m.swap_in(lora("a", 50 * 1024 * 1024, "c1", 0)).unwrap();
        m.swap_out("a").unwrap();
        assert_eq!(m.loaded.len(), 0);
    }

    #[test]
    fn swap_out_unknown_errors() {
        let mut m = LoraHotSwapManager::new(100 * 1024 * 1024).unwrap();
        let err = m.swap_out("nonexistent").unwrap_err();
        assert_eq!(err, LoraSwapError::AdapterNotFound);
    }

    #[test]
    fn touch_updates_last_used_for_lru() {
        let mut m = LoraHotSwapManager::new(150 * 1024 * 1024).unwrap();
        m.swap_in(lora("oldest", 50 * 1024 * 1024, "c1", 100)).unwrap();
        m.swap_in(lora("middle", 50 * 1024 * 1024, "c2", 200)).unwrap();
        m.swap_in(lora("newest", 50 * 1024 * 1024, "c3", 300)).unwrap();
        m.touch("oldest", 500).unwrap();
        m.swap_in(lora("incoming", 50 * 1024 * 1024, "c4", 400)).unwrap();
        assert!(m.loaded.iter().any(|d| d.id == "oldest"));
        assert!(!m.loaded.iter().any(|d| d.id == "middle"));
    }

    #[test]
    fn touch_unknown_errors() {
        let mut m = LoraHotSwapManager::new(100 * 1024 * 1024).unwrap();
        let err = m.touch("nonexistent", 0).unwrap_err();
        assert_eq!(err, LoraSwapError::AdapterNotFound);
    }

    #[test]
    fn count_and_bytes_per_companion_tracked() {
        let mut m = LoraHotSwapManager::new(300 * 1024 * 1024).unwrap();
        m.swap_in(lora("a", 50 * 1024 * 1024, "c1", 0)).unwrap();
        m.swap_in(lora("b", 50 * 1024 * 1024, "c1", 1)).unwrap();
        m.swap_in(lora("c", 50 * 1024 * 1024, "c2", 2)).unwrap();
        assert_eq!(m.count_for_companion("c1"), 2);
        assert_eq!(m.count_for_companion("c2"), 1);
        assert_eq!(m.bytes_for_companion("c1"), 100 * 1024 * 1024);
    }

    #[test]
    fn manager_roundtrips_through_serde_json() {
        let mut m = LoraHotSwapManager::new(100 * 1024 * 1024).unwrap();
        m.swap_in(lora("a", 50 * 1024 * 1024, "c1", 0)).unwrap();
        let json = serde_json::to_string(&m).unwrap();
        let back: LoraHotSwapManager = serde_json::from_str(&json).unwrap();
        assert_eq!(m, back);
    }

    #[test]
    fn free_bytes_saturates_at_zero() {
        let mut m = LoraHotSwapManager::new(50 * 1024 * 1024).unwrap();
        m.swap_in(lora("a", 50 * 1024 * 1024, "c1", 0)).unwrap();
        assert_eq!(m.free_bytes(), 0);
    }

    // ── diagnostic surface (iter 139) ────────────────────────────────────────

    #[test]
    fn fresh_manager_is_empty() {
        let m = LoraHotSwapManager::new(100 * 1024 * 1024).unwrap();
        assert!(m.is_empty());
        assert_eq!(m.loaded_count(), 0);
        assert_eq!(m.lru_id(), None);
        assert_eq!(m.mru_id(), None);
    }

    #[test]
    fn loaded_count_matches_loaded_len() {
        let mut m = LoraHotSwapManager::new(300 * 1024 * 1024).unwrap();
        m.swap_in(lora("a", 50 * 1024 * 1024, "c1", 0)).unwrap();
        m.swap_in(lora("b", 50 * 1024 * 1024, "c1", 1)).unwrap();
        m.swap_in(lora("c", 50 * 1024 * 1024, "c2", 2)).unwrap();
        assert_eq!(m.loaded_count(), 3);
        assert!(!m.is_empty());
    }

    #[test]
    fn contains_matches_swap_in_state() {
        let mut m = LoraHotSwapManager::new(150 * 1024 * 1024).unwrap();
        assert!(!m.contains("a"));
        m.swap_in(lora("a", 50 * 1024 * 1024, "c1", 0)).unwrap();
        assert!(m.contains("a"));
        m.swap_out("a").unwrap();
        assert!(!m.contains("a"));
    }

    #[test]
    fn contains_aligns_with_touch_result() {
        // Cross-surface: contains(id) iff touch(id, _) returns Ok.
        let mut m = LoraHotSwapManager::new(100 * 1024 * 1024).unwrap();
        m.swap_in(lora("present", 50 * 1024 * 1024, "c1", 0)).unwrap();
        assert_eq!(m.contains("present"), m.touch("present", 5).is_ok());
        assert_eq!(m.contains("absent"), m.touch("absent", 5).is_ok());
    }

    #[test]
    fn utilization_and_free_bytes_partition_capacity() {
        // Cross-surface invariant: current_bytes + free_bytes = pool_capacity_bytes
        // (and utilization × capacity ≈ current_bytes).
        let mut m = LoraHotSwapManager::new(300 * 1024 * 1024).unwrap();
        m.swap_in(lora("a", 50 * 1024 * 1024, "c1", 0)).unwrap();
        m.swap_in(lora("b", 70 * 1024 * 1024, "c2", 1)).unwrap();
        let cur = m.current_bytes();
        let free = m.free_bytes();
        assert_eq!(cur + free, m.pool_capacity_bytes);
        let u = m.utilization().unwrap();
        assert!((u * (m.pool_capacity_bytes as f64) - cur as f64).abs() < 1.0);
    }

    #[test]
    fn utilization_full_pool_is_one() {
        let mut m = LoraHotSwapManager::new(50 * 1024 * 1024).unwrap();
        m.swap_in(lora("a", 50 * 1024 * 1024, "c1", 0)).unwrap();
        assert!((m.utilization().unwrap() - 1.0).abs() < 1e-9);
    }

    #[test]
    fn utilization_empty_pool_is_zero() {
        let m = LoraHotSwapManager::new(100 * 1024 * 1024).unwrap();
        assert!((m.utilization().unwrap() - 0.0).abs() < 1e-9);
    }

    #[test]
    fn lru_and_mru_identify_extreme_last_used() {
        let mut m = LoraHotSwapManager::new(300 * 1024 * 1024).unwrap();
        m.swap_in(lora("oldest", 50 * 1024 * 1024, "c1", 100)).unwrap();
        m.swap_in(lora("middle", 50 * 1024 * 1024, "c2", 200)).unwrap();
        m.swap_in(lora("newest", 50 * 1024 * 1024, "c3", 300)).unwrap();
        assert_eq!(m.lru_id(), Some("oldest"));
        assert_eq!(m.mru_id(), Some("newest"));
    }

    #[test]
    fn lru_is_first_eviction_target() {
        // Cross-surface: when swap_in needs to evict, it removes lru_id().
        let mut m = LoraHotSwapManager::new(150 * 1024 * 1024).unwrap();
        m.swap_in(lora("oldest", 50 * 1024 * 1024, "c1", 100)).unwrap();
        m.swap_in(lora("middle", 50 * 1024 * 1024, "c2", 200)).unwrap();
        m.swap_in(lora("newest", 50 * 1024 * 1024, "c3", 300)).unwrap();
        let expected_evict = m.lru_id().unwrap().to_string();
        m.swap_in(lora("incoming", 50 * 1024 * 1024, "c4", 400)).unwrap();
        assert!(!m.contains(&expected_evict));
    }

    #[test]
    fn touch_updates_mru() {
        let mut m = LoraHotSwapManager::new(150 * 1024 * 1024).unwrap();
        m.swap_in(lora("a", 50 * 1024 * 1024, "c1", 100)).unwrap();
        m.swap_in(lora("b", 50 * 1024 * 1024, "c1", 200)).unwrap();
        m.swap_in(lora("c", 50 * 1024 * 1024, "c1", 300)).unwrap();
        assert_eq!(m.mru_id(), Some("c"));
        m.touch("a", 999).unwrap();
        assert_eq!(m.mru_id(), Some("a"));
        assert_eq!(m.lru_id(), Some("b"));
    }

    #[test]
    fn error_classifiers_partition_variants() {
        let errors = [
            LoraSwapError::ZeroCapacity,
            LoraSwapError::LoraTooLarge { id_byte_size: 0, capacity: 0 },
            LoraSwapError::PerCompanionCeilingExceeded { companion_id_size: 0, ceiling: 0 },
            LoraSwapError::AdapterNotFound,
        ];
        for e in errors.iter() {
            assert_ne!(e.is_capacity_error(), e.is_lookup_error());
        }
        assert!(errors[0].is_capacity_error());
        assert!(errors[1].is_capacity_error());
        assert!(errors[2].is_capacity_error());
        assert!(errors[3].is_lookup_error());
    }
}
