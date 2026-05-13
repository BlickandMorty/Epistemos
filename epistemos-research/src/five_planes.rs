//! HELIOS V6.1 — Five-Plane runtime formalism (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-FIVE-PLANES guard
//!
//! Per `Epistemos V6_1 — Final Synthesis Lock` PART 3:
//!
//! > "Tri-stream is the *product* organization (MAS / Pro / Vault).
//! >  Five planes is the *runtime* organization. They are
//! >  orthogonal: every stream contains the same five planes, with
//! >  different surface-area exposed."
//!
//! The five planes per V6.1 §3:
//!
//! - **Plane 1 — State** (recurrent semantic spine; Mamba-2 / Granite-4-H /
//!   Falcon-Mamba). Semiseparable block scan.
//! - **Plane 2 — Episodic** (exact recall pages: Atlas, tool traces,
//!   pinned quotes, claim ledgers, theorem witnesses, file-line anchors).
//! - **Plane 3 — Assembly** (runtime routing language: Gate3, cortical
//!   packets, Connectome anchors). Symbolic-then-learned.
//! - **Plane 4 — Controller** (small high-leverage executive surfaces:
//!   write/forget/admit/route/norm/safety gates).
//! - **Plane 5 — Verification** (audit substrate: WBO, ClaimKind,
//!   AnswerPacket, VRM labels, sheaf-residual, witness logs).
//!
//! Every plane has a plane-specific kernel and plane-specific theorem.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// One of five canonical V6.1 runtime planes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RuntimePlane {
    /// Plane 1 — recurrent semantic spine (Mamba-2 / Granite-4-H /
    /// Falcon-Mamba). Default cost; carries semantic continuity.
    State,
    /// Plane 2 — exact recall pages (Atlas / tool traces / pinned
    /// quotes / claim ledgers / theorem witnesses / file-line anchors).
    Episodic,
    /// Plane 3 — runtime routing language (Gate3 / cortical packets /
    /// Connectome anchors). Symbolic-then-learned routing.
    Assembly,
    /// Plane 4 — executive surfaces (write/forget/admit/route/norm/
    /// safety gates; speculative-accept; kernel-promotion).
    Controller,
    /// Plane 5 — audit substrate (WBO / ClaimKind / AnswerPacket /
    /// VRM / sheaf-residual / witness logs / replay verifiers).
    Verification,
}

impl RuntimePlane {
    /// Plane number (1..5) per V6.1 §3 numbering.
    pub fn plane_number(self) -> u32 {
        match self {
            RuntimePlane::State => 1,
            RuntimePlane::Episodic => 2,
            RuntimePlane::Assembly => 3,
            RuntimePlane::Controller => 4,
            RuntimePlane::Verification => 5,
        }
    }

    /// Plane-specific Metal kernel filename per V6.1 §7
    /// "The Five Kernels That Matter".
    pub fn kernel_filename(self) -> &'static str {
        match self {
            RuntimePlane::State => "SemiseparableBlockScan.metal",
            // The Episodic plane carries TWO kernels (LocalRecallIsland +
            // PageGather); we surface the primary one here. PageGather
            // is the secondary; consumers should track both.
            RuntimePlane::Episodic => "LocalRecallIsland.metal",
            RuntimePlane::Assembly => "PacketRouter1bit.metal",
            RuntimePlane::Controller => "ControllerKernelPack.metal",
            // Verification plane has no GPU kernel — it lives in the
            // doctrine substrate (theorems, AnswerPacket, etc.).
            RuntimePlane::Verification => "(audit substrate; no Metal kernel)",
        }
    }

    /// True when this plane requires GPU-accelerated kernels.
    /// Verification plane is the only doctrine-only plane (no
    /// Metal kernel).
    pub fn requires_gpu_kernel(self) -> bool {
        !matches!(self, RuntimePlane::Verification)
    }

    /// True when this plane is the natural home for the ternary
    /// (1-bit / 1.58-bit) compute path per V6.1 sharpening point 5.
    /// Per V6.1: "Routing decisions, page-admission, kernel-promotion,
    /// safety vetoes, and tool gating are *naturally* ternary
    /// (fire / suppress / defer). The semantic spine stays denser."
    pub fn natural_ternary_home(self) -> bool {
        // Routing (Assembly) and gates (Controller) are naturally
        // ternary. State remains denser. Episodic + Verification
        // are not ternary natively.
        matches!(self, RuntimePlane::Assembly | RuntimePlane::Controller)
    }
}

