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
    pub const fn code(self) -> &'static str {
        match self {
            TransitionGuard::None => "none",
            TransitionGuard::SignatureValid => "g1_signature_valid",
            TransitionGuard::EligibilityGreen => "g2_eligibility_green",
            TransitionGuard::RunnerAdmitted => "g3_runner_admitted",
            TransitionGuard::UserAck => "g4_user_ack",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TransitionError {
    IllegalTransition { from: LiveFileState, to: LiveFileState },
    GuardFailed { from: LiveFileState, to: LiveFileState, guard: TransitionGuard },
    RevokedIsTerminal,
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
