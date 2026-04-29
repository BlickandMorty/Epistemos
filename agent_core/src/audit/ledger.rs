//! `AuditLedger` — SQLite-backed (delta_id → AuditOrigin) store
//! per DOCTRINE §9.3.
//!
//! Records every `FrameDelta` the reducer emits, indexed for the
//! "Why is this animation happening?" query the Audit View
//! exposes (S14). Schema lives inline at open time per the
//! existing `agent_core/src/session_persistence.rs` precedent
//! (no migration runner today; schema_version table lands when
//! the schema first needs to evolve, per the audit follow-up).
//!
//! Table shape (`frame_delta_audit_log`):
//!
//!   id            INTEGER PK AUTOINCREMENT
//!   delta_id      TEXT     UNIQUE                   -- ULID
//!   origin_kind   TEXT     NOT NULL                 -- 'event' | 'cosmetic_idle' | 'state_transition'
//!   delta_kind    TEXT     NOT NULL                 -- FrameDeltaKind discriminator
//!   event_id      INTEGER                           -- non-null for origin_kind='event'
//!   event_kind    TEXT                              -- non-null for origin_kind='event'
//!   companion_id  TEXT                              -- non-null for cosmetic_idle / state_transition
//!   since_seq     INTEGER                           -- non-null for cosmetic_idle
//!   activity_from TEXT                              -- non-null for state_transition
//!   activity_to   TEXT                              -- non-null for state_transition
//!   recorded_at   TEXT     NOT NULL                 -- RFC3339 with millis
//!
//! The flat-column shape (rather than a single JSON payload)
//! makes the table queryable from `sqlite3` CLI for ad-hoc
//! audit work; the typed `query_*` API on the struct is the
//! canonical way Rust callers should reach in.

use std::path::Path;

use rusqlite::{params, Connection, OptionalExtension};

use super::delta::{DeltaId, FrameDelta, FrameDeltaKind};
use super::origin::{AuditOrigin, AuditOriginKind, EventId};
use crate::companions::{ActivityState, CompanionId};

/// Errors emitted by the audit ledger.
#[derive(Debug, thiserror::Error)]
pub enum AuditError {
    #[error("sqlite: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("decode: column '{column}' had unexpected value '{value}'")]
    Decode { column: &'static str, value: String },
}

/// SQLite-backed audit ledger. Single-writer pattern matches
/// `CompanionRegistry` and `SessionPersistence`; outer ownership
/// wraps in a `Mutex` if multiple producers fan in.
#[derive(Debug)]
pub struct AuditLedger {
    db: Connection,
}

/// One read-back row from `frame_delta_audit_log`. Returned by
/// the typed query methods; the flat-column SQLite shape is
/// reconstituted into a typed `AuditOrigin` here.
#[derive(Debug, Clone, PartialEq)]
pub struct DeltaAuditEntry {
    pub id: i64,
    pub delta_id: DeltaId,
    pub origin: AuditOrigin,
    pub delta_kind: FrameDeltaKind,
    pub recorded_at: String,
}

impl AuditLedger {
    /// Open or create the ledger. Idempotent across launches.
    pub fn open(db_path: &Path) -> Result<Self, AuditError> {
        if let Some(parent) = db_path.parent() {
            if !parent.as_os_str().is_empty() {
                std::fs::create_dir_all(parent)?;
            }
        }
        let db = Connection::open(db_path)?;
        Self::init_schema(&db)?;
        Ok(Self { db })
    }

    /// Open an in-memory ledger. Used by tests + by replay code
    /// that wants to build a transient audit projection without
    /// touching disk.
    pub fn open_in_memory() -> Result<Self, AuditError> {
        let db = Connection::open_in_memory()?;
        Self::init_schema(&db)?;
        Ok(Self { db })
    }

    fn init_schema(db: &Connection) -> Result<(), AuditError> {
        db.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS frame_delta_audit_log (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                delta_id      TEXT NOT NULL UNIQUE,
                origin_kind   TEXT NOT NULL,
                delta_kind    TEXT NOT NULL,
                event_id      INTEGER,
                event_kind    TEXT,
                companion_id  TEXT,
                since_seq     INTEGER,
                activity_from TEXT,
                activity_to   TEXT,
                recorded_at   TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_fda_event_id
                ON frame_delta_audit_log(event_id);
            CREATE INDEX IF NOT EXISTS idx_fda_companion_id
                ON frame_delta_audit_log(companion_id);
            CREATE INDEX IF NOT EXISTS idx_fda_origin_kind
                ON frame_delta_audit_log(origin_kind);
            CREATE INDEX IF NOT EXISTS idx_fda_recorded_at
                ON frame_delta_audit_log(recorded_at);
            ",
        )?;
        Ok(())
    }

