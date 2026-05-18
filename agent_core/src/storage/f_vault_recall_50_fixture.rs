//! F-VaultRecall-50 fixture — canonical regression set for the Epistemos
//! vault retrieval contract.
//!
//! Each row is a (query, expected_paths, forbidden_paths, category) tuple
//! that the vault retrieval ladder must handle correctly for the
//! "first 7 irrelevant notes" failure to remain structurally impossible.
//! The fixture is the load-bearing F-VaultRecall-50 falsifier for the
//! M2 Pro hardware floor; it does NOT exercise retrieval here (that's
//! per-iter integration work) — it stages the typed contract so future
//! iters can wire it to the Settings → Diagnostics → "Vault recall health"
//! row (W-21) and the Brain Panel "Retrieved by" surface.
//!
//! Cross-references:
//! - `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` (root diagnosis)
//! - `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T21
//!   ("F-VaultRecall-50 fixture visible in diagnostics")
//! - `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` W-21
//!   (Settings → Diagnostics → "Vault recall health" row)
//! - `docs/fusion/DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md` 1:15 PM scene

use serde::Serialize;

/// Categorical bucket for a fixture row. Used by the diagnostics surface
/// to break down pass rate per query class so the user can see which
/// failure modes regressed without scanning all 50 rows.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
pub enum FVaultRecallCategory {
    /// User query with chatty prefix; signal terms are well-formed.
    /// Canonical example: "Pull my notes on residency governance".
    ChattyPrefix,
    /// User query without any chatter, just topical terms.
    SignalOnly,
    /// User query is entirely chatter (e.g. "show me my notes").
    /// Contract: ladder must defer or broaden, never silently return
    /// arbitrary index-order notes.
    PureChatter,
    /// Paraphrase: user terms don't exactly match doc terms.
    /// Lexical-only retrieval fails; semantic / fusion must save it.
    Paraphrase,
    /// Synthesis: correct answer requires citing 2+ notes.
    Synthesis,
    /// Adversarial: the docs lexically match chatter; correct answer
    /// requires semantic / graph signals.
    Adversarial,
    /// Unicode / non-ASCII query.
    Unicode,
}

/// One canonical row in the F-VaultRecall-50 set.
///
/// `&'static str` everywhere so the entire fixture lives in `.rodata`
/// and can be embedded into the Settings diagnostics surface with no
/// allocation or IO. Future overlay sources (e.g. power-user custom
/// fixtures from a JSON file in `~/.epistemos/`) wrap this type in
/// an owned variant rather than complicating the canonical case.
#[derive(Debug, Clone, Serialize)]
pub struct FVaultRecallRow {
    /// The user-facing query string fed to the retrieval ladder.
    pub query: &'static str,
    /// Vault paths that MUST appear in the top-`top_n` result set for
    /// this row to pass (must-contain). At least one is required.
    pub expected_paths: &'static [&'static str],
    /// Vault paths that MUST NOT appear in the top-`top_n` result set.
    /// For the canonical 1:15 PM scene this is the "first 7 irrelevant
    /// notes" set (UI design, Hermes branding, character DNA specs,
    /// user_hardware.md) that the original bug surfaced.
    pub forbidden_paths: &'static [&'static str],
    /// The query category, used by the diagnostics breakdown.
    pub category: FVaultRecallCategory,
    /// Top-N window the contract applies to. The canonical bug
    /// requires the expected paths to be in the top 7.
    pub top_n: usize,
    /// Free-form note for humans reading the fixture diff.
    pub note: &'static str,
}

/// The 50-row F-VaultRecall fixture. The full row set will grow one row
/// per iter so each addition is reviewable in isolation; this stub seeds
/// the canonical Day-in-the-Life 1:15 PM scene so the loader contract is
/// in place from iter-2 forward.
pub const F_VAULT_RECALL_50_FIXTURE: &[FVaultRecallRow] = &[
    FVaultRecallRow {
        query: "Pull my notes on residency governance",
        expected_paths: &["MASTER_FUSION/3_2_residency_governor.md"],
        forbidden_paths: &[
            "ui/hermes_branding.md",
            "ui/character_dna_specs.md",
            "user_hardware.md",
        ],
        category: FVaultRecallCategory::ChattyPrefix,
        top_n: 7,
        note: "Day-in-the-Life 1:15 PM canonical bug — chatty prefix must \
               be stripped (Fix B, shipped iter 81) and BM25 scores must \
               be raw so the floor ladder works (Fix C, shipped iter b812ba618). \
               Residency-governance notes must outrank UI/branding/hardware \
               chatter. This is THE row that the entire T21 mission exists \
               to make pass.",
    },
];

