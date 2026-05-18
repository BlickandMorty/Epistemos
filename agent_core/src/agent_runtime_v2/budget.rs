//! Agent Runtime v2 budget — per-mission resource cap with debit-and-reject
//! semantics.
//!
//! Sits *underneath* the WBO-6 drift accounting in `agent_core::wbo6::`
//! (which tracks logit drift bounds at the inference layer). The v2 budget
//! is the **runtime resource cap** that gates every executor side-effect:
//! tokens, wall time, tool calls. When a proposed debit would exceed any
//! cap, the call is rejected with `BudgetError::Exhausted` and the executor
//! emits `StopReason::BudgetExhausted` (see `para::StopReason`).
//!
//! Budget term mapping vs WBO-6 (from
//! `docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md`):
//!
//! | v2 budget term      | WBO-6 term  | Why                                |
//! |---------------------|-------------|------------------------------------|
//! | `max_tokens`        | (orthogonal | token counts don't bound logit     |
//! |                     | accounting) | drift, but gate $ + latency caps   |
//! | `max_wall_ms`       | T_S         | substrate boundary budget          |
//! | `max_tool_calls`    | T_S         | substrate side-effect surface      |
//! | `max_subprocess_ms` | T_SE        | sovereign enforcement budget       |
//!
//! Acceptance bar reference (§4 T11): property test
//! `over_budget_call_rejected` lives in this module.

use serde::{Deserialize, Serialize};

/// Per-mission resource caps. A zero cap means "unbounded" (caller must
/// opt out explicitly by setting 0; `BudgetSpec::default()` returns
/// everything zeroed which means unbounded).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct BudgetSpec {
    /// Maximum total tokens (prompt + completion + thinking) across all
    /// turns of the mission. 0 = unbounded.
    pub max_tokens: u64,
    /// Maximum wall-clock milliseconds across all turns. 0 = unbounded.
    pub max_wall_ms: u64,
    /// Maximum number of tool calls across all turns. 0 = unbounded.
    pub max_tool_calls: u64,
    /// Maximum cumulative subprocess milliseconds (Pro Research only —
    /// MAS observes this as 0 and the Subprocess mode is unreachable).
    /// 0 = unbounded.
    pub max_subprocess_ms: u64,
}

impl BudgetSpec {
    /// Convenience constructor for tests and typical Pro defaults.
    #[must_use]
    pub const fn new(
        max_tokens: u64,
        max_wall_ms: u64,
        max_tool_calls: u64,
        max_subprocess_ms: u64,
    ) -> Self {
        Self {
            max_tokens,
            max_wall_ms,
            max_tool_calls,
            max_subprocess_ms,
        }
    }
}

/// Running counters for a mission. Monotonically increases; never resets
/// mid-mission. Persisted into `RunEventLog` for replay.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct BudgetLedger {
    pub tokens_used: u64,
    pub wall_used_ms: u64,
    pub tool_calls_used: u64,
    pub subprocess_used_ms: u64,
}

/// A proposed debit. The executor builds this from an `AgentEvent` and
/// hands it to `BudgetGate::check_and_debit` *before* performing the
/// side-effect. If the debit would exceed any cap, the call is rejected
/// and no counter is mutated.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct BudgetDebit {
    pub tokens: u64,
    pub wall_ms: u64,
    pub tool_calls: u64,
    pub subprocess_ms: u64,
}

/// Which WBO-6 / v2 term tripped the rejection. Surfaced so the
/// `RunEventLog` can record exactly why the call failed.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BudgetTerm {
    Tokens,
    WallMs,
    ToolCalls,
    SubprocessMs,
}

impl BudgetTerm {
    /// Canonical short code matching the WBO-6 term shape where applicable.
    #[must_use]
    pub const fn code(self) -> &'static str {
        match self {
            Self::Tokens => "tokens",
            Self::WallMs => "wall_ms",
            Self::ToolCalls => "tool_calls",
            Self::SubprocessMs => "subprocess_ms",
        }
    }
}

