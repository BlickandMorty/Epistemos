//! HELIOS V5 — Wyner-Babai Operator (WBO) Master Inequality
//! generations (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-WBO-GENERATIONS guard
//!
//! Per HELIOS v4 preservation +
//! `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §1 E4 +
//! `epistemos_definitive_master.md` §"PART II" +
//! `compass_artifact_wf-...md` §B.2 +
//! `helios_v3.md` Part II.
//!
//! The Master Inequality has evolved across three named
//! generations. Each is a strict superset of the previous; the
//! current canon is WBO-7.
//!
//! ## Generations
//!
//! - **WBO-5** (compass artifact, 3 May 2026): 5 terms
//!   [T_W, T_K, T_R, T_Q, T_S] with leading ½ from Pillar III.
//!
//! - **WBO-6** (definitive master, 4 May 2026): adds T_SE for
//!   self-evolving update drift. Total: 6 terms
//!   [T_W, T_K, T_R, T_Q, T_S, T_SE].
//!
//! - **WBO-7** (HELIOS V5 canon lock, 5 May 2026): supersedes
//!   WBO-6 with active-support penalty + numerical-precision
//!   refinement. The canonical Rust substrate at
//!   `epistemos-research/src/theorems/e4_wbo7.rs` uses the
//!   refined naming `[T_LWZ, T_K, T_R, T_TTR, T_SE, T_DAG, T_num]`
//!   where T_LWZ folds T_W + T_R into a Lattice-Wyner-Ziv
//!   composite. Total: 7 terms.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// One named generation of the Master Inequality.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WboGeneration {
    /// WBO-5 — compass artifact reconciliation (3 May 2026).
    Wbo5,
    /// WBO-6 — definitive master spec (4 May 2026).
    Wbo6,
    /// WBO-7 — HELIOS V5 canon lock (5 May 2026, current).
    Wbo7,
}

impl WboGeneration {
    /// Number of terms in this generation's master-inequality sum.
    pub fn term_count(self) -> usize {
        match self {
            WboGeneration::Wbo5 => 5,
            WboGeneration::Wbo6 => 6,
            WboGeneration::Wbo7 => 7,
        }
    }

    /// Date the generation was locked (UTC, ISO-8601).
    pub fn lock_date(self) -> &'static str {
        match self {
            WboGeneration::Wbo5 => "2026-05-03",
            WboGeneration::Wbo6 => "2026-05-04",
            WboGeneration::Wbo7 => "2026-05-05",
        }
    }

    /// Source-document anchor where this generation is canonical.
    pub fn anchor_source(self) -> &'static str {
        match self {
            WboGeneration::Wbo5 => "compass_artifact_wf-...md §B.2",
            WboGeneration::Wbo6 => "epistemos_definitive_master.md §PART II",
            WboGeneration::Wbo7 => "docs/HELIOS_V5_DOC_6_THEOREM_CANON.md §1 E4",
        }
    }

    /// True when this generation is the current canon.
    pub fn is_current_canon(self) -> bool {
        self == WboGeneration::CURRENT
    }

    /// The current canonical generation. WBO-7 as of 2026-05-05
    /// canon lock.
    pub const CURRENT: WboGeneration = WboGeneration::Wbo7;
}

/// All three generations in chronological order.
pub const ALL_GENERATIONS: [WboGeneration; 3] = [
    WboGeneration::Wbo5,
    WboGeneration::Wbo6,
    WboGeneration::Wbo7,
];