/// Load the canonical fixture. Returns the static slice in a typed wrapper
/// so future iters can extend with a JSON file overlay (for power-user
/// custom fixtures) without breaking the public signature.
pub fn load_canonical() -> &'static [FVaultRecallRow] {
    F_VAULT_RECALL_50_FIXTURE
}

/// Total row count, exposed so diagnostics can render "12 / 50 passing"
/// or similar without re-counting. Constant-eval'd at compile time.
pub const fn fixture_size() -> usize {
    F_VAULT_RECALL_50_FIXTURE.len()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The fixture must have at least one row (the canonical 1:15 PM
    /// scene) at all times. Future rows are added one at a time per
    /// the T21 iter cadence; this floor never goes to zero.
    #[test]
    fn fixture_has_at_least_canonical_row() {
        let fixture = load_canonical();
        assert!(
            !fixture.is_empty(),
            "F-VaultRecall-50 fixture must have ≥ 1 row"
        );
        assert_eq!(fixture.len(), fixture_size());
    }

    /// Structural invariant: every row must have a non-empty query and
    /// ≥ 1 expected_path. An empty expected_paths means "no positive
    /// contract" — that's not a meaningful regression row and must not
    /// land in the fixture even temporarily.
    #[test]
    fn every_row_has_non_empty_query_and_expectation() {
        for row in load_canonical() {
            assert!(
                !row.query.is_empty(),
                "fixture row has empty query: {:?}",
                row
            );
            assert!(
                !row.expected_paths.is_empty(),
                "fixture row has no expected_paths: query={:?}",
                row.query
            );
            assert!(row.top_n > 0, "top_n must be positive: {:?}", row);
        }
    }

    /// Canonical 1:15 PM scene must be present. This is the load-bearing
    /// regression — the entire T21 mission exists to make this row pass,
    /// so it must remain in the fixture from iter-2 forward.
    #[test]
    fn canonical_residency_governance_row_present() {
        let found = load_canonical()
            .iter()
            .any(|row| row.query == "Pull my notes on residency governance");
        assert!(
            found,
            "F-VaultRecall-50 must contain the canonical 1:15 PM scene query"
        );
    }

    /// `forbidden_paths` and `expected_paths` must not overlap on any row —
    /// a path cannot simultaneously be required and forbidden. Catches
    /// future-iter copy-paste mistakes before they confuse diagnostics.
    #[test]
    fn forbidden_and_expected_paths_are_disjoint_per_row() {
        for row in load_canonical() {
            for forbidden in row.forbidden_paths {
                assert!(
                    !row.expected_paths.contains(forbidden),
                    "row {:?} has path in both expected and forbidden: {}",
                    row.query,
                    forbidden
                );
            }
        }
    }

    /// Every row must serialize to JSON cleanly. The Settings diagnostics
    /// surface (W-21) will render fixture results as JSON to the Brain
    /// Panel; this test pins the serialize-side of that contract. The
    /// deserialize-side lands when the JSON overlay (power-user custom
    /// fixtures from `~/.epistemos/`) is wired in a later iter via a
    /// separate `FVaultRecallRowOwned` type.
    #[test]
    fn fixture_rows_serialize_to_json() {
        for row in load_canonical() {
            let encoded = serde_json::to_string(row).expect("serialize");
            assert!(
                encoded.contains(row.query),
                "encoded JSON missing query {:?}: {}",
                row.query,
                encoded
            );
            assert!(
                encoded.contains("expected_paths"),
                "encoded JSON missing expected_paths field: {}",
                encoded
            );
        }
    }
}
