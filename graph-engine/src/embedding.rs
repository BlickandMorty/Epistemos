//! # Embedding Storage with SIMD-Accelerated Cosine Similarity
//!
//! Stores optional f32 embedding vectors per node (SoA layout).
//! Pre-computes L2 norms for fast cosine similarity.
//! Uses NEON SIMD intrinsics on aarch64 (Apple Silicon) for 4-wide f32 dot products.

use rustc_hash::FxHashMap;

/// Default embedding dimension (matches NLEmbedding word vectors).
pub const DEFAULT_DIM: usize = 512;

/// SoA embedding storage: maps node index → embedding + cached norm.
pub struct EmbeddingStore {
    /// Dimension of each embedding vector.
    dim: usize,
    /// Flat storage: embeddings[node_index] = Some((vector, l2_norm)).
    embeddings: FxHashMap<u32, EmbeddingEntry>,
}

struct EmbeddingEntry {
    vector: Vec<f32>,
    norm: f32,
}

/// A scored neighbor from KNN search.
#[derive(Clone, Copy)]
pub struct KnnHit {
    pub node_index: u32,
    pub similarity: f32,
}

impl EmbeddingStore {
    pub fn new(dim: usize) -> Self {
        Self {
            dim,
            embeddings: FxHashMap::default(),
        }
    }

    /// Set embedding for a node. Vector must have exactly `self.dim` elements.
    pub fn set(&mut self, node_index: u32, vector: &[f32]) {
        if vector.len() != self.dim {
            return;
        }
        let norm = l2_norm(vector);
        self.embeddings.insert(
            node_index,
            EmbeddingEntry {
                vector: vector.to_vec(),
                norm,
            },
        );
    }

    /// Remove embedding for a node.
    pub fn remove(&mut self, node_index: u32) {
        self.embeddings.remove(&node_index);
    }

    /// Clear all embeddings.
    pub fn clear(&mut self) {
        self.embeddings.clear();
    }

    /// Number of stored embeddings.
    pub fn len(&self) -> usize {
        self.embeddings.len()
    }

    /// Whether the store is empty.
    pub fn is_empty(&self) -> bool {
        self.embeddings.is_empty()
    }

    /// Cosine similarity between two nodes. Returns 0.0 if either has no embedding.
    pub fn cosine_similarity(&self, a: u32, b: u32) -> f32 {
        let (Some(ea), Some(eb)) = (self.embeddings.get(&a), self.embeddings.get(&b)) else {
            return 0.0;
        };
        if ea.norm == 0.0 || eb.norm == 0.0 {
            return 0.0;
        }
        dot_product(&ea.vector, &eb.vector) / (ea.norm * eb.norm)
    }

