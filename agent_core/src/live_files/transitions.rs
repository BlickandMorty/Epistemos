//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.6.11 — 10-state Live-File state machine:
//!   `Static → LiveCandidate → Compiled (signed) → Eligible → Running →
//!    {Paused / Completed / Quarantined} → Suspended → Eligible;
//!    Revoked = kill switch`.
//! - Companion to [`super::LiveFileState`] (the 10-variant enum).
//!
//! # Wave J B.6.11 — Live-File transition graph
//!
//! The enum sits next to this module; this module owns the **edge
//! set** — which `(from, to)` pairs the runtime is allowed to
//! perform, and what guard each edge requires.
//!
//! Guard taxonomy (G1-G4 per FINAL_SYNTHESIS §4):
//! - **G1 SignatureValid** — the LivePlan's signature verifies under
//!   the user's local key.
//! - **G2 EligibilityGreen** — triggers + thermal + battery + budget
//!   all green per [`super::LivePlanEligibility`].
//! - **G3 RunnerAdmitted** — runner has capacity + the plan's
//!   intent slot is available.
//! - **G4 UserAck** — Quarantined state requires explicit user
//!   acknowledgment before transitioning out.
//!
//! Revoked is the kill switch — accepts inbound edges from every
//! other state but emits no outbound edges (one-way terminal).
//!
//! `kani` formal verification (per FINAL_SYNTHESIS §4 invariants —
//! "no orphan states, no unreachable states, no race conditions on
//! transition") is the F-Live-File-Verify falsifier; lands once
//! `cargo kani` is added to the CI matrix (NOT-STARTED, deferred).

use super::LiveFileState;
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum TransitionGuard {
    /// No guard — the edge is always legal when the source state is
    /// what it claims.
    None,
    /// G1: the LivePlan's signature verifies.
    SignatureValid,
    /// G2: triggers + thermal + battery + budget all green.
    EligibilityGreen,
    /// G3: runner has capacity + intent slot available.
    RunnerAdmitted,
    /// G4: explicit user acknowledgment.
    UserAck,
}

