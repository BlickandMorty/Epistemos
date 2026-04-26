//! W8.4.c stub — usearch HNSW wrapper.
//!
//! Filled in by the W8.4.c commit. The shape:
//!
//!   pub struct VectorIndex {
//!       index: usearch::Index,
//!       doc_to_key: rustc_hash::FxHashMap<String, u64>,
//!       key_to_doc: rustc_hash::FxHashMap<u64, String>,
//!       free_keys: Vec<u64>,
//!       next_key: u64,
//!   }
//!
//!   impl VectorIndex {
//!       pub fn new(dim: usize) -> Result<Self, ShadowError>;
//!       pub fn add(&mut self, doc_id: &str, embedding: &[f32]) -> Result<(), ShadowError>;
//!       pub fn remove(&mut self, doc_id: &str) -> Result<(), ShadowError>;
//!       pub fn search(&self, query: &[f32], limit: usize) -> Vec<(String, f32)>;
//!   }
//!
//! IndexOptions mirror graph-engine/src/retrieval_index.rs:401-411 —
//! the production HNSW config that already works on this hardware:
//!   metric:           Cos
//!   quantization:     F16
//!   connectivity:     16  (M parameter)
//!   expansion_add:    128 (ef_construction)
//!   expansion_search: 64  (ef_search)
//!
//! Distance → similarity: `1.0 - distance` clamped to [-1, 1] (mirrors
//! retrieval_index.rs:517-519). Domain filtering is the caller's
//! responsibility; W8.4.e holds one VectorIndex per domain.

#![allow(dead_code)]
