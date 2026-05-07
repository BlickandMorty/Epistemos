//! EPISTEMOS / HELIOS V6.2 — Lean verification canon and M2-Pro
//! hardware falsifier handbook (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-V6_2 guard
//!
//! Source: `docs/fusion/jordan's research/helios v6.2.md`.
//!
//! V6.2 is not a replacement canon. It is a strict V6.1 delta that
//! makes the actual ship rig explicit: Jojo's M2 Pro 14" 2023,
//! 12-core CPU / 19-core GPU, 16GB unified memory, 200 GB/s memory
//! bandwidth. Anything that requires a workstation stays Pro/Vault
//! or research-tier.
//!
//! The V6.2 intake also resolves the previous open research ask:
//! hardware falsifiers must be calibrated to the M2 Pro 16GB rig,
//! not inherited from the M2 Max reference envelope.

use serde::{Deserialize, Serialize};

use crate::hardware_profile::HardwareProfile;
use crate::m2_max_kernels::LoadBearingKernel;

/// Canonical source path for the user-supplied V6.2 addendum.
pub const V6_2_CANON_SOURCE_PATH: &str = "docs/fusion/jordan's research/helios v6.2.md";

/// V6.2 hardware lock: the user's actual shippability rig.
pub const V6_2_HARDWARE_LOCK: HardwareProfile = HardwareProfile::M2Pro16Gb;

/// Apple-published M2 Pro memory bandwidth for the 14" 2023 profile.
pub const M2_PRO_MEMORY_BANDWIDTH_GBPS: u32 = 200;

/// MAS Tier-1 soft resident-memory ceiling per V6.2 Stage 3.
pub const MAS_TIER1_SOFT_CEILING_GB: f32 = 12.0;

/// MAS Tier-1 hard resident-memory ceiling per V6.2 Stage 3.
pub const MAS_TIER1_HARD_CEILING_GB: f32 = 14.0;

/// PageGather scatter/gather target: 70% of the local measured
/// baseline, not 70% of theoretical peak bandwidth.
pub const PAGE_GATHER_BASELINE_RATIO: f32 = 0.70;

/// Foundation refresh sustained-bandwidth band for the M2 Pro baseline
/// harness. This is the STREAM-style baseline itself, not the scatter
/// target.
pub const PAGE_GATHER_BASELINE_SUSTAINED_GBPS_MIN: u32 = 63;
pub const PAGE_GATHER_BASELINE_SUSTAINED_GBPS_MAX: u32 = 73;

/// Reject sub-second PageGather bandwidth numbers; SLC bursts inflate
/// them on Apple Silicon.
pub const PAGE_GATHER_MIN_WINDOW_SECONDS: f32 = 1.0;

/// V6.2 Core/Stretch buffer matrix in MB. 4GB is intentionally absent:
/// it would force swap on a 16GB rig and poison the measurement.
pub const PAGE_GATHER_BUFFER_MB: [u32; 3] = [256, 512, 1024];

/// SemiseparableBlockScan Core lane sequence length.
pub const SEMISEPARABLE_CORE_L: u32 = 32_768;

/// SemiseparableBlockScan Stretch lane sequence length.
pub const SEMISEPARABLE_STRETCH_L: u32 = 131_072;

/// V6.2 canonical correctness chunk size.
pub const SEMISEPARABLE_CANONICAL_CHUNK_SIZE: u32 = 256;

/// V6.2 performance-candidate chunk size.
pub const SEMISEPARABLE_PERF_CANDIDATE_CHUNK_SIZE: u32 = 128;

/// V6.2 source-file correction: Mamba-2 ngroups must be 1.
pub const SEMISEPARABLE_NGROUPS: u32 = 1;

/// V6.2 Core LocalRecallIsland context.
pub const LOCAL_RECALL_CORE_CONTEXT_K: u32 = 32;

/// V6.2 Stretch LocalRecallIsland context.
pub const LOCAL_RECALL_STRETCH_CONTEXT_K: u32 = 128;

/// V6.2 Core LocalRecallIsland trial count and depth count.
pub const LOCAL_RECALL_CORE_TRIALS: u32 = 50;
pub const LOCAL_RECALL_CORE_DEPTHS: u32 = 5;

/// Core lane passkey and niah_single_1 target.
pub const LOCAL_RECALL_CORE_PASS_THRESHOLD: f32 = 0.95;

/// PacketRouter1bit V6.2 dispatch P99 target in microseconds.
pub const PACKET_ROUTER_P99_US_MAX: u32 = 100;

/// InterruptScore V6.2 P99 target in microseconds.
pub const INTERRUPT_SCORE_P99_US_MAX: u32 = 100;

/// Minimum token batch before the Metal shadow path is worth trying
/// for InterruptScore. The canonical implementation is Swift CPU.
pub const INTERRUPT_SCORE_METAL_SHADOW_MIN_BATCH: u32 = 64;