    /// Record one delta with a caller-supplied wall timestamp.
    /// The reducer (S4) will call `record_now` for live events;
    /// tests use this form for deterministic assertions.
    pub fn record(
        &mut self,
        delta_id: DeltaId,
        origin: AuditOrigin,
        kind: FrameDeltaKind,
        recorded_at: chrono::DateTime<chrono::Utc>,
    ) -> Result<(), AuditError> {
        let ts = recorded_at.to_rfc3339_opts(chrono::SecondsFormat::Millis, true);
        let origin_kind = origin.kind().as_str();
        let kind_str = serde_json::to_value(kind)
            .ok()
            .and_then(|v| v.as_str().map(String::from))
            .unwrap_or_else(|| "unknown".to_string());

        // Flatten origin into the typed columns.
        let (event_id, event_kind, companion_id, since_seq, activity_from, activity_to) =
            flatten_origin(&origin);

        self.db.execute(
            "INSERT INTO frame_delta_audit_log
                (delta_id, origin_kind, delta_kind, event_id, event_kind,
                 companion_id, since_seq, activity_from, activity_to, recorded_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
            params![
                delta_id.to_string(),
                origin_kind,
                kind_str,
                event_id,
                event_kind,
                companion_id,
                since_seq,
                activity_from,
                activity_to,
                ts,
            ],
        )?;
        Ok(())
    }

    /// Convenience: record with `Utc::now()`.
    pub fn record_now(
        &mut self,
        delta_id: DeltaId,
        origin: AuditOrigin,
        kind: FrameDeltaKind,
    ) -> Result<(), AuditError> {
        self.record(delta_id, origin, kind, chrono::Utc::now())
    }

    /// Bulk-record an entire `FrameDelta` value. Equivalent to
    /// the manual `record` call but takes the typed delta the
    /// reducer produced.
    pub fn record_delta(
        &mut self,
        delta: &FrameDelta,
        recorded_at: chrono::DateTime<chrono::Utc>,
    ) -> Result<(), AuditError> {
        self.record(delta.delta_id, delta.origin.clone(), delta.kind, recorded_at)
    }

    /// User-facing query per DOCTRINE §9.3:
    /// "Why did this animation happen?" Returns the origin
    /// recorded for `delta_id` or `None` if the delta isn't in
    /// the ledger.
    pub fn query_origin(&self, delta_id: DeltaId) -> Result<Option<AuditOrigin>, AuditError> {
        let row = self
            .db
            .query_row(
                "SELECT origin_kind, event_id, event_kind, companion_id,
                        since_seq, activity_from, activity_to
                 FROM frame_delta_audit_log
                 WHERE delta_id = ?1",
                params![delta_id.to_string()],
                |row| Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, Option<i64>>(1)?,
                    row.get::<_, Option<String>>(2)?,
                    row.get::<_, Option<String>>(3)?,
                    row.get::<_, Option<i64>>(4)?,
                    row.get::<_, Option<String>>(5)?,
                    row.get::<_, Option<String>>(6)?,
                )),
            )
            .optional()?;
        match row {
            None => Ok(None),
            Some((kind_s, eid, ekind, cid_s, sseq, afrom, ato)) => {
                let parsed = decode_origin(&kind_s, eid, ekind, cid_s, sseq, afrom, ato)?;
                Ok(Some(parsed))
            }
        }
    }

    /// All deltas attributed to a given `EventId` (e.g., "show
    /// every animation triggered by event #42"). Useful for the
    /// Audit View's per-event drill-down.
    pub fn query_by_event(&self, event_id: EventId) -> Result<Vec<DeltaAuditEntry>, AuditError> {
        let mut stmt = self.db.prepare(
            "SELECT id, delta_id, origin_kind, delta_kind, event_id, event_kind,
                    companion_id, since_seq, activity_from, activity_to, recorded_at
             FROM frame_delta_audit_log
             WHERE event_id = ?1
             ORDER BY id",
        )?;
        let mut rows = stmt.query(params![event_id.seq() as i64])?;
        let mut out = Vec::new();
        while let Some(row) = rows.next()? {
            out.push(row_to_entry(row)??);
        }
        Ok(out)
    }

