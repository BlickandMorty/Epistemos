//! Hyperdynamic Schema Loop primitive — Terminal S, 2026-05-24.
//!
//! Every typed model output should pass through:
//!   draft → schema/admission/witness check → repair-or-accept → next layer
//!
//! Before Terminal S, every consumer of model output wrote ad-hoc retry
//! code: if a tool call had the wrong shape, the consumer either dropped
//! the turn or invented its own re-prompt. That fragmented the failure
//! surface and silently violated the typed-output contract.
//!
//! This module ships the *generic* runner. The three concrete loops live
//! alongside in submodules:
//! - `schema_repair`     — JSONSchema validate → repair prompt with field list
//! - `admission_repair`  — ACS verdict `defer`/`quarantine` → repair with policy hint
//! - `witness_repair`    — EML / F-ULP witness fails → repair with constraint
//!
//! The substrate motion is **Mutate / Promote** (raw model output → typed
//! accepted packet) per `docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md`
//! §12.6.

pub mod admission_repair;
#[cfg(feature = "research")]
pub mod schema_repair;
pub mod witness_repair;

pub use admission_repair::{AdmissionDraft, AdmissionRepairLoop};
#[cfg(feature = "research")]
pub use schema_repair::{SchemaDraft, SchemaRepairLoop};
pub use witness_repair::{WitnessDraft, WitnessRepairLoop, WitnessState};

use std::time::{Duration, Instant};

/// Bounded retry envelope. The acceptance bar in
/// `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md` §Terminal S is
/// `min(3 retries, 5 s, 1024 tokens)` by default; each call site can
/// tighten further via [`RepairBudget::tightened`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RepairBudget {
    pub max_retries: u8,
    pub max_latency: Duration,
    pub max_tokens: u32,
}

impl RepairBudget {
    /// Canonical default per the Terminal S acceptance bar.
    pub const DEFAULT: Self = Self {
        max_retries: 3,
        max_latency: Duration::from_millis(5_000),
        max_tokens: 1024,
    };

    #[must_use]
    pub const fn tightened(max_retries: u8, max_latency: Duration, max_tokens: u32) -> Self {
        Self {
            max_retries: if max_retries < Self::DEFAULT.max_retries {
                max_retries
            } else {
                Self::DEFAULT.max_retries
            },
            max_latency: if max_latency.as_millis() < Self::DEFAULT.max_latency.as_millis() {
                max_latency
            } else {
                Self::DEFAULT.max_latency
            },
            max_tokens: if max_tokens < Self::DEFAULT.max_tokens {
                max_tokens
            } else {
                Self::DEFAULT.max_tokens
            },
        }
    }

    #[must_use]
    pub const fn max_retries(self) -> u8 {
        self.max_retries
    }

    #[must_use]
    pub const fn max_latency(self) -> Duration {
        self.max_latency
    }

    #[must_use]
    pub const fn max_tokens(self) -> u32 {
        self.max_tokens
    }
}

impl Default for RepairBudget {
    fn default() -> Self {
        Self::DEFAULT
    }
}

/// One-shot verdict produced by a [`HyperdynamicLoop`] over a draft
/// packet. The runner closes the loop by mapping verdicts to either an
/// accepted packet, a fresh draft (with hint surface), or a terminal
/// quarantine.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RepairVerdict<P> {
    /// Draft satisfies the loop's invariant and may flow to the next layer.
    Accept(P),
    /// Draft is reparable. The runner is expected to re-emit a new draft
    /// using `hint` and the (tightened) seed packet.
    RepairWith {
        /// Operator-visible repair hint (policy snippet / missing fields / constraint).
        hint: String,
        /// Tightened seed packet for the next attempt. Concrete loops use
        /// this to project the partial-but-typed remnant forward (e.g.
        /// only the parseable fields of a schema draft).
        tightened: P,
    },
    /// Draft is terminal and must NOT flow forward. The reason is
    /// surfaced verbatim into the Provenance Console quarantine row.
    Quarantine { reason: String },
}

/// Lightweight per-(loop kind) counters surfaced by the SwiftUI
/// `HyperdynamicLoopHealthRow` chip strip.
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct LoopCounters {
    pub drafts: u64,
    pub accepted: u64,
    pub repaired: u64,
    pub quarantined: u64,
    pub total_repair_attempts: u64,
}

impl LoopCounters {
    #[must_use]
    pub const fn new() -> Self {
        Self {
            drafts: 0,
            accepted: 0,
            repaired: 0,
            quarantined: 0,
            total_repair_attempts: 0,
        }
    }