/// Goodfire VPD public-page revalidation status from this Codex
/// intake. V6.2's source doc was cautious about the 9972 / 205 /
/// 2.1% subnumbers; Codex rechecked the live Goodfire page on
/// intake and found the table with those values present.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GoodfireV6_2Evidence {
    /// Headline numbers public-confirmed: 4 layers, 67M params,
    /// 28M non-embedding params, 38,912 rank-1 subcomponents.
    HeadlinePublicConfirmed,
    /// 9972 alive / 205 active / 2.1% public table revalidated
    /// during Codex intake.
    ActivitySubnumbersRevalidated,
    /// Runtime acceleration still candidate/Vault; public atlas
    /// evidence does not validate Connectome-RAG as substrate.
    RuntimeAccelerationStillCandidate,
}

pub const GOODFIRE_V6_2_EVIDENCE: [GoodfireV6_2Evidence; 3] = [
    GoodfireV6_2Evidence::HeadlinePublicConfirmed,
    GoodfireV6_2Evidence::ActivitySubnumbersRevalidated,
    GoodfireV6_2Evidence::RuntimeAccelerationStillCandidate,
];

/// V6.1 Foundation W1 (`F-ULP-Oracle`) runs before this V6.2
/// kernel-side ladder. The existing order below is therefore W2+,
/// not the first Helios falsifier overall.
pub const V6_2_KERNEL_LADDER_IS_AFTER_F_ULP_ORACLE: bool = true;

/// Canonical implementation posture for InterruptScore in V6.2.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum InterruptScoreImplementation {
    /// Single-token expected path: Swift CPU on QoS `.userInteractive`.
    SwiftCpuCanonical,
    /// Batch-amortized path only, for >= 64 tokens.
    MetalShadowBatchOnly,
}

impl InterruptScoreImplementation {
    pub fn is_canonical(self) -> bool {
        matches!(self, InterruptScoreImplementation::SwiftCpuCanonical)
    }
}

/// One V6.2 falsifier in dependency order.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum V6_2Falsifier {
    PageGatherBaseline,
    PageGatherScatter,
    InterruptScoreCpu,
    PacketRouter1bit,
    ControllerKernelPack,
    SemiseparableBlockScan,
    LocalRecallIsland,
    RulerBabilongHarness,
}

impl V6_2Falsifier {
    /// Associated V6.1 kernel target when the falsifier corresponds
    /// to one of the five named kernels.
    pub fn kernel(self) -> Option<LoadBearingKernel> {
        match self {
            V6_2Falsifier::PageGatherBaseline => None,
            V6_2Falsifier::PageGatherScatter => Some(LoadBearingKernel::PageGather),
            V6_2Falsifier::InterruptScoreCpu => None,
            V6_2Falsifier::PacketRouter1bit => Some(LoadBearingKernel::PacketRouter1bit),
            V6_2Falsifier::ControllerKernelPack => Some(LoadBearingKernel::ControllerKernelPack),
            V6_2Falsifier::SemiseparableBlockScan => {
                Some(LoadBearingKernel::SemiseparableBlockScan)
            }
            V6_2Falsifier::LocalRecallIsland => Some(LoadBearingKernel::LocalRecallIsland),
            V6_2Falsifier::RulerBabilongHarness => None,
        }
    }

    pub fn is_core_lane(self) -> bool {
        matches!(
            self,
            V6_2Falsifier::PageGatherBaseline
                | V6_2Falsifier::PageGatherScatter
                | V6_2Falsifier::InterruptScoreCpu
                | V6_2Falsifier::PacketRouter1bit
                | V6_2Falsifier::ControllerKernelPack
                | V6_2Falsifier::SemiseparableBlockScan
                | V6_2Falsifier::LocalRecallIsland
        )
    }
}

/// Dependency-true falsifier order per V6.2 recommendations.
pub const V6_2_FALSIFIER_ORDER: [V6_2Falsifier; 8] = [
    V6_2Falsifier::PageGatherBaseline,
    V6_2Falsifier::PageGatherScatter,
    V6_2Falsifier::InterruptScoreCpu,
    V6_2Falsifier::PacketRouter1bit,
    V6_2Falsifier::ControllerKernelPack,
    V6_2Falsifier::SemiseparableBlockScan,
    V6_2Falsifier::LocalRecallIsland,
    V6_2Falsifier::RulerBabilongHarness,
];

/// Dependency-gated V6.2 stages; no calendar commitments.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum V6_2Stage {
    LeanScaffolding,
    HardwareFalsifiers,
    LeanIntegration,
    Migration,
}

