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
    pub const ALL: [LayerPlacement; 3] =
        [LayerPlacement::Ane, LayerPlacement::Gpu, LayerPlacement::Cpu];

    pub const fn code(self) -> &'static str {
        match self {
            LayerPlacement::Ane => "ane",
            LayerPlacement::Gpu => "gpu",
            LayerPlacement::Cpu => "cpu",
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|p| p.code() == code)
    }

    /// Predicate: this placement is on a hardware accelerator
    /// (ANE or GPU). Cross-surface invariant: `is_accelerator XOR
    /// is_cpu` partitions all variants.
    pub const fn is_accelerator(self) -> bool {
        matches!(self, LayerPlacement::Ane | LayerPlacement::Gpu)
    }

    /// Predicate: this placement is the CPU.
    pub const fn is_cpu(self) -> bool {
        matches!(self, LayerPlacement::Cpu)
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

    pub const ALL: [QuantSpec; 3] = [QuantSpec::Fp16, QuantSpec::Int8, QuantSpec::Int4];

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|q| q.code() == code)
    }

    /// Predicate: this spec uses integer quantization (`Int8` or
    /// `Int4`). Cross-surface invariant: `is_quantized iff
    /// bits_per_weight < 16`.
    pub const fn is_quantized(self) -> bool {
        matches!(self, QuantSpec::Int8 | QuantSpec::Int4)
    }

    /// Predicate: this spec is the floating-point baseline (`Fp16`).
    /// Companion to [`Self::is_quantized`]; exactly one true per variant.
    pub const fn is_floating_point(self) -> bool {
        matches!(self, QuantSpec::Fp16)
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

impl RecipeError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            RecipeError::EmptyLayers => "empty_layers",
            RecipeError::NonContiguousLayerIndex { .. } => "non_contiguous_layer_index",
            RecipeError::DuplicateLayerIndex { .. } => "duplicate_layer_index",
            RecipeError::AneWithInt4 { .. } => "ane_with_int4",
            RecipeError::NonPositiveLearningRate { .. } => "non_positive_learning_rate",
        }
    }

    /// Predicate: error pertains to layer-index validation
    /// (Empty / NonContiguous / Duplicate).
    pub const fn is_layer_index_error(&self) -> bool {
        matches!(
            self,
            RecipeError::EmptyLayers
                | RecipeError::NonContiguousLayerIndex { .. }
                | RecipeError::DuplicateLayerIndex { .. }
        )
    }

    /// Predicate: error pertains to a per-layer placement/quant rule
    /// (AneWithInt4 — Apple ANE doesn't support int4).
    pub const fn is_placement_quant_error(&self) -> bool {
        matches!(self, RecipeError::AneWithInt4 { .. })
    }

    /// Predicate: error pertains to hyperparameter validation
    /// (NonPositiveLearningRate). Cross-surface invariant:
    /// `is_layer_index_error XOR is_placement_quant_error XOR
    /// is_hyperparam_error` partitions all variants.
    pub const fn is_hyperparam_error(&self) -> bool {
        matches!(self, RecipeError::NonPositiveLearningRate { .. })
    }

    /// Layer index involved in the error, when the variant carries
    /// one. `None` for variants that don't reference a specific layer.
    pub const fn layer_index(&self) -> Option<usize> {
        match self {
            RecipeError::NonContiguousLayerIndex { actual, .. } => Some(*actual),
            RecipeError::DuplicateLayerIndex { index } => Some(*index),
            RecipeError::AneWithInt4 { layer_index } => Some(*layer_index),
            _ => None,
        }
    }
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

    // ── diagnostic surface (iter 172) ────────────────────────────────────────

    #[test]
    fn placement_from_code_roundtrips_all() {
        for p in LayerPlacement::ALL.iter().copied() {
            assert_eq!(LayerPlacement::from_code(p.code()), Some(p));
        }
        assert_eq!(LayerPlacement::from_code("ANE"), None);
        assert_eq!(LayerPlacement::from_code(""), None);
    }

    #[test]
    fn placement_accelerator_vs_cpu_partition() {
        // Cross-surface invariant: is_accelerator XOR is_cpu.
        for p in LayerPlacement::ALL.iter().copied() {
            assert_ne!(p.is_accelerator(), p.is_cpu());
        }
        assert!(LayerPlacement::Ane.is_accelerator());
        assert!(LayerPlacement::Gpu.is_accelerator());
        assert!(LayerPlacement::Cpu.is_cpu());
    }

    #[test]
    fn quant_from_code_roundtrips_all() {
        for q in QuantSpec::ALL.iter().copied() {
            assert_eq!(QuantSpec::from_code(q.code()), Some(q));
        }
        assert_eq!(QuantSpec::from_code("FP16"), None);
    }

    #[test]
    fn quant_is_quantized_aligns_with_bits_below_16() {
        // Cross-surface invariant: is_quantized iff bits_per_weight < 16.
        for q in QuantSpec::ALL.iter().copied() {
            assert_eq!(q.is_quantized(), q.bits_per_weight() < 16);
        }
    }

    #[test]
    fn quant_floating_point_and_quantized_partition() {
        // Cross-surface invariant: is_floating_point XOR is_quantized.
        for q in QuantSpec::ALL.iter().copied() {
            assert_ne!(q.is_floating_point(), q.is_quantized());
        }
        assert!(QuantSpec::Fp16.is_floating_point());
        assert!(QuantSpec::Int8.is_quantized());
        assert!(QuantSpec::Int4.is_quantized());
    }

    #[test]
    fn recipe_error_cause_distinct_per_variant() {
        let variants = [
            RecipeError::EmptyLayers,
            RecipeError::NonContiguousLayerIndex { expected: 0, actual: 1 },
            RecipeError::DuplicateLayerIndex { index: 0 },
            RecipeError::AneWithInt4 { layer_index: 0 },
            RecipeError::NonPositiveLearningRate { stage: 1, lr: 0.0 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 5);
    }

    #[test]
    fn recipe_error_3way_classifier_partition() {
        let variants = [
            RecipeError::EmptyLayers,
            RecipeError::NonContiguousLayerIndex { expected: 0, actual: 1 },
            RecipeError::DuplicateLayerIndex { index: 0 },
            RecipeError::AneWithInt4 { layer_index: 0 },
            RecipeError::NonPositiveLearningRate { stage: 1, lr: 0.0 },
        ];
        // Cross-surface invariant: exactly one of the 3 predicates is true.
        for e in variants {
            let trio = [
                e.is_layer_index_error(),
                e.is_placement_quant_error(),
                e.is_hyperparam_error(),
            ];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", e);
        }
        assert_eq!(variants.iter().filter(|e| e.is_layer_index_error()).count(), 3);
        assert_eq!(variants.iter().filter(|e| e.is_placement_quant_error()).count(), 1);
        assert_eq!(variants.iter().filter(|e| e.is_hyperparam_error()).count(), 1);
    }

    #[test]
    fn recipe_error_layer_index_extracts_when_present() {
        assert_eq!(RecipeError::EmptyLayers.layer_index(), None);
        assert_eq!(
            RecipeError::NonContiguousLayerIndex { expected: 1, actual: 5 }.layer_index(),
            Some(5),
        );
        assert_eq!(
            RecipeError::DuplicateLayerIndex { index: 7 }.layer_index(),
            Some(7),
        );
        assert_eq!(
            RecipeError::AneWithInt4 { layer_index: 3 }.layer_index(),
            Some(3),
        );
        assert_eq!(
            RecipeError::NonPositiveLearningRate { stage: 1, lr: 0.0 }.layer_index(),
            None,
        );
    }

    #[test]
    fn real_validate_error_carries_matching_cause_and_layer() {
        // Cross-surface: validate() errors carry the right cause + layer_index.
        let r = NanoTrainingRecipe {
            target_param_count: 1_000_000,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![spec(0, LayerPlacement::Ane, QuantSpec::Int4)],
        };
        let err = r.validate().unwrap_err();
        assert_eq!(err.cause(), "ane_with_int4");
        assert!(err.is_placement_quant_error());
        assert_eq!(err.layer_index(), Some(0));
    }

    #[test]
    fn placement_counts_total_matches_layers_len_invariant() {
        // Cross-surface invariant: placement_counts.total() == layers.len().
        let r = NanoTrainingRecipe {
            target_param_count: 0,
            hyperparams: MohawkHyperparams::DEFAULT,
            layers: vec![
                spec(0, LayerPlacement::Ane, QuantSpec::Fp16),
                spec(1, LayerPlacement::Gpu, QuantSpec::Int8),
                spec(2, LayerPlacement::Cpu, QuantSpec::Int4),
            ],
        };
        assert_eq!(r.placement_counts().total(), r.layers.len());
        assert_eq!(r.quant_counts().total(), r.layers.len());
    }
}