    /// Mean repair attempts per *finalized* draft (accepted + quarantined).
    /// Returns 0.0 when nothing has finalized yet.
    #[must_use]
    pub fn avg_repair_count(&self) -> f64 {
        let finalized = self.accepted + self.quarantined;
        if finalized == 0 {
            0.0
        } else {
            (self.total_repair_attempts as f64) / (finalized as f64)
        }
    }
}

/// Per-call-site loop primitive. Concrete impls live in the
/// `schema_repair` / `admission_repair` / `witness_repair` submodules.
pub trait HyperdynamicLoop {
    /// Draft packet shape the loop classifies.
    type Packet;
    /// Loop-internal classification error (distinct from a repairable
    /// verdict — e.g. validator panic, bad inputs).
    type Error;

    /// Stable identifier surfaced in counters + health row chips.
    fn kind(&self) -> &'static str;

    /// Classify a single draft. Pure: must not mutate counters or emit
    /// new drafts — the runner owns both.
    fn check(&self, draft: &Self::Packet) -> Result<RepairVerdict<Self::Packet>, Self::Error>;
}

/// Outcome of one full [`run_loop`] cycle. `repairs` is the number of
/// `RepairWith` verdicts that fired before the terminal verdict.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RepairOutcome<P> {
    /// Draft (or one of its repairs) was accepted. Safe to forward.
    Accepted { packet: P, repairs: u8 },
    /// A `Quarantine` verdict fired explicitly; the loop refused to
    /// repair.
    Quarantined { reason: String, repairs: u8 },
    /// `RepairWith` kept firing past the budget. Indistinguishable from
    /// quarantine to consumers, but distinct in metrics + the
    /// Provenance Console.
    QuarantinedBudgetExhausted { last_hint: String, repairs: u8 },
}

impl<P> RepairOutcome<P> {
    #[must_use]
    pub fn is_accepted(&self) -> bool {
        matches!(self, Self::Accepted { .. })
    }

    #[must_use]
    pub fn is_quarantined(&self) -> bool {
        matches!(
            self,
            Self::Quarantined { .. } | Self::QuarantinedBudgetExhausted { .. }
        )
    }

    #[must_use]
    pub fn repairs(&self) -> u8 {
        match self {
            Self::Accepted { repairs, .. }
            | Self::Quarantined { repairs, .. }
            | Self::QuarantinedBudgetExhausted { repairs, .. } => *repairs,
        }
    }

    #[must_use]
    pub fn accepted_packet(self) -> Option<P> {
        match self {
            Self::Accepted { packet, .. } => Some(packet),
            _ => None,
        }
    }
}

/// Drive a single draft through one [`HyperdynamicLoop`] until it
/// accepts, quarantines, or exhausts the [`RepairBudget`].
///
/// `re_emit` is the call site's "rerun the model with this hint"
/// closure — for production it ends up calling the model adapter, for
/// the falsifier harness it produces synthetic drafts. The loop has no
/// opinion on how the draft is re-produced; it only enforces the
/// **bounded retries** invariant required by F-HyperdynamicLoop-Bounded.
///
/// The runner is intentionally synchronous: every concrete callsite
/// today is a finite, bounded retry sequence; an async wrapper sits one
/// layer up in the executor.
pub fn run_loop<L, F>(
    loop_impl: &L,
    initial: L::Packet,
    budget: RepairBudget,
    counters: &mut LoopCounters,
    mut re_emit: F,
) -> Result<RepairOutcome<L::Packet>, L::Error>
where
    L: HyperdynamicLoop,
    F: FnMut(&L::Packet, &str) -> L::Packet,
{
    run_loop_with_clock(
        loop_impl,
        initial,
        budget,
        counters,
        &mut re_emit,
        Instant::now,
    )
}

