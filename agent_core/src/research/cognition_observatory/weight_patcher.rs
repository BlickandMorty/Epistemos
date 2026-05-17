//! Source: `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md`
//! lines 588-637 — `WeightPatcher` Swift spec (`applyLoRADelta` / `revertPatch`)
//! and `WeightType` enum (qProj, kProj, vProj, oProj, gate, up, down, embed,
//! lmHead). This module is the Rust mirror: the 9-variant target enum +
//! WeightPatch + the trait that future MLX-Rust bindings will impl, plus a
//! mock implementation for substrate testing.
//!
//! # Wave J2 sub-feature #3 — Weight Surgery
//!
//! Per `MASTER_FUSION §3.26`: targeted in-place modification of one of the
//! nine transformer weight matrices per call. The math per the Swift spec
//! is `W_new[i] = W_old[i] + alpha * delta[i]` — LoRA-style additive patch
//! with a scalar α multiplier. Revert is byte-copy from a pre-patch
//! snapshot captured by the caller before the patch landed.
//!
//! The trait deliberately does NOT keep its own snapshot ring (unlike
//! [`super::kv_implant::KvCacheImplanter`]) — weight snapshots can be
//! hundreds of MB and storing them inside the patcher would leak memory.
//! The caller is responsible for capturing + retaining the snapshot it
//! wants to revert to.

use serde::{Deserialize, Serialize};

/// The 9 patchable weight matrices per `WeightType` in the source doc.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum WeightTarget {
    QProj,
    KProj,
    VProj,
    OProj,
    Gate,
    Up,
    Down,
    Embed,
    LmHead,
}

impl WeightTarget {
    pub const ALL: [WeightTarget; 9] = [
        WeightTarget::QProj,
        WeightTarget::KProj,
        WeightTarget::VProj,
        WeightTarget::OProj,
        WeightTarget::Gate,
        WeightTarget::Up,
        WeightTarget::Down,
        WeightTarget::Embed,
        WeightTarget::LmHead,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            WeightTarget::QProj => "q_proj",
            WeightTarget::KProj => "k_proj",
            WeightTarget::VProj => "v_proj",
            WeightTarget::OProj => "o_proj",
            WeightTarget::Gate => "gate",
            WeightTarget::Up => "up",
            WeightTarget::Down => "down",
            WeightTarget::Embed => "embed",
            WeightTarget::LmHead => "lm_head",
        }
    }

    /// True for the 4 self-attention projections (Q, K, V, O). These
    /// are the "head-routed" weights — patching one affects how
    /// attention selects across token positions.
    pub const fn is_attention(self) -> bool {
        matches!(
            self,
            WeightTarget::QProj | WeightTarget::KProj | WeightTarget::VProj | WeightTarget::OProj
        )
    }

    /// True for the 3 MLP / SwiGLU projections (Gate, Up, Down).
    pub const fn is_mlp(self) -> bool {
        matches!(self, WeightTarget::Gate | WeightTarget::Up | WeightTarget::Down)
    }

    /// True for the 2 vocab-boundary tensors (Embed, LmHead). Patching
    /// these directly affects token-distribution shape and is the
    /// highest-stakes surgery class per §3.26.
    pub const fn is_io_boundary(self) -> bool {
        matches!(self, WeightTarget::Embed | WeightTarget::LmHead)
    }
}

/// A LoRA-style additive weight patch. `delta` length must match the
/// target weight tensor's element count; the patcher verifies this and
/// refuses partial / overrun patches.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct WeightPatch {
    pub layer: usize,
    pub target: WeightTarget,
    pub delta: Vec<f32>,
    pub alpha: f32,
}

impl WeightPatch {
    /// L2 norm of the delta: `sqrt(Σ d_i²)`. The "how big is this
    /// patch?" diagnostic. Production callers compare against a
    /// per-layer + per-target threshold before applying to avoid
    /// catastrophic surgery.
    pub fn magnitude(&self) -> f32 {
        let sum_sq: f32 = self.delta.iter().map(|d| d * d).sum();
        sum_sq.sqrt()
    }

    /// `|alpha| * magnitude` — the magnitude scaled by the patch's
    /// alpha. Reflects the actual change applied to weights, not just
    /// the raw delta. A patch with delta of magnitude 10 but alpha
    /// 0.01 has scaled_magnitude 0.1.
    pub fn scaled_magnitude(&self) -> f32 {
        self.alpha.abs() * self.magnitude()
    }
}

