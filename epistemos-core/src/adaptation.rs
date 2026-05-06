use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Instant;

// ── Adaptation Session Types ────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ExperimentalAdaptTarget {
    #[default]
    HelperModel,
    MainModelExperiment,
}

impl ExperimentalAdaptTarget {
    pub fn label(self) -> &'static str {
        match self {
            Self::HelperModel => "helper_model",
            Self::MainModelExperiment => "main_model_experiment",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AdaptSessionState {
    Idle,
    Accumulating,
    Updating,
    Validating,
    Committed,
    RolledBack,
    Failed,
}

impl AdaptSessionState {
    pub fn label(self) -> &'static str {
        match self {
            Self::Idle => "idle",
            Self::Accumulating => "accumulating",
            Self::Updating => "updating",
            Self::Validating => "validating",
            Self::Committed => "committed",
            Self::RolledBack => "rolled_back",
            Self::Failed => "failed",
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct AdaptSessionConfig {
    pub adapt_target: String,
    pub adapter_id: String,
    pub model_id: String,
    pub min_chunk_tokens: u32,
    pub max_update_count: u32,
    pub max_adapt_steps: u32,
    pub gradient_norm_cap: f64,
    pub canary_loss_threshold_multiplier: f64,
}

impl AdaptSessionConfig {
    pub fn parsed_target(&self) -> ExperimentalAdaptTarget {
        match self.adapt_target.as_str() {
            "main_model_experiment" => ExperimentalAdaptTarget::MainModelExperiment,
            _ => ExperimentalAdaptTarget::HelperModel,
        }
    }
}

impl Default for AdaptSessionConfig {
    fn default() -> Self {
        Self {
            adapt_target: "helper_model".into(),
            adapter_id: String::new(),
            model_id: String::new(),
            min_chunk_tokens: 256,
            max_update_count: 50,
            max_adapt_steps: 200,
            gradient_norm_cap: 1.0,
            canary_loss_threshold_multiplier: 2.0,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct AdaptUpdateResult {
    pub accepted: bool,
    pub canary_loss: f64,
    pub anchor_divergence: f64,
    pub gradient_norm: f64,
    pub rollback_triggered: bool,
    pub duration_ms: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct AdaptSessionSnapshot {
    pub session_id: String,
    pub state: String,
    pub adapter_id: String,
    pub model_id: String,
    pub update_count: u32,
    pub accumulated_tokens: u32,
    pub rollback_count: u32,
    pub baseline_canary_loss: f64,
    pub last_canary_loss: f64,
    pub anchor_divergence: f64,
    pub total_duration_ms: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AdaptSessionError {
    SessionNotFound,
    InvalidTransition,
    NormCapExceeded,
    CanaryFailed,
    BudgetExhausted,
    ExperimentNotAvailable,
    PolicyDenied,
    InternalError,
}

impl std::fmt::Display for AdaptSessionError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let label = match self {
            Self::SessionNotFound => "adapt_session_not_found",
            Self::InvalidTransition => "adapt_invalid_transition",
            Self::NormCapExceeded => "adapt_norm_cap_exceeded",
            Self::CanaryFailed => "adapt_canary_failed",
            Self::BudgetExhausted => "adapt_budget_exhausted",
            Self::ExperimentNotAvailable => "adapt_experiment_not_available",
            Self::PolicyDenied => "adapt_policy_denied",
            Self::InternalError => "adapt_internal_error",
        };
        f.write_str(label)
    }
}

impl std::error::Error for AdaptSessionError {}

// ── SSM Sidecar Lifecycle Types ─────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SidecarSessionState {
    Idle,
    Compressing,
    Ready,
    Failed,
}

impl SidecarSessionState {
    pub fn label(self) -> &'static str {
        match self {
            Self::Idle => "idle",
            Self::Compressing => "compressing",
            Self::Ready => "ready",
            Self::Failed => "failed",
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct SidecarSessionSnapshot {
    pub session_id: String,
    pub state: String,
    pub input_token_count: u32,
    pub compressed_token_count: u32,
    pub compression_ratio: f64,
    pub duration_ms: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SidecarSessionError {
    SessionNotFound,
    InvalidTransition,
    CompressionFailed,
    InternalError,
}

impl std::fmt::Display for SidecarSessionError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let label = match self {
            Self::SessionNotFound => "sidecar_session_not_found",
            Self::InvalidTransition => "sidecar_invalid_transition",
            Self::CompressionFailed => "sidecar_compression_failed",
            Self::InternalError => "sidecar_internal_error",
        };
        f.write_str(label)
    }
}

impl std::error::Error for SidecarSessionError {}

// ── Internal Session State ──────────────────────────────────────────────────

struct AdaptSession {
    config: AdaptSessionConfig,
    state: AdaptSessionState,
    accumulated_tokens: u32,
    update_count: u32,
    rollback_count: u32,
    baseline_canary_loss: f64,
    last_canary_loss: f64,
    anchor_divergence: f64,
    start_time: Instant,
}

impl AdaptSession {
    fn new(config: AdaptSessionConfig) -> Self {
        Self {
            config,
            state: AdaptSessionState::Accumulating,
            accumulated_tokens: 0,
            update_count: 0,
            rollback_count: 0,
            baseline_canary_loss: 0.0,
            last_canary_loss: 0.0,
            anchor_divergence: 0.0,
            start_time: Instant::now(),
        }
    }

    fn snapshot(&self, session_id: &str) -> AdaptSessionSnapshot {
        AdaptSessionSnapshot {
            session_id: session_id.to_string(),
            state: self.state.label().to_string(),
            adapter_id: self.config.adapter_id.clone(),
            model_id: self.config.model_id.clone(),
            update_count: self.update_count,
            accumulated_tokens: self.accumulated_tokens,
            rollback_count: self.rollback_count,
            baseline_canary_loss: self.baseline_canary_loss,
            last_canary_loss: self.last_canary_loss,
            anchor_divergence: self.anchor_divergence,
            total_duration_ms: self.start_time.elapsed().as_secs_f64() * 1000.0,
        }
    }
}

struct SidecarSession {
    state: SidecarSessionState,
    input_token_count: u32,
    compressed_token_count: u32,
    duration_ms: f64,
    start_time: Instant,
}

impl SidecarSession {
    fn new(input_token_count: u32) -> Self {
        Self {
            state: SidecarSessionState::Compressing,
            input_token_count,
            compressed_token_count: 0,
            duration_ms: 0.0,
            start_time: Instant::now(),
        }
    }

    fn snapshot(&self, session_id: &str) -> SidecarSessionSnapshot {
        let ratio = if self.input_token_count > 0 {
            self.compressed_token_count as f64 / self.input_token_count as f64
        } else {
            0.0
        };
        SidecarSessionSnapshot {
            session_id: session_id.to_string(),
            state: self.state.label().to_string(),
            input_token_count: self.input_token_count,
            compressed_token_count: self.compressed_token_count,
            compression_ratio: ratio,
            duration_ms: self.start_time.elapsed().as_secs_f64() * 1000.0,
        }
    }
}

// ── Adaptation Subsystem ────────────────────────────────────────────────────

pub struct AdaptationSubsystem {
    adapt_sessions: Mutex<HashMap<String, AdaptSession>>,
    sidecar_sessions: Mutex<HashMap<String, SidecarSession>>,
    next_session_counter: Mutex<u64>,
}

impl Default for AdaptationSubsystem {
    fn default() -> Self {
        Self::new()
    }
}

impl AdaptationSubsystem {
    pub fn new() -> Self {
        Self {
            adapt_sessions: Mutex::new(HashMap::new()),
            sidecar_sessions: Mutex::new(HashMap::new()),
            next_session_counter: Mutex::new(0),
        }
    }

    fn next_id(&self, prefix: &str) -> String {
        let mut counter = self.next_session_counter.lock().unwrap();
        *counter += 1;
        format!("{prefix}-{:08x}", *counter)
    }

    // ── Adaptation Session API ──────────────────────────────────────────

    pub fn begin_adapt_session(
        &self,
        config: AdaptSessionConfig,
    ) -> Result<String, AdaptSessionError> {
        if config.adapter_id.is_empty() || config.model_id.is_empty() {
            return Err(AdaptSessionError::InternalError);
        }

        if config.parsed_target() == ExperimentalAdaptTarget::MainModelExperiment {
            #[cfg(not(feature = "experimental_main_adapt"))]
            {
                return Err(AdaptSessionError::PolicyDenied);
            }
            #[cfg(feature = "experimental_main_adapt")]
            {
                return Err(AdaptSessionError::ExperimentNotAvailable);
            }
        }

        let session_id = self.next_id("adapt");
        let session = AdaptSession::new(config);

        self.adapt_sessions
            .lock()
            .map_err(|_| AdaptSessionError::InternalError)?
            .insert(session_id.clone(), session);

        Ok(session_id)
    }

    pub fn submit_training_signal(
        &self,
        session_id: String,
        token_count: u32,
    ) -> Result<(), AdaptSessionError> {
        let mut sessions = self
            .adapt_sessions
            .lock()
            .map_err(|_| AdaptSessionError::InternalError)?;
        let session = sessions
            .get_mut(&session_id)
            .ok_or(AdaptSessionError::SessionNotFound)?;

        match session.state {
            AdaptSessionState::Accumulating
            | AdaptSessionState::Committed
            | AdaptSessionState::RolledBack => {
                session.accumulated_tokens += token_count;
                if session.state != AdaptSessionState::Accumulating {
                    session.state = AdaptSessionState::Accumulating;
                }
                Ok(())
            }
            _ => Err(AdaptSessionError::InvalidTransition),
        }
    }

    pub fn set_baseline_canary_loss(
        &self,
        session_id: String,
        baseline_loss: f64,
    ) -> Result<(), AdaptSessionError> {
        let mut sessions = self
            .adapt_sessions
            .lock()
            .map_err(|_| AdaptSessionError::InternalError)?;
        let session = sessions
            .get_mut(&session_id)
            .ok_or(AdaptSessionError::SessionNotFound)?;
        session.baseline_canary_loss = baseline_loss;
        Ok(())
    }

    pub fn fire_update(&self, session_id: String) -> Result<(), AdaptSessionError> {
        let mut sessions = self
            .adapt_sessions
            .lock()
            .map_err(|_| AdaptSessionError::InternalError)?;
        let session = sessions
            .get_mut(&session_id)
            .ok_or(AdaptSessionError::SessionNotFound)?;

        if session.state != AdaptSessionState::Accumulating {
            return Err(AdaptSessionError::InvalidTransition);
        }

        if session.accumulated_tokens < session.config.min_chunk_tokens {
            return Err(AdaptSessionError::InvalidTransition);
        }

        if session.update_count >= session.config.max_update_count {
            return Err(AdaptSessionError::BudgetExhausted);
        }

        session.state = AdaptSessionState::Updating;
        Ok(())
    }

    pub fn report_update_result(
        &self,
        session_id: String,
        result: AdaptUpdateResult,
    ) -> Result<(), AdaptSessionError> {
        let mut sessions = self
            .adapt_sessions
            .lock()
            .map_err(|_| AdaptSessionError::InternalError)?;
        let session = sessions
            .get_mut(&session_id)
            .ok_or(AdaptSessionError::SessionNotFound)?;

        if session.state != AdaptSessionState::Updating {
            return Err(AdaptSessionError::InvalidTransition);
        }

        if result.gradient_norm > session.config.gradient_norm_cap {
            session.state = AdaptSessionState::Accumulating;
            session.accumulated_tokens = 0;
            return Err(AdaptSessionError::NormCapExceeded);
        }

        session.state = AdaptSessionState::Validating;
        session.last_canary_loss = result.canary_loss;
        session.anchor_divergence = result.anchor_divergence;

        let canary_threshold =
            session.baseline_canary_loss * session.config.canary_loss_threshold_multiplier;

        if !result.accepted
            || result.rollback_triggered
            || (session.baseline_canary_loss > 0.0 && result.canary_loss > canary_threshold)
        {
            session.state = AdaptSessionState::RolledBack;
            session.rollback_count += 1;
            session.accumulated_tokens = 0;
            return Err(AdaptSessionError::CanaryFailed);
        }

        session.state = AdaptSessionState::Committed;
        session.update_count += 1;
        session.accumulated_tokens = 0;
        Ok(())
    }

    pub fn end_adapt_session(
        &self,
        session_id: String,
    ) -> Result<AdaptSessionSnapshot, AdaptSessionError> {
        let mut sessions = self
            .adapt_sessions
            .lock()
            .map_err(|_| AdaptSessionError::InternalError)?;
        let session = sessions
            .remove(&session_id)
            .ok_or(AdaptSessionError::SessionNotFound)?;
        Ok(session.snapshot(&session_id))
    }

    pub fn adapt_session_snapshot(
        &self,
        session_id: String,
    ) -> Result<AdaptSessionSnapshot, AdaptSessionError> {
        let sessions = self
            .adapt_sessions
            .lock()
            .map_err(|_| AdaptSessionError::InternalError)?;
        let session = sessions
            .get(&session_id)
            .ok_or(AdaptSessionError::SessionNotFound)?;
        Ok(session.snapshot(&session_id))
    }

    pub fn has_active_session(&self) -> bool {
        self.adapt_sessions
            .lock()
            .map(|sessions| !sessions.is_empty())
            .unwrap_or(false)
    }

    pub fn active_session_adaptation_state(&self) -> String {
        let has_active = self
            .adapt_sessions
            .lock()
            .map(|sessions| {
                sessions.values().any(|s| {
                    matches!(
                        s.state,
                        AdaptSessionState::Accumulating
                            | AdaptSessionState::Updating
                            | AdaptSessionState::Validating
                    )
                })
            })
            .unwrap_or(false);

        let has_rolled_back = self
            .adapt_sessions
            .lock()
            .map(|sessions| {
                sessions
                    .values()
                    .any(|s| s.state == AdaptSessionState::RolledBack)
            })
            .unwrap_or(false);

        if has_active {
            "active_session".to_string()
        } else if has_rolled_back {
            "rolled_back".to_string()
        } else {
            "helper_model_only".to_string()
        }
    }

    // ── SSM Sidecar Session API ─────────────────────────────────────────

    pub fn begin_sidecar_compression(
        &self,
        input_token_count: u32,
    ) -> Result<String, SidecarSessionError> {
        if input_token_count == 0 {
            return Err(SidecarSessionError::InvalidTransition);
        }

        let session_id = self.next_id("sidecar");
        let session = SidecarSession::new(input_token_count);

        self.sidecar_sessions
            .lock()
            .map_err(|_| SidecarSessionError::InternalError)?
            .insert(session_id.clone(), session);

        Ok(session_id)
    }

    pub fn report_sidecar_result(
        &self,
        session_id: String,
        compressed_token_count: u32,
        duration_ms: f64,
    ) -> Result<(), SidecarSessionError> {
        let mut sessions = self
            .sidecar_sessions
            .lock()
            .map_err(|_| SidecarSessionError::InternalError)?;
        let session = sessions
            .get_mut(&session_id)
            .ok_or(SidecarSessionError::SessionNotFound)?;

        if session.state != SidecarSessionState::Compressing {
            return Err(SidecarSessionError::InvalidTransition);
        }

        session.compressed_token_count = compressed_token_count;
        session.duration_ms = duration_ms;
        session.state = SidecarSessionState::Ready;
        Ok(())
    }

    pub fn report_sidecar_failure(&self, session_id: String) -> Result<(), SidecarSessionError> {
        let mut sessions = self
            .sidecar_sessions
            .lock()
            .map_err(|_| SidecarSessionError::InternalError)?;
        let session = sessions
            .get_mut(&session_id)
            .ok_or(SidecarSessionError::SessionNotFound)?;
        session.state = SidecarSessionState::Failed;
        Ok(())
    }

    pub fn end_sidecar_session(
        &self,
        session_id: String,
    ) -> Result<SidecarSessionSnapshot, SidecarSessionError> {
        let mut sessions = self
            .sidecar_sessions
            .lock()
            .map_err(|_| SidecarSessionError::InternalError)?;
        let session = sessions
            .remove(&session_id)
            .ok_or(SidecarSessionError::SessionNotFound)?;
        Ok(session.snapshot(&session_id))
    }

    pub fn sidecar_session_snapshot(
        &self,
        session_id: String,
    ) -> Result<SidecarSessionSnapshot, SidecarSessionError> {
        let sessions = self
            .sidecar_sessions
            .lock()
            .map_err(|_| SidecarSessionError::InternalError)?;
        let session = sessions
            .get(&session_id)
            .ok_or(SidecarSessionError::SessionNotFound)?;
        Ok(session.snapshot(&session_id))
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn default_config() -> AdaptSessionConfig {
        AdaptSessionConfig {
            adapter_id: "test-adapter".into(),
            model_id: "test-model".into(),
            ..Default::default()
        }
    }

    // ── Adaptation session lifecycle ────────────────────────────────────

    #[test]
    fn begin_session_creates_accumulating_state() {
        let subsystem = AdaptationSubsystem::new();
        let session_id = subsystem.begin_adapt_session(default_config()).unwrap();
        let snap = subsystem
            .adapt_session_snapshot(session_id.clone())
            .unwrap();
        assert_eq!(snap.state, "accumulating");
        assert_eq!(snap.update_count, 0);
    }

    #[test]
    fn empty_adapter_id_is_rejected() {
        let subsystem = AdaptationSubsystem::new();
        let config = AdaptSessionConfig {
            adapter_id: "".into(),
            model_id: "test".into(),
            ..Default::default()
        };
        assert!(matches!(
            subsystem.begin_adapt_session(config),
            Err(AdaptSessionError::InternalError)
        ));
    }

    #[test]
    fn submit_signal_accumulates_tokens() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_adapt_session(default_config()).unwrap();
        subsystem.submit_training_signal(sid.clone(), 100).unwrap();
        subsystem.submit_training_signal(sid.clone(), 200).unwrap();
        let snap = subsystem.adapt_session_snapshot(sid.clone()).unwrap();
        assert_eq!(snap.accumulated_tokens, 300);
    }

    #[test]
    fn fire_update_requires_minimum_tokens() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_adapt_session(default_config()).unwrap();
        subsystem.submit_training_signal(sid.clone(), 100).unwrap();
        let err = subsystem.fire_update(sid.clone()).unwrap_err();
        assert_eq!(err, AdaptSessionError::InvalidTransition);
    }

    #[test]
    fn fire_update_transitions_to_updating() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_adapt_session(default_config()).unwrap();
        subsystem.submit_training_signal(sid.clone(), 300).unwrap();
        subsystem.fire_update(sid.clone()).unwrap();
        let snap = subsystem.adapt_session_snapshot(sid.clone()).unwrap();
        assert_eq!(snap.state, "updating");
    }

    #[test]
    fn successful_update_commits() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_adapt_session(default_config()).unwrap();
        subsystem
            .set_baseline_canary_loss(sid.clone(), 1.0)
            .unwrap();
        subsystem.submit_training_signal(sid.clone(), 300).unwrap();
        subsystem.fire_update(sid.clone()).unwrap();

        subsystem
            .report_update_result(
                sid.clone(),
                AdaptUpdateResult {
                    accepted: true,
                    canary_loss: 1.2,
                    anchor_divergence: 0.01,
                    gradient_norm: 0.5,
                    rollback_triggered: false,
                    duration_ms: 25.0,
                },
            )
            .unwrap();

        let snap = subsystem.adapt_session_snapshot(sid.clone()).unwrap();
        assert_eq!(snap.state, "committed");
        assert_eq!(snap.update_count, 1);
        assert_eq!(snap.accumulated_tokens, 0);
    }

    #[test]
    fn canary_failure_triggers_rollback() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_adapt_session(default_config()).unwrap();
        subsystem
            .set_baseline_canary_loss(sid.clone(), 1.0)
            .unwrap();
        subsystem.submit_training_signal(sid.clone(), 300).unwrap();
        subsystem.fire_update(sid.clone()).unwrap();

        let err = subsystem
            .report_update_result(
                sid.clone(),
                AdaptUpdateResult {
                    accepted: true,
                    canary_loss: 3.0,
                    anchor_divergence: 0.5,
                    gradient_norm: 0.5,
                    rollback_triggered: false,
                    duration_ms: 25.0,
                },
            )
            .unwrap_err();

        assert_eq!(err, AdaptSessionError::CanaryFailed);
        let snap = subsystem.adapt_session_snapshot(sid.clone()).unwrap();
        assert_eq!(snap.state, "rolled_back");
        assert_eq!(snap.rollback_count, 1);
    }

    #[test]
    fn rejected_update_rolls_back_even_without_threshold_breach() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_adapt_session(default_config()).unwrap();
        subsystem
            .set_baseline_canary_loss(sid.clone(), 1.0)
            .unwrap();
        subsystem.submit_training_signal(sid.clone(), 300).unwrap();
        subsystem.fire_update(sid.clone()).unwrap();

        let err = subsystem
            .report_update_result(
                sid.clone(),
                AdaptUpdateResult {
                    accepted: false,
                    canary_loss: 1.1,
                    anchor_divergence: 0.01,
                    gradient_norm: 0.5,
                    rollback_triggered: false,
                    duration_ms: 25.0,
                },
            )
            .unwrap_err();

        assert_eq!(err, AdaptSessionError::CanaryFailed);
        let snap = subsystem.adapt_session_snapshot(sid.clone()).unwrap();
        assert_eq!(snap.state, "rolled_back");
        assert_eq!(snap.rollback_count, 1);
        assert_eq!(snap.update_count, 0);
    }

    #[test]
    fn norm_cap_exceeded_drops_update() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_adapt_session(default_config()).unwrap();
        subsystem.submit_training_signal(sid.clone(), 300).unwrap();
        subsystem.fire_update(sid.clone()).unwrap();

        let err = subsystem
            .report_update_result(
                sid.clone(),
                AdaptUpdateResult {
                    accepted: true,
                    canary_loss: 1.0,
                    anchor_divergence: 0.01,
                    gradient_norm: 5.0,
                    rollback_triggered: false,
                    duration_ms: 10.0,
                },
            )
            .unwrap_err();

        assert_eq!(err, AdaptSessionError::NormCapExceeded);
        let snap = subsystem.adapt_session_snapshot(sid.clone()).unwrap();
        assert_eq!(snap.state, "accumulating");
        assert_eq!(snap.update_count, 0);
    }

    #[test]
    fn budget_exhaustion_prevents_further_updates() {
        let subsystem = AdaptationSubsystem::new();
        let config = AdaptSessionConfig {
            adapter_id: "test".into(),
            model_id: "test".into(),
            max_update_count: 1,
            ..Default::default()
        };
        let sid = subsystem.begin_adapt_session(config).unwrap();

        subsystem.submit_training_signal(sid.clone(), 300).unwrap();
        subsystem.fire_update(sid.clone()).unwrap();
        subsystem
            .report_update_result(
                sid.clone(),
                AdaptUpdateResult {
                    accepted: true,
                    canary_loss: 0.0,
                    anchor_divergence: 0.0,
                    gradient_norm: 0.1,
                    rollback_triggered: false,
                    duration_ms: 10.0,
                },
            )
            .unwrap();

        subsystem.submit_training_signal(sid.clone(), 300).unwrap();
        let err = subsystem.fire_update(sid.clone()).unwrap_err();
        assert_eq!(err, AdaptSessionError::BudgetExhausted);
    }

    #[test]
    fn end_session_removes_and_returns_snapshot() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_adapt_session(default_config()).unwrap();
        let snap = subsystem.end_adapt_session(sid.clone()).unwrap();
        assert_eq!(snap.state, "accumulating");

        assert!(matches!(
            subsystem.adapt_session_snapshot(sid.clone()),
            Err(AdaptSessionError::SessionNotFound)
        ));
    }