    /// All deltas attributed to a given companion (any origin
    /// kind). Used by the Audit View's per-companion timeline.
    pub fn query_by_companion(
        &self,
        companion_id: CompanionId,
    ) -> Result<Vec<DeltaAuditEntry>, AuditError> {
        let mut stmt = self.db.prepare(
            "SELECT id, delta_id, origin_kind, delta_kind, event_id, event_kind,
                    companion_id, since_seq, activity_from, activity_to, recorded_at
             FROM frame_delta_audit_log
             WHERE companion_id = ?1
             ORDER BY id",
        )?;
        let mut rows = stmt.query(params![companion_id.to_string()])?;
        let mut out = Vec::new();
        while let Some(row) = rows.next()? {
            out.push(row_to_entry(row)??);
        }
        Ok(out)
    }

    /// All deltas matching one of the three audit-origin kinds.
    /// Useful for "show every cosmetic_idle animation" debugging
    /// queries.
    pub fn query_by_kind(
        &self,
        kind: AuditOriginKind,
    ) -> Result<Vec<DeltaAuditEntry>, AuditError> {
        let mut stmt = self.db.prepare(
            "SELECT id, delta_id, origin_kind, delta_kind, event_id, event_kind,
                    companion_id, since_seq, activity_from, activity_to, recorded_at
             FROM frame_delta_audit_log
             WHERE origin_kind = ?1
             ORDER BY id",
        )?;
        let mut rows = stmt.query(params![kind.as_str()])?;
        let mut out = Vec::new();
        while let Some(row) = rows.next()? {
            out.push(row_to_entry(row)??);
        }
        Ok(out)
    }

    /// Total number of recorded entries. Convenience for tests
    /// and for the Audit View's status summary.
    pub fn count(&self) -> Result<i64, AuditError> {
        let n: i64 = self
            .db
            .query_row("SELECT COUNT(*) FROM frame_delta_audit_log", [], |row| {
                row.get(0)
            })?;
        Ok(n)
    }
}

// =============================================================================
// Origin <-> flat columns conversion.
// =============================================================================

/// Flatten an `AuditOrigin` into the column tuple persisted by
/// `record()`. Borrows from `origin` where possible — `event_kind`
/// is borrowed from the `AuditOrigin::Event` variant; activity
/// state names are `&'static str` from `ActivityState::as_str()`;
/// the `companion_id` is the only allocation (ULID → String).
#[allow(clippy::type_complexity)]
fn flatten_origin(
    origin: &AuditOrigin,
) -> (
    Option<i64>,
    Option<&str>,
    Option<String>,
    Option<i64>,
    Option<&'static str>,
    Option<&'static str>,
) {
    match origin {
        AuditOrigin::Event {
            event_id,
            event_kind,
        } => (
            Some(event_id.seq() as i64),
            Some(event_kind.as_str()),
            None,
            None,
            None,
            None,
        ),
        AuditOrigin::CosmeticIdle {
            companion_id,
            since_seq,
        } => (
            None,
            None,
            Some(companion_id.to_string()),
            Some(since_seq.seq() as i64),
            None,
            None,
        ),
        AuditOrigin::StateTransition {
            companion_id,
            from,
            to,
        } => (
            None,
            None,
            Some(companion_id.to_string()),
            None,
            Some(from.as_str()),
            Some(to.as_str()),
        ),
    }
}

