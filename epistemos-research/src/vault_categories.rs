//! HELIOS V5 — Lane 5 Speculative Vault category taxonomy
//! (Lane 3 RESEARCH-ONLY metadata about Lane 5 vault contents).
//!
//! HELIOS-VAULT-CATEGORIES guard
//!
//! Per `docs/fusion/helios v5 first.md` DOC 5 (Lane 5 Speculative
//! Vault). The vault has six canonical sections:
//!
//! - §5.1 Demoted EML branches (4 rows)
//! - §5.2 Architectural overclaims (4 rows; F7e, 1.1MB-seed, etc.)
//! - §5.3 SCOPE-Rex Gate Register "Do not build into Core/MAS"
//! - §5.4 T18-T35 from v4.2 catalog (vault rows)
//! - §5.5 Pro R&D items (Gate Register "build later")
//! - §5.6 Speculative-but-preserved
//!
//! ## Read-only banner (canonical)
//!
//! > ⚠️ **VAULT — READ ONLY.** Items here are preserved for
//! > traceability. **No re-promotion without an explicit
//! > falsifier** (specified per row). Modifying this file requires
//! > an integration-plan PR, not a normal commit.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY substrate-about-substrate. Building
//! requires `--features research`. The vault contents themselves
//! never ship in MAS.

use serde::{Deserialize, Serialize};

/// One of six canonical Lane 5 Speculative Vault sections.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VaultSection {
    /// §5.1 Demoted EML branches (4 rows).
    /// Per HELIOS v4 preservation; re-promotion falsifier specified per row.
    DemotedEmlBranches,
    /// §5.2 Architectural overclaims (4 rows).
    /// Includes F7e (full 8B → tiny tree, expected fail), 1.1MB
    /// seed completeness, EML-alone density, sparse-texture KV-tree.
    ArchitecturalOverclaims,
    /// §5.3 SCOPE-Rex Gate Register "Do not build into Core/MAS"
    /// rows. Private ANE APIs, hot-path Python, raw subprocesses,
    /// direct weight mutation, banned marketing language.
    DoNotBuildInCoreOrMas,
    /// §5.4 T18-T35 from v4.2 catalog (vault rows).
    /// Free-energy, optimal transport, Galois quotient, Cardano-
    /// Tartaglia, Pascal moments, persistent homology, tropical,
    /// grid cells, Solomonoff, HoTT, skyrmions, liquid vector,
    /// surface code, diffeology, operadic, condensed math, free
    /// probability, game semantics.
    T18T35V42Catalog,
    /// §5.5 Pro R&D items (Gate Register "build later").
    /// PSOFT adapter lab, OSFT consolidation, coSO FD sketch,
    /// DSC adapter composer, HCache/KVCrush, Brain Time Machine
    /// V1.5 semantic-first / Pro tensor-later.
    ProRdLater,
    /// §5.6 Speculative-but-preserved.
    /// "Five infinities same", Conway surreals, Spencer-Brown
    /// Laws of Form, Wolfram NKS, Mochizuki IUT, p-adic hot
    /// path, sheaf-as-attention, ANE private API exploration,
    /// M5 Ultra placeholder, PEER / Mixture-of-Recursions.
    SpeculativeButPreserved,
}

impl VaultSection {
    /// Section number (e.g. "§5.1") per the DOC 5 layout.
    pub fn section_label(self) -> &'static str {
        match self {
            VaultSection::DemotedEmlBranches => "§5.1",
            VaultSection::ArchitecturalOverclaims => "§5.2",
            VaultSection::DoNotBuildInCoreOrMas => "§5.3",
            VaultSection::T18T35V42Catalog => "§5.4",
            VaultSection::ProRdLater => "§5.5",
            VaultSection::SpeculativeButPreserved => "§5.6",
        }
    }

    /// True when items in this section MAY be actively worked
    /// on in `helios/research/*` branches per the canon-promotion
    /// protocol (§5.5 only).
    pub fn allows_active_research(self) -> bool {
        matches!(self, VaultSection::ProRdLater)
    }

    /// True when items in this section are explicitly BANNED from
    /// Core / MAS per the gate register (§5.3 only).
    pub fn is_explicitly_banned_from_mas(self) -> bool {
        matches!(self, VaultSection::DoNotBuildInCoreOrMas)
    }
}