    /// Top-K nearest neighbors by cosine similarity.
    /// Returns at most `k` hits with similarity >= `threshold`.
    pub fn knn(&self, query_index: u32, k: usize, threshold: f32) -> Vec<KnnHit> {
        let Some(query) = self.embeddings.get(&query_index) else {
            return Vec::new();
        };
        if query.norm == 0.0 {
            return Vec::new();
        }

        let mut hits: Vec<KnnHit> = self
            .embeddings
            .iter()
            .filter(|(idx, _)| **idx != query_index)
            .map(|(idx, entry)| {
                let sim = if entry.norm == 0.0 {
                    0.0
                } else {
                    dot_product(&query.vector, &entry.vector) / (query.norm * entry.norm)
                };
                KnnHit {
                    node_index: *idx,
                    similarity: sim,
                }
            })
            .filter(|hit| hit.similarity >= threshold)
            .collect();

        // Partial sort: top-K by descending similarity
        hits.sort_unstable_by(|a, b| {
            b.similarity
                .partial_cmp(&a.similarity)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        hits.truncate(k);
        hits
    }

    /// Semantic search: find nodes most similar to a query vector.
    pub fn search(&self, query_vec: &[f32], k: usize, threshold: f32) -> Vec<KnnHit> {
        if query_vec.len() != self.dim {
            return Vec::new();
        }
        let query_norm = l2_norm(query_vec);
        if query_norm == 0.0 {
            return Vec::new();
        }

        let mut hits: Vec<KnnHit> = self
            .embeddings
            .iter()
            .map(|(idx, entry)| {
                let sim = if entry.norm == 0.0 {
                    0.0
                } else {
                    dot_product(query_vec, &entry.vector) / (query_norm * entry.norm)
                };
                KnnHit {
                    node_index: *idx,
                    similarity: sim,
                }
            })
            .filter(|hit| hit.similarity >= threshold)
            .collect();

        hits.sort_unstable_by(|a, b| {
            b.similarity
                .partial_cmp(&a.similarity)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        hits.truncate(k);
        hits
    }

    /// Get pre-computed KNN list for semantic force calculation.
    /// Returns top-K neighbors for each node that has an embedding.
    pub fn all_knn_pairs(&self, k: usize, threshold: f32) -> Vec<(u32, u32, f32)> {
        let mut pairs = Vec::new();
        for node_idx in self.embeddings.keys().copied() {
            for hit in self.knn(node_idx, k, threshold) {
                // Only add each pair once (lower index first)
                if node_idx < hit.node_index {
                    pairs.push((node_idx, hit.node_index, hit.similarity));
                }
            }
        }
        pairs
    }
}

// ── SIMD-Accelerated Math ───────────────────────────────────────────────────

/// L2 norm of a vector.
fn l2_norm(v: &[f32]) -> f32 {
    dot_product(v, v).sqrt()
}

/// Dot product using NEON SIMD on aarch64, scalar fallback otherwise.
#[inline]
pub fn dot_product(a: &[f32], b: &[f32]) -> f32 {
    debug_assert_eq!(a.len(), b.len());
    #[cfg(target_arch = "aarch64")]
    {
        dot_product_neon(a, b)
    }
    #[cfg(not(target_arch = "aarch64"))]
    {
        dot_product_scalar(a, b)
    }
}

/// Scalar fallback dot product.
#[inline]
#[allow(dead_code)]
fn dot_product_scalar(a: &[f32], b: &[f32]) -> f32 {
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

/// NEON-accelerated dot product for Apple Silicon (4-wide f32).
#[cfg(target_arch = "aarch64")]
#[inline]
fn dot_product_neon(a: &[f32], b: &[f32]) -> f32 {
    use std::arch::aarch64::*;

    let len = a.len().min(b.len());
    let chunks = len / 4;
    let remainder = len % 4;

    unsafe {
        let mut acc = vdupq_n_f32(0.0);

        for i in 0..chunks {
            let offset = i * 4;
            let va = vld1q_f32(a.as_ptr().add(offset));
            let vb = vld1q_f32(b.as_ptr().add(offset));
            acc = vfmaq_f32(acc, va, vb);
        }

        // Horizontal sum of 4 lanes
        let mut sum = vaddvq_f32(acc);

        // Handle remainder
        let base = chunks * 4;
        for i in 0..remainder {
            sum += a[base + i] * b[base + i];
        }

        sum
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dot_product_basic() {
        let a = [1.0, 2.0, 3.0, 4.0];
        let b = [5.0, 6.0, 7.0, 8.0];
        let result = dot_product(&a, &b);
        assert!((result - 70.0).abs() < 1e-5);
    }

    #[test]
    fn dot_product_unaligned_length() {
        let a = [1.0, 2.0, 3.0, 4.0, 5.0];
        let b = [2.0, 3.0, 4.0, 5.0, 6.0];
        let expected: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
        let result = dot_product(&a, &b);
        assert!((result - expected).abs() < 1e-5);
    }

    #[test]
    fn cosine_identical_vectors() {
        let mut store = EmbeddingStore::new(4);
        store.set(0, &[1.0, 0.0, 0.0, 0.0]);
        store.set(1, &[1.0, 0.0, 0.0, 0.0]);
        let sim = store.cosine_similarity(0, 1);
        assert!((sim - 1.0).abs() < 1e-5);
    }

    #[test]
    fn cosine_orthogonal_vectors() {
        let mut store = EmbeddingStore::new(4);
        store.set(0, &[1.0, 0.0, 0.0, 0.0]);
        store.set(1, &[0.0, 1.0, 0.0, 0.0]);
        let sim = store.cosine_similarity(0, 1);
        assert!(sim.abs() < 1e-5);
    }

    #[test]
    fn cosine_opposite_vectors() {
        let mut store = EmbeddingStore::new(4);
        store.set(0, &[1.0, 0.0, 0.0, 0.0]);
        store.set(1, &[-1.0, 0.0, 0.0, 0.0]);
        let sim = store.cosine_similarity(0, 1);
        assert!((sim - (-1.0)).abs() < 1e-5);
    }

    #[test]
    fn knn_returns_top_k() {
        let mut store = EmbeddingStore::new(3);
        // Query node
        store.set(0, &[1.0, 0.0, 0.0]);
        // Very similar
        store.set(1, &[0.9, 0.1, 0.0]);
        // Somewhat similar
        store.set(2, &[0.5, 0.5, 0.0]);
        // Dissimilar
        store.set(3, &[0.0, 0.0, 1.0]);

        let hits = store.knn(0, 2, 0.0);
        assert_eq!(hits.len(), 2);
        // Most similar first
        assert_eq!(hits[0].node_index, 1);
        assert!(hits[0].similarity > hits[1].similarity);
    }

    #[test]
    fn knn_respects_threshold() {
        let mut store = EmbeddingStore::new(3);
        store.set(0, &[1.0, 0.0, 0.0]);
        store.set(1, &[0.9, 0.1, 0.0]);
        store.set(2, &[0.0, 0.0, 1.0]); // orthogonal, sim ≈ 0

        let hits = store.knn(0, 10, 0.5);
        assert_eq!(hits.len(), 1); // Only node 1 passes threshold
    }

    #[test]
    fn missing_embedding_returns_zero_similarity() {
        let mut store = EmbeddingStore::new(3);
        store.set(0, &[1.0, 0.0, 0.0]);
        let sim = store.cosine_similarity(0, 99);
        assert_eq!(sim, 0.0);
    }

    #[test]
    fn wrong_dimension_rejected() {
        let mut store = EmbeddingStore::new(3);
        store.set(0, &[1.0, 2.0]); // Wrong dim
        assert!(store.is_empty());
    }

    #[test]
    fn semantic_search_finds_similar() {
        let mut store = EmbeddingStore::new(3);
        store.set(0, &[1.0, 0.0, 0.0]);
        store.set(1, &[0.0, 1.0, 0.0]);
        store.set(2, &[0.9, 0.1, 0.0]);

        let hits = store.search(&[1.0, 0.0, 0.0], 2, 0.0);
        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].node_index, 0); // Exact match
        assert_eq!(hits[1].node_index, 2); // Close match
    }

    #[cfg(target_arch = "aarch64")]
    #[test]
    fn simd_vs_scalar_parity() {
        let a: Vec<f32> = (0..512).map(|i| (i as f32) * 0.01).collect();
        let b: Vec<f32> = (0..512).map(|i| ((512 - i) as f32) * 0.01).collect();

        let simd_result = dot_product_neon(&a, &b);
        let scalar_result = dot_product_scalar(&a, &b);
        assert!(
            (simd_result - scalar_result).abs() < 0.1,
            "SIMD {} vs scalar {}",
            simd_result,
            scalar_result
        );
    }
}
