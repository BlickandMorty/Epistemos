//! MTLResidencySet management and GPU/CPU residency tracking.
//!
//! Apple provides `MTLResidencySet` (Metal 3.1+) as a way to declare which
//! buffers and textures must stay resident in GPU memory.  The API is
//! currently private / undocumented; this module implements a **Rust-side**
//! tracker that mirrors the intended behaviour.  When the official API becomes
//! available the [`ResidencyManager`] can be swapped for thin FFI wrappers.
//!
//! # Design
//! * **Hot set** — pages pinned in GPU-visible memory (fast path).
//! * **Cold set** — pages evicted to system memory (slow path, mmap-backed).
//! * **LRU eviction** — when the hot set exceeds a budget, the least-recently
//!   touched page is demoted.
//! * **Predictive tracker** — access-pattern histograms inform pre-fetching.

use std::collections::{HashMap, HashSet, VecDeque};

use tracing::{debug, info, trace, warn};

use crate::types::PageId;

// ---------------------------------------------------------------------------
// ResidencyManager
// ---------------------------------------------------------------------------

/// Tracks which pages are resident in GPU memory vs. system memory.
///
/// TODO: integrate with `MTLResidencySet` when the API becomes public.
#[derive(Debug, Clone)]
pub struct ResidencyManager {
    /// Pages currently pinned in GPU memory.
    pub hot_set: HashSet<PageId>,
    /// Pages stored in CPU/system memory (may be mmap-backed).
    pub cold_set: HashSet<PageId>,
    /// Maximum number of pages allowed in the hot set.
    pub hot_budget: usize,
    /// LRU queue — front = oldest access, back = newest.
    pub lru_queue: VecDeque<PageId>,
    /// Access counter per page (for telemetry).
    pub access_count: HashMap<PageId, u64>,
    /// Last access tick.
    pub last_tick: u64,
}

impl Default for ResidencyManager {
    fn default() -> Self {
        Self {
            hot_set: HashSet::new(),
            cold_set: HashSet::new(),
            hot_budget: 256,
            lru_queue: VecDeque::new(),
            access_count: HashMap::new(),
            last_tick: 0,
        }
    }
}

impl ResidencyManager {
    /// Create a manager with the given GPU page budget.
    pub fn with_budget(hot_budget: usize) -> Self {
        Self {
            hot_budget,
            ..Default::default()
        }
    }

    /// Promote `page` into the GPU-resident hot set.
    ///
    /// If the hot set is already at capacity, the least-recently-used page is
    /// evicted to the cold set first.
    pub fn promote_to_gpu(&mut self, page: PageId) {
        if self.hot_set.contains(&page) {
            // Touch: move to back of LRU.
            self.touch(page);
            return;
        }

        if self.hot_set.len() >= self.hot_budget {
            self.evict_lru();
        }

        self.cold_set.remove(&page);
        self.hot_set.insert(page);
        self.lru_queue.push_back(page);
        *self.access_count.entry(page).or_insert(0) += 1;
        self.last_tick += 1;

        trace!(
            "promote_to_gpu: page {} | hot={} cold={}",
            page.0,
            self.hot_set.len(),
            self.cold_set.len()
        );
    }

    /// Demote `page` from GPU to CPU residency.
    pub fn demote_to_cpu(&mut self, page: PageId) {
        if !self.hot_set.contains(&page) {
            warn!("demote_to_cpu called on page {} not in hot_set", page.0);
        }
        self.hot_set.remove(&page);
        self.cold_set.insert(page);
        self.lru_queue.retain(|&p| p != page);
        trace!(
            "demote_to_cpu: page {} | hot={} cold={}",
            page.0,
            self.hot_set.len(),
            self.cold_set.len()
        );
    }

    /// Evict the least-recently-used page from the hot set.
    ///
    /// Returns the evicted page, or `None` if the hot set is empty.
    pub fn evict_lru(&mut self) -> Option<PageId> {
        while let Some(page) = self.lru_queue.pop_front() {
            if self.hot_set.contains(&page) {
                self.demote_to_cpu(page);
                return Some(page);
            }
            // Stale entry — page was already removed by an explicit demote.
        }
        None
    }

