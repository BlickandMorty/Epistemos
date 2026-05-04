//! MLX-specific types and tensor descriptors.
//!
//! This module defines the lightweight tensor abstractions used throughout the
//! `helios-mlx` crate.  All heavy tensor operations are delegated to the
//! underlying MLX runtime (via `mlx-rs` or raw Metal kernels); Helios only
//! keeps enough metadata to route memory, reconstruct KV state, and drive
//! the 6-tier allocator.

use std::fmt;

// ---------------------------------------------------------------------------
// Type aliases – these will be re-exported from `helios_core` once that
// crate matures.  For now we define local new-types so that `helios-mlx`
// compiles stand-alone.
// ---------------------------------------------------------------------------

/// Opaque layer identifier (0 … num_layers).
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
pub struct LayerId(pub usize);

/// Opaque token identifier (position in the sequence).
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
pub struct TokenId(pub usize);

/// Memory page identifier.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
pub struct PageId(pub usize);

// ---------------------------------------------------------------------------
// MLXDtype
// ---------------------------------------------------------------------------

/// Supported MLX element types.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub enum MLXDtype {
    /// 32-bit IEEE-754 float.
    #[default]
    F32,
    /// 16-bit IEEE-754 float.
    F16,
    /// Brain float 16 (bfloat16).
    BFloat16,
    /// 32-bit signed integer.
    Int32,
    /// 64-bit signed integer.
    Int64,
}

impl MLXDtype {
    /// Size of one scalar in bytes.
    pub fn size_bytes(&self) -> usize {
        match self {
            MLXDtype::F32 => 4,
            MLXDtype::F16 | MLXDtype::BFloat16 => 2,
            MLXDtype::Int32 => 4,
            MLXDtype::Int64 => 8,
        }
    }

    /// Human-readable name.
    pub fn as_str(&self) -> &'static str {
        match self {
            MLXDtype::F32 => "f32",
            MLXDtype::F16 => "f16",
            MLXDtype::BFloat16 => "bf16",
            MLXDtype::Int32 => "i32",
            MLXDtype::Int64 => "i64",
        }
    }
}

// ---------------------------------------------------------------------------
// TensorView
// ---------------------------------------------------------------------------

/// Lightweight tensor descriptor.
///
/// A `TensorView` does **not** own data; it merely describes a contiguous or
/// strided region of memory that is managed by the MLX runtime (or by the
/// 6-tier allocator).  All pointer fields are `usize` offsets rather than
/// raw pointers so that the descriptor remains `Send + Sync`.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct TensorView {
    /// Logical shape, e.g. `[batch, heads, seq_len, head_dim]`.
    pub shape: Vec<usize>,
    /// Strides in elements (not bytes).
    pub strides: Vec<usize>,
    /// Element type.
    pub dtype: MLXDtype,
    /// Byte offset into the backing buffer.
    pub data_offset: usize,
    /// Total bytes of the backing allocation (for bounds checking).
    pub backing_bytes: usize,
}

impl TensorView {
    /// Create a new descriptor with row-major (C-style) strides.
    pub fn row_major(shape: Vec<usize>, dtype: MLXDtype, backing_bytes: usize) -> Self {
        let mut strides = Vec::with_capacity(shape.len());
        let mut acc = 1usize;
        for &dim in shape.iter().rev() {
            strides.push(acc);
            acc *= dim;
        }
        strides.reverse();
        Self {
            shape,
            strides,
            dtype,
            data_offset: 0,
            backing_bytes,
        }
    }

    /// Total number of elements.
    pub fn numel(&self) -> usize {
        self.shape.iter().product()
    }

    /// Size of the view in bytes (contiguous estimate).
    pub fn nbytes(&self) -> usize {
        self.numel() * self.dtype.size_bytes()
    }

    /// Is the view contiguous in memory?
    pub fn is_contiguous(&self) -> bool {
        let mut expected = 1usize;
        for (&dim, &stride) in self.shape.iter().zip(self.strides.iter()).rev() {
            if stride != expected {
                return false;
            }
            expected *= dim;
        }
        true
    }

    /// Index into the view (element offset).
    ///
    /// # Panics
    /// Panics if indices are out of bounds.
    pub fn index(&self, indices: &[usize]) -> usize {
        assert_eq!(
            indices.len(),
            self.shape.len(),
            "rank mismatch: expected {}, got {}",
            self.shape.len(),
            indices.len()
        );
        let mut off = self.data_offset / self.dtype.size_bytes();
        for ((&i, &dim), &stride) in indices.iter().zip(&self.shape).zip(&self.strides) {
            assert!(i < dim, "index {} out of bounds for dimension {}", i, dim);
            off += i * stride;
        }
        off
    }

    /// Slice the last dimension, returning a new view.
    pub fn slice_last(&self, start: usize, len: usize) -> Option<Self> {
        if self.shape.is_empty() {
            return None;
        }
        let last = self.shape.len() - 1;
        if start + len > self.shape[last] {
            return None;
        }
        let mut new = self.clone();
        new.shape[last] = len;
        new.data_offset += start * self.strides[last] * self.dtype.size_bytes();
        Some(new)
    }
}

impl fmt::Display for TensorView {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "TensorView{{shape={:?}, strides={:?}, dtype={}, offset={}, nbytes={}}}",
            self.shape,
            self.strides,
            self.dtype.as_str(),
            self.data_offset,
            self.nbytes()
        )
    }
}

// ---------------------------------------------------------------------------
// AttentionHead
// ---------------------------------------------------------------------------

/// Identifies a single attention head inside a multi-head layer.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
pub struct AttentionHead {
    /// Head index within the layer.
    pub head_idx: usize,
    /// Per-head dimension (e.g. 128 for a 4096-dim, 32-head model).
    pub dim: usize,
}

impl AttentionHead {
    /// Number of bytes occupied by one token's K/V vector for this head.
    pub fn kv_bytes_per_token(&self, dtype: MLXDtype) -> usize {
        self.dim * dtype.size_bytes()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mlxdtype_size() {
        assert_eq!(MLXDtype::F32.size_bytes(), 4);
        assert_eq!(MLXDtype::F16.size_bytes(), 2);
        assert_eq!(MLXDtype::BFloat16.size_bytes(), 2);
        assert_eq!(MLXDtype::Int32.size_bytes(), 4);
        assert_eq!(MLXDtype::Int64.size_bytes(), 8);
    }

    #[test]
    fn tensorview_row_major() {
        let tv = TensorView::row_major(vec![2, 3, 4], MLXDtype::F32, 96);
        assert_eq!(tv.shape, vec![2, 3, 4]);
        assert_eq!(tv.strides, vec![12, 4, 1]);
        assert_eq!(tv.numel(), 24);
        assert_eq!(tv.nbytes(), 96);
        assert!(tv.is_contiguous());
    }

    #[test]
    fn tensorview_index() {
        let tv = TensorView::row_major(vec![2, 3, 4], MLXDtype::F32, 96);
        assert_eq!(tv.index(&[1, 2, 3]), 1 * 12 + 2 * 4 + 3); // 23
    }

    #[test]
    fn tensorview_slice_last() {
        let tv = TensorView::row_major(vec![2, 8], MLXDtype::F32, 64);
        let s = tv.slice_last(4, 2).unwrap();
        assert_eq!(s.shape, vec![2, 2]);
        assert_eq!(s.data_offset, 4 * tv.dtype.size_bytes());
    }

    #[test]
    fn attention_head_bytes() {
        let h = AttentionHead {
            head_idx: 0,
            dim: 128,
        };
        assert_eq!(h.kv_bytes_per_token(MLXDtype::F16), 256);
    }
}
