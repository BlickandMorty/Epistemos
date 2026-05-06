//! HELIOS V6.1 — Five load-bearing M2 Max kernels (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-M2-MAX-KERNELS guard
//!
//! Per `Epistemos V6_1 — Final Synthesis Lock` PART 7 — V6.1
//! commits to the FIVE kernels the synthesis identified as
//! load-bearing on M2 Max. The kernel taxonomy is plane-aligned:
//!
//! | Kernel                          | Plane      |
//! |---------------------------------|------------|
//! | SemiseparableBlockScan.metal    | State      |
//! | LocalRecallIsland.metal         | Episodic   |
//! | PageGather.metal                | Episodic   |
//! | ControllerKernelPack.metal      | Controller |
//! | PacketRouter1bit.metal          | Assembly   |
//!
//! Plus a 6th always-on kernel — `InterruptScore.metal` — that
//! computes u_t before every step. Its compute budget is in the
//! noise; its decisions determine everything.
//!
//! The five-kernel discipline is itself a constraint: kernels not
//! in this list (e.g. active-rank-one execution, model-surgery,
//! Connectome Distillation) live in Vault and are gated behind
//! separate build flags. The W40 lane-classifier enforces this at
//! CI time: any [VAULT-ONLY] kernel that links into the MAS target
//! fails the build.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY substrate. Building requires `--features
//! research`. The kernels themselves ship in MAS via the standard
//! Metal pipeline.

use serde::{Deserialize, Serialize};

use crate::five_planes::RuntimePlane;

/// One of the five load-bearing M2 Max kernels per V6.1 §7.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LoadBearingKernel {
    /// State plane: semiseparable block scan (Mamba-2 SSD framework
    /// per Theorem 3.7). NEVER scalar token loops — that's the
    /// benchmark trap on Apple Silicon.
    SemiseparableBlockScan,
    /// Episodic plane: small-window exact attention over recent +
    /// pinned-page tokens.
    LocalRecallIsland,
    /// Episodic plane: page-local sparse gather, prefetch-aware,
    /// cache-resident.
    PageGather,
    /// Controller plane: 6 fused micro-kernels (write/forget/admit/
    /// route/norm/safety).
    ControllerKernelPack,
    /// Assembly plane: ternary routing (fire/suppress/defer);
    /// quantized scores. The natural home for the 1-bit/1.58-bit
    /// path per V6.1 sharpening point 5.
    PacketRouter1bit,
}

impl LoadBearingKernel {
    /// Metal kernel filename per the V6.1 §7 table.
    pub fn filename(self) -> &'static str {
        match self {
            LoadBearingKernel::SemiseparableBlockScan => "SemiseparableBlockScan.metal",
            LoadBearingKernel::LocalRecallIsland => "LocalRecallIsland.metal",
            LoadBearingKernel::PageGather => "PageGather.metal",
            LoadBearingKernel::ControllerKernelPack => "ControllerKernelPack.metal",
            LoadBearingKernel::PacketRouter1bit => "PacketRouter1bit.metal",
        }
    }

    /// Plane this kernel implements per V6.1 §3 + §7.
    pub fn plane(self) -> RuntimePlane {
        match self {
            LoadBearingKernel::SemiseparableBlockScan => RuntimePlane::State,
            LoadBearingKernel::LocalRecallIsland | LoadBearingKernel::PageGather => {
                RuntimePlane::Episodic
            }
            LoadBearingKernel::ControllerKernelPack => RuntimePlane::Controller,
            LoadBearingKernel::PacketRouter1bit => RuntimePlane::Assembly,
        }
    }

    /// Bit-exact correctness falsifier per V6.1 §7. Returns the
    /// canonical bit-exact reference target.
    pub fn falsifier_target(self) -> &'static str {
        match self {
            LoadBearingKernel::SemiseparableBlockScan => {
                "bit-exact match to cartesia-metal reference within 1e-5"
            }
            LoadBearingKernel::LocalRecallIsland => {
                "passkey recall ≥ 0.99 at 128K (Samba-style)"
            }
            LoadBearingKernel::PageGather => {
                "gather-bound benchmarks: ≥ 70% memory bandwidth utilization"
            }
            LoadBearingKernel::ControllerKernelPack => {
                "bit-exact equivalence to baseline controller within 1 ULP"
            }
            LoadBearingKernel::PacketRouter1bit => {
                "routing-quality loss ≤ 2% vs FP16 reference"
            }
        }
    }
}

/// All five load-bearing kernels in canonical V6.1 §7 order.
pub const FIVE_LOAD_BEARING_KERNELS: [LoadBearingKernel; 5] = [
    LoadBearingKernel::SemiseparableBlockScan,
    LoadBearingKernel::LocalRecallIsland,
    LoadBearingKernel::PageGather,
    LoadBearingKernel::ControllerKernelPack,
    LoadBearingKernel::PacketRouter1bit,
];

