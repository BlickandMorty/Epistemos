//! `WitnessRepairLoop` — gates a model draft on whether an attached
//! proof witness verified. The loop is generic over the witness
//! verdict so it composes with both EML / F-ULP witnesses today and
//! future proof shapes (e.g. weight-bit replay) without code change.
//!
//! Three witness states map to the loop's three verdicts:
//! - `Verified` → Accept
//! - `RepairableMismatch { constraint }` → RepairWith (model rerun with constraint)
//! - `Invalid { reason }` → Quarantine (terminal — proof shape itself rejects)

use super::{HyperdynamicLoop, RepairVerdict};

/// Witness verdict carried alongside the underlying draft. The
/// concrete proof backend (EML, F-ULP, etc.) lowers its replay error
/// into one of these three states before handing the draft to the
/// loop.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WitnessState {
    /// Proof verified — draft satisfies the loop's witnessed contract.
    Verified,
    /// Proof failed in a way that's repairable by tightening one
    /// constraint. `constraint` is the hint surfaced to the model.
    RepairableMismatch { constraint: String },
    /// Proof failed in a way no repair can address (corrupt JSON,
    /// unsupported evaluator, missing hardware pin). Terminal.
    Invalid { reason: String },
}

impl WitnessState {
    #[must_use]
    pub fn verified() -> Self {
        Self::Verified
    }

    #[must_use]
    pub fn repairable(constraint: impl Into<String>) -> Self {
        Self::RepairableMismatch {
            constraint: constraint.into(),
        }
    }

    #[must_use]
    pub fn invalid(reason: impl Into<String>) -> Self {
        Self::Invalid {
            reason: reason.into(),
        }
    }
}

/// Draft + its current witness verdict. The loop only inspects
/// `state`; the `payload` is opaque to the loop and threaded through
/// for whatever consumer is waiting downstream.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WitnessDraft<T: Clone> {
    pub payload: T,
    pub state: WitnessState,
}

impl<T: Clone> WitnessDraft<T> {
    #[must_use]
    pub fn new(payload: T, state: WitnessState) -> Self {
        Self { payload, state }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct WitnessRepairLoop<T: Clone>(core::marker::PhantomData<T>);

impl<T: Clone> WitnessRepairLoop<T> {
    #[must_use]
    pub const fn new() -> Self {
        Self(core::marker::PhantomData)
    }
}

impl<T: Clone> Default for WitnessRepairLoop<T> {
    fn default() -> Self {
        Self::new()
    }
}

impl<T> HyperdynamicLoop for WitnessRepairLoop<T>
where
    T: Clone,
{
    type Packet = WitnessDraft<T>;
    type Error = std::convert::Infallible;

    fn kind(&self) -> &'static str {
        "witness_repair"
    }

    fn check(&self, draft: &Self::Packet) -> Result<RepairVerdict<Self::Packet>, Self::Error> {
        match &draft.state {
            WitnessState::Verified => Ok(RepairVerdict::Accept(draft.clone())),
            WitnessState::RepairableMismatch { constraint } => Ok(RepairVerdict::RepairWith {
                hint: format!("witness_repair: constraint failed — {constraint}"),
                tightened: draft.clone(),
            }),
            WitnessState::Invalid { reason } => Ok(RepairVerdict::Quarantine {
                reason: format!("witness_invalid: {reason}"),
            }),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::hyperdynamic_loop::{run_loop, LoopCounters, RepairBudget, RepairOutcome};

    #[derive(Clone, Debug, PartialEq, Eq)]
    struct DummyPayload {
        run_id: u32,
    }

    fn d(run_id: u32, state: WitnessState) -> WitnessDraft<DummyPayload> {
        WitnessDraft::new(DummyPayload { run_id }, state)
    }

    #[test]
    fn kind_is_witness_repair() {
        assert_eq!(
            WitnessRepairLoop::<DummyPayload>::new().kind(),
            "witness_repair"
        );
    }

    #[test]
    fn verified_draft_accepts() {
        let l = WitnessRepairLoop::<DummyPayload>::new();
        let draft = d(1, WitnessState::verified());
        match l.check(&draft).unwrap() {
            RepairVerdict::Accept(p) => assert_eq!(p.payload.run_id, 1),
            other => panic!("expected accept, got {other:?}"),
        }
    }

    #[test]
    fn repairable_produces_constraint_hint() {
        let l = WitnessRepairLoop::<DummyPayload>::new();
        let draft = d(
            1,
            WitnessState::repairable("ulp_mean[add] over budget by 1.4×"),
        );
        match l.check(&draft).unwrap() {
            RepairVerdict::RepairWith { hint, .. } => {
                assert!(hint.starts_with("witness_repair: constraint failed"));
                assert!(hint.contains("ulp_mean[add] over budget"));
            }
            other => panic!("expected RepairWith, got {other:?}"),
        }
    }

    #[test]
    fn invalid_witness_is_terminal() {
        let l = WitnessRepairLoop::<DummyPayload>::new();
        let draft = d(1, WitnessState::invalid("hardware_pin_mismatch"));
        match l.check(&draft).unwrap() {
            RepairVerdict::Quarantine { reason } => {
                assert!(reason.starts_with("witness_invalid:"));
                assert!(reason.contains("hardware_pin_mismatch"));
            }
            other => panic!("expected Quarantine, got {other:?}"),
        }
    }

    #[test]
    fn full_loop_repairs_then_verifies() {
        let l = WitnessRepairLoop::<DummyPayload>::new();
        let initial = d(1, WitnessState::repairable("budget_wall_clock_ms_exceeded"));
        let mut c = LoopCounters::new();
        let outcome = run_loop(&l, initial, RepairBudget::DEFAULT, &mut c, |prev, _hint| {
            let mut next = prev.clone();
            next.state = WitnessState::Verified;
            next.payload.run_id += 1;
            next
        })
        .unwrap();
        match outcome {
            RepairOutcome::Accepted { packet, repairs } => {
                assert_eq!(repairs, 1);
                assert_eq!(packet.payload.run_id, 2);
                assert_eq!(packet.state, WitnessState::Verified);
            }
            other => panic!("expected accepted, got {other:?}"),
        }
        assert_eq!(c.accepted, 1);
        assert_eq!(c.repaired, 1);
    }

    #[test]
    fn persistent_repairable_quarantines_on_budget() {
        let l = WitnessRepairLoop::<DummyPayload>::new();
        let initial = d(1, WitnessState::repairable("ulp_max[add] over budget"));
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

    #[test]
    fn invalid_witness_short_circuits_no_repair_attempts() {
        let l = WitnessRepairLoop::<DummyPayload>::new();
        let initial = d(1, WitnessState::invalid("unsupported_evaluator: ane_v8"));
        let mut c = LoopCounters::new();
        let outcome = run_loop(&l, initial, RepairBudget::DEFAULT, &mut c, |prev, _hint| {
            prev.clone()
        })
        .unwrap();
        match outcome {
            RepairOutcome::Quarantined { reason, repairs } => {
                assert!(reason.contains("unsupported_evaluator: ane_v8"));
                assert_eq!(repairs, 0);
            }
            other => panic!("expected explicit quarantine, got {other:?}"),
        }
        assert_eq!(c.quarantined, 1);
        assert_eq!(c.total_repair_attempts, 0);
    }
}