/// All five runtime planes in canonical V6.1 §3 order.
pub const FIVE_PLANES: [RuntimePlane; 5] = [
    RuntimePlane::State,
    RuntimePlane::Episodic,
    RuntimePlane::Assembly,
    RuntimePlane::Controller,
    RuntimePlane::Verification,
];

/// Three product-tier streams per V6.1 — every stream contains
/// all five planes, with different surface areas exposed.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProductStream {
    Mas,
    Pro,
    Vault,
}

/// All three product streams in canonical order.
pub const THREE_STREAMS: [ProductStream; 3] = [
    ProductStream::Mas,
    ProductStream::Pro,
    ProductStream::Vault,
];

// ── Provenance ledger plane placement ──────────────────────────────────────
//
// The active app's `agent_core::provenance::ClaimLedger` stores exact,
// addressable claim + evidence records — that's the Episodic plane storage
// substrate. Replay-bundle export (`ReplayBundle`, `LedgerSnapshot`,
// `epistemos-trace` verify) lives in the Verification plane substrate (the
// audit surface that runs WBO / ClaimKind / replay verifiers). This mirrors
// the `acs.rs` pattern (ACS_CANONICAL_PLANE = Episodic, ACS_AUDIT_PLANE =
// Verification) and is the canonical placement per V6.1 §3 +
// v6_1_stream_surface.rs (which explicitly tags the provenance ledger as
// living below the Verification plane).

/// Plane where the live provenance ledger lives. Episodic stores exact
/// addressable claim/evidence records; the active-app analog is
/// `agent_core::provenance::ClaimLedger`.
pub const PROVENANCE_STORAGE_PLANE: RuntimePlane = RuntimePlane::Episodic;

