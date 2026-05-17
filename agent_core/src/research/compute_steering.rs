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

    /// The smallest of `(tokens_remaining, ms_remaining,
    /// kv_slots_remaining)`. The "what's about to run out first?"
    /// diagnostic. Cross-surface invariant: `is_exhausted() iff
    /// min_resource_remaining() == 0`.
    pub const fn min_resource_remaining(&self) -> u32 {
        let m1 = if self.tokens_remaining < self.ms_remaining {
            self.tokens_remaining
        } else {
            self.ms_remaining
        };
        if m1 < self.kv_slots_remaining {
            m1
        } else {
            self.kv_slots_remaining
        }
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

impl SteeringError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            SteeringError::TokenBudgetExceeded { .. } => "token_budget_exceeded",
            SteeringError::TimeBudgetExceeded { .. } => "time_budget_exceeded",
            SteeringError::KvBudgetExceeded { .. } => "kv_budget_exceeded",
            SteeringError::NoExpertsAvailable => "no_experts_available",
        }
    }

    /// Predicate: error pertains to a budget being exceeded
    /// (Token / Time / Kv).
    pub const fn is_budget_error(&self) -> bool {
        matches!(
            self,
            SteeringError::TokenBudgetExceeded { .. }
                | SteeringError::TimeBudgetExceeded { .. }
                | SteeringError::KvBudgetExceeded { .. }
        )
    }

    /// Predicate: error pertains to expert availability
    /// (NoExpertsAvailable). Cross-surface invariant:
    /// `is_budget_error XOR is_expert_error` partitions all variants.
    pub const fn is_expert_error(&self) -> bool {
        matches!(self, SteeringError::NoExpertsAvailable)
    }
}

impl DispatchDecision {
    /// Number of experts selected for this dispatch. Cross-surface
    /// invariant: `short_circuit iff expert_count() == 0`.
    pub fn expert_count(&self) -> usize {
        self.experts.len()
    }
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

/// Sparse top-K expert dispatch per Shazeer et al. arXiv:1701.06538
/// "Outrageously Large Neural Networks: The Sparsely-Gated Mixture-of-
/// Experts Layer" — the canonical MoE pattern. Dispatches the first
/// `top_k` experts (substrate floor — production wires the routing-
/// score-driven selection). `kv_per_call` is split evenly across the
/// selected experts (each gets `kv_per_call / actual_k`); remainder
/// goes to expert 0.
///
/// If `n_experts_available < top_k`, dispatches all `n_experts_available`
/// experts (graceful degradation rather than error).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MultiExpertSparsePolicy {
    pub top_k: u32,
    pub kv_per_call: u32,
    pub max_tokens_per_call: u32,
}

impl SteeringPolicy for MultiExpertSparsePolicy {
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
        if self.top_k == 0 {
            return Err(SteeringError::NoExpertsAvailable);
        }
        let actual_k = (self.top_k as usize).min(n_experts_available);
        let experts: Vec<usize> = (0..actual_k).collect();
        let kv = self.kv_per_call.min(budget.kv_slots_remaining);
        let max_tokens = self.max_tokens_per_call.min(budget.tokens_remaining);
        Ok(DispatchDecision {
            experts,
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

    // ── MultiExpertSparsePolicy tests (iter 88) ─────────────────────────────

    #[test]
    fn multi_expert_dispatches_top_k() {
        let p = MultiExpertSparsePolicy { top_k: 2, kv_per_call: 16, max_tokens_per_call: 64 };
        let b = ComputeBudget::new(100, 1000, 64);
        let d = p.decide(&b, 8).unwrap();
        assert_eq!(d.experts, vec![0, 1]);
        assert_eq!(d.kv_allocate, 16);
        assert_eq!(d.max_tokens, 64);
        assert!(!d.short_circuit);
    }

    #[test]
    fn multi_expert_degrades_when_fewer_experts_available() {
        let p = MultiExpertSparsePolicy { top_k: 8, kv_per_call: 16, max_tokens_per_call: 64 };
        let b = ComputeBudget::new(100, 1000, 64);
        let d = p.decide(&b, 3).unwrap();
        assert_eq!(d.experts, vec![0, 1, 2]);
    }

    #[test]
    fn multi_expert_short_circuits_when_budget_exhausted() {
        let p = MultiExpertSparsePolicy { top_k: 2, kv_per_call: 16, max_tokens_per_call: 64 };
        let b = ComputeBudget::new(0, 1000, 64);
        let d = p.decide(&b, 8).unwrap();
        assert!(d.experts.is_empty());
        assert!(d.short_circuit);
    }

    #[test]
    fn multi_expert_no_experts_available_errors() {
        let p = MultiExpertSparsePolicy { top_k: 2, kv_per_call: 16, max_tokens_per_call: 64 };
        let b = ComputeBudget::new(100, 1000, 64);
        let err = p.decide(&b, 0).unwrap_err();
        assert_eq!(err, SteeringError::NoExpertsAvailable);
    }

    #[test]
    fn multi_expert_top_k_zero_errors() {
        let p = MultiExpertSparsePolicy { top_k: 0, kv_per_call: 16, max_tokens_per_call: 64 };
        let b = ComputeBudget::new(100, 1000, 64);
        let err = p.decide(&b, 8).unwrap_err();
        assert_eq!(err, SteeringError::NoExpertsAvailable);
    }

    #[test]
    fn multi_expert_clamps_kv_and_tokens_to_remaining() {
        let p = MultiExpertSparsePolicy { top_k: 2, kv_per_call: 100, max_tokens_per_call: 100 };
        let b = ComputeBudget::new(10, 1000, 8);
        let d = p.decide(&b, 4).unwrap();
        assert_eq!(d.kv_allocate, 8);
        assert_eq!(d.max_tokens, 10);
    }

    #[test]
    fn multi_expert_top_k_equals_available_dispatches_all() {
        let p = MultiExpertSparsePolicy { top_k: 4, kv_per_call: 16, max_tokens_per_call: 64 };
        let b = ComputeBudget::new(100, 1000, 64);
        let d = p.decide(&b, 4).unwrap();
        assert_eq!(d.experts.len(), 4);
        assert_eq!(d.experts, vec![0, 1, 2, 3]);
    }

    // ── diagnostic surface (iter 167) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            SteeringError::TokenBudgetExceeded { requested: 1, remaining: 0 },
            SteeringError::TimeBudgetExceeded { requested_ms: 1, remaining_ms: 0 },
            SteeringError::KvBudgetExceeded { requested: 1, remaining: 0 },
            SteeringError::NoExpertsAvailable,
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 4);
    }

