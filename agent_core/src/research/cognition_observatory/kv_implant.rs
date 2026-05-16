//! Source: `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md`
//! lines 419-510 — `KVCacheImplanter` / `KVCacheSnapshot` / `LayerKVSnapshot`
//! Swift spec. This module is the Rust mirror: serializable types for
//! cross-process / on-disk transfer of KV snapshots + a trait for the
//! implanter behavior + a mock implementation suitable for substrate tests.
//!
//! # Wave J2 sub-feature #1 — KV implantation
//!
//! Per `MASTER_FUSION §3.26`:
//! - **KVCacheImplanter / KVCacheSnapshot / LayerKVSnapshot** — direct UMA
//!   memory inspection of the live KV cache + targeted restore at a
//!   specific layer / token position.
//!
//! The Swift `KVCacheImplanter` operates on MLX KV cache (Swift-side). The
//! Rust mirror here owns the wire format + the implanter trait that future
//! MLX-Rust bindings will impl. The included [`MockKvCacheImplanter`] is
//! purely in-memory and exists for testing the trait surface.
//!
//! Snapshot bytes are kept untyped (`Vec<u8>`) and tagged with a [`KvDtype`]
//! enum so callers can serialize fp16 / fp32 / int8 quantized caches
//! through the same envelope. Layout is deferred to the caller — the
//! substrate is intentionally format-agnostic.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum KvDtype {
    Float16,
    Float32,
    Int8,
}

