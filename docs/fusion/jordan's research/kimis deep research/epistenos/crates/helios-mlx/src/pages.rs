//! 6-tier memory allocator.
//!
//! The tiered allocator partitions the KV cache into six levels of cost,
//! precision, and latency:
//!
//! | Tier | Name | Precision | Latency | Backing |
//! |------|------|-----------|---------|---------|
//! | L0 | Exact Hot | Full `f32/f16` | GPU-local | `hot_set` |
//! | L1 | Compressed Residual | Sherry / NF4 / Adaptive | GPU decompress | `CompressedCache` |
//! | L2 | Shadow Sketch | CountSketch | CPU→GPU copy | `CountSketch` per page |
//! | L3 | SSD Oracle | Quantised blobs | SSD mmap | `MmapOracle` |
//! | L4 | Hermes Cascade | Cloud fallback | Network | `HermesBuffer` |
//! | LSE | Self-Evolving | Online-learned | Variable | `LSEModule` |
//!
//! A [`Page`] is the unit of allocation (default 4 KB of token state).
//! [`TieredAllocator`] manages promotion / demotion between tiers and
//! answers [`PageAllocationRequest`]s.

use thiserror::Error;
use tracing::{debug, error, info, trace, warn};

use crate::cache::{AdaptiveCache, CompressedCache, NF4Cache, SherryCache};
use crate::residency::{ResidencyManager, ResidencyTracker};
use crate::shadow::ShadowAttention;
use crate::types::{LayerId, PageId, TensorView, TokenId};
use helios_core::CountSketch;

// ---------------------------------------------------------------------------
// MemoryTier
// ---------------------------------------------------------------------------

/// Six-level memory hierarchy.
///
/// Re-exported from `helios_core` once that crate defines the enum.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum MemoryTier {
    /// L0 — hot, exact precision, GPU-resident.
    L0ExactHot,
    /// L1 — Sherry-compressed or NF4 residual.
    L1CompressedResidual,
    /// L2 — shadow sketch (approximate, fast select).
    L2ShadowSketch,
    /// L3 — memory-mapped cold storage on SSD.
    L3SSDOracle,
    /// L4 — cloud escalation buffer (Hermes).
    L4HermesCascade,
    /// LSE — self-evolving module (online learning).
    LSESelfEvolving,
}

impl MemoryTier {
    /// Human-readable label.
    pub fn label(&self) -> &'static str {
        match self {
            MemoryTier::L0ExactHot => "L0-ExactHot",
            MemoryTier::L1CompressedResidual => "L1-Compressed",
            MemoryTier::L2ShadowSketch => "L2-Shadow",
            MemoryTier::L3SSDOracle => "L3-SSD",
            MemoryTier::L4HermesCascade => "L4-Hermes",
            MemoryTier::LSESelfEvolving => "LSE-SelfEvolving",
        }
    }

    /// Relative latency factor (higher = slower).
    pub fn latency_factor(&self) -> f32 {
        match self {
            MemoryTier::L0ExactHot => 1.0,
            MemoryTier::L1CompressedResidual => 2.5,
            MemoryTier::L2ShadowSketch => 5.0,
            MemoryTier::L3SSDOracle => 50.0,
            MemoryTier::L4HermesCascade => 1000.0,
            MemoryTier::LSESelfEvolving => 10.0,
        }
    }
}

// ---------------------------------------------------------------------------
// PageAllocationRequest
// ---------------------------------------------------------------------------

/// Request to allocate a contiguous range of pages.
#[derive(Debug, Clone)]
pub struct PageAllocationRequest {
    /// Number of tokens to store.
    pub token_count: usize,
    /// Number of transformer layers.
    pub layer_count: usize,
    /// Preferred starting tier.
    pub tier_preference: MemoryTier,
    /// Head dimension (needed for byte-size computation).
    pub head_dim: usize,
    /// Number of attention heads.
    pub num_heads: usize,
    /// Bytes per element.
    pub dtype_bytes: usize,
}

