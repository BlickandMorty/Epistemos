//! Phase 4 — Self-healing Try-Heal-Retry per plan §5.
//!
//! Plan §5.1: "The agent never directly mutates state. It emits an
//! Intent. The Rust runtime applies the Intent. If application fails,
//! the failure becomes a heal step — the Intent is fed back to the LLM
//! with the captured stderr/violation/empty-result and a diagnostic
//! prompt asking for a corrected Intent. This is bounded by a circuit
//! breaker."
//!
//! Plan §5.2 implementation sketch verbatim — `HealLoop::run` walks
//! retries until either:
//! - apply succeeds (return Ok),
//! - max_heal_steps exhausted (return last error),
//! - diagnostician gives up (return error from the failed step),
//! - circuit breaker open (return BreakerOpen error).
//!
//! Phase 4A scope (this commit):
//! - HealLoop generic over the apply closure's Effect type.
//! - Diagnostician trait — LLM-bearing in production; `GiveUpDiagnostician`
//!   for tests / no-LLM contexts.
//! - ApplyError typed (kind/message/context — plan §5.7 column shapes).
//! - heal/breaker.rs as a re-export of tools::breaker (single
//!   CircuitBreaker type, two consumers per plan §5.3 + §3.2).
//!
//! Phase 4B will add heal_log.sqlite persistence (§5.7); Phase 4C wires
//! the actual diagnostic soul file (`agent_core/souls/
//! diagnostician.soul.{json,md}` per §11 Phase 4).

pub mod breaker;
pub mod log;

use std::future::Future;
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::format::intent::Intent;
use crate::tools::breaker::{BreakerError, CircuitBreaker};

use self::log::{HealEvent, HealEventLog, HealOutcome};

/// Plan §5.7 heal_events column shapes — `error JSON NOT NULL`.
/// `kind` corresponds to the error class (schema_violation, io,
/// timeout, breaker_open, etc.); `message` is human-readable; `context`
/// carries arbitrary structured details (file paths, error chains, …).
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct ApplyError {
    pub kind: String,
    pub message: String,
    #[serde(default)]
    pub context: Value,
}

impl ApplyError {
    pub fn new(kind: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            kind: kind.into(),
            message: message.into(),
            context: Value::Null,
        }
    }

    pub fn breaker_open() -> Self {
        Self::new("breaker_open", "circuit breaker is open")
    }

    pub fn with_context(mut self, ctx: Value) -> Self {
        self.context = ctx;
        self
    }
}

impl std::fmt::Display for ApplyError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.kind, self.message)
    }
}

impl std::error::Error for ApplyError {}

/// Plan §5.2 — diagnose_and_correct receives the failing Intent + the
/// captured error, asks the LLM (Phase 6 wires real diagnostic soul)
/// for a corrected Intent. Returning `None` is interpreted as
/// "give up" and short-circuits the heal loop with the original error.
#[async_trait]
pub trait Diagnostician: Send + Sync {
    async fn diagnose_and_correct(
        &self,
        original: &Intent,
        err: &ApplyError,
    ) -> Option<Intent>;
}

/// Test/no-LLM diagnostician: always gives up. With this set the
/// HealLoop runs the apply once, returns success, or surfaces the
/// original error — equivalent to having no heal.
pub struct GiveUpDiagnostician;

#[async_trait]
impl Diagnostician for GiveUpDiagnostician {
    async fn diagnose_and_correct(&self, _: &Intent, _: &ApplyError) -> Option<Intent> {
        None
    }
}

/// Plan §5.2 max_heal_steps default — "bounded at 3 retries before
/// falling back to verifier-only" (§3.6 cascading + §6.5 repeat-loop
/// failure mode mention 3 as the bound).
pub const DEFAULT_MAX_HEAL_STEPS: u32 = 3;

/// Plan §5.3 default breaker config — open after 5 consecutive
/// failures, 30s cooldown, 2 successes to close.
pub const HEAL_BREAKER_FAILURE_THRESHOLD: u32 = 5;

