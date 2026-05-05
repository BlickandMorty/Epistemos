pub mod breaker;
pub mod log;

use std::future::Future;
use std::sync::Arc;

use async_trait::async_trait;
use chrono::Utc;

use crate::effect::ApplyError;
use crate::format::Intent;
use breaker::CircuitBreaker;
use log::{HealEvent, HealEventLog, HealOutcome};

#[async_trait]
pub trait Diagnostician: Send + Sync {
    async fn diagnose_and_correct(&self, intent: &Intent, error: &ApplyError) -> Option<Intent>;
}

pub struct GiveUpDiagnostician;

#[async_trait]
impl Diagnostician for GiveUpDiagnostician {
    async fn diagnose_and_correct(&self, _intent: &Intent, _error: &ApplyError) -> Option<Intent> {
        None
    }
}

pub const DEFAULT_MAX_HEAL_STEPS: u32 = 3;

pub struct HealLoop {
    breaker: CircuitBreaker,
    max_heal_steps: u32,
    diagnostician: Arc<dyn Diagnostician>,
    event_log: Option<Arc<HealEventLog>>,
    tool_name: String,
    variant_id: String,
}

impl HealLoop {
    pub fn new(diagnostician: Arc<dyn Diagnostician>) -> Self {
        Self {
            breaker: CircuitBreaker::new(Default::default()),
            max_heal_steps: DEFAULT_MAX_HEAL_STEPS,
            diagnostician,
            event_log: None,
            tool_name: String::new(),
            variant_id: String::new(),
        }
    }

    pub fn with_max_heal_steps(mut self, max_heal_steps: u32) -> Self {
        self.max_heal_steps = max_heal_steps.max(1);
        self
    }

    pub fn with_breaker(mut self, breaker: CircuitBreaker) -> Self {
        self.breaker = breaker;
        self
    }

    pub fn with_event_log(
        mut self,
        event_log: Arc<HealEventLog>,
        tool_name: impl Into<String>,
        variant_id: impl Into<String>,
    ) -> Self {
        self.event_log = Some(event_log);
        self.tool_name = tool_name.into();
        self.variant_id = variant_id.into();
        self
    }

    pub fn breaker(&self) -> &CircuitBreaker {
        &self.breaker
    }

    pub async fn run<E, F, Fut>(&self, intent: Intent, apply: F) -> Result<E, ApplyError>
    where
        F: FnMut(Intent) -> Fut,
        Fut: Future<Output = Result<E, ApplyError>>,
    {
        self.run_logged(intent, "", apply).await
    }

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
        let mut pending_events = Vec::new();

        for step_idx in 0..self.max_heal_steps {
            if !self.breaker.try_acquire() {
                return Err(ApplyError::BreakerOpen);
            }

            match apply(current.clone()).await {
                Ok(effect) => {
                    self.breaker.record_success();
                    self.flush_events(&mut pending_events, HealOutcome::Recovered);
                    return Ok(effect);
                }
                Err(error) => {
                    self.breaker.record_failure();
                    let is_last_step = step_idx + 1 >= self.max_heal_steps;
                    let corrected_intent = if is_last_step {
                        None
                    } else {
                        self.diagnostician
                            .diagnose_and_correct(&current, &error)
                            .await
                    };

                    if self.event_log.is_some() {
                        pending_events.push(HealEvent {
                            id: None,
                            ts: Utc::now(),
                            tool: self.tool_name.clone(),
                            variant: self.variant_id.clone(),
                            original_intent: current.clone(),
                            error: error.clone(),
                            corrected_intent: corrected_intent.clone(),
                            outcome: HealOutcome::Abandoned,
                            step_idx,
                            session_id: session_id.to_string(),
                        });
                    }

                    match corrected_intent {
                        Some(next_intent) => current = next_intent,
                        None => {
                            self.flush_events(&mut pending_events, HealOutcome::Abandoned);
                            return Err(error);
                        }
                    }
                }
            }
        }

        Err(ApplyError::Permanent(
            "heal loop exited without verdict".to_string(),
        ))
    }

    fn flush_events(&self, events: &mut [HealEvent], outcome: HealOutcome) {
        let Some(log) = &self.event_log else {
            return;
        };
        for event in events.iter_mut() {
            event.outcome = outcome;
        }
        let _ = log.append_batch(events);
    }
}