/// Outcome of a budget check.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BudgetError {
    /// One term would be exceeded by the proposed debit.
    Exhausted {
        term: BudgetTerm,
        attempted_total: u64,
        cap: u64,
    },
}

/// Pure budget gate. Holds the spec; the ledger is passed in by the
/// caller (executor owns the ledger lifecycle). `check_and_debit`
/// returns the new ledger on success — never mutates in place, so a
/// rejected call cannot leave a partial debit behind.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BudgetGate {
    spec: BudgetSpec,
}

impl BudgetGate {
    #[must_use]
    pub const fn new(spec: BudgetSpec) -> Self {
        Self { spec }
    }

    #[must_use]
    pub const fn spec(&self) -> BudgetSpec {
        self.spec
    }

    /// Check the proposed debit against the spec + current ledger.
    /// Returns the would-be new ledger on success. On rejection, the
    /// caller's ledger is left untouched (caller never mutates from
    /// the return value when we Err).
    ///
    /// Caps of 0 mean unbounded for that term (the term is skipped).
    pub fn check_and_debit(
        &self,
        ledger: BudgetLedger,
        debit: BudgetDebit,
    ) -> Result<BudgetLedger, BudgetError> {
        // Tokens
        let tokens_total = ledger.tokens_used.saturating_add(debit.tokens);
        if self.spec.max_tokens > 0 && tokens_total > self.spec.max_tokens {
            return Err(BudgetError::Exhausted {
                term: BudgetTerm::Tokens,
                attempted_total: tokens_total,
                cap: self.spec.max_tokens,
            });
        }
        // Wall
        let wall_total = ledger.wall_used_ms.saturating_add(debit.wall_ms);
        if self.spec.max_wall_ms > 0 && wall_total > self.spec.max_wall_ms {
            return Err(BudgetError::Exhausted {
                term: BudgetTerm::WallMs,
                attempted_total: wall_total,
                cap: self.spec.max_wall_ms,
            });
        }
        // Tool calls
        let tool_total = ledger.tool_calls_used.saturating_add(debit.tool_calls);
        if self.spec.max_tool_calls > 0 && tool_total > self.spec.max_tool_calls {
            return Err(BudgetError::Exhausted {
                term: BudgetTerm::ToolCalls,
                attempted_total: tool_total,
                cap: self.spec.max_tool_calls,
            });
        }
        // Subprocess (Research only — but check regardless; MAS sets cap=0
        // and never produces nonzero subprocess_ms because Subprocess mode
        // is unreachable in MAS).
        let sub_total = ledger.subprocess_used_ms.saturating_add(debit.subprocess_ms);
        if self.spec.max_subprocess_ms > 0 && sub_total > self.spec.max_subprocess_ms {
            return Err(BudgetError::Exhausted {
                term: BudgetTerm::SubprocessMs,
                attempted_total: sub_total,
                cap: self.spec.max_subprocess_ms,
            });
        }
        Ok(BudgetLedger {
            tokens_used: tokens_total,
            wall_used_ms: wall_total,
            tool_calls_used: tool_total,
            subprocess_used_ms: sub_total,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn over_budget_call_rejected() {
        // §4 T11 acceptance: "over-budget call rejected".
        let gate = BudgetGate::new(BudgetSpec::new(1_000, 0, 0, 0));
        let ledger = BudgetLedger {
            tokens_used: 950,
            ..Default::default()
        };
        // Debit of 100 would push total to 1_050 > 1_000 cap.
        let err = gate
            .check_and_debit(ledger, BudgetDebit { tokens: 100, ..Default::default() })
            .expect_err("over-budget debit must be rejected");
        assert!(
            matches!(
                err,
                BudgetError::Exhausted {
                    term: BudgetTerm::Tokens,
                    attempted_total: 1_050,
                    cap: 1_000,
                }
            ),
            "unexpected error shape: {err:?}"
        );
    }

    #[test]
    fn rejected_call_leaves_ledger_untouched() {
        // Functional purity check: we must not write the partial debit
        // when any one term would trip.
        let gate = BudgetGate::new(BudgetSpec::new(0, 0, 3, 0));
        let ledger = BudgetLedger {
            tokens_used: 5,
            tool_calls_used: 3,
            ..Default::default()
        };
        let original = ledger; // copy; struct is Copy
        let err = gate
            .check_and_debit(ledger, BudgetDebit { tool_calls: 1, ..Default::default() })
            .expect_err("rejected debit");
        assert!(matches!(err, BudgetError::Exhausted { term: BudgetTerm::ToolCalls, .. }));
        // Caller's ledger (passed by value) is bitwise-equal to original.
        assert_eq!(ledger, original);
    }

    #[test]
    fn underbudget_call_returns_advanced_ledger() {
        let gate = BudgetGate::new(BudgetSpec::new(1_000, 60_000, 5, 0));
        let ledger = BudgetLedger::default();
        let advanced = gate
            .check_and_debit(
                ledger,
                BudgetDebit {
                    tokens: 250,
                    wall_ms: 1_500,
                    tool_calls: 1,
                    ..Default::default()
                },
            )
            .expect("under-budget debit");
        assert_eq!(advanced.tokens_used, 250);
        assert_eq!(advanced.wall_used_ms, 1_500);
        assert_eq!(advanced.tool_calls_used, 1);
        assert_eq!(advanced.subprocess_used_ms, 0);
    }

    #[test]
    fn zero_cap_means_unbounded() {
        // All caps zero → any debit succeeds.
        let gate = BudgetGate::new(BudgetSpec::default());
        let huge = BudgetDebit {
            tokens: u64::MAX / 2,
            wall_ms: u64::MAX / 2,
            tool_calls: u64::MAX / 2,
            subprocess_ms: u64::MAX / 2,
        };
        let ledger = BudgetLedger::default();
        gate.check_and_debit(ledger, huge).expect("unbounded gate must accept any debit");
    }

    #[test]
    fn first_tripped_term_is_reported() {
        // Ordering: tokens checked first, so token over-cap reports
        // Tokens even when wall would also trip.
        let gate = BudgetGate::new(BudgetSpec::new(10, 10, 0, 0));
        let ledger = BudgetLedger::default();
        let err = gate
            .check_and_debit(
                ledger,
                BudgetDebit { tokens: 100, wall_ms: 100, ..Default::default() },
            )
            .expect_err("either term over cap");
        assert!(matches!(err, BudgetError::Exhausted { term: BudgetTerm::Tokens, .. }));
    }

    #[test]
    fn boundary_equal_to_cap_accepted() {
        // Exactly at the cap is allowed (the comparison is strict `>`).
        let gate = BudgetGate::new(BudgetSpec::new(1_000, 0, 0, 0));
        let ledger = BudgetLedger { tokens_used: 900, ..Default::default() };
        let advanced = gate
            .check_and_debit(ledger, BudgetDebit { tokens: 100, ..Default::default() })
            .expect("debit landing exactly on cap must be accepted");
        assert_eq!(advanced.tokens_used, 1_000);
    }

    #[test]
    fn subprocess_cap_enforced_independently() {
        let gate = BudgetGate::new(BudgetSpec::new(0, 0, 0, 5_000));
        let ledger = BudgetLedger { subprocess_used_ms: 4_900, ..Default::default() };
        let err = gate
            .check_and_debit(ledger, BudgetDebit { subprocess_ms: 200, ..Default::default() })
            .expect_err("subprocess cap exceeded");
        assert!(matches!(
            err,
            BudgetError::Exhausted { term: BudgetTerm::SubprocessMs, .. }
        ));
    }

    #[test]
    fn budget_term_codes_are_stable() {
        // Stability matters because RunEventLog persists these as
        // strings; a rename would silently fork replay parity.
        assert_eq!(BudgetTerm::Tokens.code(), "tokens");
        assert_eq!(BudgetTerm::WallMs.code(), "wall_ms");
        assert_eq!(BudgetTerm::ToolCalls.code(), "tool_calls");
        assert_eq!(BudgetTerm::SubprocessMs.code(), "subprocess_ms");
    }
}