/// Canonical filename of the 6th always-on kernel per V6.1 §7:
/// "InterruptScore.metal — computes u_t from the five components.
/// It is small, fast, always-on, and runs *before* every step."
pub const INTERRUPT_SCORE_KERNEL_FILENAME: &str = "InterruptScore.metal";

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn five_kernels_in_canonical_v6_1_order() {
        assert_eq!(FIVE_LOAD_BEARING_KERNELS.len(), 5);
        assert_eq!(
            FIVE_LOAD_BEARING_KERNELS[0],
            LoadBearingKernel::SemiseparableBlockScan
        );
        assert_eq!(
            FIVE_LOAD_BEARING_KERNELS[4],
            LoadBearingKernel::PacketRouter1bit
        );
    }

    #[test]
    fn five_kernels_are_distinct() {
        let set: std::collections::HashSet<LoadBearingKernel> =
            FIVE_LOAD_BEARING_KERNELS.iter().copied().collect();
        assert_eq!(set.len(), 5);
    }

    #[test]
    fn filenames_are_canonical_metal_files() {
        for k in FIVE_LOAD_BEARING_KERNELS {
            let name = k.filename();
            assert!(name.ends_with(".metal"), "kernel filename must end .metal");
        }
    }

    #[test]
    fn filenames_are_distinct() {
        let names: std::collections::HashSet<&'static str> =
            FIVE_LOAD_BEARING_KERNELS.iter().map(|k| k.filename()).collect();
        assert_eq!(names.len(), 5);
    }

    #[test]
    fn state_plane_kernel_is_semiseparable_block_scan() {
        // Per V6.1 §3 + §7: State plane = SemiseparableBlockScan.
        assert_eq!(
            LoadBearingKernel::SemiseparableBlockScan.plane(),
            RuntimePlane::State
        );
        assert_eq!(
            LoadBearingKernel::SemiseparableBlockScan.filename(),
            "SemiseparableBlockScan.metal"
        );
    }

    #[test]
    fn episodic_plane_has_two_kernels() {
        // V6.1: LocalRecallIsland + PageGather both map to Episodic.
        let count = FIVE_LOAD_BEARING_KERNELS
            .iter()
            .filter(|k| k.plane() == RuntimePlane::Episodic)
            .count();
        assert_eq!(count, 2);
    }

    #[test]
    fn assembly_plane_kernel_is_packet_router_1bit() {
        // Per V6.1 sharpening point 5: ternary lives in Assembly plane.
        assert_eq!(
            LoadBearingKernel::PacketRouter1bit.plane(),
            RuntimePlane::Assembly
        );
    }

    #[test]
    fn controller_plane_kernel_is_controller_pack() {
        assert_eq!(
            LoadBearingKernel::ControllerKernelPack.plane(),
            RuntimePlane::Controller
        );
    }

    #[test]
    fn no_load_bearing_kernel_in_verification_plane() {
        // Verification plane has no GPU kernel; it lives in audit
        // substrate.
        for k in FIVE_LOAD_BEARING_KERNELS {
            assert_ne!(k.plane(), RuntimePlane::Verification);
        }
    }

    #[test]
    fn semiseparable_falsifier_references_cartesia_metal() {
        // V6.1 §7: bit-exact match to `cartesia-metal` reference.
        let target = LoadBearingKernel::SemiseparableBlockScan.falsifier_target();
        assert!(target.contains("cartesia-metal"));
    }

    #[test]
    fn local_recall_falsifier_references_passkey_recall() {
        let target = LoadBearingKernel::LocalRecallIsland.falsifier_target();
        assert!(target.contains("passkey recall"));
    }

    #[test]
    fn interrupt_score_kernel_is_separate_from_load_bearing_five() {
        // The 6th always-on kernel sits OUTSIDE the load-bearing
        // five but is still canonical per V6.1 §7.
        assert_eq!(INTERRUPT_SCORE_KERNEL_FILENAME, "InterruptScore.metal");
    }

    #[test]
    fn load_bearing_kernel_serializes_in_snake_case() {
        for (k, expected) in [
            (
                LoadBearingKernel::SemiseparableBlockScan,
                "\"semiseparable_block_scan\"",
            ),
            (LoadBearingKernel::LocalRecallIsland, "\"local_recall_island\""),
            (LoadBearingKernel::PageGather, "\"page_gather\""),
            (
                LoadBearingKernel::ControllerKernelPack,
                "\"controller_kernel_pack\"",
            ),
            (LoadBearingKernel::PacketRouter1bit, "\"packet_router1bit\""),
        ] {
            assert_eq!(serde_json::to_string(&k).unwrap(), expected);
        }
    }

    #[test]
    fn round_trip_through_json() {
        for k in FIVE_LOAD_BEARING_KERNELS {
            let json = serde_json::to_string(&k).unwrap();
            let parsed: LoadBearingKernel = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, k);
        }
    }
}