    #[test]
    fn after_rollback_can_continue_accumulating() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_adapt_session(default_config()).unwrap();
        subsystem
            .set_baseline_canary_loss(sid.clone(), 1.0)
            .unwrap();
        subsystem.submit_training_signal(sid.clone(), 300).unwrap();
        subsystem.fire_update(sid.clone()).unwrap();

        let _ = subsystem.report_update_result(
            sid.clone(),
            AdaptUpdateResult {
                accepted: true,
                canary_loss: 3.0,
                anchor_divergence: 0.5,
                gradient_norm: 0.5,
                rollback_triggered: false,
                duration_ms: 25.0,
            },
        );

        subsystem.submit_training_signal(sid.clone(), 300).unwrap();
        let snap = subsystem.adapt_session_snapshot(sid.clone()).unwrap();
        assert_eq!(snap.state, "accumulating");
        assert_eq!(snap.accumulated_tokens, 300);
    }

    #[test]
    fn active_session_adaptation_state_reflects_sessions() {
        let subsystem = AdaptationSubsystem::new();
        assert_eq!(
            subsystem.active_session_adaptation_state(),
            "helper_model_only"
        );

        let sid = subsystem.begin_adapt_session(default_config()).unwrap();
        assert_eq!(
            subsystem.active_session_adaptation_state(),
            "active_session"
        );

        subsystem.end_adapt_session(sid.clone()).unwrap();
        assert_eq!(
            subsystem.active_session_adaptation_state(),
            "helper_model_only"
        );
    }

    // ── SSM Sidecar lifecycle ───────────────────────────────────────────

    #[test]
    fn sidecar_begin_creates_compressing_state() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_sidecar_compression(1000).unwrap();
        let snap = subsystem.sidecar_session_snapshot(sid.clone()).unwrap();
        assert_eq!(snap.state, "compressing");
        assert_eq!(snap.input_token_count, 1000);
    }

    #[test]
    fn sidecar_zero_tokens_rejected() {
        let subsystem = AdaptationSubsystem::new();
        assert!(matches!(
            subsystem.begin_sidecar_compression(0),
            Err(SidecarSessionError::InvalidTransition)
        ));
    }

    #[test]
    fn sidecar_success_transitions_to_ready() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_sidecar_compression(1000).unwrap();
        subsystem
            .report_sidecar_result(sid.clone(), 200, 150.0)
            .unwrap();
        let snap = subsystem.sidecar_session_snapshot(sid.clone()).unwrap();
        assert_eq!(snap.state, "ready");
        assert_eq!(snap.compressed_token_count, 200);
        assert!((snap.compression_ratio - 0.2).abs() < 0.01);
    }

    #[test]
    fn sidecar_failure_transitions_to_failed() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_sidecar_compression(1000).unwrap();
        subsystem.report_sidecar_failure(sid.clone()).unwrap();
        let snap = subsystem.sidecar_session_snapshot(sid.clone()).unwrap();
        assert_eq!(snap.state, "failed");
    }

    #[test]
    fn sidecar_end_removes_session() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_sidecar_compression(1000).unwrap();
        subsystem
            .report_sidecar_result(sid.clone(), 200, 100.0)
            .unwrap();
        let snap = subsystem.end_sidecar_session(sid.clone()).unwrap();
        assert_eq!(snap.state, "ready");

        assert!(matches!(
            subsystem.sidecar_session_snapshot(sid.clone()),
            Err(SidecarSessionError::SessionNotFound)
        ));
    }

    #[test]
    fn double_report_on_sidecar_fails() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_sidecar_compression(1000).unwrap();
        subsystem
            .report_sidecar_result(sid.clone(), 200, 100.0)
            .unwrap();
        assert!(matches!(
            subsystem.report_sidecar_result(sid.clone(), 100, 50.0),
            Err(SidecarSessionError::InvalidTransition)
        ));
    }

    #[test]
    fn explicit_rollback_flag_triggers_rollback() {
        let subsystem = AdaptationSubsystem::new();
        let sid = subsystem.begin_adapt_session(default_config()).unwrap();
        subsystem.submit_training_signal(sid.clone(), 300).unwrap();
        subsystem.fire_update(sid.clone()).unwrap();

        let err = subsystem
            .report_update_result(
                sid.clone(),
                AdaptUpdateResult {
                    accepted: true,
                    canary_loss: 0.5,
                    anchor_divergence: 0.01,
                    gradient_norm: 0.1,
                    rollback_triggered: true,
                    duration_ms: 10.0,
                },
            )
            .unwrap_err();

        assert_eq!(err, AdaptSessionError::CanaryFailed);
        let snap = subsystem.adapt_session_snapshot(sid.clone()).unwrap();
        assert_eq!(snap.state, "rolled_back");
    }

    // ── Phase 4: Experiment Target Tests ────────────────────────────────

    #[test]
    fn helper_model_target_is_allowed() {
        let subsystem = AdaptationSubsystem::new();
        let config = AdaptSessionConfig {
            adapter_id: "adapter".into(),
            model_id: "helper-model".into(),
            adapt_target: "helper_model".into(),
            ..Default::default()
        };
        let result = subsystem.begin_adapt_session(config);
        assert!(result.is_ok());
    }

    #[test]
    #[cfg(not(feature = "experimental_main_adapt"))]
    fn main_model_experiment_denied_without_feature_flag() {
        let subsystem = AdaptationSubsystem::new();
        let config = AdaptSessionConfig {
            adapter_id: "adapter".into(),
            model_id: "main-model".into(),
            adapt_target: "main_model_experiment".into(),
            ..Default::default()
        };
        let result = subsystem.begin_adapt_session(config);
        assert!(matches!(result, Err(AdaptSessionError::PolicyDenied)));
    }

    #[test]
    #[cfg(feature = "experimental_main_adapt")]
    fn main_model_experiment_returns_not_available_with_flag() {
        let subsystem = AdaptationSubsystem::new();
        let config = AdaptSessionConfig {
            adapter_id: "adapter".into(),
            model_id: "main-model".into(),
            adapt_target: "main_model_experiment".into(),
            ..Default::default()
        };
        let result = subsystem.begin_adapt_session(config);
        assert!(matches!(
            result,
            Err(AdaptSessionError::ExperimentNotAvailable)
        ));
    }

    #[test]
    fn parsed_target_defaults_to_helper() {
        let config = AdaptSessionConfig::default();
        assert_eq!(config.parsed_target(), ExperimentalAdaptTarget::HelperModel);
    }

    #[test]
    fn parsed_target_recognizes_main_model() {
        let config = AdaptSessionConfig {
            adapt_target: "main_model_experiment".into(),
            adapter_id: "a".into(),
            model_id: "m".into(),
            ..Default::default()
        };
        assert_eq!(
            config.parsed_target(),
            ExperimentalAdaptTarget::MainModelExperiment
        );
    }
}
