//! Canonical GPU pipeline pass order (locked decision #18).
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Locked
//! architectural decisions" #18:
//!
//! > GPU pass order: Activation → grid bin → cell reduce → repulsion →
//! > springs → adaptive speed → integrate+sleep → compact → indirect
//! > draw → render
//!
//! This module enumerates the canonical stage order so the integrator
//! (and the upcoming MSL `.metal` translation pass) consumes a single
//! source-of-truth ordering rather than rediscovering it from prose. A
//! `validate_ordering` helper catches out-of-order configurations
//! defensively — useful for engine integration tests + ABI checks.
//!
//! ## Pure data
//!
//! No engine dependencies. Each `PipelineStage` enum variant maps to a
//! kernel module (or in the renderer's case, the actual draw call).
//! The enum's wire-stable u8 discriminants are part of the FFI surface
//! when the Swift side wants to construct a custom pipeline trace.

use serde::{Deserialize, Serialize};

/// One stage of the canonical kernel pipeline. Discriminant values are
/// wire-stable — Swift / Metal trace tools encode them as u8 indices.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
#[repr(u8)]
pub enum PipelineStage {
    /// "Activation" — per-node flag refresh (RENDERABLE / AWAKE / WARMING /
    /// SLEEPING / PINNED). Runs first because every downstream kernel
    /// reads the flag mask to decide whether to integrate the node.
    Activation = 0,
    /// Grid bin — hash node positions into cell ids
    /// (mirrors `grid_kernels::grid_build_kernel`).
    GridBin = 1,
    /// Cell reduce — per-cell mass + centre-of-mass for the far-field
    /// repulsion approximation
    /// (mirrors `grid_kernels::cell_reduce_kernel`).
    CellReduce = 2,
    /// Repulsion — near-field exact + far-field aggregate
    /// (mirrors `grid_kernels::repulsion_kernel`).
    Repulsion = 3,
    /// Springs — node-parallel CSR gather
    /// (mirrors `force_kernels::spring_forces_kernel`).
    Springs = 4,
    /// Adaptive speed — FA2 global swing + traction reduction +
    /// per-node alpha scaling
    /// (mirrors `adaptive_kernels::fa2_swing_traction` +
    /// `fa2_global_speed`).
    AdaptiveSpeed = 5,
    /// Integrate + sleep — symplectic Euler step + calm-frame counter
    /// + propose_sleep mask, fused into one pass for cache locality
    /// (mirrors `force_kernels::integrate_kernel` +
    /// `adaptive_kernels::sleep_update_kernel`).
    IntegrateSleep = 6,
    /// Compact — frustum cull + emit visible-id lists
    /// (mirrors `visibility_kernels::frustum_cull_nodes` +
    /// `frustum_cull_edges`).
    Compact = 7,
    /// Indirect draw args — write `MTLDrawPrimitivesIndirectArguments`
    /// (mirrors `visibility_kernels::build_indirect_args`).
    IndirectDraw = 8,
    /// Render — Metal render encoder consumes the indirect-draw buffer.
    Render = 9,
}

impl PipelineStage {
    /// Stage name for telemetry / signpost labels.
    pub fn name(self) -> &'static str {
        match self {
            Self::Activation => "activation",
            Self::GridBin => "grid_bin",
            Self::CellReduce => "cell_reduce",
            Self::Repulsion => "repulsion",
            Self::Springs => "springs",
            Self::AdaptiveSpeed => "adaptive_speed",
            Self::IntegrateSleep => "integrate_sleep",
            Self::Compact => "compact",
            Self::IndirectDraw => "indirect_draw",
            Self::Render => "render",
        }
    }

    /// Position in the canonical ordering (0..10).
    pub fn ordinal(self) -> u8 { self as u8 }

    /// Is this a compute stage (vs the render encoder)? Useful for
    /// engine code that walks the pipeline + needs to know when to
    /// transition encoders.
    pub fn is_compute(self) -> bool {
        !matches!(self, Self::Render)
    }
}

/// The canonical pipeline order — single source of truth for the
/// engine + the upcoming MSL translation pass.
pub const CANONICAL_PIPELINE_ORDER: [PipelineStage; 10] = [
    PipelineStage::Activation,
    PipelineStage::GridBin,
    PipelineStage::CellReduce,
    PipelineStage::Repulsion,
    PipelineStage::Springs,
    PipelineStage::AdaptiveSpeed,
    PipelineStage::IntegrateSleep,
    PipelineStage::Compact,
    PipelineStage::IndirectDraw,
    PipelineStage::Render,
];

