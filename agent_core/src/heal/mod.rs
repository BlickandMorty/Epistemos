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

use std::future::Future;
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::format::intent::Intent;
use crate::tools::breaker::{BreakerError, CircuitBreaker};

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

    pub fn breaker(&self) -> &CircuitBreaker {
        &self.breaker
    }

    /// Plan §5.2 verbatim — Try-Heal-Retry. Generic over the apply
    /// closure's Ok type so callers can yield `Effect`, `ToolResult`,
    /// or any opaque success value.
    pub async fn run<E, F, Fut>(
        &self,
        intent: Intent,
        mut apply: F,
    ) -> Result<E, ApplyError>
    where
        F: FnMut(Intent) -> Fut,
        Fut: Future<Output = Result<E, ApplyError>>,
    {
        let mut current = intent;
        let mut last_err: Option<ApplyError> = None;
        for step in 0..self.max_heal_steps {
            // Plan §5.2 self.breaker.before_call()? — translate
            // BreakerError into ApplyError for caller convenience.
            if let Err(BreakerError::Open) = self.breaker.before_call() {
                return Err(ApplyError::breaker_open());
            }
            match apply(current.clone()).await {
                Ok(effect) => {
                    self.breaker.record_success();
                    return Ok(effect);
                }
                Err(err) => {
                    self.breaker.record_failure();
                    last_err = Some(err.clone());
                    if step + 1 >= self.max_heal_steps {
                        return Err(err);
                    }
                    match self
                        .diagnostician
                        .diagnose_and_correct(&current, &err)
                        .await
                    {
                        Some(corrected) => current = corrected,
                        None => return Err(err),
                    }
                }
            }
        }
        // unreachable in practice — the loop returns from each branch.
        Err(last_err.unwrap_or_else(|| {
            ApplyError::new("internal", "heal loop exited without verdict")
        }))
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
}