pub const V6_2_STAGE_ORDER: [V6_2Stage; 4] = [
    V6_2Stage::LeanScaffolding,
    V6_2Stage::HardwareFalsifiers,
    V6_2Stage::LeanIntegration,
    V6_2Stage::Migration,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hardware_lock_is_m2_pro_16gb() {
        assert_eq!(V6_2_HARDWARE_LOCK, HardwareProfile::M2Pro16Gb);
        assert_eq!(V6_2_HARDWARE_LOCK.unified_memory_gb(), 16);
        assert_eq!(M2_PRO_MEMORY_BANDWIDTH_GBPS, 200);
    }

    #[test]
    fn mas_residency_ceiling_fits_16gb_machine() {
        assert!(MAS_TIER1_SOFT_CEILING_GB < MAS_TIER1_HARD_CEILING_GB);
        assert!(MAS_TIER1_HARD_CEILING_GB < V6_2_HARDWARE_LOCK.unified_memory_gb() as f32);
    }

    #[test]
    fn page_gather_uses_measured_baseline_not_theoretical_bandwidth() {
        assert!((PAGE_GATHER_BASELINE_RATIO - 0.70).abs() < f32::EPSILON);
        assert_eq!(PAGE_GATHER_BASELINE_SUSTAINED_GBPS_MIN, 63);
        assert_eq!(PAGE_GATHER_BASELINE_SUSTAINED_GBPS_MAX, 73);
        assert!(
            (PAGE_GATHER_BASELINE_SUSTAINED_GBPS_MAX as f32)
                / (M2_PRO_MEMORY_BANDWIDTH_GBPS as f32)
                < 0.40
        );
        assert_eq!(PAGE_GATHER_MIN_WINDOW_SECONDS, 1.0);
        assert_eq!(PAGE_GATHER_BUFFER_MB, [256, 512, 1024]);
        assert!(!PAGE_GATHER_BUFFER_MB.contains(&4096));
    }

    #[test]
    fn semiseparable_v6_2_core_is_32k_and_stretch_is_128k() {
        assert_eq!(SEMISEPARABLE_CORE_L, 32_768);
        assert_eq!(SEMISEPARABLE_STRETCH_L, 131_072);
        assert_eq!(SEMISEPARABLE_CANONICAL_CHUNK_SIZE, 256);
        assert_eq!(SEMISEPARABLE_PERF_CANDIDATE_CHUNK_SIZE, 128);
        assert_eq!(SEMISEPARABLE_NGROUPS, 1);
    }

    #[test]
    fn local_recall_core_lane_is_budget_revised() {
        assert_eq!(LOCAL_RECALL_CORE_CONTEXT_K, 32);
        assert_eq!(LOCAL_RECALL_STRETCH_CONTEXT_K, 128);
        assert_eq!(LOCAL_RECALL_CORE_TRIALS * LOCAL_RECALL_CORE_DEPTHS, 250);
        assert_eq!(LOCAL_RECALL_CORE_PASS_THRESHOLD, 0.95);
    }

    #[test]
    fn interrupt_score_is_cpu_canonical_with_metal_shadow_only_for_batches() {
        assert!(InterruptScoreImplementation::SwiftCpuCanonical.is_canonical());
        assert!(!InterruptScoreImplementation::MetalShadowBatchOnly.is_canonical());
        assert_eq!(INTERRUPT_SCORE_METAL_SHADOW_MIN_BATCH, 64);
        assert_eq!(INTERRUPT_SCORE_P99_US_MAX, 100);
    }

    #[test]
    fn goodfire_activity_subnumbers_are_revalidated_but_runtime_stays_candidate() {
        assert_eq!(GOODFIRE_V6_2_EVIDENCE.len(), 3);
        assert!(GOODFIRE_V6_2_EVIDENCE
            .contains(&GoodfireV6_2Evidence::ActivitySubnumbersRevalidated));
        assert!(GOODFIRE_V6_2_EVIDENCE
            .contains(&GoodfireV6_2Evidence::RuntimeAccelerationStillCandidate));
    }

    #[test]
    fn falsifier_order_starts_with_bandwidth_calibration() {
        assert!(V6_2_KERNEL_LADDER_IS_AFTER_F_ULP_ORACLE);
        assert_eq!(V6_2_FALSIFIER_ORDER[0], V6_2Falsifier::PageGatherBaseline);
        assert_eq!(V6_2_FALSIFIER_ORDER[1], V6_2Falsifier::PageGatherScatter);
        assert_eq!(V6_2_FALSIFIER_ORDER[2], V6_2Falsifier::InterruptScoreCpu);
    }

    #[test]
    fn v6_2_core_falsifiers_cover_all_five_named_kernels() {
        let kernels: std::collections::HashSet<LoadBearingKernel> = V6_2_FALSIFIER_ORDER
            .iter()
            .filter(|f| f.is_core_lane())
            .filter_map(|f| f.kernel())
            .collect();
        assert!(kernels.contains(&LoadBearingKernel::PageGather));
        assert!(kernels.contains(&LoadBearingKernel::PacketRouter1bit));
        assert!(kernels.contains(&LoadBearingKernel::ControllerKernelPack));
        assert!(kernels.contains(&LoadBearingKernel::SemiseparableBlockScan));
        assert!(kernels.contains(&LoadBearingKernel::LocalRecallIsland));
    }

    #[test]
    fn stage_order_is_dependency_order_not_calendar_order() {
        assert_eq!(V6_2_STAGE_ORDER.len(), 4);
        assert_eq!(V6_2_STAGE_ORDER[0], V6_2Stage::LeanScaffolding);
        assert_eq!(V6_2_STAGE_ORDER[3], V6_2Stage::Migration);
    }
}