impl PageAllocationRequest {
    /// Compute the total bytes required if all state were exact (L0).
    pub fn exact_bytes_needed(&self) -> usize {
        self.token_count
            * self.layer_count
            * self.num_heads
            * self.head_dim
            * 2 // K + V
            * self.dtype_bytes
    }

    /// Suggested number of pages (each page holds ~4 KB of state).
    pub fn suggested_pages(&self, page_capacity_bytes: usize) -> usize {
        self.exact_bytes_needed().div_ceil(page_capacity_bytes)
    }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

/// Fixed-size memory page holding token state.
///
/// A page is the unit of migration between tiers.  Its backing may be:
/// * a GPU buffer descriptor (`data_offset` into a Metal heap),
/// * a compressed blob (L1),
/// * a sketch only (L2),
/// * an mmap offset (L3),
/// * a remote handle (L4), or
/// * an LSE embedding (LSE).
#[derive(Debug, Clone)]
pub struct Page {
    pub id: PageId,
    /// Current tier.
    pub tier: MemoryTier,
    /// Byte offset into the backing allocation (valid for L0/L3).
    pub data_offset: usize,
    /// Size of this page in bytes.
    pub size_bytes: usize,
    /// Token IDs stored in this page (sparse).
    pub tokens: Vec<TokenId>,
    /// Compressed payload (L1).
    pub compressed_payload: Option<Vec<u8>>,
    /// Sketch index (L2).
    pub sketch_index: Option<usize>,
    /// For L3: file path handle.
    pub mmap_handle: Option<String>,
    /// Access tick (for LRU).
    pub last_access_tick: u64,
    /// Number of times this page has been accessed.
    pub access_count: u64,
}

impl Page {
    pub fn new(id: PageId, size_bytes: usize) -> Self {
        Self {
            id,
            tier: MemoryTier::L0ExactHot,
            data_offset: 0,
            size_bytes,
            tokens: Vec::new(),
            compressed_payload: None,
            sketch_index: None,
            mmap_handle: None,
            last_access_tick: 0,
            access_count: 0,
        }
    }

    /// Mark an access.
    pub fn touch(&mut self, tick: u64) {
        self.last_access_tick = tick;
        self.access_count += 1;
    }
}

/// A contiguous range of page identifiers.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PageRange {
    pub start: PageId,
    pub end: PageId, // exclusive
}

impl PageRange {
    pub fn len(&self) -> usize {
        self.end.0.saturating_sub(self.start.0)
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    pub fn contains(&self, page: PageId) -> bool {
        page.0 >= self.start.0 && page.0 < self.end.0
    }
}

// ---------------------------------------------------------------------------
// TieredAllocator
// ---------------------------------------------------------------------------

/// Errors from the tiered allocator.
#[derive(Error, Debug, Clone, PartialEq)]
pub enum AllocatorError {
    #[error("out of memory: requested {requested} pages, available {available}")]
    OutOfMemory { requested: usize, available: usize },
    #[error("invalid tier transition: {from:?} -> {to:?}")]
    InvalidTransition { from: MemoryTier, to: MemoryTier },
    #[error("page {0:?} not found")]
    PageNotFound(PageId),
    #[error("mmap error: {0}")]
    MmapError(String),
}

pub type AllocatorResult<T> = Result<T, AllocatorError>;

/// 6-tier memory allocator.
#[derive(Debug)]
pub struct TieredAllocator {
    /// Hot exact-precision pages.
    pub l0_pages: Vec<Page>,
    /// L1 compressed cache.
    pub l1_cache: Box<dyn CompressedCache>,
    /// L2 shadow sketches (one per page).
    pub l2_sketches: Vec<CountSketch<1024, 4>>,
    /// L3 memory-mapped cold storage.
    pub l3_mmap: MmapOracle,
    /// L4 Hermes cloud buffer.
    pub l4_hermes: HermesBuffer,
    /// LSE self-evolving module.
    pub l_se_module: LSEModule,
    /// GPU residency manager.
    pub residency: ResidencyManager,
    /// Predictive tracker.
    pub tracker: ResidencyTracker,
    /// Default page capacity in bytes.
    pub page_size: usize,
    /// Monotonic access tick.
    pub tick: u64,
    /// Free-list of page IDs.
    free_list: Vec<PageId>,
    /// Next page ID to allocate.
    next_page_id: usize,
}

impl Default for TieredAllocator {
    fn default() -> Self {
        Self::new(4096)
    }
}

impl TieredAllocator {
    /// Create a new allocator with the given page size.
    pub fn new(page_size: usize) -> Self {
        Self {
            l0_pages: Vec::new(),
            l1_cache: Box::new(SherryCache::default()),
            l2_sketches: Vec::new(),
            l3_mmap: MmapOracle::new("/tmp/helios_mmap"),
            l4_hermes: HermesBuffer::new(),
            l_se_module: LSEModule::new(),
            residency: ResidencyManager::with_budget(256),
            tracker: ResidencyTracker::with_window(32),
            page_size,
            tick: 0,
            free_list: Vec::new(),
            next_page_id: 0,
        }
    }