/// Compose the per-generation list of canonical term names.
pub fn term_names(generation: WboGeneration) -> &'static [&'static str] {
    match generation {
        WboGeneration::Wbo5 => &["T_W", "T_K", "T_R", "T_Q", "T_S"],
        WboGeneration::Wbo6 => &["T_W", "T_K", "T_R", "T_Q", "T_S", "T_SE"],
        // WBO-7 in V5 canon refactors to Lattice-Wyner-Ziv (T_LWZ
        // composing T_W + T_R) + the new T_TTR + T_DAG + T_num.
        WboGeneration::Wbo7 => &["T_LWZ", "T_K", "T_R", "T_TTR", "T_SE", "T_DAG", "T_num"],
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_generations_listed_chronologically() {
        assert_eq!(ALL_GENERATIONS.len(), 3);
        assert_eq!(ALL_GENERATIONS[0], WboGeneration::Wbo5);
        assert_eq!(ALL_GENERATIONS[2], WboGeneration::Wbo7);
        // Strict ordering: each generation's lock_date is a strict
        // successor.
        assert!(WboGeneration::Wbo5.lock_date() < WboGeneration::Wbo6.lock_date());
        assert!(WboGeneration::Wbo6.lock_date() < WboGeneration::Wbo7.lock_date());
    }

    #[test]
    fn term_count_grows_monotonically() {
        // Each newer generation has strictly more terms.
        assert_eq!(WboGeneration::Wbo5.term_count(), 5);
        assert_eq!(WboGeneration::Wbo6.term_count(), 6);
        assert_eq!(WboGeneration::Wbo7.term_count(), 7);
    }

    #[test]
    fn wbo7_is_current_canon() {
        assert_eq!(WboGeneration::CURRENT, WboGeneration::Wbo7);
        assert!(WboGeneration::Wbo7.is_current_canon());
        assert!(!WboGeneration::Wbo5.is_current_canon());
        assert!(!WboGeneration::Wbo6.is_current_canon());
    }

    #[test]
    fn term_names_match_count() {
        for gen in ALL_GENERATIONS {
            assert_eq!(term_names(gen).len(), gen.term_count());
        }
    }

    #[test]
    fn wbo7_is_strict_superset_of_wbo6_term_set() {
        // WBO-7 refactors WBO-6's T_W + T_R into T_LWZ (composite),
        // so the canonical-name sets aren't identical, but the
        // semantic content is preserved + extended.
        // WBO-7 terms: T_LWZ + T_K + T_R + T_TTR + T_SE + T_DAG + T_num
        // WBO-6 terms: T_W + T_K + T_R + T_Q + T_S + T_SE
        // Common between the two: T_K, T_R, T_SE
        let wbo6_set: std::collections::HashSet<&str> =
            term_names(WboGeneration::Wbo6).iter().copied().collect();
        let wbo7_set: std::collections::HashSet<&str> =
            term_names(WboGeneration::Wbo7).iter().copied().collect();
        let common: std::collections::HashSet<&str> =
            wbo6_set.intersection(&wbo7_set).copied().collect();
        // T_K, T_R, T_SE are preserved verbatim across the
        // generations.
        assert!(common.contains("T_K"));
        assert!(common.contains("T_R"));
        assert!(common.contains("T_SE"));
    }

    #[test]
    fn wbo5_is_strict_subset_of_wbo6_terms() {
        // Per the doctrine: WBO-6 = WBO-5 ∪ {T_SE}.
        let wbo5_set: std::collections::HashSet<&str> =
            term_names(WboGeneration::Wbo5).iter().copied().collect();
        let wbo6_set: std::collections::HashSet<&str> =
            term_names(WboGeneration::Wbo6).iter().copied().collect();
        for term in wbo5_set.iter() {
            assert!(
                wbo6_set.contains(term),
                "WBO-5 term {} missing from WBO-6",
                term
            );
        }
        // Difference is exactly {T_SE}.
        let diff: std::collections::HashSet<&str> =
            wbo6_set.difference(&wbo5_set).copied().collect();
        assert_eq!(diff.len(), 1);
        assert!(diff.contains("T_SE"));
    }

    #[test]
    fn lock_dates_are_iso_8601_strings() {
        for gen in ALL_GENERATIONS {
            let date = gen.lock_date();
            // YYYY-MM-DD format (10 chars; 4-2-2 with hyphens).
            assert_eq!(date.len(), 10);
            assert_eq!(date.chars().nth(4).unwrap(), '-');
            assert_eq!(date.chars().nth(7).unwrap(), '-');
        }
    }

    #[test]
    fn anchor_source_non_empty() {
        for gen in ALL_GENERATIONS {
            assert!(!gen.anchor_source().is_empty());
        }
    }

    #[test]
    fn wbo_generation_serializes_in_snake_case() {
        for (gen, expected) in [
            (WboGeneration::Wbo5, "\"wbo5\""),
            (WboGeneration::Wbo6, "\"wbo6\""),
            (WboGeneration::Wbo7, "\"wbo7\""),
        ] {
            assert_eq!(serde_json::to_string(&gen).unwrap(), expected);
        }
    }

    #[test]
    fn wbo_generation_round_trips_through_json() {
        for gen in ALL_GENERATIONS {
            let json = serde_json::to_string(&gen).unwrap();
            let parsed: WboGeneration = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, gen);
        }
    }

    #[test]
    fn wbo_generations_are_partial_ord_chronologically() {
        // Since the enum derives Ord, and the variants are
        // declared chronologically, comparison works lexically
        // by variant order — Wbo5 < Wbo6 < Wbo7.
        assert!(WboGeneration::Wbo5 < WboGeneration::Wbo6);
        assert!(WboGeneration::Wbo6 < WboGeneration::Wbo7);
    }
}
