//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.6.6 — Adaptation / Compute Steering split. Compute
//!   Steering is "per-call expert-budget / KV-allocation dispatch
//!   policy" — distinct from Adaptation (long-horizon weight updates).
//! - Related upstream: Shazeer et al. arXiv:1701.06538 (sparse-gated
//!   MoE expert selection); helios v3.md Part III L_SE row
//!   (Titans-MAC adaptation lane separation).
//!
//! # Wave J B.6.6 — Compute Steering substrate
//!
//! Compute Steering owns the **per-call** policy that decides:
//! - How much token / wall-clock / KV-cache budget this call may
//!   consume.
//! - Which expert(s) from a sparse routing layer to dispatch to.
//! - Whether to short-circuit early when the budget runs out.
//!
//! Adaptation (a sibling lane, lives in [`super::continual_learning`])
//! owns the **long-horizon** weight-update policy. The split is what
//! the V6.1 doctrine names "the adaptation/steering split" — keep
//! them in two separate dispatch points so the same weights can serve
//! many compute budgets.
//!
//! Substrate floor: budget tracker + dispatch decision struct +
//! a `SteeringPolicy` trait that production impls satisfy.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct ComputeBudget {
    pub tokens_remaining: u32,
    pub ms_remaining: u32,
    pub kv_slots_remaining: u32,
}

impl ComputeBudget {
    pub fn new(tokens: u32, ms: u32, kv: u32) -> Self {
        Self { tokens_remaining: tokens, ms_remaining: ms, kv_slots_remaining: kv }
    }

    pub fn is_exhausted(&self) -> bool {
        self.tokens_remaining == 0
            || self.ms_remaining == 0
            || self.kv_slots_remaining == 0
    }