    /// Allocate a contiguous page range for `req`.
    ///
    /// # Algorithm
    /// 1. Compute required pages from `req.suggested_pages(self.page_size)`.
    /// 2. Try to satisfy from the free list.
    /// 3. If insufficient, grow `l0_pages` and `l2_sketches`.
    /// 4. Return the [`PageRange`].
    pub fn allocate_pages(&mut self, req: &PageAllocationRequest) -> AllocatorResult<PageRange> {
        let needed = req.suggested_pages(self.page_size);
        if needed == 0 {
            return Ok(PageRange {
                start: PageId(0),
                end: PageId(0),
            });
        }

        // Try free list first.
        let mut allocated = Vec::with_capacity(needed);
        while allocated.len() < needed && !self.free_list.is_empty() {
            allocated.push(self.free_list.pop().unwrap());
        }

        // Grow if still needed.
        let grow = needed.saturating_sub(allocated.len());
        let start_id = self.next_page_id;
        for _ in 0..grow {
            let pid = PageId(self.next_page_id);
            let mut page = Page::new(pid, self.page_size);
            page.tier = req.tier_preference;
            self.l0_pages.push(page);
            self.l2_sketches.push(CountSketch::<1024, 4>::default());
            allocated.push(pid);
            self.next_page_id += 1;
        }

        // If we used the free list the IDs may not be contiguous.
        // For simplicity we require contiguous ranges; sort and check.
        allocated.sort_by_key(|p| p.0);
        let start = *allocated.first().unwrap();
        let end = PageId(allocated.last().unwrap().0 + 1);

        info!(
            "allocate_pages: {} pages [{:?} .. {:?}) for {} tokens, {} layers, tier={:?}",
            needed, start, end, req.token_count, req.layer_count, req.tier_preference
        );

        Ok(PageRange { start, end })
    }

    /// Promote a page from `from` tier to `to` tier.
    ///
    /// # Supported transitions
    /// * L3 → L2 → L1 → L0 (warming)
    /// * L0 → L1 → L2 → L3 (cooling)
    /// * Any tier → L4 (cloud off-load)
    /// * Any tier → LSE (self-evolving)
    pub fn promote_page(&mut self, page: &mut Page, from: MemoryTier, to: MemoryTier) {
        trace!(
            "promote_page: {:?} {:?} -> {:?}",
            page.id, from, to
        );
        match (from, to) {
            // Warming
            (MemoryTier::L3SSDOracle, MemoryTier::L2ShadowSketch) => {
                page.tier = to;
                // Decompress from mmap, keep sketch.
            }
            (MemoryTier::L3SSDOracle | MemoryTier::L2ShadowSketch, MemoryTier::L1CompressedResidual) => {
                page.tier = to;
                // Load blob, decompress into compressed payload.
            }
            (MemoryTier::L1CompressedResidual | MemoryTier::L2ShadowSketch | MemoryTier::L3SSDOracle, MemoryTier::L0ExactHot) => {
                page.tier = to;
                self.residency.promote_to_gpu(page.id);
            }
            // Cooling
            (MemoryTier::L0ExactHot, MemoryTier::L1CompressedResidual) => {
                page.tier = to;
                self.residency.demote_to_cpu(page.id);
                // TODO: run compression, store blob in page.compressed_payload.
            }
            (MemoryTier::L0ExactHot | MemoryTier::L1CompressedResidual, MemoryTier::L2ShadowSketch) => {
                page.tier = to;
                self.residency.demote_to_cpu(page.id);
                page.compressed_payload = None; // drop exact data, keep sketch.
            }
            (MemoryTier::L0ExactHot | MemoryTier::L1CompressedResidual | MemoryTier::L2ShadowSketch, MemoryTier::L3SSDOracle) => {
                page.tier = to;
                self.residency.demote_to_cpu(page.id);
                // TODO: flush to mmap file.
                page.compressed_payload = None;
            }
            // Cloud & LSE
            (_, MemoryTier::L4HermesCascade) => {
                page.tier = to;
                self.residency.remove(page.id);
            }
            (_, MemoryTier::LSESelfEvolving) => {
                page.tier = to;
                self.l_se_module.ingest_page(page);
            }
            // Same tier — no-op.
            (a, b) if a == b => {}
            _ => {
                warn!(
                    "Unsupported tier transition: {:?} -> {:?} for page {:?}",
                    from, to, page.id
                );
            }
        }
    }

