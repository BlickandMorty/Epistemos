use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use tokio_util::sync::CancellationToken;

use crate::reasoning_metrics::ReasoningTrajectoryMetrics;
use crate::storage::session_store::{SessionFolder, TraceEvent, TranscriptTurn};

static SESSIONS: OnceLock<Mutex<SessionRegistry>> = OnceLock::new();

pub struct GlobalSessions;

impl GlobalSessions {
    fn registry() -> &'static Mutex<SessionRegistry> {
        SESSIONS.get_or_init(|| Mutex::new(SessionRegistry::default()))
    }

    pub fn register(session_id: &str) -> (SessionGuard, CancellationToken) {
        let token = CancellationToken::new();
        let handle = SessionHandle {
            cancel: token.clone(),
            state: SessionState::Running,
            _started_at: chrono::Utc::now(),
            folder: None,
        };

        let mut registry = Self::registry().lock().expect("session registry poisoned");
        registry.sessions.insert(session_id.to_string(), handle);

        (
            SessionGuard {
                session_id: session_id.to_string(),
            },
            token,
        )
    }

    /// Register a session with an associated disk-backed folder.
    pub fn register_with_folder(
        session_id: &str,
        folder: SessionFolder,
    ) -> (SessionGuard, CancellationToken) {
        let token = CancellationToken::new();
        let handle = SessionHandle {
            cancel: token.clone(),
            state: SessionState::Running,
            _started_at: chrono::Utc::now(),
            folder: Some(folder),
        };

        let mut registry = Self::registry().lock().expect("session registry poisoned");
        registry.sessions.insert(session_id.to_string(), handle);

        (
            SessionGuard {
                session_id: session_id.to_string(),
            },
            token,
        )
    }

    /// Get the session folder path for a running session (if it has one).
    pub fn session_folder_path(session_id: &str) -> Option<String> {
        let registry = Self::registry().lock().expect("session registry poisoned");
        registry
            .sessions
            .get(session_id)
            .and_then(|h| h.folder.as_ref())
            .map(|f| f.root().to_string_lossy().to_string())
    }

    pub fn append_transcript_turn(session_id: &str, turn: TranscriptTurn) {
        let mut registry = Self::registry().lock().expect("session registry poisoned");
        if let Some(handle) = registry.sessions.get_mut(session_id) {
            if let Some(ref folder) = handle.folder {
                let _ = folder.append_transcript_turn(&turn);
            }
        }
    }

    pub fn append_trace_event(session_id: &str, event: TraceEvent) {
        let mut registry = Self::registry().lock().expect("session registry poisoned");
        if let Some(handle) = registry.sessions.get_mut(session_id) {
            if let Some(ref folder) = handle.folder {
                let _ = folder.append_trace_event(&event);
            }
        }
    }

    pub fn cancel(session_id: &str) {
        let registry = Self::registry().lock().expect("session registry poisoned");
        if let Some(handle) = registry.sessions.get(session_id) {
            handle.cancel.cancel();
        }
    }

    pub fn complete(
        session_id: &str,
        turns: u32,
        input_tokens: u32,
        output_tokens: u32,
        trajectory_metrics: Option<ReasoningTrajectoryMetrics>,
    ) {
        let mut registry = Self::registry().lock().expect("session registry poisoned");
        if let Some(handle) = registry.sessions.get_mut(session_id) {
            handle.state = SessionState::Completed {
                turns,
                input_tokens,
                output_tokens,
                trajectory_metrics,
            };
        }
    }

    pub fn fail(session_id: &str, error: &str) {
        let mut registry = Self::registry().lock().expect("session registry poisoned");
        if let Some(handle) = registry.sessions.get_mut(session_id) {
            handle.state = SessionState::Failed {
                error: error.to_string(),
            };
        }
    }

    /// Pause a running session to await human approval for a tool call.
    pub fn pause_for_approval(
        session_id: &str,
        tool_name: &str,
        args_json: &str,
        deadline_secs: u64,
    ) {
        let mut registry = Self::registry().lock().expect("session registry poisoned");
        if let Some(handle) = registry.sessions.get_mut(session_id) {
            handle.state = SessionState::PausedForApproval {
                tool_name: tool_name.to_string(),
                args_json: args_json.to_string(),
                deadline_secs,
            };
        }
    }

    /// Resume a session after approval was granted.
    pub fn resume_from_approval(session_id: &str) {
        let mut registry = Self::registry().lock().expect("session registry poisoned");
        if let Some(handle) = registry.sessions.get_mut(session_id) {
            handle.state = SessionState::Running;
        }
    }

    /// Reschedule a session for later (budget exceeded, rate limited, NightBrain deferred).
    pub fn reschedule(session_id: &str, reason: &str) {
        let mut registry = Self::registry().lock().expect("session registry poisoned");
        if let Some(handle) = registry.sessions.get_mut(session_id) {
            handle.state = SessionState::Rescheduled {
                reason: reason.to_string(),
            };
        }
    }

    /// User-initiated termination (distinct from fail — not an error).
    pub fn terminate(session_id: &str) {
        let mut registry = Self::registry().lock().expect("session registry poisoned");
        if let Some(handle) = registry.sessions.get_mut(session_id) {
            handle.cancel.cancel();
            handle.state = SessionState::Terminated;
        }
    }

    pub fn active_count() -> usize {
        let registry = Self::registry().lock().expect("session registry poisoned");
        registry
            .sessions
            .values()
            .filter(|handle| matches!(handle.state, SessionState::Running))
            .count()
    }

    pub fn list() -> Vec<(String, SessionState)> {
        let registry = Self::registry().lock().expect("session registry poisoned");
        registry
            .sessions
            .iter()
            .map(|(id, handle)| (id.clone(), handle.state.clone()))
            .collect()
    }

    fn remove(session_id: &str) {
        let mut registry = Self::registry().lock().expect("session registry poisoned");
        registry.sessions.remove(session_id);
    }
}

