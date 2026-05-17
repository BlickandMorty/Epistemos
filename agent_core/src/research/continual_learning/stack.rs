//! Source:
//! - `docs/fusion/jordan's research/kimis deep research/research/continual_learning_online.md`
//!   §8.1 "Architecture Recommendation: 'Never Retrain' Stack" — the
//!   7-layer architecture (base model · adaptation · protection · memory ·
//!   history · governance · quantization).
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.1 J3 row — the 5 sub-features this stack composes.
//! - Companions: [`super::ewc`] (Protection), [`super::oftv2`]
//!   (Adaptation), [`super::dsc`] (Adaptation direction tracking),
//!   [`super::titans_mac`] (Memory), [`super::seal_dora`] (History →
//!   nightly self-edit).
//!
//! # Wave J3 — NeverRetrainStack assembly
//!
//! Each of the 5 J3 sub-features already ships a substrate-floor
//! kernel under its own sibling module. This file is the typed
//! envelope that catalogs which sub-feature occupies which §8.1 layer
//! slot — so future agents that wire `NeverRetrainStack` into a
//! runtime can't accidentally route, say, an OFTv2 rotation through
//! the Protection layer.
//!
//! ## §8.1 layer table (canonical)
//!
//! | Slot # | Layer        | Purpose                              | Primitive(s)              |
//! |--------|--------------|--------------------------------------|---------------------------|
//! | 0      | Base         | immutable foundation weights         | (external — frozen)       |
//! | 1      | Adaptation   | task-time low-rank deltas            | OFTv2, DSC                |
//! | 2      | Protection   | freeze-mask high-Fisher params       | EWC                       |
//! | 3      | Memory       | surprise-driven external memory      | Titans-MAC                |
//! | 4      | History      | rolling event ledger                 | (external — provenance)   |
//! | 5      | Governance   | per-tier policy + caps               | (external — capabilities) |
//! | 6      | Quantization | post-train weight compression        | (external — sherry/leech) |
//!
//! ## "Never Retrain" invariant
//!
//! The stack contract: base weights are NEVER mutated. All learning
//! happens through layers 1-3 (Adaptation + Protection + Memory).
//! Layers 4-6 are catalog-only here (provenance ledger, governance
//! capabilities, and the J7 quantization codebooks all live in their
//! own crates).

use serde::{Deserialize, Serialize};

/// 7-layer slot taxonomy. Numeric tag matches §8.1 layer index.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum NeverRetrainLayer {
    Base = 0,
    Adaptation = 1,
    Protection = 2,
    Memory = 3,
    History = 4,
    Governance = 5,
    Quantization = 6,
}

impl NeverRetrainLayer {
    pub const ALL: [NeverRetrainLayer; 7] = [
        NeverRetrainLayer::Base,
        NeverRetrainLayer::Adaptation,
        NeverRetrainLayer::Protection,
        NeverRetrainLayer::Memory,
        NeverRetrainLayer::History,
        NeverRetrainLayer::Governance,
        NeverRetrainLayer::Quantization,
    ];

    pub const fn name(self) -> &'static str {
        match self {
            NeverRetrainLayer::Base => "base",
            NeverRetrainLayer::Adaptation => "adaptation",
            NeverRetrainLayer::Protection => "protection",
            NeverRetrainLayer::Memory => "memory",
            NeverRetrainLayer::History => "history",
            NeverRetrainLayer::Governance => "governance",
            NeverRetrainLayer::Quantization => "quantization",
        }
    }

    pub const fn index(self) -> u8 {
        self as u8
    }

    /// True iff this layer is allowed to mutate state per the §8.1
    /// "Never Retrain" invariant. Base/History/Governance/Quantization
    /// are read-mostly from the stack's perspective; Adaptation/
    /// Protection/Memory carry the learning load.
    pub const fn is_writable(self) -> bool {
        matches!(
            self,
            NeverRetrainLayer::Adaptation
                | NeverRetrainLayer::Protection
                | NeverRetrainLayer::Memory
        )
    }

    /// Reverse lookup for [`Self::name`]. `None` for unknown names.
    pub fn from_name(name: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|l| l.name() == name)
    }

    /// Reverse lookup for [`Self::index`]. `None` for indices > 6.
    pub const fn from_index(idx: u8) -> Option<Self> {
        match idx {
            0 => Some(NeverRetrainLayer::Base),
            1 => Some(NeverRetrainLayer::Adaptation),
            2 => Some(NeverRetrainLayer::Protection),
            3 => Some(NeverRetrainLayer::Memory),
            4 => Some(NeverRetrainLayer::History),
            5 => Some(NeverRetrainLayer::Governance),
            6 => Some(NeverRetrainLayer::Quantization),
            _ => None,
        }
    }

    /// Complement to [`Self::is_writable`]. Cross-surface invariant:
    /// `is_writable XOR is_read_only` partitions every layer.
    pub const fn is_read_only(self) -> bool {
        !self.is_writable()
    }
}