    /// Demote a page (convenience wrapper that calls promote_page with reversed tiers).
    pub fn demote_page(&mut self, page: &mut Page, from: MemoryTier, to: MemoryTier) {
        self.promote_page(page, from, to);
    }

    /// Total resident bytes (L0 + L1 + L2, excluding L3 mmap and L4 cloud).
    pub fn total_resident_bytes(&self) -> usize {
        let l0: usize = self
            .l0_pages
            .iter()
            .filter(|p| p.tier == MemoryTier::L0ExactHot)
            .map(|p| p.size_bytes)
            .sum();
        let l1: usize = self
            .l0_pages
            .iter()
            .filter(|p| p.tier == MemoryTier::L1CompressedResidual)
            .map(|p| p.compressed_payload.as_ref().map(|v| v.len()).unwrap_or(0))
            .sum();
        let l2: usize = self
            .l2_sketches
            .len()
            * (1024 * 4 * 4); // W=1024, D=4, i32=4 bytes
        l0 + l1 + l2
    }

    /// Touch a page (update LRU, access counts, tracker).
    pub fn touch_page(&mut self, page: &mut Page) {
        self.tick += 1;
        page.touch(self.tick);
        self.residency.touch(page.id);
        self.tracker.record(page.id, self.tick);
    }

    /// Find a page by ID.
    pub fn find_page(&self, id: PageId) -> Option<&Page> {
        self.l0_pages.get(id.0)
    }

    /// Find a page by ID (mutable).
    pub fn find_page_mut(&mut self, id: PageId) -> Option<&mut Page> {
        self.l0_pages.get_mut(id.0)
    }

    /// Free a page range, returning IDs to the free list.
    pub fn free_pages(&mut self, range: PageRange) {
        for i in range.start.0..range.end.0 {
            if let Some(page) = self.l0_pages.get_mut(i) {
                page.tokens.clear();
                page.compressed_payload = None;
                page.tier = MemoryTier::L0ExactHot;
                self.residency.remove(PageId(i));
                self.free_list.push(PageId(i));
            }
        }
        trace!("free_pages: [{:?} .. {:?})", range.start, range.end);
    }
}

// ---------------------------------------------------------------------------
// MmapOracle (L3)
// ---------------------------------------------------------------------------

/// Memory-mapped cold-storage backend.
///
/// Wraps `memmap2` to map large quantised blobs into virtual memory.  Only
/// actively-touched pages are paged in by the OS.
#[derive(Debug, Clone)]
pub struct MmapOracle {
    pub path_prefix: String,
    pub next_file_id: usize,
}

impl MmapOracle {
    pub fn new(path_prefix: &str) -> Self {
        Self {
            path_prefix: path_prefix.to_string(),
            next_file_id: 0,
        }
    }

