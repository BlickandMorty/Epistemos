//! Hermes Graph-Native Faculty (Simulation Mode S9; DOCTRINE §8).
//!
//! Per DOCTRINE §8.1 Hermes is privileged — it is **not** "another
//! companion". It is the graph faculty: the agent that owns the
//! seven canonical graph verbs (`graph.search_semantic`,
//! `graph.search_fulltext`, `graph.get_node`, `graph.traverse`,
//! `graph.create_node`, `graph.create_edge`, `graph.commit_session`).
//!
//! This module owns the Rust-side **session lifecycle** for Hermes
//! sessions:
//!
//!   - `HermesSession::begin(...)` — opens a session, allocates a
//!     `SessionId`, and emits `AgentEvent::SessionStarted`. The
//!     7-phase landing ritual (§8.2.2) is theatre over this
//!     substrate (per §8.2 the session begins the moment the user
//!     invokes the action, NOT when the ritual finishes).
//!   - `HermesSession::end(...)` — closes the session and emits
//!     `AgentEvent::SessionCompleted`. Idempotent; closing a
//!     never-opened session is a no-op.
//!
//! The MCP graph-tool catalog itself lives in `omega-mcp/src/catalog.rs`
//! (the seven verbs) — this module is the agent_core-side
//! lifecycle that the Swift host drives via UniFFI.

use std::sync::Mutex;

use crate::companions::CompanionId;
use crate::events::{AgentEvent, SessionId, SessionMode};

/// Lifecycle state for a Hermes session. Per DOCTRINE §8.1
/// "Hermes is privileged" — at most ONE Hermes session can be
/// active at a time per registry (the graph faculty is
/// singular). Multiple Hermes companions can exist in the
/// registry, but only one may hold the faculty session at any
/// moment.
#[derive(Debug)]
pub struct HermesSession {
    inner: Mutex<HermesSessionInner>,
}

#[derive(Debug)]
struct HermesSessionInner {
    /// `Some(...)` while a session is open; `None` after end().
    active: Option<ActiveSession>,
}

#[derive(Debug, Clone)]
struct ActiveSession {
    companion_id: CompanionId,
    session_id: SessionId,
    started_seq: u64,
    last_event_seq: u64,
}

/// Outcome of `HermesSession::begin` — caller dispatches the
/// emitted events through the audit ledger / reducer pipeline,
/// gets a `BeginOutcome::AlreadyActive(_)` for re-entry calls.
#[derive(Debug, Clone)]
pub enum BeginOutcome {
    /// New session opened. Caller must dispatch the events.
    Started {
        companion_id: CompanionId,
        session_id: SessionId,
        events: Vec<AgentEvent>,
    },
    /// A session is already open with this `companion_id` —
    /// caller should NOT replay the ritual or emit events again.
    /// Lets the Swift host re-attach to an in-flight session
    /// (e.g. after a window reload).
    AlreadyActive { session_id: SessionId },
    /// Another Hermes companion already holds the faculty.
    /// Honesty requirement (§8.1 "graph faculty is singular")
    /// — caller decides whether to surface to the user or to
    /// queue a swap.
    Conflict {
        active_companion_id: CompanionId,
        active_session_id: SessionId,
    },
}

/// Outcome of `HermesSession::end` — `Closed` if a session was
/// active and was closed cleanly; `NoOp` if no session was
/// active at all; `WrongCompanion` if the caller asked to close
/// a session that doesn't belong to the requested companion.
#[derive(Debug, Clone)]
pub enum EndOutcome {
    Closed {
        session_id: SessionId,
        events: Vec<AgentEvent>,
    },
    NoOp,
    WrongCompanion {
        active_companion_id: CompanionId,
    },
}