impl TransitionGuard {
    pub const ALL: [TransitionGuard; 5] = [
        TransitionGuard::None,
        TransitionGuard::SignatureValid,
        TransitionGuard::EligibilityGreen,
        TransitionGuard::RunnerAdmitted,
        TransitionGuard::UserAck,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            TransitionGuard::None => "none",
            TransitionGuard::SignatureValid => "g1_signature_valid",
            TransitionGuard::EligibilityGreen => "g2_eligibility_green",
            TransitionGuard::RunnerAdmitted => "g3_runner_admitted",
            TransitionGuard::UserAck => "g4_user_ack",
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|g| g.code() == code)
    }

    /// Predicate: this guard requires no caller witness — the edge
    /// is unconditionally legal when the source state matches.
    pub const fn is_none_guard(self) -> bool {
        matches!(self, TransitionGuard::None)
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TransitionError {
    IllegalTransition { from: LiveFileState, to: LiveFileState },
    GuardFailed { from: LiveFileState, to: LiveFileState, guard: TransitionGuard },
    RevokedIsTerminal,
}

impl TransitionError {
    pub const fn is_illegal_edge(&self) -> bool {
        matches!(self, TransitionError::IllegalTransition { .. })
    }

    pub const fn is_guard_failed(&self) -> bool {
        matches!(self, TransitionError::GuardFailed { .. })
    }

    pub const fn is_terminal_source(&self) -> bool {
        matches!(self, TransitionError::RevokedIsTerminal)
    }
}

/// Predicate: `(from, to)` is a legal edge in the transition graph.
/// Cross-surface invariant: `is_legal_edge(f, t) iff guard_for(f, t).is_some()`.
pub fn is_legal_edge(from: LiveFileState, to: LiveFileState) -> bool {
    guard_for(from, to).is_some()
}

/// All `(target_state, guard)` pairs reachable from `from` in one step.
/// Cross-surface invariant: `outbound_edges(Revoked).is_empty()` per
/// the §5 "Revoked is one-way terminal" doctrine.
pub fn outbound_edges(from: LiveFileState) -> Vec<(LiveFileState, TransitionGuard)> {
    LiveFileState::ALL
        .iter()
        .copied()
        .filter_map(|to| guard_for(from, to).map(|g| (to, g)))
        .collect()
}

/// All `(source_state, guard)` pairs that can transition INTO `to`.
/// Cross-surface invariant: `inbound_edges(Revoked).len() == 9` —
/// every non-Revoked state has an edge into Revoked.
pub fn inbound_edges(to: LiveFileState) -> Vec<(LiveFileState, TransitionGuard)> {
    LiveFileState::ALL
        .iter()
        .copied()
        .filter_map(|from| guard_for(from, to).map(|g| (from, g)))
        .collect()
}

/// Return the guard required to transition `from → to`, or `None` if
/// the edge is illegal.
pub fn guard_for(from: LiveFileState, to: LiveFileState) -> Option<TransitionGuard> {
    use LiveFileState::*;
    match (from, to) {
        // Revoked terminal — only inbound from every other state.
        (Revoked, _) => None,
        (_, Revoked) => Some(TransitionGuard::UserAck),

        // Main happy path.
        (Static, LiveCandidate) => Some(TransitionGuard::None),
        (LiveCandidate, Compiled) => Some(TransitionGuard::SignatureValid),
        (LiveCandidate, Static) => Some(TransitionGuard::None),
        (Compiled, Eligible) => Some(TransitionGuard::EligibilityGreen),
        (Compiled, LiveCandidate) => Some(TransitionGuard::None),
        (Eligible, Running) => Some(TransitionGuard::RunnerAdmitted),
        (Eligible, Compiled) => Some(TransitionGuard::None),

        // Mid-run forks.
        (Running, Paused) => Some(TransitionGuard::None),
        (Running, Completed) => Some(TransitionGuard::None),
        (Running, Quarantined) => Some(TransitionGuard::None),

        // Resume from Paused.
        (Paused, Running) => Some(TransitionGuard::RunnerAdmitted),
        (Paused, Suspended) => Some(TransitionGuard::None),

        // Completed/Quarantined → Suspended (awaiting next trigger).
        (Completed, Suspended) => Some(TransitionGuard::None),
        (Quarantined, Suspended) => Some(TransitionGuard::UserAck),

        // Suspended → Eligible (re-trigger).
        (Suspended, Eligible) => Some(TransitionGuard::EligibilityGreen),

        _ => None,
    }
}

/// Attempt to transition. `guard_passes` is the caller's witness that
/// the required guard has been verified. Returns the new state or an
/// error describing why the transition failed.
pub fn attempt_transition(
    from: LiveFileState,
    to: LiveFileState,
    guard_passes: bool,
) -> Result<LiveFileState, TransitionError> {
    if from == LiveFileState::Revoked {
        return Err(TransitionError::RevokedIsTerminal);
    }
    let guard = guard_for(from, to).ok_or(TransitionError::IllegalTransition { from, to })?;
    if guard != TransitionGuard::None && !guard_passes {
        return Err(TransitionError::GuardFailed { from, to, guard });
    }
    Ok(to)
}

#[cfg(test)]
mod tests {
    use super::*;
    use LiveFileState::*;

    #[test]
    fn five_distinct_guards() {
        let s: std::collections::HashSet<_> = [
            TransitionGuard::None,
            TransitionGuard::SignatureValid,
            TransitionGuard::EligibilityGreen,
            TransitionGuard::RunnerAdmitted,
            TransitionGuard::UserAck,
        ]
        .iter()
        .copied()
        .collect();
        assert_eq!(s.len(), 5);
    }

    #[test]
    fn guard_codes_stable() {
        assert_eq!(TransitionGuard::None.code(), "none");
        assert_eq!(TransitionGuard::SignatureValid.code(), "g1_signature_valid");
        assert_eq!(TransitionGuard::EligibilityGreen.code(), "g2_eligibility_green");
        assert_eq!(TransitionGuard::RunnerAdmitted.code(), "g3_runner_admitted");
        assert_eq!(TransitionGuard::UserAck.code(), "g4_user_ack");
    }

    #[test]
    fn static_to_live_candidate_allowed_with_no_guard() {
        let r = attempt_transition(Static, LiveCandidate, false).unwrap();
        assert_eq!(r, LiveCandidate);
    }

    #[test]
    fn live_candidate_to_compiled_requires_signature() {
        let err = attempt_transition(LiveCandidate, Compiled, false).unwrap_err();
        assert_eq!(
            err,
            TransitionError::GuardFailed {
                from: LiveCandidate,
                to: Compiled,
                guard: TransitionGuard::SignatureValid,
            }
        );
        let ok = attempt_transition(LiveCandidate, Compiled, true).unwrap();
        assert_eq!(ok, Compiled);
    }

    #[test]
    fn compiled_to_eligible_requires_eligibility_green() {
        assert!(attempt_transition(Compiled, Eligible, false).is_err());
        assert_eq!(
            attempt_transition(Compiled, Eligible, true).unwrap(),
            Eligible
        );
    }

    #[test]
    fn eligible_to_running_requires_runner_admitted() {
        assert!(attempt_transition(Eligible, Running, false).is_err());
        assert_eq!(
            attempt_transition(Eligible, Running, true).unwrap(),
            Running
        );
    }

    #[test]
    fn running_to_three_forks_unguarded() {
        for &fork in &[Paused, Completed, Quarantined] {
            let r = attempt_transition(Running, fork, false).unwrap();
            assert_eq!(r, fork);
        }
    }

    #[test]
    fn paused_to_running_requires_admit() {
        assert!(attempt_transition(Paused, Running, false).is_err());
        assert!(attempt_transition(Paused, Running, true).is_ok());
    }

    #[test]
    fn completed_to_suspended_unguarded() {
        let r = attempt_transition(Completed, Suspended, false).unwrap();
        assert_eq!(r, Suspended);
    }

    #[test]
    fn quarantined_to_suspended_requires_user_ack() {
        assert!(attempt_transition(Quarantined, Suspended, false).is_err());
        assert!(attempt_transition(Quarantined, Suspended, true).is_ok());
    }

    #[test]
    fn suspended_to_eligible_requires_eligibility_green() {
        assert!(attempt_transition(Suspended, Eligible, false).is_err());
        assert!(attempt_transition(Suspended, Eligible, true).is_ok());
    }

    #[test]
    fn any_state_to_revoked_requires_user_ack() {
        for &state in &[Static, LiveCandidate, Compiled, Eligible, Running, Paused, Completed, Quarantined, Suspended] {
            let err = attempt_transition(state, Revoked, false).unwrap_err();
            assert!(matches!(err, TransitionError::GuardFailed { guard: TransitionGuard::UserAck, .. }));
            assert!(attempt_transition(state, Revoked, true).is_ok());
        }
    }

    #[test]
    fn revoked_is_terminal_no_outbound() {
        for &to in &[Static, LiveCandidate, Compiled, Eligible, Running, Paused, Completed, Quarantined, Suspended] {
            let err = attempt_transition(Revoked, to, true).unwrap_err();
            assert_eq!(err, TransitionError::RevokedIsTerminal);
        }
    }

    #[test]
    fn illegal_skip_static_to_running_rejected() {
        let err = attempt_transition(Static, Running, true).unwrap_err();
        assert_eq!(
            err,
            TransitionError::IllegalTransition { from: Static, to: Running }
        );
    }

    #[test]
    fn illegal_completed_to_running_rejected() {
        let err = attempt_transition(Completed, Running, true).unwrap_err();
        assert!(matches!(err, TransitionError::IllegalTransition { .. }));
    }

    #[test]
    fn guard_for_returns_none_for_illegal_edges() {
        assert!(guard_for(Static, Running).is_none());
        assert!(guard_for(Completed, Running).is_none());
        assert!(guard_for(Revoked, Static).is_none());
    }

    // ── diagnostic surface (iter 146) ────────────────────────────────────────

    #[test]
    fn guard_all_includes_five_distinct() {
        let s: std::collections::HashSet<_> = TransitionGuard::ALL.iter().copied().collect();
        assert_eq!(s.len(), 5);
    }

    #[test]
    fn guard_from_code_roundtrips_all() {
        // Cross-surface invariant: from_code(g.code()) == Some(g) for all guards.
        for g in TransitionGuard::ALL.iter().copied() {
            assert_eq!(TransitionGuard::from_code(g.code()), Some(g));
        }
    }

    #[test]
    fn guard_from_code_unknown_returns_none() {
        assert_eq!(TransitionGuard::from_code("not-a-guard"), None);
        assert_eq!(TransitionGuard::from_code("G1"), None); // case-sensitive
    }

    #[test]
    fn is_none_guard_only_for_none() {
        for g in TransitionGuard::ALL.iter().copied() {
            assert_eq!(g.is_none_guard(), g == TransitionGuard::None);
        }
    }

    #[test]
    fn is_legal_edge_matches_guard_for() {
        // Cross-surface invariant: is_legal_edge(f, t) iff guard_for(f, t).is_some()
        for f in LiveFileState::ALL.iter().copied() {
            for t in LiveFileState::ALL.iter().copied() {
                assert_eq!(is_legal_edge(f, t), guard_for(f, t).is_some());
            }
        }
    }

    #[test]
    fn outbound_edges_revoked_is_empty() {
        // §5 invariant: Revoked has no outbound edges (one-way terminal).
        assert!(outbound_edges(Revoked).is_empty());
    }

    #[test]
    fn inbound_edges_revoked_covers_nine_states() {
        // §5 invariant: every non-Revoked state has an edge into Revoked.
        let inbound = inbound_edges(Revoked);
        assert_eq!(inbound.len(), 9);
        for (_, g) in &inbound {
            assert_eq!(*g, TransitionGuard::UserAck);
        }
        assert!(!inbound.iter().any(|(f, _)| *f == Revoked));
    }

    #[test]
    fn outbound_inbound_sum_invariant() {
        // Cross-surface invariant: the sum of |outbound_edges| over all
        // states equals the sum of |inbound_edges| over all states —
        // each edge is counted once in each direction.
        let outbound_total: usize = LiveFileState::ALL
            .iter()
            .map(|s| outbound_edges(*s).len())
            .sum();
        let inbound_total: usize = LiveFileState::ALL
            .iter()
            .map(|s| inbound_edges(*s).len())
            .sum();
        assert_eq!(outbound_total, inbound_total);
    }

    #[test]
    fn no_orphan_states_every_state_has_inbound_or_is_initial() {
        // §4 invariant (FINAL_SYNTHESIS): no orphan states. Every
        // non-Static state must have at least one inbound edge.
        for s in LiveFileState::ALL.iter().copied() {
            if s == Static {
                continue; // Static is the initial state — no inbound required.
            }
            assert!(!inbound_edges(s).is_empty(), "orphan state {:?}", s);
        }
    }

    #[test]
    fn attempt_transition_alignment_with_is_legal_edge() {
        // Cross-surface invariant: attempt_transition(f, t, true).is_ok()
        // iff f != Revoked AND is_legal_edge(f, t).
        for f in LiveFileState::ALL.iter().copied() {
            for t in LiveFileState::ALL.iter().copied() {
                let expected = f != Revoked && is_legal_edge(f, t);
                let got = attempt_transition(f, t, true).is_ok();
                assert_eq!(got, expected, "{:?} → {:?}", f, t);
            }
        }
    }

    #[test]
    fn transition_error_classifiers_partition() {
        let illegal = TransitionError::IllegalTransition { from: Static, to: Running };
        let failed = TransitionError::GuardFailed {
            from: LiveCandidate,
            to: Compiled,
            guard: TransitionGuard::SignatureValid,
        };
        let terminal = TransitionError::RevokedIsTerminal;
        // Cross-surface invariant: exactly one of the three predicates
        // is true for any TransitionError variant.
        for e in [illegal, failed, terminal] {
            let trio = [e.is_illegal_edge(), e.is_guard_failed(), e.is_terminal_source()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", e);
        }
    }

    #[test]
    fn happy_path_walks_full_lifecycle() {
        let s = attempt_transition(Static, LiveCandidate, true).unwrap();
        let s = attempt_transition(s, Compiled, true).unwrap();
        let s = attempt_transition(s, Eligible, true).unwrap();
        let s = attempt_transition(s, Running, true).unwrap();
        let s = attempt_transition(s, Completed, true).unwrap();
        let s = attempt_transition(s, Suspended, true).unwrap();
        let s = attempt_transition(s, Eligible, true).unwrap();
        let s = attempt_transition(s, Running, true).unwrap();
        let s = attempt_transition(s, Revoked, true).unwrap();
        assert_eq!(s, Revoked);
    }
}
