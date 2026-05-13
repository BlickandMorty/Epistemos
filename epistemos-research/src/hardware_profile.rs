//! HELIOS V6.1 — Apple Silicon hardware profile substrate
//! (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-HARDWARE-PROFILE guard
//!
//! Per `Epistemos V6.1 Final Synthesis Lock` PART 7 (M2 Max
//! kernels) + user-confirmed hardware (2026-05-06): "i have a
//! m2 pro not max with 16gb of ram."
//!
//! V6.1's canonical performance targets reference an M2 Max
//! 64GB profile. V6.2 sharpens the ship doctrine: the user's
//! actual deployment hardware is M2 Pro 16GB, and if a feature
//! cannot pass there it remains Pro/Vault/research-tier. This
//! module captures BOTH so V6.1 reference thresholds remain
//! legible while V6.2 shippability is bounded by the user's rig.
//!
//! ## Memory budgets per profile
//!
//! M2 Pro 16GB realistic budget per
//! `~/.claude/.../user_hardware.md`:
//!   "16GB unified memory ceiling; realistic budget ~10-11GB
//!    for weights+KV; 4-bit 7-8B is the sweet spot."
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY substrate. Building requires `--features
//! research`. Hardware capability gating happens at runtime via
//! the kernel pipeline; this module documents canonical bounds.

use serde::{Deserialize, Serialize};

/// One canonical Apple Silicon profile.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HardwareProfile {
    /// M2 Pro 16GB — V6.2 canonical user ship target as of 2026-05-06
    /// directive. Realistic budget: ~10-11GB for weights+KV.
    M2Pro16Gb,
    /// M2 Pro 18GB — user's actual deployment rig per runtime
    /// hardware-tier detection 2026-05-12 ("Hardware tier: pro-18GB,
    /// dual budget: 10800MB"). Same chip family as M2Pro16Gb but
    /// the 2GB extra capacity gives a marginally bigger budget. The
    /// `Epistemos/Omega/Inference/HardwareTierManager.swift` `pro18`
    /// tier maps onto this profile.
    M2Pro18Gb,
    /// M2 Max 64GB — V6.1's canonical performance target
    /// (e.g. PEAK_RAM_GB_MAX = 12.0 references this profile).
    M2Max64Gb,
    /// M3 Max 36GB — referenced in V5/V6 hardware-correction
    /// patches per epistemos_helios_v3_master_canon_v2_1 §A2.
    M3Max36Gb,
    /// M3 Ultra 256GB — Omega tier per V5/V6 hardware notes.
    M3Ultra256Gb,
}

impl HardwareProfile {
    /// Total unified-memory capacity in gigabytes.
    pub fn unified_memory_gb(self) -> u32 {
        match self {
            HardwareProfile::M2Pro16Gb => 16,
            HardwareProfile::M2Pro18Gb => 18,
            HardwareProfile::M2Max64Gb => 64,
            HardwareProfile::M3Max36Gb => 36,
            HardwareProfile::M3Ultra256Gb => 256,
        }
    }

    /// Realistic resident budget in gigabytes (system overhead +
    /// app shell + headroom subtracted). For M2 Pro 16GB this is
    /// the ~10-11GB sweet spot per user_hardware.md.
    pub fn realistic_resident_budget_gb(self) -> f32 {
        match self {
            HardwareProfile::M2Pro16Gb => 10.5,    // 10-11GB sweet spot
            HardwareProfile::M2Pro18Gb => 10.8,    // Swift HardwareTierManager: 18 * 0.60 = 10.8
            HardwareProfile::M2Max64Gb => 12.0,    // V6.1 canonical PEAK_RAM_GB_MAX
            HardwareProfile::M3Max36Gb => 24.0,    // ~2/3 of total (substantial app overhead)
            HardwareProfile::M3Ultra256Gb => 192.0, // 75% of total
        }
    }

    /// Sweet-spot model size in billions of parameters at 4-bit
    /// quantization. Smaller hardware → smaller model.
    pub fn sweet_spot_model_b(self) -> f32 {
        match self {
            HardwareProfile::M2Pro16Gb => 7.0,     // 4-bit 7-8B sweet spot
            HardwareProfile::M2Pro18Gb => 8.0,     // Marginally bigger headroom than 16GB
            HardwareProfile::M2Max64Gb => 13.0,    // larger headroom
            HardwareProfile::M3Max36Gb => 8.0,     // Qwen3-8B fits comfortably
            HardwareProfile::M3Ultra256Gb => 70.0, // Hermes-4 70B class
        }
    }

    /// Maximum practical context window in tokens at the sweet-spot
    /// model size and 4-bit quantization. Tighter on smaller
    /// hardware due to KV-cache dominance.
    pub fn max_practical_context_k(self) -> u32 {
        match self {
            HardwareProfile::M2Pro16Gb => 32,      // 32k tight; 128k requires KV-Direct
            HardwareProfile::M2Pro18Gb => 32,      // Same chip family, similar tight ceiling
            HardwareProfile::M2Max64Gb => 128,     // V6.1 canonical 128k target
            HardwareProfile::M3Max36Gb => 64,      // 64k comfortable
            HardwareProfile::M3Ultra256Gb => 1000, // 1M context per V6.1
        }
    }