pub struct HealLoop {
    breaker: CircuitBreaker,
    max_heal_steps: u32,
    diagnostician: Arc<dyn Diagnostician>,
    /// Phase 4C — optional sink for per-step heal events. When set,
    /// `run_logged` collects an event per failed step + flushes them
    /// atomically (append_batch) on loop termination with the final
    /// `HealOutcome` stamped on every row.
    event_log: Option<Arc<HealEventLog>>,
    /// Tool name stamped on heal_events rows. Required when event_log
    /// is set; defaults to empty string when unset.
    tool_name: String,
    /// Variant id stamped on heal_events rows.
    variant_id: String,
}

impl HealLoop {
    pub fn new(diagnostician: Arc<dyn Diagnostician>) -> Self {
        Self {
            breaker: CircuitBreaker::new(
                HEAL_BREAKER_FAILURE_THRESHOLD,
                Duration::from_secs(30),
            ),
            max_heal_steps: DEFAULT_MAX_HEAL_STEPS,
            diagnostician,
            event_log: None,
            tool_name: String::new(),
            variant_id: String::new(),
        }
    }

    pub fn with_max_heal_steps(mut self, n: u32) -> Self {
        self.max_heal_steps = n;
        self
    }

    pub fn with_breaker(mut self, breaker: CircuitBreaker) -> Self {
        self.breaker = breaker;
        self
    }

    /// Phase 4C — attach a HealEventLog so the heal loop emits per-step
    /// events on termination. `tool` and `variant` stamp every event;
    /// `session_id` is supplied per-call via `run_logged`.
    pub fn with_event_log(
        mut self,
        log: Arc<HealEventLog>,
        tool: impl Into<String>,
        variant: impl Into<String>,
    ) -> Self {
        self.event_log = Some(log);
        self.tool_name = tool.into();
        self.variant_id = variant.into();
        self
    }

    pub fn breaker(&self) -> &CircuitBreaker {
        &self.breaker
    }

    /// Plan §5.2 verbatim — Try-Heal-Retry. Generic over the apply
    /// closure's Ok type. Equivalent to `run_logged` with an empty
    /// session_id; events are still recorded if `with_event_log` was
    /// called (the empty session_id is what the trace UI sees).
    pub async fn run<E, F, Fut>(
        &self,
        intent: Intent,
        apply: F,
    ) -> Result<E, ApplyError>
    where
        F: FnMut(Intent) -> Fut,
        Fut: Future<Output = Result<E, ApplyError>>,
    {
        self.run_logged(intent, "", apply).await
    }