/// Validate that a custom pipeline ordering matches the canonical one.
/// Returns `Ok(())` when the input is the canonical order; otherwise
/// returns a list of `(expected, got)` pairs at each mismatched
/// position.
///
/// Used by engine integration tests + Swift bridge to catch pipeline
/// drift before it reaches a customer's GPU.
pub fn validate_ordering(stages: &[PipelineStage]) -> Result<(), Vec<(PipelineStage, PipelineStage)>> {
    if stages == CANONICAL_PIPELINE_ORDER {
        return Ok(());
    }
    let mut diffs = Vec::new();
    let canon = &CANONICAL_PIPELINE_ORDER[..];
    let max = canon.len().max(stages.len());
    for i in 0..max {
        let expected = canon.get(i).copied();
        let got = stages.get(i).copied();
        if expected != got {
            if let (Some(e), Some(g)) = (expected, got) {
                diffs.push((e, g));
            } else {
                // Length mismatch — synthesize a placeholder pair using the
                // first-defined side. Either side can be missing.
                if let Some(e) = expected {
                    diffs.push((e, PipelineStage::Render));
                }
                if let Some(g) = got {
                    diffs.push((PipelineStage::Activation, g));
                }
            }
        }
    }
    Err(diffs)
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_order_has_exactly_ten_stages() {
        assert_eq!(CANONICAL_PIPELINE_ORDER.len(), 10);
    }

    #[test]
    fn stage_ordinals_are_strictly_increasing() {
        for w in CANONICAL_PIPELINE_ORDER.windows(2) {
            assert!(w[0].ordinal() < w[1].ordinal(),
                "stages must have strictly increasing ordinals: {:?} → {:?}", w[0], w[1]);
        }
    }

    #[test]
    fn render_is_terminal_and_non_compute() {
        let last = *CANONICAL_PIPELINE_ORDER.last().unwrap();
        assert_eq!(last, PipelineStage::Render);
        assert!(!last.is_compute());
        // Every other stage is compute.
        for &stage in &CANONICAL_PIPELINE_ORDER[..CANONICAL_PIPELINE_ORDER.len() - 1] {
            assert!(stage.is_compute(), "{:?} should be compute", stage);
        }
    }

    #[test]
    fn stage_names_are_snake_case_and_unique() {
        let mut seen: std::collections::BTreeSet<&str> = Default::default();
        for s in &CANONICAL_PIPELINE_ORDER {
            assert!(seen.insert(s.name()), "duplicate stage name: {}", s.name());
            assert!(s.name().chars().all(|c| c.is_ascii_lowercase() || c == '_'),
                "stage name must be snake_case: {}", s.name());
        }
        assert_eq!(seen.len(), 10);
    }

    #[test]
    fn validate_ordering_accepts_canonical() {
        let canon: Vec<PipelineStage> = CANONICAL_PIPELINE_ORDER.to_vec();
        assert!(validate_ordering(&canon).is_ok());
    }

    #[test]
    fn validate_ordering_rejects_swapped_pair() {
        // Swap Springs and Repulsion (decision #18 says Repulsion before Springs).
        let mut bad = CANONICAL_PIPELINE_ORDER.to_vec();
        bad.swap(3, 4); // positions of Repulsion and Springs
        let result = validate_ordering(&bad);
        assert!(result.is_err());
        let diffs = result.unwrap_err();
        assert_eq!(diffs.len(), 2);
        // Position 3: expected Repulsion, got Springs
        assert_eq!(diffs[0].0, PipelineStage::Repulsion);
        assert_eq!(diffs[0].1, PipelineStage::Springs);
    }

    #[test]
    fn validate_ordering_rejects_short_list() {
        // Missing render stage.
        let short = &CANONICAL_PIPELINE_ORDER[..9];
        let result = validate_ordering(short);
        assert!(result.is_err());
    }

    #[test]
    fn stages_round_trip_via_serde() {
        for &stage in &CANONICAL_PIPELINE_ORDER {
            let json = serde_json::to_string(&stage).unwrap();
            let back: PipelineStage = serde_json::from_str(&json).unwrap();
            assert_eq!(stage, back);
        }
    }

    #[test]
    fn canonical_order_matches_decision_18_prose() {
        // Spell out the canonical order as a sanity check against
        // drift. If anyone re-orders without updating this test, the
        // CI failure carries the exact decision-#18 string with it.
        assert_eq!(
            CANONICAL_PIPELINE_ORDER.iter().map(|s| s.name()).collect::<Vec<_>>(),
            vec![
                "activation",
                "grid_bin",
                "cell_reduce",
                "repulsion",
                "springs",
                "adaptive_speed",
                "integrate_sleep",
                "compact",
                "indirect_draw",
                "render",
            ],
            "Decision #18 ordering: Activation → grid bin → cell reduce → repulsion → springs → adaptive speed → integrate+sleep → compact → indirect draw → render"
        );
    }

    #[test]
    fn stage_discriminants_are_wire_stable() {
        // Discriminant values are the FFI contract — never reorder.
        assert_eq!(PipelineStage::Activation as u8, 0);
        assert_eq!(PipelineStage::GridBin as u8, 1);
        assert_eq!(PipelineStage::CellReduce as u8, 2);
        assert_eq!(PipelineStage::Repulsion as u8, 3);
        assert_eq!(PipelineStage::Springs as u8, 4);
        assert_eq!(PipelineStage::AdaptiveSpeed as u8, 5);
        assert_eq!(PipelineStage::IntegrateSleep as u8, 6);
        assert_eq!(PipelineStage::Compact as u8, 7);
        assert_eq!(PipelineStage::IndirectDraw as u8, 8);
        assert_eq!(PipelineStage::Render as u8, 9);
    }
}
