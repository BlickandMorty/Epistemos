//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.6.7 — Nano Model Training Recipe: MOHAWK distillation
//!   hyperparameters validated · layer placement + quant table +
//!   ANE-vs-GPU rule · training infra via MLX-LM v0.31.1+ (Mamba-1,
//!   Mamba-2, Nemotron-H, Jamba native).
//! - MOHAWK distillation paper: Bick et al., "Transformers to SSMs:
//!   Distilling Quadratic Knowledge to Subquadratic Models",
//!   arXiv:2408.10189, 2024.
//!
//! # Wave J B.6.7 — Nano Model Training Recipe substrate
//!
//! The Recipe is the **plan** that converts a teacher transformer
//! into a small SSM (Mamba / Nemotron-H / Jamba) via 3-stage MOHAWK
//! distillation. Substrate floor here owns:
//!
//! - [`MohawkHyperparams`] — the per-stage learning rates / weights.
//! - [`LayerPlacement`] enum (Ane / Gpu / Cpu) per-layer.
//! - [`QuantSpec`] enum (Fp16 / Int8 / Int4) per-layer.
//! - [`NanoTrainingRecipe`] — the full recipe; ::validate() enforces
//!   per-layer placement + quant consistency.
//!
//! Real training infra lives in `epistemos-research/python/` (MLX-LM
//! wrapper); substrate floor is the recipe envelope that envelope
//! consumes.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum LayerPlacement {
    Ane,
    Gpu,
    Cpu,
}

