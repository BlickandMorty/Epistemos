//! `helios-mlx` — MLX memory substrate for the Epistenos inference engine.
//!
//! This crate implements the **6-tier memory hierarchy** and the **KV-Direct**
//! residual-first exactness mechanism that together form the memory thesis of
//! Epistenos.
//!
//! # 6-tier memory hierarchy
//!
//! | Tier | Name | Precision | Latency | Purpose |
//! |------|------|-----------|---------|---------|
//! | **L0** | Exact Hot | Full `f32` / `f16` | GPU-local | Fast-path attention |
//! | **L1** | Compressed Residual | Sherry / NF4 / Adaptive | GPU decompress | 4-8× memory savings |
//! | **L2** | Shadow Sketch | CountSketch | CPU→GPU copy | Sub-linear page selection |
//! | **L3** | SSD Oracle | Quantised blobs | SSD mmap | Cold storage |
//! | **L4** | Hermes Cascade | Cloud blob | Network | Off-load |
//! | **LSE** | Self-Evolving | Online-learned | Variable | Predictive placement |
//!
//! # KV-Direct (the gate experiment)
//!
//! Instead of storing the full key/value cache (~136 KB/token for a 7 B model),
//! KV-Direct stores **sparse residual checkpoints** every `N` tokens and
//! reconstructs exact K/V on demand by replaying K-projection and V-projection
//! from the nearest checkpoint.  Memory drops to ~5 KB/token (~27× reduction)
//! while reconstruction MSE stays below `1e-4`.
//!
//! # Architecture
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────┐
//! │                    HeliosAttention                          │
//! │  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐  │
//! │  │ ShadowFirst │→ │ KVDirect     │→ │ TieredAllocator    │  │
//! │  │ select_pages│  │ reconstruct_kv│  │ promote/demote   │  │
//! │  └─────────────┘  └──────────────┘  └────────────────────┘  │
//! └─────────────────────────────────────────────────────────────┘
//! ```
//!
//! # Usage
//!
//! ```rust,ignore
//! use helios_mlx::{HeliosAttention, KVDirectBuilder, TieredAllocator, ShadowAttention};
//!
//! let kv = KVDirectBuilder::new()
//!     .hidden_dim(4096)
//!     .head_dim(128)
//!     .num_heads(32)
//!     .checkpoint_interval(64)
//!     .build()?;
//!
//! let shadow = ShadowAttention::with_capacity(256, 8);
//! let alloc = TieredAllocator::new(4096);
//! let mut attn = HeliosAttention::new(kv, shadow, alloc, 0.5, 128, 32);
//!
//! // Prefill a sequence.
//! let tokens: Vec<TokenId> = (0..128).map(TokenId).collect();
//! let _ = attn.prefill(&tokens)?;
//!
//! // Decode a new token.
//! let query = TensorView::row_major(vec![32, 128], MLXDtype::F32, 16384);
//! let out = attn.forward(&query, LayerId(0), TokenId(128))?;
//! ```

#![warn(missing_docs)]
#![warn(rustdoc::missing_doc_code_examples)]

pub mod attention;
pub mod cache;
pub mod kv_direct;
pub mod pages;
pub mod residency;
pub mod shadow;
pub mod types;

// ---------------------------------------------------------------------------
// Re-exports for ergonomic top-level access
// ---------------------------------------------------------------------------

pub use attention::{AttentionError, AttentionResult, HeliosAttention};
pub use cache::{kl_divergence, AdaptiveCache, CacheError, CacheResult, CompressedCache, NF4Cache, SherryCache};
pub use kv_direct::{Checkpoint, KVDirect, KVDirectBuilder, KVDirectError, KVDirectResult, KVProjection, ProjectionMatrix};
pub use pages::{AllocatorError, AllocatorResult, HermesBuffer, LSEModule, MemoryTier, MmapOracle, Page, PageAllocationRequest, PageRange, TieredAllocator};
pub use residency::{MTLResidencySetBridge, ResidencyManager, ResidencyTracker};
pub use shadow::{shadow_score, PageIndex, ShadowAttention};
pub use types::{AttentionHead, LayerId, MLXDtype, PageId, TensorView, TokenId};
pub use helios_core::CountSketch;