impl KvDtype {
    pub const fn byte_size(self) -> usize {
        match self {
            KvDtype::Float16 => 2,
            KvDtype::Float32 => 4,
            KvDtype::Int8 => 1,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvShape {
    pub n_heads: usize,
    pub head_dim: usize,
    pub seq_len: usize,
}

impl KvShape {
    pub fn element_count(self) -> usize {
        self.n_heads * self.head_dim * self.seq_len
    }

    /// Byte size of one tensor (keys or values) at the given dtype.
    /// `element_count() * dtype.byte_size()`.
    pub fn byte_size(self, dtype: KvDtype) -> usize {
        self.element_count() * dtype.byte_size()
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LayerKVSnapshot {
    pub layer_index: usize,
    pub keys: Vec<u8>,
    pub values: Vec<u8>,
    pub keys_dtype: KvDtype,
    pub values_dtype: KvDtype,
    pub shape: KvShape,
}

impl LayerKVSnapshot {
    /// Total bytes-on-the-wire for this layer: `keys.len() + values.len()`.
    pub fn bytes(&self) -> usize {
        self.keys.len() + self.values.len()
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvCacheSnapshot {
    pub layers: Vec<LayerKVSnapshot>,
    pub model_id: String,
    pub created_at_unix_secs: i64,
}

impl KvCacheSnapshot {
    /// Number of layers in this snapshot.
    pub fn layer_count(&self) -> usize {
        self.layers.len()
    }

    /// Total bytes across every layer (sum of `LayerKVSnapshot::bytes`).
    /// The "how big is this snapshot on disk?" diagnostic.
    pub fn total_bytes(&self) -> usize {
        self.layers.iter().map(|l| l.bytes()).sum()
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum KvImplantError {
    /// Snapshot byte length didn't match `shape.element_count() * dtype.byte_size()`.
    SnapshotShapeMismatch {
        expected: usize,
        actual: usize,
        which: &'static str,
    },
    /// Restore targeted a layer index outside `0..impl.layer_count()`.
    LayerOutOfRange { layer: usize, layer_count: usize },
    /// Restore position would walk off the end of the destination cache.
    PositionOutOfRange { position: usize, dest_seq_len: usize, src_seq_len: usize },
    /// dtype mismatch between snapshot and destination cache.
    DtypeMismatch { snapshot: KvDtype, destination: KvDtype },
}

pub trait KvCacheImplanter {
    fn layer_count(&self) -> usize;

    fn snapshot(&self, model_id: &str, created_at_unix_secs: i64) -> Result<KvCacheSnapshot, KvImplantError>;

    fn restore(
        &mut self,
        snapshot: &KvCacheSnapshot,
        into_layer: usize,
        at_position: usize,
    ) -> Result<(), KvImplantError>;
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MockKvCacheImplanter {
    pub layers: Vec<LayerKVSnapshot>,
}

impl MockKvCacheImplanter {
    pub fn new(layers: Vec<LayerKVSnapshot>) -> Self {
        Self { layers }
    }

    pub fn empty(layer_count: usize, shape: KvShape, dtype: KvDtype) -> Self {
        let bytes_per_layer = shape.element_count() * dtype.byte_size();
        let layers = (0..layer_count)
            .map(|i| LayerKVSnapshot {
                layer_index: i,
                keys: vec![0u8; bytes_per_layer],
                values: vec![0u8; bytes_per_layer],
                keys_dtype: dtype,
                values_dtype: dtype,
                shape,
            })
            .collect();
        Self { layers }
    }
}

impl KvCacheImplanter for MockKvCacheImplanter {
    fn layer_count(&self) -> usize {
        self.layers.len()
    }

    fn snapshot(&self, model_id: &str, created_at_unix_secs: i64) -> Result<KvCacheSnapshot, KvImplantError> {
        for layer in &self.layers {
            let key_expected =
                layer.shape.element_count() * layer.keys_dtype.byte_size();
            if layer.keys.len() != key_expected {
                return Err(KvImplantError::SnapshotShapeMismatch {
                    expected: key_expected,
                    actual: layer.keys.len(),
                    which: "keys",
                });
            }
            let val_expected =
                layer.shape.element_count() * layer.values_dtype.byte_size();
            if layer.values.len() != val_expected {
                return Err(KvImplantError::SnapshotShapeMismatch {
                    expected: val_expected,
                    actual: layer.values.len(),
                    which: "values",
                });
            }
        }
        Ok(KvCacheSnapshot {
            layers: self.layers.clone(),
            model_id: model_id.to_string(),
            created_at_unix_secs,
        })
    }

    fn restore(
        &mut self,
        snapshot: &KvCacheSnapshot,
        into_layer: usize,
        at_position: usize,
    ) -> Result<(), KvImplantError> {
        if into_layer >= self.layers.len() {
            return Err(KvImplantError::LayerOutOfRange {
                layer: into_layer,
                layer_count: self.layers.len(),
            });
        }
        let dest = &mut self.layers[into_layer];
        let src = snapshot.layers.iter().find(|l| l.layer_index == into_layer);
        let src = match src {
            Some(l) => l,
            None => {
                return Err(KvImplantError::LayerOutOfRange {
                    layer: into_layer,
                    layer_count: snapshot.layers.len(),
                });
            }
        };
        if src.keys_dtype != dest.keys_dtype || src.values_dtype != dest.values_dtype {
            return Err(KvImplantError::DtypeMismatch {
                snapshot: src.keys_dtype,
                destination: dest.keys_dtype,
            });
        }
        if at_position + src.shape.seq_len > dest.shape.seq_len {
            return Err(KvImplantError::PositionOutOfRange {
                position: at_position,
                dest_seq_len: dest.shape.seq_len,
                src_seq_len: src.shape.seq_len,
            });
        }
        let per_token_key_bytes =
            src.shape.n_heads * src.shape.head_dim * src.keys_dtype.byte_size();
        let per_token_val_bytes =
            src.shape.n_heads * src.shape.head_dim * src.values_dtype.byte_size();
        let key_offset = at_position * per_token_key_bytes;
        let val_offset = at_position * per_token_val_bytes;
        let key_len = src.shape.seq_len * per_token_key_bytes;
        let val_len = src.shape.seq_len * per_token_val_bytes;
        dest.keys[key_offset..key_offset + key_len].copy_from_slice(&src.keys[..key_len]);
        dest.values[val_offset..val_offset + val_len].copy_from_slice(&src.values[..val_len]);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn shape_for(seq_len: usize) -> KvShape {
        KvShape { n_heads: 2, head_dim: 3, seq_len }
    }

    #[test]
    fn byte_size_per_dtype_is_canonical() {
        assert_eq!(KvDtype::Float16.byte_size(), 2);
        assert_eq!(KvDtype::Float32.byte_size(), 4);
        assert_eq!(KvDtype::Int8.byte_size(), 1);
    }

    #[test]
    fn element_count_multiplies_three_axes() {
        let s = KvShape { n_heads: 4, head_dim: 8, seq_len: 16 };
        assert_eq!(s.element_count(), 4 * 8 * 16);
    }

    #[test]
    fn empty_mock_implanter_has_zeroed_layers() {
        let m = MockKvCacheImplanter::empty(3, shape_for(4), KvDtype::Float32);
        assert_eq!(m.layer_count(), 3);
        for l in &m.layers {
            assert!(l.keys.iter().all(|&b| b == 0));
            assert!(l.values.iter().all(|&b| b == 0));
            assert_eq!(l.shape.seq_len, 4);
        }
    }

    #[test]
    fn snapshot_roundtrips_through_serde_json() {
        let mock = MockKvCacheImplanter::empty(2, shape_for(2), KvDtype::Int8);
        let snap = mock.snapshot("qwen3-test", 1_700_000_000).unwrap();
        let json = serde_json::to_string(&snap).unwrap();
        let back: KvCacheSnapshot = serde_json::from_str(&json).unwrap();
        assert_eq!(snap, back);
    }

    #[test]
    fn snapshot_shape_mismatch_errors() {
        let mut mock = MockKvCacheImplanter::empty(1, shape_for(2), KvDtype::Float16);
        mock.layers[0].keys.pop();
        let err = mock.snapshot("m", 0).unwrap_err();
        match err {
            KvImplantError::SnapshotShapeMismatch { which, .. } => {
                assert_eq!(which, "keys");
            }
            other => panic!("expected SnapshotShapeMismatch, got {:?}", other),
        }
    }

    #[test]
    fn restore_layer_out_of_range_errors() {
        let mock_src = MockKvCacheImplanter::empty(1, shape_for(1), KvDtype::Float32);
        let snap = mock_src.snapshot("m", 0).unwrap();
        let mut mock_dst = MockKvCacheImplanter::empty(1, shape_for(4), KvDtype::Float32);
        let err = mock_dst.restore(&snap, 99, 0).unwrap_err();
        assert_eq!(err, KvImplantError::LayerOutOfRange { layer: 99, layer_count: 1 });
    }

    #[test]
    fn restore_position_out_of_range_errors() {
        let mock_src = MockKvCacheImplanter::empty(1, shape_for(2), KvDtype::Float32);
        let snap = mock_src.snapshot("m", 0).unwrap();
        let mut mock_dst = MockKvCacheImplanter::empty(1, shape_for(3), KvDtype::Float32);
        let err = mock_dst.restore(&snap, 0, 2).unwrap_err();
        match err {
            KvImplantError::PositionOutOfRange { position, dest_seq_len, src_seq_len } => {
                assert_eq!(position, 2);
                assert_eq!(dest_seq_len, 3);
                assert_eq!(src_seq_len, 2);
            }
            other => panic!("expected PositionOutOfRange, got {:?}", other),
        }
    }

    #[test]
    fn restore_dtype_mismatch_errors() {
        let mock_src = MockKvCacheImplanter::empty(1, shape_for(1), KvDtype::Float16);
        let snap = mock_src.snapshot("m", 0).unwrap();
        let mut mock_dst = MockKvCacheImplanter::empty(1, shape_for(4), KvDtype::Float32);
        let err = mock_dst.restore(&snap, 0, 0).unwrap_err();
        assert_eq!(
            err,
            KvImplantError::DtypeMismatch {
                snapshot: KvDtype::Float16,
                destination: KvDtype::Float32,
            }
        );
    }

    #[test]
    fn restore_copies_into_position() {
        let mut src_layer = LayerKVSnapshot {
            layer_index: 0,
            keys: vec![0u8; 2 * 3 * 2 * 4],
            values: vec![0u8; 2 * 3 * 2 * 4],
            keys_dtype: KvDtype::Float32,
            values_dtype: KvDtype::Float32,
            shape: shape_for(2),
        };
        for (i, b) in src_layer.keys.iter_mut().enumerate() {
            *b = (i % 256) as u8;
        }
        let snapshot = KvCacheSnapshot {
            layers: vec![src_layer.clone()],
            model_id: "m".to_string(),
            created_at_unix_secs: 0,
        };
        let mut mock_dst = MockKvCacheImplanter::empty(1, shape_for(5), KvDtype::Float32);
        mock_dst.restore(&snapshot, 0, 1).unwrap();
        let per_token_bytes = 2 * 3 * 4;
        let dst_keys = &mock_dst.layers[0].keys;
        assert!(dst_keys[..per_token_bytes].iter().all(|&b| b == 0));
        for i in 0..(2 * per_token_bytes) {
            assert_eq!(dst_keys[per_token_bytes + i], src_layer.keys[i]);
        }
    }

    #[test]
    fn layer_count_reflects_constructor() {
        let m = MockKvCacheImplanter::empty(5, shape_for(1), KvDtype::Int8);
        assert_eq!(m.layer_count(), 5);
    }

    // ── byte_size + bytes + total_bytes (iter 128) ──────────────────────────

    #[test]
    fn dtype_byte_size_pinned() {
        assert_eq!(KvDtype::Float16.byte_size(), 2);
        assert_eq!(KvDtype::Float32.byte_size(), 4);
        assert_eq!(KvDtype::Int8.byte_size(), 1);
    }

    #[test]
    fn shape_byte_size_multiplies_element_count_by_dtype() {
        let s = KvShape { n_heads: 4, head_dim: 64, seq_len: 32 };
        // element_count = 4*64*32 = 8192
        assert_eq!(s.element_count(), 8192);
        assert_eq!(s.byte_size(KvDtype::Float16), 8192 * 2);
        assert_eq!(s.byte_size(KvDtype::Float32), 8192 * 4);
        assert_eq!(s.byte_size(KvDtype::Int8), 8192);
    }

    #[test]
    fn layer_bytes_sums_keys_and_values() {
        let s = shape_for(4);
        let layer = LayerKVSnapshot {
            layer_index: 0,
            keys: vec![0u8; 100],
            values: vec![0u8; 80],
            keys_dtype: KvDtype::Int8,
            values_dtype: KvDtype::Int8,
            shape: s,
        };
        assert_eq!(layer.bytes(), 180);
    }

    #[test]
    fn snapshot_layer_count_zero_for_empty() {
        let snap = KvCacheSnapshot {
            layers: vec![],
            model_id: "x".into(),
            created_at_unix_secs: 0,
        };
        assert_eq!(snap.layer_count(), 0);
        assert_eq!(snap.total_bytes(), 0);
    }

    #[test]
    fn snapshot_total_bytes_sums_all_layers() {
        let mock = MockKvCacheImplanter::empty(3, shape_for(4), KvDtype::Float16);
        let snap = mock.snapshot("test", 0).unwrap();
        assert_eq!(snap.layer_count(), 3);
        // Each layer: 2 (heads) × 3 (head_dim) × 4 (seq_len) × 2 (fp16)
        // = 48 bytes for keys + 48 for values = 96 bytes/layer.
        // 3 layers × 96 = 288 total.
        let per_layer = shape_for(4).byte_size(KvDtype::Float16);
        let expected = 3 * (2 * per_layer);
        assert_eq!(snap.total_bytes(), expected);
    }

    #[test]
    fn snapshot_realistic_size_estimate() {
        // Realistic Qwen3-8B-style KV: 32 layers, 32 heads, 128 head_dim,
        // 32K seq_len, fp16. Per layer: 32 * 128 * 32768 * 2 (fp16) = 256 MB
        // keys + 256 MB values = 512 MB/layer × 32 layers = 16 GB total
        // (the canonical "why we need KV-cache compression" number).
        let shape = KvShape { n_heads: 32, head_dim: 128, seq_len: 32_768 };
        let per_layer = shape.byte_size(KvDtype::Float16);
        assert_eq!(per_layer, 256 * 1024 * 1024); // 256 MB
        let mock = MockKvCacheImplanter::empty(32, shape, KvDtype::Float16);
        let snap = mock.snapshot("qwen3-8b", 0).unwrap();
        let expected_total = 32 * 2 * per_layer; // 32 layers × (keys + values)
        assert_eq!(snap.total_bytes(), expected_total);
        assert_eq!(expected_total, 16 * 1024 * 1024 * 1024); // 16 GB exactly
    }
}