/// `run_loop` with an injected clock — only used by tests + the
/// falsifier harness so latency-bounded runs are deterministic.
pub fn run_loop_with_clock<L, F, Clk>(
    loop_impl: &L,
    initial: L::Packet,
    budget: RepairBudget,
    counters: &mut LoopCounters,
    re_emit: &mut F,
    mut clock: Clk,
) -> Result<RepairOutcome<L::Packet>, L::Error>
where
    L: HyperdynamicLoop,
    F: FnMut(&L::Packet, &str) -> L::Packet,
    Clk: FnMut() -> Instant,
{
    counters.drafts += 1;
    let start = clock();
    let mut current = initial;
    let mut attempts: u8 = 0;

    loop {
        match loop_impl.check(&current)? {
            RepairVerdict::Accept(packet) => {
                counters.accepted += 1;
                counters.total_repair_attempts += u64::from(attempts);
                if attempts > 0 {
                    counters.repaired += 1;
                }
                return Ok(RepairOutcome::Accepted {
                    packet,
                    repairs: attempts,
                });
            }
            RepairVerdict::RepairWith { hint, tightened } => {
                let elapsed = clock().saturating_duration_since(start);
                if attempts >= budget.max_retries || elapsed >= budget.max_latency {
                    counters.quarantined += 1;
                    counters.total_repair_attempts += u64::from(attempts);
                    return Ok(RepairOutcome::QuarantinedBudgetExhausted {
                        last_hint: hint,
                        repairs: attempts,
                    });
                }
                attempts = attempts.saturating_add(1);
                current = re_emit(&tightened, &hint);
            }
            RepairVerdict::Quarantine { reason } => {
                counters.quarantined += 1;
                counters.total_repair_attempts += u64::from(attempts);
                return Ok(RepairOutcome::Quarantined {
                    reason,
                    repairs: attempts,
                });
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::Cell;

    struct AlwaysAccept;
    impl HyperdynamicLoop for AlwaysAccept {
        type Packet = u32;
        type Error = ();
        fn kind(&self) -> &'static str {
            "always_accept"
        }
        fn check(&self, draft: &Self::Packet) -> Result<RepairVerdict<Self::Packet>, Self::Error> {
            Ok(RepairVerdict::Accept(*draft))
        }
    }

    struct AcceptAfterN(u32);
    impl HyperdynamicLoop for AcceptAfterN {
        type Packet = u32;
        type Error = ();
        fn kind(&self) -> &'static str {
            "accept_after_n"
        }
        fn check(&self, draft: &Self::Packet) -> Result<RepairVerdict<Self::Packet>, Self::Error> {
            if *draft >= self.0 {
                Ok(RepairVerdict::Accept(*draft))
            } else {
                Ok(RepairVerdict::RepairWith {
                    hint: format!("need ≥ {}", self.0),
                    tightened: *draft,
                })
            }
        }
    }

    struct AlwaysRepair;
    impl HyperdynamicLoop for AlwaysRepair {
        type Packet = u32;
        type Error = ();
        fn kind(&self) -> &'static str {
            "always_repair"
        }
        fn check(&self, draft: &Self::Packet) -> Result<RepairVerdict<Self::Packet>, Self::Error> {
            Ok(RepairVerdict::RepairWith {
                hint: "still drift".to_string(),
                tightened: *draft,
            })
        }
    }

    struct ImmediateQuarantine;
    impl HyperdynamicLoop for ImmediateQuarantine {
        type Packet = u32;
        type Error = ();
        fn kind(&self) -> &'static str {
            "immediate_quarantine"
        }
        fn check(&self, _draft: &Self::Packet) -> Result<RepairVerdict<Self::Packet>, Self::Error> {
            Ok(RepairVerdict::Quarantine {
                reason: "policy_terminal".to_string(),
            })
        }
    }

    #[test]
    fn budget_default_is_canonical_acceptance_bar() {
        let b = RepairBudget::DEFAULT;
        assert_eq!(b.max_retries, 3);
        assert_eq!(b.max_latency, Duration::from_millis(5_000));
        assert_eq!(b.max_tokens, 1024);
    }

    #[test]
    fn tightened_never_loosens_the_default() {
        let tight = RepairBudget::tightened(1, Duration::from_millis(100), 256);
        assert_eq!(tight.max_retries, 1);
        assert_eq!(tight.max_latency, Duration::from_millis(100));
        assert_eq!(tight.max_tokens, 256);

        let loose = RepairBudget::tightened(99, Duration::from_secs(60), 100_000);
        assert_eq!(loose, RepairBudget::DEFAULT);
    }

    #[test]
    fn accept_first_try_records_no_repair() {
        let mut c = LoopCounters::new();
        let outcome = run_loop(
            &AlwaysAccept,
            7u32,
            RepairBudget::DEFAULT,
            &mut c,
            |p, _| *p,
        )
        .expect("loop runs");
        assert!(matches!(
            outcome,
            RepairOutcome::Accepted {
                packet: 7,
                repairs: 0
            }
        ));
        assert_eq!(c.drafts, 1);
        assert_eq!(c.accepted, 1);
        assert_eq!(c.repaired, 0);
        assert_eq!(c.quarantined, 0);
        assert_eq!(c.total_repair_attempts, 0);
        assert_eq!(c.avg_repair_count(), 0.0);
    }

    #[test]
    fn repair_then_accept_records_repaired_bucket() {
        let mut c = LoopCounters::new();
        let loop_impl = AcceptAfterN(3);
        let outcome = run_loop(&loop_impl, 0u32, RepairBudget::DEFAULT, &mut c, |p, _| {
            *p + 1
        })
        .expect("loop runs");
        match outcome {
            RepairOutcome::Accepted { packet, repairs } => {
                assert_eq!(packet, 3);
                assert_eq!(repairs, 3);
            }
            other => panic!("expected accepted, got {other:?}"),
        }
        assert_eq!(c.drafts, 1);
        assert_eq!(c.accepted, 1);
        assert_eq!(c.repaired, 1);
        assert_eq!(c.quarantined, 0);
        assert_eq!(c.total_repair_attempts, 3);
        assert!((c.avg_repair_count() - 3.0).abs() < f64::EPSILON);
    }

    #[test]
    fn budget_caps_retries_and_quarantines() {
        let mut c = LoopCounters::new();
        let budget = RepairBudget::tightened(2, Duration::from_millis(100), 64);
        let outcome =
            run_loop(&AlwaysRepair, 0u32, budget, &mut c, |p, _| *p + 1).expect("loop runs");
        match outcome {
            RepairOutcome::QuarantinedBudgetExhausted { repairs, .. } => {
                assert_eq!(repairs, 2);
            }
            other => panic!("expected budget exhaustion, got {other:?}"),
        }
        assert_eq!(c.accepted, 0);
        assert_eq!(c.quarantined, 1);
        assert_eq!(c.total_repair_attempts, 2);
    }

    #[test]
    fn budget_caps_on_wall_clock_too() {
        // Synthetic clock that jumps 50 ms every read after start.
        let now = Cell::new(Instant::now());
        let mut clk = || {
            let t = now.get();
            now.set(t + Duration::from_millis(50));
            t
        };
        let mut c = LoopCounters::new();
        let mut re = |p: &u32, _: &str| *p + 1;
        let budget = RepairBudget::tightened(99, Duration::from_millis(80), 64);
        let outcome = run_loop_with_clock(&AlwaysRepair, 0u32, budget, &mut c, &mut re, &mut clk)
            .expect("loop runs");
        assert!(matches!(
            outcome,
            RepairOutcome::QuarantinedBudgetExhausted { .. }
        ));
        // Two reads after start: t+50ms (still under), then t+100ms (over).
        assert!(c.quarantined == 1);
    }

    #[test]
    fn explicit_quarantine_terminates_immediately() {
        let mut c = LoopCounters::new();
        let outcome = run_loop(
            &ImmediateQuarantine,
            42u32,
            RepairBudget::DEFAULT,
            &mut c,
            |p, _| *p,
        )
        .expect("loop runs");
        match outcome {
            RepairOutcome::Quarantined { reason, repairs } => {
                assert_eq!(reason, "policy_terminal");
                assert_eq!(repairs, 0);
            }
            other => panic!("expected explicit quarantine, got {other:?}"),
        }
        assert_eq!(c.drafts, 1);
        assert_eq!(c.quarantined, 1);
        assert_eq!(c.accepted, 0);
    }

    #[test]
    fn loop_kind_strings_are_stable() {
        assert_eq!(AlwaysAccept.kind(), "always_accept");
        assert_eq!(AcceptAfterN(1).kind(), "accept_after_n");
        assert_eq!(AlwaysRepair.kind(), "always_repair");
        assert_eq!(ImmediateQuarantine.kind(), "immediate_quarantine");
    }

    #[test]
    fn avg_repair_count_averages_only_finalized() {
        let mut c = LoopCounters::new();
        // Two accepts at 0 + 2 repairs.
        let _ = run_loop(
            &AlwaysAccept,
            1u32,
            RepairBudget::DEFAULT,
            &mut c,
            |p, _| *p,
        )
        .unwrap();
        let _ = run_loop(
            &AcceptAfterN(2),
            0u32,
            RepairBudget::DEFAULT,
            &mut c,
            |p, _| *p + 1,
        )
        .unwrap();
        assert_eq!(c.accepted, 2);
        assert_eq!(c.total_repair_attempts, 2);
        assert!((c.avg_repair_count() - 1.0).abs() < f64::EPSILON);
    }
}