#[derive(Default)]
struct SessionRegistry {
    sessions: HashMap<String, SessionHandle>,
}

struct SessionHandle {
    cancel: CancellationToken,
    state: SessionState,
    _started_at: chrono::DateTime<chrono::Utc>,
    folder: Option<SessionFolder>,
}

#[derive(Debug, Clone)]
pub enum SessionState {
    Idle,
    Running,
    PausedForApproval {
        tool_name: String,
        args_json: String,
        /// Seconds since UNIX epoch when approval times out (auto-deny).
        deadline_secs: u64,
    },
    Rescheduled {
        reason: String,
    },
    Completed {
        turns: u32,
        input_tokens: u32,
        output_tokens: u32,
        trajectory_metrics: Option<ReasoningTrajectoryMetrics>,
    },
    Failed {
        error: String,
    },
    Terminated,
}

pub struct SessionGuard {
    session_id: String,
}

impl Drop for SessionGuard {
    fn drop(&mut self) {
        // Cascade-close any PTY sessions tied to this agent session.
        crate::pty::PtyPool::close_all_for_session(&self.session_id);

        // Crash recovery: if the session folder was never finalized, finalize it now
        // with a "failed" status so the session is still browsable.
        {
            let mut registry = GlobalSessions::registry()
                .lock()
                .expect("session registry poisoned");
            if let Some(handle) = registry.sessions.get_mut(&self.session_id) {
                if let Some(ref mut folder) = handle.folder {
                    let (status, turns, input, output, error, trajectory_metrics) =
                        match &handle.state {
                            SessionState::Completed {
                                turns,
                                input_tokens,
                                output_tokens,
                                trajectory_metrics,
                            } => (
                                "completed",
                                *turns,
                                *input_tokens,
                                *output_tokens,
                                None,
                                trajectory_metrics.as_ref(),
                            ),
                            SessionState::Failed { error } => {
                                ("failed", 0, 0, 0, Some(error.as_str()), None)
                            }
                            SessionState::Terminated => (
                                "terminated",
                                0,
                                0,
                                0,
                                Some("session terminated by user"),
                                None,
                            ),
                            SessionState::Rescheduled { reason } => {
                                ("rescheduled", 0, 0, 0, Some(reason.as_str()), None)
                            }
                            SessionState::Idle
                            | SessionState::Running
                            | SessionState::PausedForApproval { .. } => (
                                "failed",
                                0,
                                0,
                                0,
                                Some("session dropped without finalization"),
                                None,
                            ),
                        };
                    // Best-effort finalize — ignore errors during drop
                    let _ =
                        folder.finalize(status, turns, input, output, error, trajectory_metrics);
                    if !folder.root().join("summary.md").exists() {
                        let summary = folder.generate_structured_summary();
                        let summary = if summary.trim().is_empty() {
                            folder.generate_default_summary()
                        } else {
                            summary
                        };
                        let _ = folder.write_summary(&summary);
                    }
                }
            }
        }

        GlobalSessions::remove(&self.session_id);
    }
}