    /// True when this profile is the user's actual deployment
    /// target. As of 2026-05-12 runtime detection, the user is on
    /// M2 Pro 18GB (not 16GB as previously believed). Both profiles
    /// represent valid M2 Pro ship targets — `M2Pro16Gb` is the
    /// canonical V6.2 ship doctrine entry; `M2Pro18Gb` is the
    /// observed runtime variant.
    pub fn is_actual_user_target(self) -> bool {
        matches!(self, HardwareProfile::M2Pro16Gb | HardwareProfile::M2Pro18Gb)
    }
}

/// All four canonical Apple Silicon profiles in canonical order
/// (smallest to largest). Kept as `FOUR_PROFILES` for backward
/// compatibility — `M2Pro18Gb` is documented in `FIVE_PROFILES`
/// without disturbing existing callers of `FOUR_PROFILES`.
pub const FOUR_PROFILES: [HardwareProfile; 4] = [
    HardwareProfile::M2Pro16Gb,
    HardwareProfile::M3Max36Gb,
    HardwareProfile::M2Max64Gb,
    HardwareProfile::M3Ultra256Gb,
];

/// Extended profile list including `M2Pro18Gb` (the observed user
/// runtime variant 2026-05-12). Use this when iterating across all
/// shippable M2 Pro variants.
pub const FIVE_PROFILES: [HardwareProfile; 5] = [
    HardwareProfile::M2Pro16Gb,
    HardwareProfile::M2Pro18Gb,
    HardwareProfile::M3Max36Gb,
    HardwareProfile::M2Max64Gb,
    HardwareProfile::M3Ultra256Gb,
];

/// User's confirmed actual hardware target per the 2026-05-06
/// directive: "i have a m2 pro not max with 16gb of ram." This
/// is the ship-target profile; V6.1 canonical M2 Max 64GB is
/// the reference profile the bounds were calibrated against.
pub const USER_ACTUAL_TARGET: HardwareProfile = HardwareProfile::M2Pro16Gb;