    /// Phase 4C entry point — like `run` but records per-step events to
    /// the attached `HealEventLog` (if any), stamping every event with
    /// `session_id` for the trace UI. Per-step rows are collected
    /// during the loop and flushed atomically (append_batch) on
    /// termination; the final loop outcome (Recovered / Abandoned)
    /// is stamped on every row per §5.7.
    ///
    /// When no event log is attached this method is identical to `run`.
    pub async fn run_logged<E, F, Fut>(
        &self,
        intent: Intent,
        session_id: &str,
        mut apply: F,
    ) -> Result<E, ApplyError>
    where
        F: FnMut(Intent) -> Fut,
        Fut: Future<Output = Result<E, ApplyError>>,
    {
        let mut current = intent;
        let mut last_err: Option<ApplyError> = None;
        let mut pending_events: Vec<HealEvent> = Vec::new();

        // Run the loop body; on termination we know the overall outcome
        // and can stamp it on every collected event before flushing.
        let (outcome, result): (HealOutcome, Result<E, ApplyError>) = 'body: {
            for step in 0..self.max_heal_steps {
                if let Err(BreakerError::Open) = self.breaker.before_call() {
                    let err = ApplyError::breaker_open();
                    last_err = Some(err.clone());
                    break 'body (HealOutcome::Abandoned, Err(err));
                }
                match apply(current.clone()).await {
                    Ok(effect) => {
                        self.breaker.record_success();
                        break 'body (HealOutcome::Recovered, Ok(effect));
                    }
                    Err(err) => {
                        self.breaker.record_failure();
                        last_err = Some(err.clone());
                        let is_last_step = step + 1 >= self.max_heal_steps;
                        let corrected = if is_last_step {
                            None
                        } else {
                            self.diagnostician
                                .diagnose_and_correct(&current, &err)
                                .await
                        };
                        // Phase 4C: record THIS step's failure event.
                        // outcome is tentative (Abandoned); stamped to
                        // final value before flush.
                        if self.event_log.is_some() {
                            pending_events.push(HealEvent {
                                id: None,
                                ts: Utc::now(),
                                tool: self.tool_name.clone(),
                                variant: self.variant_id.clone(),
                                original_intent: current.clone(),
                                error: err.clone(),
                                corrected_intent: corrected.clone(),
                                outcome: HealOutcome::Abandoned,
                                step_idx: step,
                                session_id: session_id.to_string(),
                            });
                        }
                        match corrected {
                            Some(c) => current = c,
                            None => break 'body (HealOutcome::Abandoned, Err(err)),
                        }
                    }
                }
            }
            // Loop body fell through (shouldn't happen — every iteration
            // either returns or continues). Defence-in-depth.
            (
                HealOutcome::Abandoned,
                Err(last_err.clone().unwrap_or_else(|| {
                    ApplyError::new("internal", "heal loop exited without verdict")
                })),
            )
        };

        // Phase 4C — flush pending events with the final outcome stamped
        // on each row. Best-effort: log failures don't propagate to the
        // caller (preserve `result`); they're only reachable in tests.
        if let Some(log) = &self.event_log {
            for ev in pending_events.iter_mut() {
                ev.outcome = outcome;
            }
            // append_batch is atomic; either all per-step rows land or
            // none do (preserves §5.7 referential integrity).
            let _ = log.append_batch(&pending_events);
        }

        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    /// Diagnostician that returns a preconfigured sequence of corrections.
    /// Tests build it with a Vec; each call to diagnose_and_correct
    /// pops the next entry.
    struct ScriptedDiagnostician {
        script: Mutex<Vec<Option<Intent>>>,
    }

    impl ScriptedDiagnostician {
        fn new(script: Vec<Option<Intent>>) -> Self {
            Self {
                script: Mutex::new(script.into_iter().rev().collect()),
            }
        }
    }

    #[async_trait]
    impl Diagnostician for ScriptedDiagnostician {
        async fn diagnose_and_correct(
            &self,
            _: &Intent,
            _: &ApplyError,
        ) -> Option<Intent> {
            self.script.lock().unwrap().pop().unwrap_or(None)
        }
    }

    fn noop_intent() -> Intent {
        Intent::Noop {
            reason: "test".to_string(),
        }
    }

    fn write_intent(path: &str) -> Intent {
        Intent::VaultWrite {
            path: path.to_string(),
            body: "test".to_string(),
            frontmatter: serde_json::json!({}),
        }
    }

    #[tokio::test]
    async fn first_apply_success_returns_immediately() {
        let h = HealLoop::new(Arc::new(GiveUpDiagnostician));
        let r: Result<&str, _> = h
            .run(noop_intent(), |_| async { Ok("ok") })
            .await;
        assert_eq!(r.unwrap(), "ok");
    }

    #[tokio::test]
    async fn give_up_diagnostician_returns_first_error() {
        let h = HealLoop::new(Arc::new(GiveUpDiagnostician));
        let attempts = Arc::new(Mutex::new(0u32));
        let attempts_clone = attempts.clone();
        let r: Result<(), _> = h
            .run(noop_intent(), move |_| {
                let attempts = attempts_clone.clone();
                async move {
                    *attempts.lock().unwrap() += 1;
                    Err(ApplyError::new("schema_violation", "bad"))
                }
            })
            .await;
        let err = r.unwrap_err();
        assert_eq!(err.kind, "schema_violation");
        assert_eq!(*attempts.lock().unwrap(), 1, "give-up retries 0 times");
    }

