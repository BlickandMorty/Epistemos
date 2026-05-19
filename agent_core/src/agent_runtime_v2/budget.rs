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
    /// Maximum cumulative memory bytes consumed by run-private buffers
    /// (KV cache snapshots, intermediate tensors, context windows held
    /// past compaction). 0 = unbounded. Phase 1 hardening per user's
    /// explicit list: "memory-byte axes".
    #[serde(default)]
    pub max_memory_bytes: u64,
}

impl BudgetSpec {
    /// Convenience constructor for tests and typical Pro defaults.
    /// `max_memory_bytes` defaults to 0 (unbounded); use
    /// [`Self::with_memory_bytes`] to set it.
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
            max_memory_bytes: 0,
        }
    }

    /// Builder helper: clone `self` with `max_memory_bytes` set. Lets
    /// callers opt into the memory cap without breaking the
    /// 4-positional `::new` signature.
    #[must_use]
    pub const fn with_memory_bytes(mut self, max_memory_bytes: u64) -> Self {
        self.max_memory_bytes = max_memory_bytes;
        self
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
    #[serde(default)]
    pub memory_bytes_used: u64,
}

/// A proposed debit. The executor builds this from an `AgentEvent` and
/// hands it to `BudgetGate::check_and_debit` *before* performing the
/// side-effect. If the debit would exceed any cap, the call is rejected
/// and no counter is mutated.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct BudgetDebit {
    pub tokens: u64,
    pub wall_ms: u64,
    pub tool_calls: u64,
    pub subprocess_ms: u64,
    #[serde(default)]
    pub memory_bytes: u64,
}

/// Which WBO-6 / v2 term tripped the rejection. Surfaced so the
/// `RunEventLog` can record exactly why the call failed.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BudgetTerm {
    Tokens,
    WallMs,
    ToolCalls,
    SubprocessMs,
    MemoryBytes,
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
            Self::MemoryBytes => "memory_bytes",
        }
    }
}

impl std::fmt::Display for BudgetTerm {
    /// Reuse the canonical short code so log lines and JSON
    /// persistence agree on a single string for each term.
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.code())
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

impl BudgetDebit {
    /// Build a `BudgetDebit` for one tool call with the given prompt +
    /// completion token cost. Convenience for executors so the call
    /// site doesn't open-code the field layout — keeps `tool_calls=1`
    /// + token sum + zero wall/subprocess (wall is set by the
    /// dispatcher from its own timer; subprocess is set only when the
    /// Subprocess mode actually spawned a child).
    #[must_use]
    pub const fn for_tool_call(prompt_tokens: u64, completion_tokens: u64) -> Self {
        Self {
            tokens: prompt_tokens.saturating_add(completion_tokens),
            wall_ms: 0,
            tool_calls: 1,
            subprocess_ms: 0,
            memory_bytes: 0,
        }
    }

    /// Build a `BudgetDebit` for a pure-thinking turn (no tool call,
    /// no subprocess). `tool_calls = 0` because no side-effect tool
    /// was invoked; only `tokens` is debited.
    #[must_use]
    pub const fn for_thinking_turn(prompt_tokens: u64, completion_tokens: u64) -> Self {
        Self {
            tokens: prompt_tokens.saturating_add(completion_tokens),
            wall_ms: 0,
            tool_calls: 0,
            subprocess_ms: 0,
            memory_bytes: 0,
        }
    }
}

impl BudgetLedger {
    /// Refund a previously-applied debit back to the ledger. Used by
    /// cancel-paths: if a debit was applied for an operation that
    /// later gets cancelled (user aborts, transport fails after debit
    /// but before any side-effect lands, etc), the cancel handler
    /// calls `refund` so the cap is restored.
    ///
    /// Uses `saturating_sub` so a refund larger than the current usage
    /// (which shouldn't happen in correct code) clamps to zero rather
    /// than wrapping to MAX. Pure function — returns the new ledger;
    /// caller writes it back.
    ///
    /// Phase 1 hardening — user's explicit list: "refund-on-cancel".
    #[must_use]
    pub const fn refund(self, debit: BudgetDebit) -> BudgetLedger {
        BudgetLedger {
            tokens_used: self.tokens_used.saturating_sub(debit.tokens),
            wall_used_ms: self.wall_used_ms.saturating_sub(debit.wall_ms),
            tool_calls_used: self.tool_calls_used.saturating_sub(debit.tool_calls),
            subprocess_used_ms: self
                .subprocess_used_ms
                .saturating_sub(debit.subprocess_ms),
            memory_bytes_used: self
                .memory_bytes_used
                .saturating_sub(debit.memory_bytes),
        }
    }
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
        // Memory bytes — Phase 1 hardening axis.
        let mem_total = ledger.memory_bytes_used.saturating_add(debit.memory_bytes);
        if self.spec.max_memory_bytes > 0 && mem_total > self.spec.max_memory_bytes {
            return Err(BudgetError::Exhausted {
                term: BudgetTerm::MemoryBytes,
                attempted_total: mem_total,
                cap: self.spec.max_memory_bytes,
            });
        }
        Ok(BudgetLedger {
            tokens_used: tokens_total,
            wall_used_ms: wall_total,
            tool_calls_used: tool_total,
            subprocess_used_ms: sub_total,
            memory_bytes_used: mem_total,
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
    fn budget_spec_new_zero_zero_zero_zero_equals_default() {
        // Phase 1 hardening — equivalence pin. BudgetSpec::new with
        // all-zero arguments must produce the same value as
        // BudgetSpec::default() (with_memory_bytes also defaulting
        // to 0). Pins the constructor's contract that "no args"
        // and "all zeros" are the same canonical unbounded state.
        //
        // A future refactor that changed BudgetSpec::new to default
        // any of the 4 args to a non-zero "safety" value would
        // silently diverge from default().
        let via_new = BudgetSpec::new(0, 0, 0, 0);
        let via_default = BudgetSpec::default();
        assert_eq!(via_new, via_default);
        assert_eq!(via_new.max_memory_bytes, via_default.max_memory_bytes);
    }

    #[test]
    fn budget_spec_ledger_and_debit_fields_are_pub_per_field_visibility_doctrine() {
        // Phase 1 hardening — field-visibility pin trio for
        // BudgetSpec / BudgetLedger / BudgetDebit (companion to the
        // field-visibility pin family iter-505..iter-511).
        //
        // All 3 budget types have 5 pub fields (the WBO-6 axis layout).
        // Direct field access is load-bearing for the dispatcher's
        // hot-path BudgetGate::check_and_debit + the audit serialiser.
        let spec = BudgetSpec::new(1, 2, 3, 4).with_memory_bytes(5);
        let _: u64 = spec.max_tokens;
        let _: u64 = spec.max_wall_ms;
        let _: u64 = spec.max_tool_calls;
        let _: u64 = spec.max_subprocess_ms;
        let _: u64 = spec.max_memory_bytes;
        assert_eq!(spec.max_tokens, 1);
        assert_eq!(spec.max_memory_bytes, 5);

        let ledger = BudgetLedger {
            tokens_used: 10,
            wall_used_ms: 20,
            tool_calls_used: 30,
            subprocess_used_ms: 40,
            memory_bytes_used: 50,
        };
        let _: u64 = ledger.tokens_used;
        let _: u64 = ledger.wall_used_ms;
        let _: u64 = ledger.tool_calls_used;
        let _: u64 = ledger.subprocess_used_ms;
        let _: u64 = ledger.memory_bytes_used;
        assert_eq!(ledger.memory_bytes_used, 50);

        let debit = BudgetDebit {
            tokens: 100,
            wall_ms: 200,
            tool_calls: 300,
            subprocess_ms: 400,
            memory_bytes: 500,
        };
        let _: u64 = debit.tokens;
        let _: u64 = debit.wall_ms;
        let _: u64 = debit.tool_calls;
        let _: u64 = debit.subprocess_ms;
        let _: u64 = debit.memory_bytes;
        assert_eq!(debit.memory_bytes, 500);
    }

    #[test]
    fn budget_spec_ledger_and_debit_struct_field_shapes_pinned_via_destructure() {
        // Phase 1 hardening — struct-field-shape pin trio for
        // BudgetSpec / BudgetLedger / BudgetDebit (companion to the
        // struct destructure pin family iter-464..iter-468).
        //
        // All 3 have the parallel 5-axis layout:
        //   BudgetSpec  : max_<axis>     (u64 each, 5 fields total)
        //   BudgetLedger: <axis>_used    (u64 each, 5 fields total)
        //   BudgetDebit : <axis>         (u64 each, 5 fields total)
        //
        // A future "let me add a max_network_bytes / network_bytes_used
        // / network_bytes" axis triple would silently fork every
        // persisted log + every gate site. Pin all 5 axes per struct
        // via destructure compile-fail.
        let BudgetSpec {
            max_tokens,
            max_wall_ms,
            max_tool_calls,
            max_subprocess_ms,
            max_memory_bytes,
        } = BudgetSpec::new(1, 2, 3, 4).with_memory_bytes(5);
        let _: u64 = max_tokens;
        let _: u64 = max_wall_ms;
        let _: u64 = max_tool_calls;
        let _: u64 = max_subprocess_ms;
        let _: u64 = max_memory_bytes;

        let BudgetLedger {
            tokens_used,
            wall_used_ms,
            tool_calls_used,
            subprocess_used_ms,
            memory_bytes_used,
        } = BudgetLedger::default();
        let _: u64 = tokens_used;
        let _: u64 = wall_used_ms;
        let _: u64 = tool_calls_used;
        let _: u64 = subprocess_used_ms;
        let _: u64 = memory_bytes_used;

        let BudgetDebit {
            tokens,
            wall_ms,
            tool_calls,
            subprocess_ms,
            memory_bytes,
        } = BudgetDebit::default();
        let _: u64 = tokens;
        let _: u64 = wall_ms;
        let _: u64 = tool_calls;
        let _: u64 = subprocess_ms;
        let _: u64 = memory_bytes;
    }

    #[test]
    fn budget_spec_default_is_all_zero_unbounded_for_every_term() {
        // Phase 1 hardening — pin Default::default() semantics. All
        // five fields zero == every term unbounded. A future refactor
        // that introduces a non-zero default (e.g. "safe" production
        // ceiling) would silently change the meaning of every
        // BudgetSpec::default() call site. Catch the change at PR
        // review.
        let s = BudgetSpec::default();
        assert_eq!(s.max_tokens, 0);
        assert_eq!(s.max_wall_ms, 0);
        assert_eq!(s.max_tool_calls, 0);
        assert_eq!(s.max_subprocess_ms, 0);
        assert_eq!(s.max_memory_bytes, 0);
        // BudgetGate with default spec accepts any debit (proved
        // independently in zero_cap_means_unbounded, but the link
        // between Default and unbounded must stay tight).
        let gate = BudgetGate::new(s);
        let debit = BudgetDebit {
            tokens: u64::MAX / 2,
            ..Default::default()
        };
        gate.check_and_debit(BudgetLedger::default(), debit)
            .expect("default spec must accept any debit");
    }

    #[test]
    fn budget_gate_new_with_default_spec_creates_fully_unbounded_gate() {
        // Phase 1 hardening — equivalence companion to iter-272's
        // BudgetSpec::new(0,0,0,0)==default pin.
        // BudgetGate::new(BudgetSpec::default()) must produce a
        // gate that accepts arbitrary debits on every axis.
        //
        // Companion to zero_cap_means_unbounded (uses default spec
        // already but pins via huge debit). This pin makes the
        // BudgetGate::new(default()) → unbounded contract explicit
        // as a single test scenario.
        let gate = BudgetGate::new(BudgetSpec::default());
        // Probe with a non-trivial debit on every axis simultaneously.
        let multi_axis = BudgetDebit {
            tokens: 100_000,
            wall_ms: 200_000,
            tool_calls: 50,
            subprocess_ms: 500_000,
            memory_bytes: 100_000_000,
        };
        let advanced = gate
            .check_and_debit(BudgetLedger::default(), multi_axis)
            .expect("default spec must accept multi-axis debit");
        assert_eq!(advanced.tokens_used, 100_000);
        assert_eq!(advanced.wall_used_ms, 200_000);
        assert_eq!(advanced.tool_calls_used, 50);
        assert_eq!(advanced.subprocess_used_ms, 500_000);
        assert_eq!(advanced.memory_bytes_used, 100_000_000);
    }

    #[test]
    fn mixed_caps_one_axis_bounded_others_unbounded_isolates_enforcement() {
        // Phase 1 hardening — independent-axis isolation pin. With
        // mixed caps (one axis bounded, others zero/unbounded), the
        // gate must enforce ONLY the bounded axis and accept any
        // value on the unbounded axes.
        //
        // Pin per-axis: for each axis A, set max_A to a small value
        // and leave the other 4 max_* at 0 (unbounded). Then:
        //   - debit on axis A that exceeds cap → trips Exhausted(A).
        //   - same debit with HUGE values on the OTHER 4 axes → still
        //     accepted (the other axes are unbounded).
        //
        // Companion to budget_gate_new_with_default_spec_creates_fully_unbounded_gate
        // (all-zero → all-unbounded) and zero_cap_means_unbounded
        // (single-axis cap=0 unbounded). Catches a future "let me
        // enforce a hidden cross-axis check" refactor.
        let huge_on_others = |bounded_axis: char| {
            let mut d = BudgetDebit {
                tokens: 1_000_000,
                wall_ms: 1_000_000,
                tool_calls: 1_000,
                subprocess_ms: 1_000_000,
                memory_bytes: 1_000_000,
            };
            // Zero out the bounded axis so the WHOLE-debit test isn't
            // tripped by the bounded axis itself.
            match bounded_axis {
                't' => d.tokens = 0,
                'w' => d.wall_ms = 0,
                'c' => d.tool_calls = 0,
                's' => d.subprocess_ms = 0,
                'm' => d.memory_bytes = 0,
                _ => unreachable!(),
            }
            d
        };

        // tokens bounded, others unbounded.
        let gate_t = BudgetGate::new(BudgetSpec::new(100, 0, 0, 0));
        let _ = gate_t
            .check_and_debit(BudgetLedger::default(), huge_on_others('t'))
            .expect("non-tokens huge debits accepted under tokens-only cap");

        // wall_ms bounded, others unbounded.
        let gate_w = BudgetGate::new(BudgetSpec::new(0, 100, 0, 0));
        let _ = gate_w
            .check_and_debit(BudgetLedger::default(), huge_on_others('w'))
            .expect("non-wall huge debits accepted under wall_ms-only cap");

        // tool_calls bounded, others unbounded.
        let gate_c = BudgetGate::new(BudgetSpec::new(0, 0, 5, 0));
        let _ = gate_c
            .check_and_debit(BudgetLedger::default(), huge_on_others('c'))
            .expect("non-tool huge debits accepted under tool_calls-only cap");

        // subprocess_ms bounded, others unbounded.
        let gate_s = BudgetGate::new(BudgetSpec::new(0, 0, 0, 100));
        let _ = gate_s
            .check_and_debit(BudgetLedger::default(), huge_on_others('s'))
            .expect("non-subprocess huge debits accepted under subprocess-only cap");

        // memory_bytes bounded, others unbounded.
        let gate_m = BudgetGate::new(BudgetSpec::default().with_memory_bytes(1024));
        let _ = gate_m
            .check_and_debit(BudgetLedger::default(), huge_on_others('m'))
            .expect("non-memory huge debits accepted under memory_bytes-only cap");
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
            memory_bytes: u64::MAX / 2,
        };
        let ledger = BudgetLedger::default();
        gate.check_and_debit(ledger, huge).expect("unbounded gate must accept any debit");
    }

    #[test]
    fn budget_gate_axis_check_order_pins_full_5_axis_priority_chain() {
        // Phase 1 hardening — companion to first_tripped_term_is_reported
        // (which pins Tokens > Wall). check_and_debit checks axes in
        // source order:
        //   Tokens → WallMs → ToolCalls → SubprocessMs → MemoryBytes
        // When MULTIPLE axes would trip, the FIRST in this order is
        // reported.
        //
        // A future refactor that reordered the axis checks would
        // silently change audit-attribution semantics. Pin the full
        // 5-axis priority chain via pairwise probes.

        // Tokens > WallMs (already covered by existing first_tripped_term_is_reported)
        // WallMs > ToolCalls
        let gate_wm = BudgetGate::new(BudgetSpec::new(0, 10, 0, 0).with_memory_bytes(0));
        let err = gate_wm
            .check_and_debit(
                BudgetLedger::default(),
                BudgetDebit { wall_ms: 100, tool_calls: u64::MAX, ..Default::default() },
            )
            .expect_err("over wall + over tool_calls");
        assert!(
            matches!(err, BudgetError::Exhausted { term: BudgetTerm::WallMs, .. }),
            "WallMs must take priority over ToolCalls, got {err:?}"
        );

        // ToolCalls > SubprocessMs
        let gate_tc = BudgetGate::new(BudgetSpec::new(0, 0, 1, 0));
        let err = gate_tc
            .check_and_debit(
                BudgetLedger::default(),
                BudgetDebit { tool_calls: 10, subprocess_ms: u64::MAX, ..Default::default() },
            )
            .expect_err("over tool_calls + over subprocess");
        assert!(
            matches!(err, BudgetError::Exhausted { term: BudgetTerm::ToolCalls, .. }),
            "ToolCalls must take priority over SubprocessMs, got {err:?}"
        );

        // SubprocessMs > MemoryBytes
        let gate_sm = BudgetGate::new(BudgetSpec::new(0, 0, 0, 10).with_memory_bytes(10));
        let err = gate_sm
            .check_and_debit(
                BudgetLedger::default(),
                BudgetDebit { subprocess_ms: 100, memory_bytes: 100, ..Default::default() },
            )
            .expect_err("over subprocess + over memory");
        assert!(
            matches!(err, BudgetError::Exhausted { term: BudgetTerm::SubprocessMs, .. }),
            "SubprocessMs must take priority over MemoryBytes, got {err:?}"
        );
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
    fn budget_const_fn_annotations_compile_in_const_context() {
        // Phase 1 hardening — compile-time pin for the `const fn`
        // annotations on the canonical constructors / builders. The
        // following const-context items compile if-and-only-if every
        // called function is `const fn`. A future refactor that
        // dropped `const` from any of these signatures would surface
        // as a compile failure right here (NOT a silent runtime
        // regression in callers that depend on const-context usage).
        //
        // Pins: BudgetSpec::new, BudgetSpec::with_memory_bytes,
        //       BudgetDebit::for_tool_call, BudgetDebit::for_thinking_turn,
        //       BudgetLedger::refund, BudgetGate::new, BudgetGate::spec,
        //       BudgetTerm::code.
        const SPEC: BudgetSpec = BudgetSpec::new(1_000, 60_000, 5, 30_000);
        const SPEC_WITH_MEM: BudgetSpec = SPEC.with_memory_bytes(1_048_576);
        const DEBIT_TOOL: BudgetDebit = BudgetDebit::for_tool_call(100, 50);
        const DEBIT_THINK: BudgetDebit = BudgetDebit::for_thinking_turn(200, 100);
        const REFUNDED: BudgetLedger = BudgetLedger {
            tokens_used: 100,
            wall_used_ms: 0,
            tool_calls_used: 1,
            subprocess_used_ms: 0,
            memory_bytes_used: 0,
        }
        .refund(DEBIT_TOOL);
        const GATE: BudgetGate = BudgetGate::new(SPEC_WITH_MEM);
        const GATE_SPEC: BudgetSpec = GATE.spec();
        const TERM_CODE: &str = BudgetTerm::Tokens.code();

        // Runtime sanity (the test is a compile-time gate; assert
        // a few values to keep the const items live).
        assert_eq!(SPEC.max_tokens, 1_000);
        assert_eq!(SPEC_WITH_MEM.max_memory_bytes, 1_048_576);
        assert_eq!(DEBIT_TOOL.tokens, 150);
        assert_eq!(DEBIT_TOOL.tool_calls, 1);
        assert_eq!(DEBIT_THINK.tokens, 300);
        assert_eq!(DEBIT_THINK.tool_calls, 0);
        // Refund saturates: started with tokens_used=100, refunded 150 → 0.
        assert_eq!(REFUNDED.tokens_used, 0);
        assert_eq!(REFUNDED.tool_calls_used, 0);
        assert_eq!(GATE_SPEC.max_memory_bytes, 1_048_576);
        assert_eq!(TERM_CODE, "tokens");
    }

    #[test]
    fn every_budget_spec_field_is_identity_load_bearing() {
        // Phase 1 hardening — ninth leg of the identity-pin pattern.
        // BudgetSpec has 5 fields (max_tokens, max_wall_ms,
        // max_tool_calls, max_subprocess_ms, max_memory_bytes); each
        // must participate in PartialEq. The existing
        // budget_spec_serde_rejects_json_missing_required_field test
        // covers MISSING fields on deserialise; this pins that all
        // 5 fields contribute to equality at the value level. A
        // silent #[serde(skip)] / PartialEq override dropping any
        // field would let a tight cap and a loose cap compare
        // equal — wrong for cache keying and audit.
        let base = BudgetSpec::new(1_000, 60_000, 5, 30_000).with_memory_bytes(1_024 * 1_024);

        let mut diff_tokens = base;
        diff_tokens.max_tokens += 1;
        assert_ne!(diff_tokens, base, "max_tokens must participate in PartialEq");

        let mut diff_wall = base;
        diff_wall.max_wall_ms += 1;
        assert_ne!(diff_wall, base, "max_wall_ms must participate in PartialEq");

        let mut diff_tool = base;
        diff_tool.max_tool_calls += 1;
        assert_ne!(diff_tool, base, "max_tool_calls must participate in PartialEq");

        let mut diff_sub = base;
        diff_sub.max_subprocess_ms += 1;
        assert_ne!(diff_sub, base, "max_subprocess_ms must participate in PartialEq");

        let mut diff_mem = base;
        diff_mem.max_memory_bytes += 1;
        assert_ne!(diff_mem, base, "max_memory_bytes must participate in PartialEq");

        // Sanity preserved (Copy semantics).
        assert_eq!(base, base);
    }

    #[test]
    fn every_budget_debit_field_is_identity_load_bearing() {
        // Phase 1 hardening — tenth leg of the identity-pin pattern.
        // BudgetDebit has 5 u64 fields (tokens, wall_ms, tool_calls,
        // subprocess_ms, memory_bytes). The existing
        // budget_debit_default_is_all_zero_across_every_axis pins
        // the default. This pins inequality propagation when each
        // field is independently mutated.
        let base = BudgetDebit {
            tokens: 100,
            wall_ms: 200,
            tool_calls: 3,
            subprocess_ms: 400,
            memory_bytes: 5_000,
        };

        let mut diff_tokens = base;
        diff_tokens.tokens += 1;
        assert_ne!(diff_tokens, base, "tokens must participate in PartialEq");

        let mut diff_wall = base;
        diff_wall.wall_ms += 1;
        assert_ne!(diff_wall, base, "wall_ms must participate in PartialEq");

        let mut diff_tool = base;
        diff_tool.tool_calls += 1;
        assert_ne!(diff_tool, base, "tool_calls must participate in PartialEq");

        let mut diff_sub = base;
        diff_sub.subprocess_ms += 1;
        assert_ne!(diff_sub, base, "subprocess_ms must participate in PartialEq");

        let mut diff_mem = base;
        diff_mem.memory_bytes += 1;
        assert_ne!(diff_mem, base, "memory_bytes must participate in PartialEq");

        // Sanity preserved.
        assert_eq!(base, base);
    }

    #[test]
    fn every_budget_ledger_field_is_identity_load_bearing() {
        // Phase 1 hardening — eleventh leg of the identity-pin
        // pattern. BudgetLedger has 5 u64 fields (tokens_used,
        // wall_used_ms, tool_calls_used, subprocess_used_ms,
        // memory_bytes_used). The existing
        // budget_ledger_default_is_all_zero pins the default and
        // budget_ledger_complete_round_trip_preserves_all_five_fields
        // pins the serde round-trip; this pins value-level inequality
        // propagation when each field is independently mutated.
        let base = BudgetLedger {
            tokens_used: 100,
            wall_used_ms: 200,
            tool_calls_used: 3,
            subprocess_used_ms: 400,
            memory_bytes_used: 5_000,
        };

        let mut diff_tokens = base;
        diff_tokens.tokens_used += 1;
        assert_ne!(diff_tokens, base, "tokens_used must participate in PartialEq");

        let mut diff_wall = base;
        diff_wall.wall_used_ms += 1;
        assert_ne!(diff_wall, base, "wall_used_ms must participate in PartialEq");

        let mut diff_tool = base;
        diff_tool.tool_calls_used += 1;
        assert_ne!(diff_tool, base, "tool_calls_used must participate in PartialEq");

        let mut diff_sub = base;
        diff_sub.subprocess_used_ms += 1;
        assert_ne!(diff_sub, base, "subprocess_used_ms must participate in PartialEq");

        let mut diff_mem = base;
        diff_mem.memory_bytes_used += 1;
        assert_ne!(diff_mem, base, "memory_bytes_used must participate in PartialEq");

        // Sanity preserved.
        assert_eq!(base, base);
    }

    #[test]
    fn budget_gate_check_and_debit_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the idempotency series: iter-168 / iter-217 /
        // iter-218 / iter-219). BudgetGate::check_and_debit is pure
        // (no &mut self, no interior mutability). Same gate +
        // same ledger + same debit → same result across calls.
        //
        // A future refactor that introduced a stateful side
        // (e.g., logging counter on the gate, throttle state) would
        // silently break the pure-function contract that callers
        // — especially the concurrent dispatcher pool — depend on.
        let gate = BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0));
        let ledger = BudgetLedger::default();
        let debit = BudgetDebit { tokens: 25, tool_calls: 1, ..Default::default() };

