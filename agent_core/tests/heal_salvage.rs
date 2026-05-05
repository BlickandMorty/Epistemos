use std::sync::{Arc, Mutex};

use agent_core::effect::ApplyError;
use agent_core::format::Intent;
use agent_core::heal::breaker::{BreakerConfig, BreakerState, CircuitBreaker};
use agent_core::heal::log::{HealEventLog, HealOutcome};
use agent_core::heal::{Diagnostician, GiveUpDiagnostician, HealLoop, DEFAULT_MAX_HEAL_STEPS};
use async_trait::async_trait;

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
    async fn diagnose_and_correct(&self, _intent: &Intent, _error: &ApplyError) -> Option<Intent> {
        self.script
            .lock()
            .expect("script mutex")
            .pop()
            .unwrap_or(None)
    }
}

fn write_intent(path: &str) -> Intent {
    Intent::VaultWrite {
        path: path.to_string(),
        body: "body".to_string(),
        frontmatter: serde_json::json!({}),
    }
}

#[tokio::test]
async fn heal_loop_recovers_with_corrected_intent_and_logs_recovered_step() {
    let log = Arc::new(HealEventLog::open_in_memory().expect("heal log"));
    let loop_ = HealLoop::new(Arc::new(ScriptedDiagnostician::new(vec![Some(
        write_intent("ok.md"),
    )])))
    .with_event_log(Arc::clone(&log), "vault.write", "variant_a");

    let result: Result<String, ApplyError> = loop_
        .run_logged(write_intent("bad.md"), "session-1", |intent| async move {
            match intent {
                Intent::VaultWrite { path, .. } if path == "bad.md" => {
                    Err(ApplyError::InvalidIntent("bad path".to_string()))
                }
                Intent::VaultWrite { path, .. } => Ok(path),
                _ => Err(ApplyError::Permanent("wrong intent".to_string())),
            }
        })
        .await;

    assert_eq!(result.expect("recovered"), "ok.md");
    let events = log.events_for_session("session-1").expect("events");
    assert_eq!(events.len(), 1);
    assert_eq!(events[0].outcome, HealOutcome::Recovered);
    assert_eq!(events[0].tool, "vault.write");
    assert_eq!(events[0].variant, "variant_a");
    assert!(events[0].corrected_intent.is_some());
}

#[tokio::test]
async fn give_up_diagnostician_returns_first_error_without_retry() {
    let loop_ = HealLoop::new(Arc::new(GiveUpDiagnostician));
    let attempts = Arc::new(Mutex::new(0usize));
    let attempts_for_apply = Arc::clone(&attempts);

    let result: Result<(), ApplyError> = loop_
        .run(write_intent("bad.md"), move |_| {
            let attempts = Arc::clone(&attempts_for_apply);
            async move {
                *attempts.lock().expect("attempts mutex") += 1;
                Err(ApplyError::IoError("disk said no".to_string()))
            }
        })
        .await;

    assert!(matches!(result, Err(ApplyError::IoError(_))));
    assert_eq!(*attempts.lock().expect("attempts mutex"), 1);
    assert_eq!(DEFAULT_MAX_HEAL_STEPS, 3);
}

#[tokio::test]
async fn open_breaker_short_circuits_before_apply() {
    let breaker = CircuitBreaker::new(BreakerConfig {
        failure_threshold: 1,
        cooldown_secs: 60,
    });
    breaker.record_failure();
    assert_eq!(breaker.snapshot().state, BreakerState::Open);

    let loop_ = HealLoop::new(Arc::new(GiveUpDiagnostician)).with_breaker(breaker);
    let result: Result<(), ApplyError> = loop_
        .run(write_intent("bad.md"), |_| async { Ok(()) })
        .await;
    assert!(matches!(result, Err(ApplyError::BreakerOpen)));
}

#[test]
fn heal_event_log_reports_recurring_error_patterns() {
    let log = HealEventLog::open_in_memory().expect("heal log");
    for step in 0..10 {
        log.append_failure(
            "vault.write",
            "variant_a",
            &write_intent("bad.md"),
            &ApplyError::InvalidIntent("bad path".to_string()),
            None,
            HealOutcome::Abandoned,
            step,
            "session-recurring",
        )
        .expect("append");
    }

    let patterns = log.recurring_patterns(7, 10).expect("patterns");
    assert_eq!(patterns.len(), 1);
    assert_eq!(patterns[0].tool, "vault.write");
    assert_eq!(patterns[0].error_kind, "invalid_intent");
    assert_eq!(patterns[0].event_count, 10);
}
