//! HELIOS V6.1 — Per-stream plane surface exposure (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-V6-1-STREAM-SURFACE guard
//!
//! Per `Epistemos V6_1 — Final Synthesis Lock` PART 3:
//!
//! > "Tri-stream is the *product* organization (MAS / Pro / Vault).
//! >  Five planes is the *runtime* organization. They are
//! >  orthogonal: every stream contains the same five planes, with
//! >  different surface-area exposed."
//!
//! This module captures the 3 × 5 = 15 cell matrix. Without this
//! substrate, "different surface-area exposed" is rhetoric; with
//! it, every stream-plane pair has a canonical exposure level that
//! can be cross-checked against the per-stream tests.
//!
//! ## Exposure level vocabulary
//!
//! - **Full** — the canonical V6.1 reference surface applies at
//!   this policy layer (e.g. State plane in Pro = configured
//!   Mamba-2 / hybrid choices; Episodic plane in Vault = full Atlas
//!   page set). This is not an implementation-completeness claim.
//! - **Bounded** — capability is exposed but with explicit MAS-class
//!   bounds (e.g. State plane in MAS = Granite-4-H-Micro 3B 9:1; not
//!   arbitrary user-supplied weights).
//! - **Restricted** — capability is gated behind explicit user grant
//!   per-call (e.g. Episodic plane Atlas pages in MAS require
//!   security-scoped bookmark per page-cluster).
//! - **DoctrineOnly** — plane is doctrine substrate only (no GPU
//!   kernel) and is emitted in all three streams (e.g. Verification
//!   plane AnswerPacket, WBO, ClaimKind, sheaf-residual emit in
//!   every stream; replay-bundle export adds a stream-specific
//!   level).
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY substrate. Building requires `--features
//! research`. Real per-stream gating happens at runtime via the MAS
//! capability lattice + Cargo feature taxonomy; this module documents
//! the canonical exposure shape so the lattice + taxonomy stay in
//! sync with V6.1 doctrine.

use serde::{Deserialize, Serialize};

use crate::five_planes::{ProductStream, RuntimePlane};

/// One exposure-policy level for a (stream, plane) cell per V6.1 §3.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StreamSurfaceLevel {
    /// Full V6.1 canonical surface at this policy layer. This does
    /// not mean the current repo has implemented every underlying
    /// kernel or model.
    Full,
    /// Capability exposed but with explicit MAS-class bounds (e.g.
    /// Granite-4-H-Micro 3B for State plane in MAS, not arbitrary
    /// user-supplied weights).
    Bounded,
    /// Capability gated behind explicit per-call user grant (e.g.
    /// Atlas page admission requires security-scoped bookmark in MAS).
    Restricted,
    /// Plane is doctrine substrate only — emitted in all streams via
    /// audit emission (no GPU kernel). Verification plane only.
    DoctrineOnly,
}

impl StreamSurfaceLevel {
    /// True when the cell is modeled as a runtime-facing policy
    /// surface (Full / Bounded / Restricted). Doctrine-only planes
    /// remain audit emissions.
    pub fn is_runtime_capability(self) -> bool {
        !matches!(self, StreamSurfaceLevel::DoctrineOnly)
    }

    /// True when the cell carries the full V6.1 canonical policy
    /// surface (distinct from current implementation completeness).
    pub fn is_full(self) -> bool {
        matches!(self, StreamSurfaceLevel::Full)
    }
}

/// Canonical surface exposure for a (stream, plane) cell per V6.1 §3.
///
/// 3 streams × 5 planes = 15 cells. Every cell is well-defined; no
/// stream omits any plane (per V6.1 §3 "every stream contains the
/// same five planes").
pub fn stream_surface(stream: ProductStream, plane: RuntimePlane) -> StreamSurfaceLevel {
    use ProductStream::*;
    use RuntimePlane::*;
    match (stream, plane) {
        // ===== State plane (recurrent semantic spine) =====
        // MAS: Granite-4-H-Micro 3B (9:1) bundled. Not arbitrary
        // user-supplied weights — that's a Pro-tier capability.
        (Mas, State) => StreamSurfaceLevel::Bounded,
        // Pro: any Mamba-2 / Granite-4-H / Falcon-Mamba per V6.1 §5.
        (Pro, State) => StreamSurfaceLevel::Full,
        // Vault: full + research-tier extensions (custom kernels,
        // weight-surgery, model-distillation).
        (Vault, State) => StreamSurfaceLevel::Full,

        // ===== Episodic plane (exact recall pages) =====
        // MAS: Atlas pages require security-scoped bookmark per
        // page-cluster (selected-vault retrieval per
        // mas_capability_lattice). Pinned-page retrieval works at
        // the entitled-folder boundary.
        (Mas, Episodic) => StreamSurfaceLevel::Restricted,
        // Pro: full page set; user controls retention.
        (Pro, Episodic) => StreamSurfaceLevel::Full,
        // Vault: full + research-tier indexes (theorem witnesses,
        // raw claim ledgers).
        (Vault, Episodic) => StreamSurfaceLevel::Full,

        // ===== Assembly plane (ternary routing) =====
        // MAS exposes only the bounded App-Store-safe routing
        // vocabulary. Pro/Vault widen to the full research policy
        // surface. This is exposure policy, not proof that
        // PacketRouter1bit.metal exists yet.
        (Mas, Assembly) => StreamSurfaceLevel::Bounded,
        (Pro, Assembly) => StreamSurfaceLevel::Full,
        (Vault, Assembly) => StreamSurfaceLevel::Full,

        // ===== Controller plane (executive surfaces) =====
        // MAS exposes bounded controller gates. The fused
        // ControllerKernelPack.metal name is canonical doctrine, but
        // this matrix does not claim the Metal implementation ships.
        (Mas, Controller) => StreamSurfaceLevel::Bounded,
        (Pro, Controller) => StreamSurfaceLevel::Full,
        (Vault, Controller) => StreamSurfaceLevel::Full,

        // ===== Verification plane (audit substrate) =====
        // No GPU kernel; doctrine substrate. AnswerPacket / WBO /
        // ClaimKind / VRM / sheaf-residual emit in every stream.
        // Pro adds replay-bundle export; Vault adds raw witness
        // logs. Cells uniformly classed as DoctrineOnly here; the
        // stream-specific replay/witness extensions live in the
        // provenance ledger substrate.
        (_, Verification) => StreamSurfaceLevel::DoctrineOnly,
    }
}