/// Plane that audits the ledger (replay bundle export, retraction
/// propagation reports, doctrine lint). Active-app analog is
/// `agent_core::provenance::replay::ReplayBundle` + the
/// `epistemos_trace verify | verify-replay` CLI.
pub const PROVENANCE_AUDIT_PLANE: RuntimePlane = RuntimePlane::Verification;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn five_planes_in_canonical_v6_1_order() {
        assert_eq!(FIVE_PLANES.len(), 5);
        assert_eq!(FIVE_PLANES[0], RuntimePlane::State);
        assert_eq!(FIVE_PLANES[4], RuntimePlane::Verification);
    }

    #[test]
    fn five_planes_are_distinct() {
        let set: std::collections::HashSet<RuntimePlane> = FIVE_PLANES.iter().copied().collect();
        assert_eq!(set.len(), 5);
    }

    #[test]
    fn plane_numbers_match_canonical_index() {
        for (i, plane) in FIVE_PLANES.iter().enumerate() {
            assert_eq!(plane.plane_number(), (i + 1) as u32);
        }
    }

    #[test]
    fn verification_plane_is_only_doctrine_only_plane() {
        for plane in FIVE_PLANES {
            if plane == RuntimePlane::Verification {
                assert!(!plane.requires_gpu_kernel());
            } else {
                assert!(plane.requires_gpu_kernel());
            }
        }
    }

    #[test]
    fn assembly_and_controller_are_ternary_homes() {
        // Per V6.1 sharpening point 5: ternary lives in routing +
        // gates, NOT in the semantic spine.
        assert!(RuntimePlane::Assembly.natural_ternary_home());
        assert!(RuntimePlane::Controller.natural_ternary_home());
        // State, Episodic, Verification are NOT natural ternary homes.
        assert!(!RuntimePlane::State.natural_ternary_home());
        assert!(!RuntimePlane::Episodic.natural_ternary_home());
        assert!(!RuntimePlane::Verification.natural_ternary_home());
    }

    #[test]
    fn state_plane_kernel_is_semiseparable_block_scan() {
        // V6.1 §7: SemiseparableBlockScan.metal is the State plane
        // kernel. NEVER scalar token loops — that's the benchmark
        // trap on Apple Silicon.
        assert_eq!(
            RuntimePlane::State.kernel_filename(),
            "SemiseparableBlockScan.metal"
        );
    }

    #[test]
    fn assembly_plane_kernel_is_packet_router_1bit() {
        // V6.1: ternary path lives in Assembly plane.
        assert_eq!(
            RuntimePlane::Assembly.kernel_filename(),
            "PacketRouter1bit.metal"
        );
    }

    #[test]
    fn three_streams_are_distinct() {
        let set: std::collections::HashSet<ProductStream> =
            THREE_STREAMS.iter().copied().collect();
        assert_eq!(set.len(), 3);
    }

    /// Doctrine ↔ active-app `agent_core::provenance` plane alignment.
    ///
    /// `ClaimLedger` (storage of exact addressable claim/evidence records)
    /// lives in the Episodic plane per V6.1 §3. `ReplayBundle` +
    /// `LedgerSnapshot` + the `epistemos_trace verify | verify-replay` CLI
    /// (the audit surface) live in the Verification plane.
    ///
    /// This test locks both placements + an inequality invariant so the two
    /// constants stay on DIFFERENT planes — a single-plane provenance system
    /// would conflate storage and audit and violate V6.1 §3's tri-stream-by-
    /// five-plane orthogonality.
    ///
    /// Drift gate: if `agent_core` ever moves the ledger or the audit surface,
    /// the placement here must change in lockstep with the doctrine cross-
    /// reference comments in `agent_core/src/provenance/ledger.rs` and
    /// `agent_core/src/provenance/replay.rs`.
    #[test]
    fn provenance_storage_in_episodic_audit_in_verification() {
        assert_eq!(PROVENANCE_STORAGE_PLANE, RuntimePlane::Episodic);
        assert_eq!(PROVENANCE_AUDIT_PLANE, RuntimePlane::Verification);

        // Inequality invariant: storage ≠ audit. The two doctrine roles
        // must remain on distinct planes per V6.1 §3.
        assert_ne!(PROVENANCE_STORAGE_PLANE, PROVENANCE_AUDIT_PLANE);

        // The provenance storage plane is not the semantic spine
        // (State plane). Claim ledgers are addressable, exact, replayable —
        // explicitly NOT the recurrent semantic continuity carrier.
        assert_ne!(PROVENANCE_STORAGE_PLANE, RuntimePlane::State);

        // The provenance audit plane is doctrine-substrate, no GPU kernel
        // (matches V6.1 §7 — Verification plane has no Metal kernel).
        assert!(!PROVENANCE_AUDIT_PLANE.requires_gpu_kernel());
    }

    #[test]
    fn streams_and_planes_are_orthogonal_axes() {
        // Per V6.1 §3: "Tri-stream is the product organization;
        // five planes is the runtime organization. They are
        // orthogonal: every stream contains the same five planes."
        // This test asserts the cardinalities don't overlap (3 vs 5).
        assert_eq!(THREE_STREAMS.len(), 3);
        assert_eq!(FIVE_PLANES.len(), 5);
    }

    #[test]
    fn runtime_plane_serializes_in_snake_case() {
        for (plane, expected) in [
            (RuntimePlane::State, "\"state\""),
            (RuntimePlane::Episodic, "\"episodic\""),
            (RuntimePlane::Assembly, "\"assembly\""),
            (RuntimePlane::Controller, "\"controller\""),
            (RuntimePlane::Verification, "\"verification\""),
        ] {
            assert_eq!(serde_json::to_string(&plane).unwrap(), expected);
        }
    }

    #[test]
    fn product_stream_serializes_in_snake_case() {
        for (stream, expected) in [
            (ProductStream::Mas, "\"mas\""),
            (ProductStream::Pro, "\"pro\""),
            (ProductStream::Vault, "\"vault\""),
        ] {
            assert_eq!(serde_json::to_string(&stream).unwrap(), expected);
        }
    }

    #[test]
    fn round_trip_through_json() {
        for plane in FIVE_PLANES {
            let json = serde_json::to_string(&plane).unwrap();
            let parsed: RuntimePlane = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, plane);
        }
        for stream in THREE_STREAMS {
            let json = serde_json::to_string(&stream).unwrap();
            let parsed: ProductStream = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, stream);
        }
    }
}