fn decode_origin(
    origin_kind: &str,
    event_id: Option<i64>,
    event_kind: Option<String>,
    companion_id: Option<String>,
    since_seq: Option<i64>,
    activity_from: Option<String>,
    activity_to: Option<String>,
) -> Result<AuditOrigin, AuditError> {
    match origin_kind {
        "event" => {
            let eid = event_id.ok_or(AuditError::Decode {
                column: "event_id",
                value: "NULL".to_string(),
            })?;
            let ek = event_kind.ok_or(AuditError::Decode {
                column: "event_kind",
                value: "NULL".to_string(),
            })?;
            Ok(AuditOrigin::Event {
                event_id: EventId::new(eid as u64),
                event_kind: ek,
            })
        }
        "cosmetic_idle" => {
            let cid_s = companion_id.ok_or(AuditError::Decode {
                column: "companion_id",
                value: "NULL".to_string(),
            })?;
            let cid = CompanionId::parse(&cid_s).ok_or(AuditError::Decode {
                column: "companion_id",
                value: cid_s,
            })?;
            let seq = since_seq.ok_or(AuditError::Decode {
                column: "since_seq",
                value: "NULL".to_string(),
            })?;
            Ok(AuditOrigin::CosmeticIdle {
                companion_id: cid,
                since_seq: EventId::new(seq as u64),
            })
        }
        "state_transition" => {
            let cid_s = companion_id.ok_or(AuditError::Decode {
                column: "companion_id",
                value: "NULL".to_string(),
            })?;
            let cid = CompanionId::parse(&cid_s).ok_or(AuditError::Decode {
                column: "companion_id",
                value: cid_s,
            })?;
            let from_s = activity_from.ok_or(AuditError::Decode {
                column: "activity_from",
                value: "NULL".to_string(),
            })?;
            let to_s = activity_to.ok_or(AuditError::Decode {
                column: "activity_to",
                value: "NULL".to_string(),
            })?;
            let from = parse_activity(&from_s)?;
            let to = parse_activity(&to_s)?;
            Ok(AuditOrigin::StateTransition {
                companion_id: cid,
                from,
                to,
            })
        }
        other => Err(AuditError::Decode {
            column: "origin_kind",
            value: other.to_string(),
        }),
    }
}

fn parse_activity(s: &str) -> Result<ActivityState, AuditError> {
    match s {
        "Active" => Ok(ActivityState::Active),
        "Recent" => Ok(ActivityState::Recent),
        "Dormant" => Ok(ActivityState::Dormant),
        "Parked" => Ok(ActivityState::Parked),
        "JustAcquired" => Ok(ActivityState::JustAcquired),
        other => Err(AuditError::Decode {
            column: "activity_state",
            value: other.to_string(),
        }),
    }
}

fn parse_delta_kind(s: &str) -> Result<FrameDeltaKind, AuditError> {
    let v = serde_json::Value::String(s.to_string());
    serde_json::from_value::<FrameDeltaKind>(v).map_err(|_| AuditError::Decode {
        column: "delta_kind",
        value: s.to_string(),
    })
}

