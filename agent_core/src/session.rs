use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use tokio_util::sync::CancellationToken;

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

    pub fn cancel(session_id: &str) {
        let registry = Self::registry().lock().expect("session registry poisoned");
        if let Some(handle) = registry.sessions.get(session_id) {
            handle.cancel.cancel();
        }
    }

    pub fn complete(session_id: &str, turns: u32, input_tokens: u32, output_tokens: u32) {
        let mut registry = Self::registry().lock().expect("session registry poisoned");
        if let Some(handle) = registry.sessions.get_mut(session_id) {
            handle.state = SessionState::Completed {
                turns,
                input_tokens,
                output_tokens,
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
}

#[derive(Debug, Clone)]
pub enum SessionState {
    Running,
    Completed {
        turns: u32,
        input_tokens: u32,
        output_tokens: u32,
    },
    Failed {
        error: String,
    },
}

pub struct SessionGuard {
    session_id: String,
}

impl Drop for SessionGuard {
    fn drop(&mut self) {
        // Cascade-close any PTY sessions tied to this agent session.
        crate::pty::PtyPool::close_all_for_session(&self.session_id);
        GlobalSessions::remove(&self.session_id);
    }
}