/// All six vault sections in canonical doctrine order.
pub const SIX_VAULT_SECTIONS: [VaultSection; 6] = [
    VaultSection::DemotedEmlBranches,
    VaultSection::ArchitecturalOverclaims,
    VaultSection::DoNotBuildInCoreOrMas,
    VaultSection::T18T35V42Catalog,
    VaultSection::ProRdLater,
    VaultSection::SpeculativeButPreserved,
];

/// Re-promotion gate per the read-only banner. Returns true only
/// when a vault item carries an explicit re-promotion falsifier
/// AND the falsifier has been satisfied. Both are required.
pub fn re_promotion_allowed(
    has_explicit_falsifier: bool,
    falsifier_satisfied: bool,
) -> bool {
    has_explicit_falsifier && falsifier_satisfied
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn six_vault_sections_in_canonical_order() {
        assert_eq!(SIX_VAULT_SECTIONS.len(), 6);
        assert_eq!(SIX_VAULT_SECTIONS[0], VaultSection::DemotedEmlBranches);
        assert_eq!(SIX_VAULT_SECTIONS[5], VaultSection::SpeculativeButPreserved);
    }

    #[test]
    fn six_vault_sections_are_distinct() {
        let set: std::collections::HashSet<VaultSection> =
            SIX_VAULT_SECTIONS.iter().copied().collect();
        assert_eq!(set.len(), 6);
    }

    #[test]
    fn section_labels_follow_5_dot_n_pattern() {
        assert_eq!(VaultSection::DemotedEmlBranches.section_label(), "§5.1");
        assert_eq!(VaultSection::ArchitecturalOverclaims.section_label(), "§5.2");
        assert_eq!(VaultSection::DoNotBuildInCoreOrMas.section_label(), "§5.3");
        assert_eq!(VaultSection::T18T35V42Catalog.section_label(), "§5.4");
        assert_eq!(VaultSection::ProRdLater.section_label(), "§5.5");
        assert_eq!(VaultSection::SpeculativeButPreserved.section_label(), "§5.6");
    }

    #[test]
    fn only_pro_rd_later_allows_active_research() {
        for section in SIX_VAULT_SECTIONS {
            if section == VaultSection::ProRdLater {
                assert!(section.allows_active_research());
            } else {
                assert!(!section.allows_active_research());
            }
        }
    }

    #[test]
    fn only_do_not_build_in_core_or_mas_is_explicitly_banned() {
        for section in SIX_VAULT_SECTIONS {
            if section == VaultSection::DoNotBuildInCoreOrMas {
                assert!(section.is_explicitly_banned_from_mas());
            } else {
                assert!(!section.is_explicitly_banned_from_mas());
            }
        }
    }

    #[test]
    fn re_promotion_requires_both_falsifier_and_satisfaction() {
        assert!(!re_promotion_allowed(false, false));
        assert!(!re_promotion_allowed(false, true));
        assert!(!re_promotion_allowed(true, false));
        assert!(re_promotion_allowed(true, true));
    }

    #[test]
    fn vault_section_serializes_in_snake_case() {
        for (s, expected) in [
            (VaultSection::DemotedEmlBranches, "\"demoted_eml_branches\""),
            (VaultSection::ArchitecturalOverclaims, "\"architectural_overclaims\""),
            (VaultSection::DoNotBuildInCoreOrMas, "\"do_not_build_in_core_or_mas\""),
            (VaultSection::T18T35V42Catalog, "\"t18_t35_v42_catalog\""),
            (VaultSection::ProRdLater, "\"pro_rd_later\""),
            (VaultSection::SpeculativeButPreserved, "\"speculative_but_preserved\""),
        ] {
            assert_eq!(serde_json::to_string(&s).unwrap(), expected);
        }
    }

    #[test]
    fn vault_section_round_trips_through_json() {
        for s in SIX_VAULT_SECTIONS {
            let json = serde_json::to_string(&s).unwrap();
            let parsed: VaultSection = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, s);
        }
    }

    #[test]
    fn allows_research_and_explicitly_banned_are_disjoint() {
        // §5.5 (research-allowed) and §5.3 (explicitly-banned)
        // are mutually exclusive — a section can't be both.
        for s in SIX_VAULT_SECTIONS {
            assert!(!(s.allows_active_research() && s.is_explicitly_banned_from_mas()));
        }
    }
}