impl HermesSession {
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(HermesSessionInner { active: None }),
        }
    }

    /// Open a new Hermes session for `companion_id`.
    ///
    /// `next_seq` should be monotonically increasing reducer
    /// event_seq values — the session uses them to anchor its
    /// `started_seq` for chip-row ordering (§3.3.1 v1.6) and
    /// `last_event_seq` for the working-pulse gate.
    pub fn begin(
        &self,
        companion_id: CompanionId,
        session_id: SessionId,
        started_seq: u64,
    ) -> BeginOutcome {
        let mut inner = self
            .inner
            .lock()
            .unwrap_or_else(|p| p.into_inner());

        if let Some(active) = inner.active.as_ref() {
            if active.companion_id == companion_id {
                return BeginOutcome::AlreadyActive {
                    session_id: active.session_id.clone(),
                };
            }
            return BeginOutcome::Conflict {
                active_companion_id: active.companion_id,
                active_session_id: active.session_id.clone(),
            };
        }

        inner.active = Some(ActiveSession {
            companion_id,
            session_id: session_id.clone(),
            started_seq,
            last_event_seq: started_seq,
        });

        let events = vec![
            AgentEvent::SessionStarted {
                session_id: session_id.clone(),
                mode: SessionMode::Hermes,
            },
            AgentEvent::ParticipantJoined {
                agent_id: companion_id,
                role: crate::companions::ProviderRole::Faculty,
            },
        ];

        BeginOutcome::Started {
            companion_id,
            session_id,
            events,
        }
    }

    /// Close the active Hermes session.
    pub fn end(&self, companion_id: CompanionId) -> EndOutcome {
        let mut inner = self
            .inner
            .lock()
            .unwrap_or_else(|p| p.into_inner());

        let Some(active) = inner.active.as_ref() else {
            return EndOutcome::NoOp;
        };

        if active.companion_id != companion_id {
            return EndOutcome::WrongCompanion {
                active_companion_id: active.companion_id,
            };
        }

        let session_id = active.session_id.clone();
        inner.active = None;

        EndOutcome::Closed {
            session_id: session_id.clone(),
            events: vec![AgentEvent::SessionCompleted {
                session_id,
                summary: None,
            }],
        }
    }

    /// Bump `last_event_seq` on the active session. Called by
    /// the reducer integration when an event for this session
    /// fires — keeps the chip-row pulse current per §3.3.1 v1.6.
    /// No-op if no session is active or the seq is stale.
    pub fn touch(&self, event_seq: u64) {
        let mut inner = self
            .inner
            .lock()
            .unwrap_or_else(|p| p.into_inner());
        if let Some(active) = inner.active.as_mut() {
            if event_seq > active.last_event_seq {
                active.last_event_seq = event_seq;
            }
        }
    }

    /// Read the current active session for the chip row /
    /// audit view. `None` when no Hermes session is open.
    pub fn snapshot(&self) -> Option<HermesSessionSnapshot> {
        let inner = self
            .inner
            .lock()
            .unwrap_or_else(|p| p.into_inner());
        inner.active.as_ref().map(|a| HermesSessionSnapshot {
            companion_id: a.companion_id,
            session_id: a.session_id.clone(),
            started_seq: a.started_seq,
            last_event_seq: a.last_event_seq,
        })
    }
}

impl Default for HermesSession {
    fn default() -> Self {
        Self::new()
    }
}