/// V6.1 canonical reference profile per PART 7. The PEAK_RAM_GB_MAX
/// = 12.0 threshold in validation_thresholds.rs is calibrated for
/// this profile.
pub const V6_1_CANONICAL_REFERENCE: HardwareProfile = HardwareProfile::M2Max64Gb;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn four_profiles_are_distinct() {
        let set: std::collections::HashSet<HardwareProfile> =
            FOUR_PROFILES.iter().copied().collect();
        assert_eq!(set.len(), 4);
    }

    #[test]
    fn user_actual_target_is_m2_pro_16gb() {
        // Per user message 2026-05-06: "i have a m2 pro not max
        // with 16gb of ram."
        assert_eq!(USER_ACTUAL_TARGET, HardwareProfile::M2Pro16Gb);
        assert!(USER_ACTUAL_TARGET.is_actual_user_target());
    }

    #[test]
    fn v6_1_canonical_reference_is_m2_max_64gb() {
        // V6.1 PART 7 references M2 Max 64GB as the M2 Max kernel
        // benchmark profile.
        assert_eq!(V6_1_CANONICAL_REFERENCE, HardwareProfile::M2Max64Gb);
        assert!(!V6_1_CANONICAL_REFERENCE.is_actual_user_target());
    }

    #[test]
    fn unified_memory_matches_canonical_capacities() {
        assert_eq!(HardwareProfile::M2Pro16Gb.unified_memory_gb(), 16);
        assert_eq!(HardwareProfile::M2Max64Gb.unified_memory_gb(), 64);
        assert_eq!(HardwareProfile::M3Max36Gb.unified_memory_gb(), 36);
        assert_eq!(HardwareProfile::M3Ultra256Gb.unified_memory_gb(), 256);
    }

    #[test]
    fn m2_pro_realistic_budget_matches_user_hardware_memory() {
        // user_hardware.md: "realistic budget ~10-11GB for weights+KV"
        let budget = HardwareProfile::M2Pro16Gb.realistic_resident_budget_gb();
        assert!(budget >= 10.0 && budget <= 11.0);
    }

    #[test]
    fn m2_max_realistic_budget_matches_v6_1_peak_ram_threshold() {
        // V6.1: PEAK_RAM_GB_MAX = 12.0 (per validation_thresholds.rs).
        assert_eq!(HardwareProfile::M2Max64Gb.realistic_resident_budget_gb(), 12.0);
    }

    #[test]
    fn m2_pro_sweet_spot_is_4bit_7_to_8b_per_user_hardware_memory() {
        // user_hardware.md: "4-bit 7-8B is the sweet spot."
        let sweet = HardwareProfile::M2Pro16Gb.sweet_spot_model_b();
        assert!(sweet >= 7.0 && sweet <= 8.0);
    }

    #[test]
    fn unified_memory_grows_monotonically_in_canonical_order() {
        // Per FOUR_PROFILES order (smallest to largest by unified
        // memory). Budgets are NOT strictly monotonic because the
        // M2 Max 64GB profile uses V6.1's conservative PEAK_RAM
        // ceiling (12GB) rather than capacity-fraction.
        let mut last_capacity = 0_u32;
        for profile in FOUR_PROFILES {
            let cap = profile.unified_memory_gb();
            assert!(cap >= last_capacity, "unified-memory order must be monotonic");
            last_capacity = cap;
        }
    }

    #[test]
    fn m2_max_budget_intentionally_conservative_against_capacity() {
        // M2 Max 64GB's budget = 12.0 (the V6.1 threshold from
        // validation_thresholds.rs) is intentionally MUCH smaller
        // than its 64GB capacity. This is a doctrinal conservative
        // ceiling, not a capacity-fraction. The 12GB target
        // applies regardless of how much extra headroom the
        // hardware has.
        let cap = HardwareProfile::M2Max64Gb.unified_memory_gb() as f32;
        let budget = HardwareProfile::M2Max64Gb.realistic_resident_budget_gb();
        assert!(budget < cap, "budget must be ≤ capacity");
        assert!(budget < cap * 0.25, "M2 Max budget is conservative (V6.1 threshold)");
    }

    #[test]
    fn m2_pro_max_context_is_32k_tight() {
        // 16GB tight at long context; KV-Direct needed for 128k.
        assert_eq!(HardwareProfile::M2Pro16Gb.max_practical_context_k(), 32);
    }

    #[test]
    fn m2_max_max_context_is_128k_canonical() {
        assert_eq!(HardwareProfile::M2Max64Gb.max_practical_context_k(), 128);
    }

    #[test]
    fn hardware_profile_serializes_in_snake_case() {
        for (p, expected) in [
            (HardwareProfile::M2Pro16Gb, "\"m2_pro16_gb\""),
            (HardwareProfile::M2Max64Gb, "\"m2_max64_gb\""),
            (HardwareProfile::M3Max36Gb, "\"m3_max36_gb\""),
            (HardwareProfile::M3Ultra256Gb, "\"m3_ultra256_gb\""),
        ] {
            assert_eq!(serde_json::to_string(&p).unwrap(), expected);
        }
    }

    #[test]
    fn hardware_profile_round_trips_through_json() {
        for p in FOUR_PROFILES {
            let json = serde_json::to_string(&p).unwrap();
            let parsed: HardwareProfile = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, p);
        }
    }

    #[test]
    fn m2_pro_18gb_matches_swift_dual_budget() {
        // Swift `HardwareTierManager.computeDualModelBudget` computes
        // `tier.memoryGB * 1_000_000_000 * 0.60`. For pro18:
        //   18 * 1_000_000_000 * 0.60 = 10_800_000_000 = 10.8 GB.
        // The HELIOS `realistic_resident_budget_gb` for M2Pro18Gb is
        // calibrated to match this exact value so doctrine + runtime
        // stay aligned.
        let helios = HardwareProfile::M2Pro18Gb.realistic_resident_budget_gb();
        let swift_dual_budget_gb = 18.0_f32 * 0.60;
        assert!((helios - swift_dual_budget_gb).abs() < 0.01,
            "HELIOS M2Pro18Gb budget ({}) must match Swift dual-budget formula ({}) within 0.01 GB",
            helios, swift_dual_budget_gb);
    }

    #[test]
    fn m2_pro_18gb_is_recognized_user_target() {
        // 2026-05-12 user-trace shows actual hardware is M2 Pro 18GB.
        // is_actual_user_target should accept both 16GB and 18GB M2
        // Pro variants since both represent valid V6.2 ship targets.
        assert!(HardwareProfile::M2Pro18Gb.is_actual_user_target());
        assert!(HardwareProfile::M2Pro16Gb.is_actual_user_target());
        assert!(!HardwareProfile::M2Max64Gb.is_actual_user_target());
    }

    #[test]
    fn five_profiles_are_distinct() {
        let set: std::collections::HashSet<HardwareProfile> =
            FIVE_PROFILES.iter().copied().collect();
        assert_eq!(set.len(), 5);
    }

    #[test]
    fn five_profiles_unified_memory_grows_monotonically() {
        let mut last = 0_u32;
        for profile in FIVE_PROFILES {
            let cap = profile.unified_memory_gb();
            assert!(cap >= last, "unified-memory order monotonic: got {} after {}", cap, last);
            last = cap;
        }
    }

    #[test]
    fn five_profiles_round_trip_through_json() {
        for p in FIVE_PROFILES {
            let json = serde_json::to_string(&p).unwrap();
            let parsed: HardwareProfile = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, p);
        }
    }
}
