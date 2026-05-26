//! `AdmissionRepairLoop` — consumes
//! [`crate::acs_admission::ACSAdmissionVerdict`] to gate model drafts
//! against the production ACS policy. Defer → repair with policy hint;
//! Allow / AllowWithWarning → accept; Quarantine / Reject → terminal
//! quarantine (per ACSAdmissionVerdict::is_terminal).

use crate::acs_admission::ACSAdmissionVerdict;

use super::{HyperdynamicLoop, RepairVerdict};

/// Outcome of one ACS admission call attached to whatever the
/// underlying request was. The loop owns no knowledge of the request
/// itself — only the verdict + diagnostic surface.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AdmissionDraft {
    pub verdict: ACSAdmissionVerdict,
    pub reason: String,
}

impl AdmissionDraft {
    #[must_use]
    pub fn new(verdict: ACSAdmissionVerdict, reason: impl Into<String>) -> Self {
        Self {
            verdict,
            reason: reason.into(),
        }
    }
}

/// Per-call-site loop. Holds no state — every decision flows from the
/// verdict carried on the draft. This means the same loop instance
/// can be reused across requests within a mission run.
#[derive(Debug, Default, Clone, Copy)]
pub struct AdmissionRepairLoop;

impl AdmissionRepairLoop {
    #[must_use]
    pub const fn new() -> Self {
        Self
    }

    fn hint(verdict: ACSAdmissionVerdict, reason: &str) -> String {
        format!(
            "admission_repair: ACS verdict `{}` — {reason}. Tighten constraints \
             (lower risk axes, attach evidence) and retry.",
            verdict.code()
        )
    }
}

impl HyperdynamicLoop for AdmissionRepairLoop {
    type Packet = AdmissionDraft;
    type Error = std::convert::Infallible;

    fn kind(&self) -> &'static str {
        "admission_repair"
    }

    fn check(&self, draft: &Self::Packet) -> Result<RepairVerdict<Self::Packet>, Self::Error> {
        match draft.verdict {
            ACSAdmissionVerdict::Allow | ACSAdmissionVerdict::AllowWithWarning => {
                Ok(RepairVerdict::Accept(draft.clone()))
            }
            ACSAdmissionVerdict::Defer => Ok(RepairVerdict::RepairWith {
                hint: Self::hint(draft.verdict, &draft.reason),
                tightened: draft.clone(),
            }),
            ACSAdmissionVerdict::Quarantine | ACSAdmissionVerdict::Reject => {
                Ok(RepairVerdict::Quarantine {
                    reason: format!(
                        "acs_terminal:{}: {}",
                        draft.verdict.code(),
                        draft.reason
                    ),
                })
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::hyperdynamic_loop::{run_loop, LoopCounters, RepairBudget, RepairOutcome};

    #[test]
    fn kind_is_admission_repair() {
        assert_eq!(AdmissionRepairLoop::new().kind(), "admission_repair");
    }

    #[test]
    fn allow_verdict_accepts() {
        let l = AdmissionRepairLoop::new();
        let d = AdmissionDraft::new(ACSAdmissionVerdict::Allow, "ok");
        assert!(matches!(l.check(&d).unwrap(), RepairVerdict::Accept(_)));
    }

    #[test]
    fn allow_with_warning_still_accepts() {
        let l = AdmissionRepairLoop::new();
        let d = AdmissionDraft::new(ACSAdmissionVerdict::AllowWithWarning, "evidence-thin");
        assert!(matches!(l.check(&d).unwrap(), RepairVerdict::Accept(_)));
    }

    #[test]
    fn defer_produces_repair_hint_with_policy_reason() {
        let l = AdmissionRepairLoop::new();
        let d = AdmissionDraft::new(ACSAdmissionVerdict::Defer, "risk_axes_near_quarantine");
        match l.check(&d).unwrap() {
            RepairVerdict::RepairWith { hint, .. } => {
                assert!(hint.contains("admission_repair:"), "hint: {hint}");
                assert!(hint.contains("`defer`"), "hint: {hint}");
                assert!(hint.contains("risk_axes_near_quarantine"), "hint: {hint}");
            }
            other => panic!("expected RepairWith, got {other:?}"),
        }
    }

    #[test]
    fn quarantine_verdict_is_terminal() {
        let l = AdmissionRepairLoop::new();
        let d = AdmissionDraft::new(ACSAdmissionVerdict::Quarantine, "egress_unsafe");
        match l.check(&d).unwrap() {
            RepairVerdict::Quarantine { reason } => {
                assert!(reason.starts_with("acs_terminal:quarantine"), "reason: {reason}");
                assert!(reason.contains("egress_unsafe"), "reason: {reason}");
            }
            other => panic!("expected Quarantine, got {other:?}"),
        }
    }

    #[test]
    fn reject_verdict_is_terminal_with_distinct_prefix() {
        let l = AdmissionRepairLoop::new();
        let d = AdmissionDraft::new(ACSAdmissionVerdict::Reject, "policy_violation");
        match l.check(&d).unwrap() {
            RepairVerdict::Quarantine { reason } => {
                assert!(reason.starts_with("acs_terminal:reject"));
            }
            other => panic!("expected Quarantine, got {other:?}"),
        }
    }

    #[test]
    fn defer_then_allow_drives_full_repair_cycle() {
        let l = AdmissionRepairLoop::new();
        let initial = AdmissionDraft::new(ACSAdmissionVerdict::Defer, "first-pass");
        let mut c = LoopCounters::new();
        let outcome = run_loop(
            &l,
            initial,
            RepairBudget::DEFAULT,
            &mut c,
            |_prev, _hint| AdmissionDraft::new(ACSAdmissionVerdict::Allow, "repaired"),
        )
        .unwrap();
        match outcome {
            RepairOutcome::Accepted { packet, repairs } => {
                assert_eq!(repairs, 1);
                assert_eq!(packet.verdict, ACSAdmissionVerdict::Allow);
            }
            other => panic!("expected accepted, got {other:?}"),
        }
        assert_eq!(c.accepted, 1);
        assert_eq!(c.repaired, 1);
    }

    #[test]
    fn persistent_defer_quarantines_on_budget() {
        let l = AdmissionRepairLoop::new();
        let initial = AdmissionDraft::new(ACSAdmissionVerdict::Defer, "stuck");
        let mut c = LoopCounters::new();
        let outcome = run_loop(
            &l,
            initial,
            RepairBudget::tightened(2, std::time::Duration::from_millis(500), 64),
            &mut c,
            |prev, _hint| prev.clone(),
        )
        .unwrap();
        assert!(matches!(
            outcome,
            RepairOutcome::QuarantinedBudgetExhausted { repairs: 2, .. }
        ));
        assert_eq!(c.quarantined, 1);
    }
}