/// Catalog of the J3 primitives. Each variant ties a substrate kernel
/// to its canonical §8.1 layer slot. Future code that submits an
/// operation MUST tag it with one of these — the typed dispatch
/// ensures e.g. an OFTv2 rotation can't be routed through Protection.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ContinualPrimitive {
    /// OFTv2 / QOFT — orthogonal fine-tuning rotation in Adaptation slot.
    Oftv2,
    /// DSC / DOC — online PCA direction tracking in Adaptation slot.
    Dsc,
    /// EWC — Fisher-weighted quadratic penalty in Protection slot.
    Ewc,
    /// Titans-MAC — surprise-gradient memory update in Memory slot.
    TitansMac,
    /// SEAL-DoRA — nightly self-edit compiled to per-user DoRA delta.
    /// History layer feeds the outer-RL loop that emits the delta.
    SealDora,
}

impl ContinualPrimitive {
    pub const ALL: [ContinualPrimitive; 5] = [
        ContinualPrimitive::Oftv2,
        ContinualPrimitive::Dsc,
        ContinualPrimitive::Ewc,
        ContinualPrimitive::TitansMac,
        ContinualPrimitive::SealDora,
    ];

    pub const fn slot(self) -> NeverRetrainLayer {
        match self {
            ContinualPrimitive::Oftv2 => NeverRetrainLayer::Adaptation,
            ContinualPrimitive::Dsc => NeverRetrainLayer::Adaptation,
            ContinualPrimitive::Ewc => NeverRetrainLayer::Protection,
            ContinualPrimitive::TitansMac => NeverRetrainLayer::Memory,
            ContinualPrimitive::SealDora => NeverRetrainLayer::History,
        }
    }

    pub const fn code(self) -> &'static str {
        match self {
            ContinualPrimitive::Oftv2 => "oftv2",
            ContinualPrimitive::Dsc => "dsc",
            ContinualPrimitive::Ewc => "ewc",
            ContinualPrimitive::TitansMac => "titans_mac",
            ContinualPrimitive::SealDora => "seal_dora",
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|p| p.code() == code)
    }
}