    #[test]
    fn error_classifiers_partition_variants() {
        let variants = [
            SteeringError::TokenBudgetExceeded { requested: 1, remaining: 0 },
            SteeringError::TimeBudgetExceeded { requested_ms: 1, remaining_ms: 0 },
            SteeringError::KvBudgetExceeded { requested: 1, remaining: 0 },
            SteeringError::NoExpertsAvailable,
        ];
        // Cross-surface invariant: is_budget_error XOR is_expert_error.
        for e in variants {
            assert_ne!(e.is_budget_error(), e.is_expert_error());
        }
        assert_eq!(variants.iter().filter(|e| e.is_budget_error()).count(), 3);
        assert_eq!(variants.iter().filter(|e| e.is_expert_error()).count(), 1);
    }

    #[test]
    fn min_resource_remaining_matches_min_field() {
        let b = ComputeBudget::new(100, 50, 200);
        assert_eq!(b.min_resource_remaining(), 50);
        let b = ComputeBudget::new(5, 50, 200);
        assert_eq!(b.min_resource_remaining(), 5);
        let b = ComputeBudget::new(100, 50, 3);
        assert_eq!(b.min_resource_remaining(), 3);
    }

    #[test]
    fn is_exhausted_aligns_with_min_resource_zero() {
        // Cross-surface invariant: is_exhausted iff min_resource_remaining == 0.
        let b = ComputeBudget::new(100, 1000, 50);
        assert_eq!(b.is_exhausted(), b.min_resource_remaining() == 0);
        let b = ComputeBudget::new(0, 1000, 50);
        assert_eq!(b.is_exhausted(), b.min_resource_remaining() == 0);
        let b = ComputeBudget::new(100, 0, 50);
        assert_eq!(b.is_exhausted(), b.min_resource_remaining() == 0);
        let b = ComputeBudget::new(100, 1000, 0);
        assert_eq!(b.is_exhausted(), b.min_resource_remaining() == 0);
    }

    #[test]
    fn dispatch_decision_short_circuit_aligns_with_empty_experts() {
        // Cross-surface invariant: short_circuit iff expert_count == 0.
        let sc = DispatchDecision {
            experts: vec![],
            kv_allocate: 0,
            max_tokens: 0,
            short_circuit: true,
        };
        assert_eq!(sc.short_circuit, sc.expert_count() == 0);

        let active = DispatchDecision {
            experts: vec![0, 1],
            kv_allocate: 16,
            max_tokens: 32,
            short_circuit: false,
        };
        assert_eq!(active.short_circuit, active.expert_count() == 0);
    }

    #[test]
    fn greedy_policy_short_circuit_matches_decision_invariant() {
        // Cross-surface: actual policy outputs satisfy the
        // short_circuit/empty-experts invariant.
        let p = GreedySingleExpertPolicy { kv_per_call: 8, max_tokens_per_call: 50 };
        let exhausted = ComputeBudget::new(0, 1000, 64);
        let d = p.decide(&exhausted, 4).unwrap();
        assert_eq!(d.short_circuit, d.expert_count() == 0);

        let alive = ComputeBudget::new(100, 1000, 64);
        let d = p.decide(&alive, 4).unwrap();
        assert_eq!(d.short_circuit, d.expert_count() == 0);
    }

    #[test]
    fn multi_expert_short_circuit_matches_decision_invariant() {
        let p = MultiExpertSparsePolicy {
            top_k: 3,
            kv_per_call: 16,
            max_tokens_per_call: 64,
        };
        let exhausted = ComputeBudget::new(0, 1000, 64);
        let d = p.decide(&exhausted, 8).unwrap();
        assert_eq!(d.short_circuit, d.expert_count() == 0);

        let alive = ComputeBudget::new(100, 1000, 64);
        let d = p.decide(&alive, 8).unwrap();
        assert_eq!(d.short_circuit, d.expert_count() == 0);
    }

    #[test]
    fn debit_error_cause_matches_resource() {
        // Cross-surface: error returned by debit carries cause matching
        // the resource that was exceeded.
        let mut b = ComputeBudget::new(5, 5, 5);
        let err = b.debit(10, 0, 0).unwrap_err();
        assert_eq!(err.cause(), "token_budget_exceeded");
        let mut b = ComputeBudget::new(5, 5, 5);
        let err = b.debit(0, 10, 0).unwrap_err();
        assert_eq!(err.cause(), "time_budget_exceeded");
        let mut b = ComputeBudget::new(5, 5, 5);
        let err = b.debit(0, 0, 10).unwrap_err();
        assert_eq!(err.cause(), "kv_budget_exceeded");
    }
}