impl LayerPlacement {
    pub const fn code(self) -> &'static str {
        match self {
            LayerPlacement::Ane => "ane",
            LayerPlacement::Gpu => "gpu",
            LayerPlacement::Cpu => "cpu",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum QuantSpec {
    Fp16,
    Int8,
    Int4,
}

impl QuantSpec {
    pub const fn code(self) -> &'static str {
        match self {
            QuantSpec::Fp16 => "fp16",
            QuantSpec::Int8 => "int8",
            QuantSpec::Int4 => "int4",
        }
    }

    /// Bits per weight.
    pub const fn bits_per_weight(self) -> u8 {
        match self {
            QuantSpec::Fp16 => 16,
            QuantSpec::Int8 => 8,
            QuantSpec::Int4 => 4,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct MohawkHyperparams {
    pub stage1_lr: f32,
    pub stage2_lr: f32,
    pub stage3_lr: f32,
    pub kl_weight: f32,
    pub feature_weight: f32,
}

impl MohawkHyperparams {
    /// Per arXiv:2408.10189 Table 3 (representative; the paper varies
    /// per architecture). Substrate-floor defaults — production callers
    /// override per target model.
    pub const DEFAULT: Self = Self {
        stage1_lr: 1e-4,
        stage2_lr: 5e-5,
        stage3_lr: 2e-5,
        kl_weight: 0.5,
        feature_weight: 0.5,
    };
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LayerSpec {
    pub layer_index: usize,
    pub placement: LayerPlacement,
    pub quant: QuantSpec,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct NanoTrainingRecipe {
    pub target_param_count: u64,
    pub hyperparams: MohawkHyperparams,
    pub layers: Vec<LayerSpec>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum RecipeError {
    EmptyLayers,
    NonContiguousLayerIndex { expected: usize, actual: usize },
    DuplicateLayerIndex { index: usize },
    AneWithInt4 { layer_index: usize },
    NonPositiveLearningRate { stage: u8, lr: f32 },
}

impl NanoTrainingRecipe {
    /// Validate: layers form `0..N` contiguous range, no duplicates,
    /// no ANE+Int4 combo (ANE doesn't support int4 per Apple docs),
    /// all learning rates positive.
    pub fn validate(&self) -> Result<(), RecipeError> {
        if self.layers.is_empty() {
            return Err(RecipeError::EmptyLayers);
        }
        if self.hyperparams.stage1_lr <= 0.0 {
            return Err(RecipeError::NonPositiveLearningRate {
                stage: 1,
                lr: self.hyperparams.stage1_lr,
            });
        }
        if self.hyperparams.stage2_lr <= 0.0 {
            return Err(RecipeError::NonPositiveLearningRate {
                stage: 2,
                lr: self.hyperparams.stage2_lr,
            });
        }
        if self.hyperparams.stage3_lr <= 0.0 {
            return Err(RecipeError::NonPositiveLearningRate {
                stage: 3,
                lr: self.hyperparams.stage3_lr,
            });
        }
        let mut seen = std::collections::HashSet::new();
        let mut sorted: Vec<&LayerSpec> = self.layers.iter().collect();
        sorted.sort_by_key(|l| l.layer_index);
        for (expected, l) in sorted.iter().enumerate() {
            if !seen.insert(l.layer_index) {
                return Err(RecipeError::DuplicateLayerIndex { index: l.layer_index });
            }
            if l.layer_index != expected {
                return Err(RecipeError::NonContiguousLayerIndex {
                    expected,
                    actual: l.layer_index,
                });
            }
            if l.placement == LayerPlacement::Ane && l.quant == QuantSpec::Int4 {
                return Err(RecipeError::AneWithInt4 { layer_index: l.layer_index });
            }
        }
        Ok(())
    }

    /// Total bits across all layers' weights (caller multiplies by
    /// per-layer parameter count separately; substrate is per-layer
    /// quant-bits sum).
    pub fn total_quant_bits(&self) -> u64 {
        self.layers
            .iter()
            .map(|l| l.quant.bits_per_weight() as u64)
            .sum()
    }

    /// Layer-count distribution across placements. Useful for the
    /// recipe planner: an ANE-heavy recipe takes a different memory
    /// envelope than a GPU-heavy one even at the same total bit count.
    pub fn placement_counts(&self) -> PlacementCounts {
        let mut c = PlacementCounts::default();
        for l in &self.layers {
            match l.placement {
                LayerPlacement::Ane => c.ane += 1,
                LayerPlacement::Gpu => c.gpu += 1,
                LayerPlacement::Cpu => c.cpu += 1,
            }
        }
        c
    }

    /// Layer-count distribution across quant specs.
    pub fn quant_counts(&self) -> QuantCounts {
        let mut c = QuantCounts::default();
        for l in &self.layers {
            match l.quant {
                QuantSpec::Fp16 => c.fp16 += 1,
                QuantSpec::Int8 => c.int8 += 1,
                QuantSpec::Int4 => c.int4 += 1,
            }
        }
        c
    }

    /// Estimated weight memory in bytes, given a uniform per-layer
    /// parameter count `params_per_layer`. Each layer contributes
    /// `(params_per_layer × quant_bits_per_weight) / 8` bytes; the
    /// total is rounded up to the next whole byte to be conservative
    /// (production planners want upper bounds, not optimistic floors).
    pub fn weight_bytes_estimate(&self, params_per_layer: u64) -> u64 {
        let total_bits: u64 = self
            .layers
            .iter()
            .map(|l| params_per_layer.saturating_mul(l.quant.bits_per_weight() as u64))
            .sum();
        // Ceiling division by 8.
        (total_bits + 7) / 8
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlacementCounts {
    pub ane: usize,
    pub gpu: usize,
    pub cpu: usize,
}

impl PlacementCounts {
    pub fn total(&self) -> usize {
        self.ane + self.gpu + self.cpu
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct QuantCounts {
    pub fp16: usize,
    pub int8: usize,
    pub int4: usize,
}

impl QuantCounts {
    pub fn total(&self) -> usize {
        self.fp16 + self.int8 + self.int4
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn spec(idx: usize, p: LayerPlacement, q: QuantSpec) -> LayerSpec {
        LayerSpec { layer_index: idx, placement: p, quant: q }
    }

    #[test]
    fn three_distinct_placements() {
        let s: std::collections::HashSet<_> =
            [LayerPlacement::Ane, LayerPlacement::Gpu, LayerPlacement::Cpu]
                .iter()
                .copied()
                .collect();
        assert_eq!(s.len(), 3);
    }

    #[test]
    fn three_distinct_quant_specs() {
        let s: std::collections::HashSet<_> =
            [QuantSpec::Fp16, QuantSpec::Int8, QuantSpec::Int4]
                .iter()
                .copied()
                .collect();
        assert_eq!(s.len(), 3);
    }

    #[test]
    fn bits_per_weight_matches_spec() {
        assert_eq!(QuantSpec::Fp16.bits_per_weight(), 16);
        assert_eq!(QuantSpec::Int8.bits_per_weight(), 8);
        assert_eq!(QuantSpec::Int4.bits_per_weight(), 4);
    }

    #[test]
    fn default_hyperparams_are_positive_and_descending() {
        let h = MohawkHyperparams::DEFAULT;
        assert!(h.stage1_lr > 0.0);
        assert!(h.stage2_lr > 0.0);
        assert!(h.stage3_lr > 0.0);
        assert!(h.stage1_lr > h.stage2_lr);
        assert!(h.stage2_lr > h.stage3_lr);
    }

    #[test]
    fn empty_layers_rejected() {
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![],
        };
        let err = r.validate().unwrap_err();
        assert_eq!(err, RecipeError::EmptyLayers);
    }

    #[test]
    fn contiguous_layers_validate() {
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![
                spec(0, LayerPlacement::Gpu, QuantSpec::Fp16),
                spec(1, LayerPlacement::Gpu, QuantSpec::Int8),
                spec(2, LayerPlacement::Cpu, QuantSpec::Int4),
            ],
        };
        assert!(r.validate().is_ok());
    }

    #[test]
    fn non_contiguous_layers_rejected() {
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![
                spec(0, LayerPlacement::Gpu, QuantSpec::Fp16),
                spec(2, LayerPlacement::Gpu, QuantSpec::Int8),
            ],
        };
        let err = r.validate().unwrap_err();
        assert_eq!(
            err,
            RecipeError::NonContiguousLayerIndex { expected: 1, actual: 2 }
        );
    }

    #[test]
    fn duplicate_layer_index_rejected() {
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![
                spec(0, LayerPlacement::Gpu, QuantSpec::Fp16),
                spec(0, LayerPlacement::Cpu, QuantSpec::Int8),
            ],
        };
        let err = r.validate().unwrap_err();
        assert_eq!(err, RecipeError::DuplicateLayerIndex { index: 0 });
    }

    #[test]
    fn ane_with_int4_rejected() {
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![spec(0, LayerPlacement::Ane, QuantSpec::Int4)],
        };
        let err = r.validate().unwrap_err();
        assert_eq!(err, RecipeError::AneWithInt4 { layer_index: 0 });
    }

    #[test]
    fn ane_with_int8_allowed() {
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![spec(0, LayerPlacement::Ane, QuantSpec::Int8)],
        };
        assert!(r.validate().is_ok());
    }

    #[test]
    fn non_positive_lr_rejected_per_stage() {
        let mut h = MohawkHyperparams::DEFAULT;
        h.stage2_lr = 0.0;
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: h,
            layers: vec![spec(0, LayerPlacement::Gpu, QuantSpec::Fp16)],
        };
        let err = r.validate().unwrap_err();
        assert_eq!(err, RecipeError::NonPositiveLearningRate { stage: 2, lr: 0.0 });
    }

    #[test]
    fn total_quant_bits_sums_per_layer() {
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![
                spec(0, LayerPlacement::Gpu, QuantSpec::Fp16),
                spec(1, LayerPlacement::Gpu, QuantSpec::Int8),
                spec(2, LayerPlacement::Cpu, QuantSpec::Int4),
            ],
        };
        assert_eq!(r.total_quant_bits(), 16 + 8 + 4);
    }

    #[test]
    fn placement_codes_stable() {
        assert_eq!(LayerPlacement::Ane.code(), "ane");
        assert_eq!(LayerPlacement::Gpu.code(), "gpu");
        assert_eq!(LayerPlacement::Cpu.code(), "cpu");
    }

    #[test]
    fn quant_codes_stable() {
        assert_eq!(QuantSpec::Fp16.code(), "fp16");
        assert_eq!(QuantSpec::Int8.code(), "int8");
        assert_eq!(QuantSpec::Int4.code(), "int4");
    }

    #[test]
    fn recipe_roundtrips_through_serde_json() {
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![spec(0, LayerPlacement::Gpu, QuantSpec::Fp16)],
        };
        let json = serde_json::to_string(&r).unwrap();
        let back: NanoTrainingRecipe = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn out_of_order_but_contiguous_layers_validate() {
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![
                spec(2, LayerPlacement::Cpu, QuantSpec::Int4),
                spec(0, LayerPlacement::Gpu, QuantSpec::Fp16),
                spec(1, LayerPlacement::Gpu, QuantSpec::Int8),
            ],
        };
        assert!(r.validate().is_ok());
    }

    // ── Diagnostic surface tests (iter 96) ──────────────────────────────────

    #[test]
    fn placement_counts_distribute_correctly() {
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![
                spec(0, LayerPlacement::Ane, QuantSpec::Fp16),
                spec(1, LayerPlacement::Ane, QuantSpec::Int8),
                spec(2, LayerPlacement::Gpu, QuantSpec::Fp16),
                spec(3, LayerPlacement::Cpu, QuantSpec::Int4),
            ],
        };
        let pc = r.placement_counts();
        assert_eq!(pc.ane, 2);
        assert_eq!(pc.gpu, 1);
        assert_eq!(pc.cpu, 1);
        assert_eq!(pc.total(), 4);
    }

    #[test]
    fn quant_counts_distribute_correctly() {
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![
                spec(0, LayerPlacement::Gpu, QuantSpec::Fp16),
                spec(1, LayerPlacement::Gpu, QuantSpec::Fp16),
                spec(2, LayerPlacement::Gpu, QuantSpec::Int8),
                spec(3, LayerPlacement::Gpu, QuantSpec::Int4),
                spec(4, LayerPlacement::Gpu, QuantSpec::Int4),
            ],
        };
        let qc = r.quant_counts();
        assert_eq!(qc.fp16, 2);
        assert_eq!(qc.int8, 1);
        assert_eq!(qc.int4, 2);
        assert_eq!(qc.total(), 5);
    }

    #[test]
    fn placement_counts_empty_recipe_all_zero() {
        let r = NanoTrainingRecipe {
            target_param_count: 0,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![],
        };
        let pc = r.placement_counts();
        assert_eq!(pc.total(), 0);
        assert_eq!(pc.ane, 0);
    }

    #[test]
    fn weight_bytes_estimate_fp16_layer_uses_2_bytes_per_param() {
        let r = NanoTrainingRecipe {
            target_param_count: 100,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![spec(0, LayerPlacement::Gpu, QuantSpec::Fp16)],
        };
        // 100 params × 16 bits = 1600 bits = 200 bytes.
        assert_eq!(r.weight_bytes_estimate(100), 200);
    }

    #[test]
    fn weight_bytes_estimate_int8_uses_1_byte_per_param() {
        let r = NanoTrainingRecipe {
            target_param_count: 100,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![spec(0, LayerPlacement::Gpu, QuantSpec::Int8)],
        };
        assert_eq!(r.weight_bytes_estimate(100), 100);
    }

    #[test]
    fn weight_bytes_estimate_int4_uses_half_byte_per_param() {
        let r = NanoTrainingRecipe {
            target_param_count: 100,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![spec(0, LayerPlacement::Cpu, QuantSpec::Int4)],
        };
        // 100 × 4 bits = 400 bits = 50 bytes.
        assert_eq!(r.weight_bytes_estimate(100), 50);
    }

    #[test]
    fn weight_bytes_estimate_sums_across_layers() {
        let r = NanoTrainingRecipe {
            target_param_count: 200,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![
                spec(0, LayerPlacement::Gpu, QuantSpec::Fp16), // 100×16 = 1600
                spec(1, LayerPlacement::Gpu, QuantSpec::Int8), // 100×8  =  800
                spec(2, LayerPlacement::Cpu, QuantSpec::Int4), // 100×4  =  400
            ],
        };
        // Total: 1600 + 800 + 400 = 2800 bits = 350 bytes.
        assert_eq!(r.weight_bytes_estimate(100), 350);
    }

    #[test]
    fn weight_bytes_estimate_ceiling_rounds_up() {
        // 1 param × 4 bits = 4 bits; ceiling div by 8 → 1 byte.
        let r = NanoTrainingRecipe {
            target_param_count: 1,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![spec(0, LayerPlacement::Cpu, QuantSpec::Int4)],
        };
        assert_eq!(r.weight_bytes_estimate(1), 1);
    }

    #[test]
    fn placement_counts_serde_roundtrip() {
        let c = PlacementCounts { ane: 1, gpu: 2, cpu: 3 };
        let json = serde_json::to_string(&c).unwrap();
        let back: PlacementCounts = serde_json::from_str(&json).unwrap();
        assert_eq!(c, back);
    }

    #[test]
    fn quant_counts_serde_roundtrip() {
        let c = QuantCounts { fp16: 1, int8: 2, int4: 3 };
        let json = serde_json::to_string(&c).unwrap();
        let back: QuantCounts = serde_json::from_str(&json).unwrap();
        assert_eq!(c, back);
    }
}
