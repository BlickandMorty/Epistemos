//! Deterministic replay (S2; DOCTRINE I-13 / IMPLEMENTATION §3-S2).
//!
//! Given the same event log, replay produces byte-identical
//! `SimulationDigest`. No `Date::now()` / `Instant::now()` /
//! `arc4random` enters here — events carry their own timestamps via
//! `LogEntry`, and the reducer (S4) consumes only `AgentEvent` +
//! the persisted `ts` string. At S2 the reducer is the minimal
//! `SimulationDigest::apply` projection in `crate::digest`; this
//! module is the substrate that walks the log, applies events in
//! order, and produces the final state.

use std::path::Path;

use crate::event_log::{EventLog, EventLogError, LogEntry};
use crate::digest::SimulationDigest;
use crate::events::AgentEvent;

/// Errors emitted by replay.
#[derive(Debug, thiserror::Error)]
pub enum ReplayError {
    #[error("event log: {0}")]
    EventLog(#[from] EventLogError),
}

/// Apply every event in `events` to a fresh `SimulationDigest` and
/// return the result. Pure — given the same input sequence the
/// output is byte-stable per I-13.
pub fn replay<I>(events: I) -> SimulationDigest
where
    I: IntoIterator<Item = AgentEvent>,
{
    let mut state = SimulationDigest::initial();
    for event in events {
        state.apply(&event);
    }
    state
}

/// Replay an `&[LogEntry]` slice. Convenience for tests that hand
/// in pre-loaded log entries.
pub fn replay_entries(entries: &[LogEntry]) -> SimulationDigest {
    let mut state = SimulationDigest::initial();
    for entry in entries {
        state.apply(&entry.event);
    }
    state
}

/// Replay every entry from the JSONL log at `path`. Validates the
/// hash chain implicitly during read; an integrity break surfaces
/// as `ReplayError::EventLog(EventLogError::Integrity { .. })`.
pub fn replay_log(path: &Path) -> Result<SimulationDigest, ReplayError> {
    let log = EventLog::open(path)?;
    let mut state = SimulationDigest::initial();
    for entry in log.iter()? {
        let entry = entry?;
        state.apply(&entry.event);
    }
    Ok(state)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::companions::{CompanionId, ProviderRole};
    use crate::events::{
        ArtifactKind, ArtifactRef, ArtifactId, MessageId, SessionId, SessionMode,
        ToolCallId, Blake3Hash,
    };

    fn fixture_stream() -> Vec<AgentEvent> {
        let alice = CompanionId::new_ulid();
        let bob = CompanionId::new_ulid();
        let session = SessionId::new("s1");
        vec![
            AgentEvent::SessionStarted {
                session_id: session.clone(),
                mode: SessionMode::Chat,
            },
            AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::CodeWorker,
            },
            AgentEvent::ParticipantJoined {
                agent_id: bob,
                role: ProviderRole::Helper,
            },
            AgentEvent::MessageStarted {
                message_id: MessageId::new("m1"),
                agent_id: alice,
            },
            AgentEvent::MessageDelta {
                message_id: MessageId::new("m1"),
                delta: "hello ".to_string(),
            },
            AgentEvent::MessageDelta {
                message_id: MessageId::new("m1"),
                delta: "world".to_string(),
            },
            AgentEvent::ToolCallStarted {
                tool_call_id: ToolCallId::new("t1"),
                agent_id: alice,
                tool_name: "code_edit".to_string(),
                input_hash: Blake3Hash::of(b"input"),
            },
            AgentEvent::ToolCallCompleted {
                tool_call_id: ToolCallId::new("t1"),
                output_ref: ArtifactRef {
                    id: ArtifactId::new("a1"),
                    kind: ArtifactKind::ToolOutput,
                },
            },
            AgentEvent::Error {
                agent_id: bob,
                code: "E1".to_string(),
                message: "oops".to_string(),
            },
            AgentEvent::ParticipantLeft { agent_id: bob },
            AgentEvent::SessionCompleted {
                session_id: session,
                summary: Some("done".to_string()),
            },
        ]
    }

    #[test]
    fn replay_is_deterministic_byte_for_byte() {
        let events = fixture_stream();
        let a = replay(events.iter().cloned());
        let b = replay(events.iter().cloned());
        assert_eq!(a, b);
        assert_eq!(a.hash(), b.hash(), "byte-identical hashes");
    }

    #[test]
    fn replay_counts_match_event_categories() {
        let events = fixture_stream();
        let s = replay(events);
        assert_eq!(s.event_count, 11);
        assert_eq!(s.message_count, 1);
        assert_eq!(s.tool_call_count, 1);
        assert_eq!(s.error_count, 1);
        // Bob left explicitly; only Alice remains.
        assert_eq!(s.agents_present.len(), 1);
    }

    #[test]
    fn replay_log_round_trips_through_jsonl() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("events.jsonl");
        let events = fixture_stream();

        // Write events to the log with monotonic synthesised
        // timestamps so the test is fully deterministic.
        {
            let mut log = EventLog::open(&path).unwrap();
            let base = chrono::DateTime::parse_from_rfc3339("2026-04-29T00:00:00.000Z")
                .unwrap()
                .with_timezone(&chrono::Utc);
            for (i, e) in events.iter().enumerate() {
                log.append(e, base + chrono::Duration::milliseconds(i as i64))
                    .unwrap();
            }
        }

        let from_log = replay_log(&path).unwrap();
        let in_memory = replay(events.iter().cloned());
        assert_eq!(from_log, in_memory);
        assert_eq!(from_log.hash(), in_memory.hash());
    }

    #[test]
    fn replay_log_surfaces_integrity_error() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("events.jsonl");
        {
            let mut log = EventLog::open(&path).unwrap();
            for e in fixture_stream() {
                log.append_now(&e).unwrap();
            }
        }

        // Tamper: flip a byte in the second line.
        let mut buf = std::fs::read(&path).unwrap();
        let pos_first_newline = buf.iter().position(|b| *b == b'\n').unwrap();
        // Mutate a character inside the second line's payload.
        let target = pos_first_newline + 30;
        if target < buf.len() && buf[target] != b'\n' {
            buf[target] ^= 0x01;
            std::fs::write(&path, &buf).unwrap();
        }

        // Either open's recovery flags it, or replay does.
        let r = replay_log(&path);
        match r {
            Err(ReplayError::EventLog(EventLogError::Integrity { .. }))
            | Err(ReplayError::EventLog(EventLogError::Serde(_))) => {}
            other => panic!("expected integrity / serde error, got {other:?}"),
        }
    }
}