    pub fn debit(&mut self, tokens: u32, ms: u32, kv: u32) -> Result<(), SteeringError> {
        if tokens > self.tokens_remaining {
            return Err(SteeringError::TokenBudgetExceeded {
                requested: tokens,
                remaining: self.tokens_remaining,
            });
        }
        if ms > self.ms_remaining {
            return Err(SteeringError::TimeBudgetExceeded {
                requested_ms: ms,
                remaining_ms: self.ms_remaining,
            });
        }
        if kv > self.kv_slots_remaining {
            return Err(SteeringError::KvBudgetExceeded {
                requested: kv,
                remaining: self.kv_slots_remaining,
            });
        }
        self.tokens_remaining -= tokens;
        self.ms_remaining -= ms;
        self.kv_slots_remaining -= kv;
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DispatchDecision {
    pub experts: Vec<usize>,
    pub kv_allocate: u32,
    pub max_tokens: u32,
    pub short_circuit: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SteeringError {
    TokenBudgetExceeded { requested: u32, remaining: u32 },
    TimeBudgetExceeded { requested_ms: u32, remaining_ms: u32 },
    KvBudgetExceeded { requested: u32, remaining: u32 },
    NoExpertsAvailable,
}

pub trait SteeringPolicy {
    /// Decide dispatch for the next call. May return a short-circuit
    /// decision if the budget is exhausted.
    fn decide(
        &self,
        budget: &ComputeBudget,
        n_experts_available: usize,
    ) -> Result<DispatchDecision, SteeringError>;
}

/// Single-expert greedy steering: dispatch one expert, allocate a
/// fixed share of the remaining budget per call.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct GreedySingleExpertPolicy {
    pub kv_per_call: u32,
    pub max_tokens_per_call: u32,
}

impl SteeringPolicy for GreedySingleExpertPolicy {
    fn decide(
        &self,
        budget: &ComputeBudget,
        n_experts_available: usize,
    ) -> Result<DispatchDecision, SteeringError> {
        if budget.is_exhausted() {
            return Ok(DispatchDecision {
                experts: vec![],
                kv_allocate: 0,
                max_tokens: 0,
                short_circuit: true,
            });
        }
        if n_experts_available == 0 {
            return Err(SteeringError::NoExpertsAvailable);
        }
        let kv = self.kv_per_call.min(budget.kv_slots_remaining);
        let max_tokens = self.max_tokens_per_call.min(budget.tokens_remaining);
        Ok(DispatchDecision {
            experts: vec![0],
            kv_allocate: kv,
            max_tokens,
            short_circuit: false,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fresh_budget_is_not_exhausted() {
        let b = ComputeBudget::new(100, 1000, 50);
        assert!(!b.is_exhausted());
    }

    #[test]
    fn zero_tokens_is_exhausted() {
        let b = ComputeBudget::new(0, 1000, 50);
        assert!(b.is_exhausted());
    }

    #[test]
    fn zero_ms_is_exhausted() {
        let b = ComputeBudget::new(100, 0, 50);
        assert!(b.is_exhausted());
    }

    #[test]
    fn zero_kv_is_exhausted() {
        let b = ComputeBudget::new(100, 1000, 0);
        assert!(b.is_exhausted());
    }

    #[test]
    fn debit_within_budget_decrements_correctly() {
        let mut b = ComputeBudget::new(100, 1000, 50);
        b.debit(10, 100, 5).unwrap();
        assert_eq!(b.tokens_remaining, 90);
        assert_eq!(b.ms_remaining, 900);
        assert_eq!(b.kv_slots_remaining, 45);
    }

    #[test]
    fn debit_over_tokens_errors() {
        let mut b = ComputeBudget::new(10, 1000, 50);
        let err = b.debit(99, 100, 5).unwrap_err();
        assert_eq!(
            err,
            SteeringError::TokenBudgetExceeded { requested: 99, remaining: 10 }
        );
    }

    #[test]
    fn debit_over_ms_errors() {
        let mut b = ComputeBudget::new(100, 100, 50);
        let err = b.debit(10, 999, 5).unwrap_err();
        assert_eq!(
            err,
            SteeringError::TimeBudgetExceeded { requested_ms: 999, remaining_ms: 100 }
        );
    }

    #[test]
    fn debit_over_kv_errors() {
        let mut b = ComputeBudget::new(100, 1000, 5);
        let err = b.debit(10, 100, 99).unwrap_err();
        assert_eq!(
            err,
            SteeringError::KvBudgetExceeded { requested: 99, remaining: 5 }
        );
    }

    #[test]
    fn greedy_policy_dispatches_one_expert() {
        let p = GreedySingleExpertPolicy { kv_per_call: 8, max_tokens_per_call: 50 };
        let b = ComputeBudget::new(100, 1000, 64);
        let d = p.decide(&b, 4).unwrap();
        assert_eq!(d.experts, vec![0]);
        assert_eq!(d.kv_allocate, 8);
        assert_eq!(d.max_tokens, 50);
        assert!(!d.short_circuit);
    }

    #[test]
    fn greedy_policy_short_circuits_when_exhausted() {
        let p = GreedySingleExpertPolicy { kv_per_call: 8, max_tokens_per_call: 50 };
        let b = ComputeBudget::new(0, 1000, 64);
        let d = p.decide(&b, 4).unwrap();
        assert!(d.experts.is_empty());
        assert!(d.short_circuit);
    }

    #[test]
    fn greedy_policy_clamps_kv_to_remaining() {
        let p = GreedySingleExpertPolicy { kv_per_call: 100, max_tokens_per_call: 50 };
        let b = ComputeBudget::new(100, 1000, 8);
        let d = p.decide(&b, 4).unwrap();
        assert_eq!(d.kv_allocate, 8);
    }

    #[test]
    fn greedy_policy_no_experts_available_errors() {
        let p = GreedySingleExpertPolicy { kv_per_call: 8, max_tokens_per_call: 50 };
        let b = ComputeBudget::new(100, 1000, 64);
        let err = p.decide(&b, 0).unwrap_err();
        assert_eq!(err, SteeringError::NoExpertsAvailable);
    }

    #[test]
    fn budget_roundtrips_through_serde_json() {
        let b = ComputeBudget::new(100, 1000, 50);
        let json = serde_json::to_string(&b).unwrap();
        let back: ComputeBudget = serde_json::from_str(&json).unwrap();
        assert_eq!(b, back);
    }

    #[test]
    fn decision_roundtrips_through_serde_json() {
        let d = DispatchDecision {
            experts: vec![0, 2],
            kv_allocate: 16,
            max_tokens: 32,
            short_circuit: false,
        };
        let json = serde_json::to_string(&d).unwrap();
        let back: DispatchDecision = serde_json::from_str(&json).unwrap();
        assert_eq!(d, back);
    }

    #[test]
    fn debit_sequence_drains_budget_correctly() {
        let mut b = ComputeBudget::new(30, 300, 15);
        b.debit(10, 100, 5).unwrap();
        b.debit(10, 100, 5).unwrap();
        b.debit(10, 100, 5).unwrap();
        assert!(b.is_exhausted());
    }
}
