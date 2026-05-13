//! HELIOS V5 — ResonanceGate decision actions (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-GATE-ACTION guard
//!
//! Per HELIOS v4 preservation `source_docs/epistenos_build_prompt.md`
//! §2.4 + §2.5 (`src/resonance/gate.rs` ResonanceGate spec).
//!
//! When the τ + π + λ (+ δ + ρ + κ + η Pro/Research extensions)
//! Σ-signature is computed for a token, the ResonanceGate returns
//! one of six canonical actions.
//!
//! ## Hard invariants (canonical)
//!
//! Per the build-prompt §2.4:
//!   1. **No τ = −1 reaches user** — τ = -1 (false) tokens MUST
//!      route to Quarantine, never to Pass.
//!   2. **Edge claims trigger Evidence Supremacy Protocol.**
//!   3. **Prime + ρ > 0.7 + κ > 0.382 → Engram anchor.**
//!   4. **Recursive self-monitoring with depth guard d_max = 3.**
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// Canonical maximum self-monitoring recursion depth (hard
/// invariant 4). Any decision path deeper than this triggers a
/// HALT-class violation.
pub const SELF_MONITORING_MAX_DEPTH: u32 = 3;

/// Canonical thresholds for the Engram-anchor invariant
/// (hard invariant 3). All three must hold simultaneously to
/// trigger an EngramAnchor action: prime classification + ρ
/// resonance > 0.7 + κ stability > 0.382.
pub const ENGRAM_RHO_THRESHOLD: f32 = 0.7;
pub const ENGRAM_KAPPA_THRESHOLD: f32 = 0.382;

/// One of six canonical actions the ResonanceGate can dispatch.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GateAction {
    /// Pass — token forwarded to user. Only allowed when
    /// τ ∈ {True, Possible}; NEVER when τ = False.
    Pass,
    /// Hold — pause until additional evidence or context arrives.
    Hold,
    /// Quarantine — block emission. Required when τ = False or
    /// the safety threshold is exceeded.
    Quarantine,
    /// TriggerEvidenceSupremacy — invoke the Evidence Supremacy
    /// Protocol per hard invariant 2 (edge-class claims).
    TriggerEvidenceSupremacy,
    /// EngramAnchor — promote to long-term Engram memory per
    /// hard invariant 3 (prime + ρ > 0.7 + κ > 0.382).
    EngramAnchor,
    /// MigrateResidency — move the underlying state up or down
    /// the L0..L4 + L_SE residency hierarchy.
    MigrateResidency,
}

/// All six gate actions in canonical doctrine order.
pub const SIX_ACTIONS: [GateAction; 6] = [
    GateAction::Pass,
    GateAction::Hold,
    GateAction::Quarantine,
    GateAction::TriggerEvidenceSupremacy,
    GateAction::EngramAnchor,
    GateAction::MigrateResidency,
];

impl GateAction {
    /// True when the action emits the token to the user (only
    /// `Pass`).
    pub fn emits_to_user(self) -> bool {
        matches!(self, GateAction::Pass)
    }

    /// True when the action blocks emission (Quarantine + Hold +
    /// TriggerEvidenceSupremacy all halt the pipeline pending
    /// further work).
    pub fn blocks_emission(self) -> bool {
        matches!(
            self,
            GateAction::Quarantine
                | GateAction::Hold
                | GateAction::TriggerEvidenceSupremacy
        )
    }

    /// True when the action records persistent state (Engram
    /// anchor or residency migration).
    pub fn records_persistent_state(self) -> bool {
        matches!(
            self,
            GateAction::EngramAnchor | GateAction::MigrateResidency
        )
    }
}