    /// Record an access to `page` without changing residency.
    pub fn touch(&mut self, page: PageId) {
        self.lru_queue.retain(|&p| p != page);
        self.lru_queue.push_back(page);
        *self.access_count.entry(page).or_insert(0) += 1;
        self.last_tick += 1;
    }

    /// Is `page` currently GPU-resident?
    pub fn is_hot(&self, page: PageId) -> bool {
        self.hot_set.contains(&page)
    }

    /// Is `page` currently CPU-resident?
    pub fn is_cold(&self, page: PageId) -> bool {
        self.cold_set.contains(&page)
    }

    /// Total pages tracked (hot + cold).
    pub fn total_tracked(&self) -> usize {
        self.hot_set.len() + self.cold_set.len()
    }

    /// Remove a page from all residency tracking.
    pub fn remove(&mut self, page: PageId) {
        self.hot_set.remove(&page);
        self.cold_set.remove(&page);
        self.lru_queue.retain(|&p| p != page);
        self.access_count.remove(&page);
    }

    /// Reset all state.
    pub fn clear(&mut self) {
        self.hot_set.clear();
        self.cold_set.clear();
        self.lru_queue.clear();
        self.access_count.clear();
        self.last_tick = 0;
    }
}

// ---------------------------------------------------------------------------
// ResidencyTracker (predictive)
// ---------------------------------------------------------------------------

/// Predictive eviction / pre-fetch tracker.
///
/// Maintains an access-pattern histogram per page.  Pages with a rising access
/// frequency are pre-fetched; pages with declining frequency are evicted early.
#[derive(Debug, Clone, Default)]
pub struct ResidencyTracker {
    /// Per-page access history (ticks at which the page was touched).
    pub history: HashMap<PageId, VecDeque<u64>>,
    /// Maximum history length per page.
    pub window: usize,
}

impl ResidencyTracker {
    pub fn with_window(window: usize) -> Self {
        Self {
            window,
            ..Default::default()
        }
    }

    /// Record an access at tick `t`.
    pub fn record(&mut self, page: PageId, tick: u64) {
        let h = self.history.entry(page).or_insert_with(|| VecDeque::with_capacity(self.window));
        if h.len() >= self.window {
            h.pop_front();
        }
        h.push_back(tick);
    }

    /// Predicted access probability for `page` at `current_tick`.
    ///
    /// Returns a value in `[0, 1]`.  Higher values mean the page is likely to
    /// be accessed again soon.
    pub fn predict(&self, page: PageId, current_tick: u64) -> f32 {
        let Some(h) = self.history.get(&page) else {
            return 0.0;
        };
        if h.len() < 2 {
            return 0.5f32; // insufficient data
        }
        // Compute inter-arrival times.
        let mut iats = Vec::with_capacity(h.len() - 1);
        for w in h.windows(2) {
            iats.push((w[1] - w[0]) as f32);
        }
        let mean_iat = iats.iter().sum::<f32>() / iats.len() as f32;
        let last = *h.back().unwrap();
        let elapsed = (current_tick - last) as f32;
        // If elapsed is close to mean_iat, probability is high.
        let p = (-(elapsed / mean_iat.max(1.0)).powi(2)).exp();
        p.clamp(0.0, 1.0)
    }

    /// Pages sorted by predicted usefulness (descending).
    pub fn ranked_pages(&self, candidates: &[PageId], current_tick: u64) -> Vec<(PageId, f32)> {
        let mut ranked: Vec<(PageId, f32)> = candidates
            .iter()
            .map(|&p| (p, self.predict(p, current_tick)))
            .collect();
        ranked.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
        ranked
    }
}

// ---------------------------------------------------------------------------
// MTLResidencySet bridge (stub)
// ---------------------------------------------------------------------------