    /// Allocate a new backing file of `size_bytes` and return its path.
    pub fn create_backing(&mut self, size_bytes: usize) -> AllocatorResult<String> {
        let path = format!("{}_{}.bin", self.path_prefix, self.next_file_id);
        self.next_file_id += 1;
        // TODO: create sparse file via `std::fs::File::create` + `set_len`.
        trace!("MmapOracle created backing: {} ({} bytes)", path, size_bytes);
        Ok(path)
    }

    /// Remove a backing file.
    pub fn remove_backing(&self, path: &str) {
        // TODO: `std::fs::remove_file`.
        trace!("MmapOracle remove backing: {}", path);
    }
}

// ---------------------------------------------------------------------------
// HermesBuffer (L4)
// ---------------------------------------------------------------------------

/// Cloud escalation buffer.
///
/// When local memory is exhausted, pages can be off-loaded to a remote
/// Hermes cache.  This is a stub; the real implementation would use `reqwest`
/// to PUT/GET blob objects.
#[derive(Debug, Clone)]
pub struct HermesBuffer {
    pub endpoint: Option<String>,
}

impl HermesBuffer {
    pub fn new() -> Self {
        Self { endpoint: None }
    }

    pub fn with_endpoint(endpoint: &str) -> Self {
        Self {
            endpoint: Some(endpoint.to_string()),
        }
    }

    /// Upload a page blob to the Hermes cache.
    pub async fn upload(&self, _page_id: PageId, _blob: &[u8]) {
        // TODO: `reqwest::Client::put`.
        trace!("HermesBuffer::upload stub");
    }

    /// Download a page blob from the Hermes cache.
    pub async fn download(&self, _page_id: PageId) -> Vec<u8> {
        // TODO: `reqwest::Client::get`.
        trace!("HermesBuffer::download stub");
        Vec::new()
    }
}

// ---------------------------------------------------------------------------
// LSEModule (LSE)
// ---------------------------------------------------------------------------

/// Self-evolving memory module.
///
/// Learns per-page access patterns and automatically adjusts tier placement.
/// For now this is an interface stub.
#[derive(Debug, Clone, Default)]
pub struct LSEModule {
    pub ingested_count: usize,
}

impl LSEModule {
    pub fn new() -> Self {
        Self::default()
    }

    /// Ingest a page into the self-evolving module.
    pub fn ingest_page(&mut self, page: &Page) {
        self.ingested_count += 1;
        trace!("LSEModule ingested page {:?}", page.id);
    }