    #[tokio::test]
    async fn diagnose_and_correct_recovers_after_one_failure() {
        // First apply fails; diagnostician returns a corrected intent
        // with a different path; second apply succeeds.
        let diag = ScriptedDiagnostician::new(vec![Some(write_intent("ok.md"))]);
        let h = HealLoop::new(Arc::new(diag));
        let attempts = Arc::new(Mutex::new(0u32));
        let attempts_clone = attempts.clone();
        let r: Result<String, _> = h
            .run(write_intent("bad.md"), move |intent| {
                let attempts = attempts_clone.clone();
                async move {
                    *attempts.lock().unwrap() += 1;
                    match intent {
                        Intent::VaultWrite { path, .. } if path == "bad.md" => {
                            Err(ApplyError::new("io", "permission denied"))
                        }
                        Intent::VaultWrite { path, .. } => Ok(path),
                        _ => Err(ApplyError::new("internal", "wrong intent type")),
                    }
                }
            })
            .await;
        assert_eq!(r.unwrap(), "ok.md");
        assert_eq!(*attempts.lock().unwrap(), 2, "one failure + one recovery");
    }

    #[tokio::test]
    async fn max_heal_steps_bounds_attempts() {
        // Diagnostician keeps proposing different intents but apply
        // always fails. After max_heal_steps the loop returns the
        // last error.
        let script = vec![
            Some(write_intent("a")),
            Some(write_intent("b")),
            Some(write_intent("c")),
        ];
        let diag = ScriptedDiagnostician::new(script);
        let h = HealLoop::new(Arc::new(diag)).with_max_heal_steps(3);
        let attempts = Arc::new(Mutex::new(0u32));
        let attempts_clone = attempts.clone();
        let r: Result<(), _> = h
            .run(write_intent("initial"), move |_| {
                let attempts = attempts_clone.clone();
                async move {
                    *attempts.lock().unwrap() += 1;
                    Err(ApplyError::new("io", "always fails"))
                }
            })
            .await;
        assert!(r.is_err());
        assert_eq!(
            *attempts.lock().unwrap(),
            3,
            "exactly max_heal_steps attempts"
        );
    }

    #[tokio::test]
    async fn diagnostician_giving_up_mid_run_short_circuits() {
        // First failure → diagnostician returns Some(corrected);
        // second failure → diagnostician returns None;
        // loop short-circuits with the second error.
        let script = vec![Some(write_intent("retry-target")), None];
        let diag = ScriptedDiagnostician::new(script);
        let h = HealLoop::new(Arc::new(diag)).with_max_heal_steps(5);
        let attempts = Arc::new(Mutex::new(0u32));
        let attempts_clone = attempts.clone();
        let r: Result<(), _> = h
            .run(write_intent("initial"), move |_| {
                let attempts = attempts_clone.clone();
                async move {
                    *attempts.lock().unwrap() += 1;
                    Err(ApplyError::new("io", "fails"))
                }
            })
            .await;
        assert!(r.is_err());
        assert_eq!(
            *attempts.lock().unwrap(),
            2,
            "1 initial + 1 retry, then diagnostician None → bail"
        );
    }

    #[tokio::test]
    async fn breaker_open_short_circuits_with_breaker_open_error() {
        // Pre-trip the breaker by recording threshold failures; then
        // run() should return BreakerOpen without invoking apply.
        let breaker = CircuitBreaker::new(2, Duration::from_secs(60));
        breaker.record_failure();
        breaker.record_failure();
        let h = HealLoop::new(Arc::new(GiveUpDiagnostician)).with_breaker(breaker);
        let invoked = Arc::new(Mutex::new(0u32));
        let invoked_clone = invoked.clone();
        let r: Result<(), _> = h
            .run(noop_intent(), move |_| {
                let invoked = invoked_clone.clone();
                async move {
                    *invoked.lock().unwrap() += 1;
                    Ok(())
                }
            })
            .await;
        let err = r.unwrap_err();
        assert_eq!(err.kind, "breaker_open");
        assert_eq!(*invoked.lock().unwrap(), 0, "apply must not run when breaker open");
    }