fn row_to_entry(row: &rusqlite::Row<'_>) -> rusqlite::Result<Result<DeltaAuditEntry, AuditError>> {
    let id: i64 = row.get(0)?;
    let delta_id_s: String = row.get(1)?;
    let origin_kind: String = row.get(2)?;
    let delta_kind: String = row.get(3)?;
    let event_id: Option<i64> = row.get(4)?;
    let event_kind: Option<String> = row.get(5)?;
    let companion_id: Option<String> = row.get(6)?;
    let since_seq: Option<i64> = row.get(7)?;
    let activity_from: Option<String> = row.get(8)?;
    let activity_to: Option<String> = row.get(9)?;
    let recorded_at: String = row.get(10)?;

    let delta_id = match DeltaId::parse(&delta_id_s) {
        Some(v) => v,
        None => {
            return Ok(Err(AuditError::Decode {
                column: "delta_id",
                value: delta_id_s,
            }))
        }
    };
    let origin = match decode_origin(
        &origin_kind,
        event_id,
        event_kind,
        companion_id,
        since_seq,
        activity_from,
        activity_to,
    ) {
        Ok(v) => v,
        Err(e) => return Ok(Err(e)),
    };
    let kind = match parse_delta_kind(&delta_kind) {
        Ok(v) => v,
        Err(e) => return Ok(Err(e)),
    };
    Ok(Ok(DeltaAuditEntry {
        id,
        delta_id,
        origin,
        delta_kind: kind,
        recorded_at,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::companions::{ActivityState, CompanionId, ProviderRole};
    use crate::events::{AgentEvent, MessageId};

    fn cid() -> CompanionId {
        CompanionId::new_ulid()
    }

    fn ts(secs: i64) -> chrono::DateTime<chrono::Utc> {
        chrono::DateTime::from_timestamp(1_700_000_000 + secs, 0).unwrap()
    }

    #[test]
    fn record_and_query_event_origin() {
        let mut ledger = AuditLedger::open_in_memory().unwrap();
        let alice = cid();
        let evt = AgentEvent::MessageStarted {
            message_id: MessageId::new("m1"),
            agent_id: alice,
        };
        let delta = FrameDelta::for_event(42, &evt);
        ledger.record_delta(&delta, ts(0)).unwrap();

        let recovered = ledger.query_origin(delta.delta_id).unwrap().unwrap();
        assert_eq!(recovered, delta.origin);
    }

    #[test]
    fn record_and_query_cosmetic_idle_origin() {
        let mut ledger = AuditLedger::open_in_memory().unwrap();
        let alice = cid();
        let delta =
            FrameDelta::for_cosmetic_idle(alice, 7, FrameDeltaKind::AgentAnimation);
        ledger.record_delta(&delta, ts(0)).unwrap();
        let recovered = ledger.query_origin(delta.delta_id).unwrap().unwrap();
        assert_eq!(recovered, delta.origin);
    }

    #[test]
    fn record_and_query_state_transition_origin() {
        let mut ledger = AuditLedger::open_in_memory().unwrap();
        let alice = cid();
        let delta = FrameDelta::for_state_transition(
            alice,
            ActivityState::Active,
            ActivityState::Recent,
        );
        ledger.record_delta(&delta, ts(0)).unwrap();
        let recovered = ledger.query_origin(delta.delta_id).unwrap().unwrap();
        assert_eq!(recovered, delta.origin);
    }

    #[test]
    fn missing_delta_id_returns_none() {
        let ledger = AuditLedger::open_in_memory().unwrap();
        let id = DeltaId::new();
        assert!(ledger.query_origin(id).unwrap().is_none());
    }

    #[test]
    fn query_by_event_returns_all_attributed_deltas() {
        let mut ledger = AuditLedger::open_in_memory().unwrap();
        let alice = cid();
        // Two deltas tagged to event seq 5, one tagged to event seq 9.
        let evt5 = AgentEvent::MessageStarted {
            message_id: MessageId::new("m1"),
            agent_id: alice,
        };
        let evt9 = AgentEvent::ParticipantLeft { agent_id: alice };
        let d1 = FrameDelta::for_event(5, &evt5);
        let d2 = FrameDelta::for_event(5, &evt5);
        let d3 = FrameDelta::for_event(9, &evt9);
        for (d, t) in [(&d1, ts(0)), (&d2, ts(1)), (&d3, ts(2))] {
            ledger.record_delta(d, t).unwrap();
        }
        let by5 = ledger.query_by_event(EventId::new(5)).unwrap();
        let by9 = ledger.query_by_event(EventId::new(9)).unwrap();
        assert_eq!(by5.len(), 2);
        assert_eq!(by9.len(), 1);
        assert_eq!(by9[0].origin, d3.origin);
    }

    #[test]
    fn query_by_companion_returns_idle_and_transition_deltas() {
        let mut ledger = AuditLedger::open_in_memory().unwrap();
        let alice = cid();
        let bob = cid();
        let d_idle = FrameDelta::for_cosmetic_idle(alice, 1, FrameDeltaKind::AgentAnimation);
        let d_trans =
            FrameDelta::for_state_transition(alice, ActivityState::Active, ActivityState::Recent);
        let d_other = FrameDelta::for_cosmetic_idle(bob, 1, FrameDeltaKind::AgentAnimation);
        for (d, t) in [(&d_idle, ts(0)), (&d_trans, ts(1)), (&d_other, ts(2))] {
            ledger.record_delta(d, t).unwrap();
        }
        let alice_rows = ledger.query_by_companion(alice).unwrap();
        let bob_rows = ledger.query_by_companion(bob).unwrap();
        assert_eq!(alice_rows.len(), 2);
        assert_eq!(bob_rows.len(), 1);
    }

    #[test]
    fn query_by_kind_filters_correctly() {
        let mut ledger = AuditLedger::open_in_memory().unwrap();
        let alice = cid();
        let evt = AgentEvent::ParticipantJoined {
            agent_id: alice,
            role: ProviderRole::CodeWorker,
        };
        let d_event = FrameDelta::for_event(1, &evt);
        let d_idle = FrameDelta::for_cosmetic_idle(alice, 0, FrameDeltaKind::AgentAnimation);
        let d_trans =
            FrameDelta::for_state_transition(alice, ActivityState::Active, ActivityState::Recent);
        for (d, t) in [(&d_event, ts(0)), (&d_idle, ts(1)), (&d_trans, ts(2))] {
            ledger.record_delta(d, t).unwrap();
        }
        assert_eq!(ledger.query_by_kind(AuditOriginKind::Event).unwrap().len(), 1);
        assert_eq!(
            ledger
                .query_by_kind(AuditOriginKind::CosmeticIdle)
                .unwrap()
                .len(),
            1
        );
        assert_eq!(
            ledger
                .query_by_kind(AuditOriginKind::StateTransition)
                .unwrap()
                .len(),
            1
        );
    }

    #[test]
    fn schema_init_is_idempotent() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("audit.db");
        {
            let _l = AuditLedger::open(&path).unwrap();
        }
        let l2 = AuditLedger::open(&path).unwrap();
        assert_eq!(l2.count().unwrap(), 0);
    }

    /// Property test (DOCTRINE I-5 contract): a deterministic
    /// AgentEvent stream → every emitted FrameDelta has a
    /// non-null AuditOrigin matching one of the three legal
    /// classes. At S3 the "reducer" is `FrameDelta::for_event`
    /// stub; S4 replaces it with the real reducer and the same
    /// test serves as the regression gate.
    #[test]
    fn property_every_frame_delta_has_valid_origin() {
        use std::collections::HashSet;

        let alice = cid();
        let bob = cid();
        let stream = vec![
            AgentEvent::SessionStarted {
                session_id: crate::events::SessionId::new("s1"),
                mode: crate::events::SessionMode::Chat,
            },
            AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::CodeWorker,
            },
            AgentEvent::MessageStarted {
                message_id: MessageId::new("m1"),
                agent_id: alice,
            },
            AgentEvent::ToolCallStarted {
                tool_call_id: crate::events::ToolCallId::new("t1"),
                agent_id: alice,
                tool_name: "code_edit".to_string(),
                input_hash: crate::events::Blake3Hash::of(b""),
            },
            AgentEvent::SubagentSpawned {
                parent_id: alice,
                child_id: bob,
                count: 1,
            },
            AgentEvent::HandoffStarted {
                from_id: alice,
                to_id: bob,
                payload_id: crate::events::ArtifactRef {
                    id: crate::events::ArtifactId::new("a"),
                    kind: crate::events::ArtifactKind::Document,
                },
            },
            AgentEvent::AwaitingApproval {
                agent_id: bob,
                action: crate::events::PendingAction {
                    action_id: crate::events::ActionId::new("a1"),
                    kind: crate::events::PendingActionKind::ToolCall,
                    description: "x".to_string(),
                    tool_name: None,
                    input: serde_json::Value::Null,
                },
                deadline_ms: 1_000,
            },
            AgentEvent::Error {
                agent_id: bob,
                code: "E1".to_string(),
                message: "oops".to_string(),
            },
            AgentEvent::CompanionActivityStateChanged {
                companion_id: alice,
                from: ActivityState::Active,
                to: ActivityState::Recent,
            },
            AgentEvent::SessionCompleted {
                session_id: crate::events::SessionId::new("s1"),
                summary: None,
            },
        ];

        let mut ledger = AuditLedger::open_in_memory().unwrap();
        let mut seen_ids = HashSet::new();
        for (seq, event) in stream.iter().enumerate() {
            let seq = seq as u64 + 1;
            let delta = FrameDelta::for_event(seq, event);

            // Contract: origin is one of the three legal classes,
            // never None.
            match &delta.origin {
                AuditOrigin::Event {
                    event_id,
                    event_kind,
                } => {
                    assert_eq!(event_id.seq(), seq);
                    assert_eq!(event_kind, event.kind());
                }
                AuditOrigin::CosmeticIdle { .. } | AuditOrigin::StateTransition { .. } => {
                    panic!("for_event constructor must produce Event origin");
                }
            }

            // delta_id must be unique.
            assert!(
                seen_ids.insert(delta.delta_id),
                "duplicate delta_id at seq {seq}"
            );

            ledger.record_delta(&delta, ts(seq as i64)).unwrap();
        }
        // Every recorded row round-trips back through query_origin.
        assert_eq!(ledger.count().unwrap() as usize, stream.len());
    }
}
