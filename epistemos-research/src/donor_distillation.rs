//! HELIOS V6.1 — Donor-distillation training ramp (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-DONOR-DISTILLATION guard
//!
//! Per `Epistemos V6_1 — Final Synthesis Lock` PART 5 — V6.1's
//! NEW DEFAULT TRAINING PATH. V6.1 commits: distill from a strong
//! donor.
//!
//! Three canonical published recipes:
//!
//! - **Mamba-in-Llama** (Hu, Cheng, Tu et al.) — convert pretrained
//!   Transformer → hybrid SSM-attention student
//! - **MOHAWK** (Bick, Yang et al.) — mixer / hidden-state / output
//!   matching loss for hybrid-SSM distillation
//! - **HyLo** — up to 32× context extension and >90% KV-cache
//!   reduction
//!
//! ## V6.1 §5 canonical training plan
//!
//! 1. Donor: Qwen3-8B (V5 Verified Floor, semantically preserves the lock)
//! 2. Student: Granite-4.0-H-Micro 3B's 9:1 structure
//! 3. Compute: ~3-5 weeks M2 Max wall-clock for 50B distillation tokens
//! 4. HyLo upcycling pass for 128k context extension
//! 5. HeavySkill LoRA on top (V6 W31 carry-forward)
//! 6. Goodfire VPD extraction on the distilled student (Lane 3)
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.
//! Per V6.1: training pipeline is Vault-tier (training is NOT
//! bundled). Resulting weights are bundled as the V6.1 MAS substrate.

use serde::{Deserialize, Serialize};

/// One of three canonical published donor-distillation recipes per
/// V6.1 §5.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DistillationRecipe {
    /// Mamba-in-Llama (Hu, Cheng, Tu et al.) — pretrained
    /// Transformer → hybrid SSM-attention student.
    MambaInLlama,
    /// MOHAWK (Bick, Yang et al.) — mixer / hidden-state / output
    /// matching loss.
    Mohawk,
    /// HyLo — up to 32× context extension + >90% KV-cache reduction.
    HyLo,
}

impl DistillationRecipe {
    /// Short-form recipe name suitable for telemetry / dashboards.
    pub fn canonical_name(self) -> &'static str {
        match self {
            DistillationRecipe::MambaInLlama => "mamba_in_llama",
            DistillationRecipe::Mohawk => "mohawk",
            DistillationRecipe::HyLo => "hylo",
        }
    }
}

/// One canonical step in the V6.1 §5 six-step training plan.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TrainingPlanStep {
    /// Step 1: Donor selection (Qwen3-8B = V5 Verified Floor).
    DonorSelection,
    /// Step 2: Student architecture (Granite-4-H-Micro 3B 9:1).
    StudentArchitecture,
    /// Step 3: Compute estimate (~3-5 weeks M2 Max).
    ComputeEstimate,
    /// Step 4: HyLo upcycling pass for 128k context extension.
    HyLoUpcycling,
    /// Step 5: HeavySkill LoRA on top (V6 W31 carry-forward).
    HeavySkillLora,
    /// Step 6: Goodfire VPD extraction on distilled student.
    GoodfireVpdExtraction,
}

/// All six training plan steps in canonical V6.1 §5 order.
pub const SIX_TRAINING_STEPS: [TrainingPlanStep; 6] = [
    TrainingPlanStep::DonorSelection,
    TrainingPlanStep::StudentArchitecture,
    TrainingPlanStep::ComputeEstimate,
    TrainingPlanStep::HyLoUpcycling,
    TrainingPlanStep::HeavySkillLora,
    TrainingPlanStep::GoodfireVpdExtraction,
];

/// All three distillation recipes in canonical doctrine order.
pub const THREE_RECIPES: [DistillationRecipe; 3] = [
    DistillationRecipe::MambaInLlama,
    DistillationRecipe::Mohawk,
    DistillationRecipe::HyLo,
];

/// Canonical donor model: Qwen3-8B (V5 Verified Floor anchor).
pub const CANONICAL_DONOR: &str = "Qwen/Qwen3-8B-MLX-4bit";

/// Canonical student architecture target: Granite-4.0-H-Micro 3B
/// per V6.1 §5 Step 2.
pub const CANONICAL_STUDENT: &str = "Granite-4.0-H-Micro-3B (9:1 hybrid)";

/// Canonical fallback if Qwen3 license drift / Granite MLX delay
/// per V6.1 §"CAVEATS — what is still NOT confirmed" #1.
pub const FALLBACK_BUNDLED: &str = "tiiuae/Falcon-Mamba-7B-MLX-4bit";

/// Distillation token budget per V6.1 §5 Step 3 estimate.
pub const DISTILLATION_TOKEN_BUDGET_BILLIONS: u32 = 50;