/// All 3 × 5 = 15 (stream, plane) cells in canonical order.
pub const ALL_FIFTEEN_CELLS: [(ProductStream, RuntimePlane); 15] = [
    (ProductStream::Mas, RuntimePlane::State),
    (ProductStream::Mas, RuntimePlane::Episodic),
    (ProductStream::Mas, RuntimePlane::Assembly),
    (ProductStream::Mas, RuntimePlane::Controller),
    (ProductStream::Mas, RuntimePlane::Verification),
    (ProductStream::Pro, RuntimePlane::State),
    (ProductStream::Pro, RuntimePlane::Episodic),
    (ProductStream::Pro, RuntimePlane::Assembly),
    (ProductStream::Pro, RuntimePlane::Controller),
    (ProductStream::Pro, RuntimePlane::Verification),
    (ProductStream::Vault, RuntimePlane::State),
    (ProductStream::Vault, RuntimePlane::Episodic),
    (ProductStream::Vault, RuntimePlane::Assembly),
    (ProductStream::Vault, RuntimePlane::Controller),
    (ProductStream::Vault, RuntimePlane::Verification),
];

/// Number of "Full"-surface planes a stream exposes (excluding
/// DoctrineOnly Verification plane).
pub fn full_plane_count(stream: ProductStream) -> usize {
    [
        RuntimePlane::State,
        RuntimePlane::Episodic,
        RuntimePlane::Assembly,
        RuntimePlane::Controller,
        RuntimePlane::Verification,
    ]
    .iter()
    .filter(|p| stream_surface(stream, **p).is_full())
    .count()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_fifteen_cells_are_well_defined() {
        // Every (stream, plane) pair returns a level — no panics.
        // (Match arms cover all 15; this test just verifies the
        // helper returns a result for each.)
        assert_eq!(ALL_FIFTEEN_CELLS.len(), 15);
        for (stream, plane) in ALL_FIFTEEN_CELLS {
            // Just call it; non-panic = pass.
            let _ = stream_surface(stream, plane);
        }
    }

    #[test]
    fn mas_state_plane_is_bounded() {
        // V6.1 §5: MAS bundles Granite-4-H-Micro 3B (9:1). Not
        // arbitrary user-supplied weights.
        assert_eq!(
            stream_surface(ProductStream::Mas, RuntimePlane::State),
            StreamSurfaceLevel::Bounded
        );
    }

    #[test]
    fn pro_and_vault_state_planes_are_full() {
        // Pro tier: any Mamba-2 / hybrid per V6.1 §5. Vault: full
        // + research extensions.
        assert_eq!(
            stream_surface(ProductStream::Pro, RuntimePlane::State),
            StreamSurfaceLevel::Full
        );
        assert_eq!(
            stream_surface(ProductStream::Vault, RuntimePlane::State),
            StreamSurfaceLevel::Full
        );
    }

    #[test]
    fn mas_episodic_plane_is_restricted() {
        // MAS: Atlas pages require per-page-cluster security-scoped
        // bookmark (selected-vault retrieval).
        assert_eq!(
            stream_surface(ProductStream::Mas, RuntimePlane::Episodic),
            StreamSurfaceLevel::Restricted
        );
    }

    #[test]
    fn assembly_plane_is_bounded_in_mas_full_in_pro_and_vault() {
        // V6.1 sharpening point 5: routing is naturally ternary, but
        // MAS keeps the routing surface bounded.
        assert_eq!(
            stream_surface(ProductStream::Mas, RuntimePlane::Assembly),
            StreamSurfaceLevel::Bounded
        );
        assert_eq!(
            stream_surface(ProductStream::Pro, RuntimePlane::Assembly),
            StreamSurfaceLevel::Full
        );
        assert_eq!(
            stream_surface(ProductStream::Vault, RuntimePlane::Assembly),
            StreamSurfaceLevel::Full
        );
    }

    #[test]
    fn controller_plane_is_bounded_in_mas_full_in_pro_and_vault() {
        // The controller surface is canonical across streams, but
        // MAS is bounded and this is not a kernel-implementation
        // claim.
        assert_eq!(
            stream_surface(ProductStream::Mas, RuntimePlane::Controller),
            StreamSurfaceLevel::Bounded
        );
        assert_eq!(
            stream_surface(ProductStream::Pro, RuntimePlane::Controller),
            StreamSurfaceLevel::Full
        );
        assert_eq!(
            stream_surface(ProductStream::Vault, RuntimePlane::Controller),
            StreamSurfaceLevel::Full
        );
    }

    #[test]
    fn verification_plane_is_doctrine_only_in_every_stream() {
        // V6.1 §3: Verification plane has no GPU kernel — it lives
        // in audit substrate (AnswerPacket / WBO / ClaimKind / VRM
        // / sheaf-residual / replay).
        for stream in [ProductStream::Mas, ProductStream::Pro, ProductStream::Vault] {
            assert_eq!(
                stream_surface(stream, RuntimePlane::Verification),
                StreamSurfaceLevel::DoctrineOnly
            );
        }
    }

    #[test]
    fn doctrine_only_is_not_runtime_capability() {
        assert!(!StreamSurfaceLevel::DoctrineOnly.is_runtime_capability());
        assert!(StreamSurfaceLevel::Full.is_runtime_capability());
        assert!(StreamSurfaceLevel::Bounded.is_runtime_capability());
        assert!(StreamSurfaceLevel::Restricted.is_runtime_capability());
    }

    #[test]
    fn full_plane_count_per_stream() {
        // MAS has no Full policy planes: State/Assembly/Controller
        // are Bounded, Episodic=Restricted, Verification=DoctrineOnly.
        assert_eq!(full_plane_count(ProductStream::Mas), 0);
        // Pro: State + Episodic + Assembly + Controller all Full;
        // Verification=DoctrineOnly. 4 Full.
        assert_eq!(full_plane_count(ProductStream::Pro), 4);
        // Vault: same as Pro at this surface granularity (research
        // extensions are below this layer's resolution).
        assert_eq!(full_plane_count(ProductStream::Vault), 4);
    }

    #[test]
    fn pro_strictly_widens_mas_envelope() {
        // V6.1 stream-surface invariant: every plane that is Full in
        // MAS is also Full in Pro; planes that are Bounded/Restricted
        // in MAS are Full in Pro. (Verification is DoctrineOnly in
        // both — that's a doctrinal carve-out.)
        for plane in [
            RuntimePlane::State,
            RuntimePlane::Episodic,
            RuntimePlane::Assembly,
            RuntimePlane::Controller,
        ] {
            let mas = stream_surface(ProductStream::Mas, plane);
            let pro = stream_surface(ProductStream::Pro, plane);
            // Pro is Full for all four runtime planes.
            assert!(
                pro.is_full(),
                "Pro plane {:?} must be Full, got {:?}",
                plane,
                pro
            );
            // Where MAS is Bounded/Restricted, Pro must widen to Full.
            if !mas.is_full() {
                assert_ne!(mas, pro, "Pro must widen MAS for plane {:?}", plane);
            }
        }
    }

    #[test]
    fn pro_and_vault_have_identical_runtime_surface() {
        // At this layer's resolution, Pro and Vault are doctrinally
        // identical for every runtime plane (research extensions
        // live below this surface, in the provenance ledger and
        // raw-ANE/private-frameworks substrates).
        for plane in [
            RuntimePlane::State,
            RuntimePlane::Episodic,
            RuntimePlane::Assembly,
            RuntimePlane::Controller,
        ] {
            assert_eq!(
                stream_surface(ProductStream::Pro, plane),
                stream_surface(ProductStream::Vault, plane),
                "Pro and Vault must agree on runtime plane {:?}",
                plane
            );
        }
    }

    #[test]
    fn surface_level_round_trips_through_json() {
        for level in [
            StreamSurfaceLevel::Full,
            StreamSurfaceLevel::Bounded,
            StreamSurfaceLevel::Restricted,
            StreamSurfaceLevel::DoctrineOnly,
        ] {
            let json = serde_json::to_string(&level).unwrap();
            let parsed: StreamSurfaceLevel = serde_json::from_str(&json).unwrap();
            assert_eq!(level, parsed);
        }
    }

    #[test]
    fn surface_level_serializes_in_snake_case() {
        assert_eq!(
            serde_json::to_string(&StreamSurfaceLevel::Full).unwrap(),
            "\"full\""
        );
        assert_eq!(
            serde_json::to_string(&StreamSurfaceLevel::Bounded).unwrap(),
            "\"bounded\""
        );
        assert_eq!(
            serde_json::to_string(&StreamSurfaceLevel::Restricted).unwrap(),
            "\"restricted\""
        );
        assert_eq!(
            serde_json::to_string(&StreamSurfaceLevel::DoctrineOnly).unwrap(),
            "\"doctrine_only\""
        );
    }
}