        let first = gate.check_and_debit(ledger, debit);
        let second = gate.check_and_debit(ledger, debit);
        let third = gate.check_and_debit(ledger, debit);
        assert_eq!(first, second);
        assert_eq!(second, third);
        // The gate's spec is unchanged by repeated calls.
        assert_eq!(gate.spec(), BudgetSpec::new(1_000, 0, 5, 0));

        // Same property holds for the rejection path.
        let over_budget = BudgetDebit { tokens: 10_000, ..Default::default() };
        let r1 = gate.check_and_debit(ledger, over_budget);
        let r2 = gate.check_and_debit(ledger, over_budget);
        assert_eq!(r1, r2);
        assert!(r1.is_err());
    }

    #[test]
    fn budget_term_and_error_are_copy_clone_send_sync_for_propagation_safety() {
        // Phase 1 hardening MILESTONE iter-370 — trait-bound pin sweep
        // across the closed-taxonomy payload enums in budget.rs.
        // Companion to budget_gate, mode (iter-366), StopReason (iter-367),
        // VariantTier (iter-368), LocalAgent Tier/Owner/Surface (iter-369).
        //
        // BudgetTerm: 5-variant unit enum marked Copy via derive
        // (budget.rs §109). It rides inside BudgetError::Exhausted, which
        // is in turn carried by SealError::Budget — the error attribution
        // path is hot, and Copy keeps the field freely propagatable
        // without coordination.
        //
        // BudgetError: 1-variant enum with Copy payload (BudgetTerm + 2 u64)
        // marked Copy via derive (budget.rs §141). Copy on the outer
        // error type means the inner term can be probed without owning
        // the error.
        //
        // BudgetSpec / BudgetLedger / BudgetDebit: 5-field structs all
        // marked Copy via derive (lines 30/83/97). The dispatcher
        // copies these freely between gate sites and ledger snapshots.
        //
        // A future "let me add a Vec<MeterReading> to BudgetSpec" or
        // "let me store BudgetTerm as String for flexibility" refactor
        // would break the Copy contract — surface here.
        fn assert_copy_clone_send_sync<T: Copy + Clone + Send + Sync>() {}
        assert_copy_clone_send_sync::<BudgetTerm>();
        assert_copy_clone_send_sync::<BudgetError>();
        assert_copy_clone_send_sync::<BudgetSpec>();
        assert_copy_clone_send_sync::<BudgetLedger>();
        assert_copy_clone_send_sync::<BudgetDebit>();

        // Runtime sanity: copy + use both bindings.
        let term = BudgetTerm::MemoryBytes;
        let _ta = term; let _tb = term; assert_eq!(term, term);
        let err = BudgetError::Exhausted {
            term: BudgetTerm::Tokens,
            attempted_total: 100,
            cap: 50,
        };
        let _ea = err; let _eb = err; assert_eq!(err, err);
    }

    #[test]
    fn budget_gate_is_copy_and_clone_for_pure_function_semantics() {
        // Phase 1 hardening — BudgetGate is intentionally a tiny
        // value type (1 BudgetSpec) marked Copy. No spec_mut, no
        // interior mutability. Multiple gates can share the same
        // spec across threads without coordination. Pin the
        // pure-function shape so a future refactor that introduces
        // hidden state surfaces here at PR review.
        let gate = BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0));
        let copy = gate; // Copy semantics — no move.
        let clone = gate; // Use the original again after the copy.
        assert_eq!(copy.spec(), gate.spec());
        assert_eq!(clone.spec(), gate.spec());
        // The trait bounds also encode the contract.
        fn assert_copy_clone_send_sync<T: Copy + Clone + Send + Sync>() {}
        assert_copy_clone_send_sync::<BudgetGate>();
    }

    #[test]
    fn budget_gate_spec_getter_returns_construction_spec() {
        // Phase 1 hardening — defensive: the spec() getter has been
        // present since the gate landed (iter-3). Pin its behaviour
        // so a future refactor doesn't silently drop it.
        let spec = BudgetSpec::new(1_234, 5_678, 9, 42)
            .with_memory_bytes(98_765);
        let gate = BudgetGate::new(spec);
        let read_back = gate.spec();
        assert_eq!(read_back.max_tokens, 1_234);
        assert_eq!(read_back.max_wall_ms, 5_678);
        assert_eq!(read_back.max_tool_calls, 9);
        assert_eq!(read_back.max_subprocess_ms, 42);
        assert_eq!(read_back.max_memory_bytes, 98_765);
        assert_eq!(read_back, spec);
    }

    #[test]
    fn pre_over_cap_ledger_with_zero_debit_still_trips_exhausted_per_doctrine() {
        // Phase 1 hardening — DEFENSIVE doctrine pin. If the ledger
        // arrives at the gate ALREADY over cap (a state the gate
        // should never produce under normal operation, but COULD
        // happen via a manually-constructed BudgetLedger or a buggy
        // refund-path), then even a ZERO debit must trip Exhausted.
        //
        // Contract logic: tokens_total = 2000.saturating_add(0) = 2000,
        // spec.max_tokens = 1000 > 0, 2000 > 1000 → Exhausted.
        //
        // This is the "fail-stop" property — once over cap, the gate
        // doesn't let any further calls (even no-op probes) succeed.
        //
        // Defends against a future "let me let zero-debits through as
        // an optimisation" refactor that would silently mask invalid
        // ledger states.
        let gate = BudgetGate::new(BudgetSpec::new(1_000, 0, 0, 0));
        let over_cap_ledger = BudgetLedger {
            tokens_used: 2_000,
            ..Default::default()
        };
        let err = gate
            .check_and_debit(over_cap_ledger, BudgetDebit::default())
            .expect_err("zero debit on over-cap ledger must still trip Exhausted");
        match err {
            BudgetError::Exhausted { term: BudgetTerm::Tokens, attempted_total, cap } => {
                assert_eq!(attempted_total, 2_000);
                assert_eq!(cap, 1_000);
            }
            other => panic!("expected Exhausted(Tokens), got {other:?}"),
        }
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
    fn boundary_cap_plus_one_rejected_across_all_five_axes() {
        // Phase 1 hardening — 5-axis completeness companion to
        // boundary_equal_to_cap_accepted_across_all_five_axes (just-
        // pinned). The strict-`>` boundary contract REJECTS one byte
        // over cap on EVERY WBO-6 axis.
        //
        // For each axis: ledger pre-loaded with cap - 100; debit adds
        // 101; final total would be cap + 1; gate trips Exhausted with
        // the correct BudgetTerm + attempted_total=cap+1 + cap=cap.
        //
        // Defends against a future "let me micro-optimise to use
        // saturating-clamp instead of reject" refactor that would
        // silently let over-cap debits land.

        // wall_ms axis.
        let gate_w = BudgetGate::new(BudgetSpec::new(0, 1_000, 0, 0));
        let l_w = BudgetLedger { wall_used_ms: 900, ..Default::default() };
        let err_w = gate_w
            .check_and_debit(l_w, BudgetDebit { wall_ms: 101, ..Default::default() })
            .expect_err("wall_ms cap+1 must reject");
        match err_w {
            BudgetError::Exhausted { term: BudgetTerm::WallMs, attempted_total, cap } => {
                assert_eq!(attempted_total, 1_001);
                assert_eq!(cap, 1_000);
            }
            other => panic!("expected Exhausted(WallMs), got {other:?}"),
        }

        // tool_calls axis.
        let gate_tc = BudgetGate::new(BudgetSpec::new(0, 0, 10, 0));
        let l_tc = BudgetLedger { tool_calls_used: 9, ..Default::default() };
        let err_tc = gate_tc
            .check_and_debit(l_tc, BudgetDebit { tool_calls: 2, ..Default::default() })
            .expect_err("tool_calls cap+1 must reject");
        match err_tc {
            BudgetError::Exhausted { term: BudgetTerm::ToolCalls, attempted_total, cap } => {
                assert_eq!(attempted_total, 11);
                assert_eq!(cap, 10);
            }
            other => panic!("expected Exhausted(ToolCalls), got {other:?}"),
        }

        // subprocess_ms axis.
        let gate_sm = BudgetGate::new(BudgetSpec::new(0, 0, 0, 1_000));
        let l_sm = BudgetLedger { subprocess_used_ms: 900, ..Default::default() };
        let err_sm = gate_sm
            .check_and_debit(l_sm, BudgetDebit { subprocess_ms: 101, ..Default::default() })
            .expect_err("subprocess_ms cap+1 must reject");
        match err_sm {
            BudgetError::Exhausted { term: BudgetTerm::SubprocessMs, attempted_total, cap } => {
                assert_eq!(attempted_total, 1_001);
                assert_eq!(cap, 1_000);
            }
            other => panic!("expected Exhausted(SubprocessMs), got {other:?}"),
        }

        // memory_bytes axis.
        let gate_mb = BudgetGate::new(BudgetSpec::default().with_memory_bytes(1_024));
        let l_mb = BudgetLedger { memory_bytes_used: 1_000, ..Default::default() };
        let err_mb = gate_mb
            .check_and_debit(l_mb, BudgetDebit { memory_bytes: 25, ..Default::default() })
            .expect_err("memory_bytes cap+1 must reject");
        match err_mb {
            BudgetError::Exhausted { term: BudgetTerm::MemoryBytes, attempted_total, cap } => {
                assert_eq!(attempted_total, 1_025);
                assert_eq!(cap, 1_024);
            }
            other => panic!("expected Exhausted(MemoryBytes), got {other:?}"),
        }
    }

    #[test]
    fn boundary_equal_to_cap_accepted_across_all_five_axes() {
        // Phase 1 hardening — 5-axis completeness companion to
        // boundary_equal_to_cap_accepted (which only exercises tokens).
        // The strict-`>` boundary contract MUST hold independently for
        // every WBO-6 axis.
        //
        // For each axis: ledger pre-loaded with cap - 100; debit adds
        // exactly 100; final usage lands at the cap exactly; gate
        // accepts.
        //
        // Defends against a future "let me micro-optimise the gate's
        // boundary check from `>` to `>=`" refactor on any single axis
        // — would silently reject at-cap debits on that axis only.

        // wall_ms axis.
        let gate_w = BudgetGate::new(BudgetSpec::new(0, 1_000, 0, 0));
        let l_w = BudgetLedger { wall_used_ms: 900, ..Default::default() };
        let a_w = gate_w
            .check_and_debit(l_w, BudgetDebit { wall_ms: 100, ..Default::default() })
            .expect("wall_ms at-cap debit must accept");
        assert_eq!(a_w.wall_used_ms, 1_000);

        // tool_calls axis.
        let gate_tc = BudgetGate::new(BudgetSpec::new(0, 0, 10, 0));
        let l_tc = BudgetLedger { tool_calls_used: 9, ..Default::default() };
        let a_tc = gate_tc
            .check_and_debit(l_tc, BudgetDebit { tool_calls: 1, ..Default::default() })
            .expect("tool_calls at-cap debit must accept");
        assert_eq!(a_tc.tool_calls_used, 10);

        // subprocess_ms axis.
        let gate_sm = BudgetGate::new(BudgetSpec::new(0, 0, 0, 1_000));
        let l_sm = BudgetLedger { subprocess_used_ms: 900, ..Default::default() };
        let a_sm = gate_sm
            .check_and_debit(l_sm, BudgetDebit { subprocess_ms: 100, ..Default::default() })
            .expect("subprocess_ms at-cap debit must accept");
        assert_eq!(a_sm.subprocess_used_ms, 1_000);

        // memory_bytes axis.
        let gate_mb = BudgetGate::new(BudgetSpec::default().with_memory_bytes(1_024));
        let l_mb = BudgetLedger { memory_bytes_used: 1_000, ..Default::default() };
        let a_mb = gate_mb
            .check_and_debit(l_mb, BudgetDebit { memory_bytes: 24, ..Default::default() })
            .expect("memory_bytes at-cap debit must accept");
        assert_eq!(a_mb.memory_bytes_used, 1_024);
    }

    #[test]
    fn budget_term_code_aligns_with_budget_ledger_field_name_via_used_suffix() {
        // Phase 1 hardening — naming-alignment pin (closes the
        // 3-struct family: BudgetSpec [max_ prefix], BudgetDebit
        // [no affix], BudgetLedger [_used suffix] at iter-557/558/559).
        // BudgetLedger field names carry a "_used" suffix that
        // BudgetDebit/BudgetSpec do not — but the STEM (the part
        // between max_/empty and _used/empty) must match BudgetTerm
        // .code() across all 5 axes. Specifically:
        //   tokens_used      ↔ tokens
        //   wall_used_ms     ↔ wall_ms
        //   tool_calls_used  ↔ tool_calls
        //   subprocess_used_ms ↔ subprocess_ms
        //   memory_bytes_used ↔ memory_bytes
        //
        // Note the awkward "wall_used_ms" / "subprocess_used_ms" —
        // the suffix lands inside the term name for the *_ms axes.
        // That irregularity is itself doctrine and is worth pinning.
        // A future rename to "wall_ms_used" / "subprocess_ms_used"
        // (more consistent) would silently break the
        // RunEventLog ledger snapshot persistence format.
        let cases = [
            (BudgetTerm::Tokens, "tokens_used"),
            (BudgetTerm::WallMs, "wall_used_ms"),
            (BudgetTerm::ToolCalls, "tool_calls_used"),
            (BudgetTerm::SubprocessMs, "subprocess_used_ms"),
            (BudgetTerm::MemoryBytes, "memory_bytes_used"),
        ];
        let ledger = BudgetLedger {
            tokens_used: 1,
            wall_used_ms: 2,
            tool_calls_used: 3,
            subprocess_used_ms: 4,
            memory_bytes_used: 5,
        };
        let json = serde_json::to_string(&ledger).expect("serialize ledger");
        for (_term, expected_field) in cases {
            assert!(
                json.contains(&format!("\"{expected_field}\":")),
                "expected serialised ledger to contain field {expected_field:?}, got {json}"
            );
        }
    }

    #[test]
    fn budget_term_code_equals_budget_debit_field_name_exactly() {
        // Phase 1 hardening — naming-alignment pin (companion to
        // budget_term_code_equals_budget_spec_field_name_minus_max_prefix).
        // BudgetDebit uses unprefixed field names (tokens / wall_ms /
        // tool_calls / subprocess_ms / memory_bytes) — which must
        // match BudgetTerm.code() exactly (no prefix manipulation
        // needed). Pin asserts the BudgetDebit JSON keys match
        // BudgetTerm.code() byte-for-byte for all 5 axes. A drift
        // would silently break:
        //   1. RunEventLog SealedMutation row dashboards that group
        //      by axis name.
        //   2. BudgetError::Exhausted error attribution where the
        //      term field shows the human-readable axis label.
        let cases = [
            (BudgetTerm::Tokens, "tokens"),
            (BudgetTerm::WallMs, "wall_ms"),
            (BudgetTerm::ToolCalls, "tool_calls"),
            (BudgetTerm::SubprocessMs, "subprocess_ms"),
            (BudgetTerm::MemoryBytes, "memory_bytes"),
        ];
        // BudgetDebit JSON serialisation produces snake_case keys
        // matching the field names. A non-zero value per field +
        // serialisation contains the corresponding key.
        let debit = BudgetDebit {
            tokens: 1,
            wall_ms: 2,
            tool_calls: 3,
            subprocess_ms: 4,
            memory_bytes: 5,
        };
        let json = serde_json::to_string(&debit).expect("serialize debit");
        for (term, expected_field) in cases {
            assert_eq!(
                term.code(), expected_field,
                "BudgetTerm::{term:?}::code() must equal BudgetDebit field name {expected_field:?}"
            );
            assert!(
                json.contains(&format!("\"{expected_field}\":")),
                "expected serialised debit to contain field {expected_field:?}, got {json}"
            );
        }
    }

    #[test]
    fn budget_term_code_equals_budget_spec_field_name_minus_max_prefix() {
        // Phase 1 hardening — naming-alignment pin. BudgetTerm::code()
        // returns the canonical short term ("tokens", "wall_ms", ...);
        // BudgetSpec has matching fields prefixed with "max_"
        // (max_tokens, max_wall_ms, ...). The doctrine is "code() ==
        // BudgetSpec field name with the max_ prefix stripped". This
        // doctrine appears nowhere in code as a constraint — only as
        // a convention. Pin asserts the convention so a future
        // refactor that diverged either side (e.g., renamed
        // max_tokens to tokens_cap on the spec side, or renamed
        // code() output to upper-snake) surfaces here at PR review.
        //
        // The serialised BudgetSpec JSON keys are also derived from
        // these field names — so a drift would silently break
        // every BudgetSpec audit dashboard that filters by key.
        let cases = [
            (BudgetTerm::Tokens, "max_tokens"),
            (BudgetTerm::WallMs, "max_wall_ms"),
            (BudgetTerm::ToolCalls, "max_tool_calls"),
            (BudgetTerm::SubprocessMs, "max_subprocess_ms"),
            (BudgetTerm::MemoryBytes, "max_memory_bytes"),
        ];
        for (term, expected_field) in cases {
            let derived = format!("max_{}", term.code());
            assert_eq!(
                derived, expected_field,
                "BudgetTerm::{term:?}::code() = {:?}, derived field name {derived:?} \
                 must match BudgetSpec field {expected_field:?}",
                term.code()
            );
        }
        // And the serialised BudgetSpec JSON keys must match the
        // expected field names exactly — cross-check via a sample
        // serialisation.
        let spec = BudgetSpec::new(1, 2, 3, 4).with_memory_bytes(5);
        let json = serde_json::to_string(&spec).expect("serialize spec");
        for (_term, field) in cases {
            assert!(
                json.contains(&format!("\"{field}\":")),
                "expected serialised spec to contain field {field:?}, got {json}"
            );
        }
    }

    #[test]
    fn each_budget_term_variant_corresponds_to_exactly_one_budget_spec_axis() {
        // Phase 1 hardening — 5-to-5 mapping pin. BudgetTerm enum
        // has 5 variants (Tokens, WallMs, ToolCalls, SubprocessMs,
        // MemoryBytes); BudgetSpec has 5 max_* fields. Each variant
        // corresponds to exactly one axis; check_and_debit tripping
        // on axis N must report term N.
        //
        // A future refactor that mixed up the mapping (e.g., wired
        // max_tokens to a different BudgetTerm) would silently
        // mis-attribute Exhausted errors in audit dashboards.
        let pairs = [
            // (spec_setter_value-bearing axis, debit-bearing axis,
            //  expected BudgetTerm)
            (
                BudgetSpec::new(10, 0, 0, 0),
                BudgetDebit { tokens: 100, ..Default::default() },
                BudgetTerm::Tokens,
            ),
            (
                BudgetSpec::new(0, 10, 0, 0),
                BudgetDebit { wall_ms: 100, ..Default::default() },
                BudgetTerm::WallMs,
            ),
            (
                BudgetSpec::new(0, 0, 1, 0),
                BudgetDebit { tool_calls: 10, ..Default::default() },
                BudgetTerm::ToolCalls,
            ),
            (
                BudgetSpec::new(0, 0, 0, 10),
                BudgetDebit { subprocess_ms: 100, ..Default::default() },
                BudgetTerm::SubprocessMs,
            ),
            (
                BudgetSpec::default().with_memory_bytes(10),
                BudgetDebit { memory_bytes: 100, ..Default::default() },
                BudgetTerm::MemoryBytes,
            ),
        ];
        for (spec, debit, expected_term) in pairs {
            let gate = BudgetGate::new(spec);
            let err = gate
                .check_and_debit(BudgetLedger::default(), debit)
                .expect_err(&format!("axis for {expected_term:?} should trip"));
            assert!(
                matches!(err, BudgetError::Exhausted { term, .. } if term == expected_term),
                "expected term {expected_term:?}, got {err:?}"
            );
        }
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
    fn debit_factories_are_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series). BudgetDebit::for_tool_call
        // and for_thinking_turn are const fns over Copy inputs;
        // pure.
        for prompt in [0u64, 1, 100, u64::MAX / 2] {
            for completion in [0u64, 1, 100] {
                let t1 = BudgetDebit::for_tool_call(prompt, completion);
                let t2 = BudgetDebit::for_tool_call(prompt, completion);
                assert_eq!(t1, t2, "tool_call non-determinism for ({prompt}, {completion})");
                let th1 = BudgetDebit::for_thinking_turn(prompt, completion);
                let th2 = BudgetDebit::for_thinking_turn(prompt, completion);
                assert_eq!(
                    th1, th2,
                    "thinking_turn non-determinism for ({prompt}, {completion})"
                );
            }
        }
    }

    #[test]
    fn debit_for_tool_call_sums_tokens_and_sets_tool_calls_one() {
        let d = BudgetDebit::for_tool_call(120, 80);
        assert_eq!(d.tokens, 200);
        assert_eq!(d.tool_calls, 1);
        assert_eq!(d.wall_ms, 0);
        assert_eq!(d.subprocess_ms, 0);
    }

    #[test]
    fn debit_for_thinking_turn_has_zero_tool_calls() {
        let d = BudgetDebit::for_thinking_turn(500, 200);
        assert_eq!(d.tokens, 700);
        assert_eq!(d.tool_calls, 0);
    }

    #[test]
    fn debit_for_tool_call_and_for_thinking_turn_emit_zero_on_all_non_token_axes() {
        // Phase 1 hardening — 5-axis completeness pin for the two
        // canonical debit constructors. Existing pins cover:
        //   - tool_call: tokens sum + tool_calls=1 + wall_ms=0 + subprocess_ms=0
        //   - thinking_turn: tokens sum + tool_calls=0
        //
        // Neither test asserts `memory_bytes == 0` (the newest axis,
        // added during Phase 1 hardening). A future "let me default
        // memory_bytes to estimated payload size" refactor would
        // silently start over-charging the memory axis for every
        // tool call.
        //
        // Pin ALL 5 axes explicitly for both constructors.
        let tc = BudgetDebit::for_tool_call(100, 50);
        assert_eq!(tc.tokens, 150);
        assert_eq!(tc.wall_ms, 0);
        assert_eq!(tc.tool_calls, 1);
        assert_eq!(tc.subprocess_ms, 0);
        assert_eq!(tc.memory_bytes, 0, "for_tool_call must default memory_bytes to 0");

        let th = BudgetDebit::for_thinking_turn(200, 100);
        assert_eq!(th.tokens, 300);
        assert_eq!(th.wall_ms, 0);
        assert_eq!(th.tool_calls, 0);
        assert_eq!(th.subprocess_ms, 0);
        assert_eq!(th.memory_bytes, 0, "for_thinking_turn must default memory_bytes to 0");
    }

    #[test]
    fn debit_for_thinking_turn_with_zero_zero_produces_full_zero_debit() {
        // Phase 1 hardening — boundary pin companion to
        // debit_for_tool_call_with_zero_zero_still_sets_tool_calls_to_one
        // (iter-443). for_thinking_turn(0, 0) is also a legitimate
        // call (a thinking-only turn that emitted zero tokens — e.g.,
        // an aborted-mid-thinking turn). Unlike for_tool_call, the
        // for_thinking_turn helper sets tool_calls = 0 because no
        // tool was invoked.
        //
        // The 5-axis result with (0, 0) input is the all-zero debit:
        //   tokens=0, wall_ms=0, tool_calls=0, subprocess_ms=0, memory_bytes=0
        // == BudgetDebit::default().
        //
        // A future "let me track thinking-only turns via a non-zero
        // sentinel even at zero tokens" refactor would silently
        // diverge for_thinking_turn(0, 0) from BudgetDebit::default().
        let d = BudgetDebit::for_thinking_turn(0, 0);
        assert_eq!(d, BudgetDebit::default(), "for_thinking_turn(0, 0) must equal default debit");
        assert_eq!(d.tokens, 0);
        assert_eq!(d.tool_calls, 0);
        assert_eq!(d.wall_ms, 0);
        assert_eq!(d.subprocess_ms, 0);
        assert_eq!(d.memory_bytes, 0);
    }

    #[test]
    fn debit_for_tool_call_with_zero_zero_still_sets_tool_calls_to_one() {
        // Phase 1 hardening — boundary pin. for_tool_call(0, 0) is
        // a legitimate call (a tool that took zero prompt + zero
        // completion tokens — e.g., a deterministic T1 tool returning
        // a precomputed result). The tokens axis correctly sums to 0,
        // BUT the tool_calls counter MUST still increment to 1 because
        // the helper's contract is "one tool call's worth of debit".
        //
        // A future "let me skip tool_calls=1 when tokens are zero as
        // an optimisation" refactor would silently undercount tool
        // calls for deterministic-tier tools.
        let d = BudgetDebit::for_tool_call(0, 0);
        assert_eq!(d.tokens, 0);
        assert_eq!(d.tool_calls, 1, "for_tool_call ALWAYS bumps tool_calls regardless of token cost");
        assert_eq!(d.wall_ms, 0);
        assert_eq!(d.subprocess_ms, 0);
        assert_eq!(d.memory_bytes, 0);
    }

    #[test]
    fn debit_for_tool_call_saturates_on_overflow() {
        let d = BudgetDebit::for_tool_call(u64::MAX, 1);
        // saturating_add prevents wrap.
        assert_eq!(d.tokens, u64::MAX);
    }

    #[test]
    fn refund_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series). BudgetLedger::refund
        // is a saturating_sub on each axis; pure over Copy inputs.
        let ledger = BudgetLedger {
            tokens_used: 100,
            wall_used_ms: 200,
            tool_calls_used: 3,
            subprocess_used_ms: 400,
            memory_bytes_used: 500,
        };
        let debit = BudgetDebit {
            tokens: 25,
            wall_ms: 50,
            tool_calls: 1,
            subprocess_ms: 100,
            memory_bytes: 100,
        };
        let r1 = ledger.refund(debit);
        let r2 = ledger.refund(debit);
        let r3 = ledger.refund(debit);
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
        // Original ledger unchanged (Copy semantics).
        assert_eq!(ledger.tokens_used, 100);
    }

    #[test]
    fn refund_restores_cap_after_cancel() {
        // Apply a debit, then refund it, then verify the original
        // cap is fully restored (so a fresh debit at the cap edge
        // would succeed).
        let gate = BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0));
        let initial = BudgetLedger::default();
        let debit = BudgetDebit { tokens: 700, tool_calls: 2, ..Default::default() };
        let after_apply = gate.check_and_debit(initial, debit).expect("fits");
        assert_eq!(after_apply.tokens_used, 700);
        let after_refund = after_apply.refund(debit);
        assert_eq!(after_refund.tokens_used, 0);
        assert_eq!(after_refund.tool_calls_used, 0);
        // A subsequent debit at the cap still fits.
        let final_ = gate
            .check_and_debit(after_refund, BudgetDebit { tokens: 1_000, ..Default::default() })
            .expect("post-refund debit fits original cap");
        assert_eq!(final_.tokens_used, 1_000);
    }

    #[test]
    fn concurrent_refund_on_cancel_restores_cap_after_burst() {
        // Phase 1 hardening — work-queue B refund-on-cancel race.
        // Multiple in-flight debits can land before the user cancels
        // them; each cancel handler refunds its own debit under the
        // same ledger lock. After every refund joins, the cap must be
        // fully restored and reusable at the exact boundary.
        use std::sync::{Arc, Mutex};
        use std::thread;

        const N: u64 = 8;
        const TOKENS_PER_CALL: u64 = 125;
        let gate = BudgetGate::new(BudgetSpec::new(N * TOKENS_PER_CALL, 0, N, 0));
        let debit = BudgetDebit {
            tokens: TOKENS_PER_CALL,
            tool_calls: 1,
            ..Default::default()
        };
        let ledger = Arc::new(Mutex::new(BudgetLedger::default()));

        let mut debit_handles = Vec::with_capacity(N as usize);
        for _ in 0..N {
            let l = Arc::clone(&ledger);
            debit_handles.push(thread::spawn(move || {
                let mut guard = l.lock().expect("lock");
                *guard = gate.check_and_debit(*guard, debit).expect("debit fits");
            }));
        }
        for handle in debit_handles {
            handle.join().expect("debit join");
        }

        let after_burst = *ledger.lock().expect("lock");
        assert_eq!(after_burst.tokens_used, N * TOKENS_PER_CALL);
        assert_eq!(after_burst.tool_calls_used, N);

        let mut refund_handles = Vec::with_capacity(N as usize);
        for _ in 0..N {
            let l = Arc::clone(&ledger);
            refund_handles.push(thread::spawn(move || {
                let mut guard = l.lock().expect("lock");
                *guard = guard.refund(debit);
            }));
        }
        for handle in refund_handles {
            handle.join().expect("refund join");
        }

        let after_cancel = *ledger.lock().expect("lock");
        assert_eq!(after_cancel, BudgetLedger::default());
        let final_ = gate
            .check_and_debit(
                after_cancel,
                BudgetDebit {
                    tokens: N * TOKENS_PER_CALL,
                    tool_calls: N,
                    ..Default::default()
                },
            )
            .expect("post-cancel cap boundary must be reusable");
        assert_eq!(final_.tokens_used, N * TOKENS_PER_CALL);
        assert_eq!(final_.tool_calls_used, N);
    }

    #[test]
    fn zero_debit_refund_is_identity_companion_to_zero_debit_check_and_debit() {
        // Phase 1 hardening — symmetric companion to
        // zero_debit_is_identity_through_check_and_debit. Both
        // operations should treat BudgetDebit::default() as the
        // additive identity (no-op):
        //   - check_and_debit(ledger, default()) → ledger (already pinned)
        //   - ledger.refund(default()) → ledger              (pinned here)
        //
        // A future "let me track implicit overhead on every refund"
        // refactor that added a non-zero base cost would break the
        // identity property silently — the existing
        // refund_saturates_at_zero test only covers OVER-refunds and
        // refund_restores_cap_after_cancel only covers non-zero
        // debit pairs. This pin closes the zero-debit gap.
        let ledger = BudgetLedger {
            tokens_used: 50,
            wall_used_ms: 100,
            tool_calls_used: 3,
            subprocess_used_ms: 150,
            memory_bytes_used: 12_345,
        };
        let after = ledger.refund(BudgetDebit::default());
        // Every field byte-equal — zero debit is identity for refund.
        assert_eq!(after.tokens_used, ledger.tokens_used);
        assert_eq!(after.wall_used_ms, ledger.wall_used_ms);
        assert_eq!(after.tool_calls_used, ledger.tool_calls_used);
        assert_eq!(after.subprocess_used_ms, ledger.subprocess_used_ms);
        assert_eq!(after.memory_bytes_used, ledger.memory_bytes_used);
        assert_eq!(after, ledger);

        // Also: a default-ledger refunded by default-debit stays at
        // default. Identity-on-identity.
        let fresh = BudgetLedger::default();
        assert_eq!(fresh.refund(BudgetDebit::default()), BudgetLedger::default());
    }

    #[test]
    fn refund_saturates_at_zero_when_over_refunded() {
        // Defensive: a refund larger than the current usage must clamp
        // to zero, not wrap to u64::MAX.
        let l = BudgetLedger { tokens_used: 50, ..Default::default() };
        let refunded = l.refund(BudgetDebit { tokens: 200, ..Default::default() });
        assert_eq!(refunded.tokens_used, 0);
    }

    #[test]
    fn refund_saturates_at_zero_across_all_five_axes() {
        // Phase 1 hardening — 5-axis completeness companion to
        // refund_saturates_at_zero_when_over_refunded (tokens only).
        // Parallel to iter-310's
        // budget_overflow_at_u64_max_boundary_does_not_panic_for_all_five_axes.
        //
        // Each of the 5 axes uses saturating_sub independently; pin
        // that an over-refund on each axis clamps to 0, not wraps to
        // u64::MAX. Catches a future "let me micro-optimise refund
        // with plain `-`" refactor that would panic on debug builds
        // and silently underflow to MAX on release for the less-
        // exercised axes (wall_ms / memory_bytes).
        //
        // Tokens already covered — start at wall_ms.
        let l_w = BudgetLedger { wall_used_ms: 50, ..Default::default() };
        let r_w = l_w.refund(BudgetDebit { wall_ms: 200, ..Default::default() });
        assert_eq!(r_w.wall_used_ms, 0, "wall_ms over-refund must clamp to 0");

        let l_tc = BudgetLedger { tool_calls_used: 2, ..Default::default() };
        let r_tc = l_tc.refund(BudgetDebit { tool_calls: 99, ..Default::default() });
        assert_eq!(r_tc.tool_calls_used, 0, "tool_calls over-refund must clamp to 0");

        let l_sm = BudgetLedger { subprocess_used_ms: 100, ..Default::default() };
        let r_sm = l_sm.refund(BudgetDebit { subprocess_ms: 10_000, ..Default::default() });
        assert_eq!(r_sm.subprocess_used_ms, 0, "subprocess_ms over-refund must clamp to 0");

        let l_mb = BudgetLedger { memory_bytes_used: 1_024, ..Default::default() };
        let r_mb = l_mb.refund(BudgetDebit { memory_bytes: u64::MAX, ..Default::default() });
        assert_eq!(r_mb.memory_bytes_used, 0, "memory_bytes over-refund must clamp to 0");

        // Cross-axis: all 5 axes simultaneously over-refunded.
        let big_debit = BudgetDebit {
            tokens: 1_000_000,
            wall_ms: 1_000_000,
            tool_calls: 1_000_000,
            subprocess_ms: 1_000_000,
            memory_bytes: 1_000_000,
        };
        let small_ledger = BudgetLedger {
            tokens_used: 1,
            wall_used_ms: 1,
            tool_calls_used: 1,
            subprocess_used_ms: 1,
            memory_bytes_used: 1,
        };
        let cleared = small_ledger.refund(big_debit);
        assert_eq!(cleared, BudgetLedger::default(), "cross-axis over-refund clears the ledger");
    }

    #[test]
    fn refund_is_per_term_independent() {
        let l = BudgetLedger {
            tokens_used: 100,
            wall_used_ms: 5_000,
            tool_calls_used: 3,
            subprocess_used_ms: 10_000,
            ..Default::default()
        };
        let r = l.refund(BudgetDebit { tokens: 25, ..Default::default() });
        assert_eq!(r.tokens_used, 75);
        // Other terms untouched.
        assert_eq!(r.wall_used_ms, 5_000);
        assert_eq!(r.tool_calls_used, 3);
        assert_eq!(r.subprocess_used_ms, 10_000);
    }

    #[test]
    fn budget_gate_concurrency_minimum_2_thread_safety_under_tight_cap() {
        // Phase 1 hardening — minimum-thread boundary pin
        // (companion to budget_gate_concurrency_no_over_debit which
        // uses 32 threads). The 2-thread case is the smallest non-
        // trivial concurrency scenario: two threads each draw 50
        // tokens through a Mutex<BudgetLedger> with a cap of exactly
        // 100. Both must succeed; cap must be exactly hit.
        use std::sync::{Arc, Mutex};
        use std::thread;

        let gate = BudgetGate::new(BudgetSpec::new(100, 0, 0, 0));
        let ledger = Arc::new(Mutex::new(BudgetLedger::default()));

        let l1 = Arc::clone(&ledger);
        let l2 = Arc::clone(&ledger);
        let h1 = thread::spawn(move || {
            let mut guard = l1.lock().expect("lock");
            let next = gate
                .check_and_debit(*guard, BudgetDebit { tokens: 50, ..Default::default() })
                .expect("first debit");
            *guard = next;
        });
        let h2 = thread::spawn(move || {
            let mut guard = l2.lock().expect("lock");
            let next = gate
                .check_and_debit(*guard, BudgetDebit { tokens: 50, ..Default::default() })
                .expect("second debit");
            *guard = next;
        });
        h1.join().expect("join 1");
        h2.join().expect("join 2");

        let final_ledger = *ledger.lock().expect("lock");
        assert_eq!(final_ledger.tokens_used, 100);

        // One more debit must trip the cap exactly at the boundary.
        let err = gate
            .check_and_debit(final_ledger, BudgetDebit { tokens: 1, ..Default::default() })
            .expect_err("post-burst debit must trip cap");
        assert!(matches!(err, BudgetError::Exhausted { term: BudgetTerm::Tokens, .. }));
    }

    #[test]
    fn budget_gate_concurrency_no_over_debit_on_remaining_three_axes() {
        // Phase 1 hardening MILESTONE iter-390 — closes the
        // BudgetGate concurrency-pin coverage across all 5 WBO-6 axes.
        // Existing pins:
        //   - tokens: 2-thread + 32-thread
        //   - memory_bytes: 16-thread (iter-313)
        // This pin: wall_ms + tool_calls + subprocess_ms each under
        // an 8-thread concurrent burst — proves the saturating_add
        // hot-path holds independently for every axis.
        //
        // 8 threads is a deliberately-modest count; the property is
        // "exactly hits the cap; one more debit trips Exhausted".
        use std::sync::{Arc, Mutex};
        use std::thread;

        const N: u64 = 8;
        const PER_CALL: u64 = 100;

        // wall_ms axis.
        {
            let gate = BudgetGate::new(BudgetSpec::new(0, N * PER_CALL, 0, 0));
            let ledger = Arc::new(Mutex::new(BudgetLedger::default()));
            let mut handles = Vec::with_capacity(N as usize);
            for _ in 0..N {
                let l = Arc::clone(&ledger);
                handles.push(thread::spawn(move || {
                    let mut guard = l.lock().expect("lock");
                    let advanced = gate
                        .check_and_debit(
                            *guard,
                            BudgetDebit { wall_ms: PER_CALL, ..Default::default() },
                        )
                        .expect("wall_ms debit fits");
                    *guard = advanced;
                }));
            }
            for h in handles { h.join().expect("join"); }
            let final_ledger = *ledger.lock().expect("lock");
            assert_eq!(final_ledger.wall_used_ms, N * PER_CALL);
            let err = gate
                .check_and_debit(
                    final_ledger,
                    BudgetDebit { wall_ms: 1, ..Default::default() },
                )
                .expect_err("post-burst wall_ms debit must trip cap");
            assert!(matches!(
                err,
                BudgetError::Exhausted { term: BudgetTerm::WallMs, .. }
            ));
        }

        // tool_calls axis.
        {
            let gate = BudgetGate::new(BudgetSpec::new(0, 0, N * PER_CALL, 0));
            let ledger = Arc::new(Mutex::new(BudgetLedger::default()));
            let mut handles = Vec::with_capacity(N as usize);
            for _ in 0..N {
                let l = Arc::clone(&ledger);
                handles.push(thread::spawn(move || {
                    let mut guard = l.lock().expect("lock");
                    let advanced = gate
                        .check_and_debit(
                            *guard,
                            BudgetDebit { tool_calls: PER_CALL, ..Default::default() },
                        )
                        .expect("tool_calls debit fits");
                    *guard = advanced;
                }));
            }
            for h in handles { h.join().expect("join"); }
            let final_ledger = *ledger.lock().expect("lock");
            assert_eq!(final_ledger.tool_calls_used, N * PER_CALL);
            let err = gate
                .check_and_debit(
                    final_ledger,
                    BudgetDebit { tool_calls: 1, ..Default::default() },
                )
                .expect_err("post-burst tool_calls debit must trip cap");
            assert!(matches!(
                err,
                BudgetError::Exhausted { term: BudgetTerm::ToolCalls, .. }
            ));
        }

        // subprocess_ms axis.
        {
            let gate = BudgetGate::new(BudgetSpec::new(0, 0, 0, N * PER_CALL));
            let ledger = Arc::new(Mutex::new(BudgetLedger::default()));
            let mut handles = Vec::with_capacity(N as usize);
            for _ in 0..N {
                let l = Arc::clone(&ledger);
                handles.push(thread::spawn(move || {
                    let mut guard = l.lock().expect("lock");
                    let advanced = gate
                        .check_and_debit(
                            *guard,
                            BudgetDebit { subprocess_ms: PER_CALL, ..Default::default() },
                        )
                        .expect("subprocess_ms debit fits");
                    *guard = advanced;
                }));
            }
            for h in handles { h.join().expect("join"); }
            let final_ledger = *ledger.lock().expect("lock");
            assert_eq!(final_ledger.subprocess_used_ms, N * PER_CALL);
            let err = gate
                .check_and_debit(
                    final_ledger,
                    BudgetDebit { subprocess_ms: 1, ..Default::default() },
                )
                .expect_err("post-burst subprocess_ms debit must trip cap");
            assert!(matches!(
                err,
                BudgetError::Exhausted { term: BudgetTerm::SubprocessMs, .. }
            ));
        }
    }

    #[test]
    fn budget_gate_concurrency_no_over_debit_on_memory_bytes_axis() {
        // Phase 1 hardening — concurrency completeness across the
        // non-tokens axes. The existing 2-thread + 32-thread tests
        // both exercise the `tokens` axis. memory_bytes is the
        // newest WBO-6 axis (Phase 1 hardening); pin that the
        // same "no over-debit, exact cap-hit" invariant holds for
        // it under a 16-thread concurrent burst.
        //
        // Defends against a future "let me cache `tokens_used`
        // separately for hot-path read" optimisation that
        // accidentally bypasses the saturating_add path for the
        // less-exercised memory_bytes axis.
        use std::sync::{Arc, Mutex};
        use std::thread;

        const N: u64 = 16;
        const PER_CALL: u64 = 4_096;
        let gate = BudgetGate::new(
            BudgetSpec::default().with_memory_bytes(N * PER_CALL),
        );
        let ledger = Arc::new(Mutex::new(BudgetLedger::default()));
        let mut handles = Vec::with_capacity(N as usize);
        for _ in 0..N {
            let l = Arc::clone(&ledger);
            handles.push(thread::spawn(move || {
                let mut guard = l.lock().expect("lock");
                let advanced = gate
                    .check_and_debit(
                        *guard,
                        BudgetDebit {
                            memory_bytes: PER_CALL,
                            ..Default::default()
                        },
                    )
                    .expect("memory_bytes debit fits");
                *guard = advanced;
            }));
        }
        for h in handles {
            h.join().expect("join");
        }
        let final_ledger = *ledger.lock().expect("lock");
        assert_eq!(final_ledger.memory_bytes_used, N * PER_CALL);
        // Other axes untouched.
        assert_eq!(final_ledger.tokens_used, 0);
        assert_eq!(final_ledger.wall_used_ms, 0);
        assert_eq!(final_ledger.tool_calls_used, 0);
        assert_eq!(final_ledger.subprocess_used_ms, 0);

        // One more byte must trip the cap.
        let err = gate
            .check_and_debit(
                final_ledger,
                BudgetDebit { memory_bytes: 1, ..Default::default() },
            )
            .expect_err("post-burst memory_bytes debit must trip cap");
        assert!(matches!(
            err,
            BudgetError::Exhausted { term: BudgetTerm::MemoryBytes, .. }
        ));
    }

    #[test]
    fn budget_gate_concurrency_no_over_debit() {
        // Concurrency property: N threads each call check_and_debit
        // through a shared Mutex<BudgetLedger>. The cap is exactly
        // N * per-call, so every call must succeed AND the final
        // ledger must equal N * per-call (no over-debit, no
        // double-count).
        use std::sync::{Arc, Mutex};
        use std::thread;

        const N: u64 = 32;
        const PER_CALL: u64 = 10;
        let gate = BudgetGate::new(BudgetSpec::new(N * PER_CALL, 0, 0, 0));
        let ledger = Arc::new(Mutex::new(BudgetLedger::default()));
        let mut handles = Vec::with_capacity(N as usize);
        for _ in 0..N {
            let l = Arc::clone(&ledger);
            handles.push(thread::spawn(move || {
                let mut guard = l.lock().expect("lock");
                let advanced = gate
                    .check_and_debit(
                        *guard,
                        BudgetDebit { tokens: PER_CALL, ..Default::default() },
                    )
                    .expect("debit fits");
                *guard = advanced;
            }));
        }
        for h in handles {
            h.join().expect("join");
        }
        let final_ledger = *ledger.lock().expect("lock");
        assert_eq!(final_ledger.tokens_used, N * PER_CALL);

        // One more call must trip Exhausted — proves the cap really
        // is at the boundary after the concurrent burst.
        let err = gate
            .check_and_debit(
                final_ledger,
                BudgetDebit { tokens: 1, ..Default::default() },
            )
            .expect_err("post-burst debit must trip cap");
        assert!(matches!(err, BudgetError::Exhausted { term: BudgetTerm::Tokens, .. }));
    }

    #[test]
    fn budget_term_variant_count_is_five() {
        // Phase 1 hardening — cardinality pin completing the
        // count-pin series across every closed-taxonomy enum.
        // BudgetTerm has 5 variants (Tokens, WallMs, ToolCalls,
        // SubprocessMs, MemoryBytes) — one per WBO-6 budget axis.
        //
        // The existing budget_term_match_arm_coverage_via_closed_taxonomy_probe
        // pins codes().len() == 5 (the code STRINGS), but not the
        // variants themselves. A future variant addition (e.g.,
        // a NetworkBytes axis when the Sealer learns to gate
        // egress) would slip past the existing tests if the new
        // variant happened to share a code with an existing one
        // (theoretical but pin it).
        let variants = [
            BudgetTerm::Tokens,
            BudgetTerm::WallMs,
            BudgetTerm::ToolCalls,
            BudgetTerm::SubprocessMs,
            BudgetTerm::MemoryBytes,
        ];
        assert_eq!(variants.len(), 5);
        for i in 0..variants.len() {
            for j in (i + 1)..variants.len() {
                assert_ne!(
                    variants[i], variants[j],
                    "terms[{i}] and terms[{j}] must be distinct"
                );
            }
        }
    }

    #[test]
    fn budget_term_match_arm_coverage_via_closed_taxonomy_probe() {
        // Phase 1 hardening — closed-taxonomy probe. The .code()
        // method matches over all BudgetTerm variants exhaustively
        // (no `_ =>` arm); a future addition without doc update
        // would fail to compile. This test EXERCISES the closed
        // taxonomy at runtime: every variant must produce a
        // non-empty code AND all 5 codes must be observed in a
        // fixture set. If a new variant is added without updating
        // the fixture, this test surfaces the gap (variant count
        // mismatch).
        let fixture = [
            BudgetTerm::Tokens,
            BudgetTerm::WallMs,
            BudgetTerm::ToolCalls,
            BudgetTerm::SubprocessMs,
            BudgetTerm::MemoryBytes,
        ];
        let codes: std::collections::HashSet<&str> =
            fixture.iter().map(|t| t.code()).collect();
        assert_eq!(codes.len(), 5, "expected 5 distinct term codes");
        for term in fixture {
            assert!(!term.code().is_empty(), "{term:?} code must be non-empty");
            // Display agrees with code (already pinned elsewhere,
            // re-stated here as part of the closed-taxonomy probe).
            assert_eq!(format!("{term}"), term.code());
        }
    }

    #[test]
    fn budget_error_exhausted_field_shape_pinned_to_term_total_cap() {
        // Phase 1 hardening — field-shape pin for BudgetError::Exhausted
        // (companion to
        // mission_prompt_error_oversize_field_shape_pinned_to_exactly_size_and_cap
        // iter-454). The variant carries EXACTLY 3 named fields
        // (term: BudgetTerm, attempted_total: u64, cap: u64).
        //
        // A future "let me add a 4th field like {term, attempted_total,
        // cap, axis_id}" refactor would silently change the error
        // payload size — surface here via the destructure match arm.
        let err = BudgetError::Exhausted {
            term: BudgetTerm::Tokens,
            attempted_total: 2_000,
            cap: 1_000,
        };
        match err {
            BudgetError::Exhausted { term, attempted_total, cap } => {
                // Exactly 3 fields. Type assertions verify the typed shape.
                let _: BudgetTerm = term;
                let _: u64 = attempted_total;
                let _: u64 = cap;
                assert_eq!(term, BudgetTerm::Tokens);
                assert_eq!(attempted_total, 2_000);
                assert_eq!(cap, 1_000);
            }
        }
    }

    #[test]
    fn budget_error_exhausted_inner_fields_are_identity_load_bearing() {
        // Phase 1 hardening — inner-field distinctness pin
        // (companion to iter-197 ToolCallError::BadName).
        // BudgetError::Exhausted carries 3 fields: term,
        // attempted_total, cap. Each must participate in PartialEq
        // derivation so two Exhausted errors with different
        // attempted_totals OR different caps compare unequal —
        // audit replay relies on the distinct triples for
        // attribution.
        let base = BudgetError::Exhausted {
            term: BudgetTerm::Tokens,
            attempted_total: 100,
            cap: 50,
        };
        // Different term → unequal.
        assert_ne!(
            base,
            BudgetError::Exhausted {
                term: BudgetTerm::WallMs,
                attempted_total: 100,
                cap: 50,
            }
        );
        // Different attempted_total → unequal.
        assert_ne!(
            base,
            BudgetError::Exhausted {
                term: BudgetTerm::Tokens,
                attempted_total: 101,
                cap: 50,
            }
        );
        // Different cap → unequal.
        assert_ne!(
            base,
            BudgetError::Exhausted {
                term: BudgetTerm::Tokens,
                attempted_total: 100,
                cap: 49,
            }
        );
        // Identical → equal.
        assert_eq!(
            base,
            BudgetError::Exhausted {
                term: BudgetTerm::Tokens,
                attempted_total: 100,
                cap: 50,
            }
        );
    }

    #[test]
    fn budget_error_exhausted_debug_repr_is_stable_for_audit_persistence() {
        // Phase 1 hardening — audit-log surface. BudgetError is the
        // only failure mode of check_and_debit; its Debug repr lands
        // in incident reports + CI failure output. Pin the exact
        // format so any future refactor (e.g. tuple variant, field
        // rename) surfaces at PR review rather than silently
        // breaking grep-based audit dashboards. Field order:
        // term, attempted_total, cap.
        let err = BudgetError::Exhausted {
            term: BudgetTerm::Tokens,
            attempted_total: 12_345,
            cap: 10_000,
        };
        let dbg = format!("{err:?}");
        assert_eq!(
            dbg,
            "Exhausted { term: Tokens, attempted_total: 12345, cap: 10000 }"
        );
        // Field-order sensitivity.
        let t_idx = dbg.find("term").expect("term field");
        let a_idx = dbg.find("attempted_total").expect("attempted_total field");
        let c_idx = dbg.find("cap").expect("cap field");
        assert!(t_idx < a_idx, "term must appear before attempted_total");
        assert!(a_idx < c_idx, "attempted_total must appear before cap");
        // Cover each BudgetTerm variant so a future rename of any
        // variant catches here.
        for term in [
            BudgetTerm::Tokens,
            BudgetTerm::WallMs,
            BudgetTerm::ToolCalls,
            BudgetTerm::SubprocessMs,
            BudgetTerm::MemoryBytes,
        ] {
            let e = BudgetError::Exhausted { term, attempted_total: 1, cap: 0 };
            let s = format!("{e:?}");
            assert!(s.contains(&format!("{term:?}")), "debug includes {term:?}");
        }
    }

    #[test]
    fn budget_term_all_five_codes_are_distinct_and_lowercase_snake_case() {
        // Phase 1 hardening — code() values are persistence keys
        // embedded in BudgetError audit logs + WBO-6 docs. All 5
        // must be distinct (collisions would silently merge audit
        // counters) and snake_case lowercase (UX consistency
        // across all wbo terms). A future rename surfaces here.
        let codes = [
            BudgetTerm::Tokens.code(),
            BudgetTerm::WallMs.code(),
            BudgetTerm::ToolCalls.code(),
            BudgetTerm::SubprocessMs.code(),
            BudgetTerm::MemoryBytes.code(),
        ];
        // Pairwise distinct.
        for i in 0..codes.len() {
            for j in (i + 1)..codes.len() {
                assert_ne!(codes[i], codes[j], "codes[{i}] == codes[{j}]");
            }
        }
        // Snake_case lowercase rule: only [a-z_].
        for c in codes {
            assert!(
                c.chars().all(|ch| ch.is_ascii_lowercase() || ch == '_'),
                "code {c:?} must be lowercase snake_case"
            );
            assert!(!c.is_empty(), "code must be non-empty");
        }
    }

    #[test]
    fn budget_term_display_equals_code_for_log_persistence_parity() {
        // Phase 1 hardening — Display and code() must produce
        // identical strings for every variant so log dashboards and
        // JSON persistence never disagree on the term label.
        for term in [
            BudgetTerm::Tokens,
            BudgetTerm::WallMs,
            BudgetTerm::ToolCalls,
            BudgetTerm::SubprocessMs,
            BudgetTerm::MemoryBytes,
        ] {
            assert_eq!(format!("{term}"), term.code());
        }
    }

    #[test]
    fn budget_term_helpers_are_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — runtime determinism pin (companion to
        // the purity series). BudgetTerm::code returns &'static str
        // and Display::fmt writes it; pure.
        for term in [
            BudgetTerm::Tokens,
            BudgetTerm::WallMs,
            BudgetTerm::ToolCalls,
            BudgetTerm::SubprocessMs,
            BudgetTerm::MemoryBytes,
        ] {
            for _ in 0..3 {
                assert_eq!(term.code(), term.code());
                assert_eq!(format!("{term}"), format!("{term}"));
            }
        }
    }

    #[test]
    fn budget_term_codes_are_stable() {
        // Stability matters because RunEventLog persists these as
        // strings; a rename would silently fork replay parity.
        assert_eq!(BudgetTerm::Tokens.code(), "tokens");
        assert_eq!(BudgetTerm::WallMs.code(), "wall_ms");
        assert_eq!(BudgetTerm::ToolCalls.code(), "tool_calls");
        assert_eq!(BudgetTerm::SubprocessMs.code(), "subprocess_ms");
        assert_eq!(BudgetTerm::MemoryBytes.code(), "memory_bytes");
    }

    #[test]
    fn budget_spec_serde_json_preserves_struct_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin extending iter-158
        // (presence + count) with field-order. BudgetSpec declares
        // its 5 fields as: max_tokens, max_wall_ms, max_tool_calls,
        // max_subprocess_ms, max_memory_bytes. A future reorder
        // breaks byte-equal cache keys + diff tools.
        let spec = BudgetSpec::new(1_000, 60_000, 5, 30_000).with_memory_bytes(1_024);
        let s = serde_json::to_string(&spec).expect("serialise");
        let expected_keys_in_order = [
            "\"max_tokens\":",
            "\"max_wall_ms\":",
            "\"max_tool_calls\":",
            "\"max_subprocess_ms\":",
            "\"max_memory_bytes\":",
        ];
        let mut last_idx: Option<usize> = None;
        for key in expected_keys_in_order {
            let pos = s.find(key).unwrap_or_else(|| panic!("key {key} not found in {s}"));
            if let Some(prev) = last_idx {
                assert!(
                    pos > prev,
                    "field {key} at byte {pos} must appear after previous field at {prev}"
                );
            }
            last_idx = Some(pos);
        }
    }

    #[test]
    fn budget_spec_serde_json_contains_all_five_canonical_top_level_keys() {
        // Phase 1 hardening — wire-shape pin matching the
        // established pattern. BudgetSpec has 5 top-level fields
        // (max_tokens, max_wall_ms, max_tool_calls,
        // max_subprocess_ms, max_memory_bytes); a silent rename
        // would round-trip but break vault-side consumers, audit
        // dashboards, and Swift bridge BudgetSpec mirrors.
        let spec = BudgetSpec::new(1_000, 60_000, 5, 30_000).with_memory_bytes(1_024);
        let json = serde_json::to_value(&spec).expect("serialise");
        let obj = json.as_object().expect("BudgetSpec serialises as JSON object");
        for key in [
            "max_tokens",
            "max_wall_ms",
            "max_tool_calls",
            "max_subprocess_ms",
            "max_memory_bytes",
        ] {
            assert!(
                obj.contains_key(key),
                "missing top-level key {key:?} in {json:?}"
            );
        }
        assert_eq!(
            obj.len(),
            5,
            "expected exactly 5 top-level keys, got {} ({:?})",
            obj.len(),
            obj.keys().collect::<Vec<_>>()
        );
    }

    #[test]
    fn budget_ledger_complete_round_trip_preserves_all_five_fields() {
        // Phase 1 hardening — full BudgetLedger round-trip: build
        // with all 5 fields non-default, serialise, deserialise,
        // assert bitwise equality. Pins that serde Default + skip
        // semantics don't accidentally truncate a complete payload.
        let ledger = BudgetLedger {
            tokens_used: 12_345,
            wall_used_ms: 678_901,
            tool_calls_used: 23,
            subprocess_used_ms: 4_567,
            memory_bytes_used: 89_012_345,
        };
        let s = serde_json::to_string(&ledger).expect("serialise");
        let back: BudgetLedger = serde_json::from_str(&s).expect("deserialise");
        assert_eq!(back, ledger);
        // Specifically pin every field — Eq alone wouldn't catch a
        // silent rename that still typechecks.
        assert_eq!(back.tokens_used, 12_345);
        assert_eq!(back.wall_used_ms, 678_901);
        assert_eq!(back.tool_calls_used, 23);
        assert_eq!(back.subprocess_used_ms, 4_567);
        assert_eq!(back.memory_bytes_used, 89_012_345);
    }

    #[test]
    fn budget_spec_serde_tolerates_unknown_extra_fields_per_current_doctrine() {
        // Phase 1 hardening — DOCTRINE PIN with forward-compat teeth.
        // Companion to the serde-tolerance pin family across the
        // agent_runtime_v2 user-facing structs (MissionPacket,
        // AnswerPacket, AgentBlueprint, MutationEnvelope, ToolCall,
        // Citation, LocalAgentCapability, VariantLadderSpec, AgentEvent,
        // RunEventEntry). BudgetSpec is embedded in AgentBlueprint AND
        // surfaces directly through configuration files.
        //
        // BudgetSpec does NOT carry #[serde(deny_unknown_fields)]. A
        // future axis (e.g., max_network_bytes when egress gating
        // lands) added to BudgetSpec in vN+1 and reverted before vN+2
        // must still let vN+2 readers parse the captured row — extras
        // silently drop.
        //
        // Pin the lenient behaviour so a future
        // #[serde(deny_unknown_fields)] addition surfaces at PR review
        // as a deliberate doctrine change.
        let spec = BudgetSpec::new(1_000, 60_000, 5, 30_000)
            .with_memory_bytes(1_048_576);
        let s = serde_json::to_string(&spec).expect("serialise");
        let last_brace = s.rfind('}').expect("trailing brace");
        let mut augmented = String::with_capacity(s.len() + 40);
        augmented.push_str(&s[..last_brace]);
        augmented.push_str(r#","max_network_bytes":1024}"#);
        let parsed: BudgetSpec =
            serde_json::from_str(&augmented).expect("unknown field tolerated");
        assert_eq!(parsed, spec);
    }

    #[test]
    fn budget_spec_serde_rejects_json_missing_required_field() {
        // Phase 1 hardening — #[serde(default)] is ONLY on
        // max_memory_bytes (back-rev addition). The other four
        // fields are required; missing them must fail to deserialise.
        // Pins the contract so a future "let me make everything
        // optional for convenience" pull request surfaces here.
        let missing_max_tokens = r#"{
            "max_wall_ms": 0,
            "max_tool_calls": 0,
            "max_subprocess_ms": 0
        }"#;
        assert!(
            serde_json::from_str::<BudgetSpec>(missing_max_tokens).is_err(),
            "missing max_tokens must fail to deserialise"
        );

        let missing_max_wall_ms = r#"{
            "max_tokens": 1000,
            "max_tool_calls": 0,
            "max_subprocess_ms": 0
        }"#;
        assert!(serde_json::from_str::<BudgetSpec>(missing_max_wall_ms).is_err());

        let missing_max_tool_calls = r#"{
            "max_tokens": 1000,
            "max_wall_ms": 0,
            "max_subprocess_ms": 0
        }"#;
        assert!(serde_json::from_str::<BudgetSpec>(missing_max_tool_calls).is_err());

        let missing_max_subprocess_ms = r#"{
            "max_tokens": 1000,
            "max_wall_ms": 0,
            "max_tool_calls": 0
        }"#;
        assert!(serde_json::from_str::<BudgetSpec>(missing_max_subprocess_ms).is_err());

        // Sanity: ALL four required fields present + missing
        // max_memory_bytes still deserialises (backward-compat).
        let legacy_complete = r#"{
            "max_tokens": 1000,
            "max_wall_ms": 0,
            "max_tool_calls": 0,
            "max_subprocess_ms": 0
        }"#;
        let s: BudgetSpec = serde_json::from_str(legacy_complete).unwrap();
        assert_eq!(s.max_memory_bytes, 0);
    }

    #[test]
    fn budget_ledger_serde_json_preserves_struct_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin extending iter-160
        // (presence + count) with field-order. BudgetLedger
        // declares its 5 fields as: tokens_used, wall_used_ms,
        // tool_calls_used, subprocess_used_ms, memory_bytes_used.
        // A future reorder breaks ledger_at_ordinal byte-shape +
        // .epbundle replay byte-equal cache consumers.
        let ledger = BudgetLedger {
            tokens_used: 100,
            wall_used_ms: 200,
            tool_calls_used: 3,
            subprocess_used_ms: 400,
            memory_bytes_used: 500,
        };
        let s = serde_json::to_string(&ledger).expect("serialise");
        let expected_keys_in_order = [
            "\"tokens_used\":",
            "\"wall_used_ms\":",
            "\"tool_calls_used\":",
            "\"subprocess_used_ms\":",
            "\"memory_bytes_used\":",
        ];
        let mut last_idx: Option<usize> = None;
        for key in expected_keys_in_order {
            let pos = s.find(key).unwrap_or_else(|| panic!("key {key} not found in {s}"));
            if let Some(prev) = last_idx {
                assert!(
                    pos > prev,
                    "field {key} at byte {pos} must appear after previous field at {prev}"
                );
            }
            last_idx = Some(pos);
        }
    }

    #[test]
    fn budget_ledger_serde_json_contains_all_five_canonical_top_level_keys() {
        // Phase 1 hardening — wire-shape pin matching the
        // established pattern. BudgetLedger has 5 top-level fields
        // (tokens_used, wall_used_ms, tool_calls_used,
        // subprocess_used_ms, memory_bytes_used); a silent rename
        // would round-trip but break ledger_at_ordinal replay tools,
        // .epbundle consumers, and the Provenance Console UI.
        let ledger = BudgetLedger {
            tokens_used: 100,
            wall_used_ms: 200,
            tool_calls_used: 3,
            subprocess_used_ms: 400,
            memory_bytes_used: 500,
        };
        let json = serde_json::to_value(&ledger).expect("serialise");
        let obj = json.as_object().expect("BudgetLedger serialises as JSON object");
        for key in [
            "tokens_used",
            "wall_used_ms",
            "tool_calls_used",
            "subprocess_used_ms",
            "memory_bytes_used",
        ] {
            assert!(
                obj.contains_key(key),
                "missing top-level key {key:?} in {json:?}"
            );
        }
        assert_eq!(
            obj.len(),
            5,
            "expected exactly 5 top-level keys, got {} ({:?})",
            obj.len(),
            obj.keys().collect::<Vec<_>>()
        );
    }

    #[test]
    fn budget_ledger_and_debit_serde_tolerate_unknown_extra_fields_per_current_doctrine() {
        // Phase 1 hardening — DOCTRINE PIN with forward-compat teeth.
        // Companion to budget_spec_serde_tolerates_unknown_extra_fields...
        // (iter-357) and the broader serde-tolerance pin family.
        //
        // BudgetLedger AND BudgetDebit are embedded in RunEventEntry
        // and surface through SealedMutation rows + LedgerSnapshot rows
        // in every persisted RunEventLog. Neither carries
        // #[serde(deny_unknown_fields)].
        //
        // A future axis added to either (e.g., network_bytes_used /
        // network_bytes) added in vN+1 and reverted before vN+2 must
        // still let vN+2 readers parse the captured rows — extras
        // silently drop.
        //
        // Pin BOTH structs together — they share the same 5-axis layout
        // and the same forward-compat contract.
        let ledger = BudgetLedger {
            tokens_used: 100,
            wall_used_ms: 200,
            tool_calls_used: 3,
            subprocess_used_ms: 400,
            memory_bytes_used: 500,
        };
        let s = serde_json::to_string(&ledger).expect("serialise ledger");
        let last_brace = s.rfind('}').expect("trailing brace");
        let mut augmented = String::with_capacity(s.len() + 40);
        augmented.push_str(&s[..last_brace]);
        augmented.push_str(r#","network_bytes_used":42}"#);
        let parsed: BudgetLedger =
            serde_json::from_str(&augmented).expect("ledger unknown field tolerated");
        assert_eq!(parsed, ledger);

        let debit = BudgetDebit {
            tokens: 25,
            wall_ms: 30,
            tool_calls: 1,
            subprocess_ms: 100,
            memory_bytes: 4_096,
        };
        let s = serde_json::to_string(&debit).expect("serialise debit");
        let last_brace = s.rfind('}').expect("trailing brace");
        let mut augmented = String::with_capacity(s.len() + 40);
        augmented.push_str(&s[..last_brace]);
        augmented.push_str(r#","network_bytes":7}"#);
        let parsed: BudgetDebit =
            serde_json::from_str(&augmented).expect("debit unknown field tolerated");
        assert_eq!(parsed, debit);
    }

    #[test]
    fn budget_ledger_deserialises_legacy_json_without_memory_bytes() {
        // Phase 1 hardening — backward-compat: a RunEventLog written
        // by an earlier version of this module won't have the
        // memory_bytes_used field. Deserialisation must accept the
        // legacy shape (defaulting memory_bytes_used to 0) so replay
        // of old logs continues to work.
        let legacy = r#"{
            "tokens_used": 25,
            "wall_used_ms": 100,
            "tool_calls_used": 2,
            "subprocess_used_ms": 0
        }"#;
        let l: BudgetLedger = serde_json::from_str(legacy)
            .expect("legacy JSON without memory_bytes_used must deserialise");
        assert_eq!(l.tokens_used, 25);
        assert_eq!(l.memory_bytes_used, 0);
    }

    #[test]
    fn budget_spec_deserialises_legacy_json_without_memory_bytes() {
        let legacy = r#"{
            "max_tokens": 1000,
            "max_wall_ms": 60000,
            "max_tool_calls": 5,
            "max_subprocess_ms": 0
        }"#;
        let s: BudgetSpec = serde_json::from_str(legacy).expect("legacy spec deserialises");
        assert_eq!(s.max_tokens, 1000);
        assert_eq!(s.max_memory_bytes, 0);
    }

    #[test]
    fn budget_debit_serde_json_preserves_struct_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin extending iter-159
        // (presence + count) with field-order. BudgetDebit declares
        // its 5 fields as: tokens, wall_ms, tool_calls, subprocess_ms,
        // memory_bytes. A future reorder breaks audit-dashboard
        // byte-equal diff tools.
        let debit = BudgetDebit {
            tokens: 100,
            wall_ms: 200,
            tool_calls: 3,
            subprocess_ms: 400,
            memory_bytes: 500,
        };
        let s = serde_json::to_string(&debit).expect("serialise");
        let expected_keys_in_order = [
            "\"tokens\":",
            "\"wall_ms\":",
            "\"tool_calls\":",
            "\"subprocess_ms\":",
            "\"memory_bytes\":",
        ];
        let mut last_idx: Option<usize> = None;
        for key in expected_keys_in_order {
            let pos = s.find(key).unwrap_or_else(|| panic!("key {key} not found in {s}"));
            if let Some(prev) = last_idx {
                assert!(
                    pos > prev,
                    "field {key} at byte {pos} must appear after previous field at {prev}"
                );
            }
            last_idx = Some(pos);
        }
    }

    #[test]
    fn budget_debit_serde_json_contains_all_five_canonical_top_level_keys() {
        // Phase 1 hardening — wire-shape pin matching the
        // established pattern. BudgetDebit has 5 top-level fields
        // (tokens, wall_ms, tool_calls, subprocess_ms, memory_bytes);
        // a silent rename would round-trip but break audit-dashboard
        // attribution + Swift bridge BudgetDebit mirrors.
        let debit = BudgetDebit {
            tokens: 100,
            wall_ms: 200,
            tool_calls: 3,
            subprocess_ms: 400,
            memory_bytes: 500,
        };
        let json = serde_json::to_value(&debit).expect("serialise");
        let obj = json.as_object().expect("BudgetDebit serialises as JSON object");
        for key in [
            "tokens",
            "wall_ms",
            "tool_calls",
            "subprocess_ms",
            "memory_bytes",
        ] {
            assert!(
                obj.contains_key(key),
                "missing top-level key {key:?} in {json:?}"
            );
        }
        assert_eq!(
            obj.len(),
            5,
            "expected exactly 5 top-level keys, got {} ({:?})",
            obj.len(),
            obj.keys().collect::<Vec<_>>()
        );
    }

    #[test]
    fn budget_debit_deserialises_legacy_json_without_memory_bytes() {
        let legacy = r#"{
            "tokens": 10,
            "wall_ms": 50,
            "tool_calls": 1,
            "subprocess_ms": 0
        }"#;
        let d: BudgetDebit = serde_json::from_str(legacy).expect("legacy debit deserialises");
        assert_eq!(d.tokens, 10);
        assert_eq!(d.memory_bytes, 0);
    }

    #[test]
    fn budget_overflow_at_u64_max_boundary_does_not_panic() {
        // Phase 1 hardening — user's explicit list: "budget-overflow
        // at boundary". A ledger near u64::MAX combined with a large
        // debit must NOT panic on arithmetic overflow; saturating_add
        // must produce u64::MAX and the gate must surface Exhausted.
        let gate = BudgetGate::new(BudgetSpec::new(1_000_000, 0, 0, 0));
        let near_max = BudgetLedger {
            tokens_used: u64::MAX - 5,
            ..Default::default()
        };
        // attempted_total saturates at u64::MAX (which is > 1_000_000),
        // so we get Exhausted with the saturated total.
        let err = gate
            .check_and_debit(near_max, BudgetDebit { tokens: 100, ..Default::default() })
            .expect_err("near-MAX ledger debit must surface Exhausted, not panic");
        match err {
            BudgetError::Exhausted { term: BudgetTerm::Tokens, attempted_total, cap } => {
                assert_eq!(attempted_total, u64::MAX);
                assert_eq!(cap, 1_000_000);
            }
            other => panic!("expected Exhausted(Tokens), got {other:?}"),
        }
    }

    #[test]
    fn budget_overflow_at_u64_max_boundary_does_not_panic_for_all_five_axes() {
        // Phase 1 hardening — 5-axis completeness companion to
        // `budget_overflow_at_u64_max_boundary_does_not_panic` (tokens
        // only). Each of the 5 axes carries its own
        // saturating_add(debit) path; pin that wall_ms, tool_calls,
        // subprocess_ms, and memory_bytes also saturate at u64::MAX
        // and surface BudgetError::Exhausted with the correct
        // BudgetTerm attribution.
        //
        // Defends against a future "let me micro-optimise the gate
        // with a plain `+`" refactor that would panic on one of the
        // less-exercised axes (wall_ms / memory_bytes) under near-MAX
        // ledger state.
        //
        // Tokens already pinned by the original test — start at wall_ms.
        let gate_w = BudgetGate::new(BudgetSpec::new(0, 1_000, 0, 0));
        let near_w = BudgetLedger { wall_used_ms: u64::MAX - 5, ..Default::default() };
        let err_w = gate_w
            .check_and_debit(near_w, BudgetDebit { wall_ms: 100, ..Default::default() })
            .expect_err("wall_ms near-MAX must surface Exhausted");
        match err_w {
            BudgetError::Exhausted { term: BudgetTerm::WallMs, attempted_total, cap } => {
                assert_eq!(attempted_total, u64::MAX);
                assert_eq!(cap, 1_000);
            }
            other => panic!("expected Exhausted(WallMs), got {other:?}"),
        }

        let gate_tc = BudgetGate::new(BudgetSpec::new(0, 0, 5, 0));
        let near_tc = BudgetLedger { tool_calls_used: u64::MAX - 5, ..Default::default() };
        let err_tc = gate_tc
            .check_and_debit(near_tc, BudgetDebit { tool_calls: 100, ..Default::default() })
            .expect_err("tool_calls near-MAX must surface Exhausted");
        match err_tc {
            BudgetError::Exhausted { term: BudgetTerm::ToolCalls, attempted_total, cap } => {
                assert_eq!(attempted_total, u64::MAX);
                assert_eq!(cap, 5);
            }
            other => panic!("expected Exhausted(ToolCalls), got {other:?}"),
        }

        let gate_sm = BudgetGate::new(BudgetSpec::new(0, 0, 0, 1_000));
        let near_sm = BudgetLedger { subprocess_used_ms: u64::MAX - 5, ..Default::default() };
        let err_sm = gate_sm
            .check_and_debit(near_sm, BudgetDebit { subprocess_ms: 100, ..Default::default() })
            .expect_err("subprocess_ms near-MAX must surface Exhausted");
        match err_sm {
            BudgetError::Exhausted { term: BudgetTerm::SubprocessMs, attempted_total, cap } => {
                assert_eq!(attempted_total, u64::MAX);
                assert_eq!(cap, 1_000);
            }
            other => panic!("expected Exhausted(SubprocessMs), got {other:?}"),
        }

        let gate_mb = BudgetGate::new(BudgetSpec::default().with_memory_bytes(1_048_576));
        let near_mb = BudgetLedger { memory_bytes_used: u64::MAX - 5, ..Default::default() };
        let err_mb = gate_mb
            .check_and_debit(near_mb, BudgetDebit { memory_bytes: 100, ..Default::default() })
            .expect_err("memory_bytes near-MAX must surface Exhausted");
        match err_mb {
            BudgetError::Exhausted { term: BudgetTerm::MemoryBytes, attempted_total, cap } => {
                assert_eq!(attempted_total, u64::MAX);
                assert_eq!(cap, 1_048_576);
            }
            other => panic!("expected Exhausted(MemoryBytes), got {other:?}"),
        }
    }

    #[test]
    fn budget_overflow_at_unbounded_cap_still_saturates() {
        // Even with no cap, the ledger should not wrap.
        let gate = BudgetGate::new(BudgetSpec::default());
        let near_max = BudgetLedger {
            tokens_used: u64::MAX - 5,
            ..Default::default()
        };
        let advanced = gate
            .check_and_debit(near_max, BudgetDebit { tokens: u64::MAX, ..Default::default() })
            .expect("unbounded gate accepts even near-MAX debits without panic");
        assert_eq!(advanced.tokens_used, u64::MAX);
    }

    #[test]
    fn budget_ledger_default_is_all_zero_across_every_axis() {
        // Phase 1 hardening — companion to budget_debit_default. Pin
        // that BudgetLedger::default() has every field == 0 — a
        // "fresh ledger" state. A future #[serde(default)] that
        // installed a non-zero sentinel on any field would silently
        // skew every budget reading; surface here.
        let l = BudgetLedger::default();
        assert_eq!(l.tokens_used, 0);
        assert_eq!(l.wall_used_ms, 0);
        assert_eq!(l.tool_calls_used, 0);
        assert_eq!(l.subprocess_used_ms, 0);
        assert_eq!(l.memory_bytes_used, 0);
    }

    #[test]
    fn budget_debit_default_is_all_zero_across_every_axis() {
        // Phase 1 hardening — BudgetDebit::default() is the
        // arithmetic-zero element. Pin that ALL 5 axes are 0,
        // not just tokens. A future #[serde(default)] attribute
        // that defaulted one axis to a non-zero sentinel would
        // silently leak budget on every "no-op probe" call —
        // surface that here.
        let d = BudgetDebit::default();
        assert_eq!(d.tokens, 0);
        assert_eq!(d.wall_ms, 0);
        assert_eq!(d.tool_calls, 0);
        assert_eq!(d.subprocess_ms, 0);
        assert_eq!(d.memory_bytes, 0);
    }

    #[test]
    fn zero_debit_is_identity_through_check_and_debit() {
        // Phase 1 hardening — gate-purity boundary. A BudgetDebit::default()
        // (all-zero) is the additive identity: it must succeed under
        // ANY non-exhausted ledger AND leave every ledger field exactly
        // equal. Callers use this as a no-op gate probe (e.g. "the
        // budget is still alive" health check between iterations).
        let gate = BudgetGate::new(BudgetSpec::new(100, 200, 5, 300));
        let ledger = BudgetLedger {
            tokens_used: 50,
            wall_used_ms: 100,
            tool_calls_used: 3,
            subprocess_used_ms: 150,
            memory_bytes_used: 0,
        };
        let after = gate
            .check_and_debit(ledger.clone(), BudgetDebit::default())
            .expect("zero debit always succeeds on a fresh ledger");
        // Every field byte-equal — the zero debit is the identity.
        assert_eq!(after.tokens_used, ledger.tokens_used);
        assert_eq!(after.wall_used_ms, ledger.wall_used_ms);
        assert_eq!(after.tool_calls_used, ledger.tool_calls_used);
        assert_eq!(after.subprocess_used_ms, ledger.subprocess_used_ms);
        assert_eq!(after.memory_bytes_used, ledger.memory_bytes_used);
        // And it works on a default ledger too.
        let fresh_after = gate
            .check_and_debit(BudgetLedger::default(), BudgetDebit::default())
            .expect("zero debit on default ledger succeeds");
        assert_eq!(fresh_after, BudgetLedger::default());
    }

    #[test]
    fn tightening_spec_after_debits_does_not_retro_invalidate() {
        // Phase 1 hardening — spec mutation semantics. A ledger that
        // was within an OLD (loose) cap remains "valid past" — the
        // gate cannot retroactively reject debits already applied.
        // But a NEW (tighter) gate, evaluating a fresh debit AGAINST
        // the existing ledger, may correctly trip Exhausted if the
        // running total exceeds the new cap.
        let loose = BudgetGate::new(BudgetSpec::new(10_000, 0, 0, 0));
        let mut ledger = BudgetLedger::default();
        // Apply two 3_000-token debits under the loose cap (6_000
        // total).
        ledger = loose
            .check_and_debit(ledger, BudgetDebit { tokens: 3_000, ..Default::default() })
            .expect("first debit");
        ledger = loose
            .check_and_debit(ledger, BudgetDebit { tokens: 3_000, ..Default::default() })
            .expect("second debit");
        assert_eq!(ledger.tokens_used, 6_000);

        // Tighten the cap to 5_000. The existing ledger (6_000) is
        // ALREADY past the new cap — but the prior debits stay
        // recorded; only a NEW debit will trip the new gate.
        let tight = BudgetGate::new(BudgetSpec::new(5_000, 0, 0, 0));
        // A zero-byte debit must still trip because tokens_used >
        // max_tokens (the totals were applied historically against
        // a looser cap, and the new gate refuses to admit any further
        // debit). saturating_add(0) == 6_000 > 5_000.
        let err = tight
            .check_and_debit(ledger, BudgetDebit::default())
            .expect_err("post-tightening fresh debit must trip");
        assert!(matches!(
            err,
            BudgetError::Exhausted { term: BudgetTerm::Tokens, attempted_total: 6_000, cap: 5_000 }
        ));
        // The historical ledger itself was NOT mutated by the
        // tightening — the prior debits persist. Replay-safe.
        assert_eq!(ledger.tokens_used, 6_000);
    }

    #[test]
    fn loosening_spec_admits_previously_rejected_debits() {
        // Symmetric: loosening a cap lets a previously over-cap debit
        // succeed. The gate is pure; specs are interchangeable.
        let tight = BudgetGate::new(BudgetSpec::new(1_000, 0, 0, 0));
        let ledger = BudgetLedger::default();
        let big_debit = BudgetDebit { tokens: 2_000, ..Default::default() };
        let _ = tight
            .check_and_debit(ledger, big_debit)
            .expect_err("tight gate rejects");
        let loose = BudgetGate::new(BudgetSpec::new(10_000, 0, 0, 0));
        let advanced = loose
            .check_and_debit(ledger, big_debit)
            .expect("loose gate accepts");
        assert_eq!(advanced.tokens_used, 2_000);
    }

    #[test]
    fn memory_bytes_cap_enforced_independently() {
        // Phase 1 hardening — user's explicit list: "memory-byte axes".
        let gate = BudgetGate::new(BudgetSpec::default().with_memory_bytes(1_024 * 1_024));
        let near_cap = BudgetLedger {
            memory_bytes_used: 1_024 * 1_024 - 100,
            ..Default::default()
        };
        let err = gate
            .check_and_debit(
                near_cap,
                BudgetDebit { memory_bytes: 200, ..Default::default() },
            )
            .expect_err("memory cap exceeded");
        assert!(matches!(
            err,
            BudgetError::Exhausted { term: BudgetTerm::MemoryBytes, .. }
        ));
    }

    #[test]
    fn memory_bytes_under_cap_advances_ledger() {
        let gate = BudgetGate::new(BudgetSpec::default().with_memory_bytes(10 * 1_024));
        let advanced = gate
            .check_and_debit(
                BudgetLedger::default(),
                BudgetDebit { memory_bytes: 4_096, ..Default::default() },
            )
            .expect("under-cap memory debit");
        assert_eq!(advanced.memory_bytes_used, 4_096);
    }

    #[test]
    fn memory_bytes_refund_restores_cap() {
        let gate = BudgetGate::new(BudgetSpec::default().with_memory_bytes(1_024));
        let ledger = BudgetLedger::default();
        let debit = BudgetDebit { memory_bytes: 900, ..Default::default() };
        let after = gate.check_and_debit(ledger, debit).expect("fits");
        assert_eq!(after.memory_bytes_used, 900);
        let refunded = after.refund(debit);
        assert_eq!(refunded.memory_bytes_used, 0);
    }

    #[test]
    fn with_memory_bytes_zero_resets_to_unbounded_per_doctrine() {
        // Phase 1 hardening — builder symmetry pin. The doctrine
        // (BudgetSpec::new docstring) says "Caps of 0 mean unbounded
        // for that term." with_memory_bytes(N) sets the cap to N;
        // a subsequent with_memory_bytes(0) call should reset the
        // cap back to unbounded. This is the canonical "drop the
        // memory cap" pattern.
        //
        // No test pins this. A future "let me make with_memory_bytes
        // saturate at the previous value if N < current" tightening
        // would silently break the reset-to-unbounded pattern.
        let bounded = BudgetSpec::default()
            .with_memory_bytes(1_048_576);
        assert_eq!(bounded.max_memory_bytes, 1_048_576);

        // Chain a second with_memory_bytes(0) → resets to 0 (unbounded).
        let reset = bounded.with_memory_bytes(0);
        assert_eq!(reset.max_memory_bytes, 0);
        // After reset, the gate accepts any memory_bytes debit.
        let gate = BudgetGate::new(reset);
        let huge_debit = BudgetDebit {
            memory_bytes: u64::MAX / 2,
            ..Default::default()
        };
        gate.check_and_debit(BudgetLedger::default(), huge_debit)
            .expect("unbounded memory cap (after reset) must accept any debit");
    }

    #[test]
    fn budget_debit_and_ledger_struct_literal_with_u64_max_does_not_panic() {
        // Phase 1 hardening — max-value-boundary pin for BudgetDebit
        // and BudgetLedger struct literals (companion to
        // budget_spec_new_accepts_u64_max_per_axis iter-484).
        //
        // Struct literal construction is field assignment; should
        // round-trip u64::MAX values without panic. The gate path
        // uses saturating_add for safety, but the struct construction
        // itself must accept any u64.
        let debit = BudgetDebit {
            tokens: u64::MAX,
            wall_ms: u64::MAX,
            tool_calls: u64::MAX,
            subprocess_ms: u64::MAX,
            memory_bytes: u64::MAX,
        };
        assert_eq!(debit.tokens, u64::MAX);
        assert_eq!(debit.wall_ms, u64::MAX);
        assert_eq!(debit.tool_calls, u64::MAX);
        assert_eq!(debit.subprocess_ms, u64::MAX);
        assert_eq!(debit.memory_bytes, u64::MAX);

        let ledger = BudgetLedger {
            tokens_used: u64::MAX,
            wall_used_ms: u64::MAX,
            tool_calls_used: u64::MAX,
            subprocess_used_ms: u64::MAX,
            memory_bytes_used: u64::MAX,
        };
        assert_eq!(ledger.tokens_used, u64::MAX);
        assert_eq!(ledger.wall_used_ms, u64::MAX);
        assert_eq!(ledger.tool_calls_used, u64::MAX);
        assert_eq!(ledger.subprocess_used_ms, u64::MAX);
        assert_eq!(ledger.memory_bytes_used, u64::MAX);
    }

    #[test]
    fn budget_spec_new_accepts_u64_max_per_axis() {
        // Phase 1 hardening — max-value-boundary pin for BudgetSpec::new.
        // Companion to budget_spec_new_4_arg_constructor_defaults_max_memory_bytes_to_zero
        // (which pins the min default) and budget_overflow_at_u64_max_boundary_does_not_panic
        // (which exercises the GATE under u64::MAX debits).
        //
        // The constructor itself must accept u64::MAX for ANY axis
        // without panic — the gate's check_and_debit relies on
        // saturating_add for the overflow safety, but the constructor
        // path is a plain field assignment. Pin that nothing panics
        // and the fields round-trip the MAX value.
        //
        // Defends against a future "let me add overflow checks at
        // construction" tightening that would silently reject the
        // unbounded-cap-via-MAX-value pattern callers might use.
        let s = BudgetSpec::new(u64::MAX, u64::MAX, u64::MAX, u64::MAX)
            .with_memory_bytes(u64::MAX);
        assert_eq!(s.max_tokens, u64::MAX);
        assert_eq!(s.max_wall_ms, u64::MAX);
        assert_eq!(s.max_tool_calls, u64::MAX);
        assert_eq!(s.max_subprocess_ms, u64::MAX);
        assert_eq!(s.max_memory_bytes, u64::MAX);
        // Gate constructed from u64::MAX spec also doesn't panic.
        let _gate = BudgetGate::new(s);
    }

    #[test]
    fn budget_spec_new_4_arg_constructor_positional_order_is_pinned() {
        // Phase 1 hardening — positional-order pin for BudgetSpec::new.
        // The signature is:
        //   new(max_tokens, max_wall_ms, max_tool_calls, max_subprocess_ms)
        // and the body assigns each arg to the matching field
        // (budget.rs §62-67).
        //
        // A future "let me reorder for ergonomic intuition" refactor
        // (e.g., putting tool_calls first because it's the most
        // user-visible) would silently shuffle every call site's
        // behaviour without changing the type signature — every call
        // site uses literal numeric arguments that don't carry
        // field-name information.
        //
        // Pin via 4 DISTINCT values that map identifiably to each
        // field by being far apart in magnitude — a swap is
        // immediately catchable.
        let spec = BudgetSpec::new(
            /*max_tokens=*/        1_000,
            /*max_wall_ms=*/       60_000_000, // 60M ms = ~16hr; large
            /*max_tool_calls=*/    5,           // small
            /*max_subprocess_ms=*/ 12_345,      // mid
        );
        assert_eq!(spec.max_tokens, 1_000);
        assert_eq!(spec.max_wall_ms, 60_000_000);
        assert_eq!(spec.max_tool_calls, 5);
        assert_eq!(spec.max_subprocess_ms, 12_345);
        // Memory axis defaults to 0 (separately pinned in
        // budget_spec_new_4_arg_constructor_defaults_max_memory_bytes_to_zero).
        assert_eq!(spec.max_memory_bytes, 0);
    }

    #[test]
    fn budget_spec_new_4_arg_constructor_defaults_max_memory_bytes_to_zero() {
        // Phase 1 hardening — constructor default pin. BudgetSpec::new
        // takes 4 positional args (tokens / wall_ms / tool_calls /
        // subprocess_ms) and sets max_memory_bytes = 0 implicitly
        // (budget.rs §65). The 0 means "unbounded for memory" per the
        // BudgetSpec doctrine.
        //
        // A future "let me add max_memory_bytes as a 5th positional
        // arg" refactor or "let me default memory to a non-zero
        // safe-default" refactor would silently change the
        // BudgetSpec::new ergonomics for every call site.
        //
        // Pin via a sweep of non-trivial 4-arg constructions; every
        // one must leave max_memory_bytes == 0.
        let cases = [
            BudgetSpec::new(0, 0, 0, 0),
            BudgetSpec::new(1, 1, 1, 1),
            BudgetSpec::new(1_000_000, 60_000, 5, 30_000),
            BudgetSpec::new(u64::MAX, u64::MAX, u64::MAX, u64::MAX),
        ];
        for spec in cases {
            assert_eq!(
                spec.max_memory_bytes, 0,
                "4-arg new() must leave max_memory_bytes == 0 unbounded"
            );
        }
    }

    #[test]
    fn with_memory_bytes_chained_twice_with_nonzero_replaces_not_accumulates() {
        // Phase 1 hardening — builder semantic pin. Companion to
        // with_memory_bytes_zero_resets_to_unbounded_per_doctrine
        // (which covers `N → 0` reset). This pins the canonical
        // `N → M` (both non-zero) replacement semantic: the SECOND
        // call REPLACES the first value, it does NOT accumulate or
        // saturate.
        //
        // A future "let me min/max-clamp on the builder" optimisation
        // would silently change the doctrine — surface here.
        let base = BudgetSpec::default()
            .with_memory_bytes(1_024)
            .with_memory_bytes(4_096);
        assert_eq!(
            base.max_memory_bytes, 4_096,
            "second call must REPLACE the first (not accumulate to 5120 or clamp to 1024)"
        );

        // Decreasing chain: 4_096 → 1_024 must also replace.
        let decreasing = BudgetSpec::default()
            .with_memory_bytes(4_096)
            .with_memory_bytes(1_024);
        assert_eq!(
            decreasing.max_memory_bytes, 1_024,
            "decreasing chain must REPLACE to lower (not saturate at higher)"
        );
    }

    #[test]
    fn with_memory_bytes_builder_preserves_other_caps() {
        let s = BudgetSpec::new(1_000, 60_000, 5, 30_000).with_memory_bytes(1_048_576);
        assert_eq!(s.max_tokens, 1_000);
        assert_eq!(s.max_wall_ms, 60_000);
        assert_eq!(s.max_tool_calls, 5);
        assert_eq!(s.max_subprocess_ms, 30_000);
        assert_eq!(s.max_memory_bytes, 1_048_576);
    }

    #[test]
    fn refund_then_check_and_debit_is_right_inverse_when_non_saturating() {
        // Phase 1 hardening — algebraic-property pin completing the
        // (debit, refund) inverse trio:
        //   iter-528  L.debit(d).refund(d) == L           (left inverse)
        //   iter-530+531 commutativity
        //   THIS      L.refund(d).debit(d) == L           (right inverse)
        //
        // When d ≤ L on every axis (refund doesn't saturate) AND L
        // was reachable through the gate (so L + d still fits cap),
        // the cycle is byte-equal: refunding d then re-applying it
        // gives L back. The 3 properties together establish the
        // canonical (debit, refund) algebra as a group on the
        // 5-axis ledger up to saturation. A future "let me track
        // refund-then-debit retries with a side counter" would
        // silently break the right inverse.
        let gate = BudgetGate::new(
            BudgetSpec::new(10_000, 60_000, 100, 30_000).with_memory_bytes(1_000_000),
        );
        let initial = BudgetLedger {
            tokens_used: 1_000,
            wall_used_ms: 5_000,
            tool_calls_used: 10,
            subprocess_used_ms: 1_000,
            memory_bytes_used: 100_000,
        };
        // 4 fixtures where d ≤ initial on every axis.
        let debits = [
            BudgetDebit { tokens: 100, ..Default::default() },
            BudgetDebit { tool_calls: 1, ..Default::default() },
            BudgetDebit {
                tokens: 50,
                wall_ms: 100,
                tool_calls: 1,
                subprocess_ms: 100,
                memory_bytes: 100,
            },
            // d == initial — refund saturates to zero, then debit
            // re-fills to original. Boundary case.
            BudgetDebit {
                tokens: 1_000,
                wall_ms: 5_000,
                tool_calls: 10,
                subprocess_ms: 1_000,
                memory_bytes: 100_000,
            },
        ];
        for (idx, d) in debits.iter().enumerate() {
            let after_refund = initial.refund(*d);
            let after_debit = gate
                .check_and_debit(after_refund, *d)
                .expect("re-debit must fit cap");
            assert_eq!(
                after_debit, initial,
                "fixture {idx}: refund→debit must round-trip to initial"
            );
        }
    }

    #[test]
    fn refund_sequencing_is_commutative_when_both_refunds_fit_within_ledger() {
        // Phase 1 hardening — algebraic-property pin (companion to
        // check_and_debit_sequencing_is_commutative iter-530 + refund-
        // left-inverse iter-528). For any ledger L and debits d1, d2
        // where both refunds stay within L's used balance:
        //
        //   L.refund(d1).refund(d2) == L.refund(d2).refund(d1)
        //
        // Refund is implemented via saturating_sub, which is commutative
        // when neither operation saturates (i.e., the ledger has enough
        // headroom on every debited axis). A future tweak that added
        // path-dependent state to refund (e.g., "remember the order of
        // refunds for telemetry") would silently introduce order-
        // dependence and break the audit invariant that "a sequence of
        // refunds produces the same final ledger regardless of order".
        let initial = BudgetLedger {
            tokens_used: 1_000,
            wall_used_ms: 5_000,
            tool_calls_used: 10,
            subprocess_used_ms: 2_000,
            memory_bytes_used: 500_000,
        };
        // Both refunds stay well within the ledger's used balance.
        let pairs: &[(BudgetDebit, BudgetDebit)] = &[
            (
                BudgetDebit { tokens: 100, ..Default::default() },
                BudgetDebit { wall_ms: 500, ..Default::default() },
            ),
            (
                BudgetDebit { tokens: 200, ..Default::default() },
                BudgetDebit { tokens: 300, ..Default::default() },
            ),
            (
                BudgetDebit {
                    tokens: 100,
                    wall_ms: 200,
                    tool_calls: 1,
                    subprocess_ms: 100,
                    memory_bytes: 1_000,
                },
                BudgetDebit {
                    tokens: 50,
                    wall_ms: 100,
                    tool_calls: 2,
                    subprocess_ms: 200,
                    memory_bytes: 500,
                },
            ),
        ];
        for (idx, (d1, d2)) in pairs.iter().enumerate() {
            let l_d1_first = initial.refund(*d1).refund(*d2);
            let l_d2_first = initial.refund(*d2).refund(*d1);
            assert_eq!(
                l_d1_first, l_d2_first,
                "fixture {idx}: refund(d1).refund(d2) must commute with refund(d2).refund(d1)"
            );
        }
    }

    #[test]
    fn check_and_debit_sequencing_is_commutative_when_both_orders_fit_cap() {
        // Phase 1 hardening MILESTONE iter-530 — algebraic-property pin
        // companion to check_and_debit_sequencing_is_associative
        // (iter-529) and refund_is_left_inverse (iter-528). Together
        // these three pins establish the (5-axis ledger, debit)
        // structure as a deterministic commutative monoid modulo
        // saturation.
        //
        // For any ledger L and debits d1, d2 where BOTH orders fit
        // the gate's spec:
        //
        //   gate.check_and_debit(gate.check_and_debit(L, d1)?, d2)?
        //   == gate.check_and_debit(gate.check_and_debit(L, d2)?, d1)?
        //
        // A future "let me track per-axis ordering to dampen
        // burst-spend on hot axes" tweak would silently introduce
        // order-dependence and break replay parity for any batch
        // where the dispatcher reordered calls.
        let gate = BudgetGate::new(
            BudgetSpec::new(10_000, 60_000, 20, 30_000).with_memory_bytes(1_000_000),
        );
        let initial = BudgetLedger::default();
        let pairs: &[(BudgetDebit, BudgetDebit)] = &[
            // Disjoint axes — the easy case.
            (
                BudgetDebit { tokens: 100, ..Default::default() },
                BudgetDebit { wall_ms: 200, ..Default::default() },
            ),
            // Overlapping single-axis.
            (
                BudgetDebit { tokens: 100, ..Default::default() },
                BudgetDebit { tokens: 200, ..Default::default() },
            ),
            // Multi-axis — every axis non-zero in both debits.
            (
                BudgetDebit {
                    tokens: 50,
                    wall_ms: 100,
                    tool_calls: 1,
                    subprocess_ms: 50,
                    memory_bytes: 100,
                },
                BudgetDebit {
                    tokens: 75,
                    wall_ms: 50,
                    tool_calls: 2,
                    subprocess_ms: 75,
                    memory_bytes: 50,
                },
            ),
            // Asymmetric: one debit zero on some axes, the other zero on different axes.
            (
                BudgetDebit { tokens: 100, tool_calls: 1, ..Default::default() },
                BudgetDebit { wall_ms: 200, subprocess_ms: 100, ..Default::default() },
            ),
        ];
        for (idx, (d1, d2)) in pairs.iter().enumerate() {
            let l_d1_first = gate
                .check_and_debit(gate.check_and_debit(initial, *d1).unwrap(), *d2)
                .expect("d1 then d2 must fit");
            let l_d2_first = gate
                .check_and_debit(gate.check_and_debit(initial, *d2).unwrap(), *d1)
                .expect("d2 then d1 must fit");
            assert_eq!(
                l_d1_first, l_d2_first,
                "fixture {idx}: d1→d2 must commute with d2→d1 on ledger"
            );
        }
    }

    #[test]
    fn check_and_debit_sequencing_is_associative_when_combined_debit_fits_cap() {
        // Phase 1 hardening — algebraic-property pin (companion to
        // refund_is_left_inverse_of_check_and_debit). For any ledger L
        // and debits d1, d2 where (d1 + d2) also fits the gate's spec:
        //
        //   gate.check_and_debit(gate.check_and_debit(L, d1)?, d2)?
        //   == gate.check_and_debit(L, d1+d2)?                  (byte-equal)
        //
        // The two-step sequencing must produce the same ledger as the
        // single combined debit. This is the canonical property the
        // dispatcher relies on when batching multiple tool calls under
        // the same gate (apply one big aggregate debit OR apply each
        // tool's individual debit; ledger must agree). A future
        // "let me charge a sequencing-overhead per call" tweak would
        // silently introduce a divergence between the two paths and
        // break replay parity for batched runs.
        let gate = BudgetGate::new(
            BudgetSpec::new(10_000, 60_000, 20, 30_000).with_memory_bytes(1_000_000),
        );
        let initial = BudgetLedger::default();
        // 5 (d1, d2) fixture pairs covering single-axis + multi-axis.
        let pairs: &[(BudgetDebit, BudgetDebit)] = &[
            // Single-axis tokens.
            (
                BudgetDebit { tokens: 100, ..Default::default() },
                BudgetDebit { tokens: 200, ..Default::default() },
            ),
            // Single-axis tool_calls.
            (
                BudgetDebit { tool_calls: 1, ..Default::default() },
                BudgetDebit { tool_calls: 2, ..Default::default() },
            ),
            // Disjoint axes.
            (
                BudgetDebit { tokens: 50, ..Default::default() },
                BudgetDebit { wall_ms: 100, ..Default::default() },
            ),
            // Multi-axis: each debit non-zero on every axis.
            (
                BudgetDebit {
                    tokens: 100,
                    wall_ms: 50,
                    tool_calls: 1,
                    subprocess_ms: 100,
                    memory_bytes: 100,
                },
                BudgetDebit {
                    tokens: 50,
                    wall_ms: 75,
                    tool_calls: 2,
                    subprocess_ms: 150,
                    memory_bytes: 150,
                },
            ),
            // d1 = zero (identity), d2 = non-zero — proves zero-identity
            // is consistent with sequencing.
            (
                BudgetDebit::default(),
                BudgetDebit { tokens: 500, ..Default::default() },
            ),
        ];
        for (idx, (d1, d2)) in pairs.iter().enumerate() {
            let combined = BudgetDebit {
                tokens: d1.tokens + d2.tokens,
                wall_ms: d1.wall_ms + d2.wall_ms,
                tool_calls: d1.tool_calls + d2.tool_calls,
                subprocess_ms: d1.subprocess_ms + d2.subprocess_ms,
                memory_bytes: d1.memory_bytes + d2.memory_bytes,
            };
            // Two-step path.
            let after_d1 = gate.check_and_debit(initial, *d1).expect("d1 fits");
            let after_d1_d2 = gate.check_and_debit(after_d1, *d2).expect("d2 fits");
            // Single-step path.
            let after_combined = gate
                .check_and_debit(initial, combined)
                .expect("d1+d2 fits");
            assert_eq!(
                after_d1_d2, after_combined,
                "fixture {idx}: two-step debit must equal single-step combined"
            );
        }
    }

    #[test]
    fn refund_is_left_inverse_of_check_and_debit_across_5_axis_field_space() {
        // Phase 1 hardening — algebraic-property pin (companion to the
        // refund pin family at iter-326..iter-329). For any ledger L
        // and debit d that fits the gate's spec:
        //
        //   gate.check_and_debit(L, d).refund(d) == L     (byte-equal)
        //
        // Refund is a LEFT inverse of check_and_debit modulo saturation
        // — the test bounds d so saturation never kicks in. The
        // existing refund_restores_cap_after_cancel pin covers ONE
        // fixture; this pin sweeps the 5-axis combinatoric space:
        // single-axis debits + multi-axis debits + at-boundary debits.
        // A future "let me track implicit overhead on every refund"
        // refactor would silently break the inverse property and
        // surface here deterministically.
        let gate = BudgetGate::new(
            BudgetSpec::new(10_000, 60_000, 20, 30_000).with_memory_bytes(1_000_000),
        );
        let initial = BudgetLedger {
            tokens_used: 1_000,
            wall_used_ms: 5_000,
            tool_calls_used: 2,
            subprocess_used_ms: 1_000,
            memory_bytes_used: 100_000,
        };
        // 5 single-axis debits + 1 multi-axis debit + 1 saturation-safe debit.
        let debits = [
            BudgetDebit { tokens: 100, ..Default::default() },
            BudgetDebit { wall_ms: 200, ..Default::default() },
            BudgetDebit { tool_calls: 1, ..Default::default() },
            BudgetDebit { subprocess_ms: 300, ..Default::default() },
            BudgetDebit { memory_bytes: 500, ..Default::default() },
            // Multi-axis: every axis non-zero, all fit.
            BudgetDebit {
                tokens: 50,
                wall_ms: 50,
                tool_calls: 1,
                subprocess_ms: 50,
                memory_bytes: 50,
            },
            // At-boundary: spend exactly the headroom on every axis.
            BudgetDebit {
                tokens: 9_000,
                wall_ms: 55_000,
                tool_calls: 18,
                subprocess_ms: 29_000,
                memory_bytes: 900_000,
            },
        ];
        for (idx, d) in debits.iter().enumerate() {
            let after_apply = gate
                .check_and_debit(initial, *d)
                .expect("debit must fit gate spec");
            let after_refund = after_apply.refund(*d);
            assert_eq!(
                after_refund, initial,
                "fixture {idx}: refund must left-invert check_and_debit"
            );
            // Each field independently restored.
            assert_eq!(after_refund.tokens_used, initial.tokens_used);
            assert_eq!(after_refund.wall_used_ms, initial.wall_used_ms);
            assert_eq!(after_refund.tool_calls_used, initial.tool_calls_used);
            assert_eq!(
                after_refund.subprocess_used_ms,
                initial.subprocess_used_ms
            );
            assert_eq!(after_refund.memory_bytes_used, initial.memory_bytes_used);
        }
    }

    #[test]
    fn budget_debit_for_tool_call_and_for_thinking_turn_equal_struct_literal_byte_for_byte() {
        // Phase 1 hardening — thin-wrapper equivalence pin (companion
        // to the equivalence-pin family iter-518..iter-524). Both
        // const constructors MUST produce debits byte-equal to the
        // direct struct-literal form across representative token
        // shapes — they are the canonical entry points dispatchers
        // use to issue debits, so divergence in the helper would
        // silently produce two distinct debit byte forms per call
        // site. The pin sweeps:
        //   - (prompt, completion) = (0, 0) — minimal
        //   - (1, 0), (0, 1) — single-axis
        //   - mid + large
        //   - saturating-add boundary u64::MAX + 1 == u64::MAX
        // and pins the variant-specific tool_calls value (1 for
        // for_tool_call, 0 for for_thinking_turn).
        let fixtures: &[(u64, u64)] = &[
            (0, 0),
            (1, 0),
            (0, 1),
            (100, 50),
            (1_000_000, 500_000),
            (u64::MAX, 1), // saturates to u64::MAX
            (u64::MAX, u64::MAX),
        ];
        for &(prompt, completion) in fixtures {
            let total = prompt.saturating_add(completion);

            // for_tool_call → tool_calls = 1.
            let via_tool = BudgetDebit::for_tool_call(prompt, completion);
            let via_tool_struct = BudgetDebit {
                tokens: total,
                wall_ms: 0,
                tool_calls: 1,
                subprocess_ms: 0,
                memory_bytes: 0,
            };
            assert_eq!(
                via_tool, via_tool_struct,
                "for_tool_call({prompt}, {completion}) must equal struct-literal form"
            );
            let j_t = serde_json::to_string(&via_tool).expect("serialize tool");
            let j_ts = serde_json::to_string(&via_tool_struct).expect("serialize struct");
            assert_eq!(j_t, j_ts);

            // for_thinking_turn → tool_calls = 0.
            let via_think = BudgetDebit::for_thinking_turn(prompt, completion);
            let via_think_struct = BudgetDebit {
                tokens: total,
                wall_ms: 0,
                tool_calls: 0,
                subprocess_ms: 0,
                memory_bytes: 0,
            };
            assert_eq!(
                via_think, via_think_struct,
                "for_thinking_turn({prompt}, {completion}) must equal struct-literal form"
            );
            let j_th = serde_json::to_string(&via_think).expect("serialize think");
            let j_ths = serde_json::to_string(&via_think_struct).expect("serialize struct");
            assert_eq!(j_th, j_ths);

            // Variant pin: for_tool_call has tool_calls=1, for_thinking_turn has tool_calls=0.
            assert_eq!(via_tool.tool_calls, 1);
            assert_eq!(via_think.tool_calls, 0);
        }
    }

    #[test]
    fn budget_spec_with_memory_bytes_builder_equals_5_field_struct_literal_byte_for_byte() {
        // Phase 1 hardening — thin-wrapper equivalence pin (companion
        // to budget_spec_new_4_arg_equals_struct_literal_with_max_memory_bytes_zero
        // below). The full ergonomic-constructor path is:
        //   BudgetSpec::new(t, w, c, s).with_memory_bytes(m)
        // which MUST produce a spec byte-equal to the all-5-fields
        // struct-literal form. A future tweak that diverged either
        // helper (e.g., "let me cap memory at u64::MAX/2 in the
        // builder") would silently introduce two distinct spec byte
        // forms. Pin freezes the full chained-builder == struct
        // equivalence for the 5-axis WBO surface.
        //
        // Sweep: all-zero memory only, all-non-zero, u64::MAX memory.
        let fixtures: &[(u64, u64, u64, u64, u64)] = &[
            (0, 0, 0, 0, 0),
            (0, 0, 0, 0, 1_048_576),
            (1_000, 60_000, 5, 30_000, 1_024),
            (1, 2, 3, 4, 5),
            (u64::MAX, u64::MAX, u64::MAX, u64::MAX, u64::MAX),
        ];
        for &(t, w, c, s, m) in fixtures {
            let via_builder = BudgetSpec::new(t, w, c, s).with_memory_bytes(m);
            let via_struct = BudgetSpec {
                max_tokens: t,
                max_wall_ms: w,
                max_tool_calls: c,
                max_subprocess_ms: s,
                max_memory_bytes: m,
            };
            assert_eq!(
                via_builder, via_struct,
                "BudgetSpec::new({t}, {w}, {c}, {s}).with_memory_bytes({m}) \
                 must equal 5-field struct literal"
            );
            let j_b = serde_json::to_string(&via_builder).expect("serialize builder");
            let j_s = serde_json::to_string(&via_struct).expect("serialize struct");
            assert_eq!(j_b, j_s);
        }
    }

    #[test]
    fn budget_spec_new_4_arg_equals_struct_literal_with_max_memory_bytes_zero() {
        // Phase 1 hardening — thin-wrapper equivalence pin (companion
        // to the equivalence pin family at iter-518/519/520/521/522).
        // BudgetSpec::new is the canonical 4-arg ergonomic constructor;
        // it MUST produce a spec byte-equal to the direct struct-literal
        // form with max_memory_bytes implicitly defaulting to 0 across
        // representative argument shapes. A future "let me default
        // memory to half the system RAM" tweak in the helper that
        // diverged from struct construction would silently introduce
        // two distinct BudgetSpec forms depending on call site —
        // breaking BudgetGate.spec() equality + ledger-comparison
        // semantics downstream.
        //
        // Sweep: all-zero, mid, large, edge u64::MAX.
        let fixtures: &[(u64, u64, u64, u64)] = &[
            (0, 0, 0, 0),
            (1_000, 60_000, 5, 30_000),
            (1, 2, 3, 4),
            (u64::MAX, u64::MAX, u64::MAX, u64::MAX),
        ];
        for &(tokens, wall_ms, tool_calls, subprocess_ms) in fixtures {
            let via_new = BudgetSpec::new(tokens, wall_ms, tool_calls, subprocess_ms);
            let via_struct = BudgetSpec {
                max_tokens: tokens,
                max_wall_ms: wall_ms,
                max_tool_calls: tool_calls,
                max_subprocess_ms: subprocess_ms,
                max_memory_bytes: 0,
            };
            assert_eq!(
                via_new, via_struct,
                "BudgetSpec::new({tokens}, {wall_ms}, {tool_calls}, {subprocess_ms}) \
                 must equal struct-literal form with max_memory_bytes=0"
            );
            // Byte-equal JSON serialisation too — BudgetSpec is
            // serialised through the provenance path on snapshots.
            let j_new = serde_json::to_string(&via_new).expect("serialize new");
            let j_struct = serde_json::to_string(&via_struct).expect("serialize struct");
            assert_eq!(j_new, j_struct);
        }
    }
}