    #[tokio::test]
    async fn breaker_records_success_on_first_apply_ok() {
        // After Ok, breaker should be in Closed state with
        // consecutive_failures reset.
        let h = HealLoop::new(Arc::new(GiveUpDiagnostician));
        let _: Result<(), _> = h.run(noop_intent(), |_| async { Ok(()) }).await;
        assert_eq!(
            h.breaker().state(),
            crate::tools::breaker::BreakerState::Closed
        );
    }

    #[test]
    fn apply_error_serializes_with_plan_5_7_columns() {
        // §5.7 heal_events.error column is JSON NOT NULL. Verify
        // ApplyError carries kind + message + context fields ready
        // for storage.
        let e = ApplyError::new("schema_violation", "bad output").with_context(
            serde_json::json!({"field": "confidence", "got": 1.5, "expected": "0..=1"}),
        );
        let s = serde_json::to_string(&e).unwrap();
        let v: Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["kind"], "schema_violation");
        assert_eq!(v["message"], "bad output");
        assert_eq!(v["context"]["field"], "confidence");
    }

    #[test]
    fn default_max_heal_steps_is_3_per_plan_5_2() {
        // Plan §5.2 + §3.6 + §6.5: bounded at 3 retries.
        assert_eq!(DEFAULT_MAX_HEAL_STEPS, 3);
    }

    #[test]
    fn breaker_threshold_default_5_per_plan_5_3() {
        assert_eq!(HEAL_BREAKER_FAILURE_THRESHOLD, 5);
    }

    // ────────────────────────────────────────────────────────────
    // Phase 4C — HealLoop ↔ HealEventLog wiring tests
    // ────────────────────────────────────────────────────────────

    use super::log::HealEventLog;

    #[tokio::test]
    async fn heal_loop_records_no_events_when_first_apply_succeeds() {
        // Recovered without a single retry — §5.7 says the loop
        // emits events PER STEP, and a clean success had zero failed
        // steps. So the log stays empty.
        let log = Arc::new(HealEventLog::open_in_memory().unwrap());
        let h = HealLoop::new(Arc::new(GiveUpDiagnostician))
            .with_event_log(log.clone(), "vault.write", "a");
        let _: Result<&str, _> = h
            .run_logged(noop_intent(), "session_1", |_| async { Ok("ok") })
            .await;
        assert_eq!(log.count().unwrap(), 0);
    }

    #[tokio::test]
    async fn heal_loop_records_events_on_failed_steps_with_recovered_outcome() {
        // First apply fails; diagnostician corrects; second succeeds.
        // 1 failed step → 1 row → outcome=Recovered (loop succeeded).
        let diag = ScriptedDiagnostician::new(vec![Some(write_intent("ok.md"))]);
        let log = Arc::new(HealEventLog::open_in_memory().unwrap());
        let h = HealLoop::new(Arc::new(diag))
            .with_event_log(log.clone(), "vault.write", "a");
        let _: Result<String, _> = h
            .run_logged(write_intent("bad.md"), "session_recovered", |intent| async move {
                match intent {
                    Intent::VaultWrite { path, .. } if path == "bad.md" => {
                        Err(ApplyError::new("io", "permission denied"))
                    }
                    Intent::VaultWrite { path, .. } => Ok(path),
                    _ => Err(ApplyError::new("internal", "wrong intent")),
                }
            })
            .await;
        let events = log.events_for_session("session_recovered").unwrap();
        assert_eq!(events.len(), 1, "1 failed step before recovery");
        assert_eq!(
            events[0].outcome,
            HealOutcome::Recovered,
            "loop succeeded → outcome stamped Recovered on every row"
        );
        assert_eq!(events[0].tool, "vault.write");
        assert_eq!(events[0].variant, "a");
        assert_eq!(events[0].step_idx, 0);
        assert!(events[0].corrected_intent.is_some());
    }

    #[tokio::test]
    async fn heal_loop_records_events_on_failed_steps_with_abandoned_outcome() {
        // All retries fail; max_heal_steps=3 → 3 rows → outcome=Abandoned.
        let script = vec![Some(write_intent("a")), Some(write_intent("b"))];
        let diag = ScriptedDiagnostician::new(script);
        let log = Arc::new(HealEventLog::open_in_memory().unwrap());
        let h = HealLoop::new(Arc::new(diag))
            .with_max_heal_steps(3)
            .with_event_log(log.clone(), "vault.write", "a");
        let _: Result<(), _> = h
            .run_logged(write_intent("initial"), "session_abandoned", |_| async {
                Err(ApplyError::new("io", "always fails"))
            })
            .await;
        let events = log.events_for_session("session_abandoned").unwrap();
        // step 0, 1 collect rows (events recorded on failure with
        // a possible correction); step 2 is is_last_step → no
        // correction collected but the row IS recorded.
        // Wait — re-read code: rows are recorded for every failure
        // including the last. So 3 failures → 3 rows.
        assert_eq!(events.len(), 3);
        for ev in &events {
            assert_eq!(ev.outcome, HealOutcome::Abandoned);
        }
        // step_idx should be 0, 1, 2 in order.
        assert_eq!(events[0].step_idx, 0);
        assert_eq!(events[1].step_idx, 1);
        assert_eq!(events[2].step_idx, 2);
        // Last step has no corrected_intent (is_last_step → None).
        assert!(events[2].corrected_intent.is_none());
        // Earlier steps have their corrected intents from the script.
        assert!(events[0].corrected_intent.is_some());
        assert!(events[1].corrected_intent.is_some());
    }

    #[tokio::test]
    async fn heal_loop_with_no_event_log_does_not_crash() {
        // Without with_event_log, the loop runs normally; no log
        // interactions happen. Sanity check.
        let h = HealLoop::new(Arc::new(GiveUpDiagnostician));
        let _: Result<(), _> = h
            .run_logged(noop_intent(), "no_log_session", |_| async {
                Err(ApplyError::new("x", "fails"))
            })
            .await;
        // No assertions on a log because there isn't one — just
        // verify the call returns without panicking.
    }

    #[tokio::test]
    async fn heal_loop_breaker_open_records_no_events() {
        // Breaker pre-tripped → run never invokes apply → no failures
        // recorded → 0 rows.
        let breaker = CircuitBreaker::new(2, Duration::from_secs(60));
        breaker.record_failure();
        breaker.record_failure();
        let log = Arc::new(HealEventLog::open_in_memory().unwrap());
        let h = HealLoop::new(Arc::new(GiveUpDiagnostician))
            .with_breaker(breaker)
            .with_event_log(log.clone(), "x", "a");
        let _: Result<(), _> = h
            .run_logged(noop_intent(), "session_breaker", |_| async { Ok(()) })
            .await;
        assert_eq!(log.count().unwrap(), 0);
    }

    #[tokio::test]
    async fn heal_loop_recovered_outcome_aggregates_for_recurring_pattern_query() {
        // Smoke test: after multiple sessions with recoveries, the
        // recurring_patterns query sees the right (tool, error_kind)
        // aggregations. Each session has at most 1 failure on its
        // first step (recovered or abandoned), so we need a breaker
        // threshold high enough to not trip across 11 sessions —
        // the per-tool breaker IS shared across calls per §5.3
        // ("per-tool breakers, not global"), and 11 consecutive
        // abandons would open the default-5 breaker. For this drift
        // aggregation smoke test we keep the breaker effectively
        // disabled (threshold 100) — production can tune via
        // with_breaker (real callers will use the §5.3 default).
        let diag = ScriptedDiagnostician::new(vec![Some(write_intent("ok.md"))]);
        let log = Arc::new(HealEventLog::open_in_memory().unwrap());
        let high_threshold = CircuitBreaker::new(100, Duration::from_secs(30));
        let h = HealLoop::new(Arc::new(diag))
            .with_breaker(high_threshold)
            .with_event_log(log.clone(), "vault.write", "a");

        for i in 0..11 {
            let _: Result<String, _> = h
                .run_logged(
                    write_intent("bad.md"),
                    &format!("s{}", i),
                    |intent| async move {
                        match intent {
                            Intent::VaultWrite { path, .. } if path == "bad.md" => {
                                Err(ApplyError::new("io", "denied"))
                            }
                            Intent::VaultWrite { path, .. } => Ok(path),
                            _ => Err(ApplyError::new("x", "x")),
                        }
                    },
                )
                .await;
        }
        // 11 sessions × 1 failed step each = 11 events for
        // (vault.write, io) — exceeds the §5.7 default 10/7 threshold.
        let patterns = log
            .recurring_patterns(7, 10)
            .unwrap();
        assert_eq!(patterns.len(), 1);
        assert_eq!(patterns[0].tool, "vault.write");
        assert_eq!(patterns[0].error_kind, "io");
        assert_eq!(patterns[0].event_count, 11);
    }

    #[test]
    fn diagnostician_soul_scaffold_loads_via_soul_pair() {
        // Plan §11 Phase 4 deliverable: agent_core/souls/
        // diagnostician.soul.{json,md}. This test loads the shipped
        // scaffold via Phase 1's SoulPair::load — proves bidirectional
        // integrity (manifest ↔ narrative) per §2.3.
        use crate::format::soul::SoulPair;
        let workspace_root = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let manifest_path = workspace_root
            .join("souls")
            .join("diagnostician.soul.json");
        let pair = SoulPair::load(&manifest_path)
            .expect("diagnostician.soul.json must load via SoulPair");
        assert_eq!(pair.manifest.id, "soul.diagnostician.v1");
        assert_eq!(pair.manifest.name, "Diagnostician");
        assert_eq!(pair.manifest.version, "1.0.0");
        // §5.2 single-turn diagnose-and-correct.
        assert_eq!(pair.manifest.max_turns, Some(1));
        // No destructive tools.
        assert!(pair
            .manifest
            .tool_blacklist
            .iter()
            .any(|t| t == "action.bash"));
        assert!(pair
            .manifest
            .tool_blacklist
            .iter()
            .any(|t| t == "action.terminal"));
        // reason.think is the only whitelisted tool — diagnostician
        // can think, can't do.
        assert_eq!(
            pair.manifest.tool_whitelist,
            vec!["reason.think".to_string()]
        );
    }

    #[tokio::test]
    async fn shared_breaker_opens_after_5_consecutive_abandons_per_5_3() {
        // Plan §5.3 invariant — per-tool breaker accumulates failures
        // across calls. 5 consecutive HealLoop terminations with
        // Abandoned outcome (no recoveries) opens the breaker. This
        // is the test that ensures the canonical §5.3 behavior holds
        // even when callers reuse one HealLoop across many captures.
        let diag = ScriptedDiagnostician::new(vec![]);  // always None → bail
        let h = HealLoop::new(Arc::new(diag));
        for _ in 0..5 {
            let _: Result<(), _> = h
                .run(noop_intent(), |_| async {
                    Err(ApplyError::new("io", "fails"))
                })
                .await;
        }
        // After 5 consecutive abandons, breaker should be Open.
        assert_eq!(
            h.breaker().state(),
            crate::tools::breaker::BreakerState::Open,
            "5 consecutive failures opens the breaker per §5.3"
        );
        // Sixth call short-circuits with breaker_open.
        let r: Result<(), _> = h
            .run(noop_intent(), |_| async { Ok(()) })
            .await;
        assert_eq!(r.unwrap_err().kind, "breaker_open");
    }
}