/// T38 v6.1 falsifier per V6.1 §"PART 4":
/// "Distilled hybrid lift: a pretrained Transformer can be
/// converted to a hybrid recurrent-attention model preserving
/// downstream quality better than from-scratch hybrids at matched
/// conversion budget. Falsifier: donor-distilled student does not
/// outperform from-scratch student on matched compute."
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum T38FalsifierOutcome {
    /// Donor-distilled student outperforms from-scratch student
    /// on matched compute. T38 holds.
    DistilledOutperforms,
    /// Donor-distilled student underperforms or matches from-scratch.
    /// T38 fails — fall back to from-scratch ramp.
    DistilledUnderperforms,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_recipes_in_canonical_order() {
        assert_eq!(THREE_RECIPES.len(), 3);
        assert_eq!(THREE_RECIPES[0], DistillationRecipe::MambaInLlama);
        assert_eq!(THREE_RECIPES[2], DistillationRecipe::HyLo);
    }

    #[test]
    fn three_recipes_are_distinct() {
        let set: std::collections::HashSet<DistillationRecipe> =
            THREE_RECIPES.iter().copied().collect();
        assert_eq!(set.len(), 3);
    }

    #[test]
    fn canonical_donor_is_qwen3_8b_mlx_4bit() {
        // V6.1 §5 Step 1: Qwen3-8B = V5 Verified Floor.
        assert_eq!(CANONICAL_DONOR, "Qwen/Qwen3-8B-MLX-4bit");
    }

    #[test]
    fn canonical_student_is_granite4hmicro() {
        assert_eq!(CANONICAL_STUDENT, "Granite-4.0-H-Micro-3B (9:1 hybrid)");
    }

    #[test]
    fn fallback_bundled_is_falcon_mamba_7b() {
        // V6.1 caveat #1: if Qwen3 / Granite drift, fallback is
        // Falcon-Mamba 7B as bundled MAS substrate.
        assert_eq!(FALLBACK_BUNDLED, "tiiuae/Falcon-Mamba-7B-MLX-4bit");
    }

    #[test]
    fn distillation_token_budget_is_50b() {
        // V6.1 §5 Step 3 estimate.
        assert_eq!(DISTILLATION_TOKEN_BUDGET_BILLIONS, 50);
    }

    #[test]
    fn six_training_steps_in_canonical_order() {
        assert_eq!(SIX_TRAINING_STEPS.len(), 6);
        assert_eq!(SIX_TRAINING_STEPS[0], TrainingPlanStep::DonorSelection);
        assert_eq!(SIX_TRAINING_STEPS[5], TrainingPlanStep::GoodfireVpdExtraction);
    }

    #[test]
    fn six_training_steps_are_distinct() {
        let set: std::collections::HashSet<TrainingPlanStep> =
            SIX_TRAINING_STEPS.iter().copied().collect();
        assert_eq!(set.len(), 6);
    }

    #[test]
    fn canonical_names_match_doctrine() {
        assert_eq!(DistillationRecipe::MambaInLlama.canonical_name(), "mamba_in_llama");
        assert_eq!(DistillationRecipe::Mohawk.canonical_name(), "mohawk");
        assert_eq!(DistillationRecipe::HyLo.canonical_name(), "hylo");
    }

    #[test]
    fn t38_outcomes_are_distinct() {
        assert_ne!(
            T38FalsifierOutcome::DistilledOutperforms,
            T38FalsifierOutcome::DistilledUnderperforms
        );
    }

    #[test]
    fn distillation_recipe_serializes_in_snake_case() {
        for (r, expected) in [
            (DistillationRecipe::MambaInLlama, "\"mamba_in_llama\""),
            (DistillationRecipe::Mohawk, "\"mohawk\""),
            (DistillationRecipe::HyLo, "\"hy_lo\""),
        ] {
            assert_eq!(serde_json::to_string(&r).unwrap(), expected);
        }
    }

    #[test]
    fn training_plan_step_serializes_in_snake_case() {
        for (s, expected) in [
            (TrainingPlanStep::DonorSelection, "\"donor_selection\""),
            (TrainingPlanStep::StudentArchitecture, "\"student_architecture\""),
            (TrainingPlanStep::ComputeEstimate, "\"compute_estimate\""),
            (TrainingPlanStep::HyLoUpcycling, "\"hy_lo_upcycling\""),
            (TrainingPlanStep::HeavySkillLora, "\"heavy_skill_lora\""),
            (TrainingPlanStep::GoodfireVpdExtraction, "\"goodfire_vpd_extraction\""),
        ] {
            assert_eq!(serde_json::to_string(&s).unwrap(), expected);
        }
    }

    #[test]
    fn round_trip_through_json() {
        for r in THREE_RECIPES {
            let json = serde_json::to_string(&r).unwrap();
            let parsed: DistillationRecipe = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, r);
        }
        for s in SIX_TRAINING_STEPS {
            let json = serde_json::to_string(&s).unwrap();
            let parsed: TrainingPlanStep = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, s);
        }
    }
}
