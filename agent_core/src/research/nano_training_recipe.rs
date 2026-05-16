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
}