/// Verify hard invariant 3 thresholds: prime + ρ > 0.7 + κ > 0.382.
pub fn engram_anchor_predicate(is_prime: bool, rho: f32, kappa: f32) -> bool {
    is_prime
        && rho.is_finite()
        && rho > ENGRAM_RHO_THRESHOLD
        && kappa.is_finite()
        && kappa > ENGRAM_KAPPA_THRESHOLD
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn six_actions_listed_in_canonical_order() {
        assert_eq!(SIX_ACTIONS.len(), 6);
        assert_eq!(SIX_ACTIONS[0], GateAction::Pass);
        assert_eq!(SIX_ACTIONS[5], GateAction::MigrateResidency);
    }

    #[test]
    fn six_actions_are_distinct() {
        let set: std::collections::HashSet<GateAction> = SIX_ACTIONS.iter().copied().collect();
        assert_eq!(set.len(), 6);
    }

    #[test]
    fn only_pass_emits_to_user() {
        for action in SIX_ACTIONS {
            if action == GateAction::Pass {
                assert!(action.emits_to_user());
            } else {
                assert!(!action.emits_to_user());
            }
        }
    }

    #[test]
    fn three_actions_block_emission() {
        let blocking = SIX_ACTIONS
            .iter()
            .filter(|a| a.blocks_emission())
            .count();
        // Quarantine + Hold + TriggerEvidenceSupremacy = 3.
        assert_eq!(blocking, 3);
    }

    #[test]
    fn two_actions_record_persistent_state() {
        let persistent = SIX_ACTIONS
            .iter()
            .filter(|a| a.records_persistent_state())
            .count();
        // EngramAnchor + MigrateResidency = 2.
        assert_eq!(persistent, 2);
    }

    #[test]
    fn engram_anchor_predicate_matches_canonical_thresholds() {
        // ρ > 0.7 AND κ > 0.382 AND prime → true.
        assert!(engram_anchor_predicate(true, 0.71, 0.4));
        // ρ at exactly 0.7 → false (strict inequality).
        assert!(!engram_anchor_predicate(true, 0.7, 0.4));
        // κ at exactly 0.382 → false (strict inequality).
        assert!(!engram_anchor_predicate(true, 0.71, 0.382));
        // Not prime → false regardless of ρ + κ.
        assert!(!engram_anchor_predicate(false, 0.99, 0.99));
        // NaN → false.
        assert!(!engram_anchor_predicate(true, f32::NAN, 0.4));
        assert!(!engram_anchor_predicate(true, 0.71, f32::NAN));
    }

    #[test]
    fn self_monitoring_depth_max_is_3() {
        // Hard invariant 4 — d_max = 3.
        assert_eq!(SELF_MONITORING_MAX_DEPTH, 3);
    }

    #[test]
    fn engram_thresholds_match_canonical_doctrine() {
        assert_eq!(ENGRAM_RHO_THRESHOLD, 0.7);
        assert_eq!(ENGRAM_KAPPA_THRESHOLD, 0.382);
    }

    #[test]
    fn gate_action_serializes_in_snake_case() {
        for (action, expected) in [
            (GateAction::Pass, "\"pass\""),
            (GateAction::Hold, "\"hold\""),
            (GateAction::Quarantine, "\"quarantine\""),
            (GateAction::TriggerEvidenceSupremacy, "\"trigger_evidence_supremacy\""),
            (GateAction::EngramAnchor, "\"engram_anchor\""),
            (GateAction::MigrateResidency, "\"migrate_residency\""),
        ] {
            assert_eq!(serde_json::to_string(&action).unwrap(), expected);
        }
    }

    #[test]
    fn gate_action_round_trips_through_json() {
        for action in SIX_ACTIONS {
            let json = serde_json::to_string(&action).unwrap();
            let parsed: GateAction = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, action);
        }
    }

    /// Doctrine ↔ active-app `ApprovalDecision` gating-slice alignment.
    ///
    /// The active app's `agent_core::approval::ApprovalDecision` is a 3-way
    /// tool-approval verdict (AutoApprove / RequireApproval / Deny). HELIOS's
    /// `GateAction` is a 6-way token-emission + cognitive-memory verdict.
    /// The two enums describe DIFFERENT abstractions but partially overlap
    /// on a 3-variant "let it through / pause / block" axis:
    ///
    ///     ApprovalDecision::AutoApprove     ↔ GateAction::Pass
    ///     ApprovalDecision::RequireApproval ↔ GateAction::Hold
    ///     ApprovalDecision::Deny            ↔ GateAction::Quarantine
    ///
    /// The other three GateAction variants (TriggerEvidenceSupremacy,
    /// EngramAnchor, MigrateResidency) belong to the cognitive resonance
    /// gate and have no active-app analog yet.
    ///
    /// This test locks the SHAPE of the alignment, not Rust-level type
    /// equivalence (we can't link epistemos-research into agent_core).
    /// Drift gate: if either side renames a variant or adds/removes a
    /// gating-tier action, this test must be updated alongside the
    /// `ApprovalDecision` doctrine cross-reference comment in
    /// `agent_core/src/approval.rs`.
    #[test]
    fn active_app_approval_gating_subset_alignment() {
        // The three GateAction variants that correspond to ApprovalDecision
        // entries. Order must match the ApprovalDecision declaration order
        // in agent_core/src/approval.rs so future renames produce a clean
        // line-by-line diff.
        let approval_gating_slice = [
            ("AutoApprove",     GateAction::Pass),
            ("RequireApproval", GateAction::Hold),
            ("Deny",            GateAction::Quarantine),
        ];

        // Each mapped GateAction must be in the canonical SIX_ACTIONS list
        // (i.e. we didn't reference a renamed/removed variant).
        for (_, action) in approval_gating_slice {
            assert!(
                SIX_ACTIONS.contains(&action),
                "GateAction::{:?} mapped from ApprovalDecision must remain in SIX_ACTIONS",
                action
            );
        }

        // The semantics must be self-consistent:
        //   AutoApprove  →  Pass        (emits to user)
        //   RequireApproval → Hold      (blocks emission, pending evidence)
        //   Deny         →  Quarantine  (blocks emission, terminal)
        assert!(GateAction::Pass.emits_to_user());
        assert!(GateAction::Hold.blocks_emission());
        assert!(GateAction::Quarantine.blocks_emission());

        // Neither approval-tier action records persistent state; that's
        // exclusively HELIOS's memory-operation tier (EngramAnchor,
        // MigrateResidency).
        for (_, action) in approval_gating_slice {
            assert!(
                !action.records_persistent_state(),
                "ApprovalDecision-mapped {:?} must not record persistent state — \
                 those are HELIOS-only memory operations",
                action
            );
        }

        // Count invariant: exactly THREE GateActions correspond to the
        // 3-way ApprovalDecision enum. If either side grows or shrinks
        // its gating taxonomy, this number must move in lockstep.
        assert_eq!(approval_gating_slice.len(), 3);
        assert_eq!(SIX_ACTIONS.len() - approval_gating_slice.len(), 3,
            "remaining 3 GateActions must be the HELIOS-only memory tier \
             (TriggerEvidenceSupremacy, EngramAnchor, MigrateResidency)");
    }

    #[test]
    fn emits_blocks_persists_are_disjoint() {
        // Each action falls into exactly ONE category among:
        // emits_to_user / blocks_emission / records_persistent_state.
        for action in SIX_ACTIONS {
            let count = [
                action.emits_to_user(),
                action.blocks_emission(),
                action.records_persistent_state(),
            ]
            .iter()
            .filter(|&&b| b)
            .count();
            assert_eq!(count, 1, "{:?} should fit exactly one category", action);
        }
    }
}