impl NeverRetrainStackError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            NeverRetrainStackError::BasePrimitiveSubmitted => "base_primitive_submitted",
            NeverRetrainStackError::SlotMismatch { .. } => "slot_mismatch",
            NeverRetrainStackError::WriteToReadOnlyLayer { .. } => "write_to_read_only_layer",
        }
    }

    pub const fn is_base_submitted(&self) -> bool {
        matches!(self, NeverRetrainStackError::BasePrimitiveSubmitted)
    }

    pub const fn is_slot_mismatch(&self) -> bool {
        matches!(self, NeverRetrainStackError::SlotMismatch { .. })
    }

    /// Cross-surface invariant: exactly one of `is_base_submitted /
    /// is_slot_mismatch / is_read_only` is true per variant
    /// (3-way partition).
    pub const fn is_read_only(&self) -> bool {
        matches!(self, NeverRetrainStackError::WriteToReadOnlyLayer { .. })
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum NeverRetrainStackError {
    BasePrimitiveSubmitted,
    SlotMismatch {
        primitive: ContinualPrimitive,
        attempted_slot: NeverRetrainLayer,
        canonical_slot: NeverRetrainLayer,
    },
    WriteToReadOnlyLayer { layer: NeverRetrainLayer },
}

/// Validate that a primitive submission targets its canonical layer.
/// This is the runtime check that backs the "Never Retrain" invariant.
pub fn validate_submission(
    primitive: ContinualPrimitive,
    attempted_slot: NeverRetrainLayer,
) -> Result<(), NeverRetrainStackError> {
    if attempted_slot == NeverRetrainLayer::Base {
        return Err(NeverRetrainStackError::BasePrimitiveSubmitted);
    }
    if !attempted_slot.is_writable() {
        return Err(NeverRetrainStackError::WriteToReadOnlyLayer { layer: attempted_slot });
    }
    let canonical = primitive.slot();
    if canonical != attempted_slot {
        return Err(NeverRetrainStackError::SlotMismatch {
            primitive,
            attempted_slot,
            canonical_slot: canonical,
        });
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn seven_distinct_layers() {
        let s: std::collections::HashSet<_> = NeverRetrainLayer::ALL.iter().copied().collect();
        assert_eq!(s.len(), 7);
    }

    #[test]
    fn layer_indices_match_section_order() {
        assert_eq!(NeverRetrainLayer::Base.index(), 0);
        assert_eq!(NeverRetrainLayer::Adaptation.index(), 1);
        assert_eq!(NeverRetrainLayer::Protection.index(), 2);
        assert_eq!(NeverRetrainLayer::Memory.index(), 3);
        assert_eq!(NeverRetrainLayer::History.index(), 4);
        assert_eq!(NeverRetrainLayer::Governance.index(), 5);
        assert_eq!(NeverRetrainLayer::Quantization.index(), 6);
    }

    #[test]
    fn only_three_layers_writable() {
        let writable: Vec<_> = NeverRetrainLayer::ALL
            .iter()
            .filter(|l| l.is_writable())
            .copied()
            .collect();
        assert_eq!(writable.len(), 3);
        assert!(writable.contains(&NeverRetrainLayer::Adaptation));
        assert!(writable.contains(&NeverRetrainLayer::Protection));
        assert!(writable.contains(&NeverRetrainLayer::Memory));
    }

    #[test]
    fn base_layer_is_never_writable() {
        assert!(!NeverRetrainLayer::Base.is_writable());
    }

    #[test]
    fn five_distinct_primitives() {
        let s: std::collections::HashSet<_> = ContinualPrimitive::ALL.iter().copied().collect();
        assert_eq!(s.len(), 5);
    }

    #[test]
    fn primitive_slot_mapping_is_canonical() {
        assert_eq!(ContinualPrimitive::Oftv2.slot(), NeverRetrainLayer::Adaptation);
        assert_eq!(ContinualPrimitive::Dsc.slot(), NeverRetrainLayer::Adaptation);
        assert_eq!(ContinualPrimitive::Ewc.slot(), NeverRetrainLayer::Protection);
        assert_eq!(ContinualPrimitive::TitansMac.slot(), NeverRetrainLayer::Memory);
        assert_eq!(ContinualPrimitive::SealDora.slot(), NeverRetrainLayer::History);
    }

    #[test]
    fn all_primitive_codes_unique() {
        let mut s = std::collections::HashSet::new();
        for v in ContinualPrimitive::ALL.iter() {
            assert!(s.insert(v.code()));
        }
    }

    #[test]
    fn correct_slot_submission_passes() {
        assert!(validate_submission(
            ContinualPrimitive::Ewc,
            NeverRetrainLayer::Protection
        )
        .is_ok());
        assert!(validate_submission(
            ContinualPrimitive::Oftv2,
            NeverRetrainLayer::Adaptation
        )
        .is_ok());
    }

    #[test]
    fn base_layer_submission_rejected() {
        let err =
            validate_submission(ContinualPrimitive::Ewc, NeverRetrainLayer::Base).unwrap_err();
        assert_eq!(err, NeverRetrainStackError::BasePrimitiveSubmitted);
    }

    #[test]
    fn read_only_layer_submission_rejected() {
        let err = validate_submission(
            ContinualPrimitive::SealDora,
            NeverRetrainLayer::Governance,
        )
        .unwrap_err();
        assert_eq!(
            err,
            NeverRetrainStackError::WriteToReadOnlyLayer {
                layer: NeverRetrainLayer::Governance
            }
        );
    }

    #[test]
    fn slot_mismatch_rejected() {
        let err =
            validate_submission(ContinualPrimitive::Ewc, NeverRetrainLayer::Memory).unwrap_err();
        assert!(matches!(
            err,
            NeverRetrainStackError::SlotMismatch {
                primitive: ContinualPrimitive::Ewc,
                attempted_slot: NeverRetrainLayer::Memory,
                canonical_slot: NeverRetrainLayer::Protection,
            }
        ));
    }

    #[test]
    fn seal_dora_history_is_read_only_so_submission_rejected() {
        // SEAL-DoRA's canonical slot is History per §8.1, but History
        // is a read-only layer (it's the event ledger; the SEAL-DoRA
        // update is consumed *from* it, not written *to* it through
        // this validation surface). The substrate enforces this with
        // a precedence rule: read-only check fires before slot-match.
        let err = validate_submission(
            ContinualPrimitive::SealDora,
            NeverRetrainLayer::History,
        )
        .unwrap_err();
        assert_eq!(
            err,
            NeverRetrainStackError::WriteToReadOnlyLayer {
                layer: NeverRetrainLayer::History
            }
        );
    }

    #[test]
    fn layer_name_codes_stable() {
        for l in NeverRetrainLayer::ALL.iter() {
            assert!(!l.name().is_empty());
            assert!(l.name().chars().all(|c| c.is_ascii_lowercase()));
        }
    }

    #[test]
    fn primitive_serde_roundtrip() {
        let p = ContinualPrimitive::TitansMac;
        let json = serde_json::to_string(&p).unwrap();
        let back: ContinualPrimitive = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    #[test]
    fn layer_serde_roundtrip() {
        let l = NeverRetrainLayer::Memory;
        let json = serde_json::to_string(&l).unwrap();
        let back: NeverRetrainLayer = serde_json::from_str(&json).unwrap();
        assert_eq!(l, back);
    }

    // ── diagnostic surface (iter 187) ────────────────────────────────────────

    #[test]
    fn layer_from_name_roundtrips_all() {
        for l in NeverRetrainLayer::ALL.iter().copied() {
            assert_eq!(NeverRetrainLayer::from_name(l.name()), Some(l));
        }
        assert_eq!(NeverRetrainLayer::from_name("Base"), None);
    }

    #[test]
    fn layer_from_index_roundtrips_all() {
        for l in NeverRetrainLayer::ALL.iter().copied() {
            assert_eq!(NeverRetrainLayer::from_index(l.index()), Some(l));
        }
        assert_eq!(NeverRetrainLayer::from_index(7), None);
        assert_eq!(NeverRetrainLayer::from_index(255), None);
    }

    #[test]
    fn writable_xor_read_only_partition() {
        // Cross-surface invariant: is_writable XOR is_read_only.
        for l in NeverRetrainLayer::ALL.iter().copied() {
            assert_ne!(l.is_writable(), l.is_read_only());
        }
        assert_eq!(NeverRetrainLayer::ALL.iter().filter(|l| l.is_writable()).count(), 3);
        assert_eq!(NeverRetrainLayer::ALL.iter().filter(|l| l.is_read_only()).count(), 4);
    }

    #[test]
    fn primitive_from_code_roundtrips_all() {
        for p in ContinualPrimitive::ALL.iter().copied() {
            assert_eq!(ContinualPrimitive::from_code(p.code()), Some(p));
        }
        assert_eq!(ContinualPrimitive::from_code("Ewc"), None);
    }

    #[test]
    fn stack_error_cause_distinct() {
        let variants = [
            NeverRetrainStackError::BasePrimitiveSubmitted,
            NeverRetrainStackError::SlotMismatch {
                primitive: ContinualPrimitive::Ewc,
                attempted_slot: NeverRetrainLayer::Memory,
                canonical_slot: NeverRetrainLayer::Protection,
            },
            NeverRetrainStackError::WriteToReadOnlyLayer {
                layer: NeverRetrainLayer::Base,
            },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 3);
    }

    #[test]
    fn stack_error_3way_classifier_partition() {
        let variants = [
            NeverRetrainStackError::BasePrimitiveSubmitted,
            NeverRetrainStackError::SlotMismatch {
                primitive: ContinualPrimitive::Ewc,
                attempted_slot: NeverRetrainLayer::Memory,
                canonical_slot: NeverRetrainLayer::Protection,
            },
            NeverRetrainStackError::WriteToReadOnlyLayer {
                layer: NeverRetrainLayer::Base,
            },
        ];
        // Cross-surface invariant: is_base_submitted XOR is_slot_mismatch
        // XOR is_read_only.
        for e in variants {
            let trio = [e.is_base_submitted(), e.is_slot_mismatch(), e.is_read_only()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", e);
        }
    }

    #[test]
    fn real_validate_errors_carry_matching_classifier() {
        // Cross-surface: validate_submission errors carry matching predicates.
        let err =
            validate_submission(ContinualPrimitive::Ewc, NeverRetrainLayer::Base).unwrap_err();
        assert!(err.is_base_submitted());

        let err = validate_submission(
            ContinualPrimitive::SealDora,
            NeverRetrainLayer::Governance,
        )
        .unwrap_err();
        assert!(err.is_read_only());

        let err =
            validate_submission(ContinualPrimitive::Ewc, NeverRetrainLayer::Memory).unwrap_err();
        assert!(err.is_slot_mismatch());
    }

    #[test]
    fn every_primitive_canonical_slot_is_writable() {
        // Cross-surface invariant: every primitive's canonical slot
        // satisfies is_writable — EXCEPT SealDora which maps to History
        // (a read-only slot per the substrate-floor doctrine note).
        for p in ContinualPrimitive::ALL.iter().copied() {
            let slot = p.slot();
            if p == ContinualPrimitive::SealDora {
                assert!(slot.is_read_only(), "SealDora's slot ({:?}) should be read-only", slot);
            } else {
                assert!(slot.is_writable(), "{:?}'s slot ({:?}) should be writable", p, slot);
            }
        }
    }
}