/// Pre-patch snapshot for revert. The caller captures one of these via
/// [`WeightPatcher::snapshot`] before [`WeightPatcher::apply_patch`].
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct WeightSnapshot {
    pub layer: usize,
    pub target: WeightTarget,
    pub weights: Vec<f32>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum WeightPatchError {
    /// Layer index outside `0..impl.layer_count()`.
    LayerOutOfRange { layer: usize, layer_count: usize },
    /// Target not registered for the given layer. Some models do not have
    /// gate / up / down at every layer (e.g. embedding layer skips MLP).
    TargetNotPresent { layer: usize, target: WeightTarget },
    /// `delta.len()` (or `snapshot.weights.len()`) did not match the
    /// target tensor's element count.
    ShapeMismatch { layer: usize, target: WeightTarget, expected: usize, actual: usize },
    /// Snapshot referenced a (layer, target) that doesn't match the
    /// destination weight tensor's shape.
    SnapshotTargetMismatch {
        snapshot_layer: usize,
        snapshot_target: WeightTarget,
        dest_layer: usize,
        dest_target: WeightTarget,
    },
}

pub trait WeightPatcher {
    fn layer_count(&self) -> usize;

    fn weight_len(&self, layer: usize, target: WeightTarget) -> Result<usize, WeightPatchError>;

    fn snapshot(&self, layer: usize, target: WeightTarget) -> Result<WeightSnapshot, WeightPatchError>;

    fn apply_patch(&mut self, patch: &WeightPatch) -> Result<(), WeightPatchError>;

    fn revert(&mut self, snapshot: &WeightSnapshot) -> Result<(), WeightPatchError>;
}

/// In-memory mock for substrate-floor testing. Real impl will live in a
/// future MLX-Rust binding crate that calls into the live MTLBuffer
/// backing the loaded model.
#[derive(Clone, Debug, PartialEq)]
pub struct MockWeightPatcher {
    layers: Vec<std::collections::BTreeMap<WeightTarget, Vec<f32>>>,
}

impl MockWeightPatcher {
    pub fn new(layers: Vec<std::collections::BTreeMap<WeightTarget, Vec<f32>>>) -> Self {
        Self { layers }
    }

    /// Convenience constructor: every layer has every target, each
    /// initialized to `weight_len` zeros.
    pub fn uniform(layer_count: usize, weight_len: usize) -> Self {
        let layers = (0..layer_count)
            .map(|_| {
                WeightTarget::ALL
                    .iter()
                    .map(|&t| (t, vec![0.0_f32; weight_len]))
                    .collect()
            })
            .collect();
        Self { layers }
    }
}

impl WeightPatcher for MockWeightPatcher {
    fn layer_count(&self) -> usize {
        self.layers.len()
    }

    fn weight_len(&self, layer: usize, target: WeightTarget) -> Result<usize, WeightPatchError> {
        if layer >= self.layers.len() {
            return Err(WeightPatchError::LayerOutOfRange {
                layer,
                layer_count: self.layers.len(),
            });
        }
        match self.layers[layer].get(&target) {
            Some(w) => Ok(w.len()),
            None => Err(WeightPatchError::TargetNotPresent { layer, target }),
        }
    }

    fn snapshot(&self, layer: usize, target: WeightTarget) -> Result<WeightSnapshot, WeightPatchError> {
        if layer >= self.layers.len() {
            return Err(WeightPatchError::LayerOutOfRange {
                layer,
                layer_count: self.layers.len(),
            });
        }
        let weights = self.layers[layer]
            .get(&target)
            .ok_or(WeightPatchError::TargetNotPresent { layer, target })?
            .clone();
        Ok(WeightSnapshot { layer, target, weights })
    }

    fn apply_patch(&mut self, patch: &WeightPatch) -> Result<(), WeightPatchError> {
        if patch.layer >= self.layers.len() {
            return Err(WeightPatchError::LayerOutOfRange {
                layer: patch.layer,
                layer_count: self.layers.len(),
            });
        }
        let weights = self.layers[patch.layer]
            .get_mut(&patch.target)
            .ok_or(WeightPatchError::TargetNotPresent {
                layer: patch.layer,
                target: patch.target,
            })?;
        if weights.len() != patch.delta.len() {
            return Err(WeightPatchError::ShapeMismatch {
                layer: patch.layer,
                target: patch.target,
                expected: weights.len(),
                actual: patch.delta.len(),
            });
        }
        for (w, d) in weights.iter_mut().zip(patch.delta.iter()) {
            *w += patch.alpha * d;
        }
        Ok(())
    }

    fn revert(&mut self, snapshot: &WeightSnapshot) -> Result<(), WeightPatchError> {
        if snapshot.layer >= self.layers.len() {
            return Err(WeightPatchError::LayerOutOfRange {
                layer: snapshot.layer,
                layer_count: self.layers.len(),
            });
        }
        let weights = self.layers[snapshot.layer]
            .get_mut(&snapshot.target)
            .ok_or(WeightPatchError::TargetNotPresent {
                layer: snapshot.layer,
                target: snapshot.target,
            })?;
        if weights.len() != snapshot.weights.len() {
            return Err(WeightPatchError::ShapeMismatch {
                layer: snapshot.layer,
                target: snapshot.target,
                expected: weights.len(),
                actual: snapshot.weights.len(),
            });
        }
        weights.copy_from_slice(&snapshot.weights);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn nine_distinct_weight_targets() {
        let s: std::collections::HashSet<_> = WeightTarget::ALL.iter().copied().collect();
        assert_eq!(s.len(), 9);
    }

    #[test]
    fn codes_are_stable_strings() {
        assert_eq!(WeightTarget::QProj.code(), "q_proj");
        assert_eq!(WeightTarget::KProj.code(), "k_proj");
        assert_eq!(WeightTarget::VProj.code(), "v_proj");
        assert_eq!(WeightTarget::OProj.code(), "o_proj");
        assert_eq!(WeightTarget::Gate.code(), "gate");
        assert_eq!(WeightTarget::Up.code(), "up");
        assert_eq!(WeightTarget::Down.code(), "down");
        assert_eq!(WeightTarget::Embed.code(), "embed");
        assert_eq!(WeightTarget::LmHead.code(), "lm_head");
    }

    #[test]
    fn uniform_patcher_reports_layer_count_and_weight_len() {
        let p = MockWeightPatcher::uniform(3, 16);
        assert_eq!(p.layer_count(), 3);
        for &t in WeightTarget::ALL.iter() {
            for layer in 0..3 {
                assert_eq!(p.weight_len(layer, t).unwrap(), 16);
            }
        }
    }

    #[test]
    fn apply_patch_with_alpha_one_adds_delta_verbatim() {
        let mut p = MockWeightPatcher::uniform(1, 4);
        let patch = WeightPatch {
            layer: 0,
            target: WeightTarget::QProj,
            delta: vec![0.5, -0.25, 1.0, 0.0],
            alpha: 1.0,
        };
        p.apply_patch(&patch).unwrap();
        let snap = p.snapshot(0, WeightTarget::QProj).unwrap();
        assert_eq!(snap.weights, vec![0.5, -0.25, 1.0, 0.0]);
    }

    #[test]
    fn alpha_scales_delta() {
        let mut p = MockWeightPatcher::uniform(1, 2);
        let patch = WeightPatch {
            layer: 0,
            target: WeightTarget::Down,
            delta: vec![1.0, 1.0],
            alpha: 0.5,
        };
        p.apply_patch(&patch).unwrap();
        let snap = p.snapshot(0, WeightTarget::Down).unwrap();
        assert_eq!(snap.weights, vec![0.5, 0.5]);
    }

    #[test]
    fn revert_restores_original_weights() {
        let mut p = MockWeightPatcher::uniform(1, 3);
        let pre = p.snapshot(0, WeightTarget::Gate).unwrap();
        let patch = WeightPatch {
            layer: 0,
            target: WeightTarget::Gate,
            delta: vec![1.0, 2.0, 3.0],
            alpha: 1.0,
        };
        p.apply_patch(&patch).unwrap();
        let mid = p.snapshot(0, WeightTarget::Gate).unwrap();
        assert_eq!(mid.weights, vec![1.0, 2.0, 3.0]);
        p.revert(&pre).unwrap();
        let post = p.snapshot(0, WeightTarget::Gate).unwrap();
        assert_eq!(post.weights, vec![0.0, 0.0, 0.0]);
    }

    #[test]
    fn layer_out_of_range_errors() {
        let mut p = MockWeightPatcher::uniform(2, 4);
        let patch = WeightPatch {
            layer: 99,
            target: WeightTarget::QProj,
            delta: vec![0.0; 4],
            alpha: 1.0,
        };
        let err = p.apply_patch(&patch).unwrap_err();
        assert_eq!(
            err,
            WeightPatchError::LayerOutOfRange { layer: 99, layer_count: 2 }
        );
    }

    #[test]
    fn shape_mismatch_errors() {
        let mut p = MockWeightPatcher::uniform(1, 4);
        let patch = WeightPatch {
            layer: 0,
            target: WeightTarget::Embed,
            delta: vec![0.0; 3],
            alpha: 1.0,
        };
        let err = p.apply_patch(&patch).unwrap_err();
        assert_eq!(
            err,
            WeightPatchError::ShapeMismatch {
                layer: 0,
                target: WeightTarget::Embed,
                expected: 4,
                actual: 3,
            }
        );
    }

    #[test]
    fn target_not_present_errors() {
        let layers = vec![std::collections::BTreeMap::new()];
        let mut p = MockWeightPatcher::new(layers);
        let patch = WeightPatch {
            layer: 0,
            target: WeightTarget::LmHead,
            delta: vec![],
            alpha: 1.0,
        };
        let err = p.apply_patch(&patch).unwrap_err();
        assert_eq!(
            err,
            WeightPatchError::TargetNotPresent { layer: 0, target: WeightTarget::LmHead }
        );
    }

    #[test]
    fn snapshot_then_apply_then_revert_is_lossless() {
        let mut p = MockWeightPatcher::uniform(2, 5);
        for i in 0..5 {
            p.apply_patch(&WeightPatch {
                layer: 1,
                target: WeightTarget::Up,
                delta: vec![i as f32; 5],
                alpha: 1.0,
            })
            .unwrap();
        }
        let pre = p.snapshot(1, WeightTarget::Up).unwrap();
        for _ in 0..10 {
            p.apply_patch(&WeightPatch {
                layer: 1,
                target: WeightTarget::Up,
                delta: vec![7.7; 5],
                alpha: 0.3,
            })
            .unwrap();
        }
        p.revert(&pre).unwrap();
        let post = p.snapshot(1, WeightTarget::Up).unwrap();
        assert_eq!(post.weights, pre.weights);
    }

    #[test]
    fn patch_roundtrips_through_serde_json() {
        let patch = WeightPatch {
            layer: 7,
            target: WeightTarget::VProj,
            delta: vec![0.1, -0.2, 0.3],
            alpha: 0.5,
        };
        let json = serde_json::to_string(&patch).unwrap();
        let back: WeightPatch = serde_json::from_str(&json).unwrap();
        assert_eq!(patch, back);
    }

    // ── classifiers + magnitude tests (iter 130) ────────────────────────────

    fn approx(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn classifier_attention_includes_qkvo_only() {
        let attn = [WeightTarget::QProj, WeightTarget::KProj, WeightTarget::VProj, WeightTarget::OProj];
        for t in WeightTarget::ALL.iter() {
            assert_eq!(t.is_attention(), attn.contains(t));
        }
    }

    #[test]
    fn classifier_mlp_includes_gate_up_down_only() {
        let mlp = [WeightTarget::Gate, WeightTarget::Up, WeightTarget::Down];
        for t in WeightTarget::ALL.iter() {
            assert_eq!(t.is_mlp(), mlp.contains(t));
        }
    }

    #[test]
    fn classifier_io_boundary_includes_embed_lmhead_only() {
        let io = [WeightTarget::Embed, WeightTarget::LmHead];
        for t in WeightTarget::ALL.iter() {
            assert_eq!(t.is_io_boundary(), io.contains(t));
        }
    }

    #[test]
    fn classifiers_partition_the_target_space() {
        // Each target is in exactly one class (4 + 3 + 2 = 9).
        for t in WeightTarget::ALL.iter() {
            let c = (t.is_attention() as u8) + (t.is_mlp() as u8) + (t.is_io_boundary() as u8);
            assert_eq!(c, 1, "target {:?} belongs to {} classes", t, c);
        }
    }

    #[test]
    fn magnitude_zero_delta_is_zero() {
        let patch = WeightPatch {
            layer: 0,
            target: WeightTarget::QProj,
            delta: vec![0.0; 10],
            alpha: 1.0,
        };
        assert!(approx(patch.magnitude(), 0.0, 1e-6));
    }

    #[test]
    fn magnitude_pythagorean_three_four_five() {
        let patch = WeightPatch {
            layer: 0,
            target: WeightTarget::QProj,
            delta: vec![3.0, 4.0],
            alpha: 1.0,
        };
        assert!(approx(patch.magnitude(), 5.0, 1e-6));
    }

    #[test]
    fn scaled_magnitude_multiplies_by_abs_alpha() {
        // delta of magnitude 10, alpha 0.01 → scaled = 0.1.
        let patch = WeightPatch {
            layer: 0,
            target: WeightTarget::QProj,
            delta: vec![10.0, 0.0],
            alpha: 0.01,
        };
        assert!(approx(patch.scaled_magnitude(), 0.1, 1e-6));
    }

    #[test]
    fn scaled_magnitude_handles_negative_alpha() {
        // Negative alpha takes abs — direction of patch is captured by
        // delta sign, not by alpha sign convention.
        let patch = WeightPatch {
            layer: 0,
            target: WeightTarget::QProj,
            delta: vec![3.0, 4.0],
            alpha: -2.0,
        };
        assert!(approx(patch.scaled_magnitude(), 10.0, 1e-6));
    }
}