/// Placeholder for the Apple `MTLResidencySet` API.
///
/// When the API is public this struct will wrap an `objc2::runtime::Object`
/// pointer and expose `add_residency_set`, `remove_residency_set`, etc.
#[derive(Debug, Clone)]
pub struct MTLResidencySetBridge;

impl MTLResidencySetBridge {
    /// TODO: call `[MTLResidencySet addResidencySet:]` via objc2.
    pub fn add_page(&self, _page: PageId) {
        trace!("MTLResidencySetBridge::add_page stub");
    }

    /// TODO: call `[MTLResidencySet removeResidencySet:]` via objc2.
    pub fn remove_page(&self, _page: PageId) {
        trace!("MTLResidencySetBridge::remove_page stub");
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn promote_and_demote() {
        let mut rm = ResidencyManager::with_budget(2);
        rm.promote_to_gpu(PageId(0));
        rm.promote_to_gpu(PageId(1));
        assert!(rm.is_hot(PageId(0)));
        assert!(rm.is_hot(PageId(1)));
        rm.demote_to_cpu(PageId(0));
        assert!(!rm.is_hot(PageId(0)));
        assert!(rm.is_cold(PageId(0)));
    }

    #[test]
    fn lru_eviction_on_budget_exceeded() {
        let mut rm = ResidencyManager::with_budget(2);
        rm.promote_to_gpu(PageId(0));
        rm.promote_to_gpu(PageId(1));
        rm.promote_to_gpu(PageId(2)); // exceeds budget
        assert!(!rm.is_hot(PageId(0))); // evicted
        assert!(rm.is_hot(PageId(1)));
        assert!(rm.is_hot(PageId(2)));
    }

    #[test]
    fn lru_touch_updates_order() {
        let mut rm = ResidencyManager::with_budget(2);
        rm.promote_to_gpu(PageId(0));
        rm.promote_to_gpu(PageId(1));
        rm.touch(PageId(0)); // make page 0 most-recent
        rm.promote_to_gpu(PageId(2)); // eviction should now drop page 1
        assert!(rm.is_hot(PageId(0)));
        assert!(!rm.is_hot(PageId(1)));
        assert!(rm.is_hot(PageId(2)));
    }

    #[test]
    fn evict_lru_empty() {
        let mut rm = ResidencyManager::with_budget(2);
        assert!(rm.evict_lru().is_none());
    }

    #[test]
    fn access_counting() {
        let mut rm = ResidencyManager::with_budget(4);
        for _ in 0..5 {
            rm.promote_to_gpu(PageId(0));
        }
        assert_eq!(*rm.access_count.get(&PageId(0)).unwrap(), 5);
    }

    #[test]
    fn remove_page() {
        let mut rm = ResidencyManager::with_budget(4);
        rm.promote_to_gpu(PageId(3));
        rm.demote_to_cpu(PageId(4));
        rm.remove(PageId(3));
        rm.remove(PageId(4));
        assert_eq!(rm.total_tracked(), 0);
    }

    #[test]
    fn residency_tracker_predict() {
        let mut tracker = ResidencyTracker::with_window(8);
        let page = PageId(7);
        for t in [10, 20, 30, 40, 50] {
            tracker.record(page, t);
        }
        let p = tracker.predict(page, 60);
        assert!(p > 0.5, "predicted access probability should be high, got {}", p);
        let p_far = tracker.predict(page, 200);
        assert!(
            p_far < p,
            "far-future prediction should be lower: near={}, far={}",
            p,
            p_far
        );
    }

    #[test]
    fn residency_tracker_ranked() {
        let mut tracker = ResidencyTracker::with_window(8);
        tracker.record(PageId(0), 10);
        tracker.record(PageId(0), 20);
        tracker.record(PageId(0), 30);
        tracker.record(PageId(1), 10);
        tracker.record(PageId(1), 100);
        let ranked = tracker.ranked_pages(&[PageId(0), PageId(1)], 35);
        assert_eq!(ranked[0].0, PageId(0)); // regular pattern -> higher prob
    }
}