    /// Predict the optimal tier for a page based on learned patterns.
    pub fn predict_tier(&self, _page: &Page) -> MemoryTier {
        // TODO: train a tiny online model (e.g. EWA of access frequency).
        MemoryTier::L0ExactHot
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn make_request() -> PageAllocationRequest {
        PageAllocationRequest {
            token_count: 256,
            layer_count: 32,
            tier_preference: MemoryTier::L0ExactHot,
            head_dim: 128,
            num_heads: 32,
            dtype_bytes: 2,
        }
    }

    #[test]
    fn allocate_and_free_pages() {
        let mut alloc = TieredAllocator::new(4096);
        let req = make_request();
        let range = alloc.allocate_pages(&req).unwrap();
        assert!(!range.is_empty());
        alloc.free_pages(range);
        // After free the IDs should be reusable.
        let range2 = alloc.allocate_pages(&req).unwrap();
        assert_eq!(range2.start, range.start); // free list reused
    }

    #[test]
    fn tier_transitions_l0_to_l1_to_l0() {
        let mut alloc = TieredAllocator::new(4096);
        let req = make_request();
        let range = alloc.allocate_pages(&req).unwrap();
        let pid = range.start;
        let page = alloc.find_page_mut(pid).unwrap();
        assert_eq!(page.tier, MemoryTier::L0ExactHot);

        alloc.demote_page(page, MemoryTier::L0ExactHot, MemoryTier::L1CompressedResidual);
        let page = alloc.find_page(pid).unwrap();
        assert_eq!(page.tier, MemoryTier::L1CompressedResidual);

        let page = alloc.find_page_mut(pid).unwrap();
        alloc.promote_page(page, MemoryTier::L1CompressedResidual, MemoryTier::L0ExactHot);
        let page = alloc.find_page(pid).unwrap();
        assert_eq!(page.tier, MemoryTier::L0ExactHot);
    }

    #[test]
    fn tier_transition_cools_to_l3() {
        let mut alloc = TieredAllocator::new(4096);
        let req = make_request();
        let range = alloc.allocate_pages(&req).unwrap();
        let pid = range.start;
        let page = alloc.find_page_mut(pid).unwrap();
        alloc.demote_page(page, MemoryTier::L0ExactHot, MemoryTier::L3SSDOracle);
        let page = alloc.find_page(pid).unwrap();
        assert_eq!(page.tier, MemoryTier::L3SSDOracle);
    }

    #[test]
    fn total_resident_bytes_accounting() {
        let mut alloc = TieredAllocator::new(4096);
        let req = make_request();
        let range = alloc.allocate_pages(&req).unwrap();
        // All allocated pages start in L0.
        let resident = alloc.total_resident_bytes();
        let expected = range.len() * 4096;
        assert_eq!(resident, expected);

        // Demote one page to L1 and inject compressed payload.
        let pid = range.start;
        let page = alloc.find_page_mut(pid).unwrap();
        page.compressed_payload = Some(vec![0u8; 512]);
        alloc.demote_page(page, MemoryTier::L0ExactHot, MemoryTier::L1CompressedResidual);

        let resident_after = alloc.total_resident_bytes();
        // L0 now has (range.len()-1)*4096, L1 has 512, L2 has range.len()*16384.
        let expected_l0 = (range.len() - 1) * 4096;
        let expected_l1 = 512;
        let expected_l2 = range.len() * (1024 * 4 * 4);
        assert_eq!(resident_after, expected_l0 + expected_l1 + expected_l2);
    }

    #[test]
    fn residency_promotion_and_eviction() {
        let mut alloc = TieredAllocator::new(4096);
        alloc.residency = ResidencyManager::with_budget(2);
        let req = make_request();
        let range = alloc.allocate_pages(&req).unwrap();
        for i in range.start.0..range.end.0.min(range.start.0 + 3) {
            let page = alloc.find_page_mut(PageId(i)).unwrap();
            alloc.promote_page(page, page.tier, MemoryTier::L0ExactHot);
        }
        // With budget 2, only 2 pages should be hot.
        assert_eq!(alloc.residency.hot_set.len(), 2);
    }

    #[test]
    fn touch_increments_tick() {
        let mut alloc = TieredAllocator::new(4096);
        let req = make_request();
        let range = alloc.allocate_pages(&req).unwrap();
        let pid = range.start;
        let tick_before = alloc.tick;
        let page = alloc.find_page_mut(pid).unwrap();
        alloc.touch_page(page);
        assert_eq!(alloc.tick, tick_before + 1);
        assert_eq!(page.access_count, 1);
    }

    #[test]
    fn page_range_contains() {
        let r = PageRange {
            start: PageId(5),
            end: PageId(10),
        };
        assert!(r.contains(PageId(5)));
        assert!(r.contains(PageId(9)));
        assert!(!r.contains(PageId(10)));
        assert!(!r.contains(PageId(4)));
    }

    #[test]
    fn request_exact_bytes() {
        let req = PageAllocationRequest {
            token_count: 1,
            layer_count: 32,
            tier_preference: MemoryTier::L0ExactHot,
            head_dim: 128,
            num_heads: 32,
            dtype_bytes: 2,
        };
        let exact = req.exact_bytes_needed();
        // 1 token * 32 layers * 32 heads * 128 dim * 2 (K+V) * 2 bytes = 524_288
        assert_eq!(exact, 524_288);
    }

    #[test]
    fn lse_module_ingest() {
        let mut lse = LSEModule::new();
        let page = Page::new(PageId(0), 4096);
        lse.ingest_page(&page);
        assert_eq!(lse.ingested_count, 1);
    }

    #[test]
    fn hermes_buffer_stub() {
        let hermes = HermesBuffer::with_endpoint("http://localhost:8080");
        assert_eq!(hermes.endpoint.as_deref(), Some("http://localhost:8080"));
    }
}