/// Read-only snapshot of an active Hermes session for UI / audit.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HermesSessionSnapshot {
    pub companion_id: CompanionId,
    pub session_id: SessionId,
    pub started_seq: u64,
    pub last_event_seq: u64,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cid() -> CompanionId {
        CompanionId::new_ulid()
    }

    #[test]
    fn begin_emits_session_started_and_participant_joined() {
        let h = HermesSession::new();
        let id = cid();
        let sid = SessionId::new("hermes-test");
        let outcome = h.begin(id, sid.clone(), 1);
        match outcome {
            BeginOutcome::Started { companion_id, session_id, events } => {
                assert_eq!(companion_id, id);
                assert_eq!(session_id, sid);
                assert_eq!(events.len(), 2);
                assert!(matches!(events[0], AgentEvent::SessionStarted { .. }));
                assert!(matches!(events[1], AgentEvent::ParticipantJoined { .. }));
                // SessionStarted must use SessionMode::Hermes per §8.2.
                if let AgentEvent::SessionStarted { mode, .. } = &events[0] {
                    assert_eq!(*mode, SessionMode::Hermes);
                }
                // ParticipantJoined uses ProviderRole::Faculty per §5.4
                // Hermes preset row.
                if let AgentEvent::ParticipantJoined { role, .. } = &events[1] {
                    assert_eq!(*role, crate::companions::ProviderRole::Faculty);
                }
            }
            other => panic!("expected Started, got {other:?}"),
        }
    }

    #[test]
    fn re_begin_same_companion_reports_already_active_no_double_emit() {
        let h = HermesSession::new();
        let id = cid();
        let sid = SessionId::new("re-entry");
        let _ = h.begin(id, sid.clone(), 1);
        match h.begin(id, SessionId::new("ignored"), 2) {
            BeginOutcome::AlreadyActive { session_id } => assert_eq!(session_id, sid),
            other => panic!("expected AlreadyActive, got {other:?}"),
        }
    }

    #[test]
    fn begin_with_different_companion_reports_conflict() {
        // §8.1 graph faculty is singular — second begin from a
        // different companion must NOT silently swap; caller
        // decides the resolution.
        let h = HermesSession::new();
        let first = cid();
        let second = cid();
        let _ = h.begin(first, SessionId::new("first"), 1);
        match h.begin(second, SessionId::new("second"), 2) {
            BeginOutcome::Conflict { active_companion_id, .. } => {
                assert_eq!(active_companion_id, first);
            }
            other => panic!("expected Conflict, got {other:?}"),
        }
    }

    #[test]
    fn end_emits_session_completed_and_clears_active() {
        let h = HermesSession::new();
        let id = cid();
        let _ = h.begin(id, SessionId::new("end-me"), 1);
        match h.end(id) {
            EndOutcome::Closed { session_id, events } => {
                assert_eq!(session_id, SessionId::new("end-me"));
                assert_eq!(events.len(), 1);
                assert!(matches!(events[0], AgentEvent::SessionCompleted { .. }));
            }
            other => panic!("expected Closed, got {other:?}"),
        }
        assert!(h.snapshot().is_none());
    }

    #[test]
    fn end_when_no_session_active_is_noop() {
        let h = HermesSession::new();
        match h.end(cid()) {
            EndOutcome::NoOp => {}
            other => panic!("expected NoOp, got {other:?}"),
        }
    }

    #[test]
    fn end_with_wrong_companion_reports_wrong_companion() {
        let h = HermesSession::new();
        let owner = cid();
        let other = cid();
        let _ = h.begin(owner, SessionId::new("s"), 1);
        match h.end(other) {
            EndOutcome::WrongCompanion { active_companion_id } => {
                assert_eq!(active_companion_id, owner);
            }
            other => panic!("expected WrongCompanion, got {other:?}"),
        }
        // The original session is still active.
        assert_eq!(h.snapshot().unwrap().companion_id, owner);
    }

    #[test]
    fn touch_advances_last_event_seq_only_forward() {
        let h = HermesSession::new();
        let id = cid();
        let _ = h.begin(id, SessionId::new("t"), 1);
        h.touch(5);
        assert_eq!(h.snapshot().unwrap().last_event_seq, 5);
        h.touch(3); // backwards — should be ignored.
        assert_eq!(h.snapshot().unwrap().last_event_seq, 5);
        h.touch(10);
        assert_eq!(h.snapshot().unwrap().last_event_seq, 10);
    }

    #[test]
    fn snapshot_after_round_trip_is_empty() {
        let h = HermesSession::new();
        let id = cid();
        let _ = h.begin(id, SessionId::new("rt"), 1);
        let _ = h.end(id);
        assert!(h.snapshot().is_none());
        // A new session can be started immediately.
        let _ = h.begin(id, SessionId::new("rt2"), 2);
        assert!(h.snapshot().is_some());
    }
}
